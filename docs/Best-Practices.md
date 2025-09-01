# RealtimeKit 最佳实践指南

本指南提供使用 RealtimeKit 的最佳实践，帮助您构建高质量、高性能的实时通信应用。RealtimeKit 遵循模块化、协议导向的设计，通过提供者抽象实现无缝切换不同的实时通信服务提供商，同时保持一致的 API 接口。

## 目录

- [架构设计](#架构设计)
- [性能优化](#性能优化)
- [错误处理](#错误处理)
- [状态管理](#状态管理)
- [UI/UX 设计](#uiux-设计)
- [测试策略](#测试策略)
- [安全考虑](#安全考虑)
- [部署和监控](#部署和监控)

## 平台兼容性和服务商选择

### 平台支持策略

RealtimeKit 采用平台特定的服务商支持策略：

#### iOS 平台
- **Agora**: 生产环境首选，功能完整，稳定可靠
  - 全球覆盖，低延迟网络
  - 完整的 RTC 和 RTM 功能支持
  - 支持转推流和媒体中继
  - 企业级可靠性和技术支持
- **Mock Provider**: 适用于开发和测试阶段

#### macOS 平台
- **Mock Provider**: 唯一可用选项
  - 用于开发和测试
  - 模拟完整的 API 行为
  - 支持基础功能验证
- **未来支持**: 计划支持其他跨平台服务商

### 跨平台开发最佳实践

#### 1. 条件编译策略

```swift
// 推荐的平台适配模式
class PlatformProviderManager {
    static func createProvider() -> ProviderType {
        #if os(iOS)
        return .agora
        #elseif os(macOS)
        return .mock
        #else
        return .mock
        #endif
    }
    
    static func validateFeature(_ feature: ProviderFeature) throws {
        let supportedFeatures = getSupportedFeatures()
        guard supportedFeatures.contains(feature) else {
            throw RealtimeError.featureNotSupported(
                "\(feature.rawValue) 在当前平台不支持"
            )
        }
    }
    
    private static func getSupportedFeatures() -> Set<ProviderFeature> {
        #if os(iOS)
        return [.audioStreaming, .videoStreaming, .streamPush, .mediaRelay, .volumeIndicator, .messageProcessing]
        #else
        return [.messageProcessing, .volumeIndicator]
        #endif
    }
}
```

#### 2. 平台抽象层

```swift
protocol PlatformAdapter {
    func configureProvider() async throws
    func supportedFeatures() -> Set<ProviderFeature>
    func handlePlatformSpecificError(_ error: Error) -> RealtimeError
}

#if os(iOS)
class iOSPlatformAdapter: PlatformAdapter {
    func configureProvider() async throws {
        let config = RealtimeConfig(
            appId: "your-agora-app-id",
            appCertificate: "your-agora-certificate"
        )
        try await RealtimeManager.shared.configure(provider: .agora, config: config)
    }
    
    func supportedFeatures() -> Set<ProviderFeature> {
        return [.audioStreaming, .videoStreaming, .streamPush, .mediaRelay]
    }
}
#endif

#if os(macOS)
class macOSPlatformAdapter: PlatformAdapter {
    func configureProvider() async throws {
        let config = RealtimeConfig(appId: "mock-app-id")
        try await RealtimeManager.shared.configure(provider: .mock, config: config)
    }
    
    func supportedFeatures() -> Set<ProviderFeature> {
        return [.messageProcessing, .volumeIndicator]
    }
}
#endif
```

### 选择合适的服务商

根据您的需求和目标平台选择合适的服务商：

### Agora 最佳实践

#### 1. 配置优化

```swift
// 生产环境配置
let agoraConfig = AgoraProviderFactory.AgoraConfiguration(
    enableCloudProxy: true,          // 在网络受限环境启用
    enableAudioVolumeIndication: true, // 启用音量检测
    enableLocalizedErrors: true,     // 启用本地化错误
    logLevel: .warn,                 // 生产环境使用 warn 级别
    region: .china                   // 根据用户地理位置选择
)

let factory = AgoraProviderFactory(configuration: agoraConfig)
```

#### 2. Token 管理

```swift
// 实现 Token 自动续期
rtcProvider.onTokenWillExpire { secondsToExpire in
    Task {
        // 从服务器获取新 Token
        let newToken = try await fetchNewTokenFromServer()
        try await rtcProvider.renewToken(newToken)
    }
}

rtmProvider.onTokenWillExpire {
    Task {
        let newToken = try await fetchNewRTMTokenFromServer()
        try await rtmProvider.renewToken(newToken)
    }
}
```

#### 3. 错误处理

```swift
// 处理 Agora 特定错误
do {
    try await rtcProvider.joinRoom(roomId: roomId, userId: userId, userRole: .broadcaster)
} catch let error as RealtimeError {
    switch error {
    case .connectionError(let message) where message.contains("token"):
        // Token 相关错误，尝试刷新 Token
        await refreshTokenAndRetry()
    case .networkUnavailable:
        // 网络问题，启用云代理
        await enableCloudProxyAndRetry()
    default:
        // 其他错误处理
        handleGenericError(error)
    }
}
```

#### 4. 性能优化

```swift
// 音量检测优化
let volumeConfig = VolumeDetectionConfig(
    detectionInterval: 300,          // 适中的检测间隔
    speakingThreshold: 0.3,          // 根据环境调整
    includeLocalUser: false,         // 减少不必要的处理
    smoothFactor: 0.3                // 平滑音量变化
)

// 推流参数优化
let streamConfig = try StreamPushConfig(
    url: "rtmp://your-server.com/live/stream",
    layout: StreamLayout(canvasWidth: 1280, canvasHeight: 720),
    audioConfig: StreamAudioConfig(
        sampleRate: 48000,
        bitrate: 128,               // 根据网络条件调整
        channels: 2
    ),
    videoConfig: StreamVideoConfig(
        width: 1280,
        height: 720,
        bitrate: 2000,              // 根据网络条件调整
        frameRate: 30
    )
)
```

## 架构设计

### 架构哲学

RealtimeKit 遵循以下核心设计原则：

- **协议导向编程**: 通过 RTCProvider 和 RTMProvider 等核心协议抽象不同服务商的实现差异
- **插件化架构**: 支持动态切换和扩展多个服务提供商，无需修改业务代码
- **提供者抽象**: 实现无缝切换不同的实时通信服务提供商，同时保持一致的 API 接口
- **模块化设计**: 清晰的关注点分离，支持按需导入和使用

### 1. 模块化设计

采用模块化架构，按需导入功能模块：

```swift
// ✅ 推荐：按需导入
import RealtimeCore      // 核心功能
import RealtimeSwiftUI   // SwiftUI 组件

// ❌ 避免：不必要的完整导入
import RealtimeKit       // 包含所有模块
```

### 2. 依赖注入

使用依赖注入模式提高代码可测试性：

```swift
// ✅ 推荐：依赖注入
protocol RealtimeManagerProtocol {
    func joinRoom(roomId: String) async throws
    func leaveRoom() async throws
}

class RoomViewController: UIViewController {
    private let realtimeManager: RealtimeManagerProtocol
    
    init(realtimeManager: RealtimeManagerProtocol = RealtimeManager.shared) {
        self.realtimeManager = realtimeManager
        super.init(nibName: nil, bundle: nil)
    }
}

// ❌ 避免：直接依赖具体实现
class RoomViewController: UIViewController {
    private let manager = RealtimeManager.shared  // 难以测试
}
```

### 3. 分层架构

采用清晰的分层架构：

```
┌─────────────────────────────────────┐
│           Presentation Layer        │  ← SwiftUI Views / UIKit Controllers
├─────────────────────────────────────┤
│            Business Layer           │  ← ViewModels / Use Cases
├─────────────────────────────────────┤
│            Service Layer            │  ← RealtimeManager / Managers
├─────────────────────────────────────┤
│             Data Layer              │  ← Storage / Network
└─────────────────────────────────────┘
```

**示例实现：**

```swift
// Business Layer - ViewModel
@MainActor
class RoomViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var volumeInfos: [UserVolumeInfo] = []
    
    private let realtimeService: RealtimeServiceProtocol
    private let storageService: StorageServiceProtocol
    
    init(
        realtimeService: RealtimeServiceProtocol,
        storageService: StorageServiceProtocol
    ) {
        self.realtimeService = realtimeService
        self.storageService = storageService
    }
    
    func joinRoom(roomId: String, userId: String) async throws {
        // 业务逻辑处理
        let userSettings = storageService.loadUserSettings()
        try await realtimeService.joinRoom(roomId: roomId, userId: userId)
        try await realtimeService.applySettings(userSettings)
    }
}

// Service Layer - 服务接口
protocol RealtimeServiceProtocol {
    func joinRoom(roomId: String, userId: String) async throws
    func applySettings(_ settings: UserSettings) async throws
}

// Service Layer - 具体实现
class RealtimeService: RealtimeServiceProtocol {
    private let manager = RealtimeManager.shared
    
    func joinRoom(roomId: String, userId: String) async throws {
        try await manager.loginUser(userId: userId, userName: userId, userRole: .broadcaster)
        try await manager.joinRoom(roomId: roomId)
    }
    
    func applySettings(_ settings: UserSettings) async throws {
        try await manager.setAudioMixingVolume(settings.volume)
        try await manager.muteMicrophone(settings.isMuted)
    }
}
```

## 性能优化

### 1. 音量检测优化

合理配置音量检测参数：

```swift
// ✅ 推荐：根据场景优化参数
func configureVolumeDetection(for scenario: RoomScenario) -> VolumeDetectionConfig {
    switch scenario {
    case .meeting:
        return VolumeDetectionConfig(
            detectionInterval: 500,      // 会议场景可以较慢
            speakingThreshold: 0.2,      // 较低阈值，检测轻声说话
            smoothFactor: 0.3            // 较强平滑，减少抖动
        )
    case .liveStreaming:
        return VolumeDetectionConfig(
            detectionInterval: 200,      // 直播需要更快响应
            speakingThreshold: 0.4,      // 较高阈值，避免背景噪音
            smoothFactor: 0.1            // 较弱平滑，保持响应性
        )
    case .karaoke:
        return VolumeDetectionConfig(
            detectionInterval: 100,      // K歌需要最快响应
            speakingThreshold: 0.3,
            smoothFactor: 0.2
        )
    }
}

// ❌ 避免：固定参数用于所有场景
let config = VolumeDetectionConfig(
    detectionInterval: 300,  // 可能不适合所有场景
    speakingThreshold: 0.3
)
```

### 2. 内存管理

正确管理内存，避免循环引用：

```swift
// ✅ 推荐：使用弱引用
class RoomViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        RealtimeManager.shared.$connectionState
            .receive(on: DispatchQueue.main)
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

// ❌ 避免：强引用导致循环引用
RealtimeManager.shared.$connectionState
    .sink { state in
        self.updateUI(for: state)  // 可能导致循环引用
    }
    .store(in: &cancellables)
```

### 3. 异步操作优化

合理使用 Swift Concurrency：

```swift
// ✅ 推荐：结构化并发
func setupRoom(roomId: String, userId: String) async throws {
    async let loginTask = RealtimeManager.shared.loginUser(
        userId: userId,
        userName: userId,
        userRole: .broadcaster
    )
    
    async let configTask = loadRoomConfiguration(roomId: roomId)
    
    // 并行执行，等待完成
    let (_, config) = try await (loginTask, configTask)
    
    // 串行执行依赖操作
    try await RealtimeManager.shared.joinRoom(roomId: roomId)
    try await applyRoomConfiguration(config)
}

// ❌ 避免：串行执行可并行的操作
func setupRoom(roomId: String, userId: String) async throws {
    try await RealtimeManager.shared.loginUser(
        userId: userId,
        userName: userId,
        userRole: .broadcaster
    )
    
    let config = try await loadRoomConfiguration(roomId: roomId)  // 可以并行
    
    try await RealtimeManager.shared.joinRoom(roomId: roomId)
    try await applyRoomConfiguration(config)
}
```

### 4. UI 更新优化

批量更新 UI，避免频繁刷新：

```swift
// ✅ 推荐：批量更新
class VolumeVisualizationView: UIView {
    private var updateTimer: Timer?
    private var pendingVolumeInfos: [UserVolumeInfo] = []
    
    func updateVolumeInfos(_ volumeInfos: [UserVolumeInfo]) {
        pendingVolumeInfos = volumeInfos
        
        // 批量更新，避免频繁刷新
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.performBatchUpdate()
                self?.updateTimer = nil
            }
        }
    }
    
    private func performBatchUpdate() {
        // 执行实际的 UI 更新
        updateDisplay(with: pendingVolumeInfos)
    }
}

// ❌ 避免：每次都立即更新 UI
func updateVolumeInfos(_ volumeInfos: [UserVolumeInfo]) {
    updateDisplay(with: volumeInfos)  // 可能导致频繁刷新
}
```

### 5. 转推流优化

正确管理转推流生命周期和资源：

```swift
// ✅ 推荐：完整的转推流管理
class StreamPushManager: ObservableObject {
    @Published private(set) var streamState: StreamPushState = .stopped
    @Published private(set) var streamQuality: StreamQualityMetrics?
    
    private var currentConfig: StreamPushConfig?
    private var qualityMonitor: Timer?
    
    func startStreamPush(config: StreamPushConfig) async throws {
        // 验证配置
        try config.validate()
        
        // 检查前置条件
        guard RealtimeManager.shared.connectionState == .connected else {
            throw StreamPushError.invalidState("Must be connected to room before starting stream push")
        }
        
        // 保存配置用于重试
        currentConfig = config
        
        do {
            try await RealtimeManager.shared.startStreamPush(config: config)
            streamState = .running
            startQualityMonitoring()
        } catch {
            streamState = .failed
            throw error
        }
    }
    
    func stopStreamPush() async throws {
        defer {
            streamState = .stopped
            currentConfig = nil
            stopQualityMonitoring()
        }
        
        guard streamState == .running else {
            return // 已经停止
        }
        
        try await RealtimeManager.shared.stopStreamPush()
    }
    
    private func startQualityMonitoring() {
        qualityMonitor = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateQualityMetrics()
            }
        }
    }
    
    private func stopQualityMonitoring() {
        qualityMonitor?.invalidate()
        qualityMonitor = nil
        streamQuality = nil
    }
    
    private func updateQualityMetrics() async {
        // 获取推流质量指标
        // 实际实现需要从底层 SDK 获取数据
        streamQuality = StreamQualityMetrics(
            bitrate: getCurrentBitrate(),
            frameRate: getCurrentFrameRate(),
            packetLoss: getCurrentPacketLoss()
        )
    }
}

// ❌ 避免：不完整的资源管理
func startStreamPush(config: StreamPushConfig) async throws {
    try await RealtimeManager.shared.startStreamPush(config: config)
    // 缺少错误处理和状态管理
}
```

## 错误处理

### 1. 分层错误处理

在不同层级处理不同类型的错误：

```swift
// Domain Layer - 业务错误
enum RoomError: LocalizedError {
    case roomNotFound
    case userAlreadyInRoom
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return LocalizationManager.shared.localizedString(for: "error.room_not_found")
        case .userAlreadyInRoom:
            return LocalizationManager.shared.localizedString(for: "error.user_already_in_room")
        case .insufficientPermissions:
            return LocalizationManager.shared.localizedString(for: "error.insufficient_permissions")
        }
    }
}

// Service Layer - 转换底层错误
class RoomService {
    func joinRoom(roomId: String, userId: String) async throws {
        do {
            try await RealtimeManager.shared.joinRoom(roomId: roomId)
        } catch RealtimeError.authenticationFailed {
            throw RoomError.insufficientPermissions
        } catch RealtimeError.connectionFailed {
            throw RoomError.roomNotFound
        } catch {
            throw error  // 传递未知错误
        }
    }
}

// Presentation Layer - 用户友好的错误显示
@MainActor
class RoomViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError = false
    
    func joinRoom(roomId: String, userId: String) async {
        do {
            try await roomService.joinRoom(roomId: roomId, userId: userId)
        } catch let error as RoomError {
            // 显示业务错误
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            // 显示通用错误
            errorMessage = LocalizationManager.shared.localizedString(for: "error.generic")
            showError = true
        }
    }
}
```

### 2. 错误恢复策略

实现智能的错误恢复机制：

```swift
class ConnectionManager: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    
    private var retryCount = 0
    private let maxRetries = 3
    private var retryTask: Task<Void, Never>?
    
    func handleConnectionError(_ error: RealtimeError) {
        switch error {
        case .networkUnavailable:
            // 网络错误 - 等待网络恢复后重试
            startNetworkMonitoring()
            
        case .tokenExpired:
            // Token 过期 - 立即刷新 Token
            Task {
                await refreshTokenAndReconnect()
            }
            
        case .connectionTimeout:
            // 连接超时 - 指数退避重试
            scheduleRetry()
            
        default:
            // 其他错误 - 显示给用户
            showErrorToUser(error)
        }
    }
    
    private func scheduleRetry() {
        guard retryCount < maxRetries else {
            showErrorToUser(RealtimeError.connectionFailed("Maximum retries exceeded"))
            return
        }
        
        let delay = pow(2.0, Double(retryCount))  // 指数退避
        retryCount += 1
        
        retryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await attemptReconnection()
        }
    }
    
    private func attemptReconnection() async {
        do {
            try await RealtimeManager.shared.reconnect()
            retryCount = 0  // 重置重试计数
        } catch {
            handleConnectionError(error as? RealtimeError ?? RealtimeError.connectionFailed("Unknown error"))
        }
    }
}
```

## 状态管理

### 1. 使用自动状态持久化

充分利用 `@RealtimeStorage` 进行状态管理：

```swift
// ✅ 推荐：使用自动持久化
class UserPreferencesManager: ObservableObject {
    @RealtimeStorage("audio_volume", defaultValue: 80)
    var audioVolume: Int {
        didSet {
            Task {
                try? await RealtimeManager.shared.setAudioMixingVolume(audioVolume)
            }
        }
    }
    
    @RealtimeStorage("auto_mute", defaultValue: false)
    var autoMuteOnJoin: Bool
    
    @RealtimeStorage("preferred_language", defaultValue: SupportedLanguage.english)
    var preferredLanguage: SupportedLanguage {
        didSet {
            LocalizationManager.shared.setLanguage(preferredLanguage)
        }
    }
    
    @SecureRealtimeStorage("user_credentials", defaultValue: UserCredentials())
    var userCredentials: UserCredentials
}

// ❌ 避免：手动管理持久化
class UserPreferencesManager: ObservableObject {
    @Published var audioVolume: Int = 80 {
        didSet {
            UserDefaults.standard.set(audioVolume, forKey: "audio_volume")  // 手动保存
        }
    }
    
    init() {
        audioVolume = UserDefaults.standard.integer(forKey: "audio_volume")  // 手动加载
    }
}
```

### 2. 状态同步策略

确保 UI 状态与业务状态同步：

```swift
// ✅ 推荐：单一数据源
@MainActor
class RoomStateManager: ObservableObject {
    // 单一数据源
    @Published private(set) var roomState: RoomState = .idle
    @Published private(set) var participants: [Participant] = []
    @Published private(set) var audioSettings: AudioSettings = .default
    
    private let realtimeManager = RealtimeManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 监听底层状态变化
        realtimeManager.$connectionState
            .map { connectionState in
                switch connectionState {
                case .connected: return .inRoom
                case .connecting: return .joining
                case .disconnected: return .idle
                default: return .error
                }
            }
            .assign(to: &$roomState)
        
        realtimeManager.$volumeInfos
            .map { volumeInfos in
                volumeInfos.map { Participant(from: $0) }
            }
            .assign(to: &$participants)
        
        realtimeManager.$audioSettings
            .assign(to: &$audioSettings)
    }
    
    // 提供业务操作接口
    func joinRoom(roomId: String, userId: String) async throws {
        try await realtimeManager.joinRoom(roomId: roomId)
    }
    
    func leaveRoom() async throws {
        try await realtimeManager.leaveRoom()
    }
}

enum RoomState {
    case idle
    case joining
    case inRoom
    case leaving
    case error
}
```

## UI/UX 设计

### 1. 响应式设计

提供良好的用户反馈：

```swift
// ✅ 推荐：丰富的状态反馈
struct ConnectionStatusView: View {
    let state: ConnectionState
    
    var body: some View {
        HStack {
            statusIcon
            statusText
            if state == .connecting || state == .reconnecting {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(16)
        .animation(.easeInOut(duration: 0.3), value: state)
    }
    
    private var statusIcon: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.system(size: 14, weight: .medium))
    }
    
    private var statusText: some View {
        Text(LocalizationManager.shared.localizedString(for: "connection.\(state.rawValue)"))
            .font(.caption)
            .foregroundColor(textColor)
    }
    
    private var iconName: String {
        switch state {
        case .connected: return "checkmark.circle.fill"
        case .connecting, .reconnecting: return "arrow.clockwise.circle"
        case .disconnected: return "xmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    private var backgroundColor: Color {
        switch state {
        case .connected: return .green.opacity(0.2)
        case .connecting, .reconnecting: return .orange.opacity(0.2)
        case .disconnected, .failed: return .red.opacity(0.2)
        }
    }
}
```

### 2. 无障碍支持

确保应用具有良好的无障碍性：

```swift
// ✅ 推荐：完整的无障碍支持
struct VolumeIndicatorView: View {
    let volumeInfos: [UserVolumeInfo]
    
    var body: some View {
        HStack {
            ForEach(volumeInfos, id: \.userId) { volumeInfo in
                VolumeBarView(volumeInfo: volumeInfo)
                    .accessibilityLabel(accessibilityLabel(for: volumeInfo))
                    .accessibilityValue(accessibilityValue(for: volumeInfo))
                    .accessibilityHint("用户音量指示器")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("音量指示器")
        .accessibilityHint("显示所有用户的音量级别")
    }
    
    private func accessibilityLabel(for volumeInfo: UserVolumeInfo) -> String {
        return "用户 \(volumeInfo.userId)"
    }
    
    private func accessibilityValue(for volumeInfo: UserVolumeInfo) -> String {
        let volumePercent = Int(volumeInfo.volume * 100)
        let speakingStatus = volumeInfo.isSpeaking ? "正在说话" : "未说话"
        return "音量 \(volumePercent)%，\(speakingStatus)"
    }
}
```

### 3. 性能友好的动画

使用高效的动画实现：

```swift
// ✅ 推荐：使用 SwiftUI 内置动画
struct VolumeWaveView: View {
    let volume: Float
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 3)
                    .scaleEffect(y: waveHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: volume
                    )
            }
        }
        .onAppear {
            animationPhase = volume > 0.1 ? 1.0 : 0.0
        }
        .onChange(of: volume) { newVolume in
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = newVolume > 0.1 ? 1.0 : 0.0
            }
        }
    }
    
    private func waveHeight(for index: Int) -> Double {
        let baseHeight = 0.3
        let volumeHeight = Double(volume) * 0.7
        let waveOffset = sin(animationPhase * .pi + Double(index) * 0.5) * 0.2
        return baseHeight + volumeHeight + waveOffset
    }
}
```

## 测试策略

### 1. 单元测试

为核心业务逻辑编写单元测试：

```swift
import Testing
@testable import RealtimeKit

@Suite("RoomService Tests")
struct RoomServiceTests {
    
    @Test("Should join room successfully")
    func testJoinRoomSuccess() async throws {
        // Given
        let mockManager = MockRealtimeManager()
        let roomService = RoomService(realtimeManager: mockManager)
        
        // When
        try await roomService.joinRoom(roomId: "test-room", userId: "test-user")
        
        // Then
        #expect(mockManager.joinRoomCalled)
        #expect(mockManager.lastRoomId == "test-room")
    }
    
    @Test("Should handle authentication failure")
    func testJoinRoomAuthFailure() async {
        // Given
        let mockManager = MockRealtimeManager()
        mockManager.shouldFailAuth = true
        let roomService = RoomService(realtimeManager: mockManager)
        
        // When & Then
        await #expect(throws: RoomError.insufficientPermissions) {
            try await roomService.joinRoom(roomId: "test-room", userId: "test-user")
        }
    }
}

// Mock 实现
class MockRealtimeManager: RealtimeManagerProtocol {
    var joinRoomCalled = false
    var lastRoomId: String?
    var shouldFailAuth = false
    
    func joinRoom(roomId: String) async throws {
        joinRoomCalled = true
        lastRoomId = roomId
        
        if shouldFailAuth {
            throw RealtimeError.authenticationFailed("Mock auth failure")
        }
    }
}
```

### 2. 集成测试

测试组件间的集成：

```swift
@Suite("RealtimeManager Integration Tests")
struct RealtimeManagerIntegrationTests {
    
    @Test("Should complete full room lifecycle")
    func testFullRoomLifecycle() async throws {
        // Given
        let manager = RealtimeManager.shared
        let config = RealtimeConfig(appId: "test-app-id", appCertificate: "test-cert")
        
        // When & Then
        try await manager.configure(provider: .mock, config: config)
        
        try await manager.loginUser(userId: "test-user", userName: "Test User", userRole: .broadcaster)
        #expect(manager.currentSession?.userId == "test-user")
        
        try await manager.joinRoom(roomId: "test-room")
        #expect(manager.connectionState == .connected)
        
        try await manager.leaveRoom()
        #expect(manager.connectionState == .disconnected)
        
        try await manager.logoutUser()
        #expect(manager.currentSession == nil)
    }
}
```

### 3. UI 测试

测试用户界面交互：

```swift
import XCTest
@testable import RealtimeKit

class RoomViewUITests: XCTestCase {
    
    func testJoinRoomFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 输入房间信息
        let roomIdField = app.textFields["roomIdTextField"]
        roomIdField.tap()
        roomIdField.typeText("test-room")
        
        let userIdField = app.textFields["userIdTextField"]
        userIdField.tap()
        userIdField.typeText("test-user")
        
        // 点击加入房间
        let joinButton = app.buttons["joinButton"]
        joinButton.tap()
        
        // 验证状态变化
        let connectionStatus = app.staticTexts["connectionStatusLabel"]
        let predicate = NSPredicate(format: "label CONTAINS '已连接'")
        expectation(for: predicate, evaluatedWith: connectionStatus, handler: nil)
        
        waitForExpectations(timeout: 5.0)
    }
}
```

## 安全考虑

### 1. Token 安全管理

安全地处理认证 Token：

```swift
// ✅ 推荐：使用安全存储
class TokenManager: ObservableObject {
    @SecureRealtimeStorage("rtc_token", defaultValue: "")
    private var rtcToken: String
    
    @SecureRealtimeStorage("rtm_token", defaultValue: "")
    private var rtmToken: String
    
    func updateTokens(rtc: String, rtm: String) async throws {
        // 验证 Token 格式
        guard isValidToken(rtc), isValidToken(rtm) else {
            throw TokenError.invalidFormat
        }
        
        // 安全存储
        rtcToken = rtc
        rtmToken = rtm
        
        // 更新到 RealtimeManager
        try await RealtimeManager.shared.renewRTCToken(rtc)
        try await RealtimeManager.shared.renewRTMToken(rtm)
    }
    
    private func isValidToken(_ token: String) -> Bool {
        // 实现 Token 格式验证
        return !token.isEmpty && token.count > 32
    }
}

// ❌ 避免：明文存储敏感信息
@RealtimeStorage("rtc_token", defaultValue: "")  // 不安全
var rtcToken: String
```

### 2. 输入验证

验证所有用户输入：

```swift
// ✅ 推荐：完整的输入验证
struct RoomInputValidator {
    static func validateRoomId(_ roomId: String) throws {
        guard !roomId.isEmpty else {
            throw ValidationError.emptyRoomId
        }
        
        guard roomId.count <= 64 else {
            throw ValidationError.roomIdTooLong
        }
        
        guard roomId.allSatisfy({ $0.isAlphanumeric || $0 == "-" || $0 == "_" }) else {
            throw ValidationError.invalidRoomIdCharacters
        }
    }
    
    static func validateUserId(_ userId: String) throws {
        guard !userId.isEmpty else {
            throw ValidationError.emptyUserId
        }
        
        guard userId.count <= 32 else {
            throw ValidationError.userIdTooLong
        }
        
        guard userId.allSatisfy({ $0.isAlphanumeric }) else {
            throw ValidationError.invalidUserIdCharacters
        }
    }
}

enum ValidationError: LocalizedError {
    case emptyRoomId
    case roomIdTooLong
    case invalidRoomIdCharacters
    case emptyUserId
    case userIdTooLong
    case invalidUserIdCharacters
    
    var errorDescription: String? {
        switch self {
        case .emptyRoomId:
            return "房间 ID 不能为空"
        case .roomIdTooLong:
            return "房间 ID 不能超过 64 个字符"
        case .invalidRoomIdCharacters:
            return "房间 ID 只能包含字母、数字、连字符和下划线"
        // ... 其他错误描述
        }
    }
}
```

## 部署和监控

### 1. 日志记录

实现结构化日志记录：

```swift
import os.log

class RealtimeLogger {
    private static let subsystem = "com.yourapp.realtimekit"
    
    static let connection = Logger(subsystem: subsystem, category: "connection")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let volume = Logger(subsystem: subsystem, category: "volume")
    static let error = Logger(subsystem: subsystem, category: "error")
    
    static func logConnectionEvent(_ event: String, roomId: String? = nil) {
        connection.info("Connection event: \(event, privacy: .public), roomId: \(roomId ?? "nil", privacy: .private)")
    }
    
    static func logAudioEvent(_ event: String, volume: Int? = nil) {
        audio.info("Audio event: \(event, privacy: .public), volume: \(volume ?? -1)")
    }
    
    static func logError(_ error: Error, context: String) {
        self.error.error("Error in \(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
}

// 使用示例
extension RealtimeManager {
    func joinRoom(roomId: String) async throws {
        RealtimeLogger.logConnectionEvent("Attempting to join room", roomId: roomId)
        
        do {
            try await rtcProvider.joinRoom(roomId: roomId, userId: currentSession?.userId ?? "", userRole: currentSession?.userRole ?? .audience)
            RealtimeLogger.logConnectionEvent("Successfully joined room", roomId: roomId)
        } catch {
            RealtimeLogger.logError(error, context: "joinRoom")
            throw error
        }
    }
}
```

### 2. 性能监控

监控关键性能指标：

```swift
class PerformanceMonitor: ObservableObject {
    @Published var connectionLatency: TimeInterval = 0
    @Published var audioQuality: AudioQualityMetrics = AudioQualityMetrics()
    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    
    private var startTime: Date?
    
    func startConnectionTimer() {
        startTime = Date()
    }
    
    func recordConnectionSuccess() {
        guard let startTime = startTime else { return }
        connectionLatency = Date().timeIntervalSince(startTime)
        self.startTime = nil
        
        // 记录到分析系统
        Analytics.record(event: "connection_success", parameters: [
            "latency": connectionLatency
        ])
    }
    
    func updateAudioQuality(_ metrics: AudioQualityMetrics) {
        audioQuality = metrics
        
        // 检查质量阈值
        if metrics.packetLossRate > 0.05 {
            RealtimeLogger.audio.warning("High packet loss rate: \(metrics.packetLossRate)")
        }
    }
    
    func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        memoryUsage = usage
        
        // 内存警告
        if usage.percentage > 0.8 {
            RealtimeLogger.error.warning("High memory usage: \(usage.percentage * 100)%")
        }
    }
}

struct AudioQualityMetrics {
    let packetLossRate: Double = 0
    let jitter: TimeInterval = 0
    let roundTripTime: TimeInterval = 0
}

struct MemoryUsage {
    let used: UInt64 = 0
    let total: UInt64 = 0
    var percentage: Double { Double(used) / Double(total) }
}
```

### 3. 崩溃报告

集成崩溃报告系统：

```swift
import CrashReporter  // 假设的崩溃报告库

class CrashReportingManager {
    static func configure() {
        CrashReporter.configure(apiKey: "your-api-key")
        
        // 设置用户信息
        CrashReporter.setUserIdentifier(getCurrentUserId())
        
        // 设置自定义属性
        CrashReporter.setCustomAttribute("realtimekit_version", value: RealtimeKit.version)
        CrashReporter.setCustomAttribute("provider_type", value: getCurrentProviderType())
    }
    
    static func recordBreadcrumb(_ message: String, category: String = "general") {
        CrashReporter.recordBreadcrumb(message: message, category: category)
    }
    
    static func recordError(_ error: Error, context: [String: Any] = [:]) {
        var contextWithDefaults = context
        contextWithDefaults["timestamp"] = Date().iso8601String
        contextWithDefaults["connection_state"] = RealtimeManager.shared.connectionState.rawValue
        
        CrashReporter.recordError(error, context: contextWithDefaults)
    }
}

// 在关键操作中记录面包屑
extension RealtimeManager {
    func joinRoom(roomId: String) async throws {
        CrashReportingManager.recordBreadcrumb("Starting to join room: \(roomId)", category: "connection")
        
        do {
            try await rtcProvider.joinRoom(roomId: roomId, userId: currentSession?.userId ?? "", userRole: currentSession?.userRole ?? .audience)
            CrashReportingManager.recordBreadcrumb("Successfully joined room", category: "connection")
        } catch {
            CrashReportingManager.recordError(error, context: ["room_id": roomId])
            throw error
        }
    }
}
```

通过遵循这些最佳实践，您可以构建出高质量、高性能、易维护的实时通信应用。记住，最佳实践是不断演进的，请根据您的具体需求和用户反馈持续优化您的实现。## 
平台特定开发指南

### iOS 开发最佳实践

#### 1. Agora SDK 优化

```swift
// iOS 特定的 Agora 配置优化
#if os(iOS)
let agoraConfig = AgoraProviderFactory.AgoraConfiguration(
    enableCloudProxy: true,          // 网络受限环境启用
    enableAudioVolumeIndication: true, // 启用音量检测
    enableLocalizedErrors: true,     // 启用本地化错误
    logLevel: .warn,                 // 生产环境使用 warn 级别
    region: .china                   // 根据用户地理位置选择
)

// 音频会话配置
func configureAudioSession() throws {
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth]
    )
    try audioSession.setActive(true)
}
#endif
```

#### 2. 后台处理

```swift
#if os(iOS)
class BackgroundTaskManager {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
#endif
```

### macOS 开发最佳实践

#### 1. Mock Provider 使用

```swift
#if os(macOS)
// macOS 上的 Mock Provider 配置
class macOSRealtimeManager {
    func setupMockProvider() async throws {
        let config = RealtimeConfig(
            appId: "mock-app-id",
            appCertificate: nil
        )
        
        try await RealtimeManager.shared.configure(
            provider: .mock,
            config: config
        )
        
        // 配置 Mock 行为
        if let mockProvider = RealtimeManager.shared.currentProvider as? MockProvider {
            mockProvider.simulateNetworkDelay = true
            mockProvider.simulateVolumeData = true
        }
    }
}
#endif
```

#### 2. 功能限制处理

```swift
#if os(macOS)
extension RealtimeManager {
    func attemptStreamPush(config: StreamPushConfig) async throws {
        throw RealtimeError.featureNotSupported(
            "推流功能在 macOS 平台不支持，请在 iOS 设备上使用"
        )
    }
    
    func showPlatformLimitationAlert() {
        let alert = NSAlert()
        alert.messageText = "功能限制"
        alert.informativeText = "此功能仅在 iOS 平台支持，当前为 macOS 开发环境"
        alert.alertStyle = .informational
        alert.runModal()
    }
}
#endif
```

### 跨平台 UI 设计

#### 1. SwiftUI 平台适配

```swift
struct PlatformAwareContentView: View {
    @StateObject private var manager = RealtimeManager.shared
    
    var body: some View {
        VStack {
            // 通用组件
            ConnectionStateIndicatorView(state: manager.connectionState)
            
            #if os(iOS)
            // iOS 特定功能
            Group {
                AudioControlPanelView()
                VolumeVisualizationView(volumeInfos: manager.volumeInfos)
                StreamPushControlView()
            }
            #elseif os(macOS)
            // macOS 简化界面
            Group {
                Text("开发模式 - Mock Provider")
                    .foregroundColor(.secondary)
                BasicControlPanelView()
            }
            #endif
        }
        .onAppear {
            Task {
                await configurePlatformProvider()
            }
        }
    }
    
    private func configurePlatformProvider() async {
        do {
            #if os(iOS)
            try await manager.configure(provider: .agora, config: agoraConfig)
            #else
            try await manager.configure(provider: .mock, config: mockConfig)
            #endif
        } catch {
            print("平台配置失败: \(error)")
        }
    }
}
```

#### 2. UIKit 平台适配

```swift
#if os(iOS)
class iOSRealtimeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupiOSSpecificUI()
    }
    
    private func setupiOSSpecificUI() {
        // iOS 特定的 UI 设置
        let audioControlView = AudioControlView()
        let volumeIndicatorView = VolumeIndicatorView()
        // 添加到视图层次结构
    }
}
#endif

#if os(macOS)
class macOSRealtimeViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupmacOSSpecificUI()
    }
    
    private func setupmacOSSpecificUI() {
        // macOS 特定的 UI 设置
        let statusLabel = NSTextField(labelWithString: "Mock Provider 模式")
        // 添加到视图层次结构
    }
}
#endif
```

### 测试策略

#### 1. 平台特定测试

```swift
#if os(iOS)
class iOSAgoraTests: XCTestCase {
    func testAgoraProviderInitialization() async throws {
        let provider = AgoraRTCProvider()
        let config = RTCConfig(appId: "test-app-id")
        try await provider.initialize(config: config)
        // iOS 特定的 Agora 测试
    }
}
#endif

#if os(macOS)
class macOSMockTests: XCTestCase {
    func testMockProviderBehavior() async throws {
        let provider = MockRTCProvider()
        let config = RTCConfig(appId: "mock-app-id")
        try await provider.initialize(config: config)
        // macOS 特定的 Mock 测试
    }
}
#endif
```

#### 2. 跨平台兼容性测试

```swift
class CrossPlatformCompatibilityTests: XCTestCase {
    func testPlatformFeatureMatrix() {
        let manager = RealtimeManager.shared
        
        #if os(iOS)
        XCTAssertTrue(manager.isFeatureSupported(.audioStreaming))
        XCTAssertTrue(manager.isFeatureSupported(.streamPush))
        #else
        XCTAssertFalse(manager.isFeatureSupported(.audioStreaming))
        XCTAssertFalse(manager.isFeatureSupported(.streamPush))
        #endif
        
        // 跨平台支持的功能
        XCTAssertTrue(manager.isFeatureSupported(.messageProcessing))
        XCTAssertTrue(manager.isFeatureSupported(.volumeIndicator))
    }
}
```

### 部署和发布

#### 1. 多平台构建配置

```swift
// Package.swift 中的平台特定配置
let package = Package(
    name: "RealtimeKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "RealtimeKit", targets: ["RealtimeKit"]),
        .library(name: "RealtimeCore", targets: ["RealtimeCore"]),
        .library(name: "RealtimeAgora", targets: ["RealtimeAgora"])
    ],
    targets: [
        .target(
            name: "RealtimeAgora",
            dependencies: [
                "RealtimeCore",
                .product(name: "AgoraRtcKit", package: "AgoraRtcEngine_iOS", condition: .when(platforms: [.iOS])),
                .product(name: "AgoraRtmKit", package: "AgoraRtm_Apple", condition: .when(platforms: [.iOS]))
            ]
        )
    ]
)
```

#### 2. CI/CD 配置

```yaml
# GitHub Actions 示例
name: Multi-Platform Build
on: [push, pull_request]

jobs:
  ios-build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build iOS
        run: |
          xcodebuild -scheme RealtimeKit-iOS -destination 'platform=iOS Simulator,name=iPhone 14' build
  
  macos-build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build macOS
        run: |
          xcodebuild -scheme RealtimeKit-macOS -destination 'platform=macOS' build
```

### 性能监控

#### 1. 平台特定性能指标

```swift
class PlatformPerformanceMonitor {
    func collectMetrics() -> [String: Any] {
        var metrics: [String: Any] = [:]
        
        #if os(iOS)
        metrics["platform"] = "iOS"
        metrics["agora_version"] = getAgoraSDKVersion()
        metrics["audio_session_active"] = AVAudioSession.sharedInstance().isOtherAudioPlaying
        #else
        metrics["platform"] = "macOS"
        metrics["mock_provider"] = true
        #endif
        
        return metrics
    }
}
```

这些平台特定的最佳实践将帮助您充分利用 RealtimeKit 在不同平台上的能力，同时正确处理平台限制和差异。