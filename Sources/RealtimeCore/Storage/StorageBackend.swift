import Foundation
import Security

/// 存储后端协议，定义统一的存储接口
/// 需求: 18.4, 18.5, 18.9, 18.11
public protocol StorageBackend: AnyObject {
    /// 存储后端名称
    var name: String { get }
    
    /// 检查后端是否可用
    var isAvailable: Bool { get }
    
    /// 异步存储值
    func setValue<T: Codable>(_ value: T, for key: String) async throws
    
    /// 异步获取值
    func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T?
    
    /// 检查键是否存在
    func hasValue(for key: String) async throws -> Bool
    
    /// 删除值
    func removeValue(for key: String) async throws
    
    /// 清除所有数据
    func clearAll() async throws
    
    /// 获取所有键
    func getAllKeys() async throws -> [String]
    
    /// 批量操作支持
    func setBatch<T: Codable>(_ values: [String: T]) async throws
    func getBatch<T: Codable>(keys: [String], type: T.Type) async throws -> [String: T]
    func removeBatch(keys: [String]) async throws
}

/// 存储错误类型
public enum StorageError: Error, LocalizedError {
    case keyNotFound(String)
    case encodingFailed(String, Error)
    case decodingFailed(String, Error)
    case backendUnavailable(String)
    case keychainError(OSStatus)
    case batchOperationFailed([String: Error])
    case invalidKey(String)
    case storageQuotaExceeded
    
    public var errorDescription: String? {
        switch self {
        case .keyNotFound(let key):
            return "Key '\(key)' not found in storage"
        case .encodingFailed(let key, let error):
            return "Failed to encode value for key '\(key)': \(error.localizedDescription)"
        case .decodingFailed(let key, let error):
            return "Failed to decode value for key '\(key)': \(error.localizedDescription)"
        case .backendUnavailable(let name):
            return "Storage backend '\(name)' is not available"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .batchOperationFailed(let errors):
            return "Batch operation failed with \(errors.count) errors"
        case .invalidKey(let key):
            return "Invalid key: '\(key)'"
        case .storageQuotaExceeded:
            return "Storage quota exceeded"
        }
    }
}

/// UserDefaults 存储后端实现
/// 需求: 18.4, 18.9
public class UserDefaultsBackend: StorageBackend {
    public let name = "UserDefaults"
    private let userDefaults: UserDefaults
    private let keyPrefix: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public var isAvailable: Bool {
        return true // UserDefaults 总是可用
    }
    
    public init(userDefaults: UserDefaults = .standard, keyPrefix: String = "RealtimeKit.") {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
        
        // 配置编码器
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    public func setValue<T: Codable>(_ value: T, for key: String) async throws {
        let prefixedKey = keyPrefix + key
        
        do {
            let data = try encoder.encode(value)
            userDefaults.set(data, forKey: prefixedKey)
        } catch {
            throw StorageError.encodingFailed(key, error)
        }
    }
    
    public func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T? {
        let prefixedKey = keyPrefix + key
        
        guard let data = userDefaults.data(forKey: prefixedKey) else {
            return nil
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw StorageError.decodingFailed(key, error)
        }
    }
    
    public func hasValue(for key: String) async throws -> Bool {
        let prefixedKey = keyPrefix + key
        return userDefaults.object(forKey: prefixedKey) != nil
    }
    
    public func removeValue(for key: String) async throws {
        let prefixedKey = keyPrefix + key
        userDefaults.removeObject(forKey: prefixedKey)
    }
    
    public func clearAll() async throws {
        let allKeys = try await getAllKeys()
        for key in allKeys {
            let prefixedKey = keyPrefix + key
            userDefaults.removeObject(forKey: prefixedKey)
        }
    }
    
    public func getAllKeys() async throws -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return allKeys.compactMap { key in
            guard key.hasPrefix(keyPrefix) else { return nil }
            return String(key.dropFirst(keyPrefix.count))
        }
    }
    
    public func setBatch<T: Codable>(_ values: [String: T]) async throws {
        var errors: [String: Error] = [:]
        
        for (key, value) in values {
            do {
                try await setValue(value, for: key)
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
    }
    
    public func getBatch<T: Codable>(keys: [String], type: T.Type) async throws -> [String: T] {
        var result: [String: T] = [:]
        var errors: [String: Error] = [:]
        
        for key in keys {
            do {
                if let value = try await getValue(for: key, type: type) {
                    result[key] = value
                }
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
        
        return result
    }
    
    public func removeBatch(keys: [String]) async throws {
        var errors: [String: Error] = [:]
        
        for key in keys {
            do {
                try await removeValue(for: key)
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
    }
}

/// Keychain 存储后端实现，用于敏感数据
/// 需求: 18.5, 18.9
public class KeychainBackend: StorageBackend {
    public let name = "Keychain"
    private let service: String
    private let accessGroup: String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public var isAvailable: Bool {
        // 检查 Keychain 是否可用
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "availability_test",
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    public init(service: String = "RealtimeKit", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
        
        // 配置编码器
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    public func setValue<T: Codable>(_ value: T, for key: String) async throws {
        guard !key.isEmpty else {
            throw StorageError.invalidKey(key)
        }
        
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw StorageError.encodingFailed(key, error)
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
                throw StorageError.keychainError(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw StorageError.keychainError(updateStatus)
        }
    }
    
    public func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T? {
        guard !key.isEmpty else {
            throw StorageError.invalidKey(key)
        }
        
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
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw StorageError.keychainError(status)
        }
        
        guard let data = result as? Data else {
            throw StorageError.decodingFailed(key, NSError(domain: "KeychainBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid data format"]))
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw StorageError.decodingFailed(key, error)
        }
    }
    
    public func hasValue(for key: String) async throws -> Bool {
        guard !key.isEmpty else {
            throw StorageError.invalidKey(key)
        }
        
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
    
    public func removeValue(for key: String) async throws {
        guard !key.isEmpty else {
            throw StorageError.invalidKey(key)
        }
        
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
            throw StorageError.keychainError(status)
        }
    }
    
    public func clearAll() async throws {
        let allKeys = try await getAllKeys()
        try await removeBatch(keys: allKeys)
    }
    
    public func getAllKeys() async throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return []
        }
        
        guard status == errSecSuccess else {
            throw StorageError.keychainError(status)
        }
        
        guard let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            item[kSecAttrAccount as String] as? String
        }
    }
    
    public func setBatch<T: Codable>(_ values: [String: T]) async throws {
        var errors: [String: Error] = [:]
        
        for (key, value) in values {
            do {
                try await setValue(value, for: key)
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
    }
    
    public func getBatch<T: Codable>(keys: [String], type: T.Type) async throws -> [String: T] {
        var result: [String: T] = [:]
        var errors: [String: Error] = [:]
        
        for key in keys {
            do {
                if let value = try await getValue(for: key, type: type) {
                    result[key] = value
                }
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
        
        return result
    }
    
    public func removeBatch(keys: [String]) async throws {
        var errors: [String: Error] = [:]
        
        for key in keys {
            do {
                try await removeValue(for: key)
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
    }
}

/// Mock 存储后端，用于测试
/// 需求: 18.11
public final class MockStorageBackend: StorageBackend, @unchecked Sendable {
    public let name = "Mock"
    private var storage: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "MockStorageBackend", attributes: .concurrent)
    
    public var isAvailable: Bool = true
    public var shouldFailOperations: Bool = false
    public var operationDelay: TimeInterval = 0
    
    public init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    public func setValue<T: Codable>(_ value: T, for key: String) async throws {
        if shouldFailOperations {
            throw StorageError.backendUnavailable(name)
        }
        
        if operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }
        
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw StorageError.encodingFailed(key, error)
        }
        
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.storage[key] = data
                continuation.resume()
            }
        }
    }
    
    public func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T? {
        if shouldFailOperations {
            throw StorageError.backendUnavailable(name)
        }
        
        if operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }
        
        let data: Data? = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.storage[key])
            }
        }
        
        guard let data = data else {
            return nil
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw StorageError.decodingFailed(key, error)
        }
    }
    
    public func hasValue(for key: String) async throws -> Bool {
        if shouldFailOperations {
            throw StorageError.backendUnavailable(name)
        }
        
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.storage[key] != nil)
            }
        }
    }
    
    public func removeValue(for key: String) async throws {
        if shouldFailOperations {
            throw StorageError.backendUnavailable(name)
        }
        
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.storage.removeValue(forKey: key)
                continuation.resume()
            }
        }
    }
    
    public func clearAll() async throws {
        if shouldFailOperations {
            throw StorageError.backendUnavailable(name)
        }
        
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.storage.removeAll()
                continuation.resume()
            }
        }
    }
    
    public func getAllKeys() async throws -> [String] {
        if shouldFailOperations {
            throw StorageError.backendUnavailable(name)
        }
        
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: Array(self.storage.keys))
            }
        }
    }
    
    public func setBatch<T: Codable>(_ values: [String: T]) async throws {
        var errors: [String: Error] = [:]
        
        for (key, value) in values {
            do {
                try await setValue(value, for: key)
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
    }
    
    public func getBatch<T: Codable>(keys: [String], type: T.Type) async throws -> [String: T] {
        var result: [String: T] = [:]
        var errors: [String: Error] = [:]
        
        for key in keys {
            do {
                if let value = try await getValue(for: key, type: type) {
                    result[key] = value
                }
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
        
        return result
    }
    
    public func removeBatch(keys: [String]) async throws {
        var errors: [String: Error] = [:]
        
        for key in keys {
            do {
                try await removeValue(for: key)
            } catch {
                errors[key] = error
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchOperationFailed(errors)
        }
    }
    
    // MARK: - Testing Utilities
    
    /// 获取存储的原始数据（仅用于测试）
    public func getRawData() -> [String: Data] {
        return storage
    }
    
    /// 设置存储的原始数据（仅用于测试）
    public func setRawData(_ data: [String: Data]) {
        storage = data
    }
}