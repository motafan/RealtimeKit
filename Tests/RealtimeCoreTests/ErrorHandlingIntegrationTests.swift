// ErrorHandlingIntegrationTests.swift
// Comprehensive integration tests for error handling across the system

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Error Handling Integration Tests")
@MainActor
struct ErrorHandlingIntegrationTests {
    
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
            logLevel: .debug
        )
    }
    
    // MARK: - Network Error Handling Tests
    
    @Test("Handle network disconnection during active session")
    func testHandleNetworkDisconnectionDuringActiveSession() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var errorEvents: [RealtimeError] = []
        var stateChanges: [ConnectionState] = []
        
        manager.onError = { error in
            errorEvents.append(error)
        }
        
        manager.onConnectionStateChanged = { state in
            stateChanges.append(state)
        }
        
        // Configure and join room
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.connectionState == .connected)
        
        // Simulate network disconnection
        let networkError = RealtimeError.networkError("Network connection lost")
        manager.handleNetworkError(networkError)
        
        // Wait for error handling
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(errorEvents.count > 0)
        #expect(errorEvents.contains { error in
            if case .networkError(let message) = error {
                return message.contains("Network connection lost")
            }
            return false
        })
        
        // Should attempt reconnection
        #expect(stateChanges.contains(.reconnecting))
    }
    
    @Test("Handle provider failure with automatic fallback")
    func testHandleProviderFailureWithAutomaticFallback() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var providerSwitches: [ProviderType] = []
        manager.onProviderSwitched = { newProvider in
            providerSwitches.append(newProvider)
        }
        
        try await manager.configure(provider: .mock, config: config)
        
        // Simulate provider failure
        let providerError = RealtimeError.providerError("Mock provider failure", underlying: nil)
        manager.handleProviderError(providerError)
        
        // Wait for fallback handling
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should attempt to switch to fallback provider if available
        #expect(manager.currentProvider != nil)
    }
    
    @Test("Handle token expiration during streaming")
    func testHandleTokenExpirationDuringStreaming() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var tokenRenewalAttempts: [ProviderType] = []
        manager.onTokenRenewalAttempt = { provider in
            tokenRenewalAttempts.append(provider)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Start streaming
        let streamConfig = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://test.example.com/live/stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Simulate token expiration
        manager.handleTokenExpiration(provider: .mock, expiresIn: 10)
        
        // Wait for token renewal
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        #expect(tokenRenewalAttempts.contains(.mock))
        
        // Streaming should continue after token renewal
        #expect(manager.streamPushState == .running)
        
        try await manager.stopStreamPush()
    }
    
    // MARK: - Audio System Error Handling Tests
    
    @Test("Handle audio device failure")
    func testHandleAudioDeviceFailure() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var audioErrors: [RealtimeError] = []
        manager.onAudioError = { error in
            audioErrors.append(error)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Simulate audio device failure
        let audioError = RealtimeError.audioDeviceError("Microphone not available")
        manager.handleAudioDeviceError(audioError)
        
        #expect(audioErrors.count > 0)
        
        // Should automatically mute microphone as fallback
        #expect(manager.audioSettings.microphoneMuted == true)
    }
    
    @Test("Handle volume indicator failure")
    func testHandleVolumeIndicatorFailure() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Enable volume indicator
        try await manager.enableVolumeIndicator()
        
        // Simulate volume indicator failure
        let volumeError = RealtimeError.volumeIndicatorError("Volume detection failed")
        manager.handleVolumeIndicatorError(volumeError)
        
        // Should gracefully disable volume indicator
        #expect(manager.volumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
    }
    
    // MARK: - Message Processing Error Handling Tests
    
    @Test("Handle message processing failure with recovery")
    func testHandleMessageProcessingFailureWithRecovery() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var processingErrors: [RealtimeError] = []
        manager.onMessageProcessingError = { error in
            processingErrors.append(error)
        }
        
        try await manager.configure(provider: .mock, config: config)
        
        // Register a failing message processor
        let failingProcessor = FailingMessageProcessor()
        manager.registerMessageProcessor(failingProcessor)
        
        // Send a message that will fail processing
        let message = RealtimeMessage.text("Test message", from: "test_user")
        try await manager.sendMessage(message)
        
        // Wait for processing
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(processingErrors.count > 0)
        
        // System should continue functioning despite processor failure
        let successMessage = RealtimeMessage.text("Success message", from: "test_user")
        try await manager.sendMessage(successMessage)
    }
    
    // MARK: - Storage Error Handling Tests
    
    @Test("Handle storage failure with graceful degradation")
    func testHandleStorageFailureWithGracefulDegradation() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        // Simulate storage failure
        manager.simulateStorageFailure()
        
        // Audio settings should still work in memory
        try await manager.setAudioMixingVolume(75)
        #expect(manager.audioSettings.audioMixingVolume == 75)
        
        // But persistence should fail gracefully
        var storageErrors: [RealtimeError] = []
        manager.onStorageError = { error in
            storageErrors.append(error)
        }
        
        // Try to save settings (should fail but not crash)
        manager.saveAudioSettings()
        
        #expect(storageErrors.count > 0)
    }
    
    // MARK: - Concurrent Error Handling Tests
    
    @Test("Handle multiple concurrent errors")
    func testHandleMultipleConcurrentErrors() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var allErrors: [RealtimeError] = []
        let errorLock = NSLock()
        
        manager.onError = { error in
            errorLock.lock()
            allErrors.append(error)
            errorLock.unlock()
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Simulate multiple concurrent errors
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let networkError = RealtimeError.networkError("Network error 1")
                manager.handleNetworkError(networkError)
            }
            
            group.addTask {
                let audioError = RealtimeError.audioDeviceError("Audio error 1")
                manager.handleAudioDeviceError(audioError)
            }
            
            group.addTask {
                let providerError = RealtimeError.providerError("Provider error 1", underlying: nil)
                manager.handleProviderError(providerError)
            }
            
            group.addTask {
                let storageError = RealtimeError.storageError("Storage error 1")
                manager.handleStorageError(storageError)
            }
        }
        
        // Wait for error handling
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(allErrors.count >= 4)
        
        // System should remain stable
        #expect(manager.isInitialized)
    }
    
    // MARK: - Recovery Mechanism Tests
    
    @Test("Test automatic recovery from transient errors")
    func testAutomaticRecoveryFromTransientErrors() async throws {
        let manager = createRealtimeManager()
        manager.enableAutoRecovery(maxAttempts: 3, initialDelay: 0.1)
        
        let config = createTestConfig()
        
        var recoveryAttempts: [RealtimeError] = []
        manager.onRecoveryAttempt = { error in
            recoveryAttempts.append(error)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Simulate transient network error
        let transientError = RealtimeError.networkError("Temporary connection loss")
        manager.handleTransientError(transientError)
        
        // Wait for recovery attempts
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #expect(recoveryAttempts.count > 0)
        #expect(manager.connectionState == .connected) // Should recover
    }
    
    @Test("Test recovery failure handling")
    func testRecoveryFailureHandling() async throws {
        let manager = createRealtimeManager()
        manager.enableAutoRecovery(maxAttempts: 2, initialDelay: 0.05)
        
        let config = createTestConfig()
        
        var recoveryFailures: [RealtimeError] = []
        manager.onRecoveryFailed = { error in
            recoveryFailures.append(error)
        }
        
        try await manager.configure(provider: .mock, config: config)
        
        // Simulate persistent error that can't be recovered
        let persistentError = RealtimeError.authenticationFailed("Invalid credentials")
        manager.handlePersistentError(persistentError)
        
        // Wait for recovery attempts to exhaust
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(recoveryFailures.count > 0)
        #expect(manager.connectionState == .disconnected)
    }
    
    // MARK: - Error Propagation Tests
    
    @Test("Test error propagation through component hierarchy")
    func testErrorPropagationThroughComponentHierarchy() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var managerErrors: [RealtimeError] = []
        var volumeManagerErrors: [RealtimeError] = []
        var streamManagerErrors: [RealtimeError] = []
        
        manager.onError = { error in
            managerErrors.append(error)
        }
        
        manager.volumeIndicatorManager.onError = { error in
            volumeManagerErrors.append(error)
        }
        
        manager.streamPushManager.onError = { error in
            streamManagerErrors.append(error)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Start volume indicator and stream push
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://test.example.com/live/stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Simulate error in volume manager
        let volumeError = RealtimeError.volumeIndicatorError("Volume processing failed")
        manager.volumeIndicatorManager.handleError(volumeError)
        
        // Simulate error in stream manager
        let streamError = RealtimeError.streamPushError("Stream encoding failed")
        manager.streamPushManager.handleError(streamError)
        
        // Wait for error propagation
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(volumeManagerErrors.count > 0)
        #expect(streamManagerErrors.count > 0)
        #expect(managerErrors.count >= 2) // Should receive errors from sub-managers
        
        try await manager.stopStreamPush()
    }
    
    // MARK: - Error Context and Debugging Tests
    
    @Test("Test error context collection")
    func testErrorContextCollection() async throws {
        let manager = createRealtimeManager()
        manager.enableErrorContextCollection()
        
        let config = createTestConfig()
        
        var errorReports: [ErrorReport] = []
        manager.onErrorReport = { report in
            errorReports.append(report)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Simulate error with context
        let contextualError = RealtimeError.networkError("Connection timeout")
        manager.handleErrorWithContext(contextualError)
        
        #expect(errorReports.count > 0)
        
        let report = errorReports.first!
        #expect(report.context["provider"] as? String == "mock")
        #expect(report.context["connectionState"] as? String == "connected")
        #expect(report.context["activeSession"] as? Bool == true)
        #expect(report.context["timestamp"] != nil)
    }
    
    // MARK: - Memory Management During Errors Tests
    
    @Test("Test memory management during error conditions")
    func testMemoryManagementDuringErrorConditions() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        // Create many objects that might leak during errors
        for i in 1...100 {
            try await manager.joinRoom(
                roomId: "room_\(i)",
                userId: "user_\(i)",
                userName: "User \(i)",
                userRole: .broadcaster
            )
            
            // Simulate error during session
            let error = RealtimeError.networkError("Error \(i)")
            manager.handleNetworkError(error)
            
            try await manager.leaveRoom()
        }
        
        // Force cleanup
        manager.performMemoryCleanup()
        
        // Memory usage should not grow unbounded
        let memoryUsage = manager.getCurrentMemoryUsage()
        #expect(memoryUsage < 100_000_000) // Less than 100MB
    }
    
    // MARK: - Helper Classes
    
    class FailingMessageProcessor: MessageProcessor {
        let identifier = "failing_processor"
        let priority = 100
        
        func canProcess(_ message: RealtimeMessage) -> Bool {
            return true
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            throw RealtimeError.processingFailed("Simulated processor failure")
        }
    }
}