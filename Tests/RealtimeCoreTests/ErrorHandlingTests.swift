// ErrorHandlingTests.swift
// Unit tests for error handling and recovery system

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    @Test("RealtimeError properties")
    @MainActor
    func testRealtimeErrorProperties() async throws {
        // Test error descriptions
        let connectionError = RealtimeError.connectionFailed("Network unavailable")
        #expect(connectionError.errorDescription == "连接失败: Network unavailable")
        #expect(connectionError.errorCode == "CONNECTION_FAILED")
        #expect(connectionError.isRecoverable == true)
        #expect(connectionError.severity == .high)
        #expect(connectionError.category == .connection)
        
        // Test non-recoverable error
        let authError = RealtimeError.authenticationFailed
        #expect(authError.isRecoverable == false)
        #expect(authError.severity == .critical)
        #expect(authError.category == .connection)
        
        // Test recovery suggestion
        let tokenError = RealtimeError.tokenExpired(.agora)
        #expect(tokenError.recoverySuggestion == "Token 已过期，正在自动续期")
    }
    
    @Test("Error severity classification")
    @MainActor
    func testErrorSeverityClassification() async throws {
        // Critical errors
        let criticalErrors: [RealtimeError] = [
            .authenticationFailed,
            .invalidToken(.agora),
            .storagePermissionDenied,
            .microphonePermissionDenied
        ]
        
        for error in criticalErrors {
            #expect(error.severity == .critical)
        }
        
        // High severity errors
        let highErrors: [RealtimeError] = [
            .connectionFailed("test"),
            .networkError("test"),
            .providerInitializationFailed(.agora, "test"),
            .roomJoinFailed("test")
        ]
        
        for error in highErrors {
            #expect(error.severity == .high)
        }
        
        // Medium severity errors
        let mediumErrors: [RealtimeError] = [
            .connectionTimeout,
            .tokenExpired(.agora),
            .volumeControlFailed("test"),
            .audioControlFailed("test")
        ]
        
        for error in mediumErrors {
            #expect(error.severity == .medium)
        }
        
        // Low severity errors
        let lowErrors: [RealtimeError] = [
            .invalidParameter("test"),
            .parameterOutOfRange("test", "0-100"),
            .audioSettingsInvalid("test")
        ]
        
        for error in lowErrors {
            #expect(error.severity == .low)
        }
    }
    
    @Test("Error category classification")
    @MainActor
    func testErrorCategoryClassification() async throws {
        // Connection category
        let connectionErrors: [RealtimeError] = [
            .connectionFailed("test"),
            .connectionTimeout,
            .networkError("test"),
            .authenticationFailed
        ]
        
        for error in connectionErrors {
            #expect(error.category == .connection)
        }
        
        // Authentication category
        let authErrors: [RealtimeError] = [
            .tokenExpired(.agora),
            .tokenRenewalFailed(.agora, "test"),
            .invalidToken(.agora),
            .tokenNotProvided(.agora)
        ]
        
        for error in authErrors {
            #expect(error.category == .authentication)
        }
        
        // Audio category
        let audioErrors: [RealtimeError] = [
            .audioControlFailed("test"),
            .microphonePermissionDenied,
            .audioStreamControlFailed("test"),
            .volumeControlFailed("test"),
            .audioSettingsInvalid("test")
        ]
        
        for error in audioErrors {
            #expect(error.category == .audio)
        }
    }
}

@Suite("Error Recovery Tests")
struct ErrorRecoveryTests {
    
    @Test("Error recovery context creation")
    @MainActor
    func testErrorRecoveryContextCreation() async throws {
        let error = RealtimeError.connectionTimeout
        let strategy = ErrorRecoveryStrategy.retry(maxAttempts: 3, delay: 1.0)
        
        let context = ErrorRecoveryContext(
            error: error,
            attemptCount: 0,
            recoveryStrategy: strategy
        )
        
        #expect(context.error == error)
        #expect(context.attemptCount == 0)
        #expect(context.shouldAttemptRecovery == true)
        #expect(context.nextAttemptDelay == 1.0)
    }
    
    @Test("Recovery strategy attempt limits")
    @MainActor
    func testRecoveryStrategyAttemptLimits() async throws {
        let error = RealtimeError.connectionTimeout
        
        // Test retry strategy
        let retryStrategy = ErrorRecoveryStrategy.retry(maxAttempts: 3, delay: 1.0)
        var context = ErrorRecoveryContext(error: error, attemptCount: 2, recoveryStrategy: retryStrategy)
        #expect(context.shouldAttemptRecovery == true)
        
        context = ErrorRecoveryContext(error: error, attemptCount: 3, recoveryStrategy: retryStrategy)
        #expect(context.shouldAttemptRecovery == false)
        
        // Test no recovery strategy
        let noRecoveryStrategy = ErrorRecoveryStrategy.none
        context = ErrorRecoveryContext(error: error, attemptCount: 0, recoveryStrategy: noRecoveryStrategy)
        #expect(context.shouldAttemptRecovery == false)
    }
    
    @Test("Exponential backoff delay calculation")
    @MainActor
    func testExponentialBackoffDelay() async throws {
        let error = RealtimeError.connectionTimeout
        let strategy = ErrorRecoveryStrategy.automatic(
            strategy: .exponentialBackoff(baseDelay: 1.0, maxDelay: 10.0)
        )
        
        // Test increasing delays
        let context1 = ErrorRecoveryContext(error: error, attemptCount: 0, recoveryStrategy: strategy)
        #expect(context1.nextAttemptDelay == 1.0)
        
        let context2 = ErrorRecoveryContext(error: error, attemptCount: 1, recoveryStrategy: strategy)
        #expect(context2.nextAttemptDelay == 2.0)
        
        let context3 = ErrorRecoveryContext(error: error, attemptCount: 2, recoveryStrategy: strategy)
        #expect(context3.nextAttemptDelay == 4.0)
        
        // Test max delay cap
        let context4 = ErrorRecoveryContext(error: error, attemptCount: 5, recoveryStrategy: strategy)
        #expect(context4.nextAttemptDelay == 10.0) // Capped at maxDelay
    }
    
    @Test("Linear backoff delay calculation")
    @MainActor
    func testLinearBackoffDelay() async throws {
        let error = RealtimeError.connectionTimeout
        let strategy = ErrorRecoveryStrategy.automatic(
            strategy: .linearBackoff(delay: 2.0)
        )
        
        let context1 = ErrorRecoveryContext(error: error, attemptCount: 0, recoveryStrategy: strategy)
        #expect(context1.nextAttemptDelay == 2.0)
        
        let context2 = ErrorRecoveryContext(error: error, attemptCount: 1, recoveryStrategy: strategy)
        #expect(context2.nextAttemptDelay == 4.0)
        
        let context3 = ErrorRecoveryContext(error: error, attemptCount: 2, recoveryStrategy: strategy)
        #expect(context3.nextAttemptDelay == 6.0)
    }
    
    @Test("Error recovery manager registration")
    @MainActor
    func testErrorRecoveryManagerRegistration() async throws {
        let manager = ErrorRecoveryManager()
        let error = RealtimeError.connectionTimeout
        
        #expect(manager.activeRecoveries.isEmpty)
        
        await manager.registerError(error, identifier: "test-error")
        
        #expect(manager.activeRecoveries.count == 1)
        #expect(manager.activeRecoveries["test-error"]?.error == error)
    }
    
    @Test("Recovery cancellation")
    @MainActor
    func testRecoveryCancellation() async throws {
        let manager = ErrorRecoveryManager()
        let error = RealtimeError.connectionTimeout
        
        await manager.registerError(error, identifier: "test-error")
        #expect(manager.activeRecoveries.count == 1)
        
        manager.cancelRecovery(for: "test-error")
        #expect(manager.activeRecoveries.isEmpty)
    }
}

@Suite("Error Handler Tests")
struct ErrorHandlerTests {
    
    @Test("Error handler singleton")
    @MainActor
    func testErrorHandlerSingleton() async throws {
        let handler1 = ErrorHandler.shared
        let handler2 = ErrorHandler.shared
        
        #expect(handler1 === handler2)
    }
    
    @Test("Error handling and recording")
    @MainActor
    func testErrorHandlingAndRecording() async throws {
        let handler = ErrorHandler.shared
        handler.clearErrorHistory()
        
        let error = RealtimeError.connectionTimeout
        await handler.handleError(error, context: "Test Context")
        
        #expect(handler.recentErrors.count == 1)
        #expect(handler.recentErrors.first?.error == error)
        #expect(handler.recentErrors.first?.context == "Test Context")
        #expect(handler.errorStats.totalErrors == 1)
        #expect(handler.errorStats.recoverableErrors == 1)
    }
    
    @Test("Error statistics tracking")
    @MainActor
    func testErrorStatisticsTracking() async throws {
        let handler = ErrorHandler.shared
        handler.clearErrorHistory()
        
        // Add various errors
        await handler.handleError(.connectionTimeout)
        await handler.handleError(.authenticationFailed)
        await handler.handleError(.volumeControlFailed("test"))
        await handler.handleError(.invalidParameter("test"))
        
        let stats = handler.errorStats
        #expect(stats.totalErrors == 4)
        #expect(stats.recoverableErrors == 3) // connectionTimeout, volumeControlFailed, invalidParameter
        #expect(stats.nonRecoverableErrors == 1) // authenticationFailed
        
        // Check category distribution
        #expect(stats.errorsByCategory[.connection] == 2) // connectionTimeout, authenticationFailed
        #expect(stats.errorsByCategory[.audio] == 1) // volumeControlFailed
        #expect(stats.errorsByCategory[.validation] == 1) // invalidParameter
        
        // Check severity distribution
        #expect(stats.errorsBySeverity[.critical] == 1) // authenticationFailed
        #expect(stats.errorsBySeverity[.medium] == 2) // connectionTimeout, volumeControlFailed
        #expect(stats.errorsBySeverity[.low] == 1) // invalidParameter
    }
    
    @Test("Error filtering by category")
    @MainActor
    func testErrorFilteringByCategory() async throws {
        let handler = ErrorHandler.shared
        handler.clearErrorHistory()
        
        await handler.handleError(.connectionTimeout)
        await handler.handleError(.audioControlFailed("test"))
        await handler.handleError(.streamPushStartFailed("test"))
        
        let connectionErrors = handler.getErrors(by: .connection)
        let audioErrors = handler.getErrors(by: .audio)
        let streamingErrors = handler.getErrors(by: .streaming)
        
        #expect(connectionErrors.count == 1)
        #expect(audioErrors.count == 1)
        #expect(streamingErrors.count == 1)
    }
    
    @Test("Error filtering by severity")
    @MainActor
    func testErrorFilteringBySeverity() async throws {
        let handler = ErrorHandler.shared
        handler.clearErrorHistory()
        
        await handler.handleError(.authenticationFailed) // critical
        await handler.handleError(.connectionTimeout) // medium
        await handler.handleError(.invalidParameter("test")) // low
        
        let criticalErrors = handler.getErrors(by: .critical)
        let mediumErrors = handler.getErrors(by: .medium)
        let lowErrors = handler.getErrors(by: .low)
        
        #expect(criticalErrors.count == 1)
        #expect(mediumErrors.count == 1)
        #expect(lowErrors.count == 1)
    }
    
    @Test("Generic error conversion")
    @MainActor
    func testGenericErrorConversion() async throws {
        let handler = ErrorHandler.shared
        handler.clearErrorHistory()
        
        struct CustomError: Error {
            let message: String
        }
        
        let customError = CustomError(message: "Custom error message")
        await handler.handleError(customError)
        
        #expect(handler.recentErrors.count == 1)
        
        let recordedError = handler.recentErrors.first?.error
        if case .operationFailed(let provider, let message) = recordedError {
            #expect(provider == .mock)
            #expect(message.contains("Custom error message"))
        } else {
            Issue.record("Expected operationFailed error")
        }
    }
    
    @Test("Convenience error handling methods")
    @MainActor
    func testConvenienceErrorHandlingMethods() async throws {
        let handler = ErrorHandler.shared
        handler.clearErrorHistory()
        
        struct TimeoutError: Error {
            var localizedDescription: String { return "Connection timeout occurred" }
        }
        
        struct PermissionError: Error {
            var localizedDescription: String { return "Microphone permission denied" }
        }
        
        // Test connection error handling
        await handler.handleConnectionError(TimeoutError())
        #expect(handler.recentErrors.count == 1)
        #expect(handler.recentErrors.first?.error == .connectionTimeout)
        
        // Test audio error handling
        handler.clearErrorHistory()
        await handler.handleAudioError(PermissionError())
        #expect(handler.recentErrors.count == 1)
        #expect(handler.recentErrors.first?.error == .microphonePermissionDenied)
    }
    
    @Test("Error history management")
    @MainActor
    func testErrorHistoryManagement() async throws {
        let handler = ErrorHandler.shared
        handler.clearErrorHistory()
        
        // Add errors up to the limit
        for i in 0..<55 { // More than maxRecentErrors (50)
            await handler.handleError(.invalidParameter("error \(i)"))
        }
        
        // Should only keep the most recent 50 errors
        #expect(handler.recentErrors.count == 50)
        
        // The first error should be the most recent one
        if case .invalidParameter(let message) = handler.recentErrors.first?.error {
            #expect(message == "error 54")
        } else {
            Issue.record("Expected most recent error to be first")
        }
    }
}

@Suite("Error Statistics Tests")
struct ErrorStatisticsTests {
    
    @Test("Recovery success rate calculation")
    @MainActor
    func testRecoverySuccessRateCalculation() async throws {
        var stats = ErrorStatistics()
        
        // No recoveries attempted
        #expect(stats.recoverySuccessRate == 0.0)
        
        // Some successful recoveries
        stats.successfulRecoveries = 3
        stats.failedRecoveries = 2
        #expect(stats.recoverySuccessRate == 0.6)
        
        // All successful
        stats.successfulRecoveries = 5
        stats.failedRecoveries = 0
        #expect(stats.recoverySuccessRate == 1.0)
        
        // All failed
        stats.successfulRecoveries = 0
        stats.failedRecoveries = 3
        #expect(stats.recoverySuccessRate == 0.0)
    }
    
    @Test("Most common category and severity")
    @MainActor
    func testMostCommonCategoryAndSeverity() async throws {
        var stats = ErrorStatistics()
        
        // Add category counts
        stats.errorsByCategory[.connection] = 5
        stats.errorsByCategory[.audio] = 3
        stats.errorsByCategory[.validation] = 1
        
        #expect(stats.mostCommonCategory == .connection)
        
        // Add severity counts
        stats.errorsBySeverity[.critical] = 2
        stats.errorsBySeverity[.high] = 4
        stats.errorsBySeverity[.medium] = 1
        
        #expect(stats.mostCommonSeverity == .high)
    }
}