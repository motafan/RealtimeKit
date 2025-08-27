import Foundation
import RealtimeCore
import Combine

#if canImport(UIKit)
import UIKit
#endif

/// RealtimeUIKit 模块
/// 提供 UIKit 框架的集成支持
/// 需求: 11.1, 11.4, 15.5, 17.3, 17.6, 18.10

#if canImport(UIKit) && !os(watchOS)

// MARK: - Delegate Protocols

/// RealtimeViewController 代理协议
/// 需求: 11.1, 11.4 - 实现完整的 Delegate 模式和事件处理
public protocol RealtimeViewControllerDelegate: AnyObject {
    /// 连接状态变化时调用
    func realtimeViewController(_ controller: RealtimeViewController, didChangeConnectionState state: ConnectionState)
    
    /// 音量信息更新时调用
    func realtimeViewController(_ controller: RealtimeViewController, didUpdateVolumeInfos volumeInfos: [UserVolumeInfo])
    
    /// 用户开始说话时调用
    func realtimeViewController(_ controller: RealtimeViewController, userDidStartSpeaking userId: String, volume: Float)
    
    /// 用户停止说话时调用
    func realtimeViewController(_ controller: RealtimeViewController, userDidStopSpeaking userId: String, volume: Float)
    
    /// 主讲人变化时调用
    func realtimeViewController(_ controller: RealtimeViewController, dominantSpeakerDidChange userId: String?)
    
    /// 音频设置变化时调用
    func realtimeViewController(_ controller: RealtimeViewController, didChangeAudioSettings settings: AudioSettings)
    
    /// 错误发生时调用
    func realtimeViewController(_ controller: RealtimeViewController, didEncounterError error: Error)
}

/// 音量可视化视图代理协议
public protocol VolumeVisualizationViewDelegate: AnyObject {
    /// 音量级别变化时调用
    func volumeVisualizationView(_ view: VolumeVisualizationView, didChangeVolumeLevel level: Float)
    
    /// 说话状态变化时调用
    func volumeVisualizationView(_ view: VolumeVisualizationView, didChangeSpeakingState isSpeaking: Bool)
}

// MARK: - UIKit 基础组件

/// RealtimeKit UIKit 集成的基础视图控制器
/// 需求: 11.1, 11.4, 17.3, 17.6, 18.10 - 完善功能实现，集成本地化和持久化
open class RealtimeViewController: UIViewController {
    
    // MARK: - Properties
    
    /// RealtimeManager 实例
    public let realtimeManager = RealtimeManager.shared
    
    /// 代理对象
    public weak var delegate: RealtimeViewControllerDelegate?
    
    /// UI 状态持久化
    /// 需求: 18.10 - 集成 @RealtimeStorage 到 UIKit 控制器中，实现 UI 状态自动持久化
    @RealtimeStorage("uiState", namespace: "RealtimeKit.UI.ViewController")
    public var uiState: ViewControllerUIState = ViewControllerUIState()
    
    /// 用户偏好设置持久化
    @RealtimeStorage("userPreferences", namespace: "RealtimeKit.UI.ViewController")
    public var userPreferences: ViewControllerPreferences = ViewControllerPreferences()
    
    /// 当前连接状态
    public private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            DispatchQueue.main.async {
                self.connectionStateDidChange(from: oldValue, to: self.connectionState)
                self.delegate?.realtimeViewController(self, didChangeConnectionState: self.connectionState)
                
                // 更新持久化状态
                self.uiState.lastConnectionState = self.connectionState
                self.uiState.lastStateChangeDate = Date()
            }
        }
    }
    
    /// 当前音量信息
    public private(set) var volumeInfos: [UserVolumeInfo] = [] {
        didSet {
            DispatchQueue.main.async {
                self.volumeInfosDidUpdate(self.volumeInfos)
                self.delegate?.realtimeViewController(self, didUpdateVolumeInfos: self.volumeInfos)
                
                // 检测说话状态变化
                self.detectSpeakingStateChanges(oldValue, self.volumeInfos)
                
                // 更新持久化状态
                self.uiState.lastVolumeUpdateDate = Date()
                self.uiState.speakingUserCount = self.volumeInfos.filter { $0.isSpeaking }.count
            }
        }
    }
    
    /// 当前音频设置
    public private(set) var audioSettings: AudioSettings = .default {
        didSet {
            DispatchQueue.main.async {
                self.audioSettingsDidChange(from: oldValue, to: self.audioSettings)
                self.delegate?.realtimeViewController(self, didChangeAudioSettings: self.audioSettings)
                
                // 更新持久化状态
                self.uiState.lastAudioSettingsChangeDate = Date()
            }
        }
    }
    
    /// 本地化管理器
    private let localizationManager = LocalizationManager.shared
    
    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 上一次的说话用户集合（用于检测变化）
    private var previousSpeakingUsers: Set<String> = []
    
    /// 上一次的主讲人
    private var previousDominantSpeaker: String?
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupRealtimeKit()
        setupLocalization()
        setupStateObservation()
        
        // 注册本地化更新
        LocalizationNotificationManager.registerViewController(self)
        
        // 恢复 UI 状态
        restoreUIState()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startObservingRealtimeEvents()
        
        // 更新持久化状态
        uiState.viewAppearanceCount += 1
        uiState.lastViewAppearanceDate = Date()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopObservingRealtimeEvents()
        
        // 保存当前 UI 状态
        saveUIState()
    }
    
    deinit {
        // 注销本地化更新
        LocalizationNotificationManager.unregisterViewController(self)
        
        // 清理订阅
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    private func setupRealtimeKit() {
        // 子类可以重写此方法进行自定义设置
        configureRealtimeKit()
    }
    
    /// 配置 RealtimeKit（子类可重写）
    open func configureRealtimeKit() {
        // 默认实现为空，子类可以重写
    }
    
    /// 设置本地化支持
    /// 需求: 17.3, 17.6 - 集成本地化 UIKit 扩展组件
    private func setupLocalization() {
        // 设置本地化标题
        if let titleKey = userPreferences.titleLocalizationKey {
            setLocalizedTitle(titleKey)
        }
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    /// 设置状态观察
    private func setupStateObservation() {
        // 观察 RealtimeManager 的状态变化
        realtimeManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
        
        realtimeManager.$volumeInfos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumeInfos in
                self?.volumeInfos = volumeInfos
            }
            .store(in: &cancellables)
        
        realtimeManager.$audioSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.audioSettings = settings
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Observation
    
    private func startObservingRealtimeEvents() {
        // 观察连接状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStateChange(_:)),
            name: .realtimeConnectionStateChanged,
            object: nil
        )
        
        // 观察音量信息更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVolumeInfoUpdate(_:)),
            name: .realtimeVolumeInfoUpdated,
            object: nil
        )
        
        // 观察错误事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRealtimeError(_:)),
            name: .realtimeErrorOccurred,
            object: nil
        )
    }
    
    private func stopObservingRealtimeEvents() {
        NotificationCenter.default.removeObserver(self, name: .realtimeConnectionStateChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .realtimeVolumeInfoUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .realtimeErrorOccurred, object: nil)
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleConnectionStateChange(_ notification: Notification) {
        if let newState = notification.userInfo?["state"] as? ConnectionState {
            connectionState = newState
        }
    }
    
    @objc private func handleVolumeInfoUpdate(_ notification: Notification) {
        if let volumeInfos = notification.userInfo?["volumeInfos"] as? [UserVolumeInfo] {
            self.volumeInfos = volumeInfos
        }
    }
    
    @objc private func handleRealtimeError(_ notification: Notification) {
        if let error = notification.userInfo?["error"] as? Error {
            DispatchQueue.main.async {
                self.realtimeErrorDidOccur(error)
                self.delegate?.realtimeViewController(self, didEncounterError: error)
                
                // 更新错误统计
                self.uiState.errorCount += 1
                self.uiState.lastErrorDate = Date()
            }
        }
    }
    
    @objc internal override func languageDidChange() {
        // 更新本地化内容
        updateLocalizedContent()
        
        // 更新持久化状态
        uiState.languageChangeCount += 1
        uiState.lastLanguageChangeDate = Date()
    }
    
    // MARK: - Speaking State Detection
    
    private func detectSpeakingStateChanges(_ oldVolumeInfos: [UserVolumeInfo], _ newVolumeInfos: [UserVolumeInfo]) {
        let oldSpeakingUsers = Set(oldVolumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        let newSpeakingUsers = Set(newVolumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        
        // 检测开始说话的用户
        let startedSpeaking = newSpeakingUsers.subtracting(oldSpeakingUsers)
        for userId in startedSpeaking {
            if let volumeInfo = newVolumeInfos.first(where: { $0.userId == userId }) {
                delegate?.realtimeViewController(self, userDidStartSpeaking: userId, volume: Float(volumeInfo.volume))
                userDidStartSpeaking(userId: userId, volume: Float(volumeInfo.volume))
            }
        }
        
        // 检测停止说话的用户
        let stoppedSpeaking = oldSpeakingUsers.subtracting(newSpeakingUsers)
        for userId in stoppedSpeaking {
            if let volumeInfo = oldVolumeInfos.first(where: { $0.userId == userId }) {
                delegate?.realtimeViewController(self, userDidStopSpeaking: userId, volume: Float(volumeInfo.volume))
                userDidStopSpeaking(userId: userId, volume: Float(volumeInfo.volume))
            }
        }
        
        // 检测主讲人变化
        let newDominantSpeaker = newVolumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        
        if newDominantSpeaker != previousDominantSpeaker {
            delegate?.realtimeViewController(self, dominantSpeakerDidChange: newDominantSpeaker)
            dominantSpeakerDidChange(userId: newDominantSpeaker)
            previousDominantSpeaker = newDominantSpeaker
        }
        
        previousSpeakingUsers = newSpeakingUsers
    }
    
    // MARK: - UI State Management
    
    /// 恢复 UI 状态
    /// 需求: 18.10 - UI 状态自动持久化和恢复
    private func restoreUIState() {
        // 恢复用户偏好
        if userPreferences.rememberWindowPosition {
            // 在实际应用中可以恢复窗口位置等
        }
        
        // 恢复视图状态
        if let lastLanguage = uiState.lastSelectedLanguage {
            Task {
                await localizationManager.switchLanguage(to: lastLanguage)
            }
        }
    }
    
    /// 保存 UI 状态
    private func saveUIState() {
        uiState.lastSelectedLanguage = localizationManager.currentLanguage
        uiState.lastSaveDate = Date()
    }
    
    // MARK: - Override Points
    
    /// 连接状态变化时调用（子类可重写）
    /// - Parameters:
    ///   - oldState: 旧状态
    ///   - newState: 新状态
    open func connectionStateDidChange(from oldState: ConnectionState, to newState: ConnectionState) {
        // 默认实现为空，子类可以重写
    }
    
    /// 音量信息更新时调用（子类可重写）
    /// - Parameter volumeInfos: 更新的音量信息数组
    open func volumeInfosDidUpdate(_ volumeInfos: [UserVolumeInfo]) {
        // 默认实现为空，子类可以重写
    }
    
    /// 音频设置变化时调用（子类可重写）
    /// - Parameters:
    ///   - oldSettings: 旧设置
    ///   - newSettings: 新设置
    open func audioSettingsDidChange(from oldSettings: AudioSettings, to newSettings: AudioSettings) {
        // 默认实现为空，子类可以重写
    }
    
    /// 用户开始说话时调用（子类可重写）
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - volume: 音量级别
    open func userDidStartSpeaking(userId: String, volume: Float) {
        // 默认实现为空，子类可以重写
    }
    
    /// 用户停止说话时调用（子类可重写）
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - volume: 音量级别
    open func userDidStopSpeaking(userId: String, volume: Float) {
        // 默认实现为空，子类可以重写
    }
    
    /// 主讲人变化时调用（子类可重写）
    /// - Parameter userId: 新的主讲人ID，nil表示没有主讲人
    open func dominantSpeakerDidChange(userId: String?) {
        // 默认实现为空，子类可以重写
    }
    
    /// 错误发生时调用（子类可重写）
    /// - Parameter error: 发生的错误
    open func realtimeErrorDidOccur(_ error: Error) {
        // 默认实现：显示本地化错误提示
        showLocalizedErrorAlert(error)
    }
    
    /// 更新本地化内容（子类可重写）
    /// 需求: 17.6 - 语言变化通知和 UI 自动更新机制
    open func updateLocalizedContent() {
        // 更新标题
        if let titleKey = userPreferences.titleLocalizationKey {
            setLocalizedTitle(titleKey)
        }
        
        // 递归更新所有子视图的本地化内容
        view.updateLocalizedSubviews()
    }
    
    // MARK: - Convenience Methods
    
    /// 显示本地化错误提示
    /// 需求: 17.6 - 本地化的用户界面文本和提示
    public func showLocalizedErrorAlert(_ error: Error) {
        let alert = UIAlertController.localizedAlert(
            titleKey: "error.title",
            messageKey: "error.message",
            preferredStyle: .alert
        )
        
        alert.addLocalizedAction(
            titleKey: "common.ok",
            style: .default
        )
        
        present(alert, animated: true)
    }
    
    /// 设置本地化标题并保存偏好
    /// 需求: 17.3, 18.10 - 本地化支持和偏好持久化
    public func setLocalizedTitleAndSave(_ key: String, arguments: CVarArg..., fallbackValue: String? = nil) {
        setLocalizedTitle(key, arguments: arguments, fallbackValue: fallbackValue)
        userPreferences.titleLocalizationKey = key
    }
}

/// 音量可视化视图
/// 需求: 11.1, 11.4, 6.5 - 添加音量可视化和说话指示器 UIView 组件
public class VolumeVisualizationView: UIView {
    
    // MARK: - Properties
    
    /// 代理对象
    public weak var delegate: VolumeVisualizationViewDelegate?
    
    /// 当前音量级别 (0.0 - 1.0)
    public var volumeLevel: Float = 0.0 {
        didSet {
            let clampedLevel = max(0.0, min(1.0, volumeLevel))
            if clampedLevel != oldValue {
                DispatchQueue.main.async {
                    self.updateVisualization()
                    self.delegate?.volumeVisualizationView(self, didChangeVolumeLevel: clampedLevel)
                }
            }
        }
    }
    
    /// 是否正在说话
    public var isSpeaking: Bool = false {
        didSet {
            if isSpeaking != oldValue {
                DispatchQueue.main.async {
                    self.updateSpeakingState()
                    self.delegate?.volumeVisualizationView(self, didChangeSpeakingState: self.isSpeaking)
                }
            }
        }
    }
    
    /// 用户ID（用于标识）
    public var userId: String?
    
    /// 音量条颜色
    public var volumeColor: UIColor = .systemBlue {
        didSet {
            updateVisualization()
        }
    }
    
    /// 说话状态颜色
    public var speakingColor: UIColor = .systemGreen {
        didSet {
            updateSpeakingState()
        }
    }
    
    /// 背景颜色
    public var backgroundBarColor: UIColor = .systemGray5 {
        didSet {
            backgroundBar.backgroundColor = backgroundBarColor
        }
    }
    
    /// 动画持续时间
    public var animationDuration: TimeInterval = 0.2
    
    /// 是否启用波纹动画
    public var enableRippleAnimation: Bool = true
    
    /// 可视化样式
    public var visualizationStyle: VolumeVisualizationStyle = .bar {
        didSet {
            if visualizationStyle != oldValue {
                setupVisualizationStyle()
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let volumeBar = UIView()
    private let backgroundBar = UIView()
    private let rippleLayer = CAShapeLayer()
    private var volumeWidthConstraint: NSLayoutConstraint?
    private var rippleAnimation: CAAnimationGroup?
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear
        
        // 背景条
        backgroundBar.backgroundColor = backgroundBarColor
        backgroundBar.layer.cornerRadius = 2
        addSubview(backgroundBar)
        
        // 音量条
        volumeBar.backgroundColor = volumeColor
        volumeBar.layer.cornerRadius = 2
        addSubview(volumeBar)
        
        // 波纹层
        if enableRippleAnimation {
            setupRippleLayer()
        }
        
        setupConstraints()
        setupVisualizationStyle()
    }
    
    private func setupRippleLayer() {
        rippleLayer.fillColor = UIColor.clear.cgColor
        rippleLayer.strokeColor = speakingColor.cgColor
        rippleLayer.lineWidth = 2.0
        rippleLayer.opacity = 0.0
        layer.addSublayer(rippleLayer)
    }
    
    private func setupConstraints() {
        backgroundBar.translatesAutoresizingMaskIntoConstraints = false
        volumeBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backgroundBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundBar.topAnchor.constraint(equalTo: topAnchor),
            backgroundBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            volumeBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            volumeBar.topAnchor.constraint(equalTo: topAnchor),
            volumeBar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 音量宽度约束
        volumeWidthConstraint = volumeBar.widthAnchor.constraint(equalToConstant: 0)
        volumeWidthConstraint?.isActive = true
    }
    
    private func setupVisualizationStyle() {
        switch visualizationStyle {
        case .bar:
            setupBarStyle()
        case .circle:
            setupCircleStyle()
        case .wave:
            setupWaveStyle()
        }
    }
    
    private func setupBarStyle() {
        backgroundBar.layer.cornerRadius = bounds.height / 2
        volumeBar.layer.cornerRadius = bounds.height / 2
    }
    
    private func setupCircleStyle() {
        backgroundBar.layer.cornerRadius = min(bounds.width, bounds.height) / 2
        volumeBar.layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }
    
    private func setupWaveStyle() {
        // 波形样式的特殊设置
        backgroundBar.layer.cornerRadius = 4
        volumeBar.layer.cornerRadius = 4
    }
    
    // MARK: - Updates
    
    private func updateVisualization() {
        let targetWidth = bounds.width * CGFloat(volumeLevel)
        
        UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseInOut], animations: {
            self.volumeWidthConstraint?.constant = targetWidth
            self.layoutIfNeeded()
            
            // 更新颜色
            self.volumeBar.backgroundColor = self.isSpeaking ? self.speakingColor : self.volumeColor
        })
    }
    
    private func updateSpeakingState() {
        UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseInOut], animations: {
            self.volumeBar.backgroundColor = self.isSpeaking ? self.speakingColor : self.volumeColor
            
            // 说话时的缩放效果
            if self.isSpeaking {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } else {
                self.transform = .identity
            }
        })
        
        // 波纹动画
        if enableRippleAnimation && isSpeaking {
            startRippleAnimation()
        } else {
            stopRippleAnimation()
        }
    }
    
    // MARK: - Ripple Animation
    
    private func startRippleAnimation() {
        guard enableRippleAnimation else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        
        // 创建圆形路径
        let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        rippleLayer.path = circlePath.cgPath
        
        // 缩放动画
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.5
        scaleAnimation.duration = 1.0
        
        // 透明度动画
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = 1.0
        
        // 组合动画
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.duration = 1.0
        animationGroup.repeatCount = .infinity
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        rippleAnimation = animationGroup
        rippleLayer.add(animationGroup, forKey: "ripple")
    }
    
    private func stopRippleAnimation() {
        rippleLayer.removeAnimation(forKey: "ripple")
        rippleAnimation = nil
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        setupVisualizationStyle()
        updateVisualization()
        
        // 更新波纹层位置
        if enableRippleAnimation {
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let radius = min(bounds.width, bounds.height) / 2
            let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            rippleLayer.path = circlePath.cgPath
        }
    }
    
    // MARK: - Public Methods
    
    /// 更新音量信息
    /// - Parameter volumeInfo: 音量信息
    public func updateVolumeInfo(_ volumeInfo: UserVolumeInfo) {
        userId = volumeInfo.userId
        volumeLevel = Float(volumeInfo.volume)
        isSpeaking = volumeInfo.isSpeaking
    }
    
    /// 重置可视化状态
    public func reset() {
        volumeLevel = 0.0
        isSpeaking = false
        userId = nil
        stopRippleAnimation()
    }
}

// MARK: - VolumeVisualizationStyle

/// 音量可视化样式
public enum VolumeVisualizationStyle: Codable, Sendable {
    case bar    // 条形
    case circle // 圆形
    case wave   // 波形
}

// MARK: - 说话指示器视图

/// 说话指示器视图
/// 需求: 11.1, 6.5 - 说话指示器 UIView 组件
public class SpeakingIndicatorView: UIView {
    
    // MARK: - Properties
    
    /// 是否正在说话
    public var isSpeaking: Bool = false {
        didSet {
            updateSpeakingState()
        }
    }
    
    /// 用户名
    public var userName: String? {
        didSet {
            userNameLabel.text = userName
        }
    }
    
    /// 用户ID
    public var userId: String?
    
    /// 说话状态颜色
    public var speakingColor: UIColor = .systemGreen {
        didSet {
            updateColors()
        }
    }
    
    /// 非说话状态颜色
    public var idleColor: UIColor = .systemGray3 {
        didSet {
            updateColors()
        }
    }
    
    // MARK: - Private Properties
    
    private let indicatorView = UIView()
    private let userNameLabel = UILabel()
    private let stackView = UIStackView()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear
        
        // 指示器视图
        indicatorView.backgroundColor = idleColor
        indicatorView.layer.cornerRadius = 6
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        
        // 用户名标签
        userNameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        userNameLabel.textColor = .label
        userNameLabel.textAlignment = .left
        
        // 堆栈视图
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(indicatorView)
        stackView.addArrangedSubview(userNameLabel)
        addSubview(stackView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            indicatorView.widthAnchor.constraint(equalToConstant: 12),
            indicatorView.heightAnchor.constraint(equalToConstant: 12),
            
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Updates
    
    private func updateSpeakingState() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
            self.indicatorView.backgroundColor = self.isSpeaking ? self.speakingColor : self.idleColor
            self.indicatorView.transform = self.isSpeaking ? CGAffineTransform(scaleX: 1.2, y: 1.2) : .identity
            self.userNameLabel.font = self.isSpeaking ? 
                UIFont.systemFont(ofSize: 14, weight: .bold) : 
                UIFont.systemFont(ofSize: 14, weight: .medium)
        })
        
        // 添加脉冲动画
        if isSpeaking {
            startPulseAnimation()
        } else {
            stopPulseAnimation()
        }
    }
    
    private func updateColors() {
        indicatorView.backgroundColor = isSpeaking ? speakingColor : idleColor
    }
    
    // MARK: - Pulse Animation
    
    private func startPulseAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.5
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        indicatorView.layer.add(pulseAnimation, forKey: "pulse")
    }
    
    private func stopPulseAnimation() {
        indicatorView.layer.removeAnimation(forKey: "pulse")
    }
    
    // MARK: - Public Methods
    
    /// 更新用户信息
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - userName: 用户名
    ///   - isSpeaking: 是否正在说话
    public func updateUserInfo(userId: String, userName: String, isSpeaking: Bool) {
        self.userId = userId
        self.userName = userName
        self.isSpeaking = isSpeaking
    }
}

// MARK: - UI State Models

/// 视图控制器 UI 状态
/// 需求: 18.10 - UI 状态自动持久化
public struct ViewControllerUIState: Codable, Sendable {
    /// 最后的连接状态
    public var lastConnectionState: ConnectionState = .disconnected
    
    /// 最后的状态变化日期
    public var lastStateChangeDate: Date?
    
    /// 最后的音量更新日期
    public var lastVolumeUpdateDate: Date?
    
    /// 最后的音频设置变化日期
    public var lastAudioSettingsChangeDate: Date?
    
    /// 最后选择的语言
    public var lastSelectedLanguage: SupportedLanguage?
    
    /// 视图出现次数
    public var viewAppearanceCount: Int = 0
    
    /// 最后的视图出现日期
    public var lastViewAppearanceDate: Date?
    
    /// 错误计数
    public var errorCount: Int = 0
    
    /// 最后的错误日期
    public var lastErrorDate: Date?
    
    /// 语言变化次数
    public var languageChangeCount: Int = 0
    
    /// 最后的语言变化日期
    public var lastLanguageChangeDate: Date?
    
    /// 说话用户数量
    public var speakingUserCount: Int = 0
    
    /// 最后保存日期
    public var lastSaveDate: Date?
    
    public init() {}
}

/// 视图控制器用户偏好
/// 需求: 18.10 - 用户界面设置和偏好持久化
public struct ViewControllerPreferences: Codable, Sendable {
    /// 标题本地化键
    public var titleLocalizationKey: String?
    
    /// 是否记住窗口位置
    public var rememberWindowPosition: Bool = true
    
    /// 是否启用音量可视化
    public var enableVolumeVisualization: Bool = true
    
    /// 是否启用说话指示器
    public var enableSpeakingIndicator: Bool = true
    
    /// 是否启用波纹动画
    public var enableRippleAnimation: Bool = true
    
    /// 音量可视化样式
    public var volumeVisualizationStyle: VolumeVisualizationStyle = .bar
    
    /// 自动语言检测
    public var autoLanguageDetection: Bool = true
    
    /// 错误提示显示时长
    public var errorAlertDuration: TimeInterval = 3.0
    
    /// 是否启用触觉反馈
    public var enableHapticFeedback: Bool = true
    
    public init() {}
}

// MARK: - 音频控制面板

/// 音频控制面板视图
/// 需求: 11.4, 5.1, 5.2, 5.3 - 音频控制面板和设置界面组件
public class AudioControlPanelView: UIView {
    
    // MARK: - Properties
    
    /// 音频设置持久化
    @RealtimeStorage("audioControlSettings", namespace: "RealtimeKit.UI.AudioControl")
    public var controlSettings: AudioControlSettings = AudioControlSettings()
    
    /// 当前音频设置
    public var audioSettings: AudioSettings = .default {
        didSet {
            updateControlsFromSettings()
        }
    }
    
    /// 音频设置变化回调
    public var onAudioSettingsChanged: ((AudioSettings) -> Void)?
    
    /// 静音按钮点击回调
    public var onMuteToggled: ((Bool) -> Void)?
    
    /// 音量变化回调
    public var onVolumeChanged: ((AudioVolumeType, Int) -> Void)?
    
    // MARK: - UI Components
    
    private let stackView = UIStackView()
    private let muteButton = UIButton(type: .system)
    private let mixingVolumeSlider = UISlider()
    private let playbackVolumeSlider = UISlider()
    private let recordingVolumeSlider = UISlider()
    private let mixingVolumeLabel = UILabel()
    private let playbackVolumeLabel = UILabel()
    private let recordingVolumeLabel = UILabel()
    private let mixingValueLabel = UILabel()
    private let playbackValueLabel = UILabel()
    private let recordingValueLabel = UILabel()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLocalization()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupLocalization()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        setupStackView()
        setupMuteButton()
        setupVolumeControls()
        setupConstraints()
        
        // 恢复控制设置
        restoreControlSettings()
    }
    
    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
    }
    
    private func setupMuteButton() {
        muteButton.setTitle("🎤", for: .normal)
        muteButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        muteButton.backgroundColor = .systemBlue
        muteButton.layer.cornerRadius = 25
        muteButton.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        
        let muteContainer = UIView()
        muteContainer.addSubview(muteButton)
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            muteButton.centerXAnchor.constraint(equalTo: muteContainer.centerXAnchor),
            muteButton.topAnchor.constraint(equalTo: muteContainer.topAnchor),
            muteButton.bottomAnchor.constraint(equalTo: muteContainer.bottomAnchor),
            muteButton.widthAnchor.constraint(equalToConstant: 50),
            muteButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        stackView.addArrangedSubview(muteContainer)
    }
    
    private func setupVolumeControls() {
        // 混音音量
        let mixingContainer = createVolumeControlContainer(
            label: mixingVolumeLabel,
            slider: mixingVolumeSlider,
            valueLabel: mixingValueLabel,
            tag: AudioVolumeType.mixing.rawValue
        )
        stackView.addArrangedSubview(mixingContainer)
        
        // 播放音量
        let playbackContainer = createVolumeControlContainer(
            label: playbackVolumeLabel,
            slider: playbackVolumeSlider,
            valueLabel: playbackValueLabel,
            tag: AudioVolumeType.playback.rawValue
        )
        stackView.addArrangedSubview(playbackContainer)
        
        // 录制音量
        let recordingContainer = createVolumeControlContainer(
            label: recordingVolumeLabel,
            slider: recordingVolumeSlider,
            valueLabel: recordingValueLabel,
            tag: AudioVolumeType.recording.rawValue
        )
        stackView.addArrangedSubview(recordingContainer)
    }
    
    private func createVolumeControlContainer(
        label: UILabel,
        slider: UISlider,
        valueLabel: UILabel,
        tag: Int
    ) -> UIView {
        let container = UIView()
        
        // 标签设置
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        
        // 滑块设置
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 100
        slider.tag = tag
        slider.addTarget(self, action: #selector(volumeSliderChanged(_:)), for: .valueChanged)
        
        // 数值标签设置
        valueLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.text = "100"
        
        // 布局
        let topStack = UIStackView(arrangedSubviews: [label, valueLabel])
        topStack.axis = .horizontal
        topStack.distribution = .fillProportionally
        
        let mainStack = UIStackView(arrangedSubviews: [topStack, slider])
        mainStack.axis = .vertical
        mainStack.spacing = 4
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: container.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            valueLabel.widthAnchor.constraint(equalToConstant: 40)
        ])
        
        return container
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    private func setupLocalization() {
        mixingVolumeLabel.setLocalizedText("audio.mixing_volume", fallbackValue: "Mixing Volume")
        playbackVolumeLabel.setLocalizedText("audio.playback_volume", fallbackValue: "Playback Volume")
        recordingVolumeLabel.setLocalizedText("audio.recording_volume", fallbackValue: "Recording Volume")
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    @objc private func muteButtonTapped() {
        let newMutedState = !audioSettings.microphoneMuted
        
        // 更新 UI
        updateMuteButtonState(muted: newMutedState)
        
        // 触发回调
        onMuteToggled?(newMutedState)
        
        // 更新设置
        audioSettings = AudioSettings(
            microphoneMuted: newMutedState,
            audioMixingVolume: audioSettings.audioMixingVolume,
            playbackSignalVolume: audioSettings.playbackSignalVolume,
            recordingSignalVolume: audioSettings.recordingSignalVolume,
            localAudioStreamActive: audioSettings.localAudioStreamActive
        )
        
        onAudioSettingsChanged?(audioSettings)
        
        // 保存控制设置
        controlSettings.lastMuteToggleDate = Date()
        controlSettings.muteToggleCount += 1
    }
    
    @objc private func volumeSliderChanged(_ slider: UISlider) {
        let value = Int(slider.value)
        let volumeType = AudioVolumeType(rawValue: slider.tag) ?? .mixing
        
        // 更新数值标签
        switch volumeType {
        case .mixing:
            mixingValueLabel.text = "\(value)"
        case .playback:
            playbackValueLabel.text = "\(value)"
        case .recording:
            recordingValueLabel.text = "\(value)"
        }
        
        // 触发回调
        onVolumeChanged?(volumeType, value)
        
        // 更新音频设置
        updateAudioSettingsFromSlider(volumeType: volumeType, value: value)
        
        // 保存控制设置
        controlSettings.lastVolumeChangeDate = Date()
        controlSettings.volumeChangeCount += 1
    }
    
    @objc private func languageDidChange() {
        mixingVolumeLabel.setLocalizedText("audio.mixing_volume", fallbackValue: "Mixing Volume")
        playbackVolumeLabel.setLocalizedText("audio.playback_volume", fallbackValue: "Playback Volume")
        recordingVolumeLabel.setLocalizedText("audio.recording_volume", fallbackValue: "Recording Volume")
    }
    
    // MARK: - Private Methods
    
    private func updateControlsFromSettings() {
        // 更新静音按钮
        updateMuteButtonState(muted: audioSettings.microphoneMuted)
        
        // 更新滑块
        mixingVolumeSlider.value = Float(audioSettings.audioMixingVolume)
        playbackVolumeSlider.value = Float(audioSettings.playbackSignalVolume)
        recordingVolumeSlider.value = Float(audioSettings.recordingSignalVolume)
        
        // 更新数值标签
        mixingValueLabel.text = "\(audioSettings.audioMixingVolume)"
        playbackValueLabel.text = "\(audioSettings.playbackSignalVolume)"
        recordingValueLabel.text = "\(audioSettings.recordingSignalVolume)"
    }
    
    private func updateMuteButtonState(muted: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.muteButton.setTitle(muted ? "🔇" : "🎤", for: .normal)
            self.muteButton.backgroundColor = muted ? .systemRed : .systemBlue
        }
    }
    
    private func updateAudioSettingsFromSlider(volumeType: AudioVolumeType, value: Int) {
        switch volumeType {
        case .mixing:
            audioSettings = audioSettings.withUpdatedVolume(audioMixing: value)
        case .playback:
            audioSettings = audioSettings.withUpdatedVolume(playbackSignal: value)
        case .recording:
            audioSettings = audioSettings.withUpdatedVolume(recordingSignal: value)
        }
        
        onAudioSettingsChanged?(audioSettings)
    }
    
    private func restoreControlSettings() {
        // 根据保存的设置恢复控件状态
        if controlSettings.rememberSliderPositions {
            // 可以在这里恢复滑块位置等
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Audio Volume Type

/// 音频音量类型
public enum AudioVolumeType: Int, CaseIterable {
    case mixing = 0
    case playback = 1
    case recording = 2
}

/// 音频控制设置
/// 需求: 18.10 - 用户界面设置和偏好持久化
public struct AudioControlSettings: Codable, Sendable {
    /// 是否记住滑块位置
    public var rememberSliderPositions: Bool = true
    
    /// 最后的静音切换日期
    public var lastMuteToggleDate: Date?
    
    /// 静音切换次数
    public var muteToggleCount: Int = 0
    
    /// 最后的音量变化日期
    public var lastVolumeChangeDate: Date?
    
    /// 音量变化次数
    public var volumeChangeCount: Int = 0
    
    public init() {}
}

// MARK: - 错误处理和用户反馈组件

/// 错误提示视图
/// 需求: 13.1, 13.4, 17.1, 17.6 - 错误处理和用户反馈 UI 组件，本地化错误消息
public class ErrorFeedbackView: UIView {
    
    // MARK: - Properties
    
    /// 错误信息
    public var error: Error? {
        didSet {
            updateErrorDisplay()
        }
    }
    
    /// 显示持续时间
    public var displayDuration: TimeInterval = 3.0
    
    /// 自动隐藏定时器
    private var hideTimer: Timer?
    
    // MARK: - UI Components
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    private let stackView = UIStackView()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLocalization()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupLocalization()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        alpha = 0
        
        // 容器视图
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.2
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // 图标
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        iconImageView.tintColor = .systemRed
        iconImageView.contentMode = .scaleAspectFit
        
        // 标题标签
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        
        // 消息标签
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        
        // 关闭按钮
        dismissButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        dismissButton.tintColor = .systemGray3
        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        
        // 堆栈视图
        let topStack = UIStackView(arrangedSubviews: [iconImageView, titleLabel, UIView(), dismissButton])
        topStack.axis = .horizontal
        topStack.spacing = 12
        topStack.alignment = .center
        
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(topStack)
        stackView.addArrangedSubview(messageLabel)
        
        containerView.addSubview(stackView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            dismissButton.widthAnchor.constraint(equalToConstant: 24),
            dismissButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupLocalization() {
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// 显示错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - in: 父视图
    ///   - duration: 显示持续时间
    public func showError(_ error: Error, in parentView: UIView, duration: TimeInterval? = nil) {
        self.error = error
        self.displayDuration = duration ?? displayDuration
        
        // 添加到父视图
        parentView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            topAnchor.constraint(equalTo: parentView.topAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
        
        // 显示动画
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
            self.alpha = 1.0
            self.containerView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }) { _ in
            // 设置自动隐藏定时器
            self.scheduleAutoHide()
        }
        
        // 初始变换
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }
    
    /// 隐藏错误提示
    public func hideError() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
            self.alpha = 0.0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateErrorDisplay() {
        guard let error = error else { return }
        
        // 获取本地化错误信息
        let localizationManager = LocalizationManager.shared
        
        if let localizedError = error as? LocalizedRealtimeError {
            titleLabel.text = localizationManager.localizedString(for: "error.title", fallbackValue: "Error")
            messageLabel.text = localizedError.errorDescription ?? error.localizedDescription
        } else {
            titleLabel.text = localizationManager.localizedString(for: "error.title", fallbackValue: "Error")
            messageLabel.text = error.localizedDescription
        }
    }
    
    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.hideError()
        }
    }
    
    // MARK: - Actions
    
    @objc private func dismissButtonTapped() {
        hideError()
    }
    
    @objc private func languageDidChange() {
        updateErrorDisplay()
    }
    
    deinit {
        hideTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 转推流控制面板

/// 转推流控制面板视图
/// 需求: 11.4, 7.2 - 转推流 UI 控制组件
public class StreamPushControlPanelView: UIView {
    
    // MARK: - Properties
    
    /// 转推流控制设置持久化
    @RealtimeStorage("streamPushControlSettings", namespace: "RealtimeKit.UI.StreamPush")
    public var controlSettings: StreamPushControlSettings = StreamPushControlSettings()
    
    /// 当前转推流状态
    public var streamPushState: StreamPushState = .stopped {
        didSet {
            updateControlsFromState()
        }
    }
    
    /// 转推流配置
    public var streamPushConfig: StreamPushConfig? {
        didSet {
            updateConfigurationDisplay()
        }
    }
    
    /// 转推流状态变化回调
    public var onStreamPushStateChanged: ((StreamPushState) -> Void)?
    
    /// 开始转推流回调
    public var onStartStreamPush: ((StreamPushConfig) -> Void)?
    
    /// 停止转推流回调
    public var onStopStreamPush: (() -> Void)?
    
    /// 更新布局回调
    public var onUpdateLayout: ((StreamLayout) -> Void)?
    
    // MARK: - UI Components
    
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let statusIndicator = UIView()
    private let startStopButton = UIButton(type: .system)
    private let configurationButton = UIButton(type: .system)
    private let layoutButton = UIButton(type: .system)
    private let urlTextField = UITextField()
    private let resolutionSegmentedControl = UISegmentedControl(items: ["720p", "1080p", "4K"])
    private let bitrateSlider = UISlider()
    private let bitrateLabel = UILabel()
    private let bitrateValueLabel = UILabel()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLocalization()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupLocalization()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        setupStackView()
        setupTitleAndStatus()
        setupControls()
        setupConfiguration()
        setupConstraints()
        
        // 恢复控制设置
        restoreControlSettings()
    }
    
    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
    }
    
    private func setupTitleAndStatus() {
        // 标题
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        // 状态容器
        let statusContainer = UIView()
        
        // 状态指示器
        statusIndicator.backgroundColor = .systemGray3
        statusIndicator.layer.cornerRadius = 6
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // 状态标签
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        
        let statusStack = UIStackView(arrangedSubviews: [statusIndicator, statusLabel])
        statusStack.axis = .horizontal
        statusStack.spacing = 8
        statusStack.alignment = .center
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        
        statusContainer.addSubview(statusStack)
        
        NSLayoutConstraint.activate([
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            statusStack.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            statusStack.topAnchor.constraint(equalTo: statusContainer.topAnchor),
            statusStack.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor)
        ])
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(statusContainer)
    }
    
    private func setupControls() {
        // 开始/停止按钮
        startStopButton.setTitle("Start Stream", for: .normal)
        startStopButton.backgroundColor = .systemBlue
        startStopButton.setTitleColor(.white, for: .normal)
        startStopButton.layer.cornerRadius = 8
        startStopButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        startStopButton.addTarget(self, action: #selector(startStopButtonTapped), for: .touchUpInside)
        
        // 配置按钮
        configurationButton.setTitle("Configuration", for: .normal)
        configurationButton.backgroundColor = .systemGray5
        configurationButton.setTitleColor(.label, for: .normal)
        configurationButton.layer.cornerRadius = 8
        configurationButton.addTarget(self, action: #selector(configurationButtonTapped), for: .touchUpInside)
        
        // 布局按钮
        layoutButton.setTitle("Layout", for: .normal)
        layoutButton.backgroundColor = .systemGray5
        layoutButton.setTitleColor(.label, for: .normal)
        layoutButton.layer.cornerRadius = 8
        layoutButton.addTarget(self, action: #selector(layoutButtonTapped), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [configurationButton, layoutButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        stackView.addArrangedSubview(startStopButton)
        stackView.addArrangedSubview(buttonStack)
        
        // 设置按钮高度
        startStopButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        configurationButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        layoutButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }
    
    private func setupConfiguration() {
        // URL 输入框
        urlTextField.placeholder = "Stream URL"
        urlTextField.borderStyle = .roundedRect
        urlTextField.font = UIFont.systemFont(ofSize: 14)
        urlTextField.addTarget(self, action: #selector(urlTextFieldChanged), for: .editingChanged)
        
        // 分辨率选择
        resolutionSegmentedControl.selectedSegmentIndex = 0
        resolutionSegmentedControl.addTarget(self, action: #selector(resolutionChanged), for: .valueChanged)
        
        // 码率滑块
        bitrateSlider.minimumValue = 500
        bitrateSlider.maximumValue = 8000
        bitrateSlider.value = 2000
        bitrateSlider.addTarget(self, action: #selector(bitrateChanged), for: .valueChanged)
        
        // 码率标签
        bitrateLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        bitrateLabel.textColor = .label
        bitrateLabel.text = "Bitrate"
        
        bitrateValueLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        bitrateValueLabel.textColor = .secondaryLabel
        bitrateValueLabel.textAlignment = .right
        bitrateValueLabel.text = "2000 kbps"
        
        // 码率容器
        let bitrateTopStack = UIStackView(arrangedSubviews: [bitrateLabel, bitrateValueLabel])
        bitrateTopStack.axis = .horizontal
        bitrateTopStack.distribution = .fillProportionally
        
        let bitrateStack = UIStackView(arrangedSubviews: [bitrateTopStack, bitrateSlider])
        bitrateStack.axis = .vertical
        bitrateStack.spacing = 4
        
        // 分辨率标签
        let resolutionLabel = UILabel()
        resolutionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        resolutionLabel.textColor = .label
        resolutionLabel.text = "Resolution"
        
        let resolutionStack = UIStackView(arrangedSubviews: [resolutionLabel, resolutionSegmentedControl])
        resolutionStack.axis = .vertical
        resolutionStack.spacing = 8
        
        stackView.addArrangedSubview(urlTextField)
        stackView.addArrangedSubview(resolutionStack)
        stackView.addArrangedSubview(bitrateStack)
        
        // 设置约束
        bitrateValueLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    private func setupLocalization() {
        titleLabel.setLocalizedText("stream_push.title", fallbackValue: "Stream Push")
        startStopButton.setLocalizedTitle("stream_push.start", fallbackValue: "Start Stream")
        configurationButton.setLocalizedTitle("stream_push.configuration", fallbackValue: "Configuration")
        layoutButton.setLocalizedTitle("stream_push.layout", fallbackValue: "Layout")
        urlTextField.setLocalizedPlaceholder("stream_push.url_placeholder", fallbackValue: "Stream URL")
        bitrateLabel.setLocalizedText("stream_push.bitrate", fallbackValue: "Bitrate")
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    @objc private func startStopButtonTapped() {
        switch streamPushState {
        case .stopped, .failed:
            startStreamPush()
        case .running:
            stopStreamPush()
        case .starting, .stopping:
            // 忽略，正在处理中
            break
        }
        
        // 更新控制设置
        controlSettings.lastButtonTapDate = Date()
        controlSettings.buttonTapCount += 1
    }
    
    @objc private func configurationButtonTapped() {
        // 显示配置界面（可以是模态视图或导航到配置页面）
        showConfigurationAlert()
        
        controlSettings.configurationViewCount += 1
    }
    
    @objc private func layoutButtonTapped() {
        // 显示布局选择界面
        showLayoutSelectionAlert()
        
        controlSettings.layoutChangeCount += 1
    }
    
    @objc private func urlTextFieldChanged() {
        controlSettings.lastConfigChangeDate = Date()
    }
    
    @objc private func resolutionChanged() {
        controlSettings.lastConfigChangeDate = Date()
    }
    
    @objc private func bitrateChanged() {
        let value = Int(bitrateSlider.value)
        bitrateValueLabel.text = "\(value) kbps"
        controlSettings.lastConfigChangeDate = Date()
    }
    
    @objc private func languageDidChange() {
        titleLabel.setLocalizedText("stream_push.title", fallbackValue: "Stream Push")
        configurationButton.setLocalizedTitle("stream_push.configuration", fallbackValue: "Configuration")
        layoutButton.setLocalizedTitle("stream_push.layout", fallbackValue: "Layout")
        urlTextField.setLocalizedPlaceholder("stream_push.url_placeholder", fallbackValue: "Stream URL")
        bitrateLabel.setLocalizedText("stream_push.bitrate", fallbackValue: "Bitrate")
        
        updateControlsFromState() // 更新状态相关的本地化文本
    }
    
    // MARK: - Private Methods
    
    private func startStreamPush() {
        guard let url = urlTextField.text, !url.isEmpty else {
            showErrorAlert(message: "Please enter a valid stream URL")
            return
        }
        
        let resolution = getSelectedResolution()
        let bitrate = Int(bitrateSlider.value)
        
        let config = StreamPushConfig(
            url: url,
            width: resolution.width,
            height: resolution.height,
            videoBitrate: bitrate,
            audioBitrate: 128,
            frameRate: 30
        )
        
        onStartStreamPush?(config)
    }
    
    private func stopStreamPush() {
        onStopStreamPush?()
    }
    
    private func getSelectedResolution() -> (width: Int, height: Int) {
        switch resolutionSegmentedControl.selectedSegmentIndex {
        case 0: return (1280, 720)   // 720p
        case 1: return (1920, 1080)  // 1080p
        case 2: return (3840, 2160)  // 4K
        default: return (1280, 720)
        }
    }
    
    private func updateControlsFromState() {
        DispatchQueue.main.async {
            switch self.streamPushState {
            case .stopped:
                self.statusIndicator.backgroundColor = .systemGray3
                self.statusLabel.setLocalizedText("stream_push.status.stopped", fallbackValue: "Stopped")
                self.startStopButton.setLocalizedTitle("stream_push.start", fallbackValue: "Start Stream")
                self.startStopButton.backgroundColor = .systemBlue
                self.startStopButton.isEnabled = true
                
            case .starting:
                self.statusIndicator.backgroundColor = .systemYellow
                self.statusLabel.setLocalizedText("stream_push.status.starting", fallbackValue: "Starting...")
                self.startStopButton.setLocalizedTitle("stream_push.starting", fallbackValue: "Starting...")
                self.startStopButton.backgroundColor = .systemGray3
                self.startStopButton.isEnabled = false
                
            case .running:
                self.statusIndicator.backgroundColor = .systemGreen
                self.statusLabel.setLocalizedText("stream_push.status.running", fallbackValue: "Running")
                self.startStopButton.setLocalizedTitle("stream_push.stop", fallbackValue: "Stop Stream")
                self.startStopButton.backgroundColor = .systemRed
                self.startStopButton.isEnabled = true
                
            case .stopping:
                self.statusIndicator.backgroundColor = .systemOrange
                self.statusLabel.setLocalizedText("stream_push.status.stopping", fallbackValue: "Stopping...")
                self.startStopButton.setLocalizedTitle("stream_push.stopping", fallbackValue: "Stopping...")
                self.startStopButton.backgroundColor = .systemGray3
                self.startStopButton.isEnabled = false
                
            case .failed:
                self.statusIndicator.backgroundColor = .systemRed
                self.statusLabel.setLocalizedText("stream_push.status.failed", fallbackValue: "Failed")
                self.startStopButton.setLocalizedTitle("stream_push.retry", fallbackValue: "Retry")
                self.startStopButton.backgroundColor = .systemBlue
                self.startStopButton.isEnabled = true
            }
        }
    }
    
    private func updateConfigurationDisplay() {
        guard let config = streamPushConfig else { return }
        
        urlTextField.text = config.url
        bitrateSlider.value = Float(config.videoConfig.bitrate)
        bitrateValueLabel.text = "\(config.videoConfig.bitrate) kbps"
        
        // 设置分辨率
        if config.videoConfig.width == 1280 && config.videoConfig.height == 720 {
            resolutionSegmentedControl.selectedSegmentIndex = 0
        } else if config.videoConfig.width == 1920 && config.videoConfig.height == 1080 {
            resolutionSegmentedControl.selectedSegmentIndex = 1
        } else if config.videoConfig.width == 3840 && config.videoConfig.height == 2160 {
            resolutionSegmentedControl.selectedSegmentIndex = 2
        }
    }
    
    private func showConfigurationAlert() {
        let alert = UIAlertController.localizedAlert(
            titleKey: "stream_push.configuration.title",
            messageKey: "stream_push.configuration.message",
            preferredStyle: .alert
        )
        
        alert.addLocalizedAction(titleKey: "common.ok", style: .default)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func showLayoutSelectionAlert() {
        let alert = UIAlertController.localizedAlert(
            titleKey: "stream_push.layout.title",
            messageKey: "stream_push.layout.message",
            preferredStyle: .actionSheet
        )
        
        // 添加布局选项
        alert.addLocalizedAction(titleKey: "stream_push.layout.floating", style: .default) { _ in
            let layout = StreamLayout(type: .floating)
            self.onUpdateLayout?(layout)
        }
        
        alert.addLocalizedAction(titleKey: "stream_push.layout.best_fit", style: .default) { _ in
            let layout = StreamLayout(type: .bestFit)
            self.onUpdateLayout?(layout)
        }
        
        alert.addLocalizedAction(titleKey: "stream_push.layout.vertical", style: .default) { _ in
            let layout = StreamLayout(type: .vertical)
            self.onUpdateLayout?(layout)
        }
        
        alert.addLocalizedAction(titleKey: "common.cancel", style: .cancel)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func restoreControlSettings() {
        // 根据保存的设置恢复控件状态
        if let lastUrl = controlSettings.lastStreamUrl, !lastUrl.isEmpty {
            urlTextField.text = lastUrl
        }
        
        if controlSettings.lastBitrate > 0 {
            bitrateSlider.value = Float(controlSettings.lastBitrate)
            bitrateValueLabel.text = "\(controlSettings.lastBitrate) kbps"
        }
        
        if controlSettings.lastResolutionIndex >= 0 && controlSettings.lastResolutionIndex < resolutionSegmentedControl.numberOfSegments {
            resolutionSegmentedControl.selectedSegmentIndex = controlSettings.lastResolutionIndex
        }
    }
    
    deinit {
        // 保存当前设置
        controlSettings.lastStreamUrl = urlTextField.text
        controlSettings.lastBitrate = Int(bitrateSlider.value)
        controlSettings.lastResolutionIndex = resolutionSegmentedControl.selectedSegmentIndex
        
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 媒体中继控制面板

/// 媒体中继控制面板视图
/// 需求: 11.4, 8.2 - 媒体中继 UI 控制组件
public class MediaRelayControlPanelView: UIView {
    
    // MARK: - Properties
    
    /// 媒体中继控制设置持久化
    @RealtimeStorage("mediaRelayControlSettings", namespace: "RealtimeKit.UI.MediaRelay")
    public var controlSettings: MediaRelayControlSettings = MediaRelayControlSettings()
    
    /// 当前媒体中继状态
    public var mediaRelayState: MediaRelayState? {
        didSet {
            updateControlsFromState()
        }
    }
    
    /// 媒体中继配置
    public var mediaRelayConfig: MediaRelayConfig? {
        didSet {
            updateConfigurationDisplay()
        }
    }
    
    /// 开始媒体中继回调
    public var onStartMediaRelay: ((MediaRelayConfig) -> Void)?
    
    /// 停止媒体中继回调
    public var onStopMediaRelay: (() -> Void)?
    
    /// 添加目标频道回调
    public var onAddDestinationChannel: ((String, String) -> Void)?
    
    /// 移除目标频道回调
    public var onRemoveDestinationChannel: ((String) -> Void)?
    
    // MARK: - UI Components
    
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let statusIndicator = UIView()
    private let startStopButton = UIButton(type: .system)
    private let addChannelButton = UIButton(type: .system)
    private let sourceChannelTextField = UITextField()
    private let destinationChannelsTableView = UITableView()
    private let addChannelTextField = UITextField()
    private let addChannelTokenTextField = UITextField()
    
    /// 目标频道列表
    private var destinationChannels: [(channel: String, token: String)] = []
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLocalization()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupLocalization()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        setupStackView()
        setupTitleAndStatus()
        setupControls()
        setupChannelManagement()
        setupConstraints()
        
        // 恢复控制设置
        restoreControlSettings()
    }
    
    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
    }
    
    private func setupTitleAndStatus() {
        // 标题
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        // 状态容器
        let statusContainer = UIView()
        
        // 状态指示器
        statusIndicator.backgroundColor = .systemGray3
        statusIndicator.layer.cornerRadius = 6
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // 状态标签
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        
        let statusStack = UIStackView(arrangedSubviews: [statusIndicator, statusLabel])
        statusStack.axis = .horizontal
        statusStack.spacing = 8
        statusStack.alignment = .center
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        
        statusContainer.addSubview(statusStack)
        
        NSLayoutConstraint.activate([
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            statusStack.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            statusStack.topAnchor.constraint(equalTo: statusContainer.topAnchor),
            statusStack.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor)
        ])
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(statusContainer)
    }
    
    private func setupControls() {
        // 源频道输入框
        sourceChannelTextField.placeholder = "Source Channel"
        sourceChannelTextField.borderStyle = .roundedRect
        sourceChannelTextField.font = UIFont.systemFont(ofSize: 14)
        
        // 开始/停止按钮
        startStopButton.setTitle("Start Relay", for: .normal)
        startStopButton.backgroundColor = .systemBlue
        startStopButton.setTitleColor(.white, for: .normal)
        startStopButton.layer.cornerRadius = 8
        startStopButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        startStopButton.addTarget(self, action: #selector(startStopButtonTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(sourceChannelTextField)
        stackView.addArrangedSubview(startStopButton)
        
        // 设置按钮高度
        startStopButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
    
    private func setupChannelManagement() {
        // 目标频道标签
        let destinationLabel = UILabel()
        destinationLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        destinationLabel.textColor = .label
        destinationLabel.text = "Destination Channels"
        
        // 添加频道输入框
        addChannelTextField.placeholder = "Channel Name"
        addChannelTextField.borderStyle = .roundedRect
        addChannelTextField.font = UIFont.systemFont(ofSize: 14)
        
        addChannelTokenTextField.placeholder = "Channel Token"
        addChannelTokenTextField.borderStyle = .roundedRect
        addChannelTokenTextField.font = UIFont.systemFont(ofSize: 14)
        
        // 添加频道按钮
        addChannelButton.setTitle("Add Channel", for: .normal)
        addChannelButton.backgroundColor = .systemGreen
        addChannelButton.setTitleColor(.white, for: .normal)
        addChannelButton.layer.cornerRadius = 6
        addChannelButton.addTarget(self, action: #selector(addChannelButtonTapped), for: .touchUpInside)
        
        // 频道列表表格
        destinationChannelsTableView.delegate = self
        destinationChannelsTableView.dataSource = self
        destinationChannelsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ChannelCell")
        destinationChannelsTableView.layer.cornerRadius = 8
        destinationChannelsTableView.layer.borderWidth = 1
        destinationChannelsTableView.layer.borderColor = UIColor.systemGray4.cgColor
        
        stackView.addArrangedSubview(destinationLabel)
        stackView.addArrangedSubview(addChannelTextField)
        stackView.addArrangedSubview(addChannelTokenTextField)
        stackView.addArrangedSubview(addChannelButton)
        stackView.addArrangedSubview(destinationChannelsTableView)
        
        // 设置表格高度
        destinationChannelsTableView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        addChannelButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    private func setupLocalization() {
        titleLabel.setLocalizedText("media_relay.title", fallbackValue: "Media Relay")
        startStopButton.setLocalizedTitle("media_relay.start", fallbackValue: "Start Relay")
        addChannelButton.setLocalizedTitle("media_relay.add_channel", fallbackValue: "Add Channel")
        sourceChannelTextField.setLocalizedPlaceholder("media_relay.source_channel", fallbackValue: "Source Channel")
        addChannelTextField.setLocalizedPlaceholder("media_relay.channel_name", fallbackValue: "Channel Name")
        addChannelTokenTextField.setLocalizedPlaceholder("media_relay.channel_token", fallbackValue: "Channel Token")
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    @objc private func startStopButtonTapped() {
        if mediaRelayState == .running {
            stopMediaRelay()
        } else {
            startMediaRelay()
        }
        
        // 更新控制设置
        controlSettings.lastButtonTapDate = Date()
        controlSettings.buttonTapCount += 1
    }
    
    @objc private func addChannelButtonTapped() {
        guard let channelName = addChannelTextField.text, !channelName.isEmpty,
              let channelToken = addChannelTokenTextField.text, !channelToken.isEmpty else {
            showErrorAlert(message: "Please enter both channel name and token")
            return
        }
        
        // 检查是否已存在
        if destinationChannels.contains(where: { $0.channel == channelName }) {
            showErrorAlert(message: "Channel already exists")
            return
        }
        
        destinationChannels.append((channel: channelName, token: channelToken))
        destinationChannelsTableView.reloadData()
        
        // 清空输入框
        addChannelTextField.text = ""
        addChannelTokenTextField.text = ""
        
        // 触发回调
        onAddDestinationChannel?(channelName, channelToken)
        
        // 更新控制设置
        controlSettings.channelAddCount += 1
        controlSettings.lastChannelChangeDate = Date()
    }
    
    @objc private func languageDidChange() {
        titleLabel.setLocalizedText("media_relay.title", fallbackValue: "Media Relay")
        addChannelButton.setLocalizedTitle("media_relay.add_channel", fallbackValue: "Add Channel")
        sourceChannelTextField.setLocalizedPlaceholder("media_relay.source_channel", fallbackValue: "Source Channel")
        addChannelTextField.setLocalizedPlaceholder("media_relay.channel_name", fallbackValue: "Channel Name")
        addChannelTokenTextField.setLocalizedPlaceholder("media_relay.channel_token", fallbackValue: "Channel Token")
        
        updateControlsFromState() // 更新状态相关的本地化文本
    }
    
    // MARK: - Private Methods
    
    private func startMediaRelay() {
        guard let sourceChannel = sourceChannelTextField.text, !sourceChannel.isEmpty else {
            showErrorAlert(message: "Please enter a source channel")
            return
        }
        
        guard !destinationChannels.isEmpty else {
            showErrorAlert(message: "Please add at least one destination channel")
            return
        }
        
        let destinationChannelInfos = destinationChannels.map { channel in
            MediaRelayChannelInfo(channelName: channel.channel, userId: "user_\(channel.channel)", token: channel.token)
        }
        
        let config = try MediaRelayConfig(
            sourceChannel: MediaRelayChannelInfo(channelName: sourceChannel, userId: "source_user", token: ""),
            destinationChannels: destinationChannelInfos
        )
        
        onStartMediaRelay?(config)
    }
    
    private func stopMediaRelay() {
        onStopMediaRelay?()
    }
    
    private func updateControlsFromState() {
        guard let state = mediaRelayState else {
            statusIndicator.backgroundColor = .systemGray3
            statusLabel.setLocalizedText("media_relay.status.idle", fallbackValue: "Idle")
            startStopButton.setLocalizedTitle("media_relay.start", fallbackValue: "Start Relay")
            startStopButton.backgroundColor = .systemBlue
            startStopButton.isEnabled = true
            return
        }
        
        DispatchQueue.main.async {
            switch state {
            case .idle:
                self.statusIndicator.backgroundColor = .systemGray3
                self.statusLabel.setLocalizedText("media_relay.status.idle", fallbackValue: "Idle")
                self.startStopButton.setLocalizedTitle("media_relay.start", fallbackValue: "Start Relay")
                self.startStopButton.backgroundColor = .systemBlue
                self.startStopButton.isEnabled = true
                
            case .running:
                self.statusIndicator.backgroundColor = .systemGreen
                self.statusLabel.setLocalizedText("media_relay.status.running", fallbackValue: "Running")
                self.startStopButton.setLocalizedTitle("media_relay.stop", fallbackValue: "Stop Relay")
                self.startStopButton.backgroundColor = .systemRed
                self.startStopButton.isEnabled = true
                
            case .failure:
                self.statusIndicator.backgroundColor = .systemRed
                self.statusLabel.setLocalizedText("media_relay.status.failed", fallbackValue: "Failed")
                self.startStopButton.setLocalizedTitle("media_relay.retry", fallbackValue: "Retry")
                self.startStopButton.backgroundColor = .systemBlue
                self.startStopButton.isEnabled = true
            }
        }
    }
    
    private func updateConfigurationDisplay() {
        guard let config = mediaRelayConfig else { return }
        
        sourceChannelTextField.text = config.sourceChannel.channelName
        
        destinationChannels = config.destinationChannels.map { channelInfo in
            (channel: channelInfo.channelName, token: channelInfo.token)
        }
        
        destinationChannelsTableView.reloadData()
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func restoreControlSettings() {
        // 根据保存的设置恢复控件状态
        if let lastSourceChannel = controlSettings.lastSourceChannel, !lastSourceChannel.isEmpty {
            sourceChannelTextField.text = lastSourceChannel
        }
    }
    
    deinit {
        // 保存当前设置
        controlSettings.lastSourceChannel = sourceChannelTextField.text
        
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - MediaRelayControlPanelView TableView DataSource and Delegate

extension MediaRelayControlPanelView: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return destinationChannels.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChannelCell", for: indexPath)
        let channel = destinationChannels[indexPath.row]
        cell.textLabel?.text = channel.channel
        cell.detailTextLabel?.text = String(channel.token.prefix(10)) + "..."
        return cell
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let channel = destinationChannels[indexPath.row]
            destinationChannels.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // 触发回调
            onRemoveDestinationChannel?(channel.channel)
            
            // 更新控制设置
            controlSettings.channelRemoveCount += 1
            controlSettings.lastChannelChangeDate = Date()
        }
    }
}

// MARK: - Control Settings Models

/// 转推流控制设置
/// 需求: 18.10 - 用户界面设置和偏好持久化
public struct StreamPushControlSettings: Codable, Sendable {
    /// 最后的推流 URL
    public var lastStreamUrl: String?
    
    /// 最后的码率设置
    public var lastBitrate: Int = 2000
    
    /// 最后的分辨率索引
    public var lastResolutionIndex: Int = 0
    
    /// 最后的按钮点击日期
    public var lastButtonTapDate: Date?
    
    /// 按钮点击次数
    public var buttonTapCount: Int = 0
    
    /// 配置界面查看次数
    public var configurationViewCount: Int = 0
    
    /// 布局变化次数
    public var layoutChangeCount: Int = 0
    
    /// 最后的配置变化日期
    public var lastConfigChangeDate: Date?
    
    public init() {}
}

/// 媒体中继控制设置
/// 需求: 18.10 - 用户界面设置和偏好持久化
public struct MediaRelayControlSettings: Codable, Sendable {
    /// 最后的源频道
    public var lastSourceChannel: String?
    
    /// 最后的按钮点击日期
    public var lastButtonTapDate: Date?
    
    /// 按钮点击次数
    public var buttonTapCount: Int = 0
    
    /// 频道添加次数
    public var channelAddCount: Int = 0
    
    /// 频道移除次数
    public var channelRemoveCount: Int = 0
    
    /// 最后的频道变化日期
    public var lastChannelChangeDate: Date?
    
    public init() {}
}

// MARK: - UIView Extension for Finding View Controller

extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

/// 转推流控制视图
/// 需求: 11.4, 7.2 - 转推流的 UI 控制组件
public class StreamPushControlView: UIView {
    
    // MARK: - Properties
    
    /// 转推流管理器
    public weak var streamPushManager: StreamPushManager?
    
    /// 当前转推流状态
    public private(set) var streamPushState: StreamPushState = .stopped {
        didSet {
            DispatchQueue.main.async {
                self.updateUI()
            }
        }
    }
    
    /// 转推流配置
    public private(set) var streamPushConfig: StreamPushConfig?
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let configButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
        
        // 标题标签
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.setLocalizedText("stream_push.title", fallbackValue: "Stream Push")
        addSubview(titleLabel)
        
        // 状态标签
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.setLocalizedText("stream_push.status.stopped", fallbackValue: "Stopped")
        addSubview(statusLabel)
        
        // 开始按钮
        startButton.setLocalizedTitle("stream_push.start", fallbackValue: "Start")
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        addSubview(startButton)
        
        // 停止按钮
        stopButton.setLocalizedTitle("stream_push.stop", fallbackValue: "Stop")
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        stopButton.isEnabled = false
        addSubview(stopButton)
        
        // 配置按钮
        configButton.setLocalizedTitle("stream_push.config", fallbackValue: "Config")
        configButton.addTarget(self, action: #selector(configButtonTapped), for: .touchUpInside)
        addSubview(configButton)
        
        // 进度视图
        progressView.isHidden = true
        addSubview(progressView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        configButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // 状态
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // 按钮
            startButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            startButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            startButton.widthAnchor.constraint(equalToConstant: 80),
            
            stopButton.topAnchor.constraint(equalTo: startButton.topAnchor),
            stopButton.leadingAnchor.constraint(equalTo: startButton.trailingAnchor, constant: 8),
            stopButton.widthAnchor.constraint(equalToConstant: 80),
            
            configButton.topAnchor.constraint(equalTo: startButton.topAnchor),
            configButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            configButton.widthAnchor.constraint(equalToConstant: 80),
            
            // 进度视图
            progressView.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func startButtonTapped() {
        guard let config = streamPushConfig else {
            showConfigurationAlert()
            return
        }
        
        Task {
            do {
                try await streamPushManager?.startStreamPush(config: config)
            } catch {
                showErrorAlert(error)
            }
        }
    }
    
    @objc private func stopButtonTapped() {
        Task {
            do {
                try await streamPushManager?.stopStreamPush()
            } catch {
                showErrorAlert(error)
            }
        }
    }
    
    @objc private func configButtonTapped() {
        // 显示配置界面
        showConfigurationInterface()
    }
    
    // MARK: - Public Methods
    
    /// 配置转推流管理器
    public func configure(with manager: StreamPushManager) {
        self.streamPushManager = manager
    }
    
    /// 更新转推流状态
    public func updateStreamPushState(_ state: StreamPushState) {
        self.streamPushState = state
    }
    
    /// 设置转推流配置
    public func setStreamPushConfig(_ config: StreamPushConfig) {
        self.streamPushConfig = config
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        switch streamPushState {
        case .stopped:
            statusLabel.setLocalizedText("stream_push.status.stopped", fallbackValue: "Stopped")
            statusLabel.textColor = .secondaryLabel
            startButton.isEnabled = true
            stopButton.isEnabled = false
            progressView.isHidden = true
            
        case .starting:
            statusLabel.setLocalizedText("stream_push.status.starting", fallbackValue: "Starting...")
            statusLabel.textColor = .systemOrange
            startButton.isEnabled = false
            stopButton.isEnabled = false
            progressView.isHidden = false
            
        case .running:
            statusLabel.setLocalizedText("stream_push.status.running", fallbackValue: "Running")
            statusLabel.textColor = .systemGreen
            startButton.isEnabled = false
            stopButton.isEnabled = true
            progressView.isHidden = true
            
        case .stopping:
            statusLabel.setLocalizedText("stream_push.status.stopping", fallbackValue: "Stopping...")
            statusLabel.textColor = .systemOrange
            startButton.isEnabled = false
            stopButton.isEnabled = false
            progressView.isHidden = false
            
        case .failed:
            statusLabel.setLocalizedText("stream_push.status.failed", fallbackValue: "Failed")
            statusLabel.textColor = .systemRed
            startButton.isEnabled = true
            stopButton.isEnabled = false
            progressView.isHidden = true
        }
    }
    
    private func showConfigurationAlert() {
        let alert = UIAlertController.localizedAlert(
            titleKey: "stream_push.config.required.title",
            messageKey: "stream_push.config.required.message",
            preferredStyle: .alert
        )
        
        alert.addLocalizedAction(titleKey: "common.ok", style: .default)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func showErrorAlert(_ error: Error) {
        let localizedError = LocalizedRealtimeError.from(error)
        let alert = UIAlertController.localizedAlert(
            titleKey: "error.title",
            messageKey: localizedError.localizationKey,
            preferredStyle: .alert
        )
        
        alert.addLocalizedAction(titleKey: "common.ok", style: .default)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func showConfigurationInterface() {
        // 这里可以显示更详细的配置界面
        // 暂时使用简单的输入对话框
        let alert = UIAlertController.localizedAlert(
            titleKey: "stream_push.config.title",
            messageKey: "stream_push.config.message",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "RTMP URL"
            textField.text = self.streamPushConfig?.url
        }
        
        alert.addLocalizedAction(titleKey: "common.save", style: .default) { _ in
            if let url = alert.textFields?.first?.text, !url.isEmpty {
                do {
                    let config = try StreamPushConfig(url: url)
                    self.setStreamPushConfig(config)
                } catch {
                    // Handle configuration error
                    print("Failed to create stream push config: \(error)")
                }
            }
        }
        
        alert.addLocalizedAction(titleKey: "common.cancel", style: .cancel)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
}

/// 媒体中继控制视图
/// 需求: 11.4, 8.2 - 媒体中继的 UI 控制组件
public class MediaRelayControlView: UIView {
    
    // MARK: - Properties
    
    /// 媒体中继管理器
    public weak var mediaRelayManager: MediaRelayManager?
    
    /// 当前媒体中继状态
    public private(set) var mediaRelayState: MediaRelayState = .idle {
        didSet {
            DispatchQueue.main.async {
                self.updateUI()
            }
        }
    }
    
    /// 媒体中继配置
    public private(set) var mediaRelayConfig: MediaRelayConfig?
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let configButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
        
        // 标题标签
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.setLocalizedText("media_relay.title", fallbackValue: "Media Relay")
        addSubview(titleLabel)
        
        // 状态标签
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.setLocalizedText("media_relay.status.idle", fallbackValue: "Idle")
        addSubview(statusLabel)
        
        // 开始按钮
        startButton.setLocalizedTitle("media_relay.start", fallbackValue: "Start")
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        addSubview(startButton)
        
        // 停止按钮
        stopButton.setLocalizedTitle("media_relay.stop", fallbackValue: "Stop")
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        stopButton.isEnabled = false
        addSubview(stopButton)
        
        // 配置按钮
        configButton.setLocalizedTitle("media_relay.config", fallbackValue: "Config")
        configButton.addTarget(self, action: #selector(configButtonTapped), for: .touchUpInside)
        addSubview(configButton)
        
        // 进度视图
        progressView.isHidden = true
        addSubview(progressView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        configButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // 状态
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // 按钮
            startButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            startButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            startButton.widthAnchor.constraint(equalToConstant: 80),
            
            stopButton.topAnchor.constraint(equalTo: startButton.topAnchor),
            stopButton.leadingAnchor.constraint(equalTo: startButton.trailingAnchor, constant: 8),
            stopButton.widthAnchor.constraint(equalToConstant: 80),
            
            configButton.topAnchor.constraint(equalTo: startButton.topAnchor),
            configButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            configButton.widthAnchor.constraint(equalToConstant: 80),
            
            // 进度视图
            progressView.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func startButtonTapped() {
        guard let config = mediaRelayConfig else {
            showConfigurationAlert()
            return
        }
        
        Task {
            do {
                try await mediaRelayManager?.startRelay(config: config)
            } catch {
                showErrorAlert(error)
            }
        }
    }
    
    @objc private func stopButtonTapped() {
        Task {
            do {
                try await mediaRelayManager?.stopRelay()
            } catch {
                showErrorAlert(error)
            }
        }
    }
    
    @objc private func configButtonTapped() {
        showConfigurationInterface()
    }
    
    // MARK: - Public Methods
    
    /// 配置媒体中继管理器
    public func configure(with manager: MediaRelayManager) {
        self.mediaRelayManager = manager
    }
    
    /// 更新媒体中继状态
    public func updateMediaRelayState(_ state: MediaRelayState) {
        self.mediaRelayState = state
    }
    
    /// 设置媒体中继配置
    public func setMediaRelayConfig(_ config: MediaRelayConfig) {
        self.mediaRelayConfig = config
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        switch mediaRelayState {
        case .idle:
            statusLabel.setLocalizedText("media_relay.status.idle", fallbackValue: "Idle")
            statusLabel.textColor = .secondaryLabel
            startButton.isEnabled = true
            stopButton.isEnabled = false
            progressView.isHidden = true
            
        case .connecting:
            statusLabel.setLocalizedText("media_relay.status.connecting", fallbackValue: "Connecting...")
            statusLabel.textColor = .systemOrange
            startButton.isEnabled = false
            stopButton.isEnabled = false
            progressView.isHidden = false
            
        case .running:
            statusLabel.setLocalizedText("media_relay.status.running", fallbackValue: "Running")
            statusLabel.textColor = .systemGreen
            startButton.isEnabled = false
            stopButton.isEnabled = true
            progressView.isHidden = true
            
        case .paused:
            statusLabel.setLocalizedText("media_relay.status.paused", fallbackValue: "Paused")
            statusLabel.textColor = .systemYellow
            startButton.isEnabled = true
            stopButton.isEnabled = true
            progressView.isHidden = true
            
        case .stopping:
            statusLabel.setLocalizedText("media_relay.status.stopping", fallbackValue: "Stopping...")
            statusLabel.textColor = .systemOrange
            startButton.isEnabled = false
            stopButton.isEnabled = false
            progressView.isHidden = false
            
        case .failure:
            statusLabel.setLocalizedText("media_relay.status.failed", fallbackValue: "Failed")
            statusLabel.textColor = .systemRed
            startButton.isEnabled = true
            stopButton.isEnabled = false
            progressView.isHidden = true
        }
    }
    
    private func showConfigurationAlert() {
        let alert = UIAlertController.localizedAlert(
            titleKey: "media_relay.config.required.title",
            messageKey: "media_relay.config.required.message",
            preferredStyle: .alert
        )
        
        alert.addLocalizedAction(titleKey: "common.ok", style: .default)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func showErrorAlert(_ error: Error) {
        let localizedError = LocalizedErrorFactory.createLocalizedError(from: error)
        let alert = UIAlertController.localizedAlert(
            titleKey: "error.title",
            message: localizedError.errorDescription ?? error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addLocalizedAction(titleKey: "common.ok", style: .default)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func showConfigurationInterface() {
        let alert = UIAlertController.localizedAlert(
            titleKey: "media_relay.config.title",
            messageKey: "media_relay.config.message",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Destination Channel"
            textField.text = self.mediaRelayConfig?.destinationChannels.first?.channelName
        }
        
        alert.addLocalizedAction(titleKey: "common.save", style: .default) { _ in
            if let channel = alert.textFields?.first?.text, !channel.isEmpty {
                do {
                    let sourceChannel = MediaRelayChannelInfo(channelName: "source", userId: "source_user", token: "")
                    let destinationChannel = MediaRelayChannelInfo(channelName: channel, userId: "dest_user", token: "")
                    let config = try MediaRelayConfig(sourceChannel: sourceChannel, destinationChannels: [destinationChannel])
                    self.setMediaRelayConfig(config)
                } catch {
                    print("Failed to create media relay config: \(error)")
                }
            }
        }
        
        alert.addLocalizedAction(titleKey: "common.cancel", style: .cancel)
        
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
}

/// 错误处理和用户反馈视图
/// 需求: 11.4, 17.6 - 错误处理和用户反馈 UI 组件，本地化的用户界面文本和提示
public class ErrorHandlingView: UIView {
    
    // MARK: - Properties
    
    /// 错误显示模式
    public enum DisplayMode {
        case banner
        case modal
        case inline
    }
    
    /// 当前显示模式
    public var displayMode: DisplayMode = .banner
    
    /// 是否自动隐藏
    public var autoHide: Bool = true
    
    /// 自动隐藏延迟（秒）
    public var autoHideDelay: TimeInterval = 3.0
    
    /// 错误历史记录
    @RealtimeStorage("errorHistory", namespace: "RealtimeKit.UI.ErrorHandling")
    public var errorHistory: [ErrorHistoryEntry] = []
    
    // MARK: - UI Components
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    
    private var actionHandler: (() -> Void)?
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear
        
        // 容器视图
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 8
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        containerView.layer.shadowOpacity = 0.1
        addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemRed
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        containerView.addSubview(titleLabel)
        
        // 消息
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        containerView.addSubview(messageLabel)
        
        // 操作按钮
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        actionButton.setTitleColor(.systemBlue, for: .normal)
        containerView.addSubview(actionButton)
        
        // 关闭按钮
        dismissButton.setTitle("×", for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        dismissButton.setTitleColor(.systemGray, for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        containerView.addSubview(dismissButton)
        
        setupConstraints()
        
        // 初始状态隐藏
        isHidden = true
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 容器视图
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 图标
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // 关闭按钮
            dismissButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            dismissButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            dismissButton.widthAnchor.constraint(equalToConstant: 24),
            dismissButton.heightAnchor.constraint(equalToConstant: 24),
            
            // 标题
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            
            // 消息
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            // 操作按钮
            actionButton.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor),
            actionButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Public Methods
    
    /// 显示错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - actionTitle: 操作按钮标题
    ///   - actionHandler: 操作按钮处理器
    public func showError(
        _ error: Error,
        actionTitle: String? = nil,
        actionHandler: (() -> Void)? = nil
    ) {
        let localizedError = LocalizedErrorFactory.createLocalizedError(from: error)
        let localizationManager = LocalizationManager.shared
        
        // 设置图标
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        
        // 设置标题和消息
        titleLabel.text = localizationManager.localizedString(for: "error.title")
        messageLabel.text = localizationManager.localizedString(for: localizedError.localizationKey)
        
        // 设置操作按钮
        if let actionTitle = actionTitle, let actionHandler = actionHandler {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
            
            // 移除之前的 target
            actionButton.removeTarget(nil, action: nil, for: .allEvents)
            if #available(iOS 14.0, *) {
                actionButton.addAction(UIAction { _ in actionHandler() }, for: .touchUpInside)
            } else {
                actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
                self.actionHandler = actionHandler
            }
        } else {
            actionButton.isHidden = true
        }
        
        // 记录错误历史
        recordError(error)
        
        // 显示错误视图
        showErrorView()
    }
    
    /// 显示成功消息
    /// - Parameter message: 成功消息
    public func showSuccess(_ message: String) {
        iconImageView.image = UIImage(systemName: "checkmark.circle.fill")
        iconImageView.tintColor = .systemGreen
        
        titleLabel.text = LocalizationManager.shared.localizedString(for: "success.title")
        messageLabel.text = message
        actionButton.isHidden = true
        
        showErrorView()
    }
    
    /// 显示警告消息
    /// - Parameter message: 警告消息
    public func showWarning(_ message: String) {
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        iconImageView.tintColor = .systemOrange
        
        titleLabel.text = LocalizationManager.shared.localizedString(for: "warning.title")
        messageLabel.text = message
        actionButton.isHidden = true
        
        showErrorView()
    }
    
    /// 隐藏错误视图
    public func hideError() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { _ in
            self.isHidden = true
            self.alpha = 1
        }
    }
    
    /// 获取错误历史
    /// - Parameter limit: 返回记录数量限制
    /// - Returns: 错误历史记录数组
    public func getErrorHistory(limit: Int = 50) -> [ErrorHistoryEntry] {
        return Array(errorHistory.suffix(limit))
    }
    
    /// 清除错误历史
    public func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    @objc private func actionButtonTapped() {
        actionHandler?()
    }
    
    private func showErrorView() {
        isHidden = false
        alpha = 0
        
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
        
        // 自动隐藏
        if autoHide {
            DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay) {
                self.hideError()
            }
        }
    }
    
    private func recordError(_ error: Error) {
        let entry = ErrorHistoryEntry(
            error: error,
            timestamp: Date(),
            viewType: String(describing: type(of: self))
        )
        
        errorHistory.append(entry)
        
        // 保持最近100条记录
        if errorHistory.count > 100 {
            errorHistory.removeFirst()
        }
    }
    
    @objc private func dismissButtonTapped() {
        hideError()
    }
}

// MARK: - Supporting Data Models

/// 错误历史记录条目
/// 需求: 18.10 - 错误历史持久化
public struct ErrorHistoryEntry: Codable, Sendable {
    public let errorDescription: String
    public let errorCode: Int
    public let timestamp: Date
    public let viewType: String
    
    public init(error: Error, timestamp: Date, viewType: String) {
        self.errorDescription = error.localizedDescription
        self.errorCode = (error as NSError).code
        self.timestamp = timestamp
        self.viewType = viewType
    }
}

// MARK: - UIView Extensions for Error Handling



// MARK: - Notification Names

extension Notification.Name {
    static let realtimeConnectionStateChanged = Notification.Name("RealtimeKit.connectionStateChanged")
    static let realtimeVolumeInfoUpdated = Notification.Name("RealtimeKit.volumeInfoUpdated")
    static let realtimeErrorOccurred = Notification.Name("RealtimeKit.errorOccurred")
}

#endif
