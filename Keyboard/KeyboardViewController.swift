import UIKit

private struct HostContext: Equatable {
    // UIKit can return nil while connecting or tearing down the extension,
    // although the SDK imports the getter as a nonoptional Swift UUID.
    static func identifier(_ proxy: UITextDocumentProxy) -> UUID? {
        (proxy as? NSObject)?.value(forKey: #keyPath(UITextDocumentProxy.documentIdentifier)) as? UUID
    }

    let document: UUID?
    let before: String?
    let after: String?
    let selection: String?

    init(_ proxy: UITextDocumentProxy) {
        document = Self.identifier(proxy)
        before = proxy.documentContextBeforeInput
        after = proxy.documentContextAfterInput
        selection = proxy.selectedText
    }
}

final class KeyboardViewController: UIInputViewController {
    private let board = UIView()
    private let keyArea = UIStackView()
    private let toolbar = UIStackView()
    private let rows = UIStackView()
    private let candidates = UIStackView()
    private let languageButton = UIButton(type: .system)
    private let appearanceButton = UIButton(type: .system)
    private var height: NSLayoutConstraint?
    private var keyAreaTop: NSLayoutConstraint?
    private var pickerBottom: NSLayoutConstraint?
    private var isSearchingEmoji = false
    private var language = Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .burmese
    private var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "System"
    private var shift = false
    private var symbolPage: Int?
    private var composition = BurmeseComposition()
    private var owner: UUID?
    private var anchorBefore: String?
    private var anchorAfter: String?
    private var letterKeys = [ObjectIdentifier: LetterKey]()
    private var emojiPicker: EmojiPicker?
    private var recentEmoji = [EmojiItem]()
    private var popup: AlternateMenu?
    private var repeatingDelete: Timer?
    private var lookup: Task<Void, Never>?
    private var previousSwitchRequirement: Bool?
    private var currentReturnKey: UIReturnKeyType?

    override func viewDidLoad() {
        super.viewDidLoad()
        board.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(board)
        let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        background.contentView.backgroundColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.black.withAlphaComponent(0.6)
            }
            return UIColor.systemFill.resolvedColor(with: traits)
        }
        background.translatesAutoresizingMaskIntoConstraints = false
        background.isUserInteractionEnabled = false
        board.addSubview(background)
        keyArea.addArrangedSubview(toolbar)
        keyArea.addArrangedSubview(rows)
        keyArea.axis = .vertical
        keyArea.spacing = 5
        keyArea.translatesAutoresizingMaskIntoConstraints = false
        board.addSubview(keyArea)
        let top = keyArea.topAnchor.constraint(equalTo: board.topAnchor, constant: 3)
        keyAreaTop = top
        NSLayoutConstraint.activate([
            board.leadingAnchor.constraint(equalTo: view.leadingAnchor), board.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            board.topAnchor.constraint(equalTo: view.topAnchor), board.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: board.leadingAnchor), background.trailingAnchor.constraint(equalTo: board.trailingAnchor),
            background.topAnchor.constraint(equalTo: board.topAnchor), background.bottomAnchor.constraint(equalTo: board.bottomAnchor),
            keyArea.leadingAnchor.constraint(equalTo: board.safeAreaLayoutGuide.leadingAnchor, constant: 4),
            keyArea.trailingAnchor.constraint(equalTo: board.safeAreaLayoutGuide.trailingAnchor, constant: -4),
            top,
            keyArea.bottomAnchor.constraint(equalTo: board.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            toolbar.heightAnchor.constraint(equalToConstant: 33)
        ])
        let size = view.heightAnchor.constraint(equalToConstant: 278)
        size.priority = UILayoutPriority(999)
        size.isActive = true
        height = size
        rows.axis = .vertical
        rows.distribution = .fillEqually
        rows.spacing = 5
        toolbar.spacing = 3
        candidates.distribution = .fillEqually
        toolbar.addArrangedSubview(languageButton)
        toolbar.addArrangedSubview(candidates)
        toolbar.addArrangedSubview(appearanceButton)
        languageButton.widthAnchor.constraint(equalToConstant: 66).isActive = true
        appearanceButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        var switchConfiguration = UIButton.Configuration.plain()
        switchConfiguration.image = UIImage(systemName: "arrow.left.arrow.right",
                                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        switchConfiguration.imagePlacement = .trailing
        switchConfiguration.imagePadding = 4
        switchConfiguration.contentInsets = .zero
        switchConfiguration.baseForegroundColor = KeyColors.ink
        switchConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = .systemFont(ofSize: 14, weight: .semibold)
            return attributes
        }
        languageButton.configuration = switchConfiguration
        languageButton.addAction(UIAction { [weak self] _ in self?.switchLanguage() }, for: .touchUpInside)
        appearanceButton.setImage(UIImage(systemName: "circle.lefthalf.filled"), for: .normal)
        appearanceButton.accessibilityLabel = "Appearance"
        languageButton.tintColor = KeyColors.ink
        appearanceButton.tintColor = KeyColors.ink
        appearanceButton.showsMenuAsPrimaryAction = true
        primaryLanguage = language.rawValue
        configureAppearance()
        rebuild()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateKeyboardHeight()
        if previousSwitchRequirement != needsInputModeSwitchKey { rebuild() }
    }

    private func updateKeyboardHeight() {
        let compact = traitCollection.verticalSizeClass == .compact
        let baseHeight: CGFloat = compact ? 202 : 278
        var panelHeight: CGFloat = 0
        if let emojiPicker, emojiPicker.isSearching {
            panelHeight = emojiPicker.showsResults ? (compact ? 92 : 140) : 42
        }
        height?.constant = baseHeight + panelHeight
        keyAreaTop?.constant = 3 + panelHeight
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        closeEmoji()
        finishComposition()
        cancelGestures()
        lookup?.cancel()
    }

    private func configureAppearance() {
        switch appearance {
        case "Dark": board.overrideUserInterfaceStyle = .dark
        case "Light": board.overrideUserInterfaceStyle = .light
        default:
            switch textDocumentProxy.keyboardAppearance {
            case .dark: board.overrideUserInterfaceStyle = .dark
            case .light: board.overrideUserInterfaceStyle = .light
            default: board.overrideUserInterfaceStyle = .unspecified
            }
        }
        appearanceButton.accessibilityValue = appearance
        appearanceButton.menu = UIMenu(children: ["System","Light","Dark"].map { choice in
            UIAction(title: choice, state: choice == appearance ? .on : .off) { [weak self] _ in
                self?.appearance = choice
                UserDefaults.standard.set(choice, forKey: "appearance")
                self?.configureAppearance()
            }
        })
    }

    private func switchLanguage() {
        if isSearchingEmoji { emojiPicker?.commitQueryComposition() }
        else { commitComposition() }
        language = language == .burmese ? .english : .burmese
        primaryLanguage = language.rawValue
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        shift = false
        symbolPage = nil
        rebuild()
        updateSuggestions()
    }

    private func cancelGestures() {
        repeatingDelete?.invalidate()
        repeatingDelete = nil
        popup?.removeFromSuperview()
        popup = nil
    }

    private func command(_ title: String, symbol: String? = nil, action: @escaping () -> Void) -> KeyButton {
        let button = KeyButton(title: title, symbol: symbol, modifier: true)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func letterButton(_ letter: LetterKey) -> KeyButton {
        let button = KeyButton(title: LetterKey.label(for: letter.text), hint: letter.hint)
        button.accessibilityIdentifier = "key." + letter.text
        button.addAction(UIAction { [weak self] _ in self?.insert(letter.text) }, for: .touchUpInside)
        if !letter.alternatives.isEmpty {
            letterKeys[ObjectIdentifier(button)] = letter
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(holdLetter(_:)))
            hold.minimumPressDuration = 0.35
            button.addGestureRecognizer(hold)
            button.accessibilityCustomActions = letter.alternatives.map { value in
                UIAccessibilityCustomAction(name: LetterKey.label(for: value)) { [weak self] _ in self?.insert(value); return true }
            }
        }
        return button
    }

    @objc private func holdLetter(_ gesture: UILongPressGestureRecognizer) {
        guard let key = gesture.view as? KeyButton, let letter = letterKeys[ObjectIdentifier(key)] else { return }
        let point = gesture.location(in: board)
        switch gesture.state {
        case .began:
            cancelGestures()
            let menu = AlternateMenu(key: key, letter: letter, board: board, start: point)
            board.addSubview(menu)
            popup = menu
        case .changed: popup?.track(point)
        case .ended:
            popup?.track(point)
            let value = popup?.value
            cancelGestures()
            if let value { insert(value) }
        case .cancelled, .failed: cancelGestures()
        default: break
        }
    }

    private func deleteKey() -> KeyButton {
        let button = command("Delete", symbol: "delete.left") { [weak self] in self?.backspace() }
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(holdDelete(_:)))
        hold.minimumPressDuration = 0.4
        button.addGestureRecognizer(hold)
        return button
    }

    @objc private func holdDelete(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            cancelGestures()
            backspace()
            repeatingDelete = Timer.scheduledTimer(withTimeInterval: 0.085, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.backspace() }
            }
        case .ended, .cancelled, .failed: cancelGestures()
        default: break
        }
    }

    private func rebuild() {
        cancelGestures()
        letterKeys.removeAll(keepingCapacity: true)
        previousSwitchRequirement = needsInputModeSwitchKey
        currentReturnKey = textDocumentProxy.returnKeyType
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        languageButton.configuration?.title = language == .burmese ? "EN" : "မြန်မာ"
        languageButton.accessibilityLabel = language == .burmese ? "Switch to English" : "Switch to Burmese"
        let letterRows = symbolPage.map { KeyboardLayout.symbols(language, second: $0 == 2) }
            ?? KeyboardLayout.letters(language, shift: shift)
        for (i, letters) in letterRows.enumerated() {
            var buttons = letters.map(letterButton)
            if i == letterRows.count - 1 {
                let toggle: KeyButton
                if let page = symbolPage {
                    toggle = command(page == 1 ? "=\\<" : "?123") { [weak self] in
                        self?.symbolPage = page == 1 ? 2 : 1
                        self?.rebuild()
                    }
                } else {
                    toggle = command("Shift", symbol: shift ? "shift.fill" : "shift") { [weak self] in
                        self?.shift.toggle()
                        self?.rebuild()
                    }
                    toggle.accessibilityValue = shift ? "On" : "Off"
                }
                buttons.insert(toggle, at: 0)
                buttons.append(deleteKey())
            }
            let row = UIStackView(arrangedSubviews: buttons)
            row.distribution = .fillEqually
            row.spacing = 4
            if language == .english && symbolPage == nil && i == 1 {
                let inset = UILayoutGuide()
                let wrapper = UIView()
                wrapper.addLayoutGuide(inset)
                row.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(row)
                NSLayoutConstraint.activate([inset.widthAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: 0.05),
                    inset.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor), row.leadingAnchor.constraint(equalTo: inset.trailingAnchor),
                    row.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor), row.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)])
                rows.addArrangedSubview(wrapper)
            } else { rows.addArrangedSubview(row) }
        }
        let bottom = UIStackView()
        bottom.spacing = 4
        let symbols = command(symbolPage == nil ? (language == .burmese ? "?၁၂၃" : "?123") :
                                (language == .burmese ? "ကခ" : "ABC")) { [weak self] in
            guard let self else { return }
            if self.isSearchingEmoji { self.emojiPicker?.commitQueryComposition() }
            else { self.commitComposition() }
            self.symbolPage = self.symbolPage == nil ? 1 : nil
            self.shift = false
            self.rebuild()
        }
        bottom.addArrangedSubview(symbols)
        if needsInputModeSwitchKey {
            let globe = KeyButton(title: "Next keyboard", symbol: "globe", modifier: true)
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            bottom.addArrangedSubview(globe)
        }
        let punctuation = symbolPage == 2 ? ["<",">"] : language == .burmese && symbolPage == nil ? ["၊","။"] : [",","."]
        bottom.addArrangedSubview(letterButton(LetterKey(punctuation[0])))
        if symbolPage == nil && !isSearchingEmoji {
            bottom.addArrangedSubview(command("Emoji", symbol: "face.smiling") { [weak self] in self?.openEmoji() })
        }
        let space = command(language.title) { [weak self] in self?.insertLiteral(" ") }
        space.accessibilityLabel = "Space"
        space.fill = KeyColors.letter
        bottom.addArrangedSubview(space)
        let trailing = language == .english && symbolPage == nil ? KeyboardLayout.period : LetterKey(punctuation[1])
        bottom.addArrangedSubview(letterButton(trailing))
        let action = isSearchingEmoji ? .search : currentReturnKey
        let enter = command(action == .search ? "Search" : "Return", symbol: action == .search ? "magnifyingglass" : "return") {
            [weak self] in self?.insertLiteral("\n")
        }
        bottom.addArrangedSubview(enter)
        rows.addArrangedSubview(bottom)
        for button in bottom.arrangedSubviews where button !== space {
            let fraction = button === symbols || button === enter ? 0.14 : 0.09
            button.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: fraction).isActive = true
        }
    }

    private func openEmoji() {
        commitComposition()
        cancelGestures()
        guard emojiPicker == nil else { return }
        let picker = EmojiPicker(recent: recentEmoji)
        picker.onInsert = { [weak self] in self?.insertHostText($0) }
        picker.onDelete = { [weak self] in self?.deleteFromHost() }
        picker.onClose = { [weak self] in self?.closeEmoji() }
        picker.onSearchLayoutChange = { [weak self] in self?.updateEmojiLayout() }
        picker.translatesAutoresizingMaskIntoConstraints = false
        board.addSubview(picker)
        NSLayoutConstraint.activate([picker.topAnchor.constraint(equalTo: board.topAnchor),
            picker.leadingAnchor.constraint(equalTo: board.safeAreaLayoutGuide.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: board.safeAreaLayoutGuide.trailingAnchor)])
        let bottom = picker.bottomAnchor.constraint(equalTo: board.safeAreaLayoutGuide.bottomAnchor)
        bottom.isActive = true
        pickerBottom = bottom
        emojiPicker = picker
        keyArea.isHidden = true
    }

    private func updateEmojiLayout() {
        guard let picker = emojiPicker else { return }
        if isSearchingEmoji != picker.isSearching {
            isSearchingEmoji = picker.isSearching
            pickerBottom?.isActive = false
            let bottom = isSearchingEmoji ? keyArea.topAnchor : board.safeAreaLayoutGuide.bottomAnchor
            let constraint = picker.bottomAnchor.constraint(equalTo: bottom)
            constraint.isActive = true
            pickerBottom = constraint
            keyArea.isHidden = !isSearchingEmoji
            shift = false
            symbolPage = nil
            rebuild()
        }
        updateKeyboardHeight()
    }

    private func closeEmoji() {
        guard let picker = emojiPicker else { return }
        let wasSearching = isSearchingEmoji
        recentEmoji = picker.recent
        picker.removeFromSuperview()
        emojiPicker = nil
        pickerBottom = nil
        isSearchingEmoji = false
        keyArea.isHidden = false
        if wasSearching {
            shift = false
            symbolPage = nil
            rebuild()
        }
        updateKeyboardHeight()
        updateSuggestions()
    }

    private func resetOwnership() {
        composition = BurmeseComposition()
        owner = nil
        anchorBefore = nil
        anchorAfter = nil
    }

    private func finishComposition() {
        let previousOwner = owner
        resetOwnership()
        if let previousOwner, previousOwner == HostContext.identifier(textDocumentProxy) {
            textDocumentProxy.unmarkText()
        }
    }

    /// An explicit insertion commits the marked range through the host proxy.
    /// On the iOS 27 simulator, unmark followed immediately by another mark
    /// could replace the previous syllable before the host finished unmarking.
    private func commitComposition() {
        guard !composition.isEmpty else { return }
        let context = HostContext(textDocumentProxy)
        checkOwnership(context)
        guard let owner, owner == context.document else { return }
        let text = composition.text
        resetOwnership()
        textDocumentProxy.insertText(text)
    }

    private func checkOwnership(_ context: HostContext) {
        guard let owner else { return }
        let expected = (anchorBefore ?? "") + composition.text
        let truncatedMatch = context.before.map { value in
            !value.isEmpty && expected.unicodeScalars.suffix(value.unicodeScalars.count).elementsEqual(value.unicodeScalars)
        } ?? false
        guard context.document == owner, context.selection?.isEmpty != false, context.after == anchorAfter,
              context.before == anchorBefore || context.before == expected ||
                truncatedMatch
        else { finishComposition(); return }
    }

    private func insert(_ value: String) {
        let composes = language == .burmese && symbolPage == nil && BurmeseComposition.canCompose(value)
        if isSearchingEmoji {
            emojiPicker?.appendToQuery(value, composingBurmese: composes)
            didType()
            return
        }
        guard composes else {
            insertLiteral(value)
            return
        }
        let context = HostContext(textDocumentProxy)
        guard context.document != nil else { insertLiteral(value); return }
        checkOwnership(context)
        if composition.startsNewSegment(value) { commitComposition() }
        if owner == nil {
            let start = HostContext(textDocumentProxy)
            owner = start.document
            anchorBefore = start.before
            anchorAfter = start.after
        }
        composition.append(value)
        mark()
        didType()
    }

    private func mark() {
        textDocumentProxy.setMarkedText(composition.text,
                                        selectedRange: NSRange(location: composition.text.utf16.count, length: 0))
    }

    private func insertLiteral(_ value: String) {
        if isSearchingEmoji {
            if value == "\n" { emojiPicker?.confirmSearch() }
            else { emojiPicker?.appendToQuery(value) }
            didType()
            return
        }
        insertHostText(value)
    }

    private func insertHostText(_ value: String) {
        commitComposition()
        textDocumentProxy.insertText(value)
        didType()
    }

    private func didType() {
        if shift {
            shift = false
            rebuild()
        }
        updateSuggestions()
    }

    private func backspace() {
        if isSearchingEmoji {
            emojiPicker?.deleteQueryCharacter()
            return
        }
        deleteFromHost()
    }

    private func deleteFromHost() {
        let proxy = textDocumentProxy
        let context = HostContext(proxy)
        checkOwnership(context)
        if !composition.isEmpty {
            composition.backspace()
            mark()
            if composition.isEmpty { finishComposition() }
        } else {
            proxy.deleteBackward()
            let result = HostContext(proxy)
            if context.document != nil, context.selection?.isEmpty != false, context.document == result.document, context.after == result.after,
               let before = context.before, let remaining = result.before,
               let restore = BurmeseDeletion.retainedScalars(before: before, afterHostDelete: remaining) {
                proxy.insertText(restore)
            }
        }
        updateSuggestions()
    }

    private func updateSuggestions() {
        lookup?.cancel()
        candidates.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard emojiPicker == nil else { return }
        let context = HostContext(textDocumentProxy)
        guard context.document != nil, context.selection?.isEmpty != false else { return }
        let marked = composition.text
        // UITextDocumentProxy commonly returns only the text preceding its marked range.
        var before = context.before ?? ""
        if owner == context.document && context.before == anchorBefore { before += marked }
        guard !before.isEmpty else { return }
        let mode = language
        lookup = Task { [weak self] in
            // Coalesce rapid taps. Only immutable text and language go to the worker.
            let recent = String(before.unicodeScalars.suffix(96))
            let results = await Task.detached(priority: .utility) {
                Completions.matches(before: recent, language: mode)
            }.value
            guard !Task.isCancelled, let self, self.language == mode, self.composition.text == marked,
                  HostContext(self.textDocumentProxy) == context else { return }
            for candidate in results {
                let button = UIButton(type: .system)
                button.setTitle(candidate.title, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 14)
                button.titleLabel?.adjustsFontSizeToFitWidth = true
                button.tintColor = KeyColors.ink
                button.addAction(UIAction { [weak self] _ in
                    guard let self, self.language == mode, self.composition.text == marked, HostContext(self.textDocumentProxy) == context else { return }
                    self.insertLiteral(candidate.suffix)
                }, for: .touchUpInside)
                self.candidates.addArrangedSubview(button)
            }
        }
    }

    override func selectionWillChange(_ textInput: UITextInput?) { finishComposition() }
    override func textWillChange(_ textInput: UITextInput?) { finishComposition() }
    override func selectionDidChange(_ textInput: UITextInput?) { updateSuggestions() }
    override func textDidChange(_ textInput: UITextInput?) {
        guard isViewLoaded else { return }
        configureAppearance()
        if currentReturnKey != textDocumentProxy.returnKeyType { rebuild() }
        updateSuggestions()
    }
}
