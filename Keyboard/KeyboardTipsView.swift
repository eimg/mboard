import UIKit

final class KeyboardTipsView: KeyboardPanelView {
    init(language: Language) {
        super.init(title: language == .burmese ? "မြန်မာ Typing Tips" : "English Typing Tips",
                   preferredPortraitHeight: language == .burmese ? 406 : 300)
        accessibilityIdentifier = "typingTips"

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
    }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }

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
        stack.backgroundColor = .secondarySystemGroupedBackground
        stack.layer.cornerRadius = 10
        stack.layer.cornerCurve = .continuous
        stack.isAccessibilityElement = true
        stack.accessibilityIdentifier = identifier
        stack.accessibilityLabel = title + ". " + detail + " " + example
        return stack
    }
}
