// VolumeIndicatorManagerTests.swift
// Unit tests for VolumeIndicatorManager

import Testing
@testable import RealtimeCore

@Suite("VolumeIndicatorManager Tests")
struct VolumeIndicatorManagerTests {
    
    @MainActor
    func createManager() -> VolumeIndicatorManager {
        return VolumeIndicatorManager()
    }
    
    @Test("Manager initialization")
    @MainActor
    func testManagerInitialization() {
        let manager = createManager()
        
        #expect(manager.isEnabled == false)
        #expect(manager.volumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
        #expect(manager.dominantSpeaker == nil)
        #expect(manager.config == VolumeDetectionConfig.default)
    }
    
    @Test("Enable volume indicator with valid config")
    @MainActor
    func testEnableWithValidConfig() {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            detectionInterval: 500,
            speakingThreshold: 0.4,
            silenceThreshold: 0.1,
            includeLocalUser: true,
            smoothFactor: 0.5
        )
        
        manager.enable(with: config)
        
        #expect(manager.isEnabled == true)
        #expect(manager.config == config)
    }
    
    @Test("Enable volume indicator with invalid config")
    @MainActor
    func testEnableWithInvalidConfig() {
        let manager = createManager()
        let invalidConfig = VolumeDetectionConfig(
            detectionInterval: 300,
            speakingThreshold: 0.2, // Lower than silence threshold
            silenceThreshold: 0.3,
            includeLocalUser: true,
            smoothFactor: 0.3
        )
        
        manager.enable(with: invalidConfig)
        
        // Should remain disabled due to invalid config
        #expect(manager.isEnabled == false)
    }
    
    @Test("Disable volume indicator")
    @MainActor
    func testDisableVolumeIndicator() {
        let manager = createManager()
        let config = VolumeDetectionConfig.default
        
        manager.enable(with: config)
        #expect(manager.isEnabled == true)
        
        manager.disable()
        #expect(manager.isEnabled == false)
        #expect(manager.volumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
        #expect(manager.dominantSpeaker == nil)
    }
    
    @Test("Process volume update when disabled")
    @MainActor
    func testProcessVolumeUpdateWhenDisabled() {
        let manager = createManager()
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.5, isSpeaking: true),
            UserVolumeInfo(userId: "user2", volume: 0.3, isSpeaking: false)
        ]
        
        manager.processVolumeUpdate(volumeInfos)
        
        // Should not process when disabled
        #expect(manager.volumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
    }
    
    @Test("Process volume update when enabled")
    @MainActor
    func testProcessVolumeUpdateWhenEnabled() {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            speakingThreshold: 0.3,
            silenceThreshold: 0.1,
            smoothFactor: 0.0 // No smoothing for predictable results
        )
        manager.enable(with: config)
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.5, isSpeaking: false), // Will be updated based on threshold
            UserVolumeInfo(userId: "user2", volume: 0.2, isSpeaking: false)  // Below threshold
        ]
        
        manager.processVolumeUpdate(volumeInfos)
        
        #expect(manager.volumeInfos.count == 2)
        
        // Check speaking states based on thresholds
        let user1Info = manager.getVolumeInfo(for: "user1")
        let user2Info = manager.getVolumeInfo(for: "user2")
        
        #expect(user1Info?.isSpeaking == true)  // Above speaking threshold
        #expect(user2Info?.isSpeaking == false) // Below speaking threshold
    }
    
    @Test("Smoothing filter application")
    @MainActor
    func testSmoothingFilter() {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            speakingThreshold: 0.3,
            silenceThreshold: 0.1,
            smoothFactor: 0.5 // 50% smoothing
        )
        manager.enable(with: config)
        
        // First update
        let firstUpdate = [UserVolumeInfo(userId: "user1", volume: 0.0, isSpeaking: false)]
        manager.processVolumeUpdate(firstUpdate)
        
        // Second update with higher volume
        let secondUpdate = [UserVolumeInfo(userId: "user1", volume: 1.0, isSpeaking: false)]
        manager.processVolumeUpdate(secondUpdate)
        
        let user1Info = manager.getVolumeInfo(for: "user1")
        
        // Volume should be smoothed: 0.0 * 0.5 + 1.0 * 0.5 = 0.5
        #expect(user1Info?.volume == 0.5)
    }
    
    @Test("Speaking state detection with hysteresis")
    @MainActor
    func testSpeakingStateHysteresis() {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            speakingThreshold: 0.3,
            silenceThreshold: 0.1,
            smoothFactor: 0.0 // No smoothing for predictable results
        )
        manager.enable(with: config)
        
        // Start with volume above speaking threshold
        let firstUpdate = [UserVolumeInfo(userId: "user1", volume: 0.4, isSpeaking: false)]
        manager.processVolumeUpdate(firstUpdate)
        
        let user1AfterFirst = manager.getVolumeInfo(for: "user1")
        #expect(user1AfterFirst?.isSpeaking == true)
        
        // Drop to volume between silence and speaking threshold
        let secondUpdate = [UserVolumeInfo(userId: "user1", volume: 0.2, isSpeaking: false)]
        manager.processVolumeUpdate(secondUpdate)
        
        let user1AfterSecond = manager.getVolumeInfo(for: "user1")
        #expect(user1AfterSecond?.isSpeaking == true) // Still speaking due to hysteresis
        
        // Drop below silence threshold
        let thirdUpdate = [UserVolumeInfo(userId: "user1", volume: 0.05, isSpeaking: false)]
        manager.processVolumeUpdate(thirdUpdate)
        
        let user1AfterThird = manager.getVolumeInfo(for: "user1")
        #expect(user1AfterThird?.isSpeaking == false) // Now stopped speaking
    }
    
    @Test("Dominant speaker detection")
    @MainActor
    func testDominantSpeakerDetection() {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            speakingThreshold: 0.2,
            silenceThreshold: 0.1,
            smoothFactor: 0.0
        )
        manager.enable(with: config)
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.3, isSpeaking: false),
            UserVolumeInfo(userId: "user2", volume: 0.7, isSpeaking: false), // Highest volume
            UserVolumeInfo(userId: "user3", volume: 0.5, isSpeaking: false)
        ]
        
        manager.processVolumeUpdate(volumeInfos)
        
        #expect(manager.dominantSpeaker == "user2")
        #expect(manager.speakingUsers.contains("user1"))
        #expect(manager.speakingUsers.contains("user2"))
        #expect(manager.speakingUsers.contains("user3"))
    }
    
    @Test("Volume event callbacks")
    @MainActor
    func testVolumeEventCallbacks() async {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            speakingThreshold: 0.3,
            silenceThreshold: 0.1,
            smoothFactor: 0.0
        )
        manager.enable(with: config)
        
        var receivedEvents: [VolumeEvent] = []
        var startSpeakingCalls: [(String, UserVolumeInfo)] = []
        var stopSpeakingCalls: [(String, UserVolumeInfo)] = []
        var dominantSpeakerChanges: [String?] = []
        
        manager.onVolumeEvent = { event in
            receivedEvents.append(event)
        }
        
        manager.onUserStartSpeaking = { userId, volumeInfo in
            startSpeakingCalls.append((userId, volumeInfo))
        }
        
        manager.onUserStopSpeaking = { userId, volumeInfo in
            stopSpeakingCalls.append((userId, volumeInfo))
        }
        
        manager.onDominantSpeakerChanged = { userId in
            dominantSpeakerChanges.append(userId)
        }
        
        // First update - user starts speaking
        let firstUpdate = [UserVolumeInfo(userId: "user1", volume: 0.5, isSpeaking: false)]
        manager.processVolumeUpdate(firstUpdate)
        
        // Wait for async event processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(startSpeakingCalls.count == 1)
        #expect(startSpeakingCalls[0].0 == "user1")
        #expect(dominantSpeakerChanges.count == 1)
        #expect(dominantSpeakerChanges[0] == "user1")
        
        // Second update - user stops speaking
        let secondUpdate = [UserVolumeInfo(userId: "user1", volume: 0.05, isSpeaking: false)]
        manager.processVolumeUpdate(secondUpdate)
        
        // Wait for async event processing
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        

        
        #expect(stopSpeakingCalls.count == 1)
        #expect(stopSpeakingCalls[0].0 == "user1")
        #expect(dominantSpeakerChanges.count == 2)
        #expect(dominantSpeakerChanges[1] == nil)
    }
    
    @Test("Local user filtering")
    @MainActor
    func testLocalUserFiltering() {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            speakingThreshold: 0.3,
            silenceThreshold: 0.1,
            includeLocalUser: false, // Exclude local user
            smoothFactor: 0.0
        )
        manager.enable(with: config)
        
        let volumeInfos = [
            UserVolumeInfo(userId: "local_user", volume: 0.5, isSpeaking: false), // Local user
            UserVolumeInfo(userId: "remote_user", volume: 0.4, isSpeaking: false)  // Remote user
        ]
        
        manager.processVolumeUpdate(volumeInfos)
        
        // Should only have remote user
        #expect(manager.volumeInfos.count == 1)
        #expect(manager.getVolumeInfo(for: "remote_user") != nil)
        #expect(manager.getVolumeInfo(for: "local_user") == nil)
    }
    
    @Test("Volume history tracking")
    @MainActor
    func testVolumeHistoryTracking() {
        let manager = createManager()
        let config = VolumeDetectionConfig(
            smoothFactor: 0.0 // No smoothing for predictable results
        )
        manager.enable(with: config)
        
        // Process multiple updates for same user
        for i in 1...3 {
            let volume = Float(i) * 0.2
            let volumeInfos = [UserVolumeInfo(userId: "user1", volume: volume, isSpeaking: false)]
            manager.processVolumeUpdate(volumeInfos)
        }
        
        let averageVolume = manager.getAverageVolume(for: "user1")
        let expectedAverage: Float = (0.2 + 0.4 + 0.6) / 3.0
        
        #expect(abs(averageVolume - expectedAverage) < 0.01)
    }
    
    @Test("Volume trend detection")
    @MainActor
    func testVolumeTrendDetection() {
        let manager = createManager()
        let config = VolumeDetectionConfig.default
        manager.enable(with: config)
        
        // Process increasing volume trend
        let volumes: [Float] = [0.1, 0.3, 0.5]
        for volume in volumes {
            let volumeInfos = [UserVolumeInfo(userId: "user1", volume: volume, isSpeaking: false)]
            manager.processVolumeUpdate(volumeInfos)
        }
        
        let trend = manager.getVolumeTrend(for: "user1")
        #expect(trend == .increasing)
    }
    
    @Test("Config update while enabled")
    @MainActor
    func testConfigUpdateWhileEnabled() {
        let manager = createManager()
        let initialConfig = VolumeDetectionConfig.default
        manager.enable(with: initialConfig)
        
        let newConfig = VolumeDetectionConfig(
            detectionInterval: 200,
            speakingThreshold: 0.5,
            silenceThreshold: 0.2,
            includeLocalUser: false,
            smoothFactor: 0.8
        )
        
        manager.updateConfig(newConfig)
        
        #expect(manager.config == newConfig)
        #expect(manager.isEnabled == true)
    }
    
    @Test("Invalid config update")
    @MainActor
    func testInvalidConfigUpdate() {
        let manager = createManager()
        let validConfig = VolumeDetectionConfig.default
        manager.enable(with: validConfig)
        
        let invalidConfig = VolumeDetectionConfig(
            speakingThreshold: 0.1,
            silenceThreshold: 0.3 // Invalid: silence > speaking
        )
        
        manager.updateConfig(invalidConfig)
        
        // Should keep the old valid config
        #expect(manager.config == validConfig)
    }
}