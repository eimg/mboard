import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let navigation = UINavigationController(rootViewController: SetupController(style: .insetGrouped))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class SetupController: UITableViewController, UITextViewDelegate, UIGestureRecognizerDelegate {
    private let editor = UITextView()
    private let placeholder = UILabel()
    private lazy var practiceCell = makePracticeCell()
    private let instructions = [
        "Settings ထဲက General → Keyboard → Keyboards → Add New Keyboard ကို သွားပြီး MBoard ကို ရွေးပါ။",
        "🌐 ကို ဖိထားပြီး MBoard ကို ရွေးပါ။ English နဲ့ မြန်မာ ပြောင်းဖို့ Keyboard အပေါ်ဘက်က Language Button ကို နှိပ်ပါ။"
    ]

    private let links = [
        (title: "Settings ဖွင့်ရန်", identifier: "openSettings", url: UIApplication.openSettingsURLString),
        (title: "Privacy Policy", identifier: "privacyPolicy", url: "https://github.com/eimg/mboard/blob/main/PRIVACY.md"),
        (title: "Support", identifier: "support", url: "https://github.com/eimg/mboard/blob/main/SUPPORT.md")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MBoard"
        navigationItem.titleView = makeTitleView()
        editor.accessibilityLabel = "စာရိုက်စမ်းရန်"
        editor.accessibilityIdentifier = "practice"
        editor.font = .preferredFont(forTextStyle: .title3)
        editor.adjustsFontForContentSizeCategory = true
        editor.textColor = .label
        editor.backgroundColor = .clear
        editor.autocorrectionType = .no
        editor.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        editor.delegate = self
        placeholder.text = "ဒီနေရာမှာ စာရိုက်စမ်းကြည့်ပါ။"
        placeholder.font = .preferredFont(forTextStyle: .body)
        placeholder.adjustsFontForContentSizeCategory = true
        placeholder.textColor = .placeholderText
        placeholder.numberOfLines = 0
        placeholder.isAccessibilityElement = false
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .onDrag
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(endTyping))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        tableView.addGestureRecognizer(dismissTap)
    }

    private func makeTitleView() -> UIView {
        let icon = UIImageView(image: UIImage(named: "MBoardMark"))
        icon.contentMode = .scaleAspectFit
        icon.clipsToBounds = true
        icon.layer.cornerRadius = 8
        icon.layer.cornerCurve = .continuous
        icon.isAccessibilityElement = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalTo: icon.widthAnchor)
        ])

        let name = UILabel()
        name.text = title
        name.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 19, weight: .semibold))
        name.adjustsFontForContentSizeCategory = true
        name.textColor = .label
        name.accessibilityTraits.insert(.header)

        let stack = UIStackView(arrangedSubviews: [icon, name])
        stack.alignment = .center
        stack.spacing = 8
        stack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(endTyping)))
        return stack
    }

    @objc private func endTyping() { view.endEditing(true) }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        editor.isFirstResponder && !editor.bounds.contains(touch.location(in: editor))
    }

    override func accessibilityPerformEscape() -> Bool {
        editor.isFirstResponder ? editor.resignFirstResponder() : super.accessibilityPerformEscape()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        placeholder.isHidden = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : instructions.count + links.count
    }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UITableViewHeaderFooterView(reuseIdentifier: nil)
        var content = UIListContentConfiguration.groupedHeader()
        content.text = section == 0 ? "စာရိုက်စမ်းရန်" : "Keyboard ထည့်ရန်"
        content.textProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.textProperties.transform = .none
        header.contentConfiguration = content
        header.accessibilityTraits.insert(.header)
        return header
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 { return practiceCell }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        if indexPath.row >= instructions.count {
            let link = links[indexPath.row - instructions.count]
            content.text = link.title
            content.textProperties.color = view.tintColor
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityTraits.insert(.button)
            cell.accessibilityIdentifier = link.identifier
        } else {
            cell.selectionStyle = .none
            setInstruction(instructions[indexPath.row], in: &content)
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1, indexPath.row >= instructions.count,
              let url = URL(string: links[indexPath.row - instructions.count].url) else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        endTyping()
        UIApplication.shared.open(url)
    }

    private func setInstruction(_ text: String, in content: inout UIListContentConfiguration) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 10
        content.textProperties.numberOfLines = 0
        content.attributedText = NSAttributedString(string: text, attributes: [.paragraphStyle: paragraph])
    }

    private func makePracticeCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let content = cell.contentView
        editor.translatesAutoresizingMaskIntoConstraints = false
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(editor)
        content.addSubview(placeholder)
        NSLayoutConstraint.activate([
            editor.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            editor.topAnchor.constraint(equalTo: content.topAnchor),
            editor.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            editor.heightAnchor.constraint(greaterThanOrEqualToConstant: 128),
            placeholder.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 17),
            placeholder.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -17),
            placeholder.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            placeholder.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -12)
        ])
        return cell
    }
}
