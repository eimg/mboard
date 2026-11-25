import UIKit

enum KeyColors {
    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            let color = traits.userInterfaceStyle == .dark ? dark : light
            return color.resolvedColor(with: traits)
        }
    }
    static let letter = adaptive(light: .white, dark: .systemGray3)
    static let modifier = adaptive(light: .systemGray4, dark: .systemGray5)
    static let pressed = adaptive(light: .systemGray3, dark: .systemGray2)
    static let emojiSurface = adaptive(light: .systemGray5, dark: .secondarySystemGroupedBackground)
    static let ink = UIColor.label
}

final class KeyButton: UIButton {
    var fill: UIColor = KeyColors.letter { didSet { updateFill() } }
    override var isHighlighted: Bool { didSet { updateFill() } }
    private func updateFill() {
        backgroundColor = isHighlighted ? KeyColors.pressed : fill
        layer.shadowOpacity = fill == .clear || isHighlighted ? 0 : 0.18
    }

    init(title: String, symbol: String? = nil, modifier: Bool = false, hint: String? = nil) {
        super.init(frame: .zero)
        fill = modifier ? KeyColors.modifier : KeyColors.letter
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0.5
        tintColor = KeyColors.ink
        setTitleColor(KeyColors.ink, for: .normal)
        titleLabel?.font = .systemFont(ofSize: modifier ? 16 : 23)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.5
        titleLabel?.lineBreakMode = .byClipping
        if let symbol {
            setImage(UIImage(systemName: symbol), for: .normal)
            setPreferredSymbolConfiguration(.init(pointSize: 17, weight: .medium), forImageIn: .normal)
        } else {
            contentVerticalAlignment = .fill
            contentHorizontalAlignment = .fill
            titleLabel?.textAlignment = .center
            titleLabel?.baselineAdjustment = .alignCenters
            setTitle(title, for: .normal)
        }
        accessibilityLabel = title
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        updateFill()
        if let hint {
            let label = UILabel()
            label.font = .systemFont(ofSize: 9, weight: .medium)
            label.textColor = .secondaryLabel
            label.text = hint
            label.isAccessibilityElement = false
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([label.topAnchor.constraint(equalTo: topAnchor, constant: 1),
                                         label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3)])
        }
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}

final class AlternateMenu: UIView {
    private let options: [String]
    private var labels: [UILabel] = []
    private var selected: Int
    private let start: CGPoint
    private let columns: Int
    private let cellWidth: CGFloat
    private let defaultIndex: Int
    var value: String { options[selected] }

    init(key: KeyButton, letter: LetterKey, board: UIView, start: CGPoint) {
        options = letter.alternatives
        selected = letter.defaultIndex
        defaultIndex = letter.defaultIndex
        self.start = start
        let keyFrame = key.convert(key.bounds, to: board)
        let cell = min(48, max(34, keyFrame.width))
        let lines = options.count > 4 ? 2 : 1
        columns = (options.count + lines - 1) / lines
        cellWidth = min(cell, (board.bounds.width - 12) / CGFloat(columns))
        let width = cellWidth * CGFloat(columns) + 8
        let height = CGFloat(lines) * 36 + 8
        let x = min(max(2, keyFrame.midX - cellWidth * (CGFloat(selected % columns) + 0.5) - 4), board.bounds.width - width - 2)
        super.init(frame: CGRect(x: x, y: max(0, keyFrame.minY - height), width: width, height: height))
        isUserInteractionEnabled = false
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 13
        layer.cornerCurve = .continuous
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
        for (i, text) in options.enumerated() {
            let label = UILabel(frame: CGRect(x: 4 + CGFloat(i % columns) * cellWidth, y: 4 + CGFloat(i / columns) * 36, width: cellWidth, height: 36))
            label.text = LetterKey.label(for: text)
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 20)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.layer.cornerRadius = 9
            label.clipsToBounds = true
            addSubview(label)
            labels.append(label)
        }
        paint()
    }
    func track(_ point: CGPoint) {
        // Lifting in place always chooses the captured default, including at screen edges.
        let local = CGPoint(x: point.x - frame.minX - 4, y: point.y - frame.minY - 4)
        let col = max(0, min(columns - 1, Int(floor(local.x / cellWidth))))
        let row = min((options.count - 1) / columns, max(0, Int(floor(local.y / 36))))
        selected = hypot(point.x - start.x, point.y - start.y) < 8 ? defaultIndex : min(options.count - 1, row * columns + col)
        paint()
    }
    private func paint() {
        for (i, label) in labels.enumerated() {
            label.backgroundColor = i == selected ? .tertiarySystemFill : .clear
            label.textColor = KeyColors.ink
        }
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view") }
}
