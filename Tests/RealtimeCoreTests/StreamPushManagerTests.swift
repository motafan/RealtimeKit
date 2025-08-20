// StreamPushManagerTests.swift
// Unit tests for stream push management and control logic

import Testing
@testable import RealtimeCore

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
        func createRoom(roomId: String) async throws -> RTCRoom { 
            RTCRoom(roomId: roomId, roomName: roomId, createdAt: Date(), maxUsers: 100, isPrivate: false, metadata: [:])
        }
        func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {}
        func leaveRoom() async throws {}
        func switchUserRole(_ role: UserRole) async throws {}
        func muteMicrophone(_ muted: Bool) async throws {}
        nonisolated func isMicrophoneMuted() -> Bool { false }
        func stopLocalAudioStream() async throws {}
        func resumeLocalAudioStream() async throws {}
        nonisolated func isLocalAudioStreamActive() -> Bool { true }
        func setAudioMixingVolume(_ volume: Int) async throws {}
        nonisolated func getAudioMixingVolume() -> Int { 100 }
        func setPlaybackSignalVolume(_ volume: Int) async throws {}
        nonisolated func getPlaybackSignalVolume() -> Int { 100 }
        func setRecordingSignalVolume(_ volume: Int) async throws {}
        nonisolated func getRecordingSignalVolume() -> Int { 100 }
        
        func startStreamPush(config: StreamPushConfig) async throws {
            startCallCount += 1
            lastConfig = config
            if shouldFailStart {
                throw RealtimeError.streamPushStartFailed("Mock start failure")
            }
        }
        
        func stopStreamPush() async throws {
            stopCallCount += 1
            if shouldFailStop {
                throw RealtimeError.streamPushStopFailed("Mock stop failure")
            }
        }
        
        func updateStreamPushLayout(layout: StreamLayout) async throws {
            layoutUpdateCallCount += 1
            lastLayout = layout
            if shouldFailLayoutUpdate {
                throw RealtimeError.streamLayoutUpdateFailed("Mock layout update failure")
            }
        }
        
        func startMediaRelay(config: MediaRelayConfig) async throws {}
        func stopMediaRelay() async throws {}
        func updateMediaRelayChannels(config: MediaRelayConfig) async throws {}
        func pauseMediaRelay(toChannel: String) async throws {}
        func resumeMediaRelay(toChannel: String) async throws {}
        func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {}
        func disableVolumeIndicator() async throws {}
        nonisolated func setVolumeIndicatorHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void) {}
        nonisolated func setVolumeEventHandler(_ handler: @escaping @Sendable (VolumeEvent) -> Void) {}
        nonisolated func getCurrentVolumeInfos() -> [UserVolumeInfo] { [] }
        nonisolated func getVolumeInfo(for userId: String) -> UserVolumeInfo? { nil }
        func renewToken(_ newToken: String) async throws {}
        nonisolated func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {}
    }
    
    // MARK: - Test Helpers
    
    private func createValidConfig() throws -> StreamPushConfig {
        let layout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
        return try StreamPushConfig(
            pushUrl: "rtmp://example.com/live/stream",
            width: 1280,
            height: 720,
            bitrate: 2000,
            frameRate: 30,
            layout: layout
        )
    }
    
    private func createValidLayout() throws -> StreamLayout {
        let region = try UserRegion(
            userId: "user1",
            x: 0.0, y: 0.0,
            width: 1.0, height: 1.0,
            zOrder: 1,
            alpha: 1.0
        )
        return try StreamLayout(
            backgroundColor: "#000000",
            userRegions: [region]
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("Manager should initialize with correct default state")
    func testInitialization() async {
        let manager = StreamPushManager()
        
        #expect(manager.currentState == .stopped)
        #expect(manager.currentConfig == nil)
        #expect(manager.lastError == nil)
        #expect(manager.isActive == false)
        #expect(manager.canStart == true)
        #expect(manager.canStop == false)
    }
    
    @Test("Manager should configure with RTC provider")
    func testConfiguration() async {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        
        manager.configure(with: provider)
        
        // Configuration should not change state
        #expect(manager.currentState == .stopped)
    }
    
    // MARK: - Stream Push Start Tests
    
    @Test("Should start stream push successfully")
    func testStartStreamPushSuccess() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        manager.configure(with: provider)
        
        try await manager.startStreamPush(config: config)
        
        #expect(manager.currentState == .running)
        #expect(manager.currentConfig == config)
        #expect(manager.lastError == nil)
        #expect(manager.isActive == true)
        #expect(manager.canStart == false)
        #expect(manager.canStop == true)
        
        let startCount = provider.startCallCount
        let lastConfig = provider.lastConfig
        #expect(startCount == 1)
        #expect(lastConfig == config)
    }
    
    @Test("Should fail to start without provider")
    func testStartStreamPushWithoutProvider() async throws {
        let manager = StreamPushManager()
        let config = try createValidConfig()
        
        await #expect(throws: RealtimeError.self) {
            try await manager.startStreamPush(config: config)
        }
        
        #expect(manager.currentState == .stopped)
    }
    
    @Test("Should fail to start with invalid config")
    func testStartStreamPushWithInvalidConfig() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        
        manager.configure(with: provider)
        
        // Create invalid config (this should throw during validation)
        await #expect(throws: RealtimeError.self) {
            let invalidConfig = try StreamPushConfig(
                pushUrl: "", // Invalid empty URL
                width: 1280,
                height: 720,
                bitrate: 2000,
                frameRate: 30,
                layout: StreamLayout.singleUser
            )
            try await manager.startStreamPush(config: invalidConfig)
        }
    }
    
    @Test("Should handle provider start failure")
    func testStartStreamPushProviderFailure() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        provider.setShouldFailStart(true)
        manager.configure(with: provider)
        
        await #expect(throws: RealtimeError.self) {
            try await manager.startStreamPush(config: config)
        }
        
        #expect(manager.currentState == .failed)
        #expect(manager.lastError != nil)
    }
    
    @Test("Should not start when already running")
    func testStartStreamPushWhenRunning() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        manager.configure(with: provider)
        try await manager.startStreamPush(config: config)
        
        // Try to start again
        await #expect(throws: RealtimeError.self) {
            try await manager.startStreamPush(config: config)
        }
        
        let startCount = provider.startCallCount
        #expect(startCount == 1) // Should only be called once
    }
    
    // MARK: - Stream Push Stop Tests
    
    @Test("Should stop stream push successfully")
    func testStopStreamPushSuccess() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        manager.configure(with: provider)
        try await manager.startStreamPush(config: config)
        try await manager.stopStreamPush()
        
        #expect(manager.currentState == .stopped)
        #expect(manager.currentConfig == nil)
        #expect(manager.isActive == false)
        #expect(manager.canStart == true)
        #expect(manager.canStop == false)
        
        let stopCount = provider.stopCallCount
        #expect(stopCount == 1)
    }
    
    @Test("Should fail to stop without provider")
    func testStopStreamPushWithoutProvider() async throws {
        let manager = StreamPushManager()
        
        await #expect(throws: RealtimeError.self) {
            try await manager.stopStreamPush()
        }
    }
    
    @Test("Should fail to stop when not running")
    func testStopStreamPushWhenNotRunning() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        
        manager.configure(with: provider)
        
        await #expect(throws: RealtimeError.self) {
            try await manager.stopStreamPush()
        }
        
        let stopCount = provider.stopCallCount
        #expect(stopCount == 0)
    }
    
    @Test("Should handle provider stop failure")
    func testStopStreamPushProviderFailure() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        manager.configure(with: provider)
        try await manager.startStreamPush(config: config)
        
        provider.setShouldFailStop(true)
        
        await #expect(throws: RealtimeError.self) {
            try await manager.stopStreamPush()
        }
        
        #expect(manager.currentState == .failed)
        #expect(manager.lastError != nil)
    }
    
    // MARK: - Layout Update Tests
    
    @Test("Should update layout successfully")
    func testUpdateLayoutSuccess() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        let newLayout = try createValidLayout()
        
        manager.configure(with: provider)
        try await manager.startStreamPush(config: config)
        try await manager.updateLayout(newLayout)
        
        #expect(manager.currentState == .running)
        #expect(manager.currentConfig?.layout == newLayout)
        
        let updateCount = provider.layoutUpdateCallCount
        let lastLayout = provider.lastLayout
        #expect(updateCount == 1)
        #expect(lastLayout == newLayout)
    }
    
    @Test("Should fail to update layout when not running")
    func testUpdateLayoutWhenNotRunning() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let newLayout = try createValidLayout()
        
        manager.configure(with: provider)
        
        await #expect(throws: RealtimeError.self) {
            try await manager.updateLayout(newLayout)
        }
        
        let updateCount = provider.layoutUpdateCallCount
        #expect(updateCount == 0)
    }
    
    @Test("Should handle layout update failure")
    func testUpdateLayoutProviderFailure() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        let newLayout = try createValidLayout()
        
        manager.configure(with: provider)
        try await manager.startStreamPush(config: config)
        
        provider.setShouldFailLayoutUpdate(true)
        
        await #expect(throws: RealtimeError.self) {
            try await manager.updateLayout(newLayout)
        }
        
        #expect(manager.currentState == .failed)
        #expect(manager.lastError != nil)
    }
    
    // MARK: - Configuration Update Tests
    
    @Test("Should update configuration by restarting")
    func testUpdateConfiguration() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config1 = try createValidConfig()
        
        let config2 = try StreamPushConfig(
            pushUrl: "rtmp://example2.com/live/stream",
            width: 1920,
            height: 1080,
            bitrate: 4000,
            frameRate: 30,
            layout: StreamLayout.singleUser
        )
        
        manager.configure(with: provider)
        try await manager.startStreamPush(config: config1)
        try await manager.updateConfiguration(config2)
        
        #expect(manager.currentState == .running)
        #expect(manager.currentConfig == config2)
        
        let startCount = provider.startCallCount
        let stopCount = provider.stopCallCount
        #expect(startCount == 2) // Original start + restart
        #expect(stopCount == 1) // Stop before restart
    }
    
    // MARK: - State Management Tests
    
    @Test("State transitions should be correct")
    func testStateTransitions() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        var stateChanges: [(StreamPushState, StreamPushState)] = []
        manager.onStateChanged = { old, new in
            stateChanges.append((old, new))
        }
        
        manager.configure(with: provider)
        
        // Start stream push
        try await manager.startStreamPush(config: config)
        
        // Stop stream push
        try await manager.stopStreamPush()
        
        #expect(stateChanges.count == 4)
        #expect(stateChanges[0] == (.stopped, .starting))
        #expect(stateChanges[1] == (.starting, .running))
        #expect(stateChanges[2] == (.running, .stopping))
        #expect(stateChanges[3] == (.stopping, .stopped))
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Should reset error state")
    func testResetErrorState() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        manager.configure(with: provider)
        provider.setShouldFailStart(true)
        
        // Cause an error
        do {
            try await manager.startStreamPush(config: config)
        } catch {
            // Expected to fail
        }
        
        #expect(manager.currentState == .failed)
        #expect(manager.lastError != nil)
        
        // Reset error state
        manager.resetErrorState()
        
        #expect(manager.lastError == nil)
        #expect(manager.canStart == true)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Statistics should be tracked correctly")
    func testStatistics() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        let newLayout = try createValidLayout()
        
        manager.configure(with: provider)
        
        // Start stream push
        try await manager.startStreamPush(config: config)
        
        #expect(manager.statistics.startTime != nil)
        
        // Update layout
        try await manager.updateLayout(newLayout)
        
        #expect(manager.statistics.layoutUpdateCount == 1)
        
        // Stop stream push
        try await manager.stopStreamPush()
        
        #expect(manager.statistics.endTime != nil)
    }
    
    // MARK: - Utility Tests
    
    @Test("Duration calculation should work")
    func testDurationCalculation() async throws {
        let manager = StreamPushManager()
        let provider = MockRTCProvider()
        let config = try createValidConfig()
        
        manager.configure(with: provider)
        
        #expect(manager.currentDuration == 0)
        
        try await manager.startStreamPush(config: config)
        
        // Small delay to ensure duration > 0
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(manager.currentDuration > 0)
        
        try await manager.stopStreamPush()
        
        #expect(manager.currentDuration == 0)
    }
}

// MARK: - MockRTCProvider Extensions

extension StreamPushManagerTests.MockRTCProvider {
    func setShouldFailStart(_ shouldFail: Bool) {
        shouldFailStart = shouldFail
    }
    
    func setShouldFailStop(_ shouldFail: Bool) {
        shouldFailStop = shouldFail
    }
    
    func setShouldFailLayoutUpdate(_ shouldFail: Bool) {
        shouldFailLayoutUpdate = shouldFail
    }
}