// TokenManagerTests.swift
// Unit tests for TokenManager

import Testing
import Foundation
@testable import RealtimeCore

@MainActor
struct TokenManagerTests {
    
    // MARK: - Test Setup
    
    private func createTokenManager() -> TokenManager {
        let config = TokenRenewalSchedulerConfig(
            renewalAdvanceTime: 5.0, // 5 seconds for faster testing
            checkInterval: 1.0,      // 1 second for faster testing
            maxConcurrentRenewals: 2,
            enablePeriodicCheck: true
        )
        return TokenManager(schedulerConfig: config)
    }
    
    private func createMockToken(expiresIn: TimeInterval = 60.0) -> (String, Date) {
        let token = "mock_token_\(UUID().uuidString)"
        let expirationTime = Date().addingTimeInterval(expiresIn)
        return (token, expirationTime)
    }
    
    // MARK: - Basic Token Management Tests
    
    @Test("Token Manager Initialization")
    func testTokenManagerInitialization() async throws {
        let tokenManager = createTokenManager()
        
        #expect(tokenManager.tokenInfos.isEmpty)
        #expect(tokenManager.renewalStates.isEmpty)
        #expect(tokenManager.renewalStats.isEmpty)
        #expect(tokenManager.activeProviders.isEmpty)
        #expect(tokenManager.expiredProviders.isEmpty)
    }
    
    @Test("Set and Get Token")
    func testSetAndGetToken() async throws {
        let tokenManager = createTokenManager()
        let (token, expirationTime) = createMockToken()
        let provider = ProviderType.agora
        
        tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        
        let retrievedToken = tokenManager.getToken(for: provider)
        #expect(retrievedToken?.token == token)
        #expect(retrievedToken?.provider == provider)
        #expect(retrievedToken?.expirationTime == expirationTime)
        #expect(tokenManager.isTokenValid(for: provider) == true)
    }
    
    @Test("Token Expiration Detection")
    func testTokenExpirationDetection() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        
        // Set expired token
        let expiredToken = "expired_token"
        let expiredTime = Date().addingTimeInterval(-10) // 10 seconds ago
        tokenManager.setToken(expiredToken, expirationTime: expiredTime, for: provider)
        
        #expect(tokenManager.isTokenValid(for: provider) == false)
        #expect(tokenManager.expiredProviders.contains(provider))
        #expect(!tokenManager.activeProviders.contains(provider))
        
        let tokenInfo = tokenManager.getToken(for: provider)
        #expect(tokenInfo?.isExpired == true)
        #expect(tokenInfo?.willExpireSoon == true)
    }
    
    @Test("Multiple Provider Token Management")
    func testMultipleProviderTokenManagement() async throws {
        let tokenManager = createTokenManager()
        
        let providers: [ProviderType] = [.agora, .tencent, .zego]
        var tokens: [ProviderType: (String, Date)] = [:]
        
        // Set tokens for multiple providers
        for provider in providers {
            let (token, expirationTime) = createMockToken()
            tokens[provider] = (token, expirationTime)
            tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        }
        
        // Verify all tokens are set correctly
        for provider in providers {
            let retrievedToken = tokenManager.getToken(for: provider)
            let expectedToken = tokens[provider]!
            
            #expect(retrievedToken?.token == expectedToken.0)
            #expect(retrievedToken?.expirationTime == expectedToken.1)
            #expect(tokenManager.isTokenValid(for: provider) == true)
        }
        
        #expect(tokenManager.activeProviders.count == providers.count)
        #expect(tokenManager.expiredProviders.isEmpty)
    }
    
    // MARK: - Token Renewal Tests
    
    @Test("Token Renewal Handler Registration")
    func testTokenRenewalHandlerRegistration() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        var renewalCalled = false
        
        // Register renewal handler
        tokenManager.registerTokenRenewalHandler(for: provider) {
            renewalCalled = true
            return "new_token_\(UUID().uuidString)"
        }
        
        // Set initial token
        let (token, expirationTime) = createMockToken()
        tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        
        // Manually trigger renewal
        try await tokenManager.renewToken(for: provider)
        
        #expect(renewalCalled == true)
        #expect(tokenManager.renewalStates[provider] == .completed)
        
        // Verify token was updated
        let newToken = tokenManager.getToken(for: provider)
        #expect(newToken?.token != token) // Should be different from original
    }
    
    @Test("Token Renewal Failure Handling")
    func testTokenRenewalFailureHandling() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        
        // Register failing renewal handler
        tokenManager.registerTokenRenewalHandler(for: provider) {
            throw RealtimeError.networkError("Simulated network failure")
        }
        
        // Set initial token
        let (token, expirationTime) = createMockToken()
        tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        
        // Attempt renewal (should fail)
        do {
            try await tokenManager.renewToken(for: provider)
            #expect(Bool(false), "Expected renewal to fail")
        } catch {
            #expect(error is RealtimeError)
            #expect(tokenManager.renewalStates[provider] == .failed)
        }
        
        // Verify statistics
        let stats = tokenManager.getRenewalStats(for: provider)
        #expect(stats?.totalRenewals == 1)
        #expect(stats?.failedRenewals == 1)
        #expect(stats?.successfulRenewals == 0)
    }
    
    @Test("Token Renewal Retry Logic")
    func testTokenRenewalRetryLogic() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        var attemptCount = 0
        
        // Register handler that fails first few times
        tokenManager.registerTokenRenewalHandler(for: provider) {
            attemptCount += 1
            if attemptCount < 3 {
                throw RealtimeError.networkError("Temporary failure")
            }
            return "success_token_\(UUID().uuidString)"
        }
        
        // Set initial token
        let (token, expirationTime) = createMockToken()
        tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        
        // Attempt renewal (should succeed after retries)
        try await tokenManager.renewToken(for: provider)
        
        #expect(attemptCount == 3) // Should have retried 3 times
        #expect(tokenManager.renewalStates[provider] == .completed)
        
        // Verify statistics include retry attempts
        let stats = tokenManager.getRenewalStats(for: provider)
        #expect(stats?.totalRenewals == 1)
        #expect(stats?.successfulRenewals == 1)
        #expect(stats?.retryAttempts == 2) // 2 retries before success
    }
    
    // MARK: - Token Expiration Notification Tests
    
    @Test("Token Expiration Handler Registration")
    func testTokenExpirationHandlerRegistration() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        var expirationNotified = false
        var notifiedProvider: ProviderType?
        var notifiedExpiresIn: Int?
        
        // Register expiration handler
        tokenManager.registerTokenExpirationHandler(for: provider) { provider, expiresIn in
            expirationNotified = true
            notifiedProvider = provider
            notifiedExpiresIn = expiresIn
        }
        
        // Simulate expiration notification
        await tokenManager.handleTokenExpiration(provider: provider, expiresIn: 30)
        
        #expect(expirationNotified == true)
        #expect(notifiedProvider == provider)
        #expect(notifiedExpiresIn == 30)
    }
    
    @Test("Automatic Token Renewal on Expiration")
    func testAutomaticTokenRenewalOnExpiration() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        var renewalCalled = false
        
        // Register renewal handler
        tokenManager.registerTokenRenewalHandler(for: provider) {
            renewalCalled = true
            return "auto_renewed_token_\(UUID().uuidString)"
        }
        
        // Set initial token
        let (token, expirationTime) = createMockToken()
        tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        
        // Simulate expiration notification that should trigger auto-renewal
        await tokenManager.handleTokenExpiration(provider: provider, expiresIn: 25) // Less than 30 seconds
        
        #expect(renewalCalled == true)
        #expect(tokenManager.renewalStates[provider] == .completed)
    }
    
    // MARK: - Token Removal Tests
    
    @Test("Token Removal")
    func testTokenRemoval() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        
        // Set initial token
        let (token, expirationTime) = createMockToken()
        tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        
        #expect(tokenManager.getToken(for: provider) != nil)
        
        // Remove token
        tokenManager.removeToken(for: provider)
        
        #expect(tokenManager.getToken(for: provider) == nil)
        #expect(tokenManager.renewalStates[provider] == nil)
        #expect(!tokenManager.activeProviders.contains(provider))
    }
    
    @Test("Clear All Tokens")
    func testClearAllTokens() async throws {
        let tokenManager = createTokenManager()
        let providers: [ProviderType] = [.agora, .tencent, .zego]
        
        // Set tokens for multiple providers
        for provider in providers {
            let (token, expirationTime) = createMockToken()
            tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        }
        
        #expect(tokenManager.tokenInfos.count == providers.count)
        
        // Clear all tokens
        tokenManager.clearAllTokens()
        
        #expect(tokenManager.tokenInfos.isEmpty)
        #expect(tokenManager.renewalStates.isEmpty)
        #expect(tokenManager.activeProviders.isEmpty)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Renewal Statistics Tracking")
    func testRenewalStatisticsTracking() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        var renewalCount = 0
        
        // Register renewal handler
        tokenManager.registerTokenRenewalHandler(for: provider) {
            renewalCount += 1
            return "renewed_token_\(renewalCount)"
        }
        
        // Set initial token
        let (token, expirationTime) = createMockToken()
        tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        
        // Perform multiple renewals
        try await tokenManager.renewToken(for: provider)
        try await tokenManager.renewToken(for: provider)
        try await tokenManager.renewToken(for: provider)
        
        let stats = tokenManager.getRenewalStats(for: provider)
        #expect(stats?.totalRenewals == 3)
        #expect(stats?.successfulRenewals == 3)
        #expect(stats?.failedRenewals == 0)
        #expect(stats?.successRate == 1.0)
        #expect(stats?.lastRenewalTime != nil)
    }
    
    @Test("Overall Success Rate Calculation")
    func testOverallSuccessRateCalculation() async throws {
        let tokenManager = createTokenManager()
        let providers: [ProviderType] = [.agora, .tencent]
        
        // Register handlers for both providers
        for provider in providers {
            tokenManager.registerTokenRenewalHandler(for: provider) {
                return "renewed_token_\(UUID().uuidString)"
            }
            
            let (token, expirationTime) = createMockToken()
            tokenManager.setToken(token, expirationTime: expirationTime, for: provider)
        }
        
        // Perform renewals
        try await tokenManager.renewToken(for: .agora)
        try await tokenManager.renewToken(for: .tencent)
        
        #expect(tokenManager.overallSuccessRate == 1.0)
        
        // Add a failing provider
        tokenManager.registerTokenRenewalHandler(for: .zego) {
            throw RealtimeError.networkError("Failure")
        }
        
        let (token, expirationTime) = createMockToken()
        tokenManager.setToken(token, expirationTime: expirationTime, for: .zego)
        
        do {
            try await tokenManager.renewToken(for: .zego)
        } catch {
            // Expected to fail
        }
        
        // Success rate should now be 2/3 = 0.67 (approximately)
        let successRate = tokenManager.overallSuccessRate
        #expect(successRate > 0.6 && successRate < 0.7)
    }
    
    // MARK: - Scheduler Integration Tests
    
    @Test("Token Renewal Scheduler Integration")
    func testTokenRenewalSchedulerIntegration() async throws {
        let tokenManager = createTokenManager()
        let provider = ProviderType.agora
        var renewalCalled = false
        
        // Register renewal handler
        tokenManager.registerTokenRenewalHandler(for: provider) {
            renewalCalled = true
            return "scheduled_renewed_token"
        }
        
        // Set token that expires soon (within scheduler's advance time)
        let shortExpirationTime = Date().addingTimeInterval(3.0) // 3 seconds
        tokenManager.setToken("short_lived_token", expirationTime: shortExpirationTime, for: provider)
        
        // Wait for scheduler to trigger renewal
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
        
        #expect(renewalCalled == true)
        #expect(tokenManager.renewalStates[provider] == .completed)
    }
    
    @Test("Scheduler Concurrent Renewal Limit")
    func testSchedulerConcurrentRenewalLimit() async throws {
        let config = TokenRenewalSchedulerConfig(
            renewalAdvanceTime: 2.0,
            checkInterval: 0.5,
            maxConcurrentRenewals: 1, // Limit to 1 concurrent renewal
            enablePeriodicCheck: true
        )
        let tokenManager = TokenManager(schedulerConfig: config)
        
        let providers: [ProviderType] = [.agora, .tencent, .zego]
        var renewalOrder: [ProviderType] = []
        
        // Register renewal handlers that track order
        for provider in providers {
            tokenManager.registerTokenRenewalHandler(for: provider) {
                renewalOrder.append(provider)
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                return "renewed_token_\(provider)"
            }
            
            // Set tokens that expire soon
            let expirationTime = Date().addingTimeInterval(1.0)
            tokenManager.setToken("token_\(provider)", expirationTime: expirationTime, for: provider)
        }
        
        // Wait for renewals to complete
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // Should have renewed all tokens, but not concurrently
        #expect(renewalOrder.count == providers.count)
        
        // Verify all renewals completed
        for provider in providers {
            #expect(tokenManager.renewalStates[provider] == .completed)
        }
    }
}

// MARK: - Token Renewal Scheduler Tests

@MainActor
struct TokenRenewalSchedulerTests {
    
    @Test("Scheduler Initialization and Lifecycle")
    func testSchedulerInitializationAndLifecycle() async throws {
        let config = TokenRenewalSchedulerConfig(
            renewalAdvanceTime: 10.0,
            checkInterval: 2.0,
            maxConcurrentRenewals: 3,
            enablePeriodicCheck: true
        )
        let scheduler = TokenRenewalScheduler(config: config)
        let tokenManager = TokenManager()
        
        #expect(scheduler.isRunning == false)
        #expect(scheduler.activeRenewals.isEmpty)
        #expect(scheduler.scheduledRenewals.isEmpty)
        
        scheduler.start(with: tokenManager)
        #expect(scheduler.isRunning == true)
        
        scheduler.stop()
        #expect(scheduler.isRunning == false)
    }
    
    @Test("Schedule and Cancel Renewal")
    func testScheduleAndCancelRenewal() async throws {
        let scheduler = TokenRenewalScheduler()
        let tokenManager = TokenManager()
        let provider = ProviderType.agora
        let renewalTime = Date().addingTimeInterval(60) // 1 minute from now
        
        scheduler.start(with: tokenManager)
        
        scheduler.scheduleRenewal(for: provider, at: renewalTime)
        #expect(scheduler.scheduledRenewals[provider] == renewalTime)
        
        scheduler.cancelScheduledRenewal(for: provider)
        #expect(scheduler.scheduledRenewals[provider] == nil)
        
        scheduler.stop()
    }
}