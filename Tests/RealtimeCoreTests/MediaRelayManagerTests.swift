// MediaRelayManagerTests.swift
// Comprehensive unit tests for MediaRelayManager

import Testing
import Foundation
@testable import RealtimeCore

@Suite("MediaRelayManager Tests")
@MainActor
struct MediaRelayManagerTests {
    
    // MARK: - Test Setup
    
    private func createManager() -> MediaRelayManager {
        return MediaRelayManager()
    }
    
    private func createTestConfig() throws -> MediaRelayConfig {
        let sourceChannel = RelayChannelInfo(
            channelName: "source_channel",
            token: "source_token_123",
            userId: "source_user"
        )
        
        let targetChannel1 = RelayChannelInfo(
            channelName: "target_channel_1",
            token: "target_token_1",
            userId: "target_user_1"
        )
        
        let targetChannel2 = RelayChannelInfo(
            channelName: "target_channel_2",
            token: "target_token_2",
            userId: "target_user_2"
        )
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [targetChannel1, targetChannel2]
        )
    }
    
    private func createSingleTargetConfig() throws -> MediaRelayConfig {
        let sourceChannel = RelayChannelInfo(
            channelName: "source_channel",
            token: "source_token_123",
            userId: "source_user"
        )
        
        let targetChannel = RelayChannelInfo(
            channelName: "target_channel",
            token: "target_token",
            userId: "target_user"
        )
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [targetChannel]
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("Manager initialization")
    func testManagerInitialization() {
        let manager = createManager()
        
        #expect(manager.currentState == nil)
        #expect(manager.currentConfig == nil)
        #expect(manager.isActive == false)
        #expect(manager.activeChannels.isEmpty)
        #expect(manager.channelStates.isEmpty)
        #expect(manager.statistics.totalRelays == 0)
    }
    
    // MARK: - Media Relay Start Tests
    
    @Test("Start media relay with valid config")
    func testStartMediaRelayWithValidConfig() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var stateChanges: [MediaRelayState] = []
        manager.onStateChanged = { state in
            stateChanges.append(state)
        }
        
        try await manager.startMediaRelay(config: config)
        
        #expect(manager.isActive == true)
        #expect(manager.currentConfig?.sourceChannel.channelName == "source_channel")
        #expect(manager.currentConfig?.destinationChannels.count == 2)
        #expect(manager.activeChannels.count == 2)
        #expect(stateChanges.contains { $0.isActive })
    }
    
    @Test("Start media relay when already active")
    func testStartMediaRelayWhenAlreadyActive() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start first relay
        try await manager.startMediaRelay(config: config)
        #expect(manager.isActive == true)
        
        // Try to start another relay
        do {
            try await manager.startMediaRelay(config: config)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .alreadyInState(.active))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Start media relay with invalid config")
    func testStartMediaRelayWithInvalidConfig() async {
        let manager = createManager()
        
        do {
            // Create config with empty destination channels
            let sourceChannel = RelayChannelInfo(
                channelName: "source",
                token: "token",
                userId: "user"
            )
            
            let invalidConfig = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [] // Empty destinations
            )
            
            try await manager.startMediaRelay(config: invalidConfig)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(manager.isActive == false)
            #expect(manager.currentConfig == nil)
        }
    }
    
    // MARK: - Media Relay Stop Tests
    
    @Test("Stop media relay when active")
    func testStopMediaRelayWhenActive() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var stateChanges: [MediaRelayState] = []
        manager.onStateChanged = { state in
            stateChanges.append(state)
        }
        
        // Start relay
        try await manager.startMediaRelay(config: config)
        #expect(manager.isActive == true)
        
        // Stop relay
        try await manager.stopMediaRelay()
        
        #expect(manager.isActive == false)
        #expect(manager.currentState == nil)
        #expect(manager.activeChannels.isEmpty)
        #expect(stateChanges.contains { !$0.isActive })
    }
    
    @Test("Stop media relay when not active")
    func testStopMediaRelayWhenNotActive() async {
        let manager = createManager()
        
        do {
            try await manager.stopMediaRelay()
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .notInState(.active))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Channel Management Tests
    
    @Test("Add destination channel during relay")
    func testAddDestinationChannelDuringRelay() async throws {
        let manager = createManager()
        let config = try createSingleTargetConfig()
        
        // Start relay with one target
        try await manager.startMediaRelay(config: config)
        #expect(manager.activeChannels.count == 1)
        
        // Add another target channel
        let newChannel = RelayChannelInfo(
            channelName: "new_target_channel",
            token: "new_target_token",
            userId: "new_target_user"
        )
        
        try await manager.addDestinationChannel(newChannel)
        
        #expect(manager.activeChannels.count == 2)
        #expect(manager.activeChannels.contains("new_target_channel"))
        #expect(manager.channelStates["new_target_channel"] == .connected)
    }
    
    @Test("Remove destination channel during relay")
    func testRemoveDestinationChannelDuringRelay() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start relay with two targets
        try await manager.startMediaRelay(config: config)
        #expect(manager.activeChannels.count == 2)
        
        // Remove one target channel
        try await manager.removeDestinationChannel("target_channel_1")
        
        #expect(manager.activeChannels.count == 1)
        #expect(!manager.activeChannels.contains("target_channel_1"))
        #expect(manager.activeChannels.contains("target_channel_2"))
    }
    
    @Test("Update destination channels")
    func testUpdateDestinationChannels() async throws {
        let manager = createManager()
        let config = try createSingleTargetConfig()
        
        // Start relay
        try await manager.startMediaRelay(config: config)
        
        // Update with new set of channels
        let newChannel1 = RelayChannelInfo(
            channelName: "updated_channel_1",
            token: "updated_token_1",
            userId: "updated_user_1"
        )
        
        let newChannel2 = RelayChannelInfo(
            channelName: "updated_channel_2",
            token: "updated_token_2",
            userId: "updated_user_2"
        )
        
        let updatedConfig = try MediaRelayConfig(
            sourceChannel: config.sourceChannel,
            destinationChannels: [newChannel1, newChannel2]
        )
        
        try await manager.updateDestinationChannels(updatedConfig)
        
        #expect(manager.activeChannels.count == 2)
        #expect(manager.activeChannels.contains("updated_channel_1"))
        #expect(manager.activeChannels.contains("updated_channel_2"))
        #expect(!manager.activeChannels.contains("target_channel"))
    }
    
    // MARK: - Channel State Management Tests
    
    @Test("Pause and resume channel relay")
    func testPauseAndResumeChannelRelay() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start relay
        try await manager.startMediaRelay(config: config)
        
        let channelName = "target_channel_1"
        #expect(manager.channelStates[channelName] == .connected)
        
        // Pause channel
        try await manager.pauseChannelRelay(channelName)
        #expect(manager.channelStates[channelName] == .paused)
        
        // Resume channel
        try await manager.resumeChannelRelay(channelName)
        #expect(manager.channelStates[channelName] == .connected)
    }
    
    @Test("Pause non-existent channel")
    func testPauseNonExistentChannel() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        try await manager.startMediaRelay(config: config)
        
        do {
            try await manager.pauseChannelRelay("non_existent_channel")
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            if case .channelNotFound(let channelName) = error {
                #expect(channelName == "non_existent_channel")
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Channel connection state tracking")
    func testChannelConnectionStateTracking() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var channelStateChanges: [(String, RelayChannelState)] = []
        manager.onChannelStateChanged = { channelName, state in
            channelStateChanges.append((channelName, state))
        }
        
        try await manager.startMediaRelay(config: config)
        
        // Simulate connection state changes
        manager.handleChannelConnectionChange("target_channel_1", state: .connecting)
        manager.handleChannelConnectionChange("target_channel_1", state: .connected)
        manager.handleChannelConnectionChange("target_channel_2", state: .error)
        
        #expect(channelStateChanges.count >= 3)
        #expect(channelStateChanges.contains { $0.0 == "target_channel_1" && $0.1 == .connecting })
        #expect(channelStateChanges.contains { $0.0 == "target_channel_1" && $0.1 == .connected })
        #expect(channelStateChanges.contains { $0.0 == "target_channel_2" && $0.1 == .error })
    }
    
    // MARK: - Statistics Tests
    
    @Test("Relay statistics tracking")
    func testRelayStatisticsTracking() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start and stop multiple relays
        for _ in 1...3 {
            try await manager.startMediaRelay(config: config)
            
            // Simulate some relay time
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            try await manager.stopMediaRelay()
        }
        
        let stats = manager.statistics
        #expect(stats.totalRelays == 3)
        #expect(stats.totalDuration > 0.2) // At least 0.2 seconds total
        #expect(stats.averageRelayDuration > 0.05) // At least 0.05 seconds average
    }
    
    @Test("Channel statistics tracking")
    func testChannelStatisticsTracking() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        try await manager.startMediaRelay(config: config)
        
        // Simulate data transfer
        manager.updateChannelStatistics("target_channel_1", bytesTransferred: 1024, packetsTransferred: 10)
        manager.updateChannelStatistics("target_channel_2", bytesTransferred: 2048, packetsTransferred: 20)
        
        let channel1Stats = manager.getChannelStatistics("target_channel_1")
        let channel2Stats = manager.getChannelStatistics("target_channel_2")
        
        #expect(channel1Stats?.bytesTransferred == 1024)
        #expect(channel1Stats?.packetsTransferred == 10)
        #expect(channel2Stats?.bytesTransferred == 2048)
        #expect(channel2Stats?.packetsTransferred == 20)
        
        try await manager.stopMediaRelay()
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle channel connection failure")
    func testHandleChannelConnectionFailure() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var errorReceived: RealtimeError?
        manager.onChannelError = { channelName, error in
            errorReceived = error
        }
        
        try await manager.startMediaRelay(config: config)
        
        // Simulate connection failure
        let connectionError = RealtimeError.networkError("Channel connection failed")
        manager.handleChannelError("target_channel_1", error: connectionError)
        
        #expect(errorReceived != nil)
        #expect(manager.channelStates["target_channel_1"] == .error)
    }
    
    @Test("Automatic channel reconnection")
    func testAutomaticChannelReconnection() async throws {
        let manager = createManager()
        manager.enableAutoReconnect(maxAttempts: 3, retryDelay: 0.1)
        
        let config = try createTestConfig()
        
        var reconnectionAttempts: [(String, RealtimeError)] = []
        manager.onChannelReconnectionAttempt = { channelName, error in
            reconnectionAttempts.append((channelName, error))
        }
        
        try await manager.startMediaRelay(config: config)
        
        // Simulate transient connection failure
        let transientError = RealtimeError.networkError("Temporary connection loss")
        manager.handleChannelError("target_channel_1", error: transientError)
        
        // Wait for reconnection attempts
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(reconnectionAttempts.count > 0)
        #expect(reconnectionAttempts.first?.0 == "target_channel_1")
        
        try await manager.stopMediaRelay()
    }
    
    @Test("Handle source channel failure")
    func testHandleSourceChannelFailure() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var relayFailureReceived = false
        manager.onRelayFailure = { error in
            relayFailureReceived = true
        }
        
        try await manager.startMediaRelay(config: config)
        
        // Simulate source channel failure
        let sourceError = RealtimeError.providerError("Source channel disconnected", underlying: nil)
        manager.handleSourceChannelError(sourceError)
        
        #expect(relayFailureReceived == true)
        #expect(manager.currentState?.isActive == false)
    }
    
    // MARK: - Configuration Validation Tests
    
    @Test("Validate relay configuration")
    func testValidateRelayConfiguration() throws {
        // Valid configuration
        let validConfig = try createTestConfig()
        #expect(validConfig.isValid)
        
        // Invalid configuration - empty destination channels
        let sourceChannel = RelayChannelInfo(
            channelName: "source",
            token: "token",
            userId: "user"
        )
        
        #expect(throws: RealtimeError.self) {
            let _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: []
            )
        }
        
        // Invalid configuration - too many destination channels
        let manyChannels = (1...20).map { i in
            RelayChannelInfo(
                channelName: "channel_\(i)",
                token: "token_\(i)",
                userId: "user_\(i)"
            )
        }
        
        #expect(throws: RealtimeError.self) {
            let _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: manyChannels
            )
        }
    }
    
    @Test("Validate channel info")
    func testValidateChannelInfo() {
        // Valid channel info
        let validChannel = RelayChannelInfo(
            channelName: "test_channel",
            token: "valid_token_123",
            userId: "test_user"
        )
        #expect(validChannel.isValid)
        
        // Invalid channel info - empty channel name
        let invalidChannel1 = RelayChannelInfo(
            channelName: "",
            token: "valid_token",
            userId: "test_user"
        )
        #expect(!invalidChannel1.isValid)
        
        // Invalid channel info - empty token
        let invalidChannel2 = RelayChannelInfo(
            channelName: "test_channel",
            token: "",
            userId: "test_user"
        )
        #expect(!invalidChannel2.isValid)
        
        // Invalid channel info - empty user ID
        let invalidChannel3 = RelayChannelInfo(
            channelName: "test_channel",
            token: "valid_token",
            userId: ""
        )
        #expect(!invalidChannel3.isValid)
    }
    
    // MARK: - Performance Tests
    
    @Test("Relay start/stop performance")
    func testRelayStartStopPerformance() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        let startTime = Date()
        
        // Perform multiple start/stop cycles
        for _ in 1...5 {
            try await manager.startMediaRelay(config: config)
            try await manager.stopMediaRelay()
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 5.0) // 5 seconds for 5 cycles
    }
    
    @Test("Channel management performance")
    func testChannelManagementPerformance() async throws {
        let manager = createManager()
        let config = try createSingleTargetConfig()
        
        try await manager.startMediaRelay(config: config)
        
        let startTime = Date()
        
        // Add and remove channels rapidly
        for i in 1...10 {
            let channel = RelayChannelInfo(
                channelName: "temp_channel_\(i)",
                token: "temp_token_\(i)",
                userId: "temp_user_\(i)"
            )
            
            try await manager.addDestinationChannel(channel)
            try await manager.removeDestinationChannel("temp_channel_\(i)")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 3.0) // 3 seconds for 10 add/remove cycles
        
        try await manager.stopMediaRelay()
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("Concurrent channel operations")
    func testConcurrentChannelOperations() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        try await manager.startMediaRelay(config: config)
        
        // Perform concurrent channel operations
        await withTaskGroup(of: Void.self) { group in
            // Concurrent pause/resume operations
            for i in 1...5 {
                group.addTask {
                    do {
                        if i % 2 == 0 {
                            try await manager.pauseChannelRelay("target_channel_1")
                        } else {
                            try await manager.resumeChannelRelay("target_channel_1")
                        }
                    } catch {
                        // Some operations might fail due to concurrent access
                    }
                }
            }
            
            // Concurrent statistics updates
            for i in 1...5 {
                group.addTask {
                    manager.updateChannelStatistics("target_channel_2", bytesTransferred: i * 100, packetsTransferred: i * 10)
                }
            }
        }
        
        // Should handle concurrent operations without crashing
        #expect(manager.isActive == true)
        
        try await manager.stopMediaRelay()
    }
    
    // MARK: - State Management Tests
    
    @Test("Relay state transitions")
    func testRelayStateTransitions() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var stateHistory: [MediaRelayState?] = []
        manager.onStateChanged = { state in
            stateHistory.append(state)
        }
        
        // Start relay
        try await manager.startMediaRelay(config: config)
        
        // Pause a channel
        try await manager.pauseChannelRelay("target_channel_1")
        
        // Resume channel
        try await manager.resumeChannelRelay("target_channel_1")
        
        // Stop relay
        try await manager.stopMediaRelay()
        
        #expect(stateHistory.count >= 2) // At least start and stop states
        #expect(stateHistory.first?.isActive == true)
        #expect(stateHistory.last?.isActive == false)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Manager cleanup on deallocation")
    func testManagerCleanupOnDeallocation() async throws {
        var manager: MediaRelayManager? = createManager()
        
        weak var weakManager = manager
        
        let config = try createTestConfig()
        try await manager?.startMediaRelay(config: config)
        try await manager?.stopMediaRelay()
        
        manager = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakManager == nil)
    }
    
    // MARK: - Integration Tests
    
    @Test("End-to-end media relay lifecycle")
    func testEndToEndMediaRelayLifecycle() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var events: [String] = []
        
        manager.onStateChanged = { state in
            events.append("state: \(state?.isActive == true ? "active" : "inactive")")
        }
        
        manager.onChannelStateChanged = { channelName, state in
            events.append("channel: \(channelName) -> \(state)")
        }
        
        manager.onChannelError = { channelName, error in
            events.append("error: \(channelName) -> \(error.localizedDescription)")
        }
        
        // Complete lifecycle
        try await manager.startMediaRelay(config: config)
        
        // Add a new channel
        let newChannel = RelayChannelInfo(
            channelName: "additional_channel",
            token: "additional_token",
            userId: "additional_user"
        )
        try await manager.addDestinationChannel(newChannel)
        
        // Pause and resume a channel
        try await manager.pauseChannelRelay("target_channel_1")
        try await manager.resumeChannelRelay("target_channel_1")
        
        // Update statistics
        manager.updateChannelStatistics("target_channel_1", bytesTransferred: 5000, packetsTransferred: 50)
        
        // Simulate some relay time
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        try await manager.stopMediaRelay()
        
        // Verify events occurred
        #expect(events.count > 0)
        #expect(events.contains { $0.contains("active") })
        #expect(events.contains { $0.contains("inactive") })
        
        // Verify final state
        #expect(manager.isActive == false)
        #expect(manager.statistics.totalRelays == 1)
        #expect(manager.statistics.totalDuration > 0.1)
        
        // Verify channel statistics
        let channel1Stats = manager.getChannelStatistics("target_channel_1")
        #expect(channel1Stats?.bytesTransferred == 5000)
        #expect(channel1Stats?.packetsTransferred == 50)
    }
}