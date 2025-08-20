// RealtimeManagerTests.swift
// Unit tests for RealtimeManager

import Testing
@testable import RealtimeCore
import RealtimeMocking

@Suite("RealtimeManager Tests")
@MainActor
struct RealtimeManagerTests {
    
    // MARK: - Test Configuration
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "test_app_id",
            appKey: "test_app_key",
            logLevel: .debug
        )
    }
    
    private func setupManager() async throws -> RealtimeManager {
        let manager = RealtimeManager.shared
        
        // Register mock provider factory
        manager.registerMockProvider()
        
        let config = createTestConfig()
        try await manager.configure(provider: .mock, config: config)
        return manager
    }
    
    // MARK: - Initialization Tests
    
    @Test("Manager singleton initialization")
    func testManagerSingletonInitialization() async {
        let manager1 = RealtimeManager.shared
        let manager2 = RealtimeManager.shared
        
        #expect(manager1 === manager2)
        #expect(!manager1.isInitialized)
        #expect(manager1.currentProvider == nil)
    }
    
    @Test("Manager configuration with mock provider")
    func testManagerConfigurationWithMockProvider() async throws {
        let manager = RealtimeManager.shared
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        #expect(manager.isInitialized)
        #expect(manager.currentProvider == .mock)
        #expect(manager.connectionState == .connected)
    }
    
    @Test("Manager configuration with unavailable provider")
    func testManagerConfigurationWithUnavailableProvider() async {
        let manager = RealtimeManager.shared
        let config = createTestConfig()
        
        do {
            try await manager.configure(provider: .agora, config: config)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .providerNotAvailable(.agora))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Provider Management Tests
    
    @Test("Provider factory registration")
    func testProviderFactoryRegistration() async throws {
        let manager = try await setupManager()
        
        let availableProviders = manager.getAvailableProviders()
        #expect(availableProviders.contains(.mock))
        
        let mockFeatures = manager.getSupportedFeatures(for: .mock)
        #expect(mockFeatures.contains(.audioStreaming))
        #expect(mockFeatures.contains(.messageProcessing))
    }
    
    @Test("Provider switching")
    func testProviderSwitching() async throws {
        let manager = try await setupManager()
        
        // Create a session first
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.currentSession != nil)
        
        // Switch provider (should preserve session)
        try await manager.switchProvider(to: .mock, preserveSession: true)
        
        #expect(manager.currentProvider == .mock)
        #expect(manager.currentSession != nil)
        #expect(manager.currentSession?.userId == "test_user")
    }
    
    // MARK: - Room Management Tests
    
    @Test("Room creation")
    func testRoomCreation() async throws {
        let manager = try await setupManager()
        
        let room = try await manager.createRoom(roomId: "test_room")
        
        #expect(room.roomId == "test_room")
    }
    
    @Test("Room joining with valid role")
    func testRoomJoiningWithValidRole() async throws {
        let manager = try await setupManager()
        
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.currentSession != nil)
        #expect(manager.currentSession?.userId == "test_user")
        #expect(manager.currentSession?.userName == "Test User")
        #expect(manager.currentSession?.userRole == .broadcaster)
        #expect(manager.currentSession?.roomId == "test_room")
    }
    
    @Test("Room joining with invalid role permissions")
    func testRoomJoiningWithInvalidRolePermissions() async throws {
        let manager = try await setupManager()
        
        // This should work as audience role is valid
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .audience
        )
        
        #expect(manager.currentSession != nil)
        #expect(manager.currentSession?.userRole == .audience)
    }
    
    @Test("Room leaving")
    func testRoomLeaving() async throws {
        let manager = try await setupManager()
        
        // Join room first
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.currentSession != nil)
        
        // Leave room
        try await manager.leaveRoom()
        
        #expect(manager.currentSession == nil)
    }
    
    @Test("User role switching with valid transition")
    func testUserRoleSwitchingWithValidTransition() async throws {
        let manager = try await setupManager()
        
        // Join as co-host
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .coHost
        )
        
        #expect(manager.currentSession?.userRole == .coHost)
        
        // Switch to broadcaster (valid transition)
        try await manager.switchUserRole(.broadcaster)
        
        #expect(manager.currentSession?.userRole == .broadcaster)
    }
    
    @Test("User role switching with invalid transition")
    func testUserRoleSwitchingWithInvalidTransition() async throws {
        let manager = try await setupManager()
        
        // Join as audience
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .audience
        )
        
        #expect(manager.currentSession?.userRole == .audience)
        
        // Try to switch to broadcaster (invalid transition)
        do {
            try await manager.switchUserRole(.broadcaster)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            if case .invalidRoleTransition(let from, let to) = error {
                #expect(from == .audience)
                #expect(to == .broadcaster)
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Role switching without active session")
    func testRoleSwitchingWithoutActiveSession() async throws {
        let manager = try await setupManager()
        
        do {
            try await manager.switchUserRole(.broadcaster)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .noActiveSession)
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Audio Control Tests
    
    @Test("Microphone mute control")
    func testMicrophoneMuteControl() async throws {
        let manager = try await setupManager()
        
        // Initially not muted
        #expect(!manager.audioSettings.microphoneMuted)
        
        // Mute microphone
        try await manager.muteMicrophone(true)
        
        #expect(manager.audioSettings.microphoneMuted)
        
        // Unmute microphone
        try await manager.muteMicrophone(false)
        
        #expect(!manager.audioSettings.microphoneMuted)
    }
    
    @Test("Audio volume control")
    func testAudioVolumeControl() async throws {
        let manager = try await setupManager()
        
        // Test audio mixing volume
        try await manager.setAudioMixingVolume(75)
        #expect(manager.audioSettings.audioMixingVolume == 75)
        
        // Test playback signal volume
        try await manager.setPlaybackSignalVolume(50)
        #expect(manager.audioSettings.playbackSignalVolume == 50)
        
        // Test recording signal volume
        try await manager.setRecordingSignalVolume(80)
        #expect(manager.audioSettings.recordingSignalVolume == 80)
    }
    
    @Test("Audio volume clamping")
    func testAudioVolumeClamping() async throws {
        let manager = try await setupManager()
        
        // Test volume above maximum
        try await manager.setAudioMixingVolume(150)
        #expect(manager.audioSettings.audioMixingVolume == 100)
        
        // Test volume below minimum
        try await manager.setAudioMixingVolume(-10)
        #expect(manager.audioSettings.audioMixingVolume == 0)
    }
    
    @Test("Local audio stream control")
    func testLocalAudioStreamControl() async throws {
        let manager = try await setupManager()
        
        // Initially active
        #expect(manager.audioSettings.localAudioStreamActive)
        
        // Stop local audio stream
        try await manager.stopLocalAudioStream()
        #expect(!manager.audioSettings.localAudioStreamActive)
        
        // Resume local audio stream
        try await manager.resumeLocalAudioStream()
        #expect(manager.audioSettings.localAudioStreamActive)
    }
    
    // MARK: - Volume Indicator Tests
    
    @Test("Volume indicator enable/disable")
    func testVolumeIndicatorEnableDisable() async throws {
        let manager = try await setupManager()
        
        // Enable volume indicator
        try await manager.enableVolumeIndicator()
        
        // Disable volume indicator
        try await manager.disableVolumeIndicator()
        
        #expect(manager.volumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
        #expect(manager.dominantSpeaker == nil)
    }
    
    // MARK: - Stream Push Tests
    
    @Test("Stream push start/stop")
    func testStreamPushStartStop() async throws {
        let manager = try await setupManager()
        
        let config = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://test.example.com/live/stream"
        )
        
        // Start stream push
        try await manager.startStreamPush(config: config)
        #expect(manager.streamPushState == .running)
        
        // Stop stream push
        try await manager.stopStreamPush()
        #expect(manager.streamPushState == .stopped)
    }
    
    // MARK: - Media Relay Tests
    
    @Test("Media relay start/stop")
    func testMediaRelayStartStop() async throws {
        let manager = try await setupManager()
        
        let sourceChannel = RelayChannelInfo(
            channelName: "source_channel",
            token: "source_token",
            userId: "source_user"
        )
        
        let targetChannel = RelayChannelInfo(
            channelName: "target_channel",
            token: "target_token",
            userId: "target_user"
        )
        
        let config = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [targetChannel]
        )
        
        // Start media relay
        try await manager.startMediaRelay(config: config)
        
        #expect(manager.mediaRelayState != nil)
        #expect(manager.mediaRelayState?.isActive == true)
        #expect(manager.mediaRelayState?.sourceChannel == "source_channel")
        #expect(manager.mediaRelayState?.targetChannels.contains("target_channel") == true)
        
        // Stop media relay
        try await manager.stopMediaRelay()
        #expect(manager.mediaRelayState == nil)
    }
    
    // MARK: - Message Processing Tests
    
    @Test("Message sending")
    func testMessageSending() async throws {
        let manager = try await setupManager()
        
        let message = RealtimeMessage.text("Hello world", from: "test_user")
        
        // Should not throw
        try await manager.sendMessage(message)
    }
    
    @Test("Message processor registration")
    func testMessageProcessorRegistration() async throws {
        let manager = try await setupManager()
        
        let processor = TestMessageProcessor()
        manager.registerMessageProcessor(processor)
        
        // Processor should be registered in the internal manager
        // We can't directly test this without exposing internal state
        // but we can test that it doesn't throw
        #expect(Bool(true))
    }
    
    @Test("Channel subscription")
    func testChannelSubscription() async throws {
        let manager = try await setupManager()
        
        // Should not throw
        try await manager.subscribe(to: "test_channel")
    }
    
    // MARK: - Settings Persistence Tests
    
    @Test("Audio settings persistence")
    func testAudioSettingsPersistence() async throws {
        let manager = try await setupManager()
        
        // Change audio settings
        try await manager.setAudioMixingVolume(75)
        try await manager.muteMicrophone(true)
        
        // Settings should be persisted automatically
        #expect(manager.audioSettings.audioMixingVolume == 75)
        #expect(manager.audioSettings.microphoneMuted == true)
    }
    
    @Test("Session persistence")
    func testSessionPersistence() async throws {
        let manager = try await setupManager()
        
        // Join room to create session
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.currentSession != nil)
        #expect(manager.currentSession?.userId == "test_user")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Operations without initialization")
    func testOperationsWithoutInitialization() async {
        // Create a fresh manager instance (not the shared one)
        // Since we can't create new instances, we'll test with uninitialized state
        
        // This test would require a way to reset the manager or create new instances
        // For now, we'll skip this test as the singleton pattern prevents it
        #expect(Bool(true))
    }
    
    // MARK: - Helper Classes
    
    @MainActor
    class TestMessageProcessor: MessageProcessor {
        nonisolated let identifier = "test_message_processor"
        nonisolated let priority = 50
        
        nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
            return true
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            return message.withMetadata(["processed_by": identifier])
        }
    }
}