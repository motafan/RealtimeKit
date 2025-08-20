// MediaRelayConfigTests.swift
// Unit tests for media relay configuration management

import Testing
@testable import RealtimeCore

@Suite("Media Relay Configuration Tests")
struct MediaRelayConfigTests {
    
    // MARK: - RelayChannelInfo Tests
    
    @Test("RelayChannelInfo initialization with valid parameters")
    func testRelayChannelInfoValidInitialization() throws {
        let channelInfo = try RelayChannelInfo(
            channelName: "test_channel",
            token: "test_token_123",
            userId: "user_123",
            uid: 12345
        )
        
        #expect(channelInfo.channelName == "test_channel")
        #expect(channelInfo.token == "test_token_123")
        #expect(channelInfo.userId == "user_123")
        #expect(channelInfo.uid == 12345)
        #expect(channelInfo.isValid == true)
    }
    
    @Test("RelayChannelInfo initialization without token")
    func testRelayChannelInfoWithoutToken() throws {
        let channelInfo = try RelayChannelInfo(
            channelName: "test_channel",
            userId: "user_123"
        )
        
        #expect(channelInfo.channelName == "test_channel")
        #expect(channelInfo.token == nil)
        #expect(channelInfo.userId == "user_123")
        #expect(channelInfo.uid == nil)
        #expect(channelInfo.isValid == true)
    }
    
    @Test("RelayChannelInfo validation with empty channel name")
    func testRelayChannelInfoEmptyChannelName() {
        #expect(throws: RealtimeError.self) {
            try RelayChannelInfo(
                channelName: "",
                userId: "user_123"
            )
        }
    }
    
    @Test("RelayChannelInfo validation with empty user ID")
    func testRelayChannelInfoEmptyUserId() {
        #expect(throws: RealtimeError.self) {
            try RelayChannelInfo(
                channelName: "test_channel",
                userId: ""
            )
        }
    }
    
    @Test("RelayChannelInfo validation with whitespace-only channel name")
    func testRelayChannelInfoWhitespaceChannelName() {
        #expect(throws: RealtimeError.self) {
            try RelayChannelInfo(
                channelName: "   ",
                userId: "user_123"
            )
        }
    }
    
    @Test("RelayChannelInfo validation with invalid characters in channel name")
    func testRelayChannelInfoInvalidChannelNameCharacters() {
        #expect(throws: RealtimeError.self) {
            try RelayChannelInfo(
                channelName: "test@channel",
                userId: "user_123"
            )
        }
    }
    
    @Test("RelayChannelInfo validation with too long channel name")
    func testRelayChannelInfoTooLongChannelName() {
        let longChannelName = String(repeating: "a", count: 65)
        #expect(throws: RealtimeError.self) {
            try RelayChannelInfo(
                channelName: longChannelName,
                userId: "user_123"
            )
        }
    }
    
    @Test("RelayChannelInfo token update")
    func testRelayChannelInfoTokenUpdate() throws {
        let originalChannelInfo = try RelayChannelInfo(
            channelName: "test_channel",
            userId: "user_123"
        )
        
        let updatedChannelInfo = try originalChannelInfo.withToken("new_token_456")
        
        #expect(updatedChannelInfo.channelName == "test_channel")
        #expect(updatedChannelInfo.userId == "user_123")
        #expect(updatedChannelInfo.token == "new_token_456")
    }
    
    // MARK: - MediaRelayMode Tests
    
    @Test("MediaRelayMode display names")
    func testMediaRelayModeDisplayNames() {
        #expect(MediaRelayMode.oneToOne.displayName == "一对一中继")
        #expect(MediaRelayMode.oneToMany.displayName == "一对多中继")
        #expect(MediaRelayMode.manyToMany.displayName == "多对多中继")
    }
    
    @Test("MediaRelayMode descriptions")
    func testMediaRelayModeDescriptions() {
        #expect(MediaRelayMode.oneToOne.description.contains("单个源频道"))
        #expect(MediaRelayMode.oneToMany.description.contains("多个目标频道"))
        #expect(MediaRelayMode.manyToMany.description.contains("双向"))
    }
    
    // MARK: - MediaRelayConfig Tests
    
    @Test("MediaRelayConfig valid initialization")
    func testMediaRelayConfigValidInitialization() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destinationChannel = try RelayChannelInfo(
            channelName: "dest_channel",
            userId: "dest_user"
        )
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destinationChannel],
            relayMode: .oneToOne,
            enableAudio: true,
            enableVideo: true
        )
        
        #expect(config.sourceChannel.channelName == "source_channel")
        #expect(config.destinationChannels.count == 1)
        #expect(config.destinationChannels[0].channelName == "dest_channel")
        #expect(config.relayMode == .oneToOne)
        #expect(config.enableAudio == true)
        #expect(config.enableVideo == true)
        #expect(config.isValid == true)
    }
    
    @Test("MediaRelayConfig validation with empty destinations")
    func testMediaRelayConfigEmptyDestinations() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        #expect(throws: RealtimeError.self) {
            try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [],
                relayMode: .oneToOne
            )
        }
    }
    
    @Test("MediaRelayConfig validation with too many destinations")
    func testMediaRelayConfigTooManyDestinations() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        var destinations: [RelayChannelInfo] = []
        for i in 1...11 {
            destinations.append(try RelayChannelInfo(
                channelName: "dest_\(i)",
                userId: "user_\(i)"
            ))
        }
        
        #expect(throws: RealtimeError.self) {
            try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinations,
                relayMode: .oneToMany
            )
        }
    }
    
    @Test("MediaRelayConfig validation with duplicate destination channels")
    func testMediaRelayConfigDuplicateDestinations() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destination1 = try RelayChannelInfo(
            channelName: "dest_channel",
            userId: "user_1"
        )
        
        let destination2 = try RelayChannelInfo(
            channelName: "dest_channel", // Same channel name
            userId: "user_2"
        )
        
        #expect(throws: RealtimeError.self) {
            try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [destination1, destination2],
                relayMode: .oneToMany
            )
        }
    }
    
    @Test("MediaRelayConfig validation with source as destination")
    func testMediaRelayConfigSourceAsDestination() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "same_channel",
            userId: "source_user"
        )
        
        let destinationChannel = try RelayChannelInfo(
            channelName: "same_channel", // Same as source
            userId: "dest_user"
        )
        
        #expect(throws: RealtimeError.self) {
            try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [destinationChannel],
                relayMode: .oneToOne
            )
        }
    }
    
    @Test("MediaRelayConfig validation with no media types enabled")
    func testMediaRelayConfigNoMediaTypesEnabled() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destinationChannel = try RelayChannelInfo(
            channelName: "dest_channel",
            userId: "dest_user"
        )
        
        #expect(throws: RealtimeError.self) {
            try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [destinationChannel],
                relayMode: .oneToOne,
                enableAudio: false,
                enableVideo: false
            )
        }
    }
    
    @Test("MediaRelayConfig one-to-one mode validation")
    func testMediaRelayConfigOneToOneModeValidation() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destinations = try (1...2).map { i in
            try RelayChannelInfo(
                channelName: "dest_\(i)",
                userId: "user_\(i)"
            )
        }
        
        #expect(throws: RealtimeError.self) {
            try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinations,
                relayMode: .oneToOne // Should only allow 1 destination
            )
        }
    }
    
    @Test("MediaRelayConfig many-to-many mode validation")
    func testMediaRelayConfigManyToManyModeValidation() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destination = try RelayChannelInfo(
            channelName: "dest_channel",
            userId: "dest_user"
        )
        
        #expect(throws: RealtimeError.self) {
            try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: [destination],
                relayMode: .manyToMany // Should require at least 2 destinations
            )
        }
    }
    
    @Test("MediaRelayConfig destination channel lookup")
    func testMediaRelayConfigDestinationLookup() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destination1 = try RelayChannelInfo(
            channelName: "dest_1",
            userId: "user_1"
        )
        
        let destination2 = try RelayChannelInfo(
            channelName: "dest_2",
            userId: "user_2"
        )
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destination1, destination2],
            relayMode: .oneToMany
        )
        
        let foundChannel = config.destinationChannel(named: "dest_1")
        #expect(foundChannel?.channelName == "dest_1")
        #expect(foundChannel?.userId == "user_1")
        
        let notFoundChannel = config.destinationChannel(named: "nonexistent")
        #expect(notFoundChannel == nil)
    }
    
    @Test("MediaRelayConfig adding destination")
    func testMediaRelayConfigAddingDestination() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destination1 = try RelayChannelInfo(
            channelName: "dest_1",
            userId: "user_1"
        )
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destination1],
            relayMode: .oneToMany
        )
        
        let destination2 = try RelayChannelInfo(
            channelName: "dest_2",
            userId: "user_2"
        )
        
        let updatedConfig = try config.addingDestination(destination2)
        
        #expect(updatedConfig.destinationChannels.count == 2)
        #expect(updatedConfig.destinationChannel(named: "dest_1") != nil)
        #expect(updatedConfig.destinationChannel(named: "dest_2") != nil)
    }
    
    @Test("MediaRelayConfig removing destination")
    func testMediaRelayConfigRemovingDestination() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destination1 = try RelayChannelInfo(
            channelName: "dest_1",
            userId: "user_1"
        )
        
        let destination2 = try RelayChannelInfo(
            channelName: "dest_2",
            userId: "user_2"
        )
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destination1, destination2],
            relayMode: .oneToMany
        )
        
        let updatedConfig = try config.removingDestination(named: "dest_1")
        
        #expect(updatedConfig.destinationChannels.count == 1)
        #expect(updatedConfig.destinationChannel(named: "dest_1") == nil)
        #expect(updatedConfig.destinationChannel(named: "dest_2") != nil)
    }
    
    @Test("MediaRelayConfig predefined one-to-one configuration")
    func testMediaRelayConfigOneToOneFactory() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destinationChannel = try RelayChannelInfo(
            channelName: "dest_channel",
            userId: "dest_user"
        )
        
        let config = try MediaRelayConfig.oneToOne(
            source: sourceChannel,
            destination: destinationChannel
        )
        
        #expect(config.relayMode == .oneToOne)
        #expect(config.destinationChannels.count == 1)
        #expect(config.enableAudio == true)
        #expect(config.enableVideo == true)
    }
    
    @Test("MediaRelayConfig predefined one-to-many configuration")
    func testMediaRelayConfigOneToManyFactory() throws {
        let sourceChannel = try RelayChannelInfo(
            channelName: "source_channel",
            userId: "source_user"
        )
        
        let destinations = try (1...3).map { i in
            try RelayChannelInfo(
                channelName: "dest_\(i)",
                userId: "user_\(i)"
            )
        }
        
        let config = try MediaRelayConfig.oneToMany(
            source: sourceChannel,
            destinations: destinations
        )
        
        #expect(config.relayMode == .oneToMany)
        #expect(config.destinationChannels.count == 3)
        #expect(config.enableAudio == true)
        #expect(config.enableVideo == true)
    }
    
    // MARK: - MediaRelayState Tests
    
    @Test("MediaRelayState initialization")
    func testMediaRelayStateInitialization() {
        let destinationStates = [
            "dest_1": RelayChannelState.connected,
            "dest_2": RelayChannelState.connecting
        ]
        
        let state = MediaRelayState(
            overallState: .running,
            sourceChannel: "source_channel",
            destinationStates: destinationStates,
            startTime: Date()
        )
        
        #expect(state.overallState == .running)
        #expect(state.sourceChannel == "source_channel")
        #expect(state.destinationStates.count == 2)
        #expect(state.startTime != nil)
    }
    
    @Test("MediaRelayState destination state lookup")
    func testMediaRelayStateDestinationLookup() {
        let destinationStates = [
            "dest_1": RelayChannelState.connected,
            "dest_2": RelayChannelState.paused
        ]
        
        let state = MediaRelayState(
            overallState: .running,
            sourceChannel: "source_channel",
            destinationStates: destinationStates
        )
        
        #expect(state.stateForDestination("dest_1") == .connected)
        #expect(state.stateForDestination("dest_2") == .paused)
        #expect(state.stateForDestination("nonexistent") == nil)
    }
    
    @Test("MediaRelayState all destinations connected check")
    func testMediaRelayStateAllDestinationsConnected() {
        let allConnectedStates = [
            "dest_1": RelayChannelState.connected,
            "dest_2": RelayChannelState.connected
        ]
        
        let mixedStates = [
            "dest_1": RelayChannelState.connected,
            "dest_2": RelayChannelState.connecting
        ]
        
        let allConnectedState = MediaRelayState(
            overallState: .running,
            sourceChannel: "source_channel",
            destinationStates: allConnectedStates
        )
        
        let mixedState = MediaRelayState(
            overallState: .connecting,
            sourceChannel: "source_channel",
            destinationStates: mixedStates
        )
        
        #expect(allConnectedState.allDestinationsConnected == true)
        #expect(mixedState.allDestinationsConnected == false)
    }
    
    @Test("MediaRelayState connected destinations list")
    func testMediaRelayStateConnectedDestinations() {
        let destinationStates = [
            "dest_1": RelayChannelState.connected,
            "dest_2": RelayChannelState.connecting,
            "dest_3": RelayChannelState.connected
        ]
        
        let state = MediaRelayState(
            overallState: .running,
            sourceChannel: "source_channel",
            destinationStates: destinationStates
        )
        
        let connectedDestinations = state.connectedDestinations
        #expect(connectedDestinations.count == 2)
        #expect(connectedDestinations.contains("dest_1"))
        #expect(connectedDestinations.contains("dest_3"))
        #expect(!connectedDestinations.contains("dest_2"))
    }
    
    @Test("MediaRelayState failed destinations list")
    func testMediaRelayStateFailedDestinations() {
        let destinationStates: [String: RelayChannelState] = [
            "dest_1": .connected,
            "dest_2": .failure(MediaRelayError.destinationConnectionFailed),
            "dest_3": .failure(MediaRelayError.networkError("Connection lost"))
        ]
        
        let state = MediaRelayState(
            overallState: .running,
            sourceChannel: "source_channel",
            destinationStates: destinationStates
        )
        
        let failedDestinations = state.failedDestinations
        #expect(failedDestinations.count == 2)
        #expect(failedDestinations.contains("dest_2"))
        #expect(failedDestinations.contains("dest_3"))
        #expect(!failedDestinations.contains("dest_1"))
    }
    
    @Test("MediaRelayState relay duration calculation")
    func testMediaRelayStateRelayDuration() {
        let startTime = Date().addingTimeInterval(-60) // 1 minute ago
        
        let state = MediaRelayState(
            overallState: .running,
            sourceChannel: "source_channel",
            startTime: startTime
        )
        
        let stateWithoutStartTime = MediaRelayState(
            overallState: .stopped,
            sourceChannel: "source_channel"
        )
        
        let duration = state.relayDuration
        #expect(duration != nil)
        #expect(duration! > 50) // Should be around 60 seconds
        
        #expect(stateWithoutStartTime.relayDuration == nil)
    }
    
    @Test("MediaRelayState updating destination")
    func testMediaRelayStateUpdatingDestination() {
        let initialStates = [
            "dest_1": RelayChannelState.connecting,
            "dest_2": RelayChannelState.connected
        ]
        
        let state = MediaRelayState(
            overallState: .connecting,
            sourceChannel: "source_channel",
            destinationStates: initialStates
        )
        
        let updatedState = state.updatingDestination("dest_1", state: .connected)
        
        #expect(updatedState.stateForDestination("dest_1") == .connected)
        #expect(updatedState.stateForDestination("dest_2") == .connected)
        #expect(updatedState.overallState == .running) // Should be running when all connected
    }
    
    // MARK: - MediaRelayError Tests
    
    @Test("MediaRelayError localized descriptions")
    func testMediaRelayErrorLocalizedDescriptions() {
        let configError = MediaRelayError.invalidConfiguration("Test message")
        let connectionError = MediaRelayError.sourceChannelConnectionFailed
        let networkError = MediaRelayError.networkError("Network timeout")
        
        #expect(configError.localizedDescription.contains("配置无效"))
        #expect(connectionError.localizedDescription.contains("源频道连接失败"))
        #expect(networkError.localizedDescription.contains("网络错误"))
    }
    
    @Test("MediaRelayError recoverability")
    func testMediaRelayErrorRecoverability() {
        let nonRecoverableError = MediaRelayError.invalidConfiguration("Bad config")
        let recoverableError = MediaRelayError.networkError("Temporary network issue")
        let permissionError = MediaRelayError.insufficientPermissions
        
        #expect(nonRecoverableError.isRecoverable == false)
        #expect(recoverableError.isRecoverable == true)
        #expect(permissionError.isRecoverable == false)
    }
    
    // MARK: - MediaRelayStatistics Tests
    
    @Test("MediaRelayStatistics initialization")
    func testMediaRelayStatisticsInitialization() {
        let channelStats = RelayChannelStatistics(
            channelName: "test_channel",
            connectionTime: 120,
            audioBytesSent: 1000,
            videoBytesSent: 5000
        )
        
        let stats = MediaRelayStatistics(
            totalRelayTime: 300,
            audioBytesSent: 2000,
            videoBytesSent: 10000,
            destinationStats: ["test_channel": channelStats]
        )
        
        #expect(stats.totalRelayTime == 300)
        #expect(stats.audioBytesSent == 2000)
        #expect(stats.videoBytesSent == 10000)
        #expect(stats.totalBytesSent == 12000)
        #expect(stats.destinationStats.count == 1)
    }
    
    @Test("MediaRelayStatistics average bitrate calculation")
    func testMediaRelayStatisticsAverageBitrate() {
        let stats = MediaRelayStatistics(
            totalRelayTime: 10, // 10 seconds
            audioBytesSent: 1000, // 1000 bytes
            videoBytesSent: 4000  // 4000 bytes
        )
        
        // Total: 5000 bytes = 40000 bits over 10 seconds = 4000 bps = 4 kbps
        let expectedBitrate = 4.0
        #expect(abs(stats.averageBitrate - expectedBitrate) < 0.1)
        
        let zeroTimeStats = MediaRelayStatistics(totalRelayTime: 0)
        #expect(zeroTimeStats.averageBitrate == 0)
    }
    
    @Test("RelayChannelStatistics calculations")
    func testRelayChannelStatisticsCalculations() {
        let channelStats = RelayChannelStatistics(
            channelName: "test_channel",
            connectionTime: 60, // 60 seconds
            audioBytesSent: 2000,
            videoBytesSent: 8000,
            audioPacketsSent: 100,
            videoPacketsSent: 200,
            packetsLost: 10
        )
        
        #expect(channelStats.totalBytesSent == 10000)
        #expect(channelStats.totalPacketsSent == 300)
        
        // Packet loss rate: 10 lost out of 310 total = ~0.032
        let expectedLossRate = 10.0 / 310.0
        #expect(abs(channelStats.packetLossRate - expectedLossRate) < 0.001)
        
        // Average bitrate: 10000 bytes = 80000 bits over 60 seconds = ~1333 bps = ~1.33 kbps
        let expectedBitrate = 80000.0 / (60.0 * 1000.0)
        #expect(abs(channelStats.averageBitrate - expectedBitrate) < 0.01)
    }
}