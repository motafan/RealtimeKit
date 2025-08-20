// RealtimeStorage.swift
// Property wrapper for persistent storage similar to SwiftUI's AppStorage

import Foundation
import Combine

/// Property wrapper for persistent storage with automatic synchronization
/// Similar to SwiftUI's @AppStorage but with RealtimeKit-specific features
@propertyWrapper
public struct RealtimeStorage<Value: Codable> {
    
    private let key: String
    private let defaultValue: Value
    private let storage: StorageProvider
    private var subject: CurrentValueSubject<Value, Never>
    
    /// Initialize RealtimeStorage with key and default value
    /// - Parameters:
    ///   - key: Storage key
    ///   - defaultValue: Default value if no stored value exists
    ///   - storage: Storage provider to use
    public init(
        _ key: String,
        defaultValue: Value,
        storage: StorageProvider = UserDefaultsStorageProvider()
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
        
        // Load initial value from storage
        let initialValue: Value
        do {
            initialValue = try storage.getValue(Value.self, forKey: key) ?? defaultValue
        } catch {
            print("RealtimeStorage: Failed to load value for key '\(key)': \(error)")
            initialValue = defaultValue
        }
        
        self.subject = CurrentValueSubject<Value, Never>(initialValue)
    }
    
    /// The wrapped value with automatic persistence
    public var wrappedValue: Value {
        get {
            return subject.value
        }
        set {
            // Update in-memory value
            subject.send(newValue)
            
            // Persist to storage
            do {
                try storage.setValue(newValue, forKey: key)
            } catch {
                print("RealtimeStorage: Failed to save value for key '\(key)': \(error)")
            }
        }
    }
    
    /// Publisher for observing value changes
    public var projectedValue: AnyPublisher<Value, Never> {
        return subject.eraseToAnyPublisher()
    }
    
    /// Reset to default value
    public mutating func reset() {
        wrappedValue = defaultValue
    }
    
    /// Remove value from storage (will use default value)
    public mutating func remove() {
        do {
            try storage.removeValue(forKey: key)
            subject.send(defaultValue)
        } catch {
            print("RealtimeStorage: Failed to remove value for key '\(key)': \(error)")
        }
    }
}

/// Convenience extensions for common types
public extension RealtimeStorage where Value == Bool {
    init(_ key: String, storage: StorageProvider = UserDefaultsStorageProvider()) {
        self.init(key, defaultValue: false, storage: storage)
    }
}

public extension RealtimeStorage where Value == Int {
    init(_ key: String, storage: StorageProvider = UserDefaultsStorageProvider()) {
        self.init(key, defaultValue: 0, storage: storage)
    }
}

public extension RealtimeStorage where Value == String {
    init(_ key: String, storage: StorageProvider = UserDefaultsStorageProvider()) {
        self.init(key, defaultValue: "", storage: storage)
    }
}

public extension RealtimeStorage where Value: ExpressibleByNilLiteral {
    init(_ key: String, storage: StorageProvider = UserDefaultsStorageProvider()) {
        self.init(key, defaultValue: nil, storage: storage)
    }
}