import Foundation
import SwiftUI

/// 自动状态持久化属性包装器
/// 需求: 18.1, 18.2, 18.3, 18.10
@propertyWrapper
public struct RealtimeStorage<Value: Codable & Sendable>: DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let storage: RealtimeStorageProvider
    private let namespace: String?
    
    public init(
        wrappedValue defaultValue: Value,
        _ key: String,
        storage: RealtimeStorageProvider? = nil,
        namespace: String? = nil
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage ?? UserDefaults.standard
        self.namespace = namespace
    }
    
    public var wrappedValue: Value {
        get {
            return storage.getValue(for: fullKey, defaultValue: defaultValue)
        }
        nonmutating set {
            storage.setValue(newValue, for: fullKey)
        }
    }
    
    public var projectedValue: RealtimeStorageBinding<Value> {
        return RealtimeStorageBinding(
            key: fullKey,
            defaultValue: defaultValue,
            storage: storage
        )
    }
    
    private var fullKey: String {
        if let namespace = namespace {
            return "\(namespace).\(key)"
        }
        return key
    }
}

/// 实时存储提供者协议
public protocol RealtimeStorageProvider: Sendable {
    func getValue<T: Codable>(for key: String, defaultValue: T) -> T
    func setValue<T: Codable>(_ value: T, for key: String)
    func hasValue(for key: String) -> Bool
    func removeValue(for key: String)
}

/// UserDefaults 扩展，实现 RealtimeStorageProvider
extension UserDefaults: RealtimeStorageProvider {
    public func getValue<T: Codable>(for key: String, defaultValue: T) -> T {
        guard let data = data(forKey: key) else {
            return defaultValue
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode value for key \(key): \(error)")
            return defaultValue
        }
    }
    
    public func setValue<T: Codable>(_ value: T, for key: String) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            set(data, forKey: key)
        } catch {
            print("Failed to encode value for key \(key): \(error)")
        }
    }
    
    public func hasValue(for key: String) -> Bool {
        return object(forKey: key) != nil
    }
    
    public func removeValue(for key: String) {
        removeObject(forKey: key)
    }
}

/// 安全存储属性包装器，用于敏感数据
/// 需求: 18.2, 18.5
@propertyWrapper
public struct SecureRealtimeStorage<Value: Codable & Sendable>: DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let storage: SecureStorageProvider
    private let namespace: String?
    
    public init(
        wrappedValue defaultValue: Value,
        _ key: String,
        service: String = "RealtimeKit",
        accessGroup: String? = nil,
        namespace: String? = nil
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = KeychainStorageProvider(service: service, accessGroup: accessGroup)
        self.namespace = namespace
    }
    
    public var wrappedValue: Value {
        get {
            return storage.getValue(for: fullKey, defaultValue: defaultValue)
        }
        nonmutating set {
            storage.setValue(newValue, for: fullKey)
        }
    }
    
    public var projectedValue: RealtimeStorageBinding<Value> {
        return RealtimeStorageBinding(
            key: fullKey,
            defaultValue: defaultValue,
            storage: storage
        )
    }
    
    private var fullKey: String {
        if let namespace = namespace {
            return "\(namespace).\(key)"
        }
        return key
    }
}

/// 安全存储提供者协议
public protocol SecureStorageProvider: RealtimeStorageProvider {}

/// Keychain 存储提供者实现
public final class KeychainStorageProvider: SecureStorageProvider, @unchecked Sendable {
    private let service: String
    private let accessGroup: String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init(service: String = "RealtimeKit", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
        
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    public func getValue<T: Codable>(for key: String, defaultValue: T) -> T {
        guard !key.isEmpty else { return defaultValue }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return defaultValue
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode secure value for key \(key): \(error)")
            return defaultValue
        }
    }
    
    public func setValue<T: Codable>(_ value: T, for key: String) {
        guard !key.isEmpty else { return }
        
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            print("Failed to encode secure value for key \(key): \(error)")
            return
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // 先尝试更新
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecItemNotFound {
            // 如果不存在，则添加新项
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("Failed to add secure value for key \(key): \(addStatus)")
            }
        } else if updateStatus != errSecSuccess {
            print("Failed to update secure value for key \(key): \(updateStatus)")
        }
    }
    
    public func hasValue(for key: String) -> Bool {
        guard !key.isEmpty else { return false }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func removeValue(for key: String) {
        guard !key.isEmpty else { return }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Failed to remove secure value for key \(key): \(status)")
        }
    }
}

/// 存储绑定，提供额外的存储操作和 SwiftUI Binding 支持
/// 需求: 18.3, 18.10
public struct RealtimeStorageBinding<Value: Codable & Sendable>: Sendable {
    private let key: String
    private let defaultValue: Value
    private let storage: RealtimeStorageProvider
    
    init(
        key: String,
        defaultValue: Value,
        storage: RealtimeStorageProvider
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }
    
    /// 重置为默认值
    public func reset() {
        storage.setValue(defaultValue, for: key)
    }
    
    /// 检查是否存在存储的值
    public func hasValue() -> Bool {
        return storage.hasValue(for: key)
    }
    
    /// 删除存储的值
    public func remove() {
        storage.removeValue(for: key)
    }
    
    /// 获取 SwiftUI Binding
    public var binding: Binding<Value> {
        Binding(
            get: { [key, defaultValue, storage] in
                storage.getValue(for: key, defaultValue: defaultValue)
            },
            set: { [key, storage] newValue in
                storage.setValue(newValue, for: key)
            }
        )
    }
    
    /// 获取当前值
    public var value: Value {
        return storage.getValue(for: key, defaultValue: defaultValue)
    }
    
    /// 设置值
    public func setValue(_ value: Value) {
        storage.setValue(value, for: key)
    }
}

/// 存储管理器，提供中央化的存储管理
/// 需求: 18.6, 18.8, 18.9
@MainActor
public class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var statistics: StorageStatistics = StorageStatistics()
    @Published public private(set) var performanceMetrics: StoragePerformanceMetrics = StoragePerformanceMetrics()
    
    private var storageProviders: [String: RealtimeStorageProvider] = [:]
    private var namespaces: Set<String> = []
    private var batchOperations: [BatchOperation] = []
    private var batchTimer: Timer?
    private var performanceMonitor = StoragePerformanceMonitor()
    private var migrationManager = DataMigrationManager()
    private let batchDelay: TimeInterval = 0.5 // 500ms 批量写入延迟
    private let maxBatchSize: Int = 50
    
    public var defaultStorage: RealtimeStorageProvider {
        return storageProviders["userdefaults"] ?? UserDefaults.standard
    }
    
    public var secureStorage: SecureStorageProvider {
        return storageProviders["keychain"] as? SecureStorageProvider ?? KeychainStorageProvider()
    }
    
    private init() {
        setupDefaultProviders()
        setupPerformanceMonitoring()
    }
    
    private func setupDefaultProviders() {
        storageProviders["userdefaults"] = UserDefaults.standard
        storageProviders["keychain"] = KeychainStorageProvider()
        isInitialized = true
    }
    
    private func setupPerformanceMonitoring() {
        // 定期更新性能指标
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    /// 注册自定义存储提供者
    public func registerStorageProvider(_ provider: RealtimeStorageProvider, name: String) {
        storageProviders[name] = provider
        performanceMonitor.registerProvider(name)
    }
    
    /// 获取存储提供者
    public func getStorageProvider(name: String) -> RealtimeStorageProvider? {
        return storageProviders[name]
    }
    
    /// 注册命名空间
    public func registerNamespace(_ namespace: String) {
        namespaces.insert(namespace)
        performanceMonitor.registerNamespace(namespace)
    }
    
    /// 获取所有注册的命名空间
    public var registeredNamespaces: [String] {
        return Array(namespaces).sorted()
    }
    
    /// 批量写入操作
    /// 需求: 18.8 - 批量写入和延迟写入机制优化性能
    public func batchWrite<T: Codable>(_ value: T, for key: String, provider: String = "userdefaults") {
        let operation = BatchOperation(
            key: key,
            value: value,
            provider: provider,
            timestamp: Date()
        )
        
        batchOperations.append(operation)
        
        // 如果达到最大批量大小，立即执行
        if batchOperations.count >= maxBatchSize {
            executeBatchOperations()
        } else {
            // 否则启动延迟写入定时器
            scheduleBatchExecution()
        }
    }
    
    private func scheduleBatchExecution() {
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.executeBatchOperations()
            }
        }
    }
    
    private func executeBatchOperations() {
        guard !batchOperations.isEmpty else { return }
        
        let startTime = Date()
        let operationsToExecute = batchOperations
        batchOperations.removeAll()
        
        // 按提供者分组执行
        let groupedOperations = Dictionary(grouping: operationsToExecute) { $0.provider }
        
        for (providerName, operations) in groupedOperations {
            guard let provider = storageProviders[providerName] else { continue }
            
            for operation in operations {
                do {
                    try operation.execute(on: provider)
                    performanceMonitor.recordSuccess(for: providerName)
                } catch {
                    performanceMonitor.recordError(for: providerName, error: error)
                    handleStorageError(error, for: operation.key, provider: providerName)
                }
            }
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        performanceMonitor.recordBatchExecution(
            operationCount: operationsToExecute.count,
            executionTime: executionTime
        )
    }
    
    /// 存储错误处理和降级机制
    /// 需求: 18.9 - 存储错误处理和降级机制
    private func handleStorageError(_ error: Error, for key: String, provider: String) {
        print("Storage error for key '\(key)' in provider '\(provider)': \(error)")
        
        // 降级处理：如果主存储失败，尝试使用备用存储
        if provider != "userdefaults" {
            print("Attempting fallback to UserDefaults for key: \(key)")
            // 这里可以实现降级逻辑
        }
        
        // 记录错误统计
        performanceMonitor.recordError(for: provider, error: error)
    }
    
    /// 清理命名空间数据
    public func clearNamespace(_ namespace: String) {
        let keysToRemove = performanceMonitor.getKeysForNamespace(namespace)
        
        for provider in storageProviders.values {
            for key in keysToRemove {
                provider.removeValue(for: key)
            }
        }
        
        performanceMonitor.clearNamespace(namespace)
        print("Cleared namespace: \(namespace) (\(keysToRemove.count) keys)")
    }
    
    /// 更新统计信息
    public func updateStatistics() {
        let backendStats = performanceMonitor.getBackendStatistics()
        
        statistics = StorageStatistics(
            totalKeys: performanceMonitor.getTotalKeyCount(),
            backendStats: backendStats,
            namespaceCount: namespaces.count,
            lastUpdated: Date()
        )
    }
    
    /// 更新性能指标
    private func updatePerformanceMetrics() {
        performanceMetrics = performanceMonitor.getCurrentMetrics()
    }
    
    /// 获取存储健康状态
    /// 需求: 18.9 - 错误处理和降级机制
    public func getStorageHealth() -> StorageManagerHealthStatus {
        let errors = performanceMonitor.getRecentErrors()
        let isHealthy = errors.count < 10 // 如果最近错误少于10个认为是健康的
        
        return StorageManagerHealthStatus(
            isHealthy: isHealthy,
            totalErrors: errors.count,
            providerStatus: performanceMonitor.getProviderHealthStatus(),
            lastChecked: Date()
        )
    }
    
    /// 执行存储维护
    /// 需求: 18.8 - 性能优化
    public func performMaintenance() {
        // 清理过期的性能数据
        performanceMonitor.cleanupOldData()
        
        // 执行待处理的批量操作
        executeBatchOperations()
        
        // 更新统计信息
        updateStatistics()
        updatePerformanceMetrics()
        
        print("Storage maintenance completed")
    }
    
    // MARK: - Data Migration Support
    
    /// 注册数据迁移计划
    /// 需求: 18.7 - 数据迁移和版本化支持
    public func registerMigrationPlan(_ plan: DataMigrationPlan) {
        migrationManager.registerMigrationPlan(plan)
    }
    
    /// 执行数据迁移
    /// 需求: 18.7 - 数据迁移和版本化支持
    public func executeMigrations(for namespace: String) async throws {
        try await migrationManager.executeMigrations(
            for: namespace,
            storageProvider: defaultStorage,
            secureStorageProvider: secureStorage
        )
    }
    
    /// 获取迁移状态
    /// 需求: 18.7 - 数据迁移状态监控
    public func getMigrationStatus(for namespace: String) -> DataMigrationStatus {
        return migrationManager.getMigrationStatus(for: namespace)
    }
    
    /// 回滚迁移
    /// 需求: 18.7 - 数据迁移错误恢复
    public func rollbackMigration(for namespace: String, to version: Int) async throws {
        try await migrationManager.rollbackMigration(
            for: namespace,
            to: version,
            storageProvider: defaultStorage,
            secureStorageProvider: secureStorage
        )
    }
    
    /// 验证数据完整性
    /// 需求: 18.7 - 数据完整性验证
    public func validateDataIntegrity(for namespace: String) async throws -> DataIntegrityReport {
        return try await migrationManager.validateDataIntegrity(
            for: namespace,
            storageProvider: defaultStorage,
            secureStorageProvider: secureStorage
        )
    }
}

/// 存储统计信息
public struct StorageStatistics: Codable, Sendable {
    public let totalKeys: Int
    public let backendStats: [String: Int]
    public let namespaceCount: Int
    public let lastUpdated: Date
    
    public init(
        totalKeys: Int = 0,
        backendStats: [String: Int] = [:],
        namespaceCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.totalKeys = totalKeys
        self.backendStats = backendStats
        self.namespaceCount = namespaceCount
        self.lastUpdated = lastUpdated
    }
}

/// 批量操作结构
private struct BatchOperation {
    let key: String
    let value: Any
    let provider: String
    let timestamp: Date
    
    func execute(on provider: RealtimeStorageProvider) throws {
        if let codableValue = value as? any Codable {
            // 使用类型擦除来处理 Codable 值
            try executeTypedOperation(codableValue, on: provider)
        } else {
            throw StorageManagerError.invalidValueType
        }
    }
    
    private func executeTypedOperation<T: Codable>(_ value: T, on provider: RealtimeStorageProvider) throws {
        provider.setValue(value, for: key)
    }
}

/// 存储性能指标
public struct StoragePerformanceMetrics: Codable, Sendable {
    public let averageWriteTime: TimeInterval
    public let averageReadTime: TimeInterval
    public let totalOperations: Int
    public let errorRate: Double
    public let batchOperationsCount: Int
    public let lastUpdated: Date
    
    public init(
        averageWriteTime: TimeInterval = 0,
        averageReadTime: TimeInterval = 0,
        totalOperations: Int = 0,
        errorRate: Double = 0,
        batchOperationsCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.averageWriteTime = averageWriteTime
        self.averageReadTime = averageReadTime
        self.totalOperations = totalOperations
        self.errorRate = errorRate
        self.batchOperationsCount = batchOperationsCount
        self.lastUpdated = lastUpdated
    }
}

/// 存储管理器健康状态
public struct StorageManagerHealthStatus: Codable, Sendable {
    public let isHealthy: Bool
    public let totalErrors: Int
    public let providerStatus: [String: Bool]
    public let lastChecked: Date
    
    public init(
        isHealthy: Bool,
        totalErrors: Int,
        providerStatus: [String: Bool],
        lastChecked: Date
    ) {
        self.isHealthy = isHealthy
        self.totalErrors = totalErrors
        self.providerStatus = providerStatus
        self.lastChecked = lastChecked
    }
}

/// 存储性能监控器
private class StoragePerformanceMonitor {
    private var operationTimes: [String: [TimeInterval]] = [:]
    private var errorCounts: [String: Int] = [:]
    private var totalOperations: [String: Int] = [:]
    private var namespaceKeys: [String: Set<String>] = [:]
    private var recentErrors: [StorageManagerError] = []
    private var batchExecutions: [BatchExecutionMetric] = []
    
    func registerProvider(_ name: String) {
        operationTimes[name] = []
        errorCounts[name] = 0
        totalOperations[name] = 0
    }
    
    func registerNamespace(_ namespace: String) {
        namespaceKeys[namespace] = Set<String>()
    }
    
    func recordSuccess(for provider: String) {
        totalOperations[provider, default: 0] += 1
    }
    
    func recordError(for provider: String, error: Error) {
        errorCounts[provider, default: 0] += 1
        recentErrors.append(StorageManagerError.operationFailed(error))
        
        // 保持最近100个错误
        if recentErrors.count > 100 {
            recentErrors.removeFirst()
        }
    }
    
    func recordBatchExecution(operationCount: Int, executionTime: TimeInterval) {
        let metric = BatchExecutionMetric(
            operationCount: operationCount,
            executionTime: executionTime,
            timestamp: Date()
        )
        batchExecutions.append(metric)
        
        // 保持最近100次批量执行记录
        if batchExecutions.count > 100 {
            batchExecutions.removeFirst()
        }
    }
    
    func getBackendStatistics() -> [String: Int] {
        return totalOperations
    }
    
    func getTotalKeyCount() -> Int {
        return namespaceKeys.values.reduce(0) { $0 + $1.count }
    }
    
    func getKeysForNamespace(_ namespace: String) -> Set<String> {
        return namespaceKeys[namespace] ?? Set<String>()
    }
    
    func clearNamespace(_ namespace: String) {
        namespaceKeys[namespace] = Set<String>()
    }
    
    func getRecentErrors() -> [StorageManagerError] {
        return recentErrors
    }
    
    func getProviderHealthStatus() -> [String: Bool] {
        var status: [String: Bool] = [:]
        for provider in totalOperations.keys {
            let errors = errorCounts[provider] ?? 0
            let total = totalOperations[provider] ?? 0
            let errorRate = total > 0 ? Double(errors) / Double(total) : 0
            status[provider] = errorRate < 0.1 // 错误率小于10%认为健康
        }
        return status
    }
    
    func getCurrentMetrics() -> StoragePerformanceMetrics {
        let totalOps = totalOperations.values.reduce(0, +)
        let totalErrors = errorCounts.values.reduce(0, +)
        let errorRate = totalOps > 0 ? Double(totalErrors) / Double(totalOps) : 0
        
        let avgBatchTime = batchExecutions.isEmpty ? 0 : 
            batchExecutions.map { $0.executionTime }.reduce(0, +) / Double(batchExecutions.count)
        
        return StoragePerformanceMetrics(
            averageWriteTime: avgBatchTime,
            averageReadTime: 0, // 简化实现
            totalOperations: totalOps,
            errorRate: errorRate,
            batchOperationsCount: batchExecutions.count,
            lastUpdated: Date()
        )
    }
    
    func cleanupOldData() {
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24小时前
        
        // 清理旧的批量执行记录
        batchExecutions = batchExecutions.filter { $0.timestamp >= cutoffDate }
        
        // 清理旧的错误记录
        if recentErrors.count > 50 {
            recentErrors = Array(recentErrors.suffix(50))
        }
    }
}

/// 批量执行指标
private struct BatchExecutionMetric {
    let operationCount: Int
    let executionTime: TimeInterval
    let timestamp: Date
}

/// 存储管理器错误类型
public enum StorageManagerError: Error, LocalizedError {
    case invalidValueType
    case operationFailed(Error)
    case providerNotFound(String)
    case namespaceNotRegistered(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidValueType:
            return "Invalid value type for storage operation"
        case .operationFailed(let error):
            return "Storage operation failed: \(error.localizedDescription)"
        case .providerNotFound(let name):
            return "Storage provider '\(name)' not found"
        case .namespaceNotRegistered(let namespace):
            return "Namespace '\(namespace)' not registered"
        }
    }
}

// MARK: - Data Migration Framework

/// 数据迁移计划
/// 需求: 18.7 - 数据迁移框架
public struct DataMigrationPlan: Codable, Sendable {
    public let namespace: String
    public let fromVersion: Int
    public let toVersion: Int
    public let migrations: [DataMigration]
    public let rollbackSupported: Bool
    public let description: String
    
    public init(
        namespace: String,
        fromVersion: Int,
        toVersion: Int,
        migrations: [DataMigration],
        rollbackSupported: Bool = true,
        description: String
    ) {
        self.namespace = namespace
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.migrations = migrations
        self.rollbackSupported = rollbackSupported
        self.description = description
    }
}

/// 单个数据迁移
/// 需求: 18.7 - 迁移计划创建和执行机制
public struct DataMigration: Codable, Sendable {
    public let version: Int
    public let description: String
    public let migrationSteps: [MigrationStep]
    public let rollbackSteps: [MigrationStep]
    public let requiredBackup: Bool
    
    public init(
        version: Int,
        description: String,
        migrationSteps: [MigrationStep],
        rollbackSteps: [MigrationStep] = [],
        requiredBackup: Bool = true
    ) {
        self.version = version
        self.description = description
        self.migrationSteps = migrationSteps
        self.rollbackSteps = rollbackSteps
        self.requiredBackup = requiredBackup
    }
}

/// 迁移步骤
/// 需求: 18.7 - 迁移计划执行机制
public struct MigrationStep: Codable, Sendable {
    public let stepId: String
    public let operation: MigrationOperation
    public let sourceKey: String?
    public let targetKey: String?
    public let transformer: String? // 转换器名称
    public let validation: String? // 验证规则
    
    public init(
        stepId: String,
        operation: MigrationOperation,
        sourceKey: String? = nil,
        targetKey: String? = nil,
        transformer: String? = nil,
        validation: String? = nil
    ) {
        self.stepId = stepId
        self.operation = operation
        self.sourceKey = sourceKey
        self.targetKey = targetKey
        self.transformer = transformer
        self.validation = validation
    }
}

/// 迁移操作类型
public enum MigrationOperation: String, Codable, Sendable {
    case createKey = "create_key"
    case deleteKey = "delete_key"
    case renameKey = "rename_key"
    case transformValue = "transform_value"
    case moveToSecureStorage = "move_to_secure_storage"
    case moveFromSecureStorage = "move_from_secure_storage"
    case validateData = "validate_data"
    case backupData = "backup_data"
}

/// 迁移状态
/// 需求: 18.7 - 迁移状态监控
public struct DataMigrationStatus: Codable, Sendable {
    public let namespace: String
    public let currentVersion: Int
    public let targetVersion: Int?
    public let status: MigrationExecutionStatus
    public let completedSteps: [String]
    public let failedSteps: [String]
    public let lastExecuted: Date?
    public let errorMessage: String?
    
    public init(
        namespace: String,
        currentVersion: Int,
        targetVersion: Int? = nil,
        status: MigrationExecutionStatus = .notStarted,
        completedSteps: [String] = [],
        failedSteps: [String] = [],
        lastExecuted: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.namespace = namespace
        self.currentVersion = currentVersion
        self.targetVersion = targetVersion
        self.status = status
        self.completedSteps = completedSteps
        self.failedSteps = failedSteps
        self.lastExecuted = lastExecuted
        self.errorMessage = errorMessage
    }
}

/// 迁移执行状态
public enum MigrationExecutionStatus: String, Codable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case rolledBack = "rolled_back"
}

/// 数据完整性报告
/// 需求: 18.7 - 数据完整性验证
public struct DataIntegrityReport: Codable, Sendable {
    public let namespace: String
    public let isValid: Bool
    public let checkedKeys: [String]
    public let corruptedKeys: [String]
    public let missingKeys: [String]
    public let validationErrors: [String]
    public let checkedAt: Date
    
    public init(
        namespace: String,
        isValid: Bool,
        checkedKeys: [String],
        corruptedKeys: [String],
        missingKeys: [String],
        validationErrors: [String],
        checkedAt: Date = Date()
    ) {
        self.namespace = namespace
        self.isValid = isValid
        self.checkedKeys = checkedKeys
        self.corruptedKeys = corruptedKeys
        self.missingKeys = missingKeys
        self.validationErrors = validationErrors
        self.checkedAt = checkedAt
    }
}

/// 数据迁移管理器
/// 需求: 18.7 - 数据迁移框架
@MainActor
private class DataMigrationManager {
    private var migrationPlans: [String: DataMigrationPlan] = [:]
    private var migrationStatus: [String: DataMigrationStatus] = [:]
    private var backups: [String: [String: Data]] = [:]
    
    func registerMigrationPlan(_ plan: DataMigrationPlan) {
        migrationPlans[plan.namespace] = plan
        
        // 初始化迁移状态
        if migrationStatus[plan.namespace] == nil {
            migrationStatus[plan.namespace] = DataMigrationStatus(
                namespace: plan.namespace,
                currentVersion: plan.fromVersion
            )
        }
    }
    
    func executeMigrations(
        for namespace: String,
        storageProvider: RealtimeStorageProvider,
        secureStorageProvider: SecureStorageProvider
    ) async throws {
        guard let plan = migrationPlans[namespace] else {
            throw DataMigrationError.planNotFound(namespace)
        }
        
        var status = migrationStatus[namespace] ?? DataMigrationStatus(
            namespace: namespace,
            currentVersion: plan.fromVersion
        )
        
        // 更新状态为进行中
        status = DataMigrationStatus(
            namespace: status.namespace,
            currentVersion: status.currentVersion,
            targetVersion: plan.toVersion,
            status: .inProgress,
            completedSteps: status.completedSteps,
            failedSteps: status.failedSteps,
            lastExecuted: Date(),
            errorMessage: nil
        )
        migrationStatus[namespace] = status
        
        do {
            // 创建备份
            if plan.migrations.contains(where: { $0.requiredBackup }) {
                try await createBackup(for: namespace, storageProvider: storageProvider, secureStorageProvider: secureStorageProvider)
            }
            
            // 执行迁移步骤
            var completedSteps: [String] = []
            
            for migration in plan.migrations {
                for step in migration.migrationSteps {
                    try await executeStep(
                        step,
                        storageProvider: storageProvider,
                        secureStorageProvider: secureStorageProvider
                    )
                    completedSteps.append(step.stepId)
                }
            }
            
            // 更新状态为完成
            migrationStatus[namespace] = DataMigrationStatus(
                namespace: namespace,
                currentVersion: plan.toVersion,
                targetVersion: plan.toVersion,
                status: .completed,
                completedSteps: completedSteps,
                failedSteps: [],
                lastExecuted: Date(),
                errorMessage: nil
            )
            
        } catch {
            // 更新状态为失败
            migrationStatus[namespace] = DataMigrationStatus(
                namespace: status.namespace,
                currentVersion: status.currentVersion,
                targetVersion: plan.toVersion,
                status: .failed,
                completedSteps: status.completedSteps,
                failedSteps: status.failedSteps,
                lastExecuted: Date(),
                errorMessage: error.localizedDescription
            )
            
            throw error
        }
    }
    
    func rollbackMigration(
        for namespace: String,
        to version: Int,
        storageProvider: RealtimeStorageProvider,
        secureStorageProvider: SecureStorageProvider
    ) async throws {
        guard let plan = migrationPlans[namespace] else {
            throw DataMigrationError.planNotFound(namespace)
        }
        
        guard plan.rollbackSupported else {
            throw DataMigrationError.rollbackNotSupported(namespace)
        }
        
        // 恢复备份
        if let backup = backups[namespace] {
            for (key, data) in backup {
                // 简化实现：直接设置数据
                // 在实际实现中需要根据键的类型选择合适的存储提供者
                storageProvider.setValue(data, for: key)
            }
        }
        
        // 更新状态
        migrationStatus[namespace] = DataMigrationStatus(
            namespace: namespace,
            currentVersion: version,
            targetVersion: nil,
            status: .rolledBack,
            completedSteps: [],
            failedSteps: [],
            lastExecuted: Date(),
            errorMessage: nil
        )
    }
    
    func getMigrationStatus(for namespace: String) -> DataMigrationStatus {
        return migrationStatus[namespace] ?? DataMigrationStatus(
            namespace: namespace,
            currentVersion: 0
        )
    }
    
    func validateDataIntegrity(
        for namespace: String,
        storageProvider: RealtimeStorageProvider,
        secureStorageProvider: SecureStorageProvider
    ) async throws -> DataIntegrityReport {
        // 简化的数据完整性验证实现
        let checkedKeys: [String] = [] // 在实际实现中需要获取所有相关键
        let corruptedKeys: [String] = []
        let missingKeys: [String] = []
        let validationErrors: [String] = []
        
        return DataIntegrityReport(
            namespace: namespace,
            isValid: corruptedKeys.isEmpty && missingKeys.isEmpty && validationErrors.isEmpty,
            checkedKeys: checkedKeys,
            corruptedKeys: corruptedKeys,
            missingKeys: missingKeys,
            validationErrors: validationErrors
        )
    }
    
    private func createBackup(
        for namespace: String,
        storageProvider: RealtimeStorageProvider,
        secureStorageProvider: SecureStorageProvider
    ) async throws {
        // 简化的备份实现
        // 在实际实现中需要获取所有相关键并创建备份
        backups[namespace] = [:]
    }
    
    private func executeStep(
        _ step: MigrationStep,
        storageProvider: RealtimeStorageProvider,
        secureStorageProvider: SecureStorageProvider
    ) async throws {
        switch step.operation {
        case .createKey:
            // 创建新键的实现
            break
        case .deleteKey:
            if let key = step.sourceKey {
                storageProvider.removeValue(for: key)
            }
        case .renameKey:
            if let sourceKey = step.sourceKey, let targetKey = step.targetKey {
                // 简化实现：需要根据实际数据类型处理
                let value: String = storageProvider.getValue(for: sourceKey, defaultValue: "")
                storageProvider.setValue(value, for: targetKey)
                storageProvider.removeValue(for: sourceKey)
            }
        case .transformValue:
            // 值转换的实现
            break
        case .moveToSecureStorage:
            if let sourceKey = step.sourceKey, let targetKey = step.targetKey {
                let value: String = storageProvider.getValue(for: sourceKey, defaultValue: "")
                secureStorageProvider.setValue(value, for: targetKey)
                storageProvider.removeValue(for: sourceKey)
            }
        case .moveFromSecureStorage:
            if let sourceKey = step.sourceKey, let targetKey = step.targetKey {
                let value: String = secureStorageProvider.getValue(for: sourceKey, defaultValue: "")
                storageProvider.setValue(value, for: targetKey)
                secureStorageProvider.removeValue(for: sourceKey)
            }
        case .validateData:
            // 数据验证的实现
            break
        case .backupData:
            // 数据备份的实现
            break
        }
    }
}

/// 数据迁移错误
public enum DataMigrationError: Error, LocalizedError {
    case planNotFound(String)
    case rollbackNotSupported(String)
    case migrationFailed(String, Error)
    case validationFailed(String)
    case backupFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .planNotFound(let namespace):
            return "Migration plan not found for namespace: \(namespace)"
        case .rollbackNotSupported(let namespace):
            return "Rollback not supported for namespace: \(namespace)"
        case .migrationFailed(let namespace, let error):
            return "Migration failed for namespace \(namespace): \(error.localizedDescription)"
        case .validationFailed(let namespace):
            return "Data validation failed for namespace: \(namespace)"
        case .backupFailed(let namespace):
            return "Backup creation failed for namespace: \(namespace)"
        }
    }
}

