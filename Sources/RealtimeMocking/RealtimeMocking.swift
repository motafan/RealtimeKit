import Foundation
import RealtimeCore

/// RealtimeMocking 模块
/// 提供用于测试的模拟实现
/// 需求: 12.4, 16.3

// MARK: - Mock Provider Factory

/// Mock 服务商工厂
public class MockProviderFactory: ProviderFactory {
    
    public init() {}
    
    public func createRTCProvider() -> RTCProvider {
        return MockRTCProvider()
    }
    
    public func createRTMProvider() -> RTMProvider {
        return MockRTMProvider()
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

// MARK: - Mock RTC Provider

/// Mock RTC 提供者实现，用于测试
public class MockRTCProvider: RTCProvider {
    
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
    
    // 模拟配置
    public var simulateNetworkDelay: Bool = true
    public var simulateErrors: Bool = false
    public var networkDelayRange: ClosedRange<UInt64> = 100_000_000...500_000_000 // 0.1-0.5秒
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - RTCProvider Implementation
    
    public func initialize(config: RTCConfig) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if simulateErrors && Bool.random() {
            throw RealtimeError.configurationError("模拟配置错误")
        }
        
        self.config = config
        print("Mock RTC Provider 初始化完成 - App ID: \(config.appId)")
    }
    
    public func createRoom(roomId: String) async throws -> RTCRoom {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard config != nil else {
            throw RealtimeError.configurationError("RTC Provider 未初始化")
        }
        
        let room = MockingRTCRoom(roomId: roomId)
        
        currentRoom = room
        print("Mock: 创建房间 \(roomId)")
        return room
    }
    
    public func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard config != nil else {
            throw RealtimeError.configurationError("RTC Provider 未初始化")
        }
        
        print("Mock: 用户 \(userId) 以 \(userRole.displayName) 身份加入房间 \(roomId)")
    }
    
    public func leaveRoom() async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard currentRoom != nil else {
            throw RealtimeError.noActiveSession
        }
        
        print("Mock: 离开房间")
        currentRoom = nil
    }
    
    public func switchUserRole(_ role: UserRole) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 切换用户角色到 \(role.displayName)")
    }
    
    // MARK: - Audio Stream Control
    
    public func muteMicrophone(_ muted: Bool) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        isMuted = muted
        print("Mock: 麦克风 \(muted ? "静音" : "取消静音")")
    }
    
    public func isMicrophoneMuted() -> Bool {
        return isMuted
    }
    
    public func stopLocalAudioStream() async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        isLocalAudioActive = false
        print("Mock: 停止本地音频流")
    }
    
    public func resumeLocalAudioStream() async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        isLocalAudioActive = true
        print("Mock: 恢复本地音频流")
    }
    
    public func isLocalAudioStreamActive() -> Bool {
        return isLocalAudioActive
    }
    
    // MARK: - Volume Control
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        audioMixingVolume = max(0, min(100, volume))
        print("Mock: 设置混音音量为 \(audioMixingVolume)")
    }
    
    public func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        playbackSignalVolume = max(0, min(100, volume))
        print("Mock: 设置播放音量为 \(playbackSignalVolume)")
    }
    
    public func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        recordingSignalVolume = max(0, min(100, volume))
        print("Mock: 设置录音音量为 \(recordingSignalVolume)")
    }
    
    public func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    // MARK: - Stream Push
    
    public func startStreamPush(config: StreamPushConfig) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 开始推流到 \(config.url)")
    }
    
    public func stopStreamPush() async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 停止推流")
    }
    
    public func updateStreamPushLayout(layout: StreamLayout) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 更新推流布局")
    }
    
    // MARK: - Media Relay
    
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 开始媒体中继")
    }
    
    public func stopMediaRelay() async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 停止媒体中继")
    }
    
    public func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 更新媒体中继频道")
    }
    
    public func pauseMediaRelay(toChannel: String) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 暂停到频道 \(toChannel) 的媒体中继")
    }
    
    public func resumeMediaRelay(toChannel: String) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 恢复到频道 \(toChannel) 的媒体中继")
    }
    
    // MARK: - Volume Indicator
    
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 启用音量指示器，间隔 \(config.interval)ms")
        
        // 启动模拟音量数据
        startMockVolumeSimulation(interval: config.interval)
    }
    
    public func disableVolumeIndicator() async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
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
        return UserVolumeInfo(userId: userId, volume: Int.random(in: 0...255))
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock: 更新 Token")
    }
    
    public func onTokenWillExpire(_ handler: @escaping (Int) -> Void) {
        tokenExpirationHandler = handler
        
        // 模拟 Token 过期通知 - 简化实现
        print("Mock RTC: Token 过期处理器已设置")
    }
    
    // MARK: - Private Methods
    
    private func simulateDelay() async throws {
        let delay = UInt64.random(in: networkDelayRange)
        try await Task.sleep(nanoseconds: delay)
    }
    
    private func startMockVolumeSimulation(interval: Int) {
        // 模拟音量数据更新 - 简化实现避免并发问题
        print("Mock: 音量模拟已启动，间隔 \(interval)ms")
    }
    
    private func generateMockVolumeInfos() -> [UserVolumeInfo] {
        let userIds = ["user1", "user2", "user3", "local_user"]
        return userIds.map { userId in
            let volume = Int.random(in: 0...255)
            let isSpeaking = volume > 50 // 简单的说话检测逻辑
            return UserVolumeInfo(
                userId: userId,
                volume: volume,
                vad: isSpeaking ? .speaking : .notSpeaking
            )
        }
    }
}

// MARK: - Mock RTM Provider

/// Mock RTM 提供者实现，用于测试
public class MockRTMProvider: RTMProvider {
    
    // MARK: - Properties
    
    private var config: RTMConfig?
    private var _isLoggedIn: Bool = false
    private var messageHandler: ((RTMMessage) -> Void)?
    private var connectionStateHandler: ((RTMConnectionState, RTMConnectionChangeReason) -> Void)?
    private var tokenExpirationHandler: (() -> Void)?
    
    // 模拟配置
    public var simulateNetworkDelay: Bool = true
    public var simulateErrors: Bool = false
    public var networkDelayRange: ClosedRange<UInt64> = 100_000_000...300_000_000 // 0.1-0.3秒
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - RTMProvider Implementation
    
    public func initialize(config: RTMConfig) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        if simulateErrors && Bool.random() {
            throw RealtimeError.configurationError("模拟RTM配置错误")
        }
        
        self.config = config
        print("Mock RTM Provider 初始化完成 - App ID: \(config.appId)")
    }
    
    public func login(userId: String, token: String) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        guard config != nil else {
            throw RealtimeError.configurationError("RTM Provider 未初始化")
        }
        
        print("Mock RTM: 用户 \(userId) 登录")
        _isLoggedIn = true
        
        connectionStateHandler?(.connected, .loginSuccess)
    }
    
    public func logout() async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock RTM: 用户登出")
        _isLoggedIn = false
        
        connectionStateHandler?(.disconnected, .logout)
    }
    
    public func isLoggedIn() -> Bool {
        return _isLoggedIn
    }
    
    // MARK: - Channel Management
    
    public func createChannel(channelId: String) -> RTMChannel {
        return MockingRTMChannel(channelId: channelId)
    }
    
    public func joinChannel(channelId: String) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock RTM: 加入频道 \(channelId)")
    }
    
    public func leaveChannel(channelId: String) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock RTM: 离开频道 \(channelId)")
    }
    
    public func getChannelMembers(channelId: String) async throws -> [RTMChannelMember] {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        // 返回模拟的频道成员
        return [
            RTMChannelMember(userId: "mock_user1"),
            RTMChannelMember(userId: "mock_user2")
        ]
    }
    
    public func getChannelMemberCount(channelId: String) async throws -> Int {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        return Int.random(in: 1...10)
    }
    
    // MARK: - Message Sending
    
    public func sendPeerMessage(_ message: RTMMessage, toPeer peerId: String, options: RTMSendMessageOptions?) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock RTM: 发送点对点消息给 \(peerId): \(message.text)")
        
        // 模拟消息回执
        simulateMessageDelivery(message)
    }
    
    public func sendChannelMessage(_ message: RTMMessage, toChannel channelId: String, options: RTMSendMessageOptions?) async throws {
        if simulateNetworkDelay {
            try await simulateDelay()
        }
        
        print("Mock RTM: 发送频道消息到 \(channelId): \(message.text)")
        
        // 模拟消息回执
        simulateMessageDelivery(message)
    }
    
    // MARK: - User Attributes (简化实现)
    
    public func setLocalUserAttributes(_ attributes: [String: String]) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 设置本地用户属性")
    }
    
    public func addOrUpdateLocalUserAttributes(_ attributes: [String: String]) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 添加或更新本地用户属性")
    }
    
    public func deleteLocalUserAttributesByKeys(_ attributeKeys: [String]) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 删除本地用户属性")
    }
    
    public func clearLocalUserAttributes() async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 清除本地用户属性")
    }
    
    public func getUserAttributes(userId: String) async throws -> [String: String] {
        if simulateNetworkDelay { try await simulateDelay() }
        return ["nickname": "Mock User", "status": "online"]
    }
    
    public func getUsersAttributes(userIds: [String]) async throws -> [String: [String: String]] {
        if simulateNetworkDelay { try await simulateDelay() }
        return userIds.reduce(into: [:]) { result, userId in
            result[userId] = ["nickname": "Mock User \(userId)", "status": "online"]
        }
    }
    
    // MARK: - Channel Attributes (简化实现)
    
    public func setChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 设置频道 \(channelId) 属性")
    }
    
    public func addOrUpdateChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 添加或更新频道 \(channelId) 属性")
    }
    
    public func deleteChannelAttributesByKeys(channelId: String, attributeKeys: [String], options: RTMChannelAttributeOptions?) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 删除频道 \(channelId) 属性")
    }
    
    public func clearChannelAttributes(channelId: String, options: RTMChannelAttributeOptions?) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 清除频道 \(channelId) 属性")
    }
    
    public func getChannelAttributes(channelId: String) async throws -> [String: String] {
        if simulateNetworkDelay { try await simulateDelay() }
        return ["topic": "Mock Channel Topic", "description": "Mock Channel Description"]
    }
    
    public func getChannelAttributesByKeys(channelId: String, attributeKeys: [String]) async throws -> [String: String] {
        if simulateNetworkDelay { try await simulateDelay() }
        return attributeKeys.reduce(into: [:]) { result, key in
            result[key] = "Mock Value for \(key)"
        }
    }
    
    // MARK: - Online Status (简化实现)
    
    public func queryPeersOnlineStatus(userIds: [String]) async throws -> [String: Bool] {
        if simulateNetworkDelay { try await simulateDelay() }
        return userIds.reduce(into: [:]) { result, userId in
            result[userId] = Bool.random()
        }
    }
    
    public func subscribePeersOnlineStatus(userIds: [String]) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 订阅用户在线状态")
    }
    
    public func unsubscribePeersOnlineStatus(userIds: [String]) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 取消订阅用户在线状态")
    }
    
    public func querySubscribedPeersList() async throws -> [String] {
        if simulateNetworkDelay { try await simulateDelay() }
        return ["mock_user1", "mock_user2"]
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        if simulateNetworkDelay { try await simulateDelay() }
        print("Mock RTM: 更新 Token")
    }
    
    public func onTokenWillExpire(_ handler: @escaping () -> Void) {
        tokenExpirationHandler = handler
        
        // 模拟 Token 过期通知 - 简化实现
        print("Mock RTM: Token 过期处理器已设置")
    }
    
    // MARK: - Event Handlers
    
    public func onConnectionStateChanged(_ handler: @escaping (RTMConnectionState, RTMConnectionChangeReason) -> Void) {
        connectionStateHandler = handler
    }
    
    public func onPeerMessageReceived(_ handler: @escaping (RTMMessage, String) -> Void) {
        // 模拟接收点对点消息 - 简化实现
        print("Mock RTM: 点对点消息接收处理器已设置")
    }
    
    public func onChannelMessageReceived(_ handler: @escaping (RTMMessage, RTMChannelMember, String) -> Void) {
        // 模拟接收频道消息 - 简化实现
        print("Mock RTM: 频道消息接收处理器已设置")
    }
    
    public func onPeersOnlineStatusChanged(_ handler: @escaping ([String: Bool]) -> Void) {
        // 模拟用户在线状态变化 - 简化实现
        print("Mock RTM: 在线状态变化处理器已设置")
    }
    
    // MARK: - Private Methods
    
    private func simulateDelay() async throws {
        let delay = UInt64.random(in: networkDelayRange)
        try await Task.sleep(nanoseconds: delay)
    }
    
    private func simulateMessageDelivery(_ message: RTMMessage) {
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒后模拟送达
            // 这里可以触发消息状态更新回调
        }
    }
}

// MARK: - Mock RTC Room

/// Mock RTC Room 实现
internal class MockingRTCRoom: RTCRoom {
    let roomId: String
    
    init(roomId: String) {
        self.roomId = roomId
    }
}

// MARK: - Mock RTM Channel

/// Mock RTM Channel 实现
internal class MockingRTMChannel: RTMChannel {
    let channelId: String
    
    init(channelId: String) {
        self.channelId = channelId
    }
}