# RealtimeKit 常见问题解答 (FAQ)

本文档收集了 RealtimeKit 使用过程中的常见问题和解答，帮助开发者快速解决问题。

## 目录

- [安装和配置](#安装和配置)
- [服务提供商](#服务提供商)
- [功能使用](#功能使用)
- [性能和优化](#性能和优化)
- [兼容性](#兼容性)
- [最佳实践](#最佳实践)
- [故障排除](#故障排除)

## 安装和配置

### Q: RealtimeKit 支持哪些平台和版本？

**A:** RealtimeKit 支持以下平台和版本：

- **iOS**: 13.0 及以上版本
- **macOS**: 10.15 及以上版本
- **Swift**: 6.2 及以上版本
- **Xcode**: 15.0 及以上版本

### Q: 如何选择合适的模块导入？

**A:** 根据您的需求选择导入方式：

```swift
// 完整功能 - 适合大多数应用
import RealtimeKit

// 核心功能 - 适合只需要基础功能的应用
import RealtimeCore

// UI 集成 - 根据使用的 UI 框架选择
import RealtimeUIKit     // UIKit 应用
import RealtimeSwiftUI   // SwiftUI 应用

// 服务商 - 根据使用的服务商选择
import RealtimeAgora     // 声网 Agora
import RealtimeTencent   // 腾讯云 TRTC（开发中）

// 测试 - 开发和测试时使用
import RealtimeMocking   // Mock 服务商
```

## 服务提供商

### Q: RealtimeKit 支持哪些服务提供商？

**A:** RealtimeKit 目前支持以下服务提供商：

- ✅ **Agora**: 完全支持，包括 RTC 和 RTM 功能
- 🚧 **腾讯云 TRTC**: 开发中，即将支持
- 🚧 **ZEGO**: 开发中，即将支持  
- ✅ **Mock Provider**: 完整的测试和开发支持

### Q: 如何在不同服务提供商之间切换？

**A:** RealtimeKit 的插件化架构支持无缝切换：

```swift
// 方法 1: 运行时切换
try await RealtimeManager.shared.switchProvider(.agora)
try await RealtimeManager.shared.switchProvider(.tencent)

// 方法 2: 初始化时指定
let config = RealtimeConfig(
    appId: "your-app-id",
    provider: .agora  // 或 .tencent, .zego
)
```

### Q: 为什么选择 RealtimeKit 而不是直接使用服务商 SDK？

**A:** RealtimeKit 提供以下优势：

1. **统一 API**: 一套代码支持多个服务商，降低学习成本
2. **插件化架构**: 轻松切换服务商，无需重写业务逻辑
3. **自动状态管理**: 内置状态持久化和恢复机制
4. **现代并发**: 全面支持 Swift Concurrency
5. **完整本地化**: 内置多语言支持
6. **双框架支持**: 同时支持 UIKit 和 SwiftUI

### Q: 如何获取不同服务商的凭证？

**A:** 各服务商凭证获取方式：

#### Agora
1. 访问 [Agora 控制台](https://console.agora.io/)
2. 创建项目并获取 App ID
3. 启用 App Certificate（推荐）

#### 腾讯云 TRTC（即将支持）
1. 访问 [腾讯云控制台](https://console.cloud.tencent.com/trtc)
2. 创建应用并获取 SDKAppID
3. 获取密钥信息

#### ZEGO（即将支持）
1. 访问 [ZEGO 控制台](https://console.zego.im/)
2. 创建项目并获取 AppID
3. 获取 AppSign

### Q: 如何获取 Agora App ID 和 App Certificate？

**A:** 按以下步骤获取：

1. 访问 [Agora 控制台](https://console.agora.io/)
2. 注册并登录账号
3. 创建新项目
4. 在项目设置中找到 App ID
5. 启用 App Certificate 并获取证书

```swift
let config = RealtimeConfig(
    appId: "your-agora-app-id",        // 从控制台获取
    appCertificate: "your-app-cert",   // 从控制台获取
    logLevel: .info
)
```

### Q: 是否需要在 Info.plist 中添加权限？

**A:** 是的，需要添加以下权限：

```xml
<!-- 麦克风权限 -->
<key>NSMicrophoneUsageDescription</key>
<string>此应用需要访问麦克风进行语音通话</string>

<!-- 摄像头权限（如果使用视频功能） -->
<key>NSCameraUsageDescription</key>
<string>此应用需要访问摄像头进行视频通话</string>

<!-- 本地网络权限 -->
<key>NSLocalNetworkUsageDescription</key>
<string>此应用需要访问本地网络进行实时通信</string>
```

## 功能使用

### Q: 如何实现用户角色切换？

**A:** 使用 `switchUserRole` 方法：

```swift
// 检查是否可以切换到目标角色
let currentRole = RealtimeManager.shared.currentSession?.userRole
let targetRole = UserRole.coHost

if currentRole?.canSwitchToRole.contains(targetRole) == true {
    try await RealtimeManager.shared.switchUserRole(targetRole)
} else {
    print("无法从 \(currentRole) 切换到 \(targetRole)")
}

// 角色切换规则：
// broadcaster -> moderator
// audience -> coHost
// coHost -> audience, broadcaster
// moderator -> broadcaster
```

### Q: 音量检测的最佳参数设置是什么？

**A:** 根据使用场景调整参数：

```swift
// 会议场景 - 需要检测轻声说话
let meetingConfig = VolumeDetectionConfig(
    detectionInterval: 500,      // 较慢的检测间隔
    speakingThreshold: 0.2,      // 较低的说话阈值
    silenceThreshold: 0.05,      // 较低的静音阈值
    smoothFactor: 0.4            // 较强的平滑处理
)

// 直播场景 - 需要快速响应
let liveConfig = VolumeDetectionConfig(
    detectionInterval: 200,      // 较快的检测间隔
    speakingThreshold: 0.4,      // 较高的说话阈值
    silenceThreshold: 0.1,       // 较高的静音阈值
    smoothFactor: 0.2            // 较弱的平滑处理
)

// K歌场景 - 需要最快响应
let karaokeConfig = VolumeDetectionConfig(
    detectionInterval: 100,      // 最快的检测间隔
    speakingThreshold: 0.3,      // 中等说话阈值
    silenceThreshold: 0.05,      // 较低的静音阈值
    smoothFactor: 0.1            // 最弱的平滑处理
)
```

### Q: 如何处理网络连接异常？

**A:** RealtimeKit 内置了自动重连机制，您也可以监听连接状态：

```swift
class ConnectionHandler: ObservableObject {
    @Published var showReconnectingAlert = false
    @Published var showConnectionFailedAlert = false
    
    init() {
        RealtimeManager.shared.$connectionState
            .sink { [weak self] state in
                self?.handleConnectionState(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleConnectionState(_ state: ConnectionState) {
        switch state {
        case .connecting:
            // 显示连接中提示
            break
            
        case .reconnecting:
            showReconnectingAlert = true
            
        case .connected:
            // 隐藏所有提示
            showReconnectingAlert = false
            showConnectionFailedAlert = false
            
        case .failed:
            showConnectionFailedAlert = true
            
        case .disconnected:
            // 正常断开连接
            break
        }
    }
}
```

### Q: 如何实现自定义消息处理？

**A:** 实现 `MessageProcessor` 协议：

```swift
class CustomMessageProcessor: MessageProcessor {
    var supportedMessageTypes: [String] {
        return ["custom_notification", "user_action", "system_alert"]
    }
    
    func canProcess(_ message: RealtimeMessage) -> Bool {
        return supportedMessageTypes.contains(message.type)
    }
    
    func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        switch message.type {
        case "custom_notification":
            return try await processNotification(message)
            
        case "user_action":
            return try await processUserAction(message)
            
        case "system_alert":
            return try await processSystemAlert(message)
            
        default:
            return .skipped
        }
    }
    
    func handleProcessingError(_ error: Error, for message: RealtimeMessage) async -> MessageProcessingResult {
        print("处理消息失败: \(error)")
        return .failed(error)
    }
    
    private func processNotification(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        // 处理自定义通知
        NotificationCenter.default.post(
            name: .customNotificationReceived,
            object: message.content
        )
        return .processed(nil)
    }
}

// 注册处理器
let processor = CustomMessageProcessor()
try RealtimeManager.shared.registerMessageProcessor(processor)
```

### Q: 如何使用自动状态持久化？

**A:** 使用 `@RealtimeStorage` 属性包装器：

```swift
class UserSettings: ObservableObject {
    // 基础类型自动持久化
    @RealtimeStorage("user_volume", defaultValue: 80)
    var userVolume: Int
    
    @RealtimeStorage("is_muted", defaultValue: false)
    var isMuted: Bool
    
    // 复杂类型自动持久化
    @RealtimeStorage("audio_settings", defaultValue: AudioSettings.default)
    var audioSettings: AudioSettings
    
    // 敏感数据使用安全存储
    @SecureRealtimeStorage("auth_token", defaultValue: "")
    var authToken: String
    
    // 值变化时自动保存
    func updateVolume(_ newVolume: Int) {
        userVolume = newVolume  // 自动保存到 UserDefaults
    }
}

// 在 SwiftUI 中使用
struct SettingsView: View {
    @StateObject private var settings = UserSettings()
    
    var body: some View {
        VStack {
            Slider(value: Binding(
                get: { Double(settings.userVolume) },
                set: { settings.userVolume = Int($0) }  // 自动保存
            ), in: 0...100)
            
            Toggle("静音", isOn: $settings.isMuted)  // 自动保存
        }
    }
}
```

## 性能和优化

### Q: 如何优化音量检测的性能？

**A:** 采用以下优化策略：

```swift
// 1. 根据应用状态调整检测频率
class AdaptiveVolumeManager: ObservableObject {
    private var isAppActive = true
    private var isInBackground = false
    
    func adjustDetectionFrequency() {
        let config: VolumeDetectionConfig
        
        if isInBackground {
            // 后台时降低频率
            config = VolumeDetectionConfig(
                detectionInterval: 1000,  // 1秒
                speakingThreshold: 0.5,
                smoothFactor: 0.6
            )
        } else if isAppActive {
            // 前台活跃时正常频率
            config = VolumeDetectionConfig(
                detectionInterval: 300,   // 300ms
                speakingThreshold: 0.3,
                smoothFactor: 0.3
            )
        } else {
            // 前台非活跃时中等频率
            config = VolumeDetectionConfig(
                detectionInterval: 600,   // 600ms
                speakingThreshold: 0.4,
                smoothFactor: 0.4
            )
        }
        
        Task {
            try? await RealtimeManager.shared.updateVolumeDetectionConfig(config)
        }
    }
}

// 2. 批量处理 UI 更新
class BatchedUIUpdater {
    private var pendingVolumeInfos: [UserVolumeInfo] = []
    private var updateTimer: Timer?
    
    func updateVolumeInfos(_ volumeInfos: [UserVolumeInfo]) {
        pendingVolumeInfos = volumeInfos
        
        // 批量更新，避免频繁刷新
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performUIUpdate()
        }
    }
    
    private func performUIUpdate() {
        // 执行实际的 UI 更新
        NotificationCenter.default.post(
            name: .volumeInfosUpdated,
            object: pendingVolumeInfos
        )
    }
}
```

### Q: 如何减少内存使用？

**A:** 遵循以下内存管理最佳实践：

```swift
// 1. 使用弱引用避免循环引用
class RoomViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        RealtimeManager.shared.$connectionState
            .sink { [weak self] state in  // 使用弱引用
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // 清理资源
        cancellables.removeAll()
        Task {
            try? await RealtimeManager.shared.leaveRoom()
        }
    }
}

// 2. 及时释放大对象
class AudioDataManager {
    private var audioBuffers: [Data] = []
    private let maxBufferCount = 10
    
    func addAudioBuffer(_ buffer: Data) {
        audioBuffers.append(buffer)
        
        // 限制缓冲区数量
        if audioBuffers.count > maxBufferCount {
            audioBuffers.removeFirst()
        }
    }
    
    func clearBuffers() {
        audioBuffers.removeAll()
    }
}

// 3. 使用对象池重用对象
class VolumeInfoPool {
    private var pool: [UserVolumeInfo] = []
    
    func getVolumeInfo() -> UserVolumeInfo {
        if let reusable = pool.popLast() {
            return reusable
        } else {
            return UserVolumeInfo(userId: "", volume: 0, isSpeaking: false)
        }
    }
    
    func returnVolumeInfo(_ info: UserVolumeInfo) {
        if pool.count < 50 {  // 限制池大小
            pool.append(info)
        }
    }
}
```

### Q: 如何优化 UI 渲染性能？

**A:** 使用以下 UI 优化技巧：

```swift
// SwiftUI 优化
struct OptimizedVolumeListView: View {
    let volumeInfos: [UserVolumeInfo]
    
    var body: some View {
        LazyVStack {  // 使用 LazyVStack 延迟加载
            ForEach(volumeInfos, id: \.userId) { volumeInfo in
                VolumeRowView(volumeInfo: volumeInfo)
                    .equatable()  // 添加 Equatable 优化重绘
            }
        }
        .drawingGroup()  // 将视图组合为单个绘制操作
    }
}

struct VolumeRowView: View, Equatable {
    let volumeInfo: UserVolumeInfo
    
    var body: some View {
        HStack {
            Text(volumeInfo.userId)
                .font(.caption)
            
            Spacer()
            
            // 使用简单的进度条而不是复杂动画
            ProgressView(value: Double(volumeInfo.volume))
                .progressViewStyle(LinearProgressViewStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    static func == (lhs: VolumeRowView, rhs: VolumeRowView) -> Bool {
        return lhs.volumeInfo.userId == rhs.volumeInfo.userId &&
               lhs.volumeInfo.volume == rhs.volumeInfo.volume &&
               lhs.volumeInfo.isSpeaking == rhs.volumeInfo.isSpeaking
    }
}

// UIKit 优化
class OptimizedVolumeTableViewCell: UITableViewCell {
    static let identifier = "VolumeCell"
    
    @IBOutlet weak var userIdLabel: UILabel!
    @IBOutlet weak var volumeProgressView: UIProgressView!
    @IBOutlet weak var speakingIndicator: UIView!
    
    func configure(with volumeInfo: UserVolumeInfo) {
        userIdLabel.text = volumeInfo.userId
        volumeProgressView.progress = volumeInfo.volume
        
        // 使用简单的颜色变化而不是复杂动画
        speakingIndicator.backgroundColor = volumeInfo.isSpeaking ? .systemGreen : .systemGray
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // 重置状态
        userIdLabel.text = nil
        volumeProgressView.progress = 0
        speakingIndicator.backgroundColor = .systemGray
    }
}
```

## 兼容性

### Q: RealtimeKit 是否支持 Objective-C？

**A:** RealtimeKit 是纯 Swift 框架，不直接支持 Objective-C。如果需要在 Objective-C 项目中使用，可以创建 Swift 桥接文件：

```swift
// RealtimeKitBridge.swift
import RealtimeKit

@objc public class RealtimeKitBridge: NSObject {
    @objc public static let shared = RealtimeKitBridge()
    
    @objc public func configure(appId: String, appCertificate: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let config = RealtimeConfig(appId: appId, appCertificate: appCertificate)
                try await RealtimeManager.shared.configure(provider: .agora, config: config)
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    @objc public func joinRoom(roomId: String, userId: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await RealtimeManager.shared.loginUser(userId: userId, userName: userId, userRole: .broadcaster)
                try await RealtimeManager.shared.joinRoom(roomId: roomId)
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
}
```

### Q: 是否支持 iOS 12 或更早版本？

**A:** RealtimeKit 最低支持 iOS 13.0，不支持更早版本。这是因为：

- 使用了 SwiftUI（iOS 13.0+）
- 使用了 Combine 框架（iOS 13.0+）
- 使用了 Swift Concurrency（iOS 13.0+）

如果需要支持更早版本，建议：

1. 使用条件编译
2. 创建兼容层
3. 或考虑使用其他解决方案

### Q: 是否支持 macOS Catalyst？

**A:** 是的，RealtimeKit 支持 macOS Catalyst。在 Catalyst 应用中使用时注意：

```swift
#if targetEnvironment(macCatalyst)
// Catalyst 特定代码
let config = RealtimeConfig(
    appId: "your-app-id",
    appCertificate: "your-app-certificate",
    enableCatalystOptimizations: true  // 启用 Catalyst 优化
)
#else
// iOS 原生代码
let config = RealtimeConfig(
    appId: "your-app-id",
    appCertificate: "your-app-certificate"
)
#endif
```

## 最佳实践

### Q: 如何组织 RealtimeKit 相关代码？

**A:** 推荐使用以下代码组织结构：

```
YourApp/
├── Realtime/
│   ├── Managers/
│   │   ├── RealtimeCoordinator.swift      # 协调器
│   │   ├── AudioManager.swift             # 音频管理
│   │   └── VolumeManager.swift            # 音量管理
│   ├── Models/
│   │   ├── RoomState.swift                # 房间状态
│   │   ├── UserState.swift                # 用户状态
│   │   └── AudioState.swift               # 音频状态
│   ├── Views/
│   │   ├── SwiftUI/
│   │   │   ├── RoomView.swift             # SwiftUI 房间视图
│   │   │   └── AudioControlView.swift     # SwiftUI 音频控制
│   │   └── UIKit/
│   │       ├── RoomViewController.swift   # UIKit 房间控制器
│   │       └── AudioControlView.swift     # UIKit 音频控制
│   └── Extensions/
│       ├── RealtimeManager+Extensions.swift
│       └── UserRole+Extensions.swift
```

### Q: 如何处理多个房间的场景？

**A:** 虽然 RealtimeKit 主要设计为单房间使用，但可以通过以下方式支持多房间：

```swift
class MultiRoomManager: ObservableObject {
    private var roomManagers: [String: RealtimeManager] = [:]
    @Published var activeRoomId: String?
    
    func createRoom(_ roomId: String) async throws {
        guard roomManagers[roomId] == nil else {
            throw MultiRoomError.roomAlreadyExists
        }
        
        let manager = RealtimeManager()
        let config = RealtimeConfig(/* ... */)
        
        try await manager.configure(provider: .agora, config: config)
        roomManagers[roomId] = manager
    }
    
    func joinRoom(_ roomId: String, userId: String) async throws {
        guard let manager = roomManagers[roomId] else {
            throw MultiRoomError.roomNotFound
        }
        
        // 离开当前房间
        if let currentRoomId = activeRoomId,
           let currentManager = roomManagers[currentRoomId] {
            try await currentManager.leaveRoom()
        }
        
        // 加入新房间
        try await manager.loginUser(userId: userId, userName: userId, userRole: .broadcaster)
        try await manager.joinRoom(roomId: roomId)
        
        activeRoomId = roomId
    }
    
    func leaveRoom(_ roomId: String) async throws {
        guard let manager = roomManagers[roomId] else {
            throw MultiRoomError.roomNotFound
        }
        
        try await manager.leaveRoom()
        try await manager.logoutUser()
        
        if activeRoomId == roomId {
            activeRoomId = nil
        }
    }
    
    func destroyRoom(_ roomId: String) {
        roomManagers.removeValue(forKey: roomId)
        
        if activeRoomId == roomId {
            activeRoomId = nil
        }
    }
}

enum MultiRoomError: LocalizedError {
    case roomAlreadyExists
    case roomNotFound
    
    var errorDescription: String? {
        switch self {
        case .roomAlreadyExists:
            return "房间已存在"
        case .roomNotFound:
            return "房间不存在"
        }
    }
}
```

### Q: 如何实现自定义 UI 主题？

**A:** 使用环境值和主题管理器：

```swift
// 主题定义
struct RealtimeTheme {
    let primaryColor: Color
    let secondaryColor: Color
    let backgroundColor: Color
    let textColor: Color
    let errorColor: Color
    let successColor: Color
    
    static let light = RealtimeTheme(
        primaryColor: .blue,
        secondaryColor: .gray,
        backgroundColor: .white,
        textColor: .black,
        errorColor: .red,
        successColor: .green
    )
    
    static let dark = RealtimeTheme(
        primaryColor: .blue,
        secondaryColor: .gray,
        backgroundColor: .black,
        textColor: .white,
        errorColor: .red,
        successColor: .green
    )
}

// 主题管理器
class ThemeManager: ObservableObject {
    @RealtimeStorage("app_theme", defaultValue: "light")
    private var themeString: String
    
    @Published var currentTheme: RealtimeTheme = .light
    
    init() {
        updateTheme()
    }
    
    func setTheme(_ theme: String) {
        themeString = theme
        updateTheme()
    }
    
    private func updateTheme() {
        switch themeString {
        case "dark":
            currentTheme = .dark
        default:
            currentTheme = .light
        }
    }
}

// 环境键
struct RealtimeThemeKey: EnvironmentKey {
    static let defaultValue = RealtimeTheme.light
}

extension EnvironmentValues {
    var realtimeTheme: RealtimeTheme {
        get { self[RealtimeThemeKey.self] }
        set { self[RealtimeThemeKey.self] = newValue }
    }
}

// 使用主题
struct ThemedRealtimeView: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        ContentView()
            .environment(\.realtimeTheme, themeManager.currentTheme)
            .environmentObject(themeManager)
    }
}

struct ContentView: View {
    @Environment(\.realtimeTheme) var theme
    
    var body: some View {
        VStack {
            Text("RealtimeKit")
                .foregroundColor(theme.textColor)
            
            Button("加入房间") {
                // ...
            }
            .foregroundColor(theme.primaryColor)
        }
        .background(theme.backgroundColor)
    }
}
```

## 故障排除

### Q: 编译时出现 "No such module 'RealtimeKit'" 错误

**A:** 检查以下几点：

1. **确认依赖添加正确**：
   ```swift
   // Package.swift
   dependencies: [
       .package(url: "https://github.com/your-org/RealtimeKit", from: "1.0.0")
   ]
   ```

2. **清理构建缓存**：
   - Xcode: Product → Clean Build Folder
   - 命令行: `rm -rf ~/Library/Developer/Xcode/DerivedData`

3. **检查最低版本要求**：
   - iOS Deployment Target: 13.0+
   - macOS Deployment Target: 10.15+

### Q: 运行时崩溃，提示 "Thread 1: Fatal error: Unexpectedly found nil"

**A:** 通常是因为在配置完成前使用了 RealtimeManager：

```swift
// ❌ 错误：在配置前使用
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 错误：立即使用 RealtimeManager
        RealtimeManager.shared.joinRoom(roomId: "test")  // 崩溃！
        
        return true
    }
}

// ✅ 正确：先配置再使用
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        Task {
            await configureRealtimeKit()
        }
        
        return true
    }
    
    private func configureRealtimeKit() async {
        do {
            let config = RealtimeConfig(appId: "your-app-id", appCertificate: "your-cert")
            try await RealtimeManager.shared.configure(provider: .agora, config: config)
            
            // 现在可以安全使用
            // try await RealtimeManager.shared.joinRoom(roomId: "test")
        } catch {
            print("配置失败: \(error)")
        }
    }
}
```

### Q: 音频功能不工作，没有声音

**A:** 检查以下几点：

1. **权限检查**：
   ```swift
   let permission = AVAudioSession.sharedInstance().recordPermission
   if permission != .granted {
       // 请求权限或引导用户到设置
   }
   ```

2. **音频会话配置**：
   ```swift
   try AVAudioSession.sharedInstance().setCategory(
       .playAndRecord,
       mode: .voiceChat,
       options: [.defaultToSpeaker]
   )
   try AVAudioSession.sharedInstance().setActive(true)
   ```

3. **检查静音状态**：
   ```swift
   if RealtimeManager.shared.isMicrophoneMuted() {
       try await RealtimeManager.shared.muteMicrophone(false)
   }
   ```

### Q: 如何获取更多调试信息？

**A:** 启用详细日志记录：

```swift
// 1. 设置日志级别
let config = RealtimeConfig(
    appId: "your-app-id",
    appCertificate: "your-cert",
    logLevel: .debug  // 启用详细日志
)

// 2. 监听错误事件
NotificationCenter.default.addObserver(
    forName: .realtimeError,
    object: nil,
    queue: .main
) { notification in
    if let error = notification.object as? Error {
        print("RealtimeKit 错误: \(error)")
    }
}

// 3. 使用调试面板
struct DebugView: View {
    @StateObject private var manager = RealtimeManager.shared
    
    var body: some View {
        VStack {
            Text("连接状态: \(manager.connectionState.rawValue)")
            Text("当前会话: \(manager.currentSession?.userId ?? "无")")
            Text("音量信息数量: \(manager.volumeInfos.count)")
            
            Button("导出日志") {
                // 导出调试日志
                let logs = RealtimeLogger.exportLogs()
                // 处理日志...
            }
        }
    }
}
```

---

如果您的问题没有在此 FAQ 中找到答案，请查看 [故障排除指南](Troubleshooting.md) 或联系技术支持。我们会持续更新此文档以包含更多常见问题。