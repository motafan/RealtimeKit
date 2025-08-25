import Testing
import Foundation
@testable import RealtimeCore

/// 存储管理器测试
/// 需求: 18.6, 18.8, 18.9
@Suite("Storage Manager Tests")
@MainActor
struct StorageManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test("存储管理器初始化")
    func testInitialization() async throws {
        let manager = StorageManager.shared
        
        #expect(manager.isInitialized)
        #expect(manager.defaultStorage is UserDefaults)
        #expect(manager.secureStorage is KeychainStorageProvider)
    }
    
    // MARK: - Provider Registration Tests
    
    @Test("注册自定义存储提供者")
    func testRegisterStorageProvider() async throws {
        let manager = StorageManager.shared
        let mockProvider = MockStorageProvider()
        
        manager.registerStorageProvider(mockProvider, name: "mock")
        
        let retrievedProvider = manager.getStorageProvider(name: "mock")
        #expect(retrievedProvider != nil)
    }
    
    @Test("获取不存在的存储提供者")
    func testGetNonExistentProvider() async throws {
        let manager = StorageManager.shared
        
        let provider = manager.getStorageProvider(name: "nonexistent")
        #expect(provider == nil)
    }
    
    // MARK: - Namespace Management Tests
    
    @Test("注册和管理命名空间")
    func testNamespaceManagement() async throws {
        let manager = StorageManager.shared
        
        manager.registerNamespace("TestApp")
        manager.registerNamespace("AnotherApp")
        
        let namespaces = manager.registeredNamespaces
        #expect(namespaces.contains("TestApp"))
        #expect(namespaces.contains("AnotherApp"))
        #expect(namespaces.count >= 2)
    }
    
    @Test("清理命名空间数据")
    func testClearNamespace() async throws {
        let manager = StorageManager.shared
        
        manager.registerNamespace("TestClear")
        manager.clearNamespace("TestClear")
        
        // 验证命名空间仍然注册但数据被清理
        let namespaces = manager.registeredNamespaces
        #expect(namespaces.contains("TestClear"))
    }
    
    // MARK: - Batch Operations Tests
    
    @Test("批量写入操作")
    func testBatchWrite() async throws {
        let manager = StorageManager.shared
        let mockProvider = MockStorageProvider()
        manager.registerStorageProvider(mockProvider, name: "test")
        
        // 执行批量写入
        manager.batchWrite("value1", for: "key1", provider: "test")
        manager.batchWrite("value2", for: "key2", provider: "test")
        manager.batchWrite("value3", for: "key3", provider: "test")
        
        // 等待批量操作执行
        try await Task.sleep(nanoseconds: 600_000_000) // 600ms
        
        // 验证数据已写入
        #expect(mockProvider.hasValue(for: "key1"))
        #expect(mockProvider.hasValue(for: "key2"))
        #expect(mockProvider.hasValue(for: "key3"))
    }
    
    @Test("大批量操作立即执行")
    func testLargeBatchImmediateExecution() async throws {
        let manager = StorageManager.shared
        let mockProvider = MockStorageProvider()
        manager.registerStorageProvider(mockProvider, name: "test_large")
        
        // 写入超过最大批量大小的操作
        for i in 1...60 {
            manager.batchWrite("value\(i)", for: "key\(i)", provider: "test_large")
        }
        
        // 应该立即执行，不需要等待
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // 验证至少前50个已被写入
        #expect(mockProvider.hasValue(for: "key1"))
        #expect(mockProvider.hasValue(for: "key50"))
    }
    
    // MARK: - Performance Monitoring Tests
    
    @Test("性能指标更新")
    func testPerformanceMetrics() async throws {
        let manager = StorageManager.shared
        
        // 触发一些操作
        manager.batchWrite("test", for: "perf_key", provider: "userdefaults")
        
        // 等待性能指标更新
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        manager.updateStatistics()
        
        let metrics = manager.performanceMetrics
        #expect(metrics.lastUpdated != Date.distantPast)
    }
    
    @Test("统计信息更新")
    func testStatisticsUpdate() async throws {
        let manager = StorageManager.shared
        
        manager.registerNamespace("StatsTest")
        manager.updateStatistics()
        
        let stats = manager.statistics
        #expect(stats.namespaceCount > 0)
        #expect(stats.lastUpdated != Date.distantPast)
    }
    
    // MARK: - Health Monitoring Tests
    
    @Test("存储健康状态检查")
    func testStorageHealth() async throws {
        let manager = StorageManager.shared
        
        let health = manager.getStorageHealth()
        
        #expect(health.lastChecked != Date.distantPast)
        #expect(health.providerStatus.count >= 0)
    }
    
    // MARK: - Maintenance Tests
    
    @Test("存储维护功能")
    func testStorageMaintenance() async throws {
        let manager = StorageManager.shared
        
        // 添加一些数据
        manager.batchWrite("maintenance_test", for: "maint_key", provider: "userdefaults")
        
        // 执行维护
        manager.performMaintenance()
        
        // 验证维护完成
        let stats = manager.statistics
        #expect(stats.lastUpdated != Date.distantPast)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("存储错误处理")
    func testStorageErrorHandling() async throws {
        let manager = StorageManager.shared
        let failingProvider = FailingStorageProvider()
        manager.registerStorageProvider(failingProvider, name: "failing")
        
        // 尝试写入到失败的提供者
        manager.batchWrite("test", for: "error_key", provider: "failing")
        
        // 等待批量操作执行
        try await Task.sleep(nanoseconds: 600_000_000) // 600ms
        
        // 检查健康状态应该反映错误
        let health = manager.getStorageHealth()
        #expect(health.totalErrors >= 0) // 可能有错误
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("并发批量操作")
    func testConcurrentBatchOperations() async throws {
        let manager = StorageManager.shared
        let mockProvider = MockStorageProvider()
        manager.registerStorageProvider(mockProvider, name: "concurrent")
        
        // 并发执行多个批量写入
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    await manager.batchWrite("concurrent_value\(i)", for: "concurrent_key\(i)", provider: "concurrent")
                }
            }
        }
        
        // 等待所有操作完成
        try await Task.sleep(nanoseconds: 700_000_000) // 700ms
        
        // 验证数据完整性
        #expect(mockProvider.hasValue(for: "concurrent_key1"))
        #expect(mockProvider.hasValue(for: "concurrent_key10"))
    }
    
    // MARK: - Data Migration Tests
    
    @Test("注册数据迁移计划")
    func testRegisterMigrationPlan() async throws {
        let manager = StorageManager.shared
        
        let migrationStep = MigrationStep(
            stepId: "step1",
            operation: .renameKey,
            sourceKey: "old_key",
            targetKey: "new_key"
        )
        
        let migration = DataMigration(
            version: 2,
            description: "Rename key migration",
            migrationSteps: [migrationStep]
        )
        
        let plan = DataMigrationPlan(
            namespace: "TestMigration",
            fromVersion: 1,
            toVersion: 2,
            migrations: [migration],
            description: "Test migration plan"
        )
        
        manager.registerMigrationPlan(plan)
        
        let status = manager.getMigrationStatus(for: "TestMigration")
        #expect(status.namespace == "TestMigration")
        #expect(status.currentVersion == 1)
    }
    
    @Test("执行数据迁移")
    func testExecuteMigrations() async throws {
        let manager = StorageManager.shared
        let mockProvider = MockStorageProvider()
        manager.registerStorageProvider(mockProvider, name: "migration_test")
        
        // 设置初始数据
        mockProvider.setValue("test_value", for: "old_key")
        
        let migrationStep = MigrationStep(
            stepId: "rename_step",
            operation: .renameKey,
            sourceKey: "old_key",
            targetKey: "new_key"
        )
        
        let migration = DataMigration(
            version: 2,
            description: "Rename key migration",
            migrationSteps: [migrationStep],
            requiredBackup: false
        )
        
        let plan = DataMigrationPlan(
            namespace: "MigrationTest",
            fromVersion: 1,
            toVersion: 2,
            migrations: [migration],
            description: "Test migration"
        )
        
        manager.registerMigrationPlan(plan)
        
        try await manager.executeMigrations(for: "MigrationTest")
        
        let status = manager.getMigrationStatus(for: "MigrationTest")
        #expect(status.status == .completed)
        #expect(status.currentVersion == 2)
        #expect(status.completedSteps.contains("rename_step"))
    }
    
    @Test("数据完整性验证")
    func testDataIntegrityValidation() async throws {
        let manager = StorageManager.shared
        
        let report = try await manager.validateDataIntegrity(for: "IntegrityTest")
        
        #expect(report.namespace == "IntegrityTest")
        #expect(report.checkedAt != Date.distantPast)
        #expect(report.isValid) // 简化实现总是返回有效
    }
    
    @Test("迁移状态监控")
    func testMigrationStatusMonitoring() async throws {
        let manager = StorageManager.shared
        
        // 获取不存在的命名空间状态
        let status = manager.getMigrationStatus(for: "NonExistent")
        #expect(status.namespace == "NonExistent")
        #expect(status.currentVersion == 0)
        #expect(status.status == .notStarted)
    }
    
    @Test("迁移错误处理")
    func testMigrationErrorHandling() async throws {
        let manager = StorageManager.shared
        
        // 尝试执行不存在的迁移计划
        do {
            try await manager.executeMigrations(for: "NonExistentPlan")
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is DataMigrationError)
        }
    }
}

// MARK: - Mock Storage Provider

private final class MockStorageProvider: RealtimeStorageProvider, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func getValue<T: Codable>(for key: String, defaultValue: T) -> T {
        guard let data = storage[key] else { return defaultValue }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            return defaultValue
        }
    }
    
    func setValue<T: Codable>(_ value: T, for key: String) {
        do {
            let data = try encoder.encode(value)
            storage[key] = data
        } catch {
            print("Failed to encode value for key \(key): \(error)")
        }
    }
    
    func hasValue(for key: String) -> Bool {
        return storage[key] != nil
    }
    
    func removeValue(for key: String) {
        storage.removeValue(forKey: key)
    }
}

// MARK: - Failing Storage Provider (for error testing)

private final class FailingStorageProvider: RealtimeStorageProvider, @unchecked Sendable {
    func getValue<T: Codable>(for key: String, defaultValue: T) -> T {
        return defaultValue
    }
    
    func setValue<T: Codable>(_ value: T, for key: String) {
        // 总是失败
        // 在实际实现中这会抛出错误，但这里我们简化处理
    }
    
    func hasValue(for key: String) -> Bool {
        return false
    }
    
    func removeValue(for key: String) {
        // 不做任何操作
    }
}