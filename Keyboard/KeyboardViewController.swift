import UIKit

private extension HostContext {
    // UIKit can return nil while connecting or tearing down the extension,
    // although the SDK imports the getter as a nonoptional Swift UUID.
    static func identifier(_ proxy: UITextDocumentProxy) -> UUID? {
        (proxy as? NSObject)?.value(forKey: #keyPath(UITextDocumentProxy.documentIdentifier)) as? UUID
    }


    init(_ proxy: UITextDocumentProxy) {
        document = Self.identifier(proxy)
        before = proxy.documentContextBeforeInput
        after = proxy.documentContextAfterInput
        selection = proxy.selectedText
    }
}

@MainActor
private struct ProxyEditHost: BurmeseEditHost {
    let proxy: UITextDocumentProxy
    var context: HostContext { HostContext(proxy) }
    var hasText: Bool { proxy.hasText }
    func insert(_ text: String) { proxy.insertText(text) }
    func mark(_ text: String) {
        proxy.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0))
    }
    func moveCaret(byUTF16 offset: Int) { proxy.adjustTextPosition(byCharacterOffset: offset) }
    func unmark() { proxy.unmarkText() }
    func deleteBackward() { proxy.deleteBackward() }
}

@MainActor
private final class EnglishWordCompletions {
    private let checker = UITextChecker()
    private let language: String?
    private let cache = NSCache<NSString, NSArray>()

    init() {
        let available = UITextChecker.availableLanguages
        language = available.first { $0 == "en_US" } ?? available.first { $0 == "en" || $0.hasPrefix("en_") }
        cache.countLimit = 96
    }

    func words(for prefix: String) -> [String] {
        guard !prefix.isEmpty, let language else { return [] }
        if let saved = cache.object(forKey: prefix as NSString) as? [String] { return saved }
        let range = NSRange(location: 0, length: prefix.utf16.count)
        let words = Array((checker.completions(forPartialWordRange: range, in: prefix, language: language) ?? []).prefix(16))
        if !words.isEmpty { cache.setObject(words as NSArray, forKey: prefix as NSString) }
        return words
    }
}

final class KeyboardViewController: UIInputViewController {
    private let board = UIView()
    private let contentTopInset: CGFloat = 7
    private let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let keyArea = UIStackView()
    private let toolbar = UIStackView()
    private let rows = UIStackView()
    private let candidates = UIStackView()
    private let settingsButton = UIButton(type: .system)
    private var height: NSLayoutConstraint?
    private var keyAreaTop: NSLayoutConstraint?
    private var pickerBottom: NSLayoutConstraint?
    private var isSearchingEmoji = false
    private var language = Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .burmese
    private var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "System"
    private var autoCapitalize = UserDefaults.standard.object(forKey: "autoCapitalize") as? Bool ?? true
    private var wordSuggestions = UserDefaults.standard.object(forKey: "wordSuggestions") as? Bool ?? true
    private var manualShiftContext: HostContext?
    private var shift = false
    private var doubleSpace = DoubleSpaceShortcut()
    private var typedOnSymbols = false
    private var symbolPage: Int?
    private var editor = BurmeseHostEditor()
    private var editHost: ProxyEditHost { ProxyEditHost(proxy: textDocumentProxy) }
    private var englishLetters = [KeyButton]()
    private weak var englishShiftButton: KeyButton?
    private var emojiPicker: EmojiPicker?
    private var recentEmoji = [EmojiItem]()
    private let keyPopup = KeyPopup()
    private var repeatingDelete: Timer?
    private var lookup: Task<Void, Never>?
    private lazy var englishCompletions = EnglishWordCompletions()
    private var previousSwitchRequirement: Bool?
    private var currentReturnKey: UIReturnKeyType?

    override func viewDidLoad() {
        super.viewDidLoad()
        board.translatesAutoresizingMaskIntoConstraints = false
        board.layer.cornerCurve = .continuous
        board.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        board.clipsToBounds = true
        view.addSubview(board)
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
        let top = keyArea.topAnchor.constraint(equalTo: board.topAnchor, constant: contentTopInset)
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
        let size = view.heightAnchor.constraint(equalToConstant: 275 + contentTopInset)
        size.priority = UILayoutPriority(999)
        size.isActive = true
        height = size
        rows.axis = .vertical
        rows.distribution = .fillEqually
        rows.spacing = 5
        toolbar.spacing = 3
        candidates.distribution = .fillEqually
        let brand = UIView()
        let mark = UIImageView(image: UIImage(named: "MBoardMark"))
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.layer.cornerRadius = 6
        mark.layer.cornerCurve = .continuous
        mark.clipsToBounds = true
        brand.isUserInteractionEnabled = false
        brand.addSubview(mark)
        toolbar.addArrangedSubview(brand)
        toolbar.addArrangedSubview(candidates)
        toolbar.addArrangedSubview(settingsButton)
        NSLayoutConstraint.activate([
            brand.widthAnchor.constraint(equalToConstant: 36),
            mark.centerXAnchor.constraint(equalTo: brand.centerXAnchor),
            mark.centerYAnchor.constraint(equalTo: brand.centerYAnchor),
            mark.widthAnchor.constraint(equalToConstant: 27),
            mark.heightAnchor.constraint(equalTo: mark.widthAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 36)
        ])
        let gearSize = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        settingsButton.setImage(UIImage(systemName: "gearshape", withConfiguration: gearSize), for: .normal)
        settingsButton.tintColor = KeyColors.ink
        settingsButton.accessibilityLabel = "MBoard Keyboard Settings"
        settingsButton.showsMenuAsPrimaryAction = true
        primaryLanguage = language.rawValue
        configureAppearance()
        configureSettingsMenu()
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        manualShiftContext = nil
        updateEnglishShift()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateKeyboardHeight()
        if previousSwitchRequirement != needsInputModeSwitchKey { rebuild() }
    }

    private func updateKeyboardHeight() {
        let compact = traitCollection.verticalSizeClass == .compact
        let contentHeight: CGFloat = compact ? 199 : 275
        var panelHeight: CGFloat = 0
        if let emojiPicker, emojiPicker.isSearching {
            panelHeight = emojiPicker.showsResults ? (compact ? 92 : 140) : 42
        }
        height?.constant = contentTopInset + contentHeight + panelHeight
        keyAreaTop?.constant = contentTopInset + panelHeight
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        doubleSpace = DoubleSpaceShortcut()
        typedOnSymbols = false
        closeEmoji()
        finishComposition()
        cancelGestures()
        lookup?.cancel()
    }

    private func configureAppearance() {
        let usesSystemBackground = appearance == "System"
        background.isHidden = usesSystemBackground
        board.layer.cornerRadius = usesSystemBackground ? 0 : 12
        emojiPicker?.usesSystemBackground = usesSystemBackground
        switch appearance {
        case "Dark": board.overrideUserInterfaceStyle = .dark
        case "Light": board.overrideUserInterfaceStyle = .light
        default:
            // UIKit updates the input view's traits for both the host field and live theme changes.
            board.overrideUserInterfaceStyle = .unspecified
        }
    }

    private func configureSettingsMenu() {
        let appearanceMenu = UIMenu(title: "Appearance", options: .displayInline, children: ["System","Light","Dark"].map { choice in
            UIAction(title: choice, state: choice == appearance ? .on : .off) { [weak self] _ in
                self?.appearance = choice
                UserDefaults.standard.set(choice, forKey: "appearance")
                self?.configureAppearance()
                self?.configureSettingsMenu()
            }
        })
        let capitalization = UIAction(title: "Auto-Capitalization", state: autoCapitalize ? .on : .off) { [weak self] _ in
            guard let self else { return }
            autoCapitalize.toggle()
            UserDefaults.standard.set(autoCapitalize, forKey: "autoCapitalize")
            manualShiftContext = nil
            updateEnglishShift()
            configureSettingsMenu()
        }
        let suggestions = UIAction(title: "Word Suggestions", state: wordSuggestions ? .on : .off) { [weak self] _ in
            guard let self else { return }
            wordSuggestions.toggle()
            UserDefaults.standard.set(wordSuggestions, forKey: "wordSuggestions")
            updateSuggestions()
            configureSettingsMenu()
        }
        let clear = UIAction(title: "Clear for Both Languages", attributes: .destructive) { [weak self] _ in
            LearnedWordStore.shared.clear()
            self?.updateSuggestions()
        }
        let learned = UIMenu(title: "Clear Learned Words", children: [clear])
        settingsButton.menu = UIMenu(children: [UIMenu(title: "Typing", options: .displayInline,
                                                      children: [capitalization, suggestions, learned]), appearanceMenu])
    }

    private func englishShift(for context: HostContext) -> Bool {
        if manualShiftContext == context { return shift }
        manualShiftContext = nil
        guard autoCapitalize, !isSearchingEmoji else { return false }
        let proxy = textDocumentProxy
        switch proxy.keyboardType {
        case .emailAddress, .URL, .numberPad, .decimalPad, .phonePad: return false
        default: break
        }
        let mode: EnglishCapitalization
        switch proxy.autocapitalizationType {
        case .some(.none): mode = .none
        case .words: mode = .words
        case .allCharacters: mode = .allCharacters
        default: mode = .sentences
        }
        return mode.shouldShift(before: context.before ?? "", after: context.after ?? "")
    }

    private func updateEnglishShift() {
        guard isViewLoaded, language == .english, symbolPage == nil, repeatingDelete == nil else { return }
        let wanted = englishShift(for: HostContext(textDocumentProxy))
        if shift != wanted { shift = wanted; refreshEnglishCase() }
    }

    private func switchLanguage() {
        if isSearchingEmoji { emojiPicker?.commitQueryComposition() }
        else { finishComposition() }
        doubleSpace = DoubleSpaceShortcut()
        typedOnSymbols = false
        language = language == .burmese ? .english : .burmese
        primaryLanguage = language.rawValue
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        manualShiftContext = nil
        symbolPage = nil
        shift = language == .english && englishShift(for: HostContext(textDocumentProxy))
        rebuild()
        updateSuggestions()
    }

    private func cancelGestures() {
        keyPopup.dismiss()
        repeatingDelete?.invalidate()
        repeatingDelete = nil
    }

    private func command(_ title: String, symbol: String? = nil, action: @escaping () -> Void) -> KeyButton {
        let button = KeyButton(title: title, symbol: symbol, modifier: true)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func letterButton(_ letter: LetterKey) -> KeyButton {
        let button = KeyButton(title: LetterKey.label(for: letter.text), hint: letter.hint)
        configureLetter(button, letter)
        button.addTarget(self, action: #selector(showPreview(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(releasePreview(_:)), for: [.touchDragExit, .touchUpInside, .touchUpOutside, .touchCancel])
        button.addTarget(self, action: #selector(tapLetter(_:)), for: .touchUpInside)
        if !letter.alternatives.isEmpty {
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(holdLetter(_:)))
            hold.minimumPressDuration = 0.35
            button.addGestureRecognizer(hold)
        }
        return button
    }

    private func configureLetter(_ button: KeyButton, _ letter: LetterKey) {
        button.letter = letter
        let label = LetterKey.label(for: letter.text)
        if button.currentTitle != label { button.setTitle(label, for: .normal) }
        button.accessibilityLabel = label
        button.accessibilityIdentifier = "key." + letter.text
        button.accessibilityCustomActions = letter.alternatives.map { value in
            UIAccessibilityCustomAction(name: LetterKey.label(for: value)) { [weak self] _ in self?.insert(value); return true }
        }
    }

    @objc private func tapLetter(_ button: KeyButton) {
        if let letter = button.letter { insert(letter.text) }
    }

    private func refreshEnglishCase() {
        guard let englishShiftButton else { rebuild(); return }
        keyPopup.dismiss()
        let letters = KeyboardLayout.letters(.english, shift: shift).joined()
        for (button, letter) in zip(englishLetters, letters) { configureLetter(button, letter) }
        englishShiftButton.setImage(UIImage(systemName: shift ? "shift.fill" : "shift"), for: .normal)
        englishShiftButton.accessibilityValue = shift ? "On" : "Off"
    }

    @objc private func showPreview(_ key: KeyButton) {
        guard !keyPopup.isChoosingAlternate, let title = key.currentTitle else { return }
        keyPopup.show([title], for: key, in: board)
    }

    @objc private func releasePreview(_ key: KeyButton) {
        keyPopup.release(key)
    }

    @objc private func holdLetter(_ gesture: UILongPressGestureRecognizer) {
        guard let key = gesture.view as? KeyButton, let letter = key.letter else { return }
        let point = gesture.location(in: board)
        switch gesture.state {
        case .began:
            cancelGestures()
            keyPopup.show(letter.alternatives, for: key, in: board, defaultIndex: letter.defaultIndex, start: point)
        case .changed: keyPopup.track(point)
        case .ended:
            keyPopup.track(point)
            let value = keyPopup.selectedAlternate
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
            repeatingDelete = Timer.scheduledTimer(withTimeInterval: 0.085, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.backspace() }
            }
            backspace()
        case .ended, .cancelled, .failed:
            cancelGestures()
            updateEnglishShift()
        default: break
        }
    }

    private func rebuild() {
        cancelGestures()
        englishLetters.removeAll(keepingCapacity: true)
        englishShiftButton = nil
        previousSwitchRequirement = needsInputModeSwitchKey
        currentReturnKey = textDocumentProxy.returnKeyType
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let digitsLabel = language == .burmese ? "၁၂၃" : "123"
        let letterRows = symbolPage.map { KeyboardLayout.symbols(language, second: $0 == 2) }
            ?? KeyboardLayout.letters(language, shift: shift)
        for (i, letters) in letterRows.enumerated() {
            var buttons = letters.map(letterButton)
            if language == .english && symbolPage == nil { englishLetters.append(contentsOf: buttons) }
            if i == letterRows.count - 1 {
                let toggle: KeyButton
                if let page = symbolPage {
                    toggle = command(page == 1 ? "=\\<" : digitsLabel) { [weak self] in
                        self?.doubleSpace = DoubleSpaceShortcut()
                        self?.symbolPage = page == 1 ? 2 : 1
                        self?.rebuild()
                    }
                } else {
                    toggle = command("Shift", symbol: shift ? "shift.fill" : "shift") { [weak self] in
                        guard let self else { return }
                        doubleSpace = DoubleSpaceShortcut()
                        shift.toggle()
                        if language == .english {
                            manualShiftContext = HostContext(textDocumentProxy)
                            refreshEnglishCase()
                        } else { rebuild() }
                    }
                    if language == .english { englishShiftButton = toggle }
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
        let symbols = command(symbolPage == nil ? digitsLabel :
                                (language == .burmese ? "ကခ" : "ABC")) { [weak self] in
            guard let self else { return }
            if self.isSearchingEmoji { self.emojiPicker?.commitQueryComposition() }
            else { self.finishComposition() }
            self.doubleSpace = DoubleSpaceShortcut()
            self.typedOnSymbols = false
            self.symbolPage = self.symbolPage == nil ? 1 : nil
            self.manualShiftContext = nil
            self.shift = self.language == .english && self.symbolPage == nil && self.englishShift(for: HostContext(self.textDocumentProxy))
            self.rebuild()
        }
        symbols.accessibilityLabel = symbolPage == nil ? "Show symbols" : "Show letters"
        let languages = command(language == .burmese ? "abc" : "ကခ") { [weak self] in self?.switchLanguage() }
        languages.accessibilityLabel = language == .burmese ? "Switch to English" : "Switch to Burmese"
        bottom.addArrangedSubview(languages)
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
        let space = command(language.title) { [weak self] in self?.tapSpace() }
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
            let fraction: CGFloat
            switch button {
            case enter: fraction = 0.14
            case symbols: fraction = 0.11
            default: fraction = 0.09
            }
            button.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: fraction).isActive = true
        }
    }

    private func openEmoji() {
        doubleSpace = DoubleSpaceShortcut()
        finishComposition()
        cancelGestures()
        guard emojiPicker == nil else { return }
        let picker = EmojiPicker(recent: recentEmoji, usesSystemBackground: appearance == "System",
                                 topInset: contentTopInset)
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
        updateSuggestions()
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
            manualShiftContext = nil
            symbolPage = nil
            shift = language == .english && englishShift(for: HostContext(textDocumentProxy))
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
            manualShiftContext = nil
            symbolPage = nil
            shift = language == .english && englishShift(for: HostContext(textDocumentProxy))
            rebuild()
        }
        updateKeyboardHeight()
        updateSuggestions()
    }

    private func finishComposition() {
        editor.finish(in: editHost)
    }

    private func insert(_ value: String) {
        doubleSpace = DoubleSpaceShortcut()
        if symbolPage != nil { typedOnSymbols = true }
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
        editor.type(value, in: editHost)
        didType()
    }

    private func tapSpace() {
        if isSearchingEmoji {
            emojiPicker?.appendToQuery(" ")
        } else {
            finishComposition()
            let proxy = textDocumentProxy
            if let separator = doubleSpace.separator(for: language, at: HostContext(proxy)) {
                proxy.deleteBackward()
                proxy.insertText(separator)
            } else {
                proxy.insertText(" ")
            }
        }
        returnToLettersAfterSeparator()
        didType()
    }

    private func returnToLettersAfterSeparator() {
        guard symbolPage != nil, typedOnSymbols else { return }
        symbolPage = nil
        typedOnSymbols = false
        manualShiftContext = nil
        shift = language == .english && englishShift(for: HostContext(textDocumentProxy))
        rebuild()
    }

    private func insertLiteral(_ value: String) {
        if isSearchingEmoji {
            if value == "\n" { emojiPicker?.confirmSearch() }
            else { emojiPicker?.appendToQuery(value) }
            didType()
            return
        }
        insertHostText(value)
        if value == "\n" { returnToLettersAfterSeparator() }
    }

    private func insertHostText(_ value: String) {
        doubleSpace = DoubleSpaceShortcut()
        finishComposition()
        textDocumentProxy.insertText(value)
        didType()
    }

    private func didType() {
        manualShiftContext = nil
        if language == .english { updateEnglishShift() }
        else if shift {
            shift = false
            rebuild()
        }
        updateSuggestions()
    }

    private func backspace() {
        doubleSpace = DoubleSpaceShortcut()
        if isSearchingEmoji {
            emojiPicker?.deleteQueryCharacter()
            return
        }
        deleteFromHost()
    }

    private func deleteFromHost() {
        manualShiftContext = nil
        editor.backspace(in: editHost)
        updateEnglishShift()
        updateSuggestions()
    }

    private var suggestionContext: HostContext {
        editor.contextForSuggestions(HostContext(textDocumentProxy))
    }

    private func updateSuggestions() {
        lookup?.cancel()
        candidates.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard wordSuggestions, emojiPicker == nil else { return }
        let context = suggestionContext
        guard context.document != nil, context.selection?.isEmpty != false else { return }
        guard let before = context.before, !before.isEmpty else { return }
        let mode = language
        guard mode != .english || !Completions.continuesEnglishWord(context.after) else { return }
        let allCaps = autoCapitalize && textDocumentProxy.autocapitalizationType == .allCharacters
        lookup = Task { [weak self] in
            // UIKit isolates UITextChecker to the main actor. Wait for a pause
            // before asking it, and never call it from the key's insertion action.
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            let recent = String(before.unicodeScalars.suffix(96))
            let learned = await LearnedWordStore.shared.ranked(for: mode)
            guard !Task.isCancelled, let self else { return }
            let apple = mode == .english ? englishCompletions.words(for: Completions.englishPrefix(in: recent)) : []
            let results = await Task.detached(priority: .utility) {
                Completions.matches(before: recent, after: context.after, language: mode, apple: apple, learned: learned, allCaps: allCaps)
            }.value
            guard !Task.isCancelled, self.wordSuggestions, self.emojiPicker == nil, self.language == mode,
                  self.suggestionContext == context else { return }
            for candidate in results {
                let button = UIButton(type: .system)
                button.accessibilityIdentifier = "completion." + candidate.title
                button.setTitle(candidate.title, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 14)
                button.titleLabel?.adjustsFontSizeToFitWidth = true
                button.tintColor = KeyColors.ink
                button.addAction(UIAction { [weak self] _ in
                    guard let self, self.wordSuggestions, self.emojiPicker == nil, self.language == mode,
                          self.suggestionContext == context else { return }
                    LearnedWordStore.shared.record(candidate.title, language: mode)
                    self.insertHostText(candidate.suffix)
                }, for: .touchUpInside)
                if candidate.learned {
                    let forget = UIAction(title: "Forget This Suggestion", attributes: .destructive) { [weak self] _ in
                        LearnedWordStore.shared.forget(candidate.title, language: mode)
                        self?.updateSuggestions()
                    }
                    button.menu = UIMenu(children: [forget])
                }
                self.candidates.addArrangedSubview(button)
            }
        }
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        let context = HostContext(textDocumentProxy)
        doubleSpace.selectionChanged(to: context)
        editor.check(context, in: editHost)
        updateEnglishShift()
        updateSuggestions()
    }
    override func textDidChange(_ textInput: UITextInput?) {
        guard isViewLoaded else { return }
        editor.check(HostContext(textDocumentProxy), in: editHost)
        updateEnglishShift()
        if currentReturnKey != textDocumentProxy.returnKeyType { rebuild() }
        updateSuggestions()
    }
}
