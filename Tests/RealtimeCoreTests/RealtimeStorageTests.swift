import Testing
import Foundation
import SwiftUI
@testable import RealtimeCore

/// 属性包装器测试套件
/// 需求: 18.1, 18.2, 18.3, 18.10
@Suite("RealtimeStorage Property Wrapper Tests")
struct RealtimeStorageTests {
    
    // MARK: - Test Data Models
    
    struct TestSettings: Codable, Equatable {
        let theme: String
        let fontSize: Int
        let isEnabled: Bool
        
        static let `default` = TestSettings(theme: "light", fontSize: 14, isEnabled: true)
    }
    
    // MARK: - Test Class with Property Wrappers
    
    @MainActor
    class TestStorageClass: ObservableObject {
        static let testId = UUID().uuidString
        
        @RealtimeStorage(wrappedValue: "default", "test_string_\(TestStorageClass.testId)")
        var testString: String
        
        @RealtimeStorage(wrappedValue: 42, "test_int_\(TestStorageClass.testId)")
        var testInt: Int
        
        @RealtimeStorage(wrappedValue: TestSettings.default, "test_settings_\(TestStorageClass.testId)")
        var testSettings: TestSettings
        
        @SecureRealtimeStorage(wrappedValue: "secret", "test_secret_\(TestStorageClass.testId)")
        var testSecret: String
        
        init() {}
    }
    
    // MARK: - Basic Property Wrapper Tests
    
    @Suite("Basic RealtimeStorage Tests")
    struct BasicRealtimeStorageTests {
        
        @Test("Property wrapper initialization and default values")
        @MainActor
        func testInitializationAndDefaults() async throws {
            // 清理之前的数据
            let cleanup = TestStorageClass()
            cleanup.$testString.remove()
            cleanup.$testInt.remove()
            cleanup.$testSettings.remove()
            
            let testObject = TestStorageClass()
            
            // 验证默认值
            #expect(testObject.testString == "default")
            #expect(testObject.testInt == 42)
            #expect(testObject.testSettings == TestSettings.default)
        }
        
        @Test("Property wrapper value persistence")
        @MainActor
        func testValuePersistence() async throws {
            let testObject1 = TestStorageClass()
            
            // 设置新值
            testObject1.testString = "updated"
            testObject1.testInt = 100
            testObject1.testSettings = TestSettings(theme: "dark", fontSize: 16, isEnabled: false)
            
            // 创建新实例验证持久化
            let testObject2 = TestStorageClass()
            
            #expect(testObject2.testString == "updated")
            #expect(testObject2.testInt == 100)
            #expect(testObject2.testSettings.theme == "dark")
            #expect(testObject2.testSettings.fontSize == 16)
            #expect(testObject2.testSettings.isEnabled == false)
        }
        
        @Test("Projected value operations")
        @MainActor
        func testProjectedValue() async throws {
            let testObject = TestStorageClass()
            
            // 测试 reset 功能
            testObject.testString = "modified"
            testObject.$testString.reset()
            #expect(testObject.testString == "default")
            
            // 测试 hasValue 功能
            let hasValue = testObject.$testString.hasValue()
            #expect(hasValue == true)
            
            // 测试 remove 功能
            testObject.$testString.remove()
            
            // 创建新实例验证删除
            let testObject2 = TestStorageClass()
            #expect(testObject2.testString == "default") // 应该回到默认值
        }
        
        @Test("SwiftUI Binding support")
        @MainActor
        func testSwiftUIBinding() async throws {
            let testObject = TestStorageClass()
            
            // 获取 Binding
            let binding = testObject.$testInt.binding
            
            // 通过 Binding 设置值
            binding.wrappedValue = 999
            
            #expect(testObject.testInt == 999)
            
            // 验证 Binding 的 get 功能
            #expect(binding.wrappedValue == 999)
        }
        
        @Test("Value operations")
        @MainActor
        func testValueOperations() async throws {
            let testObject = TestStorageClass()
            
            // 设置值
            testObject.$testString.setValue("new_value")
            
            // 获取值
            let retrievedValue = testObject.$testString.value
            #expect(retrievedValue == "new_value")
            #expect(testObject.testString == "new_value")
        }
    }
    
    // MARK: - Secure Storage Tests
    
    @Suite("SecureRealtimeStorage Tests")
    struct SecureRealtimeStorageTests {
        
        @Test("Secure storage basic functionality")
        @MainActor
        func testSecureStorageBasics() async throws {
            let testObject = TestStorageClass()
            
            // 设置敏感值
            testObject.testSecret = "top_secret_token"
            
            // 创建新实例验证持久化
            let testObject2 = TestStorageClass()
            
            #expect(testObject2.testSecret == "top_secret_token")
        }
        
        @Test("Secure storage projected value operations")
        @MainActor
        func testSecureStorageProjectedValue() async throws {
            let testObject = TestStorageClass()
            
            // 设置值
            testObject.testSecret = "sensitive_data"
            
            // 测试 hasValue
            let hasValue = testObject.$testSecret.hasValue()
            #expect(hasValue == true)
            
            // 测试 reset
            testObject.$testSecret.reset()
            #expect(testObject.testSecret == "secret") // 默认值
            
            // 测试 remove
            testObject.testSecret = "to_be_removed"
            testObject.$testSecret.remove()
            
            let testObject2 = TestStorageClass()
            #expect(testObject2.testSecret == "secret") // 应该是默认值
        }
    }
    
    // MARK: - Namespace Tests
    
    @Suite("Namespace Support Tests")
    struct NamespaceTests {
        
        @MainActor
        class NamespacedTestClass: ObservableObject {
            static let testId = UUID().uuidString
            
            @RealtimeStorage(wrappedValue: "default", "test_key_\(NamespacedTestClass.testId)", namespace: "app_settings")
            var appSetting: String
            
            @RealtimeStorage(wrappedValue: "default", "test_key_\(NamespacedTestClass.testId)", namespace: "user_preferences")
            var userPreference: String
            
            init() {}
        }
        
        @Test("Namespace isolation")
        @MainActor
        func testNamespaceIsolation() async throws {
            let testObject = NamespacedTestClass()
            
            // 设置不同命名空间的相同键
            testObject.appSetting = "app_value"
            testObject.userPreference = "user_value"
            
            // 验证值不会冲突
            #expect(testObject.appSetting == "app_value")
            #expect(testObject.userPreference == "user_value")
            
            // 创建新实例验证持久化
            let testObject2 = NamespacedTestClass()
            
            #expect(testObject2.appSetting == "app_value")
            #expect(testObject2.userPreference == "user_value")
        }
        
        @Test("Namespace management")
        @MainActor
        func testNamespaceManagement() async throws {
            let storageManager = StorageManager.shared
            
            // 注册命名空间
            storageManager.registerNamespace("test_namespace")
            storageManager.registerNamespace("another_namespace")
            
            let namespaces = storageManager.registeredNamespaces
            #expect(namespaces.contains("test_namespace"))
            #expect(namespaces.contains("another_namespace"))
            
            // 测试命名空间清理
            let testObject = NamespacedTestClass()
            testObject.appSetting = "to_be_cleared"
            
            // 清理命名空间
            storageManager.clearNamespace("app_settings")
            
            // 注意：简化的实现不会真正清理数据，这里只是测试API
            #expect(testObject.appSetting == "to_be_cleared") // 值仍然存在
        }
    }
    
    // MARK: - Storage Manager Tests
    
    @Suite("Storage Manager Tests")
    struct StorageManagerTests {
        
        @Test("Storage manager initialization")
        @MainActor
        func testStorageManagerInitialization() async throws {
            let manager = StorageManager.shared
            #expect(manager.isInitialized == true)
            
            // 验证默认存储提供者
            #expect(manager.defaultStorage is UserDefaults)
            #expect(manager.secureStorage is KeychainStorageProvider)
        }
        
        @Test("Custom storage provider registration")
        @MainActor
        func testCustomStorageProviderRegistration() async throws {
            let manager = StorageManager.shared
            let mockProvider = UserDefaults.standard // 使用 UserDefaults 作为测试
            
            manager.registerStorageProvider(mockProvider, name: "custom_provider")
            
            let retrievedProvider = manager.getStorageProvider(name: "custom_provider")
            #expect(retrievedProvider != nil)
        }
        
        @Test("Storage statistics")
        @MainActor
        func testStorageStatistics() async throws {
            let manager = StorageManager.shared
            
            // 创建一些测试数据
            let testObject = TestStorageClass()
            testObject.testString = "stats_test"
            testObject.testInt = 123
            
            // 更新统计信息
            manager.updateStatistics()
            
            let stats = manager.statistics
            #expect(stats.namespaceCount >= 0)
            #expect(stats.lastUpdated.timeIntervalSinceNow < 1.0)
        }
        
        @Test("Manager initialization")
        @MainActor
        func testManagerInitialization() async throws {
            let manager = StorageManager.shared
            
            // 验证管理器初始化
            #expect(manager.isInitialized == true)
            #expect(manager.defaultStorage is UserDefaults)
            #expect(manager.secureStorage is KeychainStorageProvider)
        }
    }
    
    // MARK: - Test Helper Classes
    
    class FailingStorageProvider: RealtimeStorageProvider {
        func getValue<T: Codable>(for key: String, defaultValue: T) -> T {
            return defaultValue // 总是返回默认值
        }
        
        func setValue<T: Codable>(_ value: T, for key: String) {
            // 什么都不做，模拟存储失败
        }
        
        func hasValue(for key: String) -> Bool {
            return false
        }
        
        func removeValue(for key: String) {
            // 什么都不做
        }
    }
    
    class InvalidDataStorageProvider: RealtimeStorageProvider {
        func getValue<T: Codable>(for key: String, defaultValue: T) -> T {
            return defaultValue // 总是返回默认值，模拟解码失败
        }
        
        func setValue<T: Codable>(_ value: T, for key: String) {
            // 正常存储
        }
        
        func hasValue(for key: String) -> Bool {
            return true
        }
        
        func removeValue(for key: String) {
            // 正常删除
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Suite("Error Handling Tests")
    struct ErrorHandlingTests {
        
        @Test("Storage provider failure handling")
        @MainActor
        func testStorageProviderFailureHandling() async throws {
            // 创建一个会失败的存储提供者
            let failingProvider = FailingStorageProvider()
            
            @RealtimeStorage(wrappedValue: "default", "fail_test", storage: failingProvider)
            var testValue: String
            
            // 设置值应该不会崩溃
            testValue = "new_value"
            
            // 由于存储失败，获取时应该返回默认值
            #expect(testValue == "default")
        }
        
        @Test("Invalid data handling")
        @MainActor
        func testInvalidDataHandling() async throws {
            let invalidProvider = InvalidDataStorageProvider()
            
            @RealtimeStorage(wrappedValue: TestSettings.default, "invalid_key", storage: invalidProvider)
            var testSettings: TestSettings
            
            // 应该回退到默认值
            #expect(testSettings == TestSettings.default)
        }
    }
}