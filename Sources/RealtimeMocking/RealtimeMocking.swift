import Foundation
import RealtimeCore

/// RealtimeMocking 模块
/// 提供用于测试的模拟实现
/// 需求: 12.4, 16.3, 17.1

// MARK: - Mock Provider Factory

/// Mock 服务商工厂
/// 需求: 12.4, 16.3
public class MockProviderFactory: ProviderFactory {
    
    /// 模拟配置选项
    public struct MockConfiguration: Sendable {
        public let simulateNetworkDelay: Bool
        public let simulateErrors: Bool
        public let errorRate: Double // 0.0 - 1.0
        public let networkDelayRange: ClosedRange<UInt64> // 纳秒
        public let enableLocalizedErrors: Bool
        
        public init(
            simulateNetworkDelay: Bool = true,
            simulateErrors: Bool = false,
            errorRate: Double = 0.1,
            networkDelayRange: ClosedRange<UInt64> = 100_000_000...500_000_000,
            enableLocalizedErrors: Bool = true
        ) {
            self.simulateNetworkDelay = simulateNetworkDelay
            self.simulateErrors = simulateErrors
            self.errorRate = max(0.0, min(1.0, errorRate))
            self.networkDelayRange = networkDelayRange
            self.enableLocalizedErrors = enableLocalizedErrors
        }
        
        public static let `default` = MockConfiguration()
        public static let testing = MockConfiguration(simulateNetworkDelay: false, simulateErrors: false)
        public static let errorTesting = MockConfiguration(simulateErrors: true, errorRate: 0.5)
    }
    
    public let configuration: MockConfiguration
    
    public init(configuration: MockConfiguration = .default) {
        self.configuration = configuration
    }
    
    public func createRTCProvider() -> RTCProvider {
        return MockRTCProvider(configuration: configuration)
    }
    
    public func createRTMProvider() -> RTMProvider {
        return MockRTMProvider(configuration: configuration)
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return Set(ProviderFeature.allCases) // Mock 支持所有功能
    }
}

// MARK: - Mock RTC Provider

/// Mock RTC 提供者实现，用于测试
/// 需求: 12.4, 16.3, 17.1
public class MockRTCProvider: RTCProvider, @unchecked Sendable {
    
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
    private var volumeSimulationTask: Task<Void, Never>?

    
    // 推流和媒体中继状态
    private var streamPushActive: Bool = false
    private var mediaRelayActive: Bool = false
    private var mediaRelayChannels: Set<String> = []
    
    // 模拟配置
    private let configuration: MockProviderFactory.MockConfiguration
    
    // 模拟数据
    private var mockUsers: [String] = ["user1", "user2", "user3", "local_user"]
    private var mockVolumeData: [String: Float] = [:]
    private var previousSpeakingUsers: Set<String> = []
    private let volumeDataQueue = DispatchQueue(label: "com.realtimekit.mock.volumeData", attributes: .concurrent)
    
    // MARK: - Initialization
    
    internal init(configuration: MockProviderFactory.MockConfiguration = .default) {
        self.configuration = configuration
        setupMockVolumeData()
    }
    
    // MARK: - RTCProvider Implementation
    
    public func initialize(config: RTCConfig) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Mock configuration error"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        self.config = config
        print("Mock RTC Provider 初始化完成 - App ID: \(config.appId)")
    }
    
    public func createRoom(roomId: String) async throws -> RTCRoom {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard config != nil else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Room creation failed"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        let room = MockingRTCRoom(roomId: roomId)
        currentRoom = room
        print("Mock: 创建房间 \(roomId)")
        return room
    }
    
    public func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard config != nil else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to join room"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        if currentRoom == nil {
            currentRoom = MockingRTCRoom(roomId: roomId)
        }
        
        // 添加用户到模拟用户列表
        if !mockUsers.contains(userId) {
            mockUsers.append(userId)
        }
        
        print("Mock: 用户 \(userId) 以 \(userRole.displayName) 身份加入房间 \(roomId)")
    }
    
    public func leaveRoom() async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard currentRoom != nil else {
            throw RealtimeError.noActiveSession
        }
        
        // 停止音量模拟
        stopVolumeSimulation()
        
        print("Mock: 离开房间")
        currentRoom = nil
    }
    
    public func switchUserRole(_ role: UserRole) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Role switch failed"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        print("Mock: 切换用户角色到 \(role.displayName)")
    }
    
    // MARK: - Audio Stream Control
    
    public func muteMicrophone(_ muted: Bool) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to mute microphone"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        isMuted = muted
        let statusText = muted ? "静音" : "取消静音"
        print("Mock: 麦克风\(statusText)")
    }
    
    public func isMicrophoneMuted() -> Bool {
        return isMuted
    }
    
    public func stopLocalAudioStream() async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to stop audio stream"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        isLocalAudioActive = false
        print("Mock: 停止本地音频流")
    }
    
    public func resumeLocalAudioStream() async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to resume audio stream"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        isLocalAudioActive = true
        print("Mock: 恢复本地音频流")
    }
    
    public func isLocalAudioStreamActive() -> Bool {
        return isLocalAudioActive
    }
    
    // MARK: - Volume Control
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to set volume"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        audioMixingVolume = AudioSettings.validateVolume(volume)
        print("Mock: 设置混音音量为 \(audioMixingVolume)")
    }
    
    public func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to set volume"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        playbackSignalVolume = AudioSettings.validateVolume(volume)
        print("Mock: 设置播放音量为 \(playbackSignalVolume)")
    }
    
    public func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to set volume"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        recordingSignalVolume = AudioSettings.validateVolume(volume)
        print("Mock: 设置录音音量为 \(recordingSignalVolume)")
    }
    
    public func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    // MARK: - Stream Push
    
    public func startStreamPush(config: StreamPushConfig) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to start stream push"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        streamPushActive = true
        print("Mock: 开始推流到 \(config.url)")
    }
    
    public func stopStreamPush() async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to stop stream push"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        streamPushActive = false
        print("Mock: 停止推流")
    }
    
    public func updateStreamPushLayout(layout: StreamLayout) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to update stream layout"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        print("Mock: 更新推流布局")
    }
    
    // MARK: - Media Relay
    
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to start media relay"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        mediaRelayActive = true
        mediaRelayChannels = Set(config.destinationChannels.map { $0.channelName })
        print("Mock: 开始媒体中继到 \(mediaRelayChannels.count) 个频道")
    }
    
    public func stopMediaRelay() async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to stop media relay"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        mediaRelayActive = false
        mediaRelayChannels.removeAll()
        print("Mock: 停止媒体中继")
    }
    
    public func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to update media relay channels"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        mediaRelayChannels = Set(config.destinationChannels.map { $0.channelName })
        print("Mock: 更新媒体中继频道到 \(mediaRelayChannels.count) 个频道")
    }
    
    public func pauseMediaRelay(toChannel: String) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to pause media relay"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        print("Mock: 暂停到频道 \(toChannel) 的媒体中继")
    }
    
    public func resumeMediaRelay(toChannel: String) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to resume media relay"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        print("Mock: 恢复到频道 \(toChannel) 的媒体中继")
    }
    
    // MARK: - Volume Indicator
    
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to enable volume indicator"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        volumeIndicatorEnabled = true
        volumeDetectionConfig = config
        print("Mock: 启用音量指示器，间隔 \(config.detectionInterval)ms")
        
        // 启动模拟音量数据
        startMockVolumeSimulation()
    }
    
    public func disableVolumeIndicator() async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to disable volume indicator"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        volumeIndicatorEnabled = false
        volumeDetectionConfig = nil
        stopVolumeSimulation()
        print("Mock: 禁用音量指示器")
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
        let isSpeaking = volume > 50
        return UserVolumeInfo(
            userId: userId,
            volume: volume,
            vad: isSpeaking ? .speaking : .notSpeaking,
            timestamp: Date()
        )
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Token renewal failed"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        print("Mock: 更新 Token")
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {
        tokenExpirationHandler = handler
        
        // 模拟 Token 过期通知
        if configuration.simulateErrors {
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒后模拟过期通知
                handler(300) // 300秒后过期
            }
        }
        
        print("Mock RTC: Token 过期处理器已设置")
    }
    
    // MARK: - Private Methods
    
    private func simulateDelay() async throws {
        let delay = UInt64.random(in: configuration.networkDelayRange)
        try await Task.sleep(nanoseconds: delay)
    }
    
    private func shouldSimulateError() -> Bool {
        return Double.random(in: 0...1) < configuration.errorRate
    }
    
    private func setupMockVolumeData() {
        volumeDataQueue.sync(flags: .barrier) {
            for userId in mockUsers {
                mockVolumeData[userId] = Float.random(in: 0...1)
            }
        }
    }
    
    private func startMockVolumeSimulation() {
        guard let config = volumeDetectionConfig else { return }
        
        // 停止之前的任务
        stopVolumeSimulation()
        
        let interval = TimeInterval(config.detectionInterval) / 1000.0
        
        volumeSimulationTask = Task { [weak self] in
            while let self = self, self.volumeIndicatorEnabled, !Task.isCancelled {
                let volumeInfos = self.generateMockVolumeInfos()
                
                // 安全地调用处理器
                await MainActor.run {
                    self.volumeHandler?(volumeInfos)
                }

                // 检测说话状态变化
                let currentSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
                
                // 检测开始说话的用户
                let startedSpeaking = currentSpeakingUsers.subtracting(self.previousSpeakingUsers)
                for userId in startedSpeaking {
                    if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                        await MainActor.run {
                            self.volumeEventHandler?(.userStartedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
                        }
                    }
                }
                
                // 检测停止说话的用户
                let stoppedSpeaking = self.previousSpeakingUsers.subtracting(currentSpeakingUsers)
                for userId in stoppedSpeaking {
                    if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                        await MainActor.run {
                            self.volumeEventHandler?(.userStoppedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
                        }
                    }
                }
                
                // 检测主讲人变化
                let dominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
                await MainActor.run {
                    self.volumeEventHandler?(.dominantSpeakerChanged(userId: dominantSpeaker))
                    self.volumeEventHandler?(.volumeUpdate(volumeInfos))
                }

                self.previousSpeakingUsers = currentSpeakingUsers

                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    private func stopVolumeSimulation() {
        volumeSimulationTask?.cancel()
        volumeSimulationTask = nil
        previousSpeakingUsers.removeAll()
    }
    
    private func generateMockVolumeInfos() -> [UserVolumeInfo] {
        return volumeDataQueue.sync {
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
}

// MARK: - Mock RTM Provider

/// Mock RTM 提供者实现，用于测试
/// 需求: 12.4, 16.3, 17.1
public class MockRTMProvider: RTMProvider {
    
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
    
    // 模拟配置
    private let configuration: MockProviderFactory.MockConfiguration
    
    // 模拟数据
    private var mockChannelMembers: [String: [RTMChannelMember]] = [:]
    private var mockOnlineStatus: [String: Bool] = [:]
    
    // MARK: - Initialization
    
    internal init(configuration: MockProviderFactory.MockConfiguration = .default) {
        self.configuration = configuration
        setupMockData()
    }
    
    // MARK: - RTMProvider Implementation
    
    public func initialize(config: RTMConfig) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "RTM configuration failed"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        self.config = config
        print("Mock RTM Provider 初始化完成 - App ID: \(config.appId)")
    }
    
    public func login(userId: String, token: String) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard config != nil else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "RTM login failed"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        print("Mock RTM: 用户 \(userId) 登录")
        _isLoggedIn = true
        
        connectionStateHandler?(.connected, .loginSuccess)
    }
    
    public func logout() async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "RTM logout failed"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        print("Mock RTM: 用户登出")
        _isLoggedIn = false
        joinedChannels.removeAll()
        userAttributes.removeAll()
        subscribedUsers.removeAll()
        
        connectionStateHandler?(.disconnected, .logout)
    }
    
    public func isLoggedIn() -> Bool {
        return _isLoggedIn
    }
    
    // MARK: - Channel Management
    
    public func createChannel(channelId: String) -> RTMChannel {
        // 初始化频道成员列表
        if mockChannelMembers[channelId] == nil {
            mockChannelMembers[channelId] = [
                RTMChannelMember(userId: "mock_user1", nickname: "Mock User 1"),
                RTMChannelMember(userId: "mock_user2", nickname: "Mock User 2")
            ]
        }
        return MockingRTMChannel(channelId: channelId)
    }
    
    public func joinChannel(channelId: String) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to join channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        joinedChannels.insert(channelId)
        print("Mock RTM: 加入频道 \(channelId)")
    }
    
    public func leaveChannel(channelId: String) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to leave channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        joinedChannels.remove(channelId)
        print("Mock RTM: 离开频道 \(channelId)")
    }
    
    public func getChannelMembers(channelId: String) async throws -> [RTMChannelMember] {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to get channel members"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return mockChannelMembers[channelId] ?? []
    }
    
    public func getChannelMemberCount(channelId: String) async throws -> Int {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to get member count"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return mockChannelMembers[channelId]?.count ?? Int.random(in: 1...10)
    }
    
    // MARK: - Message Sending
    
    public func sendPeerMessage(_ message: RTMMessage, toPeer peerId: String, options: RTMSendMessageOptions?) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to send message"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        print("Mock RTM: 发送点对点消息给 \(peerId): \(message.text)")
        
        // 模拟消息回执
        simulateMessageDelivery(message)
    }
    
    public func sendChannelMessage(_ message: RTMMessage, toChannel channelId: String, options: RTMSendMessageOptions?) async throws {
        if configuration.simulateNetworkDelay {
            try await simulateDelay()
        }
        
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
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to send message"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        print("Mock RTM: 发送频道消息到 \(channelId): \(message.text)")
        
        // 模拟消息回执
        simulateMessageDelivery(message)
    }
    
    // MARK: - User Attributes
    
    public func setLocalUserAttributes(_ attributes: [String: String]) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to set user attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        userAttributes = attributes
        print("Mock RTM: 设置本地用户属性")
    }
    
    public func addOrUpdateLocalUserAttributes(_ attributes: [String: String]) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to update user attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        userAttributes.merge(attributes) { _, new in new }
        print("Mock RTM: 添加或更新本地用户属性")
    }
    
    public func deleteLocalUserAttributesByKeys(_ attributeKeys: [String]) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to delete user attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        for key in attributeKeys {
            userAttributes.removeValue(forKey: key)
        }
        print("Mock RTM: 删除本地用户属性")
    }
    
    public func clearLocalUserAttributes() async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to clear user attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        userAttributes.removeAll()
        print("Mock RTM: 清除本地用户属性")
    }
    
    public func getUserAttributes(userId: String) async throws -> [String: String] {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to get user attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return ["nickname": "Mock User \(userId)", "status": "online"]
    }
    
    public func getUsersAttributes(userIds: [String]) async throws -> [String: [String: String]] {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to get user attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return userIds.reduce(into: [:]) { result, userId in
            result[userId] = ["nickname": "Mock User \(userId)", "status": "online"]
        }
    }
    
    // MARK: - Channel Attributes
    
    public func setChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to set channel attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        channelAttributes[channelId] = attributes
        print("Mock RTM: 设置频道 \(channelId) 属性")
    }
    
    public func addOrUpdateChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to update channel attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        if channelAttributes[channelId] == nil {
            channelAttributes[channelId] = [:]
        }
        channelAttributes[channelId]?.merge(attributes) { _, new in new }
        print("Mock RTM: 添加或更新频道 \(channelId) 属性")
    }
    
    public func deleteChannelAttributesByKeys(channelId: String, attributeKeys: [String], options: RTMChannelAttributeOptions?) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to delete channel attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        for key in attributeKeys {
            channelAttributes[channelId]?.removeValue(forKey: key)
        }
        print("Mock RTM: 删除频道 \(channelId) 属性")
    }
    
    public func clearChannelAttributes(channelId: String, options: RTMChannelAttributeOptions?) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to clear channel attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        channelAttributes[channelId] = [:]
        print("Mock RTM: 清除频道 \(channelId) 属性")
    }
    
    public func getChannelAttributes(channelId: String) async throws -> [String: String] {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to get channel attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return channelAttributes[channelId] ?? ["topic": "Mock Channel Topic", "description": "Mock Channel Description"]
    }
    
    public func getChannelAttributesByKeys(channelId: String, attributeKeys: [String]) async throws -> [String: String] {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to get channel attributes"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        let allAttributes = channelAttributes[channelId] ?? [:]
        return attributeKeys.reduce(into: [:]) { result, key in
            result[key] = allAttributes[key] ?? "Mock Value for \(key)"
        }
    }
    
    // MARK: - Online Status
    
    public func queryPeersOnlineStatus(userIds: [String]) async throws -> [String: Bool] {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to query online status"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return userIds.reduce(into: [:]) { result, userId in
            result[userId] = mockOnlineStatus[userId] ?? Bool.random()
        }
    }
    
    public func subscribePeersOnlineStatus(userIds: [String]) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to subscribe online status"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        subscribedUsers.formUnion(userIds)
        print("Mock RTM: 订阅用户在线状态")
    }
    
    public func unsubscribePeersOnlineStatus(userIds: [String]) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to unsubscribe online status"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        subscribedUsers.subtract(userIds)
        print("Mock RTM: 取消订阅用户在线状态")
    }
    
    public func querySubscribedPeersList() async throws -> [String] {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Failed to query subscribed peers"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        return Array(subscribedUsers)
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        if configuration.simulateNetworkDelay { try await simulateDelay() }
        
        if configuration.simulateErrors && shouldSimulateError() {
            let errorMessage =
                "Token renewal failed"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        print("Mock RTM: 更新 Token")
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable () -> Void) {
        tokenExpirationHandler = handler
        
        // 模拟 Token 过期通知
        if configuration.simulateErrors {
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒后模拟过期通知
                handler()
            }
        }
        
        print("Mock RTM: Token 过期处理器已设置")
    }
    
    // MARK: - Event Handlers
    
    public func onConnectionStateChanged(_ handler: @escaping @Sendable (RTMConnectionState, RTMConnectionChangeReason) -> Void) {
        connectionStateHandler = handler
    }
    
    public func onPeerMessageReceived(_ handler: @escaping @Sendable (RTMMessage, String) -> Void) {
        peerMessageHandler = handler
        
        // 模拟接收点对点消息
        if configuration.simulateErrors {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒后模拟收到消息
                let mockMessage = RTMMessage(
                    text: "Mock peer message",
                    senderId: "mock_sender"
                )
                handler(mockMessage, "mock_sender")
            }
        }
        
        print("Mock RTM: 点对点消息接收处理器已设置")
    }
    
    public func onChannelMessageReceived(_ handler: @escaping @Sendable (RTMMessage, RTMChannelMember, String) -> Void) {
        channelMessageHandler = handler
        
        // 模拟接收频道消息
        if configuration.simulateErrors {
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒后模拟收到消息
                let mockMessage = RTMMessage(
                    text: "Mock channel message",
                    senderId: "mock_sender"
                )
                let mockMember = RTMChannelMember(userId: "mock_sender", nickname: "Mock Sender")
                handler(mockMessage, mockMember, "mock_channel")
            }
        }
        
        print("Mock RTM: 频道消息接收处理器已设置")
    }
    
    public func onPeersOnlineStatusChanged(_ handler: @escaping @Sendable ([String: Bool]) -> Void) {
        peersOnlineStatusHandler = handler
        
        // 模拟用户在线状态变化
        if configuration.simulateErrors {
            Task { [subscribedUsers] in
                try? await Task.sleep(nanoseconds: 4_000_000_000) // 4秒后模拟状态变化
                let statusChanges = Array(subscribedUsers).reduce(into: [:]) { result, userId in
                    result[userId] = Bool.random()
                }
                handler(statusChanges)
            }
        }
        
        print("Mock RTM: 在线状态变化处理器已设置")
    }
    
    // MARK: - Private Methods
    
    private func simulateDelay() async throws {
        let delay = UInt64.random(in: configuration.networkDelayRange)
        try await Task.sleep(nanoseconds: delay)
    }
    
    private func shouldSimulateError() -> Bool {
        return Double.random(in: 0...1) < configuration.errorRate
    }
    
    private func setupMockData() {
        // 设置模拟在线状态
        mockOnlineStatus = [
            "mock_user1": true,
            "mock_user2": false,
            "mock_user3": true
        ]
    }
    
    private func simulateMessageDelivery(_ message: RTMMessage) {
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒后模拟送达
            // 这里可以触发消息状态更新回调
            print("Mock RTM: 消息 \(message.id) 已送达")
        }
    }
}

// MARK: - Mock RTC Room

/// Mock RTC Room 实现
/// 需求: 12.4, 16.3
internal class MockingRTCRoom: RTCRoom {
    public let roomId: String
    private var members: Set<String> = []
    private var createdAt: Date = Date()
    
    init(roomId: String) {
        self.roomId = roomId
    }
    
    /// 添加成员到房间
    internal func addMember(_ userId: String) {
        members.insert(userId)
    }
    
    /// 从房间移除成员
    internal func removeMember(_ userId: String) {
        members.remove(userId)
    }
    
    /// 获取房间成员数量
    internal var memberCount: Int {
        return members.count
    }
    
    /// 检查用户是否在房间中
    internal func hasMember(_ userId: String) -> Bool {
        return members.contains(userId)
    }
}

// MARK: - Mock RTM Channel

/// Mock RTM Channel 实现
/// 需求: 12.4, 16.3
internal class MockingRTMChannel: RTMChannel {
    public let channelId: String
    private var members: Set<String> = []
    private var messages: [RTMMessage] = []
    private var attributes: [String: String] = [:]
    private var createdAt: Date = Date()
    
    init(channelId: String) {
        self.channelId = channelId
    }
    
    /// 添加成员到频道
    internal func addMember(_ userId: String) {
        members.insert(userId)
    }
    
    /// 从频道移除成员
    internal func removeMember(_ userId: String) {
        members.remove(userId)
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
}
