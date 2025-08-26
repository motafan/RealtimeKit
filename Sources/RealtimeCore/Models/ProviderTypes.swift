import Foundation

/// 服务商类型枚举
/// 需求: 2.1, 2.2, 2.3
public enum ProviderType: String, CaseIterable, Codable, Sendable {
    case agora = "agora"
    case tencent = "tencent"
    case zego = "zego"
    case mock = "mock"  // 用于测试和降级
    
    /// 获取服务商的显示名称
    public var displayName: String {
        switch self {
        case .agora:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.agora")
        case .tencent:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.tencent")
        case .zego:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.zego")
        case .mock:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.mock")
        }
    }
    
    /// 获取服务商的描述信息
    public var description: String {
        switch self {
        case .agora:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.agora.description")
        case .tencent:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.tencent.description")
        case .zego:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.zego.description")
        case .mock:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.mock.description")
        }
    }
    
    /// 检查服务商是否为生产环境服务商
    public var isProductionProvider: Bool {
        switch self {
        case .agora, .tencent, .zego:
            return true
        case .mock:
            return false
        }
    }
    
    /// 获取服务商的优先级（数值越小优先级越高）
    public var priority: Int {
        switch self {
        case .agora:
            return 1
        case .tencent:
            return 2
        case .zego:
            return 3
        case .mock:
            return 999 // 最低优先级，仅用于测试和降级
        }
    }
}

/// 服务商功能特性
/// 需求: 2.2
public enum ProviderFeature: String, CaseIterable, Codable, Sendable {
    case audioStreaming = "audio_streaming"
    case videoStreaming = "video_streaming"
    case streamPush = "stream_push"
    case mediaRelay = "media_relay"
    case volumeIndicator = "volume_indicator"
    case messageProcessing = "message_processing"
    
    public var displayName: String {
        switch self {
        case .audioStreaming:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.feature.audio_streaming")
        case .videoStreaming:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.feature.video_streaming")
        case .streamPush:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.feature.stream_push")
        case .mediaRelay:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.feature.media_relay")
        case .volumeIndicator:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.feature.volume_indicator")
        case .messageProcessing:
            return ErrorLocalizationHelper.getLocalizedString(for: "provider.feature.message_processing")
        }
    }
}

/// 服务商工厂协议
/// 需求: 2.2
public protocol ProviderFactory {
    /// 创建 RTC Provider 实例
    func createRTCProvider() -> RTCProvider
    
    /// 创建 RTM Provider 实例
    func createRTMProvider() -> RTMProvider
    
    /// 获取支持的功能特性
    func supportedFeatures() -> Set<ProviderFeature>
}

/// Mock 服务商工厂实现
/// 需求: 2.2, 12.4, 16.3
public class MockProviderFactory: ProviderFactory {
    public init() {}
    
    public func createRTCProvider() -> RTCProvider {
        return InternalMockRTCProvider()
    }
    
    public func createRTMProvider() -> RTMProvider {
        return InternalMockRTMProvider()
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return Set(ProviderFeature.allCases) // Mock 支持所有功能
    }
}

/// Internal Mock RTC Provider 实现
/// 需求: 12.4, 16.3
internal class InternalMockRTCProvider: RTCProvider {
    private var isInitialized = false
    private var currentRoom: RTCRoom?
    private var microphoneMuted = false
    private var audioMixingVolume = 100
    private var playbackSignalVolume = 100
    private var recordingSignalVolume = 100
    private var localAudioStreamActive = true
    private var volumeIndicatorEnabled = false
    
    private var volumeIndicatorHandler: (([UserVolumeInfo]) -> Void)?
    private var volumeEventHandler: ((VolumeEvent) -> Void)?
    private var tokenWillExpireHandler: ((Int) -> Void)?
    
    func initialize(config: RTCConfig) async throws {
        isInitialized = true
        print("MockRTCProvider 初始化完成")
    }
    
    func createRoom(roomId: String) async throws -> RTCRoom {
        guard isInitialized else {
            throw RealtimeError.configurationError("Provider 未初始化")
        }
        
        let room = MockRTCRoom(roomId: roomId)
        currentRoom = room
        return room
    }
    
    func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        guard isInitialized else {
            throw RealtimeError.configurationError("Provider 未初始化")
        }
        
        if currentRoom == nil {
            currentRoom = MockRTCRoom(roomId: roomId)
        }
        
        print("MockRTCProvider 加入房间: \(roomId), 用户: \(userId), 角色: \(userRole.displayName)")
    }
    
    func leaveRoom() async throws {
        currentRoom = nil
        print("MockRTCProvider 离开房间")
    }
    
    func switchUserRole(_ role: UserRole) async throws {
        print("MockRTCProvider 切换角色: \(role.displayName)")
    }
    
    func muteMicrophone(_ muted: Bool) async throws {
        microphoneMuted = muted
        print("MockRTCProvider 麦克风\(muted ? "静音" : "取消静音")")
    }
    
    func isMicrophoneMuted() -> Bool {
        return microphoneMuted
    }
    
    func stopLocalAudioStream() async throws {
        localAudioStreamActive = false
        print("MockRTCProvider 停止本地音频流")
    }
    
    func resumeLocalAudioStream() async throws {
        localAudioStreamActive = true
        print("MockRTCProvider 恢复本地音频流")
    }
    
    func isLocalAudioStreamActive() -> Bool {
        return localAudioStreamActive
    }
    
    func setAudioMixingVolume(_ volume: Int) async throws {
        audioMixingVolume = max(0, min(100, volume))
        print("MockRTCProvider 设置混音音量: \(audioMixingVolume)")
    }
    
    func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    func setPlaybackSignalVolume(_ volume: Int) async throws {
        playbackSignalVolume = max(0, min(100, volume))
        print("MockRTCProvider 设置播放音量: \(playbackSignalVolume)")
    }
    
    func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    func setRecordingSignalVolume(_ volume: Int) async throws {
        recordingSignalVolume = max(0, min(100, volume))
        print("MockRTCProvider 设置录音音量: \(recordingSignalVolume)")
    }
    
    func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    func startStreamPush(config: StreamPushConfig) async throws {
        print("MockRTCProvider 开始推流: \(config.url)")
    }
    
    func stopStreamPush() async throws {
        print("MockRTCProvider 停止推流")
    }
    
    func updateStreamPushLayout(layout: StreamLayout) async throws {
        print("MockRTCProvider 更新推流布局")
    }
    
    func startMediaRelay(config: MediaRelayConfig) async throws {
        print("MockRTCProvider 开始媒体中继")
    }
    
    func stopMediaRelay() async throws {
        print("MockRTCProvider 停止媒体中继")
    }
    
    func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        print("MockRTCProvider 更新媒体中继频道")
    }
    
    func pauseMediaRelay(toChannel: String) async throws {
        print("MockRTCProvider 暂停媒体中继到频道: \(toChannel)")
    }
    
    func resumeMediaRelay(toChannel: String) async throws {
        print("MockRTCProvider 恢复媒体中继到频道: \(toChannel)")
    }
    
    func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        volumeIndicatorEnabled = true
        print("MockRTCProvider 启用音量指示器")
        
        // 模拟音量数据
        simulateVolumeData()
    }
    
    func disableVolumeIndicator() async throws {
        volumeIndicatorEnabled = false
        print("MockRTCProvider 禁用音量指示器")
    }
    
    func setVolumeIndicatorHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void) {
        volumeIndicatorHandler = handler
    }
    
    func setVolumeEventHandler(_ handler: @escaping (VolumeEvent) -> Void) {
        volumeEventHandler = handler
    }
    
    func getCurrentVolumeInfos() -> [UserVolumeInfo] {
        return []
    }
    
    func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return nil
    }
    
    func renewToken(_ newToken: String) async throws {
        print("MockRTCProvider 更新 Token")
    }
    
    func onTokenWillExpire(_ handler: @escaping (Int) -> Void) {
        tokenWillExpireHandler = handler
    }
    
    // MARK: - Mock Simulation Methods
    
    private func simulateVolumeData() {
        guard volumeIndicatorEnabled else { return }
        
        // 简化实现，直接调用而不使用异步
        let mockVolumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 128, vad: .speaking, timestamp: Date()),
            UserVolumeInfo(userId: "user2", volume: 51, vad: .notSpeaking, timestamp: Date())
        ]
        
        volumeIndicatorHandler?(mockVolumeInfos)
        volumeEventHandler?(.volumeUpdate(mockVolumeInfos))
    }
}

/// Internal Mock RTM Provider 实现
/// 需求: 12.4, 16.3
internal class InternalMockRTMProvider: RTMProvider {
    private var isInitialized = false
    private var loggedIn = false
    private var joinedChannels: Set<String> = []
    
    private var connectionStateHandler: ((RTMConnectionState, RTMConnectionChangeReason) -> Void)?
    private var peerMessageHandler: ((RTMMessage, String) -> Void)?
    private var channelMessageHandler: ((RTMMessage, RTMChannelMember, String) -> Void)?
    private var peersOnlineStatusHandler: (([String: Bool]) -> Void)?
    private var tokenWillExpireHandler: (() -> Void)?
    
    func initialize(config: RTMConfig) async throws {
        isInitialized = true
        print("MockRTMProvider 初始化完成")
    }
    
    func login(userId: String, token: String) async throws {
        guard isInitialized else {
            throw RealtimeError.configurationError("Provider 未初始化")
        }
        
        loggedIn = true
        connectionStateHandler?(.connected, .loginSuccess)
        print("MockRTMProvider 登录成功: \(userId)")
    }
    
    func logout() async throws {
        loggedIn = false
        joinedChannels.removeAll()
        connectionStateHandler?(.disconnected, .logout)
        print("MockRTMProvider 登出")
    }
    
    func isLoggedIn() -> Bool {
        return loggedIn
    }
    
    func createChannel(channelId: String) -> RTMChannel {
        return MockRTMChannel(channelId: channelId)
    }
    
    func joinChannel(channelId: String) async throws {
        guard isLoggedIn() else {
            throw RealtimeError.configurationError("未登录")
        }
        
        joinedChannels.insert(channelId)
        print("MockRTMProvider 加入频道: \(channelId)")
    }
    
    func leaveChannel(channelId: String) async throws {
        joinedChannels.remove(channelId)
        print("MockRTMProvider 离开频道: \(channelId)")
    }
    
    func getChannelMembers(channelId: String) async throws -> [RTMChannelMember] {
        return []
    }
    
    func getChannelMemberCount(channelId: String) async throws -> Int {
        return 0
    }
    
    func sendPeerMessage(_ message: RTMMessage, toPeer peerId: String, options: RTMSendMessageOptions?) async throws {
        print("MockRTMProvider 发送点对点消息到: \(peerId)")
    }
    
    func sendChannelMessage(_ message: RTMMessage, toChannel channelId: String, options: RTMSendMessageOptions?) async throws {
        print("MockRTMProvider 发送频道消息到: \(channelId)")
    }
    
    func setLocalUserAttributes(_ attributes: [String: String]) async throws {
        print("MockRTMProvider 设置用户属性")
    }
    
    func addOrUpdateLocalUserAttributes(_ attributes: [String: String]) async throws {
        print("MockRTMProvider 更新用户属性")
    }
    
    func deleteLocalUserAttributesByKeys(_ attributeKeys: [String]) async throws {
        print("MockRTMProvider 删除用户属性")
    }
    
    func clearLocalUserAttributes() async throws {
        print("MockRTMProvider 清除用户属性")
    }
    
    func getUserAttributes(userId: String) async throws -> [String: String] {
        return [:]
    }
    
    func getUsersAttributes(userIds: [String]) async throws -> [String: [String: String]] {
        return [:]
    }
    
    func setChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        print("MockRTMProvider 设置频道属性")
    }
    
    func addOrUpdateChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        print("MockRTMProvider 更新频道属性")
    }
    
    func deleteChannelAttributesByKeys(channelId: String, attributeKeys: [String], options: RTMChannelAttributeOptions?) async throws {
        print("MockRTMProvider 删除频道属性")
    }
    
    func clearChannelAttributes(channelId: String, options: RTMChannelAttributeOptions?) async throws {
        print("MockRTMProvider 清除频道属性")
    }
    
    func getChannelAttributes(channelId: String) async throws -> [String: String] {
        return [:]
    }
    
    func getChannelAttributesByKeys(channelId: String, attributeKeys: [String]) async throws -> [String: String] {
        return [:]
    }
    
    func queryPeersOnlineStatus(userIds: [String]) async throws -> [String: Bool] {
        return [:]
    }
    
    func subscribePeersOnlineStatus(userIds: [String]) async throws {
        print("MockRTMProvider 订阅在线状态")
    }
    
    func unsubscribePeersOnlineStatus(userIds: [String]) async throws {
        print("MockRTMProvider 取消订阅在线状态")
    }
    
    func querySubscribedPeersList() async throws -> [String] {
        return []
    }
    
    func renewToken(_ newToken: String) async throws {
        print("MockRTMProvider 更新 Token")
    }
    
    func onTokenWillExpire(_ handler: @escaping () -> Void) {
        tokenWillExpireHandler = handler
    }
    
    func onConnectionStateChanged(_ handler: @escaping (RTMConnectionState, RTMConnectionChangeReason) -> Void) {
        connectionStateHandler = handler
    }
    
    func onPeerMessageReceived(_ handler: @escaping (RTMMessage, String) -> Void) {
        peerMessageHandler = handler
    }
    
    func onChannelMessageReceived(_ handler: @escaping (RTMMessage, RTMChannelMember, String) -> Void) {
        channelMessageHandler = handler
    }
    
    func onPeersOnlineStatusChanged(_ handler: @escaping ([String: Bool]) -> Void) {
        peersOnlineStatusHandler = handler
    }
}

/// Mock RTC Room 实现
internal class MockRTCRoom: RTCRoom {
    let roomId: String
    
    init(roomId: String) {
        self.roomId = roomId
    }
}

/// Mock RTM Channel 实现
internal class MockRTMChannel: RTMChannel {
    let channelId: String
    
    init(channelId: String) {
        self.channelId = channelId
    }
}