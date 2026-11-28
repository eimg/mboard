import UIKit

class KeyboardPanelView: UIView {
    var onClose: (() -> Void)?
    var onHide: (() -> Void)?
    let backButton = UIButton(type: .system)
    let content = UIStackView()
    let preferredPortraitHeight: CGFloat

    init(title titleText: String, preferredPortraitHeight: CGFloat) {
        self.preferredPortraitHeight = preferredPortraitHeight
        super.init(frame: .zero)

        backButton.setTitle("Back", for: .normal)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 14)
        backButton.accessibilityLabel = "Back to Keyboard"
        backButton.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        let title = label(titleText, size: 16, weight: .semibold)
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

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26.0, *) {
            scroll.topEdgeEffect.isHidden = true
            scroll.bottomEdgeEffect.isHidden = true
        }
        addSubview(scroll)
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        content.addArrangedSubview(title)
        content.setCustomSpacing(16, after: title)

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

    func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular) -> UILabel {
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
}
