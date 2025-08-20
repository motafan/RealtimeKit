// RealtimeStorageTests.swift
// Comprehensive unit tests for RealtimeStorage

import Testing
import Foundation
@testable import RealtimeCore

@Suite("RealtimeStorage Tests")
struct RealtimeStorageTests {
    
    // MARK: - Mock Storage Implementation
    
    final class MockRealtimeStorage: RealtimeStorage {
        private var storage: [String: Data] = [:]
        private var shouldFailOperations = false
        
        func setValue<T: Codable>(_ value: T, forKey key: String) throws {
            if shouldFailOperations {
                throw RealtimeError.storageError("Mock storage failure")
            }
            
            let data = try JSONEncoder().encode(value)
            storage[key] = data
        }
        
        func getValue<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
            if shouldFailOperations {
                throw RealtimeError.storageError("Mock storage failure")
            }
            
            guard let data = storage[key] else { return nil }
            return try JSONDecoder().decode(type, from: data)
        }
        
        func removeValue(forKey key: String) throws {
            if shouldFailOperations {
                throw RealtimeError.storageError("Mock storage failure")
            }
            
            storage.removeValue(forKey: key)
        }
        
        func hasValue(forKey key: String) -> Bool {
            return storage[key] != nil
        }
        
        func clearAll() throws {
            if shouldFailOperations {
                throw RealtimeError.storageError("Mock storage failure")
            }
            
            storage.removeAll()
        }
        
        func getAllKeys() -> [String] {
            return Array(storage.keys)
        }
        
        func getStorageSize() -> Int {
            return storage.values.reduce(0) { $0 + $1.count }
        }
        
        // Test helper methods
        func setFailureMode(_ shouldFail: Bool) {
            shouldFailOperations = shouldFail
        }
        
        func reset() {
            storage.removeAll()
            shouldFailOperations = false
        }
    }
    
    // MARK: - Test Data Models
    
    struct TestUser: Codable, Equatable {
        let id: String
        let name: String
        let email: String
        let age: Int
        
        static let sample = TestUser(
            id: "user123",
            name: "John Doe",
            email: "john@example.com",
            age: 30
        )
    }
    
    struct TestSettings: Codable, Equatable {
        let theme: String
        let notifications: Bool
        let volume: Int
        
        static let sample = TestSettings(
            theme: "dark",
            notifications: true,
            volume: 75
        )
    }
    
    // MARK: - Test Setup
    
    private func createStorage() -> MockRealtimeStorage {
        return MockRealtimeStorage()
    }
    
    // MARK: - Basic Storage Operations Tests
    
    @Test("Store and retrieve simple value")
    func testStoreAndRetrieveSimpleValue() throws {
        let storage = createStorage()
        let testString = "Hello, World!"
        
        try storage.setValue(testString, forKey: "test_string")
        let retrievedString: String? = try storage.getValue(String.self, forKey: "test_string")
        
        #expect(retrievedString == testString)
        #expect(storage.hasValue(forKey: "test_string"))
    }
    
    @Test("Store and retrieve complex object")
    func testStoreAndRetrieveComplexObject() throws {
        let storage = createStorage()
        let testUser = TestUser.sample
        
        try storage.setValue(testUser, forKey: "test_user")
        let retrievedUser: TestUser? = try storage.getValue(TestUser.self, forKey: "test_user")
        
        #expect(retrievedUser == testUser)
        #expect(retrievedUser?.id == testUser.id)
        #expect(retrievedUser?.name == testUser.name)
        #expect(retrievedUser?.email == testUser.email)
        #expect(retrievedUser?.age == testUser.age)
    }
    
    @Test("Retrieve non-existent value")
    func testRetrieveNonExistentValue() throws {
        let storage = createStorage()
        
        let retrievedValue: String? = try storage.getValue(String.self, forKey: "non_existent")
        
        #expect(retrievedValue == nil)
        #expect(!storage.hasValue(forKey: "non_existent"))
    }
    
    @Test("Remove stored value")
    func testRemoveStoredValue() throws {
        let storage = createStorage()
        let testValue = "test_value"
        
        // Store value
        try storage.setValue(testValue, forKey: "test_key")
        #expect(storage.hasValue(forKey: "test_key"))
        
        // Remove value
        try storage.removeValue(forKey: "test_key")
        #expect(!storage.hasValue(forKey: "test_key"))
        
        let retrievedValue: String? = try storage.getValue(String.self, forKey: "test_key")
        #expect(retrievedValue == nil)
    }
    
    @Test("Remove non-existent value")
    func testRemoveNonExistentValue() throws {
        let storage = createStorage()
        
        // Should not throw when removing non-existent key
        try storage.removeValue(forKey: "non_existent")
        
        #expect(!storage.hasValue(forKey: "non_existent"))
    }
    
    // MARK: - Multiple Values Tests
    
    @Test("Store multiple values")
    func testStoreMultipleValues() throws {
        let storage = createStorage()
        
        let user = TestUser.sample
        let settings = TestSettings.sample
        let counter = 42
        
        try storage.setValue(user, forKey: "user")
        try storage.setValue(settings, forKey: "settings")
        try storage.setValue(counter, forKey: "counter")
        
        #expect(storage.hasValue(forKey: "user"))
        #expect(storage.hasValue(forKey: "settings"))
        #expect(storage.hasValue(forKey: "counter"))
        
        let retrievedUser: TestUser? = try storage.getValue(TestUser.self, forKey: "user")
        let retrievedSettings: TestSettings? = try storage.getValue(TestSettings.self, forKey: "settings")
        let retrievedCounter: Int? = try storage.getValue(Int.self, forKey: "counter")
        
        #expect(retrievedUser == user)
        #expect(retrievedSettings == settings)
        #expect(retrievedCounter == counter)
    }
    
    @Test("Overwrite existing value")
    func testOverwriteExistingValue() throws {
        let storage = createStorage()
        
        let originalValue = "original"
        let newValue = "updated"
        
        // Store original value
        try storage.setValue(originalValue, forKey: "test_key")
        let retrieved1: String? = try storage.getValue(String.self, forKey: "test_key")
        #expect(retrieved1 == originalValue)
        
        // Overwrite with new value
        try storage.setValue(newValue, forKey: "test_key")
        let retrieved2: String? = try storage.getValue(String.self, forKey: "test_key")
        #expect(retrieved2 == newValue)
    }
    
    @Test("Clear all values")
    func testClearAllValues() throws {
        let storage = createStorage()
        
        // Store multiple values
        try storage.setValue("value1", forKey: "key1")
        try storage.setValue("value2", forKey: "key2")
        try storage.setValue("value3", forKey: "key3")
        
        #expect(storage.getAllKeys().count == 3)
        
        // Clear all
        try storage.clearAll()
        
        #expect(storage.getAllKeys().isEmpty)
        #expect(!storage.hasValue(forKey: "key1"))
        #expect(!storage.hasValue(forKey: "key2"))
        #expect(!storage.hasValue(forKey: "key3"))
    }
    
    // MARK: - Data Type Tests
    
    @Test("Store different data types")
    func testStoreDifferentDataTypes() throws {
        let storage = createStorage()
        
        // Basic types
        try storage.setValue(true, forKey: "bool")
        try storage.setValue(42, forKey: "int")
        try storage.setValue(3.14, forKey: "double")
        try storage.setValue("string", forKey: "string")
        
        // Collections
        try storage.setValue([1, 2, 3], forKey: "array")
        try storage.setValue(["key": "value"], forKey: "dictionary")
        
        // Custom types
        try storage.setValue(TestUser.sample, forKey: "user")
        
        // Retrieve and verify
        let bool: Bool? = try storage.getValue(Bool.self, forKey: "bool")
        let int: Int? = try storage.getValue(Int.self, forKey: "int")
        let double: Double? = try storage.getValue(Double.self, forKey: "double")
        let string: String? = try storage.getValue(String.self, forKey: "string")
        let array: [Int]? = try storage.getValue([Int].self, forKey: "array")
        let dictionary: [String: String]? = try storage.getValue([String: String].self, forKey: "dictionary")
        let user: TestUser? = try storage.getValue(TestUser.self, forKey: "user")
        
        #expect(bool == true)
        #expect(int == 42)
        #expect(double == 3.14)
        #expect(string == "string")
        #expect(array == [1, 2, 3])
        #expect(dictionary == ["key": "value"])
        #expect(user == TestUser.sample)
    }
    
    @Test("Handle optional values")
    func testHandleOptionalValues() throws {
        let storage = createStorage()
        
        let optionalString: String? = "optional_value"
        let nilString: String? = nil
        
        try storage.setValue(optionalString, forKey: "optional")
        try storage.setValue(nilString, forKey: "nil")
        
        let retrievedOptional: String?? = try storage.getValue(String?.self, forKey: "optional")
        let retrievedNil: String?? = try storage.getValue(String?.self, forKey: "nil")
        
        #expect(retrievedOptional == optionalString)
        #expect(retrievedNil == nilString)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle storage operation failures")
    func testHandleStorageOperationFailures() throws {
        let storage = createStorage()
        storage.setFailureMode(true)
        
        // All operations should throw errors
        #expect(throws: RealtimeError.self) {
            try storage.setValue("test", forKey: "key")
        }
        
        #expect(throws: RealtimeError.self) {
            let _: String? = try storage.getValue(String.self, forKey: "key")
        }
        
        #expect(throws: RealtimeError.self) {
            try storage.removeValue(forKey: "key")
        }
        
        #expect(throws: RealtimeError.self) {
            try storage.clearAll()
        }
    }
    
    @Test("Handle corrupted data")
    func testHandleCorruptedData() throws {
        let storage = createStorage()
        
        // Manually insert corrupted data
        let corruptedData = "corrupted_json_data".data(using: .utf8)!
        storage.storage["corrupted"] = corruptedData
        
        // Should throw when trying to decode corrupted data
        #expect(throws: Error.self) {
            let _: TestUser? = try storage.getValue(TestUser.self, forKey: "corrupted")
        }
    }
    
    @Test("Handle type mismatch")
    func testHandleTypeMismatch() throws {
        let storage = createStorage()
        
        // Store as string
        try storage.setValue("not_a_number", forKey: "test_key")
        
        // Try to retrieve as int (should throw)
        #expect(throws: Error.self) {
            let _: Int? = try storage.getValue(Int.self, forKey: "test_key")
        }
    }
    
    // MARK: - Storage Metadata Tests
    
    @Test("Get all keys")
    func testGetAllKeys() throws {
        let storage = createStorage()
        
        let keys = ["key1", "key2", "key3"]
        for key in keys {
            try storage.setValue("value_\(key)", forKey: key)
        }
        
        let allKeys = storage.getAllKeys()
        
        #expect(allKeys.count == keys.count)
        for key in keys {
            #expect(allKeys.contains(key))
        }
    }
    
    @Test("Get storage size")
    func testGetStorageSize() throws {
        let storage = createStorage()
        
        #expect(storage.getStorageSize() == 0)
        
        try storage.setValue("small", forKey: "key1")
        let sizeAfterFirst = storage.getStorageSize()
        #expect(sizeAfterFirst > 0)
        
        try storage.setValue("much_longer_string_value", forKey: "key2")
        let sizeAfterSecond = storage.getStorageSize()
        #expect(sizeAfterSecond > sizeAfterFirst)
        
        try storage.removeValue(forKey: "key1")
        let sizeAfterRemoval = storage.getStorageSize()
        #expect(sizeAfterRemoval < sizeAfterSecond)
    }
    
    // MARK: - Performance Tests
    
    @Test("Storage performance with many operations")
    func testStoragePerformanceWithManyOperations() throws {
        let storage = createStorage()
        
        let startTime = Date()
        
        // Perform many storage operations
        for i in 1...1000 {
            try storage.setValue("value_\(i)", forKey: "key_\(i)")
        }
        
        for i in 1...1000 {
            let _: String? = try storage.getValue(String.self, forKey: "key_\(i)")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 5.0) // 5 seconds for 2000 operations
        #expect(storage.getAllKeys().count == 1000)
    }
    
    @Test("Storage performance with large objects")
    func testStoragePerformanceWithLargeObjects() throws {
        let storage = createStorage()
        
        // Create large object
        let largeArray = Array(1...10000)
        
        let startTime = Date()
        
        try storage.setValue(largeArray, forKey: "large_array")
        let retrieved: [Int]? = try storage.getValue([Int].self, forKey: "large_array")
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(duration < 1.0) // Should complete within 1 second
        #expect(retrieved?.count == 10000)
        #expect(retrieved == largeArray)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent storage operations")
    func testConcurrentStorageOperations() async throws {
        let storage = createStorage()
        
        await withTaskGroup(of: Void.self) { group in
            // Concurrent writes
            for i in 1...50 {
                group.addTask {
                    do {
                        try storage.setValue("value_\(i)", forKey: "key_\(i)")
                    } catch {
                        // Handle potential concurrent access issues
                    }
                }
            }
            
            // Concurrent reads
            for i in 1...50 {
                group.addTask {
                    do {
                        let _: String? = try storage.getValue(String.self, forKey: "key_\(i)")
                    } catch {
                        // Handle potential concurrent access issues
                    }
                }
            }
        }
        
        // Should handle concurrent operations without major issues
        let finalKeys = storage.getAllKeys()
        #expect(finalKeys.count > 0)
    }
    
    // MARK: - Storage Limits Tests
    
    @Test("Handle storage size limits")
    func testHandleStorageSizeLimits() throws {
        let storage = createStorage()
        
        // Store many values to test size limits
        var totalSize = 0
        for i in 1...100 {
            let largeString = String(repeating: "x", count: 1000) // 1KB string
            try storage.setValue(largeString, forKey: "large_key_\(i)")
            totalSize += 1000
        }
        
        let actualSize = storage.getStorageSize()
        #expect(actualSize > totalSize) // Should be larger due to JSON encoding overhead
        
        // Clear and verify size reduction
        try storage.clearAll()
        #expect(storage.getStorageSize() == 0)
    }
    
    // MARK: - Key Management Tests
    
    @Test("Key validation and special characters")
    func testKeyValidationAndSpecialCharacters() throws {
        let storage = createStorage()
        
        // Test various key formats
        let specialKeys = [
            "normal_key",
            "key-with-dashes",
            "key.with.dots",
            "key with spaces",
            "key_with_numbers_123",
            "UPPERCASE_KEY",
            "mixedCaseKey",
            "key/with/slashes",
            "key@with#special$chars%",
            "🔑_emoji_key",
            ""  // Empty key
        ]
        
        for (index, key) in specialKeys.enumerated() {
            try storage.setValue("value_\(index)", forKey: key)
            
            let retrieved: String? = try storage.getValue(String.self, forKey: key)
            #expect(retrieved == "value_\(index)")
        }
        
        #expect(storage.getAllKeys().count == specialKeys.count)
    }
    
    // MARK: - Data Integrity Tests
    
    @Test("Data integrity across operations")
    func testDataIntegrityAcrossOperations() throws {
        let storage = createStorage()
        
        let originalUser = TestUser.sample
        
        // Store original data
        try storage.setValue(originalUser, forKey: "user")
        
        // Perform other operations
        try storage.setValue("other_data", forKey: "other_key")
        try storage.removeValue(forKey: "other_key")
        try storage.setValue([1, 2, 3], forKey: "array")
        
        // Verify original data is intact
        let retrievedUser: TestUser? = try storage.getValue(TestUser.self, forKey: "user")
        #expect(retrievedUser == originalUser)
        
        // Modify and verify changes
        let modifiedUser = TestUser(
            id: originalUser.id,
            name: "Modified Name",
            email: originalUser.email,
            age: originalUser.age + 1
        )
        
        try storage.setValue(modifiedUser, forKey: "user")
        let finalUser: TestUser? = try storage.getValue(TestUser.self, forKey: "user")
        #expect(finalUser == modifiedUser)
        #expect(finalUser != originalUser)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Storage cleanup on deallocation")
    func testStorageCleanupOnDeallocation() throws {
        var storage: MockRealtimeStorage? = createStorage()
        
        weak var weakStorage = storage
        
        // Store some data
        try storage?.setValue("test_data", forKey: "test_key")
        
        storage = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakStorage == nil)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Handle edge case values")
    func testHandleEdgeCaseValues() throws {
        let storage = createStorage()
        
        // Empty values
        try storage.setValue("", forKey: "empty_string")
        try storage.setValue([] as [String], forKey: "empty_array")
        try storage.setValue([:] as [String: String], forKey: "empty_dict")
        
        // Extreme values
        try storage.setValue(Int.max, forKey: "max_int")
        try storage.setValue(Int.min, forKey: "min_int")
        try storage.setValue(Double.greatestFiniteMagnitude, forKey: "max_double")
        try storage.setValue(-Double.greatestFiniteMagnitude, forKey: "min_double")
        
        // Retrieve and verify
        let emptyString: String? = try storage.getValue(String.self, forKey: "empty_string")
        let emptyArray: [String]? = try storage.getValue([String].self, forKey: "empty_array")
        let emptyDict: [String: String]? = try storage.getValue([String: String].self, forKey: "empty_dict")
        let maxInt: Int? = try storage.getValue(Int.self, forKey: "max_int")
        let minInt: Int? = try storage.getValue(Int.self, forKey: "min_int")
        let maxDouble: Double? = try storage.getValue(Double.self, forKey: "max_double")
        let minDouble: Double? = try storage.getValue(Double.self, forKey: "min_double")
        
        #expect(emptyString == "")
        #expect(emptyArray?.isEmpty == true)
        #expect(emptyDict?.isEmpty == true)
        #expect(maxInt == Int.max)
        #expect(minInt == Int.min)
        #expect(maxDouble == Double.greatestFiniteMagnitude)
        #expect(minDouble == -Double.greatestFiniteMagnitude)
    }
}