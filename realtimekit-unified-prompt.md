# RealtimeKit Swift Package 统一开发提示词

## 项目概述
开发一个名为 **RealtimeKit** 的 Swift Package，用于集成多家第三方 RTM (Real-Time Messaging) 和 RTC (Real-Time Communication) 服务提供商，为 iOS/macOS 应用提供统一的实时通信解决方案。

## 核心目标
- 提供统一的 API 接口，屏蔽不同服务商的差异
- 支持主流 RTC/RTM 提供商（声网Agora、腾讯云、即构ZEGO等）
- **同时兼容 UIKit 和 SwiftUI** 调用方式
- 插件化架构，便于扩展新的服务商
- 高性能、低延迟的实时通信体验
- 完善的错误处理和状态管理
- **音量指示器功能，支持"谁在说话"波纹动画**
- **音频设置持久化存储**
- **身份切换功能**
- **灵活的音频流控制**
- **转推流功能**
- **跨媒体流中继**
- **Token 自动续期管理**
- **消息处理管道**

## 技术要求

### Swift 版本支持
- Swift 6.0+
- iOS 13.0+
- macOS 10.15+

## 架构设计原则
1. **Protocol-Oriented Programming** - 使用协议定义统一接口
2. **Dependency Injection** - 支持依赖注入，便于测试
3. **Plugin Architecture** - 插件化设计，支持动态加载
4. **Async/Await** - 全面支持现代 Swift 异步编程
5. **Memory Safety** - 避免内存泄漏，合理管理资源
6. **Modular Design** - 模块化架构，可直接封装为 Swift Package
7. **Data Persistence** - 智能的设置持久化机制

## 核心功能模块

### 1. 核心抽象层 (Core)

#### 主要协议定义
```swift
public protocol RTCProvider {
    func initialize(config: RTCConfig) async throws
    func createRoom(roomId: String) async throws -> RTCRoom
    func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws
    func leaveRoom() async throws
    func switchUserRole(_ role: UserRole) async throws
    
    // 音频流控制
    func muteMicrophone(_ muted: Bool) async throws
    func isMicrophoneMuted() -> Bool
    func stopLocalAudioStream() async throws
    func resumeLocalAudioStream() async throws
    func isLocalAudioStreamActive() -> Bool
    
    // 音量控制 API
    func setAudioMixingVolume(_ volume: Int) async throws      // 0-100
    func getAudioMixingVolume() -> Int
    func setPlaybackSignalVolume(_ volume: Int) async throws   // 0-100
    func getPlaybackSignalVolume() -> Int
    func setRecordingSignalVolume(_ volume: Int) async throws  // 0-100
    func getRecordingSignalVolume() -> Int
    
    // 转推流功能
    func startStreamPush(config: StreamPushConfig) async throws
    func stopStreamPush() async throws
    func updateStreamPushLayout(layout: StreamLayout) async throws
    
    // 跨媒体流功能
    func startMediaRelay(config: MediaRelayConfig) async throws
    func stopMediaRelay() async throws
    func updateMediaRelayChannels(config: MediaRelayConfig) async throws
    func pauseMediaRelay(toChannel: String) async throws
    func resumeMediaRelay(toChannel: String) async throws
    
    // 音量指示器功能
    func enableVolumeIndicator(config: VolumeDetectionConfig) async throws
    func disableVolumeIndicator() async throws
    func setVolumeIndicatorHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void)
    func setVolumeEventHandler(_ handler: @escaping (VolumeEvent) -> Void)
    func getCurrentVolumeInfos() -> [UserVolumeInfo]
    func getVolumeInfo(for userId: String) -> UserVolumeInfo?
    
    // Token 管理
    func renewToken(_ newToken: String) async throws
    func onTokenWillExpire(_ handler: @escaping (Int) -> Void)
}

public protocol RTMProvider {
    func initialize(config: RTMConfig) async throws
    func sendMessage(_ message: RealtimeMessage) async throws
    func subscribe(to channel: String) async throws
    
    // 消息处理功能
    func setMessageHandler(_ handler: @escaping (RealtimeMessage) -> Void)
    func setConnectionStateHandler(_ handler: @escaping (ConnectionState) -> Void)
    func processIncomingMessage(_ rawMessage: Any) async throws -> RealtimeMessage
    
    // Token 管理
    func renewToken(_ newToken: String) async throws
    func onTokenWillExpire(_ handler: @escaping (Int) -> Void)
}
```

#### 核心数据模型
```swift
// 用户角色枚举
public enum UserRole: String, CaseIterable, Codable {
    case broadcaster = "broadcaster"    // 主播
    case audience = "audience"         // 观众
    case coHost = "co_host"           // 连麦嘉宾
    case moderator = "moderator"      // 主持人
    
    public var displayName: String {
        switch self {
        case .broadcaster: return "主播"
        case .audience: return "观众"
        case .coHost: return "连麦嘉宾"
        case .moderator: return "主持人"
        }
    }
    
    public var hasAudioPermission: Bool {
        switch self {
        case .broadcaster, .coHost, .moderator: return true
        case .audience: return false
        }
    }
    
    public var hasVideoPermission: Bool {
        switch self {
        case .broadcaster, .coHost: return true
        case .audience, .moderator: return false
        }
    }
}

// 音频设置模型
public struct AudioSettings: Codable {
    let microphoneMuted: Bool
    let audioMixingVolume: Int        // 0-100
    let playbackSignalVolume: Int     // 0-100
    let recordingSignalVolume: Int    // 0-100
    let localAudioStreamActive: Bool
    
    public init(
        microphoneMuted: Bool = false,
        audioMixingVolume: Int = 100,
        playbackSignalVolume: Int = 100,
        recordingSignalVolume: Int = 100,
        localAudioStreamActive: Bool = true
    ) {
        self.microphoneMuted = microphoneMuted
        self.audioMixingVolume = max(0, min(100, audioMixingVolume))
        self.playbackSignalVolume = max(0, min(100, playbackSignalVolume))
        self.recordingSignalVolume = max(0, min(100, recordingSignalVolume))
        self.localAudioStreamActive = localAudioStreamActive
    }
    
    public static let `default` = AudioSettings()
}

// 用户会话信息
public struct UserSession: Codable {
    let userId: String
    let userName: String
    let userRole: UserRole
    let avatar: String?
    let lastActiveTime: Date
    let audioSettings: AudioSettings
    
    public init(
        userId: String,
        userName: String,
        userRole: UserRole = .audience,
        avatar: String? = nil,
        audioSettings: AudioSettings = .default
    ) {
        self.userId = userId
        self.userName = userName
        self.userRole = userRole
        self.avatar = avatar
        self.lastActiveTime = Date()
        self.audioSettings = audioSettings
    }
}

// 转推流配置
public struct StreamPushConfig {
    let pushUrl: String
    let width: Int
    let height: Int
    let bitrate: Int
    let frameRate: Int
    let layout: StreamLayout
}

public struct StreamLayout {
    let backgroundColor: UInt32
    let regions: [StreamRegion]
}

public struct StreamRegion {
    let uid: String
    let x: Double
    let y: Double  
    let width: Double
    let height: Double
    let zOrder: Int
    let alpha: Double
}

// 跨媒体流配置
public struct MediaRelayConfig {
    let sourceChannel: MediaRelayChannelInfo
    let destinationChannels: [MediaRelayChannelInfo]
    let relayMode: MediaRelayMode
}

public struct MediaRelayChannelInfo {
    let channelName: String
    let token: String?
    let uid: UInt32
    let serverUrl: String?
}

public enum MediaRelayMode {
    case oneToOne        // 1对1中继
    case oneToMany       // 1对多中继  
    case manyToMany      // 多对多中继
    case crossChannel    // 跨频道中继
}

public struct MediaRelayState {
    let state: RelayState
    let sourceChannel: String
    let destinationChannels: [String: ChannelRelayState]
}

public enum RelayState {
    case idle
    case connecting
    case running
    case failure(MediaRelayError)
}

public enum ChannelRelayState {
    case connected
    case disconnected
    case failure(MediaRelayError)
}

public enum MediaRelayError: Error {
    case serverConnectionLost
    case serverNoResponse
    case invalidToken
    case userNotInChannel
    case destinationChannelFull
    case networkError(String)
}

// 音量指示器相关配置
public struct VolumeDetectionConfig {
    let detectionInterval: Int      // 检测间隔（毫秒）
    let speakingThreshold: Float    // 说话音量阈值 (0.0 - 1.0)
    let silenceThreshold: Float     // 静音音量阈值
    let includeLocalUser: Bool      // 是否包含本地用户
    let smoothFactor: Float         // 平滑处理参数
    
    public init(
        detectionInterval: Int = 300,
        speakingThreshold: Float = 0.3,
        silenceThreshold: Float = 0.05,
        includeLocalUser: Bool = true,
        smoothFactor: Float = 0.3
    ) {
        self.detectionInterval = detectionInterval
        self.speakingThreshold = speakingThreshold
        self.silenceThreshold = silenceThreshold
        self.includeLocalUser = includeLocalUser
        self.smoothFactor = smoothFactor
    }
    
    public static let `default` = VolumeDetectionConfig()
}

public struct UserVolumeInfo {
    let userId: String
    let volume: Float       // 0.0 - 1.0 音量级别
    let isSpeaking: Bool    // 是否正在说话
    let timestamp: Date
    
    public init(userId: String, volume: Float, isSpeaking: Bool, timestamp: Date = Date()) {
        self.userId = userId
        self.volume = max(0.0, min(1.0, volume))
        self.isSpeaking = isSpeaking
        self.timestamp = timestamp
    }
}

public enum VolumeEvent {
    case userStartedSpeaking(UserVolumeInfo)
    case userStoppedSpeaking(UserVolumeInfo)
    case volumeUpdated(UserVolumeInfo)
    case volumeListUpdated([UserVolumeInfo])
    case dominantSpeakerChanged(String?)
}
```

### 2. 统一管理器 (Manager)

```swift
public class RealtimeManager: ObservableObject {
    public static let shared = RealtimeManager()
    
    // MARK: - Published Properties for SwiftUI
    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var audioSettings: AudioSettings = .default
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var streamPushState: StreamPushState = .stopped
    @Published public private(set) var mediaRelayState: MediaRelayState?
    
    private let settingsStorage = AudioSettingsStorage()
    private let sessionStorage = UserSessionStorage()
    private var rtcProvider: RTCProvider!
    private var rtmProvider: RTMProvider!
    
    public func configure(provider: ProviderType, config: RealtimeConfig) async throws
    public func switchProvider(to: ProviderType) async throws
    public func getCurrentProvider() -> ProviderType
    
    // MARK: - 身份管理
    public func loginUser(
        userId: String, 
        userName: String, 
        userRole: UserRole = .audience,
        avatar: String? = nil
    ) async throws {
        let session = UserSession(
            userId: userId,
            userName: userName,
            userRole: userRole,
            avatar: avatar,
            audioSettings: settingsStorage.loadAudioSettings()
        )
        currentSession = session
        sessionStorage.saveUserSession(session)
        
        // 恢复音频设置
        await restoreAudioSettings()
    }
    
    public func logoutUser() async throws {
        await leaveRoom()
        currentSession = nil
        sessionStorage.clearUserSession()
    }
    
    public func switchUserRole(_ role: UserRole) async throws {
        guard var session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        try await rtcProvider.switchUserRole(role)
        
        session = UserSession(
            userId: session.userId,
            userName: session.userName,
            userRole: role,
            avatar: session.avatar,
            audioSettings: session.audioSettings
        )
        currentSession = session
        sessionStorage.saveUserSession(session)
    }
    
    public func getCurrentUserRole() -> UserRole? {
        return currentSession?.userRole
    }
    
    public func hasAudioPermission() -> Bool {
        return currentSession?.userRole.hasAudioPermission ?? false
    }
    
    public func hasVideoPermission() -> Bool {
        return currentSession?.userRole.hasVideoPermission ?? false
    }
    
    // MARK: - 音频控制与持久化
    public func muteMicrophone(_ muted: Bool) async throws {
        try await rtcProvider.muteMicrophone(muted)
        await updateAudioSettings { settings in
            AudioSettings(
                microphoneMuted: muted,
                audioMixingVolume: settings.audioMixingVolume,
                playbackSignalVolume: settings.playbackSignalVolume,
                recordingSignalVolume: settings.recordingSignalVolume,
                localAudioStreamActive: settings.localAudioStreamActive
            )
        }
    }
    
    public func isMicrophoneMuted() -> Bool {
        return audioSettings.microphoneMuted
    }
    
    public func stopLocalAudioStream() async throws {
        try await rtcProvider.stopLocalAudioStream()
        await updateAudioSettings { settings in
            AudioSettings(
                microphoneMuted: settings.microphoneMuted,
                audioMixingVolume: settings.audioMixingVolume,
                playbackSignalVolume: settings.playbackSignalVolume,
                recordingSignalVolume: settings.recordingSignalVolume,
                localAudioStreamActive: false
            )
        }
    }
    
    public func resumeLocalAudioStream() async throws {
        try await rtcProvider.resumeLocalAudioStream()
        await updateAudioSettings { settings in
            AudioSettings(
                microphoneMuted: settings.microphoneMuted,
                audioMixingVolume: settings.audioMixingVolume,
                playbackSignalVolume: settings.playbackSignalVolume,
                recordingSignalVolume: settings.recordingSignalVolume,
                localAudioStreamActive: true
            )
        }
    }
    
    public func isLocalAudioStreamActive() -> Bool {
        return audioSettings.localAudioStreamActive
    }
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setAudioMixingVolume(clampedVolume)
        await updateAudioSettings { settings in
            AudioSettings(
                microphoneMuted: settings.microphoneMuted,
                audioMixingVolume: clampedVolume,
                playbackSignalVolume: settings.playbackSignalVolume,
                recordingSignalVolume: settings.recordingSignalVolume,
                localAudioStreamActive: settings.localAudioStreamActive
            )
        }
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setPlaybackSignalVolume(clampedVolume)
        await updateAudioSettings { settings in
            AudioSettings(
                microphoneMuted: settings.microphoneMuted,
                audioMixingVolume: settings.audioMixingVolume,
                playbackSignalVolume: clampedVolume,
                recordingSignalVolume: settings.recordingSignalVolume,
                localAudioStreamActive: settings.localAudioStreamActive
            )
        }
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setRecordingSignalVolume(clampedVolume)
        await updateAudioSettings { settings in
            AudioSettings(
                microphoneMuted: settings.microphoneMuted,
                audioMixingVolume: settings.audioMixingVolume,
                playbackSignalVolume: settings.playbackSignalVolume,
                recordingSignalVolume: clampedVolume,
                localAudioStreamActive: settings.localAudioStreamActive
            )
        }
    }
    
    // MARK: - 私有方法
    @MainActor
    private func updateAudioSettings(_ updater: (AudioSettings) -> AudioSettings) {
        let newSettings = updater(audioSettings)
        audioSettings = newSettings
        settingsStorage.saveAudioSettings(newSettings)
        
        // 更新当前会话
        if let session = currentSession {
            let updatedSession = UserSession(
                userId: session.userId,
                userName: session.userName,
                userRole: session.userRole,
                avatar: session.avatar,
                audioSettings: newSettings
            )
            currentSession = updatedSession
            sessionStorage.saveUserSession(updatedSession)
        }
    }
    
    private func restoreAudioSettings() async {
        let settings = settingsStorage.loadAudioSettings()
        await MainActor.run {
            audioSettings = settings
        }
        
        // 恢复到 RTC Provider
        do {
            try await rtcProvider.muteMicrophone(settings.microphoneMuted)
            try await rtcProvider.setAudioMixingVolume(settings.audioMixingVolume)
            try await rtcProvider.setPlaybackSignalVolume(settings.playbackSignalVolume)
            try await rtcProvider.setRecordingSignalVolume(settings.recordingSignalVolume)
            
            if settings.localAudioStreamActive {
                try await rtcProvider.resumeLocalAudioStream()
            } else {
                try await rtcProvider.stopLocalAudioStream()
            }
        } catch {
            print("Failed to restore audio settings: \(error)")
        }
    }
    
    // MARK: - Token 管理
    public func setupTokenRenewal(handler: @escaping (ProviderType) async -> String) {
        // Token 续期实现
    }
    
    public func renewAllTokens() async throws {
        // 续期所有 Token
    }
    
    // MARK: - 转推流管理
    public func startLiveStreaming(config: StreamPushConfig) async throws {
        try await rtcProvider.startStreamPush(config: config)
        await MainActor.run {
            streamPushState = .running
        }
    }
    
    public func stopLiveStreaming() async throws {
        try await rtcProvider.stopStreamPush()
        await MainActor.run {
            streamPushState = .stopped
        }
    }
    
    public func updateStreamLayout(_ layout: StreamLayout) async throws {
        try await rtcProvider.updateStreamPushLayout(layout: layout)
    }
    
    // MARK: - 跨媒体流管理
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        try await rtcProvider.startMediaRelay(config: config)
    }
    
    public func stopMediaRelay() async throws {
        try await rtcProvider.stopMediaRelay()
    }
    
    public func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        try await rtcProvider.updateMediaRelayChannels(config: config)
    }
    
    public func pauseMediaRelayChannel(_ channel: String) async throws {
        try await rtcProvider.pauseMediaRelay(toChannel: channel)
    }
    
    public func resumeMediaRelayChannel(_ channel: String) async throws {
        try await rtcProvider.resumeMediaRelay(toChannel: channel)
    }
    
    public func getMediaRelayState() -> MediaRelayState? {
        return mediaRelayState
    }
    
    // MARK: - 音量指示器管理
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        try await rtcProvider.enableVolumeIndicator(config: config)
    }
    
    public func disableVolumeIndicator() async throws {
        try await rtcProvider.disableVolumeIndicator()
    }
    
    public func setGlobalVolumeHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void) {
        rtcProvider.setVolumeIndicatorHandler(handler)
    }
    
    public func getCurrentSpeakingUsers() -> Set<String> {
        let volumeInfos = rtcProvider.getCurrentVolumeInfos()
        return Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
    }
    
    public func getDominantSpeaker() -> String? {
        let volumeInfos = rtcProvider.getCurrentVolumeInfos()
        return volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
    }
    
    public func getVolumeLevel(for userId: String) -> Float {
        return rtcProvider.getVolumeInfo(for: userId)?.volume ?? 0.0
    }
    
    // MARK: - 消息处理中心
    public func setGlobalMessageHandler(_ handler: @escaping (RealtimeMessage) -> Void) {
        rtmProvider.setMessageHandler(handler)
    }
    
    public func registerMessageProcessor(_ processor: MessageProcessor) {
        // 注册消息处理器
    }
    
    // MARK: - 房间管理
    public func joinRoom(roomId: String) async throws {
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        try await rtcProvider.joinRoom(roomId: roomId, userId: session.userId, userRole: session.userRole)
        await MainActor.run {
            connectionState = .connected
        }
    }
    
    public func leaveRoom() async throws {
        try await rtcProvider.leaveRoom()
        await MainActor.run {
            connectionState = .disconnected
        }
    }
}

// MARK: - 存储管理器
public class AudioSettingsStorage {
    private let userDefaults = UserDefaults.standard
    private let audioSettingsKey = "RealtimeKit.AudioSettings"
    
    public func saveAudioSettings(_ settings: AudioSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: audioSettingsKey)
        }
    }
    
    public func loadAudioSettings() -> AudioSettings {
        guard let data = userDefaults.data(forKey: audioSettingsKey),
              let settings = try? JSONDecoder().decode(AudioSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    public func clearAudioSettings() {
        userDefaults.removeObject(forKey: audioSettingsKey)
    }
}

public class UserSessionStorage {
    private let userDefaults = UserDefaults.standard
    private let userSessionKey = "RealtimeKit.UserSession"
    
    public func saveUserSession(_ session: UserSession) {
        if let data = try? JSONEncoder().encode(session) {
            userDefaults.set(data, forKey: userSessionKey)
        }
    }
    
    public func loadUserSession() -> UserSession? {
        guard let data = userDefaults.data(forKey: userSessionKey),
              let session = try? JSONDecoder().decode(UserSession.self, from: data) else {
            return nil
        }
        return session
    }
    
    public func clearUserSession() {
        userDefaults.removeObject(forKey: userSessionKey)
    }
}

// Token 管理器
public class TokenManager {
    public func scheduleTokenRenewal(provider: ProviderType, expiresIn: Int) {
        // Token 续期调度
    }
    
    public func handleTokenExpiration(provider: ProviderType) async throws {
        // Token 过期处理
    }
    
    public func isTokenExpiring(within seconds: Int) -> Bool {
        // 检查 Token 是否即将过期
        return false
    }
}

// 消息处理器协议
public protocol MessageProcessor {
    func canProcess(_ message: RealtimeMessage) -> Bool
    func process(_ message: RealtimeMessage) async throws -> ProcessedMessage?
}

// 跨媒体流管理器
public class MediaRelayManager {
    public func startRelay(from source: MediaRelayChannelInfo, to destinations: [MediaRelayChannelInfo]) async throws {
        // 开始媒体流中继
    }
    
    public func addDestinationChannel(_ channel: MediaRelayChannelInfo) async throws {
        // 添加目标频道
    }
    
    public func removeDestinationChannel(_ channelName: String) async throws {
        // 移除目标频道
    }
    
    public func updateChannelToken(_ channelName: String, token: String) async throws {
        // 更新频道 Token
    }
    
    public func getRelayStatistics() -> MediaRelayStatistics {
        // 获取中继统计信息
        return MediaRelayStatistics(
            totalRelayTime: 0,
            bytesSent: 0,
            bytesReceived: 0,
            packetsLost: 0,
            averageDelay: 0,
            channelStatistics: [:]
        )
    }
}

// 音量指示器管理器
@MainActor
public class VolumeIndicatorManager: ObservableObject {
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var speakingUsers: Set<String> = []
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var dominantSpeaker: String? = nil
    
    // 回调处理器
    public var onVolumeUpdate: (([UserVolumeInfo]) -> Void)?
    public var onUserStartSpeaking: ((String, UserVolumeInfo) -> Void)?
    public var onUserStopSpeaking: ((String, UserVolumeInfo) -> Void)?
    public var onDominantSpeakerChanged: ((String?) -> Void)?
    
    public func configure(with config: VolumeDetectionConfig) {
        // 配置音量检测
    }
    
    public func processVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        self.volumeInfos = volumeInfos
        self.speakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        self.dominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
        
        // 触发回调
        self.onVolumeUpdate?(volumeInfos)
        
        // 检测说话状态变化
        let newSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        let startedSpeaking = newSpeakingUsers.subtracting(self.speakingUsers)
        let stoppedSpeaking = self.speakingUsers.subtracting(newSpeakingUsers)
        
        for userId in startedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                self.onUserStartSpeaking?(userId, volumeInfo)
            }
        }
        
        for userId in stoppedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                self.onUserStopSpeaking?(userId, volumeInfo)
            }
        }
        
        // 检测主讲人变化
        let newDominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
        if newDominantSpeaker != self.dominantSpeaker {
            self.onDominantSpeakerChanged?(newDominantSpeaker)
        }
    }
    
    public func getVolumeLevel(for userId: String) -> Float {
        return volumeInfos.first { $0.userId == userId }?.volume ?? 0.0
    }
    
    public func isSpeaking(_ userId: String) -> Bool {
        return speakingUsers.contains(userId)
    }
    
    public func enable(with config: VolumeDetectionConfig) {
        self.isEnabled = true
        configure(with: config)
    }
    
    public func disable() {
        self.isEnabled = false
        self.volumeInfos = []
        self.speakingUsers = []
        self.dominantSpeaker = nil
    }
    
    public func reset() {
        self.volumeInfos = []
        self.speakingUsers = []
        self.dominantSpeaker = nil
    }
    
    public func getSpeakingUsersCount() -> Int {
        return speakingUsers.count
    }
    
    public func getAverageVolume() -> Float {
        guard !volumeInfos.isEmpty else { return 0.0 }
        let totalVolume = volumeInfos.reduce(0.0) { $0 + $1.volume }
        return totalVolume / Float(volumeInfos.count)
    }
    
    public func getMaxVolume() -> Float {
        return volumeInfos.max { $0.volume < $1.volume }?.volume ?? 0.0
    }
    
    public func getUsersAboveThreshold(_ threshold: Float) -> [UserVolumeInfo] {
        return volumeInfos.filter { $0.volume > threshold }
    }
}
```

### 3. 基础枚举和状态定义

```swift
// 跨媒体流统计信息
public struct MediaRelayStatistics {
    let totalRelayTime: TimeInterval
    let bytesSent: UInt64
    let bytesReceived: UInt64
    let packetsLost: UInt32
    let averageDelay: TimeInterval
    let channelStatistics: [String: ChannelStatistics]
}

public struct ChannelStatistics {
    let channelName: String
    let connectionState: ChannelRelayState
    let bytesSent: UInt64
    let bytesReceived: UInt64
    let lastUpdateTime: Date
}

// 基础枚举和状态
public enum ProviderType {
    case agora
    case tencent
    case zego
}

public enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(Error)
}

public enum StreamPushState {
    case stopped
    case starting
    case running
    case stopping
    case failed(Error)
}

public struct RealtimeMessage {
    let id: String
    let type: MessageType
    let content: String
    let senderId: String
    let timestamp: Date
}

public enum MessageType {
    case text
    case image
    case audio
    case video
    case custom(String)
}

public struct ProcessedMessage {
    let originalMessage: RealtimeMessage
    let processedContent: Any
    let processorId: String
    let timestamp: Date
}

public struct RealtimeConfig {
    let appId: String
    let appSecret: String
    let serverUrl: String?
    let region: String
    let logLevel: String
    let features: [String]
    let audioSettings: AudioSettings?
    let autoRestoreSettings: Bool
    
    public init(
        appId: String,
        appSecret: String,
        serverUrl: String? = nil,
        region: String = "CN",
        logLevel: String = "INFO",
        features: [String] = [],
        audioSettings: AudioSettings? = nil,
        autoRestoreSettings: Bool = true
    ) {
        self.appId = appId
        self.appSecret = appSecret
        self.serverUrl = serverUrl
        self.region = region
        self.logLevel = logLevel
        self.features = []
        self.audioSettings = audioSettings
        self.autoRestoreSettings = autoRestoreSettings
    }
}
```

### 4. 消息系统 (Messaging)
- 文本消息
- 富媒体消息（图片、音频、视频）
- 自定义消息格式
- 消息历史管理
- 离线消息处理

### 5. UI 集成层 (UI Integration)

```swift
// UIKit 支持
public class RealtimeViewController: UIViewController {
    public func configureRealtime(provider: ProviderType)
    public func presentVideoCall(userId: String)
    public func showMessageInput() -> RealtimeMessageInputView
    public func showVolumeIndicators() -> VolumeIndicatorView
}

// SwiftUI 支持
@available(iOS 13.0, *)
public struct RealtimeView: View {
    @StateObject private var viewModel = RealtimeViewModel()
    
    var body: some View {
        // SwiftUI 组件实现
    }
}

public struct VideoCallView: View {
    // SwiftUI 视频通话组件
}

public struct VolumeWaveView: View {
    let userId: String
    let volumeLevel: Float
    let isSpeaking: Bool
    
    var body: some View {
        // 波纹动画实现
    }
}
```

## 支持的服务商

### 第一批集成
1. **声网 Agora**
   - Agora RTC SDK
   - Agora RTM SDK
2. **腾讯云 TRTC**
   - TRTC SDK
   - TIM SDK
3. **即构 ZEGO**
   - ZEGO Express SDK
   - ZEGO ZIM SDK

### 扩展支持
- 融云 RongCloud
- 网易云信 NeteaseIM
- 环信 Easemob
- 自定义服务商接入

## 模块化项目结构

```
RealtimeKit/
├── Sources/
│   ├── RealtimeCore/              # 核心模块
│   │   ├── Protocols/
│   │   │   ├── RTCProvider.swift
│   │   │   ├── RTMProvider.swift
│   │   │   └── MessageProcessor.swift
│   │   ├── Models/
│   │   │   ├── StreamPushConfig.swift
│   │   │   ├── StreamLayout.swift
│   │   │   ├── MediaRelayConfig.swift
│   │   │   ├── MediaRelayState.swift
│   │   │   ├── VolumeDetectionConfig.swift
│   │   │   ├── UserVolumeInfo.swift
│   │   │   └── TokenInfo.swift
│   │   ├── Managers/
│   │   │   ├── RealtimeManager.swift
│   │   │   ├── TokenManager.swift
│   │   │   ├── MessagePipeline.swift
│   │   │   ├── MediaRelayManager.swift
│   │   │   └── VolumeIndicatorManager.swift
│   │   ├── Utils/
│   │   └── Extensions/
│   ├── RealtimeUIKit/             # UIKit UI 模块  
│   │   ├── ViewControllers/
│   │   │   ├── StreamingViewController.swift
│   │   │   ├── MediaRelayViewController.swift
│   │   │   ├── VolumeIndicatorViewController.swift
│   │   │   └── TokenSettingsViewController.swift
│   │   ├── Views/
│   │   │   ├── StreamLayoutView.swift
│   │   │   ├── MediaRelayControlView.swift
│   │   │   ├── VolumeWaveView.swift
│   │   │   ├── SpeakingIndicatorView.swift
│   │   │   └── MessageProcessorView.swift
│   │   ├── Extensions/
│   │   └── Resources/
│   ├── RealtimeSwiftUI/           # SwiftUI UI 模块
│   │   ├── Views/
│   │   │   ├── StreamingView.swift
│   │   │   ├── MediaRelayView.swift
│   │   │   ├── VolumeIndicatorView.swift
│   │   │   ├── WaveformView.swift
│   │   │   ├── SpeakingUserView.swift
│   │   │   ├── TokenManagementView.swift
│   │   │   └── MessageHandlerView.swift
│   │   ├── ViewModels/
│   │   │   ├── StreamingViewModel.swift
│   │   │   ├── MediaRelayViewModel.swift
│   │   │   ├── VolumeViewModel.swift
│   │   │   └── TokenViewModel.swift
│   │   ├── Modifiers/
│   │   │   ├── VolumeWaveModifier.swift
│   │   │   └── SpeakingAnimationModifier.swift
│   │   └── Extensions/
│   ├── Providers/                 # 服务商模块
│   │   ├── RealtimeAgora/
│   │   │   ├── AgoraRTCProvider.swift
│   │   │   ├── AgoraRTMProvider.swift
│   │   │   ├── AgoraStreamPush.swift
│   │   │   ├── AgoraMediaRelay.swift
│   │   │   ├── AgoraVolumeIndicator.swift
│   │   │   ├── AgoraTokenHandler.swift
│   │   │   └── AgoraMessageProcessor.swift
│   │   ├── RealtimeTencent/
│   │   │   ├── TRTCProvider.swift
│   │   │   ├── TIMProvider.swift
│   │   │   ├── TencentStreamPush.swift
│   │   │   ├── TencentMediaRelay.swift
│   │   │   ├── TencentVolumeIndicator.swift
│   │   │   └── TencentTokenHandler.swift
│   │   └── RealtimeZego/
│   │       ├── ZegoExpressProvider.swift
│   │       ├── ZegoZIMProvider.swift
│   │       ├── ZegoStreamPush.swift
│   │       ├── ZegoMediaRelay.swift
│   │       ├── ZegoVolumeIndicator.swift
│   │       └── ZegoTokenHandler.swift
│   ├── RealtimeMocking/           # 测试工具模块
│   │   ├── MockProviders/
│   │   ├── MockStreamPush.swift
│   │   ├── MockMediaRelay.swift
│   │   ├── MockVolumeIndicator.swift
│   │   ├── MockTokenManager.swift
│   │   ├── TestHelpers/
│   │   └── Fixtures/
│   ├── RealtimeKit/               # 主聚合模块
│   │   └── RealtimeKit.swift
│   ├── UIKitDemo/                 # UIKit Demo 应用
│   │   ├── App/
│   │   ├── ViewControllers/
│   │   │   ├── LiveStreamingViewController.swift
│   │   │   ├── MediaRelayViewController.swift
│   │   │   ├── VolumeIndicatorViewController.swift
│   │   │   └── MessageCenterViewController.swift
│   │   ├── Views/
│   │   ├── Models/
│   │   └── Resources/
│   └── SwiftUIDemo/               # SwiftUI Demo 应用
│       ├── App/
│       ├── Views/
│       │   ├── LiveStreamingView.swift
│       │   ├── MediaRelayView.swift
│       │   ├── VolumeVisualizerView.swift
│       │   └── MessageCenterView.swift
│       ├── ViewModels/
│       ├── Models/
│       └── Resources/
├── Tests/
│   └── RealtimeKitTests/
│       ├── TokenTests/
│       ├── StreamPushTests/
│       ├── MediaRelayTests/
│       ├── VolumeIndicatorTests/
│       └── MessageProcessingTests/
├── Package.swift
├── README.md
└── Documentation/
```

## Demo 应用功能要求

### UIKit Demo 应用特性

```swift
// UIKitDemo/App/AppDelegate.swift
import UIKit
import RealtimeKit
import RealtimeUIKit
import RealtimeAgora

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 配置 RealtimeKit
        RealtimeManager.shared.configure(
            provider: .agora,
            config: RealtimeConfig(
                appId: "demo_app_id",
                appSecret: "demo_secret"
            )
        )
        
        // 配置音量指示器
        try await RealtimeManager.shared.enableVolumeIndicator(
            config: VolumeDetectionConfig.default
        )
        
        return true
    }
}
```

**核心功能演示:**
- 登录/注册界面
- 房间列表和创建
- 文本消息聊天
- 1v1 视频通话
- 多人会议室
- **直播转推流设置**
- **媒体流跨频道中继**
- **Token 自动续期演示**
- **音量可视化和说话指示器**
- **"谁在说话"波纹动画**
- **消息处理中心**
- 设置和配置界面

### SwiftUI Demo 应用特性

```swift
// SwiftUIDemo/App/App.swift
import SwiftUI
import RealtimeKit
import RealtimeSwiftUI
import RealtimeAgora

@main
struct RealtimeSwiftUIDemoApp: App {
    init() {
        // 配置 RealtimeKit
        RealtimeManager.shared.configure(
            provider: .agora,
            config: RealtimeConfig(
                appId: "demo_app_id", 
                appSecret: "demo_secret"
            )
        )
        
        Task {
            try await RealtimeManager.shared.enableVolumeIndicator(
                config: VolumeDetectionConfig(
                    detectionInterval: 200,
                    speakingThreshold: 0.2,
                    smoothFactor: 0.4
                )
            )
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**核心功能演示:**
- 现代 SwiftUI 界面设计
- 声明式 UI 状态管理
- Combine 数据流处理
- 原生 SwiftUI 动画效果
- iPad 自适应布局
- **实时转推流控制面板**
- **跨频道媒体流中继界面**
- **Token 状态实时监控**
- **实时音量波形可视化**
- **动态说话指示器动画**
- **主讲人高亮效果**
- **消息处理可视化界面**

### Demo 应用权限配置
**相机权限**: "This demo app uses the camera for video calls."
**麦克风权限**: "This demo app uses the microphone for audio calls."  
**相册权限**: "This demo app allows selecting images to share."
**后台音频**: "This demo app supports background audio for calls."

### 运行和测试方式
```bash
# 运行 UIKit Demo
swift run UIKitDemoApp

# 运行 SwiftUI Demo  
swift run SwiftUIDemoApp

# 在 Xcode 中打开
open Package.swift
# 然后选择对应的 Scheme 运行
```

## 模块化使用方式

### 1. 完整导入 (推荐)
```swift
// 导入完整功能
import RealtimeKit

// 自动包含所有模块：Core + UIKit + SwiftUI
let manager = RealtimeManager.shared
```

### 2. 按需导入 (精简)
```swift
// 仅导入核心功能
import RealtimeCore

// 仅导入特定 UI 框架
import RealtimeUIKit    // 或
import RealtimeSwiftUI

// 仅导入特定服务商
import RealtimeAgora
import RealtimeTencent
```

### 3. 测试环境导入
```swift
// 导入测试工具
import RealtimeMocking

let mockProvider = MockRTCProvider()
```

### 4. Package.swift 依赖配置
```swift
// 在其他项目中使用
dependencies: [
    // 完整功能
    .package(url: "https://github.com/yourorg/RealtimeKit", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            // 可选择性导入
            .product(name: "RealtimeCore", package: "RealtimeKit"),
            .product(name: "RealtimeSwiftUI", package: "RealtimeKit"),
            .product(name: "RealtimeAgora", package: "RealtimeKit")
        ]
    )
]
```

## 配置系统设计

### 配置文件支持
```swift
public struct RealtimeConfig {
    let appId: String
    let appSecret: String
    let serverUrl: String?
    let region: Region
    let logLevel: LogLevel
    let features: [Feature]
}

// 支持多种配置方式
// 1. 代码配置
// 2. plist 文件配置
// 3. JSON 配置文件
// 4. 环境变量配置
```

## API 设计原则

### 1. 链式调用支持
```swift
RealtimeKit
    .configure(provider: .agora, config: config)
    .enableLogging(.debug)
    .setDelegate(self)
    .enableAutoTokenRenewal(true)
    .setTokenRenewalHandler { provider in
        // 获取新 Token 的逻辑
        return await TokenService.renewToken(for: provider)
    }
    .enableStreamPush()
    .enableMediaRelay()
    .enableVolumeIndicator(config: .default)
    .setMessageProcessor(CustomMessageProcessor())
```

### 2. Result 类型错误处理
```swift
public enum RealtimeError: Error {
    case configurationError(String)
    case connectionFailed(String)
    case authenticationFailed
    case networkError(Error)
    case noActiveSession
    
    // Token 相关错误
    case tokenExpired(ProviderType)
    case tokenRenewalFailed(ProviderType, Error)
    case invalidToken(ProviderType)
    
    // 转推流相关错误
    case streamPushStartFailed(String)
    case streamPushStopFailed(String)
    case invalidStreamConfig(String)
    case streamLayoutUpdateFailed(String)
    
    // 跨媒体流相关错误
    case mediaRelayStartFailed(String)
    case mediaRelayStopFailed(String)
    case mediaRelayUpdateFailed(String)
    case invalidRelayConfig(String)
    case relayChannelConnectionFailed(String)
    
    // 音量指示器相关错误
    case volumeIndicatorStartFailed(String)
    case volumeIndicatorStopFailed(String)
    case invalidVolumeConfig(String)
    case audioPermissionDenied
    
    // 消息处理相关错误
    case messageProcessingFailed(String)
    case unsupportedMessageType(String)
    case messageHandlerNotFound
}

// 新增状态枚举
public enum VolumeIndicatorState {
    case disabled
    case starting
    case active
    case stopping
    case failed(Error)
}

public enum ProcessingState {
    case idle
    case processing
    case completed
    case failed(Error)
}

public struct TokenWarning {
    let provider: ProviderType
    let expiresIn: Int // 秒数
    let renewalAvailable: Bool
}
```

### 3. 多种回调方式支持

```swift
// UIKit - Delegate 模式
public protocol RealtimeDelegate: AnyObject {
    func didReceiveMessage(_ message: RealtimeMessage)
    func didJoinRoom(_ roomId: String)
    
    // 新增 Token 处理
    func tokenWillExpire(provider: ProviderType, in seconds: Int)
    func tokenDidRenew(provider: ProviderType)
    
    // 新增转推流状态
    func streamPushDidStart()
    func streamPushDidStop()
    func streamPushDidFail(error: RealtimeError)
    
    // 新增跨媒体流状态
    func mediaRelayDidStart()
    func mediaRelayDidStop()
    func mediaRelayDidFail(error: MediaRelayError)
    func mediaRelayChannelDidConnect(_ channel: String)
    func mediaRelayChannelDidDisconnect(_ channel: String, error: MediaRelayError?)
    
    // 新增音量指示器状态
    func volumeIndicatorDidUpdate(_ volumeInfos: [UserVolumeInfo])
    func userDidStartSpeaking(_ userId: String, volumeInfo: UserVolumeInfo)
    func userDidStopSpeaking(_ userId: String, volumeInfo: UserVolumeInfo)
    func dominantSpeakerDidChange(_ userId: String?)
    
    // 新增消息处理状态
    func messageProcessingDidStart()
    func messageDidProcess(_ message: ProcessedMessage)
    func messageProcessingDidFail(_ error: Error)
}

// UIKit - Closure 模式  
public func onMessageReceived(_ handler: @escaping (RealtimeMessage) -> Void)
public func onTokenWillExpire(_ handler: @escaping (ProviderType, Int) -> Void)
public func onStreamPushStateChanged(_ handler: @escaping (StreamPushState) -> Void)
public func onMediaRelayStateChanged(_ handler: @escaping (MediaRelayState) -> Void)
public func onVolumeUpdate(_ handler: @escaping ([UserVolumeInfo]) -> Void)
public func onSpeakingStateChanged(_ handler: @escaping (String, Bool) -> Void)

// SwiftUI - Combine 支持
@Published public var messages: [RealtimeMessage] = []
@Published public var connectionState: ConnectionState = .disconnected
@Published public var tokenExpirationWarning: TokenWarning? = nil
@Published public var streamPushState: StreamPushState = .stopped
@Published public var mediaRelayState: MediaRelayState? = nil
@Published public var volumeInfos: [UserVolumeInfo] = []
@Published public var speakingUsers: Set<String> = []
@Published public var dominantSpeaker: String? = nil
@Published public var messageProcessingState: ProcessingState = .idle

// SwiftUI - AsyncSequence 支持
public var messageStream: AsyncStream<RealtimeMessage> { get }
public var tokenEventStream: AsyncStream<TokenEvent> { get }
public var streamPushEventStream: AsyncStream<StreamPushEvent> { get }
public var mediaRelayEventStream: AsyncStream<MediaRelayEvent> { get }
public var volumeEventStream: AsyncStream<VolumeEvent> { get }
```

## 性能优化要求

### 1. 内存管理
- 使用 weak 引用避免循环引用
- 及时释放不需要的资源
- 实现对象池减少频繁创建销毁
- 音量数据缓存优化

### 2. 网络优化
- 连接池管理
- 心跳机制
- 断线重连
- 数据压缩
- 音量数据传输优化

### 3. 线程安全
- 主线程回调 UI 更新
- 后台队列处理网络请求
- 线程安全的状态管理
- 音量检测异步处理

### 4. 音量处理优化
- 平滑滤波算法减少抖动
- 自适应阈值调整
- 批量处理音量数据
- 内存高效的历史数据管理

## 测试要求

### 1. Swift Testing 框架
- 使用 **Swift Testing** 替代 XCTest
- 利用 `@Test` 宏简化测试编写
- 支持参数化测试和条件测试
- 覆盖率 > 80%

### 2. 单元测试
- 核心协议测试
- 数据模型测试
- 管理器功能测试
- Token 管理测试
- 转推流功能测试
- 跨媒体流功能测试
- 音量指示器测试
- 消息处理测试
- 错误处理测试

### 3. 集成测试
- 多服务商兼容性测试
- 网络异常处理测试
- 并发操作测试
- 内存泄漏测试
- 性能基准测试

### 4. UI 测试
- UIKit 组件测试
- SwiftUI 视图测试
- 用户交互测试
- 动画效果测试
- 音量可视化测试

## 文档要求

### 1. API 文档
- 完整的 API 参考文档
- 代码示例和最佳实践
- 迁移指南
- 故障排除指南

### 2. 集成指南
- 快速开始教程
- 各服务商配置指南
- 高级功能使用指南
- 性能优化建议

### 3. Demo 应用文档
- UIKit Demo 使用说明
- SwiftUI Demo 使用说明
- 功能演示视频
- 常见问题解答

## 版本管理和发布

### 语义化版本控制
- 主版本号：不兼容的 API 修改
- 次版本号：向下兼容的功能性新增
- 修订号：向下兼容的问题修正

### 发布流程
1. 功能开发和测试
2. 文档更新
3. 版本标记
4. Swift Package Manager 发布
5. 发布说明

### 兼容性保证
- 向下兼容承诺
- 废弃 API 迁移期
- 版本升级指南

## 安全和隐私

### 数据安全
- 端到端加密支持
- 敏感信息保护
- 安全的 Token 存储
- 数据传输加密

### 隐私保护
- 最小权限原则
- 用户数据控制
- 隐私政策合规
- GDPR 兼容性

## 国际化支持

### 多语言支持
- 中文（简体/繁体）
- 英文
- 日文
- 韩文
- 其他主要语言

### 本地化内容
- 错误消息本地化
- UI 文本本地化
- 文档多语言版本
- 示例代码本地化

## 社区和支持

### 开源社区
- GitHub 仓库管理
- Issue 跟踪和处理
- Pull Request 审核
- 社区贡献指南

### 技术支持
- 官方技术支持渠道
- 社区论坛
- 在线文档
- 视频教程

## 路线图

### 第一阶段 (v1.0)
- 核心 RTC/RTM 功能
- 声网 Agora 集成
- 基础 UI 组件
- 基本音量指示器
- 简单转推流功能

### 第二阶段 (v1.1)
- 腾讯云 TRTC 集成
- 即构 ZEGO 集成
- 高级音量可视化
- 跨媒体流中继
- Token 自动续期
- 消息处理管道

### 第三阶段 (v1.2)
- 更多服务商支持
- 高级 UI 组件
- 性能优化
- 更多动画效果
- 智能音频设置

### 第四阶段 (v2.0)
- 架构重构
- 新特性支持
- 跨平台扩展
- AI 功能集成

## 总结

RealtimeKit 旨在成为 iOS/macOS 平台上最全面、最易用的实时通信解决方案。通过统一的 API 接口、插件化架构、完善的 UI 组件和丰富的功能特性，为开发者提供一站式的实时通信开发体验。

### 核心价值
1. **统一性** - 一套 API 支持多家服务商
2. **易用性** - 简单的集成和使用方式
3. **灵活性** - 模块化设计，按需使用
4. **完整性** - 从核心功能到 UI 组件的全覆盖
5. **现代性** - 支持最新的 Swift 特性和设计模式
6. **可靠性** - 完善的测试和错误处理
7. **扩展性** - 易于添加新的服务商和功能

通过 RealtimeKit，开发者可以快速构建高质量的实时通信应用，专注于业务逻辑而不是底层技术细节。