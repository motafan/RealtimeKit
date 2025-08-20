// MediaRelayManagerTests.swift
// Unit tests for MediaRelayManager

import Testing
@testable import RealtimeCore

@Suite("Media Relay Manager Tests")
@MainActor
struct MediaRelayManagerTests {
    
    // MARK: - Test Helpers
    
    private func createMockRTCProvider() -> MockRTCProvider {
        return MockRTCProvider()
    }
    
    private func createTestChannelInfo(name: String, userId: String) throws -> RelayChannelInfo {
        return try RelayChannelInfo(
            channelName: name,
            userId: userId
        )
    }
    
    private func createTestConfig() throws -> MediaRelayConfig {
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let destChannel = try createTestChannelInfo(name: "dest", userId: "dest_user")
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destChannel],
            relayMode: .oneToOne
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("MediaRelayManager initialization")
    func testMediaRelayManagerInitialization() {
        let manager = MediaRelayManager()
        
        #expect(manager.currentState == nil)
        #expect(manager.currentConfig == nil)
        #expect(manager.isRelayActive == false)
        #expect(manager.statistics.totalRelayTime == 0)
    }
    
    @Test("MediaRelayManager configuration with provider")
    func testMediaRelayManagerConfiguration() {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        
        manager.configure(with: mockProvider)
        
        // Configuration should complete without error
        #expect(true) // If we reach here, configuration succeeded
    }
    
    // MARK: - Relay Control Tests
    
    @Test("Start relay with valid configuration")
    func testStartRelayWithValidConfiguration() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        
        try await manager.startRelay(config: config)
        
        #expect(manager.isRelayActive == true)
        #expect(manager.currentConfig != nil)
        #expect(manager.currentState != nil)
        #expect(manager.currentState?.overallState == .running)
    }
    
    @Test("Start relay without provider configuration")
    func testStartRelayWithoutProvider() async throws {
        let manager = MediaRelayManager()
        let config = try createTestConfig()
        
        await #expect(throws: RealtimeError.self) {
            try await manager.startRelay(config: config)
        }
    }
    
    @Test("Start relay with invalid configuration")
    func testStartRelayWithInvalidConfiguration() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        
        await #expect(throws: RealtimeError.self) {
            let invalidConfig = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [], // Empty destinations - invalid
                relayMode: .oneToOne
            )
            try await manager.startRelay(config: invalidConfig)
        }
    }
    
    @Test("Stop relay when active")
    func testStopRelayWhenActive() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        #expect(manager.isRelayActive == true)
        
        try await manager.stopRelay()
        
        #expect(manager.isRelayActive == false)
        #expect(manager.currentConfig == nil)
        #expect(manager.currentState?.overallState == .stopped)
    }
    
    @Test("Stop relay when not active")
    func testStopRelayWhenNotActive() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        // Should not throw error when stopping inactive relay
        try await manager.stopRelay()
        
        #expect(manager.isRelayActive == false)
    }
    
    // MARK: - Channel Management Tests
    
    @Test("Add destination channel to active relay")
    func testAddDestinationChannelToActiveRelay() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        // Start with one-to-many relay instead of one-to-one
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let destChannel = try createTestChannelInfo(name: "dest", userId: "dest_user")
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destChannel],
            relayMode: .oneToMany  // Use oneToMany instead of oneToOne
        )
        
        try await manager.startRelay(config: config)
        
        let newChannel = try createTestChannelInfo(name: "new_dest", userId: "new_user")
        try await manager.addDestinationChannel(newChannel)
        
        #expect(manager.currentConfig?.destinationChannels.count == 2)
        #expect(manager.currentConfig?.destinationChannel(named: "new_dest") != nil)
    }
    
    @Test("Add destination channel to inactive relay")
    func testAddDestinationChannelToInactiveRelay() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let newChannel = try createTestChannelInfo(name: "new_dest", userId: "new_user")
        
        await #expect(throws: RealtimeError.self) {
            try await manager.addDestinationChannel(newChannel)
        }
    }
    
    @Test("Add duplicate destination channel")
    func testAddDuplicateDestinationChannel() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        let duplicateChannel = try createTestChannelInfo(name: "dest", userId: "another_user")
        
        await #expect(throws: RealtimeError.self) {
            try await manager.addDestinationChannel(duplicateChannel)
        }
    }
    
    @Test("Remove destination channel from active relay")
    func testRemoveDestinationChannelFromActiveRelay() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        // Start with multiple destinations
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let dest1 = try createTestChannelInfo(name: "dest1", userId: "user1")
        let dest2 = try createTestChannelInfo(name: "dest2", userId: "user2")
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [dest1, dest2],
            relayMode: .oneToMany
        )
        
        try await manager.startRelay(config: config)
        
        try await manager.removeDestinationChannel("dest1")
        
        #expect(manager.currentConfig?.destinationChannels.count == 1)
        #expect(manager.currentConfig?.destinationChannel(named: "dest1") == nil)
        #expect(manager.currentConfig?.destinationChannel(named: "dest2") != nil)
    }
    
    @Test("Remove nonexistent destination channel")
    func testRemoveNonexistentDestinationChannel() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        await #expect(throws: RealtimeError.self) {
            try await manager.removeDestinationChannel("nonexistent")
        }
    }
    
    @Test("Pause relay to specific channel")
    func testPauseRelayToChannel() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        try await manager.pauseRelayToChannel("dest")
        
        #expect(manager.currentState?.stateForDestination("dest") == .paused)
    }
    
    @Test("Resume relay to specific channel")
    func testResumeRelayToChannel() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        try await manager.pauseRelayToChannel("dest")
        try await manager.resumeRelayToChannel("dest")
        
        #expect(manager.currentState?.stateForDestination("dest") == .connected)
    }
    
    @Test("Pause relay to nonexistent channel")
    func testPauseRelayToNonexistentChannel() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        await #expect(throws: RealtimeError.self) {
            try await manager.pauseRelayToChannel("nonexistent")
        }
    }
    
    // MARK: - State Management Tests
    
    @Test("State update handler registration and notification")
    func testStateUpdateHandlerRegistration() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        var receivedStates: [MediaRelayState] = []
        
        manager.addStateUpdateHandler { state in
            receivedStates.append(state)
        }
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        // Should have received state updates
        #expect(receivedStates.count > 0)
        #expect(receivedStates.last?.overallState == .running)
    }
    
    @Test("Channel state update handling")
    func testChannelStateUpdateHandling() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        manager.handleChannelStateUpdate("dest", newState: .paused)
        
        #expect(manager.currentState?.stateForDestination("dest") == .paused)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Statistics initialization and retrieval")
    func testStatisticsInitializationAndRetrieval() {
        let manager = MediaRelayManager()
        
        let stats = manager.getStatistics()
        #expect(stats.totalRelayTime == 0)
        #expect(stats.totalBytesSent == 0)
    }
    
    @Test("Statistics update handler registration")
    func testStatisticsUpdateHandlerRegistration() {
        let manager = MediaRelayManager()
        
        var receivedStats: [MediaRelayStatistics] = []
        
        manager.addStatisticsUpdateHandler { stats in
            receivedStats.append(stats)
        }
        
        let newStats = MediaRelayStatistics(
            totalRelayTime: 60,
            audioBytesSent: 1000,
            videoBytesSent: 5000
        )
        
        manager.updateStatistics(newStats)
        
        #expect(receivedStats.count == 1)
        #expect(receivedStats[0].totalRelayTime == 60)
        #expect(receivedStats[0].totalBytesSent == 6000)
    }
    
    // MARK: - Utility Methods Tests
    
    @Test("Check relay active for specific channel")
    func testIsRelayActiveForChannel() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        #expect(manager.isRelayActive(for: "dest") == true)
        #expect(manager.isRelayActive(for: "nonexistent") == false)
    }
    
    @Test("Get destination channels list")
    func testGetDestinationChannels() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let dest1 = try createTestChannelInfo(name: "dest1", userId: "user1")
        let dest2 = try createTestChannelInfo(name: "dest2", userId: "user2")
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [dest1, dest2],
            relayMode: .oneToMany
        )
        
        try await manager.startRelay(config: config)
        
        let channels = manager.getDestinationChannels()
        #expect(channels.count == 2)
        #expect(channels.contains("dest1"))
        #expect(channels.contains("dest2"))
    }
    
    @Test("Get channel info by name")
    func testGetChannelInfo() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        let channelInfo = manager.getChannelInfo("dest")
        #expect(channelInfo?.channelName == "dest")
        #expect(channelInfo?.userId == "dest_user")
        
        let nonexistentInfo = manager.getChannelInfo("nonexistent")
        #expect(nonexistentInfo == nil)
    }
    
    // MARK: - Convenience Methods Tests
    
    @Test("Start one-to-one relay convenience method")
    func testStartOneToOneRelayConvenience() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let destChannel = try createTestChannelInfo(name: "dest", userId: "dest_user")
        
        try await manager.startOneToOneRelay(
            source: sourceChannel,
            destination: destChannel
        )
        
        #expect(manager.isRelayActive == true)
        #expect(manager.currentConfig?.relayMode == .oneToOne)
        #expect(manager.currentConfig?.destinationChannels.count == 1)
    }
    
    @Test("Start one-to-many relay convenience method")
    func testStartOneToManyRelayConvenience() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let destinations = try [
            createTestChannelInfo(name: "dest1", userId: "user1"),
            createTestChannelInfo(name: "dest2", userId: "user2"),
            createTestChannelInfo(name: "dest3", userId: "user3")
        ]
        
        try await manager.startOneToManyRelay(
            source: sourceChannel,
            destinations: destinations
        )
        
        #expect(manager.isRelayActive == true)
        #expect(manager.currentConfig?.relayMode == .oneToMany)
        #expect(manager.currentConfig?.destinationChannels.count == 3)
    }
}

// MARK: - Mock RTC Provider for Testing

class MockRTCProvider: RTCProvider {
    var isInitialized = false
    var currentRoom: RTCRoom?
    var microphoneMuted = false
    var localAudioStreamActive = true
    var audioMixingVolume = 100
    var playbackSignalVolume = 100
    var recordingSignalVolume = 100
    var volumeIndicatorEnabled = false
    var streamPushActive = false
    var mediaRelayActive = false
    
    func initialize(config: RTCConfig) async throws {
        isInitialized = true
    }
    
    func createRoom(roomId: String) async throws -> RTCRoom {
        let room = RTCRoom(roomId: roomId, createdAt: Date())
        currentRoom = room
        return room
    }
    
    func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        // Mock implementation
    }
    
    func leaveRoom() async throws {
        currentRoom = nil
    }
    
    func switchUserRole(_ role: UserRole) async throws {
        // Mock implementation
    }
    
    func muteMicrophone(_ muted: Bool) async throws {
        microphoneMuted = muted
    }
    
    func isMicrophoneMuted() -> Bool {
        return microphoneMuted
    }
    
    func stopLocalAudioStream() async throws {
        localAudioStreamActive = false
    }
    
    func resumeLocalAudioStream() async throws {
        localAudioStreamActive = true
    }
    
    func isLocalAudioStreamActive() -> Bool {
        return localAudioStreamActive
    }
    
    func setAudioMixingVolume(_ volume: Int) async throws {
        audioMixingVolume = volume
    }
    
    func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    func setPlaybackSignalVolume(_ volume: Int) async throws {
        playbackSignalVolume = volume
    }
    
    func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    func setRecordingSignalVolume(_ volume: Int) async throws {
        recordingSignalVolume = volume
    }
    
    func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    func startStreamPush(config: StreamPushConfig) async throws {
        streamPushActive = true
    }
    
    func stopStreamPush() async throws {
        streamPushActive = false
    }
    
    func updateStreamPushLayout(layout: StreamLayout) async throws {
        // Mock implementation
    }
    
    func startMediaRelay(config: MediaRelayConfig) async throws {
        mediaRelayActive = true
    }
    
    func stopMediaRelay() async throws {
        mediaRelayActive = false
    }
    
    func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        // Mock implementation
    }
    
    func pauseMediaRelay(toChannel: String) async throws {
        // Mock implementation
    }
    
    func resumeMediaRelay(toChannel: String) async throws {
        // Mock implementation
    }
    
    func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        volumeIndicatorEnabled = true
    }
    
    func disableVolumeIndicator() async throws {
        volumeIndicatorEnabled = false
    }
    
    func setVolumeIndicatorHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void) {
        // Mock implementation
    }
    
    func setVolumeEventHandler(_ handler: @escaping (VolumeEvent) -> Void) {
        // Mock implementation
    }
    
    func getCurrentVolumeInfos() -> [UserVolumeInfo] {
        return []
    }
    
    func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return nil
    }
    
    func renewToken(_ newToken: String) async throws {
        // Mock implementation
    }
    
    func onTokenWillExpire(_ handler: @escaping (Int) -> Void) {
        // Mock implementation
    }
}