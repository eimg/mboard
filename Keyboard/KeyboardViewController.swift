import UIKit

extension UITextInputTraits {
    var permitsPersonalSuggestions: Bool {
        guard isSecureTextEntry != true else { return false }
        switch keyboardType {
        case .emailAddress, .URL, .phonePad, .namePhonePad, .numberPad, .decimalPad, .asciiCapableNumberPad: return false
        default: break
        }
        if #available(iOS 17.0, *) {
            switch textContentType {
            case .creditCardSecurityCode, .creditCardExpiration, .creditCardExpirationMonth, .creditCardExpirationYear,
                 .creditCardName, .creditCardGivenName, .creditCardMiddleName, .creditCardFamilyName: return false
            default: break
            }
        }
        switch textContentType {
        case .username, .password, .newPassword, .oneTimeCode, .creditCardNumber, .emailAddress, .URL, .telephoneNumber:
            return false
        default: return true
        }
    }
}

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

    func guesses(for word: String) -> [String] {
        guard word.count >= 3, let language else { return [] }
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
                                                       wrap: false, language: language)
        guard misspelled == range else { return [] }
        return Array((checker.guesses(forWordRange: range, in: word, language: language) ?? []).prefix(12))
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

private final class SuggestionButton: UIButton {
    var visualInsets = UIEdgeInsets.zero

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel?.center.y = bounds.inset(by: visualInsets).midY
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
    private weak var highlightedSuggestion: UIButton?
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
    private var capsLockDocument: UUID?
    private var cursorDrag: SpacebarCursorDrag?
    private var doubleSpace = DoubleSpaceShortcut()
    private var deferredSpace = DeferredEnglishSpace()
    private var typingHistory = EnglishTypingHistory()
    private var settleWord: Task<Void, Never>?
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
    private struct SuggestionRequest: Equatable {
        let context: HostContext
        let language: Language
        let allCaps: Bool
    }
    private var suggestionRequest: SuggestionRequest?
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
        for _ in 0..<3 { candidates.addArrangedSubview(UIView()) }
        let brand = UIView()
        let mark = UIImageView(image: UIImage(named: "MBoardMark"))
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.layer.cornerRadius = 6
        mark.layer.cornerCurve = .continuous
        mark.clipsToBounds = true
        brand.isUserInteractionEnabled = false
        brand.addSubview(mark)
        toolbar.addArrangedSubview(brand)
        // The toolbar spacer fixes the label columns. The actual buttons include the
        // empty strips above and below the bar, up to the first row of typing keys.
        let suggestionSlot = UIView()
        suggestionSlot.isUserInteractionEnabled = false
        toolbar.addArrangedSubview(suggestionSlot)
        toolbar.addArrangedSubview(settingsButton)
        candidates.translatesAutoresizingMaskIntoConstraints = false
        candidates.isHidden = true
        board.addSubview(candidates)
        NSLayoutConstraint.activate([
            candidates.leadingAnchor.constraint(equalTo: suggestionSlot.leadingAnchor),
            candidates.trailingAnchor.constraint(equalTo: suggestionSlot.trailingAnchor),
            candidates.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: -contentTopInset),
            candidates.bottomAnchor.constraint(equalTo: rows.topAnchor),
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
        updateSuggestions()
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
        finishTypingHistory()
        capsLockDocument = nil
        deferredSpace = DeferredEnglishSpace()
        doubleSpace = DoubleSpaceShortcut()
        typedOnSymbols = false
        closeEmoji()
        finishComposition()
        cancelGestures()
        clearSuggestions()
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
            updateSuggestions()
            configureSettingsMenu()
        }
        let suggestions = UIAction(title: "Word Suggestions", state: wordSuggestions ? .on : .off) { [weak self] _ in
            guard let self else { return }
            wordSuggestions.toggle()
            typingHistory = EnglishTypingHistory()
            deferredSpace = DeferredEnglishSpace()
            UserDefaults.standard.set(wordSuggestions, forKey: "wordSuggestions")
            updateSuggestions()
            configureSettingsMenu()
        }
        let clear = UIAction(title: "Clear for Both Languages", attributes: .destructive) { [weak self] _ in
            self?.typingHistory = EnglishTypingHistory()
            LearnedWordStore.shared.clear()
            self?.updateSuggestions(force: true)
        }
        let learned = UIMenu(title: "Clear Learned Words", children: [clear])
        settingsButton.menu = UIMenu(children: [UIMenu(title: "Typing", options: .displayInline,
                                                      children: [capitalization, suggestions, learned]), appearanceMenu])
    }

    private func englishShift(for context: HostContext) -> Bool {
        if let capsLockDocument {
            if capsLockDocument == context.document { return true }
            self.capsLockDocument = nil
        }
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
        let boundary = deferredSpace.applies(at: context) ? " " : ""
        return mode.shouldShift(before: (context.before ?? "") + boundary, after: context.after ?? "")
    }

    private func updateEnglishShift() {
        guard isViewLoaded, language == .english, symbolPage == nil, repeatingDelete == nil, cursorDrag == nil else { return }
        let wanted = englishShift(for: HostContext(textDocumentProxy))
        if shift != wanted {
            shift = wanted
            refreshEnglishCase()
        } else if englishShiftButton?.accessibilityValue != shiftValue {
            updateShiftButton()
        }
    }

    private func switchLanguage() {
        finishTypingHistory()
        capsLockDocument = nil
        deferredSpace = DeferredEnglishSpace()
        if isSearchingEmoji { emojiPicker?.commitQueryComposition() }
        else { finishComposition() }
        doubleSpace = DoubleSpaceShortcut()
        typedOnSymbols = false
        language = language == .burmese ? .english : .burmese
        emojiPicker?.setReturnLanguage(language)
        primaryLanguage = language.rawValue
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        manualShiftContext = nil
        symbolPage = nil
        shift = language == .english && englishShift(for: HostContext(textDocumentProxy))
        rebuild()
        updateSuggestions()
    }

    private func cancelGestures() {
        highlightedSuggestion?.removeFromSuperview()
        cursorDrag = nil
        rows.alpha = 1
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
        guard englishShiftButton != nil else { rebuild(); return }
        keyPopup.dismiss()
        let letters = KeyboardLayout.letters(.english, shift: shift).joined()
        for (button, letter) in zip(englishLetters, letters) { configureLetter(button, letter) }
        updateShiftButton()
    }

    private var shiftSymbol: String {
        if capsLockDocument != nil { return "capslock.fill" }
        return shift ? "shift.fill" : "shift"
    }

    private var shiftValue: String {
        if capsLockDocument != nil { return "Caps Lock" }
        return shift ? "On" : "Off"
    }

    private func updateShiftButton() {
        englishShiftButton?.setImage(UIImage(systemName: shiftSymbol), for: .normal)
        englishShiftButton?.accessibilityValue = shiftValue
    }

    @objc private func tapEnglishShift(_ button: KeyButton, event: UIEvent?) {
        // UIKit counts consecutive taps on this key. A single tap takes effect immediately.
        let taps = event?.touches(for: button)?.first?.tapCount ?? 1
        setEnglishShift(lock: taps == 2 && capsLockDocument == nil)
    }

    private func setEnglishShift(lock: Bool) {
        let context = HostContext(textDocumentProxy)
        doubleSpace = DoubleSpaceShortcut()
        capsLockDocument = lock ? context.document : nil
        shift = capsLockDocument != nil || !shift
        manualShiftContext = context
        refreshEnglishCase()
        updateSuggestions()
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
                } else if language == .english {
                    toggle = KeyButton(title: "Shift", symbol: shiftSymbol, modifier: true)
                    toggle.addTarget(self, action: #selector(tapEnglishShift(_:event:)), for: .touchUpInside)
                    toggle.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Toggle Caps Lock") { [weak self] _ in
                        guard let self else { return false }
                        self.setEnglishShift(lock: self.capsLockDocument == nil)
                        return true
                    }]
                    toggle.accessibilityValue = shiftValue
                    englishShiftButton = toggle
                } else {
                    toggle = command("Shift", symbol: shift ? "shift.fill" : "shift") { [weak self] in
                        guard let self else { return }
                        doubleSpace = DoubleSpaceShortcut()
                        shift.toggle()
                        rebuild()
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
        let symbols = command(symbolPage == nil ? digitsLabel :
                                (language == .burmese ? "ကခ" : "ABC")) { [weak self] in
            guard let self else { return }
            if self.isSearchingEmoji { self.emojiPicker?.commitQueryComposition() }
            else { self.finishComposition() }
            self.doubleSpace = DoubleSpaceShortcut()
            self.typedOnSymbols = false
            self.symbolPage = self.symbolPage == nil ? 1 : nil
            self.deferredSpace = DeferredEnglishSpace()
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
        if !isSearchingEmoji {
            space.accessibilityHint = "Hold and drag left or right to move the cursor."
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(holdSpace(_:)))
            hold.minimumPressDuration = 0.35
            space.addGestureRecognizer(hold)
        }
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
        finishTypingHistory()
        deferredSpace = DeferredEnglishSpace()
        doubleSpace = DoubleSpaceShortcut()
        finishComposition()
        cancelGestures()
        guard emojiPicker == nil else { return }
        let picker = EmojiPicker(recent: recentEmoji, language: language, usesSystemBackground: appearance == "System",
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
            capsLockDocument = nil
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
            capsLockDocument = nil
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
        if allowsAutomaticWordSpacing, language.needsWordSpace(before: value, at: suggestionContext) {
            // Commit the separator outside the Burmese marked syllable.
            finishComposition()
            _ = capitalizePronoun(before: " ", at: editHost.context)
            editHost.insert(" ")
        }
        editor.type(value, in: editHost)
        didType()
    }

    @objc private func holdSpace(_ gesture: UILongPressGestureRecognizer) {
        let x = gesture.location(in: board).x
        switch gesture.state {
        case .began:
            guard !isSearchingEmoji, let document = HostContext.identifier(textDocumentProxy) else { return }
            finishTypingHistory()
            cancelGestures()
            deferredSpace = DeferredEnglishSpace()
            doubleSpace = DoubleSpaceShortcut()
            manualShiftContext = nil
            finishComposition()
            cursorDrag = SpacebarCursorDrag(document: document, x: x)
            rows.alpha = 0.65
            updateSuggestions()
        case .changed, .ended:
            guard cursorDrag != nil else { return }
            let context = HostContext(textDocumentProxy)
            if cursorDrag?.document == context.document {
                let delta = cursorDrag?.offset(to: x, in: context) ?? 0
                if delta != 0 { editHost.moveCaret(byUTF16: delta) }
                if gesture.state == .changed { return }
            }
            finishCursorDrag()
        case .cancelled, .failed:
            if cursorDrag != nil { finishCursorDrag() }
        default: break
        }
    }

    private func finishCursorDrag() {
        cancelGestures()
        updateEnglishShift()
        updateSuggestions()
    }

    private func tapSpace() {
        deferredSpace = DeferredEnglishSpace()
        if isSearchingEmoji {
            emojiPicker?.appendToQuery(" ")
        } else {
            finishComposition()
            let proxy = textDocumentProxy
            let before = capitalizePronoun(before: " ", at: HostContext(proxy))
            if let separator = doubleSpace.separator(for: language, at: before) {
                typingHistory.observe(before)
                finishTypingHistory()
                proxy.deleteBackward()
                proxy.insertText(separator)
            } else {
                insertAndObserve(" ", at: before)
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
        insertHostText(value, applyingWordSpacing: symbolPage == nil)
        if value == "\n" { returnToLettersAfterSeparator() }
    }

    private var allowsAutomaticWordSpacing: Bool {
        allowsEnglishWordEdits && textDocumentProxy.permitsPersonalSuggestions
    }

    private func capitalizePronoun(before input: String, at context: HostContext) -> HostContext {
        guard autoCapitalize, context.before?.last == "i", allowsAutomaticWordSpacing,
              textDocumentProxy.autocapitalizationType != .some(.none),
              let pronoun = EnglishToken.standalonePronoun(at: context, before: input) else { return context }
        _ = pronoun.replace(with: "I", at: context, in: editHost)
        return editHost.context
    }

    private func insertHostText(_ value: String, applyingWordSpacing: Bool = false) {
        doubleSpace = DoubleSpaceShortcut()
        finishComposition()
        let context = HostContext(textDocumentProxy)
        let addSpace = applyingWordSpacing && allowsAutomaticWordSpacing &&
            (language.needsWordSpace(before: value, at: context) ||
             (language == .english && deferredSpace.consume(before: value, at: context)))
        deferredSpace = DeferredEnglishSpace()
        let insertion = addSpace ? " " + value : value
        insertAndObserve(insertion, at: capitalizePronoun(before: insertion, at: context))
        didType()
    }

    private var learnsEnglish: Bool {
        wordSuggestions && language == .english && emojiPicker == nil && allowsEnglishWordEdits
            && textDocumentProxy.permitsPersonalSuggestions
    }

    private func persist(_ entry: EnglishTypingHistory.Entry?) {
        guard let entry else { return }
        LearnedWordStore.shared.record(entry.word, language: .english, previous: entry.previous,
                                       typed: true, intentionalCase: entry.intentionalCase)
    }

    private func finishTypingHistory() {
        settleWord?.cancel()
        persist(typingHistory.finish())
    }

    private func insertAndObserve(_ value: String, at before: HostContext) {
        guard learnsEnglish else {
            typingHistory = EnglishTypingHistory()
            textDocumentProxy.insertText(value)
            return
        }
        let automatic = shift && manualShiftContext == nil && capsLockDocument == nil
        textDocumentProxy.insertText(value)
        let after = HostContext(textDocumentProxy)
        persist(typingHistory.inserted(value, from: before, to: after, automaticInitial: automatic))
        settleWord?.cancel()
        if typingHistory.awaitsSettlement {
            settleWord = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled, let self, self.learnsEnglish else { return }
                self.persist(self.typingHistory.settled(at: HostContext(self.textDocumentProxy)))
            }
        }
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
        deferredSpace = DeferredEnglishSpace()
        manualShiftContext = nil
        let before = learnsEnglish ? HostContext(textDocumentProxy) : nil
        editor.backspace(in: editHost)
        if let before { typingHistory.deleted(from: before, to: HostContext(textDocumentProxy)) }
        updateEnglishShift()
        updateSuggestions()
    }

    private var suggestionContext: HostContext {
        editor.contextForSuggestions(HostContext(textDocumentProxy))
    }

    private var allowsEnglishWordEdits: Bool {
        switch textDocumentProxy.keyboardType {
        case nil, .default, .asciiCapable, .webSearch: return true
        default: return false
        }
    }

    private func accept(_ candidate: Completion, context: HostContext, from button: UIButton) {
        // Updating the editor can immediately remove the tapped button.
        let slot = button.convert(button.bounds, to: board)
        deferredSpace = DeferredEnglishSpace()
        doubleSpace = DoubleSpaceShortcut()
        finishComposition()
        switch candidate.action {
        case .keep:
            guard HostContext(textDocumentProxy) == context else { return }
        case .append:
            textDocumentProxy.insertText(candidate.suffix)
        case .selection:
            guard HostContext(textDocumentProxy) == context else { return }
            textDocumentProxy.insertText(candidate.title)
        case .replace(let token):
            guard token.replace(with: candidate.title, at: context, in: editHost) else {
                updateSuggestions()
                return
            }
        }
        let result = HostContext(textDocumentProxy)
        let accepted = candidate.confirmed(from: context, to: result)
        if accepted {
            if !candidate.title.contains(" "), language == .burmese || learnsEnglish {
                let previous = language == .english ? typingHistory.accepted(candidate.title, from: context, to: result) : nil
                LearnedWordStore.shared.record(candidate.title, language: language, previous: previous)
            } else {
                typingHistory = EnglishTypingHistory()
            }
            if language == .english, allowsEnglishWordEdits, symbolPage == nil {
                deferredSpace.remember(result, accepted: candidate.title)
            }
        }
        didType()
        if accepted { highlightAcceptedSuggestion(button, in: slot) }
    }

    private func highlightAcceptedSuggestion(_ button: UIButton, in slot: CGRect) {
        guard !slot.isEmpty, let label = button.titleLabel else { return }
        highlightedSuggestion?.removeFromSuperview()
        // Reuse the tapped button so even a fitted, long title keeps its exact geometry.
        button.translatesAutoresizingMaskIntoConstraints = true
        button.autoresizingMask = []
        button.frame = slot
        button.isUserInteractionEnabled = false
        button.isAccessibilityElement = false
        button.accessibilityElementsHidden = true
        board.addSubview(button)
        button.layoutIfNeeded()
        let fill = UIView(frame: label.frame.insetBy(dx: -7, dy: -2).intersection(button.bounds))
        fill.backgroundColor = .secondarySystemFill
        fill.layer.cornerRadius = 5
        fill.layer.cornerCurve = .continuous
        button.insertSubview(fill, at: 0)
        highlightedSuggestion = button
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak button] in
            button?.removeFromSuperview()
        }
    }

    private func clearSuggestions() {
        lookup?.cancel()
        lookup = nil
        suggestionRequest = nil
        candidates.isHidden = true
        for slot in candidates.arrangedSubviews {
            slot.subviews.forEach { $0.removeFromSuperview() }
        }
    }

    private func updateSuggestions(force: Bool = false) {
        guard textDocumentProxy.permitsPersonalSuggestions else {
            typingHistory = EnglishTypingHistory()
            deferredSpace = DeferredEnglishSpace()
            clearSuggestions()
            return
        }
        guard wordSuggestions, emojiPicker == nil, cursorDrag == nil else { clearSuggestions(); return }
        let context = suggestionContext
        let mode = language
        let allCaps = (capsLockDocument != nil && capsLockDocument == context.document)
            || (autoCapitalize && textDocumentProxy.autocapitalizationType == .allCharacters)
        guard context.document != nil,
              mode != .english || (allowsEnglishWordEdits && !deferredSpace.applies(at: context))
        else { clearSuggestions(); return }
        let request = SuggestionRequest(context: context, language: mode, allCaps: allCaps)
        // UIKit often reports the same edit through multiple delegate callbacks.
        // Keep the visible controls and any touch or menu they're already tracking.
        guard force || request != suggestionRequest else { return }
        clearSuggestions()
        suggestionRequest = request
        let before = context.before ?? "", after = context.after ?? ""
        let selected = context.selection ?? ""
        let token = mode == .english ? EnglishToken(before: before, after: after) : nil
        if mode == .english {
            guard token != nil, selected.isEmpty else { return }
        } else if before.isEmpty && selected.isEmpty { return }
        let immediate = token.flatMap { Completions.joinedPhrase(for: $0, allCaps: allCaps) }
        if let immediate { addSuggestion(immediate, context: context, language: mode) }
        lookup = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            let ranking = await LearnedWordStore.shared.ranking(for: mode, previous: token?.previousWord(in: before))
            let learned = ranking.words
            guard !Task.isCancelled, let self else { return }
            let apple = token.flatMap { $0.right.isEmpty ? self.englishCompletions.words(for: $0.left) : nil } ?? []
            let guesses = token.map { self.englishCompletions.guesses(for: $0.word) } ?? []
            let results = await Task.detached(priority: .utility) {
                if let token {
                    return Completions.englishSuggestions(token, apple: apple, guesses: guesses,
                                                          learned: learned, allCaps: allCaps, personalCase: ranking.personalCase)
                }
                if !selected.isEmpty { return Completions.selectedBurmese(selected, learned: learned) }
                return Completions.matches(before: String(before.unicodeScalars.suffix(96)),
                                           after: after, language: mode, learned: learned)
            }.value
            guard !Task.isCancelled, self.suggestionRequest == request, self.suggestionContext == context,
                  self.textDocumentProxy.permitsPersonalSuggestions else { return }
            let additional = results.filter { $0 != immediate }
            guard !additional.isEmpty else { return }
            for candidate in additional { self.addSuggestion(candidate, context: context, language: mode) }
        }
    }

    private func addSuggestion(_ candidate: Completion, context: HostContext, language mode: Language) {
        let button = SuggestionButton(type: .system)
        // In System appearance, fully transparent pixels can pass through the
        // remote keyboard surface before UIKit hit-tests this button.
        button.backgroundColor = UIColor(white: 0.5, alpha: 0.015)
        button.visualInsets = UIEdgeInsets(top: contentTopInset, left: 0, bottom: keyArea.spacing, right: 0)
        button.accessibilityIdentifier = "completion." + candidate.title
        button.setTitle(candidate.title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: mode == .burmese ? 16 : 17)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.tintColor = KeyColors.ink
        button.addAction(UIAction { [weak self, weak button] _ in
            guard let self, let button, self.wordSuggestions, self.emojiPicker == nil, self.language == mode,
                  self.textDocumentProxy.permitsPersonalSuggestions,
                  self.suggestionContext == context else { return }
            self.accept(candidate, context: context, from: button)
        }, for: .touchUpInside)
        if candidate.learned {
            let forget = UIAction(title: "Forget This Suggestion", attributes: .destructive) { [weak self] _ in
                self?.typingHistory = EnglishTypingHistory()
                LearnedWordStore.shared.forget(candidate.title, language: mode)
                self?.updateSuggestions(force: true)
            }
            button.menu = UIMenu(children: [forget])
        }
        // A later result must never move the suggestion already under a finger.
        guard let slot = [1, 0, 2].map({ candidates.arrangedSubviews[$0] }).first(where: { $0.subviews.isEmpty })
        else { return }
        button.frame = slot.bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        slot.addSubview(button)
        candidates.isHidden = false
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        let context = HostContext(textDocumentProxy)
        typingHistory.observe(context)
        deferredSpace.observe(context)
        doubleSpace.selectionChanged(to: context)
        editor.check(context, in: editHost)
        updateEnglishShift()
        updateSuggestions()
    }
    override func textDidChange(_ textInput: UITextInput?) {
        guard isViewLoaded else { return }
        let context = HostContext(textDocumentProxy)
        typingHistory.observe(context)
        deferredSpace.observe(context)
        editor.check(context, in: editHost)
        updateEnglishShift()
        if currentReturnKey != textDocumentProxy.returnKeyType { rebuild() }
        updateSuggestions()
    }
}
