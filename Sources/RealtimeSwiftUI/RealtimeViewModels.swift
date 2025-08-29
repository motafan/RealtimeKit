import Foundation
import SwiftUI
@preconcurrency import Combine
import RealtimeCore

/// RealtimeSwiftUI ViewModels
/// 提供完整的 ViewModel 层支持 MVVM 架构
/// 需求: 11.3, 11.5, 17.3, 18.10

#if canImport(SwiftUI)

// MARK: - Base ViewModel

/// 基础 ViewModel 类，提供通用功能和状态管理
/// 需求: 11.3, 11.5 - ViewModel 层支持 MVVM 架构和 Combine 数据流
@MainActor
@available(macOS 10.15, iOS 13.0, *)
open class BaseRealtimeViewModel: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: RealtimeError?
    @Published public private(set) var lastUpdateTime: Date?
    
    /// ViewModel state with automatic persistence
    /// 需求: 18.10 - ViewModel 中使用 @RealtimeStorage 实现状态持久化
    @RealtimeStorage("baseViewModelState", namespace: "RealtimeKit.ViewModels")
    public var baseState: BaseViewModelState = BaseViewModelState()
    
    internal var cancellables = Set<AnyCancellable>()
    internal let realtimeManager = RealtimeManager.shared
    internal let localizationManager = LocalizationManager.shared
    
    // MARK: - Initialization
    
    public init() {
        setupBindings()
        baseState.initializationCount += 1
        baseState.lastInitializationTime = Date()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// 开始加载状态
    public func startLoading() {
        isLoading = true
        baseState.loadingStartCount += 1
    }
    
    /// 结束加载状态
    public func stopLoading() {
        isLoading = false
        lastUpdateTime = Date()
        baseState.loadingEndCount += 1
        baseState.lastUpdateTime = Date()
    }
    
    /// 设置错误状态
    public func setError(_ error: RealtimeError) {
        self.error = error
        baseState.errorCount += 1
        baseState.lastErrorTime = Date()
        stopLoading()
    }
    
    /// 清除错误状态
    public func clearError() {
        self.error = nil
        baseState.errorClearCount += 1
    }
    
    /// 刷新数据
    open func refresh() async {
        startLoading()
        defer { stopLoading() }
        
        do {
            try await performRefresh()
            clearError()
        } catch let realtimeError as RealtimeError {
            setError(realtimeError)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
    }
    
    // MARK: - Protected Methods
    
    /// 子类重写此方法实现具体的刷新逻辑
    open func performRefresh() async throws {
        // 默认实现为空，子类重写
    }
    
    /// 设置数据绑定
    open func setupBindings() {
        // 监听语言变化
        NotificationCenter.default
            .publisher(for: .realtimeLanguageDidChange)
            .sink { [weak self] _ in
                self?.baseState.languageChangeCount += 1
                self?.baseState.currentLanguage = self?.localizationManager.currentLanguage ?? .english
            }
            .store(in: &cancellables)
    }
}

/// 基础 ViewModel 持久化状态
/// 需求: 18.10 - ViewModel 状态持久化
public struct BaseViewModelState: Codable, Sendable {
    /// 初始化次数
    public var initializationCount: Int = 0
    
    /// 最后初始化时间
    public var lastInitializationTime: Date?
    
    /// 加载开始次数
    public var loadingStartCount: Int = 0
    
    /// 加载结束次数
    public var loadingEndCount: Int = 0
    
    /// 错误次数
    public var errorCount: Int = 0
    
    /// 错误清除次数
    public var errorClearCount: Int = 0
    
    /// 语言变化次数
    public var languageChangeCount: Int = 0
    
    /// 当前语言
    public var currentLanguage: SupportedLanguage = .english
    
    /// 最后更新时间
    public var lastUpdateTime: Date?
    
    /// 最后错误时间
    public var lastErrorTime: Date?
    
    public init() {}
}

// MARK: - Connection ViewModel

/// 连接状态管理 ViewModel
/// 需求: 11.3, 11.5, 17.3 - ViewModel 层和本地化支持
@MainActor
@available(macOS 10.15, iOS 13.0, *)
public final class ConnectionViewModel: BaseRealtimeViewModel {
    
    // MARK: - Published Properties
    
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var connectionHistory: [ConnectionEvent] = []
    @Published public private(set) var reconnectAttempts: Int = 0
    @Published public private(set) var connectionQuality: ConnectionQuality = .unknown
    
    /// Connection ViewModel state with automatic persistence
    /// 需求: 18.10 - ViewModel 状态持久化
    @RealtimeStorage("connectionViewModelState", namespace: "RealtimeKit.ViewModels")
    public var connectionState_persistent: ConnectionViewModelState = ConnectionViewModelState()
    
    // MARK: - Computed Properties
    
    public var isConnected: Bool {
        connectionState.isActive
    }
    
    public var canReconnect: Bool {
        connectionState.canAttemptConnection && reconnectAttempts < maxReconnectAttempts
    }
    
    public var connectionStatusText: String {
        localizationManager.localizedString(
            for: connectionState.localizationKey,
            fallbackValue: connectionState.displayName
        )
    }
    
    public var connectionQualityText: String {
        localizationManager.localizedString(
            for: connectionQuality.localizationKey,
            fallbackValue: connectionQuality.displayName
        )
    }
    
    // MARK: - Private Properties
    
    private let maxReconnectAttempts = 5
    private let maxHistoryCount = 50
    private var reconnectTimer: Timer?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupConnectionBindings()
    }
    
    // MARK: - Public Methods
    
    /// 手动重连
    public func reconnect() async {
        guard canReconnect else { return }
        
        startLoading()
        reconnectAttempts += 1
        connectionState_persistent.manualReconnectCount += 1
        
        do {
            // Simplified reconnect logic - in real implementation this would be in RealtimeManager
            // try await realtimeManager.reconnect()
            throw RealtimeError.unknown(reason: "Reconnect not implemented")
        } catch let error as RealtimeError {
            setError(error)
            connectionState_persistent.failedReconnectCount += 1
            
            if reconnectAttempts >= maxReconnectAttempts {
                connectionState_persistent.maxReconnectAttemptsReached += 1
            }
        } catch {
            setError(.connectionFailed(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 断开连接
    public func disconnect() async {
        startLoading()
        connectionState_persistent.manualDisconnectCount += 1
        
        do {
            // Simplified disconnect logic - in real implementation this would be in RealtimeManager
            // try await realtimeManager.disconnect()
            throw RealtimeError.unknown(reason: "Disconnect not implemented")
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.connectionFailed(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 清除连接历史
    public func clearHistory() {
        connectionHistory.removeAll()
        connectionState_persistent.historyClearCount += 1
    }
    
    // MARK: - Private Methods
    
    private func setupConnectionBindings() {
        // 监听连接状态变化
        realtimeManager.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                self?.handleConnectionStateChange(newState)
            }
            .store(in: &cancellables)
        
        // 监听连接质量变化 (simplified - would need to be implemented in RealtimeManager)
        // realtimeManager.$connectionQuality
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] quality in
        //         self?.connectionQuality = quality
        //         self?.connectionState_persistent.qualityChangeCount += 1
        //     }
        //     .store(in: &cancellables)
    }
    
    private func handleConnectionStateChange(_ newState: ConnectionState) {
        let previousState = connectionState
        connectionState = newState
        
        // 记录连接事件
        let event = ConnectionEvent(
            fromState: previousState,
            toState: newState,
            timestamp: Date(),
            reconnectAttempt: reconnectAttempts
        )
        
        connectionHistory.append(event)
        connectionState_persistent.stateChangeCount += 1
        connectionState_persistent.lastStateChangeTime = Date()
        
        // 限制历史记录数量
        if connectionHistory.count > maxHistoryCount {
            connectionHistory.removeFirst()
        }
        
        // 处理自动重连
        if newState == .failed && reconnectAttempts < maxReconnectAttempts {
            scheduleAutoReconnect()
        } else if newState == .connected {
            reconnectAttempts = 0
            reconnectTimer?.invalidate()
            reconnectTimer = nil
        }
    }
    
    private func scheduleAutoReconnect() {
        reconnectTimer?.invalidate()
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // 指数退避，最大30秒
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.reconnect()
            }
        }
        
        connectionState_persistent.autoReconnectScheduleCount += 1
    }
}

/// 连接事件模型
public struct ConnectionEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let fromState: ConnectionState
    public let toState: ConnectionState
    public let timestamp: Date
    public let reconnectAttempt: Int
    
    public init(fromState: ConnectionState, toState: ConnectionState, timestamp: Date, reconnectAttempt: Int) {
        self.id = UUID()
        self.fromState = fromState
        self.toState = toState
        self.timestamp = timestamp
        self.reconnectAttempt = reconnectAttempt
    }
}

/// 连接质量枚举
public enum ConnectionQuality: String, CaseIterable, Codable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
    
    public var localizationKey: String {
        return "connection.quality.\(rawValue)"
    }
    
    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
}

/// Connection ViewModel 持久化状态
/// 需求: 18.10 - ViewModel 状态持久化
public struct ConnectionViewModelState: Codable, Sendable {
    /// 状态变化次数
    public var stateChangeCount: Int = 0
    
    /// 质量变化次数
    public var qualityChangeCount: Int = 0
    
    /// 手动重连次数
    public var manualReconnectCount: Int = 0
    
    /// 成功重连次数
    public var successfulReconnectCount: Int = 0
    
    /// 失败重连次数
    public var failedReconnectCount: Int = 0
    
    /// 手动断开次数
    public var manualDisconnectCount: Int = 0
    
    /// 历史清除次数
    public var historyClearCount: Int = 0
    
    /// 自动重连调度次数
    public var autoReconnectScheduleCount: Int = 0
    
    /// 达到最大重连次数的次数
    public var maxReconnectAttemptsReached: Int = 0
    
    /// 最后状态变化时间
    public var lastStateChangeTime: Date?
    
    public init() {}
}

// MARK: - Audio ViewModel

/// 音频控制管理 ViewModel
/// 需求: 11.3, 11.5, 17.3, 18.10 - ViewModel 层、Combine 数据流和状态持久化
@MainActor
@available(macOS 10.15, iOS 13.0, *)
public final class AudioViewModel: BaseRealtimeViewModel {
    
    // MARK: - Published Properties
    
    @Published public private(set) var audioSettings: AudioSettings = .default
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var speakingUsers: Set<String> = []
    @Published public private(set) var dominantSpeaker: String?
    @Published public private(set) var isVolumeDetectionEnabled: Bool = false
    
    /// Audio ViewModel state with automatic persistence
    /// 需求: 18.10 - ViewModel 状态持久化
    @RealtimeStorage("audioViewModelState", namespace: "RealtimeKit.ViewModels")
    public var audioState: AudioViewModelState = AudioViewModelState()
    
    // MARK: - Computed Properties
    
    public var isMicrophoneMuted: Bool {
        audioSettings.microphoneMuted
    }
    
    public var isLocalAudioActive: Bool {
        audioSettings.localAudioStreamActive
    }
    
    public var speakingUserCount: Int {
        speakingUsers.count
    }
    
    public var totalUserCount: Int {
        volumeInfos.count
    }
    
    public var averageVolume: Float {
        guard !volumeInfos.isEmpty else { return 0 }
        let totalVolume = volumeInfos.reduce(0) { $0 + $1.volume }
        return Float(totalVolume) / Float(volumeInfos.count)
    }
    
    public var maxVolume: Float {
        volumeInfos.map { Float($0.volume) }.max() ?? 0.0
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupAudioBindings()
    }
    
    // MARK: - Public Methods
    
    /// 切换麦克风静音状态
    public func toggleMicrophone() async {
        startLoading()
        audioState.microphoneToggleCount += 1
        
        do {
            try await realtimeManager.muteMicrophone(!isMicrophoneMuted)
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 设置混音音量
    public func setAudioMixingVolume(_ volume: Int) async {
        let clampedVolume = max(0, min(100, volume))
        startLoading()
        audioState.volumeAdjustmentCount += 1
        
        do {
            try await realtimeManager.setAudioMixingVolume(clampedVolume)
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 设置播放音量
    public func setPlaybackVolume(_ volume: Int) async {
        let clampedVolume = max(0, min(100, volume))
        startLoading()
        audioState.volumeAdjustmentCount += 1
        
        do {
            try await realtimeManager.setPlaybackSignalVolume(clampedVolume)
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 设置录制音量
    public func setRecordingVolume(_ volume: Int) async {
        let clampedVolume = max(0, min(100, volume))
        startLoading()
        audioState.volumeAdjustmentCount += 1
        
        do {
            try await realtimeManager.setRecordingSignalVolume(clampedVolume)
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 切换本地音频流状态
    public func toggleLocalAudioStream() async {
        startLoading()
        audioState.streamToggleCount += 1
        
        do {
            if isLocalAudioActive {
                try await realtimeManager.stopLocalAudioStream()
            } else {
                try await realtimeManager.resumeLocalAudioStream()
            }
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 启用音量检测
    public func enableVolumeDetection(config: VolumeDetectionConfig = .default) async {
        startLoading()
        audioState.volumeDetectionToggleCount += 1
        
        do {
            try await realtimeManager.enableVolumeIndicator(config: config)
            isVolumeDetectionEnabled = true
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 禁用音量检测
    public func disableVolumeDetection() async {
        startLoading()
        audioState.volumeDetectionToggleCount += 1
        
        do {
            try await realtimeManager.disableVolumeIndicator()
            isVolumeDetectionEnabled = false
            volumeInfos.removeAll()
            speakingUsers.removeAll()
            dominantSpeaker = nil
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 获取用户音量信息
    public func getUserVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return volumeInfos.first { $0.userId == userId }
    }
    
    /// 检查用户是否在说话
    public func isUserSpeaking(_ userId: String) -> Bool {
        return speakingUsers.contains(userId)
    }
    
    /// 检查用户是否为主讲人
    public func isDominantSpeaker(_ userId: String) -> Bool {
        return dominantSpeaker == userId
    }
    
    // MARK: - Private Methods
    
    private func setupAudioBindings() {
        // 监听音频设置变化
        realtimeManager.$audioSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.audioSettings = settings
                self?.audioState.settingsUpdateCount += 1
                self?.audioState.lastSettingsUpdateTime = Date()
            }
            .store(in: &cancellables)
        
        // 监听音量信息变化
        realtimeManager.$volumeInfos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] infos in
                self?.volumeInfos = infos
                self?.audioState.volumeUpdateCount += 1
                self?.audioState.lastVolumeUpdateTime = Date()
                
                // 更新最大用户数统计
                if infos.count > self?.audioState.maxUserCount ?? 0 {
                    self?.audioState.maxUserCount = infos.count
                }
            }
            .store(in: &cancellables)
        
        // 监听说话用户变化
        realtimeManager.$speakingUsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] users in
                self?.speakingUsers = users
                self?.audioState.speakingUsersUpdateCount += 1
                
                // 更新最大说话用户数统计
                if users.count > self?.audioState.maxSpeakingUsers ?? 0 {
                    self?.audioState.maxSpeakingUsers = users.count
                }
            }
            .store(in: &cancellables)
        
        // 监听主讲人变化
        realtimeManager.$dominantSpeaker
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaker in
                self?.dominantSpeaker = speaker
                if speaker != nil {
                    self?.audioState.dominantSpeakerChangeCount += 1
                }
            }
            .store(in: &cancellables)
    }
}

/// Audio ViewModel 持久化状态
/// 需求: 18.10 - ViewModel 状态持久化
public struct AudioViewModelState: Codable, Sendable {
    /// 麦克风切换次数
    public var microphoneToggleCount: Int = 0
    
    /// 音量调整次数
    public var volumeAdjustmentCount: Int = 0
    
    /// 音频流切换次数
    public var streamToggleCount: Int = 0
    
    /// 音量检测切换次数
    public var volumeDetectionToggleCount: Int = 0
    
    /// 设置更新次数
    public var settingsUpdateCount: Int = 0
    
    /// 音量更新次数
    public var volumeUpdateCount: Int = 0
    
    /// 说话用户更新次数
    public var speakingUsersUpdateCount: Int = 0
    
    /// 主讲人变化次数
    public var dominantSpeakerChangeCount: Int = 0
    
    /// 最大用户数
    public var maxUserCount: Int = 0
    
    /// 最大说话用户数
    public var maxSpeakingUsers: Int = 0
    
    /// 最后设置更新时间
    public var lastSettingsUpdateTime: Date?
    
    /// 最后音量更新时间
    public var lastVolumeUpdateTime: Date?
    
    public init() {}
}

// MARK: - User Session ViewModel

/// 用户会话管理 ViewModel
/// 需求: 11.3, 11.5, 17.3, 18.10 - ViewModel 层、本地化支持和状态持久化
@MainActor
@available(macOS 10.15, iOS 13.0, *)
public final class UserSessionViewModel: BaseRealtimeViewModel {
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var sessionHistory: [UserSession] = []
    @Published public private(set) var availableRoles: [UserRole] = UserRole.allCases
    
    /// User Session ViewModel state with automatic persistence
    /// 需求: 18.10 - ViewModel 状态持久化
    @RealtimeStorage("userSessionViewModelState", namespace: "RealtimeKit.ViewModels")
    public var sessionState: UserSessionViewModelState = UserSessionViewModelState()
    
    // MARK: - Computed Properties
    
    public var isLoggedIn: Bool {
        currentSession != nil
    }
    
    public var currentUserRole: UserRole? {
        currentSession?.userRole
    }
    
    public var currentUserId: String? {
        currentSession?.userId
    }
    
    public var currentUserName: String? {
        currentSession?.userName
    }
    
    public var hasAudioPermission: Bool {
        currentUserRole?.hasAudioPermission ?? false
    }
    
    public var hasVideoPermission: Bool {
        currentUserRole?.hasVideoPermission ?? false
    }
    
    public var canSwitchRoles: Set<UserRole> {
        currentUserRole?.canSwitchToRole ?? []
    }
    
    public var sessionDuration: TimeInterval {
        guard let session = currentSession else { return 0 }
        return Date().timeIntervalSince(session.joinTime)
    }
    
    public var formattedSessionDuration: String {
        let duration = sessionDuration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupSessionBindings()
        loadSessionHistory()
    }
    
    // MARK: - Public Methods
    
    /// 用户登录
    public func login(userId: String, userName: String, userRole: UserRole) async {
        startLoading()
        sessionState.loginAttemptCount += 1
        
        do {
            try await realtimeManager.loginUser(userId: userId, userName: userName, userRole: userRole)
            sessionState.successfulLoginCount += 1
        } catch let error as RealtimeError {
            setError(error)
            sessionState.failedLoginCount += 1
        } catch {
            setError(.unknown(reason: error.localizedDescription))
            sessionState.failedLoginCount += 1
        }
        
        stopLoading()
    }
    
    /// 用户登出
    public func logout() async {
        startLoading()
        sessionState.logoutCount += 1
        
        do {
            try await realtimeManager.logoutUser()
            
            // 保存会话到历史记录
            if let session = currentSession {
                addToHistory(session)
            }
            
            currentSession = nil
        } catch let error as RealtimeError {
            setError(error)
        } catch {
            setError(.unknown(reason: error.localizedDescription))
        }
        
        stopLoading()
    }
    
    /// 切换用户角色
    public func switchRole(to newRole: UserRole) async {
        guard let currentRole = currentUserRole,
              currentRole.canSwitchToRole.contains(newRole) else {
            setError(.invalidRoleTransition(from: currentUserRole ?? .audience, to: newRole))
            return
        }
        
        startLoading()
        sessionState.roleSwitchAttemptCount += 1
        
        do {
            try await realtimeManager.switchUserRole(newRole)
            sessionState.successfulRoleSwitchCount += 1
        } catch let error as RealtimeError {
            setError(error)
            sessionState.failedRoleSwitchCount += 1
        } catch {
            setError(.unknown(reason: error.localizedDescription))
            sessionState.failedRoleSwitchCount += 1
        }
        
        stopLoading()
    }
    
    /// 获取角色显示名称
    public func getRoleDisplayName(_ role: UserRole) -> String {
        return localizationManager.localizedString(
            for: "user.role.\(role.rawValue)",
            fallbackValue: role.displayName
        )
    }
    
    /// 获取权限描述
    public func getPermissionDescription(_ role: UserRole) -> String {
        var permissions: [String] = []
        
        if role.hasAudioPermission {
            permissions.append(localizationManager.localizedString(
                for: "permission.audio",
                fallbackValue: "Audio"
            ))
        }
        
        if role.hasVideoPermission {
            permissions.append(localizationManager.localizedString(
                for: "permission.video",
                fallbackValue: "Video"
            ))
        }
        
        if permissions.isEmpty {
            return localizationManager.localizedString(
                for: "permission.none",
                fallbackValue: "No permissions"
            )
        }
        
        return permissions.joined(separator: ", ")
    }
    
    /// 清除会话历史
    public func clearHistory() {
        sessionHistory.removeAll()
        sessionState.historyClearCount += 1
        saveSessionHistory()
    }
    
    /// 获取会话统计信息
    public func getSessionStats() -> UserSessionStats? {
        guard let session = currentSession else { return nil }
        
        return UserSessionStats(
            sessionId: session.userId,
            userId: session.userId,
            sessionDuration: sessionDuration,
            inactiveDuration: 0, // 简化实现
            isValid: true
        )
    }
    
    // MARK: - Private Methods
    
    private func setupSessionBindings() {
        // 监听当前会话变化
        realtimeManager.$currentSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.currentSession = session
                self?.sessionState.sessionUpdateCount += 1
                self?.sessionState.lastSessionUpdateTime = Date()
            }
            .store(in: &cancellables)
    }
    
    private func addToHistory(_ session: UserSession) {
        sessionHistory.append(session)
        sessionState.historyAddCount += 1
        
        // 限制历史记录数量
        let maxHistoryCount = 20
        if sessionHistory.count > maxHistoryCount {
            sessionHistory.removeFirst()
        }
        
        saveSessionHistory()
    }
    
    private func loadSessionHistory() {
        // 从持久化存储加载会话历史
        // 简化实现，实际应该从存储中加载
        sessionState.historyLoadCount += 1
    }
    
    private func saveSessionHistory() {
        // 保存会话历史到持久化存储
        // 简化实现，实际应该保存到存储中
        sessionState.historySaveCount += 1
    }
}

/// User Session ViewModel 持久化状态
/// 需求: 18.10 - ViewModel 状态持久化
public struct UserSessionViewModelState: Codable, Sendable {
    /// 登录尝试次数
    public var loginAttemptCount: Int = 0
    
    /// 成功登录次数
    public var successfulLoginCount: Int = 0
    
    /// 失败登录次数
    public var failedLoginCount: Int = 0
    
    /// 登出次数
    public var logoutCount: Int = 0
    
    /// 角色切换尝试次数
    public var roleSwitchAttemptCount: Int = 0
    
    /// 成功角色切换次数
    public var successfulRoleSwitchCount: Int = 0
    
    /// 失败角色切换次数
    public var failedRoleSwitchCount: Int = 0
    
    /// 会话更新次数
    public var sessionUpdateCount: Int = 0
    
    /// 历史记录添加次数
    public var historyAddCount: Int = 0
    
    /// 历史记录清除次数
    public var historyClearCount: Int = 0
    
    /// 历史记录加载次数
    public var historyLoadCount: Int = 0
    
    /// 历史记录保存次数
    public var historySaveCount: Int = 0
    
    /// 最后会话更新时间
    public var lastSessionUpdateTime: Date?
    
    public init() {}
}

#endif
