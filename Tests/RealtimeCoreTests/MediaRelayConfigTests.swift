import Testing
import Foundation
@testable import RealtimeCore

/// 媒体中继配置测试
/// 需求: 8.1, 8.4 - 测试媒体中继配置管理和验证逻辑
@Suite("MediaRelayConfig Tests")
struct MediaRelayConfigTests {
    
    // MARK: - Test Data
    
    private func createValidSourceChannel() -> MediaRelayChannelInfo {
        return MediaRelayChannelInfo(
            channelName: "source_channel",
            userId: "user123",
            token: "valid_token_123",
            description: "Source channel for testing"
        )
    }
    
    private func createValidDestinationChannel(name: String = "dest_channel") -> MediaRelayChannelInfo {
        return MediaRelayChannelInfo(
            channelName: name,
            userId: "user456",
            token: "valid_token_456",
            description: "Destination channel for testing"
        )
    }
    
    // MARK: - MediaRelayChannelInfo Tests
    
    @Test("Valid channel info creation")
    func testValidChannelInfoCreation() throws {
        let channel = createValidSourceChannel()
        
        #expect(channel.channelName == "source_channel")
        #expect(channel.userId == "user123")
        #expect(channel.token == "valid_token_123")
        #expect(channel.description == "Source channel for testing")
        #expect(channel.createdAt <= Date())
    }
    
    @Test("Channel info validation - valid cases")
    func testChannelInfoValidation_ValidCases() throws {
        let validChannels = [
            MediaRelayChannelInfo(channelName: "test", userId: "user1", token: "token1"),
            MediaRelayChannelInfo(channelName: "test_channel", userId: "user_123", token: "long_token_string"),
            MediaRelayChannelInfo(channelName: "test-channel", userId: "user", token: "t"),
            MediaRelayChannelInfo(channelName: "a", userId: "u", token: "t")
        ]
        
        for channel in validChannels {
            try channel.validate()
        }
    }
    
    @Test("Channel info validation - invalid channel names", 
          arguments: [
            ("", "Empty channel name"),
            ("channel with spaces", "Channel name with spaces"),
            ("channel@invalid", "Channel name with special characters"),
            ("channel.invalid", "Channel name with dots"),
            (String(repeating: "a", count: 65), "Channel name too long")
          ])
    func testChannelInfoValidation_InvalidChannelNames(channelName: String, description: String) throws {
        let channel = MediaRelayChannelInfo(
            channelName: channelName,
            userId: "valid_user",
            token: "valid_token"
        )
        
        #expect(throws: MediaRelayValidationError.self) {
            try channel.validate()
        }
    }
    
    @Test("Channel info validation - invalid user IDs",
          arguments: [
            ("", "Empty user ID"),
            (String(repeating: "u", count: 256), "User ID too long")
          ])
    func testChannelInfoValidation_InvalidUserIds(userId: String, description: String) throws {
        let channel = MediaRelayChannelInfo(
            channelName: "valid_channel",
            userId: userId,
            token: "valid_token"
        )
        
        #expect(throws: MediaRelayValidationError.self) {
            try channel.validate()
        }
    }
    
    @Test("Channel info validation - invalid tokens",
          arguments: [
            ("", "Empty token"),
            (String(repeating: "t", count: 2049), "Token too long")
          ])
    func testChannelInfoValidation_InvalidTokens(token: String, description: String) throws {
        let channel = MediaRelayChannelInfo(
            channelName: "valid_channel",
            userId: "valid_user",
            token: token
        )
        
        #expect(throws: MediaRelayValidationError.self) {
            try channel.validate()
        }
    }
    
    // MARK: - MediaRelayMode Tests
    
    @Test("Media relay mode properties")
    func testMediaRelayModeProperties() throws {
        #expect(MediaRelayMode.oneToOne.displayName == "一对一中继")
        #expect(MediaRelayMode.oneToMany.displayName == "一对多中继")
        #expect(MediaRelayMode.manyToMany.displayName == "多对多中继")
        
        #expect(MediaRelayMode.oneToOne.maxDestinationChannels == 1)
        #expect(MediaRelayMode.oneToMany.maxDestinationChannels == 4)
        #expect(MediaRelayMode.manyToMany.maxDestinationChannels == 8)
        
        #expect(!MediaRelayMode.oneToOne.description.isEmpty)
        #expect(!MediaRelayMode.oneToMany.description.isEmpty)
        #expect(!MediaRelayMode.manyToMany.description.isEmpty)
    }
    
    // MARK: - MediaRelayConfig Tests
    
    @Test("Valid media relay config creation - one to one")
    func testValidMediaRelayConfig_OneToOne() throws {
        let sourceChannel = createValidSourceChannel()
        let destinationChannel = createValidDestinationChannel()
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destinationChannel]
        )
        
        #expect(config.sourceChannel.channelName == "source_channel")
        #expect(config.destinationChannels.count == 1)
        #expect(config.relayMode == .oneToOne)
    }
    
    @Test("Valid media relay config creation - one to many")
    func testValidMediaRelayConfig_OneToMany() throws {
        let sourceChannel = createValidSourceChannel()
        let destinationChannels = [
            createValidDestinationChannel(name: "dest1"),
            createValidDestinationChannel(name: "dest2"),
            createValidDestinationChannel(name: "dest3")
        ]
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels
        )
        
        #expect(config.sourceChannel.channelName == "source_channel")
        #expect(config.destinationChannels.count == 3)
        #expect(config.relayMode == .oneToMany)
    }
    
    @Test("Media relay config validation - empty destinations")
    func testMediaRelayConfig_EmptyDestinations() throws {
        let sourceChannel = createValidSourceChannel()
        
        #expect(throws: MediaRelayValidationError.self) {
            _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: []
            )
        }
    }
    
    @Test("Media relay config validation - too many destinations")
    func testMediaRelayConfig_TooManyDestinations() throws {
        let sourceChannel = createValidSourceChannel()
        let destinationChannels = (1...5).map { i in
            createValidDestinationChannel(name: "dest\(i)")
        }
        
        #expect(throws: MediaRelayValidationError.self) {
            _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinationChannels
            )
        }
    }
    
    @Test("Media relay config validation - duplicate destinations")
    func testMediaRelayConfig_DuplicateDestinations() throws {
        let sourceChannel = createValidSourceChannel()
        let destinationChannels = [
            createValidDestinationChannel(name: "dest1"),
            createValidDestinationChannel(name: "dest1") // Duplicate
        ]
        
        #expect(throws: MediaRelayValidationError.self) {
            _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinationChannels
            )
        }
    }
    
    @Test("Media relay config validation - source in destinations")
    func testMediaRelayConfig_SourceInDestinations() throws {
        let sourceChannel = createValidSourceChannel()
        let destinationChannels = [
            createValidDestinationChannel(name: "source_channel") // Same as source
        ]
        
        #expect(throws: MediaRelayValidationError.self) {
            _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinationChannels
            )
        }
    }
    
    @Test("Media relay config - adding destination channel")
    func testMediaRelayConfig_AddingDestinationChannel() throws {
        let sourceChannel = createValidSourceChannel()
        let initialDestination = createValidDestinationChannel(name: "dest1")
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [initialDestination]
        )
        
        let newDestination = createValidDestinationChannel(name: "dest2")
        let updatedConfig = try config.addingDestinationChannel(newDestination)
        
        #expect(updatedConfig.destinationChannels.count == 2)
        #expect(updatedConfig.relayMode == .oneToMany)
        #expect(updatedConfig.destinationChannels.contains { $0.channelName == "dest2" })
    }
    
    @Test("Media relay config - adding duplicate destination channel")
    func testMediaRelayConfig_AddingDuplicateDestinationChannel() throws {
        let sourceChannel = createValidSourceChannel()
        let initialDestination = createValidDestinationChannel(name: "dest1")
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [initialDestination]
        )
        
        let duplicateDestination = createValidDestinationChannel(name: "dest1")
        
        #expect(throws: MediaRelayValidationError.self) {
            _ = try config.addingDestinationChannel(duplicateDestination)
        }
    }
    
    @Test("Media relay config - removing destination channel")
    func testMediaRelayConfig_RemovingDestinationChannel() throws {
        let sourceChannel = createValidSourceChannel()
        let destinationChannels = [
            createValidDestinationChannel(name: "dest1"),
            createValidDestinationChannel(name: "dest2")
        ]
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels
        )
        
        let updatedConfig = try config.removingDestinationChannel("dest1")
        
        #expect(updatedConfig.destinationChannels.count == 1)
        #expect(updatedConfig.relayMode == .oneToOne)
        #expect(!updatedConfig.destinationChannels.contains { $0.channelName == "dest1" })
        #expect(updatedConfig.destinationChannels.contains { $0.channelName == "dest2" })
    }
    
    @Test("Media relay config - removing last destination channel")
    func testMediaRelayConfig_RemovingLastDestinationChannel() throws {
        let sourceChannel = createValidSourceChannel()
        let destinationChannel = createValidDestinationChannel(name: "dest1")
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destinationChannel]
        )
        
        #expect(throws: MediaRelayValidationError.self) {
            _ = try config.removingDestinationChannel("dest1")
        }
    }
    
    // MARK: - MediaRelayDetailedState Tests
    
    @Test("Media relay detailed state creation and properties")
    func testMediaRelayDetailedStateCreation() throws {
        let sourceState = MediaRelayChannelState(
            channelName: "source",
            connectionState: .connected
        )
        
        let destStates = [
            MediaRelayChannelState(channelName: "dest1", connectionState: .connected),
            MediaRelayChannelState(channelName: "dest2", connectionState: .connecting)
        ]
        
        let statistics = MediaRelayStatistics(
            totalRelayDuration: 120.0,
            totalBytesSent: 1024000
        )
        
        let relayState = MediaRelayDetailedState(
            overallState: .running,
            sourceChannelState: sourceState,
            destinationChannelStates: destStates,
            startTime: Date(),
            statistics: statistics
        )
        
        #expect(relayState.overallState == .running)
        #expect(relayState.sourceChannelState.channelName == "source")
        #expect(relayState.destinationChannelStates.count == 2)
        #expect(relayState.connectedDestinationCount == 1)
        #expect(relayState.failedDestinationCount == 0)
        #expect(!relayState.allDestinationsConnected)
        #expect(relayState.statistics?.totalRelayDuration == 120.0)
    }
    
    @Test("Media relay detailed state - get channel state")
    func testMediaRelayDetailedState_GetChannelState() throws {
        let sourceState = MediaRelayChannelState(
            channelName: "source",
            connectionState: .connected
        )
        
        let destStates = [
            MediaRelayChannelState(channelName: "dest1", connectionState: .connected),
            MediaRelayChannelState(channelName: "dest2", connectionState: .failure)
        ]
        
        let relayState = MediaRelayDetailedState(
            overallState: .running,
            sourceChannelState: sourceState,
            destinationChannelStates: destStates
        )
        
        let sourceResult = relayState.getChannelState(for: "source")
        #expect(sourceResult?.channelName == "source")
        #expect(sourceResult?.connectionState == .connected)
        
        let dest1Result = relayState.getChannelState(for: "dest1")
        #expect(dest1Result?.channelName == "dest1")
        #expect(dest1Result?.connectionState == .connected)
        
        let nonExistentResult = relayState.getChannelState(for: "nonexistent")
        #expect(nonExistentResult == nil)
    }
    
    // MARK: - MediaRelayStatistics Tests
    
    @Test("Media relay statistics calculations")
    func testMediaRelayStatisticsCalculations() throws {
        let statistics = MediaRelayStatistics(
            totalRelayDuration: 100.0,
            totalBytesSent: 1000000,
            audioPacketsSent: 800,
            videoPacketsSent: 200,
            packetsLost: 10
        )
        
        #expect(statistics.packetLossRate == 1.0) // 10 lost out of 1000 total = 1%
        #expect(statistics.averageTransferRate == 10000.0) // 1000000 bytes / 100 seconds
    }
    
    @Test("Media relay channel statistics calculations")
    func testMediaRelayChannelStatisticsCalculations() throws {
        let channelStats = MediaRelayChannelStatistics(
            channelName: "test_channel",
            bytesSent: 500000,
            audioPacketsSent: 400,
            videoPacketsSent: 100,
            packetsLost: 5,
            connectionDuration: 50.0
        )
        
        #expect(channelStats.packetLossRate == 1.0) // 5 lost out of 500 total = 1%
        #expect(channelStats.transferRate == 10000.0) // 500000 bytes / 50 seconds
    }
    
    // MARK: - Connection State Tests
    
    @Test("Media relay connection state properties")
    func testMediaRelayConnectionStateProperties() throws {
        #expect(MediaRelayConnectionState.connected.isConnected)
        #expect(!MediaRelayConnectionState.connecting.isConnected)
        #expect(!MediaRelayConnectionState.disconnected.isConnected)
        
        #expect(MediaRelayConnectionState.failure.isFailure)
        #expect(!MediaRelayConnectionState.connected.isFailure)
        #expect(!MediaRelayConnectionState.connecting.isFailure)
    }
    
    @Test("Media relay overall state properties")
    func testMediaRelayOverallStateProperties() throws {
        #expect(MediaRelayOverallState.running.isActive)
        #expect(MediaRelayOverallState.connecting.isActive)
        #expect(MediaRelayOverallState.paused.isActive)
        
        #expect(!MediaRelayOverallState.idle.isActive)
        #expect(!MediaRelayOverallState.stopping.isActive)
        #expect(!MediaRelayOverallState.failure.isActive)
    }
    
    @Test("Media relay channel state availability")
    func testMediaRelayChannelStateAvailability() throws {
        let availableState = MediaRelayChannelState(
            channelName: "test",
            connectionState: .connected,
            isPaused: false
        )
        #expect(availableState.isAvailable)
        
        let pausedState = MediaRelayChannelState(
            channelName: "test",
            connectionState: .connected,
            isPaused: true
        )
        #expect(!pausedState.isAvailable)
        
        let disconnectedState = MediaRelayChannelState(
            channelName: "test",
            connectionState: .disconnected,
            isPaused: false
        )
        #expect(!disconnectedState.isAvailable)
    }
}