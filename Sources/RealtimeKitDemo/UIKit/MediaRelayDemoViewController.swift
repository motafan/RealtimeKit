import UIKit
import RealtimeCore

// MARK: - 媒体中继演示界面
class MediaRelayDemoViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // UI 组件
    private let titleLabel = UILabel()
    
    // 源频道配置
    private let sourceChannelTextField = UITextField()
    private let sourceTokenTextField = UITextField()
    
    // 目标频道管理
    private let targetChannelsTableView = UITableView()
    private let addChannelButton = UIButton(type: .system)
    
    // 中继模式选择
    private let relayModeSegmentedControl = UISegmentedControl(items: ["一对一", "一对多", "多对多"])
    
    // 控制按钮
    private let startRelayButton = UIButton(type: .system)
    private let stopRelayButton = UIButton(type: .system)
    private let pauseResumeButton = UIButton(type: .system)
    
    // 状态显示
    private let statusLabel = UILabel()
    private let statusInfoView = UIView()
    private let statusInfoLabel = UILabel()
    
    // 统计信息
    private let statsView = UIView()
    private let statsLabel = UILabel()
    
    // 数据模型
    private var targetChannels: [RelayChannelInfo] = []
    private var relayStats: MediaRelayStats?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        setupTableView()
        updateUI()
        observeRealtimeManager()
        loadSampleData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "媒体中继演示"
        
        // 标题
        titleLabel.text = "跨媒体流中继"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 源频道配置
        sourceChannelTextField.placeholder = "源频道名称"
        sourceChannelTextField.borderStyle = .roundedRect
        sourceChannelTextField.text = "source_channel_\(Int.random(in: 1000...9999))"
        
        sourceTokenTextField.placeholder = "源频道Token"
        sourceTokenTextField.borderStyle = .roundedRect
        sourceTokenTextField.text = "source_token_demo"
        
        // 目标频道表格
        targetChannelsTableView.backgroundColor = .systemGray6
        targetChannelsTableView.layer.cornerRadius = 8
        
        // 添加频道按钮
        addChannelButton.setTitle("+ 添加目标频道", for: .normal)
        addChannelButton.backgroundColor = .systemBlue
        addChannelButton.setTitleColor(.white, for: .normal)
        addChannelButton.layer.cornerRadius = 8
        addChannelButton.addTarget(self, action: #selector(addChannelButtonTapped), for: .touchUpInside)
        
        // 中继模式选择
        relayModeSegmentedControl.selectedSegmentIndex = 1 // 默认一对多
        
        // 控制按钮
        startRelayButton.setTitle("开始中继", for: .normal)
        startRelayButton.backgroundColor = .systemGreen
        startRelayButton.setTitleColor(.white, for: .normal)
        startRelayButton.layer.cornerRadius = 8
        startRelayButton.addTarget(self, action: #selector(startRelayButtonTapped), for: .touchUpInside)
        
        stopRelayButton.setTitle("停止中继", for: .normal)
        stopRelayButton.backgroundColor = .systemRed
        stopRelayButton.setTitleColor(.white, for: .normal)
        stopRelayButton.layer.cornerRadius = 8
        stopRelayButton.addTarget(self, action: #selector(stopRelayButtonTapped), for: .touchUpInside)
        
        pauseResumeButton.setTitle("暂停中继", for: .normal)
        pauseResumeButton.backgroundColor = .systemOrange
        pauseResumeButton.setTitleColor(.white, for: .normal)
        pauseResumeButton.layer.cornerRadius = 8
        pauseResumeButton.addTarget(self, action: #selector(pauseResumeButtonTapped), for: .touchUpInside)
        
        // 状态显示
        statusLabel.text = "未开始中继"
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .systemGray
        
        // 状态信息视图
        statusInfoView.backgroundColor = .systemGray6
        statusInfoView.layer.cornerRadius = 8
        statusInfoView.isHidden = true
        
        statusInfoLabel.numberOfLines = 0
        statusInfoLabel.font = .systemFont(ofSize: 14)
        statusInfoLabel.textColor = .label
        
        // 统计信息视图
        statsView.backgroundColor = .systemGray6
        statsView.layer.cornerRadius = 8
        statsView.isHidden = true
        
        statsLabel.numberOfLines = 0
        statsLabel.font = .systemFont(ofSize: 14)
        statsLabel.textColor = .label
        
        // 堆栈视图配置
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
    }
    
    private func setupTableView() {
        targetChannelsTableView.delegate = self
        targetChannelsTableView.dataSource = self
        targetChannelsTableView.register(MediaRelayChannelCell.self, forCellReuseIdentifier: "ChannelCell")
        targetChannelsTableView.separatorStyle = .none
    }
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        statusInfoView.addSubview(statusInfoLabel)
        statsView.addSubview(statsLabel)
        
        // 添加到堆栈视图
        stackView.addArrangedSubview(titleLabel)
        
        // 源频道配置
        stackView.addArrangedSubview(createSectionView(title: "源频道配置", content: [
            sourceChannelTextField,
            sourceTokenTextField
        ]))
        
        // 中继模式
        stackView.addArrangedSubview(createSectionView(title: "中继模式", content: [
            createLabeledControl(label: "模式选择", control: relayModeSegmentedControl)
        ]))
        
        // 目标频道管理
        stackView.addArrangedSubview(createSectionView(title: "目标频道管理", content: [
            targetChannelsTableView,
            addChannelButton
        ]))
        
        // 控制按钮
        let buttonStack1 = UIStackView(arrangedSubviews: [startRelayButton, stopRelayButton])
        buttonStack1.axis = .horizontal
        buttonStack1.spacing = 12
        buttonStack1.distribution = .fillEqually
        
        stackView.addArrangedSubview(createSectionView(title: "中继控制", content: [buttonStack1, pauseResumeButton]))
        
        // 状态信息
        stackView.addArrangedSubview(createSectionView(title: "中继状态", content: [statusLabel, statusInfoView]))
        
        // 统计信息
        stackView.addArrangedSubview(createSectionView(title: "统计信息", content: [statsView]))
        
        // 约束设置
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        statusInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            targetChannelsTableView.heightAnchor.constraint(equalToConstant: 200),
            
            statusInfoLabel.topAnchor.constraint(equalTo: statusInfoView.topAnchor, constant: 12),
            statusInfoLabel.leadingAnchor.constraint(equalTo: statusInfoView.leadingAnchor, constant: 12),
            statusInfoLabel.trailingAnchor.constraint(equalTo: statusInfoView.trailingAnchor, constant: -12),
            statusInfoLabel.bottomAnchor.constraint(equalTo: statusInfoView.bottomAnchor, constant: -12),
            
            statsLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 12),
            statsLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 12),
            statsLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -12),
            statsLabel.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -12),
            
            startRelayButton.heightAnchor.constraint(equalToConstant: 44),
            stopRelayButton.heightAnchor.constraint(equalToConstant: 44),
            pauseResumeButton.heightAnchor.constraint(equalToConstant: 44),
            addChannelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func createLabeledControl(label: String, control: UIView) -> UIView {
        let containerView = UIView()
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, control])
        stackView.axis = .vertical
        stackView.spacing = 8
        
        containerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    private func createSectionView(title: String, content: [UIView]) -> UIView {
        let sectionView = UIView()
        let sectionTitle = UILabel()
        let sectionStack = UIStackView()
        
        sectionTitle.text = title
        sectionTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        sectionTitle.textColor = .label
        
        sectionStack.axis = .vertical
        sectionStack.spacing = 12
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
    
    private func loadSampleData() {
        targetChannels = [
            try! RelayChannelInfo(
                channelName: "target_channel_1",
                token: "target_token_1",
                userId: "demo_user_1",
                uid: 12345,
                state: .idle
            ),
            try! RelayChannelInfo(
                channelName: "target_channel_2",
                token: "target_token_2",
                userId: "demo_user_2",
                uid: 12346,
                state: .idle
            )
        ]
        targetChannelsTableView.reloadData()
    }
    
    private func observeRealtimeManager() {
        // 监听媒体中继状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mediaRelayStateDidChange),
            name: NSNotification.Name("RealtimeManager.mediaRelayStateDidChange"),
            object: nil
        )
    }
    
    @objc private func mediaRelayStateDidChange() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    private func updateUI() {
        let mediaRelayState = RealtimeManager.shared.mediaRelayState
        
        if let state = mediaRelayState {
            switch state.overallState {
            case .idle:
                statusLabel.text = "未开始中继"
                statusLabel.textColor = .systemGray
                startRelayButton.isEnabled = !targetChannels.isEmpty
                stopRelayButton.isEnabled = false
                pauseResumeButton.isEnabled = false
                statusInfoView.isHidden = true
                statsView.isHidden = true
                
            case .connecting:
                statusLabel.text = "正在连接..."
                statusLabel.textColor = .systemOrange
                startRelayButton.isEnabled = false
                stopRelayButton.isEnabled = false
                pauseResumeButton.isEnabled = false
                
            case .running:
                statusLabel.text = "中继运行中"
                statusLabel.textColor = .systemGreen
                startRelayButton.isEnabled = false
                stopRelayButton.isEnabled = true
                pauseResumeButton.isEnabled = true
                pauseResumeButton.setTitle("暂停中继", for: .normal)
                statusInfoView.isHidden = false
                statsView.isHidden = false
                
                updateStatusInfo(state)
                updateStatsInfo()
                
            case .paused:
                statusLabel.text = "中继已暂停"
                statusLabel.textColor = .systemOrange
                startRelayButton.isEnabled = false
                stopRelayButton.isEnabled = true
                pauseResumeButton.isEnabled = true
                pauseResumeButton.setTitle("恢复中继", for: .normal)
                
            case .error(let error):
                statusLabel.text = "中继错误"
                statusLabel.textColor = .systemRed
                startRelayButton.isEnabled = true
                stopRelayButton.isEnabled = false
                pauseResumeButton.isEnabled = false
                statusInfoView.isHidden = false
                
                statusInfoLabel.text = "错误信息: \(error.localizedDescription)"
            }
        } else {
            statusLabel.text = "未开始中继"
            statusLabel.textColor = .systemGray
            startRelayButton.isEnabled = !targetChannels.isEmpty
            stopRelayButton.isEnabled = false
            pauseResumeButton.isEnabled = false
            statusInfoView.isHidden = true
            statsView.isHidden = true
        }
        
        targetChannelsTableView.reloadData()
    }
    
    private func updateStatusInfo(_ state: MediaRelayState) {
        let mode = getSelectedModeName()
        let activeChannels = state.channelStates.filter { $0.value == .running }.count
        let totalChannels = state.channelStates.count
        
        statusInfoLabel.text = """
        源频道: \(sourceChannelTextField.text ?? "")
        中继模式: \(mode)
        活跃频道: \(activeChannels)/\(totalChannels)
        开始时间: \(formatDate(Date()))
        """
    }
    
    private func updateStatsInfo() {
        // 模拟统计数据
        let stats = MediaRelayStats(
            totalDataTransferred: Int64.random(in: 1000000...10000000),
            averageBitrate: Int.random(in: 1000...5000),
            packetsLost: Int.random(in: 0...100),
            latency: Int.random(in: 10...100)
        )
        
        statsLabel.text = """
        数据传输: \(formatBytes(stats.totalDataTransferred))
        平均码率: \(stats.averageBitrate) kbps
        丢包数: \(stats.packetsLost)
        延迟: \(stats.latency) ms
        运行时长: \(formatDuration(60)) // 模拟1分钟
        """
        
        self.relayStats = stats
    }
    
    private func getSelectedModeName() -> String {
        switch relayModeSegmentedControl.selectedSegmentIndex {
        case 0: return "一对一"
        case 1: return "一对多"
        case 2: return "多对多"
        default: return "一对多"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - 控件事件处理
    @objc private func addChannelButtonTapped() {
        showAddChannelDialog()
    }
    
    @objc private func startRelayButtonTapped() {
        guard let sourceChannel = sourceChannelTextField.text, !sourceChannel.isEmpty else {
            showAlert(title: "错误", message: "请输入源频道名称")
            return
        }
        
        guard !targetChannels.isEmpty else {
            showAlert(title: "错误", message: "请至少添加一个目标频道")
            return
        }
        
        let config = try! MediaRelayConfig(
            sourceChannel: try! RelayChannelInfo(
                channelName: sourceChannel,
                token: sourceTokenTextField.text ?? "",
                userId: "demo_source_user",
                uid: 0,
                state: .idle
            ),
            destinationChannels: targetChannels,
            relayMode: getSelectedRelayMode()
        )
        
        Task {
            do {
                try await RealtimeManager.shared.startMediaRelay(config: config)
                await MainActor.run {
                    self.showAlert(title: "成功", message: "媒体中继启动成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "启动失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func stopRelayButtonTapped() {
        Task {
            do {
                try await RealtimeManager.shared.stopMediaRelay()
                await MainActor.run {
                    self.showAlert(title: "成功", message: "媒体中继停止成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "停止失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func pauseResumeButtonTapped() {
        let isPaused = pauseResumeButton.titleLabel?.text == "恢复中继"
        
        if isPaused {
            // 恢复中继
            Task {
                do {
                    for channel in targetChannels {
                        try await RealtimeManager.shared.resumeMediaRelay(toChannel: channel.channelName)
                    }
                    await MainActor.run {
                        self.showAlert(title: "成功", message: "媒体中继恢复成功")
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "恢复失败", message: error.localizedDescription)
                    }
                }
            }
        } else {
            // 暂停中继
            Task {
                do {
                    for channel in targetChannels {
                        try await RealtimeManager.shared.pauseMediaRelay(toChannel: channel.channelName)
                    }
                    await MainActor.run {
                        self.showAlert(title: "成功", message: "媒体中继暂停成功")
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "暂停失败", message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func getSelectedRelayMode() -> MediaRelayMode {
        switch relayModeSegmentedControl.selectedSegmentIndex {
        case 0: return .oneToOne
        case 1: return .oneToMany
        case 2: return .manyToMany
        default: return .oneToMany
        }
    }
    
    private func showAddChannelDialog() {
        let alert = UIAlertController(title: "添加目标频道", message: "请输入频道信息", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "频道名称"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Token"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "用户ID"
            textField.keyboardType = .numberPad
        }
        
        let addAction = UIAlertAction(title: "添加", style: .default) { _ in
            guard let channelName = alert.textFields?[0].text, !channelName.isEmpty,
                  let token = alert.textFields?[1].text,
                  let uidText = alert.textFields?[2].text, let uid = UInt(uidText) else {
                self.showAlert(title: "错误", message: "请填写完整的频道信息")
                return
            }
            
            let channelInfo = try! RelayChannelInfo(
                channelName: channelName,
                token: token,
                userId: "demo_user_\(uid)",
                uid: uid,
                state: .idle
            )
            
            self.targetChannels.append(channelInfo)
            self.targetChannelsTableView.reloadData()
            self.updateUI()
        }
        
        alert.addAction(addAction)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
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
extension MediaRelayDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return targetChannels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChannelCell", for: indexPath) as! MediaRelayChannelCell
        cell.configure(with: targetChannels[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            targetChannels.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            updateUI()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return targetChannels.isEmpty ? "暂无目标频道" : "目标频道列表 (\(targetChannels.count))"
    }
}

// MARK: - 媒体中继频道信息单元格
class MediaRelayChannelCell: UITableViewCell {
    
    private let channelNameLabel = UILabel()
    private let uidLabel = UILabel()
    private let stateLabel = UILabel()
    private let stateIndicator = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 频道名称
        channelNameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        channelNameLabel.textColor = .label
        
        // 用户ID
        uidLabel.font = .systemFont(ofSize: 14)
        uidLabel.textColor = .secondaryLabel
        
        // 状态标签
        stateLabel.font = .systemFont(ofSize: 12)
        stateLabel.textColor = .secondaryLabel
        
        // 状态指示器
        stateIndicator.layer.cornerRadius = 4
        stateIndicator.widthAnchor.constraint(equalToConstant: 8).isActive = true
        stateIndicator.heightAnchor.constraint(equalToConstant: 8).isActive = true
        
        // 布局
        let leftStack = UIStackView(arrangedSubviews: [channelNameLabel, uidLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 2
        
        let rightStack = UIStackView(arrangedSubviews: [stateIndicator, stateLabel])
        rightStack.axis = .horizontal
        rightStack.spacing = 6
        rightStack.alignment = .center
        
        let mainStack = UIStackView(arrangedSubviews: [leftStack, rightStack])
        mainStack.axis = .horizontal
        mainStack.distribution = .equalSpacing
        mainStack.alignment = .center
        
        contentView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with channelInfo: RelayChannelInfo) {
        channelNameLabel.text = channelInfo.channelName
        uidLabel.text = "UID: \(channelInfo.uid)"
        
        switch channelInfo.state {
        case .idle:
            stateLabel.text = "空闲"
            stateIndicator.backgroundColor = .systemGray
        case .connecting:
            stateLabel.text = "连接中"
            stateIndicator.backgroundColor = .systemOrange
        case .running:
            stateLabel.text = "运行中"
            stateIndicator.backgroundColor = .systemGreen
        case .paused:
            stateLabel.text = "已暂停"
            stateIndicator.backgroundColor = .systemYellow
        case .error:
            stateLabel.text = "错误"
            stateIndicator.backgroundColor = .systemRed
        }
    }
}