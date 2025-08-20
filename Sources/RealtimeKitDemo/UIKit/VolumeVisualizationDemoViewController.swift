import UIKit
import RealtimeCore

// MARK: - 音量可视化演示界面
class VolumeVisualizationDemoViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // UI 组件
    private let titleLabel = UILabel()
    private let enableVolumeSwitch = UISwitch()
    private let enableVolumeLabel = UILabel()
    
    // 配置控件
    private let intervalSlider = UISlider()
    private let intervalLabel = UILabel()
    private let intervalValueLabel = UILabel()
    
    private let thresholdSlider = UISlider()
    private let thresholdLabel = UILabel()
    private let thresholdValueLabel = UILabel()
    
    private let smoothFactorSlider = UISlider()
    private let smoothFactorLabel = UILabel()
    private let smoothFactorValueLabel = UILabel()
    
    // 音量显示
    private let volumeVisualizationView = VolumeVisualizationView()
    private let speakingUsersLabel = UILabel()
    private let dominantSpeakerLabel = UILabel()
    
    // 统计信息
    private let statsView = UIView()
    private let statsLabel = UILabel()
    
    // 模拟用户数据
    private var simulatedUsers = ["用户1", "用户2", "用户3", "当前用户"]
    private var simulationTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        updateUI()
        observeRealtimeManager()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSimulation()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "音量可视化演示"
        
        // 标题
        titleLabel.text = "音量检测与可视化"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 音量检测开关
        enableVolumeLabel.text = "启用音量检测"
        enableVolumeLabel.font = .systemFont(ofSize: 16, weight: .medium)
        enableVolumeSwitch.addTarget(self, action: #selector(enableVolumeSwitchChanged), for: .valueChanged)
        
        // 配置滑块
        setupConfigSlider(intervalSlider, label: intervalLabel, valueLabel: intervalValueLabel,
                         title: "检测间隔 (ms)", min: 100, max: 1000, value: 300,
                         action: #selector(intervalSliderChanged))
        
        setupConfigSlider(thresholdSlider, label: thresholdLabel, valueLabel: thresholdValueLabel,
                         title: "说话阈值", min: 0.1, max: 0.8, value: 0.3,
                         action: #selector(thresholdSliderChanged))
        
        setupConfigSlider(smoothFactorSlider, label: smoothFactorLabel, valueLabel: smoothFactorValueLabel,
                         title: "平滑因子", min: 0.1, max: 1.0, value: 0.3,
                         action: #selector(smoothFactorSliderChanged))
        
        // 音量可视化视图
        volumeVisualizationView.backgroundColor = .systemGray6
        volumeVisualizationView.layer.cornerRadius = 12
        
        // 说话用户显示
        speakingUsersLabel.text = "说话用户: 无"
        speakingUsersLabel.font = .systemFont(ofSize: 16, weight: .medium)
        speakingUsersLabel.numberOfLines = 0
        
        dominantSpeakerLabel.text = "主讲人: 无"
        dominantSpeakerLabel.font = .systemFont(ofSize: 16, weight: .medium)
        dominantSpeakerLabel.textColor = .systemBlue
        
        // 统计信息视图
        statsView.backgroundColor = .systemGray6
        statsView.layer.cornerRadius = 8
        
        statsLabel.numberOfLines = 0
        statsLabel.font = .systemFont(ofSize: 14)
        statsLabel.textColor = .label
        
        // 堆栈视图配置
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
    }
    
    private func setupConfigSlider(_ slider: UISlider, label: UILabel, valueLabel: UILabel, 
                                  title: String, min: Float, max: Float, value: Float, action: Selector) {
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.addTarget(self, action: action, for: .valueChanged)
        
        if title.contains("间隔") {
            valueLabel.text = "\(Int(value))"
        } else {
            valueLabel.text = String(format: "%.1f", value)
        }
        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = .systemBlue
        valueLabel.textAlignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        statsView.addSubview(statsLabel)
        
        // 添加到堆栈视图
        stackView.addArrangedSubview(titleLabel)
        
        // 音量检测开关
        let enableControl = createControlRow(label: enableVolumeLabel, control: enableVolumeSwitch)
        stackView.addArrangedSubview(createSectionView(title: "音量检测", content: [enableControl]))
        
        // 配置控制
        let intervalControl = createSliderRow(label: intervalLabel, slider: intervalSlider, valueLabel: intervalValueLabel)
        let thresholdControl = createSliderRow(label: thresholdLabel, slider: thresholdSlider, valueLabel: thresholdValueLabel)
        let smoothControl = createSliderRow(label: smoothFactorLabel, slider: smoothFactorSlider, valueLabel: smoothFactorValueLabel)
        
        stackView.addArrangedSubview(createSectionView(title: "检测配置", content: [intervalControl, thresholdControl, smoothControl]))
        
        // 音量可视化
        stackView.addArrangedSubview(createSectionView(title: "音量可视化", content: [volumeVisualizationView]))
        
        // 说话状态
        stackView.addArrangedSubview(createSectionView(title: "说话状态", content: [speakingUsersLabel, dominantSpeakerLabel]))
        
        // 统计信息
        stackView.addArrangedSubview(createSectionView(title: "统计信息", content: [statsView]))
        
        // 约束设置
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
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
            
            volumeVisualizationView.heightAnchor.constraint(equalToConstant: 200),
            
            statsLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 12),
            statsLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 12),
            statsLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -12),
            statsLabel.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -12)
        ])
    }
    
    private func createControlRow(label: UILabel, control: UIView) -> UIView {
        let containerView = UIView()
        let stackView = UIStackView(arrangedSubviews: [label, control])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        
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
    
    private func createSliderRow(label: UILabel, slider: UISlider, valueLabel: UILabel) -> UIView {
        let containerView = UIView()
        let labelStack = UIStackView(arrangedSubviews: [label, valueLabel])
        labelStack.axis = .horizontal
        labelStack.distribution = .equalSpacing
        
        let mainStack = UIStackView(arrangedSubviews: [labelStack, slider])
        mainStack.axis = .vertical
        mainStack.spacing = 8
        
        containerView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
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
    
    private func observeRealtimeManager() {
        // 监听音量信息变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeInfoDidChange),
            name: NSNotification.Name("RealtimeManager.volumeInfoDidChange"),
            object: nil
        )
    }
    
    @objc private func volumeInfoDidChange() {
        DispatchQueue.main.async {
            self.updateVolumeDisplay()
        }
    }
    
    private func updateUI() {
        // 更新配置显示
        intervalValueLabel.text = "\(Int(intervalSlider.value))"
        thresholdValueLabel.text = String(format: "%.1f", thresholdSlider.value)
        smoothFactorValueLabel.text = String(format: "%.1f", smoothFactorSlider.value)
        
        updateVolumeDisplay()
    }
    
    private func updateVolumeDisplay() {
        let volumeInfos = RealtimeManager.shared.volumeInfos
        let speakingUsers = RealtimeManager.shared.speakingUsers
        let dominantSpeaker = RealtimeManager.shared.dominantSpeaker
        
        // 更新可视化视图
        volumeVisualizationView.updateVolumeInfos(volumeInfos)
        
        // 更新说话用户显示
        if speakingUsers.isEmpty {
            speakingUsersLabel.text = "说话用户: 无"
        } else {
            speakingUsersLabel.text = "说话用户: \(Array(speakingUsers).joined(separator: ", "))"
        }
        
        // 更新主讲人显示
        if let dominantSpeaker = dominantSpeaker {
            dominantSpeakerLabel.text = "主讲人: \(dominantSpeaker)"
        } else {
            dominantSpeakerLabel.text = "主讲人: 无"
        }
        
        // 更新统计信息
        let totalUsers = volumeInfos.count
        let speakingCount = speakingUsers.count
        let averageVolume = volumeInfos.isEmpty ? 0.0 : volumeInfos.map { $0.volume }.reduce(0, +) / Float(volumeInfos.count)
        
        statsLabel.text = """
        总用户数: \(totalUsers)
        说话用户数: \(speakingCount)
        平均音量: \(String(format: "%.2f", averageVolume))
        检测间隔: \(Int(intervalSlider.value))ms
        说话阈值: \(String(format: "%.1f", thresholdSlider.value))
        平滑因子: \(String(format: "%.1f", smoothFactorSlider.value))
        """
    }
    
    // MARK: - 控件事件处理
    @objc private func enableVolumeSwitchChanged() {
        if enableVolumeSwitch.isOn {
            startVolumeDetection()
            startSimulation()
        } else {
            stopVolumeDetection()
            stopSimulation()
        }
    }
    
    @objc private func intervalSliderChanged() {
        intervalValueLabel.text = "\(Int(intervalSlider.value))"
        updateVolumeDetectionConfig()
    }
    
    @objc private func thresholdSliderChanged() {
        thresholdValueLabel.text = String(format: "%.1f", thresholdSlider.value)
        updateVolumeDetectionConfig()
    }
    
    @objc private func smoothFactorSliderChanged() {
        smoothFactorValueLabel.text = String(format: "%.1f", smoothFactorSlider.value)
        updateVolumeDetectionConfig()
    }
    
    private func startVolumeDetection() {
        let config = VolumeDetectionConfig(
            detectionInterval: Int(intervalSlider.value),
            speakingThreshold: thresholdSlider.value,
            silenceThreshold: 0.05,
            includeLocalUser: true,
            smoothFactor: smoothFactorSlider.value
        )
        
        Task {
            do {
                try await RealtimeManager.shared.enableVolumeIndicator(config: config)
            } catch {
                await MainActor.run {
                    self.showAlert(title: "启用失败", message: error.localizedDescription)
                    self.enableVolumeSwitch.isOn = false
                }
            }
        }
    }
    
    private func stopVolumeDetection() {
        Task {
            do {
                try await RealtimeManager.shared.disableVolumeIndicator()
            } catch {
                await MainActor.run {
                    self.showAlert(title: "停用失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateVolumeDetectionConfig() {
        if enableVolumeSwitch.isOn {
            startVolumeDetection()
        }
    }
    
    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSlider.value) / 1000.0, repeats: true) { _ in
            self.generateSimulatedVolumeData()
        }
    }
    
    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        volumeVisualizationView.updateVolumeInfos([])
        updateVolumeDisplay()
    }
    
    private func generateSimulatedVolumeData() {
        let volumeInfos = simulatedUsers.map { userId in
            let volume = Float.random(in: 0.0...1.0)
            let isSpeaking = volume > thresholdSlider.value
            return UserVolumeInfo(userId: userId, volume: volume, isSpeaking: isSpeaking)
        }
        
        // 模拟 RealtimeManager 的音量更新
        DispatchQueue.main.async {
            // 这里应该通过 RealtimeManager 更新，但为了演示直接更新UI
            self.volumeVisualizationView.updateVolumeInfos(volumeInfos)
            
            let speakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
            let dominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
            
            if speakingUsers.isEmpty {
                self.speakingUsersLabel.text = "说话用户: 无"
            } else {
                self.speakingUsersLabel.text = "说话用户: \(Array(speakingUsers).joined(separator: ", "))"
            }
            
            if let dominantSpeaker = dominantSpeaker {
                self.dominantSpeakerLabel.text = "主讲人: \(dominantSpeaker)"
            } else {
                self.dominantSpeakerLabel.text = "主讲人: 无"
            }
            
            self.updateUI()
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopSimulation()
    }
}

// MARK: - 音量可视化视图
class VolumeVisualizationView: UIView {
    
    private var volumeInfos: [UserVolumeInfo] = []
    private var volumeBars: [UIView] = []
    private var userLabels: [UILabel] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 12
    }
    
    func updateVolumeInfos(_ infos: [UserVolumeInfo]) {
        volumeInfos = infos
        setupVolumeVisualization()
    }
    
    private func setupVolumeVisualization() {
        // 清除现有视图
        volumeBars.forEach { $0.removeFromSuperview() }
        userLabels.forEach { $0.removeFromSuperview() }
        volumeBars.removeAll()
        userLabels.removeAll()
        
        guard !volumeInfos.isEmpty else { return }
        
        let barWidth: CGFloat = 40
        let barSpacing: CGFloat = 20
        let totalWidth = CGFloat(volumeInfos.count) * barWidth + CGFloat(volumeInfos.count - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        
        for (index, volumeInfo) in volumeInfos.enumerated() {
            let x = startX + CGFloat(index) * (barWidth + barSpacing)
            
            // 创建用户标签
            let userLabel = UILabel()
            userLabel.text = volumeInfo.userId
            userLabel.font = .systemFont(ofSize: 12)
            userLabel.textAlignment = .center
            userLabel.textColor = volumeInfo.isSpeaking ? .systemBlue : .label
            userLabel.frame = CGRect(x: x, y: 10, width: barWidth, height: 20)
            addSubview(userLabel)
            userLabels.append(userLabel)
            
            // 创建音量条背景
            let barBackground = UIView()
            barBackground.backgroundColor = .systemGray4
            barBackground.layer.cornerRadius = 4
            barBackground.frame = CGRect(x: x, y: 40, width: barWidth, height: 120)
            addSubview(barBackground)
            
            // 创建音量条
            let volumeBar = UIView()
            let barHeight = CGFloat(volumeInfo.volume) * 120
            volumeBar.backgroundColor = volumeInfo.isSpeaking ? .systemGreen : .systemBlue
            volumeBar.layer.cornerRadius = 4
            volumeBar.frame = CGRect(x: x, y: 40 + (120 - barHeight), width: barWidth, height: barHeight)
            addSubview(volumeBar)
            volumeBars.append(volumeBar)
            
            // 添加音量值标签
            let volumeLabel = UILabel()
            volumeLabel.text = String(format: "%.2f", volumeInfo.volume)
            volumeLabel.font = .systemFont(ofSize: 10)
            volumeLabel.textAlignment = .center
            volumeLabel.textColor = .secondaryLabel
            volumeLabel.frame = CGRect(x: x, y: 170, width: barWidth, height: 15)
            addSubview(volumeLabel)
            
            // 添加动画效果
            if volumeInfo.isSpeaking {
                addPulseAnimation(to: volumeBar)
            }
        }
    }
    
    private func addPulseAnimation(to view: UIView) {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 0.5
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.1
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        view.layer.add(pulseAnimation, forKey: "pulse")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !volumeInfos.isEmpty {
            setupVolumeVisualization()
        }
    }
}