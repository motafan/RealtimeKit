import Testing
import Foundation
@testable import RealtimeCore

/// 存储后端测试套件
/// 需求: 18.4, 18.5, 18.9, 18.11
@Suite("Storage Backend Tests")
struct StorageBackendTests {
    
    // MARK: - Test Data Models
    
    struct TestModel: Codable, Equatable {
        let id: String
        let name: String
        let value: Int
        let timestamp: Date
        
        static let sample = TestModel(
            id: "test-id",
            name: "Test Model",
            value: 42,
            timestamp: Date(timeIntervalSince1970: 1640995200) // Fixed timestamp: 2022-01-01 00:00:00 UTC
        )
    }
    
    // MARK: - UserDefaults Backend Tests
    
    @Suite("UserDefaults Backend Tests")
    struct UserDefaultsBackendTests {
        
        @Test("UserDefaults backend availability")
        func testAvailability() async throws {
            let backend = UserDefaultsBackend(keyPrefix: "Test.")
            #expect(backend.isAvailable == true)
            #expect(backend.name == "UserDefaults")
        }
        
        @Test("Store and retrieve value")
        func testStoreAndRetrieve() async throws {
            let backend = UserDefaultsBackend(keyPrefix: "Test.")
            let testModel = TestModel.sample
            
            // 存储值
            try await backend.setValue(testModel, for: "test_model")
            
            // 检查是否存在
            let hasValue = try await backend.hasValue(for: "test_model")
            #expect(hasValue == true)
            
            // 获取值
            let retrievedModel = try await backend.getValue(for: "test_model", type: TestModel.self)
            #expect(retrievedModel == testModel)
        }
        
        @Test("Handle non-existent key")
        func testNonExistentKey() async throws {
            let backend = UserDefaultsBackend(keyPrefix: "Test.")
            
            let hasValue = try await backend.hasValue(for: "non_existent")
            #expect(hasValue == false)
            
            let value = try await backend.getValue(for: "non_existent", type: TestModel.self)
            #expect(value == nil)
        }
        
        @Test("Remove value")
        func testRemoveValue() async throws {
            let backend = UserDefaultsBackend(keyPrefix: "Test.")
            let testModel = TestModel.sample
            
            // 存储值
            try await backend.setValue(testModel, for: "test_remove")
            
            // 确认存在
            let hasValueBefore = try await backend.hasValue(for: "test_remove")
            #expect(hasValueBefore == true)
            
            // 删除值
            try await backend.removeValue(for: "test_remove")
            
            // 确认已删除
            let hasValueAfter = try await backend.hasValue(for: "test_remove")
            #expect(hasValueAfter == false)
        }
        
        @Test("Get all keys")
        func testGetAllKeys() async throws {
            let backend = UserDefaultsBackend(keyPrefix: "TestKeys.")
            
            // 清理之前的数据
            try await backend.clearAll()
            
            // 存储多个值
            try await backend.setValue("value1", for: "key1")
            try await backend.setValue("value2", for: "key2")
            try await backend.setValue("value3", for: "key3")
            
            // 获取所有键
            let keys = try await backend.getAllKeys()
            #expect(keys.sorted() == ["key1", "key2", "key3"])
            
            // 清理
            try await backend.clearAll()
        }
        
        @Test("Batch operations")
        func testBatchOperations() async throws {
            let backend = UserDefaultsBackend(keyPrefix: "TestBatch.")
            
            // 清理之前的数据
            try await backend.clearAll()
            
            // 批量设置
            let values = [
                "batch1": "value1",
                "batch2": "value2",
                "batch3": "value3"
            ]
            try await backend.setBatch(values)
            
            // 批量获取
            let keys = Array(values.keys)
            let retrievedValues = try await backend.getBatch(keys: keys, type: String.self)
            #expect(retrievedValues == values)
            
            // 批量删除
            try await backend.removeBatch(keys: keys)
            
            // 确认已删除
            let remainingKeys = try await backend.getAllKeys()
            #expect(remainingKeys.isEmpty)
        }
        
        @Test("Clear all data")
        func testClearAll() async throws {
            let backend = UserDefaultsBackend(keyPrefix: "TestClear.")
            
            // 存储一些数据
            try await backend.setValue("value1", for: "clear1")
            try await backend.setValue("value2", for: "clear2")
            
            // 确认数据存在
            let keysBefore = try await backend.getAllKeys()
            #expect(keysBefore.count == 2)
            
            // 清除所有数据
            try await backend.clearAll()
            
            // 确认数据已清除
            let keysAfter = try await backend.getAllKeys()
            #expect(keysAfter.isEmpty)
        }
    }
    
    // MARK: - Keychain Backend Tests
    
    @Suite("Keychain Backend Tests")
    struct KeychainBackendTests {
        
        @Test("Keychain backend availability")
        func testAvailability() async throws {
            let backend = KeychainBackend(service: "TestService")
            #expect(backend.name == "Keychain")
            // Keychain 可用性取决于系统环境，在测试中可能不可用
        }
        
        @Test("Store and retrieve sensitive value", .enabled(if: isKeychainAvailable()))
        func testStoreAndRetrieveSensitive() async throws {
            let backend = KeychainBackend(service: "TestService")
            let sensitiveData = "sensitive_token_12345"
            
            // 存储敏感值
            try await backend.setValue(sensitiveData, for: "auth_token")
            
            // 检查是否存在
            let hasValue = try await backend.hasValue(for: "auth_token")
            #expect(hasValue == true)
            
            // 获取值
            let retrievedData = try await backend.getValue(for: "auth_token", type: String.self)
            #expect(retrievedData == sensitiveData)
            
            // 清理
            try await backend.removeValue(for: "auth_token")
        }
        
        @Test("Handle invalid key", .enabled(if: isKeychainAvailable()))
        func testInvalidKey() async throws {
            let backend = KeychainBackend(service: "TestService")
            
            do {
                try await backend.setValue("value", for: "")
                #expect(Bool(false), "Should throw invalid key error")
            } catch StorageError.invalidKey {
                // 预期的错误
            }
        }
        
        @Test("Complex data structure", .enabled(if: isKeychainAvailable()))
        func testComplexDataStructure() async throws {
            let backend = KeychainBackend(service: "TestService")
            let testModel = TestModel.sample
            
            // 存储复杂数据结构
            try await backend.setValue(testModel, for: "complex_model")
            
            // 获取并验证
            let retrievedModel = try await backend.getValue(for: "complex_model", type: TestModel.self)
            #expect(retrievedModel == testModel)
            
            // 清理
            try await backend.removeValue(for: "complex_model")
        }
        
        private static func isKeychainAvailable() -> Bool {
            let backend = KeychainBackend(service: "AvailabilityTest")
            return backend.isAvailable
        }
    }
    
    // MARK: - Mock Backend Tests
    
    @Suite("Mock Backend Tests")
    struct MockBackendTests {
        
        @Test("Mock backend basic functionality")
        func testBasicFunctionality() async throws {
            let backend = MockStorageBackend()
            #expect(backend.isAvailable == true)
            #expect(backend.name == "Mock")
            
            let testModel = TestModel.sample
            
            // 存储和获取
            try await backend.setValue(testModel, for: "mock_test")
            let retrieved = try await backend.getValue(for: "mock_test", type: TestModel.self)
            #expect(retrieved == testModel)
        }
        
        @Test("Mock backend failure simulation")
        func testFailureSimulation() async throws {
            let backend = MockStorageBackend()
            backend.shouldFailOperations = true
            
            do {
                try await backend.setValue("test", for: "fail_test")
                #expect(Bool(false), "Should throw backend unavailable error")
            } catch StorageError.backendUnavailable {
                // 预期的错误
            }
        }
        
        @Test("Mock backend delay simulation")
        func testDelaySimulation() async throws {
            let backend = MockStorageBackend()
            backend.operationDelay = 0.1 // 100ms 延迟
            
            let startTime = Date()
            try await backend.setValue("test", for: "delay_test")
            let endTime = Date()
            
            let duration = endTime.timeIntervalSince(startTime)
            #expect(duration >= 0.1, "Operation should take at least 100ms")
        }
        
        @Test("Mock backend raw data access")
        func testRawDataAccess() async throws {
            let backend = MockStorageBackend()
            
            // 存储一些数据
            try await backend.setValue("value1", for: "key1")
            try await backend.setValue("value2", for: "key2")
            
            // 获取原始数据
            let rawData = backend.getRawData()
            #expect(rawData.count == 2)
            #expect(rawData.keys.contains("key1"))
            #expect(rawData.keys.contains("key2"))
            
            // 设置原始数据
            backend.setRawData([:])
            let emptyData = backend.getRawData()
            #expect(emptyData.isEmpty)
        }
    }
    
    // MARK: - Cross-Backend Compatibility Tests
    
    @Suite("Cross-Backend Compatibility Tests")
    struct CrossBackendCompatibilityTests {
        
        @Test("Data format compatibility between backends")
        func testDataFormatCompatibility() async throws {
            let userDefaultsBackend = UserDefaultsBackend(keyPrefix: "Compat.")
            let mockBackend = MockStorageBackend()
            
            let testModel = TestModel.sample
            
            // 在 UserDefaults 中存储
            try await userDefaultsBackend.setValue(testModel, for: "compat_test")
            
            // 在 Mock 中存储相同数据
            try await mockBackend.setValue(testModel, for: "compat_test")
            
            // 从两个后端获取数据
            let fromUserDefaults = try await userDefaultsBackend.getValue(for: "compat_test", type: TestModel.self)
            let fromMock = try await mockBackend.getValue(for: "compat_test", type: TestModel.self)
            
            // 验证数据一致性
            #expect(fromUserDefaults == testModel)
            #expect(fromMock == testModel)
            #expect(fromUserDefaults == fromMock)
            
            // 清理
            try await userDefaultsBackend.removeValue(for: "compat_test")
        }
        
        @Test("Batch operation consistency")
        func testBatchOperationConsistency() async throws {
            let backends: [StorageBackend] = [
                UserDefaultsBackend(keyPrefix: "BatchTest."),
                MockStorageBackend()
            ]
            
            let testData = [
                "batch1": TestModel(id: "1", name: "Model 1", value: 10, timestamp: Date(timeIntervalSince1970: 1640995200)),
                "batch2": TestModel(id: "2", name: "Model 2", value: 20, timestamp: Date(timeIntervalSince1970: 1640995200)),
                "batch3": TestModel(id: "3", name: "Model 3", value: 30, timestamp: Date(timeIntervalSince1970: 1640995200))
            ]
            
            for backend in backends {
                // 清理之前的数据
                try await backend.clearAll()
                
                // 批量设置
                try await backend.setBatch(testData)
                
                // 批量获取
                let keys = Array(testData.keys)
                let retrieved = try await backend.getBatch(keys: keys, type: TestModel.self)
                
                // 验证数据
                #expect(retrieved.count == testData.count)
                for (key, expectedValue) in testData {
                    #expect(retrieved[key] == expectedValue)
                }
                
                // 清理
                try await backend.clearAll()
            }
        }
    }
}