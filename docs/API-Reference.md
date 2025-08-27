# RealtimeKit API 参考文档

本文档提供 RealtimeKit Swift Package 的完整 API 参考，包括所有公开接口、数据模型和使用示例。

## 目录

- [核心管理器](#核心管理器)
- [协议接口](#协议接口)
- [数据模型](#数据模型)
- [错误处理](#错误处理)
- [本地化支持](#本地化支持)
- [自动状态持久化](#自动状态持久化)
- [UI 组件](#ui-组件)

## 核心管理器

### RealtimeManager

`RealtimeManager` 是 RealtimeKit 的核心管理器，提供统一的实时通信功能接口。

```swift
@MainActor
public class RealtimeManager: ObservableObject {
    public static let shared = RealtimeManager()
}
```

#### 配置方法

```swift
// 配置服务商和基础设置
public func configure(provider: ProviderType, config: RealtimeConfig) async throws

// 支持的服务商类型
public enum ProviderType: String, CaseIterable {
    case agora = "agora"
    case tencent = "tencent"
    case zego = "zego"
    case mock = "mock"
}
```

**示例：**

```swift
let config = RealtimeConfig(
    appId: "your-app-id",
    appCertificate: "your-app-certificate",
    logLevel: .info
)

try await RealtimeManager.shared.configure(
    provider: .agora,
    config: config
)
```

#### 用户会话管理

```swift
// 用户登录
public func loginUser(
    userId: String,
    userName: String,
    userRole: UserRole
) async throws

// 用户登出
public func logoutUser() async throws

// 角色切换
public func switchUserRole(_ newRole: UserRole) async throws

// 当前会话状态
@Published public private(set) var currentSession: UserSession?
```

**示例：**

```swift
// 登录为主播
try await RealtimeManager.shared.loginUser(
    userId: "user123",
    userName: "张三",
    userRole: .broadcaster
)

// 切换为连麦嘉宾
try await RealtimeManager.shared.switchUserRole(.coHost)
```

#### 房间管理

```swift
// 加入房间
public func joinRoom(roomId: String) async throws

// 离开房间
public func leaveRoom() async throws

// 连接状态
@Published public private(set) var connectionState: ConnectionState
```

#### 音频控制

```swift
// 麦克风控制
public func muteMicrophone(_ muted: Bool) async throws
public func isMicrophoneMuted() -> Bool

// 音频流控制
public func stopLocalAudioStream() async throws
public func resumeLocalAudioStream() async throws
public func isLocalAudioStreamActive() -> Bool

// 音量控制
public func setAudioMixingVolume(_ volume: Int) async throws
public func setPlaybackSignalVolume(_ volume: Int) async throws
public func setRecordingSignalVolume(_ volume: Int) async throws

// 音频设置状态
@Published public private(set) var audioSettings: AudioSettings
```

**示例：**

```swift
// 静音麦克风
try await RealtimeManager.shared.muteMicrophone(true)

// 设置混音音量为 80%
try await RealtimeManager.shared.setAudioMixingVolume(80)

// 停止本地音频流
try await RealtimeManager.shared.stopLocalAudioStream()
```

#### 音量指示器

```swift
// 启用音量检测
public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws

// 禁用音量检测
public func disableVolumeIndicator() async throws

// 音量信息
@Published public private(set) var volumeInfos: [UserVolumeInfo]
@Published public private(set) var speakingUsers: Set<String>
@Published public private(set) var dominantSpeaker: String?
```

**示例：**

```swift
let config = VolumeDetectionConfig(
    detectionInterval: 300,
    speakingThreshold: 0.3,
    includeLocalUser: true
)

try await RealtimeManager.shared.enableVolumeIndicator(config: config)
```

#### 转推流功能

```swift
// 开始转推流
public func startStreamPush(config: StreamPushConfig) async throws

// 停止转推流
public func stopStreamPush() async throws

// 更新转推流布局
public func updateStreamPushLayout(layout: StreamLayout) async throws

// 转推流状态
@Published public private(set) var streamPushState: StreamPushState
```

#### 媒体中继功能

```swift
// 开始媒体中继
public func startMediaRelay(config: MediaRelayConfig) async throws

// 停止媒体中继
public func stopMediaRelay() async throws

// 更新中继频道
public func updateMediaRelayChannels(config: MediaRelayConfig) async throws

// 媒体中继状态
@Published public private(set) var mediaRelayState: MediaRelayState?
```

## 协议接口

### RTCProvider

RTC (Real-Time Communication) 提供商协议，定义音视频通信功能。

```swift
public protocol RTCProvider: AnyObject {
    // 生命周期管理
    func initialize(config: RTCConfig) async throws
    func createRoom(roomId: String) async throws -> RTCRoom
    func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws
    func leaveRoom() async throws
    
    // 音频控制
    func muteMicrophone(_ muted: Bool) async throws
    func setAudioMixingVolume(_ volume: Int) async throws
    
    // 音量指示器
    func enableVolumeIndicator(config: VolumeDetectionConfig) async throws
    func setVolumeIndicatorHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void)
    
    // Token 管理
    func renewToken(_ newToken: String) async throws
    func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void)
}
```

### RTMProvider

RTM (Real-Time Messaging) 提供商协议，定义实时消息功能。

```swift
public protocol RTMProvider: AnyObject {
    // 生命周期管理
    func initialize(config: RTMConfig) async throws
    
    // 消息功能
    func sendMessage(_ message: RealtimeMessage) async throws
    func subscribe(to channel: String) async throws
    func setMessageHandler(_ handler: @escaping @Sendable (RealtimeMessage) -> Void)
    
    // 连接状态
    func setConnectionStateHandler(_ handler: @escaping @Sendable (ConnectionState) -> Void)
    
    // Token 管理
    func renewToken(_ newToken: String) async throws
    func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void)
}
```

### MessageProcessor

消息处理器协议，用于自定义消息处理逻辑。

```swift
public protocol MessageProcessor: AnyObject {
    var supportedMessageTypes: [String] { get }
    
    func canProcess(_ message: RealtimeMessage) -> Bool
    func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult
    func handleProcessingError(_ error: Error, for message: RealtimeMessage) async -> MessageProcessingResult
}
```

## 数据模型

### UserRole

用户角色枚举，定义不同用户的权限级别。

```swift
public enum UserRole: String, CaseIterable, Codable {
    case broadcaster = "broadcaster"    // 主播
    case audience = "audience"         // 观众
    case coHost = "co_host"           // 连麦嘉宾
    case moderator = "moderator"      // 主持人
    
    // 权限检查
    public var hasAudioPermission: Bool
    public var hasVideoPermission: Bool
    public var canSwitchToRole: Set<UserRole>
}
```

### UserSession

用户会话模型，包含用户的基本信息和状态。

```swift
public struct UserSession: Codable, Equatable {
    public let userId: String
    public let userName: String
    public let userRole: UserRole
    public let roomId: String?
    public let joinTime: Date
    public let lastActiveTime: Date
}
```

### AudioSettings

音频设置模型，包含所有音频相关配置。

```swift
public struct AudioSettings: Codable, Equatable {
    public let microphoneMuted: Bool
    public let audioMixingVolume: Int              // 0-100
    public let playbackSignalVolume: Int           // 0-100
    public let recordingSignalVolume: Int          // 0-100
    public let localAudioStreamActive: Bool
    public let lastModified: Date
    
    // 便捷更新方法
    public func withUpdatedVolume(
        audioMixing: Int? = nil,
        playbackSignal: Int? = nil,
        recordingSignal: Int? = nil
    ) -> AudioSettings
}
```

### VolumeDetectionConfig

音量检测配置模型。

```swift
public struct VolumeDetectionConfig: Codable, Equatable {
    public let detectionInterval: Int      // 检测间隔（毫秒）
    public let speakingThreshold: Float    // 说话音量阈值 (0.0 - 1.0)
    public let silenceThreshold: Float     // 静音音量阈值
    public let includeLocalUser: Bool      // 是否包含本地用户
    public let smoothFactor: Float         // 平滑处理参数
}
```

### UserVolumeInfo

用户音量信息模型。

```swift
public struct UserVolumeInfo: Codable, Equatable {
    public let userId: String
    public let volume: Float               // 0.0 - 1.0
    public let isSpeaking: Bool
    public let timestamp: Date
}
```

### ConnectionState

连接状态枚举。

```swift
public enum ConnectionState: String, CaseIterable, Codable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
}
```

### StreamPushConfig

转推流配置模型。

```swift
public struct StreamPushConfig: Codable, Equatable {
    public let pushUrl: String
    public let resolution: StreamResolution
    public let bitrate: Int
    public let frameRate: Int
    public let layout: StreamLayout
}
```

### MediaRelayConfig

媒体中继配置模型。

```swift
public struct MediaRelayConfig: Codable, Equatable {
    public let sourceChannel: MediaRelayChannelInfo
    public let destinationChannels: [MediaRelayChannelInfo]
    public let relayMode: MediaRelayMode
}
```

## 错误处理

### RealtimeError

统一的错误类型，提供详细的错误信息和本地化描述。

```swift
public enum RealtimeError: LocalizedError, Equatable {
    // 配置错误
    case invalidConfiguration(String)
    case providerNotAvailable(ProviderType)
    
    // 认证错误
    case authenticationFailed(String)
    case tokenExpired
    case invalidToken
    
    // 连接错误
    case connectionFailed(String)
    case networkUnavailable
    case connectionTimeout
    
    // 权限错误
    case insufficientPermissions(UserRole)
    case invalidRoleTransition(from: UserRole, to: UserRole)
    
    // 会话错误
    case noActiveSession
    case sessionExpired
    case duplicateSession
    
    // 音频错误
    case audioInitializationFailed(String)
    case microphonePermissionDenied
    case audioDeviceUnavailable
    
    // 本地化错误描述
    public var errorDescription: String?
    public var failureReason: String?
    public var recoverySuggestion: String?
}
```

**使用示例：**

```swift
do {
    try await RealtimeManager.shared.loginUser(
        userId: "user123",
        userName: "张三",
        userRole: .broadcaster
    )
} catch let error as RealtimeError {
    switch error {
    case .insufficientPermissions(let role):
        print("权限不足：\(role)")
    case .authenticationFailed(let reason):
        print("认证失败：\(reason)")
    default:
        print("错误：\(error.localizedDescription)")
    }
}
```

## 本地化支持

### LocalizationManager

本地化管理器，提供多语言支持。

```swift
@MainActor
public class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    @Published public private(set) var currentLanguage: SupportedLanguage
    
    // 获取本地化字符串
    public func localizedString(for key: String, arguments: [String] = []) -> String
    
    // 切换语言
    public func setLanguage(_ language: SupportedLanguage)
    
    // 自动检测系统语言
    public func detectSystemLanguage() -> SupportedLanguage
}
```

### SupportedLanguage

支持的语言枚举。

```swift
public enum SupportedLanguage: String, CaseIterable, Codable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    
    public var displayName: String
    public var nativeName: String
}
```

## 自动状态持久化

### @RealtimeStorage

自动状态持久化属性包装器，类似于 SwiftUI 的 @AppStorage。

```swift
@propertyWrapper
public struct RealtimeStorage<Value: Codable>: DynamicProperty {
    public init(
        _ key: String,
        defaultValue: Value,
        backend: StorageBackend = UserDefaultsBackend.shared
    )
    
    public var wrappedValue: Value { get set }
    public var projectedValue: Binding<Value> { get }
}
```

**使用示例：**

```swift
class SettingsManager: ObservableObject {
    @RealtimeStorage("user_volume", defaultValue: 80)
    var userVolume: Int
    
    @RealtimeStorage("is_muted", defaultValue: false)
    var isMuted: Bool
    
    @RealtimeStorage("audio_settings", defaultValue: AudioSettings.default)
    var audioSettings: AudioSettings
}
```

### @SecureRealtimeStorage

安全存储属性包装器，用于敏感数据（如 Token）。

```swift
@propertyWrapper
public struct SecureRealtimeStorage<Value: Codable>: DynamicProperty {
    public init(
        _ key: String,
        defaultValue: Value,
        backend: StorageBackend = KeychainBackend.shared
    )
}
```

**使用示例：**

```swift
class TokenManager: ObservableObject {
    @SecureRealtimeStorage("rtc_token", defaultValue: "")
    var rtcToken: String
    
    @SecureRealtimeStorage("rtm_token", defaultValue: "")
    var rtmToken: String
}
```

## UI 组件

### SwiftUI 组件

#### ConnectionStateIndicatorView

连接状态指示器组件。

```swift
public struct ConnectionStateIndicatorView: View {
    public let state: ConnectionState
    public let showText: Bool
    
    public init(state: ConnectionState, showText: Bool = true)
}
```

#### VolumeVisualizationView

音量可视化组件。

```swift
public struct VolumeVisualizationView: View {
    public let volumeInfos: [UserVolumeInfo]
    public let style: VolumeVisualizationStyle
    
    public init(
        volumeInfos: [UserVolumeInfo],
        style: VolumeVisualizationStyle = .waveform
    )
}
```

#### AudioControlPanelView

音频控制面板组件。

```swift
public struct AudioControlPanelView: View {
    @StateObject private var manager = RealtimeManager.shared
    
    public init()
}
```

### UIKit 组件

#### RealtimeViewController

基础实时通信视图控制器。

```swift
open class RealtimeViewController: UIViewController {
    public let manager = RealtimeManager.shared
    
    // 代理方法
    open func realtimeManager(_ manager: RealtimeManager, didUpdateConnectionState state: ConnectionState)
    open func realtimeManager(_ manager: RealtimeManager, didUpdateVolumeInfos volumeInfos: [UserVolumeInfo])
    open func realtimeManager(_ manager: RealtimeManager, didEncounterError error: RealtimeError)
}
```

#### VolumeIndicatorView

音量指示器 UIView 组件。

```swift
public class VolumeIndicatorView: UIView {
    public var volumeInfos: [UserVolumeInfo] = [] { didSet { updateDisplay() } }
    public var style: VolumeVisualizationStyle = .waveform
    
    public func updateDisplay()
}
```

## 使用示例

### 完整的 SwiftUI 应用示例

```swift
import SwiftUI
import RealtimeKit

@main
struct RealtimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        await configureRealtimeKit()
                    }
                }
        }
    }
    
    private func configureRealtimeKit() async {
        do {
            let config = RealtimeConfig(
                appId: "your-app-id",
                appCertificate: "your-app-certificate"
            )
            
            try await RealtimeManager.shared.configure(
                provider: .agora,
                config: config
            )
        } catch {
            print("配置失败: \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = RealtimeManager.shared
    @State private var roomId = ""
    @State private var userId = ""
    @State private var userName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 用户信息输入
                Group {
                    TextField("房间 ID", text: $roomId)
                    TextField("用户 ID", text: $userId)
                    TextField("用户名", text: $userName)
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // 连接状态
                ConnectionStateIndicatorView(state: manager.connectionState)
                
                // 控制按钮
                HStack {
                    Button("加入房间") {
                        Task {
                            await joinRoom()
                        }
                    }
                    .disabled(roomId.isEmpty || userId.isEmpty)
                    
                    Button("离开房间") {
                        Task {
                            await leaveRoom()
                        }
                    }
                    .disabled(manager.connectionState != .connected)
                }
                
                // 音频控制
                AudioControlPanelView()
                
                // 音量可视化
                VolumeVisualizationView(volumeInfos: manager.volumeInfos)
                
                Spacer()
            }
            .padding()
            .navigationTitle("RealtimeKit Demo")
        }
    }
    
    private func joinRoom() async {
        do {
            try await manager.loginUser(
                userId: userId,
                userName: userName,
                userRole: .broadcaster
            )
            
            try await manager.joinRoom(roomId: roomId)
            
            // 启用音量检测
            let volumeConfig = VolumeDetectionConfig(
                detectionInterval: 300,
                speakingThreshold: 0.3
            )
            try await manager.enableVolumeIndicator(config: volumeConfig)
            
        } catch {
            print("加入房间失败: \(error)")
        }
    }
    
    private func leaveRoom() async {
        do {
            try await manager.leaveRoom()
            try await manager.logoutUser()
        } catch {
            print("离开房间失败: \(error)")
        }
    }
}
```

### 完整的 UIKit 应用示例

```swift
import UIKit
import RealtimeKit
import Combine

class MainViewController: RealtimeViewController {
    @IBOutlet weak var roomIdTextField: UITextField!
    @IBOutlet weak var userIdTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var leaveButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var volumeIndicatorView: VolumeIndicatorView!
    
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        configureRealtimeKit()
    }
    
    private func setupUI() {
        title = "RealtimeKit Demo"
        leaveButton.isEnabled = false
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 100
        volumeSlider.value = 80
    }
    
    private func setupBindings() {
        // 监听连接状态变化
        manager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateConnectionStatus(state)
            }
            .store(in: &cancellables)
        
        // 监听音频设置变化
        manager.$audioSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.updateAudioControls(settings)
            }
            .store(in: &cancellables)
        
        // 监听音量信息变化
        manager.$volumeInfos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumeInfos in
                self?.volumeIndicatorView.volumeInfos = volumeInfos
            }
            .store(in: &cancellables)
    }
    
    private func configureRealtimeKit() {
        Task {
            do {
                let config = RealtimeConfig(
                    appId: "your-app-id",
                    appCertificate: "your-app-certificate"
                )
                
                try await manager.configure(
                    provider: .agora,
                    config: config
                )
            } catch {
                showError("配置失败: \(error)")
            }
        }
    }
    
    @IBAction func joinButtonTapped(_ sender: UIButton) {
        guard let roomId = roomIdTextField.text, !roomId.isEmpty,
              let userId = userIdTextField.text, !userId.isEmpty,
              let userName = userNameTextField.text, !userName.isEmpty else {
            showError("请填写完整信息")
            return
        }
        
        Task {
            do {
                try await manager.loginUser(
                    userId: userId,
                    userName: userName,
                    userRole: .broadcaster
                )
                
                try await manager.joinRoom(roomId: roomId)
                
                // 启用音量检测
                let volumeConfig = VolumeDetectionConfig(
                    detectionInterval: 300,
                    speakingThreshold: 0.3
                )
                try await manager.enableVolumeIndicator(config: volumeConfig)
                
            } catch {
                await MainActor.run {
                    showError("加入房间失败: \(error)")
                }
            }
        }
    }
    
    @IBAction func leaveButtonTapped(_ sender: UIButton) {
        Task {
            do {
                try await manager.leaveRoom()
                try await manager.logoutUser()
            } catch {
                await MainActor.run {
                    showError("离开房间失败: \(error)")
                }
            }
        }
    }
    
    @IBAction func muteButtonTapped(_ sender: UIButton) {
        Task {
            do {
                let isMuted = manager.audioSettings.microphoneMuted
                try await manager.muteMicrophone(!isMuted)
            } catch {
                await MainActor.run {
                    showError("麦克风控制失败: \(error)")
                }
            }
        }
    }
    
    @IBAction func volumeSliderChanged(_ sender: UISlider) {
        Task {
            do {
                try await manager.setAudioMixingVolume(Int(sender.value))
            } catch {
                await MainActor.run {
                    showError("音量设置失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - RealtimeViewController Overrides
    
    override func realtimeManager(_ manager: RealtimeManager, didUpdateConnectionState state: ConnectionState) {
        updateConnectionStatus(state)
    }
    
    override func realtimeManager(_ manager: RealtimeManager, didUpdateVolumeInfos volumeInfos: [UserVolumeInfo]) {
        volumeIndicatorView.volumeInfos = volumeInfos
    }
    
    override func realtimeManager(_ manager: RealtimeManager, didEncounterError error: RealtimeError) {
        showError(error.localizedDescription)
    }
    
    // MARK: - Private Methods
    
    private func updateConnectionStatus(_ state: ConnectionState) {
        connectionStatusLabel.text = state.localizedDescription
        
        switch state {
        case .connected:
            joinButton.isEnabled = false
            leaveButton.isEnabled = true
            connectionStatusLabel.textColor = .systemGreen
        case .disconnected:
            joinButton.isEnabled = true
            leaveButton.isEnabled = false
            connectionStatusLabel.textColor = .systemRed
        case .connecting, .reconnecting:
            joinButton.isEnabled = false
            leaveButton.isEnabled = false
            connectionStatusLabel.textColor = .systemOrange
        case .failed:
            joinButton.isEnabled = true
            leaveButton.isEnabled = false
            connectionStatusLabel.textColor = .systemRed
        }
    }
    
    private func updateAudioControls(_ settings: AudioSettings) {
        muteButton.setTitle(settings.microphoneMuted ? "取消静音" : "静音", for: .normal)
        volumeSlider.value = Float(settings.audioMixingVolume)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "错误",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
```

这个 API 参考文档提供了 RealtimeKit 的完整接口说明和使用示例，开发者可以根据这个文档快速上手并集成到自己的项目中。