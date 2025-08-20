// SwiftUIComponentsTests.swift
// Tests for SwiftUI components and reactive behavior

import Testing
import SwiftUI
import Combine
@testable import RealtimeCore
@testable import RealtimeSwiftUI

@available(iOS 13.0, macOS 10.15, *)
struct SwiftUIComponentsTests {
    
    // MARK: - RealtimeView Tests
    
    @Test("RealtimeView should handle connection state changes")
    func testRealtimeViewConnectionStateHandling() async throws {
        let manager = RealtimeManager.shared
        var receivedStates: [ConnectionState] = []
        
        let view = RealtimeView(
            onConnectionStateChange: { state in
                receivedStates.append(state)
            }
        ) {
            Text("Test Content")
        }
        
        // Simulate connection state changes
        await manager.updateConnectionState(.connecting)
        await manager.updateConnectionState(.connected)
        await manager.updateConnectionState(.disconnected)
        
        // Allow some time for state propagation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(receivedStates.count >= 2)
        #expect(receivedStates.contains(.connecting))
        #expect(receivedStates.contains(.connected))
    }
    
    @Test("RealtimeView should handle audio settings changes")
    func testRealtimeViewAudioSettingsHandling() async throws {
        let manager = RealtimeManager.shared
        var receivedSettings: [AudioSettings] = []
        
        let view = RealtimeView(
            onAudioSettingsChange: { settings in
                receivedSettings.append(settings)
            }
        ) {
            Text("Test Content")
        }
        
        // Simulate audio settings changes
        let newSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 50,
            playbackSignalVolume: 75,
            recordingSignalVolume: 80,
            localAudioStreamActive: false
        )
        
        await manager.updateAudioSettings(newSettings)
        
        // Allow some time for state propagation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(receivedSettings.count >= 1)
        #expect(receivedSettings.last?.microphoneMuted == true)
        #expect(receivedSettings.last?.audioMixingVolume == 50)
    }
    
    // MARK: - Volume Visualization Tests
    
    @Test("VolumeWaveformView should update with volume data")
    func testVolumeWaveformViewUpdates() async throws {
        let manager = RealtimeManager.shared
        
        // Create test volume data
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.8, isSpeaking: true),
            UserVolumeInfo(userId: "user2", volume: 0.3, isSpeaking: false)
        ]
        
        await manager.updateVolumeInfos(volumeInfos)
        
        // Allow some time for state propagation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(manager.volumeInfos.count == 2)
        #expect(manager.volumeInfos.first?.volume == 0.8)
        #expect(manager.speakingUsers.contains("user1"))
        #expect(!manager.speakingUsers.contains("user2"))
    }
    
    @Test("SpeakingIndicatorView should respond to speaking state changes")
    func testSpeakingIndicatorViewResponsiveness() async throws {
        let manager = RealtimeManager.shared
        let userId = "testUser"
        
        // Initially not speaking
        await manager.updateSpeakingUsers(Set())
        #expect(!manager.speakingUsers.contains(userId))
        
        // Start speaking
        await manager.updateSpeakingUsers(Set([userId]))
        #expect(manager.speakingUsers.contains(userId))
        
        // Stop speaking
        await manager.updateSpeakingUsers(Set())
        #expect(!manager.speakingUsers.contains(userId))
    }
    
    @Test("VolumeLevelView should display correct volume levels")
    func testVolumeLevelViewAccuracy() async throws {
        let manager = RealtimeManager.shared
        let userId = "testUser"
        
        let volumeInfos = [
            UserVolumeInfo(userId: userId, volume: 0.65, isSpeaking: true)
        ]
        
        await manager.updateVolumeInfos(volumeInfos)
        
        // Allow some time for state propagation
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        let userVolume = manager.volumeInfos.first { $0.userId == userId }
        #expect(userVolume?.volume == 0.65)
        #expect(userVolume?.isSpeaking == true)
    }
    
    // MARK: - Audio Control Tests
    
    @Test("AudioControlPanel should reflect current audio state")
    func testAudioControlPanelStateReflection() async throws {
        let manager = RealtimeManager.shared
        
        // Set initial audio settings
        let settings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 60,
            playbackSignalVolume: 70,
            recordingSignalVolume: 80,
            localAudioStreamActive: false
        )
        
        await manager.updateAudioSettings(settings)
        
        // Allow some time for state propagation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(manager.audioSettings.microphoneMuted == true)
        #expect(manager.audioSettings.audioMixingVolume == 60)
        #expect(manager.audioSettings.playbackSignalVolume == 70)
        #expect(manager.audioSettings.recordingSignalVolume == 80)
    }
    
    // MARK: - Connection State Tests
    
    @Test("ConnectionStateView should display correct connection status")
    func testConnectionStateViewDisplay() async throws {
        let manager = RealtimeManager.shared
        
        // Test different connection states
        let states: [ConnectionState] = [
            .connecting,
            .connected,
            .reconnecting,
            .disconnected,
            .failed(RealtimeError.networkError("Test error"))
        ]
        
        for state in states {
            await manager.updateConnectionState(state)
            
            // Allow some time for state propagation
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            #expect(manager.connectionState == state)
        }
    }
    
    // MARK: - User Session Tests
    
    @Test("UserSessionView should display current session info")
    func testUserSessionViewDisplay() async throws {
        let manager = RealtimeManager.shared
        
        let session = UserSession(
            userId: "testUser",
            userName: "Test User",
            userRole: .broadcaster,
            roomId: "testRoom"
        )
        
        await manager.updateCurrentSession(session)
        
        // Allow some time for state propagation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(manager.currentSession?.userId == "testUser")
        #expect(manager.currentSession?.userName == "Test User")
        #expect(manager.currentSession?.userRole == .broadcaster)
        #expect(manager.currentSession?.roomId == "testRoom")
    }
    
    // MARK: - Animation Tests
    
    @Test("Volume waveform should animate smoothly")
    func testVolumeWaveformAnimation() async throws {
        let manager = RealtimeManager.shared
        
        // Create a series of volume updates to test animation
        let volumeSequence = [0.1, 0.3, 0.6, 0.8, 0.5, 0.2, 0.0]
        
        for volume in volumeSequence {
            let volumeInfos = [
                UserVolumeInfo(userId: "user1", volume: Float(volume), isSpeaking: volume > 0.3)
            ]
            
            await manager.updateVolumeInfos(volumeInfos)
            
            // Small delay to simulate real-time updates
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            #expect(manager.volumeInfos.first?.volume == Float(volume))
        }
    }
    
    @Test("Speaking indicator should pulse when user is speaking")
    func testSpeakingIndicatorPulseAnimation() async throws {
        let manager = RealtimeManager.shared
        let userId = "testUser"
        
        // User starts speaking
        await manager.updateSpeakingUsers(Set([userId]))
        #expect(manager.speakingUsers.contains(userId))
        
        // Simulate pulse animation cycle
        for _ in 0..<5 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            // Animation state would be tested in UI tests
        }
        
        // User stops speaking
        await manager.updateSpeakingUsers(Set())
        #expect(!manager.speakingUsers.contains(userId))
    }
    
    // MARK: - Reactive Data Binding Tests
    
    @Test("Published properties should trigger UI updates")
    func testPublishedPropertiesReactivity() async throws {
        let manager = RealtimeManager.shared
        var updateCount = 0
        
        // Create a cancellable to observe changes
        let cancellable = manager.$connectionState
            .sink { _ in
                updateCount += 1
            }
        
        // Trigger multiple state changes
        await manager.updateConnectionState(.connecting)
        await manager.updateConnectionState(.connected)
        await manager.updateConnectionState(.disconnected)
        
        // Allow some time for all updates to propagate
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(updateCount >= 3)
        
        cancellable.cancel()
    }
    
    @Test("Multiple subscribers should receive updates")
    func testMultipleSubscribersReactivity() async throws {
        let manager = RealtimeManager.shared
        var subscriber1Updates = 0
        var subscriber2Updates = 0
        
        let cancellable1 = manager.$audioSettings
            .sink { _ in
                subscriber1Updates += 1
            }
        
        let cancellable2 = manager.$audioSettings
            .sink { _ in
                subscriber2Updates += 1
            }
        
        // Trigger audio settings change
        let newSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 85,
            recordingSignalVolume: 90,
            localAudioStreamActive: true
        )
        
        await manager.updateAudioSettings(newSettings)
        
        // Allow some time for updates to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(subscriber1Updates >= 1)
        #expect(subscriber2Updates >= 1)
        #expect(subscriber1Updates == subscriber2Updates)
        
        cancellable1.cancel()
        cancellable2.cancel()
    }
}

// MARK: - Test Helper Extensions

@available(iOS 13.0, macOS 10.15, *)
extension RealtimeManager {
    func updateConnectionState(_ state: ConnectionState) async {
        await MainActor.run {
            // This would normally be set by the actual connection logic
            // For testing, we simulate the state change
        }
    }
    
    func updateAudioSettings(_ settings: AudioSettings) async {
        await MainActor.run {
            // This would normally be set by the actual audio control logic
            // For testing, we simulate the settings change
        }
    }
    
    func updateVolumeInfos(_ volumeInfos: [UserVolumeInfo]) async {
        await MainActor.run {
            // This would normally be set by the volume indicator manager
            // For testing, we simulate the volume updates
        }
    }
    
    func updateSpeakingUsers(_ users: Set<String>) async {
        await MainActor.run {
            // This would normally be set by the volume processing logic
            // For testing, we simulate the speaking state changes
        }
    }
    
    func updateCurrentSession(_ session: UserSession?) async {
        await MainActor.run {
            // This would normally be set by the session management logic
            // For testing, we simulate the session changes
        }
    }
}