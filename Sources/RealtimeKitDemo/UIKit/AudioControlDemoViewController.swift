import UIKit
import RealtimeCore

// MARK: - 音频控制演示界面
class AudioControlDemoViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // UI 组件
    private let titleLabel = UILabel()
    
    // 麦克风控制
    private let microphoneSwitch = UISwitch()
    private let microphoneLabel = UILabel()
    
    // 音频流控制
    private let audioStreamSwitch = UISwitch()
    private let audioStreamLabel = UILabel()
    
    // 音量控制
    private let audioMixingSlider = UISlider()
    private let audioMixingLabel = UILabel()
    private let audioMixingValueLabel = UILabel()
    
    private let playbackSlider = UISlider()
    private let playbackLabel = UILabel()
    private let playbackValueLabel = UILabel()
    
    private let recordingSlider = UISlider()
    private let recordingLabel = UILabel()
    private let recordingValueLabel = UILabel()
    
    // 音频设置信息
    private let settingsInfoView = UIView()
    private let settingsInfoLabel = UILabel()
    
    // 快速设置按钮
    private let muteAllButton = UIButton(type: .system)
    private let resetSettingsButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        updateUI()
        observeRealtimeManager()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "音频控制演示"
        
        // 标题
        titleLabel.text = "音频控制功能"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 麦克风控制
        microphoneLabel.text = "麦克风"
        microphoneLabel.font = .systemFont(ofSize: 16, weight: .medium)
        microphoneSwitch.addTarget(self, action: #selector(microphoneSwitchChanged), for: .valueChanged)
        
        // 音频流控制
        audioStreamLabel.text = "本地音频流"
        audioStreamLabel.font = .systemFont(ofSize: 16, weight: .medium)
        audioStreamSwitch.addTarget(self, action: #selector(audioStreamSwitchChanged), for: .valueChanged)
        
        // 音量控制滑块
        setupVolumeSlider(audioMixingSlider, label: audioMixingLabel, valueLabel: audioMixingValueLabel, 
                         title: "混音音量", action: #selector(audioMixingSliderChanged))
        setupVolumeSlider(playbackSlider, label: playbackLabel, valueLabel: playbackValueLabel,
                         title: "播放音量", action: #selector(playbackSliderChanged))
        setupVolumeSlider(recordingSlider, label: recordingLabel, valueLabel: recordingValueLabel,
                         title: "录制音量", action: #selector(recordingSliderChanged))
        
        // 设置信息视图
        settingsInfoView.backgroundColor = .systemGray6
        settingsInfoView.layer.cornerRadius = 8
        
        settingsInfoLabel.numberOfLines = 0
        settingsInfoLabel.font = .systemFont(ofSize: 14)
        settingsInfoLabel.textColor = .label
        
        // 快速设置按钮
        muteAllButton.setTitle("全部静音", for: .normal)
        muteAllButton.backgroundColor = .systemOrange
        muteAllButton.setTitleColor(.white, for: .normal)
        muteAllButton.layer.cornerRadius = 8
        muteAllButton.addTarget(self, action: #selector(muteAllButtonTapped), for: .touchUpInside)
        
        resetSettingsButton.setTitle("重置设置", for: .normal)
        resetSettingsButton.backgroundColor = .systemGray
        resetSettingsButton.setTitleColor(.white, for: .normal)
        resetSettingsButton.layer.cornerRadius = 8
        resetSettingsButton.addTarget(self, action: #selector(resetSettingsButtonTapped), for: .touchUpInside)
        
        // 堆栈视图配置
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
    }
    
    private func setupVolumeSlider(_ slider: UISlider, label: UILabel, valueLabel: UILabel, title: String, action: Selector) {
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 100
        slider.addTarget(self, action: action, for: .valueChanged)
        
        valueLabel.text = "100"
        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = .systemBlue
        valueLabel.textAlignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
    }
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        settingsInfoView.addSubview(settingsInfoLabel)
        
        // 添加到堆栈视图
        stackView.addArrangedSubview(titleLabel)
        
        // 麦克风和音频流控制
        let microphoneControl = createControlRow(label: microphoneLabel, control: microphoneSwitch)
        let audioStreamControl = createControlRow(label: audioStreamLabel, control: audioStreamSwitch)
        
        stackView.addArrangedSubview(createSectionView(title: "音频开关", content: [microphoneControl, audioStreamControl]))
        
        // 音量控制
        let audioMixingControl = createSliderRow(label: audioMixingLabel, slider: audioMixingSlider, valueLabel: audioMixingValueLabel)
        let playbackControl = createSliderRow(label: playbackLabel, slider: playbackSlider, valueLabel: playbackValueLabel)
        let recordingControl = createSliderRow(label: recordingLabel, slider: recordingSlider, valueLabel: recordingValueLabel)
        
        stackView.addArrangedSubview(createSectionView(title: "音量控制", content: [audioMixingControl, playbackControl, recordingControl]))
        
        // 快速设置
        let buttonStack = UIStackView(arrangedSubviews: [muteAllButton, resetSettingsButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        stackView.addArrangedSubview(createSectionView(title: "快速设置", content: [buttonStack]))
        
        // 设置信息
        stackView.addArrangedSubview(createSectionView(title: "当前设置", content: [settingsInfoView]))
        
        // 约束设置
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        settingsInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            settingsInfoLabel.topAnchor.constraint(equalTo: settingsInfoView.topAnchor, constant: 12),
            settingsInfoLabel.leadingAnchor.constraint(equalTo: settingsInfoView.leadingAnchor, constant: 12),
            settingsInfoLabel.trailingAnchor.constraint(equalTo: settingsInfoView.trailingAnchor, constant: -12),
            settingsInfoLabel.bottomAnchor.constraint(equalTo: settingsInfoView.bottomAnchor, constant: -12),
            
            muteAllButton.heightAnchor.constraint(equalToConstant: 44),
            resetSettingsButton.heightAnchor.constraint(equalToConstant: 44)
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
        // 监听音频设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSettingsDidChange),
            name: NSNotification.Name("RealtimeManager.audioSettingsDidChange"),
            object: nil
        )
    }
    
    @objc private func audioSettingsDidChange() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    private func updateUI() {
        let audioSettings = RealtimeManager.shared.audioSettings
        
        // 更新开关状态
        microphoneSwitch.isOn = !audioSettings.microphoneMuted
        audioStreamSwitch.isOn = audioSettings.localAudioStreamActive
        
        // 更新滑块值
        audioMixingSlider.value = Float(audioSettings.audioMixingVolume)
        audioMixingValueLabel.text = "\(audioSettings.audioMixingVolume)"
        
        playbackSlider.value = Float(audioSettings.playbackSignalVolume)
        playbackValueLabel.text = "\(audioSettings.playbackSignalVolume)"
        
        recordingSlider.value = Float(audioSettings.recordingSignalVolume)
        recordingValueLabel.text = "\(audioSettings.recordingSignalVolume)"
        
        // 更新设置信息
        settingsInfoLabel.text = """
        麦克风: \(audioSettings.microphoneMuted ? "静音" : "开启")
        本地音频流: \(audioSettings.localAudioStreamActive ? "活跃" : "停止")
        混音音量: \(audioSettings.audioMixingVolume)%
        播放音量: \(audioSettings.playbackSignalVolume)%
        录制音量: \(audioSettings.recordingSignalVolume)%
        最后修改: \(formatDate(audioSettings.lastModified))
        """
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - 控件事件处理
    @objc private func microphoneSwitchChanged() {
        Task {
            do {
                try await RealtimeManager.shared.muteMicrophone(!microphoneSwitch.isOn)
            } catch {
                await MainActor.run {
                    self.showAlert(title: "操作失败", message: error.localizedDescription)
                    self.updateUI() // 恢复UI状态
                }
            }
        }
    }
    
    @objc private func audioStreamSwitchChanged() {
        Task {
            do {
                if audioStreamSwitch.isOn {
                    try await RealtimeManager.shared.resumeLocalAudioStream()
                } else {
                    try await RealtimeManager.shared.stopLocalAudioStream()
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "操作失败", message: error.localizedDescription)
                    self.updateUI() // 恢复UI状态
                }
            }
        }
    }
    
    @objc private func audioMixingSliderChanged() {
        let value = Int(audioMixingSlider.value)
        audioMixingValueLabel.text = "\(value)"
        
        Task {
            do {
                try await RealtimeManager.shared.setAudioMixingVolume(value)
            } catch {
                await MainActor.run {
                    self.showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func playbackSliderChanged() {
        let value = Int(playbackSlider.value)
        playbackValueLabel.text = "\(value)"
        
        Task {
            do {
                try await RealtimeManager.shared.setPlaybackSignalVolume(value)
            } catch {
                await MainActor.run {
                    self.showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func recordingSliderChanged() {
        let value = Int(recordingSlider.value)
        recordingValueLabel.text = "\(value)"
        
        Task {
            do {
                try await RealtimeManager.shared.setRecordingSignalVolume(value)
            } catch {
                await MainActor.run {
                    self.showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func muteAllButtonTapped() {
        Task {
            do {
                try await RealtimeManager.shared.muteMicrophone(true)
                try await RealtimeManager.shared.setAudioMixingVolume(0)
                try await RealtimeManager.shared.setPlaybackSignalVolume(0)
                try await RealtimeManager.shared.setRecordingSignalVolume(0)
                
                await MainActor.run {
                    self.showAlert(title: "成功", message: "已全部静音")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "操作失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func resetSettingsButtonTapped() {
        Task {
            do {
                try await RealtimeManager.shared.muteMicrophone(false)
                try await RealtimeManager.shared.resumeLocalAudioStream()
                try await RealtimeManager.shared.setAudioMixingVolume(100)
                try await RealtimeManager.shared.setPlaybackSignalVolume(100)
                try await RealtimeManager.shared.setRecordingSignalVolume(100)
                
                await MainActor.run {
                    self.showAlert(title: "成功", message: "设置已重置为默认值")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "重置失败", message: error.localizedDescription)
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