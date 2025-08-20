import UIKit
import RealtimeCore

// MARK: - 用户登录演示界面
class LoginDemoViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // UI 组件
    private let titleLabel = UILabel()
    private let userIdTextField = UITextField()
    private let userNameTextField = UITextField()
    private let roleSegmentedControl = UISegmentedControl(items: ["主播", "观众", "连麦嘉宾", "主持人"])
    private let loginButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let sessionInfoView = UIView()
    private let sessionLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        updateUI()
        observeRealtimeManager()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "用户登录演示"
        
        // 标题
        titleLabel.text = "用户身份管理"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 用户ID输入
        userIdTextField.placeholder = "输入用户ID"
        userIdTextField.borderStyle = .roundedRect
        userIdTextField.text = "demo_user_\(Int.random(in: 1000...9999))"
        
        // 用户名输入
        userNameTextField.placeholder = "输入用户名"
        userNameTextField.borderStyle = .roundedRect
        userNameTextField.text = "演示用户"
        
        // 角色选择
        roleSegmentedControl.selectedSegmentIndex = 0
        
        // 登录按钮
        loginButton.setTitle("登录", for: .normal)
        loginButton.backgroundColor = .systemBlue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        // 登出按钮
        logoutButton.setTitle("登出", for: .normal)
        logoutButton.backgroundColor = .systemRed
        logoutButton.setTitleColor(.white, for: .normal)
        logoutButton.layer.cornerRadius = 8
        logoutButton.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        
        // 状态标签
        statusLabel.text = "未登录"
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .systemGray
        
        // 会话信息视图
        sessionInfoView.backgroundColor = .systemGray6
        sessionInfoView.layer.cornerRadius = 8
        sessionInfoView.isHidden = true
        
        sessionLabel.numberOfLines = 0
        sessionLabel.font = .systemFont(ofSize: 14)
        sessionLabel.textColor = .label
        
        // 堆栈视图配置
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
    }
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        sessionInfoView.addSubview(sessionLabel)
        
        // 添加到堆栈视图
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(createSectionView(title: "用户信息", content: [userIdTextField, userNameTextField]))
        stackView.addArrangedSubview(createSectionView(title: "用户角色", content: [roleSegmentedControl]))
        stackView.addArrangedSubview(createSectionView(title: "操作", content: [loginButton, logoutButton]))
        stackView.addArrangedSubview(createSectionView(title: "状态", content: [statusLabel]))
        stackView.addArrangedSubview(createSectionView(title: "会话信息", content: [sessionInfoView]))
        
        // 约束设置
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        sessionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            sessionLabel.topAnchor.constraint(equalTo: sessionInfoView.topAnchor, constant: 12),
            sessionLabel.leadingAnchor.constraint(equalTo: sessionInfoView.leadingAnchor, constant: 12),
            sessionLabel.trailingAnchor.constraint(equalTo: sessionInfoView.trailingAnchor, constant: -12),
            sessionLabel.bottomAnchor.constraint(equalTo: sessionInfoView.bottomAnchor, constant: -12),
            
            loginButton.heightAnchor.constraint(equalToConstant: 44),
            logoutButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func createSectionView(title: String, content: [UIView]) -> UIView {
        let sectionView = UIView()
        let sectionTitle = UILabel()
        let sectionStack = UIStackView()
        
        sectionTitle.text = title
        sectionTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        sectionTitle.textColor = .label
        
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        sectionStack.alignment = .fill
        
        content.forEach { sectionStack.addArrangedSubview($0) }
        
        sectionView.addSubview(sectionTitle)
        sectionView.addSubview(sectionStack)
        
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        sectionStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: sectionView.topAnchor),
            sectionTitle.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            sectionTitle.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            
            sectionStack.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 8),
            sectionStack.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            sectionStack.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            sectionStack.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor)
        ])
        
        return sectionView
    }
    
    private func observeRealtimeManager() {
        // 监听 RealtimeManager 状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidChange),
            name: NSNotification.Name("RealtimeManager.sessionDidChange"),
            object: nil
        )
    }
    
    @objc private func sessionDidChange() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    private func updateUI() {
        let session = RealtimeManager.shared.currentSession
        
        if let session = session {
            statusLabel.text = "已登录"
            statusLabel.textColor = .systemGreen
            loginButton.isEnabled = false
            logoutButton.isEnabled = true
            sessionInfoView.isHidden = false
            
            let roleText = getUserRoleDisplayName(session.userRole)
            sessionLabel.text = """
            用户ID: \(session.userId)
            用户名: \(session.userName)
            角色: \(roleText)
            房间ID: \(session.roomId ?? "未加入房间")
            登录时间: \(formatDate(session.joinTime))
            """
        } else {
            statusLabel.text = "未登录"
            statusLabel.textColor = .systemGray
            loginButton.isEnabled = true
            logoutButton.isEnabled = false
            sessionInfoView.isHidden = true
        }
    }
    
    private func getUserRoleDisplayName(_ role: UserRole) -> String {
        switch role {
        case .broadcaster: return "主播"
        case .audience: return "观众"
        case .coHost: return "连麦嘉宾"
        case .moderator: return "主持人"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    @objc private func loginButtonTapped() {
        guard let userId = userIdTextField.text, !userId.isEmpty,
              let userName = userNameTextField.text, !userName.isEmpty else {
            showAlert(title: "错误", message: "请输入用户ID和用户名")
            return
        }
        
        let selectedRole = getUserRole(from: roleSegmentedControl.selectedSegmentIndex)
        
        Task {
            do {
                try await RealtimeManager.shared.loginUser(
                    userId: userId,
                    userName: userName,
                    userRole: selectedRole
                )
                
                await MainActor.run {
                    self.updateUI()
                    self.showAlert(title: "成功", message: "登录成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "登录失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func logoutButtonTapped() {
        Task {
            do {
                try await RealtimeManager.shared.logoutUser()
                
                await MainActor.run {
                    self.updateUI()
                    self.showAlert(title: "成功", message: "登出成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "登出失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func getUserRole(from index: Int) -> UserRole {
        switch index {
        case 0: return .broadcaster
        case 1: return .audience
        case 2: return .coHost
        case 3: return .moderator
        default: return .audience
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}