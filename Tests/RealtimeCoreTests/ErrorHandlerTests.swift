// ErrorHandlerTests.swift
// Comprehensive unit tests for ErrorHandler

import Testing
import Combine
@testable import RealtimeCore

@Suite("ErrorHandler Tests")
@MainActor
struct ErrorHandlerTests {
    
    // MARK: - Test Setup
    
    private func createErrorHandler() -> ErrorHandler {
        return ErrorHandler()
    }
    
    // MARK: - Initialization Tests
    
    @Test("ErrorHandler initialization")
    func testErrorHandlerInitialization() {
        let handler = createErrorHandler()
        
        #expect(handler.errorCount == 0)
        #expect(handler.lastError == nil)
        #expect(handler.isRecoveryInProgress == false)
        #expect(handler.recoveryStrategies.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle network error")
    func testHandleNetworkError() async {
        let handler = createErrorHandler()
        
        var handledErrors: [RealtimeError] = []
        handler.onErrorHandled = { error in
            handledErrors.append(error)
        }
        
        let networkError = RealtimeError.networkError("Connection timeout")
        await handler.handleError(networkError)
        
        #expect(handler.errorCount == 1)
        #expect(handler.lastError?.localizedDescription == networkError.localizedDescription)
        #expect(handledErrors.count == 1)
    }
    
    @Test("Handle authentication error")
    func testHandleAuthenticationError() async {
        let handler = createErrorHandler()
        
        var recoveryAttempts: [RealtimeError] = []
        handler.onRecoveryAttempt = { error in
            recoveryAttempts.append(error)
        }
        
        let authError = RealtimeError.authenticationFailed("Invalid token")
        await handler.handleError(authError)
        
        #expect(handler.errorCount == 1)
        #expect(recoveryAttempts.count == 1)
    }
    
    @Test("Handle provider error")
    func testHandleProviderError() async {
        let handler = createErrorHandler()
        
        let providerError = RealtimeError.providerError("Agora SDK error", underlying: nil)
        await handler.handleError(providerError)
        
        #expect(handler.errorCount == 1)
        #expect(handler.lastError?.localizedDescription.contains("Agora SDK error") == true)
    }
    
    @Test("Handle configuration error")
    func testHandleConfigurationError() async {
        let handler = createErrorHandler()
        
        let configError = RealtimeError.invalidConfiguration("Missing app ID")
        await handler.handleError(configError)
        
        #expect(handler.errorCount == 1)
        #expect(handler.lastError?.localizedDescription.contains("Missing app ID") == true)
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Automatic recovery for network errors")
    func testAutomaticRecoveryForNetworkErrors() async {
        let handler = createErrorHandler()
        handler.enableAutoRecovery(maxAttempts: 3, initialDelay: 0.1)
        
        var recoveryAttempts: [RealtimeError] = []
        handler.onRecoveryAttempt = { error in
            recoveryAttempts.append(error)
        }
        
        let networkError = RealtimeError.networkError("Connection lost")
        await handler.handleError(networkError)
        
        // Wait for recovery attempts
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(recoveryAttempts.count > 0)
        #expect(handler.isRecoveryInProgress == true || recoveryAttempts.count >= 3)
    }
    
    @Test("Recovery strategy registration")
    func testRecoveryStrategyRegistration() async {
        let handler = createErrorHandler()
        
        var networkRecoveryCalled = false
        let networkStrategy: ErrorRecoveryStrategy = { error in
            networkRecoveryCalled = true
            return .retry(after: 0.1)
        }
        
        handler.registerRecoveryStrategy(for: .networkError(""), strategy: networkStrategy)
        
        let networkError = RealtimeError.networkError("Connection failed")
        await handler.handleError(networkError)
        
        // Wait for strategy execution
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(networkRecoveryCalled == true)
    }
    
    @Test("Custom recovery strategy")
    func testCustomRecoveryStrategy() async {
        let handler = createErrorHandler()
        
        var customRecoveryExecuted = false
        let customStrategy: ErrorRecoveryStrategy = { error in
            customRecoveryExecuted = true
            return .handled
        }
        
        handler.registerRecoveryStrategy(for: .authenticationFailed(""), strategy: customStrategy)
        
        let authError = RealtimeError.authenticationFailed("Token expired")
        await handler.handleError(authError)
        
        #expect(customRecoveryExecuted == true)
    }
    
    @Test("Recovery with exponential backoff")
    func testRecoveryWithExponentialBackoff() async {
        let handler = createErrorHandler()
        handler.enableAutoRecovery(maxAttempts: 3, initialDelay: 0.05)
        
        let startTime = Date()
        var recoveryTimes: [Date] = []
        
        handler.onRecoveryAttempt = { _ in
            recoveryTimes.append(Date())
        }
        
        let networkError = RealtimeError.networkError("Connection unstable")
        await handler.handleError(networkError)
        
        // Wait for all recovery attempts
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Check that delays increase exponentially
        if recoveryTimes.count >= 2 {
            let firstDelay = recoveryTimes[0].timeIntervalSince(startTime)
            let secondDelay = recoveryTimes[1].timeIntervalSince(recoveryTimes[0])
            
            #expect(secondDelay > firstDelay)
        }
    }
    
    @Test("Recovery failure handling")
    func testRecoveryFailureHandling() async {
        let handler = createErrorHandler()
        handler.enableAutoRecovery(maxAttempts: 2, initialDelay: 0.05)
        
        var recoveryFailures: [RealtimeError] = []
        handler.onRecoveryFailed = { error in
            recoveryFailures.append(error)
        }
        
        // Register a strategy that always fails
        let failingStrategy: ErrorRecoveryStrategy = { error in
            return .failed(RealtimeError.recoveryFailed("Recovery not possible"))
        }
        
        handler.registerRecoveryStrategy(for: .networkError(""), strategy: failingStrategy)
        
        let networkError = RealtimeError.networkError("Unrecoverable error")
        await handler.handleError(networkError)
        
        // Wait for recovery attempts
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        #expect(recoveryFailures.count > 0)
        #expect(handler.isRecoveryInProgress == false)
    }
    
    // MARK: - Error Categorization Tests
    
    @Test("Error severity classification")
    func testErrorSeverityClassification() {
        let handler = createErrorHandler()
        
        let criticalError = RealtimeError.authenticationFailed("Invalid credentials")
        let warningError = RealtimeError.networkError("Slow connection")
        let infoError = RealtimeError.configurationWarning("Deprecated setting")
        
        #expect(handler.getErrorSeverity(criticalError) == .critical)
        #expect(handler.getErrorSeverity(warningError) == .warning)
        #expect(handler.getErrorSeverity(infoError) == .info)
    }
    
    @Test("Error category grouping")
    func testErrorCategoryGrouping() {
        let handler = createErrorHandler()
        
        let networkError1 = RealtimeError.networkError("Connection timeout")
        let networkError2 = RealtimeError.networkError("DNS resolution failed")
        let authError = RealtimeError.authenticationFailed("Token expired")
        
        #expect(handler.getErrorCategory(networkError1) == .network)
        #expect(handler.getErrorCategory(networkError2) == .network)
        #expect(handler.getErrorCategory(authError) == .authentication)
    }
    
    // MARK: - Error Statistics Tests
    
    @Test("Error frequency tracking")
    func testErrorFrequencyTracking() async {
        let handler = createErrorHandler()
        
        // Generate multiple errors of same type
        for _ in 1...5 {
            await handler.handleError(RealtimeError.networkError("Connection issue"))
        }
        
        // Generate different error type
        for _ in 1...2 {
            await handler.handleError(RealtimeError.authenticationFailed("Auth issue"))
        }
        
        let networkFrequency = handler.getErrorFrequency(for: .network)
        let authFrequency = handler.getErrorFrequency(for: .authentication)
        
        #expect(networkFrequency == 5)
        #expect(authFrequency == 2)
        #expect(handler.errorCount == 7)
    }
    
    @Test("Error rate limiting")
    func testErrorRateLimiting() async {
        let handler = createErrorHandler()
        handler.enableRateLimiting(maxErrorsPerMinute: 3)
        
        var rateLimitedErrors: [RealtimeError] = []
        handler.onErrorRateLimited = { error in
            rateLimitedErrors.append(error)
        }
        
        // Generate errors rapidly
        for i in 1...5 {
            await handler.handleError(RealtimeError.networkError("Error \(i)"))
        }
        
        #expect(rateLimitedErrors.count >= 2) // Should rate limit after 3 errors
    }
    
    // MARK: - Error Reporting Tests
    
    @Test("Error reporting to external service")
    func testErrorReportingToExternalService() async {
        let handler = createErrorHandler()
        
        var reportedErrors: [ErrorReport] = []
        handler.setErrorReporter { errorReport in
            reportedErrors.append(errorReport)
        }
        
        let error = RealtimeError.providerError("Critical failure", underlying: nil)
        await handler.handleError(error)
        
        #expect(reportedErrors.count == 1)
        #expect(reportedErrors.first?.error.localizedDescription == error.localizedDescription)
        #expect(reportedErrors.first?.timestamp != nil)
        #expect(reportedErrors.first?.severity == .critical)
    }
    
    @Test("Error context collection")
    func testErrorContextCollection() async {
        let handler = createErrorHandler()
        
        // Set up context providers
        handler.addContextProvider("device") {
            return ["model": "iPhone", "os": "iOS 17.0"]
        }
        
        handler.addContextProvider("network") {
            return ["type": "WiFi", "strength": "Strong"]
        }
        
        var reportedErrors: [ErrorReport] = []
        handler.setErrorReporter { errorReport in
            reportedErrors.append(errorReport)
        }
        
        await handler.handleError(RealtimeError.networkError("Connection failed"))
        
        #expect(reportedErrors.count == 1)
        
        let context = reportedErrors.first?.context
        #expect(context?["device"] as? [String: String] != nil)
        #expect(context?["network"] as? [String: String] != nil)
    }
    
    // MARK: - Error Filtering Tests
    
    @Test("Error filtering by severity")
    func testErrorFilteringBySeverity() async {
        let handler = createErrorHandler()
        handler.setMinimumSeverityLevel(.warning)
        
        var handledErrors: [RealtimeError] = []
        handler.onErrorHandled = { error in
            handledErrors.append(error)
        }
        
        // These should be handled
        await handler.handleError(RealtimeError.networkError("Warning level"))
        await handler.handleError(RealtimeError.authenticationFailed("Critical level"))
        
        // This should be filtered out
        await handler.handleError(RealtimeError.configurationWarning("Info level"))
        
        #expect(handledErrors.count == 2)
    }
    
    @Test("Error filtering by category")
    func testErrorFilteringByCategory() async {
        let handler = createErrorHandler()
        handler.setIgnoredCategories([.configuration])
        
        var handledErrors: [RealtimeError] = []
        handler.onErrorHandled = { error in
            handledErrors.append(error)
        }
        
        // These should be handled
        await handler.handleError(RealtimeError.networkError("Network issue"))
        await handler.handleError(RealtimeError.authenticationFailed("Auth issue"))
        
        // This should be filtered out
        await handler.handleError(RealtimeError.invalidConfiguration("Config issue"))
        
        #expect(handledErrors.count == 2)
    }
    
    // MARK: - Concurrent Error Handling Tests
    
    @Test("Concurrent error handling")
    func testConcurrentErrorHandling() async {
        let handler = createErrorHandler()
        
        var handledErrors: [RealtimeError] = []
        let lock = NSLock()
        
        handler.onErrorHandled = { error in
            lock.lock()
            handledErrors.append(error)
            lock.unlock()
        }
        
        // Handle multiple errors concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    await handler.handleError(RealtimeError.networkError("Error \(i)"))
                }
            }
        }
        
        #expect(handledErrors.count == 10)
        #expect(handler.errorCount == 10)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Error history cleanup")
    func testErrorHistoryCleanup() async {
        let handler = createErrorHandler()
        handler.setMaxHistorySize(5)
        
        // Generate more errors than history size
        for i in 1...10 {
            await handler.handleError(RealtimeError.networkError("Error \(i)"))
        }
        
        let history = handler.getErrorHistory()
        #expect(history.count <= 5)
        
        // Should contain the most recent errors
        #expect(history.last?.localizedDescription.contains("Error 10") == true)
    }
    
    @Test("Callback cleanup on deallocation")
    func testCallbackCleanupOnDeallocation() async {
        var handler: ErrorHandler? = createErrorHandler()
        
        weak var weakHandler = handler
        
        handler?.onErrorHandled = { _ in
            // This callback should be cleaned up
        }
        
        handler = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakHandler == nil)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Handle nil error")
    func testHandleNilError() async {
        let handler = createErrorHandler()
        
        // This should not crash
        await handler.handleError(nil)
        
        #expect(handler.errorCount == 0)
        #expect(handler.lastError == nil)
    }
    
    @Test("Handle error during recovery")
    func testHandleErrorDuringRecovery() async {
        let handler = createErrorHandler()
        handler.enableAutoRecovery(maxAttempts: 2, initialDelay: 0.1)
        
        // Start recovery for first error
        await handler.handleError(RealtimeError.networkError("First error"))
        
        #expect(handler.isRecoveryInProgress == true)
        
        // Handle another error during recovery
        await handler.handleError(RealtimeError.networkError("Second error"))
        
        #expect(handler.errorCount == 2)
    }
}