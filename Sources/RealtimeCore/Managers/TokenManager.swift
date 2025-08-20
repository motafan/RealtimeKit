// TokenManager.swift
// Token management system for RealtimeKit

import Foundation
import Combine

/// Token renewal handler type
public typealias TokenRenewalHandler = () async throws -> String

/// Token expiration notification handler type
public typealias TokenExpirationHandler = (ProviderType, Int) async -> Void

/// Token information structure
public struct TokenInfo: Codable, Equatable, Sendable {
    let token: String
    let expirationTime: Date
    let provider: ProviderType
    let createdAt: Date
    
    public init(token: String, expirationTime: Date, provider: ProviderType) {
        self.token = token
        self.expirationTime = expirationTime
        self.provider = provider
        self.createdAt = Date()
    }
    
    /// Time remaining until token expires (in seconds)
    public var timeUntilExpiration: TimeInterval {
        return expirationTime.timeIntervalSinceNow
    }
    
    /// Whether the token is expired
    public var isExpired: Bool {
        return Date() >= expirationTime
    }
    
    /// Whether the token will expire soon (within 30 seconds)
    public var willExpireSoon: Bool {
        return timeUntilExpiration <= 30
    }
}

/// Token renewal state
public enum TokenRenewalState: String, CaseIterable, Codable, Sendable {
    case idle = "idle"
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .pending: return "等待中"
        case .inProgress: return "续期中"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }
}

/// Token renewal statistics
public struct TokenRenewalStats: Codable, Equatable, Sendable {
    var totalRenewals: Int = 0
    var successfulRenewals: Int = 0
    var failedRenewals: Int = 0
    var retryAttempts: Int = 0
    var lastRenewalTime: Date?
    var lastFailureTime: Date?
    var lastFailureReason: String?
    
    public var successRate: Double {
        guard totalRenewals > 0 else { return 0.0 }
        return Double(successfulRenewals) / Double(totalRenewals)
    }
}

/// Token renewal scheduler configuration
public struct TokenRenewalSchedulerConfig: Codable, Equatable, Sendable {
    let renewalAdvanceTime: TimeInterval
    let checkInterval: TimeInterval
    let maxConcurrentRenewals: Int
    let enablePeriodicCheck: Bool
    
    public init(
        renewalAdvanceTime: TimeInterval = 30.0,
        checkInterval: TimeInterval = 10.0,
        maxConcurrentRenewals: Int = 3,
        enablePeriodicCheck: Bool = true
    ) {
        self.renewalAdvanceTime = renewalAdvanceTime
        self.checkInterval = checkInterval
        self.maxConcurrentRenewals = maxConcurrentRenewals
        self.enablePeriodicCheck = enablePeriodicCheck
    }
    
    public static let `default` = TokenRenewalSchedulerConfig()
}

/// Token renewal scheduler for managing multiple provider token lifecycles
/// Requirements: 9.5
@MainActor
public class TokenRenewalScheduler: ObservableObject {
    
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var activeRenewals: Set<ProviderType> = []
    @Published public private(set) var scheduledRenewals: [ProviderType: Date] = [:]
    
    private let config: TokenRenewalSchedulerConfig
    private weak var tokenManager: TokenManager?
    private var schedulerTask: Task<Void, Never>?
    private var periodicCheckTask: Task<Void, Never>?
    
    public init(config: TokenRenewalSchedulerConfig = .default) {
        self.config = config
    }
    
    deinit {
        schedulerTask?.cancel()
        periodicCheckTask?.cancel()
    }
    
    /// Start the token renewal scheduler
    /// - Parameter tokenManager: The token manager to schedule renewals for
    public func start(with tokenManager: TokenManager) {
        guard !isRunning else { return }
        
        self.tokenManager = tokenManager
        isRunning = true
        
        if config.enablePeriodicCheck {
            startPeriodicCheck()
        }
        
        print("Token renewal scheduler started")
    }
    
    /// Stop the token renewal scheduler
    public func stop() {
        guard isRunning else { return }
        
        isRunning = false
        schedulerTask?.cancel()
        periodicCheckTask?.cancel()
        schedulerTask = nil
        periodicCheckTask = nil
        activeRenewals.removeAll()
        scheduledRenewals.removeAll()
        
        print("Token renewal scheduler stopped")
    }
    
    /// Schedule token renewal for a specific provider
    /// - Parameters:
    ///   - provider: The provider type
    ///   - renewalTime: When to renew the token
    public func scheduleRenewal(for provider: ProviderType, at renewalTime: Date) {
        scheduledRenewals[provider] = renewalTime
        
        _ = Task { @MainActor in
            await executeScheduledRenewal(provider: provider, renewalTime: renewalTime)
        }
        
        print("Token renewal scheduled for \(provider) at \(renewalTime)")
    }
    
    /// Cancel scheduled renewal for a provider
    /// - Parameter provider: The provider type
    public func cancelScheduledRenewal(for provider: ProviderType) {
        scheduledRenewals.removeValue(forKey: provider)
        print("Cancelled scheduled renewal for \(provider)")
    }
    
    private func startPeriodicCheck() {
        periodicCheckTask = Task { @MainActor in
            while !Task.isCancelled && isRunning {
                await performPeriodicCheck()
                
                do {
                    try await Task.sleep(nanoseconds: UInt64(config.checkInterval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }
    
    private func performPeriodicCheck() async {
        guard let tokenManager = tokenManager else { return }
        
        let now = Date()
        
        for (provider, tokenInfo) in tokenManager.tokenInfos {
            let timeUntilExpiration = tokenInfo.timeUntilExpiration
            
            // Schedule renewal if token will expire soon and no renewal is scheduled
            if timeUntilExpiration <= config.renewalAdvanceTime &&
               timeUntilExpiration > 0 &&
               !activeRenewals.contains(provider) &&
               scheduledRenewals[provider] == nil {
                
                let renewalTime = now.addingTimeInterval(max(0, timeUntilExpiration - config.renewalAdvanceTime))
                scheduleRenewal(for: provider, at: renewalTime)
            }
        }
        
        // Execute due renewals
        let dueRenewals = scheduledRenewals.filter { $0.value <= now }
        for (provider, _) in dueRenewals {
            if activeRenewals.count < config.maxConcurrentRenewals {
                await executeRenewal(for: provider)
            }
        }
    }
    
    private func executeScheduledRenewal(provider: ProviderType, renewalTime: Date) async {
        let now = Date()
        let delay = renewalTime.timeIntervalSince(now)
        
        if delay > 0 {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return // Task was cancelled
            }
        }
        
        // Check if renewal is still needed and scheduled
        guard scheduledRenewals[provider] == renewalTime else { return }
        
        await executeRenewal(for: provider)
    }
    
    private func executeRenewal(for provider: ProviderType) async {
        guard let tokenManager = tokenManager,
              !activeRenewals.contains(provider),
              activeRenewals.count < config.maxConcurrentRenewals else {
            return
        }
        
        activeRenewals.insert(provider)
        scheduledRenewals.removeValue(forKey: provider)
        
        do {
            try await tokenManager.renewToken(for: provider)
            print("Scheduled token renewal completed for \(provider)")
        } catch {
            print("Scheduled token renewal failed for \(provider): \(error)")
        }
        
        activeRenewals.remove(provider)
    }
}

/// Token Manager for handling multi-provider token lifecycle management
/// Supports automatic renewal, exponential backoff retry, and error handling
/// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
@MainActor
public class TokenManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var tokenInfos: [ProviderType: TokenInfo] = [:]
    @Published public private(set) var renewalStates: [ProviderType: TokenRenewalState] = [:]
    @Published public private(set) var renewalStats: [ProviderType: TokenRenewalStats] = [:]
    
    // MARK: - Private Properties
    private var renewalHandlers: [ProviderType: TokenRenewalHandler] = [:]
    private var expirationHandlers: [ProviderType: TokenExpirationHandler] = [:]
    private var renewalTasks: [ProviderType: Task<Void, Never>] = [:]
    private var monitoringTasks: [ProviderType: Task<Void, Never>] = [:]
    
    // Token renewal scheduler
    private let renewalScheduler: TokenRenewalScheduler
    
    // Exponential backoff configuration
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 60.0
    private let maxRetryAttempts: Int = 5
    private let renewalAdvanceTime: TimeInterval = 30.0 // Renew 30 seconds before expiration
    
    public init(schedulerConfig: TokenRenewalSchedulerConfig = .default) {
        self.renewalScheduler = TokenRenewalScheduler(config: schedulerConfig)
        print("TokenManager initialized")
        
        // Start the renewal scheduler
        renewalScheduler.start(with: self)
    }
    
    deinit {
        // Cancel all ongoing tasks
        for task in renewalTasks.values {
            task.cancel()
        }
        for task in monitoringTasks.values {
            task.cancel()
        }
    }
    
    // MARK: - Public API
    
    /// Register a token renewal handler for a specific provider
    /// - Parameters:
    ///   - provider: The provider type
    ///   - handler: Async handler that returns a new token
    /// Requirements: 9.2
    public func registerTokenRenewalHandler(
        for provider: ProviderType,
        handler: @escaping TokenRenewalHandler
    ) {
        renewalHandlers[provider] = handler
        print("Token renewal handler registered for provider: \(provider)")
    }
    
    /// Register a token expiration notification handler for a specific provider
    /// - Parameters:
    ///   - provider: The provider type
    ///   - handler: Async handler called when token will expire
    /// Requirements: 9.1
    public func registerTokenExpirationHandler(
        for provider: ProviderType,
        handler: @escaping TokenExpirationHandler
    ) {
        expirationHandlers[provider] = handler
        print("Token expiration handler registered for provider: \(provider)")
    }
    
    /// Set initial token for a provider and start monitoring
    /// - Parameters:
    ///   - token: The token string
    ///   - expirationTime: When the token expires
    ///   - provider: The provider type
    /// Requirements: 9.1, 9.5
    public func setToken(
        _ token: String,
        expirationTime: Date,
        for provider: ProviderType
    ) {
        let tokenInfo = TokenInfo(
            token: token,
            expirationTime: expirationTime,
            provider: provider
        )
        
        tokenInfos[provider] = tokenInfo
        renewalStates[provider] = .idle
        
        if renewalStats[provider] == nil {
            renewalStats[provider] = TokenRenewalStats()
        }
        
        startTokenMonitoring(for: provider)
        
        // Schedule automatic renewal through scheduler
        let renewalTime = expirationTime.addingTimeInterval(-renewalAdvanceTime)
        if renewalTime > Date() {
            renewalScheduler.scheduleRenewal(for: provider, at: renewalTime)
        }
        
        print("Token set for provider \(provider), expires at: \(expirationTime)")
    }
    
    /// Get current token for a provider
    /// - Parameter provider: The provider type
    /// - Returns: Current token info if available
    public func getToken(for provider: ProviderType) -> TokenInfo? {
        return tokenInfos[provider]
    }
    
    /// Check if token is valid (not expired) for a provider
    /// - Parameter provider: The provider type
    /// - Returns: True if token is valid, false otherwise
    public func isTokenValid(for provider: ProviderType) -> Bool {
        guard let tokenInfo = tokenInfos[provider] else { return false }
        return !tokenInfo.isExpired
    }
    
    /// Manually trigger token renewal for a provider
    /// - Parameter provider: The provider type
    /// Requirements: 9.2, 9.3, 9.4
    public func renewToken(for provider: ProviderType) async throws {
        guard let handler = renewalHandlers[provider] else {
            throw RealtimeError.tokenRenewalFailed(provider, "No renewal handler registered")
        }
        
        guard renewalStates[provider] != .inProgress else {
            print("Token renewal already in progress for provider: \(provider)")
            return
        }
        
        renewalStates[provider] = .inProgress
        
        do {
            let newToken = try await performTokenRenewalWithRetry(
                provider: provider,
                handler: handler
            )
            
            // Calculate new expiration time (assuming 1 hour validity)
            let newExpirationTime = Date().addingTimeInterval(3600)
            
            let newTokenInfo = TokenInfo(
                token: newToken,
                expirationTime: newExpirationTime,
                provider: provider
            )
            
            tokenInfos[provider] = newTokenInfo
            renewalStates[provider] = .completed
            
            // Update statistics
            var stats = renewalStats[provider] ?? TokenRenewalStats()
            stats.totalRenewals += 1
            stats.successfulRenewals += 1
            stats.lastRenewalTime = Date()
            renewalStats[provider] = stats
            
            print("Token renewed successfully for provider: \(provider)")
            
            // Restart monitoring with new token
            startTokenMonitoring(for: provider)
            
        } catch {
            renewalStates[provider] = .failed
            
            // Update statistics
            var stats = renewalStats[provider] ?? TokenRenewalStats()
            stats.totalRenewals += 1
            stats.failedRenewals += 1
            stats.lastFailureTime = Date()
            stats.lastFailureReason = error.localizedDescription
            renewalStats[provider] = stats
            
            print("Token renewal failed for provider \(provider): \(error)")
            throw RealtimeError.tokenRenewalFailed(provider, error.localizedDescription)
        }
    }
    
    /// Handle token expiration notification from provider
    /// - Parameters:
    ///   - provider: The provider type
    ///   - expiresIn: Seconds until expiration
    /// Requirements: 9.1, 9.2
    public func handleTokenExpiration(
        provider: ProviderType,
        expiresIn: Int
    ) async {
        print("Token expiration notification for \(provider): expires in \(expiresIn) seconds")
        
        // Notify registered handler
        if let handler = expirationHandlers[provider] {
            await handler(provider, expiresIn)
        }
        
        // Trigger automatic renewal if handler is available and token expires soon
        if expiresIn <= Int(renewalAdvanceTime), renewalHandlers[provider] != nil {
            do {
                try await renewToken(for: provider)
            } catch {
                print("Automatic token renewal failed for \(provider): \(error)")
            }
        }
    }
    
    /// Remove token and stop monitoring for a provider
    /// - Parameter provider: The provider type
    public func removeToken(for provider: ProviderType) {
        tokenInfos.removeValue(forKey: provider)
        renewalStates.removeValue(forKey: provider)
        renewalHandlers.removeValue(forKey: provider)
        expirationHandlers.removeValue(forKey: provider)
        
        // Cancel scheduled renewals
        renewalScheduler.cancelScheduledRenewal(for: provider)
        
        // Cancel ongoing tasks
        renewalTasks[provider]?.cancel()
        renewalTasks.removeValue(forKey: provider)
        
        monitoringTasks[provider]?.cancel()
        monitoringTasks.removeValue(forKey: provider)
        
        print("Token removed for provider: \(provider)")
    }
    
    /// Get renewal statistics for a provider
    /// - Parameter provider: The provider type
    /// - Returns: Renewal statistics if available
    public func getRenewalStats(for provider: ProviderType) -> TokenRenewalStats? {
        return renewalStats[provider]
    }
    
    /// Clear all tokens and stop all monitoring
    public func clearAllTokens() {
        let providers = Array(tokenInfos.keys)
        for provider in providers {
            removeToken(for: provider)
        }
        renewalScheduler.stop()
        print("All tokens cleared")
    }
    
    /// Get the renewal scheduler instance
    public var scheduler: TokenRenewalScheduler {
        return renewalScheduler
    }
    
    // MARK: - Private Methods
    
    /// Start monitoring token expiration for a provider
    /// Requirements: 9.5
    private func startTokenMonitoring(for provider: ProviderType) {
        // Cancel existing monitoring task
        monitoringTasks[provider]?.cancel()
        
        guard let tokenInfo = tokenInfos[provider] else { return }
        
        let task = Task { @MainActor in
            await monitorTokenExpiration(tokenInfo: tokenInfo, provider: provider)
        }
        
        monitoringTasks[provider] = task
    }
    
    /// Monitor token expiration and trigger renewal
    /// Requirements: 9.1, 9.5
    private func monitorTokenExpiration(tokenInfo: TokenInfo, provider: ProviderType) async {
        let timeUntilRenewal = max(0, tokenInfo.timeUntilExpiration - renewalAdvanceTime)
        
        print("Monitoring token for \(provider), will renew in \(timeUntilRenewal) seconds")
        
        do {
            try await Task.sleep(nanoseconds: UInt64(timeUntilRenewal * 1_000_000_000))
            
            // Check if task was cancelled or token was updated
            guard !Task.isCancelled,
                  let currentToken = tokenInfos[provider],
                  currentToken.token == tokenInfo.token else {
                return
            }
            
            // Notify about upcoming expiration
            let expiresIn = Int(currentToken.timeUntilExpiration)
            await handleTokenExpiration(provider: provider, expiresIn: expiresIn)
            
        } catch {
            if !Task.isCancelled {
                print("Token monitoring error for \(provider): \(error)")
            }
        }
    }
    
    /// Perform token renewal with exponential backoff retry
    /// Requirements: 9.3, 9.4
    private func performTokenRenewalWithRetry(
        provider: ProviderType,
        handler: TokenRenewalHandler
    ) async throws -> String {
        var attempt = 0
        var lastError: Error?
        
        while attempt < maxRetryAttempts {
            do {
                print("Token renewal attempt \(attempt + 1) for provider: \(provider)")
                let newToken = try await handler()
                
                if attempt > 0 {
                    // Update retry statistics
                    var stats = renewalStats[provider] ?? TokenRenewalStats()
                    stats.retryAttempts += attempt
                    renewalStats[provider] = stats
                }
                
                return newToken
                
            } catch {
                lastError = error
                attempt += 1
                
                print("Token renewal attempt \(attempt) failed for \(provider): \(error)")
                
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(attempt: attempt)
                    print("Retrying token renewal for \(provider) in \(delay) seconds")
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All attempts failed
        throw lastError ?? RealtimeError.tokenRenewalFailed(provider, "Max retry attempts exceeded")
    }
    
    /// Calculate exponential backoff delay
    /// Requirements: 9.4
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt - 1))
        let jitteredDelay = exponentialDelay * (0.5 + Double.random(in: 0...0.5))
        return min(jitteredDelay, maxRetryDelay)
    }
}

// MARK: - Extensions

extension TokenManager {
    
    /// Get all active providers with valid tokens
    public var activeProviders: [ProviderType] {
        return tokenInfos.compactMap { (provider, tokenInfo) in
            tokenInfo.isExpired ? nil : provider
        }
    }
    
    /// Get all providers with expired tokens
    public var expiredProviders: [ProviderType] {
        return tokenInfos.compactMap { (provider, tokenInfo) in
            tokenInfo.isExpired ? provider : nil
        }
    }
    
    /// Get overall renewal success rate across all providers
    public var overallSuccessRate: Double {
        let allStats = renewalStats.values
        let totalRenewals = allStats.reduce(0) { $0 + $1.totalRenewals }
        let successfulRenewals = allStats.reduce(0) { $0 + $1.successfulRenewals }
        
        guard totalRenewals > 0 else { return 0.0 }
        return Double(successfulRenewals) / Double(totalRenewals)
    }
}