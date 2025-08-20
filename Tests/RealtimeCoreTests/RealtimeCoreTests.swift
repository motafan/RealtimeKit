// RealtimeCoreTests.swift
// Basic tests for RealtimeCore module

import Testing
@testable import RealtimeCore
@testable import RealtimeMocking

@Suite("RealtimeCore Basic Tests")
struct RealtimeCoreTests {
    
    @Test("UserRole permissions test")
    func testUserRolePermissions() {
        #expect(UserRole.broadcaster.hasAudioPermission == true)
        #expect(UserRole.broadcaster.hasVideoPermission == true)
        #expect(UserRole.broadcaster.canManageRoom == true)
        
        #expect(UserRole.audience.hasAudioPermission == false)
        #expect(UserRole.audience.hasVideoPermission == false)
        #expect(UserRole.audience.canManageRoom == false)
        
        #expect(UserRole.coHost.hasAudioPermission == true)
        #expect(UserRole.coHost.hasVideoPermission == true)
        #expect(UserRole.coHost.canManageRoom == false)
        
        #expect(UserRole.moderator.hasAudioPermission == true)
        #expect(UserRole.moderator.hasVideoPermission == false)
        #expect(UserRole.moderator.canManageRoom == true)
    }
    
    @Test("AudioSettings validation test")
    func testAudioSettingsValidation() {
        let settings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 150, // Should be clamped to 100
            playbackSignalVolume: -10, // Should be clamped to 0
            recordingSignalVolume: 50,
            localAudioStreamActive: false
        )
        
        #expect(settings.microphoneMuted == true)
        #expect(settings.audioMixingVolume == 100)
        #expect(settings.playbackSignalVolume == 0)
        #expect(settings.recordingSignalVolume == 50)
        #expect(settings.localAudioStreamActive == false)
    }
    
    @Test("VolumeDetectionConfig validation test")
    func testVolumeDetectionConfigValidation() {
        let config = VolumeDetectionConfig(
            detectionInterval: 50, // Should be clamped to minimum 100
            speakingThreshold: 1.5, // Should be clamped to 1.0
            silenceThreshold: -0.1, // Should be clamped to 0.0
            includeLocalUser: true,
            smoothFactor: 2.0 // Should be clamped to 1.0
        )
        
        #expect(config.detectionInterval == 100)
        #expect(config.speakingThreshold == 1.0)
        #expect(config.silenceThreshold == 0.0)
        #expect(config.smoothFactor == 1.0)
        #expect(config.includeLocalUser == true)
    }
    
    @Test("RealtimeMessage creation test")
    func testRealtimeMessageCreation() {
        let textMessage = RealtimeMessage.text(
            "Hello World",
            from: "user123",
            senderName: "Test User",
            in: "channel1"
        )
        
        #expect(textMessage.messageType == .text)
        #expect(textMessage.content == "Hello World")
        #expect(textMessage.senderId == "user123")
        #expect(textMessage.senderName == "Test User")
        #expect(textMessage.channelId == "channel1")
        #expect(textMessage.isSystemMessage == false)
        
        let systemMessage = RealtimeMessage.system("System notification")
        #expect(systemMessage.messageType == .system)
        #expect(systemMessage.isSystemMessage == true)
    }
    
    @Test("UserSession management test")
    func testUserSessionManagement() {
        let session = UserSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster,
            roomId: nil
        )
        
        #expect(session.userId == "user123")
        #expect(session.userName == "Test User")
        #expect(session.userRole == .broadcaster)
        #expect(session.isInRoom == false)
        
        let sessionWithRoom = session.withRoom("room456")
        #expect(sessionWithRoom.roomId == "room456")
        #expect(sessionWithRoom.isInRoom == true)
        
        let sessionWithNewRole = sessionWithRoom.withRole(.moderator)
        #expect(sessionWithNewRole.userRole == .moderator)
        #expect(sessionWithNewRole.roomId == "room456") // Should preserve room
    }
}