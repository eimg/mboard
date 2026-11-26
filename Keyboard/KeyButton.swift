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
    var letter: LetterKey?
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
        let fontSize: CGFloat = modifier ? 16 : 23
        titleLabel?.font = Self.labelFont(for: title, size: fontSize)
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

    static func labelFont(for text: String, size: CGFloat) -> UIFont {
        // Look at the glyphs so mixed symbol pages keep their Latin sizing.
        let isMyanmar = text.unicodeScalars.contains { (0x1000...0x109F).contains($0.value) }
        return .systemFont(ofSize: isMyanmar ? (size * 0.83).rounded() : size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}

/// One keycap on touch-down, expanded into a grid of equally sized keycaps on hold.
final class KeyPopup: UIView {
    private weak var source: KeyButton?
    private var options: [String] = []
    private var labels: [UILabel] = []
    private var holdStart: CGPoint?
    private var defaultIndex = 0
    private var selected = 0
    private var columns = 1
    private var cell = CGSize.zero

    var isChoosingAlternate: Bool { holdStart != nil }
    var selectedAlternate: String? { isChoosingAlternate ? options[selected] : nil }

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        backgroundColor = KeyColors.letter
        layer.cornerRadius = 9
        layer.cornerCurve = .continuous
        layer.shadowOpacity = 0.23
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }

    func show(_ values: [String], for key: KeyButton, in board: UIView,
              defaultIndex: Int = 0, start: CGPoint? = nil) {
        let keyFrame = key.convert(key.bounds, to: board)
        let availableWidth = board.bounds.width - 4
        guard availableWidth > 0, values.indices.contains(defaultIndex) else { return }
        source = key
        options = values
        holdStart = start
        self.defaultIndex = defaultIndex
        selected = defaultIndex
        cell = CGSize(width: min(availableWidth, min(60, max(51, keyFrame.width + 14))),
                      height: min(48, keyFrame.height + 6))
        let preferredColumns = values.count > 4 ? (values.count + 1) / 2 : values.count
        columns = min(preferredColumns, max(1, Int(availableWidth / cell.width)))
        let rows = (values.count + columns - 1) / columns
        let size = CGSize(width: CGFloat(columns) * cell.width, height: CGFloat(rows) * cell.height)
        let alignedX = keyFrame.midX - (CGFloat(selected % columns) + 0.5) * cell.width
        let x = min(max(2, alignedX), board.bounds.width - size.width - 2)
        layer.removeAllAnimations()
        frame = CGRect(origin: CGPoint(x: x, y: max(2, keyFrame.minY - size.height - 2)), size: size)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        for (index, value) in values.enumerated() {
            if index == labels.count {
                let label = UILabel()
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.6
                label.textColor = KeyColors.ink
                label.layer.cornerRadius = layer.cornerRadius
                label.layer.cornerCurve = .continuous
                label.clipsToBounds = true
                addSubview(label)
                labels.append(label)
            }
            let label = labels[index]
            label.frame = CGRect(x: CGFloat(index % columns) * cell.width,
                                 y: CGFloat(index / columns) * cell.height, width: cell.width, height: cell.height)
            label.text = LetterKey.label(for: value)
            label.font = KeyButton.labelFont(for: value, size: 31)
            label.isHidden = false
            label.backgroundColor = index == selected && values.count > 1 ? KeyColors.pressed : .clear
        }
        for label in labels.dropFirst(values.count) { label.isHidden = true }
        alpha = 1
        board.addSubview(self)
    }

    func track(_ point: CGPoint) {
        guard let holdStart else { return }
        let local = convert(point, from: superview)
        let column = max(0, min(columns - 1, Int(floor(local.x / cell.width))))
        let row = max(0, min((options.count - 1) / columns, Int(floor(local.y / cell.height))))
        // Lifting in place chooses the default even if the popup was clamped at an edge.
        let next = hypot(point.x - holdStart.x, point.y - holdStart.y) < 8
            ? defaultIndex : min(options.count - 1, row * columns + column)
        guard next != selected else { return }
        labels[selected].backgroundColor = .clear
        selected = next
        labels[next].backgroundColor = KeyColors.pressed
    }

    func release(_ key: KeyButton) {
        guard source === key, !isChoosingAlternate else { return }
        source = nil
        if UIAccessibility.isReduceMotionEnabled { dismiss(); return }
        UIView.animate(withDuration: 0.09, animations: { self.alpha = 0 }) { finished in
            if finished && self.source == nil { self.removeFromSuperview() }
        }
    }

    func dismiss() {
        source = nil
        holdStart = nil
        layer.removeAllAnimations()
        removeFromSuperview()
    }
}
