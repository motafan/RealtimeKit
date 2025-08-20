import UIKit
import RealtimeCore

// MARK: - 房间管理演示界面
class RoomManagementDemoViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // UI 组件
    private let titleLabel = UILabel()
    private let roomIdTextField = UITextField()
    private let createRoomButton = UIButton(type: .system)
    private let joinRoomButton = UIButton(type: .system)
    private let leaveRoomButton = UIButton(type: .system)
    private let roomStatusLabel = UILabel()
    private let roomInfoView = UIView()
    private let roomInfoLabel = UILabel()
    private let participantsTableView = UITableView()
    
    private var participants: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        updateUI()
        observeRealtimeManager()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "房间管理演示"
        
        // 标题
        titleLabel.text = "房间管理功能"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 房间ID输入
        roomIdTextField.placeholder = "输入房间ID"
        roomIdTextField.borderStyle = .roundedRect
        roomIdTextField.text = "demo_room_\(Int.random(in: 1000...9999))"
        
        // 创建房间按钮
        createRoomButton.setTitle("创建房间", for: .normal)
        createRoomButton.backgroundColor = .systemGreen
        createRoomButton.setTitleColor(.white, for: .normal)
        createRoomButton.layer.cornerRadius = 8
        createRoomButton.addTarget(self, action: #selector(createRoomButtonTapped), for: .touchUpInside)
        
        // 加入房间按钮
        joinRoomButton.setTitle("加入房间", for: .normal)
        joinRoomButton.backgroundColor = .systemBlue
        joinRoomButton.setTitleColor(.white, for: .normal)
        joinRoomButton.layer.cornerRadius = 8
        joinRoomButton.addTarget(self, action: #selector(joinRoomButtonTapped), for: .touchUpInside)
        
        // 离开房间按钮
        leaveRoomButton.setTitle("离开房间", for: .normal)
        leaveRoomButton.backgroundColor = .systemRed
        leaveRoomButton.setTitleColor(.white, for: .normal)
        leaveRoomButton.layer.cornerRadius = 8
        leaveRoomButton.addTarget(self, action: #selector(leaveRoomButtonTapped), for: .touchUpInside)
        
        // 房间状态标签
        roomStatusLabel.text = "未在房间中"
        roomStatusLabel.textAlignment = .center
        roomStatusLabel.font = .systemFont(ofSize: 16)
        roomStatusLabel.textColor = .systemGray
        
        // 房间信息视图
        roomInfoView.backgroundColor = .systemGray6
        roomInfoView.layer.cornerRadius = 8
        roomInfoView.isHidden = true
        
        roomInfoLabel.numberOfLines = 0
        roomInfoLabel.font = .systemFont(ofSize: 14)
        roomInfoLabel.textColor = .label
        
        // 参与者列表
        participantsTableView.delegate = self
        participantsTableView.dataSource = self
        participantsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ParticipantCell")
        participantsTableView.layer.cornerRadius = 8
        participantsTableView.backgroundColor = .systemGray6
        
        // 堆栈视图配置
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
    }
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        roomInfoView.addSubview(roomInfoLabel)
        
        // 添加到堆栈视图
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(createSectionView(title: "房间操作", content: [roomIdTextField]))
        
        let buttonStack = UIStackView(arrangedSubviews: [createRoomButton, joinRoomButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        stackView.addArrangedSubview(buttonStack)
        stackView.addArrangedSubview(leaveRoomButton)
        stackView.addArrangedSubview(createSectionView(title: "房间状态", content: [roomStatusLabel]))
        stackView.addArrangedSubview(createSectionView(title: "房间信息", content: [roomInfoView]))
        
        let participantsSection = createSectionView(title: "参与者列表", content: [participantsTableView])
        stackView.addArrangedSubview(participantsSection)
        
        // 约束设置
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roomInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            roomInfoLabel.topAnchor.constraint(equalTo: roomInfoView.topAnchor, constant: 12),
            roomInfoLabel.leadingAnchor.constraint(equalTo: roomInfoView.leadingAnchor, constant: 12),
            roomInfoLabel.trailingAnchor.constraint(equalTo: roomInfoView.trailingAnchor, constant: -12),
            roomInfoLabel.bottomAnchor.constraint(equalTo: roomInfoView.bottomAnchor, constant: -12),
            
            createRoomButton.heightAnchor.constraint(equalToConstant: 44),
            joinRoomButton.heightAnchor.constraint(equalToConstant: 44),
            leaveRoomButton.heightAnchor.constraint(equalToConstant: 44),
            participantsTableView.heightAnchor.constraint(equalToConstant: 200)
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
        // 监听房间状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(roomStateDidChange),
            name: NSNotification.Name("RealtimeManager.roomStateDidChange"),
            object: nil
        )
    }
    
    @objc private func roomStateDidChange() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    private func updateUI() {
        let session = RealtimeManager.shared.currentSession
        let connectionState = RealtimeManager.shared.connectionState
        
        if let session = session, let roomId = session.roomId, connectionState == .connected {
            roomStatusLabel.text = "已在房间中"
            roomStatusLabel.textColor = .systemGreen
            createRoomButton.isEnabled = false
            joinRoomButton.isEnabled = false
            leaveRoomButton.isEnabled = true
            roomInfoView.isHidden = false
            
            roomInfoLabel.text = """
            房间ID: \(roomId)
            用户角色: \(getUserRoleDisplayName(session.userRole))
            连接状态: 已连接
            加入时间: \(formatDate(session.joinTime))
            """
            
            // 模拟参与者列表
            participants = ["用户1", "用户2", session.userName]
            participantsTableView.reloadData()
        } else {
            roomStatusLabel.text = "未在房间中"
            roomStatusLabel.textColor = .systemGray
            createRoomButton.isEnabled = session != nil
            joinRoomButton.isEnabled = session != nil
            leaveRoomButton.isEnabled = false
            roomInfoView.isHidden = true
            
            participants = []
            participantsTableView.reloadData()
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
    
    @objc private func createRoomButtonTapped() {
        guard let roomId = roomIdTextField.text, !roomId.isEmpty else {
            showAlert(title: "错误", message: "请输入房间ID")
            return
        }
        
        guard let session = RealtimeManager.shared.currentSession else {
            showAlert(title: "错误", message: "请先登录")
            return
        }
        
        Task {
            do {
                try await RealtimeManager.shared.createRoom(roomId: roomId)
                try await RealtimeManager.shared.joinRoom(roomId: roomId, userId: session.userId, userRole: session.userRole)
                
                await MainActor.run {
                    self.updateUI()
                    self.showAlert(title: "成功", message: "房间创建并加入成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "创建房间失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func joinRoomButtonTapped() {
        guard let roomId = roomIdTextField.text, !roomId.isEmpty else {
            showAlert(title: "错误", message: "请输入房间ID")
            return
        }
        
        guard let session = RealtimeManager.shared.currentSession else {
            showAlert(title: "错误", message: "请先登录")
            return
        }
        
        Task {
            do {
                try await RealtimeManager.shared.joinRoom(roomId: roomId, userId: session.userId, userRole: session.userRole)
                
                await MainActor.run {
                    self.updateUI()
                    self.showAlert(title: "成功", message: "加入房间成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "加入房间失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func leaveRoomButtonTapped() {
        Task {
            do {
                try await RealtimeManager.shared.leaveRoom()
                
                await MainActor.run {
                    self.updateUI()
                    self.showAlert(title: "成功", message: "离开房间成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "离开房间失败", message: error.localizedDescription)
                }
            }
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

// MARK: - UITableViewDataSource & UITableViewDelegate
extension RoomManagementDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return participants.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ParticipantCell", for: indexPath)
        cell.textLabel?.text = participants[indexPath.row]
        cell.backgroundColor = .clear
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return participants.isEmpty ? "暂无参与者" : "当前参与者 (\(participants.count))"
    }
}