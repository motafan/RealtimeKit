// StorageProtocol.swift
// Core storage protocols for RealtimeKit

import Foundation

/// Protocol for persistent storage operations
public protocol StorageProvider: AnyObject {
    
    /// Store a value for the given key
    /// - Parameters:
    ///   - value: Value to store
    ///   - key: Storage key
    func setValue<T: Codable>(_ value: T, forKey key: String) throws
    
    /// Retrieve a value for the given key
    /// - Parameters:
    ///   - type: Type of value to retrieve
    ///   - key: Storage key
    /// - Returns: Stored value or nil if not found
    func getValue<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    
    /// Remove value for the given key
    /// - Parameter key: Storage key
    func removeValue(forKey key: String) throws
    
    /// Check if a key exists in storage
    /// - Parameter key: Storage key
    /// - Returns: True if key exists
    func hasValue(forKey key: String) -> Bool
    
    /// Clear all stored values
    func clearAll() throws
}

/// UserDefaults-based storage provider
public final class UserDefaultsStorageProvider: StorageProvider {
    
    private let userDefaults: UserDefaults
    private let keyPrefix: String
    
    /// Initialize with UserDefaults instance and key prefix
    /// - Parameters:
    ///   - userDefaults: UserDefaults instance to use
    ///   - keyPrefix: Prefix for all storage keys
    public init(userDefaults: UserDefaults = .standard, keyPrefix: String = "RealtimeKit.") {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
    }
    
    public func setValue<T: Codable>(_ value: T, forKey key: String) throws {
        let prefixedKey = keyPrefix + key
        
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: prefixedKey)
        } catch {
            throw RealtimeError.storageError("Failed to encode value for key '\(key)': \(error.localizedDescription)")
        }
    }
    
    public func getValue<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        let prefixedKey = keyPrefix + key
        
        guard let data = userDefaults.data(forKey: prefixedKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw RealtimeError.dataCorrupted("Failed to decode value for key '\(key)': \(error.localizedDescription)")
        }
    }
    
    public func removeValue(forKey key: String) throws {
        let prefixedKey = keyPrefix + key
        userDefaults.removeObject(forKey: prefixedKey)
    }
    
    public func hasValue(forKey key: String) -> Bool {
        let prefixedKey = keyPrefix + key
        return userDefaults.object(forKey: prefixedKey) != nil
    }
    
    public func clearAll() throws {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(keyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }
}