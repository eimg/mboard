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

final class SetupController: UITableViewController {
    private let editor = UITextView()
    private let instructions = [
        "In Settings, open General → Keyboard → Keyboards → Add New Keyboard and choose MBoard.",
        "In a text field, hold the globe and choose MBoard. Use the language button to switch between English and Burmese."
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MBoard"
        editor.accessibilityLabel = "Typing practice"
        editor.accessibilityIdentifier = "practice"
        editor.font = .preferredFont(forTextStyle: .title3)
        editor.adjustsFontForContentSizeCategory = true
        editor.backgroundColor = .clear
        editor.autocorrectionType = .no
        editor.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tableView.keyboardDismissMode = .interactive
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(endTyping))
    }

    @objc private func endTyping() { editor.resignFirstResponder() }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : 3 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Try the keyboard" : "Keyboard setup"
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? "Choose System, Light, or Dark with the appearance button on the keyboard. MBoard works offline with Full Access off." : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        if indexPath.section == 0 {
            editor.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(editor)
            NSLayoutConstraint.activate([
                editor.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor), editor.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                editor.topAnchor.constraint(equalTo: cell.contentView.topAnchor), editor.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                editor.heightAnchor.constraint(equalToConstant: 128)
            ])
        } else {
            var content = cell.defaultContentConfiguration()
            content.text = indexPath.row < 2 ? instructions[indexPath.row] : "Open Settings"
            content.textProperties.numberOfLines = 0
            if indexPath.row == 2 {
                content.textProperties.color = view.tintColor
                cell.accessoryType = .disclosureIndicator
                cell.accessibilityTraits = .button
            }
            cell.contentConfiguration = content
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1, indexPath.row == 2, let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
