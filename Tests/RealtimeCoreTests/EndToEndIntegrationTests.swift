// EndToEndIntegrationTests.swift
// Comprehensive end-to-end integration tests covering complete user scenarios

import Testing
import Foundation
@testable import RealtimeCore

@Suite("End-to-End Integration Tests")
@MainActor
struct EndToEndIntegrationTests {
    
    // MARK: - Test Setup
    
    private func createRealtimeManager() -> RealtimeManager {
        let manager = RealtimeManager.shared
        manager.registerMockProvider()
        return manager
    }
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "e2e_test_app_id",
            appKey: "e2e_test_app_key",
            logLevel: .info
        )
    }
    
    // MARK: - Complete User Journey Tests
    
    @Test("Complete broadcaster journey")
    func testCompleteBroadcasterJourney() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        // Track the complete journey
        var journeyEvents: [String] = []
        
        // 1. Initialize and configure
        journeyEvents.append("Initializing")
        try await manager.configure(provider: .mock, config: config)
        journeyEvents.append("Configured")
        
        // 2. User login as broadcaster
        journeyEvents.append("Logging in")
        try await manager.loginUser(
            userId: "broadcaster_001",
            userName: "Main Broadcaster",
            userRole: .broadcaster
        )
        journeyEvents.append("Logged in")
        
        #expect(manager.currentSession?.userRole == .broadcaster)
        #expect(manager.currentSession?.userId == "broadcaster_001")
        
        // 3. Join room
        journeyEvents.append("Joining room")
        try await manager.joinRoom(
            roomId: "live_room_001",
            userId: "broadcaster_001",
            userName: "Main Broadcaster",
            userRole: .broadcaster
        )
        journeyEvents.append("Joined room")
        
        #expect(manager.connectionState == .connected)
        #expect(manager.currentSession?.roomId == "live_room_001")
        
        // 4. Configure audio settings
        journeyEvents.append("Configuring audio")
        try await manager.setAudioMixingVolume(80)
        try await manager.setPlaybackSignalVolume(90)
        try await manager.setRecordingSignalVolume(85)
        try await manager.muteMicrophone(false)
        journeyEvents.append("Audio configured")
        
        #expect(manager.audioSettings.audioMixingVolume == 80)
        #expect(manager.audioSettings.microphoneMuted == false)
        
        // 5. Enable volume indicator
        journeyEvents.append("Enabling volume indicator")
        try await manager.enableVolumeIndicator()
        journeyEvents.append("Volume indicator enabled")
        
        #expect(manager.volumeIndicatorEnabled == true)
        
        // 6. Start stream push
        journeyEvents.append("Starting stream push")
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://live.example.com/stream/broadcaster_001"
        )
        try await manager.startStreamPush(config: streamConfig)
        journeyEvents.append("Stream push started")
        
        #expect(manager.streamPushState == .running)
        
        // 7. Simulate live interaction
        journeyEvents.append("Simulating live interaction")
        
        // Send messages
        for i in 1...10 {
            let message = RealtimeMessage.text("Live message \(i)", from: "broadcaster_001")
            try await manager.sendMessage(message)
        }
        
        // Process volume updates
        for _ in 1...20 {
            let volumeInfos = [
                UserVolumeInfo(userId: "broadcaster_001", volume: Float.random(in: 0.3...1.0), isSpeaking: true),
                UserVolumeInfo(userId: "viewer_001", volume: Float.random(in: 0...0.2), isSpeaking: false)
            ]
            manager.processVolumeUpdate(volumeInfos)
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        journeyEvents.append("Live interaction completed")
        
        // 8. Update stream layout
        journeyEvents.append("Updating stream layout")
        let layout = StreamLayout(
            backgroundColor: "#000000",
            userRegions: [
                UserRegion(
                    userId: "broadcaster_001",
                    x: 0, y: 0,
                    width: 1920, height: 1080,
                    zOrder: 1,
                    alpha: 1.0
                )
            ]
        )
        try await manager.updateStreamLayout(layout: layout)
        journeyEvents.append("Stream layout updated")
        
        // 9. Handle co-host joining (role switch scenario)
        journeyEvents.append("Handling co-host scenario")
        
        // Simulate another user joining as co-host
        let coHostMessage = RealtimeMessage.system("Co-host joined", metadata: ["userId": "cohost_001"])
        try await manager.sendMessage(coHostMessage)
        
        // Update layout for co-host
        let multiUserLayout = StreamLayout(
            backgroundColor: "#000000",
            userRegions: [
                UserRegion(userId: "broadcaster_001", x: 0, y: 0, width: 960, height: 1080, zOrder: 1, alpha: 1.0),
                UserRegion(userId: "cohost_001", x: 960, y: 0, width: 960, height: 1080, zOrder: 1, alpha: 1.0)
            ]
        )
        try await manager.updateStreamLayout(layout: multiUserLayout)
        journeyEvents.append("Co-host scenario handled")
        
        // 10. Stop stream push
        journeyEvents.append("Stopping stream push")
        try await manager.stopStreamPush()
        journeyEvents.append("Stream push stopped")
        
        #expect(manager.streamPushState == .stopped)
        
        // 11. Disable volume indicator
        journeyEvents.append("Disabling volume indicator")
        try await manager.disableVolumeIndicator()
        journeyEvents.append("Volume indicator disabled")
        
        #expect(manager.volumeIndicatorEnabled == false)
        
        // 12. Leave room
        journeyEvents.append("Leaving room")
        try await manager.leaveRoom()
        journeyEvents.append("Left room")
        
        #expect(manager.connectionState == .disconnected)
        
        // 13. Logout
        journeyEvents.append("Logging out")
        try await manager.logoutUser()
        journeyEvents.append("Logged out")
        
        #expect(manager.currentSession == nil)
        
        // Verify complete journey
        print("Broadcaster journey events: \(journeyEvents)")
        #expect(journeyEvents.count >= 20)
        #expect(journeyEvents.first == "Initializing")
        #expect(journeyEvents.last == "Logged out")
    }
    
    @Test("Complete audience to co-host journey")
    func testCompleteAudienceToCoHostJourney() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var roleTransitions: [(from: UserRole, to: UserRole)] = []
        manager.onRoleChanged = { from, to in
            roleTransitions.append((from: from, to: to))
        }
        
        // 1. Start as audience
        try await manager.configure(provider: .mock, config: config)
        try await manager.loginUser(
            userId: "user_002",
            userName: "Audience Member",
            userRole: .audience
        )
        
        #expect(manager.currentSession?.userRole == .audience)
        
        try await manager.joinRoom(
            roomId: "interactive_room",
            userId: "user_002",
            userName: "Audience Member",
            userRole: .audience
        )
        
        // 2. As audience - limited capabilities
        #expect(manager.currentSession?.userRole.hasAudioPermission == false)
        
        // Should not be able to unmute microphone as audience
        try await manager.muteMicrophone(false)
        #expect(manager.audioSettings.microphoneMuted == true) // Should remain muted
        
        // 3. Receive invitation to become co-host
        let invitationMessage = RealtimeMessage.system(
            "Co-host invitation",
            metadata: ["targetUserId": "user_002", "newRole": "co_host"]
        )
        try await manager.sendMessage(invitationMessage)
        
        // 4. Accept and switch to co-host role
        try await manager.switchUserRole(.coHost)
        
        #expect(manager.currentSession?.userRole == .coHost)
        #expect(roleTransitions.count > 0)
        #expect(roleTransitions.last?.from == .audience)
        #expect(roleTransitions.last?.to == .coHost)
        
        // 5. As co-host - gain audio/video permissions
        #expect(manager.currentSession?.userRole.hasAudioPermission == true)
        #expect(manager.currentSession?.userRole.hasVideoPermission == true)
        
        // Now can unmute microphone
        try await manager.muteMicrophone(false)
        #expect(manager.audioSettings.microphoneMuted == false)
        
        // 6. Configure audio as co-host
        try await manager.setAudioMixingVolume(70)
        try await manager.setRecordingSignalVolume(80)
        
        // 7. Enable volume indicator to participate
        try await manager.enableVolumeIndicator()
        
        // 8. Participate in conversation
        for i in 1...5 {
            let message = RealtimeMessage.text("Co-host message \(i)", from: "user_002")
            try await manager.sendMessage(message)
        }
        
        // Simulate speaking
        let speakingVolumeInfos = [
            UserVolumeInfo(userId: "user_002", volume: 0.8, isSpeaking: true),
            UserVolumeInfo(userId: "broadcaster_001", volume: 0.2, isSpeaking: false)
        ]
        manager.processVolumeUpdate(speakingVolumeInfos)
        
        #expect(manager.speakingUsers.contains("user_002"))
        
        // 9. End co-host session - return to audience
        try await manager.switchUserRole(.audience)
        
        #expect(manager.currentSession?.userRole == .audience)
        #expect(roleTransitions.count >= 2)
        
        // Should automatically mute when returning to audience
        #expect(manager.audioSettings.microphoneMuted == true)
        
        // 10. Leave as audience
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
        try await manager.logoutUser()
        
        print("Role transitions: \(roleTransitions)")
    }
    
    @Test("Multi-room media relay scenario")
    func testMultiRoomMediaRelayScenario() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.loginUser(
            userId: "relay_host",
            userName: "Relay Host",
            userRole: .broadcaster
        )
        
        // 1. Join main room
        try await manager.joinRoom(
            roomId: "main_conference_room",
            userId: "relay_host",
            userName: "Relay Host",
            userRole: .broadcaster
        )
        
        // 2. Set up media relay to multiple destination rooms
        let sourceChannel = try RelayChannelInfo(
            channelName: "main_conference_room",
            userId: "relay_host"
        )
        
        let destinationChannels = try [
            RelayChannelInfo(channelName: "breakout_room_1", userId: "relay_host"),
            RelayChannelInfo(channelName: "breakout_room_2", userId: "relay_host"),
            RelayChannelInfo(channelName: "overflow_room", userId: "relay_host")
        ]
        
        let relayConfig = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels,
            relayMode: .oneToMany,
            enableAudio: true,
            enableVideo: true
        )
        
        // 3. Start media relay
        try await manager.startMediaRelay(config: relayConfig)
        
        #expect(manager.isMediaRelayActive == true)
        #expect(manager.getDestinationChannels().count == 3)
        
        // 4. Simulate live presentation with relay
        try await manager.enableVolumeIndicator()
        
        // Send presentation messages
        for i in 1...10 {
            let message = RealtimeMessage.text("Presentation slide \(i)", from: "relay_host")
            try await manager.sendMessage(message)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // 5. Dynamically manage relay channels
        // Add emergency overflow room
        let emergencyChannel = try RelayChannelInfo(
            channelName: "emergency_overflow",
            userId: "relay_host"
        )
        try await manager.addMediaRelayChannel(emergencyChannel)
        
        #expect(manager.getDestinationChannels().count == 4)
        
        // Pause relay to one room (technical issues)
        try await manager.pauseMediaRelay(toChannel: "breakout_room_2")
        
        // Resume after fixing issues
        try await manager.resumeMediaRelay(toChannel: "breakout_room_2")
        
        // Remove overflow room (no longer needed)
        try await manager.removeMediaRelayChannel("overflow_room")
        
        #expect(manager.getDestinationChannels().count == 3)
        
        // 6. Monitor relay statistics
        let stats = manager.getMediaRelayStatistics()
        #expect(stats.totalRelayTime > 0)
        #expect(stats.destinationStats.count >= 3)
        
        // 7. End relay session
        try await manager.stopMediaRelay()
        
        #expect(manager.isMediaRelayActive == false)
        
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
    
    @Test("Complex streaming with multiple features")
    func testComplexStreamingWithMultipleFeatures() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.loginUser(
            userId: "complex_streamer",
            userName: "Complex Streamer",
            userRole: .broadcaster
        )
        
        try await manager.joinRoom(
            roomId: "complex_stream_room",
            userId: "complex_streamer",
            userName: "Complex Streamer",
            userRole: .broadcaster
        )
        
        // 1. Set up comprehensive audio configuration
        try await manager.setAudioMixingVolume(75)
        try await manager.setPlaybackSignalVolume(85)
        try await manager.setRecordingSignalVolume(90)
        try await manager.muteMicrophone(false)
        
        // 2. Enable all monitoring features
        try await manager.enableVolumeIndicator()
        
        // 3. Start high-quality stream
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://premium.streaming.com/live/complex_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // 4. Set up media relay for simulcast
        let sourceChannel = try RelayChannelInfo(
            channelName: "complex_stream_room",
            userId: "complex_streamer"
        )
        
        let relayDestinations = try [
            RelayChannelInfo(channelName: "youtube_relay", userId: "complex_streamer"),
            RelayChannelInfo(channelName: "twitch_relay", userId: "complex_streamer")
        ]
        
        let relayConfig = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: relayDestinations,
            relayMode: .oneToMany
        )
        
        try await manager.startMediaRelay(config: relayConfig)
        
        // 5. Simulate complex live show
        var eventCount = 0
        
        await withTaskGroup(of: Void.self) { group in
            // Message broadcasting task
            group.addTask {
                for i in 1...50 {
                    let message = RealtimeMessage.text("Live show segment \(i)", from: "complex_streamer")
                    try? await manager.sendMessage(message)
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
                eventCount += 1
            }
            
            // Volume monitoring task
            group.addTask {
                for cycle in 1...100 {
                    let volumeInfos = [
                        UserVolumeInfo(userId: "complex_streamer", volume: Float.random(in: 0.5...1.0), isSpeaking: true),
                        UserVolumeInfo(userId: "guest_001", volume: Float.random(in: 0...0.8), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "guest_002", volume: Float.random(in: 0...0.6), isSpeaking: Bool.random())
                    ]
                    manager.processVolumeUpdate(volumeInfos)
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                eventCount += 1
            }
            
            // Dynamic layout updates task
            group.addTask {
                for layoutIndex in 1...20 {
                    let layout: StreamLayout
                    
                    if layoutIndex % 3 == 0 {
                        // Three-person layout
                        layout = StreamLayout(
                            backgroundColor: "#001122",
                            userRegions: [
                                UserRegion(userId: "complex_streamer", x: 0, y: 0, width: 960, height: 540, zOrder: 1, alpha: 1.0),
                                UserRegion(userId: "guest_001", x: 960, y: 0, width: 960, height: 540, zOrder: 1, alpha: 1.0),
                                UserRegion(userId: "guest_002", x: 480, y: 540, width: 960, height: 540, zOrder: 1, alpha: 1.0)
                            ]
                        )
                    } else if layoutIndex % 2 == 0 {
                        // Two-person layout
                        layout = StreamLayout(
                            backgroundColor: "#000000",
                            userRegions: [
                                UserRegion(userId: "complex_streamer", x: 0, y: 0, width: 960, height: 1080, zOrder: 1, alpha: 1.0),
                                UserRegion(userId: "guest_001", x: 960, y: 0, width: 960, height: 1080, zOrder: 1, alpha: 1.0)
                            ]
                        )
                    } else {
                        // Single-person layout
                        layout = StreamLayout(
                            backgroundColor: "#000000",
                            userRegions: [
                                UserRegion(userId: "complex_streamer", x: 0, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                            ]
                        )
                    }
                    
                    try? await manager.updateStreamLayout(layout: layout)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                eventCount += 1
            }
            
            // Audio adjustments task
            group.addTask {
                for adjustment in 1...10 {
                    let volume = 50 + (adjustment * 5) // 55, 60, 65, ... 100
                    try? await manager.setAudioMixingVolume(volume)
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
                eventCount += 1
            }
        }
        
        // 6. Verify all tasks completed
        #expect(eventCount == 4)
        
        // 7. Check final state
        #expect(manager.streamPushState == .running)
        #expect(manager.isMediaRelayActive == true)
        #expect(manager.volumeIndicatorEnabled == true)
        #expect(manager.connectionState == .connected)
        
        // 8. Graceful shutdown
        try await manager.stopMediaRelay()
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
        try await manager.logoutUser()
        
        #expect(manager.streamPushState == .stopped)
        #expect(manager.isMediaRelayActive == false)
        #expect(manager.currentSession == nil)
    }
    
    @Test("Error recovery during live session")
    func testErrorRecoveryDuringLiveSession() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var recoveryEvents: [String] = []
        manager.onErrorRecovery = { event in
            recoveryEvents.append(event)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.loginUser(
            userId: "recovery_user",
            userName: "Recovery User",
            userRole: .broadcaster
        )
        
        try await manager.joinRoom(
            roomId: "recovery_room",
            userId: "recovery_user",
            userName: "Recovery User",
            userRole: .broadcaster
        )
        
        // Start streaming
        let streamConfig = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://recovery.test.com/live/recovery_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        try await manager.enableVolumeIndicator()
        
        // Simulate various errors during live session
        
        // 1. Network disconnection
        manager.simulateNetworkError("Connection lost")
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Should attempt recovery
        #expect(recoveryEvents.contains("network_recovery_attempted"))
        
        // 2. Audio device error
        manager.simulateAudioDeviceError("Microphone disconnected")
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should handle gracefully
        #expect(manager.audioSettings.microphoneMuted == true) // Auto-muted as fallback
        
        // 3. Stream push error
        manager.simulateStreamPushError("Encoding failed")
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Should attempt to restart stream
        #expect(recoveryEvents.contains("stream_recovery_attempted"))
        
        // 4. Volume indicator error
        manager.simulateVolumeIndicatorError("Volume detection failed")
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should disable volume indicator gracefully
        #expect(manager.volumeIndicatorEnabled == false)
        
        // 5. Verify session continues despite errors
        #expect(manager.connectionState == .connected)
        #expect(manager.currentSession != nil)
        
        // 6. Manual recovery actions
        try await manager.muteMicrophone(false) // Re-enable audio
        try await manager.enableVolumeIndicator() // Re-enable volume detection
        
        // Should work after recovery
        let message = RealtimeMessage.text("Recovery test message", from: "recovery_user")
        try await manager.sendMessage(message)
        
        // Clean shutdown
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
        
        print("Recovery events: \(recoveryEvents)")
        #expect(recoveryEvents.count >= 3)
    }
    
    @Test("Performance under realistic load")
    func testPerformanceUnderRealisticLoad() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.loginUser(
            userId: "load_test_user",
            userName: "Load Test User",
            userRole: .broadcaster
        )
        
        try await manager.joinRoom(
            roomId: "load_test_room",
            userId: "load_test_user",
            userName: "Load Test User",
            userRole: .broadcaster
        )
        
        let startTime = Date()
        let testDuration: TimeInterval = 10.0 // 10 seconds of realistic load
        
        // Start all features
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://load.test.com/live/load_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        var totalOperations = 0
        let operationLock = NSLock()
        
        // Simulate realistic load
        await withTaskGroup(of: Void.self) { group in
            // Continuous message flow (chat simulation)
            group.addTask {
                var messageCount = 0
                while Date().timeIntervalSince(startTime) < testDuration {
                    let message = RealtimeMessage.text("Chat message \(messageCount)", from: "load_test_user")
                    try? await manager.sendMessage(message)
                    messageCount += 1
                    
                    operationLock.lock()
                    totalOperations += 1
                    operationLock.unlock()
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds (10 messages/sec)
                }
            }
            
            // Volume updates (realistic speaking patterns)
            group.addTask {
                while Date().timeIntervalSince(startTime) < testDuration {
                    let volumeInfos = [
                        UserVolumeInfo(userId: "load_test_user", volume: Float.random(in: 0.3...1.0), isSpeaking: true),
                        UserVolumeInfo(userId: "participant_1", volume: Float.random(in: 0...0.5), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "participant_2", volume: Float.random(in: 0...0.4), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "participant_3", volume: Float.random(in: 0...0.3), isSpeaking: Bool.random())
                    ]
                    manager.processVolumeUpdate(volumeInfos)
                    
                    operationLock.lock()
                    totalOperations += 1
                    operationLock.unlock()
                    
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms (20 updates/sec)
                }
            }
            
            // Periodic layout updates (scene changes)
            group.addTask {
                var layoutIndex = 0
                while Date().timeIntervalSince(startTime) < testDuration {
                    let layouts = [
                        // Single speaker
                        StreamLayout(backgroundColor: "#000000", userRegions: [
                            UserRegion(userId: "load_test_user", x: 0, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                        ]),
                        // Two speakers
                        StreamLayout(backgroundColor: "#000000", userRegions: [
                            UserRegion(userId: "load_test_user", x: 0, y: 0, width: 960, height: 1080, zOrder: 1, alpha: 1.0),
                            UserRegion(userId: "participant_1", x: 960, y: 0, width: 960, height: 1080, zOrder: 1, alpha: 1.0)
                        ]),
                        // Four speakers
                        StreamLayout(backgroundColor: "#000000", userRegions: [
                            UserRegion(userId: "load_test_user", x: 0, y: 0, width: 960, height: 540, zOrder: 1, alpha: 1.0),
                            UserRegion(userId: "participant_1", x: 960, y: 0, width: 960, height: 540, zOrder: 1, alpha: 1.0),
                            UserRegion(userId: "participant_2", x: 0, y: 540, width: 960, height: 540, zOrder: 1, alpha: 1.0),
                            UserRegion(userId: "participant_3", x: 960, y: 540, width: 960, height: 540, zOrder: 1, alpha: 1.0)
                        ])
                    ]
                    
                    let layout = layouts[layoutIndex % layouts.count]
                    try? await manager.updateStreamLayout(layout: layout)
                    layoutIndex += 1
                    
                    operationLock.lock()
                    totalOperations += 1
                    operationLock.unlock()
                    
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds between layout changes
                }
            }
            
            // Audio adjustments (realistic user interactions)
            group.addTask {
                while Date().timeIntervalSince(startTime) < testDuration {
                    // Random audio adjustments
                    let adjustments = [
                        { try? await manager.setAudioMixingVolume(Int.random(in: 70...100)) },
                        { try? await manager.setPlaybackSignalVolume(Int.random(in: 80...100)) },
                        { try? await manager.muteMicrophone(Bool.random()) }
                    ]
                    
                    let adjustment = adjustments.randomElement()!
                    await adjustment()
                    
                    operationLock.lock()
                    totalOperations += 1
                    operationLock.unlock()
                    
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds between adjustments
                }
            }
        }
        
        let endTime = Date()
        let actualDuration = endTime.timeIntervalSince(startTime)
        let operationsPerSecond = Double(totalOperations) / actualDuration
        
        print("Load test completed:")
        print("  Duration: \(actualDuration) seconds")
        print("  Total operations: \(totalOperations)")
        print("  Operations per second: \(operationsPerSecond)")
        print("  Memory usage: \(manager.getCurrentMemoryUsage() / 1_000_000) MB")
        
        // Performance expectations
        #expect(operationsPerSecond > 20) // At least 20 operations per second
        #expect(manager.getCurrentMemoryUsage() < 200_000_000) // Less than 200MB
        #expect(manager.connectionState == .connected)
        #expect(manager.streamPushState == .running)
        
        // Clean shutdown
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
}