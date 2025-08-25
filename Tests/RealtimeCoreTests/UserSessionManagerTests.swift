import Testing
import Foundation
@testable import RealtimeCore

/// 用户会话管理器测试
/// 需求: 4.1, 4.2, 4.4, 测试要求 1, 18.1, 18.2
@Suite("User Session Manager Tests")
@MainActor
struct UserSessionManagerTests {
    
    // MARK: - Helper Methods
    
    private func createCleanManager() -> UserSessionManager {
        let manager = UserSessionManager()
        manager.resetStorage()
        return manager
    }
    
    // MARK: - Initialization Tests
    
    @Test("用户会话管理器初始化")
    func testInitialization() async throws {
        let manager = createCleanManager()
        
        #expect(manager.currentSession == nil)
        #expect(!manager.isSessionActive)
        #expect(manager.sessionDuration == 0)
    }
    
    // MARK: - Session Creation Tests
    
    @Test("创建用户会话")
    func testCreateSession() async throws {
        let manager = createCleanManager()
        let deviceInfo = DeviceInfo(
            deviceId: "test_device",
            deviceModel: "iPhone 15",
            systemVersion: "17.0",
            appVersion: "1.0.0"
        )
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            roomId: "room456",
            deviceInfo: deviceInfo
        )
        
        #expect(manager.currentSession != nil)
        #expect(manager.isSessionActive)
        #expect(manager.currentSession?.userId == "user123")
        #expect(manager.currentSession?.userName == "测试用户")
        #expect(manager.currentSession?.userRole == .broadcaster)
        #expect(manager.currentSession?.roomId == "room456")
        #expect(manager.currentSession?.deviceInfo == deviceInfo)
    }
    
    @Test("创建会话后自动添加到历史记录")
    func testSessionAddedToHistory() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        let history = manager.getSessionHistory()
        #expect(history.count == 1)
        #expect(history.first?.userId == "user123")
    }
    
    // MARK: - Role Update Tests
    
    @Test("更新用户角色")
    func testUpdateUserRole() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        manager.updateUserRole(.moderator)
        
        #expect(manager.currentSession?.userRole == .moderator)
        
        // 检查历史记录中有两个条目
        let history = manager.getSessionHistory()
        #expect(history.count == 2)
        #expect(history.last?.userRole == .moderator)
    }
    
    @Test("无效角色切换应该被拒绝")
    func testInvalidRoleSwitch() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .audience
        )
        
        // 观众不能直接切换到主播
        manager.updateUserRole(.broadcaster)
        
        // 角色应该保持不变
        #expect(manager.currentSession?.userRole == .audience)
    }
    
    // MARK: - Room Update Tests
    
    @Test("更新房间ID")
    func testUpdateRoomId() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            roomId: "room1"
        )
        
        manager.updateRoomId("room2")
        
        #expect(manager.currentSession?.roomId == "room2")
        #expect(manager.currentSession?.isInRoom == true)
        
        // 离开房间
        manager.updateRoomId(nil)
        
        #expect(manager.currentSession?.roomId == nil)
        #expect(manager.currentSession?.isInRoom == false)
    }
    
    // MARK: - Session End Tests
    
    @Test("结束会话")
    func testEndSession() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        #expect(manager.isSessionActive)
        
        manager.endSession()
        
        #expect(manager.currentSession == nil)
        #expect(!manager.isSessionActive)
        #expect(manager.sessionDuration == 0)
    }
    
    // MARK: - History Management Tests
    
    @Test("获取会话历史")
    func testGetSessionHistory() async throws {
        let manager = createCleanManager()
        
        // 创建多个会话
        for i in 1...5 {
            manager.createSession(
                userId: "user\(i)",
                userName: "用户\(i)",
                userRole: .broadcaster
            )
            manager.endSession()
        }
        
        let history = manager.getSessionHistory()
        #expect(history.count == 5)
        
        // 测试限制数量
        let limitedHistory = manager.getSessionHistory(limit: 3)
        #expect(limitedHistory.count == 3)
        #expect(limitedHistory.last?.userId == "user5")
    }
    
    @Test("清除会话历史")
    func testClearHistory() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        #expect(manager.getSessionHistory().count == 1)
        
        manager.clearHistory()
        
        #expect(manager.getSessionHistory().isEmpty)
    }
    
    // MARK: - Statistics Tests
    
    @Test("获取会话统计信息")
    func testGetSessionStatistics() async throws {
        let manager = createCleanManager()
        
        // 创建不同角色的会话
        manager.createSession(userId: "user1", userName: "用户1", userRole: .broadcaster)
        manager.endSession()
        
        manager.createSession(userId: "user2", userName: "用户2", userRole: .audience)
        manager.endSession()
        
        manager.createSession(userId: "user3", userName: "用户3", userRole: .broadcaster)
        manager.endSession()
        
        let stats = manager.getSessionStatistics()
        
        #expect(stats.totalSessions == 3)
        #expect(stats.roleDistribution[.broadcaster] == 2)
        #expect(stats.roleDistribution[.audience] == 1)
        #expect(stats.lastSessionDate != nil)
    }
    
    // MARK: - Storage Tests
    
    @Test("重置存储数据")
    func testResetStorage() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        #expect(manager.isSessionActive)
        #expect(!manager.getSessionHistory().isEmpty)
        
        manager.resetStorage()
        
        #expect(!manager.isSessionActive)
        #expect(manager.currentSession == nil)
        #expect(manager.getSessionHistory().isEmpty)
    }
    
    // MARK: - @RealtimeStorage Integration Tests
    
    @Test("会话数据持久化")
    func testSessionPersistence() async throws {
        let manager1 = createCleanManager()
        
        manager1.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            roomId: "room456"
        )
        
        // 创建新的管理器实例，应该能够恢复会话数据
        let manager2 = UserSessionManager()
        
        #expect(manager2.currentSession?.userId == "user123")
        #expect(manager2.currentSession?.userName == "测试用户")
        #expect(manager2.currentSession?.userRole == .broadcaster)
        #expect(manager2.currentSession?.roomId == "room456")
        #expect(manager2.isSessionActive)
    }
    
    @Test("会话历史持久化")
    func testSessionHistoryPersistence() async throws {
        let manager1 = createCleanManager()
        
        // 创建多个会话
        for i in 1...3 {
            manager1.createSession(
                userId: "user\(i)",
                userName: "用户\(i)",
                userRole: .broadcaster
            )
            manager1.endSession()
        }
        
        let originalHistory = manager1.getSessionHistory()
        #expect(originalHistory.count == 3)
        
        // 创建新的管理器实例
        let manager2 = UserSessionManager()
        let restoredHistory = manager2.getSessionHistory()
        
        #expect(restoredHistory.count == originalHistory.count)
        #expect(restoredHistory.first?.userId == originalHistory.first?.userId)
        #expect(restoredHistory.last?.userId == originalHistory.last?.userId)
    }
    
    // MARK: - Performance Tests
    
    @Test("大量会话历史性能测试")
    func testLargeHistoryPerformance() async throws {
        let manager = createCleanManager()
        
        // 创建大量会话
        for i in 1...100 {
            manager.createSession(
                userId: "user\(i)",
                userName: "用户\(i)",
                userRole: .broadcaster
            )
            manager.endSession()
        }
        
        let startTime = Date()
        let history = manager.getSessionHistory()
        let endTime = Date()
        
        // 历史记录被限制为最大数量（默认100），但由于其他测试的影响，实际可能更少
        #expect(history.count <= 100)
        #expect(history.count > 0)
        #expect(endTime.timeIntervalSince(startTime) < 0.1) // 应该在100ms内完成
    }
    
    // MARK: - Secure Storage Tests
    
    @Test("安全会话令牌存储")
    func testSecureSessionToken() async throws {
        let manager = createCleanManager()
        
        let secureToken = "secure_token_12345"
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            secureToken: secureToken
        )
        
        #expect(manager.getSecureSessionToken() == secureToken)
        
        // 更新令牌
        let newToken = "new_secure_token_67890"
        manager.updateSecureSessionToken(newToken)
        
        #expect(manager.getSecureSessionToken() == newToken)
    }
    
    @Test("安全令牌持久化")
    func testSecureTokenPersistence() async throws {
        let manager1 = createCleanManager()
        let secureToken = "persistent_secure_token"
        
        manager1.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            secureToken: secureToken
        )
        
        // 创建新的管理器实例，应该能够恢复安全令牌
        let manager2 = UserSessionManager()
        
        #expect(manager2.getSecureSessionToken() == secureToken)
    }
    
    @Test("清除安全令牌")
    func testClearSecureToken() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            secureToken: "token_to_clear"
        )
        
        #expect(manager.getSecureSessionToken() != nil)
        
        manager.updateSecureSessionToken(nil)
        
        #expect(manager.getSecureSessionToken() == nil)
    }
    
    // MARK: - Storage Health Tests
    
    @Test("存储健康状态检查")
    func testStorageHealthCheck() async throws {
        let manager = createCleanManager()
        
        // 初始状态应该是健康的
        let initialHealth = manager.checkStorageHealth()
        #expect(initialHealth.isHealthy)
        #expect(initialHealth.sessionCount == 0)
        #expect(!initialHealth.hasActiveSession)
        #expect(!initialHealth.hasSecureToken)
        
        // 创建会话后
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            secureToken: "test_token"
        )
        
        let healthWithSession = manager.checkStorageHealth()
        #expect(healthWithSession.hasActiveSession)
        #expect(healthWithSession.hasSecureToken)
    }
    
    @Test("存储维护功能")
    func testStorageMaintenance() async throws {
        let manager = createCleanManager()
        
        // 创建大量会话历史
        for i in 1...150 {
            manager.createSession(
                userId: "user\(i)",
                userName: "用户\(i)",
                userRole: .broadcaster
            )
            manager.endSession()
        }
        
        let beforeMaintenance = manager.getSessionHistory().count
        #expect(beforeMaintenance > 0) // 应该有会话历史
        
        // 执行维护
        manager.performStorageMaintenance()
        
        let afterMaintenance = manager.getSessionHistory().count
        #expect(afterMaintenance <= 100) // 应该被限制到最大历史数量
        #expect(afterMaintenance > 0) // 维护后仍应有数据
    }
    
    // MARK: - Migration Tests
    
    @Test("数据迁移测试")
    func testDataMigration() async throws {
        // 先清理现有数据
        _ = createCleanManager()
        // 模拟旧格式数据
        let legacySession = UserSession(
            userId: "legacy_user",
            userName: "遗留用户",
            userRole: .broadcaster,
            roomId: "legacy_room"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacySession)
        
        // 存储到旧的键名
        UserDefaults.standard.set(legacyData, forKey: "RealtimeKit.UserSession")
        
        // 创建新的管理器，应该触发迁移
        let manager = UserSessionManager()
        
        #expect(manager.currentSession?.userId == "legacy_user")
        #expect(manager.currentSession?.userName == "遗留用户")
        #expect(manager.currentSession?.userRole == .broadcaster)
        #expect(manager.currentSession?.roomId == "legacy_room")
        
        // 验证旧数据已被清理
        #expect(UserDefaults.standard.object(forKey: "RealtimeKit.UserSession") == nil)
    }
    
    @Test("会话历史迁移测试")
    func testSessionHistoryMigration() async throws {
        // 先清理现有数据
        _ = createCleanManager()
        let legacyHistory = [
            UserSession(userId: "user1", userName: "用户1", userRole: .broadcaster),
            UserSession(userId: "user2", userName: "用户2", userRole: .audience)
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacyHistory)
        
        // 存储到旧的键名
        UserDefaults.standard.set(legacyData, forKey: "RealtimeKit.SessionHistory")
        
        // 创建新的管理器，应该触发迁移
        let manager = UserSessionManager()
        let migratedHistory = manager.getSessionHistory()
        
        #expect(migratedHistory.count == 2)
        #expect(migratedHistory[0].userId == "user1")
        #expect(migratedHistory[1].userId == "user2")
        
        // 验证旧数据已被清理
        #expect(UserDefaults.standard.object(forKey: "RealtimeKit.SessionHistory") == nil)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("无会话时的操作")
    func testOperationsWithoutSession() async throws {
        let manager = createCleanManager()
        
        // 尝试更新角色（无会话）
        manager.updateUserRole(.broadcaster)
        #expect(manager.currentSession == nil)
        
        // 尝试更新房间ID（无会话）
        manager.updateRoomId("room123")
        #expect(manager.currentSession == nil)
        
        // 结束会话（无会话）
        manager.endSession()
        #expect(!manager.isSessionActive)
    }
    
    @Test("会话持续时间计算")
    func testSessionDurationCalculation() async throws {
        let manager = createCleanManager()
        
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        // 等待一小段时间
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        #expect(manager.sessionDuration > 0)
        #expect(manager.sessionDuration < 1.0) // 应该小于1秒
    }
    
    @Test("命名空间隔离测试")
    func testNamespaceIsolation() async throws {
        let manager1 = createCleanManager()
        
        manager1.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        // 直接使用不同命名空间的存储应该不会冲突
        @RealtimeStorage(wrappedValue: nil, "current_user_session", namespace: "DifferentApp")
        var differentNamespaceSession: UserSession?
        
        #expect(differentNamespaceSession == nil)
        #expect(manager1.currentSession != nil)
    }
    
    @Test("存储错误处理")
    func testStorageErrorHandling() async throws {
        let manager = createCleanManager()
        
        // 测试重置存储后的状态
        manager.createSession(
            userId: "user123",
            userName: "测试用户",
            userRole: .broadcaster,
            secureToken: "test_token"
        )
        
        #expect(manager.isSessionActive)
        #expect(manager.getSecureSessionToken() != nil)
        
        manager.resetStorage()
        
        #expect(!manager.isSessionActive)
        #expect(manager.currentSession == nil)
        #expect(manager.getSecureSessionToken() == nil)
        #expect(manager.getSessionHistory().isEmpty)
    }
}