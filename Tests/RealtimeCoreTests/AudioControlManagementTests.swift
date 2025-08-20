// AudioControlManagementTests.swift
// Unit tests for audio control and settings management

import Testing
@testable import RealtimeCore

@Suite("Audio Control Management Tests")
struct AudioControlManagementTests {
    
    @MainActor
    func setupManager() async throws -> RealtimeManager {
        let manager = RealtimeManager.shared
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Login user first
        try await manager.loginUser(
            userId: "test-user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        return manager
    }
    
    @Test("Audio settings are properly initialized")
    @MainActor
    func testAudioSettingsInitialization() async throws {
        let manager = try await setupManager()
        
        // Check default audio settings
        #expect(manager.audioSettings.microphoneMuted == false)
        #expect(manager.audioSettings.audioMixingVolume == 100)
        #expect(manager.audioSettings.playbackSignalVolume == 100)
        #expect(manager.audioSettings.recordingSignalVolume == 100)
        #expect(manager.audioSettings.localAudioStreamActive == true)
    }
    
    @Test("Microphone mute/unmute works correctly")
    @MainActor
    func testMicrophoneMuteUnmute() async throws {
        let manager = try await setupManager()
        
        // Initially unmuted
        #expect(manager.isMicrophoneMuted() == false)
        
        // Mute microphone
        try await manager.muteMicrophone(true)
        #expect(manager.isMicrophoneMuted() == true)
        #expect(manager.audioSettings.microphoneMuted == true)
        
        // Unmute microphone
        try await manager.muteMicrophone(false)
        #expect(manager.isMicrophoneMuted() == false)
        #expect(manager.audioSettings.microphoneMuted == false)
    }
    
    @Test("Audio volume controls work correctly")
    @MainActor
    func testAudioVolumeControls() async throws {
        let manager = try await setupManager()
        
        // Test audio mixing volume
        try await manager.setAudioMixingVolume(75)
        #expect(manager.getAudioMixingVolume() == 75)
        #expect(manager.audioSettings.audioMixingVolume == 75)
        
        // Test playback signal volume
        try await manager.setPlaybackSignalVolume(50)
        #expect(manager.getPlaybackSignalVolume() == 50)
        #expect(manager.audioSettings.playbackSignalVolume == 50)
        
        // Test recording signal volume
        try await manager.setRecordingSignalVolume(25)
        #expect(manager.getRecordingSignalVolume() == 25)
        #expect(manager.audioSettings.recordingSignalVolume == 25)
    }
    
    @Test("Volume values are clamped to valid range")
    @MainActor
    func testVolumeValueClamping() async throws {
        let manager = try await setupManager()
        
        // Test values above 100 are clamped to 100
        try await manager.setAudioMixingVolume(150)
        #expect(manager.getAudioMixingVolume() == 100)
        
        // Test negative values are clamped to 0
        try await manager.setPlaybackSignalVolume(-10)
        #expect(manager.getPlaybackSignalVolume() == 0)
        
        // Test recording signal volume clamping
        try await manager.setRecordingSignalVolume(200)
        #expect(manager.getRecordingSignalVolume() == 100)
    }
    
    @Test("Local audio stream control works correctly")
    @MainActor
    func testLocalAudioStreamControl() async throws {
        let manager = try await setupManager()
        
        // Initially active
        #expect(manager.isLocalAudioStreamActive() == true)
        
        // Stop local audio stream
        try await manager.stopLocalAudioStream()
        #expect(manager.isLocalAudioStreamActive() == false)
        #expect(manager.audioSettings.localAudioStreamActive == false)
        
        // Resume local audio stream
        try await manager.resumeLocalAudioStream()
        #expect(manager.isLocalAudioStreamActive() == true)
        #expect(manager.audioSettings.localAudioStreamActive == true)
    }
    
    @Test("Bulk audio settings update works correctly")
    @MainActor
    func testBulkAudioSettingsUpdate() async throws {
        let manager = try await setupManager()
        
        // Update multiple settings at once
        try await manager.updateAudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 80,
            playbackSignalVolume: 60,
            recordingSignalVolume: 40,
            localAudioStreamActive: false
        )
        
        // Verify all settings were updated
        #expect(manager.isMicrophoneMuted() == true)
        #expect(manager.getAudioMixingVolume() == 80)
        #expect(manager.getPlaybackSignalVolume() == 60)
        #expect(manager.getRecordingSignalVolume() == 40)
        #expect(manager.isLocalAudioStreamActive() == false)
    }
    
    @Test("Partial audio settings update works correctly")
    @MainActor
    func testPartialAudioSettingsUpdate() async throws {
        let manager = try await setupManager()
        
        // Set initial values
        try await manager.setAudioMixingVolume(50)
        try await manager.setPlaybackSignalVolume(60)
        
        // Update only some settings
        try await manager.updateAudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 70
            // Other settings should remain unchanged
        )
        
        // Verify updated settings
        #expect(manager.isMicrophoneMuted() == true)
        #expect(manager.getAudioMixingVolume() == 70)
        
        // Verify unchanged settings
        #expect(manager.getPlaybackSignalVolume() == 60)
        #expect(manager.isLocalAudioStreamActive() == true)
    }
    
    @Test("Audio settings validation works correctly")
    @MainActor
    func testAudioSettingsValidation() async throws {
        let manager = try await setupManager()
        
        // Valid settings
        let validSettings = AudioSettings(
            microphoneMuted: false,
            audioMixingVolume: 50,
            playbackSignalVolume: 75,
            recordingSignalVolume: 25,
            localAudioStreamActive: true
        )
        #expect(manager.validateAudioSettings(validSettings) == true)
        
        // Invalid audio mixing volume (too high)
        let invalidSettings1 = AudioSettings(
            microphoneMuted: false,
            audioMixingVolume: 150,
            playbackSignalVolume: 75,
            recordingSignalVolume: 25,
            localAudioStreamActive: true
        )
        #expect(manager.validateAudioSettings(invalidSettings1) == false)
        
        // Invalid playback volume (negative)
        let invalidSettings2 = AudioSettings(
            microphoneMuted: false,
            audioMixingVolume: 50,
            playbackSignalVolume: -10,
            recordingSignalVolume: 25,
            localAudioStreamActive: true
        )
        #expect(manager.validateAudioSettings(invalidSettings2) == false)
    }
    
    @Test("Audio settings reset works correctly")
    @MainActor
    func testAudioSettingsReset() async throws {
        let manager = try await setupManager()
        
        // Change settings from default
        try await manager.updateAudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 50,
            playbackSignalVolume: 25,
            recordingSignalVolume: 75,
            localAudioStreamActive: false
        )
        
        // Verify settings are changed
        #expect(manager.isMicrophoneMuted() == true)
        #expect(manager.getAudioMixingVolume() == 50)
        
        // Reset to default
        try await manager.resetAudioSettings()
        
        // Verify settings are back to default
        #expect(manager.isMicrophoneMuted() == false)
        #expect(manager.getAudioMixingVolume() == 100)
        #expect(manager.getPlaybackSignalVolume() == 100)
        #expect(manager.getRecordingSignalVolume() == 100)
        #expect(manager.isLocalAudioStreamActive() == true)
    }
    
    @Test("Audio settings summary provides correct information")
    @MainActor
    func testAudioSettingsSummary() async throws {
        let manager = try await setupManager()
        
        // Set specific values
        try await manager.updateAudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 80,
            playbackSignalVolume: 60,
            recordingSignalVolume: 40,
            localAudioStreamActive: false
        )
        
        let summary = manager.getAudioSettingsSummary()
        
        #expect(summary["microphoneMuted"] as? Bool == true)
        #expect(summary["audioMixingVolume"] as? Int == 80)
        #expect(summary["playbackSignalVolume"] as? Int == 60)
        #expect(summary["recordingSignalVolume"] as? Int == 40)
        #expect(summary["localAudioStreamActive"] as? Bool == false)
        #expect(summary["lastModified"] != nil)
    }
    
    @Test("Audio settings persistence works correctly")
    @MainActor
    func testAudioSettingsPersistence() async throws {
        let manager = try await setupManager()
        
        // Change settings
        try await manager.updateAudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 50
        )
        
        // Force save
        manager.saveAudioSettings()
        
        // Verify settings are not marked as unsaved
        #expect(manager.hasUnsavedAudioSettings() == false)
        
        // Make another change without saving
        try await manager.setRecordingSignalVolume(25)
        
        // Verify settings are marked as unsaved
        #expect(manager.hasUnsavedAudioSettings() == true)
    }
    
    @Test("Audio settings are restored after configuration")
    @MainActor
    func testAudioSettingsRestoration() async throws {
        let manager = RealtimeManager.shared
        
        // Configure and set custom settings
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        try await manager.loginUser(
            userId: "test-user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        try await manager.updateAudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 60,
            playbackSignalVolume: 40
        )
        
        // Save settings
        manager.saveAudioSettings()
        
        // Reconfigure (simulating app restart)
        try await manager.configure(provider: .mock, config: config)
        
        // Verify settings were restored and synced
        #expect(manager.isMicrophoneMuted() == true)
        #expect(manager.getAudioMixingVolume() == 60)
        #expect(manager.getPlaybackSignalVolume() == 40)
    }
}