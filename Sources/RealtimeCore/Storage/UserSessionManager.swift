import Foundation

/// 用户会话管理器，使用新的自动持久化机制
/// 需求: 4.4, 4.5, 18.1, 18.2, 18.5
@MainActor
public class UserSessionManager: ObservableObject {
    
    // 使用新的 @RealtimeStorage 属性包装器，支持自动持久化
    @RealtimeStorage(wrappedValue: nil, "current_user_session", namespace: "RealtimeKit")
    public var currentSession: UserSession?
    
    @RealtimeStorage(wrappedValue: [], "session_history", namespace: "RealtimeKit")
    private var sessionHistory: [UserSession]
    
    @RealtimeStorage(wrappedValue: SessionPreferences(), "session_preferences", namespace: "RealtimeKit")
    private var preferences: SessionPreferences
    
    // 敏感会话数据使用安全存储
    @SecureRealtimeStorage(wrappedValue: nil, "secure_session_token", namespace: "RealtimeKit")
    private var secureSessionToken: String?
    
    // MARK: - Published Properties
    
    @Published public private(set) var isSessionActive: Bool = false
    @Published public private(set) var sessionDuration: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private var sessionTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        // 注册命名空间
        StorageManager.shared.registerNamespace("RealtimeKit")
        
        // 执行数据迁移（如果需要）
        performMigrationIfNeeded()
        
        // 更新会话状态
        updateSessionState()
    }
    
    // MARK: - Migration Support
    
    /// 执行数据迁移（从旧的存储格式到新的格式）
    /// 需求: 18.5 - 敏感数据安全存储和数据迁移
    private func performMigrationIfNeeded() {
        // 检查是否存在旧格式的会话数据
        let legacySessionKey = "RealtimeKit.UserSession"
        let legacyHistoryKey = "RealtimeKit.SessionHistory"
        
        // 迁移当前会话
        if UserDefaults.standard.object(forKey: legacySessionKey) != nil {
            if let legacyData = UserDefaults.standard.data(forKey: legacySessionKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let legacySession = try decoder.decode(UserSession.self, from: legacyData)
                    
                    // 只有在新存储中没有数据时才迁移
                    if !$currentSession.hasValue() {
                        currentSession = legacySession
                        print("Migrated current session from legacy storage")
                    }
                    
                    // 清理旧数据
                    UserDefaults.standard.removeObject(forKey: legacySessionKey)
                } catch {
                    print("Failed to migrate legacy session: \(error)")
                    UserDefaults.standard.removeObject(forKey: legacySessionKey)
                }
            }
        }
        
        // 迁移会话历史
        if UserDefaults.standard.object(forKey: legacyHistoryKey) != nil {
            if let legacyData = UserDefaults.standard.data(forKey: legacyHistoryKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let legacyHistory = try decoder.decode([UserSession].self, from: legacyData)
                    
                    // 只有在新存储中没有数据时才迁移
                    if sessionHistory.isEmpty {
                        sessionHistory = legacyHistory
                        print("Migrated session history from legacy storage")
                    }
                    
                    // 清理旧数据
                    UserDefaults.standard.removeObject(forKey: legacyHistoryKey)
                } catch {
                    print("Failed to migrate legacy session history: \(error)")
                    UserDefaults.standard.removeObject(forKey: legacyHistoryKey)
                }
            }
        }
    }
    

    
    // MARK: - Public Methods
    
    /// 创建新的用户会话
    /// 需求: 4.4, 18.2 - 会话管理和自动持久化
    public func createSession(
        userId: String,
        userName: String,
        userRole: UserRole,
        roomId: String? = nil,
        deviceInfo: DeviceInfo? = nil,
        secureToken: String? = nil
    ) {
        let session = UserSession(
            userId: userId,
            userName: userName,
            userRole: userRole,
            roomId: roomId,
            deviceInfo: deviceInfo
        )
        
        currentSession = session
        
        // 安全存储敏感令牌
        if let token = secureToken {
            secureSessionToken = token
        }
        
        addToHistory(session)
        startSessionTimer()
        updateSessionState()
    }
    
    /// 获取安全会话令牌
    /// 需求: 18.5 - 敏感数据安全存储
    public func getSecureSessionToken() -> String? {
        return secureSessionToken
    }
    
    /// 更新安全会话令牌
    /// 需求: 18.5 - 敏感数据安全存储
    public func updateSecureSessionToken(_ token: String?) {
        secureSessionToken = token
    }
    
    /// 更新当前会话的角色
    public func updateUserRole(_ newRole: UserRole) {
        guard let session = currentSession else { return }
        
        // 验证角色切换权限
        guard session.userRole.canSwitchTo(newRole) else {
            print("Cannot switch from \(session.userRole) to \(newRole)")
            return
        }
        
        let updatedSession = session.withUpdatedRole(newRole)
        currentSession = updatedSession
        addToHistory(updatedSession)
    }
    
    /// 更新房间ID
    public func updateRoomId(_ roomId: String?) {
        guard let session = currentSession else { return }
        
        let updatedSession = session.withUpdatedRoomId(roomId)
        currentSession = updatedSession
        addToHistory(updatedSession)
    }
    
    /// 结束当前会话
    public func endSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        currentSession = nil
        updateSessionState()
    }
    
    /// 获取会话历史
    public func getSessionHistory(limit: Int = 10) -> [UserSession] {
        return Array(sessionHistory.suffix(limit))
    }
    
    /// 清除会话历史
    public func clearHistory() {
        sessionHistory.removeAll()
    }
    
    /// 获取会话统计信息
    public func getSessionStatistics() -> SessionStatistics {
        let totalSessions = sessionHistory.count
        let totalDuration = sessionHistory.reduce(0) { total, session in
            return total + (session.lastActiveTime.timeIntervalSince(session.joinTime))
        }
        
        let roleDistribution = Dictionary(grouping: sessionHistory, by: { $0.userRole })
            .mapValues { $0.count }
        
        return SessionStatistics(
            totalSessions: totalSessions,
            totalDuration: totalDuration,
            averageDuration: totalSessions > 0 ? totalDuration / Double(totalSessions) : 0,
            roleDistribution: roleDistribution,
            lastSessionDate: sessionHistory.last?.joinTime
        )
    }
    
    /// 重置存储的会话数据
    /// 需求: 18.2 - 支持数据清理
    public func resetStorage() {
        $currentSession.remove()
        $sessionHistory.remove()
        $preferences.reset()
        $secureSessionToken.remove()
        updateSessionState()
        print("User session storage reset successfully")
    }
    
    /// 检查存储健康状态
    /// 需求: 18.9 - 错误处理和降级机制
    public func checkStorageHealth() -> SessionStorageHealthStatus {
        var issues: [String] = []
        
        // 检查会话历史大小
        if sessionHistory.count > preferences.maxHistoryCount {
            issues.append("Session history exceeds maximum count (\(sessionHistory.count) > \(preferences.maxHistoryCount))")
        }
        
        // 检查当前会话有效性
        if let session = currentSession, !session.isValid() {
            issues.append("Current session is expired")
        }
        
        // 检查偏好设置
        if !$preferences.hasValue() {
            issues.append("Session preferences not initialized")
        }
        
        return SessionStorageHealthStatus(
            isHealthy: issues.isEmpty,
            issues: issues,
            sessionCount: sessionHistory.count,
            hasActiveSession: currentSession != nil,
            hasSecureToken: secureSessionToken != nil,
            lastChecked: Date()
        )
    }
    
    /// 执行存储维护
    /// 需求: 18.8 - 性能优化
    public func performStorageMaintenance() {
        // 清理过期的会话历史
        let maxAge: TimeInterval = 90 * 24 * 60 * 60 // 90天
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        let originalCount = sessionHistory.count
        sessionHistory = sessionHistory.filter { session in
            session.lastActiveTime >= cutoffDate
        }
        
        let removedCount = originalCount - sessionHistory.count
        if removedCount > 0 {
            print("Removed \(removedCount) expired sessions from history")
        }
        
        // 限制历史记录数量
        if sessionHistory.count > preferences.maxHistoryCount {
            let excessCount = sessionHistory.count - preferences.maxHistoryCount
            sessionHistory = Array(sessionHistory.suffix(preferences.maxHistoryCount))
            print("Trimmed \(excessCount) sessions to maintain history limit")
        }
        
        // 清理过期的安全令牌
        if let session = currentSession, !session.isValid() {
            secureSessionToken = nil
            print("Cleared expired secure session token")
        }
        
        // 更新统计信息
        StorageManager.shared.updateStatistics()
    }
    
    // MARK: - Private Methods
    
    private func addToHistory(_ session: UserSession) {
        sessionHistory.append(session)
        
        // 限制历史记录数量
        if sessionHistory.count > preferences.maxHistoryCount {
            sessionHistory.removeFirst(sessionHistory.count - preferences.maxHistoryCount)
        }
    }
    
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionDuration()
            }
        }
    }
    
    private func updateSessionDuration() {
        guard let session = currentSession else {
            sessionDuration = 0
            return
        }
        
        sessionDuration = Date().timeIntervalSince(session.joinTime)
    }
    
    private func updateSessionState() {
        isSessionActive = currentSession != nil
        updateSessionDuration()
    }
}

/// 会话偏好设置
public struct SessionPreferences: Codable, Sendable {
    public var maxHistoryCount: Int = 100
    public var autoSaveInterval: TimeInterval = 30.0
    public var enableSessionAnalytics: Bool = true
    
    public init() {}
}

/// 会话统计信息
public struct SessionStatistics: Codable, Sendable {
    public let totalSessions: Int
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let roleDistribution: [UserRole: Int]
    public let lastSessionDate: Date?
    
    public init(
        totalSessions: Int,
        totalDuration: TimeInterval,
        averageDuration: TimeInterval,
        roleDistribution: [UserRole: Int],
        lastSessionDate: Date?
    ) {
        self.totalSessions = totalSessions
        self.totalDuration = totalDuration
        self.averageDuration = averageDuration
        self.roleDistribution = roleDistribution
        self.lastSessionDate = lastSessionDate
    }
}

/// 会话存储健康状态
public struct SessionStorageHealthStatus: Codable, Sendable {
    public let isHealthy: Bool
    public let issues: [String]
    public let sessionCount: Int
    public let hasActiveSession: Bool
    public let hasSecureToken: Bool
    public let lastChecked: Date
    
    public init(
        isHealthy: Bool,
        issues: [String],
        sessionCount: Int,
        hasActiveSession: Bool,
        hasSecureToken: Bool,
        lastChecked: Date
    ) {
        self.isHealthy = isHealthy
        self.issues = issues
        self.sessionCount = sessionCount
        self.hasActiveSession = hasActiveSession
        self.hasSecureToken = hasSecureToken
        self.lastChecked = lastChecked
    }
}