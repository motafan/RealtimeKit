import Foundation

/// 连接历史记录条目
/// 需求: 18.1, 18.2 - 连接历史等状态的自动持久化
public struct ConnectionHistoryEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let provider: ProviderType
    public let connectionTime: Date
    public let disconnectionTime: Date?
    public let duration: TimeInterval?
    public let success: Bool
    public let errorMessage: String?
    public let roomId: String?
    public let userId: String?
    
    public init(
        id: String = UUID().uuidString,
        provider: ProviderType,
        connectionTime: Date = Date(),
        disconnectionTime: Date? = nil,
        duration: TimeInterval? = nil,
        success: Bool = true,
        errorMessage: String? = nil,
        roomId: String? = nil,
        userId: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.connectionTime = connectionTime
        self.disconnectionTime = disconnectionTime
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
        self.roomId = roomId
        self.userId = userId
    }
    
    /// 创建连接结束的记录
    public func withDisconnection(at time: Date, error: String? = nil) -> ConnectionHistoryEntry {
        let duration = time.timeIntervalSince(connectionTime)
        return ConnectionHistoryEntry(
            id: self.id,
            provider: self.provider,
            connectionTime: self.connectionTime,
            disconnectionTime: time,
            duration: duration,
            success: error == nil,
            errorMessage: error,
            roomId: self.roomId,
            userId: self.userId
        )
    }
}

/// RealtimeManager 用户偏好设置
/// 需求: 18.1, 18.2 - 用户偏好设置的自动持久化
public struct RealtimeManagerPreferences: Codable, Sendable {
    /// 是否启用自动重连
    public var enableAutoReconnect: Bool
    
    /// 自动重连最大尝试次数
    public var maxReconnectAttempts: Int
    
    /// 重连间隔（秒）
    public var reconnectInterval: TimeInterval
    
    /// 是否启用连接历史记录
    public var enableConnectionHistory: Bool
    
    /// 连接历史记录最大条数
    public var maxConnectionHistoryEntries: Int
    
    /// 是否启用音频设置自动恢复
    public var enableAudioSettingsRestore: Bool
    
    /// 是否启用会话状态自动恢复
    public var enableSessionStateRestore: Bool
    
    /// 是否启用后台连接保持
    public var enableBackgroundConnection: Bool
    
    /// 网络变化时是否自动切换服务商
    public var enableProviderSwitchOnNetworkChange: Bool
    
    /// 首选的服务商降级链
    public var preferredFallbackChain: [ProviderType]
    
    /// 是否启用性能监控
    public var enablePerformanceMonitoring: Bool
    
    /// 是否启用详细日志记录
    public var enableVerboseLogging: Bool
    
    public init(
        enableAutoReconnect: Bool = true,
        maxReconnectAttempts: Int = 3,
        reconnectInterval: TimeInterval = 5.0,
        enableConnectionHistory: Bool = true,
        maxConnectionHistoryEntries: Int = 50,
        enableAudioSettingsRestore: Bool = true,
        enableSessionStateRestore: Bool = true,
        enableBackgroundConnection: Bool = false,
        enableProviderSwitchOnNetworkChange: Bool = false,
        preferredFallbackChain: [ProviderType] = [.mock],
        enablePerformanceMonitoring: Bool = false,
        enableVerboseLogging: Bool = false
    ) {
        self.enableAutoReconnect = enableAutoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectInterval = reconnectInterval
        self.enableConnectionHistory = enableConnectionHistory
        self.maxConnectionHistoryEntries = maxConnectionHistoryEntries
        self.enableAudioSettingsRestore = enableAudioSettingsRestore
        self.enableSessionStateRestore = enableSessionStateRestore
        self.enableBackgroundConnection = enableBackgroundConnection
        self.enableProviderSwitchOnNetworkChange = enableProviderSwitchOnNetworkChange
        self.preferredFallbackChain = preferredFallbackChain
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.enableVerboseLogging = enableVerboseLogging
    }
}

/// 应用状态恢复信息
/// 需求: 18.1, 18.3 - 应用启动时的自动状态恢复机制
public struct AppStateRecoveryInfo: Codable, Sendable {
    /// 最后一次成功连接的时间
    public var lastSuccessfulConnection: Date?
    
    /// 最后使用的服务商
    public var lastUsedProvider: ProviderType?
    
    /// 最后加入的房间ID
    public var lastRoomId: String?
    
    /// 最后的用户角色
    public var lastUserRole: UserRole?
    
    /// 应用最后一次正常退出的时间
    public var lastNormalExit: Date?
    
    /// 是否需要恢复会话
    public var needsSessionRecovery: Bool
    
    /// 是否需要恢复音频设置
    public var needsAudioSettingsRecovery: Bool
    
    /// 恢复尝试次数
    public var recoveryAttempts: Int
    
    /// 最大恢复尝试次数
    public var maxRecoveryAttempts: Int
    
    /// 应用版本（用于兼容性检查）
    public var appVersion: String?
    
    /// 框架版本（用于兼容性检查）
    public var frameworkVersion: String?
    
    /// 设备信息（用于恢复验证）
    public var deviceInfo: DeviceInfo?
    
    public init(
        lastSuccessfulConnection: Date? = nil,
        lastUsedProvider: ProviderType? = nil,
        lastRoomId: String? = nil,
        lastUserRole: UserRole? = nil,
        lastNormalExit: Date? = nil,
        needsSessionRecovery: Bool = false,
        needsAudioSettingsRecovery: Bool = false,
        recoveryAttempts: Int = 0,
        maxRecoveryAttempts: Int = 3,
        appVersion: String? = nil,
        frameworkVersion: String? = nil,
        deviceInfo: DeviceInfo? = nil
    ) {
        self.lastSuccessfulConnection = lastSuccessfulConnection
        self.lastUsedProvider = lastUsedProvider
        self.lastRoomId = lastRoomId
        self.lastUserRole = lastUserRole
        self.lastNormalExit = lastNormalExit
        self.needsSessionRecovery = needsSessionRecovery
        self.needsAudioSettingsRecovery = needsAudioSettingsRecovery
        self.recoveryAttempts = recoveryAttempts
        self.maxRecoveryAttempts = maxRecoveryAttempts
        self.appVersion = appVersion
        self.frameworkVersion = frameworkVersion
        self.deviceInfo = deviceInfo
    }
    
    /// 检查是否可以尝试恢复
    public var canAttemptRecovery: Bool {
        return recoveryAttempts < maxRecoveryAttempts
    }
    
    /// 检查恢复信息是否过期
    public func isRecoveryInfoExpired(maxAge: TimeInterval = 24 * 60 * 60) -> Bool {
        guard let lastExit = lastNormalExit else { return true }
        return Date().timeIntervalSince(lastExit) > maxAge
    }
    
    /// 标记恢复尝试
    public func withIncrementedRecoveryAttempts() -> AppStateRecoveryInfo {
        var info = self
        info.recoveryAttempts += 1
        return info
    }
    
    /// 重置恢复尝试
    public func withResetRecoveryAttempts() -> AppStateRecoveryInfo {
        var info = self
        info.recoveryAttempts = 0
        return info
    }
    
    /// 更新最后正常退出时间
    public func withNormalExit() -> AppStateRecoveryInfo {
        var info = self
        info.lastNormalExit = Date()
        info.needsSessionRecovery = false
        info.needsAudioSettingsRecovery = false
        return info
    }
}

/// 持久化状态管理器
/// 需求: 18.1, 18.2, 18.3 - 自动状态持久化和恢复机制
@MainActor
public class PersistentStateManager: ObservableObject {
    
    /// 单例实例
    public static let shared = PersistentStateManager()
    
    /// 状态恢复完成标志
    @Published public private(set) var isStateRestored: Bool = false
    
    /// 状态恢复错误
    @Published public private(set) var stateRestoreError: Error?
    
    /// 持久化统计信息
    @Published public private(set) var persistenceStats: PersistenceStatistics = PersistenceStatistics()
    
    private init() {}
    
    /// 执行应用启动时的状态恢复
    /// 需求: 18.3 - 应用启动时的自动状态恢复机制
    public func performStartupStateRecovery() async {
        let realtimeManager = RealtimeManager.shared
        
        // 检查是否需要恢复
        guard realtimeManager.appStateRecovery.canAttemptRecovery else {
            print("状态恢复: 已达到最大尝试次数，跳过恢复")
            isStateRestored = true
            return
        }
        
        // 检查恢复信息是否过期
        if realtimeManager.appStateRecovery.isRecoveryInfoExpired() {
            print("状态恢复: 恢复信息已过期，跳过恢复")
            await clearExpiredRecoveryInfo()
            isStateRestored = true
            return
        }
        
        // 增加恢复尝试次数
        realtimeManager.appStateRecovery = realtimeManager.appStateRecovery.withIncrementedRecoveryAttempts()
        
        // 恢复音频设置
        if realtimeManager.appStateRecovery.needsAudioSettingsRecovery {
            await restoreAudioSettings()
        }
        
        // 恢复会话状态
        if realtimeManager.appStateRecovery.needsSessionRecovery {
            await restoreSessionState()
        }
        
        // 恢复连接状态
        await restoreConnectionState()
        
        // 标记恢复完成
        realtimeManager.appStateRecovery = realtimeManager.appStateRecovery.withResetRecoveryAttempts()
        isStateRestored = true
        
        print("状态恢复完成")
    }
    
    /// 准备应用退出时的状态保存
    /// 需求: 18.1, 18.3 - 状态持久化
    public func prepareForAppExit() {
        let realtimeManager = RealtimeManager.shared
        
        // 更新应用状态恢复信息
        var recoveryInfo = realtimeManager.appStateRecovery
        recoveryInfo.lastNormalExit = Date()
        recoveryInfo.lastUsedProvider = realtimeManager.currentProvider
        recoveryInfo.lastRoomId = realtimeManager.currentSession?.roomId
        recoveryInfo.lastUserRole = realtimeManager.currentSession?.userRole
        recoveryInfo.needsSessionRecovery = realtimeManager.currentSession != nil
        recoveryInfo.needsAudioSettingsRecovery = true
        
        realtimeManager.appStateRecovery = recoveryInfo.withNormalExit()
        
        print("应用退出状态已保存")
    }
    
    /// 记录连接历史
    /// 需求: 18.1, 18.2 - 连接历史的自动持久化
    public func recordConnectionHistory(_ entry: ConnectionHistoryEntry) {
        let realtimeManager = RealtimeManager.shared
        
        // 添加新记录
        realtimeManager.connectionHistory.append(entry)
        
        // 保持历史记录数量限制
        let maxEntries = realtimeManager.userPreferences.maxConnectionHistoryEntries
        if realtimeManager.connectionHistory.count > maxEntries {
            realtimeManager.connectionHistory = Array(realtimeManager.connectionHistory.suffix(maxEntries))
        }
        
        // 更新统计信息
        persistenceStats.totalConnectionHistoryEntries = realtimeManager.connectionHistory.count
        persistenceStats.lastConnectionHistoryUpdate = Date()
    }
    
    /// 获取连接历史
    public func getConnectionHistory() -> [ConnectionHistoryEntry] {
        return RealtimeManager.shared.connectionHistory
    }
    
    /// 清理过期的恢复信息
    private func clearExpiredRecoveryInfo() async {
        let realtimeManager = RealtimeManager.shared
        realtimeManager.appStateRecovery = AppStateRecoveryInfo()
        print("已清理过期的恢复信息")
    }
    
    /// 恢复音频设置
    private func restoreAudioSettings() async {
        do {
            let realtimeManager = RealtimeManager.shared
            
            // 音频设置已通过 @RealtimeStorage 自动恢复
            // 这里只需要同步到 RTC Provider
            try await realtimeManager.applyAudioSettings(realtimeManager.audioSettings)
            
            print("音频设置恢复完成")
            
        } catch {
            print("音频设置恢复失败: \(error)")
        }
    }
    
    /// 恢复会话状态
    private func restoreSessionState() async {
        let realtimeManager = RealtimeManager.shared
        
        // 尝试恢复用户会话
        if let session = realtimeManager.sessionStorage.loadUserSession() {
            realtimeManager.currentSession = session
            print("会话状态恢复完成: \(session.userName)")
        }
    }
    
    /// 恢复连接状态
    private func restoreConnectionState() async {
        let realtimeManager = RealtimeManager.shared
        
        // 如果有最后使用的服务商，尝试恢复连接
        if let lastProvider = realtimeManager.appStateRecovery.lastUsedProvider,
           let config = realtimeManager.currentConfig {
            
            do {
                // 尝试重新配置服务商
                try await realtimeManager.configure(provider: lastProvider, config: config)
                print("连接状态恢复完成，使用服务商: \(lastProvider.displayName)")
                
            } catch {
                print("连接状态恢复失败: \(error)")
                
                // 尝试降级到默认服务商
                do {
                    try await realtimeManager.configure(provider: ProviderType.mock, config: config)
                    print("已降级到 Mock 服务商")
                } catch {
                    print("降级到 Mock 服务商也失败: \(error)")
                }
            }
        }
    }
    
    /// 更新用户偏好设置
    /// 需求: 18.1, 18.2 - 用户偏好的自动持久化
    public func updateUserPreferences(_ preferences: RealtimeManagerPreferences) {
        RealtimeManager.shared.userPreferences = preferences
        print("用户偏好设置已更新")
    }
    
    /// 获取用户偏好设置
    public func getUserPreferences() -> RealtimeManagerPreferences {
        return RealtimeManager.shared.userPreferences
    }
    
    /// 存储认证令牌
    /// 需求: 18.2, 18.5 - 敏感数据的安全存储
    public func storeAuthToken(_ token: String, for provider: ProviderType) {
        RealtimeManager.shared.authTokens[provider.rawValue] = token
        print("认证令牌已安全存储: \(provider.displayName)")
    }
    
    /// 获取认证令牌
    public func getAuthToken(for provider: ProviderType) -> String? {
        return RealtimeManager.shared.authTokens[provider.rawValue]
    }
    
    /// 清除认证令牌
    public func clearAuthToken(for provider: ProviderType) {
        RealtimeManager.shared.authTokens.removeValue(forKey: provider.rawValue)
        print("认证令牌已清除: \(provider.displayName)")
    }
    
    /// 清除所有认证令牌
    public func clearAllAuthTokens() {
        RealtimeManager.shared.authTokens.removeAll()
        print("所有认证令牌已清除")
    }
    
    /// 获取持久化统计信息
    public func updatePersistenceStatistics() {
        let realtimeManager = RealtimeManager.shared
        
        persistenceStats.totalConnectionHistoryEntries = realtimeManager.connectionHistory.count
        persistenceStats.totalStoredTokens = realtimeManager.authTokens.count
        persistenceStats.hasAudioSettings = true // 音频设置总是存在
        persistenceStats.hasUserPreferences = true // 用户偏好总是存在
        persistenceStats.hasAppStateRecovery = true // 应用状态恢复信息总是存在
        persistenceStats.lastUpdate = Date()
    }
}

/// 持久化统计信息
/// 需求: 18.8 - 性能监控和指标收集
public struct PersistenceStatistics: Codable, Sendable {
    public var totalConnectionHistoryEntries: Int = 0
    public var totalStoredTokens: Int = 0
    public var hasAudioSettings: Bool = false
    public var hasUserPreferences: Bool = false
    public var hasAppStateRecovery: Bool = false
    public var lastConnectionHistoryUpdate: Date?
    public var lastUpdate: Date = Date()
    
    public init() {}
}