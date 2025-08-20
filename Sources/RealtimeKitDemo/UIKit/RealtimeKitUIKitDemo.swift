import UIKit
import RealtimeCore
import RealtimeUIKit

@main
class RealtimeKitUIKitDemoApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // 配置 RealtimeKit
        Task {
            do {
                let config = RealtimeConfig(
                    appId: "demo_app_id",
                    appCertificate: "demo_app_certificate",
                    provider: .mock // 使用 Mock 服务商进行演示
                )
                try await RealtimeManager.shared.configure(provider: .mock, config: config)
                print("RealtimeKit configured successfully")
            } catch {
                print("Failed to configure RealtimeKit: \(error)")
            }
        }
        
        // 设置根视图控制器
        let mainViewController = MainDemoViewController()
        let navigationController = UINavigationController(rootViewController: mainViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        return true
    }
}

// MARK: - 主演示界面
class MainDemoViewController: UIViewController {
    
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "RealtimeKit UIKit Demo"
        
        // 标题
        titleLabel.text = "RealtimeKit 功能演示"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 堆栈视图配置
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        
        // 功能按钮
        let loginButton = createDemoButton(title: "用户登录演示", action: #selector(showLoginDemo))
        let roomButton = createDemoButton(title: "房间管理演示", action: #selector(showRoomDemo))
        let audioButton = createDemoButton(title: "音频控制演示", action: #selector(showAudioDemo))
        let volumeButton = createDemoButton(title: "音量可视化演示", action: #selector(showVolumeDemo))
        let streamButton = createDemoButton(title: "转推流演示", action: #selector(showStreamPushDemo))
        let relayButton = createDemoButton(title: "媒体中继演示", action: #selector(showMediaRelayDemo))
        
        stackView.addArrangedSubview(loginButton)
        stackView.addArrangedSubview(roomButton)
        stackView.addArrangedSubview(audioButton)
        stackView.addArrangedSubview(volumeButton)
        stackView.addArrangedSubview(streamButton)
        stackView.addArrangedSubview(relayButton)
    }
    
    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(stackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func createDemoButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        return button
    }
    
    // MARK: - 演示功能导航
    @objc private func showLoginDemo() {
        let loginDemo = LoginDemoViewController()
        navigationController?.pushViewController(loginDemo, animated: true)
    }
    
    @objc private func showRoomDemo() {
        let roomDemo = RoomManagementDemoViewController()
        navigationController?.pushViewController(roomDemo, animated: true)
    }
    
    @objc private func showAudioDemo() {
        let audioDemo = AudioControlDemoViewController()
        navigationController?.pushViewController(audioDemo, animated: true)
    }
    
    @objc private func showVolumeDemo() {
        let volumeDemo = VolumeVisualizationDemoViewController()
        navigationController?.pushViewController(volumeDemo, animated: true)
    }
    
    @objc private func showStreamPushDemo() {
        let streamDemo = StreamPushDemoViewController()
        navigationController?.pushViewController(streamDemo, animated: true)
    }
    
    @objc private func showMediaRelayDemo() {
        let relayDemo = MediaRelayDemoViewController()
        navigationController?.pushViewController(relayDemo, animated: true)
    }
}