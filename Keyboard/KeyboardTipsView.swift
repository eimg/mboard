import UIKit

/// Read-only help stays inside the extension and never edits the host document.
final class KeyboardTipsView: UIView {
    var onClose: (() -> Void)?
    var onHide: (() -> Void)?
    let backButton = UIButton(type: .system)
    let preferredPortraitHeight: CGFloat

    init(language: Language) {
        preferredPortraitHeight = language == .burmese ? 406 : 300
        super.init(frame: .zero)
        accessibilityIdentifier = "typingTips"

        backButton.setTitle("Back", for: .normal)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 14)
        backButton.accessibilityLabel = "Back to Keyboard"
        backButton.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        let title = label(language == .burmese ? "မြန်မာ Typing Tips" : "English Typing Tips", size: 16, weight: .semibold)
        title.accessibilityTraits.insert(.header)
        title.textAlignment = .center

        let hide = UIButton(type: .system)
        hide.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        hide.setPreferredSymbolConfiguration(.init(pointSize: 14, weight: .regular), forImageIn: .normal)
        hide.accessibilityLabel = "Hide Keyboard"
        hide.addAction(UIAction { [weak self] _ in self?.onHide?() }, for: .touchUpInside)
        let header = UIStackView(arrangedSubviews: [backButton, UIView(), hide])
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        // Scrolling keeps longer Burmese copy and larger text usable at compact heights.
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26.0, *) {
            // The cards sit below their own header; edge blur would obscure the first tip.
            scroll.topEdgeEffect.isHidden = true
            scroll.bottomEdgeEffect.isHidden = true
        }
        addSubview(scroll)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        content.addArrangedSubview(title)
        content.setCustomSpacing(16, after: title)

        if language == .burmese {
            content.addArrangedSubview(card(
                title: "အစားထိုးအက္ခရာ",
                detail: "ခလုပ်ကို ခဏဖိထားပြီး လွှတ်ရင် အစားထိုးအက္ခရာ ရပါမယ်။ ကြာကြာဖိထားရင် ရွေးချယ်စရာတွေ ရပါမယ်။",
                demo: sequence([("က", false), ("→", false), ("ဥ", true)]),
                identifier: "typingTips.burmese.hold",
                example: "က ကို ဖိထားပြီး နေရာမရွှေ့ဘဲ လွှတ်ရင် ဥ ကို ရပါမယ်။"))
            content.addArrangedSubview(card(
                title: "ပါဌ်ဆင့် ရိုက်ရန်",
                detail: "အသတ် ( ် ) ၏ အစားထိုးအက္ခရာဖြစ်သော ( ္ ) ကိုသုံးပါ။ ( Shift + ် ) သို့မဟုတ် ( ် ) ကို ခဏဖိပြီးလွှတ်ပါ။",
                demo: sequence([("က", false), ("+", false), ("◌္", true), ("+", false), ("က", false), ("→", false), ("က္က", true)]),
                identifier: "typingTips.burmese.stacking",
                example: "က၊ ပါဌ်ဆင့်၊ က ကို အစဉ်လိုက် နှိပ်ရင် က္က ကို ရပါမယ်။"))
        } else {
            content.addArrangedSubview(card(
                title: "Move the cursor",
                detail: "Hold Space, then drag left or right to move the cursor.",
                demo: sequence([("←", false), ("Space", true), ("→", false)]),
                identifier: "typingTips.english.cursor",
                example: "Hold Space and drag left or right."))
            content.addArrangedSubview(card(
                title: "Finish a sentence",
                detail: "Double-tap Space after a word to insert a period and a space.",
                demo: sequence([("Hello", false), ("→", false), ("Hello. ␣", true)]),
                identifier: "typingTips.english.period",
                example: "Hello followed by two Space taps becomes Hello, period, space."))
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),
            backButton.widthAnchor.constraint(equalToConstant: 60),
            hide.widthAnchor.constraint(equalToConstant: 44),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }

    override func accessibilityPerformEscape() -> Bool {
        onClose?()
        return true
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: size, weight: weight))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0
        if text.unicodeScalars.contains(where: { (0x1000...0x109F).contains($0.value) }) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = label.font.pointSize * 1.9
            paragraph.lineSpacing = 2
            label.attributedText = NSAttributedString(string: text, attributes: [.paragraphStyle: paragraph])
        }
        return label
    }

    private func sequence(_ items: [(String, Bool)]) -> UIView {
        let row = UIStackView()
        row.spacing = 6
        row.alignment = .center
        for (text, highlighted) in items {
            let key = label(text, size: 19, weight: highlighted ? .semibold : .regular)
            // Examples are single glyphs; paragraph spacing is only for prose.
            key.attributedText = nil
            key.text = text
            if text.unicodeScalars.contains(where: { (0x1000...0x109F).contains($0.value) }) {
                // Myanmar fallback glyphs extend beyond the system font's Latin metrics.
                key.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: KeyButton.labelFont(for: text, size: 19))
            }
            key.textAlignment = .center
            let cap = UIView()
            if highlighted { key.textColor = .systemBlue }
            key.translatesAutoresizingMaskIntoConstraints = false
            cap.addSubview(key)
            NSLayoutConstraint.activate([
                key.topAnchor.constraint(equalTo: cap.topAnchor, constant: 4),
                key.bottomAnchor.constraint(equalTo: cap.bottomAnchor, constant: -4),
                key.leadingAnchor.constraint(equalTo: cap.leadingAnchor, constant: 6),
                key.trailingAnchor.constraint(equalTo: cap.trailingAnchor, constant: -6)
            ])
            row.addArrangedSubview(cap)
        }
        row.addArrangedSubview(UIView())
        row.isAccessibilityElement = false
        row.accessibilityElementsHidden = true
        return row
    }

    private func card(title: String, detail: String, demo: UIView, identifier: String, example: String) -> UIView {
        let heading = label(title, size: 14, weight: .semibold)
        heading.accessibilityTraits.insert(.header)
        let body = label(detail, size: 13)
        body.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [heading, body, demo])
        stack.axis = .vertical
        stack.spacing = 6
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        stack.backgroundColor = KeyColors.letter
        stack.layer.cornerRadius = 10
        stack.layer.cornerCurve = .continuous
        stack.isAccessibilityElement = true
        stack.accessibilityIdentifier = identifier
        stack.accessibilityLabel = title + ". " + detail + " " + example
        return stack
    }
}
