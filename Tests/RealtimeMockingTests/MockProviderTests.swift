// MockProviderTests.swift
// Tests for mock providers

import Testing
@testable import RealtimeCore
@testable import RealtimeMocking

@Suite("Mock Provider Tests")
struct MockProviderTests {
    
    @Test("MockRTCProvider initialization test")
    func testMockRTCProviderInitialization() async throws {
        let provider = MockRTCProvider()
        let config = RTCConfig(appId: "test_app_id")
        
        #expect(provider.isInitialized == false)
        
        try await provider.initialize(config: config)
        
        #expect(provider.isInitialized == true)
        #expect(provider.currentConfig?.appId == "test_app_id")
    }
    
    @Test("MockRTCProvider room operations test")
    func testMockRTCProviderRoomOperations() async throws {
        let provider = MockRTCProvider()
        let config = RTCConfig(appId: "test_app_id")
        
        try await provider.initialize(config: config)
        
        let room = try await provider.createRoom(roomId: "test_room")
        #expect(room.roomId == "test_room")
        #expect(provider.currentRoom?.roomId == "test_room")
        
        try await provider.joinRoom(roomId: "test_room", userId: "user123", userRole: .broadcaster)
        #expect(provider.currentRoom?.roomId == "test_room")
        
        try await provider.leaveRoom()
        #expect(provider.currentRoom == nil)
    }
    
    @Test("MockRTCProvider audio control test")
    func testMockRTCProviderAudioControl() async throws {
        let provider = MockRTCProvider()
        let config = RTCConfig(appId: "test_app_id")
        
        try await provider.initialize(config: config)
        
        #expect(provider.isMicrophoneMuted() == false)
        try await provider.muteMicrophone(true)
        #expect(provider.isMicrophoneMuted() == true)
        
        #expect(provider.isLocalAudioStreamActive() == true)
        try await provider.stopLocalAudioStream()
        #expect(provider.isLocalAudioStreamActive() == false)
        
        try await provider.resumeLocalAudioStream()
        #expect(provider.isLocalAudioStreamActive() == true)
    }
    
    @Test("MockRTCProvider volume control test")
    func testMockRTCProviderVolumeControl() async throws {
        let provider = MockRTCProvider()
        let config = RTCConfig(appId: "test_app_id")
        
        try await provider.initialize(config: config)
        
        try await provider.setAudioMixingVolume(75)
        #expect(provider.getAudioMixingVolume() == 75)
        
        try await provider.setPlaybackSignalVolume(80)
        #expect(provider.getPlaybackSignalVolume() == 80)
        
        try await provider.setRecordingSignalVolume(90)
        #expect(provider.getRecordingSignalVolume() == 90)
    }
    
    @Test("MockRTMProvider initialization test")
    func testMockRTMProviderInitialization() async throws {
        let provider = MockRTMProvider()
        let config = RTMConfig(appId: "test_app_id")
        
        #expect(provider.isInitialized == false)
        #expect(provider.getConnectionState() == .disconnected)
        
        try await provider.initialize(config: config)
        
        #expect(provider.isInitialized == true)
        #expect(provider.getConnectionState() == .connected)
        #expect(provider.currentConfig?.appId == "test_app_id")
    }
    
    @Test("MockRTMProvider messaging test")
    func testMockRTMProviderMessaging() async throws {
        let provider = MockRTMProvider()
        let config = RTMConfig(appId: "test_app_id")
        
        try await provider.initialize(config: config)
        
        try await provider.subscribe(to: "test_channel")
        #expect(provider.subscribedChannels.contains("test_channel"))
        
        let message = RealtimeMessage.text("Hello", from: "user123", in: "test_channel")
        try await provider.sendMessage(message)
        
        try await provider.unsubscribe(from: "test_channel")
        #expect(!provider.subscribedChannels.contains("test_channel"))
    }
    
    @Test("MockProvider error simulation test")
    func testMockProviderErrorSimulation() async throws {
        let rtcProvider = MockRTCProvider()
        let rtmProvider = MockRTMProvider()
        
        // Test initialization failure
        rtcProvider.shouldFailInitialization = true
        rtmProvider.shouldFailInitialization = true
        
        let config = RTCConfig(appId: "test_app_id")
        let rtmConfig = RTMConfig(appId: "test_app_id")
        
        await #expect(throws: RealtimeError.self) {
            try await rtcProvider.initialize(config: config)
        }
        
        await #expect(throws: RealtimeError.self) {
            try await rtmProvider.initialize(config: rtmConfig)
        }
        
        // Reset and test other failures
        rtcProvider.reset()
        rtmProvider.reset()
        
        try await rtcProvider.initialize(config: config)
        try await rtmProvider.initialize(config: rtmConfig)
        
        rtcProvider.shouldFailRoomOperations = true
        await #expect(throws: RealtimeError.self) {
            try await rtcProvider.createRoom(roomId: "test_room")
        }
        
        rtmProvider.shouldFailMessageOperations = true
        let message = RealtimeMessage.text("Hello", from: "user123")
        await #expect(throws: RealtimeError.self) {
            try await rtmProvider.sendMessage(message)
        }
    }
}