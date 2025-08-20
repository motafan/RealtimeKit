// RealtimeUIKit.swift
// UIKit integration module for RealtimeKit

#if canImport(UIKit)
import UIKit
import Combine
import RealtimeCore

/// RealtimeUIKit version information
public struct RealtimeUIKitVersion {
    public static let current = "1.0.0"
    public static let build = "1"
}

// MARK: - UIKit Extensions and Utilities

/// Base view controller for RealtimeKit UIKit integration
@available(iOS 13.0, *)
open class RealtimeViewController: UIViewController {
    
    /// RealtimeManager instance for this view controller
    public let realtimeManager = RealtimeManager.shared
    
    /// Delegate for handling RealtimeKit events
    public weak var delegate: RealtimeUIKitDelegate?
    
    /// Closure-based event handlers
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
    public var onUserJoined: ((String) -> Void)?
    public var onUserLeft: ((String) -> Void)?
    public var onVolumeChanged: (([UserVolumeInfo]) -> Void)?
    public var onMessageReceived: ((RealtimeMessage) -> Void)?
    public var onError: ((RealtimeError) -> Void)?
    
    /// Combine cancellables for reactive updates
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user session
    public var currentSession: UserSession? {
        return realtimeManager.currentSession
    }
    
    /// Current audio settings
    public var audioSettings: AudioSettings {
        return realtimeManager.audioSettings
    }
    
    /// Current connection state
    public var connectionState: ConnectionState {
        return realtimeManager.connectionState
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupRealtimeKit()
        setupReactiveBindings()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshRealtimeState()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    /// Override this method to setup RealtimeKit specific configurations
    open func setupRealtimeKit() {
        // To be implemented by subclasses
    }
    
    /// Override this method to handle RealtimeKit events
    open func handleRealtimeEvent(_ event: RealtimeEvent) {
        // Default implementation calls delegate and closures
        delegate?.realtimeKit(realtimeManager, didReceiveEvent: event)
        
        switch event {
        case .connectionStateChanged(let state):
            onConnectionStateChanged?(state)
        case .userJoined(let userId):
            onUserJoined?(userId)
        case .userLeft(let userId):
            onUserLeft?(userId)
        case .volumeChanged(let volumeInfos):
            onVolumeChanged?(volumeInfos)
        case .messageReceived(let message):
            onMessageReceived?(message)
        case .error(let error):
            onError?(error)
            delegate?.realtimeKit(realtimeManager, didEncounterError: error)
        }
    }
    
    /// Setup reactive bindings to RealtimeManager
    private func setupReactiveBindings() {
        // Connection state changes
        realtimeManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleRealtimeEvent(.connectionStateChanged(state))
            }
            .store(in: &cancellables)
        
        // Volume changes
        realtimeManager.$volumeInfos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumeInfos in
                self?.handleRealtimeEvent(.volumeChanged(volumeInfos))
            }
            .store(in: &cancellables)
        
        // Audio settings changes
        realtimeManager.$audioSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.audioSettingsDidChange()
            }
            .store(in: &cancellables)
        
        // Session changes
        realtimeManager.$currentSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.sessionDidChange(session)
            }
            .store(in: &cancellables)
    }
    
    /// Called when audio settings change
    open func audioSettingsDidChange() {
        // To be overridden by subclasses
    }
    
    /// Called when session changes
    open func sessionDidChange(_ session: UserSession?) {
        // To be overridden by subclasses
    }
    
    /// Refresh the current realtime state
    private func refreshRealtimeState() {
        // Trigger initial state updates
        handleRealtimeEvent(.connectionStateChanged(connectionState))
        if !realtimeManager.volumeInfos.isEmpty {
            handleRealtimeEvent(.volumeChanged(realtimeManager.volumeInfos))
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Join a room with the current user session
    public func joinRoom(_ roomId: String) async throws {
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        try await realtimeManager.joinRoom(roomId: roomId, userId: session.userId, userRole: session.userRole)
    }
    
    /// Leave the current room
    public func leaveRoom() async throws {
        try await realtimeManager.leaveRoom()
    }
    
    /// Toggle microphone mute state
    public func toggleMicrophone() async throws {
        let currentlyMuted = audioSettings.microphoneMuted
        try await realtimeManager.muteMicrophone(!currentlyMuted)
    }
    
    /// Set audio mixing volume
    public func setAudioMixingVolume(_ volume: Int) async throws {
        try await realtimeManager.setAudioMixingVolume(volume)
    }
}

/// RealtimeKit events for UIKit integration
public enum RealtimeEvent {
    case connectionStateChanged(ConnectionState)
    case userJoined(String)
    case userLeft(String)
    case volumeChanged([UserVolumeInfo])
    case messageReceived(RealtimeMessage)
    case error(RealtimeError)
}

/// Protocol for RealtimeKit UIKit delegates
@available(iOS 13.0, *)
public protocol RealtimeUIKitDelegate: AnyObject {
    func realtimeKit(_ manager: RealtimeManager, didReceiveEvent event: RealtimeEvent)
    func realtimeKit(_ manager: RealtimeManager, didEncounterError error: RealtimeError)
}

// MARK: - Volume Visualization Components

/// A UIView that displays volume levels with animated bars
@available(iOS 13.0, *)
public class VolumeVisualizationView: UIView {
    
    /// Configuration for volume visualization
    public struct Configuration {
        let barCount: Int
        let barSpacing: CGFloat
        let barCornerRadius: CGFloat
        let activeColor: UIColor
        let inactiveColor: UIColor
        let animationDuration: TimeInterval
        
        public init(
            barCount: Int = 5,
            barSpacing: CGFloat = 2.0,
            barCornerRadius: CGFloat = 1.0,
            activeColor: UIColor = .systemBlue,
            inactiveColor: UIColor = .systemGray5,
            animationDuration: TimeInterval = 0.1
        ) {
            self.barCount = barCount
            self.barSpacing = barSpacing
            self.barCornerRadius = barCornerRadius
            self.activeColor = activeColor
            self.inactiveColor = inactiveColor
            self.animationDuration = animationDuration
        }
        
        public static let `default` = Configuration()
    }
    
    /// Current volume level (0.0 - 1.0)
    public var volumeLevel: Float = 0.0 {
        didSet {
            updateVolumeDisplay()
        }
    }
    
    /// Configuration for the visualization
    public var configuration: Configuration = .default {
        didSet {
            setupBars()
        }
    }
    
    /// Whether the user is currently speaking
    public var isSpeaking: Bool = false {
        didSet {
            updateSpeakingState()
        }
    }
    
    private var volumeBars: [UIView] = []
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupBars()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBars()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutBars()
    }
    
    private func setupBars() {
        // Remove existing bars
        volumeBars.forEach { $0.removeFromSuperview() }
        volumeBars.removeAll()
        
        // Create new bars
        for _ in 0..<configuration.barCount {
            let bar = UIView()
            bar.backgroundColor = configuration.inactiveColor
            bar.layer.cornerRadius = configuration.barCornerRadius
            addSubview(bar)
            volumeBars.append(bar)
        }
        
        layoutBars()
    }
    
    private func layoutBars() {
        guard !volumeBars.isEmpty else { return }
        
        let totalSpacing = CGFloat(volumeBars.count - 1) * configuration.barSpacing
        let barWidth = (bounds.width - totalSpacing) / CGFloat(volumeBars.count)
        
        for (index, bar) in volumeBars.enumerated() {
            let x = CGFloat(index) * (barWidth + configuration.barSpacing)
            bar.frame = CGRect(x: x, y: 0, width: barWidth, height: bounds.height)
        }
    }
    
    private func updateVolumeDisplay() {
        let activeBarCount = Int(Float(configuration.barCount) * volumeLevel)
        
        UIView.animate(withDuration: configuration.animationDuration) {
            for (index, bar) in self.volumeBars.enumerated() {
                bar.backgroundColor = index < activeBarCount ? 
                    self.configuration.activeColor : 
                    self.configuration.inactiveColor
            }
        }
    }
    
    private func updateSpeakingState() {
        if isSpeaking {
            // Add pulsing animation when speaking
            let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
            pulseAnimation.duration = 0.6
            pulseAnimation.fromValue = 1.0
            pulseAnimation.toValue = 1.1
            pulseAnimation.autoreverses = true
            pulseAnimation.repeatCount = .infinity
            layer.add(pulseAnimation, forKey: "pulse")
        } else {
            // Remove pulsing animation when not speaking
            layer.removeAnimation(forKey: "pulse")
        }
    }
    
    /// Update volume info for a user
    public func updateVolumeInfo(_ volumeInfo: UserVolumeInfo) {
        volumeLevel = volumeInfo.volume
        isSpeaking = volumeInfo.isSpeaking
    }
}

/// A UIView that shows a speaking indicator with ripple animation
@available(iOS 13.0, *)
public class SpeakingIndicatorView: UIView {
    
    /// Configuration for speaking indicator
    public struct Configuration {
        let indicatorColor: UIColor
        let rippleColor: UIColor
        let animationDuration: TimeInterval
        let rippleCount: Int
        
        public init(
            indicatorColor: UIColor = .systemGreen,
            rippleColor: UIColor = .systemGreen.withAlphaComponent(0.3),
            animationDuration: TimeInterval = 1.5,
            rippleCount: Int = 3
        ) {
            self.indicatorColor = indicatorColor
            self.rippleColor = rippleColor
            self.animationDuration = animationDuration
            self.rippleCount = rippleCount
        }
        
        public static let `default` = Configuration()
    }
    
    /// Whether the indicator is currently showing speaking state
    public var isSpeaking: Bool = false {
        didSet {
            updateSpeakingState()
        }
    }
    
    /// Configuration for the indicator
    public var configuration: Configuration = .default {
        didSet {
            setupIndicator()
        }
    }
    
    private var indicatorLayer: CAShapeLayer!
    private var rippleLayers: [CAShapeLayer] = []
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupIndicator()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupIndicator()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames()
    }
    
    private func setupIndicator() {
        // Remove existing layers
        indicatorLayer?.removeFromSuperlayer()
        rippleLayers.forEach { $0.removeFromSuperlayer() }
        rippleLayers.removeAll()
        
        // Create indicator layer
        indicatorLayer = CAShapeLayer()
        indicatorLayer.fillColor = configuration.indicatorColor.cgColor
        layer.addSublayer(indicatorLayer)
        
        // Create ripple layers
        for _ in 0..<configuration.rippleCount {
            let rippleLayer = CAShapeLayer()
            rippleLayer.fillColor = UIColor.clear.cgColor
            rippleLayer.strokeColor = configuration.rippleColor.cgColor
            rippleLayer.lineWidth = 2.0
            layer.insertSublayer(rippleLayer, below: indicatorLayer)
            rippleLayers.append(rippleLayer)
        }
        
        updateLayerFrames()
    }
    
    private func updateLayerFrames() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 4
        
        let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        indicatorLayer?.path = circlePath.cgPath
        
        rippleLayers.forEach { layer in
            layer.path = circlePath.cgPath
        }
    }
    
    private func updateSpeakingState() {
        if isSpeaking {
            startRippleAnimation()
        } else {
            stopRippleAnimation()
        }
    }
    
    private func startRippleAnimation() {
        for (index, rippleLayer) in rippleLayers.enumerated() {
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 1.0
            scaleAnimation.toValue = 3.0
            
            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = 1.0
            opacityAnimation.toValue = 0.0
            
            let groupAnimation = CAAnimationGroup()
            groupAnimation.animations = [scaleAnimation, opacityAnimation]
            groupAnimation.duration = configuration.animationDuration
            groupAnimation.repeatCount = .infinity
            groupAnimation.beginTime = CACurrentMediaTime() + Double(index) * 0.5
            
            rippleLayer.add(groupAnimation, forKey: "ripple")
        }
    }
    
    private func stopRippleAnimation() {
        rippleLayers.forEach { layer in
            layer.removeAnimation(forKey: "ripple")
        }
    }
}

/// A composite view that combines volume visualization and speaking indicator
@available(iOS 13.0, *)
public class UserVolumeIndicatorView: UIView {
    
    /// User ID this indicator represents
    public var userId: String = "" {
        didSet {
            userLabel.text = userId
        }
    }
    
    /// User name to display
    public var userName: String = "" {
        didSet {
            userLabel.text = userName.isEmpty ? userId : userName
        }
    }
    
    /// Volume visualization view
    public let volumeView = VolumeVisualizationView()
    
    /// Speaking indicator view
    public let speakingIndicator = SpeakingIndicatorView()
    
    /// User label
    public let userLabel = UILabel()
    
    /// Stack view for layout
    private let stackView = UIStackView()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Configure stack view
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        // Configure user label
        userLabel.font = UIFont.systemFont(ofSize: 14)
        userLabel.textColor = .label
        userLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Configure volume view
        volumeView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure speaking indicator
        speakingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to stack view
        stackView.addArrangedSubview(userLabel)
        stackView.addArrangedSubview(volumeView)
        stackView.addArrangedSubview(speakingIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            volumeView.widthAnchor.constraint(equalToConstant: 60),
            volumeView.heightAnchor.constraint(equalToConstant: 20),
            
            speakingIndicator.widthAnchor.constraint(equalToConstant: 24),
            speakingIndicator.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    /// Update with volume info
    public func updateVolumeInfo(_ volumeInfo: UserVolumeInfo) {
        userId = volumeInfo.userId
        volumeView.updateVolumeInfo(volumeInfo)
        speakingIndicator.isSpeaking = volumeInfo.isSpeaking
    }
}

// MARK: - UIViewController Extensions for Error Handling

/// Extension to UIViewController for easy error handling
@available(iOS 13.0, *)
public extension UIViewController {
    
    /// Show error alert with retry option
    func showRealtimeError(_ error: RealtimeError, retryHandler: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        
        if let retryHandler = retryHandler {
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                retryHandler()
            })
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    /// Show success toast
    func showSuccessToast(_ message: String) {
        // Simple implementation using alert for now
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Show error toast
    func showErrorToast(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Show warning toast
    func showWarningToast(_ message: String) {
        let alert = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Show info toast
    func showInfoToast(_ message: String) {
        let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

#else
// Provide empty implementations for non-UIKit platforms
public struct RealtimeUIKitVersion {
    public static let current = "1.0.0"
    public static let build = "1"
}
#endif