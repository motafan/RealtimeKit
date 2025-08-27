# RealtimeKit 快速开始指南

本指南将帮助您快速集成 RealtimeKit 到您的 iOS/macOS 应用中，实现实时音视频通信功能。

## 目录

- [环境准备](#环境准备)
- [安装配置](#安装配置)
- [基础集成](#基础集成)
- [SwiftUI 集成](#swiftui-集成)
- [UIKit 集成](#uikit-集成)
- [高级功能](#高级功能)
- [常见问题](#常见问题)

## 环境准备

### 系统要求

- **iOS**: 13.0 及以上版本
- **macOS**: 10.15 及以上版本
- **Swift**: 6.2 及以上版本
- **Xcode**: 15.0 及以上版本

### 权限配置

在 `Info.plist` 中添加必要的权限：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>此应用需要访问麦克风进行语音通话</string>

<key>NSCameraUsageDescription</key>
<string>此应用需要访问摄像头进行视频通话</string>

<key>NSLocalNetworkUsageDescription</key>
<string>此应用需要访问本地网络进行实时通信</string>
```

## 安装配置

### 1. 添加 Package 依赖

#### 通过 Xcode

1. 打开 Xcode 项目
2. 选择 `File` → `Add Package Dependencies...`
3. 输入仓库 URL：`https://github.com/your-org/RealtimeKit`
4. 选择版本并添加到项目

#### 通过 Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/your-org/RealtimeKit", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: ["RealtimeKit"]
        )
    ]
)
```

### 2. 导入模块

```swift
// 完整功能导入
import RealtimeKit

// 或按需导入
import RealtimeCore      // 核心功能
import RealtimeUIKit     // UIKit 集成
import RealtimeSwiftUI   // SwiftUI 集成
import RealtimeAgora     // 声网服务商
```

## 基础集成

### 1. 应用配置

在 `AppDelegate` 或 `App` 中配置 RealtimeKit：

#### SwiftUI App

```swift
import SwiftUI
import RealtimeKit

@main
struct MyRealtimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await configureRealtimeKit()
                }
        }
    }
    
    private func configureRealtimeKit() async {
        do {
            let config = RealtimeConfig(
                appId: "your-agora-app-id",
                appCertificate: "your-agora-app-certificate",
                logLevel: .info
            )
            
            try await RealtimeManager.shared.configure(
                provider: .agora,
                config: config
            )
            
            print("RealtimeKit 配置成功")
        } catch {
            print("RealtimeKit 配置失败: \(error)")
        }
    }
}
```

#### UIKit AppDelegate

```swift
import UIKit
import RealtimeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        Task {
            await configureRealtimeKit()
        }
        
        return true
    }
    
    private func configureRealtimeKit() async {
        do {
            let config = RealtimeConfig(
                appId: "your-agora-app-id",
                appCertificate: "your-agora-app-certificate",
                logLevel: .info
            )
            
            try await RealtimeManager.shared.configure(
                provider: .agora,
                config: config
            )
            
            print("RealtimeKit 配置成功")
        } catch {
            print("RealtimeKit 配置失败: \(error)")
        }
    }
}
```

### 2. 获取服务商配置

#### 声网 Agora

1. 注册 [Agora 开发者账号](https://www.agora.io/)
2. 创建项目获取 App ID 和 App Certificate
3. 在项目中使用这些配置

```swift
let config = RealtimeConfig(
    appId: "your-agora-app-id",
    appCertificate: "your-agora-app-certificate"
)
```

## SwiftUI 集成

### 1. 基础 SwiftUI 视图

```swift
import SwiftUI
import RealtimeKit

struct RealtimeView: View {
    @StateObject private var manager = RealtimeManager.shared
    @State private var roomId = ""
    @State private var userId = ""
    @State private var userName = ""
    @State private var isInRoom = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 输入区域
                inputSection
                
                // 连接状态
                ConnectionStateIndicatorView(state: manager.connectionState)
                
                // 控制按钮
                controlButtons
                
                // 音频控制面板
                if isInRoom {
                    AudioControlPanelView()
                }
                
                // 音量可视化
                if !manager.volumeInfos.isEmpty {
                    VolumeVisualizationView(volumeInfos: manager.volumeInfos)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("实时通信")
        }
    }
    
    private var inputSection: some View {
        Group {
            TextField("房间 ID", text: $roomId)
            TextField("用户 ID", text: $userId)
            TextField("用户名", text: $userName)
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .disabled(isInRoom)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            Button(isInRoom ? "离开房间" : "加入房间") {
                Task {
                    if isInRoom {
                        await leaveRoom()
                    } else {
                        await joinRoom()
                    }
                }
            }
            .disabled(roomId.isEmpty || userId.isEmpty || userName.isEmpty)
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func joinRoom() async {
        do {
            // 1. 用户登录
            try await manager.loginUser(
                userId: userId,
                userName: userName,
                userRole: .broadcaster
            )
            
            // 2. 加入房间
            try await manager.joinRoom(roomId: roomId)
            
            // 3. 启用音量检测
            let volumeConfig = VolumeDetectionConfig(
                detectionInterval: 300,
                speakingThreshold: 0.3,
                includeLocalUser: true
            )
            try await manager.enableVolumeIndicator(config: volumeConfig)
            
            isInRoom = true
            
        } catch {
            print("加入房间失败: \(error)")
            // 显示错误提示
        }
    }
    
    private func leaveRoom() async {
        do {
            try await manager.disableVolumeIndicator()
            try await manager.leaveRoom()
            try await manager.logoutUser()
            
            isInRoom = false
            
        } catch {
            print("离开房间失败: \(error)")
        }
    }
}
```

### 2. 自定义音频控制组件

```swift
struct CustomAudioControlView: View {
    @StateObject private var manager = RealtimeManager.shared
    
    var body: some View {
        VStack(spacing: 15) {
            Text("音频控制")
                .font(.headline)
            
            // 麦克风控制
            HStack {
                Image(systemName: manager.audioSettings.microphoneMuted ? "mic.slash" : "mic")
                    .foregroundColor(manager.audioSettings.microphoneMuted ? .red : .green)
                
                Button(manager.audioSettings.microphoneMuted ? "取消静音" : "静音") {
                    Task {
                        try? await manager.muteMicrophone(!manager.audioSettings.microphoneMuted)
                    }
                }
                .buttonStyle(.bordered)
            }
            
            // 音量控制
            VStack {
                Text("混音音量: \(manager.audioSettings.audioMixingVolume)")
                Slider(
                    value: Binding(
                        get: { Double(manager.audioSettings.audioMixingVolume) },
                        set: { newValue in
                            Task {
                                try? await manager.setAudioMixingVolume(Int(newValue))
                            }
                        }
                    ),
                    in: 0...100,
                    step: 1
                )
            }
            
            // 播放音量控制
            VStack {
                Text("播放音量: \(manager.audioSettings.playbackSignalVolume)")
                Slider(
                    value: Binding(
                        get: { Double(manager.audioSettings.playbackSignalVolume) },
                        set: { newValue in
                            Task {
                                try? await manager.setPlaybackSignalVolume(Int(newValue))
                            }
                        }
                    ),
                    in: 0...100,
                    step: 1
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
```

## UIKit 集成

### 1. 基础 UIKit 视图控制器

```swift
import UIKit
import RealtimeKit
import Combine

class RealtimeViewController: UIViewController {
    
    // MARK: - UI Elements
    @IBOutlet weak var roomIdTextField: UITextField!
    @IBOutlet weak var userIdTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var leaveButton: UIButton!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var audioControlStackView: UIStackView!
    
    // MARK: - Properties
    private let manager = RealtimeManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInRoom = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "实时通信"
        leaveButton.isEnabled = false
        
        // 设置按钮样式
        joinButton.layer.cornerRadius = 8
        leaveButton.layer.cornerRadius = 8
        
        setupAudioControls()
    }
    
    private func setupAudioControls() {
        // 创建音频控制组件
        let muteButton = UIButton(type: .system)
        muteButton.setTitle("静音", for: .normal)
        muteButton.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        
        let volumeSlider = UISlider()
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 100
        volumeSlider.value = 80
        volumeSlider.addTarget(self, action: #selector(volumeSliderChanged), for: .valueChanged)
        
        audioControlStackView.addArrangedSubview(muteButton)
        audioControlStackView.addArrangedSubview(volumeSlider)
        audioControlStackView.isHidden = true
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
                self?.updateVolumeDisplay(volumeInfos)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    @IBAction func joinButtonTapped(_ sender: UIButton) {
        guard validateInput() else { return }
        
        Task {
            await joinRoom()
        }
    }
    
    @IBAction func leaveButtonTapped(_ sender: UIButton) {
        Task {
            await leaveRoom()
        }
    }
    
    @objc private func muteButtonTapped(_ sender: UIButton) {
        Task {
            do {
                let isMuted = manager.audioSettings.microphoneMuted
                try await manager.muteMicrophone(!isMuted)
            } catch {
                showError("麦克风控制失败: \(error)")
            }
        }
    }
    
    @objc private func volumeSliderChanged(_ sender: UISlider) {
        Task {
            do {
                try await manager.setAudioMixingVolume(Int(sender.value))
            } catch {
                showError("音量设置失败: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func validateInput() -> Bool {
        guard let roomId = roomIdTextField.text, !roomId.isEmpty,
              let userId = userIdTextField.text, !userId.isEmpty,
              let userName = userNameTextField.text, !userName.isEmpty else {
            showError("请填写完整信息")
            return false
        }
        return true
    }
    
    private func joinRoom() async {
        do {
            guard let roomId = roomIdTextField.text,
                  let userId = userIdTextField.text,
                  let userName = userNameTextField.text else { return }
            
            // 1. 用户登录
            try await manager.loginUser(
                userId: userId,
                userName: userName,
                userRole: .broadcaster
            )
            
            // 2. 加入房间
            try await manager.joinRoom(roomId: roomId)
            
            // 3. 启用音量检测
            let volumeConfig = VolumeDetectionConfig(
                detectionInterval: 300,
                speakingThreshold: 0.3,
                includeLocalUser: true
            )
            try await manager.enableVolumeIndicator(config: volumeConfig)
            
            await MainActor.run {
                isInRoom = true
                updateUIForRoomState()
            }
            
        } catch {
            await MainActor.run {
                showError("加入房间失败: \(error)")
            }
        }
    }
    
    private func leaveRoom() async {
        do {
            try await manager.disableVolumeIndicator()
            try await manager.leaveRoom()
            try await manager.logoutUser()
            
            await MainActor.run {
                isInRoom = false
                updateUIForRoomState()
            }
            
        } catch {
            await MainActor.run {
                showError("离开房间失败: \(error)")
            }
        }
    }
    
    private func updateUIForRoomState() {
        joinButton.isEnabled = !isInRoom
        leaveButton.isEnabled = isInRoom
        audioControlStackView.isHidden = !isInRoom
        
        roomIdTextField.isEnabled = !isInRoom
        userIdTextField.isEnabled = !isInRoom
        userNameTextField.isEnabled = !isInRoom
    }
    
    private func updateConnectionStatus(_ state: ConnectionState) {
        connectionStatusLabel.text = "状态: \(state.localizedDescription)"
        
        switch state {
        case .connected:
            connectionStatusLabel.textColor = .systemGreen
        case .connecting, .reconnecting:
            connectionStatusLabel.textColor = .systemOrange
        case .disconnected, .failed:
            connectionStatusLabel.textColor = .systemRed
        }
    }
    
    private func updateAudioControls(_ settings: AudioSettings) {
        // 更新音频控制 UI
        if let muteButton = audioControlStackView.arrangedSubviews.first as? UIButton {
            muteButton.setTitle(settings.microphoneMuted ? "取消静音" : "静音", for: .normal)
            muteButton.backgroundColor = settings.microphoneMuted ? .systemRed : .systemGreen
        }
        
        if let volumeSlider = audioControlStackView.arrangedSubviews.last as? UISlider {
            volumeSlider.value = Float(settings.audioMixingVolume)
        }
    }
    
    private func updateVolumeDisplay(_ volumeInfos: [UserVolumeInfo]) {
        // 更新音量显示
        print("音量信息更新: \(volumeInfos.count) 个用户")
        for info in volumeInfos {
            if info.isSpeaking {
                print("用户 \(info.userId) 正在说话，音量: \(info.volume)")
            }
        }
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

### 2. 自定义音量指示器视图

```swift
import UIKit
import RealtimeKit

class VolumeIndicatorView: UIView {
    
    // MARK: - Properties
    var volumeInfos: [UserVolumeInfo] = [] {
        didSet {
            updateDisplay()
        }
    }
    
    private var userViews: [String: UIView] = [:]
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
    }
    
    // MARK: - Update Display
    private func updateDisplay() {
        // 清除旧的视图
        userViews.values.forEach { $0.removeFromSuperview() }
        userViews.removeAll()
        
        // 创建新的用户音量视图
        for (index, volumeInfo) in volumeInfos.enumerated() {
            let userView = createUserVolumeView(for: volumeInfo, at: index)
            addSubview(userView)
            userViews[volumeInfo.userId] = userView
        }
        
        layoutUserViews()
    }
    
    private func createUserVolumeView(for volumeInfo: UserVolumeInfo, at index: Int) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = volumeInfo.isSpeaking ? UIColor.systemGreen : UIColor.systemGray4
        containerView.layer.cornerRadius = 4
        
        // 用户 ID 标签
        let userLabel = UILabel()
        userLabel.text = volumeInfo.userId
        userLabel.font = UIFont.systemFont(ofSize: 12)
        userLabel.textAlignment = .center
        userLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 音量条
        let volumeBar = UIView()
        volumeBar.backgroundColor = UIColor.systemBlue
        volumeBar.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(userLabel)
        containerView.addSubview(volumeBar)
        
        // 设置约束
        NSLayoutConstraint.activate([
            userLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            userLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            userLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            
            volumeBar.topAnchor.constraint(equalTo: userLabel.bottomAnchor, constant: 4),
            volumeBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            volumeBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            volumeBar.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: CGFloat(volumeInfo.volume), constant: -8)
        ])
        
        return containerView
    }
    
    private func layoutUserViews() {
        let userCount = userViews.count
        guard userCount > 0 else { return }
        
        let itemWidth: CGFloat = 80
        let itemHeight: CGFloat = 60
        let spacing: CGFloat = 10
        
        let totalWidth = CGFloat(userCount) * itemWidth + CGFloat(userCount - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2
        
        for (index, (_, view)) in userViews.enumerated() {
            let x = startX + CGFloat(index) * (itemWidth + spacing)
            let y = (bounds.height - itemHeight) / 2
            
            view.frame = CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutUserViews()
    }
}
```

## 高级功能

### 1. 转推流功能

```swift
// 配置转推流
let streamConfig = StreamPushConfig(
    pushUrl: "rtmp://your-streaming-server.com/live/stream-key",
    resolution: .resolution720p,
    bitrate: 1000,
    frameRate: 30,
    layout: StreamLayout(
        backgroundColor: "#000000",
        regions: [
            StreamRegion(
                userId: "user1",
                x: 0, y: 0, width: 640, height: 360,
                zOrder: 1, alpha: 1.0
            )
        ]
    )
)

// 开始转推流
try await RealtimeManager.shared.startStreamPush(config: streamConfig)

// 停止转推流
try await RealtimeManager.shared.stopStreamPush()
```

### 2. 媒体中继功能

```swift
// 配置媒体中继
let relayConfig = MediaRelayConfig(
    sourceChannel: MediaRelayChannelInfo(
        channelName: "source-room",
        token: "source-token",
        userId: "relay-user"
    ),
    destinationChannels: [
        MediaRelayChannelInfo(
            channelName: "dest-room-1",
            token: "dest-token-1",
            userId: "relay-user"
        ),
        MediaRelayChannelInfo(
            channelName: "dest-room-2",
            token: "dest-token-2",
            userId: "relay-user"
        )
    ],
    relayMode: .oneToMany
)

// 开始媒体中继
try await RealtimeManager.shared.startMediaRelay(config: relayConfig)

// 停止媒体中继
try await RealtimeManager.shared.stopMediaRelay()
```

### 3. 自动状态持久化

```swift
import RealtimeKit

class UserSettingsManager: ObservableObject {
    // 自动持久化用户偏好
    @RealtimeStorage("preferred_volume", defaultValue: 80)
    var preferredVolume: Int
    
    @RealtimeStorage("auto_mute_on_join", defaultValue: false)
    var autoMuteOnJoin: Bool
    
    @RealtimeStorage("last_user_name", defaultValue: "")
    var lastUserName: String
    
    // 安全存储敏感信息
    @SecureRealtimeStorage("user_token", defaultValue: "")
    var userToken: String
    
    func applySettings() async {
        do {
            // 应用音量设置
            try await RealtimeManager.shared.setAudioMixingVolume(preferredVolume)
            
            // 应用静音设置
            if autoMuteOnJoin {
                try await RealtimeManager.shared.muteMicrophone(true)
            }
        } catch {
            print("应用设置失败: \(error)")
        }
    }
}
```

### 4. 本地化支持

```swift
// 切换语言
LocalizationManager.shared.setLanguage(.simplifiedChinese)

// 获取本地化字符串
let welcomeMessage = LocalizationManager.shared.localizedString(
    for: "welcome_message",
    arguments: ["张三"]
)

// 在 SwiftUI 中使用本地化组件
LocalizedText("connection_status")
LocalizedButton("join_room") {
    // 加入房间逻辑
}
```

## 常见问题

### Q: 如何处理网络连接异常？

A: RealtimeKit 内置了自动重连机制，您可以监听连接状态变化：

```swift
manager.$connectionState
    .sink { state in
        switch state {
        case .reconnecting:
            // 显示重连提示
            showReconnectingIndicator()
        case .failed:
            // 显示连接失败提示
            showConnectionFailedAlert()
        case .connected:
            // 隐藏提示，恢复正常
            hideConnectionIndicators()
        default:
            break
        }
    }
    .store(in: &cancellables)
```

### Q: 如何自定义音量检测参数？

A: 您可以通过 `VolumeDetectionConfig` 自定义检测参数：

```swift
let config = VolumeDetectionConfig(
    detectionInterval: 200,        // 检测间隔 200ms
    speakingThreshold: 0.2,        // 降低说话阈值
    silenceThreshold: 0.05,        // 静音阈值
    includeLocalUser: false,       // 不包含本地用户
    smoothFactor: 0.5              // 增加平滑处理
)

try await manager.enableVolumeIndicator(config: config)
```

### Q: 如何处理权限请求？

A: 在加入房间前检查和请求权限：

```swift
import AVFoundation

func checkPermissions() async -> Bool {
    let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
    
    switch microphoneStatus {
    case .granted:
        return true
    case .denied:
        // 引导用户到设置页面
        await showPermissionDeniedAlert()
        return false
    case .undetermined:
        // 请求权限
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    @unknown default:
        return false
    }
}
```

### Q: 如何优化性能？

A: 遵循以下最佳实践：

1. **合理设置音量检测间隔**：不要设置过短的检测间隔
2. **及时释放资源**：离开房间时及时调用 `leaveRoom()` 和 `logoutUser()`
3. **使用弱引用**：在闭包中使用 `[weak self]` 避免循环引用
4. **批量更新 UI**：避免频繁的 UI 更新

```swift
// 优化音量检测间隔
let config = VolumeDetectionConfig(
    detectionInterval: 500,  // 500ms 间隔足够大多数场景
    speakingThreshold: 0.3
)

// 及时清理资源
deinit {
    Task {
        try? await RealtimeManager.shared.leaveRoom()
        try? await RealtimeManager.shared.logoutUser()
    }
}
```

通过这个快速开始指南，您应该能够成功集成 RealtimeKit 并实现基本的实时通信功能。如需更详细的信息，请参考 [API 参考文档](API-Reference.md) 和 [最佳实践](Best-Practices.md)。