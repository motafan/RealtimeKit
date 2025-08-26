import Foundation
import Combine

/// 服务商切换管理器
/// 负责管理服务商的动态切换、降级和故障转移机制
/// 需求: 2.3, 2.4, 17.6
@MainActor
public class ProviderSwitchManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前使用的服务商
    @Published public private(set) var currentProvider: ProviderType = .mock
    
    /// 可用的服务商列表
    @Published public private(set) var availableProviders: [ProviderType] = []
    
    /// 服务商切换进行中标志
    @Published public private(set) var switchingInProgress: Bool = false
    
    /// 降级链状态
    @Published public private(set) var fallbackChainStatus: [ProviderType: ProviderStatus] = [:]
    
    /// 最后一次切换的错误信息
    @Published public private(set) var lastSwitchError: LocalizedRealtimeError?
    
    // MARK: - Private Properties
    
    /// 已注册的服务商工厂
    private var providerFactories: [ProviderType: ProviderFactory] = [:]
    
    /// 降级链，按优先级排序
    private var fallbackChain: [ProviderType] = [.agora, .mock]
    
    /// 服务商健康状态监控
    private var providerHealthStatus: [ProviderType: ProviderHealthInfo] = [:]
    
    /// 切换历史记录
    private var switchHistory: [ProviderSwitchRecord] = []
    
    /// 最大历史记录数量
    private let maxHistoryRecords = 50
    
    /// 本地化管理器
    private let localizationManager = LocalizationManager.shared
    
    // MARK: - Initialization
    
    public init() {
        // 注册默认的 Mock 工厂
        registerProvider(.mock, factory: MockProviderFactory())
        
        // 初始化服务商状态
        updateProviderStatuses()
    }
    
    // MARK: - Provider Registration (需求 2.2)
    
    /// 注册服务商工厂
    /// - Parameters:
    ///   - type: 服务商类型
    ///   - factory: 服务商工厂实例
    public func registerProvider(_ type: ProviderType, factory: ProviderFactory) {
        providerFactories[type] = factory
        
        if !availableProviders.contains(type) {
            availableProviders.append(type)
            // 按优先级排序
            availableProviders.sort { $0.priority < $1.priority }
        }
        
        // 初始化健康状态
        providerHealthStatus[type] = ProviderHealthInfo(
            provider: type,
            isHealthy: true,
            lastHealthCheck: Date(),
            consecutiveFailures: 0
        )
        
        updateProviderStatuses()
        
        print("已注册服务商工厂: \(type.displayName)")
    }
    
    /// 注销服务商工厂
    /// - Parameter type: 服务商类型
    public func unregisterProvider(_ type: ProviderType) {
        providerFactories.removeValue(forKey: type)
        availableProviders.removeAll { $0 == type }
        providerHealthStatus.removeValue(forKey: type)
        
        updateProviderStatuses()
        
        print("已注销服务商工厂: \(type.displayName)")
    }
    
    /// 获取已注册的服务商工厂
    /// - Parameter type: 服务商类型
    /// - Returns: 服务商工厂实例，如果未注册则返回 nil
    public func getProviderFactory(for type: ProviderType) -> ProviderFactory? {
        return providerFactories[type]
    }
    
    /// 获取服务商支持的功能特性
    /// - Parameter type: 服务商类型
    /// - Returns: 支持的功能特性集合
    public func getSupportedFeatures(for type: ProviderType) -> Set<ProviderFeature> {
        return providerFactories[type]?.supportedFeatures() ?? []
    }
    
    /// 检查服务商是否支持特定功能
    /// - Parameters:
    ///   - type: 服务商类型
    ///   - feature: 功能特性
    /// - Returns: 是否支持该功能
    public func supportsFeature(_ type: ProviderType, feature: ProviderFeature) -> Bool {
        return getSupportedFeatures(for: type).contains(feature)
    }
    
    // MARK: - Provider Switching (需求 2.3)
    
    /// 切换到指定的服务商
    /// - Parameters:
    ///   - newProvider: 新的服务商类型
    ///   - preserveSession: 是否保持会话状态
    ///   - forceSwitch: 是否强制切换（忽略健康检查）
    /// - Throws: 切换失败时抛出错误
    public func switchProvider(
        to newProvider: ProviderType,
        preserveSession: Bool = true,
        forceSwitch: Bool = false
    ) async throws {
        // 检查服务商是否可用
        guard availableProviders.contains(newProvider) else {
            let error = RealtimeError.providerNotAvailable(newProvider)
            lastSwitchError = LocalizedErrorFactory.createLocalizedError(from: error)
            throw error
        }
        
        // 如果已经是当前服务商，直接返回
        guard newProvider != currentProvider else {
            print("已经在使用服务商: \(newProvider.displayName)")
            return
        }
        
        // 检查服务商健康状态
        if !forceSwitch && !isProviderHealthy(newProvider) {
            _ = localizationManager.localizedString(
                for: "error.provider.unhealthy",
                arguments: newProvider.displayName
            )
            let error = RealtimeError.providerNotAvailable(newProvider)
            lastSwitchError = LocalizedErrorFactory.createLocalizedError(from: error)
            throw error
        }
        
        switchingInProgress = true
        let switchStartTime = Date()
        
        defer {
            switchingInProgress = false
        }
        
        do {
            // 记录切换开始
            let switchRecord = ProviderSwitchRecord(
                fromProvider: currentProvider,
                toProvider: newProvider,
                startTime: switchStartTime,
                preserveSession: preserveSession,
                reason: .manual
            )
            
            // 执行切换
            try await performProviderSwitch(
                from: currentProvider,
                to: newProvider,
                preserveSession: preserveSession
            )
            
            // 更新当前服务商
            let previousProvider = currentProvider
            currentProvider = newProvider
            
            // 记录成功的切换
            recordSuccessfulSwitch(switchRecord.withCompletion(success: true, endTime: Date()))
            
            // 更新健康状态
            markProviderHealthy(newProvider)
            
            // 清除错误状态
            lastSwitchError = nil
            
            print("服务商切换成功: \(previousProvider.displayName) -> \(newProvider.displayName)")
            
        } catch {
            // 记录失败的切换
            let failedRecord = ProviderSwitchRecord(
                fromProvider: currentProvider,
                toProvider: newProvider,
                startTime: switchStartTime,
                preserveSession: preserveSession,
                reason: .manual
            ).withCompletion(success: false, endTime: Date(), error: error)
            
            recordFailedSwitch(failedRecord)
            
            // 更新健康状态
            markProviderUnhealthy(newProvider, error: error)
            
            // 创建本地化错误
            lastSwitchError = LocalizedErrorFactory.createLocalizedError(from: error)
            
            print("服务商切换失败: \(currentProvider.displayName) -> \(newProvider.displayName), 错误: \(error)")
            
            // 尝试降级处理
            if !forceSwitch {
                try await attemptFallback(originalError: error, excludeProvider: newProvider)
            } else {
                throw error
            }
        }
    }
    
    /// 执行服务商切换的核心逻辑
    /// - Parameters:
    ///   - fromProvider: 源服务商
    ///   - toProvider: 目标服务商
    ///   - preserveSession: 是否保持会话状态
    private func performProviderSwitch(
        from fromProvider: ProviderType,
        to toProvider: ProviderType,
        preserveSession: Bool
    ) async throws {
        // 获取 RealtimeManager 实例
        let realtimeManager = RealtimeManager.shared
        
        // 保存当前状态（如果需要保持会话）
        var savedSession: UserSession?
        var savedAudioSettings: AudioSettings?
        
        if preserveSession {
            savedSession = realtimeManager.currentSession
            savedAudioSettings = realtimeManager.audioSettings
        }
        
        // 断开当前连接
        if realtimeManager.connectionState == .connected {
            do {
                try await realtimeManager.rtcProvider?.leaveRoom()
            } catch RealtimeError.noActiveSession {
                // 忽略没有活跃会话的错误，这在切换过程中是正常的
                print("切换过程中忽略 noActiveSession 错误")
            }
        }
        
        // 临时清除会话以允许重新配置
        let originalSession = realtimeManager.currentSession
        if originalSession != nil {
            // 使用内部方法清除会话，不触发登出流程
            await realtimeManager.clearSessionForReconfiguration()
        }
        
        // 获取当前配置
        guard let config = realtimeManager.currentConfig else {
            throw RealtimeError.configurationError("缺少配置信息")
        }
        
        // 配置新的服务商
        try await realtimeManager.configure(provider: toProvider, config: config)
        
        // 恢复状态（如果需要）
        if preserveSession {
            if let session = savedSession {
                try await realtimeManager.restoreSession(session)
            }
            
            if let audioSettings = savedAudioSettings {
                try await realtimeManager.applyAudioSettings(audioSettings)
            }
        }
    }
    
    // MARK: - Fallback and Recovery (需求 2.4)
    
    /// 设置服务商降级链
    /// - Parameter chain: 降级链，按优先级排序
    public func setFallbackChain(_ chain: [ProviderType]) {
        fallbackChain = chain.filter { availableProviders.contains($0) }
        updateProviderStatuses()
        
        let chainNames = fallbackChain.map { $0.displayName }.joined(separator: " -> ")
        print("设置降级链: \(chainNames)")
    }
    
    /// 获取当前降级链
    /// - Returns: 降级链数组
    public func getFallbackChain() -> [ProviderType] {
        return fallbackChain
    }
    
    /// 尝试降级处理
    /// - Parameters:
    ///   - originalError: 原始错误
    ///   - excludeProvider: 要排除的服务商（通常是刚刚失败的服务商）
    public func attemptFallback(
        originalError: Error,
        excludeProvider: ProviderType? = nil
    ) async throws {
        print("开始尝试降级处理，原始错误: \(originalError)")
        
        // 获取可用的降级选项
        let fallbackOptions = fallbackChain.filter { provider in
            provider != currentProvider &&
            provider != excludeProvider &&
            availableProviders.contains(provider) &&
            isProviderHealthy(provider)
        }
        
        guard !fallbackOptions.isEmpty else {
            let errorMessage = localizationManager.localizedString(for: "error.no_fallback_providers")
            throw RealtimeError.allProvidersFailed(originalError: originalError, message: errorMessage)
        }
        
        // 尝试每个降级选项
        for fallbackProvider in fallbackOptions {
            do {
                print("尝试降级到服务商: \(fallbackProvider.displayName)")
                
                try await switchProvider(
                    to: fallbackProvider,
                    preserveSession: true,
                    forceSwitch: false
                )
                
                print("降级成功，当前使用服务商: \(fallbackProvider.displayName)")
                
                // 记录降级成功
                let fallbackRecord = ProviderSwitchRecord(
                    fromProvider: currentProvider,
                    toProvider: fallbackProvider,
                    startTime: Date(),
                    preserveSession: true,
                    reason: .fallback(originalError: originalError)
                ).withCompletion(success: true, endTime: Date())
                
                recordSuccessfulSwitch(fallbackRecord)
                return
                
            } catch {
                print("降级到 \(fallbackProvider.displayName) 失败: \(error)")
                markProviderUnhealthy(fallbackProvider, error: error)
                continue
            }
        }
        
        // 所有降级选项都失败了
        let errorMessage = localizationManager.localizedString(
            for: "error.all_fallback_failed",
            arguments: fallbackOptions.map { $0.displayName }.joined(separator: ", ")
        )
        throw RealtimeError.allProvidersFailed(originalError: originalError, message: errorMessage)
    }
    
    // MARK: - Provider Health Management
    
    /// 检查服务商是否健康
    /// - Parameter provider: 服务商类型
    /// - Returns: 是否健康
    public func isProviderHealthy(_ provider: ProviderType) -> Bool {
        guard let healthInfo = providerHealthStatus[provider] else { return false }
        
        // 如果连续失败次数超过阈值，认为不健康
        let maxFailures = 3
        if healthInfo.consecutiveFailures >= maxFailures {
            return false
        }
        
        // 如果最后一次健康检查时间过久，需要重新检查
        let healthCheckInterval: TimeInterval = 300 // 5分钟
        if Date().timeIntervalSince(healthInfo.lastHealthCheck) > healthCheckInterval {
            // 在实际实现中，这里可以执行健康检查
            return true // 暂时返回 true
        }
        
        return healthInfo.isHealthy
    }
    
    /// 标记服务商为健康状态
    /// - Parameter provider: 服务商类型
    private func markProviderHealthy(_ provider: ProviderType) {
        providerHealthStatus[provider] = ProviderHealthInfo(
            provider: provider,
            isHealthy: true,
            lastHealthCheck: Date(),
            consecutiveFailures: 0
        )
        updateProviderStatuses()
    }
    
    /// 标记服务商为不健康状态
    /// - Parameters:
    ///   - provider: 服务商类型
    ///   - error: 导致不健康的错误
    private func markProviderUnhealthy(_ provider: ProviderType, error: Error) {
        let currentInfo = providerHealthStatus[provider] ?? ProviderHealthInfo(
            provider: provider,
            isHealthy: true,
            lastHealthCheck: Date(),
            consecutiveFailures: 0
        )
        
        providerHealthStatus[provider] = ProviderHealthInfo(
            provider: provider,
            isHealthy: false,
            lastHealthCheck: Date(),
            consecutiveFailures: currentInfo.consecutiveFailures + 1,
            lastError: error
        )
        updateProviderStatuses()
    }
    
    /// 更新服务商状态
    private func updateProviderStatuses() {
        var newStatus: [ProviderType: ProviderStatus] = [:]
        
        for provider in availableProviders {
            let isRegistered = providerFactories[provider] != nil
            let isHealthy = isProviderHealthy(provider)
            let isCurrent = provider == currentProvider
            
            if isCurrent {
                newStatus[provider] = .current
            } else if !isRegistered {
                newStatus[provider] = .notRegistered
            } else if !isHealthy {
                newStatus[provider] = .unhealthy
            } else {
                newStatus[provider] = .available
            }
        }
        
        fallbackChainStatus = newStatus
    }
    
    // MARK: - Switch History Management
    
    /// 记录成功的切换
    /// - Parameter record: 切换记录
    private func recordSuccessfulSwitch(_ record: ProviderSwitchRecord) {
        switchHistory.append(record)
        trimSwitchHistory()
    }
    
    /// 记录失败的切换
    /// - Parameter record: 切换记录
    private func recordFailedSwitch(_ record: ProviderSwitchRecord) {
        switchHistory.append(record)
        trimSwitchHistory()
    }
    
    /// 修剪切换历史记录
    private func trimSwitchHistory() {
        if switchHistory.count > maxHistoryRecords {
            switchHistory = Array(switchHistory.suffix(maxHistoryRecords))
        }
    }
    
    /// 获取切换历史记录
    /// - Parameter limit: 返回记录的最大数量
    /// - Returns: 切换历史记录数组
    public func getSwitchHistory(limit: Int = 20) -> [ProviderSwitchRecord] {
        return Array(switchHistory.suffix(limit))
    }
    
    /// 获取服务商统计信息
    /// - Parameter provider: 服务商类型
    /// - Returns: 统计信息
    public func getProviderStatistics(_ provider: ProviderType) -> ProviderStatistics {
        let records = switchHistory.filter { $0.toProvider == provider }
        let successfulSwitches = records.filter { $0.success == true }.count
        let failedSwitches = records.filter { $0.success == false }.count
        let totalSwitches = records.count
        
        let successRate = totalSwitches > 0 ? Double(successfulSwitches) / Double(totalSwitches) : 0.0
        
        let healthInfo = providerHealthStatus[provider]
        
        return ProviderStatistics(
            provider: provider,
            totalSwitches: totalSwitches,
            successfulSwitches: successfulSwitches,
            failedSwitches: failedSwitches,
            successRate: successRate,
            consecutiveFailures: healthInfo?.consecutiveFailures ?? 0,
            lastHealthCheck: healthInfo?.lastHealthCheck,
            isCurrentlyHealthy: isProviderHealthy(provider)
        )
    }
    
    // MARK: - Localized Provider Information (需求 17.6)
    
    /// 获取本地化的服务商切换提示
    /// - Parameters:
    ///   - fromProvider: 源服务商
    ///   - toProvider: 目标服务商
    /// - Returns: 本地化的提示信息
    public func getLocalizedSwitchMessage(
        from fromProvider: ProviderType,
        to toProvider: ProviderType
    ) -> String {
        return localizationManager.localizedString(
            for: "provider.switch.message",
            arguments: fromProvider.displayName, toProvider.displayName
        )
    }
    
    /// 获取本地化的降级提示
    /// - Parameters:
    ///   - failedProvider: 失败的服务商
    ///   - fallbackProvider: 降级的服务商
    /// - Returns: 本地化的提示信息
    public func getLocalizedFallbackMessage(
        failedProvider: ProviderType,
        fallbackProvider: ProviderType
    ) -> String {
        return localizationManager.localizedString(
            for: "provider.fallback.message",
            arguments: failedProvider.displayName, fallbackProvider.displayName
        )
    }
    
    /// 获取本地化的服务商状态描述
    /// - Parameter provider: 服务商类型
    /// - Returns: 本地化的状态描述
    public func getLocalizedProviderStatus(_ provider: ProviderType) -> String {
        let status = fallbackChainStatus[provider] ?? .notRegistered
        
        switch status {
        case .current:
            return localizationManager.localizedString(for: "provider.status.current")
        case .available:
            return localizationManager.localizedString(for: "provider.status.available")
        case .unhealthy:
            return localizationManager.localizedString(for: "provider.status.unhealthy")
        case .notRegistered:
            return localizationManager.localizedString(for: "provider.status.not_registered")
        }
    }
    
    // MARK: - Public Utility Methods
    
    /// 清除错误状态
    public func clearLastError() {
        lastSwitchError = nil
    }
    
    /// 重置服务商健康状态
    /// - Parameter provider: 服务商类型，如果为 nil 则重置所有服务商
    public func resetProviderHealth(_ provider: ProviderType? = nil) {
        if let provider = provider {
            markProviderHealthy(provider)
        } else {
            for providerType in availableProviders {
                markProviderHealthy(providerType)
            }
        }
    }
    
    /// 获取推荐的服务商（基于健康状态和优先级）
    /// - Returns: 推荐的服务商类型
    public func getRecommendedProvider() -> ProviderType? {
        return availableProviders
            .filter { $0 != currentProvider && isProviderHealthy($0) }
            .min { $0.priority < $1.priority }
    }
}

// MARK: - Supporting Types

/// 服务商状态枚举
public enum ProviderStatus: String, CaseIterable {
    case current = "current"
    case available = "available"
    case unhealthy = "unhealthy"
    case notRegistered = "not_registered"
}

/// 服务商健康信息
public struct ProviderHealthInfo {
    let provider: ProviderType
    let isHealthy: Bool
    let lastHealthCheck: Date
    let consecutiveFailures: Int
    let lastError: Error?
    
    init(
        provider: ProviderType,
        isHealthy: Bool,
        lastHealthCheck: Date,
        consecutiveFailures: Int,
        lastError: Error? = nil
    ) {
        self.provider = provider
        self.isHealthy = isHealthy
        self.lastHealthCheck = lastHealthCheck
        self.consecutiveFailures = consecutiveFailures
        self.lastError = lastError
    }
}

/// 服务商切换记录
public struct ProviderSwitchRecord {
    let fromProvider: ProviderType
    let toProvider: ProviderType
    let startTime: Date
    let endTime: Date?
    let preserveSession: Bool
    let reason: SwitchReason
    let success: Bool?
    let error: Error?
    
    init(
        fromProvider: ProviderType,
        toProvider: ProviderType,
        startTime: Date,
        preserveSession: Bool,
        reason: SwitchReason,
        endTime: Date? = nil,
        success: Bool? = nil,
        error: Error? = nil
    ) {
        self.fromProvider = fromProvider
        self.toProvider = toProvider
        self.startTime = startTime
        self.endTime = endTime
        self.preserveSession = preserveSession
        self.reason = reason
        self.success = success
        self.error = error
    }
    
    func withCompletion(success: Bool, endTime: Date, error: Error? = nil) -> ProviderSwitchRecord {
        return ProviderSwitchRecord(
            fromProvider: fromProvider,
            toProvider: toProvider,
            startTime: startTime,
            preserveSession: preserveSession,
            reason: reason,
            endTime: endTime,
            success: success,
            error: error
        )
    }
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

/// 切换原因枚举
public enum SwitchReason {
    case manual
    case fallback(originalError: Error)
    case healthCheck
    case automatic
}

/// 服务商统计信息
public struct ProviderStatistics {
    let provider: ProviderType
    let totalSwitches: Int
    let successfulSwitches: Int
    let failedSwitches: Int
    let successRate: Double
    let consecutiveFailures: Int
    let lastHealthCheck: Date?
    let isCurrentlyHealthy: Bool
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
}