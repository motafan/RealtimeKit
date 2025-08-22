import Foundation
import RealtimeCore

#if canImport(UIKit)
import UIKit
#endif

/// RealtimeUIKit 模块
/// 提供 UIKit 框架的集成支持
/// 需求: 11.1, 11.4, 15.5

#if canImport(UIKit) && !os(watchOS)

// MARK: - UIKit 基础组件

/// RealtimeKit UIKit 集成的基础视图控制器
open class RealtimeViewController: UIViewController {
    
    // MARK: - Properties
    
    /// RealtimeManager 实例
    public let realtimeManager = RealtimeManager.shared
    
    /// 当前连接状态
    public private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            DispatchQueue.main.async {
                self.connectionStateDidChange(from: oldValue, to: self.connectionState)
            }
        }
    }
    
    /// 当前音量信息
    public private(set) var volumeInfos: [UserVolumeInfo] = [] {
        didSet {
            DispatchQueue.main.async {
                self.volumeInfosDidUpdate(self.volumeInfos)
            }
        }
    }
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupRealtimeKit()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startObservingRealtimeEvents()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopObservingRealtimeEvents()
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
    }
    
    private func stopObservingRealtimeEvents() {
        NotificationCenter.default.removeObserver(self)
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
}

/// 音量可视化视图
public class VolumeVisualizationView: UIView {
    
    // MARK: - Properties
    
    /// 当前音量级别 (0.0 - 1.0)
    public var volumeLevel: Float = 0.0 {
        didSet {
            DispatchQueue.main.async {
                self.updateVisualization()
            }
        }
    }
    
    /// 是否正在说话
    public var isSpeaking: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.updateSpeakingState()
            }
        }
    }
    
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
    
    private let volumeBar = UIView()
    private let backgroundBar = UIView()
    
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
        backgroundBar.backgroundColor = UIColor.systemGray5
        backgroundBar.layer.cornerRadius = 2
        addSubview(backgroundBar)
        
        // 音量条
        volumeBar.backgroundColor = volumeColor
        volumeBar.layer.cornerRadius = 2
        addSubview(volumeBar)
        
        setupConstraints()
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
    }
    
    // MARK: - Updates
    
    private func updateVisualization() {
        let width = bounds.width * CGFloat(volumeLevel)
        volumeBar.frame.size.width = width
        volumeBar.backgroundColor = isSpeaking ? speakingColor : volumeColor
    }
    
    private func updateSpeakingState() {
        UIView.animate(withDuration: 0.2) {
            self.volumeBar.backgroundColor = self.isSpeaking ? self.speakingColor : self.volumeColor
            self.transform = self.isSpeaking ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateVisualization()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let realtimeConnectionStateChanged = Notification.Name("RealtimeKit.connectionStateChanged")
    static let realtimeVolumeInfoUpdated = Notification.Name("RealtimeKit.volumeInfoUpdated")
}

#endif