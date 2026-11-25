import UIKit

struct EmojiItem: Equatable {
    let glyph: String
    let name: String
    let keywords: String
    let hasTone: Bool
    var base: String {
        let untoned = String(String.UnicodeScalarView(glyph.unicodeScalars.filter {
            !(0x1F3FB...0x1F3FF).contains($0.value) && $0.value != 0xFE0F
        }))
        return Self.variantBases[untoned] ?? untoned
    }
    // Multi-person tone sequences use a different encoding from their default emoji.
    private static let variantBases = [
        "🫱‍🫲": "🤝", "👩‍🤝‍👩": "👭", "👩‍🤝‍👨": "👫", "👨‍🤝‍👨": "👬",
        "🧑‍❤‍💋‍🧑": "💏", "🧑‍❤‍🧑": "💑"
    ]

    static let catalog: [EmojiItem] = {
        guard let url = Bundle.main.url(forResource: "Emoji", withExtension: "tsv"),
              let source = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return source.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t")
            guard fields.count >= 3 else { return nil }
            let glyph = String(fields[1])
            return EmojiItem(glyph: glyph, name: String(fields[2]),
                            keywords: fields.count == 4 ? String(fields[3]) : "",
                            hasTone: glyph.unicodeScalars.contains { (0x1F3FB...0x1F3FF).contains($0.value) })
        }
    }()
}

private final class EmojiCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 30)
        label.textAlignment = .center
        label.frame = contentView.bounds
        label.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        contentView.addSubview(label)
        isAccessibilityElement = true
        accessibilityTraits = .button
        let selected = UIView()
        selected.backgroundColor = .tertiarySystemFill
        selected.layer.cornerRadius = 8
        selectedBackgroundView = selected
    }
    required init?(coder: NSCoder) { fatalError("Programmatic cell") }
}

final class EmojiPicker: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onInsert: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSearchLayoutChange: (() -> Void)?
    private(set) var recent: [EmojiItem]
    private(set) var isSearching = false
    var showsResults: Bool { isSearching && (!searchTerm.isEmpty || variants != nil) }

    private var catalog = [EmojiItem]()
    private var allEmoji = [EmojiItem]()
    private var shown = [EmojiItem]()
    private var allEmojiOffset = CGPoint.zero
    private var committedQuery = ""
    private var queryComposition = BurmeseComposition()
    private var query: String { committedQuery + queryComposition.text }
    private var searchTerm: String {
        query.replacingOccurrences(of: "\u{200C}", with: "").trimmingCharacters(in: .whitespaces)
    }
    private var variants: [EmojiItem]?
    private let stack = UIStackView()
    private let header = UIStackView()
    private let backButton = KeyButton(title: "Back", symbol: "arrow.left")
    private let lettersButton = KeyButton(title: "ABC", modifier: true)
    private let deleteButton = KeyButton(title: "Delete", symbol: "delete.left")
    private let searchField = UIStackView()
    private let queryButton = UIButton(type: .system)
    private let clearQuery = UIButton(type: .system)
    private let heading = UILabel()
    private let grid = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())

    init(recent: [EmojiItem]) {
        self.recent = recent
        super.init(frame: .zero)
        backgroundColor = KeyColors.emojiSurface
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)])
        header.spacing = 4
        configureHeaderButton(backButton) { [weak self] in self?.goBack() }
        configureHeaderButton(lettersButton) { [weak self] in self?.onClose?() }
        configureHeaderButton(deleteButton) { [weak self] in self?.onDelete?() }
        header.addArrangedSubview(backButton)
        header.addArrangedSubview(lettersButton)
        header.addArrangedSubview(searchField)
        header.addArrangedSubview(deleteButton)
        configureSearchField()
        stack.addArrangedSubview(header)
        header.heightAnchor.constraint(equalToConstant: 32).isActive = true
        heading.font = .systemFont(ofSize: 12, weight: .medium)
        heading.textColor = .secondaryLabel
        stack.addArrangedSubview(heading)
        grid.backgroundColor = KeyColors.emojiSurface
        grid.accessibilityIdentifier = "emoji.grid"
        grid.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26.0, *) {
            grid.topEdgeEffect.isHidden = true
            grid.bottomEdgeEffect.isHidden = true
            grid.leftEdgeEffect.isHidden = true
            grid.rightEdgeEffect.isHidden = true
        }
        grid.register(EmojiCell.self, forCellWithReuseIdentifier: "emoji")
        grid.dataSource = self
        grid.delegate = self
        grid.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(hold(_:))))
        stack.addArrangedSubview(grid)
        refresh()
        Task { [weak self] in
            let items = await Task.detached(priority: .userInitiated) { EmojiItem.catalog }.value
            guard let self else { return }
            catalog = items
            let recentGlyphs = Set(self.recent.map(\.glyph))
            allEmoji = self.recent + items.filter { !$0.hasTone && !recentGlyphs.contains($0.glyph) }
            refresh()
        }
    }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }

    private func configureSearchField() {
        searchField.backgroundColor = .tertiarySystemFill
        searchField.layer.cornerRadius = 10
        searchField.layer.cornerCurve = .continuous
        searchField.spacing = 6
        searchField.alignment = .fill
        searchField.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 4)
        searchField.isLayoutMarginsRelativeArrangement = true

        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "magnifyingglass")
        configuration.imagePadding = 7
        configuration.contentInsets = .zero
        configuration.titleLineBreakMode = .byTruncatingHead
        queryButton.configuration = configuration
        queryButton.contentHorizontalAlignment = .leading
        queryButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        queryButton.accessibilityIdentifier = "emoji.search.query"
        queryButton.accessibilityLabel = "Search emoji"
        queryButton.addAction(UIAction { [weak self] _ in self?.beginSearch() }, for: .touchUpInside)
        searchField.addArrangedSubview(queryButton)

        clearQuery.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearQuery.tintColor = .secondaryLabel
        clearQuery.accessibilityLabel = "Clear emoji search"
        let clearWidth = clearQuery.widthAnchor.constraint(greaterThanOrEqualToConstant: 30)
        clearWidth.priority = .defaultHigh
        clearWidth.isActive = true
        clearQuery.addAction(UIAction { [weak self] _ in
            self?.committedQuery = ""
            self?.queryComposition = BurmeseComposition()
            self?.variants = nil
            self?.refresh()
        }, for: .touchUpInside)
        searchField.addArrangedSubview(clearQuery)
    }

    private func configureHeaderButton(_ button: KeyButton, action: @escaping () -> Void) {
        button.fill = .clear
        let width = button.widthAnchor.constraint(equalToConstant: 38)
        width.priority = .defaultHigh
        width.isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func beginSearch() {
        guard !isSearching else { return }
        if variants == nil { allEmojiOffset = grid.contentOffset }
        setSearchActive(true)
    }

    private func setSearchActive(_ active: Bool) {
        isSearching = active
        committedQuery = ""
        queryComposition = BurmeseComposition()
        variants = nil
        stack.removeArrangedSubview(header)
        stack.insertArrangedSubview(header, at: isSearching ? 2 : 0)
        refresh()
    }

    func appendToQuery(_ value: String, composingBurmese: Bool = false) {
        if value == " ", query.last?.isWhitespace != false { return }
        if composingBurmese {
            if queryComposition.startsNewSegment(value) { commitQueryComposition() }
            queryComposition.append(value)
        } else {
            commitQueryComposition()
            committedQuery += value
        }
        refresh()
    }

    func commitQueryComposition() {
        committedQuery += queryComposition.text
        queryComposition = BurmeseComposition()
    }

    func deleteQueryCharacter() {
        if !queryComposition.isEmpty { queryComposition.backspace() }
        else if !committedQuery.isEmpty { committedQuery.unicodeScalars.removeLast() }
        else { return }
        refresh()
    }

    func confirmSearch() {
        commitQueryComposition()
        refresh()
    }

    private func goBack() {
        if variants != nil { variants = nil; refresh() }
        else if isSearching { setSearchActive(false) }
    }

    private func refresh() {
        let search = searchTerm
        if let variants {
            shown = variants
        } else if isSearching {
            let matches = search.isEmpty ? [] : catalog.filter {
                $0.name.localizedCaseInsensitiveContains(search) || $0.keywords.contains(search)
            }
            shown = matches.filter { $0.name == search } + matches.filter { $0.name != search }
        } else {
            shown = allEmoji
        }
        let showingAllEmoji = !isSearching && variants == nil
        backButton.isHidden = showingAllEmoji
        lettersButton.isHidden = !showingAllEmoji
        deleteButton.isHidden = !showingAllEmoji
        queryButton.configuration?.title = query.isEmpty ? "Search emoji" : query
        queryButton.configuration?.baseForegroundColor = query.isEmpty ? .secondaryLabel : KeyColors.ink
        queryButton.accessibilityValue = query.isEmpty ? nil : query
        clearQuery.isHidden = query.isEmpty
        if variants != nil {
            heading.text = "Choose a variation"
        } else {
            heading.text = !search.isEmpty && shown.isEmpty ? "No results" : nil
        }
        heading.isHidden = heading.text == nil
        grid.reloadData()
        if showingAllEmoji { grid.layoutIfNeeded() }
        grid.setContentOffset(showingAllEmoji ? allEmojiOffset : .zero, animated: false)
        onSearchLayoutChange?()
    }

    @objc private func hold(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let path = grid.indexPathForItem(at: gesture.location(in: grid)) else { return }
        let base = shown[path.item].base
        let choices = catalog.filter { $0.base == base }
        if choices.count > 1 {
            if !isSearching && variants == nil { allEmojiOffset = grid.contentOffset }
            variants = choices
            refresh()
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { shown.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoji", for: indexPath) as! EmojiCell
        let item = shown[indexPath.item]
        cell.label.text = item.glyph
        cell.accessibilityLabel = item.name
        cell.accessibilityIdentifier = "emoji.item." + item.glyph
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = shown[indexPath.item]
        onInsert?(item.glyph)
        recent.removeAll { $0 == item }
        recent.insert(item, at: 0)
        recent = Array(recent.prefix(32))
        collectionView.deselectItem(at: indexPath, animated: false)
        if variants != nil {
            variants = nil
            refresh()
        }
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: floor(collectionView.bounds.width / 8), height: 40)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { 0 }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat { 0 }
}
