import Testing
@testable import RealtimeCore

/// 转推流管理器测试
/// 需求: 7.2, 7.3, 7.4 - 转推流控制逻辑和状态转换测试
@Suite("Stream Push Manager Tests")
@MainActor
struct StreamPushManagerTests {
    
    // MARK: - Mock RTC Provider
    
    class MockRTCProvider: RTCProvider {
        var shouldFailStart = false
        var shouldFailStop = false
        var shouldFailLayoutUpdate = false
        var startCallCount = 0
        var stopCallCount = 0
        var layoutUpdateCallCount = 0
        var lastConfig: StreamPushConfig?
        var lastLayout: StreamLayout?
        
        func initialize(config: RTCConfig) async throws {}
        func createRoom(roomId: String) async throws -> RTCRoom { fatalError("Not implemented") }
        func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {}
        func leaveRoom() async throws {}
        func switchUserRole(_ role: UserRole) async throws {}
        func muteMicrophone(_ muted: Bool) async throws {}
        func isMicrophoneMuted() -> Bool { false }
        func stopLocalAudioStream() async throws {}
        func resumeLocalAudioStream() async throws {}
        func isLocalAudioStreamActive() -> Bool { true }
        func setAudioMixingVolume(_ volume: Int) async throws {}
        func getAudioMixingVolume() -> Int { 100 }
        func setPlaybackSignalVolume(_ volume: Int) async throws {}
        func getPlaybackSignalVolume() -> Int { 100 }
        func setRecordingSignalVolume(_ volume: Int) async throws {}
        func getRecordingSignalVolume() -> Int { 100 }
        func startMediaRelay(config: MediaRelayConfig) async throws {}
        func stopMediaRelay() async throws {}
        func updateMediaRelayChannels(config: MediaRelayConfig) async throws {}
        func pauseMediaRelay(toChannel: String) async throws {}
        func resumeMediaRelay(toChannel: String) async throws {}
        func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {}
        func disableVolumeIndicator() async throws {}
        func setVolumeIndicatorHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void) {}
        func setVolumeEventHandler(_ handler: @escaping (VolumeEvent) -> Void) {}
        func getCurrentVolumeInfos() -> [UserVolumeInfo] { [] }
        func getVolumeInfo(for userId: String) -> UserVolumeInfo? { nil }
        func renewToken(_ newToken: String) async throws {}
        func onTokenWillExpire(_ handler: @escaping (Int) -> Void) {}
        
        func startStreamPush(config: StreamPushConfig) async throws {
            startCallCount += 1
            lastConfig = config
            if shouldFailStart {
                throw StreamPushError.startFailed("Mock start failure")
            }
        }
        
        func stopStreamPush() async throws {
            stopCallCount += 1
            if shouldFailStop {
                throw StreamPushError.stopFailed("Mock stop failure")
            }
        }
        
        func updateStreamPushLayout(layout: StreamLayout) async throws {
            layoutUpdateCallCount += 1
            lastLayout = layout
            if shouldFailLayoutUpdate {
                throw StreamPushError.layoutUpdateFailed("Mock layout update failure")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createValidConfig() throws -> StreamPushConfig {
        return try StreamPushConfig(
            url: "rtmp://live.example.com/live/stream123",
            layout: StreamLayout(canvasWidth: 1280, canvasHeight: 720),
            audioConfig: StreamAudioConfig(),
            videoConfig: StreamVideoConfig()
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("Stream push manager should initialize with correct default state")
    func testInitialization() async throws {
        let manager = StreamPushManager()
        
        #expect(manager.state == .stopped)
        #expect(manager.currentConfig == nil)
        #expect(manager.lastError == nil)
        #expect(manager.startTime == nil)
    }
    
    @Test("Stream push manager should accept RTC provider")
    func testSetRTCProvider() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        
        manager.setRTCProvider(provider)
        
        // Provider should be set (we can't directly test this as it's private)
        // But we can test that operations work with the provider
        let config = try createValidConfig()
        try await manager.startStreamPush(config: config)
        
        #expect(manager.state == .running)
        #expect(provider.startCallCount == 1)
    }
    
    // MARK: - Start Stream Push Tests
    
    @Test("Should start stream push successfully with valid configuration")
    func testStartStreamPushSuccess() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        try await manager.startStreamPush(config: config)
        
        #expect(manager.state == .running)
        #expect(manager.currentConfig?.url == config.url)
        #expect(manager.lastError == nil)
        #expect(manager.startTime != nil)
        #expect(provider.startCallCount == 1)
        #expect(provider.lastConfig?.url == config.url)
    }
    
    @Test("Should fail to start stream push without RTC provider")
    func testStartStreamPushWithoutProvider() async throws {
        let manager = StreamPushManager()
        let config = try createValidConfig()
        
        await #expect(throws: StreamPushError.self) {
            try await manager.startStreamPush(config: config)
        }
        
        #expect(manager.state == .stopped)
    }
    
    @Test("Should fail to start stream push with invalid configuration")
    func testStartStreamPushWithInvalidConfig() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        // Create invalid config with empty URL
        await #expect(throws: StreamPushError.self) {
            try await manager.startStreamPush(config: try StreamPushConfig(url: ""))
        }
        
        #expect(manager.state == .stopped)
        #expect(provider.startCallCount == 0)
    }
    
    @Test("Should handle start stream push failure from provider")
    func testStartStreamPushProviderFailure() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        provider.shouldFailStart = true
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        await #expect(throws: StreamPushError.self) {
            try await manager.startStreamPush(config: config)
        }
        
        #expect(manager.state == .failed)
        #expect(manager.lastError != nil)
        #expect(provider.startCallCount == 1)
    }
    
    @Test("Should not start stream push when already running")
    func testStartStreamPushWhenRunning() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        // Start first stream
        try await manager.startStreamPush(config: config)
        #expect(manager.state == .running)
        
        // Try to start second stream
        await #expect(throws: StreamPushError.self) {
            try await manager.startStreamPush(config: config)
        }
        
        #expect(provider.startCallCount == 1) // Should not call provider again
    }
    
    // MARK: - Stop Stream Push Tests
    
    @Test("Should stop stream push successfully")
    func testStopStreamPushSuccess() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        // Start stream first
        try await manager.startStreamPush(config: config)
        #expect(manager.state == .running)
        
        // Stop stream
        try await manager.stopStreamPush()
        
        #expect(manager.state == .stopped)
        #expect(manager.startTime == nil)
        #expect(provider.stopCallCount == 1)
    }
    
    @Test("Should not stop stream push when not running")
    func testStopStreamPushWhenNotRunning() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        await #expect(throws: StreamPushError.self) {
            try await manager.stopStreamPush()
        }
        
        #expect(manager.state == .stopped)
        #expect(provider.stopCallCount == 0)
    }
    
    @Test("Should handle stop stream push failure from provider")
    func testStopStreamPushProviderFailure() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        // Start stream first
        try await manager.startStreamPush(config: config)
        #expect(manager.state == .running)
        
        // Make provider fail on stop
        provider.shouldFailStop = true
        
        await #expect(throws: StreamPushError.self) {
            try await manager.stopStreamPush()
        }
        
        #expect(manager.state == .failed)
        #expect(manager.lastError != nil)
        #expect(provider.stopCallCount == 1)
    }
    
    // MARK: - Update Layout Tests
    
    @Test("Should update stream layout successfully")
    func testUpdateStreamLayoutSuccess() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        // Start stream first
        try await manager.startStreamPush(config: config)
        #expect(manager.state == .running)
        
        // Update layout
        let newLayout = StreamLayout(canvasWidth: 1920, canvasHeight: 1080)
        try await manager.updateStreamLayout(newLayout)
        
        #expect(manager.currentConfig?.layout.canvasWidth == 1920)
        #expect(manager.currentConfig?.layout.canvasHeight == 1080)
        #expect(provider.layoutUpdateCallCount == 1)
        #expect(provider.lastLayout?.canvasWidth == 1920)
    }
    
    @Test("Should not update layout when not running")
    func testUpdateStreamLayoutWhenNotRunning() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let layout = StreamLayout(canvasWidth: 1920, canvasHeight: 1080)
        
        await #expect(throws: StreamPushError.self) {
            try await manager.updateStreamLayout(layout)
        }
        
        #expect(provider.layoutUpdateCallCount == 0)
    }
    
    @Test("Should handle layout update failure from provider")
    func testUpdateStreamLayoutProviderFailure() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        // Start stream first
        try await manager.startStreamPush(config: config)
        #expect(manager.state == .running)
        
        // Make provider fail on layout update
        provider.shouldFailLayoutUpdate = true
        
        let newLayout = StreamLayout(canvasWidth: 1920, canvasHeight: 1080)
        
        await #expect(throws: StreamPushError.self) {
            try await manager.updateStreamLayout(newLayout)
        }
        
        #expect(manager.lastError != nil)
        #expect(provider.layoutUpdateCallCount == 1)
    }
    
    // MARK: - State Management Tests
    
    @Test("Stream push state should have correct transition capabilities")
    func testStreamPushStateTransitions() async throws {
        // Test canStart
        #expect(StreamPushState.stopped.canStart == true)
        #expect(StreamPushState.failed.canStart == true)
        #expect(StreamPushState.running.canStart == false)
        #expect(StreamPushState.starting.canStart == false)
        #expect(StreamPushState.stopping.canStart == false)
        
        // Test canStop
        #expect(StreamPushState.running.canStop == true)
        #expect(StreamPushState.starting.canStop == true)
        #expect(StreamPushState.stopped.canStop == false)
        #expect(StreamPushState.failed.canStop == false)
        #expect(StreamPushState.stopping.canStop == false)
        
        // Test canUpdateLayout
        #expect(StreamPushState.running.canUpdateLayout == true)
        #expect(StreamPushState.stopped.canUpdateLayout == false)
        #expect(StreamPushState.starting.canUpdateLayout == false)
        #expect(StreamPushState.stopping.canUpdateLayout == false)
        #expect(StreamPushState.failed.canUpdateLayout == false)
    }
    
    @Test("Should reset error state correctly")
    func testResetError() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        provider.shouldFailStart = true
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        // Cause an error
        await #expect(throws: StreamPushError.self) {
            try await manager.startStreamPush(config: config)
        }
        
        #expect(manager.state == .failed)
        #expect(manager.lastError != nil)
        
        // Reset error
        manager.resetError()
        
        #expect(manager.state == .stopped)
        #expect(manager.lastError == nil)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Should initialize statistics correctly")
    func testStatisticsInitialization() async throws {
        let stats = StreamPushStatistics()
        
        #expect(stats.totalDuration == 0)
        #expect(stats.layoutUpdateCount == 0)
        #expect(stats.errorCount == 0)
        #expect(stats.retryCount == 0)
        #expect(stats.averageBitrate == 0)
        #expect(stats.frameDropRate == 0)
        #expect(stats.networkLatency == 0)
    }
    
    @Test("Should reset statistics correctly")
    func testStatisticsReset() async throws {
        var stats = StreamPushStatistics()
        
        // Set some values
        stats.totalDuration = 100
        stats.layoutUpdateCount = 5
        stats.errorCount = 2
        stats.averageBitrate = 1000
        
        // Reset
        stats.reset()
        
        #expect(stats.totalDuration == 0)
        #expect(stats.layoutUpdateCount == 0)
        #expect(stats.errorCount == 0)
        #expect(stats.averageBitrate == 0)
    }
    
    @Test("Should update statistics correctly")
    func testStatisticsUpdate() async throws {
        var stats = StreamPushStatistics()
        
        stats.update(
            duration: 120,
            bitrate: 2000,
            frameDropRate: 0.5,
            latency: 50
        )
        
        #expect(stats.totalDuration == 120)
        #expect(stats.averageBitrate == 2000)
        #expect(stats.frameDropRate == 0.5)
        #expect(stats.networkLatency == 50)
    }
    
    @Test("Should track layout updates in statistics")
    func testLayoutUpdateStatistics() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        manager.setRTCProvider(provider)
        
        let config = try createValidConfig()
        
        // Start stream
        try await manager.startStreamPush(config: config)
        
        let initialStats = manager.getStatistics()
        #expect(initialStats.layoutUpdateCount == 0)
        
        // Update layout
        let newLayout = StreamLayout(canvasWidth: 1920, canvasHeight: 1080)
        try await manager.updateStreamLayout(newLayout)
        
        let updatedStats = manager.getStatistics()
        #expect(updatedStats.layoutUpdateCount == 1)
    }
}