//
//  TokenManagerTests.swift
//  RealtimeCoreTests
//
//  Created by RealtimeKit on 2024/12/25.
//

import Testing
import Foundation
@testable import RealtimeCore

/// Token 管理器测试套件
/// 测试需求 9.1, 9.2, 9.3, 9.4, 9.5
@Suite("Token Management Tests")
struct TokenManagerTests {
    
    // MARK: - Token 自动续期测试 (需求 9.1, 9.2)
    
    @Test("Token 自动续期基础功能测试")
    func testTokenAutoRenewal() async throws {
        let tokenManager = await TokenManager()
        
        // 使用 actor 来处理并发状态
        actor TestState {
            var renewalCalled = false
            var renewedToken: String?
            
            func markRenewalCalled(token: String) {
                renewalCalled = true
                renewedToken = token
            }
            
            func getRenewalState() -> (called: Bool, token: String?) {
                return (renewalCalled, renewedToken)
            }
        }
        
        let testState = TestState()
        
        // 设置续期回调 (需求 9.2)
        await tokenManager.setupTokenRenewal(provider: .mock) {
            await testState.markRenewalCalled(token: "new_token_123")
            return "new_token_123"
        }
        
        // 模拟 Token 即将过期 (需求 9.1)
        await tokenManager.handleTokenExpiration(provider: .mock, expiresIn: 2, advanceTime: 1)
        
        // 等待续期完成
        try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5秒
        
        // 验证续期逻辑被调用
        let (renewalCalled, renewedToken) = await testState.getRenewalState()
        #expect(renewalCalled, "Token 续期处理器应该被调用")
        #expect(renewedToken == "new_token_123", "应该返回正确的新 Token")
        
        // 验证 Token 状态
        let tokenState = await tokenManager.getTokenState(for: .mock)
        #expect(tokenState != nil, "应该存在 Token 状态")
        #expect(tokenState?.status == .active, "Token 状态应该为活跃")
        
        await tokenManager.cleanup()
    }
    
    @Test("Token 过期时间配置测试")
    func testTokenExpirationTiming() async throws {
        let tokenManager = await TokenManager()
        
        actor TimestampTracker {
            var renewalTimestamp: Date?
            
            func recordRenewal() {
                renewalTimestamp = Date()
            }
            
            func getTimestamp() -> Date? {
                return renewalTimestamp
            }
        }
        
        let tracker = TimestampTracker()
        
        await tokenManager.setupTokenRenewal(provider: .agora) {
            await tracker.recordRenewal()
            return "renewed_token"
        }
        
        let startTime = Date()
        
        // 设置 10 秒后过期，提前 2 秒续期
        await tokenManager.handleTokenExpiration(provider: .agora, expiresIn: 10, advanceTime: 2)
        
        // 等待续期触发
        try await Task.sleep(nanoseconds: 9_000_000_000) // 9秒
        
        if let renewalTime = await tracker.getTimestamp() {
            let timeDiff = renewalTime.timeIntervalSince(startTime)
            // 应该在 8 秒左右触发续期（10 - 2 = 8）
            #expect(timeDiff >= 7.5 && timeDiff <= 9.0, "续期应该在正确的时间触发")
        } else {
            #expect(Bool(false), "续期应该被触发")
        }
        
        await tokenManager.cleanup()
    }
    
    // MARK: - Token 续期失败重试测试 (需求 9.4)
    
    @Test("Token 续期失败重试机制测试")
    func testTokenRenewalRetry() async throws {
        let tokenManager = await TokenManager()
        
        actor AttemptCounter {
            var attemptCount = 0
            
            func increment() -> Int {
                attemptCount += 1
                return attemptCount
            }
            
            func getCount() -> Int {
                return attemptCount
            }
        }
        
        let counter = AttemptCounter()
        
        // 配置重试策略
        let retryConfig = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 0.1, // 快速重试用于测试
            maxDelay: 1.0,
            backoffMultiplier: 2.0
        )
        await tokenManager.configureRetryStrategy(for: .agora, configuration: retryConfig)
        
        await tokenManager.setupTokenRenewal(provider: .agora) {
            let count = await counter.increment()
            if count < 3 {
                throw TokenError.renewalFailed("Test error")
            }
            return "success_token"
        }
        
        // 立即执行续期以触发重试
        await tokenManager.renewTokenImmediately(provider: .agora)
        
        // 等待重试完成
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        // 验证重试机制 (需求 9.4)
        let finalCount = await counter.getCount()
        #expect(finalCount == 3, "应该重试 3 次")
        
        let tokenState = await tokenManager.getTokenState(for: .agora)
        #expect(tokenState?.status == .active, "最终应该续期成功")
        
        await tokenManager.cleanup()
    }
    
    @Test("Token 续期指数退避测试")
    func testTokenRenewalExponentialBackoff() async throws {
        let tokenManager = await TokenManager()
        
        actor TimeTracker {
            var attemptTimes: [Date] = []
            
            func recordAttempt() {
                attemptTimes.append(Date())
            }
            
            func getTimes() -> [Date] {
                return attemptTimes
            }
        }
        
        let tracker = TimeTracker()
        
        let retryConfig = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            backoffMultiplier: 2.0
        )
        await tokenManager.configureRetryStrategy(for: .zego, configuration: retryConfig)
        
        await tokenManager.setupTokenRenewal(provider: .zego) {
            await tracker.recordAttempt()
            throw TokenError.renewalFailed("Test error")
        }
        
        await tokenManager.renewTokenImmediately(provider: .zego)
        
        // 等待所有重试完成
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
        
        let attemptTimes = await tracker.getTimes()
        #expect(attemptTimes.count == 3, "应该有 3 次尝试")
        
        if attemptTimes.count >= 2 {
            let firstDelay = attemptTimes[1].timeIntervalSince(attemptTimes[0])
            #expect(firstDelay >= 0.1 && firstDelay <= 0.3, "第一次重试延迟应该约为 0.1 秒")
        }
        
        if attemptTimes.count >= 3 {
            let secondDelay = attemptTimes[2].timeIntervalSince(attemptTimes[1])
            #expect(secondDelay >= 0.2 && secondDelay <= 0.5, "第二次重试延迟应该约为 0.2 秒")
        }
        
        await tokenManager.cleanup()
    }
    
    // MARK: - 多服务商 Token 管理测试 (需求 9.5)
    
    @Test("多服务商独立 Token 管理测试")
    func testMultiProviderTokenManagement() async throws {
        let tokenManager = await TokenManager()
        
        actor RenewalCounter {
            var agoraRenewalCount = 0
            var tencentRenewalCount = 0
            
            func incrementAgora() -> Int {
                agoraRenewalCount += 1
                return agoraRenewalCount
            }
            
            func incrementTencent() -> Int {
                tencentRenewalCount += 1
                return tencentRenewalCount
            }
            
            func getCounts() -> (agora: Int, tencent: Int) {
                return (agoraRenewalCount, tencentRenewalCount)
            }
        }
        
        let counter = RenewalCounter()
        
        // 设置 Agora 续期处理器
        await tokenManager.setupTokenRenewal(provider: .agora) {
            let count = await counter.incrementAgora()
            return "agora_token_\(count)"
        }
        
        // 设置腾讯云续期处理器
        await tokenManager.setupTokenRenewal(provider: .tencent) {
            let count = await counter.incrementTencent()
            return "tencent_token_\(count)"
        }
        
        // 同时触发两个服务商的 Token 过期
        await tokenManager.handleTokenExpiration(provider: .agora, expiresIn: 2, advanceTime: 1)
        await tokenManager.handleTokenExpiration(provider: .tencent, expiresIn: 3, advanceTime: 1)
        
        // 等待续期完成
        try await Task.sleep(nanoseconds: 4_000_000_000) // 4秒
        
        // 验证独立管理 (需求 9.5)
        let (agoraCount, tencentCount) = await counter.getCounts()
        #expect(agoraCount == 1, "Agora Token 应该续期一次")
        #expect(tencentCount == 1, "腾讯云 Token 应该续期一次")
        
        let agoraState = await tokenManager.getTokenState(for: .agora)
        let tencentState = await tokenManager.getTokenState(for: .tencent)
        
        #expect(agoraState?.status == .active, "Agora Token 状态应该为活跃")
        #expect(tencentState?.status == .active, "腾讯云 Token 状态应该为活跃")
        
        await tokenManager.cleanup()
    }
    
    @Test("Token 状态管理测试")
    func testTokenStateManagement() async throws {
        let tokenManager = await TokenManager()
        
        // 初始状态
        var tokenState = await tokenManager.getTokenState(for: .mock)
        #expect(tokenState == nil, "初始状态应该为空")
        
        // 设置续期处理器后
        await tokenManager.setupTokenRenewal(provider: .mock) {
            return "test_token"
        }
        
        tokenState = await tokenManager.getTokenState(for: .mock)
        #expect(tokenState != nil, "设置处理器后应该有状态")
        #expect(tokenState?.status == .unknown, "初始状态应该为未知")
        
        // 处理过期事件后
        await tokenManager.handleTokenExpiration(provider: .mock, expiresIn: 60)
        
        tokenState = await tokenManager.getTokenState(for: .mock)
        #expect(tokenState?.status == .active, "处理过期事件后状态应该为活跃")
        #expect(tokenState?.expirationTime != nil, "应该设置过期时间")
        
        await tokenManager.cleanup()
    }
    
    // MARK: - Token 续期统计测试
    
    @Test("Token 续期统计信息测试")
    func testTokenRenewalStats() async throws {
        let tokenManager = await TokenManager()
        
        // 初始统计
        var stats = await tokenManager.renewalStats
        #expect(stats.totalAttempts == 0, "初始尝试次数应该为 0")
        #expect(stats.totalSuccesses == 0, "初始成功次数应该为 0")
        #expect(stats.totalFailures == 0, "初始失败次数应该为 0")
        #expect(stats.successRate == 0.0, "初始成功率应该为 0")
        
        // 设置成功的续期处理器
        await tokenManager.setupTokenRenewal(provider: .mock) {
            return "success_token"
        }
        
        // 执行续期
        await tokenManager.renewTokenImmediately(provider: .mock)
        
        // 等待完成
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        stats = await tokenManager.renewalStats
        #expect(stats.totalAttempts == 1, "应该有 1 次尝试")
        #expect(stats.totalSuccesses == 1, "应该有 1 次成功")
        #expect(stats.successRate == 1.0, "成功率应该为 100%")
        
        await tokenManager.cleanup()
    }
    
    // MARK: - 错误处理测试
    
    @Test("Token 续期错误处理测试")
    func testTokenRenewalErrorHandling() async throws {
        let tokenManager = await TokenManager()
        
        // 测试没有续期处理器的情况
        await tokenManager.handleTokenExpiration(provider: .mock, expiresIn: 1, advanceTime: 0)
        
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
        
        let tokenState = await tokenManager.getTokenState(for: .mock)
        #expect(tokenState == nil, "没有处理器时不应该有状态")
        
        // 测试续期失败的情况
        await tokenManager.setupTokenRenewal(provider: .mock) {
            throw TokenError.invalidToken
        }
        
        await tokenManager.renewTokenImmediately(provider: .mock)
        
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        let failedState = await tokenManager.getTokenState(for: .mock)
        #expect(failedState?.status == .failed, "续期失败时状态应该为失败")
        #expect(failedState?.lastError != nil, "应该记录错误信息")
        
        await tokenManager.cleanup()
    }
    
    // MARK: - 清理和资源管理测试
    
    @Test("Token 管理器清理测试")
    func testTokenManagerCleanup() async throws {
        let tokenManager = await TokenManager()
        
        // 设置多个服务商
        await tokenManager.setupTokenRenewal(provider: .agora) { "agora_token" }
        await tokenManager.setupTokenRenewal(provider: .tencent) { "tencent_token" }
        
        // 触发过期事件创建定时器
        await tokenManager.handleTokenExpiration(provider: .agora, expiresIn: 60)
        await tokenManager.handleTokenExpiration(provider: .tencent, expiresIn: 60)
        
        // 验证状态存在
        #expect(await tokenManager.getTokenState(for: .agora) != nil, "清理前应该有 Agora 状态")
        #expect(await tokenManager.getTokenState(for: .tencent) != nil, "清理前应该有腾讯云状态")
        
        // 执行清理
        await tokenManager.cleanup()
        
        // 验证清理结果
        #expect(await tokenManager.getTokenState(for: .agora) == nil, "清理后不应该有 Agora 状态")
        #expect(await tokenManager.getTokenState(for: .tencent) == nil, "清理后不应该有腾讯云状态")
    }
    
    @Test("Token 处理器清除测试")
    func testTokenHandlerClearance() async throws {
        let tokenManager = await TokenManager()
        
        await tokenManager.setupTokenRenewal(provider: .mock) { "test_token" }
        
        // 验证处理器存在
        #expect(await tokenManager.getTokenState(for: .mock) != nil, "应该有 Token 状态")
        
        // 清除特定服务商的处理器
        await tokenManager.clearTokenRenewalHandler(for: .mock)
        
        // 验证清除结果
        #expect(await tokenManager.getTokenState(for: .mock) == nil, "清除后不应该有状态")
        
        await tokenManager.cleanup()
    }
}

// MARK: - 重试配置测试

@Suite("Retry Configuration Tests")
struct RetryConfigurationTests {
    
    @Test("重试配置默认值测试")
    func testRetryConfigurationDefaults() {
        let config = RetryConfiguration.default
        
        #expect(config.maxRetries == 3, "默认最大重试次数应该为 3")
        #expect(config.baseDelay == 1.0, "默认基础延迟应该为 1.0 秒")
        #expect(config.maxDelay == 30.0, "默认最大延迟应该为 30.0 秒")
        #expect(config.backoffMultiplier == 2.0, "默认退避倍数应该为 2.0")
    }
    
    @Test("指数退避延迟计算测试", arguments: [
        (1, 1.0),   // 第一次重试: 1.0 * 2^0 = 1.0
        (2, 2.0),   // 第二次重试: 1.0 * 2^1 = 2.0
        (3, 4.0),   // 第三次重试: 1.0 * 2^2 = 4.0
        (4, 8.0),   // 第四次重试: 1.0 * 2^3 = 8.0
    ])
    func testExponentialBackoffCalculation(attempt: Int, expectedDelay: TimeInterval) {
        let config = RetryConfiguration(
            maxRetries: 5,
            baseDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0
        )
        
        let actualDelay = config.calculateDelay(attempt: attempt)
        #expect(actualDelay == expectedDelay, "第 \(attempt) 次重试延迟应该为 \(expectedDelay) 秒")
    }
    
    @Test("最大延迟限制测试")
    func testMaxDelayLimit() {
        let config = RetryConfiguration(
            maxRetries: 10,
            baseDelay: 1.0,
            maxDelay: 5.0,  // 最大延迟限制为 5 秒
            backoffMultiplier: 2.0
        )
        
        // 第 5 次重试理论上应该是 1.0 * 2^4 = 16.0 秒
        // 但应该被限制在 5.0 秒
        let delay = config.calculateDelay(attempt: 5)
        #expect(delay == 5.0, "延迟应该被限制在最大值")
    }
    
    @Test("自定义重试配置测试")
    func testCustomRetryConfiguration() {
        let config = RetryConfiguration(
            maxRetries: 5,
            baseDelay: 0.5,
            maxDelay: 10.0,
            backoffMultiplier: 1.5
        )
        
        #expect(config.maxRetries == 5, "自定义最大重试次数")
        #expect(config.baseDelay == 0.5, "自定义基础延迟")
        #expect(config.maxDelay == 10.0, "自定义最大延迟")
        #expect(config.backoffMultiplier == 1.5, "自定义退避倍数")
        
        let firstRetryDelay = config.calculateDelay(attempt: 1)
        #expect(firstRetryDelay == 0.5, "第一次重试延迟应该等于基础延迟")
        
        let secondRetryDelay = config.calculateDelay(attempt: 2)
        #expect(secondRetryDelay == 0.75, "第二次重试延迟: 0.5 * 1.5 = 0.75")
    }
}

// MARK: - Token 状态测试

@Suite("Token State Tests")
struct TokenStateTests {
    
    @Test("Token 状态初始化测试")
    func testTokenStateInitialization() {
        let state = TokenState(provider: .agora)
        
        #expect(state.provider == .agora, "服务商类型应该正确")
        #expect(state.status == .unknown, "初始状态应该为未知")
        #expect(state.lastRenewalTime == nil, "初始续期时间应该为空")
        #expect(state.expirationTime == nil, "初始过期时间应该为空")
        #expect(state.renewalAttempts == 0, "初始续期尝试次数应该为 0")
        #expect(state.lastError == nil, "初始错误应该为空")
    }
    
    @Test("Token 状态更新测试")
    func testTokenStateUpdates() {
        let initialState = TokenState(provider: .mock)
        
        // 测试过期时间更新
        let expiredState = initialState.updateExpiration(expiresIn: 3600)
        #expect(expiredState.status == .active, "设置过期时间后状态应该为活跃")
        #expect(expiredState.expirationTime != nil, "应该设置过期时间")
        
        // 测试续期开始
        let renewingState = expiredState.startRenewal()
        #expect(renewingState.status == .renewing, "开始续期时状态应该为续期中")
        #expect(renewingState.renewalAttempts == 1, "续期尝试次数应该增加")
        
        // 测试续期成功
        let successState = renewingState.markRenewalSuccess(newToken: "new_token")
        #expect(successState.status == .active, "续期成功后状态应该为活跃")
        #expect(successState.lastRenewalTime != nil, "应该记录续期时间")
        #expect(successState.lastError == nil, "成功后错误应该被清除")
        
        // 测试续期失败
        let testError = TokenError.invalidToken
        let failedState = successState.markRenewalFailed(error: testError)
        #expect(failedState.status == .failed, "续期失败后状态应该为失败")
        #expect(failedState.lastError != nil, "应该记录错误信息")
    }
}

// MARK: - Token 错误测试

@Suite("Token Error Tests")
struct TokenErrorTests {
    
    @Test("Token 错误类型测试")
    func testTokenErrorTypes() {
        let noHandlerError = TokenError.noRenewalHandler
        #expect(noHandlerError.errorDescription?.contains("未设置") == true, "应该包含正确的错误描述")
        
        let renewalError = TokenError.renewalFailed("Test error")
        #expect(renewalError.errorDescription?.contains("续期失败") == true, "应该包含续期失败描述")
        
        let expiredError = TokenError.tokenExpired
        #expect(expiredError.errorDescription?.contains("已过期") == true, "应该包含过期描述")
        
        let invalidError = TokenError.invalidToken
        #expect(invalidError.errorDescription?.contains("无效") == true, "应该包含无效描述")
    }
}