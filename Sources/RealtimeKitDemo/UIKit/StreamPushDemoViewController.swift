import UIKit
import RealtimeCore

// MARK: - 转推流演示界面
class StreamPushDemoViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // UI 组件
    private let titleLabel = UILabel()
    
    // 推流配置
    private let pushUrlTextField = UITextField()
    private let resolutionSegmentedControl = UISegmentedControl(items: ["720p", "1080p", "4K"])
    private let bitrateSlider = UISlider()
    private let bitrateLabel = UILabel()
    private let bitrateValueLabel = UILabel()
    private let framerateSlider = UISlider()
    private let framerateLabel = UILabel()
    private let framerateValueLabel = UILabel()
    
    // 布局配置
    private let layoutSegmentedControl = UISegmentedControl(items: ["单人", "双人", "四人", "自定义"])
    private let backgroundColorButton = UIButton(type: .system)
    private var selectedBackgroundColor: UIColor = .black
    
    // 控制按钮
    private let startPushButton = UIButton(type: .system)
    private let stopPushButton = UIButton(type: .system)
    private let updateLayoutButton = UIButton(type: .system)
    
    // 状态显示
    private let statusLabel = UILabel()
    private let statusInfoView = UIView()
    private let statusInfoLabel = UILabel()
    
    // 预览视图
    private let previewView = StreamPreviewView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        updateUI()
        observeRealtimeManager()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "转推流演示"
        
        // 标题
        titleLabel.text = "转推流功能"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 推流URL输入
        pushUrlTextField.placeholder = "输入推流URL (rtmp://...)"
        pushUrlTextField.borderStyle = .roundedRect
        pushUrlTextField.text = "rtmp://demo.server.com/live/stream_\(Int.random(in: 1000...9999))"
        
        // 分辨率选择
        resolutionSegmentedControl.selectedSegmentIndex = 0
        
        // 码率控制
        setupSlider(bitrateSlider, label: bitrateLabel, valueLabel: bitrateValueLabel,
                   title: "码率 (kbps)", min: 500, max: 8000, value: 2000,
                   action: #selector(bitrateSliderChanged))
        
        // 帧率控制
        setupSlider(framerateSlider, label: framerateLabel, valueLabel: framerateValueLabel,
                   title: "帧率 (fps)", min: 15, max: 60, value: 30,
                   action: #selector(framerateSliderChanged))
        
        // 布局选择
        layoutSegmentedControl.selectedSegmentIndex = 0
        layoutSegmentedControl.addTarget(self, action: #selector(layoutSegmentedControlChanged), for: .valueChanged)
        
        // 背景颜色选择
        backgroundColorButton.setTitle("选择背景颜色", for: .normal)
        backgroundColorButton.backgroundColor = selectedBackgroundColor
        backgroundColorButton.setTitleColor(.white, for: .normal)
        backgroundColorButton.layer.cornerRadius = 8
        backgroundColorButton.addTarget(self, action: #selector(backgroundColorButtonTapped), for: .touchUpInside)
        
        // 控制按钮
        startPushButton.setTitle("开始推流", for: .normal)
        startPushButton.backgroundColor = .systemGreen
        startPushButton.setTitleColor(.white, for: .normal)
        startPushButton.layer.cornerRadius = 8
        startPushButton.addTarget(self, action: #selector(startPushButtonTapped), for: .touchUpInside)
        
        stopPushButton.setTitle("停止推流", for: .normal)
        stopPushButton.backgroundColor = .systemRed
        stopPushButton.setTitleColor(.white, for: .normal)
        stopPushButton.layer.cornerRadius = 8
        stopPushButton.addTarget(self, action: #selector(stopPushButtonTapped), for: .touchUpInside)
        
        updateLayoutButton.setTitle("更新布局", for: .normal)
        updateLayoutButton.backgroundColor = .systemBlue
        updateLayoutButton.setTitleColor(.white, for: .normal)
        updateLayoutButton.layer.cornerRadius = 8
        updateLayoutButton.addTarget(self, action: #selector(updateLayoutButtonTapped), for: .touchUpInside)
        
        // 状态显示
        statusLabel.text = "未开始推流"
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
        
        // 预览视图
        previewView.backgroundColor = .systemGray6
        previewView.layer.cornerRadius = 12
        
        // 堆栈视图配置
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
    }
    
    private func setupSlider(_ slider: UISlider, label: UILabel, valueLabel: UILabel,
                            title: String, min: Float, max: Float, value: Float, action: Selector) {
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.addTarget(self, action: action, for: .valueChanged)
        
        valueLabel.text = "\(Int(value))"
        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = .systemBlue
        valueLabel.textAlignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
    }
    
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        statusInfoView.addSubview(statusInfoLabel)
        
        // 添加到堆栈视图
        stackView.addArrangedSubview(titleLabel)
        
        // 推流配置
        stackView.addArrangedSubview(createSectionView(title: "推流配置", content: [
            pushUrlTextField,
            createLabeledControl(label: "分辨率", control: resolutionSegmentedControl),
            createSliderRow(label: bitrateLabel, slider: bitrateSlider, valueLabel: bitrateValueLabel),
            createSliderRow(label: framerateLabel, slider: framerateSlider, valueLabel: framerateValueLabel)
        ]))
        
        // 布局配置
        stackView.addArrangedSubview(createSectionView(title: "布局配置", content: [
            createLabeledControl(label: "布局模式", control: layoutSegmentedControl),
            backgroundColorButton
        ]))
        
        // 预览
        stackView.addArrangedSubview(createSectionView(title: "推流预览", content: [previewView]))
        
        // 控制按钮
        let buttonStack = UIStackView(arrangedSubviews: [startPushButton, stopPushButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        stackView.addArrangedSubview(createSectionView(title: "推流控制", content: [buttonStack, updateLayoutButton]))
        
        // 状态信息
        stackView.addArrangedSubview(createSectionView(title: "推流状态", content: [statusLabel, statusInfoView]))
        
        // 约束设置
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        statusInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            previewView.heightAnchor.constraint(equalToConstant: 200),
            
            statusInfoLabel.topAnchor.constraint(equalTo: statusInfoView.topAnchor, constant: 12),
            statusInfoLabel.leadingAnchor.constraint(equalTo: statusInfoView.leadingAnchor, constant: 12),
            statusInfoLabel.trailingAnchor.constraint(equalTo: statusInfoView.trailingAnchor, constant: -12),
            statusInfoLabel.bottomAnchor.constraint(equalTo: statusInfoView.bottomAnchor, constant: -12),
            
            startPushButton.heightAnchor.constraint(equalToConstant: 44),
            stopPushButton.heightAnchor.constraint(equalToConstant: 44),
            updateLayoutButton.heightAnchor.constraint(equalToConstant: 44),
            backgroundColorButton.heightAnchor.constraint(equalToConstant: 44)
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
        // 监听推流状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(streamPushStateDidChange),
            name: NSNotification.Name("RealtimeManager.streamPushStateDidChange"),
            object: nil
        )
    }
    
    @objc private func streamPushStateDidChange() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    private func updateUI() {
        let streamPushState = RealtimeManager.shared.streamPushState
        
        switch streamPushState {
        case .stopped:
            statusLabel.text = "未开始推流"
            statusLabel.textColor = .systemGray
            startPushButton.isEnabled = true
            stopPushButton.isEnabled = false
            updateLayoutButton.isEnabled = false
            statusInfoView.isHidden = true
            
        case .starting:
            statusLabel.text = "正在启动推流..."
            statusLabel.textColor = .systemOrange
            startPushButton.isEnabled = false
            stopPushButton.isEnabled = false
            updateLayoutButton.isEnabled = false
            
        case .running:
            statusLabel.text = "推流中"
            statusLabel.textColor = .systemGreen
            startPushButton.isEnabled = false
            stopPushButton.isEnabled = true
            updateLayoutButton.isEnabled = true
            statusInfoView.isHidden = false
            
            updateStatusInfo()
            
        case .stopping:
            statusLabel.text = "正在停止推流..."
            statusLabel.textColor = .systemOrange
            startPushButton.isEnabled = false
            stopPushButton.isEnabled = false
            updateLayoutButton.isEnabled = false
            
        case .error(let error):
            statusLabel.text = "推流错误"
            statusLabel.textColor = .systemRed
            startPushButton.isEnabled = true
            stopPushButton.isEnabled = false
            updateLayoutButton.isEnabled = false
            statusInfoView.isHidden = false
            
            statusInfoLabel.text = "错误信息: \(error.localizedDescription)"
        }
        
        // 更新预览
        previewView.updateLayout(getSelectedLayout(), backgroundColor: selectedBackgroundColor)
    }
    
    private func updateStatusInfo() {
        let resolution = getSelectedResolution()
        let bitrate = Int(bitrateSlider.value)
        let framerate = Int(framerateSlider.value)
        let layout = getSelectedLayoutName()
        
        statusInfoLabel.text = """
        推流URL: \(pushUrlTextField.text ?? "")
        分辨率: \(resolution.width)x\(resolution.height)
        码率: \(bitrate) kbps
        帧率: \(framerate) fps
        布局: \(layout)
        背景颜色: \(getColorName(selectedBackgroundColor))
        开始时间: \(formatDate(Date()))
        """
    }
    
    private func getSelectedResolution() -> (width: Int, height: Int) {
        switch resolutionSegmentedControl.selectedSegmentIndex {
        case 0: return (1280, 720)   // 720p
        case 1: return (1920, 1080)  // 1080p
        case 2: return (3840, 2160)  // 4K
        default: return (1280, 720)
        }
    }
    
    private func getSelectedLayout() -> StreamLayout {
        switch layoutSegmentedControl.selectedSegmentIndex {
        case 0: return .single
        case 1: return .dual
        case 2: return .quad
        case 3: return .custom([])
        default: return .single
        }
    }
    
    private func getSelectedLayoutName() -> String {
        switch layoutSegmentedControl.selectedSegmentIndex {
        case 0: return "单人布局"
        case 1: return "双人布局"
        case 2: return "四人布局"
        case 3: return "自定义布局"
        default: return "单人布局"
        }
    }
    
    private func getColorName(_ color: UIColor) -> String {
        if color == .black { return "黑色" }
        if color == .white { return "白色" }
        if color == .systemBlue { return "蓝色" }
        if color == .systemGreen { return "绿色" }
        if color == .systemRed { return "红色" }
        return "自定义"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - 控件事件处理
    @objc private func bitrateSliderChanged() {
        bitrateValueLabel.text = "\(Int(bitrateSlider.value))"
    }
    
    @objc private func framerateSliderChanged() {
        framerateValueLabel.text = "\(Int(framerateSlider.value))"
    }
    
    @objc private func layoutSegmentedControlChanged() {
        previewView.updateLayout(getSelectedLayout(), backgroundColor: selectedBackgroundColor)
    }
    
    @objc private func backgroundColorButtonTapped() {
        let colorPicker = UIColorPickerViewController()
        colorPicker.selectedColor = selectedBackgroundColor
        colorPicker.delegate = self
        present(colorPicker, animated: true)
    }
    
    @objc private func startPushButtonTapped() {
        guard let pushUrl = pushUrlTextField.text, !pushUrl.isEmpty else {
            showAlert(title: "错误", message: "请输入推流URL")
            return
        }
        
        let resolution = getSelectedResolution()
        let config = StreamPushConfig(
            pushUrl: pushUrl,
            width: resolution.width,
            height: resolution.height,
            bitrate: Int(bitrateSlider.value),
            framerate: Int(framerateSlider.value),
            layout: getSelectedLayout(),
            backgroundColor: selectedBackgroundColor
        )
        
        Task {
            do {
                try await RealtimeManager.shared.startStreamPush(config: config)
                await MainActor.run {
                    self.showAlert(title: "成功", message: "推流启动成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "启动失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func stopPushButtonTapped() {
        Task {
            do {
                try await RealtimeManager.shared.stopStreamPush()
                await MainActor.run {
                    self.showAlert(title: "成功", message: "推流停止成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "停止失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func updateLayoutButtonTapped() {
        let layout = getSelectedLayout()
        
        Task {
            do {
                try await RealtimeManager.shared.updateStreamPushLayout(layout: layout)
                await MainActor.run {
                    self.showAlert(title: "成功", message: "布局更新成功")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "更新失败", message: error.localizedDescription)
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

// MARK: - UIColorPickerViewControllerDelegate
extension StreamPushDemoViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        selectedBackgroundColor = viewController.selectedColor
        backgroundColorButton.backgroundColor = selectedBackgroundColor
        previewView.updateLayout(getSelectedLayout(), backgroundColor: selectedBackgroundColor)
    }
}

// MARK: - 推流预览视图
class StreamPreviewView: UIView {
    
    private var layout: StreamLayout = .single
    private var backgroundColor: UIColor = .black
    private var userViews: [UIView] = []
    
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
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    func updateLayout(_ layout: StreamLayout, backgroundColor: UIColor) {
        self.layout = layout
        self.backgroundColor = backgroundColor
        self.backgroundColor = backgroundColor
        setupLayoutPreview()
    }
    
    private func setupLayoutPreview() {
        // 清除现有视图
        userViews.forEach { $0.removeFromSuperview() }
        userViews.removeAll()
        
        let containerView = UIView()
        containerView.backgroundColor = backgroundColor
        containerView.layer.cornerRadius = 8
        addSubview(containerView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8),
            containerView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.8)
        ])
        
        switch layout {
        case .single:
            createSingleLayout(in: containerView)
        case .dual:
            createDualLayout(in: containerView)
        case .quad:
            createQuadLayout(in: containerView)
        case .custom:
            createCustomLayout(in: containerView)
        }
    }
    
    private func createSingleLayout(in container: UIView) {
        let userView = createUserView(name: "主播", color: .systemBlue)
        container.addSubview(userView)
        userViews.append(userView)
        
        userView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            userView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            userView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.8),
            userView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.8)
        ])
    }
    
    private func createDualLayout(in container: UIView) {
        let user1 = createUserView(name: "用户1", color: .systemBlue)
        let user2 = createUserView(name: "用户2", color: .systemGreen)
        
        container.addSubview(user1)
        container.addSubview(user2)
        userViews.append(contentsOf: [user1, user2])
        
        user1.translatesAutoresizingMaskIntoConstraints = false
        user2.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            user1.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            user1.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            user1.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            user1.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.45),
            
            user2.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            user2.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            user2.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            user2.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.45)
        ])
    }
    
    private func createQuadLayout(in container: UIView) {
        let users = [
            createUserView(name: "用户1", color: .systemBlue),
            createUserView(name: "用户2", color: .systemGreen),
            createUserView(name: "用户3", color: .systemOrange),
            createUserView(name: "用户4", color: .systemPurple)
        ]
        
        users.forEach { container.addSubview($0) }
        userViews.append(contentsOf: users)
        
        users.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            // 左上
            users[0].leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            users[0].topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            users[0].widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.48),
            users[0].heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.48),
            
            // 右上
            users[1].trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            users[1].topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            users[1].widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.48),
            users[1].heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.48),
            
            // 左下
            users[2].leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            users[2].bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            users[2].widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.48),
            users[2].heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.48),
            
            // 右下
            users[3].trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            users[3].bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            users[3].widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.48),
            users[3].heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.48)
        ])
    }
    
    private func createCustomLayout(in container: UIView) {
        let label = UILabel()
        label.text = "自定义布局"
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }
    
    private func createUserView(name: String, color: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = color.withAlphaComponent(0.3)
        view.layer.cornerRadius = 6
        view.layer.borderWidth = 1
        view.layer.borderColor = color.cgColor
        
        let label = UILabel()
        label.text = name
        label.textAlignment = .center
        label.textColor = color
        label.font = .systemFont(ofSize: 12, weight: .medium)
        
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }
}