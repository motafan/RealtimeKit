//
//  TokenManager.swift
//  RealtimeCore
//
//  Created by RealtimeKit on 2024/12/25.
//

import Foundation

/// Token 管理器，负责处理多服务商的 Token 自动续期和生命周期管理
/// 实现需求 9.1, 9.2, 9.3, 9.4, 9.5
@MainActor
public class TokenManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前活跃的 Token 状态
    @Published public private(set) var tokenStates: [ProviderType: TokenState] = [:]
    
    /// Token 续期统计信息
    @Published public private(set) var renewalStats: TokenRenewalStats = TokenRenewalStats()
    
    // MARK: - Private Properties
    
    /// Token 续期处理器映射 (需求 9.2)
    private var tokenRenewalHandlers: [ProviderType: @Sendable () async throws -> String] = [:]
    
    /// Token 过期定时器映射 (需求 9.5)
    private var tokenExpirationTimers: [ProviderType: Timer] = [:]
    
    /// 重试配置映射
    private var retryConfigurations: [ProviderType: RetryConfiguration] = [:]
    
    /// 默认提前续期时间（秒）
    private let defaultAdvanceRenewalTime: TimeInterval = 30
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultRetryConfigurations()
    }
    
    /// 清理所有资源
    public func cleanup() {
        // 清理所有定时器
        tokenExpirationTimers.values.forEach { $0.invalidate() }
        tokenExpirationTimers.removeAll()
        tokenRenewalHandlers.removeAll()
        tokenStates.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// 设置 Token 续期处理器 (需求 9.2)
    /// - Parameters:
    ///   - provider: 服务商类型
    ///   - handler: 续期处理器，返回新的 Token
    public func setupTokenRenewal(
        provider: ProviderType,
        handler: @escaping @Sendable () async throws -> String
    ) {
        tokenRenewalHandlers[provider] = handler
        
        // 初始化 Token 状态
        if tokenStates[provider] == nil {
            tokenStates[provider] = TokenState(provider: provider)
        }
        
        print("TokenManager: 已设置 \(provider.displayName) 的 Token 续期处理器")
    }
    
    /// 处理 Token 即将过期事件 (需求 9.1)
    /// - Parameters:
    ///   - provider: 服务商类型
    ///   - expiresIn: 剩余过期时间（秒）
    ///   - advanceTime: 提前续期时间（秒），默认为 30 秒
    public func handleTokenExpiration(
        provider: ProviderType,
        expiresIn: Int,
        advanceTime: TimeInterval? = nil
    ) async {
        let renewalTime = advanceTime ?? defaultAdvanceRenewalTime
        let renewalDelay = max(0, TimeInterval(expiresIn) - renewalTime)
        
        // 更新 Token 状态
        if let currentState = tokenStates[provider] {
            tokenStates[provider] = currentState.updateExpiration(expiresIn: expiresIn)
        }
        
        print("TokenManager: \(provider.displayName) Token 将在 \(expiresIn) 秒后过期，将在 \(renewalDelay) 秒后开始续期")
        
        // 取消之前的定时器
        tokenExpirationTimers[provider]?.invalidate()
        
        // 创建新的续期定时器 (需求 9.5)
        let timer = Timer.scheduledTimer(withTimeInterval: renewalDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performTokenRenewal(provider: provider)
            }
        }
        
        tokenExpirationTimers[provider] = timer
    }
    
    /// 立即执行 Token 续期
    /// - Parameter provider: 服务商类型
    public func renewTokenImmediately(provider: ProviderType) async {
        await performTokenRenewal(provider: provider)
    }
    
    /// 清除指定服务商的 Token 续期处理器
    /// - Parameter provider: 服务商类型
    public func clearTokenRenewalHandler(for provider: ProviderType) {
        tokenRenewalHandlers.removeValue(forKey: provider)
        tokenExpirationTimers[provider]?.invalidate()
        tokenExpirationTimers.removeValue(forKey: provider)
        tokenStates.removeValue(forKey: provider)
        
        print("TokenManager: 已清除 \(provider.displayName) 的 Token 续期处理器")
    }
    
    /// 获取指定服务商的 Token 状态
    /// - Parameter provider: 服务商类型
    /// - Returns: Token 状态，如果不存在则返回 nil
    public func getTokenState(for provider: ProviderType) -> TokenState? {
        return tokenStates[provider]
    }
    
    /// 配置重试策略
    /// - Parameters:
    ///   - provider: 服务商类型
    ///   - configuration: 重试配置
    public func configureRetryStrategy(
        for provider: ProviderType,
        configuration: RetryConfiguration
    ) {
        retryConfigurations[provider] = configuration
    }
    
    // MARK: - Private Methods
    
    /// 执行 Token 续期 (需求 9.3, 9.4)
    /// - Parameter provider: 服务商类型
    private func performTokenRenewal(provider: ProviderType) async {
        guard let renewalHandler = tokenRenewalHandlers[provider] else {
            print("TokenManager: 未找到 \(provider.displayName) 的续期处理器")
            if let currentState = tokenStates[provider] {
                tokenStates[provider] = currentState.markRenewalFailed(error: TokenError.noRenewalHandler)
            }
            return
        }
        
        // 更新状态为续期中
        if let currentState = tokenStates[provider] {
            tokenStates[provider] = currentState.startRenewal()
        }
        renewalStats.totalAttempts += 1
        
        let retryConfig = retryConfigurations[provider] ?? RetryConfiguration.default
        var currentAttempt = 0
        
        while currentAttempt < retryConfig.maxRetries {
            do {
                // 执行续期
                let newToken = try await renewalHandler()
                
                // 更新所有相关服务的 Token (需求 9.3)
                try await updateProvidersToken(provider: provider, newToken: newToken)
                
                // 标记续期成功
                if let currentState = tokenStates[provider] {
                    tokenStates[provider] = currentState.markRenewalSuccess(newToken: newToken)
                }
                renewalStats.totalSuccesses += 1
                
                print("TokenManager: \(provider.displayName) Token 续期成功")
                return
                
            } catch {
                currentAttempt += 1
                renewalStats.totalFailures += 1
                
                print("TokenManager: \(provider.displayName) Token 续期失败 (尝试 \(currentAttempt)/\(retryConfig.maxRetries)): \(error)")
                
                if currentAttempt < retryConfig.maxRetries {
                    // 指数退避重试 (需求 9.4)
                    let delay = retryConfig.calculateDelay(attempt: currentAttempt)
                    print("TokenManager: 将在 \(delay) 秒后重试")
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    // 所有重试都失败
                    if let currentState = tokenStates[provider] {
                        tokenStates[provider] = currentState.markRenewalFailed(error: error)
                    }
                    print("TokenManager: \(provider.displayName) Token 续期最终失败，已达到最大重试次数")
                }
            }
        }
    }
    
    /// 更新服务商的 Token
    /// - Parameters:
    ///   - provider: 服务商类型
    ///   - newToken: 新的 Token
    private func updateProvidersToken(provider: ProviderType, newToken: String) async throws {
        // 这里需要访问 RealtimeManager 来更新 Token
        // 由于循环依赖问题，我们通过通知或回调的方式来处理
        
        // 发送 Token 更新通知
        let userInfo: [String: Any] = [
            "provider": provider,
            "token": newToken
        ]
        
        NotificationCenter.default.post(
            name: .tokenRenewed,
            object: self,
            userInfo: userInfo
        )
    }
    
    /// 设置默认重试配置
    private func setupDefaultRetryConfigurations() {
        let defaultConfig = RetryConfiguration.default
        
        for provider in ProviderType.allCases {
            retryConfigurations[provider] = defaultConfig
        }
    }
}

// MARK: - Supporting Types

/// Token 状态
public struct TokenState: Sendable {
    public let provider: ProviderType
    public let status: TokenStatus
    public let lastRenewalTime: Date?
    public let expirationTime: Date?
    public let renewalAttempts: Int
    public let lastError: Error?
    
    public init(
        provider: ProviderType,
        status: TokenStatus = .unknown,
        lastRenewalTime: Date? = nil,
        expirationTime: Date? = nil,
        renewalAttempts: Int = 0,
        lastError: Error? = nil
    ) {
        self.provider = provider
        self.status = status
        self.lastRenewalTime = lastRenewalTime
        self.expirationTime = expirationTime
        self.renewalAttempts = renewalAttempts
        self.lastError = lastError
    }
    
    func updateExpiration(expiresIn: Int) -> TokenState {
        let newExpirationTime = Date().addingTimeInterval(TimeInterval(expiresIn))
        let newStatus = status == .unknown ? .active : status
        return TokenState(
            provider: provider,
            status: newStatus,
            lastRenewalTime: lastRenewalTime,
            expirationTime: newExpirationTime,
            renewalAttempts: renewalAttempts,
            lastError: lastError
        )
    }
    
    func startRenewal() -> TokenState {
        return TokenState(
            provider: provider,
            status: .renewing,
            lastRenewalTime: lastRenewalTime,
            expirationTime: expirationTime,
            renewalAttempts: renewalAttempts + 1,
            lastError: lastError
        )
    }
    
    func markRenewalSuccess(newToken: String) -> TokenState {
        return TokenState(
            provider: provider,
            status: .active,
            lastRenewalTime: Date(),
            expirationTime: expirationTime,
            renewalAttempts: renewalAttempts,
            lastError: nil
        )
    }
    
    func markRenewalFailed(error: Error) -> TokenState {
        return TokenState(
            provider: provider,
            status: .failed,
            lastRenewalTime: lastRenewalTime,
            expirationTime: expirationTime,
            renewalAttempts: renewalAttempts,
            lastError: error
        )
    }
}

/// Token 状态枚举
public enum TokenStatus: Sendable {
    case unknown        // 未知状态
    case active         // 活跃状态
    case renewing       // 续期中
    case failed         // 续期失败
    case expired        // 已过期
}

/// Token 续期统计信息
public struct TokenRenewalStats: Sendable {
    public var totalAttempts: Int = 0
    public var totalSuccesses: Int = 0
    public var totalFailures: Int = 0
    
    public var successRate: Double {
        guard totalAttempts > 0 else { return 0.0 }
        return Double(totalSuccesses) / Double(totalAttempts)
    }
}

/// 重试配置
public struct RetryConfiguration: Sendable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double
    
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
    }
    
    /// 计算指数退避延迟时间
    /// - Parameter attempt: 当前尝试次数（从 1 开始）
    /// - Returns: 延迟时间（秒）
    public func calculateDelay(attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
    
    public static let `default` = RetryConfiguration()
}

/// Token 相关错误
public enum TokenError: Error, LocalizedError, Sendable {
    case noRenewalHandler
    case renewalFailed(String)
    case tokenExpired
    case invalidToken
    
    public var errorDescription: String? {
        switch self {
        case .noRenewalHandler:
            return "未设置 Token 续期处理器"
        case .renewalFailed(let message):
            return "Token 续期失败: \(message)"
        case .tokenExpired:
            return "Token 已过期"
        case .invalidToken:
            return "无效的 Token"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    // Note: Notification names are defined in ConnectionModels.swift to avoid duplicates
}