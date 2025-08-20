// ParameterizedTests.swift
// Parameterized tests for comprehensive edge case coverage

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Parameterized Tests")
struct ParameterizedTests {
    
    // MARK: - Volume Range Testing
    
    @Test("Volume validation with various inputs", arguments: [
        (-1.0, 0.0),      // Below minimum
        (0.0, 0.0),       // Minimum
        (0.5, 0.5),       // Valid middle
        (1.0, 1.0),       // Maximum
        (1.5, 1.0),       // Above maximum
        (Float.nan, 0.0), // NaN
        (Float.infinity, 1.0), // Infinity
        (-Float.infinity, 0.0) // Negative infinity
    ])
    func testVolumeValidation(input: Float, expected: Float) {
        let volumeInfo = UserVolumeInfo(
            userId: "test_user",
            volume: input,
            isSpeaking: false
        )
        
        if expected.isNaN {
            #expect(volumeInfo.volume.isNaN)
        } else {
            #expect(volumeInfo.volume == expected)
        }
    }
    
    // MARK: - Audio Settings Volume Testing
    
    @Test("Audio volume clamping", arguments: [
        (-50, 0),    // Below minimum
        (0, 0),      // Minimum
        (50, 50),    // Valid middle
        (100, 100),  // Maximum
        (150, 100),  // Above maximum
        (Int.min, 0), // Extreme minimum
        (Int.max, 100) // Extreme maximum
    ])
    func testAudioVolumeClamping(input: Int, expected: Int) {
        let settings = AudioSettings(
            audioMixingVolume: input,
            playbackSignalVolume: input,
            recordingSignalVolume: input
        )
        
        #expect(settings.audioMixingVolume == expected)
        #expect(settings.playbackSignalVolume == expected)
        #expect(settings.recordingSignalVolume == expected)
    }
    
    // MARK: - Detection Interval Testing
    
    @Test("Detection interval clamping", arguments: [
        (50, 100),     // Below minimum
        (100, 100),    // Minimum
        (300, 300),    // Valid value
        (5000, 5000),  // Maximum
        (10000, 5000), // Above maximum
        (0, 100),      // Zero
        (-100, 100)    // Negative
    ])
    func testDetectionIntervalClamping(input: Int, expected: Int) {
        let config = VolumeDetectionConfig(detectionInterval: input)
        #expect(config.detectionInterval == expected)
    }
    
    // MARK: - User Role Permission Testing
    
    @Test("User role permissions", arguments: [
        (UserRole.broadcaster, true, true),
        (UserRole.audience, false, false),
        (UserRole.coHost, true, true),
        (UserRole.moderator, true, false)
    ])
    func testUserRolePermissions(role: UserRole, hasAudio: Bool, hasVideo: Bool) {
        #expect(role.hasAudioPermission == hasAudio)
        #expect(role.hasVideoPermission == hasVideo)
    }
    
    // MARK: - URL Validation Testing
    
    @Test("Stream push URL validation", arguments: [
        ("rtmp://example.com/live/stream", true),
        ("rtmps://example.com/live/stream", true),
        ("http://example.com/stream", false),
        ("https://example.com/stream", false),
        ("ftp://example.com/stream", false),
        ("", false),
        ("not-a-url", false),
        ("rtmp://", false),
        ("rtmp://example.com", true), // Minimal valid URL
        ("rtmp://example.com/", true)
    ])
    func testStreamPushURLValidation(url: String, shouldBeValid: Bool) {
        if shouldBeValid {
            #expect(throws: Never.self) {
                let _ = try StreamPushConfig.standard720p(pushUrl: url)
            }
        } else {
            #expect(throws: RealtimeError.self) {
                let _ = try StreamPushConfig.standard720p(pushUrl: url)
            }
        }
    }
    
    // MARK: - String Length Validation Testing
    
    @Test("User ID length validation", arguments: [
        ("", false),                                    // Empty
        ("a", true),                                   // Single character
        ("valid_user_id", true),                       // Normal length
        (String(repeating: "a", count: 64), true),     // Maximum length
        (String(repeating: "a", count: 65), false),    // Too long
        (String(repeating: "a", count: 255), false),   // Way too long
        (String(repeating: "a", count: 1000), false)   // Extremely long
    ])
    func testUserIdLengthValidation(userId: String, shouldBeValid: Bool) {
        let session = UserSession(
            userId: userId,
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(session.isValid == shouldBeValid)
    }
    
    // MARK: - Threshold Validation Testing
    
    @Test("Volume threshold validation", arguments: [
        (0.1, 0.3, true),   // Valid: silence < speaking
        (0.3, 0.3, false),  // Invalid: silence == speaking
        (0.5, 0.3, false),  // Invalid: silence > speaking
        (0.0, 0.0, false),  // Invalid: both zero
        (0.0, 1.0, true),   // Valid: maximum range
        (-0.1, 0.5, true),  // Invalid silence, valid speaking (clamped)
        (0.2, 1.1, true)    // Valid silence, invalid speaking (clamped)
    ])
    func testVolumeThresholdValidation(silence: Float, speaking: Float, shouldBeValid: Bool) {
        let config = VolumeDetectionConfig(
            speakingThreshold: speaking,
            silenceThreshold: silence
        )
        
        #expect(config.isValid == shouldBeValid)
    }
    
    // MARK: - Stream Configuration Testing
    
    @Test("Stream resolution validation", arguments: [
        (0, 720, false),      // Invalid width
        (1280, 0, false),     // Invalid height
        (-100, 720, false),   // Negative width
        (1280, -100, false),  // Negative height
        (1280, 720, true),    // Valid HD
        (1920, 1080, true),   // Valid Full HD
        (3840, 2160, true),   // Valid 4K
        (100, 100, true),     // Valid small resolution
        (10000, 10000, false) // Too large resolution
    ])
    func testStreamResolutionValidation(width: Int, height: Int, shouldBeValid: Bool) {
        if shouldBeValid {
            #expect(throws: Never.self) {
                let _ = try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: width,
                    height: height,
                    videoBitrate: 2000,
                    videoFramerate: 30,
                    audioBitrate: 128,
                    audioSampleRate: 44100
                )
            }
        } else {
            #expect(throws: RealtimeError.self) {
                let _ = try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: width,
                    height: height,
                    videoBitrate: 2000,
                    videoFramerate: 30,
                    audioBitrate: 128,
                    audioSampleRate: 44100
                )
            }
        }
    }
    
    // MARK: - Bitrate Validation Testing
    
    @Test("Video bitrate validation", arguments: [
        (-1, false),     // Negative
        (0, false),      // Zero
        (1, true),       // Minimum valid
        (1000, true),    // Normal
        (10000, true),   // High
        (100000, false), // Too high
        (Int.max, false) // Extreme
    ])
    func testVideoBitrateValidation(bitrate: Int, shouldBeValid: Bool) {
        if shouldBeValid {
            #expect(throws: Never.self) {
                let _ = try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    videoBitrate: bitrate,
                    videoFramerate: 30,
                    audioBitrate: 128,
                    audioSampleRate: 44100
                )
            }
        } else {
            #expect(throws: RealtimeError.self) {
                let _ = try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    videoBitrate: bitrate,
                    videoFramerate: 30,
                    audioBitrate: 128,
                    audioSampleRate: 44100
                )
            }
        }
    }
    
    // MARK: - Framerate Validation Testing
    
    @Test("Video framerate validation", arguments: [
        (0, false),   // Zero
        (-1, false),  // Negative
        (1, true),    // Minimum
        (15, true),   // Low
        (30, true),   // Standard
        (60, true),   // High
        (120, true),  // Very high
        (1000, false) // Too high
    ])
    func testVideoFramerateValidation(framerate: Int, shouldBeValid: Bool) {
        if shouldBeValid {
            #expect(throws: Never.self) {
                let _ = try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    videoBitrate: 2000,
                    videoFramerate: framerate,
                    audioBitrate: 128,
                    audioSampleRate: 44100
                )
            }
        } else {
            #expect(throws: RealtimeError.self) {
                let _ = try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    videoBitrate: 2000,
                    videoFramerate: framerate,
                    audioBitrate: 128,
                    audioSampleRate: 44100
                )
            }
        }
    }
    
    // MARK: - Channel Name Validation Testing
    
    @Test("Channel name validation", arguments: [
        ("", false),                                    // Empty
        ("a", true),                                   // Single character
        ("valid_channel", true),                       // Normal
        ("channel-123", true),                         // With numbers and dash
        ("channel_with_underscores", true),            // With underscores
        ("UPPERCASE_CHANNEL", true),                   // Uppercase
        ("channel with spaces", false),                // With spaces
        ("channel@special", false),                    // With special chars
        (String(repeating: "a", count: 64), true),     // Maximum length
        (String(repeating: "a", count: 65), false)     // Too long
    ])
    func testChannelNameValidation(channelName: String, shouldBeValid: Bool) {
        let channelInfo = RelayChannelInfo(
            channelName: channelName,
            token: "valid_token",
            userId: "valid_user"
        )
        
        #expect(channelInfo.isValid == shouldBeValid)
    }
    
    // MARK: - Error Code Testing
    
    @Test("Error code mapping", arguments: [
        (RealtimeError.networkError("test"), "NETWORK_ERROR"),
        (RealtimeError.authenticationFailed("test"), "AUTH_FAILED"),
        (RealtimeError.invalidConfiguration("test"), "INVALID_CONFIG"),
        (RealtimeError.providerError("test", underlying: nil), "PROVIDER_ERROR"),
        (RealtimeError.noActiveSession, "NO_SESSION"),
        (RealtimeError.alreadyInState(.connected), "ALREADY_IN_STATE")
    ])
    func testErrorCodeMapping(error: RealtimeError, expectedCode: String) {
        #expect(error.errorCode == expectedCode)
    }
    
    // MARK: - Concurrent Operations Testing
    
    @Test("Concurrent volume updates", arguments: [1, 5, 10, 50, 100])
    func testConcurrentVolumeUpdates(threadCount: Int) async {
        let manager = VolumeIndicatorManager()
        let config = VolumeDetectionConfig.default
        
        await MainActor.run {
            manager.enable(with: config)
        }
        
        var completedUpdates = 0
        let lock = NSLock()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<threadCount {
                group.addTask {
                    let volumeInfos = [
                        UserVolumeInfo(
                            userId: "user_\(i)",
                            volume: Float(i) / Float(threadCount),
                            isSpeaking: i % 2 == 0
                        )
                    ]
                    
                    await MainActor.run {
                        manager.processVolumeUpdate(volumeInfos)
                    }
                    
                    lock.lock()
                    completedUpdates += 1
                    lock.unlock()
                }
            }
        }
        
        #expect(completedUpdates == threadCount)
        
        await MainActor.run {
            manager.disable()
        }
    }
    
    // MARK: - Memory Stress Testing
    
    @Test("Memory allocation stress test", arguments: [10, 100, 1000])
    func testMemoryAllocationStress(objectCount: Int) async {
        var objects: [UserVolumeInfo] = []
        
        // Allocate many objects
        for i in 0..<objectCount {
            let volumeInfo = UserVolumeInfo(
                userId: "user_\(i)",
                volume: Float.random(in: 0...1),
                isSpeaking: Bool.random()
            )
            objects.append(volumeInfo)
        }
        
        #expect(objects.count == objectCount)
        
        // Process objects
        let speakingCount = objects.filter { $0.isSpeaking }.count
        let totalVolume = objects.reduce(0.0) { $0 + $1.volume }
        
        #expect(speakingCount >= 0)
        #expect(totalVolume >= 0.0)
        
        // Clean up
        objects.removeAll()
        
        #expect(objects.isEmpty)
    }
    
    // MARK: - Boundary Value Testing
    
    @Test("Boundary value testing for smooth factor", arguments: [
        (0.0, 0.0),
        (0.1, 0.1),
        (0.5, 0.5),
        (0.9, 0.9),
        (1.0, 1.0),
        (-0.1, 0.0),  // Below minimum, should clamp
        (1.1, 1.0)    // Above maximum, should clamp
    ])
    func testSmoothFactorBoundaryValues(input: Float, expected: Float) {
        let config = VolumeDetectionConfig(smoothFactor: input)
        #expect(config.smoothFactor == expected)
    }
    
    // MARK: - Configuration Combination Testing
    
    @Test("Audio settings combinations", arguments: [
        (true, 0, 0, 0, false),      // All minimum
        (false, 100, 100, 100, true), // All maximum
        (true, 50, 60, 70, false),   // Mixed values
        (false, 25, 75, 50, true)    // Different mixed values
    ])
    func testAudioSettingsCombinations(
        muted: Bool,
        mixing: Int,
        playback: Int,
        recording: Int,
        streamActive: Bool
    ) {
        let settings = AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: mixing,
            playbackSignalVolume: playback,
            recordingSignalVolume: recording,
            localAudioStreamActive: streamActive
        )
        
        #expect(settings.microphoneMuted == muted)
        #expect(settings.audioMixingVolume >= 0 && settings.audioMixingVolume <= 100)
        #expect(settings.playbackSignalVolume >= 0 && settings.playbackSignalVolume <= 100)
        #expect(settings.recordingSignalVolume >= 0 && settings.recordingSignalVolume <= 100)
        #expect(settings.localAudioStreamActive == streamActive)
    }
    
    // MARK: - Performance Boundary Testing
    
    @Test("Large data structure handling", arguments: [100, 1000, 10000])
    func testLargeDataStructureHandling(size: Int) async {
        // Test handling of large arrays of volume info
        var volumeInfos: [UserVolumeInfo] = []
        
        for i in 0..<size {
            volumeInfos.append(UserVolumeInfo(
                userId: "user_\(i)",
                volume: Float.random(in: 0...1),
                isSpeaking: i % 10 == 0 // Every 10th user is speaking
            ))
        }
        
        let startTime = Date()
        
        // Process the large array
        let speakingUsers = volumeInfos.filter { $0.isSpeaking }
        let averageVolume = volumeInfos.reduce(0.0) { $0 + $1.volume } / Float(volumeInfos.count)
        let dominantSpeaker = speakingUsers.max { $0.volume < $1.volume }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        #expect(speakingUsers.count >= 0)
        #expect(averageVolume >= 0.0 && averageVolume <= 1.0)
        #expect(processingTime < 1.0) // Should complete within 1 second
        
        volumeInfos.removeAll()
    }
}