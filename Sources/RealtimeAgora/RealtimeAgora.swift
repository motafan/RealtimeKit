import Foundation
import RealtimeCore

/// RealtimeAgora 模块
/// 提供声网 Agora SDK 的集成实现
/// 需求: 2.1, 1.1, 1.2, 17.1

// MARK: - Agora Provider Factory

/// Agora 服务商工厂
/// 需求: 2.1, 1.1, 1.2
public class AgoraProviderFactory: ProviderFactory {
    
    /// Agora 特定配置选项
    public struct AgoraConfiguration: Sendable {
        public let enableCloudProxy: Bool
        public let enableAudioVolumeIndication: Bool
        public let enableLocalizedErrors: Bool
        public let logLevel: AgoraLogLevel
        public let region: AgoraRegion
        
        public init(
            enableCloudProxy: Bool = false,
            enableAudioVolumeIndication: Bool = true,
            enableLocalizedErrors: Bool = true,
            logLevel: AgoraLogLevel = .info,
            region: AgoraRegion = .global
        ) {
            self.enableCloudProxy = enableCloudProxy
            self.enableAudioVolumeIndication = enableAudioVolumeIndication
            self.enableLocalizedErrors = enableLocalizedErrors
            self.logLevel = logLevel
            self.region = region
        }
        
        public static let `default` = AgoraConfiguration()
    }
    
    public let configuration: AgoraConfiguration
    
    public init(configuration: AgoraConfiguration = .default) {
        self.configuration = configuration
    }
    
    public func createRTCProvider() -> RTCProvider {
        return AgoraRTCProvider(configuration: configuration)
    }
    
    public func createRTMProvider() -> RTMProvider {
        return AgoraRTMProvider(configuration: configuration)
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return [
            .audioStreaming,
            .videoStreaming,
            .streamPush,
            .mediaRelay,
            .volumeIndicator,
            .messageProcessing
        ]
    }
}

// MARK: - Agora Configuration Types

/// Agora 日志级别
public enum AgoraLogLevel: String, CaseIterable, Codable, Sendable {
    case none = "none"
    case info = "info"
    case warn = "warn"
    case error = "error"
    case fatal = "fatal"
    
    public var displayName: String {
        switch self {
        case .none: return "无日志"
        case .info: return "信息"
        case .warn: return "警告"
        case .error: return "错误"
        case .fatal: return "致命错误"
        }
    }
}

/// Agora 区域设置
public enum AgoraRegion: String, CaseIterable, Codable, Sendable {
    case global = "global"
    case china = "china"
    case northAmerica = "north_america"
    case europe = "europe"
    case asia = "asia"
    
    public var displayName: String {
        switch self {
        case .global: return "全球"
        case .china: return "中国"
        case .northAmerica: return "北美"
        case .europe: return "欧洲"
        case .asia: return "亚洲"
        }
    }
}

// MARK: - Agora RTC Provider

/// Agora RTC 提供者实现
/// 需求: 2.1, 1.1, 1.2, 17.1
public class AgoraRTCProvider: RTCProvider, @unchecked Sendable {
    
    // MARK: - Properties
    
    private var config: RTCConfig?
    private var currentRoom: RTCRoom?
    private var isMuted: Bool = false
    private var isLocalAudioActive: Bool = true
    private var volumeHandler: (([UserVolumeInfo]) -> Void)?
    private var volumeEventHandler: ((VolumeEvent) -> Void)?
    private var tokenExpirationHandler: ((Int) -> Void)?
    
    // 音量控制
    private var audioMixingVolume: Int = 100
    private var playbackSignalVolume: Int = 100
    private var recordingSignalVolume: Int = 100
    
    // 音量指示器状态
    private var volumeIndicatorEnabled: Bool = false
    private var volumeDetectionConfig: VolumeDetectionConfig?
    private var volumeSimulationTimer: Timer?
    
    // 推流和媒体中继状态
    private var streamPushActive: Bool = false
    private var streamPushConfig: StreamPushConfig?
    private var mediaRelayActive: Bool = false
    private var mediaRelayChannels: Set<String> = []
    
    // Agora 配置
    private let configuration: AgoraProviderFactory.AgoraConfiguration
    
    // 模拟数据（在真实实现中会被 Agora SDK 数据替代）
    private var mockUsers: [String] = ["user1", "user2", "user3", "local_user"]
    private var mockVolumeData: [String: Float] = [:]
    private var previousSpeakingUsers: Set<String> = []
    
    // 连接状态
    private var isInitialized: Bool = false
    private var isConnected: Bool = false
    
    // MARK: - Initialization
    
    internal init(configuration: AgoraProviderFactory.AgoraConfiguration = .default) {
        self.configuration = configuration
        setupMockVolumeData()
    }
    
    // MARK: - RTCProvider Implementation
    
    public func initialize(config: RTCConfig) async throws {
        guard !config.appId.isEmpty else {
            let errorMessage =
                "Invalid Agora App ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        self.config = config
        
        // 模拟 Agora SDK 初始化过程
        try await simulateAgoraInitialization(config: config)
        
        isInitialized = true
        print("Agora RTC Provider 初始化完成 - App ID: \(config.appId)")
        
        // 在真实实现中，这里会调用 Agora SDK 的初始化方法
        // 例如: agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: config.appId, delegate: self)
    }
    
    public func createRoom(roomId: String) async throws -> RTCRoom {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !roomId.isEmpty else {
            let errorMessage =
                "Invalid room ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 模拟 Agora 房间创建延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        let room = AgoraRTCRoom(roomId: roomId)
        currentRoom = room
        
        print("Agora: 创建房间 \(roomId)")
        return room
    }
    
    public func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !roomId.isEmpty && !userId.isEmpty else {
            let errorMessage =
                "Invalid room ID or user ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 如果房间不存在，创建房间
        if currentRoom == nil {
            currentRoom = AgoraRTCRoom(roomId: roomId)
        }
        
        // 模拟 Agora 加入房间过程
        try await simulateAgoraJoinRoom(roomId: roomId, userId: userId, userRole: userRole)
        
        // 添加用户到模拟用户列表
        if !mockUsers.contains(userId) {
            mockUsers.append(userId)
        }
        
        isConnected = true
        print("Agora: 用户 \(userId) 以 \(userRole.displayName) 身份加入房间 \(roomId)")
        
        // 在真实实现中，这里会调用 Agora SDK 的加入频道方法
        // 例如: agoraKit.joinChannel(byToken: token, channelId: roomId, info: nil, uid: UInt(userId))
    }
    
    public func leaveRoom() async throws {
        guard currentRoom != nil else {
            throw RealtimeError.noActiveSession
        }
        
        // 停止音量模拟
        stopVolumeSimulation()
        
        // 模拟 Agora 离开房间过程
        try await simulateAgoraLeaveRoom()
        
        isConnected = false
        currentRoom = nil
        
        print("Agora: 离开房间")
        
        // 在真实实现中，这里会调用 Agora SDK 的离开频道方法
        // 例如: agoraKit.leaveChannel(nil)
    }
    
    public func switchUserRole(_ role: UserRole) async throws {
        guard isConnected else {
            let errorMessage =
                "Not connected to room"
            throw RealtimeError.connectionError(errorMessage)
        }
        
        // 模拟 Agora 角色切换过程
        try await simulateAgoraRoleSwitch(role: role)
        
        print("Agora: 切换用户角色到 \(role.displayName)")
        
        // 根据角色调整音频权限
        if role.hasAudioPermission {
            try await resumeLocalAudioStream()
        } else {
            try await stopLocalAudioStream()
        }
        
        // 在真实实现中，这里会调用 Agora SDK 的角色切换方法
        // 例如: agoraKit.setClientRole(role.agoraClientRole)
    }
    
    // MARK: - Audio Stream Control
    
    public func muteMicrophone(_ muted: Bool) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 模拟 Agora 麦克风控制延迟
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        
        isMuted = muted
        let statusText = muted ? "静音" : "取消静音"
        
        print("Agora: 麦克风\(statusText)")
        
        // 在真实实现中，这里会调用 Agora SDK 的麦克风控制方法
        // 例如: agoraKit.muteLocalAudioStream(muted)
    }
    
    public func isMicrophoneMuted() -> Bool {
        return isMuted
    }
    
    public func stopLocalAudioStream() async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 模拟 Agora 音频流控制延迟
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        
        isLocalAudioActive = false
        print("Agora: 停止本地音频流")
        
        // 在真实实现中，这里会调用 Agora SDK 的音频流控制方法
        // 例如: agoraKit.enableLocalAudio(false)
    }
    
    public func resumeLocalAudioStream() async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 模拟 Agora 音频流控制延迟
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        
        isLocalAudioActive = true
        print("Agora: 恢复本地音频流")
        
        // 在真实实现中，这里会调用 Agora SDK 的音频流控制方法
        // 例如: agoraKit.enableLocalAudio(true)
    }
    
    public func isLocalAudioStreamActive() -> Bool {
        return isLocalAudioActive
    }
    
    // MARK: - Volume Control
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        let validatedVolume = AudioSettings.validateVolume(volume)
        
        // 模拟 Agora 音量设置延迟
        try await Task.sleep(nanoseconds: 30_000_000) // 0.03秒
        
        audioMixingVolume = validatedVolume
        print("Agora: 设置混音音量为 \(audioMixingVolume)")
        
        // 在真实实现中，这里会调用 Agora SDK 的音量控制方法
        // 例如: agoraKit.adjustAudioMixingVolume(Int32(validatedVolume))
    }
    
    public func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        let validatedVolume = AudioSettings.validateVolume(volume)
        
        // 模拟 Agora 音量设置延迟
        try await Task.sleep(nanoseconds: 30_000_000) // 0.03秒
        
        playbackSignalVolume = validatedVolume
        print("Agora: 设置播放音量为 \(playbackSignalVolume)")
        
        // 在真实实现中，这里会调用 Agora SDK 的音量控制方法
        // 例如: agoraKit.adjustPlaybackSignalVolume(Int32(validatedVolume))
    }
    
    public func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        let validatedVolume = AudioSettings.validateVolume(volume)
        
        // 模拟 Agora 音量设置延迟
        try await Task.sleep(nanoseconds: 30_000_000) // 0.03秒
        
        recordingSignalVolume = validatedVolume
        print("Agora: 设置录音音量为 \(recordingSignalVolume)")
        
        // 在真实实现中，这里会调用 Agora SDK 的音量控制方法
        // 例如: agoraKit.adjustRecordingSignalVolume(Int32(validatedVolume))
    }
    
    public func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    // MARK: - Stream Push
    
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard isConnected else {
            let errorMessage =
                "Not connected to room"
            throw RealtimeError.connectionError(errorMessage)
        }
        
        guard !config.url.isEmpty else {
            let errorMessage =
                "Invalid stream URL"
            throw RealtimeError.streamPushFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 推流启动延迟
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        streamPushActive = true
        streamPushConfig = config
        
        print("Agora: 开始推流到 \(config.url)")
        
        // 在真实实现中，这里会调用 Agora SDK 的推流方法
        // 例如: agoraKit.startRtmpStream(withURL: config.url, transcoding: config.transcoding)
    }
    
    public func stopStreamPush() async throws {
        guard streamPushActive else {
            let errorMessage =
                "Stream push not active"
            throw RealtimeError.streamPushFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 推流停止延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        streamPushActive = false
        streamPushConfig = nil
        
        print("Agora: 停止推流")
        
        // 在真实实现中，这里会调用 Agora SDK 的停止推流方法
        // 例如: agoraKit.stopRtmpStream(withURL: streamPushConfig?.url)
    }
    
    public func updateStreamPushLayout(layout: StreamLayout) async throws {
        guard streamPushActive else {
            let errorMessage =
                "Stream push not active"
            throw RealtimeError.streamPushFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 布局更新延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora: 更新推流布局")
        
        // 在真实实现中，这里会调用 Agora SDK 的布局更新方法
        // 例如: agoraKit.setLiveTranscoding(layout.agoraTranscoding)
    }
    
    // MARK: - Media Relay
    
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        guard isConnected else {
            let errorMessage =
                "Not connected to room"
            throw RealtimeError.connectionError(errorMessage)
        }
        
        guard !config.destinationChannels.isEmpty else {
            let errorMessage =
                "No destination channels specified"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 媒体中继启动延迟
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        mediaRelayActive = true
        mediaRelayChannels = Set(config.destinationChannels.map { $0.channelName })
        
        print("Agora: 开始媒体中继到 \(mediaRelayChannels.count) 个频道")
        
        // 在真实实现中，这里会调用 Agora SDK 的媒体中继方法
        // 例如: agoraKit.startChannelMediaRelay(config.agoraChannelMediaRelayConfiguration)
    }
    
    public func stopMediaRelay() async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 媒体中继停止延迟
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        mediaRelayActive = false
        mediaRelayChannels.removeAll()
        
        print("Agora: 停止媒体中继")
        
        // 在真实实现中，这里会调用 Agora SDK 的停止媒体中继方法
        // 例如: agoraKit.stopChannelMediaRelay()
    }
    
    public func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 媒体中继更新延迟
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        mediaRelayChannels = Set(config.destinationChannels.map { $0.channelName })
        
        print("Agora: 更新媒体中继频道到 \(mediaRelayChannels.count) 个频道")
        
        // 在真实实现中，这里会调用 Agora SDK 的更新媒体中继方法
        // 例如: agoraKit.updateChannelMediaRelay(config.agoraChannelMediaRelayConfiguration)
    }
    
    public func pauseMediaRelay(toChannel: String) async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        guard mediaRelayChannels.contains(toChannel) else {
            let errorMessage =
                "Channel not found in relay"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 媒体中继暂停延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora: 暂停到频道 \(toChannel) 的媒体中继")
        
        // 在真实实现中，这里会调用 Agora SDK 的暂停媒体中继方法
        // 例如: agoraKit.pauseAllChannelMediaRelay()
    }
    
    public func resumeMediaRelay(toChannel: String) async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        guard mediaRelayChannels.contains(toChannel) else {
            let errorMessage =
                "Channel not found in relay"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        // 模拟 Agora 媒体中继恢复延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora: 恢复到频道 \(toChannel) 的媒体中继")
        
        // 在真实实现中，这里会调用 Agora SDK 的恢复媒体中继方法
        // 例如: agoraKit.resumeAllChannelMediaRelay()
    }
    
    // MARK: - Volume Indicator
    
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard config.isValid else {
            throw RealtimeError.volumeDetectionFailed
        }
        
        volumeIndicatorEnabled = true
        volumeDetectionConfig = config
        
        print("Agora: 启用音量指示器，间隔 \(config.detectionInterval)ms")
        
        // 启动模拟音量检测（在真实实现中会启用 Agora SDK 的音量指示器）
        startVolumeSimulation()
        
        // 在真实实现中，这里会调用 Agora SDK 的音量指示器方法
        // 例如: agoraKit.enableAudioVolumeIndication(config.detectionInterval, smooth: config.enableSmoothing, report_vad: true)
    }
    
    public func disableVolumeIndicator() async throws {
        guard volumeIndicatorEnabled else {
            throw RealtimeError.volumeDetectionFailed
        }
        
        volumeIndicatorEnabled = false
        volumeDetectionConfig = nil
        stopVolumeSimulation()
        
        print("Agora: 禁用音量指示器")
        
        // 在真实实现中，这里会调用 Agora SDK 的禁用音量指示器方法
        // 例如: agoraKit.enableAudioVolumeIndication(0, smooth: false, report_vad: false)
    }
    
    public func setVolumeIndicatorHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void) {
        volumeHandler = handler
    }
    
    public func setVolumeEventHandler(_ handler: @escaping (VolumeEvent) -> Void) {
        volumeEventHandler = handler
    }
    
    public func getCurrentVolumeInfos() -> [UserVolumeInfo] {
        return generateMockVolumeInfos()
    }
    
    public func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        let volume = Int.random(in: 0...255)
        let threshold = volumeDetectionConfig?.speakingThreshold ?? 0.3
        let isSpeaking = Float(volume) / 255.0 > threshold
        
        return UserVolumeInfo(
            userId: userId,
            volume: volume,
            vad: isSpeaking ? .speaking : .notSpeaking,
            timestamp: Date()
        )
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !newToken.isEmpty else {
            throw RealtimeError.invalidToken
        }
        
        // 模拟 Agora Token 更新延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora: 更新 Token")
        
        // 在真实实现中，这里会调用 Agora SDK 的 Token 更新方法
        // 例如: agoraKit.renewToken(newToken)
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {
        tokenExpirationHandler = handler
        
        // 模拟 Token 过期通知
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒后模拟过期通知
            await MainActor.run {
                handler(300) // 300秒后过期
            }
        }
        
        print("Agora RTC: Token 过期处理器已设置")
        
        // 在真实实现中，这里会设置 Agora SDK 的 Token 过期回调
        // 例如: 在 AgoraRtcEngineDelegate 中实现 rtcEngine(_:tokenPrivilegeWillExpire:)
    }
    
    // MARK: - Private Methods
    
    private func setupMockVolumeData() {
        for userId in mockUsers {
            mockVolumeData[userId] = Float.random(in: 0...1)
        }
    }
    
    private func simulateAgoraInitialization(config: RTCConfig) async throws {
        // 模拟 Agora SDK 初始化过程
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        // 在真实实现中，这里会进行 Agora SDK 的实际初始化
        // 包括设置日志级别、区域等配置
    }
    
    private func simulateAgoraJoinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        // 模拟 Agora 加入房间过程
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 在真实实现中，这里会调用 Agora SDK 的加入频道方法
    }
    
    private func simulateAgoraLeaveRoom() async throws {
        // 模拟 Agora 离开房间过程
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        // 在真实实现中，这里会调用 Agora SDK 的离开频道方法
    }
    
    private func simulateAgoraRoleSwitch(role: UserRole) async throws {
        // 模拟 Agora 角色切换过程
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        // 在真实实现中，这里会调用 Agora SDK 的角色切换方法
    }
    
    private func startVolumeSimulation() {
        guard let config = volumeDetectionConfig else { return }
        
        // 使用 DispatchQueue 而不是 Timer 来避免并发问题
        let interval = TimeInterval(config.detectionInterval) / 1000.0
        
        Task.detached { [weak self] in
            while let self = self, self.volumeIndicatorEnabled {
                let volumeInfos = self.generateMockVolumeInfos()
                self.volumeHandler?(volumeInfos)
                
                // 检测说话状态变化
                let currentSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
                
                // 检测开始说话的用户
                let startedSpeaking = currentSpeakingUsers.subtracting(previousSpeakingUsers)
                for userId in startedSpeaking {
                    if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                        volumeEventHandler?(.userStartedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
                    }
                }
                
                // 检测停止说话的用户
                let stoppedSpeaking = previousSpeakingUsers.subtracting(currentSpeakingUsers)
                for userId in stoppedSpeaking {
                    if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                        volumeEventHandler?(.userStoppedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
                    }
                }
                
                // 检测主讲人变化
                let dominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
                volumeEventHandler?(.dominantSpeakerChanged(userId: dominantSpeaker))
                
                volumeEventHandler?(.volumeUpdate(volumeInfos))
                
                previousSpeakingUsers = currentSpeakingUsers
                
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
        
        print("Agora: 音量模拟已启动")
    }
    
    private func stopVolumeSimulation() {
        volumeSimulationTimer?.invalidate()
        volumeSimulationTimer = nil
        previousSpeakingUsers.removeAll()
    }
    
    private func generateMockVolumeInfos() -> [UserVolumeInfo] {
        return mockUsers.map { userId in
            // 更新模拟音量数据，添加一些随机变化
            let currentVolume = mockVolumeData[userId] ?? 0.0
            let change = Float.random(in: -0.1...0.1)
            let newVolume = max(0.0, min(1.0, currentVolume + change))
            mockVolumeData[userId] = newVolume
            
            let volumeInt = Int(newVolume * 255.0)
            let threshold = volumeDetectionConfig?.speakingThreshold ?? 0.3
            let isSpeaking = newVolume > threshold
            
            return UserVolumeInfo(
                userId: userId,
                volume: volumeInt,
                vad: isSpeaking ? .speaking : .notSpeaking,
                timestamp: Date()
            )
        }
    }
}

// MARK: - Agora RTM Provider

/// Agora RTM 提供者实现
/// 需求: 2.1, 1.1, 1.2, 17.1
public class AgoraRTMProvider: RTMProvider {
    
    // MARK: - Properties
    
    private var config: RTMConfig?
    private var _isLoggedIn: Bool = false
    private var joinedChannels: Set<String> = []
    private var userAttributes: [String: String] = [:]
    private var channelAttributes: [String: [String: String]] = [:]
    private var subscribedUsers: Set<String> = []
    
    // 事件处理器
    private var connectionStateHandler: ((RTMConnectionState, RTMConnectionChangeReason) -> Void)?
    private var peerMessageHandler: ((RTMMessage, String) -> Void)?
    private var channelMessageHandler: ((RTMMessage, RTMChannelMember, String) -> Void)?
    private var peersOnlineStatusHandler: (([String: Bool]) -> Void)?
    private var tokenExpirationHandler: (() -> Void)?
    
    // Agora 配置
    private let configuration: AgoraProviderFactory.AgoraConfiguration
    
    // 模拟数据（在真实实现中会被 Agora SDK 数据替代）
    private var mockChannelMembers: [String: [RTMChannelMember]] = [:]
    private var mockOnlineStatus: [String: Bool] = [:]
    
    // 连接状态
    private var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    internal init(configuration: AgoraProviderFactory.AgoraConfiguration = .default) {
        self.configuration = configuration
        setupMockData()
    }
    
    // MARK: - RTMProvider Implementation
    
    public func initialize(config: RTMConfig) async throws {
        guard !config.appId.isEmpty else {
            let errorMessage =
                "Invalid Agora App ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        self.config = config
        
        // 模拟 Agora RTM SDK 初始化过程
        try await simulateAgoraRTMInitialization(config: config)
        
        isInitialized = true
        print("Agora RTM Provider 初始化完成 - App ID: \(config.appId)")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的初始化方法
        // 例如: agoraRtmKit = AgoraRtmKit(appId: config.appId, delegate: self)
    }
    
    public func login(userId: String, token: String) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !userId.isEmpty else {
            let errorMessage =
                "Invalid user ID"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 登录过程
        try await simulateAgoraRTMLogin(userId: userId, token: token)
        
        _isLoggedIn = true
        print("Agora RTM: 用户 \(userId) 登录")
        
        connectionStateHandler?(.connected, .loginSuccess)
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的登录方法
        // 例如: agoraRtmKit.login(byToken: token, user: userId, completion: completion)
    }
    
    public func logout() async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 登出过程
        try await simulateAgoraRTMLogout()
        
        _isLoggedIn = false
        joinedChannels.removeAll()
        userAttributes.removeAll()
        subscribedUsers.removeAll()
        
        print("Agora RTM: 用户登出")
        connectionStateHandler?(.disconnected, .logout)
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的登出方法
        // 例如: agoraRtmKit.logout(completion: completion)
    }
    
    public func isLoggedIn() -> Bool {
        return _isLoggedIn
    }
    
    // MARK: - Channel Management
    
    public func createChannel(channelId: String) -> RTMChannel {
        return AgoraRTMChannel(channelId: channelId)
    }
    
    public func joinChannel(channelId: String) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        guard !channelId.isEmpty else {
            let errorMessage =
                "Invalid channel ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 模拟 Agora RTM 加入频道过程
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        joinedChannels.insert(channelId)
        
        // 创建模拟频道成员
        if mockChannelMembers[channelId] == nil {
            mockChannelMembers[channelId] = [
                RTMChannelMember(userId: "agora_user1", role: .member),
                RTMChannelMember(userId: "agora_user2", role: .admin)
            ]
        }
        
        print("Agora RTM: 加入频道 \(channelId)")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的加入频道方法
        // 例如: channel.join(completion: completion)
    }
    
    public func leaveChannel(channelId: String) async throws {
        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 模拟 Agora RTM 离开频道过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        joinedChannels.remove(channelId)
        mockChannelMembers.removeValue(forKey: channelId)
        
        print("Agora RTM: 离开频道 \(channelId)")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的离开频道方法
        // 例如: channel.leave(completion: completion)
    }
    
    public func getChannelMembers(channelId: String) async throws -> [RTMChannelMember] {
        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 返回模拟的频道成员
        return mockChannelMembers[channelId] ?? []
    }
    
    public func getChannelMemberCount(channelId: String) async throws -> Int {
        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return mockChannelMembers[channelId]?.count ?? 0
    }
    
    // MARK: - Message Sending
    
    public func sendPeerMessage(_ message: RTMMessage, toPeer peerId: String, options: RTMSendMessageOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        guard !peerId.isEmpty else {
            let errorMessage =
                "Invalid peer ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !message.text.isEmpty else {
            throw RealtimeError.invalidMessageFormat
        }
        
        // 模拟 Agora RTM 发送点对点消息过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora RTM: 发送点对点消息给 \(peerId): \(message.text)")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的发送点对点消息方法
        // 例如: agoraRtmKit.send(message, toPeer: peerId, sendMessageOptions: options, completion: completion)
    }
    
    public func sendChannelMessage(_ message: RTMMessage, toChannel channelId: String, options: RTMSendMessageOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !message.text.isEmpty else {
            throw RealtimeError.invalidMessageFormat
        }
        
        // 模拟 Agora RTM 发送频道消息过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora RTM: 发送频道消息到 \(channelId): \(message.text)")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的发送频道消息方法
        // 例如: channel.send(message, sendMessageOptions: options, completion: completion)
    }
    
    // MARK: - User Attributes
    
    public func setLocalUserAttributes(_ attributes: [String: String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 设置用户属性过程
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15秒
        
        userAttributes = attributes
        print("Agora RTM: 设置本地用户属性 \(attributes.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的设置用户属性方法
        // 例如: agoraRtmKit.setLocalUserAttributes(attributes, completion: completion)
    }
    
    public func addOrUpdateLocalUserAttributes(_ attributes: [String: String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 添加或更新用户属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        for (key, value) in attributes {
            userAttributes[key] = value
        }
        print("Agora RTM: 添加或更新本地用户属性 \(attributes.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的添加或更新用户属性方法
        // 例如: agoraRtmKit.addOrUpdateLocalUserAttributes(attributes, completion: completion)
    }
    
    public func deleteLocalUserAttributesByKeys(_ attributeKeys: [String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 删除用户属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        for key in attributeKeys {
            userAttributes.removeValue(forKey: key)
        }
        print("Agora RTM: 删除本地用户属性 \(attributeKeys.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的删除用户属性方法
        // 例如: agoraRtmKit.deleteLocalUserAttributesByKeys(attributeKeys, completion: completion)
    }
    
    public func clearLocalUserAttributes() async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 清除用户属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        userAttributes.removeAll()
        print("Agora RTM: 清除本地用户属性")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的清除用户属性方法
        // 例如: agoraRtmKit.clearLocalUserAttributes(completion: completion)
    }
    
    public func getUserAttributes(userId: String) async throws -> [String: String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 获取用户属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 返回模拟的用户属性
        return userId == "current_user" ? userAttributes : [:]
    }
    
    public func getUsersAttributes(userIds: [String]) async throws -> [String: [String: String]] {
        return [:]
    }
    
    // MARK: - Channel Attributes
    
    public func setChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 设置频道属性过程
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15秒
        
        channelAttributes[channelId] = attributes
        print("Agora RTM: 设置频道 \(channelId) 属性 \(attributes.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的设置频道属性方法
        // 例如: agoraRtmKit.setChannel(channelId, attributes: attributes, options: options, completion: completion)
    }
    
    public func addOrUpdateChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 添加或更新频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        if channelAttributes[channelId] == nil {
            channelAttributes[channelId] = [:]
        }
        
        for (key, value) in attributes {
            channelAttributes[channelId]![key] = value
        }
        print("Agora RTM: 添加或更新频道 \(channelId) 属性 \(attributes.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的添加或更新频道属性方法
        // 例如: agoraRtmKit.addOrUpdateChannel(channelId, attributes: attributes, options: options, completion: completion)
    }
    
    public func deleteChannelAttributesByKeys(channelId: String, attributeKeys: [String], options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 删除频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        if var attributes = channelAttributes[channelId] {
            for key in attributeKeys {
                attributes.removeValue(forKey: key)
            }
            channelAttributes[channelId] = attributes
        }
        print("Agora RTM: 删除频道 \(channelId) 属性 \(attributeKeys.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的删除频道属性方法
        // 例如: agoraRtmKit.deleteChannel(channelId, attributesByKeys: attributeKeys, options: options, completion: completion)
    }
    
    public func clearChannelAttributes(channelId: String, options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 清除频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        channelAttributes.removeValue(forKey: channelId)
        print("Agora RTM: 清除频道 \(channelId) 属性")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的清除频道属性方法
        // 例如: agoraRtmKit.clearChannel(channelId, options: options, completion: completion)
    }
    
    public func getChannelAttributes(channelId: String) async throws -> [String: String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 获取频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        return channelAttributes[channelId] ?? [:]
    }
    
    public func getChannelAttributesByKeys(channelId: String, attributeKeys: [String]) async throws -> [String: String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 获取频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        guard let attributes = channelAttributes[channelId] else {
            return [:]
        }
        
        var result: [String: String] = [:]
        for key in attributeKeys {
            if let value = attributes[key] {
                result[key] = value
            }
        }
        return result
    }
    
    // MARK: - Online Status
    
    public func queryPeersOnlineStatus(userIds: [String]) async throws -> [String: Bool] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 查询在线状态过程
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        var result: [String: Bool] = [:]
        for userId in userIds {
            result[userId] = mockOnlineStatus[userId] ?? Bool.random()
        }
        
        print("Agora RTM: 查询 \(userIds.count) 个用户在线状态")
        return result
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的查询在线状态方法
        // 例如: agoraRtmKit.queryPeersOnlineStatus(userIds, completion: completion)
    }
    
    public func subscribePeersOnlineStatus(userIds: [String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 订阅在线状态过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        for userId in userIds {
            subscribedUsers.insert(userId)
        }
        
        print("Agora RTM: 订阅 \(userIds.count) 个用户在线状态")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的订阅在线状态方法
        // 例如: agoraRtmKit.subscribePeersOnlineStatus(userIds, completion: completion)
    }
    
    public func unsubscribePeersOnlineStatus(userIds: [String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 取消订阅在线状态过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        for userId in userIds {
            subscribedUsers.remove(userId)
        }
        
        print("Agora RTM: 取消订阅 \(userIds.count) 个用户在线状态")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的取消订阅在线状态方法
        // 例如: agoraRtmKit.unsubscribePeersOnlineStatus(userIds, completion: completion)
    }
    
    public func querySubscribedPeersList() async throws -> [String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 查询已订阅用户列表过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        return Array(subscribedUsers)
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的查询已订阅用户列表方法
        // 例如: agoraRtmKit.getSubscribedPeersList(completion: completion)
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !newToken.isEmpty else {
            throw RealtimeError.invalidToken
        }
        
        // 模拟 Agora RTM Token 更新延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora RTM: 更新 Token")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的 Token 更新方法
        // 例如: agoraRtmKit.renewToken(newToken, completion: completion)
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable () -> Void) {
        tokenExpirationHandler = handler
        
        // 模拟 Token 过期通知
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15秒后模拟过期通知
            handler()
        }
        
        print("Agora RTM: Token 过期处理器已设置")
        
        // 在真实实现中，这里会设置 Agora RTM SDK 的 Token 过期回调
        // 例如: 在 AgoraRtmDelegate 中实现 rtmKit(_:tokenPrivilegeWillExpire:)
    }
    
    // MARK: - Event Handlers
    
    public func onConnectionStateChanged(_ handler: @escaping (RTMConnectionState, RTMConnectionChangeReason) -> Void) {
        connectionStateHandler = handler
    }
    
    public func onPeerMessageReceived(_ handler: @escaping (RTMMessage, String) -> Void) {
        peerMessageHandler = handler
        print("Agora RTM: 点对点消息接收处理器已设置")
        
        // 在真实实现中，这里会设置 Agora RTM SDK 的点对点消息接收回调
        // 例如: 在 AgoraRtmDelegate 中实现 rtmKit(_:messageReceived:fromPeer:)
    }
    
    public func onChannelMessageReceived(_ handler: @escaping (RTMMessage, RTMChannelMember, String) -> Void) {
        channelMessageHandler = handler
        print("Agora RTM: 频道消息接收处理器已设置")
        
        // 在真实实现中，这里会设置 Agora RTM SDK 的频道消息接收回调
        // 例如: 在 AgoraRtmChannelDelegate 中实现 rtmChannel(_:messageReceived:from:)
    }
    
    public func onPeersOnlineStatusChanged(_ handler: @escaping ([String: Bool]) -> Void) {
        peersOnlineStatusHandler = handler
    }
    
    // MARK: - Private RTM Methods
    
    private func setupMockData() {
        // 设置模拟在线状态
        mockOnlineStatus = [
            "agora_user1": true,
            "agora_user2": false,
            "agora_user3": true
        ]
    }
    
    private func simulateAgoraRTMInitialization(config: RTMConfig) async throws {
        // 模拟 Agora RTM SDK 初始化过程
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15秒
        
        // 在真实实现中，这里会进行 Agora RTM SDK 的实际初始化
    }
    
    private func simulateAgoraRTMLogin(userId: String, token: String) async throws {
        // 模拟 Agora RTM 登录过程
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的登录方法
    }
    
    private func simulateAgoraRTMLogout() async throws {
        // 模拟 Agora RTM 登出过程
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的登出方法
    }
}

// MARK: - Agora RTC Room

/// Agora RTC Room 实现
/// 需求: 2.1, 1.1, 1.2
internal class AgoraRTCRoom: RTCRoom {
    public let roomId: String
    private var members: Set<String> = []
    private var createdAt: Date = Date()
    private var roomState: AgoraRoomState = .idle
    
    init(roomId: String) {
        self.roomId = roomId
    }
    
    /// 添加成员到房间
    internal func addMember(_ userId: String) {
        members.insert(userId)
        roomState = .active
    }
    
    /// 从房间移除成员
    internal func removeMember(_ userId: String) {
        members.remove(userId)
        if members.isEmpty {
            roomState = .idle
        }
    }
    
    /// 获取房间成员数量
    internal var memberCount: Int {
        return members.count
    }
    
    /// 检查用户是否在房间中
    internal func hasMember(_ userId: String) -> Bool {
        return members.contains(userId)
    }
    
    /// 获取房间状态
    internal var state: AgoraRoomState {
        return roomState
    }
}

/// Agora 房间状态
internal enum AgoraRoomState {
    case idle
    case active
    case destroyed
}

// MARK: - Agora RTM Channel

/// Agora RTM Channel 实现
/// 需求: 2.1, 1.1, 1.2
internal class AgoraRTMChannel: RTMChannel {
    public let channelId: String
    private var members: Set<String> = []
    private var messages: [RTMMessage] = []
    private var attributes: [String: String] = [:]
    private var createdAt: Date = Date()
    private var channelState: AgoraChannelState = .idle
    
    init(channelId: String) {
        self.channelId = channelId
    }
    
    /// 添加成员到频道
    internal func addMember(_ userId: String) {
        members.insert(userId)
        channelState = .active
    }
    
    /// 从频道移除成员
    internal func removeMember(_ userId: String) {
        members.remove(userId)
        if members.isEmpty {
            channelState = .idle
        }
    }
    
    /// 获取频道成员数量
    internal var memberCount: Int {
        return members.count
    }
    
    /// 检查用户是否在频道中
    internal func hasMember(_ userId: String) -> Bool {
        return members.contains(userId)
    }
    
    /// 添加消息到频道
    internal func addMessage(_ message: RTMMessage) {
        messages.append(message)
    }
    
    /// 获取频道消息数量
    internal var messageCount: Int {
        return messages.count
    }
    
    /// 设置频道属性
    internal func setAttribute(_ key: String, value: String) {
        attributes[key] = value
    }
    
    /// 获取频道属性
    internal func getAttribute(_ key: String) -> String? {
        return attributes[key]
    }
    
    /// 获取所有频道属性
    internal var allAttributes: [String: String] {
        return attributes
    }
    
    /// 获取频道状态
    internal var state: AgoraChannelState {
        return channelState
    }
}

/// Agora 频道状态
internal enum AgoraChannelState {
    case idle
    case active
    case destroyed
}
