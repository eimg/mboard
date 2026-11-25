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
        navigation.navigationBar.prefersLargeTitles = true
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class SetupController: UITableViewController, UITextViewDelegate {
    private let editor = UITextView()
    private let placeholder = UILabel()
    private lazy var practiceCell = makePracticeCell()
    private lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(endTyping))
        button.accessibilityIdentifier = "doneTyping"
        return button
    }()
    private let instructions = [
        "Settings ထဲက General → Keyboard → Keyboards → Add New Keyboard ကို သွားပြီး MBoard ကို ရွေးပါ။",
        "🌐 ကို ဖိထားပြီး MBoard ကို ရွေးပါ။ English နဲ့ မြန်မာ ပြောင်းဖို့ keyboard အပေါ်ဘက်က language button ကို နှိပ်ပါ။"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MBoard"
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
        tableView.keyboardDismissMode = .interactive
    }

    @objc private func endTyping() { view.endEditing(true) }

    func textViewDidBeginEditing(_ textView: UITextView) {
        placeholder.isHidden = true
        navigationItem.rightBarButtonItem = doneButton
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
        navigationItem.rightBarButtonItem = nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : instructions.count + 1
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "စာရိုက်စမ်းရန်" : "Keyboard ထည့်ရန်"
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == 1 else { return nil }
        let footer = UITableViewHeaderFooterView(reuseIdentifier: nil)
        var content = footer.defaultContentConfiguration()
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16)
        content.textProperties.font = .preferredFont(forTextStyle: .footnote)
        content.textProperties.color = .secondaryLabel
        setInstruction(
            "appearance button နဲ့ System၊ Light သို့မဟုတ် Dark ကို ရွေးပါ။ Full Access ပိတ်ထားလည်း offline သုံးနိုင်ပါတယ်။",
            in: &content
        )
        footer.contentConfiguration = content
        return footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 { return practiceCell }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        if indexPath.row == instructions.count {
            content.text = "Settings ဖွင့်ရန်"
            content.textProperties.color = view.tintColor
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityTraits.insert(.button)
            cell.accessibilityIdentifier = "openSettings"
        } else {
            cell.selectionStyle = .none
            setInstruction(instructions[indexPath.row], in: &content)
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1, indexPath.row == instructions.count,
              let url = URL(string: UIApplication.openSettingsURLString) else { return }
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
