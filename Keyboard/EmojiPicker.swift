import Accessibility
import UIKit

private final class EmojiGrid: UICollectionView {
    private let flow = UICollectionViewFlowLayout()

    init() {
        flow.minimumLineSpacing = 0
        flow.minimumInteritemSpacing = 0
        super.init(frame: .zero, collectionViewLayout: flow)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic grid") }

    override func layoutSubviews() {
        let size = CGSize(width: max(1, floor(bounds.width / 8)), height: 40)
        if flow.itemSize != size { flow.itemSize = size }
        super.layoutSubviews()
    }
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

private final class EmojiQueryButton: UIButton {
    private let caret = UIView()
    private var editingQuery: String?

    init() {
        super.init(frame: .zero)
        caret.isHidden = true
        caret.isUserInteractionEnabled = false
        caret.backgroundColor = .systemBlue
        caret.layer.cornerRadius = 1
        addSubview(caret)
        NotificationCenter.default.addObserver(self, selector: #selector(updateCaret), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        if #available(iOS 18.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(updateCaret), name: AccessibilitySettings.prefersNonBlinkingTextInsertionIndicatorDidChangeNotification, object: nil)
        }
    }

    required init?(coder: NSCoder) { fatalError("Programmatic button") }

    func display(_ query: String, editing: Bool) {
        configuration?.title = query.isEmpty ? "Search emoji" : query
        configuration?.baseForegroundColor = query.isEmpty ? .secondaryLabel : KeyColors.ink
        accessibilityValue = query.isEmpty ? nil : query
        accessibilityHint = editing ? "Keys enter an emoji search. Tap Done to return to typing." : nil
        let next = editing ? query : nil
        guard next != editingQuery else { return }
        editingQuery = next
        updateCaret()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let editingQuery, let titleLabel else { return }
        let textRect = titleLabel.textRect(forBounds: titleLabel.bounds, limitedToNumberOfLines: 1)
        let text = titleLabel.convert(textRect, to: self)
        let x = editingQuery.isEmpty ? text.minX - 2 : text.maxX + 1
        let height = min(bounds.height, ceil(titleLabel.font.lineHeight))
        caret.frame = CGRect(x: min(max(0, x), bounds.width - 2), y: (bounds.height - height) / 2, width: 2, height: height)
        bringSubviewToFront(caret)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateCaret()
    }

    @objc private func updateCaret() {
        caret.layer.removeAnimation(forKey: "blink")
        caret.isHidden = editingQuery == nil || window == nil
        guard !caret.isHidden, !UIAccessibility.isReduceMotionEnabled else { return }
        if #available(iOS 18.0, *), AccessibilitySettings.prefersNonBlinkingTextInsertionIndicator { return }
        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = [1, 0, 1]
        blink.keyTimes = [0, 0.55, 1]
        blink.calculationMode = .discrete
        blink.duration = 1
        blink.repeatCount = .infinity
        caret.layer.add(blink, forKey: "blink")
    }
}

final class EmojiPicker: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    private static let catalogTask = Task.detached(priority: .userInitiated) {
        // Keep unsupported sequences out of browsing, search, recents and variants.
        let maximumVersion: Double
        if #available(iOS 26.4, *) { maximumVersion = 17 }
        else if #available(iOS 18.4, *) { maximumVersion = 16 }
        else if #available(iOS 17.4, *) { maximumVersion = 15.1 }
        else if #available(iOS 16.4, *) { maximumVersion = 15 }
        else { maximumVersion = 14 }
        let tsv = Bundle.main.url(forResource: "Emoji", withExtension: "tsv")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        return EmojiCatalog(tsv: tsv, maximumVersion: maximumVersion)
    }

    var onInsert: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSearchLayoutChange: (() -> Void)?
    private(set) var recent: [EmojiItem]
    private(set) var isSearching = false
    var showsResults: Bool { isSearching && (!searchTerm.isEmpty || variants != nil) }

    private var catalog: EmojiCatalog?
    private var searchTask: Task<Void, Never>?
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
    private let lettersButton = KeyButton(title: "", modifier: true)
    private let deleteButton = KeyButton(title: "Delete", symbol: "delete.left")
    private let doneButton = KeyButton(title: "Done", modifier: true)
    private let searchField = UIStackView()
    private let queryButton = EmojiQueryButton()
    private let clearQuery = UIButton(type: .system)
    private let heading = UILabel()
    private let grid = EmojiGrid()

    init(recent: [EmojiItem], language: Language, topInset: CGFloat) {
        self.recent = recent
        super.init(frame: .zero)
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: topAnchor, constant: topInset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)])
        header.spacing = 4
        configureHeaderButton(backButton) { [weak self] in self?.goBack() }
        setReturnLanguage(language)
        configureHeaderButton(lettersButton) { [weak self] in self?.onClose?() }
        configureHeaderButton(deleteButton) { [weak self] in self?.onDelete?() }
        configureHeaderButton(doneButton, width: 50) { [weak self] in self?.onClose?() }
        doneButton.accessibilityIdentifier = "emoji.search.done"
        doneButton.accessibilityHint = "Closes emoji search and returns to typing."
        header.addArrangedSubview(backButton)
        header.addArrangedSubview(lettersButton)
        header.addArrangedSubview(searchField)
        header.addArrangedSubview(doneButton)
        header.addArrangedSubview(deleteButton)
        configureSearchField()
        stack.addArrangedSubview(header)
        header.heightAnchor.constraint(equalToConstant: 32).isActive = true
        heading.font = .systemFont(ofSize: 12, weight: .medium)
        heading.textColor = .secondaryLabel
        stack.addArrangedSubview(heading)
        grid.backgroundColor = .clear
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
            let catalog = await Self.catalogTask.value
            guard let self else { return }
            self.catalog = catalog
            self.recent = catalog.recent(glyphs: UserDefaults.standard.stringArray(forKey: "recentEmoji") ?? recent.map(\.glyph))
            self.allEmoji = catalog.browse(recent: self.recent)
            refresh()
        }
    }

    deinit { searchTask?.cancel() }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }

    func setReturnLanguage(_ language: Language) {
        let title = language == .english ? "abc" : "ကခ"
        lettersButton.setTitle(title, for: .normal)
        lettersButton.titleLabel?.font = KeyButton.labelFont(for: title, size: 16)
        lettersButton.accessibilityLabel = language == .english ? "Return to English keyboard" : "Return to Burmese keyboard"
    }

    private func configureSearchField() {
        searchField.backgroundColor = .tertiarySystemFill
        searchField.layer.cornerRadius = 10
        searchField.layer.cornerCurve = .continuous
        searchField.clipsToBounds = true
        searchField.spacing = 6
        searchField.alignment = .fill
        searchField.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 4)
        searchField.isLayoutMarginsRelativeArrangement = true

        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "magnifyingglass")
        configuration.preferredSymbolConfigurationForImage = .init(pointSize: 13, weight: .regular)
        configuration.imagePadding = 7
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4)
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

    private func configureHeaderButton(_ button: KeyButton, width: CGFloat = 38, action: @escaping () -> Void) {
        button.fill = .clear
        let constraint = button.widthAnchor.constraint(equalToConstant: width)
        constraint.priority = .defaultHigh
        constraint.isActive = true
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
        searchTask?.cancel()
        let needsSearch = isSearching && variants == nil && !search.isEmpty
        shown = variants ?? (isSearching ? [] : allEmoji)
        if needsSearch, let catalog {
            searchTask = Task.detached(priority: .userInitiated) { [weak self] in
                let matches = catalog.matches(search)
                await MainActor.run { [weak self] in
                    guard !Task.isCancelled, let self else { return }
                    self.shown = matches
                    self.heading.text = matches.isEmpty ? "No results" : nil
                    self.heading.isHidden = !matches.isEmpty
                    self.grid.reloadData()
                }
            }
        }
        let showingAllEmoji = !isSearching && variants == nil
        backButton.isHidden = showingAllEmoji
        lettersButton.isHidden = !showingAllEmoji
        deleteButton.isHidden = !showingAllEmoji
        doneButton.isHidden = !isSearching
        queryButton.display(query, editing: isSearching)
        clearQuery.isHidden = query.isEmpty
        heading.text = variants == nil ? nil : "Choose a variation"
        heading.isHidden = heading.text == nil
        grid.reloadData()
        if showingAllEmoji && allEmojiOffset != .zero { grid.layoutIfNeeded() }
        grid.setContentOffset(showingAllEmoji ? allEmojiOffset : .zero, animated: false)
        onSearchLayoutChange?()
    }

    @objc private func hold(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let path = grid.indexPathForItem(at: gesture.location(in: grid)) else { return }
        let choices = catalog?.variants(for: shown[path.item]) ?? []
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
        UserDefaults.standard.set(recent.map(\.glyph), forKey: "recentEmoji")
        collectionView.deselectItem(at: indexPath, animated: false)
        if variants != nil {
            variants = nil
            refresh()
        }
    }
}
