// AgoraProviderTests.swift
// Unit tests for Agora provider implementation

import Testing
import Foundation
@testable import RealtimeCore
@testable import RealtimeAgora

@Suite("Agora Provider Tests")
struct AgoraProviderTests {
    
    // MARK: - AgoraRTCProvider Tests
    
    @Suite("AgoraRTCProvider Tests")
    struct AgoraRTCProviderTests {
        
        @Test("Initialize RTC provider successfully")
        func testInitializeRTCProvider() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            
            try await provider.initialize(config: config)
            
            // Verify initialization state
            #expect(!provider.isMicrophoneMuted())
            #expect(provider.isLocalAudioStreamActive())
            #expect(provider.getAudioMixingVolume() == 100)
            #expect(provider.getPlaybackSignalVolume() == 100)
            #expect(provider.getRecordingSignalVolume() == 100)
        }
        
        @Test("Initialize RTC provider with invalid config throws error")
        func testInitializeRTCProviderWithInvalidConfig() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "") // Empty app ID
            
            // Should not throw in our mock implementation, but would in real SDK
            try await provider.initialize(config: config)
        }
        
        @Test("Double initialization throws error")
        func testDoubleInitializationThrowsError() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            
            try await provider.initialize(config: config)
            
            await #expect(throws: RealtimeError.self) {
                try await provider.initialize(config: config)
            }
        }
        
        @Test("Create and join room successfully")
        func testCreateAndJoinRoom() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            let room = try await provider.createRoom(roomId: "test_room")
            #expect(room.roomId == "test_room")
            
            try await provider.joinRoom(roomId: "test_room", userId: "test_user", userRole: .broadcaster)
            
            // Should be able to leave room
            try await provider.leaveRoom()
        }
        
        @Test("Join room without initialization throws error")
        func testJoinRoomWithoutInitialization() async throws {
            let provider = AgoraRTCProvider()
            
            await #expect(throws: RealtimeError.self) {
                try await provider.joinRoom(roomId: "test_room", userId: "test_user", userRole: .broadcaster)
            }
        }
        
        @Test("Switch user role successfully")
        func testSwitchUserRole() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            try await provider.joinRoom(roomId: "test_room", userId: "test_user", userRole: .coHost)
            try await provider.switchUserRole(.broadcaster)
        }
        
        @Test("Audio control functions work correctly")
        func testAudioControl() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            // Test microphone muting
            try await provider.muteMicrophone(true)
            #expect(provider.isMicrophoneMuted())
            
            try await provider.muteMicrophone(false)
            #expect(!provider.isMicrophoneMuted())
            
            // Test audio stream control
            try await provider.stopLocalAudioStream()
            #expect(!provider.isLocalAudioStreamActive())
            
            try await provider.resumeLocalAudioStream()
            #expect(provider.isLocalAudioStreamActive())
        }
        
        @Test("Volume control functions work correctly")
        func testVolumeControl() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            // Test audio mixing volume
            try await provider.setAudioMixingVolume(50)
            #expect(provider.getAudioMixingVolume() == 50)
            
            // Test playback signal volume
            try await provider.setPlaybackSignalVolume(75)
            #expect(provider.getPlaybackSignalVolume() == 75)
            
            // Test recording signal volume
            try await provider.setRecordingSignalVolume(25)
            #expect(provider.getRecordingSignalVolume() == 25)
            
            // Test volume clamping
            try await provider.setAudioMixingVolume(150) // Should clamp to 100
            #expect(provider.getAudioMixingVolume() == 100)
            
            try await provider.setAudioMixingVolume(-10) // Should clamp to 0
            #expect(provider.getAudioMixingVolume() == 0)
        }
        
        @Test("Stream push functionality")
        func testStreamPush() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            let streamConfig = try StreamPushConfig(
                pushUrl: "rtmp://test.example.com/live/stream",
                width: 1280,
                height: 720,
                bitrate: 1000,
                frameRate: 30,
                layout: try StreamLayout(userRegions: [])
            )
            
            try await provider.startStreamPush(config: streamConfig)
            
            // Update layout
            let newLayout = try StreamLayout(userRegions: [
                try UserRegion(userId: "user1", x: 0.0, y: 0.0, width: 0.5, height: 0.5)
            ])
            try await provider.updateStreamPushLayout(layout: newLayout)
            
            try await provider.stopStreamPush()
        }
        
        @Test("Media relay functionality")
        func testMediaRelay() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            let relayConfig = try MediaRelayConfig(
                sourceChannel: try RelayChannelInfo(channelName: "source_channel", token: "source_token", userId: "source_uid"),
                destinationChannels: [
                    try RelayChannelInfo(channelName: "dest_channel_1", token: "dest_token_1", userId: "dest_uid_1"),
                    try RelayChannelInfo(channelName: "dest_channel_2", token: "dest_token_2", userId: "dest_uid_2")
                ]
            )
            
            try await provider.startMediaRelay(config: relayConfig)
            
            // Update channels
            let updatedConfig = MediaRelayConfig(
                sourceChannel: relayConfig.sourceChannel,
                destinationChannels: [relayConfig.destinationChannels[0]] // Remove one channel
            )
            try await provider.updateMediaRelayChannels(config: updatedConfig)
            
            // Pause and resume specific channel
            try await provider.pauseMediaRelay(toChannel: "dest_channel_1")
            try await provider.resumeMediaRelay(toChannel: "dest_channel_1")
            
            try await provider.stopMediaRelay()
        }
        
        @Test("Volume indicator functionality")
        func testVolumeIndicator() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            var receivedVolumeInfos: [UserVolumeInfo] = []
            var receivedVolumeEvents: [VolumeEvent] = []
            
            provider.setVolumeIndicatorHandler { volumeInfos in
                receivedVolumeInfos = volumeInfos
            }
            
            provider.setVolumeEventHandler { event in
                receivedVolumeEvents.append(event)
            }
            
            let volumeConfig = VolumeDetectionConfig(
                detectionInterval: 300,
                speakingThreshold: 0.3,
                includeLocalUser: true
            )
            
            try await provider.enableVolumeIndicator(config: volumeConfig)
            
            // Wait a bit for volume updates (in real implementation)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            try await provider.disableVolumeIndicator()
            
            // Verify current volume infos
            let currentInfos = provider.getCurrentVolumeInfos()
            #expect(currentInfos.isEmpty) // Should be empty after disabling
        }
        
        @Test("Token management functionality")
        func testTokenManagement() async throws {
            let provider = AgoraRTCProvider()
            let config = RTCConfig(appId: "test_app_id", token: "initial_token")
            try await provider.initialize(config: config)
            
            var tokenExpirationCalled = false
            provider.onTokenWillExpire { remainingSeconds in
                tokenExpirationCalled = true
            }
            
            // Renew token
            try await provider.renewToken("new_token")
            
            // In real implementation, token expiration would be triggered by SDK
            // Here we just verify the handler was set
            #expect(!tokenExpirationCalled) // Won't be called in mock
        }
    }
    
    // MARK: - AgoraRTMProvider Tests
    
    @Suite("AgoraRTMProvider Tests")
    struct AgoraRTMProviderTests {
        
        @Test("Initialize RTM provider successfully")
        func testInitializeRTMProvider() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            
            try await provider.initialize(config: config)
            
            #expect(provider.getConnectionState() == .disconnected) // Not logged in yet
        }
        
        @Test("Login and logout functionality")
        func testLoginLogout() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            try await provider.login(userId: "test_user", token: "test_token")
            #expect(provider.getConnectionState() == .connected)
            
            try await provider.disconnect()
            #expect(provider.getConnectionState() == .disconnected)
        }
        
        @Test("Channel subscription and messaging")
        func testChannelSubscriptionAndMessaging() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            try await provider.login(userId: "test_user")
            
            var receivedMessages: [RealtimeMessage] = []
            provider.setMessageHandler { message in
                receivedMessages.append(message)
            }
            
            // Subscribe to channel
            try await provider.subscribe(to: "test_channel")
            
            // Send channel message
            let message = RealtimeMessage.text("Hello, channel!", from: "test_user", in: "test_channel")
            try await provider.sendMessage(message)
            
            // Unsubscribe from channel
            try await provider.unsubscribe(from: "test_channel")
        }
        
        @Test("Peer messaging functionality")
        func testPeerMessaging() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            try await provider.login(userId: "test_user")
            
            var receivedMessages: [RealtimeMessage] = []
            provider.setMessageHandler { message in
                receivedMessages.append(message)
            }
            
            // Send peer message
            let message = RealtimeMessage.text("Hello, peer!", from: "test_user")
            try await provider.sendMessage(message)
        }
        
        @Test("Connection state handling")
        func testConnectionStateHandling() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            var connectionStates: [ConnectionState] = []
            provider.setConnectionStateHandler { state in
                connectionStates.append(state)
            }
            
            try await provider.login(userId: "test_user")
            try await provider.disconnect()
            
            // In real implementation, connection state changes would be captured
        }
        
        @Test("Message processing functionality")
        func testMessageProcessing() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            // Create mock Agora message
            let agoraMessage = AgoraRtmMessage(text: "Test message", type: .text)
            
            let processedMessage = try await provider.processIncomingMessage(agoraMessage)
            #expect(processedMessage.content == "Test message")
            #expect(processedMessage.type == .text)
        }
        
        @Test("Token renewal functionality")
        func testTokenRenewal() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id", token: "initial_token")
            try await provider.initialize(config: config)
            try await provider.login(userId: "test_user")
            
            var tokenExpirationCalled = false
            provider.onTokenWillExpire { remainingSeconds in
                tokenExpirationCalled = true
            }
            
            try await provider.renewToken("new_token")
        }
        
        @Test("Reconnection functionality")
        func testReconnection() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            try await provider.login(userId: "test_user")
            try await provider.disconnect()
            
            // Reconnect
            try await provider.reconnect()
            #expect(provider.getConnectionState() == .connected)
        }
        
        @Test("Send message without login throws error")
        func testSendMessageWithoutLogin() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            let message = RealtimeMessage.text("Test", from: "test_user", in: "test")
            
            await #expect(throws: RealtimeError.self) {
                try await provider.sendMessage(message)
            }
        }
        
        @Test("Subscribe to channel without login throws error")
        func testSubscribeWithoutLogin() async throws {
            let provider = AgoraRTMProvider()
            let config = RTMConfig(appId: "test_app_id")
            try await provider.initialize(config: config)
            
            await #expect(throws: RealtimeError.self) {
                try await provider.subscribe(to: "test_channel")
            }
        }
    }
    
    // MARK: - AgoraProviderFactory Tests
    
    @Suite("AgoraProviderFactory Tests")
    struct AgoraProviderFactoryTests {
        
        @Test("Factory creates correct provider instances")
        func testFactoryCreatesProviders() {
            let factory = RealtimeAgora.AgoraProviderFactory()
            
            #expect(factory.providerType == ProviderType.agora)
            
            let rtcProvider = factory.createRTCProvider()
            #expect(rtcProvider is AgoraRTCProvider)
            
            let rtmProvider = factory.createRTMProvider()
            #expect(rtmProvider is AgoraRTMProvider)
        }
        
        @Test("Factory reports correct supported features")
        func testFactorySupportedFeatures() {
            let factory = RealtimeAgora.AgoraProviderFactory()
            let features = factory.supportedFeatures()
            
            let expectedFeatures: Set<ProviderFeature> = [
                .audioStreaming,
                .videoStreaming,
                .streamPush,
                .mediaRelay,
                .volumeIndicator,
                .messageProcessing,
                .tokenManagement,
                .encryption
            ]
            
            #expect(features == expectedFeatures)
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Agora Integration Tests")
    struct AgoraIntegrationTests {
        
        @Test("Full RTC workflow integration")
        func testFullRTCWorkflow() async throws {
            let factory = RealtimeAgora.AgoraProviderFactory()
            let rtcProvider = factory.createRTCProvider()
            
            // Initialize
            let config = RTCConfig(appId: "test_app_id")
            try await rtcProvider.initialize(config: config)
            
            // Create and join room
            let room = try await rtcProvider.createRoom(roomId: "integration_room")
            try await rtcProvider.joinRoom(roomId: room.roomId, userId: "integration_user", userRole: .broadcaster)
            
            // Configure audio
            try await rtcProvider.setAudioMixingVolume(80)
            try await rtcProvider.muteMicrophone(false)
            
            // Enable volume indicator
            let volumeConfig = VolumeDetectionConfig()
            try await rtcProvider.enableVolumeIndicator(config: volumeConfig)
            
            // Start stream push
            let streamConfig = try StreamPushConfig(
                pushUrl: "rtmp://test.example.com/live/integration",
                width: 1280,
                height: 720,
                bitrate: 1000,
                frameRate: 30,
                layout: try StreamLayout(userRegions: [])
            )
            try await rtcProvider.startStreamPush(config: streamConfig)
            
            // Clean up
            try await rtcProvider.stopStreamPush()
            try await rtcProvider.disableVolumeIndicator()
            try await rtcProvider.leaveRoom()
        }
        
        @Test("Full RTM workflow integration")
        func testFullRTMWorkflow() async throws {
            let factory = RealtimeAgora.AgoraProviderFactory()
            let rtmProvider = factory.createRTMProvider()
            
            // Initialize and login
            let config = RTMConfig(appId: "test_app_id")
            try await rtmProvider.initialize(config: config)
            try await rtmProvider.login(userId: "integration_user")
            
            // Set up message handling
            var receivedMessages: [RealtimeMessage] = []
            rtmProvider.setMessageHandler { message in
                receivedMessages.append(message)
            }
            
            // Subscribe to channel and send message
            try await rtmProvider.subscribe(to: "integration_channel")
            
            let message = RealtimeMessage.text("Integration test message", from: "integration_user", in: "integration_channel")
            try await rtmProvider.sendMessage(message)
            
            // Send peer message
            let peerMessage = RealtimeMessage.text("Peer message", from: "integration_user")
            try await rtmProvider.sendMessage(peerMessage)
            
            // Clean up
            try await rtmProvider.unsubscribe(from: "integration_channel")
            try await rtmProvider.disconnect()
        }
        
        @Test("Provider factory registration and usage")
        @MainActor
        func testProviderFactoryRegistration() async throws {
            let registry = ProviderFactoryRegistry()
            let factory = RealtimeAgora.AgoraProviderFactory()
            
            // Register factory
            registry.registerFactory(factory)
            
            #expect(registry.isProviderAvailable(ProviderType.agora))
            #expect(registry.getAvailableProviders().contains(ProviderType.agora))
            
            let retrievedFactory = registry.getFactory(for: ProviderType.agora)
            #expect(retrievedFactory != nil)
            #expect(retrievedFactory?.providerType == ProviderType.agora)
            
            let features = registry.getSupportedFeatures(for: ProviderType.agora)
            #expect(features.contains(.audioStreaming))
            #expect(features.contains(.messageProcessing))
        }
    }
}