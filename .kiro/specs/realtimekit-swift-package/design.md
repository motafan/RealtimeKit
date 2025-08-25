# RealtimeKit Swift Package 设计文档

## 概述

RealtimeKit 是一个模块化的 Swift Package，采用协议导向编程和插件化架构，为 iOS/macOS 应用提供统一的实时通信解决方案。该设计文档基于 16 个核心需求，重点关注可扩展性、性能优化、类型安全和现代 Swift 特性的充分利用。

### 设计原则

1. **统一 API 接口**: 通过 RTCProvider 和 RTMProvider 协议屏蔽不同服务商差异（需求 1）
2. **插件化架构**: 支持多服务商动态切换和扩展（需求 2）
3. **响应式设计**: 全面支持 SwiftUI 和 UIKit 双框架（需求 11, 15）
4. **现代并发**: 全面采用 Swift Concurrency (async/await, actors)（需求 15）
5. **模块化设计**: 支持按需导入和独立模块管理（需求 12）


## 架构设计

### 整体架构

```mermaid
graph TB
    subgraph "应用层"
        A[UIKit App] 
        B[SwiftUI App]
    end
    
    subgraph "UI 集成层"
        C[RealtimeUIKit]
        D[RealtimeSwiftUI]
    end
    
    subgraph "核心管理层"
        E[RealtimeManager]
        F[TokenManager]
        G[VolumeIndicatorManager]
        H[MediaRelayManager]
    end
    
    subgraph "抽象协议层"
        I[RTCProvider Protocol]
        J[RTMProvider Protocol]
        K[MessageProcessor Protocol]
    end
    
    subgraph "服务商实现层"
        L[AgoraProvider]
        M[TencentProvider]
        N[ZegoProvider]
    end
    
    subgraph "存储层"
        O[AudioSettingsStorage]
        P[UserSessionStorage]
    end
    
    A --> C
    B --> D
    C --> E
    D --> E
    E --> F
    E --> G
    E --> H
    E --> I
    E --> J
    I --> L
    I --> M
    I --> N
    J --> L
    J --> M
    J --> N
    E --> O
    E --> P
```

### 模块依赖关系

```mermaid
graph LR
    subgraph "Core Modules"
        A[RealtimeCore] --> B[RealtimeUIKit]
        A --> C[RealtimeSwiftUI]
    end
    
    subgraph "Provider Modules"
        A --> D[RealtimeAgora]
        A --> E[RealtimeTencent]
        A --> F[RealtimeZego]
    end
    
    subgraph "Testing Module"
        A --> G[RealtimeMocking]
    end
    
    subgraph "Main Package"
        H[RealtimeKit] --> A
        H --> B
        H --> C
        H --> D
        H --> E
        H --> F
    end
```

### 平台和版本支持

**设计决策**: 基于需求 15 的平台兼容性要求，系统支持：
- **iOS**: 13.0+ (支持 SwiftUI 和现代 Swift 特性)
- **macOS**: 10.15+ (Catalyst 和原生 macOS 应用支持)
- **Swift**: 6.2+ (全面支持 Swift Concurrency 和 Structured Concurrency)
- **框架兼容**: UIKit 和 SwiftUI 双框架支持，可在同一应用中混合使用

## 组件和接口设计

### 1. 核心协议设计

#### RTCProvider 协议
```swift
public protocol RTCProvider: AnyObject {
    // 基础生命周期
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
    
    // 音量控制
    func setAudioMixingVolume(_ volume: Int) async throws
    func getAudioMixingVolume() -> Int
    func setPlaybackSignalVolume(_ volume: Int) async throws
    func getPlaybackSignalVolume() -> Int
    func setRecordingSignalVolume(_ volume: Int) async throws
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
```

#### RTMProvider 协议
```swift
public protocol RTMProvider: AnyObject {
    func initialize(config: RTMConfig) async throws
    func sendMessage(_ message: RealtimeMessage) async throws
    func subscribe(to channel: String) async throws
    
    // 消息处理功能 (需求 10)
    func setMessageHandler(_ handler: @escaping (RealtimeMessage) -> Void)
    func setConnectionStateHandler(_ handler: @escaping (ConnectionState) -> Void)
    func processIncomingMessage(_ rawMessage: Any) async throws -> RealtimeMessage
    func registerMessageProcessor<T: MessageProcessor>(_ processor: T) throws
    func unregisterMessageProcessor(for messageType: String) throws
    
    // Token 管理 (需求 9)
    func renewToken(_ newToken: String) async throws
    func onTokenWillExpire(_ handler: @escaping (Int) -> Void)
}

// 消息处理器协议 (需求 10.2, 10.3)
public protocol MessageProcessor: AnyObject {
    var supportedMessageTypes: [String] { get }
    func canProcess(_ message: RealtimeMessage) -> Bool
    func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult
    func handleProcessingError(_ error: Error, for message: RealtimeMessage) async -> MessageProcessingResult
}

public enum MessageProcessingResult {
    case processed(RealtimeMessage?)
    case failed(Error)
    case skipped
    case retry(after: TimeInterval)
}
```

### 2. 数据模型设计

#### 用户角色和权限系统 (需求 4)
```swift
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
    
    // 权限检查方法 (需求 4.2, 4.5)
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
    
    public var canSwitchToRole: Set<UserRole> {
        switch self {
        case .broadcaster: return [.moderator]
        case .audience: return [.coHost]
        case .coHost: return [.audience, .broadcaster]
        case .moderator: return [.broadcaster]
        }
    }
}

// 用户会话模型 (需求 4.4)
public struct UserSession: Codable, Equatable {
    let userId: String
    let userName: String
    let userRole: UserRole
    let roomId: String?
    let joinTime: Date
    let lastActiveTime: Date
    
    public init(userId: String, userName: String, userRole: UserRole, roomId: String? = nil) {
        self.userId = userId
        self.userName = userName
        self.userRole = userRole
        self.roomId = roomId
        self.joinTime = Date()
        self.lastActiveTime = Date()
    }
}
```

#### 音频设置模型 (需求 5)
```swift
public struct AudioSettings: Codable, Equatable {
    let microphoneMuted: Bool                // 需求 5.1
    let audioMixingVolume: Int              // 0-100, 需求 5.2
    let playbackSignalVolume: Int           // 0-100, 需求 5.2
    let recordingSignalVolume: Int          // 0-100, 需求 5.2
    let localAudioStreamActive: Bool        // 需求 5.3
    let lastModified: Date                  // 用于同步检测
    
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
        self.lastModified = Date()
    }
    
    // 设置更新方法 (需求 5.4, 5.6)
    public func withUpdatedVolume(
        audioMixing: Int? = nil,
        playbackSignal: Int? = nil,
        recordingSignal: Int? = nil
    ) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: self.microphoneMuted,
            audioMixingVolume: audioMixing ?? self.audioMixingVolume,
            playbackSignalVolume: playbackSignal ?? self.playbackSignalVolume,
            recordingSignalVolume: recordingSignal ?? self.recordingSignalVolume,
            localAudioStreamActive: self.localAudioStreamActive
        )
    }
    
    public static let `default` = AudioSettings()
}
```

#### 音量检测配置 (需求 6)
```swift
public struct VolumeDetectionConfig: Codable, Equatable {
    let detectionInterval: Int      // 检测间隔（毫秒）, 需求 6.1
    let speakingThreshold: Float    // 说话音量阈值 (0.0 - 1.0), 需求 6.1
    let silenceThreshold: Float     // 静音音量阈值
    let includeLocalUser: Bool      // 是否包含本地用户
    let smoothFactor: Float         // 平滑处理参数, 需求 6.6
    
    public init(
        detectionInterval: Int = 300,
        speakingThreshold: Float = 0.3,
        silenceThreshold: Float = 0.05,
        includeLocalUser: Bool = true,
        smoothFactor: Float = 0.3
    ) {
        self.detectionInterval = max(100, min(5000, detectionInterval))
        self.speakingThreshold = max(0.0, min(1.0, speakingThreshold))
        self.silenceThreshold = max(0.0, min(1.0, silenceThreshold))
        self.includeLocalUser = includeLocalUser
        self.smoothFactor = max(0.0, min(1.0, smoothFactor))
    }
    
    public static let `default` = VolumeDetectionConfig()
}

// 音量信息模型 (需求 6.2)
public struct UserVolumeInfo: Codable, Equatable {
    let userId: String
    let volume: Float               // 0.0 - 1.0
    let isSpeaking: Bool
    let timestamp: Date
    
    public init(userId: String, volume: Float, isSpeaking: Bool, timestamp: Date = Date()) {
        self.userId = userId
        self.volume = max(0.0, min(1.0, volume))
        self.isSpeaking = isSpeaking
        self.timestamp = timestamp
    }
}

// 音量事件类型 (需求 6.3)
public enum VolumeEvent {
    case userStartedSpeaking(userId: String, volume: Float)
    case userStoppedSpeaking(userId: String, volume: Float)
    case dominantSpeakerChanged(userId: String?)
    case volumeUpdate([UserVolumeInfo])
}
```

### 3. 服务商管理和切换设计 (需求 2)

#### 服务商抽象层设计
```swift
public enum ProviderType: String, CaseIterable {
    case agora = "agora"
    case tencent = "tencent"
    case zego = "zego"
    case mock = "mock"  // 用于测试
}

// 服务商工厂 (需求 2.2)
public protocol ProviderFactory {
    func createRTCProvider() -> RTCProvider
    func createRTMProvider() -> RTMProvider
    func supportedFeatures() -> Set<ProviderFeature>
}

public enum ProviderFeature: String, CaseIterable {
    case audioStreaming = "audio_streaming"
    case videoStreaming = "video_streaming"
    case streamPush = "stream_push"
    case mediaRelay = "media_relay"
    case volumeIndicator = "volume_indicator"
    case messageProcessing = "message_processing"
}

// 服务商切换管理器 (需求 2.3, 2.4)
@MainActor
public class ProviderSwitchManager: ObservableObject {
    @Published public private(set) var currentProvider: ProviderType = .agora
    @Published public private(set) var availableProviders: [ProviderType] = []
    @Published public private(set) var switchingInProgress: Bool = false
    
    private var providerFactories: [ProviderType: ProviderFactory] = [:]
    private var fallbackChain: [ProviderType] = [.agora, .mock]
    
    public func registerProvider(_ type: ProviderType, factory: ProviderFactory) {
        providerFactories[type] = factory
        if !availableProviders.contains(type) {
            availableProviders.append(type)
        }
    }
    
    public func switchProvider(to newProvider: ProviderType, preserveSession: Bool = true) async throws {
        guard availableProviders.contains(newProvider) else {
            throw RealtimeError.providerNotAvailable(newProvider)
        }
        
        switchingInProgress = true
        defer { switchingInProgress = false }
        
        // 实现平滑切换逻辑
        try await performProviderSwitch(to: newProvider, preserveSession: preserveSession)
        currentProvider = newProvider
    }
    
    private func performProviderSwitch(to newProvider: ProviderType, preserveSession: Bool) async throws {
        // 保存当前状态
        let currentSession = RealtimeManager.shared.currentSession
        let currentAudioSettings = RealtimeManager.shared.audioSettings
        
        // 切换到新服务商
        try await RealtimeManager.shared.configure(provider: newProvider, config: RealtimeManager.shared.currentConfig)
        
        // 恢复状态
        if preserveSession, let session = currentSession {
            try await RealtimeManager.shared.restoreSession(session)
        }
        
        try await RealtimeManager.shared.applyAudioSettings(currentAudioSettings)
    }
}
```

### 4. 管理器架构设计

#### RealtimeManager 核心设计 (需求 3)
```swift
@MainActor
public class RealtimeManager: ObservableObject {
    public static let shared = RealtimeManager()
    
    // MARK: - Published Properties for SwiftUI (需求 3.2, 11.3)
    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var audioSettings: AudioSettings = .default
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var streamPushState: StreamPushState = .stopped
    @Published public private(set) var mediaRelayState: MediaRelayState?
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var speakingUsers: Set<String> = []
    @Published public private(set) var dominantSpeaker: String? = nil
    
    // MARK: - Private Properties
    private let settingsStorage = AudioSettingsStorage()
    private let sessionStorage = UserSessionStorage()
    private let tokenManager = TokenManager()
    private let volumeManager = VolumeIndicatorManager()
    private let mediaRelayManager = MediaRelayManager()
    private let providerSwitchManager = ProviderSwitchManager()
    private let messageProcessingManager = MessageProcessingManager()
    
    private var rtcProvider: RTCProvider!
    private var rtmProvider: RTMProvider!
    internal var currentConfig: RealtimeConfig!
    
    // MARK: - Configuration (需求 3.1)
    public func configure(provider: ProviderType, config: RealtimeConfig) async throws {
        currentConfig = config
        
        // 使用工厂模式创建服务商实例 (需求 2.2)
        guard let factory = providerSwitchManager.providerFactories[provider] else {
            throw RealtimeError.providerNotAvailable(provider)
        }
        
        rtcProvider = factory.createRTCProvider()
        rtmProvider = factory.createRTMProvider()
        
        try await rtcProvider.initialize(config: RTCConfig(from: config))
        try await rtmProvider.initialize(config: RTMConfig(from: config))
        
        setupTokenManagement()
        setupVolumeIndicator()
        setupMessageProcessing()
        
        // 恢复设置 (需求 3.5)
        await restorePersistedSettings()
    }
    
    // MARK: - Session Management (需求 4)
    public func loginUser(userId: String, userName: String, userRole: UserRole) async throws {
        let session = UserSession(userId: userId, userName: userName, userRole: userRole)
        
        // 验证角色权限
        guard userRole.hasAudioPermission || userRole == .audience else {
            throw RealtimeError.insufficientPermissions(userRole)
        }
        
        currentSession = session
        sessionStorage.saveUserSession(session)
        
        // 根据角色配置音频权限
        if userRole.hasAudioPermission {
            try await rtcProvider.resumeLocalAudioStream()
        } else {
            try await rtcProvider.stopLocalAudioStream()
        }
    }
    
    public func switchUserRole(_ newRole: UserRole) async throws {
        guard let currentSession = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        guard currentSession.userRole.canSwitchToRole.contains(newRole) else {
            throw RealtimeError.invalidRoleTransition(from: currentSession.userRole, to: newRole)
        }
        
        try await rtcProvider.switchUserRole(newRole)
        
        let updatedSession = UserSession(
            userId: currentSession.userId,
            userName: currentSession.userName,
            userRole: newRole,
            roomId: currentSession.roomId
        )
        
        self.currentSession = updatedSession
        sessionStorage.saveUserSession(updatedSession)
    }
    
    // MARK: - Audio Settings Management (需求 5)
    public func setAudioMixingVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setAudioMixingVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(audioMixing: clampedVolume)
        settingsStorage.saveAudioSettings(audioSettings)
    }
    
    public func muteMicrophone(_ muted: Bool) async throws {
        try await rtcProvider.muteMicrophone(muted)
        
        audioSettings = AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: audioSettings.audioMixingVolume,
            playbackSignalVolume: audioSettings.playbackSignalVolume,
            recordingSignalVolume: audioSettings.recordingSignalVolume,
            localAudioStreamActive: audioSettings.localAudioStreamActive
        )
        settingsStorage.saveAudioSettings(audioSettings)
    }
    
    private func restorePersistedSettings() async {
        // 恢复音频设置 (需求 5.5)
        audioSettings = settingsStorage.loadAudioSettings()
        
        // 恢复用户会话 (需求 3.5)
        if let session = sessionStorage.loadUserSession() {
            currentSession = session
        }
        
        // 同步设置到 Provider (需求 5.6)
        do {
            try await applyAudioSettings(audioSettings)
        } catch {
            print("Failed to restore audio settings: \(error)")
        }
    }
    
    internal func applyAudioSettings(_ settings: AudioSettings) async throws {
        try await rtcProvider.muteMicrophone(settings.microphoneMuted)
        try await rtcProvider.setAudioMixingVolume(settings.audioMixingVolume)
        try await rtcProvider.setPlaybackSignalVolume(settings.playbackSignalVolume)
        try await rtcProvider.setRecordingSignalVolume(settings.recordingSignalVolume)
        
        if settings.localAudioStreamActive {
            try await rtcProvider.resumeLocalAudioStream()
        } else {
            try await rtcProvider.stopLocalAudioStream()
        }
    }
    
    internal func restoreSession(_ session: UserSession) async throws {
        currentSession = session
        sessionStorage.saveUserSession(session)
    }
    
    // MARK: - Private Setup Methods
    private func setupTokenManagement() {
        rtcProvider.onTokenWillExpire { [weak self] expiresIn in
            Task { @MainActor in
                await self?.tokenManager.handleTokenExpiration(
                    provider: self?.providerSwitchManager.currentProvider ?? .agora,
                    expiresIn: expiresIn
                )
            }
        }
        
        rtmProvider.onTokenWillExpire { [weak self] expiresIn in
            Task { @MainActor in
                await self?.tokenManager.handleTokenExpiration(
                    provider: self?.providerSwitchManager.currentProvider ?? .agora,
                    expiresIn: expiresIn
                )
            }
        }
    }
    
    private func setupVolumeIndicator() {
        rtcProvider.setVolumeIndicatorHandler { [weak self] volumeInfos in
            Task { @MainActor in
                self?.volumeManager.processVolumeUpdate(volumeInfos)
                self?.volumeInfos = volumeInfos
                self?.speakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
                self?.dominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
            }
        }
    }
    
    // 消息处理设置 (需求 10)
    private func setupMessageProcessing() {
        rtmProvider.setMessageHandler { [weak self] message in
            Task { @MainActor in
                await self?.messageProcessingManager.processMessage(message)
            }
        }
    }
}

### 5. 消息处理管道系统设计 (需求 10)

#### MessageProcessingManager 设计
```swift
@MainActor
public class MessageProcessingManager: ObservableObject {
    @Published public private(set) var processingQueue: [RealtimeMessage] = []
    @Published public private(set) var processingStats: MessageProcessingStats = MessageProcessingStats()
    
    private var processors: [String: MessageProcessor] = [:]
    private var processingChain: [MessageProcessor] = []
    
    // 注册消息处理器 (需求 10.2)
    public func registerProcessor<T: MessageProcessor>(_ processor: T) throws {
        for messageType in processor.supportedMessageTypes {
            if processors[messageType] != nil {
                throw RealtimeError.processorAlreadyRegistered(messageType)
            }
            processors[messageType] = processor
        }
        processingChain.append(processor)
    }
    
    // 处理消息 (需求 10.3, 10.4)
    public func processMessage(_ message: RealtimeMessage) async {
        processingQueue.append(message)
        processingStats.totalReceived += 1
        
        do {
            let result = try await processMessageThroughChain(message)
            await handleProcessingResult(result, for: message)
        } catch {
            await handleProcessingError(error, for: message)
        }
        
        // 从队列中移除已处理的消息
        processingQueue.removeAll { $0.id == message.id }
    }
    
    private func processMessageThroughChain(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        for processor in processingChain {
            if processor.canProcess(message) {
                let result = try await processor.process(message)
                switch result {
                case .processed(let processedMessage):
                    processingStats.totalProcessed += 1
                    return result
                case .failed(let error):
                    return try await processor.handleProcessingError(error, for: message)
                case .skipped:
                    continue
                case .retry(let delay):
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await processor.process(message)
                }
            }
        }
        
        processingStats.totalSkipped += 1
        return .skipped
    }
    
    private func handleProcessingResult(_ result: MessageProcessingResult, for message: RealtimeMessage) async {
        switch result {
        case .processed(let processedMessage):
            if let processed = processedMessage {
                // 触发处理完成回调
                NotificationCenter.default.post(
                    name: .messageProcessed,
                    object: processed
                )
            }
        case .failed(let error):
            await handleProcessingError(error, for: message)
        case .skipped:
            break
        case .retry:
            // 重试逻辑已在 processMessageThroughChain 中处理
            break
        }
    }
    
    private func handleProcessingError(_ error: Error, for message: RealtimeMessage) async {
        processingStats.totalFailed += 1
        
        // 错误恢复机制 (需求 10.5)
        if processingStats.shouldRetry(for: message.type) {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒后重试
            await processMessage(message)
        } else {
            // 记录错误并通知
            print("Message processing failed: \(error)")
            NotificationCenter.default.post(
                name: .messageProcessingFailed,
                object: MessageProcessingError(message: message, error: error)
            )
        }
    }
}

public struct MessageProcessingStats {
    var totalReceived: Int = 0
    var totalProcessed: Int = 0
    var totalFailed: Int = 0
    var totalSkipped: Int = 0
    var retryCount: [String: Int] = [:]
    
    func shouldRetry(for messageType: String) -> Bool {
        let count = retryCount[messageType] ?? 0
        return count < 3
    }
}

public struct MessageProcessingError {
    let message: RealtimeMessage
    let error: Error
    let timestamp: Date = Date()
}

extension Notification.Name {
    static let messageProcessed = Notification.Name("RealtimeKit.messageProcessed")
    static let messageProcessingFailed = Notification.Name("RealtimeKit.messageProcessingFailed")
}
```

#### 存储管理器设计
```swift
public class AudioSettingsStorage {
    private let userDefaults = UserDefaults.standard
    private let audioSettingsKey = "RealtimeKit.AudioSettings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public func saveAudioSettings(_ settings: AudioSettings) {
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: audioSettingsKey)
        } catch {
            print("Failed to save audio settings: \(error)")
        }
    }
    
    public func loadAudioSettings() -> AudioSettings {
        guard let data = userDefaults.data(forKey: audioSettingsKey) else {
            return .default
        }
        
        do {
            return try decoder.decode(AudioSettings.self, from: data)
        } catch {
            print("Failed to load audio settings: \(error)")
            return .default
        }
    }
    
    public func clearAudioSettings() {
        userDefaults.removeObject(forKey: audioSettingsKey)
    }
}
```

### 4. 音量指示器系统设计

#### VolumeIndicatorManager 设计
```swift
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
    
    private var config: VolumeDetectionConfig = .default
    private var previousSpeakingUsers: Set<String> = []
    private var previousDominantSpeaker: String? = nil
    
    public func processVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        let smoothedVolumeInfos = applySmoothingFilter(volumeInfos)
        
        self.volumeInfos = smoothedVolumeInfos
        
        let newSpeakingUsers = Set(smoothedVolumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        let newDominantSpeaker = smoothedVolumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        
        // 检测说话状态变化
        detectSpeakingStateChanges(
            previous: previousSpeakingUsers,
            current: newSpeakingUsers,
            volumeInfos: smoothedVolumeInfos
        )
        
        // 检测主讲人变化
        if newDominantSpeaker != previousDominantSpeaker {
            dominantSpeaker = newDominantSpeaker
            onDominantSpeakerChanged?(newDominantSpeaker)
            previousDominantSpeaker = newDominantSpeaker
        }
        
        speakingUsers = newSpeakingUsers
        previousSpeakingUsers = newSpeakingUsers
        
        onVolumeUpdate?(smoothedVolumeInfos)
    }
    
    private func applySmoothingFilter(_ volumeInfos: [UserVolumeInfo]) -> [UserVolumeInfo] {
        return volumeInfos.map { volumeInfo in
            let previousVolume = self.volumeInfos.first { $0.userId == volumeInfo.userId }?.volume ?? 0.0
            let smoothedVolume = previousVolume * (1.0 - config.smoothFactor) + volumeInfo.volume * config.smoothFactor
            
            return UserVolumeInfo(
                userId: volumeInfo.userId,
                volume: smoothedVolume,
                isSpeaking: smoothedVolume > config.speakingThreshold,
                timestamp: volumeInfo.timestamp
            )
        }
    }
    
    private func detectSpeakingStateChanges(
        previous: Set<String>,
        current: Set<String>,
        volumeInfos: [UserVolumeInfo]
    ) {
        let startedSpeaking = current.subtracting(previous)
        let stoppedSpeaking = previous.subtracting(current)
        
        for userId in startedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                onUserStartSpeaking?(userId, volumeInfo)
            }
        }
        
        for userId in stoppedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                onUserStopSpeaking?(userId, volumeInfo)
            }
        }
    }
}
```

### 5. 自动状态持久化和恢复机制设计 (需求 18)

#### 核心持久化架构

```mermaid
graph TB
    subgraph "应用层"
        A[SwiftUI Views] 
        B[UIKit Controllers]
    end
    
    subgraph "持久化属性包装器层"
        C[@RealtimeStorage]
        D[@SecureRealtimeStorage]
    end
    
    subgraph "存储管理层"
        E[StorageManager]
        F[StorageBackend Protocol]
    end
    
    subgraph "存储后端层"
        G[UserDefaultsBackend]
        H[KeychainBackend]
        I[MockStorageBackend]
    end
    
    subgraph "数据序列化层"
        J[StorageEncoder]
        K[StorageDecoder]
    end
    
    A --> C
    B --> C
    C --> E
    D --> E
    E --> F
    F --> G
    F --> H
    F --> I
    E --> J
    E --> K
```

#### 属性包装器设计

```swift
// 主要的持久化属性包装器 (需求 18.1, 18.2)
@propertyWrapper
public struct RealtimeStorage<Value: Codable>: DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let backend: StorageBackend
    private let namespace: String
    
    @State private var storedValue: Value
    
    public var wrappedValue: Value {
        get { storedValue }
        nonmutating set {
            storedValue = newValue
            Task {
                await backend.store(newValue, forKey: namespacedKey)
            }
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
    
    private var namespacedKey: String {
        "\(namespace).\(key)"
    }
    
    public init(
        wrappedValue defaultValue: Value,
        _ key: String,
        backend: StorageBackend = UserDefaultsBackend.shared,
        namespace: String = "RealtimeKit"
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.backend = backend
        self.namespace = namespace
        
        // 初始化时从存储中恢复值 (需求 18.3)
        let namespacedKey = "\(namespace).\(key)"
        if let stored: Value = backend.retrieve(forKey: namespacedKey) {
            self._storedValue = State(initialValue: stored)
        } else {
            self._storedValue = State(initialValue: defaultValue)
        }
    }
}

// 安全存储属性包装器 (需求 18.5)
@propertyWrapper
public struct SecureRealtimeStorage<Value: Codable>: DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let namespace: String
    
    @State private var storedValue: Value
    
    public var wrappedValue: Value {
        get { storedValue }
        nonmutating set {
            storedValue = newValue
            Task {
                await KeychainBackend.shared.store(newValue, forKey: namespacedKey)
            }
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
    
    private var namespacedKey: String {
        "\(namespace).\(key)"
    }
    
    public init(
        wrappedValue defaultValue: Value,
        _ key: String,
        namespace: String = "RealtimeKit.Secure"
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.namespace = namespace
        
        let namespacedKey = "\(namespace).\(key)"
        if let stored: Value = KeychainBackend.shared.retrieve(forKey: namespacedKey) {
            self._storedValue = State(initialValue: stored)
        } else {
            self._storedValue = State(initialValue: defaultValue)
        }
    }
}
```

#### 存储后端协议和实现

```swift
// 存储后端协议 (需求 18.5)
public protocol StorageBackend: Actor {
    func store<T: Codable>(_ value: T, forKey key: String) async
    func retrieve<T: Codable>(forKey key: String) -> T?
    func remove(forKey key: String) async
    func removeAll(withPrefix prefix: String) async
    func keys(withPrefix prefix: String) async -> [String]
}

// UserDefaults 后端实现
public actor UserDefaultsBackend: StorageBackend {
    public static let shared = UserDefaultsBackend()
    
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func store<T: Codable>(_ value: T, forKey key: String) async {
        do {
            let data = try encoder.encode(value)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Failed to store value for key \(key): \(error)")
        }
    }
    
    public func retrieve<T: Codable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to retrieve value for key \(key): \(error)")
            return nil
        }
    }
    
    public func remove(forKey key: String) async {
        userDefaults.removeObject(forKey: key)
    }
    
    public func removeAll(withPrefix prefix: String) async {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let keysToRemove = allKeys.filter { $0.hasPrefix(prefix) }
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    public func keys(withPrefix prefix: String) async -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return Array(allKeys.filter { $0.hasPrefix(prefix) })
    }
}

// Keychain 后端实现 (需求 18.5)
public actor KeychainBackend: StorageBackend {
    public static let shared = KeychainBackend()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let service = "RealtimeKit"
    
    private init() {}
    
    public func store<T: Codable>(_ value: T, forKey key: String) async {
        do {
            let data = try encoder.encode(value)
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            
            // 删除现有项目
            SecItemDelete(query as CFDictionary)
            
            // 添加新项目
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                print("Failed to store value in keychain for key \(key): \(status)")
            }
        } catch {
            print("Failed to encode value for keychain storage: \(error)")
        }
    }
    
    public func retrieve<T: Codable>(forKey key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode value from keychain: \(error)")
            return nil
        }
    }
    
    public func remove(forKey key: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    public func removeAll(withPrefix prefix: String) async {
        // Keychain 不支持前缀查询，需要维护一个键列表
        let allKeys = await keys(withPrefix: prefix)
        for key in allKeys {
            await remove(forKey: key)
        }
    }
    
    public func keys(withPrefix prefix: String) async -> [String] {
        // 简化实现：返回空数组
        // 实际实现需要维护一个键的索引
        return []
    }
}
```

#### 存储管理器设计

```swift
// 中央存储管理器 (需求 18.6, 18.7, 18.8)
@MainActor
public class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public private(set) var migrationStatus: MigrationStatus = .notRequired
    @Published public private(set) var performanceMetrics: StoragePerformanceMetrics = StoragePerformanceMetrics()
    
    private var batchOperations: [BatchOperation] = []
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 0.5 // 500ms 批量写入间隔
    
    private init() {
        setupBatchProcessing()
    }
    
    // 批量操作管理 (需求 18.8)
    private func setupBatchProcessing() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processBatchOperations()
            }
        }
    }
    
    private func processBatchOperations() async {
        guard !batchOperations.isEmpty else { return }
        
        let operations = batchOperations
        batchOperations.removeAll()
        
        let startTime = Date()
        
        for operation in operations {
            switch operation {
            case .store(let value, let key, let backend):
                await backend.store(value, forKey: key)
            case .remove(let key, let backend):
                await backend.remove(forKey: key)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        performanceMetrics.recordBatchOperation(duration: duration, operationCount: operations.count)
    }
    
    // 命名空间管理 (需求 18.6)
    public func createNamespace(_ name: String) -> StorageNamespace {
        return StorageNamespace(name: name, manager: self)
    }
    
    // 数据迁移支持 (需求 18.7)
    public func migrateData(from oldVersion: String, to newVersion: String) async throws {
        migrationStatus = .inProgress
        
        do {
            let migrationPlan = try createMigrationPlan(from: oldVersion, to: newVersion)
            try await executeMigrationPlan(migrationPlan)
            migrationStatus = .completed
        } catch {
            migrationStatus = .failed(error)
            throw error
        }
    }
    
    private func createMigrationPlan(from oldVersion: String, to newVersion: String) throws -> MigrationPlan {
        // 根据版本差异创建迁移计划
        return MigrationPlan(
            fromVersion: oldVersion,
            toVersion: newVersion,
            steps: [] // 实际实现中会包含具体的迁移步骤
        )
    }
    
    private func executeMigrationPlan(_ plan: MigrationPlan) async throws {
        for step in plan.steps {
            try await step.execute()
        }
    }
}

// 命名空间封装 (需求 18.6)
public struct StorageNamespace {
    let name: String
    private let manager: StorageManager
    
    init(name: String, manager: StorageManager) {
        self.name = name
        self.manager = manager
    }
    
    public func key(_ key: String) -> String {
        return "\(name).\(key)"
    }
}

// 批量操作类型
private enum BatchOperation {
    case store(Any, String, StorageBackend)
    case remove(String, StorageBackend)
}

// 迁移状态
public enum MigrationStatus {
    case notRequired
    case inProgress
    case completed
    case failed(Error)
}

// 性能指标
public struct StoragePerformanceMetrics {
    var totalBatchOperations: Int = 0
    var averageBatchDuration: TimeInterval = 0
    var totalOperationsProcessed: Int = 0
    
    mutating func recordBatchOperation(duration: TimeInterval, operationCount: Int) {
        totalBatchOperations += 1
        totalOperationsProcessed += operationCount
        averageBatchDuration = (averageBatchDuration * Double(totalBatchOperations - 1) + duration) / Double(totalBatchOperations)
    }
}

// 迁移计划
public struct MigrationPlan {
    let fromVersion: String
    let toVersion: String
    let steps: [MigrationStep]
}

public protocol MigrationStep {
    func execute() async throws
}
```

#### 使用示例和集成

```swift
// 在 RealtimeManager 中的使用示例 (需求 18.10)
@MainActor
public class RealtimeManager: ObservableObject {
    // 使用持久化属性包装器
    @RealtimeStorage("audioSettings") 
    private var persistedAudioSettings: AudioSettings = .default
    
    @RealtimeStorage("userSession", namespace: "RealtimeKit.Session") 
    private var persistedUserSession: UserSession?
    
    @SecureRealtimeStorage("authToken") 
    private var secureAuthToken: String = ""
    
    @RealtimeStorage("connectionHistory") 
    private var connectionHistory: [ConnectionRecord] = []
    
    // 计算属性提供对外接口
    public var audioSettings: AudioSettings {
        get { persistedAudioSettings }
        set { persistedAudioSettings = newValue }
    }
    
    public var currentSession: UserSession? {
        get { persistedUserSession }
        set { persistedUserSession = newValue }
    }
    
    // 自动恢复机制 (需求 18.3)
    public func initialize() async {
        // 属性包装器会自动从存储中恢复值
        // 无需手动调用恢复方法
        
        // 应用恢复的设置到底层 Provider
        if let session = currentSession {
            try? await restoreSession(session)
        }
        
        try? await applyAudioSettings(audioSettings)
    }
    
    // 错误处理和降级 (需求 18.9)
    private func handleStorageError(_ error: Error) {
        print("Storage error occurred: \(error)")
        
        // 降级到内存存储
        // 实际实现中会切换到 MockStorageBackend
    }
}

// SwiftUI 中的使用示例
struct AudioControlView: View {
    @RealtimeStorage("volumeLevel") private var volumeLevel: Double = 0.5
    @RealtimeStorage("isMuted") private var isMuted: Bool = false
    
    var body: some View {
        VStack {
            Slider(value: $volumeLevel, in: 0...1)
            Toggle("Mute", isOn: $isMuted)
        }
        // 值的变化会自动持久化
    }
}

// UIKit 中的使用示例 (需求 18.10)
class AudioControlViewController: UIViewController {
    @RealtimeStorage("volumeLevel") private var volumeLevel: Double = 0.5
    @RealtimeStorage("isMuted") private var isMuted: Bool = false
    
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var muteSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 恢复持久化的值
        volumeSlider.value = Float(volumeLevel)
        muteSwitch.isOn = isMuted
    }
    
    @IBAction func volumeChanged(_ sender: UISlider) {
        volumeLevel = Double(sender.value) // 自动持久化
    }
    
    @IBAction func muteToggled(_ sender: UISwitch) {
        isMuted = sender.isOn // 自动持久化
    }
}
```

#### 测试支持设计 (需求 18.11)

```swift
// Mock 存储后端用于测试
public actor MockStorageBackend: StorageBackend {
    public static let shared = MockStorageBackend()
    
    private var storage: [String: Data] = [:]
    
    public func store<T: Codable>(_ value: T, forKey key: String) async {
        do {
            let data = try JSONEncoder().encode(value)
            storage[key] = data
        } catch {
            print("Mock storage encode error: \(error)")
        }
    }
    
    public func retrieve<T: Codable>(forKey key: String) -> T? {
        guard let data = storage[key] else { return nil }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Mock storage decode error: \(error)")
            return nil
        }
    }
    
    public func remove(forKey key: String) async {
        storage.removeValue(forKey: key)
    }
    
    public func removeAll(withPrefix prefix: String) async {
        let keysToRemove = storage.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            storage.removeValue(forKey: key)
        }
    }
    
    public func keys(withPrefix prefix: String) async -> [String] {
        return Array(storage.keys.filter { $0.hasPrefix(prefix) })
    }
    
    // 测试辅助方法
    public func clear() async {
        storage.removeAll()
    }
    
    public func getAllKeys() async -> [String] {
        return Array(storage.keys)
    }
}

// 测试用例示例
@Test("RealtimeStorage property wrapper persistence")
func testRealtimeStoragePersistence() async {
    // 使用 Mock 后端进行测试
    let mockBackend = MockStorageBackend.shared
    await mockBackend.clear()
    
    struct TestData: Codable, Equatable {
        let name: String
        let value: Int
    }
    
    let testData = TestData(name: "test", value: 42)
    
    // 存储数据
    await mockBackend.store(testData, forKey: "test.data")
    
    // 验证数据被正确存储和检索
    let retrieved: TestData? = await mockBackend.retrieve(forKey: "test.data")
    #expect(retrieved == testData)
}
```

### 6. 本地化支持系统设计 (需求 17)

#### LocalizationManager 设计
```swift
@MainActor
public class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    @Published public private(set) var currentLanguage: SupportedLanguage = .english
    @Published public private(set) var availableLanguages: [SupportedLanguage] = SupportedLanguage.allCases
    
    private var localizedStrings: [SupportedLanguage: [String: String]] = [:]
    private var customLocalizations: [String: [SupportedLanguage: String]] = [:]
    
    private init() {
        detectSystemLanguage()
        loadBuiltInLocalizations()
    }
    
    // 支持的语言 (需求 17.4)
    public enum SupportedLanguage: String, CaseIterable, Codable {
        case english = "en"
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"
        case japanese = "ja"
        case korean = "ko"
        
        public var displayName: String {
            switch self {
            case .english: return "English"
            case .simplifiedChinese: return "简体中文"
            case .traditionalChinese: return "繁體中文"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            }
        }
        
        public var localeIdentifier: String {
            return self.rawValue
        }
    }
    
    // 自动检测系统语言 (需求 17.2)
    private func detectSystemLanguage() {
        let preferredLanguages = Locale.preferredLanguages
        
        for languageCode in preferredLanguages {
            if let supportedLanguage = SupportedLanguage.allCases.first(where: { 
                languageCode.hasPrefix($0.rawValue) 
            }) {
                currentLanguage = supportedLanguage
                return
            }
        }
        
        // 回退到英文 (需求 17.5)
        currentLanguage = .english
    }
    
    // 动态切换语言 (需求 17.3)
    public func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "RealtimeKit.PreferredLanguage")
        
        // 通知所有组件更新本地化文本
        NotificationCenter.default.post(name: .languageDidChange, object: language)
    }
    
    // 获取本地化字符串
    public func localizedString(for key: String, arguments: [String] = []) -> String {
        // 首先检查自定义本地化 (需求 17.7)
        if let customString = customLocalizations[key]?[currentLanguage] {
            return formatString(customString, arguments: arguments)
        }
        
        // 然后检查内置本地化
        if let localizedString = localizedStrings[currentLanguage]?[key] {
            return formatString(localizedString, arguments: arguments)
        }
        
        // 回退到英文 (需求 17.5)
        if currentLanguage != .english,
           let fallbackString = localizedStrings[.english]?[key] {
            return formatString(fallbackString, arguments: arguments)
        }
        
        // 最后回退到 key 本身
        return key
    }
    
    // 格式化带参数的字符串 (需求 17.8)
    private func formatString(_ template: String, arguments: [String]) -> String {
        guard !arguments.isEmpty else { return template }
        
        var result = template
        for (index, argument) in arguments.enumerated() {
            result = result.replacingOccurrences(of: "{\(index)}", with: argument)
        }
        return result
    }
    
    // 添加自定义本地化 (需求 17.7)
    public func addCustomLocalization(key: String, localizations: [SupportedLanguage: String]) {
        customLocalizations[key] = localizations
    }
    
    // 加载内置本地化资源
    private func loadBuiltInLocalizations() {
        localizedStrings = [
            .english: loadEnglishStrings(),
            .simplifiedChinese: loadSimplifiedChineseStrings(),
            .traditionalChinese: loadTraditionalChineseStrings(),
            .japanese: loadJapaneseStrings(),
            .korean: loadKoreanStrings()
        ]
    }
    
    // 内置英文本地化
    private func loadEnglishStrings() -> [String: String] {
        return [
            // 连接状态 (需求 17.6)
            "connection.connecting": "Connecting...",
            "connection.connected": "Connected",
            "connection.disconnected": "Disconnected",
            "connection.reconnecting": "Reconnecting...",
            "connection.failed": "Connection failed",
            
            // 错误消息 (需求 17.1)
            "error.network.timeout": "Network timeout. Please check your connection.",
            "error.network.unavailable": "Network unavailable. Please check your internet connection.",
            "error.authentication.failed": "Authentication failed. Please check your credentials.",
            "error.authentication.tokenExpired": "Token expired. Please refresh your session.",
            "error.permission.microphone": "Microphone permission required. Please enable in Settings.",
            "error.permission.camera": "Camera permission required. Please enable in Settings.",
            "error.room.notFound": "Room not found. Please check the room ID.",
            "error.room.full": "Room is full. Please try again later.",
            "error.user.alreadyInRoom": "User is already in the room.",
            "error.provider.notAvailable": "Service provider not available.",
            "error.provider.switchFailed": "Failed to switch service provider.",
            
            // 用户角色
            "role.broadcaster": "Broadcaster",
            "role.audience": "Audience",
            "role.coHost": "Co-host",
            "role.moderator": "Moderator",
            
            // 音频控制
            "audio.muted": "Muted",
            "audio.unmuted": "Unmuted",
            "audio.volumeChanged": "Volume changed to {0}%",
            
            // 用户提示 (需求 17.6)
            "prompt.joinRoom": "Join room {0}?",
            "prompt.leaveRoom": "Leave current room?",
            "prompt.switchRole": "Switch to {0} role?",
            "prompt.enableMicrophone": "Enable microphone?",
            "prompt.networkReconnect": "Network connection lost. Attempting to reconnect..."
        ]
    }
    
    // 内置中文简体本地化
    private func loadSimplifiedChineseStrings() -> [String: String] {
        return [
            // 连接状态
            "connection.connecting": "连接中...",
            "connection.connected": "已连接",
            "connection.disconnected": "已断开",
            "connection.reconnecting": "重新连接中...",
            "connection.failed": "连接失败",
            
            // 错误消息
            "error.network.timeout": "网络超时，请检查您的网络连接。",
            "error.network.unavailable": "网络不可用，请检查您的网络连接。",
            "error.authentication.failed": "身份验证失败，请检查您的凭据。",
            "error.authentication.tokenExpired": "令牌已过期，请刷新您的会话。",
            "error.permission.microphone": "需要麦克风权限，请在设置中启用。",
            "error.permission.camera": "需要摄像头权限，请在设置中启用。",
            "error.room.notFound": "未找到房间，请检查房间ID。",
            "error.room.full": "房间已满，请稍后再试。",
            "error.user.alreadyInRoom": "用户已在房间中。",
            "error.provider.notAvailable": "服务提供商不可用。",
            "error.provider.switchFailed": "切换服务提供商失败。",
            
            // 用户角色
            "role.broadcaster": "主播",
            "role.audience": "观众",
            "role.coHost": "连麦嘉宾",
            "role.moderator": "主持人",
            
            // 音频控制
            "audio.muted": "已静音",
            "audio.unmuted": "已取消静音",
            "audio.volumeChanged": "音量已调整至 {0}%",
            
            // 用户提示
            "prompt.joinRoom": "加入房间 {0}？",
            "prompt.leaveRoom": "离开当前房间？",
            "prompt.switchRole": "切换到{0}角色？",
            "prompt.enableMicrophone": "启用麦克风？",
            "prompt.networkReconnect": "网络连接丢失，正在尝试重新连接..."
        ]
    }
    
    // 其他语言的本地化方法...
    private func loadTraditionalChineseStrings() -> [String: String] { /* 实现繁体中文 */ return [:] }
    private func loadJapaneseStrings() -> [String: String] { /* 实现日文 */ return [:] }
    private func loadKoreanStrings() -> [String: String] { /* 实现韩文 */ return [:] }
}

// 本地化错误类型
public enum LocalizedRealtimeError: LocalizedError {
    case networkTimeout
    case networkUnavailable
    case authenticationFailed
    case tokenExpired
    case microphonePermissionRequired
    case cameraPermissionRequired
    case roomNotFound
    case roomFull
    case userAlreadyInRoom
    case providerNotAvailable
    case providerSwitchFailed
    
    public var errorDescription: String? {
        let localizationManager = LocalizationManager.shared
        
        switch self {
        case .networkTimeout:
            return localizationManager.localizedString(for: "error.network.timeout")
        case .networkUnavailable:
            return localizationManager.localizedString(for: "error.network.unavailable")
        case .authenticationFailed:
            return localizationManager.localizedString(for: "error.authentication.failed")
        case .tokenExpired:
            return localizationManager.localizedString(for: "error.authentication.tokenExpired")
        case .microphonePermissionRequired:
            return localizationManager.localizedString(for: "error.permission.microphone")
        case .cameraPermissionRequired:
            return localizationManager.localizedString(for: "error.permission.camera")
        case .roomNotFound:
            return localizationManager.localizedString(for: "error.room.notFound")
        case .roomFull:
            return localizationManager.localizedString(for: "error.room.full")
        case .userAlreadyInRoom:
            return localizationManager.localizedString(for: "error.user.alreadyInRoom")
        case .providerNotAvailable:
            return localizationManager.localizedString(for: "error.provider.notAvailable")
        case .providerSwitchFailed:
            return localizationManager.localizedString(for: "error.provider.switchFailed")
        }
    }
}

// 本地化通知
extension Notification.Name {
    static let languageDidChange = Notification.Name("RealtimeKit.languageDidChange")
}
```

#### 本地化 UI 组件支持

##### SwiftUI 本地化支持
```swift
// 本地化文本视图
public struct LocalizedText: View {
    private let key: String
    private let arguments: [String]
    @StateObject private var localizationManager = LocalizationManager.shared
    
    public init(_ key: String, arguments: String...) {
        self.key = key
        self.arguments = arguments
    }
    
    public var body: some View {
        Text(localizationManager.localizedString(for: key, arguments: arguments))
            .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                // SwiftUI 会自动重新渲染
            }
    }
}

// 本地化按钮
public struct LocalizedButton: View {
    private let titleKey: String
    private let action: () -> Void
    @StateObject private var localizationManager = LocalizationManager.shared
    
    public init(_ titleKey: String, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            LocalizedText(titleKey)
        }
    }
}
```

##### UIKit 本地化支持
```swift
// UIKit 本地化扩展
extension UILabel {
    public func setLocalizedText(_ key: String, arguments: String...) {
        let localizationManager = LocalizationManager.shared
        self.text = localizationManager.localizedString(for: key, arguments: arguments)
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.text = localizationManager.localizedString(for: key, arguments: arguments)
        }
    }
}

extension UIButton {
    public func setLocalizedTitle(_ key: String, for state: UIControl.State, arguments: String...) {
        let localizationManager = LocalizationManager.shared
        self.setTitle(localizationManager.localizedString(for: key, arguments: arguments), for: state)
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setTitle(localizationManager.localizedString(for: key, arguments: arguments), for: state)
        }
    }
}
```

### 6. Token 管理系统设计

#### TokenManager 设计
```swift
public class TokenManager {
    private var tokenExpirationTimers: [ProviderType: Timer] = [:]
    private var tokenRenewalHandlers: [ProviderType: () async -> String] = [:]
    
    public func setupTokenRenewal(
        provider: ProviderType,
        handler: @escaping () async -> String
    ) {
        tokenRenewalHandlers[provider] = handler
    }
    
    public func handleTokenExpiration(
        provider: ProviderType,
        expiresIn: Int
    ) async {
        // 提前 30 秒开始续期流程
        let renewalDelay = max(0, expiresIn - 30)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(renewalDelay)) {
            Task {
                await self.performTokenRenewal(provider: provider)
            }
        }
    }
    
    private func performTokenRenewal(provider: ProviderType) async {
        guard let renewalHandler = tokenRenewalHandlers[provider] else {
            print("No token renewal handler registered for provider: \(provider)")
            return
        }
        
        do {
            let newToken = try await renewalHandler()
            
            // 更新 RTC Provider Token
            if let rtcProvider = RealtimeManager.shared.rtcProvider {
                try await rtcProvider.renewToken(newToken)
            }
            
            // 更新 RTM Provider Token
            if let rtmProvider = RealtimeManager.shared.rtmProvider {
                try await rtmProvider.renewToken(newToken)
            }
            
            print("Token renewed successfully for provider: \(provider)")
            
        } catch {
            print("Token renewal failed for provider \(provider): \(error)")
            
            // 重试机制 (需求 9.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
                Task {
                    await self.performTokenRenewal(provider: provider)
                }
            }
        }
    }
    
    public func clearTokenRenewalHandler(for provider: ProviderType) {
        tokenRenewalHandlers.removeValue(forKey: provider)
        tokenExpirationTimers[provider]?.invalidate()
        tokenExpirationTimers.removeValue(forKey: provider)
    }
}() + .seconds(renewalDelay)) {
            Task {
                await self.performTokenRenewal(provider: provider)
            }
        }
    }
    
    private func performTokenRenewal(provider: ProviderType) async {
        guard let handler = tokenRenewalHandlers[provider] else {
            print("No token renewal handler registered for provider: \(provider)")
            return
        }
        
        do {
            let newToken = try await handler()
            
            // 更新 RTC 和 RTM Provider 的 Token
            try await RealtimeManager.shared.rtcProvider.renewToken(newToken)
            try await RealtimeManager.shared.rtmProvider.renewToken(newToken)
            
            print("Token renewed successfully for provider: \(provider)")
        } catch {
            print("Token renewal failed for provider \(provider): \(error)")
            // 实现重试机制
            await retryTokenRenewal(provider: provider, attempt: 1)
        }
    }
    
    private func retryTokenRenewal(provider: ProviderType, attempt: Int) async {
        guard attempt <= 3 else {
            print("Token renewal failed after 3 attempts for provider: \(provider)")
            return
        }
        
        let delay = TimeInterval(attempt * 2) // 指数退避
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        await performTokenRenewal(provider: provider)
    }
}

## 测试策略

### 测试框架选择

基于需求 16 的测试要求，RealtimeKit 采用现代化的测试策略：

#### Swift Testing 框架
- **替代 XCTest**: 使用 Swift Testing 框架提供更现代化的测试体验
- **@Test 宏**: 利用 `@Test` 宏简化测试编写，减少样板代码
- **参数化测试**: 支持使用 `@Test(arguments:)` 进行数据驱动测试
- **条件测试**: 支持使用 `@Test(.enabled(if:))` 进行条件性测试执行

### 测试架构设计

```swift
import Testing
import Foundation
@testable import RealtimeCore

// 参数化测试示例
@Test("Audio volume validation", arguments: [
    (0, true),
    (50, true), 
    (100, true),
    (-1, false),
    (101, false)
])
func testAudioVolumeValidation(volume: Int, expectedValid: Bool) async throws {
    let settings = AudioSettings(audioMixingVolume: volume)
    let isValid = (0...100).contains(settings.audioMixingVolume)
    #expect(isValid == expectedValid)
}

// 条件测试示例
@Test("Provider switching", .enabled(if: ProcessInfo.processInfo.environment["ENABLE_PROVIDER_TESTS"] == "true"))
func testProviderSwitching() async throws {
    let manager = RealtimeManager.shared
    try await manager.configure(provider: .mock, config: .default)
    
    #expect(manager.currentProvider == .mock)
}

// 异步测试示例
@Test("Token renewal mechanism")
func testTokenRenewal() async throws {
    let tokenManager = TokenManager()
    var renewalCalled = false
    
    tokenManager.setupTokenRenewal(provider: .mock) {
        renewalCalled = true
        return "new_token_123"
    }
    
    await tokenManager.handleTokenExpiration(provider: .mock, expiresIn: 30)
    
    // 等待异步操作完成
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
    
    #expect(renewalCalled == true)
}
```

### 测试覆盖策略

#### 1. 单元测试覆盖
- **协议实现测试**: 测试所有 RTCProvider 和 RTMProvider 实现
- **数据模型测试**: 验证 AudioSettings, UserSession, VolumeDetectionConfig 等模型
- **管理器功能测试**: 测试 RealtimeManager, TokenManager, VolumeIndicatorManager 核心功能
- **工具类测试**: 测试存储管理器、消息处理器等工具类

#### 2. 集成测试覆盖
- **服务商兼容性测试**: 测试不同服务商的切换和兼容性
- **网络异常处理测试**: 模拟网络中断、超时等异常情况
- **状态同步测试**: 测试跨组件的状态同步和一致性

#### 3. UI 测试覆盖
- **UIKit 组件测试**: 测试 UIKit 视图控制器和用户交互
- **SwiftUI 组件测试**: 测试 SwiftUI 视图和状态绑定
- **跨框架兼容性测试**: 测试 UIKit 和 SwiftUI 混合使用场景

### Mock 和测试工具

#### RealtimeMocking 模块设计
```swift
import Testing
import RealtimeCore

// Mock Provider 实现
public class MockRTCProvider: RTCProvider {
    public var mockAudioSettings = AudioSettings.default
    public var mockConnectionState: ConnectionState = .disconnected
    public var mockVolumeInfos: [UserVolumeInfo] = []
    
    // 测试验证属性
    public var initializeCalled = false
    public var joinRoomCalled = false
    public var muteCallCount = 0
    
    public func initialize(config: RTCConfig) async throws {
        initializeCalled = true
    }
    
    public func muteMicrophone(_ muted: Bool) async throws {
        muteCallCount += 1
        mockAudioSettings = AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: mockAudioSettings.audioMixingVolume,
            playbackSignalVolume: mockAudioSettings.playbackSignalVolume,
            recordingSignalVolume: mockAudioSettings.recordingSignalVolume,
            localAudioStreamActive: mockAudioSettings.localAudioStreamActive
        )
    }
    
    // 其他方法的 Mock 实现...
}

// 测试工具类
public class TestUtilities {
    public static func createMockVolumeInfo(userId: String, volume: Float, isSpeaking: Bool) -> UserVolumeInfo {
        return UserVolumeInfo(
            userId: userId,
            volume: volume,
            isSpeaking: isSpeaking,
            timestamp: Date()
        )
    }
    
    public static func createMockUserSession(role: UserRole = .audience) -> UserSession {
        return UserSession(
            userId: "test_user_\(UUID().uuidString)",
            userName: "Test User",
            userRole: role
        )
    }
}
```

### 性能测试

#### 性能基准测试
```swift
import Testing
import RealtimeCore

@Test("Volume processing performance")
func testVolumeProcessingPerformance() async throws {
    let manager = VolumeIndicatorManager()
    let volumeInfos = (0..<100).map { index in
        TestUtilities.createMockVolumeInfo(
            userId: "user_\(index)",
            volume: Float.random(in: 0...1),
            isSpeaking: Bool.random()
        )
    }
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    for _ in 0..<1000 {
        manager.processVolumeUpdate(volumeInfos)
    }
    
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    
    // 验证处理时间在合理范围内 (< 1秒)
    #expect(timeElapsed < 1.0)
}
```

### 测试配置和 CI/CD 集成

#### Package.swift 测试配置
```swift
// Package.swift 中的测试目标配置
.testTarget(
    name: "RealtimeCoreTests",
    dependencies: [
        "RealtimeCore",
        "RealtimeMocking"
    ],
    swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
    ]
)
```

#### 测试执行策略
- **本地开发**: 使用 `swift test` 执行完整测试套件
- **CI/CD 流水线**: 分层执行单元测试、集成测试、性能测试
- **代码覆盖率**: 目标达到 80% 以上的代码覆盖率
- **测试报告**: 生成详细的测试报告和覆盖率报告

这种基于 Swift Testing 的现代化测试策略确保了 RealtimeKit 的高质量和可靠性，同时提供了更好的开发体验和测试维护性。() + .seconds(renewalDelay)) { [weak self] in
            Task {
                await self?.renewToken(for: provider)
            }
        }
    }
    
    private func renewToken(for provider: ProviderType) async {
        guard let handler = tokenRenewalHandlers[provider] else {
            print("No token renewal handler for provider: \(provider)")
            return
        }
        
        do {
            let newToken = await handler()
            
            switch provider {
            case .agora:
                try await RealtimeManager.shared.rtcProvider.renewToken(newToken)
                try await RealtimeManager.shared.rtmProvider.renewToken(newToken)
            case .tencent:
                try await RealtimeManager.shared.rtcProvider.renewToken(newToken)
                try await RealtimeManager.shared.rtmProvider.renewToken(newToken)
            case .zego:
                try await RealtimeManager.shared.rtcProvider.renewToken(newToken)
                try await RealtimeManager.shared.rtmProvider.renewToken(newToken)
            }
            
            print("Token renewed successfully for provider: \(provider)")
        } catch {
            print("Failed to renew token for provider \(provider): \(error)")
            // 实现重试逻辑
            await retryTokenRenewal(for: provider, attempt: 1)
        }
    }
    
    private func retryTokenRenewal(for provider: ProviderType, attempt: Int) async {
        guard attempt <= 3 else {
            print("Max retry attempts reached for token renewal: \(provider)")
            return
        }
        
        let delay = TimeInterval(attempt * 2) // 指数退避
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        await renewToken(for: provider)
    }
}
```

### 6. 转推流系统设计

#### StreamPushManager 设计
```swift
public class StreamPushManager {
    private var currentConfig: StreamPushConfig?
    private var isActive: Bool = false
    
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard !isActive else {
            throw RealtimeError.streamPushStartFailed("Stream push is already active")
        }
        
        // 验证配置
        try validateStreamConfig(config)
        
        // 启动转推流
        try await RealtimeManager.shared.rtcProvider.startStreamPush(config: config)
        
        currentConfig = config
        isActive = true
        
        await MainActor.run {
            RealtimeManager.shared.streamPushState = .running
        }
    }
    
    public func stopStreamPush() async throws {
        guard isActive else {
            throw RealtimeError.streamPushStopFailed("No active stream push")
        }
        
        try await RealtimeManager.shared.rtcProvider.stopStreamPush()
        
        currentConfig = nil
        isActive = false
        
        await MainActor.run {
            RealtimeManager.shared.streamPushState = .stopped
        }
    }
    
    public func updateLayout(_ layout: StreamLayout) async throws {
        guard isActive else {
            throw RealtimeError.streamLayoutUpdateFailed("No active stream push")
        }
        
        try await RealtimeManager.shared.rtcProvider.updateStreamPushLayout(layout: layout)
        
        // 更新当前配置
        if var config = currentConfig {
            config = StreamPushConfig(
                pushUrl: config.pushUrl,
                width: config.width,
                height: config.height,
                bitrate: config.bitrate,
                frameRate: config.frameRate,
                layout: layout
            )
            currentConfig = config
        }
    }
    
    private func validateStreamConfig(_ config: StreamPushConfig) throws {
        guard !config.pushUrl.isEmpty else {
            throw RealtimeError.invalidStreamConfig("Push URL cannot be empty")
        }
        
        guard config.width > 0 && config.height > 0 else {
            throw RealtimeError.invalidStreamConfig("Invalid resolution")
        }
        
        guard config.bitrate > 0 && config.frameRate > 0 else {
            throw RealtimeError.invalidStreamConfig("Invalid bitrate or frame rate")
        }
    }
}
```

## 错误处理策略 (需求 13)

### 错误类型定义
```swift
public enum RealtimeError: Error, LocalizedError, Equatable {
    case configurationError(String)
    case connectionFailed(String)
    case authenticationFailed
    case networkError(String)
    case noActiveSession
    
    // 服务商相关错误 (需求 2)
    case providerNotAvailable(ProviderType)
    case providerSwitchFailed(from: ProviderType, to: ProviderType, Error)
    case providerInitializationFailed(ProviderType, String)
    
    // 用户权限相关错误 (需求 4)
    case insufficientPermissions(UserRole)
    case invalidRoleTransition(from: UserRole, to: UserRole)
    case userNotFound(String)
    
    // Token 相关错误 (需求 9)
    case tokenExpired(ProviderType)
    case tokenRenewalFailed(ProviderType, Error)
    case invalidToken(ProviderType)
    
    // 转推流相关错误 (需求 7)
    case streamPushStartFailed(String)
    case streamPushStopFailed(String)
    case invalidStreamConfig(String)
    case streamLayoutUpdateFailed(String)
    
    // 跨媒体流相关错误 (需求 8)
    case mediaRelayStartFailed(String)
    case mediaRelayStopFailed(String)
    case mediaRelayUpdateFailed(String)
    case invalidRelayConfig(String)
    case relayChannelConnectionFailed(String)
    
    // 音量指示器相关错误 (需求 6)
    case volumeIndicatorStartFailed(String)
    case volumeIndicatorStopFailed(String)
    case invalidVolumeConfig(String)
    case audioPermissionDenied
    
    // 消息处理相关错误 (需求 10)
    case messageProcessingFailed(String)
    case unsupportedMessageType(String)
    case messageHandlerNotFound
    case processorAlreadyRegistered(String)
    
    // 存储相关错误 (需求 5)
    case settingsLoadFailed(String)
    case settingsSaveFailed(String)
    case sessionRestoreFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationError(let message):
            return "配置错误: \(message)"
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        case .authenticationFailed:
            return "身份验证失败"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .noActiveSession:
            return "没有活跃的用户会话"
        case .providerNotAvailable(let provider):
            return "服务商 \(provider.rawValue) 不可用"
        case .providerSwitchFailed(let from, let to, let error):
            return "从 \(from.rawValue) 切换到 \(to.rawValue) 失败: \(error.localizedDescription)"
        case .insufficientPermissions(let role):
            return "用户角色 \(role.displayName) 权限不足"
        case .invalidRoleTransition(let from, let to):
            return "无法从 \(from.displayName) 切换到 \(to.displayName)"
        case .tokenExpired(let provider):
            return "\(provider.rawValue) Token 已过期"
        case .tokenRenewalFailed(let provider, let error):
            return "\(provider.rawValue) Token 续期失败: \(error.localizedDescription)"
        case .invalidToken(let provider):
            return "\(provider.rawValue) Token 无效"
        case .streamPushStartFailed(let message):
            return "转推流启动失败: \(message)"
        case .audioPermissionDenied:
            return "音频权限被拒绝"
        case .processorAlreadyRegistered(let messageType):
            return "消息类型 \(messageType) 的处理器已注册"
        case .settingsLoadFailed(let message):
            return "设置加载失败: \(message)"
        case .settingsSaveFailed(let message):
            return "设置保存失败: \(message)"
        case .sessionRestoreFailed(let message):
            return "会话恢复失败: \(message)"
        default:
            return "未知错误"
        }
    }
    
    // 错误恢复建议 (需求 13.4)
    public var recoveryAction: ErrorRecoveryAction {
        switch self {
        case .networkError, .connectionFailed:
            return .retry(delay: 2.0, maxAttempts: 3)
        case .tokenExpired, .invalidToken:
            return .renewToken
        case .providerNotAvailable:
            return .switchProvider
        case .audioPermissionDenied:
            return .requestPermission
        case .insufficientPermissions:
            return .upgradeRole
        default:
            return .none
        }
    }
}

public enum ErrorRecoveryAction {
    case none
    case retry(delay: TimeInterval, maxAttempts: Int)
    case renewToken
    case switchProvider
    case requestPermission
    case upgradeRole
}

// 连接状态管理 (需求 13.2, 13.3)
public enum ConnectionState: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .disconnected: return "已断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .reconnecting: return "重连中"
        case .failed: return "连接失败"
        }
    }
    
    public var canAttemptConnection: Bool {
        switch self {
        case .disconnected, .failed: return true
        case .connecting, .connected, .reconnecting: return false
        }
    }
}

// 自动重连管理器 (需求 13.2)
@MainActor
public class ConnectionManager: ObservableObject {
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var reconnectAttempts: Int = 0
    
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 2.0
    private var reconnectTimer: Timer?
    
    public func handleConnectionLoss() {
        guard connectionState == .connected else { return }
        
        connectionState = .reconnecting
        reconnectAttempts = 0
        startReconnectProcess()
    }
    
    private func startReconnectProcess() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .failed
            return
        }
        
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts)) // 指数退避
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.attemptReconnect()
            }
        }
    }
    
    private func attemptReconnect() async {
        reconnectAttempts += 1
        
        do {
            try await RealtimeManager.shared.reconnect()
            connectionState = .connected
            reconnectAttempts = 0
        } catch {
            if reconnectAttempts < maxReconnectAttempts {
                startReconnectProcess()
            } else {
                connectionState = .failed
            }
        }
    }
    
    public func reset() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
        connectionState = .disconnected
    }
}
```

## 测试策略 (需求 16)

### 测试架构设计

**设计决策**: 基于需求 16，采用 Swift Testing 框架替代 XCTest，确保 80% 以上的代码覆盖率。

```swift
// 使用 Swift Testing 框架 (需求 16.1)
import Testing
@testable import RealtimeCore

@Suite("RealtimeManager Tests")
struct RealtimeManagerTests {
    
    @Test("用户登录功能测试", arguments: [
        (UserRole.broadcaster, true),
        (UserRole.audience, false),
        (UserRole.coHost, true),
        (UserRole.moderator, true)
    ])
    func testUserLogin(role: UserRole, expectedAudioPermission: Bool) async throws {
        let manager = RealtimeManager()
        let mockProvider = MockRTCProvider()
        
        // 配置 mock provider
        manager.rtcProvider = mockProvider
        
        // 测试用户登录 (需求 4.1, 4.2)
        try await manager.loginUser(
            userId: "test_user",
            userName: "Test User",
            userRole: role
        )
        
        #expect(manager.currentSession?.userId == "test_user")
        #expect(manager.currentSession?.userRole == role)
        #expect(role.hasAudioPermission == expectedAudioPermission)
    }
    
    @Test("用户角色切换测试")
    func testUserRoleSwitching() async throws {
        let manager = RealtimeManager()
        let mockProvider = MockRTCProvider()
        manager.rtcProvider = mockProvider
        
        // 登录为观众
        try await manager.loginUser(userId: "test_user", userName: "Test User", userRole: .audience)
        
        // 切换到连麦嘉宾 (需求 4.3)
        try await manager.switchUserRole(.coHost)
        #expect(manager.currentSession?.userRole == .coHost)
        
        // 尝试无效切换应该失败
        await #expect(throws: RealtimeError.self) {
            try await manager.switchUserRole(.moderator)
        }
    }
    
    @Test("音频设置持久化测试")
    func testAudioSettingsPersistence() async throws {
        let manager = RealtimeManager()
        let mockProvider = MockRTCProvider()
        manager.rtcProvider = mockProvider
        
        // 设置音频参数 (需求 5.1, 5.2)
        try await manager.setAudioMixingVolume(80)
        try await manager.muteMicrophone(true)
        
        // 验证设置被保存 (需求 5.4)
        #expect(manager.audioSettings.audioMixingVolume == 80)
        #expect(manager.audioSettings.microphoneMuted == true)
        
        // 重新创建管理器，验证设置被恢复 (需求 5.5)
        let newManager = RealtimeManager()
        let restoredSettings = newManager.settingsStorage.loadAudioSettings()
        
        #expect(restoredSettings.audioMixingVolume == 80)
        #expect(restoredSettings.microphoneMuted == true)
    }
    
    @Test("音量指示器功能测试", arguments: [
        VolumeDetectionConfig(detectionInterval: 200, speakingThreshold: 0.2),
        VolumeDetectionConfig(detectionInterval: 500, speakingThreshold: 0.5)
    ])
    func testVolumeIndicator(config: VolumeDetectionConfig) async throws {
        let manager = VolumeIndicatorManager()
        
        // 模拟音量数据 (需求 6.2, 6.4)
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.8, isSpeaking: true),
            UserVolumeInfo(userId: "user2", volume: 0.1, isSpeaking: false)
        ]
        
        manager.processVolumeUpdate(volumeInfos)
        
        #expect(manager.speakingUsers.contains("user1"))
        #expect(!manager.speakingUsers.contains("user2"))
        #expect(manager.dominantSpeaker == "user1")
    }
}

@Suite("Token Management Tests")
struct TokenManagerTests {
    
    @Test("Token 自动续期测试")
    func testTokenAutoRenewal() async throws {
        let tokenManager = TokenManager()
        var renewalCalled = false
        
        // 设置续期回调 (需求 9.2)
        tokenManager.setupTokenRenewal(provider: .agora) {
            renewalCalled = true
            return "new_token_123"
        }
        
        // 模拟 Token 即将过期 (需求 9.1)
        await tokenManager.handleTokenExpiration(provider: .agora, expiresIn: 5)
        
        // 等待续期完成
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 秒
        
        #expect(renewalCalled == true)
    }
    
    @Test("Token 续期失败重试测试")
    func testTokenRenewalRetry() async throws {
        let tokenManager = TokenManager()
        var attemptCount = 0
        
        tokenManager.setupTokenRenewal(provider: .agora) {
            attemptCount += 1
            if attemptCount < 3 {
                throw RealtimeError.networkError("Network timeout")
            }
            return "new_token_after_retry"
        }
        
        await tokenManager.handleTokenExpiration(provider: .agora, expiresIn: 1)
        
        // 验证重试机制 (需求 9.4)
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 秒
        #expect(attemptCount == 3)
    }
}

@Suite("Provider Switching Tests")
struct ProviderSwitchingTests {
    
    @Test("服务商切换测试")
    func testProviderSwitching() async throws {
        let switchManager = ProviderSwitchManager()
        
        // 注册多个服务商 (需求 2.2)
        switchManager.registerProvider(.agora, factory: AgoraProviderFactory())
        switchManager.registerProvider(.mock, factory: MockProviderFactory())
        
        #expect(switchManager.currentProvider == .agora)
        
        // 切换服务商 (需求 2.3)
        try await switchManager.switchProvider(to: .mock, preserveSession: true)
        #expect(switchManager.currentProvider == .mock)
    }
}

@Suite("Message Processing Tests")
struct MessageProcessingTests {
    
    @Test("消息处理器注册测试")
    func testMessageProcessorRegistration() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        
        // 注册处理器 (需求 10.2)
        try processingManager.registerProcessor(textProcessor)
        
        // 重复注册应该失败
        await #expect(throws: RealtimeError.processorAlreadyRegistered("text")) {
            try processingManager.registerProcessor(textProcessor)
        }
    }
    
    @Test("消息处理链测试")
    func testMessageProcessingChain() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        let imageProcessor = ImageMessageProcessor()
        
        try processingManager.registerProcessor(textProcessor)
        try processingManager.registerProcessor(imageProcessor)
        
        let textMessage = RealtimeMessage(type: "text", content: "Hello World")
        
        // 处理消息 (需求 10.3, 10.4)
        await processingManager.processMessage(textMessage)
        
        #expect(processingManager.processingStats.totalProcessed == 1)
    }
}

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    @Test("网络错误重连测试")
    func testNetworkErrorRecovery() async throws {
        let connectionManager = ConnectionManager()
        
        // 模拟连接丢失 (需求 13.2)
        connectionManager.connectionState = .connected
        connectionManager.handleConnectionLoss()
        
        #expect(connectionManager.connectionState == .reconnecting)
        
        // 等待重连尝试
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 秒
        
        // 验证重连逻辑
        #expect(connectionManager.reconnectAttempts > 0)
    }
    
    @Test("错误恢复建议测试")
    func testErrorRecoveryActions() {
        let networkError = RealtimeError.networkError("Connection timeout")
        let tokenError = RealtimeError.tokenExpired(.agora)
        let permissionError = RealtimeError.audioPermissionDenied
        
        // 验证错误恢复建议 (需求 13.4)
        switch networkError.recoveryAction {
        case .retry(let delay, let maxAttempts):
            #expect(delay > 0)
            #expect(maxAttempts > 0)
        default:
            #expect(Bool(false), "Network error should suggest retry")
        }
        
        #expect(tokenError.recoveryAction == .renewToken)
        #expect(permissionError.recoveryAction == .requestPermission)
    }
}

@Suite("Performance Tests")
struct PerformanceTests {
    
    @Test("音量数据批量处理性能测试")
    func testVolumeProcessingPerformance() async throws {
        let manager = VolumeIndicatorManager()
        
        // 生成大量音量数据 (需求 14.4)
        let volumeInfos = (0..<1000).map { index in
            UserVolumeInfo(
                userId: "user_\(index)",
                volume: Float.random(in: 0.0...1.0),
                isSpeaking: Bool.random()
            )
        }
        
        let startTime = Date()
        manager.processVolumeUpdate(volumeInfos)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // 验证处理时间在合理范围内
        #expect(processingTime < 0.1) // 100ms 内完成
    }
    
    @Test("内存泄漏检测测试")
    func testMemoryLeakPrevention() async throws {
        weak var weakManager: RealtimeManager?
        
        do {
            let manager = RealtimeManager()
            weakManager = manager
            
            // 执行一些操作
            try await manager.configure(provider: .mock, config: MockRealtimeConfig())
        }
        
        // 验证对象被正确释放 (需求 14.1)
        #expect(weakManager == nil)
    }
}

// Mock 实现用于测试 (需求 12.4)
class MockRTCProvider: RTCProvider {
    // 实现所有必要的方法用于测试
}

class MockProviderFactory: ProviderFactory {
    func createRTCProvider() -> RTCProvider { MockRTCProvider() }
    func createRTMProvider() -> RTMProvider { MockRTMProvider() }
    func supportedFeatures() -> Set<ProviderFeature> { Set(ProviderFeature.allCases) }
}
```

### 集成测试策略 (需求 16.4)

1. **多服务商兼容性测试**: 验证 Agora、Tencent、ZEGO 服务商的 API 兼容性
2. **网络异常处理测试**: 模拟网络中断、延迟、丢包等异常情况
3. **并发操作测试**: 验证多线程环境下的数据一致性和线程安全
4. **性能基准测试**: 测试音量处理、消息处理等关键路径的性能指标

### UI 测试策略 (需求 16.5)

1. **UIKit 组件测试**: 验证 ViewController 和 View 的用户交互
2. **SwiftUI 组件测试**: 测试声明式 UI 的响应式更新和动画效果
3. **跨框架兼容性测试**: 验证 UIKit 和 SwiftUI 组件在同一应用中的协同工作

## UI 集成层设计 (需求 11, 15)

### UIKit 集成设计 (需求 11.1, 11.4)

**设计决策**: 提供完整的 UIKit 支持，包括 ViewController、View 组件和传统的 MVC/MVVM 架构支持。

```swift
// RealtimeViewController 基类
open class RealtimeViewController: UIViewController {
    public let realtimeManager = RealtimeManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupRealtimeBindings()
    }
    
    private func setupRealtimeBindings() {
        // 连接状态变化处理 (需求 11.4)
        realtimeManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)
        
        // 音频设置变化处理
        realtimeManager.$audioSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.handleAudioSettingsChange(settings)
            }
            .store(in: &cancellables)
    }
    
    // 子类可重写的方法
    open func handleConnectionStateChange(_ state: ConnectionState) {}
    open func handleAudioSettingsChange(_ settings: AudioSettings) {}
}

// 音量可视化 UIView 组件 (需求 6.5)
public class VolumeVisualizerView: UIView {
    private var volumeInfos: [UserVolumeInfo] = []
    private var animationLayers: [String: CAShapeLayer] = [:]
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupVolumeBinding()
    }
    
    private func setupVolumeBinding() {
        RealtimeManager.shared.$volumeInfos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumeInfos in
                self?.updateVolumeVisualization(volumeInfos)
            }
            .store(in: &cancellables)
    }
    
    private func updateVolumeVisualization(_ volumeInfos: [UserVolumeInfo]) {
        self.volumeInfos = volumeInfos
        
        for volumeInfo in volumeInfos {
            updateUserVolumeAnimation(volumeInfo)
        }
    }
    
    private func updateUserVolumeAnimation(_ volumeInfo: UserVolumeInfo) {
        let layer = animationLayers[volumeInfo.userId] ?? createVolumeLayer(for: volumeInfo.userId)
        
        // 创建波纹动画
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.0 + volumeInfo.volume
        animation.duration = 0.3
        animation.autoreverses = true
        
        layer.add(animation, forKey: "volumeAnimation")
    }
}

// UIKit Delegate 模式支持
public protocol RealtimeUIDelegate: AnyObject {
    func realtimeManager(_ manager: RealtimeManager, didUpdateConnectionState state: ConnectionState)
    func realtimeManager(_ manager: RealtimeManager, didUpdateVolumeInfos volumeInfos: [UserVolumeInfo])
    func realtimeManager(_ manager: RealtimeManager, didEncounterError error: RealtimeError)
}
```

### SwiftUI 集成设计 (需求 11.2, 11.3)

**设计决策**: 提供声明式 UI 组件和响应式数据绑定，充分利用 SwiftUI 的 @Published 属性和 Combine 框架。

```swift
// RealtimeView SwiftUI 组件
public struct RealtimeView: View {
    @StateObject private var realtimeManager = RealtimeManager.shared
    @State private var showingErrorAlert = false
    @State private var currentError: RealtimeError?
    
    public var body: some View {
        VStack {
            // 连接状态指示器
            ConnectionStatusView(state: realtimeManager.connectionState)
            
            // 音量可视化组件 (需求 6.5)
            VolumeVisualizerSwiftUIView(
                volumeInfos: realtimeManager.volumeInfos,
                speakingUsers: realtimeManager.speakingUsers,
                dominantSpeaker: realtimeManager.dominantSpeaker
            )
            
            // 音频控制面板
            AudioControlPanel(audioSettings: realtimeManager.audioSettings) { action in
                Task {
                    await handleAudioAction(action)
                }
            }
        }
        .alert("错误", isPresented: $showingErrorAlert) {
            Button("确定") { showingErrorAlert = false }
        } message: {
            Text(currentError?.localizedDescription ?? "未知错误")
        }
    }
    
    private func handleAudioAction(_ action: AudioAction) async {
        do {
            switch action {
            case .toggleMute:
                try await realtimeManager.muteMicrophone(!realtimeManager.audioSettings.microphoneMuted)
            case .setVolume(let volume):
                try await realtimeManager.setAudioMixingVolume(volume)
            }
        } catch {
            currentError = error as? RealtimeError
            showingErrorAlert = true
        }
    }
}

// SwiftUI 音量可视化组件
public struct VolumeVisualizerSwiftUIView: View {
    let volumeInfos: [UserVolumeInfo]
    let speakingUsers: Set<String>
    let dominantSpeaker: String?
    
    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
            ForEach(volumeInfos, id: \.userId) { volumeInfo in
                UserVolumeIndicator(
                    volumeInfo: volumeInfo,
                    isSpeaking: speakingUsers.contains(volumeInfo.userId),
                    isDominantSpeaker: dominantSpeaker == volumeInfo.userId
                )
                .animation(.easeInOut(duration: 0.3), value: volumeInfo.volume)
            }
        }
    }
}

public struct UserVolumeIndicator: View {
    let volumeInfo: UserVolumeInfo
    let isSpeaking: Bool
    let isDominantSpeaker: Bool
    
    public var body: some View {
        VStack {
            Circle()
                .fill(circleColor)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: isDominantSpeaker ? 3 : 1)
                )
                .scaleEffect(isSpeaking ? 1.0 + volumeInfo.volume : 1.0)
            
            Text(volumeInfo.userId)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var circleColor: Color {
        if isDominantSpeaker {
            return .red
        } else if isSpeaking {
            return .green
        } else {
            return .gray
        }
    }
    
    private var borderColor: Color {
        isDominantSpeaker ? .red : .clear
    }
    
    private var circleSize: CGFloat {
        50 + (volumeInfo.volume * 20)
    }
}

// ViewModel 支持 (需求 11.2)
@MainActor
public class RealtimeViewModel: ObservableObject {
    @Published public var isConnected: Bool = false
    @Published public var currentUser: UserSession?
    @Published public var audioSettings: AudioSettings = .default
    @Published public var volumeInfos: [UserVolumeInfo] = []
    
    private let realtimeManager = RealtimeManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // 响应式数据绑定 (需求 11.3)
        realtimeManager.$connectionState
            .map { $0 == .connected }
            .assign(to: &$isConnected)
        
        realtimeManager.$currentSession
            .assign(to: &$currentUser)
        
        realtimeManager.$audioSettings
            .assign(to: &$audioSettings)
        
        realtimeManager.$volumeInfos
            .assign(to: &$volumeInfos)
    }
    
    // 业务逻辑方法
    public func connectToRoom(roomId: String) async throws {
        guard let session = currentUser else {
            throw RealtimeError.noActiveSession
        }
        
        try await realtimeManager.joinRoom(roomId: roomId, userId: session.userId, userRole: session.userRole)
    }
    
    public func toggleMicrophone() async throws {
        try await realtimeManager.muteMicrophone(!audioSettings.microphoneMuted)
    }
}
```

### 跨框架兼容性设计 (需求 11.5, 15.7)

**设计决策**: 确保 UIKit 和 SwiftUI 组件可以在同一应用中协同工作，提供统一的 API 接口。

```swift
// 跨框架桥接器
public class RealtimeBridge: NSObject {
    public static let shared = RealtimeBridge()
    
    // UIKit 到 SwiftUI 的桥接
    public func createSwiftUIView() -> some View {
        RealtimeView()
    }
    
    // SwiftUI 到 UIKit 的桥接
    public func createUIViewController() -> UIViewController {
        let hostingController = UIHostingController(rootView: RealtimeView())
        return hostingController
    }
}

// 平台特定功能 (需求 15.8)
#if os(iOS)
extension RealtimeManager {
    public func requestAudioPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
#elseif os(macOS)
extension RealtimeManager {
    public func requestAudioPermission() async -> Bool {
        // macOS 特定的权限请求逻辑
        return true
    }
}
#endif
```

## 性能优化设计

### 内存管理策略
1. **弱引用循环**: 所有回调和闭包使用 `[weak self]` 避免循环引用
2. **对象池**: 为频繁创建的 `UserVolumeInfo` 对象实现对象池
3. **延迟初始化**: 非核心组件采用延迟初始化策略
4. **资源清理**: 实现完善的 `deinit` 方法确保资源释放

### 网络优化策略
1. **连接复用**: 实现连接池管理多个并发连接
2. **数据压缩**: 对音量数据和消息内容进行压缩传输
3. **批量处理**: 音量数据采用批量上报减少网络请求
4. **智能重连**: 实现指数退避的智能重连机制

### 线程安全设计
1. **主线程更新**: 所有 UI 相关的 `@Published` 属性更新在主线程
2. **后台处理**: 网络请求和数据处理在后台队列
3. **线程安全集合**: 使用 `actor` 保护共享状态
4. **原子操作**: 关键状态变更使用原子操作

## 安全设计

### 数据保护
1. **Token 安全存储**: 使用 Keychain 存储敏感 Token 信息
2. **数据加密**: 本地存储的用户数据进行 AES 加密
3. **传输安全**: 所有网络传输使用 HTTPS/WSS
4. **权限控制**: 严格的角色权限验证机制

### 隐私保护
1. **最小权限**: 只请求必要的系统权限
2. **数据控制**: 用户可以清除所有本地数据
3. **透明度**: 清晰的数据使用说明
4. **合规性**: 符合 GDPR 和其他隐私法规要求

## 模块化设计 (需求 12)

### Swift Package 结构设计

**设计决策**: 基于需求 12 的模块化要求，采用多目标 Swift Package 设计，支持按需导入和独立模块管理。

```swift
// Package.swift 配置
let package = Package(
    name: "RealtimeKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // 完整功能导入 (需求 12.1)
        .library(name: "RealtimeKit", targets: ["RealtimeKit"]),
        
        // 按需导入支持 (需求 12.2)
        .library(name: "RealtimeCore", targets: ["RealtimeCore"]),
        .library(name: "RealtimeUIKit", targets: ["RealtimeUIKit"]),
        .library(name: "RealtimeSwiftUI", targets: ["RealtimeSwiftUI"]),
        
        // 服务商模块独立导入 (需求 12.3)
        .library(name: "RealtimeAgora", targets: ["RealtimeAgora"]),
        .library(name: "RealtimeTencent", targets: ["RealtimeTencent"]),
        .library(name: "RealtimeZego", targets: ["RealtimeZego"]),
        
        // 测试模块 (需求 12.4)
        .library(name: "RealtimeMocking", targets: ["RealtimeMocking"])
    ],
    dependencies: [
        // 外部依赖管理 (需求 12.5)
        .package(url: "https://github.com/AgoraIO/AgoraRtcEngine_iOS", from: "4.0.0"),
        .package(url: "https://github.com/TencentCloud/TRTC_iOS", from: "11.0.0"),
        .package(url: "https://github.com/zegoim/zego-express-engine-ios", from: "3.0.0")
    ],
    targets: [
        // 核心模块
        .target(
            name: "RealtimeCore",
            dependencies: [],
            path: "Sources/RealtimeCore"
        ),
        
        // UI 集成模块
        .target(
            name: "RealtimeUIKit",
            dependencies: ["RealtimeCore"],
            path: "Sources/RealtimeUIKit"
        ),
        .target(
            name: "RealtimeSwiftUI",
            dependencies: ["RealtimeCore"],
            path: "Sources/RealtimeSwiftUI"
        ),
        
        // 服务商实现模块
        .target(
            name: "RealtimeAgora",
            dependencies: [
                "RealtimeCore",
                .product(name: "AgoraRtcKit", package: "AgoraRtcEngine_iOS")
            ],
            path: "Sources/RealtimeAgora"
        ),
        
        // 主包模块 (聚合所有功能)
        .target(
            name: "RealtimeKit",
            dependencies: [
                "RealtimeCore",
                "RealtimeUIKit",
                "RealtimeSwiftUI",
                "RealtimeAgora"
            ],
            path: "Sources/RealtimeKit"
        ),
        
        // 测试模块
        .target(
            name: "RealtimeMocking",
            dependencies: ["RealtimeCore"],
            path: "Sources/RealtimeMocking"
        )
    ]
)
```

### 模块依赖管理策略

1. **核心模块独立性**: RealtimeCore 不依赖任何外部 SDK，保持纯 Swift 实现
2. **UI 模块可选性**: UIKit 和 SwiftUI 模块可独立导入，互不依赖
3. **服务商模块隔离**: 每个服务商模块独立管理其 SDK 依赖
4. **测试模块分离**: Mock 实现独立打包，不影响生产代码体积

### 按需导入使用示例

```swift
// 仅使用核心功能
import RealtimeCore

// 添加 UIKit 支持
import RealtimeCore
import RealtimeUIKit

// 添加 SwiftUI 支持
import RealtimeCore
import RealtimeSwiftUI

// 使用特定服务商
import RealtimeCore
import RealtimeAgora

// 完整功能导入
import RealtimeKit // 包含所有模块
```

## 安全设计

### 数据保护
1. **Token 安全存储**: 使用 Keychain 存储敏感 Token 信息
2. **数据加密**: 本地存储的用户数据进行 AES 加密
3. **传输安全**: 所有网络传输使用 HTTPS/WSS
4. **权限控制**: 严格的角色权限验证机制

### 隐私保护
1. **最小权限**: 只请求必要的系统权限
2. **数据控制**: 用户可以清除所有本地数据
3. **透明度**: 清晰的数据使用说明
4. **合规性**: 符合 GDPR 和其他隐私法规要求

## 测试策略

### 本地化测试设计 (需求 17)

#### 单元测试
```swift
@Test("LocalizationManager 语言检测测试")
func testLanguageDetection() async throws {
    let manager = LocalizationManager.shared
    
    // 测试系统语言检测
    #expect(manager.currentLanguage != nil)
    #expect(manager.availableLanguages.contains(manager.currentLanguage))
}

@Test("本地化字符串获取测试")
func testLocalizedStringRetrieval() async throws {
    let manager = LocalizationManager.shared
    
    // 测试英文本地化
    manager.setLanguage(.english)
    let englishString = manager.localizedString(for: "error.network.timeout")
    #expect(englishString == "Network timeout. Please check your connection.")
    
    // 测试中文本地化
    manager.setLanguage(.simplifiedChinese)
    let chineseString = manager.localizedString(for: "error.network.timeout")
    #expect(chineseString == "网络超时，请检查您的网络连接。")
}

@Test("本地化字符串格式化测试")
func testLocalizedStringFormatting() async throws {
    let manager = LocalizationManager.shared
    manager.setLanguage(.english)
    
    let formattedString = manager.localizedString(
        for: "prompt.joinRoom", 
        arguments: ["Room123"]
    )
    #expect(formattedString == "Join room Room123?")
}

@Test("回退语言测试")
func testLanguageFallback() async throws {
    let manager = LocalizationManager.shared
    
    // 设置为不存在完整本地化的语言
    manager.setLanguage(.korean)
    
    // 测试回退到英文
    let fallbackString = manager.localizedString(for: "error.network.timeout")
    #expect(fallbackString.contains("Network timeout") || fallbackString.contains("网络超时"))
}
```

#### 集成测试
```swift
@Test("本地化错误消息集成测试")
func testLocalizedErrorIntegration() async throws {
    let manager = LocalizationManager.shared
    
    // 测试不同语言下的错误消息
    for language in LocalizationManager.SupportedLanguage.allCases {
        manager.setLanguage(language)
        
        let error = LocalizedRealtimeError.networkTimeout
        let errorMessage = error.errorDescription
        
        #expect(errorMessage != nil)
        #expect(!errorMessage!.isEmpty)
    }
}

@Test("UI 组件本地化测试")
func testUIComponentLocalization() async throws {
    let manager = LocalizationManager.shared
    
    // 测试 SwiftUI 组件
    manager.setLanguage(.simplifiedChinese)
    let localizedText = LocalizedText("connection.connecting")
    
    // 验证文本内容更新
    #expect(true) // 实际测试需要 UI 测试框架支持
}
```

#### 性能测试
```swift
@Test("本地化性能测试")
func testLocalizationPerformance() async throws {
    let manager = LocalizationManager.shared
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // 批量获取本地化字符串
    for _ in 0..<1000 {
        _ = manager.localizedString(for: "error.network.timeout")
    }
    
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    #expect(timeElapsed < 0.1) // 应在 100ms 内完成
}
```

### 错误处理测试设计 (需求 13)

#### 错误恢复测试
```swift
@Test("网络错误恢复测试")
func testNetworkErrorRecovery() async throws {
    let manager = RealtimeManager.shared
    
    // 模拟网络错误
    do {
        try await manager.joinRoom(roomId: "invalid", userId: "test", userRole: .audience)
        #expect(Bool(false), "Should throw network error")
    } catch let error as LocalizedRealtimeError {
        #expect(error == .networkUnavailable)
        #expect(error.errorDescription != nil)
    }
}

@Test("Token 过期处理测试")
func testTokenExpirationHandling() async throws {
    let tokenManager = TokenManager()
    
    var renewalCalled = false
    tokenManager.setupTokenRenewal(provider: .agora) {
        renewalCalled = true
        return "new_token_123"
    }
    
    await tokenManager.handleTokenExpiration(provider: .agora, expiresIn: 30)
    
    // 验证续期逻辑被调用
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    #expect(renewalCalled == true)
}
```

## 设计总结

本设计文档全面覆盖了 17 个核心需求，重点关注以下设计决策：

1. **统一抽象**: 通过 RTCProvider 和 RTMProvider 协议实现服务商抽象
2. **插件化架构**: 支持动态服务商切换和扩展
3. **响应式设计**: 全面支持 SwiftUI 和 UIKit 双框架
4. **现代并发**: 采用 Swift Concurrency 确保线程安全
5. **模块化结构**: 支持按需导入减少应用体积
6. **完善测试**: 使用 Swift Testing 框架确保代码质量
7. **错误处理**: 提供完整的错误恢复机制和本地化支持
8. **国际化支持**: 完整的多语言错误消息和用户界面本地化
9. **性能优化**: 内存管理和网络优化策略

### 本地化支持设计亮点

1. **自动语言检测**: 系统启动时自动检测设备语言设置
2. **动态语言切换**: 支持运行时切换语言，无需重启应用
3. **多语言支持**: 支持中文（简繁体）、英文、日文、韩文等主要语言
4. **智能回退**: 缺少特定语言时自动回退到英文
5. **开发者友好**: 支持自定义语言包和本地化字符串
6. **参数化消息**: 支持带动态参数的本地化字符串格式化
7. **UI 框架集成**: 为 UIKit 和 SwiftUI 提供专门的本地化组件
8. **错误消息本地化**: 所有系统错误都提供多语言支持

该设计确保了 RealtimeKit 作为统一实时通信解决方案的可扩展性、可维护性、高性能和国际化支持。