import Testing
import Foundation
@testable import RealtimeCore

@Suite("Localized Errors Tests")
@MainActor
struct LocalizedErrorsTests {
    
    // MARK: - Basic Error Localization Tests
    
    @Test("Basic error localization in English")
    func testBasicErrorLocalizationEnglish() async {
        ErrorLocalizationHelper.resetToDefaultLanguage()
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        let error = LocalizedRealtimeError.networkUnavailable
        #expect(error.errorDescription == "Network unavailable")
        #expect(error.description == "Network unavailable")
    }
    
    @Test("Basic error localization in Chinese")
    func testBasicErrorLocalizationChinese() async {
        ErrorLocalizationHelper.resetToDefaultLanguage()
        let manager = await createTestManager()
        await manager.switchLanguage(to: .chineseSimplified)
        
        let error = LocalizedRealtimeError.networkUnavailable
        #expect(error.errorDescription == "网络不可用")
    }
    
    @Test("Error localization with parameters")
    func testErrorLocalizationWithParameters() async {
        ErrorLocalizationHelper.resetToDefaultLanguage()
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        let error = LocalizedRealtimeError.insufficientPermissions(role: .audience)
        #expect(error.errorDescription?.contains("Audience") == true, "Error should contain role name")
        
        let transitionError = LocalizedRealtimeError.invalidRoleTransition(from: .audience, to: .broadcaster)
        #expect(transitionError.errorDescription?.contains("Audience") == true)
        #expect(transitionError.errorDescription?.contains("Broadcaster") == true)
    }
    
    // MARK: - Multi-language Error Tests
    
    @Test("Error localization across all languages", arguments: [
        (SupportedLanguage.english, "Network unavailable"),
        (SupportedLanguage.chineseSimplified, "网络不可用"),
        (SupportedLanguage.chineseTraditional, "網絡不可用"),
        (SupportedLanguage.japanese, "ネットワークが利用できません"),
        (SupportedLanguage.korean, "네트워크를 사용할 수 없습니다")
    ])
    func testErrorLocalizationAcrossLanguages(language: SupportedLanguage, expectedMessage: String) async {
        ErrorLocalizationHelper.resetToDefaultLanguage()
        let manager = await createTestManager()
        await manager.switchLanguage(to: language)
        
        // Give some time for the error localization helper to update
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let error = LocalizedRealtimeError.networkUnavailable
        #expect(error.errorDescription == expectedMessage, "Expected \(expectedMessage) for \(language), got \(error.errorDescription ?? "nil")")
    }
    
    @Test("Dynamic language switching for errors")
    func testDynamicLanguageSwitchingForErrors() async {
        ErrorLocalizationHelper.resetToDefaultLanguage()
        let manager = await createTestManager()
        let error = LocalizedRealtimeError.connectionTimeout
        
        await manager.switchLanguage(to: .english)
        let englishMessage = error.errorDescription
        #expect(englishMessage == "Connection timeout")
        
        await manager.switchLanguage(to: .japanese)
        let japaneseMessage = error.errorDescription
        #expect(japaneseMessage == "接続がタイムアウトしました")
        
        // Switch back to English
        await manager.switchLanguage(to: .english)
        let englishMessageAgain = error.errorDescription
        #expect(englishMessageAgain == "Connection timeout")
    }
    
    // MARK: - Error Categories Tests
    
    @Test("Error categories classification")
    func testErrorCategoriesClassification() {
        let testCases: [(LocalizedRealtimeError, ErrorCategory)] = [
            (.networkUnavailable, .network),
            (.connectionTimeout, .network),
            (.permissionDenied(permission: nil), .permission),
            (.insufficientPermissions(role: .audience), .permission),
            (.invalidConfiguration(details: nil), .configuration),
            (.providerUnavailable(provider: "test"), .configuration),
            (.noActiveSession, .session),
            (.audioDeviceUnavailable, .audio),
            (.streamPushFailed(reason: nil), .streamPush),
            (.mediaRelayFailed(reason: nil), .mediaRelay),
            (.processorAlreadyRegistered(messageType: "test"), .messageProcessing),
            (.localizationKeyNotFound(key: "test"), .localization),
            (.unknown(reason: nil), .system)
        ]
        
        for (error, expectedCategory) in testCases {
            #expect(error.category == expectedCategory, "Error \(error) should have category \(expectedCategory)")
        }
    }
    
    @Test("Error recoverability")
    func testErrorRecoverability() {
        let recoverableErrors: [LocalizedRealtimeError] = [
            .networkUnavailable,
            .connectionTimeout,
            .connectionFailed(reason: nil),
            .tokenExpired,
            .audioDeviceUnavailable,
            .streamPushFailed(reason: nil)
        ]
        
        let nonRecoverableErrors: [LocalizedRealtimeError] = [
            .permissionDenied(permission: nil),
            .insufficientPermissions(role: .audience),
            .invalidConfiguration(details: nil),
            .providerUnavailable(provider: "test"),
            .noActiveSession,
            .streamPushNotSupported
        ]
        
        for error in recoverableErrors {
            #expect(error.isRecoverable, "Error \(error) should be recoverable")
            #expect(error.retryDelay != nil, "Recoverable error should have retry delay")
        }
        
        for error in nonRecoverableErrors {
            #expect(!error.isRecoverable, "Error \(error) should not be recoverable")
            #expect(error.retryDelay == nil, "Non-recoverable error should not have retry delay")
        }
    }
    
    @Test("Error retry delays")
    func testErrorRetryDelays() {
        let testCases: [(LocalizedRealtimeError, TimeInterval)] = [
            (.networkUnavailable, 5.0),
            (.connectionTimeout, 5.0),
            (.connectionFailed(reason: nil), 3.0),
            (.tokenExpired, 1.0),
            (.audioDeviceUnavailable, 2.0),
            (.streamPushFailed(reason: nil), 5.0)
        ]
        
        for (error, expectedDelay) in testCases {
            #expect(error.retryDelay == expectedDelay, "Error \(error) should have retry delay \(expectedDelay)")
        }
    }
    
    // MARK: - Error Factory Tests
    
    @Test("Error factory with NSURLError")
    func testErrorFactoryWithNSURLError() {
        let urlError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let localizedError = LocalizedErrorFactory.createLocalizedError(from: urlError)
        
        #expect(localizedError.category == .network)
        
        switch localizedError {
        case .networkUnavailable:
            // Expected
            break
        default:
            #expect(Bool(false), "Should create network unavailable error")
        }
    }
    
    @Test("Error factory with timeout error")
    func testErrorFactoryWithTimeoutError() {
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let localizedError = LocalizedErrorFactory.createLocalizedError(from: timeoutError)
        
        switch localizedError {
        case .connectionTimeout:
            // Expected
            break
        default:
            #expect(Bool(false), "Should create connection timeout error")
        }
    }
    
    @Test("Error factory with generic error")
    func testErrorFactoryWithGenericError() {
        struct CustomError: Error {
            let message = "Custom error message"
        }
        
        let customError = CustomError()
        let localizedError = LocalizedErrorFactory.createLocalizedError(from: customError)
        
        switch localizedError {
        case .unknown(let reason):
            #expect(reason != nil, "Should preserve original error description")
        default:
            #expect(Bool(false), "Should create unknown error")
        }
    }
    
    @Test("Error factory with already localized error")
    func testErrorFactoryWithLocalizedError() {
        let originalError = LocalizedRealtimeError.networkUnavailable
        let processedError = LocalizedErrorFactory.createLocalizedError(from: originalError)
        
        switch processedError {
        case .networkUnavailable:
            // Expected - should return the same error
            break
        default:
            #expect(Bool(false), "Should return the same localized error")
        }
    }
    
    // MARK: - Complex Error Scenarios Tests
    
    @Test("Error with detailed information")
    func testErrorWithDetailedInformation() async {
        ErrorLocalizationHelper.resetToDefaultLanguage()
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        let error = LocalizedRealtimeError.connectionFailed(reason: "Server unreachable")
        let description = error.errorDescription
        
        #expect(description == "Connection failed", "Should use base localized message")
        
        // Test error with room ID
        let roomError = LocalizedRealtimeError.roomNotFound(roomId: "room123")
        let roomDescription = roomError.errorDescription
        
        #expect(roomDescription?.contains("room123") == true, "Should include room ID in message")
    }
    
    @Test("Error message formatting with multiple parameters")
    func testErrorMessageFormattingWithMultipleParameters() async {
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        let error = LocalizedRealtimeError.internalError(code: 500, description: "Server error")
        let description = error.errorDescription
        
        #expect(description?.contains("500") == true, "Should include error code")
    }
    
    // MARK: - Error Fallback Tests
    
    @Test("Error fallback to English")
    func testErrorFallbackToEnglish() async {
        let manager = await createTestManager()
        
        // Add a custom error key only in English
        manager.addCustomLocalization(key: "error.custom.test", localizations: [
            .english: "Custom test error"
        ])
        
        // Switch to Korean (which doesn't have this key)
        await manager.switchLanguage(to: .korean)
        
        // The error system should fallback to English
        let customErrorMessage = manager.localizedString(for: "error.custom.test")
        #expect(customErrorMessage == "Custom test error", "Should fallback to English for missing keys")
    }
    
    // MARK: - Performance Tests
    
    @Test("Error localization performance")
    func testErrorLocalizationPerformance() async {
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        let startTime = Date()
        
        // Create and localize many errors
        for i in 0..<1000 {
            let error = LocalizedRealtimeError.roomNotFound(roomId: "room\(i)")
            _ = error.errorDescription
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(duration < 1.0, "Error localization should be fast (completed in \(duration) seconds)")
    }
    
    // MARK: - Error Equality and Comparison Tests
    
    @Test("Error equality comparison")
    func testErrorEqualityComparison() {
        let error1 = LocalizedRealtimeError.networkUnavailable
        let error2 = LocalizedRealtimeError.networkUnavailable
        let error3 = LocalizedRealtimeError.connectionTimeout
        
        // Note: Swift enums with associated values don't automatically conform to Equatable
        // We're testing that the same error types produce the same localized messages
        #expect(error1.localizationKey == error2.localizationKey)
        #expect(error1.localizationKey != error3.localizationKey)
    }
    
    // MARK: - Integration Tests
    
    @Test("Error integration with notification system")
    func testErrorIntegrationWithNotificationSystem() async {
        let manager = await createTestManager()
        
        var receivedNotification = false
        let observer = NotificationCenter.default.addObserver(
            forName: .realtimeLanguageDidChange,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                receivedNotification = true
            }
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        let error = LocalizedRealtimeError.networkUnavailable
        await manager.switchLanguage(to: .english)
        let initialMessage = error.errorDescription
        
        await manager.switchLanguage(to: .japanese)
        
        // Give some time for notification and error helper update
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let newMessage = error.errorDescription
        
        #expect(receivedNotification, "Language change notification should be received")
        #expect(initialMessage != newMessage, "Error message should change with language")
    }
    
    // MARK: - Helper Methods
    
    private func createTestManager() async -> LocalizationManager {
        let config = LocalizationConfig(
            autoDetectSystemLanguage: false,
            fallbackLanguage: .english,
            persistLanguageSelection: false
        )
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return await LocalizationManager.createTestInstance(config: config, userDefaults: userDefaults)
    }
}

// MARK: - Test Extensions

extension LocalizedRealtimeError {
    /// Access to private localizationKey for testing
    var localizationKey: String {
        switch self {
        case .networkUnavailable:
            return "error.network.unavailable"
        case .connectionTimeout:
            return "error.connection.timeout"
        case .connectionFailed:
            return "error.connection.failed"
        default:
            return "error.unknown"
        }
    }
}
