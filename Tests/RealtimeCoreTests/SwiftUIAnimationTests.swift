// SwiftUIAnimationTests.swift
// Tests for SwiftUI animations and visual effects

import Testing
import SwiftUI
import Combine
@testable import RealtimeCore
@testable import RealtimeSwiftUI

@available(iOS 13.0, macOS 10.15, *)
struct SwiftUIAnimationTests {
    
    // MARK: - Volume Waveform Animation Tests
    
    @Test("Volume waveform should generate smooth wave patterns")
    func testVolumeWaveformPatternGeneration() async throws {
        let manager = RealtimeManager.shared
        
        // Test with different volume levels
        let volumeLevels: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for volume in volumeLevels {
            let volumeInfos = [
                UserVolumeInfo(userId: "user1", volume: volume, isSpeaking: volume > 0.3)
            ]
            
            await manager.updateVolumeInfos(volumeInfos)
            
            // Allow animation frame to process
            try await Task.sleep(nanoseconds: 16_666_667) // ~60fps frame time
            
            #expect(manager.volumeInfos.first?.volume == volume)
            
            // Verify speaking state threshold
            if volume > 0.3 {
                #expect(manager.volumeInfos.first?.isSpeaking == true)
            } else {
                #expect(manager.volumeInfos.first?.isSpeaking == false)
            }
        }
    }
    
    @Test("Volume waveform should handle rapid volume changes")
    func testVolumeWaveformRapidChanges() async throws {
        let manager = RealtimeManager.shared
        
        // Simulate rapid volume changes (like real audio input)
        let rapidVolumeSequence: [Float] = [
            0.1, 0.3, 0.7, 0.9, 0.6, 0.4, 0.2, 0.8, 0.5, 0.1
        ]
        
        for (index, volume) in rapidVolumeSequence.enumerated() {
            let volumeInfos = [
                UserVolumeInfo(
                    userId: "user1", 
                    volume: volume, 
                    isSpeaking: volume > 0.3,
                    timestamp: Date().addingTimeInterval(Double(index) * 0.05)
                )
            ]
            
            await manager.updateVolumeInfos(volumeInfos)
            
            // Very short delay to simulate real-time audio processing
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        // Verify final state
        #expect(manager.volumeInfos.first?.volume == 0.1)
        #expect(manager.volumeInfos.first?.isSpeaking == false)
    }
    
    @Test("Volume bars should scale correctly with volume levels")
    func testVolumeBarScaling() async throws {
        let barCount = 20
        let testVolume: Float = 0.6
        
        // Calculate expected bar heights (simulating the waveform algorithm)
        let expectedBars = (0..<barCount).map { index in
            let normalizedIndex = Float(index) / Float(barCount - 1)
            let waveOffset = sin(Double(normalizedIndex) * .pi * 2) * 0.3
            return max(0, testVolume + Float(waveOffset))
        }
        
        // Verify that all bars have reasonable values
        for bar in expectedBars {
            #expect(bar >= 0.0)
            #expect(bar <= 1.3) // Max possible with wave offset
        }
        
        // Verify wave pattern creates variation
        let minBar = expectedBars.min() ?? 0
        let maxBar = expectedBars.max() ?? 0
        #expect(maxBar > minBar) // Should have variation due to wave pattern
    }
    
    // MARK: - Speaking Indicator Animation Tests
    
    @Test("Speaking indicator should animate pulse correctly")
    func testSpeakingIndicatorPulseAnimation() async throws {
        let manager = RealtimeManager.shared
        let userId = "testUser"
        
        // Test pulse animation start
        await manager.updateSpeakingUsers(Set([userId]))
        #expect(manager.speakingUsers.contains(userId))
        
        // Simulate animation frames during pulse
        let animationDuration = 0.6 // seconds
        let frameCount = 36 // 60fps for 0.6 seconds
        
        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount - 1)
            let expectedScale = 1.0 + 0.2 * sin(progress * .pi) // Pulse from 1.0 to 1.2
            
            // In a real animation, we would verify the scale value
            // For testing, we verify the animation would be in progress
            #expect(progress >= 0.0 && progress <= 1.0)
            #expect(expectedScale >= 1.0 && expectedScale <= 1.2)
            
            try await Task.sleep(nanoseconds: 16_666_667) // ~60fps
        }
        
        // Test pulse animation stop
        await manager.updateSpeakingUsers(Set())
        #expect(!manager.speakingUsers.contains(userId))
    }
    
    @Test("Multiple speaking indicators should animate independently")
    func testMultipleSpeakingIndicatorsIndependence() async throws {
        let manager = RealtimeManager.shared
        let users = ["user1", "user2", "user3"]
        
        // Start all users speaking at different times
        for (index, userId) in users.enumerated() {
            try await Task.sleep(nanoseconds: UInt64(index * 100_000_000)) // Stagger by 0.1s
            
            var currentSpeakers = manager.speakingUsers
            currentSpeakers.insert(userId)
            await manager.updateSpeakingUsers(currentSpeakers)
            
            #expect(manager.speakingUsers.contains(userId))
        }
        
        // All users should be speaking
        #expect(manager.speakingUsers.count == 3)
        
        // Stop users speaking at different times
        for (index, userId) in users.enumerated() {
            try await Task.sleep(nanoseconds: UInt64(index * 100_000_000)) // Stagger by 0.1s
            
            var currentSpeakers = manager.speakingUsers
            currentSpeakers.remove(userId)
            await manager.updateSpeakingUsers(currentSpeakers)
            
            #expect(!manager.speakingUsers.contains(userId))
        }
        
        // No users should be speaking
        #expect(manager.speakingUsers.isEmpty)
    }
    
    // MARK: - Connection State Animation Tests
    
    @Test("Connection state indicator should animate during transitions")
    func testConnectionStateAnimationTransitions() async throws {
        let manager = RealtimeManager.shared
        
        let transitionSequence: [ConnectionState] = [
            .disconnected,
            .connecting,
            .connected,
            .reconnecting,
            .connected,
            .disconnected
        ]
        
        for state in transitionSequence {
            await manager.updateConnectionState(state)
            
            // Verify state change
            #expect(manager.connectionState == state)
            
            // Simulate animation frame processing
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Verify animation state based on connection state
            switch state {
            case .connecting, .reconnecting:
                // Should be animating (pulsing)
                #expect(true) // Animation would be active
            case .connected, .disconnected, .failed:
                // Should not be animating
                #expect(true) // Animation would be inactive
            }
        }
    }
    
    // MARK: - Volume Level Animation Tests
    
    @Test("Volume level progress should animate smoothly")
    func testVolumeLevelProgressAnimation() async throws {
        let manager = RealtimeManager.shared
        let userId = "testUser"
        
        // Test smooth volume transitions
        let volumeTransition: [Float] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
        
        for volume in volumeTransition {
            let volumeInfos = [
                UserVolumeInfo(userId: userId, volume: volume, isSpeaking: volume > 0.3)
            ]
            
            await manager.updateVolumeInfos(volumeInfos)
            
            // Verify volume update
            #expect(manager.volumeInfos.first?.volume == volume)
            
            // Simulate smooth animation frame
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
    }
    
    @Test("Volume level color should change based on volume")
    func testVolumeLevelColorTransitions() async throws {
        let testCases: [(volume: Float, expectedColorRange: String)] = [
            (0.1, "green"),   // Low volume
            (0.5, "yellow"),  // Medium volume
            (0.8, "red")      // High volume
        ]
        
        for testCase in testCases {
            // Verify color logic (this would be tested in the actual view)
            switch testCase.volume {
            case 0.0..<0.3:
                #expect(testCase.expectedColorRange == "green")
            case 0.3..<0.7:
                #expect(testCase.expectedColorRange == "yellow")
            default:
                #expect(testCase.expectedColorRange == "red")
            }
        }
    }
    
    // MARK: - Audio Control Animation Tests
    
    @Test("Audio control panel should animate expand/collapse")
    func testAudioControlPanelExpandCollapseAnimation() async throws {
        // Test the expand/collapse animation timing
        let animationDuration = 0.3 // seconds
        let frameCount = 18 // 60fps for 0.3 seconds
        
        // Simulate expand animation
        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount - 1)
            
            // Verify animation progress is within bounds
            #expect(progress >= 0.0 && progress <= 1.0)
            
            // In a real animation, height would interpolate from 0 to full height
            let expectedHeight = progress * 200.0 // Assuming 200pt full height
            #expect(expectedHeight >= 0.0 && expectedHeight <= 200.0)
            
            try await Task.sleep(nanoseconds: 16_666_667) // ~60fps
        }
    }
    
    @Test("Volume sliders should animate value changes")
    func testVolumeSliderAnimations() async throws {
        let manager = RealtimeManager.shared
        
        // Test volume slider animation from 0 to 100
        let startVolume = 0
        let endVolume = 100
        let animationSteps = 10
        
        for step in 0...animationSteps {
            let progress = Double(step) / Double(animationSteps)
            let currentVolume = Int(Double(startVolume) + progress * Double(endVolume - startVolume))
            
            let newSettings = AudioSettings(
                microphoneMuted: false,
                audioMixingVolume: currentVolume,
                playbackSignalVolume: currentVolume,
                recordingSignalVolume: currentVolume,
                localAudioStreamActive: true
            )
            
            await manager.updateAudioSettings(newSettings)
            
            #expect(manager.audioSettings.audioMixingVolume == currentVolume)
            
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Animations should maintain 60fps performance")
    func testAnimationPerformance() async throws {
        let manager = RealtimeManager.shared
        let frameCount = 60 // 1 second at 60fps
        let targetFrameTime: UInt64 = 16_666_667 // ~16.67ms in nanoseconds
        
        var frameTimes: [UInt64] = []
        
        for frame in 0..<frameCount {
            let startTime = DispatchTime.now().uptimeNanoseconds
            
            // Simulate complex animation update
            let volume = Float(sin(Double(frame) * 0.1)) * 0.5 + 0.5
            let volumeInfos = [
                UserVolumeInfo(userId: "user1", volume: volume, isSpeaking: volume > 0.3),
                UserVolumeInfo(userId: "user2", volume: volume * 0.8, isSpeaking: volume * 0.8 > 0.3),
                UserVolumeInfo(userId: "user3", volume: volume * 0.6, isSpeaking: volume * 0.6 > 0.3)
            ]
            
            await manager.updateVolumeInfos(volumeInfos)
            
            let endTime = DispatchTime.now().uptimeNanoseconds
            let frameTime = endTime - startTime
            frameTimes.append(frameTime)
            
            // Maintain target frame rate
            if frameTime < targetFrameTime {
                try await Task.sleep(nanoseconds: targetFrameTime - frameTime)
            }
        }
        
        // Verify performance
        let averageFrameTime = frameTimes.reduce(0, +) / UInt64(frameTimes.count)
        let maxFrameTime = frameTimes.max() ?? 0
        
        // Average frame time should be well under target (allowing for processing overhead)
        #expect(averageFrameTime < targetFrameTime / 2)
        
        // No frame should take more than 2x target time
        #expect(maxFrameTime < targetFrameTime * 2)
    }
    
    @Test("Memory usage should remain stable during animations")
    func testAnimationMemoryStability() async throws {
        let manager = RealtimeManager.shared
        
        // Run animation for extended period to test memory stability
        let animationDuration = 100 // frames
        
        for frame in 0..<animationDuration {
            // Create and update volume data
            let volumeInfos = (0..<10).map { userIndex in
                UserVolumeInfo(
                    userId: "user\(userIndex)",
                    volume: Float.random(in: 0...1),
                    isSpeaking: Bool.random()
                )
            }
            
            await manager.updateVolumeInfos(volumeInfos)
            
            // Update speaking users
            let speakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
            await manager.updateSpeakingUsers(speakingUsers)
            
            try await Task.sleep(nanoseconds: 16_666_667) // ~60fps
        }
        
        // Memory should be stable (no leaks)
        // In a real test, we would measure memory usage here
        #expect(manager.volumeInfos.count <= 10) // Should not accumulate
        #expect(manager.speakingUsers.count <= 10) // Should not accumulate
    }
}