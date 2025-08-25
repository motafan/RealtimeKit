import Foundation
@preconcurrency import Combine
import SwiftUI

/// 异步操作事件
/// 需求: 11.5 - 异步数据流和状态管理
public enum AsyncOperationEvent: Sendable {
    case started(AsyncOperationType)
    case completed(AsyncOperationType)
    case failed(AsyncOperationType, LocalizedRealtimeError)
    
    public var operationType: AsyncOperationType {
        switch self {
        case .started(let type), .completed(let type), .failed(let type, _):
            return type
        }
    }
    
    public var isCompleted: Bool {
        switch self {
        case .completed:
            return true
        case .started, .failed:
            return false
        }
    }
    
    public var error: LocalizedRealtimeError? {
        switch self {
        case .failed(_, let error):
            return error
        case .started, .completed:
            return nil
        }
    }
}

/// 异步操作类型
public enum AsyncOperationType: String, CaseIterable, Sendable {
    case login = "login"
    case logout = "logout"
    case joinRoom = "join_room"
    case leaveRoom = "leave_room"
    case switchRole = "switch_role"
    case switchProvider = "switch_provider"
    case muteMicrophone = "mute_microphone"
    case setVolume = "set_volume"
    case startStreamPush = "start_stream_push"
    case stopStreamPush = "stop_stream_push"
    case startMediaRelay = "start_media_relay"
    case stopMediaRelay = "stop_media_relay"
    case enableVolumeIndicator = "enable_volume_indicator"
    case disableVolumeIndicator = "disable_volume_indicator"
    case syncSettings = "sync_settings"
    case resetSettings = "reset_settings"
    
    public var displayName: String {
        switch self {
        case .login:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.login")
        case .logout:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.logout")
        case .joinRoom:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.join_room")
        case .leaveRoom:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.leave_room")
        case .switchRole:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.switch_role")
        case .switchProvider:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.switch_provider")
        case .muteMicrophone:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.mute_microphone")
        case .setVolume:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.set_volume")
        case .startStreamPush:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.start_stream_push")
        case .stopStreamPush:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.stop_stream_push")
        case .startMediaRelay:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.start_media_relay")
        case .stopMediaRelay:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.stop_media_relay")
        case .enableVolumeIndicator:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.enable_volume_indicator")
        case .disableVolumeIndicator:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.disable_volume_indicator")
        case .syncSettings:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.sync_settings")
        case .resetSettings:
            return ErrorLocalizationHelper.getLocalizedString(for: "operation.reset_settings")
        }
    }
}

/// 状态变化事件
/// 需求: 3.3, 11.3, 11.5 - 状态变化的自动 UI 更新机制
public enum StateChangeEvent: Sendable {
    case connectionStateChanged(ConnectionState)
    case sessionChanged(UserSession?)
    case providerChanged(ProviderType)
    case audioSettingsChanged(AudioSettings)
    case volumeInfoChanged([UserVolumeInfo])
    case userStartedSpeaking(String, Float)
    case userStoppedSpeaking(String)
    case dominantSpeakerChanged(String?)
    case streamPushStateChanged(StreamPushState)
    case mediaRelayStateChanged(MediaRelayState?)
    case errorOccurred(LocalizedRealtimeError)
    case languageChanged(SupportedLanguage)
    
    public var eventType: String {
        switch self {
        case .connectionStateChanged:
            return "connection_state_changed"
        case .sessionChanged:
            return "session_changed"
        case .providerChanged:
            return "provider_changed"
        case .audioSettingsChanged:
            return "audio_settings_changed"
        case .volumeInfoChanged:
            return "volume_info_changed"
        case .userStartedSpeaking:
            return "user_started_speaking"
        case .userStoppedSpeaking:
            return "user_stopped_speaking"
        case .dominantSpeakerChanged:
            return "dominant_speaker_changed"
        case .streamPushStateChanged:
            return "stream_push_state_changed"
        case .mediaRelayStateChanged:
            return "media_relay_state_changed"
        case .errorOccurred:
            return "error_occurred"
        case .languageChanged:
            return "language_changed"
        }
    }
    
    public var description: String {
        switch self {
        case .connectionStateChanged(let state):
            return "Connection state changed to: \(state.displayName)"
        case .sessionChanged(let session):
            return session != nil ? "Session updated: \(session!.userName)" : "Session cleared"
        case .providerChanged(let provider):
            return "Provider changed to: \(provider.displayName)"
        case .audioSettingsChanged:
            return "Audio settings updated"
        case .volumeInfoChanged(let infos):
            return "Volume info updated for \(infos.count) users"
        case .userStartedSpeaking(let userId, let volume):
            return "User \(userId) started speaking (volume: \(Int(volume * 100))%)"
        case .userStoppedSpeaking(let userId):
            return "User \(userId) stopped speaking"
        case .dominantSpeakerChanged(let userId):
            return userId != nil ? "Dominant speaker: \(userId!)" : "No dominant speaker"
        case .streamPushStateChanged(let state):
            return "Stream push state: \(state.displayName)"
        case .mediaRelayStateChanged(let state):
            return "Media relay state: \(state?.displayName ?? "None")"
        case .errorOccurred(let error):
            return "Error occurred: \(error.description)"
        case .languageChanged(let language):
            return "Language changed to: \(language.displayName)"
        }
    }
}

/// 本地化文本更新
/// 需求: 17.3 - 本地化支持到响应式数据绑定
public struct LocalizedTextUpdate: Sendable {
    public let connectionState: String
    public let userRole: String
    public let providerName: String
    public let updateTime: Date
    
    public init(
        connectionState: String,
        userRole: String,
        providerName: String,
        updateTime: Date
    ) {
        self.connectionState = connectionState
        self.userRole = userRole
        self.providerName = providerName
        self.updateTime = updateTime
    }
}

/// 本地化文本快照
public struct LocalizedTextSnapshot: Sendable {
    public let connectionState: String
    public let userRole: String
    public let providerName: String
    
    public init(
        connectionState: String,
        userRole: String,
        providerName: String
    ) {
        self.connectionState = connectionState
        self.userRole = userRole
        self.providerName = providerName
    }
}

/// 组合的实时状态
/// 需求: 3.3, 11.3, 11.5 - 复杂的 UI 状态绑定
public struct CombinedRealtimeState: Sendable {
    public let session: UserSession?
    public let connectionState: ConnectionState
    public let audioSettings: AudioSettings
    public let audioStatus: AudioStatusInfo
    public let updateTime: Date
    
    public init(
        session: UserSession?,
        connectionState: ConnectionState,
        audioSettings: AudioSettings,
        audioStatus: AudioStatusInfo,
        updateTime: Date
    ) {
        self.session = session
        self.connectionState = connectionState
        self.audioSettings = audioSettings
        self.audioStatus = audioStatus
        self.updateTime = updateTime
    }
    
    /// 检查是否可以进行音频操作
    public var canPerformAudioOperations: Bool {
        return connectionState == .connected && 
               session?.userRole.hasAudioPermission == true &&
               audioStatus.isProviderConnected
    }
    
    /// 检查是否可以进行视频操作
    public var canPerformVideoOperations: Bool {
        return canPerformAudioOperations && 
               session?.userRole.hasVideoPermission == true
    }
    
    /// 检查是否可以进行管理操作
    public var canPerformModeratorOperations: Bool {
        return canPerformAudioOperations && 
               session?.userRole.hasModeratorPrivileges == true
    }
    
    /// 获取状态摘要
    public var statusSummary: String {
        if canPerformAudioOperations {
            return "Ready for audio operations"
        } else if connectionState != .connected {
            return "Not connected"
        } else if session == nil {
            return "No active session"
        } else if !audioStatus.hasAudioPermission {
            return "No audio permission"
        } else {
            return "Limited functionality"
        }
    }
}

/// 响应式状态快照
/// 需求: 11.5 - 状态快照和调试支持
public struct ReactiveStateSnapshot: Sendable {
    public let session: UserSession?
    public let connectionState: ConnectionState
    public let audioSettings: AudioSettings
    public let audioStatus: AudioStatusInfo
    public let volumeInfos: [UserVolumeInfo]
    public let speakingUsers: Set<String>
    public let dominantSpeaker: String?
    public let localizedTexts: LocalizedTextSnapshot
    public let isPerformingOperation: Bool
    public let lastError: LocalizedRealtimeError?
    public let snapshotTime: Date
    
    public init(
        session: UserSession?,
        connectionState: ConnectionState,
        audioSettings: AudioSettings,
        audioStatus: AudioStatusInfo,
        volumeInfos: [UserVolumeInfo],
        speakingUsers: Set<String>,
        dominantSpeaker: String?,
        localizedTexts: LocalizedTextSnapshot,
        isPerformingOperation: Bool,
        lastError: LocalizedRealtimeError?,
        snapshotTime: Date
    ) {
        self.session = session
        self.connectionState = connectionState
        self.audioSettings = audioSettings
        self.audioStatus = audioStatus
        self.volumeInfos = volumeInfos
        self.speakingUsers = speakingUsers
        self.dominantSpeaker = dominantSpeaker
        self.localizedTexts = localizedTexts
        self.isPerformingOperation = isPerformingOperation
        self.lastError = lastError
        self.snapshotTime = snapshotTime
    }
    
    /// 获取快照的调试描述
    public var debugDescription: String {
        return """
        ReactiveStateSnapshot {
            session: \(String(describing: session))
            connectionState: \(connectionState)
            audioSettings: \(String(describing: audioSettings))
            audioStatus: \(String(describing: audioStatus))
            volumeInfos: \(volumeInfos.count) items
            speakingUsers: \(speakingUsers)
            dominantSpeaker: \(dominantSpeaker ?? "nil")
            isPerformingOperation: \(isPerformingOperation)
            lastError: \(String(describing: lastError))
            snapshotTime: \(snapshotTime)
        }
        """
    }
}

/// SwiftUI 视图模型基类
/// 需求: 11.3, 11.5, 17.3, 18.10 - SwiftUI 集成和响应式支持
@MainActor
public class RealtimeViewModel: ObservableObject {
    
    /// RealtimeManager 引用
    internal let realtimeManager: RealtimeManager
    
    /// Combine 取消令牌
    internal var cancellables = Set<AnyCancellable>()
    
    /// 本地化管理器
    internal let localizationManager = LocalizationManager.shared
    
    /// 视图状态
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    
    public init(realtimeManager: RealtimeManager = .shared) {
        self.realtimeManager = realtimeManager
        setupBindings()
    }
    
    /// 设置数据绑定
    private func setupBindings() {
        // 监听异步操作状态
        realtimeManager.asyncOperationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .started:
                    self?.isLoading = true
                    self?.errorMessage = nil
                case .completed:
                    self?.isLoading = false
                    self?.showSuccessMessage(for: event.operationType)
                case .failed(_, let error):
                    self?.isLoading = false
                    self?.errorMessage = error.errorDescription
                }
            }
            .store(in: &cancellables)
        
        // 监听语言变化
        NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLocalizedContent()
            }
            .store(in: &cancellables)
    }
    
    /// 显示成功消息
    private func showSuccessMessage(for operationType: AsyncOperationType) {
        let message = localizationManager.localizedString(
            for: "operation.success.message",
            arguments: operationType.displayName
        )
        successMessage = message
        
        // 3秒后清除成功消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.successMessage = nil
        }
    }
    
    /// 刷新本地化内容（子类重写）
    open func refreshLocalizedContent() {
        // 子类实现具体的本地化内容刷新逻辑
    }
    
    /// 清除错误消息
    public func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// 清除成功消息
    public func clearSuccessMessage() {
        successMessage = nil
    }
    
    /// 清除所有消息
    public func clearAllMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    deinit {
        cancellables.removeAll()
    }
}

/// 音频控制视图模型
/// 需求: 5.1, 5.2, 5.3, 11.5, 17.6, 18.10 - 音频控制的 SwiftUI 集成
@MainActor
public class AudioControlViewModel: RealtimeViewModel {
    
    /// 音频设置绑定（与 @RealtimeStorage 兼容）
    @Published public var audioSettings: AudioSettings = .default
    
    /// 音频状态信息
    @Published public var audioStatus: AudioStatusInfo = AudioStatusInfo(
        settings: .default,
        isProviderConnected: false,
        hasAudioPermission: false,
        currentUserRole: nil,
        lastModified: Date()
    )
    
    /// 本地化的音频状态文本
    @Published public var localizedAudioStatus: String = ""
    
    /// 是否可以控制音频
    @Published public var canControlAudio: Bool = false
    
    public override init(realtimeManager: RealtimeManager = .shared) {
        super.init(realtimeManager: realtimeManager)
        setupAudioBindings()
    }
    
    private func setupAudioBindings() {
        // 绑定音频设置
        realtimeManager.audioSettingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.audioSettings = settings
            }
            .store(in: &cancellables)
        
        // 绑定音频状态
        realtimeManager.$audioStatusInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.audioStatus = status
                self?.updateLocalizedAudioStatus(status)
                self?.canControlAudio = status.hasAudioPermission && status.isProviderConnected
            }
            .store(in: &cancellables)
    }
    
    private func updateLocalizedAudioStatus(_ status: AudioStatusInfo) {
        localizedAudioStatus = status.statusSummary
    }
    
    /// 切换麦克风静音状态
    public func toggleMicrophone() {
        Task {
            do {
                try await realtimeManager.muteMicrophone(!audioSettings.microphoneMuted)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 设置音量
    public func setVolume(_ volume: Int, type: VolumeType) {
        Task {
            do {
                switch type {
                case .mixing:
                    try await realtimeManager.setAudioMixingVolume(volume)
                case .playback:
                    try await realtimeManager.setPlaybackSignalVolume(volume)
                case .recording:
                    try await realtimeManager.setRecordingSignalVolume(volume)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 重置音频设置
    public func resetAudioSettings() {
        Task {
            do {
                try await realtimeManager.resetAudioSettings()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    public override func refreshLocalizedContent() {
        updateLocalizedAudioStatus(audioStatus)
    }
}

/// 音量类型
public enum VolumeType: CaseIterable {
    case mixing
    case playback
    case recording
    
    public var displayName: String {
        switch self {
        case .mixing:
            return ErrorLocalizationHelper.getLocalizedString(for: "volume.type.mixing")
        case .playback:
            return ErrorLocalizationHelper.getLocalizedString(for: "volume.type.playback")
        case .recording:
            return ErrorLocalizationHelper.getLocalizedString(for: "volume.type.recording")
        }
    }
}

/// 会话管理视图模型
/// 需求: 4.1, 4.2, 4.3, 11.5, 17.6, 18.2 - 用户会话的 SwiftUI 集成
@MainActor
public class SessionViewModel: RealtimeViewModel {
    
    /// 当前用户会话
    @Published public var currentSession: UserSession?
    
    /// 连接状态
    @Published public var connectionState: ConnectionState = .disconnected
    
    /// 本地化的连接状态文本
    @Published public var localizedConnectionState: String = ""
    
    /// 本地化的用户角色文本
    @Published public var localizedUserRole: String = ""
    
    /// 可用的角色切换选项
    @Published public var availableRoleSwitches: [UserRole] = []
    
    /// 是否可以切换角色
    @Published public var canSwitchRole: Bool = false
    
    public override init(realtimeManager: RealtimeManager = .shared) {
        super.init(realtimeManager: realtimeManager)
        setupSessionBindings()
    }
    
    private func setupSessionBindings() {
        // 绑定用户会话
        realtimeManager.sessionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.currentSession = session
                self?.updateAvailableRoleSwitches()
                self?.updateLocalizedUserRole(session?.userRole)
            }
            .store(in: &cancellables)
        
        // 绑定连接状态
        realtimeManager.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                self?.updateLocalizedConnectionState(state)
            }
            .store(in: &cancellables)
    }
    
    private func updateAvailableRoleSwitches() {
        availableRoleSwitches = realtimeManager.getAvailableRoleSwitches()
        canSwitchRole = !availableRoleSwitches.isEmpty && connectionState == .connected
    }
    
    private func updateLocalizedConnectionState(_ state: ConnectionState) {
        localizedConnectionState = state.displayName
    }
    
    private func updateLocalizedUserRole(_ role: UserRole?) {
        localizedUserRole = role?.displayName ?? localizationManager.localizedString(for: "user.role.none")
    }
    
    /// 用户登录
    public func login(userId: String, userName: String, userRole: UserRole) {
        Task {
            do {
                try await realtimeManager.loginUser(
                    userId: userId,
                    userName: userName,
                    userRole: userRole
                )
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 用户登出
    public func logout() {
        Task {
            do {
                try await realtimeManager.logoutUser()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 切换用户角色
    public func switchRole(to newRole: UserRole) {
        Task {
            do {
                try await realtimeManager.switchUserRole(newRole)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    public override func refreshLocalizedContent() {
        updateLocalizedConnectionState(connectionState)
        updateLocalizedUserRole(currentSession?.userRole)
    }
}