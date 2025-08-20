// MediaRelayIntegrationTests.swift
// Integration tests for media relay control functionality

import Testing
@testable import RealtimeCore

@Suite("Media Relay Integration Tests")
@MainActor
struct MediaRelayIntegrationTests {
    
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
    
    // MARK: - Integration Tests
    
    @Test("Complete media relay lifecycle")
    func testCompleteMediaRelayLifecycle() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        
        // Configure manager with provider
        manager.configure(with: mockProvider)
        
        // Create relay configuration
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let destinations = try [
            createTestChannelInfo(name: "dest1", userId: "user1"),
            createTestChannelInfo(name: "dest2", userId: "user2")
        ]
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinations,
            relayMode: .oneToMany,
            enableAudio: true,
            enableVideo: true
        )
        
        // Start relay
        try await manager.startRelay(config: config)
        
        // Verify relay is active
        #expect(manager.isRelayActive == true)
        #expect(manager.currentConfig?.destinationChannels.count == 2)
        #expect(manager.currentState?.overallState == .running)
        #expect(mockProvider.mediaRelayActive == true)
        
        // Test channel management
        let newChannel = try createTestChannelInfo(name: "dest3", userId: "user3")
        try await manager.addDestinationChannel(newChannel)
        
        #expect(manager.currentConfig?.destinationChannels.count == 3)
        #expect(manager.getDestinationChannels().contains("dest3"))
        
        // Test pause/resume functionality
        try await manager.pauseRelayToChannel("dest2")
        #expect(manager.currentState?.stateForDestination("dest2") == .paused)
        
        try await manager.resumeRelayToChannel("dest2")
        #expect(manager.currentState?.stateForDestination("dest2") == .connected)
        
        // Remove a channel
        try await manager.removeDestinationChannel("dest1")
        #expect(manager.currentConfig?.destinationChannels.count == 2)
        #expect(!manager.getDestinationChannels().contains("dest1"))
        
        // Stop relay
        try await manager.stopRelay()
        
        // Verify relay is stopped
        #expect(manager.isRelayActive == false)
        #expect(manager.currentConfig == nil)
        #expect(manager.currentState?.overallState == .stopped)
        #expect(mockProvider.mediaRelayActive == false)
    }
    
    @Test("Media relay state monitoring")
    func testMediaRelayStateMonitoring() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        var stateUpdates: [MediaRelayState] = []
        
        // Register state update handler
        manager.addStateUpdateHandler { state in
            stateUpdates.append(state)
        }
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        // Simulate state changes from provider
        manager.handleChannelStateUpdate("dest", newState: .connecting)
        manager.handleChannelStateUpdate("dest", newState: .connected)
        manager.handleChannelStateUpdate("dest", newState: .paused)
        manager.handleChannelStateUpdate("dest", newState: .connected)
        
        // Verify state updates were received
        #expect(stateUpdates.count >= 4)
        
        // Verify final state
        #expect(manager.currentState?.stateForDestination("dest") == .connected)
    }
    
    @Test("Media relay statistics tracking")
    func testMediaRelayStatisticsTracking() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        var statisticsUpdates: [MediaRelayStatistics] = []
        
        // Register statistics update handler
        manager.addStatisticsUpdateHandler { stats in
            statisticsUpdates.append(stats)
        }
        
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        // Simulate statistics updates
        let channelStats = RelayChannelStatistics(
            channelName: "dest",
            connectionTime: 60,
            audioBytesSent: 1000,
            videoBytesSent: 5000,
            audioPacketsSent: 100,
            videoPacketsSent: 200
        )
        
        let newStats = MediaRelayStatistics(
            totalRelayTime: 60,
            audioBytesSent: 1000,
            videoBytesSent: 5000,
            audioPacketsSent: 100,
            videoPacketsSent: 200,
            destinationStats: ["dest": channelStats]
        )
        
        manager.updateStatistics(newStats)
        
        // Verify statistics were updated
        #expect(statisticsUpdates.count >= 1)
        #expect(manager.getStatistics().totalRelayTime == 60)
        #expect(manager.getStatistics().totalBytesSent == 6000)
        #expect(manager.getStatistics().statisticsForDestination("dest") != nil)
    }
    
    @Test("Media relay error handling")
    func testMediaRelayErrorHandling() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        // Test starting relay without configuration
        await #expect(throws: RealtimeError.self) {
            let invalidConfig = try MediaRelayConfig(
                sourceChannel: RelayChannelInfo(
                    channelName: "",  // Invalid empty name
                    userId: "user"
                ),
                destinationChannels: []  // Empty destinations
            )
            try await manager.startRelay(config: invalidConfig)
        }
        
        // Test operations on inactive relay
        await #expect(throws: RealtimeError.self) {
            let newChannel = try createTestChannelInfo(name: "new_dest", userId: "new_user")
            try await manager.addDestinationChannel(newChannel)
        }
        
        await #expect(throws: RealtimeError.self) {
            try await manager.pauseRelayToChannel("nonexistent")
        }
        
        // Start a valid relay
        let config = try createTestConfig()
        try await manager.startRelay(config: config)
        
        // Test operations on nonexistent channels
        await #expect(throws: RealtimeError.self) {
            try await manager.pauseRelayToChannel("nonexistent")
        }
        
        await #expect(throws: RealtimeError.self) {
            try await manager.removeDestinationChannel("nonexistent")
        }
    }
    
    @Test("Media relay configuration validation")
    func testMediaRelayConfigurationValidation() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        // Test one-to-one mode with multiple destinations
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let destinations = try [
            createTestChannelInfo(name: "dest1", userId: "user1"),
            createTestChannelInfo(name: "dest2", userId: "user2")
        ]
        
        await #expect(throws: RealtimeError.self) {
            let invalidConfig = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinations,
                relayMode: .oneToOne  // Should only allow 1 destination
            )
            try await manager.startRelay(config: invalidConfig)
        }
        
        // Test many-to-many mode with insufficient destinations
        await #expect(throws: RealtimeError.self) {
            let invalidConfig = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [destinations[0]],
                relayMode: .manyToMany  // Should require at least 2 destinations
            )
            try await manager.startRelay(config: invalidConfig)
        }
        
        // Test configuration with no media types enabled
        await #expect(throws: RealtimeError.self) {
            let invalidConfig = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinations,
                relayMode: .oneToMany,
                enableAudio: false,
                enableVideo: false  // Both disabled - invalid
            )
            try await manager.startRelay(config: invalidConfig)
        }
    }
    
    @Test("Media relay convenience methods")
    func testMediaRelayConvenienceMethods() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let sourceChannel = try createTestChannelInfo(name: "source", userId: "source_user")
        let destChannel = try createTestChannelInfo(name: "dest", userId: "dest_user")
        
        // Test one-to-one convenience method
        try await manager.startOneToOneRelay(
            source: sourceChannel,
            destination: destChannel
        )
        
        #expect(manager.isRelayActive == true)
        #expect(manager.currentConfig?.relayMode == .oneToOne)
        #expect(manager.currentConfig?.destinationChannels.count == 1)
        
        try await manager.stopRelay()
        
        // Test one-to-many convenience method
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
        
        // Test utility methods
        #expect(manager.isRelayActive(for: "dest1") == true)
        #expect(manager.isRelayActive(for: "nonexistent") == false)
        
        let channelInfo = manager.getChannelInfo("dest2")
        #expect(channelInfo?.channelName == "dest2")
        #expect(channelInfo?.userId == "user2")
        
        let channels = manager.getDestinationChannels()
        #expect(channels.count == 3)
        #expect(channels.contains("dest1"))
        #expect(channels.contains("dest2"))
        #expect(channels.contains("dest3"))
    }
    
    @Test("Media relay provider integration")
    func testMediaRelayProviderIntegration() async throws {
        let manager = MediaRelayManager()
        let mockProvider = createMockRTCProvider()
        manager.configure(with: mockProvider)
        
        let config = try createTestConfig()
        
        // Verify provider methods are called correctly
        #expect(mockProvider.mediaRelayActive == false)
        
        try await manager.startRelay(config: config)
        #expect(mockProvider.mediaRelayActive == true)
        
        // Test provider method calls
        try await manager.pauseRelayToChannel("dest")
        // In a real implementation, this would verify the provider method was called
        
        try await manager.resumeRelayToChannel("dest")
        // In a real implementation, this would verify the provider method was called
        
        try await manager.stopRelay()
        #expect(mockProvider.mediaRelayActive == false)
    }
}

// MARK: - Enhanced Mock RTC Provider for Integration Testing

extension MockRTCProvider {
    
    /// Simulate provider state changes for testing
    func simulateChannelStateChange(_ channelName: String, newState: RelayChannelState) {
        // In a real implementation, this would trigger callbacks to the manager
        print("Simulating channel state change: \(channelName) -> \(newState)")
    }
    
    /// Simulate statistics updates for testing
    func simulateStatisticsUpdate(_ stats: MediaRelayStatistics) {
        // In a real implementation, this would trigger statistics callbacks
        print("Simulating statistics update: \(stats)")
    }
    
    /// Simulate error conditions for testing
    func simulateError(_ error: MediaRelayError) {
        // In a real implementation, this would trigger error callbacks
        print("Simulating error: \(error)")
    }
}