import Testing
import Foundation
@testable import RealtimeCore

/// 媒体中继管理器测试
/// 需求: 8.2, 8.3, 8.5, 8.6 - 测试媒体中继控制功能和状态管理
@Suite("MediaRelayManager Tests")
struct MediaRelayManagerTests {
    
    // MARK: - Mock Classes
    
    class MockRTCRoom: RTCRoom {
        let roomId: String
        
        init(roomId: String) {
            self.roomId = roomId
        }
    }
    
    class MockRTCProvider: RTCProvider {
        var shouldFailStartRelay = false
        var shouldFailStopRelay = false
        var shouldFailUpdateChannels = false
        var shouldFailPauseRelay = false
        var shouldFailResumeRelay = false
        
        var startRelayCallCount = 0
        var stopRelayCallCount = 0
        var updateChannelsCallCount = 0
        var pauseRelayCallCount = 0
        var resumeRelayCallCount = 0
        
        var lastRelayConfig: MediaRelayConfig?
        var lastPausedChannel: String?
        var lastResumedChannel: String?
        
        // MARK: - Required RTCProvider Methods (Minimal Implementation)
        
        func initialize(config: RTCConfig) async throws {}
        func createRoom(roomId: String) async throws -> RTCRoom { 
            return MockRTCRoom(roomId: roomId)
        }
        func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {}
        func leaveRoom() async throws {}
        func switchUserRole(_ role: UserRole) async throws {}
        func muteMicrophone(_ muted: Bool) async throws {}
        func isMicrophoneMuted() -> Bool { return false }
        func stopLocalAudioStream() async throws {}
        func resumeLocalAudioStream() async throws {}
        func isLocalAudioStreamActive() -> Bool { return true }
        func setAudioMixingVolume(_ volume: Int) async throws {}
        func getAudioMixingVolume() -> Int { return 100 }
        func setPlaybackSignalVolume(_ volume: Int) async throws {}
        func getPlaybackSignalVolume() -> Int { return 100 }
        func setRecordingSignalVolume(_ volume: Int) async throws {}
        func getRecordingSignalVolume() -> Int { return 100 }
        func startStreamPush(config: StreamPushConfig) async throws {}
        func stopStreamPush() async throws {}
        func updateStreamPushLayout(layout: StreamLayout) async throws {}
        func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {}
        func disableVolumeIndicator() async throws {}
        func setVolumeIndicatorHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void) {}
        func setVolumeEventHandler(_ handler: @escaping (VolumeEvent) -> Void) {}
        func getCurrentVolumeInfos() -> [UserVolumeInfo] { return [] }
        func getVolumeInfo(for userId: String) -> UserVolumeInfo? { return nil }
        func renewToken(_ newToken: String) async throws {}
        func onTokenWillExpire(_ handler: @escaping (Int) -> Void) {}
        
        // MARK: - Media Relay Methods
        
        func startMediaRelay(config: MediaRelayConfig) async throws {
            startRelayCallCount += 1
            lastRelayConfig = config
            
            if shouldFailStartRelay {
                throw LocalizedRealtimeError.mediaRelayFailed(reason: "Mock start relay failure")
            }
        }
        
        func stopMediaRelay() async throws {
            stopRelayCallCount += 1
            
            if shouldFailStopRelay {
                throw LocalizedRealtimeError.mediaRelayFailed(reason: "Mock stop relay failure")
            }
        }
        
        func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
            updateChannelsCallCount += 1
            lastRelayConfig = config
            
            if shouldFailUpdateChannels {
                throw LocalizedRealtimeError.mediaRelayFailed(reason: "Mock update channels failure")
            }
        }
        
        func pauseMediaRelay(toChannel: String) async throws {
            pauseRelayCallCount += 1
            lastPausedChannel = toChannel
            
            if shouldFailPauseRelay {
                throw LocalizedRealtimeError.mediaRelayFailed(reason: "Mock pause relay failure")
            }
        }
        
        func resumeMediaRelay(toChannel: String) async throws {
            resumeRelayCallCount += 1
            lastResumedChannel = toChannel
            
            if shouldFailResumeRelay {
                throw LocalizedRealtimeError.mediaRelayFailed(reason: "Mock resume relay failure")
            }
        }
    }
    
    // MARK: - Test Data
    
    private func createValidConfig() throws -> MediaRelayConfig {
        let sourceChannel = MediaRelayChannelInfo(
            channelName: "source_channel",
            userId: "user123",
            token: "source_token"
        )
        
        let destinationChannels = [
            MediaRelayChannelInfo(
                channelName: "dest1",
                userId: "user456",
                token: "dest1_token"
            ),
            MediaRelayChannelInfo(
                channelName: "dest2",
                userId: "user789",
                token: "dest2_token"
            )
        ]
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("MediaRelayManager initialization")
    @MainActor
    func testMediaRelayManagerInitialization() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        
        #expect(manager.currentConfig == nil)
        #expect(manager.currentState == .idle)
        #expect(manager.detailedState == nil)
        #expect(manager.statistics == nil)
        #expect(!manager.isRunning)
        #expect(manager.pausedChannels.isEmpty)
        #expect(manager.isMediaRelaySupported)
        #expect(manager.connectedChannelCount == 0)
        #expect(manager.failedChannelCount == 0)
    }
    
    @Test("MediaRelayManager initialization without provider")
    @MainActor
    func testMediaRelayManagerInitializationWithoutProvider() async throws {
        let manager = MediaRelayManager()
        
        #expect(!manager.isMediaRelaySupported)
        
        let config = try createValidConfig()
        
        await #expect(throws: LocalizedRealtimeError.self) {
            try await manager.startRelay(config: config)
        }
    }
    
    // MARK: - Start Relay Tests
    
    @Test("Start media relay - success")
    @MainActor
    func testStartMediaRelay_Success() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        try await manager.startRelay(config: config)
        
        #expect(manager.currentState == .running)
        #expect(manager.isRunning)
        #expect(manager.currentConfig?.sourceChannel.channelName == "source_channel")
        #expect(manager.currentConfig?.destinationChannels.count == 2)
        #expect(mockProvider.startRelayCallCount == 1)
        #expect(mockProvider.lastRelayConfig?.sourceChannel.channelName == "source_channel")
    }
    
    @Test("Start media relay - failure")
    @MainActor
    func testStartMediaRelay_Failure() async throws {
        let mockProvider = MockRTCProvider()
        mockProvider.shouldFailStartRelay = true
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        await #expect(throws: LocalizedRealtimeError.self) {
            try await manager.startRelay(config: config)
        }
        
        #expect(manager.currentState == .failure)
        #expect(!manager.isRunning)
        #expect(manager.currentConfig == nil)
        #expect(mockProvider.startRelayCallCount == 1)
    }
    
    @Test("Start media relay - already running")
    @MainActor
    func testStartMediaRelay_AlreadyRunning() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 先启动一次
        try await manager.startRelay(config: config)
        #expect(manager.isRunning)
        
        // 尝试再次启动
        await #expect(throws: LocalizedRealtimeError.self) {
            try await manager.startRelay(config: config)
        }
        
        #expect(mockProvider.startRelayCallCount == 1) // 只调用了一次
    }
    
    @Test("Start media relay - invalid config")
    @MainActor
    func testStartMediaRelay_InvalidConfig() async throws {
        let mockProvider = MockRTCProvider()
        let _ = MediaRelayManager(rtcProvider: mockProvider)
        
        let sourceChannel = MediaRelayChannelInfo(
            channelName: "source",
            userId: "user",
            token: "token"
        )
        
        // 空的目标频道列表（无效配置）
        #expect(throws: MediaRelayValidationError.self) {
            _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: []
            )
        }
    }
    
    // MARK: - Stop Relay Tests
    
    @Test("Stop media relay - success")
    @MainActor
    func testStopMediaRelay_Success() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 先启动
        try await manager.startRelay(config: config)
        #expect(manager.isRunning)
        
        // 停止
        try await manager.stopRelay()
        
        #expect(manager.currentState == .idle)
        #expect(!manager.isRunning)
        #expect(manager.pausedChannels.isEmpty)
        #expect(mockProvider.stopRelayCallCount == 1)
    }
    
    @Test("Stop media relay - failure")
    @MainActor
    func testStopMediaRelay_Failure() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 先启动
        try await manager.startRelay(config: config)
        #expect(manager.isRunning)
        
        // 设置停止失败
        mockProvider.shouldFailStopRelay = true
        
        await #expect(throws: LocalizedRealtimeError.self) {
            try await manager.stopRelay()
        }
        
        #expect(manager.currentState == .failure)
        #expect(mockProvider.stopRelayCallCount == 1)
    }
    
    @Test("Stop media relay - not running")
    @MainActor
    func testStopMediaRelay_NotRunning() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        
        // 直接停止（没有启动）
        try await manager.stopRelay()
        
        #expect(manager.currentState == .idle)
        #expect(!manager.isRunning)
        #expect(mockProvider.stopRelayCallCount == 0) // 没有调用
    }
    
    // MARK: - Channel Management Tests
    
    @Test("Add destination channel - success")
    @MainActor
    func testAddDestinationChannel_Success() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        #expect(manager.destinationChannelCount == 2)
        
        // 添加新频道
        let newChannel = MediaRelayChannelInfo(
            channelName: "dest3",
            userId: "user999",
            token: "dest3_token"
        )
        
        try await manager.addDestinationChannel(newChannel)
        
        #expect(manager.destinationChannelCount == 3)
        #expect(manager.currentConfig?.destinationChannels.contains { $0.channelName == "dest3" } == true)
        #expect(mockProvider.updateChannelsCallCount == 1)
    }
    
    @Test("Add destination channel - not running")
    @MainActor
    func testAddDestinationChannel_NotRunning() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        
        let newChannel = MediaRelayChannelInfo(
            channelName: "dest3",
            userId: "user999",
            token: "dest3_token"
        )
        
        await #expect(throws: LocalizedRealtimeError.self) {
            try await manager.addDestinationChannel(newChannel)
        }
        
        #expect(mockProvider.updateChannelsCallCount == 0)
    }
    
    @Test("Remove destination channel - success")
    @MainActor
    func testRemoveDestinationChannel_Success() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        #expect(manager.destinationChannelCount == 2)
        
        // 移除频道
        try await manager.removeDestinationChannel("dest1")
        
        #expect(manager.destinationChannelCount == 1)
        #expect(manager.currentConfig?.destinationChannels.contains { $0.channelName == "dest1" } == false)
        #expect(manager.currentConfig?.destinationChannels.contains { $0.channelName == "dest2" } == true)
        #expect(mockProvider.updateChannelsCallCount == 1)
    }
    
    @Test("Remove destination channel - last channel")
    @MainActor
    func testRemoveDestinationChannel_LastChannel() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        
        // 创建只有一个目标频道的配置
        let sourceChannel = MediaRelayChannelInfo(
            channelName: "source",
            userId: "user",
            token: "token"
        )
        let singleDestConfig = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [
                MediaRelayChannelInfo(channelName: "dest1", userId: "user", token: "token")
            ]
        )
        
        // 启动中继
        try await manager.startRelay(config: singleDestConfig)
        #expect(manager.destinationChannelCount == 1)
        
        // 尝试移除最后一个频道
        await #expect(throws: MediaRelayValidationError.self) {
            try await manager.removeDestinationChannel("dest1")
        }
        
        #expect(manager.destinationChannelCount == 1) // 没有变化
    }
    
    // MARK: - Pause/Resume Tests
    
    @Test("Pause and resume channel - success")
    @MainActor
    func testPauseAndResumeChannel_Success() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 暂停频道
        try await manager.pauseChannel("dest1")
        
        #expect(manager.pausedChannels.contains("dest1"))
        #expect(manager.isChannelPaused("dest1"))
        #expect(!manager.isChannelPaused("dest2"))
        #expect(mockProvider.pauseRelayCallCount == 1)
        #expect(mockProvider.lastPausedChannel == "dest1")
        
        // 恢复频道
        try await manager.resumeChannel("dest1")
        
        #expect(!manager.pausedChannels.contains("dest1"))
        #expect(!manager.isChannelPaused("dest1"))
        #expect(mockProvider.resumeRelayCallCount == 1)
        #expect(mockProvider.lastResumedChannel == "dest1")
    }
    
    @Test("Pause channel - already paused")
    @MainActor
    func testPauseChannel_AlreadyPaused() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 暂停频道
        try await manager.pauseChannel("dest1")
        #expect(mockProvider.pauseRelayCallCount == 1)
        
        // 再次暂停同一频道
        try await manager.pauseChannel("dest1")
        #expect(mockProvider.pauseRelayCallCount == 1) // 没有增加
    }
    
    @Test("Resume channel - not paused")
    @MainActor
    func testResumeChannel_NotPaused() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 恢复未暂停的频道
        try await manager.resumeChannel("dest1")
        #expect(mockProvider.resumeRelayCallCount == 0) // 没有调用
    }
    
    @Test("Pause channel - not running")
    @MainActor
    func testPauseChannel_NotRunning() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        
        await #expect(throws: LocalizedRealtimeError.self) {
            try await manager.pauseChannel("dest1")
        }
        
        #expect(mockProvider.pauseRelayCallCount == 0)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Statistics collection")
    @MainActor
    func testStatisticsCollection() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 等待统计信息更新
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 检查统计信息
        let stats = manager.getCurrentStatistics()
        #expect(stats != nil)
        #expect(stats?.totalRelayDuration ?? 0 > 0)
        #expect(stats?.channelStatistics.count == 2) // dest1 和 dest2
        
        // 检查频道统计信息
        let dest1Stats = manager.getChannelStatistics(for: "dest1")
        #expect(dest1Stats != nil)
        #expect(dest1Stats?.channelName == "dest1")
    }
    
    @Test("Statistics after stop")
    @MainActor
    func testStatisticsAfterStop() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 等待统计信息更新
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 停止中继
        try await manager.stopRelay()
        
        // 统计信息应该保留
        let stats = manager.getCurrentStatistics()
        #expect(stats != nil)
        #expect(stats?.totalRelayDuration ?? 0 > 0)
    }
    
    // MARK: - State Management Tests
    
    @Test("Channel state management")
    @MainActor
    func testChannelStateManagement() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 检查初始状态
        let allStates = manager.getAllChannelStates()
        #expect(allStates.count == 3) // source + 2 destinations
        #expect(allStates["source_channel"] != nil)
        #expect(allStates["dest1"] != nil)
        #expect(allStates["dest2"] != nil)
        
        // 检查特定频道状态
        let dest1State = manager.getChannelState(for: "dest1")
        #expect(dest1State?.channelName == "dest1")
        #expect(dest1State?.connectionState == .connecting)
    }
    
    @Test("Detailed state updates")
    @MainActor
    func testDetailedStateUpdates() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 等待状态更新
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 检查详细状态
        let detailedState = manager.detailedState
        #expect(detailedState != nil)
        #expect(detailedState?.overallState == .running)
        #expect(detailedState?.sourceChannelState.channelName == "source_channel")
        #expect(detailedState?.destinationChannelStates.count == 2)
        #expect(detailedState?.startTime != nil)
    }
    
    // MARK: - Reset Tests
    
    @Test("Manager reset")
    @MainActor
    func testManagerReset() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动中继并暂停一个频道
        try await manager.startRelay(config: config)
        try await manager.pauseChannel("dest1")
        
        #expect(manager.isRunning)
        #expect(manager.pausedChannels.contains("dest1"))
        
        // 重置管理器
        manager.reset()
        
        #expect(manager.currentConfig == nil)
        #expect(manager.currentState == .idle)
        #expect(manager.detailedState == nil)
        #expect(manager.statistics == nil)
        #expect(!manager.isRunning)
        #expect(manager.pausedChannels.isEmpty)
    }
    
    // MARK: - Callback Tests
    
    @Test("State change callbacks")
    @MainActor
    func testStateChangeCallbacks() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        var stateChanges: [(MediaRelayState, MediaRelayDetailedState?)] = []
        
        manager.onStateChanged = { state, detailedState in
            stateChanges.append((state, detailedState))
        }
        
        // 启动中继
        try await manager.startRelay(config: config)
        
        // 检查状态变化回调
        #expect(stateChanges.count >= 2) // connecting -> running
        #expect(stateChanges.contains { $0.0 == .connecting })
        #expect(stateChanges.contains { $0.0 == .running })
    }
    
    @Test("Error callbacks")
    @MainActor
    func testErrorCallbacks() async throws {
        let mockProvider = MockRTCProvider()
        mockProvider.shouldFailStartRelay = true
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        var receivedErrors: [Error] = []
        
        manager.onError = { error in
            receivedErrors.append(error)
        }
        
        // 尝试启动中继（会失败）
        await #expect(throws: LocalizedRealtimeError.self) {
            try await manager.startRelay(config: config)
        }
        
        // 检查错误回调
        #expect(receivedErrors.count == 1)
    }
    
    // MARK: - Property Tests
    
    @Test("Manager properties")
    @MainActor
    func testManagerProperties() async throws {
        let mockProvider = MockRTCProvider()
        let manager = MediaRelayManager(rtcProvider: mockProvider)
        let config = try createValidConfig()
        
        // 启动前
        #expect(manager.currentRelayMode == nil)
        #expect(manager.destinationChannelCount == 0)
        #expect(!manager.allDestinationsConnected)
        #expect(manager.activeChannelCount == 0)
        
        // 启动后
        try await manager.startRelay(config: config)
        
        #expect(manager.currentRelayMode == .oneToMany)
        #expect(manager.destinationChannelCount == 2)
        #expect(manager.connectedChannelCount == 0) // 初始状态为 connecting
        #expect(manager.failedChannelCount == 0)
    }
}