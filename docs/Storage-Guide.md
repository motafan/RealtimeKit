# RealtimeKit 自动状态持久化指南

本指南详细介绍 RealtimeKit 的自动状态持久化功能，包括 `@RealtimeStorage` 和 `@SecureRealtimeStorage` 属性包装器的使用方法和最佳实践。

## 目录

- [概述](#概述)
- [基础使用](#基础使用)
- [存储后端](#存储后端)
- [数据类型支持](#数据类型支持)
- [安全存储](#安全存储)
- [SwiftUI 集成](#swiftui-集成)
- [高级功能](#高级功能)
- [性能优化](#性能优化)
- [最佳实践](#最佳实践)
- [故障排除](#故障排除)

## 概述

RealtimeKit 提供了类似 SwiftUI `@AppStorage` 的自动状态持久化机制，具有以下特性：

- **自动持久化**: 值变化时自动保存到存储后端
- **自动恢复**: 应用启动时自动从存储恢复状态
- **多种后端**: 支持 UserDefaults、Keychain 等存储后端
- **类型安全**: 支持 Codable 协议的所有类型
- **SwiftUI 集成**: 完整支持 SwiftUI 数据绑定
- **命名空间**: 避免键名冲突
- **版本化**: 支持数据迁移和版本管理

## 基础使用

### 1. 简单数据类型

```swift
import RealtimeKit

class UserSettings: ObservableObject {
    // 基础类型自动持久化
    @RealtimeStorage("user_volume", defaultValue: 80)
    var userVolume: Int
    
    @RealtimeStorage("is_muted", defaultValue: false)
    var isMuted: Bool
    
    @RealtimeStorage("user_name", defaultValue: "")
    var userName: String
    
    @RealtimeStorage("last_room_id", defaultValue: "")
    var lastRoomId: String
    
    // 值变化时自动保存
    func updateVolume(_ newVolume: Int) {
        userVolume = newVolume  // 自动保存到 UserDefaults
    }
}
```

### 2. 复杂数据类型

```swift
// 自定义数据模型
struct UserPreferences: Codable, Equatable {
    let audioVolume: Int
    let videoQuality: VideoQuality
    let notificationSettings: NotificationSettings
    let preferredLanguage: SupportedLanguage
    
    static let `default` = UserPreferences(
        audioVolume: 80,
        videoQuality: .high,
        notificationSettings: NotificationSettings(),
        preferredLanguage: .english
    )
}

struct NotificationSettings: Codable, Equatable {
    let enableSound: Bool = true
    let enableVibration: Bool = true
    let enableBanner: Bool = true
}

enum VideoQuality: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

// 使用复杂类型
class AppSettingsManager: ObservableObject {
    @RealtimeStorage("user_preferences", defaultValue: UserPreferences.default)
    var userPreferences: UserPreferences
    
    @RealtimeStorage("audio_settings", defaultValue: AudioSettings.default)
    var audioSettings: AudioSettings
    
    @RealtimeStorage("recent_rooms", defaultValue: [String]())
    var recentRooms: [String]
    
    // 更新复杂对象
    func updateAudioVolume(_ volume: Int) {
        userPreferences = UserPreferences(
            audioVolume: volume,
            videoQuality: userPreferences.videoQuality,
            notificationSettings: userPreferences.notificationSettings,
            preferredLanguage: userPreferences.preferredLanguage
        )
        // 整个对象自动序列化并保存
    }
    
    // 添加最近房间
    func addRecentRoom(_ roomId: String) {
        var rooms = recentRooms
        rooms.removeAll { $0 == roomId }  // 移除重复
        rooms.insert(roomId, at: 0)       // 插入到开头
        rooms = Array(rooms.prefix(10))   // 保持最多 10 个
        recentRooms = rooms               // 自动保存
    }
}
```

## 存储后端

### 1. UserDefaults 后端（默认）

```swift
// 默认使用 UserDefaults
@RealtimeStorage("setting_key", defaultValue: "default_value")
var setting: String

// 显式指定 UserDefaults 后端
@RealtimeStorage("setting_key", defaultValue: "default_value", backend: UserDefaultsBackend.shared)
var setting: String

// 自定义 UserDefaults 实例
let customDefaults = UserDefaults(suiteName: "com.yourapp.settings")!
let customBackend = UserDefaultsBackend(userDefaults: customDefaults)

@RealtimeStorage("setting_key", defaultValue: "default_value", backend: customBackend)
var setting: String
```

### 2. Keychain 后端（安全存储）

```swift
// 使用 Keychain 存储敏感数据
@RealtimeStorage("api_token", defaultValue: "", backend: KeychainBackend.shared)
var apiToken: String

@RealtimeStorage("user_credentials", defaultValue: UserCredentials(), backend: KeychainBackend.shared)
var userCredentials: UserCredentials

// 自定义 Keychain 配置
let customKeychain = KeychainBackend(
    service: "com.yourapp.secure",
    accessGroup: "group.yourapp.shared"
)

@RealtimeStorage("secure_data", defaultValue: SecureData(), backend: customKeychain)
var secureData: SecureData
```

### 3. 自定义存储后端

```swift
// 实现自定义存储后端
class CloudStorageBackend: StorageBackend {
    func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T? {
        // 从云端获取数据
        let data = try await CloudAPI.getData(for: key)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func setValue<T: Codable>(_ value: T, for key: String) async throws {
        // 保存到云端
        let data = try JSONEncoder().encode(value)
        try await CloudAPI.saveData(data, for: key)
    }
    
    func removeValue(for key: String) async throws {
        try await CloudAPI.deleteData(for: key)
    }
}

// 使用自定义后端
let cloudBackend = CloudStorageBackend()

@RealtimeStorage("cloud_settings", defaultValue: CloudSettings(), backend: cloudBackend)
var cloudSettings: CloudSettings
```

## 数据类型支持

### 1. 支持的基础类型

```swift
class BasicTypesExample: ObservableObject {
    @RealtimeStorage("int_value", defaultValue: 0)
    var intValue: Int
    
    @RealtimeStorage("double_value", defaultValue: 0.0)
    var doubleValue: Double
    
    @RealtimeStorage("bool_value", defaultValue: false)
    var boolValue: Bool
    
    @RealtimeStorage("string_value", defaultValue: "")
    var stringValue: String
    
    @RealtimeStorage("data_value", defaultValue: Data())
    var dataValue: Data
    
    @RealtimeStorage("date_value", defaultValue: Date())
    var dateValue: Date
    
    @RealtimeStorage("url_value", defaultValue: URL(string: "https://example.com")!)
    var urlValue: URL
}
```

### 2. 集合类型

```swift
class CollectionTypesExample: ObservableObject {
    @RealtimeStorage("string_array", defaultValue: [String]())
    var stringArray: [String]
    
    @RealtimeStorage("int_set", defaultValue: Set<Int>())
    var intSet: Set<Int>
    
    @RealtimeStorage("string_dict", defaultValue: [String: String]())
    var stringDict: [String: String]
    
    @RealtimeStorage("user_dict", defaultValue: [String: User]())
    var userDict: [String: User]
    
    // 嵌套集合
    @RealtimeStorage("nested_array", defaultValue: [[String]]())
    var nestedArray: [[String]]
    
    @RealtimeStorage("complex_dict", defaultValue: [String: [User]]())
    var complexDict: [String: [User]]
}
```

### 3. 可选类型

```swift
class OptionalTypesExample: ObservableObject {
    @RealtimeStorage("optional_string", defaultValue: String?.none)
    var optionalString: String?
    
    @RealtimeStorage("optional_user", defaultValue: User?.none)
    var optionalUser: User?
    
    @RealtimeStorage("optional_array", defaultValue: [String]?.none)
    var optionalArray: [String]?
    
    // 使用示例
    func updateOptionalString(_ newValue: String?) {
        optionalString = newValue  // nil 值也会被正确保存
    }
}
```

### 4. 枚举类型

```swift
enum UserRole: String, Codable, CaseIterable {
    case broadcaster = "broadcaster"
    case audience = "audience"
    case coHost = "co_host"
    case moderator = "moderator"
}

enum ConnectionState: String, Codable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
}

class EnumTypesExample: ObservableObject {
    @RealtimeStorage("user_role", defaultValue: UserRole.audience)
    var userRole: UserRole
    
    @RealtimeStorage("connection_state", defaultValue: ConnectionState.disconnected)
    var connectionState: ConnectionState
    
    @RealtimeStorage("role_history", defaultValue: [UserRole]())
    var roleHistory: [UserRole]
}
```

## 安全存储

### 1. @SecureRealtimeStorage

对于敏感数据，使用 `@SecureRealtimeStorage`：

```swift
import RealtimeKit

class SecureDataManager: ObservableObject {
    // 自动使用 Keychain 存储
    @SecureRealtimeStorage("auth_token", defaultValue: "")
    var authToken: String
    
    @SecureRealtimeStorage("refresh_token", defaultValue: "")
    var refreshToken: String
    
    @SecureRealtimeStorage("user_credentials", defaultValue: UserCredentials())
    var userCredentials: UserCredentials
    
    @SecureRealtimeStorage("biometric_data", defaultValue: BiometricData())
    var biometricData: BiometricData
}

struct UserCredentials: Codable, Equatable {
    let username: String
    let passwordHash: String
    let salt: String
    
    init(username: String = "", passwordHash: String = "", salt: String = "") {
        self.username = username
        self.passwordHash = passwordHash
        self.salt = salt
    }
}

struct BiometricData: Codable, Equatable {
    let faceId: Data?
    let touchId: Data?
    let isEnabled: Bool
    
    init(faceId: Data? = nil, touchId: Data? = nil, isEnabled: Bool = false) {
        self.faceId = faceId
        self.touchId = touchId
        self.isEnabled = isEnabled
    }
}
```

### 2. 安全配置选项

```swift
// 自定义安全配置
let secureBackend = KeychainBackend(
    service: "com.yourapp.secure",
    accessGroup: "group.yourapp.shared",
    accessibility: .whenUnlockedThisDeviceOnly,  // 设备解锁时才能访问
    synchronizable: false  // 不同步到 iCloud
)

@RealtimeStorage("secure_token", defaultValue: "", backend: secureBackend)
var secureToken: String

// 生物识别保护
let biometricBackend = KeychainBackend(
    service: "com.yourapp.biometric",
    accessibility: .biometryCurrentSet,  // 需要生物识别
    authenticationPrompt: "请验证身份以访问敏感数据"
)

@RealtimeStorage("biometric_protected_data", defaultValue: SensitiveData(), backend: biometricBackend)
var biometricProtectedData: SensitiveData
```

## SwiftUI 集成

### 1. 数据绑定

```swift
import SwiftUI
import RealtimeKit

struct SettingsView: View {
    @StateObject private var settings = UserSettingsManager()
    
    var body: some View {
        Form {
            Section("音频设置") {
                // 直接绑定到持久化属性
                VStack {
                    Text("音量: \(settings.userVolume)")
                    Slider(value: Binding(
                        get: { Double(settings.userVolume) },
                        set: { settings.userVolume = Int($0) }  // 自动保存
                    ), in: 0...100, step: 1)
                }
                
                Toggle("静音", isOn: $settings.isMuted)  // 自动保存
            }
            
            Section("用户信息") {
                TextField("用户名", text: $settings.userName)  // 自动保存
                
                Picker("角色", selection: $settings.userRole) {  // 自动保存
                    ForEach(UserRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
            }
            
            Section("最近房间") {
                ForEach(settings.recentRooms, id: \.self) { roomId in
                    Text(roomId)
                }
                .onDelete { indexSet in
                    settings.recentRooms.remove(atOffsets: indexSet)  // 自动保存
                }
            }
        }
        .navigationTitle("设置")
    }
}

class UserSettingsManager: ObservableObject {
    @RealtimeStorage("user_volume", defaultValue: 80)
    var userVolume: Int
    
    @RealtimeStorage("is_muted", defaultValue: false)
    var isMuted: Bool
    
    @RealtimeStorage("user_name", defaultValue: "")
    var userName: String
    
    @RealtimeStorage("user_role", defaultValue: UserRole.audience)
    var userRole: UserRole
    
    @RealtimeStorage("recent_rooms", defaultValue: [String]())
    var recentRooms: [String]
}
```

### 2. 投影值（Binding）

```swift
struct AudioControlView: View {
    @StateObject private var audioManager = AudioManager()
    
    var body: some View {
        VStack {
            // 使用投影值创建 Binding
            VolumeSlider(volume: audioManager.$mixingVolume)
            VolumeSlider(volume: audioManager.$playbackVolume)
            VolumeSlider(volume: audioManager.$recordingVolume)
        }
    }
}

struct VolumeSlider: View {
    @Binding var volume: Int
    
    var body: some View {
        VStack {
            Text("音量: \(volume)")
            Slider(
                value: Binding(
                    get: { Double(volume) },
                    set: { volume = Int($0) }
                ),
                in: 0...100,
                step: 1
            )
        }
    }
}

class AudioManager: ObservableObject {
    @RealtimeStorage("mixing_volume", defaultValue: 80)
    var mixingVolume: Int
    
    @RealtimeStorage("playback_volume", defaultValue: 90)
    var playbackVolume: Int
    
    @RealtimeStorage("recording_volume", defaultValue: 70)
    var recordingVolume: Int
}
```

## 高级功能

### 1. 命名空间

避免不同模块间的键名冲突：

```swift
// 使用命名空间前缀
class UserModule: ObservableObject {
    @RealtimeStorage("user.profile.name", defaultValue: "")
    var profileName: String
    
    @RealtimeStorage("user.profile.avatar", defaultValue: Data())
    var profileAvatar: Data
    
    @RealtimeStorage("user.settings.theme", defaultValue: Theme.light)
    var theme: Theme
}

class AudioModule: ObservableObject {
    @RealtimeStorage("audio.volume.master", defaultValue: 100)
    var masterVolume: Int
    
    @RealtimeStorage("audio.volume.effects", defaultValue: 80)
    var effectsVolume: Int
    
    @RealtimeStorage("audio.settings.quality", defaultValue: AudioQuality.high)
    var audioQuality: AudioQuality
}

// 或使用自定义后端实现命名空间
class NamespacedBackend: StorageBackend {
    private let namespace: String
    private let baseBackend: StorageBackend
    
    init(namespace: String, baseBackend: StorageBackend = UserDefaultsBackend.shared) {
        self.namespace = namespace
        self.baseBackend = baseBackend
    }
    
    private func namespacedKey(_ key: String) -> String {
        return "\(namespace).\(key)"
    }
    
    func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T? {
        return try await baseBackend.getValue(for: namespacedKey(key), type: type)
    }
    
    func setValue<T: Codable>(_ value: T, for key: String) async throws {
        try await baseBackend.setValue(value, for: namespacedKey(key))
    }
    
    func removeValue(for key: String) async throws {
        try await baseBackend.removeValue(for: namespacedKey(key))
    }
}

// 使用命名空间后端
let userBackend = NamespacedBackend(namespace: "user")
let audioBackend = NamespacedBackend(namespace: "audio")

@RealtimeStorage("profile_name", defaultValue: "", backend: userBackend)
var profileName: String

@RealtimeStorage("master_volume", defaultValue: 100, backend: audioBackend)
var masterVolume: Int
```

### 2. 数据迁移

处理数据结构变化和版本升级：

```swift
// 版本化数据模型
struct UserPreferencesV1: Codable {
    let audioVolume: Int
    let videoQuality: String
}

struct UserPreferencesV2: Codable {
    let audioVolume: Int
    let videoQuality: VideoQuality
    let notificationSettings: NotificationSettings
    let version: Int = 2
    
    // 从 V1 迁移
    init(from v1: UserPreferencesV1) {
        self.audioVolume = v1.audioVolume
        self.videoQuality = VideoQuality(rawValue: v1.videoQuality) ?? .medium
        self.notificationSettings = NotificationSettings()
    }
}

// 迁移管理器
class MigrationManager {
    static func migrateUserPreferences() {
        let key = "user_preferences"
        let backend = UserDefaultsBackend.shared
        
        // 尝试加载新版本
        if let v2Data = try? await backend.getValue(for: key, type: UserPreferencesV2.self),
           v2Data != nil {
            return  // 已经是新版本
        }
        
        // 尝试从旧版本迁移
        if let v1Data = try? await backend.getValue(for: key, type: UserPreferencesV1.self),
           let v1 = v1Data {
            let v2 = UserPreferencesV2(from: v1)
            try? await backend.setValue(v2, for: key)
            print("成功迁移用户偏好设置从 V1 到 V2")
        }
    }
}

// 在应用启动时执行迁移
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        Task {
            await MigrationManager.migrateUserPreferences()
        }
        
        return true
    }
}
```

### 3. 批量操作

优化性能的批量写入：

```swift
class BatchStorageManager: ObservableObject {
    private let backend: StorageBackend
    private var pendingWrites: [String: Any] = [:]
    private var batchTimer: Timer?
    
    init(backend: StorageBackend = UserDefaultsBackend.shared) {
        self.backend = backend
    }
    
    func batchWrite<T: Codable>(_ value: T, for key: String) {
        pendingWrites[key] = value
        
        // 延迟批量写入
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task {
                await self?.flushPendingWrites()
            }
        }
    }
    
    private func flushPendingWrites() async {
        let writes = pendingWrites
        pendingWrites.removeAll()
        
        // 并行执行所有写入
        await withTaskGroup(of: Void.self) { group in
            for (key, value) in writes {
                group.addTask {
                    do {
                        if let codableValue = value as? any Codable {
                            try await self.backend.setValue(codableValue, for: key)
                        }
                    } catch {
                        print("批量写入失败: \(key) - \(error)")
                    }
                }
            }
        }
    }
}
```

## 性能优化

### 1. 延迟写入

避免频繁的磁盘写入：

```swift
@propertyWrapper
struct DelayedRealtimeStorage<Value: Codable>: DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let backend: StorageBackend
    private let writeDelay: TimeInterval
    
    @State private var currentValue: Value
    @State private var writeTimer: Timer?
    
    init(
        _ key: String,
        defaultValue: Value,
        backend: StorageBackend = UserDefaultsBackend.shared,
        writeDelay: TimeInterval = 0.5
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.backend = backend
        self.writeDelay = writeDelay
        
        // 初始化时加载值
        let loadedValue = (try? await backend.getValue(for: key, type: Value.self)) ?? defaultValue
        self._currentValue = State(initialValue: loadedValue)
    }
    
    var wrappedValue: Value {
        get { currentValue }
        nonmutating set {
            currentValue = newValue
            scheduleWrite(newValue)
        }
    }
    
    var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
    
    private func scheduleWrite(_ value: Value) {
        writeTimer?.invalidate()
        writeTimer = Timer.scheduledTimer(withTimeInterval: writeDelay, repeats: false) { _ in
            Task {
                try? await backend.setValue(value, for: key)
            }
        }
    }
}
```

### 2. 内存缓存

减少重复的序列化/反序列化：

```swift
class CachedStorageBackend: StorageBackend {
    private let baseBackend: StorageBackend
    private var cache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "storage.cache", attributes: .concurrent)
    
    init(baseBackend: StorageBackend) {
        self.baseBackend = baseBackend
    }
    
    func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T? {
        // 先检查缓存
        if let cachedValue = getCachedValue(for: key, type: type) {
            return cachedValue
        }
        
        // 从后端加载
        let value = try await baseBackend.getValue(for: key, type: type)
        
        // 缓存结果
        if let value = value {
            setCachedValue(value, for: key)
        }
        
        return value
    }
    
    func setValue<T: Codable>(_ value: T, for key: String) async throws {
        // 更新缓存
        setCachedValue(value, for: key)
        
        // 写入后端
        try await baseBackend.setValue(value, for: key)
    }
    
    private func getCachedValue<T: Codable>(for key: String, type: T.Type) -> T? {
        return cacheQueue.sync {
            return cache[key] as? T
        }
    }
    
    private func setCachedValue<T: Codable>(_ value: T, for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = value
        }
    }
}
```

## 最佳实践

### 1. 键名规范

使用一致的键名规范：

```swift
// ✅ 推荐：使用点分隔的层次结构
@RealtimeStorage("user.profile.name", defaultValue: "")
var userName: String

@RealtimeStorage("user.settings.volume", defaultValue: 80)
var userVolume: Int

@RealtimeStorage("app.ui.theme", defaultValue: Theme.light)
var appTheme: Theme

@RealtimeStorage("connection.history.recent", defaultValue: [String]())
var recentConnections: [String]

// ❌ 避免：不一致的命名
@RealtimeStorage("userName", defaultValue: "")  // 驼峰命名
@RealtimeStorage("user_volume", defaultValue: 80)  // 下划线命名
@RealtimeStorage("AppTheme", defaultValue: Theme.light)  // 大写开头
```

### 2. 默认值设计

提供合理的默认值：

```swift
// ✅ 推荐：有意义的默认值
@RealtimeStorage("audio.volume.master", defaultValue: 80)  // 80% 是合理的默认音量
var masterVolume: Int

@RealtimeStorage("user.language", defaultValue: SupportedLanguage.english)  // 英文作为默认语言
var userLanguage: SupportedLanguage

@RealtimeStorage("app.first_launch", defaultValue: true)  // 首次启动标记
var isFirstLaunch: Bool

// ❌ 避免：无意义的默认值
@RealtimeStorage("audio.volume.master", defaultValue: 0)  // 0 音量用户体验差
var masterVolume: Int

@RealtimeStorage("user.settings", defaultValue: UserSettings())  // 空对象可能导致问题
var userSettings: UserSettings
```

### 3. 数据模型设计

设计易于扩展的数据模型：

```swift
// ✅ 推荐：版本化和可扩展的模型
struct UserSettings: Codable, Equatable {
    let version: Int = 1
    let audioVolume: Int
    let videoQuality: VideoQuality
    let notificationSettings: NotificationSettings?  // 可选字段便于扩展
    let customSettings: [String: String]  // 自定义设置字典
    
    // 提供便捷的初始化方法
    init(
        audioVolume: Int = 80,
        videoQuality: VideoQuality = .medium,
        notificationSettings: NotificationSettings? = nil,
        customSettings: [String: String] = [:]
    ) {
        self.audioVolume = audioVolume
        self.videoQuality = videoQuality
        self.notificationSettings = notificationSettings
        self.customSettings = customSettings
    }
    
    // 提供更新方法
    func withUpdatedAudioVolume(_ volume: Int) -> UserSettings {
        return UserSettings(
            audioVolume: volume,
            videoQuality: self.videoQuality,
            notificationSettings: self.notificationSettings,
            customSettings: self.customSettings
        )
    }
}

// ❌ 避免：难以扩展的模型
struct UserSettings: Codable {
    let audioVolume: Int
    let videoQuality: String  // 使用字符串而不是枚举
    // 没有版本信息，难以迁移
    // 没有扩展机制
}
```

### 4. 错误处理

优雅地处理存储错误：

```swift
class RobustStorageManager: ObservableObject {
    @RealtimeStorage("user_settings", defaultValue: UserSettings.default)
    private var _userSettings: UserSettings
    
    var userSettings: UserSettings {
        get { _userSettings }
        set {
            do {
                _userSettings = newValue
            } catch {
                // 记录错误但不崩溃
                print("保存用户设置失败: \(error)")
                
                // 可选：通知用户
                NotificationCenter.default.post(
                    name: .storageError,
                    object: StorageError.saveFailed(error)
                )
            }
        }
    }
    
    // 提供手动保存方法
    func saveUserSettings(_ settings: UserSettings) async -> Bool {
        do {
            _userSettings = settings
            return true
        } catch {
            print("保存用户设置失败: \(error)")
            return false
        }
    }
    
    // 提供重置方法
    func resetToDefaults() {
        _userSettings = UserSettings.default
    }
}

enum StorageError: Error {
    case saveFailed(Error)
    case loadFailed(Error)
    case corruptedData
}

extension Notification.Name {
    static let storageError = Notification.Name("RealtimeKit.storageError")
}
```

## 故障排除

### 常见问题及解决方案

#### Q: 数据没有自动保存

**A: 检查数据类型是否符合 Codable**

```swift
// ✅ 确保所有类型都符合 Codable
struct UserData: Codable {  // 必须符合 Codable
    let name: String
    let age: Int
    let preferences: UserPreferences  // 嵌套类型也必须符合 Codable
}

struct UserPreferences: Codable {  // 嵌套类型也要符合 Codable
    let theme: Theme
    let language: SupportedLanguage
}

enum Theme: String, Codable {  // 枚举需要原始值类型
    case light = "light"
    case dark = "dark"
}
```

#### Q: 应用启动时数据没有恢复

**A: 确保在使用前初始化**

```swift
// ✅ 在 AppDelegate 或 App 中初始化
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 确保存储管理器在使用前初始化
        _ = UserSettingsManager.shared
        
        return true
    }
}

class UserSettingsManager: ObservableObject {
    static let shared = UserSettingsManager()
    
    @RealtimeStorage("user_settings", defaultValue: UserSettings.default)
    var userSettings: UserSettings
    
    private init() {
        // 私有初始化确保单例
    }
}
```

#### Q: Keychain 存储失败

**A: 检查权限和配置**

```swift
// 检查 Keychain 可用性
func checkKeychainAvailability() -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "test-account",
        kSecValueData as String: "test-data".data(using: .utf8)!
    ]
    
    let status = SecItemAdd(query as CFDictionary, nil)
    
    if status == errSecSuccess {
        // 清理测试数据
        SecItemDelete(query as CFDictionary)
        return true
    } else {
        print("Keychain 不可用: \(status)")
        return false
    }
}

// 使用回退策略
class FallbackStorageBackend: StorageBackend {
    private let primaryBackend: StorageBackend
    private let fallbackBackend: StorageBackend
    
    init(primary: StorageBackend, fallback: StorageBackend) {
        self.primaryBackend = primary
        self.fallbackBackend = fallback
    }
    
    func setValue<T: Codable>(_ value: T, for key: String) async throws {
        do {
            try await primaryBackend.setValue(value, for: key)
        } catch {
            print("主存储失败，使用备用存储: \(error)")
            try await fallbackBackend.setValue(value, for: key)
        }
    }
    
    func getValue<T: Codable>(for key: String, type: T.Type) async throws -> T? {
        do {
            return try await primaryBackend.getValue(for: key, type: type)
        } catch {
            print("主存储读取失败，尝试备用存储: \(error)")
            return try await fallbackBackend.getValue(for: key, type: type)
        }
    }
}

// 使用回退策略
let fallbackBackend = FallbackStorageBackend(
    primary: KeychainBackend.shared,
    fallback: UserDefaultsBackend.shared
)

@RealtimeStorage("secure_data", defaultValue: SecureData(), backend: fallbackBackend)
var secureData: SecureData
```

通过遵循本指南，您可以充分利用 RealtimeKit 的自动状态持久化功能，构建出数据管理简单、用户体验优秀的应用。