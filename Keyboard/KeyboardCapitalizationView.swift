import UIKit

final class KeyboardCapitalizationView: KeyboardPanelView {
    private weak var selectedButton: UIButton?

    init(selected: CapitalizationStyle, onSelect: @escaping (CapitalizationStyle) -> Void) {
        super.init(title: "Auto-Capitalization", preferredPortraitHeight: 406)
        accessibilityIdentifier = "capitalizationPanel"
        let explanation = label("All enabled modes capitalize sentence starts.", size: 14)
        explanation.textAlignment = .center
        explanation.textColor = .secondaryLabel
        content.addArrangedSubview(explanation)
        content.setCustomSpacing(12, after: explanation)

        let choices = UIStackView()
        choices.axis = .vertical
        choices.backgroundColor = .secondarySystemGroupedBackground
        choices.layer.cornerRadius = 14
        choices.layer.cornerCurve = .continuous
        choices.clipsToBounds = true
        content.addArrangedSubview(choices)

        for style in CapitalizationStyle.allCases {
            let title: String
            let example: String
            switch style {
            case .off: (title, example) = ("Off", "hello. see you soon.")
            case .sentenceStarts: (title, example) = ("Sentence starts only", "ဒီနေ့ team meeting")
            case .firstEnglishWord: (title, example) = ("First English word after Burmese", "ဒီနေ့ Team meeting")
            case .everyEnglishWord: (title, example) = ("Every English word in mixed text", "ဒီနေ့ Team Meeting")
            }
            let button = UIButton(type: .custom)
            button.isSelected = style == selected
            if button.isSelected { selectedButton = button }
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, !button.isSelected else { return }
                selectedButton?.isSelected = false
                button.isSelected = true
                selectedButton = button
                onSelect(style)
            }, for: .primaryActionTriggered)
            button.accessibilityIdentifier = "capitalization." + style.rawValue
            button.accessibilityLabel = title
            button.accessibilityValue = example

            let sample = label(example, size: 14)
            sample.textColor = .secondaryLabel
            let text = UIStackView(arrangedSubviews: [label(title, size: 15, weight: .semibold), sample])
            text.axis = .vertical
            text.spacing = 4
            let checkmark = UIImageView()
            checkmark.contentMode = .center
            let symbolSize = UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
            let checked = UIImage(systemName: "checkmark.circle.fill", withConfiguration: symbolSize)
            let unchecked = UIImage(systemName: "circle", withConfiguration: symbolSize)
            button.configurationUpdateHandler = { button in
                checkmark.image = button.isSelected ? checked : unchecked
                checkmark.tintColor = button.isSelected ? .systemBlue : .tertiaryLabel
                if button.isHighlighted {
                    button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.20)
                } else {
                    button.backgroundColor = button.isSelected ? UIColor.systemBlue.withAlphaComponent(0.10) : .clear
                }
            }
            let row = UIStackView(arrangedSubviews: [text, checkmark])
            row.alignment = .center
            row.spacing = 8
            row.isUserInteractionEnabled = false
            row.accessibilityElementsHidden = true
            row.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: button.topAnchor, constant: 11),
                row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -11),
                row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
                row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
                checkmark.widthAnchor.constraint(equalToConstant: 24),
                button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
            if style != .off {
                let divider = UIView()
                divider.backgroundColor = .separator
                divider.isUserInteractionEnabled = false
                divider.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(divider)
                NSLayoutConstraint.activate([
                    divider.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                    divider.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                    divider.topAnchor.constraint(equalTo: button.topAnchor),
                    divider.heightAnchor.constraint(equalToConstant: 1 / max(1, traitCollection.displayScale))
                ])
            }
            choices.addArrangedSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }
}
