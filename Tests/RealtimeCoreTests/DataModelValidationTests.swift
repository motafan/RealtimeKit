// DataModelValidationTests.swift
// Comprehensive validation tests for all data models

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Data Model Validation Tests")
struct DataModelValidationTests {
    
    // MARK: - UserSession Tests
    
    @Test("UserSession valid initialization")
    func testUserSessionValidInitialization() {
        let session = UserSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster,
            roomId: "room456"
        )
        
        #expect(session.userId == "user123")
        #expect(session.userName == "Test User")
        #expect(session.userRole == .broadcaster)
        #expect(session.roomId == "room456")
        #expect(session.joinTime <= Date())
        #expect(session.lastActiveTime <= Date())
    }
    
    @Test("UserSession validation rules")
    func testUserSessionValidationRules() {
        // Valid session
        let validSession = UserSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        #expect(validSession.isValid == true)
        
        // Invalid - empty user ID
        let invalidSession1 = UserSession(
            userId: "",
            userName: "Test User",
            userRole: .broadcaster
        )
        #expect(invalidSession1.isValid == false)
        
        // Invalid - empty user name
        let invalidSession2 = UserSession(
            userId: "user123",
            userName: "",
            userRole: .broadcaster
        )
        #expect(invalidSession2.isValid == false)
        
        // Invalid - user ID too long
        let longUserId = String(repeating: "a", count: 256)
        let invalidSession3 = UserSession(
            userId: longUserId,
            userName: "Test User",
            userRole: .broadcaster
        )
        #expect(invalidSession3.isValid == false)
    }
    
    @Test("UserSession role transitions")
    func testUserSessionRoleTransitions() {
        // Broadcaster can switch to moderator
        #expect(UserRole.broadcaster.canSwitchToRole.contains(.moderator))
        
        // Audience can switch to co-host
        #expect(UserRole.audience.canSwitchToRole.contains(.coHost))
        
        // Co-host can switch to audience or broadcaster
        #expect(UserRole.coHost.canSwitchToRole.contains(.audience))
        #expect(UserRole.coHost.canSwitchToRole.contains(.broadcaster))
        
        // Moderator can switch to broadcaster
        #expect(UserRole.moderator.canSwitchToRole.contains(.broadcaster))
        
        // Invalid transitions
        #expect(!UserRole.audience.canSwitchToRole.contains(.broadcaster))
        #expect(!UserRole.audience.canSwitchToRole.contains(.moderator))
    }
    
    @Test("UserSession permissions")
    func testUserSessionPermissions() {
        // Audio permissions
        #expect(UserRole.broadcaster.hasAudioPermission == true)
        #expect(UserRole.coHost.hasAudioPermission == true)
        #expect(UserRole.moderator.hasAudioPermission == true)
        #expect(UserRole.audience.hasAudioPermission == false)
        
        // Video permissions
        #expect(UserRole.broadcaster.hasVideoPermission == true)
        #expect(UserRole.coHost.hasVideoPermission == true)
        #expect(UserRole.moderator.hasVideoPermission == false)
        #expect(UserRole.audience.hasVideoPermission == false)
    }
    
    // MARK: - AudioSettings Tests
    
    @Test("AudioSettings valid initialization")
    func testAudioSettingsValidInitialization() {
        let settings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        #expect(settings.microphoneMuted == true)
        #expect(settings.audioMixingVolume == 75)
        #expect(settings.playbackSignalVolume == 80)
        #expect(settings.recordingSignalVolume == 90)
        #expect(settings.localAudioStreamActive == false)
    }
    
    @Test("AudioSettings volume clamping")
    func testAudioSettingsVolumeClamping() {
        // Test volume above maximum
        let settings1 = AudioSettings(
            audioMixingVolume: 150,
            playbackSignalVolume: 200,
            recordingSignalVolume: 300
        )
        
        #expect(settings1.audioMixingVolume == 100)
        #expect(settings1.playbackSignalVolume == 100)
        #expect(settings1.recordingSignalVolume == 100)
        
        // Test volume below minimum
        let settings2 = AudioSettings(
            audioMixingVolume: -10,
            playbackSignalVolume: -20,
            recordingSignalVolume: -30
        )
        
        #expect(settings2.audioMixingVolume == 0)
        #expect(settings2.playbackSignalVolume == 0)
        #expect(settings2.recordingSignalVolume == 0)
    }
    
    @Test("AudioSettings update methods")
    func testAudioSettingsUpdateMethods() {
        let originalSettings = AudioSettings.default
        
        let updatedSettings = originalSettings.withUpdatedVolume(
            audioMixing: 50,
            playbackSignal: 60,
            recordingSignal: 70
        )
        
        #expect(updatedSettings.audioMixingVolume == 50)
        #expect(updatedSettings.playbackSignalVolume == 60)
        #expect(updatedSettings.recordingSignalVolume == 70)
        
        // Original should remain unchanged
        #expect(originalSettings.audioMixingVolume == 100)
        #expect(originalSettings.playbackSignalVolume == 100)
        #expect(originalSettings.recordingSignalVolume == 100)
    }
    
    @Test("AudioSettings equality")
    func testAudioSettingsEquality() {
        let settings1 = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        let settings2 = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        let settings3 = AudioSettings(
            microphoneMuted: false,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        #expect(settings1 == settings2)
        #expect(settings1 != settings3)
    }
    
    // MARK: - VolumeDetectionConfig Tests
    
    @Test("VolumeDetectionConfig valid initialization")
    func testVolumeDetectionConfigValidInitialization() {
        let config = VolumeDetectionConfig(
            detectionInterval: 500,
            speakingThreshold: 0.4,
            silenceThreshold: 0.1,
            includeLocalUser: false,
            smoothFactor: 0.5
        )
        
        #expect(config.detectionInterval == 500)
        #expect(config.speakingThreshold == 0.4)
        #expect(config.silenceThreshold == 0.1)
        #expect(config.includeLocalUser == false)
        #expect(config.smoothFactor == 0.5)
    }
    
    @Test("VolumeDetectionConfig parameter clamping")
    func testVolumeDetectionConfigParameterClamping() {
        // Test interval clamping
        let config1 = VolumeDetectionConfig(detectionInterval: 50) // Below minimum
        #expect(config1.detectionInterval == 100)
        
        let config2 = VolumeDetectionConfig(detectionInterval: 10000) // Above maximum
        #expect(config2.detectionInterval == 5000)
        
        // Test threshold clamping
        let config3 = VolumeDetectionConfig(
            speakingThreshold: -0.1, // Below minimum
            silenceThreshold: 1.5 // Above maximum
        )
        #expect(config3.speakingThreshold == 0.0)
        #expect(config3.silenceThreshold == 1.0)
        
        // Test smooth factor clamping
        let config4 = VolumeDetectionConfig(smoothFactor: -0.5) // Below minimum
        #expect(config4.smoothFactor == 0.0)
        
        let config5 = VolumeDetectionConfig(smoothFactor: 1.5) // Above maximum
        #expect(config5.smoothFactor == 1.0)
    }
    
    @Test("VolumeDetectionConfig validation")
    func testVolumeDetectionConfigValidation() {
        // Valid config
        let validConfig = VolumeDetectionConfig(
            speakingThreshold: 0.3,
            silenceThreshold: 0.1
        )
        #expect(validConfig.isValid == true)
        
        // Invalid - speaking threshold lower than silence threshold
        let invalidConfig = VolumeDetectionConfig(
            speakingThreshold: 0.1,
            silenceThreshold: 0.3
        )
        #expect(invalidConfig.isValid == false)
    }
    
    // MARK: - UserVolumeInfo Tests
    
    @Test("UserVolumeInfo valid initialization")
    func testUserVolumeInfoValidInitialization() {
        let timestamp = Date()
        let volumeInfo = UserVolumeInfo(
            userId: "user123",
            volume: 0.7,
            isSpeaking: true,
            timestamp: timestamp
        )
        
        #expect(volumeInfo.userId == "user123")
        #expect(volumeInfo.volume == 0.7)
        #expect(volumeInfo.isSpeaking == true)
        #expect(volumeInfo.timestamp == timestamp)
    }
    
    @Test("UserVolumeInfo volume clamping")
    func testUserVolumeInfoVolumeClamping() {
        // Test volume above maximum
        let volumeInfo1 = UserVolumeInfo(
            userId: "user1",
            volume: 1.5,
            isSpeaking: true
        )
        #expect(volumeInfo1.volume == 1.0)
        
        // Test volume below minimum
        let volumeInfo2 = UserVolumeInfo(
            userId: "user2",
            volume: -0.5,
            isSpeaking: false
        )
        #expect(volumeInfo2.volume == 0.0)
    }
    
    @Test("UserVolumeInfo comparison")
    func testUserVolumeInfoComparison() {
        let volumeInfo1 = UserVolumeInfo(userId: "user1", volume: 0.5, isSpeaking: true)
        let volumeInfo2 = UserVolumeInfo(userId: "user2", volume: 0.7, isSpeaking: true)
        let volumeInfo3 = UserVolumeInfo(userId: "user3", volume: 0.3, isSpeaking: false)
        
        // Should be able to sort by volume
        let sorted = [volumeInfo1, volumeInfo2, volumeInfo3].sorted { $0.volume > $1.volume }
        
        #expect(sorted[0].userId == "user2") // Highest volume
        #expect(sorted[1].userId == "user1")
        #expect(sorted[2].userId == "user3") // Lowest volume
    }
    
    // MARK: - StreamPushConfig Tests
    
    @Test("StreamPushConfig valid initialization")
    func testStreamPushConfigValidInitialization() throws {
        let config = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://example.com/live/stream"
        )
        
        #expect(config.pushUrl == "rtmp://example.com/live/stream")
        #expect(config.width == 1280)
        #expect(config.height == 720)
        #expect(config.videoBitrate == 2000)
        #expect(config.videoFramerate == 30)
        #expect(config.audioBitrate == 128)
        #expect(config.audioSampleRate == 44100)
    }
    
    @Test("StreamPushConfig URL validation")
    func testStreamPushConfigURLValidation() {
        // Valid RTMP URL
        #expect(throws: Never.self) {
            let _ = try StreamPushConfig.standard720p(pushUrl: "rtmp://example.com/live/stream")
        }
        
        // Valid RTMPS URL
        #expect(throws: Never.self) {
            let _ = try StreamPushConfig.standard720p(pushUrl: "rtmps://example.com/live/stream")
        }
        
        // Invalid URL scheme
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig.standard720p(pushUrl: "http://example.com/stream")
        }
        
        // Empty URL
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig.standard720p(pushUrl: "")
        }
        
        // Invalid URL format
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig.standard720p(pushUrl: "not-a-url")
        }
    }
    
    @Test("StreamPushConfig parameter validation")
    func testStreamPushConfigParameterValidation() {
        // Invalid resolution
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig(
                pushUrl: "rtmp://example.com/live/stream",
                width: 0, // Invalid
                height: 720,
                videoBitrate: 2000,
                videoFramerate: 30,
                audioBitrate: 128,
                audioSampleRate: 44100
            )
        }
        
        // Invalid bitrate
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig(
                pushUrl: "rtmp://example.com/live/stream",
                width: 1280,
                height: 720,
                videoBitrate: -100, // Invalid
                videoFramerate: 30,
                audioBitrate: 128,
                audioSampleRate: 44100
            )
        }
        
        // Invalid framerate
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig(
                pushUrl: "rtmp://example.com/live/stream",
                width: 1280,
                height: 720,
                videoBitrate: 2000,
                videoFramerate: 0, // Invalid
                audioBitrate: 128,
                audioSampleRate: 44100
            )
        }
    }
    
    @Test("StreamPushConfig preset configurations")
    func testStreamPushConfigPresetConfigurations() throws {
        // Test 480p preset
        let config480p = try StreamPushConfig.standard480p(
            pushUrl: "rtmp://example.com/live/stream"
        )
        #expect(config480p.width == 854)
        #expect(config480p.height == 480)
        #expect(config480p.videoBitrate == 1000)
        
        // Test 720p preset
        let config720p = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://example.com/live/stream"
        )
        #expect(config720p.width == 1280)
        #expect(config720p.height == 720)
        #expect(config720p.videoBitrate == 2000)
        
        // Test 1080p preset
        let config1080p = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://example.com/live/stream"
        )
        #expect(config1080p.width == 1920)
        #expect(config1080p.height == 1080)
        #expect(config1080p.videoBitrate == 4000)
    }
    
    // MARK: - MediaRelayConfig Tests
    
    @Test("MediaRelayConfig valid initialization")
    func testMediaRelayConfigValidInitialization() throws {
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
        
        #expect(config.sourceChannel.channelName == "source_channel")
        #expect(config.destinationChannels.count == 1)
        #expect(config.destinationChannels.first?.channelName == "target_channel")
    }
    
    @Test("MediaRelayConfig validation")
    func testMediaRelayConfigValidation() {
        let sourceChannel = RelayChannelInfo(
            channelName: "source_channel",
            token: "source_token",
            userId: "source_user"
        )
        
        // Empty destination channels
        #expect(throws: RealtimeError.self) {
            let _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: []
            )
        }
        
        // Too many destination channels
        let manyChannels = (1...20).map { i in
            RelayChannelInfo(
                channelName: "channel_\(i)",
                token: "token_\(i)",
                userId: "user_\(i)"
            )
        }
        
        #expect(throws: RealtimeError.self) {
            let _ = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: manyChannels
            )
        }
    }
    
    @Test("RelayChannelInfo validation")
    func testRelayChannelInfoValidation() {
        // Valid channel info
        let validChannel = RelayChannelInfo(
            channelName: "test_channel",
            token: "test_token",
            userId: "test_user"
        )
        #expect(validChannel.isValid == true)
        
        // Invalid - empty channel name
        let invalidChannel1 = RelayChannelInfo(
            channelName: "",
            token: "test_token",
            userId: "test_user"
        )
        #expect(invalidChannel1.isValid == false)
        
        // Invalid - empty token
        let invalidChannel2 = RelayChannelInfo(
            channelName: "test_channel",
            token: "",
            userId: "test_user"
        )
        #expect(invalidChannel2.isValid == false)
        
        // Invalid - empty user ID
        let invalidChannel3 = RelayChannelInfo(
            channelName: "test_channel",
            token: "test_token",
            userId: ""
        )
        #expect(invalidChannel3.isValid == false)
    }
    
    // MARK: - RealtimeMessage Tests
    
    @Test("RealtimeMessage text message")
    func testRealtimeMessageTextMessage() {
        let message = RealtimeMessage.text("Hello world", from: "user123")
        
        #expect(message.type == .text)
        #expect(message.senderId == "user123")
        #expect(message.timestamp <= Date())
        
        if case .text(let content) = message.content {
            #expect(content == "Hello world")
        } else {
            #expect(Bool(false), "Message content should be text")
        }
    }
    
    @Test("RealtimeMessage system message")
    func testRealtimeMessageSystemMessage() {
        let systemData = ["action": "user_joined", "userId": "user123"]
        let message = RealtimeMessage.system(systemData)
        
        #expect(message.type == .system)
        #expect(message.senderId == "system")
        
        if case .system(let data) = message.content {
            #expect(data["action"] as? String == "user_joined")
            #expect(data["userId"] as? String == "user123")
        } else {
            #expect(Bool(false), "Message content should be system data")
        }
    }
    
    @Test("RealtimeMessage custom message")
    func testRealtimeMessageCustomMessage() {
        let customData = ["type": "reaction", "emoji": "👍"]
        let message = RealtimeMessage.custom("reaction", data: customData, from: "user456")
        
        #expect(message.type == .custom("reaction"))
        #expect(message.senderId == "user456")
        
        if case .custom(let data) = message.content {
            #expect(data["type"] as? String == "reaction")
            #expect(data["emoji"] as? String == "👍")
        } else {
            #expect(Bool(false), "Message content should be custom data")
        }
    }
    
    @Test("RealtimeMessage metadata")
    func testRealtimeMessageMetadata() {
        let message = RealtimeMessage.text("Test", from: "user123")
        let messageWithMetadata = message.withMetadata(["priority": "high", "encrypted": true])
        
        #expect(messageWithMetadata.metadata["priority"] as? String == "high")
        #expect(messageWithMetadata.metadata["encrypted"] as? Bool == true)
        
        // Original message should be unchanged
        #expect(message.metadata.isEmpty)
    }
    
    // MARK: - Error Model Tests
    
    @Test("RealtimeError types")
    func testRealtimeErrorTypes() {
        let networkError = RealtimeError.networkError("Connection failed")
        let authError = RealtimeError.authenticationFailed("Invalid token")
        let configError = RealtimeError.invalidConfiguration("Missing app ID")
        
        #expect(networkError.localizedDescription.contains("Connection failed"))
        #expect(authError.localizedDescription.contains("Invalid token"))
        #expect(configError.localizedDescription.contains("Missing app ID"))
    }
    
    @Test("RealtimeError equality")
    func testRealtimeErrorEquality() {
        let error1 = RealtimeError.networkError("Connection failed")
        let error2 = RealtimeError.networkError("Connection failed")
        let error3 = RealtimeError.networkError("Different message")
        let error4 = RealtimeError.authenticationFailed("Connection failed")
        
        #expect(error1 == error2)
        #expect(error1 != error3)
        #expect(error1 != error4)
    }
    
    // MARK: - Configuration Model Tests
    
    @Test("RealtimeConfig validation")
    func testRealtimeConfigValidation() {
        // Valid config
        let validConfig = RealtimeConfig(
            appId: "test_app_id",
            appKey: "test_app_key",
            logLevel: .debug
        )
        #expect(validConfig.isValid == true)
        
        // Invalid - empty app ID
        let invalidConfig1 = RealtimeConfig(
            appId: "",
            appKey: "test_app_key",
            logLevel: .debug
        )
        #expect(invalidConfig1.isValid == false)
        
        // Invalid - empty app key
        let invalidConfig2 = RealtimeConfig(
            appId: "test_app_id",
            appKey: "",
            logLevel: .debug
        )
        #expect(invalidConfig2.isValid == false)
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    @Test("Handle extreme values")
    func testHandleExtremeValues() {
        // Test with maximum integer values
        let extremeConfig = VolumeDetectionConfig(
            detectionInterval: Int.max,
            speakingThreshold: Float.greatestFiniteMagnitude,
            silenceThreshold: Float.leastNormalMagnitude,
            smoothFactor: Float.greatestFiniteMagnitude
        )
        
        // Should clamp to valid ranges
        #expect(extremeConfig.detectionInterval <= 5000)
        #expect(extremeConfig.speakingThreshold <= 1.0)
        #expect(extremeConfig.silenceThreshold >= 0.0)
        #expect(extremeConfig.smoothFactor <= 1.0)
    }
    
    @Test("Handle special float values")
    func testHandleSpecialFloatValues() {
        // Test with NaN and infinity
        let volumeInfoNaN = UserVolumeInfo(
            userId: "test",
            volume: Float.nan,
            isSpeaking: false
        )
        
        let volumeInfoInfinity = UserVolumeInfo(
            userId: "test",
            volume: Float.infinity,
            isSpeaking: false
        )
        
        // Should handle gracefully (clamp to valid range)
        #expect(volumeInfoNaN.volume.isFinite || volumeInfoNaN.volume == 0.0)
        #expect(volumeInfoInfinity.volume <= 1.0)
    }
    
    @Test("Unicode and special characters")
    func testUnicodeAndSpecialCharacters() {
        // Test with Unicode characters
        let unicodeSession = UserSession(
            userId: "用户123",
            userName: "测试用户 🎤",
            userRole: .broadcaster
        )
        
        #expect(unicodeSession.userId == "用户123")
        #expect(unicodeSession.userName == "测试用户 🎤")
        
        // Test with special characters in URLs
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig.standard720p(
                pushUrl: "rtmp://example.com/live/stream with spaces"
            )
        }
    }
}