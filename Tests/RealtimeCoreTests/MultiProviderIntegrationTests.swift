// MultiProviderIntegrationTests.swift
// Integration tests for multi-provider compatibility and switching

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Multi-Provider Integration Tests")
@MainActor
struct MultiProviderIntegrationTests {
    
    // MARK: - Test Setup
    
    private func createRealtimeManager() -> RealtimeManager {
        let manager = RealtimeManager.shared
        manager.registerMockProvider()
        return manager
    }
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "test_app_id",
            appKey: "test_app_key",
            logLevel: .info
        )
    }
    
    // MARK: - Provider Switching Tests
    
    @Test("Switch providers during active session")
    func testSwitchProvidersDuringActiveSession() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var providerSwitches: [(from: ProviderType, to: ProviderType)] = []
        manager.onProviderSwitched = { from, to in
            providerSwitches.append((from: from, to: to))
        }
        
        // Start with mock provider
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Set up audio settings
        try await manager.setAudioMixingVolume(75)
        try await manager.muteMicrophone(false)
        
        let originalSettings = manager.audioSettings
        let originalSession = manager.currentSession
        
        // Switch to another mock provider (simulating different provider)
        try await manager.switchProvider(to: .mock, preserveSession: true)
        
        // Verify session and settings are preserved
        #expect(manager.currentSession?.userId == originalSession?.userId)
        #expect(manager.currentSession?.userRole == originalSession?.userRole)
        #expect(manager.audioSettings.audioMixingVolume == originalSettings.audioMixingVolume)
        #expect(manager.audioSettings.microphoneMuted == originalSettings.microphoneMuted)
        
        // Verify provider switch was recorded
        #expect(providerSwitches.count > 0)
        
        // Test functionality after switch
        try await manager.setAudioMixingVolume(50)
        #expect(manager.audioSettings.audioMixingVolume == 50)
        
        let message = RealtimeMessage.text("Test after switch", from: "test_user")
        try await manager.sendMessage(message)
    }
    
    @Test("Provider fallback on failure")
    func testProviderFallbackOnFailure() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        // Register multiple providers with fallback chain
        manager.registerProviderFallbackChain([.mock, .mock]) // Using mock for both
        
        var fallbackAttempts: [ProviderType] = []
        manager.onFallbackAttempt = { provider in
            fallbackAttempts.append(provider)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Simulate primary provider failure
        let providerError = RealtimeError.providerError("Primary provider failed", underlying: nil)
        manager.handleProviderFailure(providerError)
        
        // Wait for fallback processing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should attempt fallback
        #expect(fallbackAttempts.count > 0)
        
        // Session should be maintained
        #expect(manager.currentSession != nil)
        #expect(manager.connectionState != .disconnected)
    }
    
    @Test("Cross-provider feature compatibility")
    func testCrossProviderFeatureCompatibility() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        let providers: [ProviderType] = [.mock] // In real implementation, would test multiple providers
        
        for provider in providers {
            print("Testing provider: \(provider)")
            
            try await manager.configure(provider: provider, config: config)
            try await manager.joinRoom(
                roomId: "test_room_\(provider.rawValue)",
                userId: "test_user",
                userName: "Test User",
                userRole: .broadcaster
            )
            
            // Test audio features
            try await manager.setAudioMixingVolume(80)
            #expect(manager.audioSettings.audioMixingVolume == 80)
            
            try await manager.muteMicrophone(true)
            #expect(manager.audioSettings.microphoneMuted == true)
            
            // Test volume indicator
            try await manager.enableVolumeIndicator()
            #expect(manager.volumeIndicatorEnabled == true)
            
            // Test message processing
            let message = RealtimeMessage.text("Cross-provider test", from: "test_user")
            try await manager.sendMessage(message)
            
            // Test stream push if supported
            if manager.supportsFeature(.streamPush) {
                let streamConfig = try StreamPushConfig.standard720p(
                    pushUrl: "rtmp://test.example.com/live/\(provider.rawValue)"
                )
                try await manager.startStreamPush(config: streamConfig)
                #expect(manager.streamPushState == .running)
                
                try await manager.stopStreamPush()
                #expect(manager.streamPushState == .stopped)
            }
            
            // Test media relay if supported
            if manager.supportsFeature(.mediaRelay) {
                let sourceChannel = try RelayChannelInfo(
                    channelName: "source_\(provider.rawValue)",
                    userId: "source_user"
                )
                let destChannel = try RelayChannelInfo(
                    channelName: "dest_\(provider.rawValue)",
                    userId: "dest_user"
                )
                
                try await manager.startOneToOneRelay(
                    source: sourceChannel,
                    destination: destChannel
                )
                #expect(manager.isMediaRelayActive == true)
                
                try await manager.stopMediaRelay()
                #expect(manager.isMediaRelayActive == false)
            }
            
            try await manager.disableVolumeIndicator()
            try await manager.leaveRoom()
        }
    }
    
    @Test("Provider-specific configuration handling")
    func testProviderSpecificConfigurationHandling() async throws {
        let manager = createRealtimeManager()
        
        // Test different configurations for different providers
        let mockConfig = RealtimeConfig(
            appId: "mock_app_id",
            appKey: "mock_app_key",
            logLevel: .debug,
            customSettings: ["mock_setting": "mock_value"]
        )
        
        try await manager.configure(provider: .mock, config: mockConfig)
        
        // Verify provider-specific settings are applied
        #expect(manager.currentProvider == .mock)
        #expect(manager.currentConfig.customSettings["mock_setting"] as? String == "mock_value")
        
        // Test configuration validation for different providers
        let invalidConfig = RealtimeConfig(
            appId: "", // Invalid empty app ID
            appKey: "test_key",
            logLevel: .error
        )
        
        await #expect(throws: RealtimeError.self) {
            try await manager.configure(provider: .mock, config: invalidConfig)
        }
    }
    
    // MARK: - Token Management Across Providers
    
    @Test("Token management across multiple providers")
    func testTokenManagementAcrossMultipleProviders() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var tokenRenewalRequests: [(provider: ProviderType, expiresIn: Int)] = []
        manager.onTokenRenewalRequest = { provider, expiresIn in
            tokenRenewalRequests.append((provider: provider, expiresIn: expiresIn))
        }
        
        // Configure with first provider
        try await manager.configure(provider: .mock, config: config)
        
        // Simulate token expiration
        manager.handleTokenExpiration(provider: .mock, expiresIn: 30)
        
        // Switch provider
        try await manager.switchProvider(to: .mock, preserveSession: true)
        
        // Simulate token expiration on new provider
        manager.handleTokenExpiration(provider: .mock, expiresIn: 60)
        
        // Should handle token renewal for both providers
        #expect(tokenRenewalRequests.count >= 2)
    }
    
    // MARK: - State Synchronization Tests
    
    @Test("State synchronization during provider switch")
    func testStateSynchronizationDuringProviderSwitch() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "sync_test_room",
            userId: "sync_user",
            userName: "Sync User",
            userRole: .broadcaster
        )
        
        // Set up complex state
        try await manager.setAudioMixingVolume(65)
        try await manager.setPlaybackSignalVolume(80)
        try await manager.setRecordingSignalVolume(90)
        try await manager.muteMicrophone(true)
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://test.example.com/live/sync_test"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Capture state before switch
        let preState = ProviderState(
            audioSettings: manager.audioSettings,
            volumeEnabled: manager.volumeIndicatorEnabled,
            streamState: manager.streamPushState,
            session: manager.currentSession
        )
        
        // Switch provider
        try await manager.switchProvider(to: .mock, preserveSession: true)
        
        // Verify state is synchronized
        #expect(manager.audioSettings.audioMixingVolume == preState.audioSettings.audioMixingVolume)
        #expect(manager.audioSettings.playbackSignalVolume == preState.audioSettings.playbackSignalVolume)
        #expect(manager.audioSettings.recordingSignalVolume == preState.audioSettings.recordingSignalVolume)
        #expect(manager.audioSettings.microphoneMuted == preState.audioSettings.microphoneMuted)
        #expect(manager.volumeIndicatorEnabled == preState.volumeEnabled)
        #expect(manager.streamPushState == preState.streamState)
        #expect(manager.currentSession?.userId == preState.session?.userId)
        
        try await manager.stopStreamPush()
    }
    
    // MARK: - Performance Comparison Tests
    
    @Test("Performance comparison across providers")
    func testPerformanceComparisonAcrossProviders() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        let providers: [ProviderType] = [.mock] // In real implementation, would test multiple
        var performanceResults: [ProviderType: PerformanceMetrics] = [:]
        
        for provider in providers {
            print("Testing performance for provider: \(provider)")
            
            try await manager.configure(provider: provider, config: config)
            try await manager.joinRoom(
                roomId: "perf_test_room",
                userId: "perf_user",
                userName: "Performance User",
                userRole: .broadcaster
            )
            
            let startTime = Date()
            let messageCount = 1000
            
            // Message processing performance
            for i in 1...messageCount {
                let message = RealtimeMessage.text("Performance test \(i)", from: "perf_user")
                try await manager.sendMessage(message)
            }
            
            let messageEndTime = Date()
            let messageDuration = messageEndTime.timeIntervalSince(startTime)
            
            // Volume indicator performance
            try await manager.enableVolumeIndicator()
            let volumeStartTime = Date()
            
            for _ in 1...100 {
                let volumeInfos = [
                    UserVolumeInfo(userId: "user1", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                    UserVolumeInfo(userId: "user2", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                ]
                manager.processVolumeUpdate(volumeInfos)
            }
            
            let volumeEndTime = Date()
            let volumeDuration = volumeEndTime.timeIntervalSince(volumeStartTime)
            
            performanceResults[provider] = PerformanceMetrics(
                messageProcessingRate: Double(messageCount) / messageDuration,
                volumeProcessingRate: 100.0 / volumeDuration,
                memoryUsage: manager.getCurrentMemoryUsage()
            )
            
            try await manager.disableVolumeIndicator()
            try await manager.leaveRoom()
        }
        
        // Verify performance is within acceptable ranges
        for (provider, metrics) in performanceResults {
            print("Provider \(provider): Messages/sec: \(metrics.messageProcessingRate), Volume/sec: \(metrics.volumeProcessingRate)")
            
            #expect(metrics.messageProcessingRate > 100) // At least 100 messages/sec
            #expect(metrics.volumeProcessingRate > 500)  // At least 500 volume updates/sec
            #expect(metrics.memoryUsage < 100_000_000)   // Less than 100MB
        }
    }
    
    // MARK: - Concurrent Provider Operations
    
    @Test("Concurrent operations across providers")
    func testConcurrentOperationsAcrossProviders() async throws {
        let manager1 = createRealtimeManager()
        let manager2 = createRealtimeManager()
        let config = createTestConfig()
        
        // Configure different managers with different providers
        try await manager1.configure(provider: .mock, config: config)
        try await manager2.configure(provider: .mock, config: config)
        
        var completedOperations = 0
        let operationLock = NSLock()
        
        await withTaskGroup(of: Void.self) { group in
            // Manager 1 operations
            group.addTask {
                do {
                    try await manager1.joinRoom(
                        roomId: "concurrent_room_1",
                        userId: "user_1",
                        userName: "User 1",
                        userRole: .broadcaster
                    )
                    
                    for i in 1...50 {
                        let message = RealtimeMessage.text("Message \(i) from manager 1", from: "user_1")
                        try await manager1.sendMessage(message)
                    }
                    
                    operationLock.lock()
                    completedOperations += 1
                    operationLock.unlock()
                } catch {
                    print("Manager 1 error: \(error)")
                }
            }
            
            // Manager 2 operations
            group.addTask {
                do {
                    try await manager2.joinRoom(
                        roomId: "concurrent_room_2",
                        userId: "user_2",
                        userName: "User 2",
                        userRole: .broadcaster
                    )
                    
                    for i in 1...50 {
                        let message = RealtimeMessage.text("Message \(i) from manager 2", from: "user_2")
                        try await manager2.sendMessage(message)
                    }
                    
                    operationLock.lock()
                    completedOperations += 1
                    operationLock.unlock()
                } catch {
                    print("Manager 2 error: \(error)")
                }
            }
        }
        
        #expect(completedOperations == 2)
    }
    
    // MARK: - Helper Structures
    
    struct ProviderState {
        let audioSettings: AudioSettings
        let volumeEnabled: Bool
        let streamState: StreamPushState
        let session: UserSession?
    }
    
    struct PerformanceMetrics {
        let messageProcessingRate: Double
        let volumeProcessingRate: Double
        let memoryUsage: Int
    }
}