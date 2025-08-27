# RealtimeKit 故障排除指南

本指南帮助您诊断和解决使用 RealtimeKit 时可能遇到的常见问题。

## 目录

- [安装和配置问题](#安装和配置问题)
- [连接和网络问题](#连接和网络问题)
- [音频相关问题](#音频相关问题)
- [UI 和界面问题](#ui-和界面问题)
- [本地化问题](#本地化问题)
- [存储和持久化问题](#存储和持久化问题)
- [性能问题](#性能问题)
- [编译和构建问题](#编译和构建问题)
- [调试工具和技巧](#调试工具和技巧)

## 安装和配置问题

### Q: Swift Package Manager 无法解析依赖

**症状**: Xcode 显示 "Package Resolution Failed" 或类似错误

**解决方案**:

1. **检查网络连接**:
   ```bash
   # 测试网络连接
   ping github.com
   curl -I https://github.com/your-org/RealtimeKit
   ```

2. **清理 Package 缓存**:
   ```bash
   # 在 Xcode 中
   File → Packages → Reset Package Caches
   
   # 或使用命令行
   rm -rf ~/Library/Developer/Xcode/DerivedData
   rm -rf ~/Library/Caches/org.swift.swiftpm
   ```

3. **检查 Package.swift 配置**:
   ```swift
   // 确保版本号正确
   .package(url: "https://github.com/your-org/RealtimeKit", from: "1.0.0")
   
   // 或使用特定版本
   .package(url: "https://github.com/your-org/RealtimeKit", exact: "1.0.0")
   ```

4. **手动添加依赖**:
   ```swift
   dependencies: [
       .package(url: "https://github.com/your-org/RealtimeKit", from: "1.0.0")
   ],
   targets: [
       .target(
           name: "YourTarget",
           dependencies: [
               .product(name: "RealtimeKit", package: "RealtimeKit")
           ]
       )
   ]
   ```

### Q: 导入 RealtimeKit 时编译错误

**症状**: `No such module 'RealtimeKit'` 或类似错误

**解决方案**:

1. **检查目标配置**:
   - 确保在项目设置中正确添加了 RealtimeKit 依赖
   - 检查 Deployment Target 是否满足最低要求（iOS 13.0+, macOS 10.15+）

2. **清理并重新构建**:
   ```bash
   # 在 Xcode 中
   Product → Clean Build Folder (Cmd+Shift+K)
   Product → Build (Cmd+B)
   ```

3. **检查导入语句**:
   ```swift
   // ✅ 正确的导入
   import RealtimeKit
   
   // 或按需导入
   import RealtimeCore
   import RealtimeSwiftUI
   
   // ❌ 错误的导入
   import Realtime  // 模块名不正确
   ```

### Q: RealtimeManager 配置失败

**症状**: `configure` 方法抛出异常或配置不生效

**解决方案**:

1. **检查配置参数**:
   ```swift
   // ✅ 正确的配置
   let config = RealtimeConfig(
       appId: "your-valid-app-id",        // 确保 App ID 有效
       appCertificate: "your-valid-cert", // 确保证书有效
       logLevel: .info
   )
   
   try await RealtimeManager.shared.configure(
       provider: .agora,  // 确保服务商可用
       config: config
   )
   ```

2. **验证服务商配置**:
   ```swift
   // 检查 Agora 配置
   func validateAgoraConfig() -> Bool {
       guard !config.appId.isEmpty else {
           print("Agora App ID 不能为空")
           return false
       }
       
       guard config.appId.count >= 32 else {
           print("Agora App ID 格式不正确")
           return false
       }
       
       return true
   }
   ```

3. **添加错误处理**:
   ```swift
   do {
       try await RealtimeManager.shared.configure(provider: .agora, config: config)
       print("RealtimeKit 配置成功")
   } catch RealtimeError.invalidConfiguration(let reason) {
       print("配置错误: \(reason)")
   } catch RealtimeError.providerNotAvailable(let provider) {
       print("服务商不可用: \(provider)")
   } catch {
       print("未知错误: \(error)")
   }
   ```

## 连接和网络问题

### Q: 无法连接到房间

**症状**: `joinRoom` 方法超时或失败

**解决方案**:

1. **检查网络连接**:
   ```swift
   import Network
   
   class NetworkMonitor: ObservableObject {
       private let monitor = NWPathMonitor()
       @Published var isConnected = false
       
       init() {
           monitor.pathUpdateHandler = { [weak self] path in
               DispatchQueue.main.async {
                   self?.isConnected = path.status == .satisfied
               }
           }
           monitor.start(queue: DispatchQueue.global())
       }
       
       deinit {
           monitor.cancel()
       }
   }
   ```

2. **验证房间 ID 和用户 ID**:
   ```swift
   func validateRoomCredentials(roomId: String, userId: String) throws {
       // 房间 ID 验证
       guard !roomId.isEmpty else {
           throw ValidationError.emptyRoomId
       }
       
       guard roomId.count <= 64 else {
           throw ValidationError.roomIdTooLong
       }
       
       guard roomId.allSatisfy({ $0.isAlphanumeric || $0 == "-" || $0 == "_" }) else {
           throw ValidationError.invalidRoomIdCharacters
       }
       
       // 用户 ID 验证
       guard !userId.isEmpty else {
           throw ValidationError.emptyUserId
       }
       
       guard userId.count <= 32 else {
           throw ValidationError.userIdTooLong
       }
   }
   ```

3. **检查 Token 有效性**:
   ```swift
   func validateToken(_ token: String) -> Bool {
       // 基本格式检查
       guard !token.isEmpty else { return false }
       guard token.count > 32 else { return false }
       
       // 检查 Token 是否过期（如果可以解析）
       // 这里需要根据具体的 Token 格式实现
       
       return true
   }
   ```

4. **实现重连机制**:
   ```swift
   class ConnectionManager: ObservableObject {
       @Published var connectionState: ConnectionState = .disconnected
       private var retryCount = 0
       private let maxRetries = 3
       
       func connectWithRetry(roomId: String, userId: String) async {
           for attempt in 1...maxRetries {
               do {
                   try await RealtimeManager.shared.joinRoom(roomId: roomId)
                   connectionState = .connected
                   retryCount = 0
                   return
               } catch {
                   print("连接尝试 \(attempt) 失败: \(error)")
                   
                   if attempt < maxRetries {
                       let delay = pow(2.0, Double(attempt))  // 指数退避
                       try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                   }
               }
           }
           
           connectionState = .failed
       }
   }
   ```

### Q: 连接频繁断开

**症状**: 连接状态在 `connected` 和 `reconnecting` 之间频繁切换

**解决方案**:

1. **检查网络稳定性**:
   ```swift
   class NetworkQualityMonitor: ObservableObject {
       @Published var networkQuality: NetworkQuality = .unknown
       private var pingTimer: Timer?
       
       func startMonitoring() {
           pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
               Task {
                   await self.checkNetworkQuality()
               }
           }
       }
       
       private func checkNetworkQuality() async {
           let startTime = Date()
           
           do {
               let url = URL(string: "https://www.google.com")!
               let (_, response) = try await URLSession.shared.data(from: url)
               
               let latency = Date().timeIntervalSince(startTime)
               
               if let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 {
                   
                   await MainActor.run {
                       if latency < 0.1 {
                           networkQuality = .excellent
                       } else if latency < 0.3 {
                           networkQuality = .good
                       } else if latency < 0.6 {
                           networkQuality = .fair
                       } else {
                           networkQuality = .poor
                       }
                   }
               }
           } catch {
               await MainActor.run {
                   networkQuality = .poor
               }
           }
       }
   }
   
   enum NetworkQuality {
       case unknown, excellent, good, fair, poor
   }
   ```

2. **优化连接参数**:
   ```swift
   let config = RealtimeConfig(
       appId: "your-app-id",
       appCertificate: "your-app-certificate",
       connectionTimeout: 30,      // 增加连接超时时间
       keepAliveInterval: 10,      // 设置心跳间隔
       enableAutoReconnect: true   // 启用自动重连
   )
   ```

3. **处理后台/前台切换**:
   ```swift
   class AppStateManager: ObservableObject {
       init() {
           NotificationCenter.default.addObserver(
               self,
               selector: #selector(appDidEnterBackground),
               name: UIApplication.didEnterBackgroundNotification,
               object: nil
           )
           
           NotificationCenter.default.addObserver(
               self,
               selector: #selector(appWillEnterForeground),
               name: UIApplication.willEnterForegroundNotification,
               object: nil
           )
       }
       
       @objc private func appDidEnterBackground() {
           // 暂停非必要的网络活动
           Task {
               try? await RealtimeManager.shared.pauseConnection()
           }
       }
       
       @objc private func appWillEnterForeground() {
           // 恢复连接
           Task {
               try? await RealtimeManager.shared.resumeConnection()
           }
       }
   }
   ```

## 音频相关问题

### Q: 麦克风权限被拒绝

**症状**: 音频功能无法使用，控制台显示权限错误

**解决方案**:

1. **检查 Info.plist 配置**:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>此应用需要访问麦克风进行语音通话</string>
   ```

2. **请求和检查权限**:
   ```swift
   import AVFoundation
   
   class PermissionManager: ObservableObject {
       @Published var microphonePermission: AVAudioSession.RecordPermission = .undetermined
       
       func requestMicrophonePermission() async -> Bool {
           return await withCheckedContinuation { continuation in
               AVAudioSession.sharedInstance().requestRecordPermission { granted in
                   DispatchQueue.main.async {
                       self.microphonePermission = granted ? .granted : .denied
                       continuation.resume(returning: granted)
                   }
               }
           }
       }
       
       func checkMicrophonePermission() {
           microphonePermission = AVAudioSession.sharedInstance().recordPermission
       }
       
       func openSettings() {
           if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
               UIApplication.shared.open(settingsUrl)
           }
       }
   }
   ```

3. **处理权限状态**:
   ```swift
   struct PermissionView: View {
       @StateObject private var permissionManager = PermissionManager()
       
       var body: some View {
           VStack {
               switch permissionManager.microphonePermission {
               case .granted:
                   Text("麦克风权限已授予")
                       .foregroundColor(.green)
               
               case .denied:
                   VStack {
                       Text("麦克风权限被拒绝")
                           .foregroundColor(.red)
                       
                       Button("打开设置") {
                           permissionManager.openSettings()
                       }
                   }
               
               case .undetermined:
                   Button("请求麦克风权限") {
                       Task {
                           await permissionManager.requestMicrophonePermission()
                       }
                   }
               
               @unknown default:
                   Text("未知权限状态")
               }
           }
           .onAppear {
               permissionManager.checkMicrophonePermission()
           }
       }
   }
   ```

### Q: 音频设置不生效

**症状**: 调用音频控制方法后，实际音频状态没有改变

**解决方案**:

1. **检查音频会话配置**:
   ```swift
   func configureAudioSession() throws {
       let audioSession = AVAudioSession.sharedInstance()
       
       try audioSession.setCategory(
           .playAndRecord,
           mode: .voiceChat,
           options: [.defaultToSpeaker, .allowBluetooth]
       )
       
       try audioSession.setActive(true)
   }
   ```

2. **验证音频设置同步**:
   ```swift
   class AudioSettingsValidator {
       static func validateSettings(_ settings: AudioSettings) async throws {
           let manager = RealtimeManager.shared
           
           // 验证麦克风状态
           let actualMuteState = manager.isMicrophoneMuted()
           guard actualMuteState == settings.microphoneMuted else {
               throw AudioError.settingsMismatch("麦克风状态不匹配")
           }
           
           // 验证音量设置
           let actualVolume = manager.getAudioMixingVolume()
           guard actualVolume == settings.audioMixingVolume else {
               throw AudioError.settingsMismatch("音量设置不匹配")
           }
       }
   }
   
   enum AudioError: LocalizedError {
       case settingsMismatch(String)
       
       var errorDescription: String? {
           switch self {
           case .settingsMismatch(let reason):
               return "音频设置不匹配: \(reason)"
           }
       }
   }
   ```

3. **实现设置重试机制**:
   ```swift
   extension RealtimeManager {
       func setAudioMixingVolumeWithRetry(_ volume: Int, maxRetries: Int = 3) async throws {
           for attempt in 1...maxRetries {
               do {
                   try await setAudioMixingVolume(volume)
                   
                   // 验证设置是否生效
                   let actualVolume = getAudioMixingVolume()
                   if actualVolume == volume {
                       return  // 设置成功
                   }
                   
                   if attempt < maxRetries {
                       try await Task.sleep(nanoseconds: 500_000_000)  // 等待 0.5 秒
                   }
               } catch {
                   if attempt == maxRetries {
                       throw error
                   }
               }
           }
           
           throw AudioError.settingsMismatch("音量设置失败，重试 \(maxRetries) 次后仍然失败")
       }
   }
   ```

### Q: 音量检测不准确

**症状**: 音量指示器显示的音量与实际说话音量不符

**解决方案**:

1. **调整检测参数**:
   ```swift
   // 根据环境调整参数
   func createVolumeConfig(for environment: AudioEnvironment) -> VolumeDetectionConfig {
       switch environment {
       case .quiet:  // 安静环境
           return VolumeDetectionConfig(
               detectionInterval: 200,
               speakingThreshold: 0.1,    // 降低阈值
               silenceThreshold: 0.02,
               smoothFactor: 0.2
           )
           
       case .noisy:  // 嘈杂环境
           return VolumeDetectionConfig(
               detectionInterval: 300,
               speakingThreshold: 0.5,    // 提高阈值
               silenceThreshold: 0.1,
               smoothFactor: 0.4
           )
           
       case .normal:  // 正常环境
           return VolumeDetectionConfig(
               detectionInterval: 300,
               speakingThreshold: 0.3,
               silenceThreshold: 0.05,
               smoothFactor: 0.3
           )
       }
   }
   
   enum AudioEnvironment {
       case quiet, normal, noisy
   }
   ```

2. **实现自适应阈值**:
   ```swift
   class AdaptiveVolumeDetector: ObservableObject {
       @Published var currentThreshold: Float = 0.3
       private var volumeHistory: [Float] = []
       private let historySize = 100
       
       func updateThreshold(with volumeInfos: [UserVolumeInfo]) {
           // 收集音量历史
           let volumes = volumeInfos.map { $0.volume }
           volumeHistory.append(contentsOf: volumes)
           
           if volumeHistory.count > historySize {
               volumeHistory = Array(volumeHistory.suffix(historySize))
           }
           
           // 计算自适应阈值
           if volumeHistory.count >= 20 {
               let averageVolume = volumeHistory.reduce(0, +) / Float(volumeHistory.count)
               let standardDeviation = calculateStandardDeviation(volumeHistory)
               
               // 设置阈值为平均值 + 1 个标准差
               currentThreshold = averageVolume + standardDeviation
               currentThreshold = max(0.1, min(0.8, currentThreshold))  // 限制范围
           }
       }
       
       private func calculateStandardDeviation(_ values: [Float]) -> Float {
           let mean = values.reduce(0, +) / Float(values.count)
           let squaredDifferences = values.map { pow($0 - mean, 2) }
           let variance = squaredDifferences.reduce(0, +) / Float(values.count)
           return sqrt(variance)
       }
   }
   ```

## UI 和界面问题

### Q: SwiftUI 界面不更新

**症状**: 数据变化后 SwiftUI 界面没有自动刷新

**解决方案**:

1. **检查 @StateObject 和 @ObservedObject 使用**:
   ```swift
   // ✅ 正确使用
   struct ContentView: View {
       @StateObject private var manager = RealtimeManager.shared  // 使用 @StateObject
       
       var body: some View {
           Text("连接状态: \(manager.connectionState.rawValue)")
       }
   }
   
   // ❌ 错误使用
   struct ContentView: View {
       @ObservedObject private var manager = RealtimeManager.shared  // 可能导致重复创建
   }
   ```

2. **确保在主线程更新 UI**:
   ```swift
   class RealtimeManager: ObservableObject {
       @Published var connectionState: ConnectionState = .disconnected
       
       private func updateConnectionState(_ newState: ConnectionState) {
           // 确保在主线程更新
           DispatchQueue.main.async {
               self.connectionState = newState
           }
           
           // 或使用 MainActor
           Task { @MainActor in
               self.connectionState = newState
           }
       }
   }
   ```

3. **检查 Combine 订阅**:
   ```swift
   class ViewModel: ObservableObject {
       @Published var volumeInfos: [UserVolumeInfo] = []
       private var cancellables = Set<AnyCancellable>()
       
       init() {
           RealtimeManager.shared.$volumeInfos
               .receive(on: DispatchQueue.main)  // 确保在主线程接收
               .assign(to: &$volumeInfos)
       }
   }
   ```

### Q: UIKit 界面更新延迟

**症状**: UIKit 界面更新比 SwiftUI 慢或不及时

**解决方案**:

1. **使用 Combine 进行数据绑定**:
   ```swift
   class RealtimeViewController: UIViewController {
       @IBOutlet weak var connectionStatusLabel: UILabel!
       @IBOutlet weak var volumeProgressView: UIProgressView!
       
       private var cancellables = Set<AnyCancellable>()
       private let manager = RealtimeManager.shared
       
       override func viewDidLoad() {
           super.viewDidLoad()
           setupBindings()
       }
       
       private func setupBindings() {
           // 连接状态绑定
           manager.$connectionState
               .receive(on: DispatchQueue.main)
               .sink { [weak self] state in
                   self?.updateConnectionStatus(state)
               }
               .store(in: &cancellables)
           
           // 音量信息绑定
           manager.$volumeInfos
               .receive(on: DispatchQueue.main)
               .sink { [weak self] volumeInfos in
                   self?.updateVolumeDisplay(volumeInfos)
               }
               .store(in: &cancellables)
       }
       
       private func updateConnectionStatus(_ state: ConnectionState) {
           connectionStatusLabel.text = state.localizedDescription
           connectionStatusLabel.textColor = state.displayColor
       }
       
       private func updateVolumeDisplay(_ volumeInfos: [UserVolumeInfo]) {
           let averageVolume = volumeInfos.isEmpty ? 0 : 
               volumeInfos.map { $0.volume }.reduce(0, +) / Float(volumeInfos.count)
           volumeProgressView.progress = averageVolume
       }
   }
   
   extension ConnectionState {
       var displayColor: UIColor {
           switch self {
           case .connected: return .systemGreen
           case .connecting, .reconnecting: return .systemOrange
           case .disconnected, .failed: return .systemRed
           }
       }
   }
   ```

2. **优化 UI 更新频率**:
   ```swift
   class ThrottledUIUpdater {
       private var updateTimer: Timer?
       private var pendingUpdate: (() -> Void)?
       
       func scheduleUpdate(_ update: @escaping () -> Void, interval: TimeInterval = 0.1) {
           pendingUpdate = update
           
           updateTimer?.invalidate()
           updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
               DispatchQueue.main.async {
                   self.pendingUpdate?()
                   self.pendingUpdate = nil
               }
           }
       }
   }
   
   // 使用示例
   class VolumeViewController: UIViewController {
       private let uiUpdater = ThrottledUIUpdater()
       
       func handleVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
           uiUpdater.scheduleUpdate {
               self.updateVolumeViews(volumeInfos)
           }
       }
   }
   ```

## 本地化问题

### Q: 语言切换后界面没有更新

**症状**: 调用 `setLanguage` 后，部分或全部界面文本没有更新

**解决方案**:

1. **确保监听语言变化通知**:
   ```swift
   // SwiftUI
   struct LocalizedView: View {
       @StateObject private var localizationManager = LocalizationManager.shared
       
       var body: some View {
           Text(localizationManager.localizedString(for: "welcome_message"))
               .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                   // SwiftUI 会自动重新渲染
               }
       }
   }
   
   // UIKit
   class LocalizedViewController: UIViewController {
       override func viewDidLoad() {
           super.viewDidLoad()
           
           NotificationCenter.default.addObserver(
               self,
               selector: #selector(languageDidChange),
               name: .languageDidChange,
               object: nil
           )
       }
       
       @objc private func languageDidChange() {
           updateLocalizedContent()
       }
       
       private func updateLocalizedContent() {
           title = "main_title".localized
           // 更新其他本地化内容...
       }
   }
   ```

2. **检查本地化字符串是否存在**:
   ```swift
   extension LocalizationManager {
       func debugLocalizedString(for key: String) -> String {
           let result = localizedString(for: key)
           
           if result == key {
               print("⚠️ 本地化字符串缺失: \(key)")
               
               // 检查所有语言中是否存在该键
               for language in SupportedLanguage.allCases {
                   if let strings = builtinStrings[language],
                      strings[key] != nil {
                       print("  ✅ 在 \(language.displayName) 中找到")
                   } else {
                       print("  ❌ 在 \(language.displayName) 中缺失")
                   }
               }
           }
           
           return result
       }
   }
   ```

### Q: 自定义语言包不生效

**症状**: 注册的自定义语言包没有被使用

**解决方案**:

1. **检查注册时机**:
   ```swift
   // ✅ 在应用启动时注册
   class AppDelegate: UIResponder, UIApplicationDelegate {
       func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
           
           // 先注册自定义语言包
           registerCustomLanguagePacks()
           
           // 再初始化其他组件
           initializeRealtimeKit()
           
           return true
       }
       
       private func registerCustomLanguagePacks() {
           let customStrings = [
               "welcome_message": "欢迎使用我的应用！",
               "connection_status": "连接状态"
           ]
           
           LocalizationManager.shared.registerCustomStrings(
               customStrings,
               for: .simplifiedChinese
           )
       }
   }
   ```

2. **验证字符串格式**:
   ```swift
   func validateLanguagePack(_ strings: [String: String]) -> [String] {
       var issues: [String] = []
       
       for (key, value) in strings {
           // 检查键名格式
           if key.isEmpty {
               issues.append("空键名")
           }
           
           if key.contains(" ") {
               issues.append("键名包含空格: \(key)")
           }
           
           // 检查参数格式
           let parameterPattern = #"\{\d+\}"#
           let regex = try? NSRegularExpression(pattern: parameterPattern)
           let matches = regex?.matches(in: value, range: NSRange(value.startIndex..., in: value))
           
           if let matches = matches, !matches.isEmpty {
               let parameterIndices = matches.compactMap { match in
                   Int(String(value[Range(match.range, in: value)!]).dropFirst().dropLast())
               }
               
               // 检查参数索引是否连续
               let sortedIndices = parameterIndices.sorted()
               for (index, paramIndex) in sortedIndices.enumerated() {
                   if paramIndex != index {
                       issues.append("参数索引不连续: \(key) - \(value)")
                       break
                   }
               }
           }
       }
       
       return issues
   }
   ```

## 存储和持久化问题

### Q: @RealtimeStorage 数据没有保存

**症状**: 应用重启后 @RealtimeStorage 标记的属性恢复为默认值

**解决方案**:

1. **检查数据类型是否符合 Codable**:
   ```swift
   // ✅ 正确的 Codable 实现
   struct UserSettings: Codable, Equatable {
       let volume: Int
       let theme: Theme
       let notifications: NotificationSettings
   }
   
   enum Theme: String, Codable {
       case light = "light"
       case dark = "dark"
   }
   
   struct NotificationSettings: Codable, Equatable {
       let enabled: Bool
       let sound: Bool
   }
   
   // ❌ 不符合 Codable 的类型
   class UserSettings {  // class 需要手动实现 Codable
       let volume: Int
       let callback: () -> Void  // 闭包不能序列化
   }
   ```

2. **检查存储后端可用性**:
   ```swift
   func testStorageBackend() async {
       let backend = UserDefaultsBackend.shared
       let testKey = "test_key"
       let testValue = "test_value"
       
       do {
           // 测试写入
           try await backend.setValue(testValue, for: testKey)
           print("✅ 写入测试成功")
           
           // 测试读取
           let retrievedValue: String? = try await backend.getValue(for: testKey, type: String.self)
           if retrievedValue == testValue {
               print("✅ 读取测试成功")
           } else {
               print("❌ 读取测试失败: 期望 \(testValue), 实际 \(retrievedValue ?? "nil")")
           }
           
           // 清理测试数据
           try await backend.removeValue(for: testKey)
           
       } catch {
           print("❌ 存储后端测试失败: \(error)")
       }
   }
   ```

3. **添加存储错误处理**:
   ```swift
   @propertyWrapper
   struct SafeRealtimeStorage<Value: Codable>: DynamicProperty {
       private let storage: RealtimeStorage<Value>
       @State private var lastError: Error?
       
       init(_ key: String, defaultValue: Value, backend: StorageBackend = UserDefaultsBackend.shared) {
           self.storage = RealtimeStorage(key, defaultValue: defaultValue, backend: backend)
       }
       
       var wrappedValue: Value {
           get { storage.wrappedValue }
           nonmutating set {
               do {
                   storage.wrappedValue = newValue
                   lastError = nil
               } catch {
                   lastError = error
                   print("存储失败: \(error)")
                   
                   // 可选：通知用户
                   NotificationCenter.default.post(
                       name: .storageError,
                       object: error
                   )
               }
           }
       }
       
       var projectedValue: Binding<Value> {
           storage.projectedValue
       }
   }
   ```

### Q: Keychain 存储失败

**症状**: 使用 @SecureRealtimeStorage 时出现存储错误

**解决方案**:

1. **检查 Keychain 权限**:
   ```swift
   func checkKeychainAccess() -> Bool {
       let query: [String: Any] = [
           kSecClass as String: kSecClassGenericPassword,
           kSecAttrAccount as String: "test-account",
           kSecValueData as String: "test-data".data(using: .utf8)!,
           kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
       ]
       
       // 尝试添加测试项
       let addStatus = SecItemAdd(query as CFDictionary, nil)
       
       if addStatus == errSecSuccess {
           // 清理测试项
           SecItemDelete(query as CFDictionary)
           return true
       } else {
           print("Keychain 访问失败: \(addStatus)")
           return false
       }
   }
   ```

2. **实现 Keychain 错误处理**:
   ```swift
   extension KeychainBackend {
       func handleKeychainError(_ status: OSStatus, operation: String) -> Error {
           switch status {
           case errSecItemNotFound:
               return KeychainError.itemNotFound
           case errSecDuplicateItem:
               return KeychainError.duplicateItem
           case errSecAuthFailed:
               return KeychainError.authenticationFailed
           case errSecUserCancel:
               return KeychainError.userCancelled
           case errSecNotAvailable:
               return KeychainError.keychainNotAvailable
           default:
               return KeychainError.unknown(status)
           }
       }
   }
   
   enum KeychainError: LocalizedError {
       case itemNotFound
       case duplicateItem
       case authenticationFailed
       case userCancelled
       case keychainNotAvailable
       case unknown(OSStatus)
       
       var errorDescription: String? {
           switch self {
           case .itemNotFound:
               return "Keychain 项目未找到"
           case .duplicateItem:
               return "Keychain 项目已存在"
           case .authenticationFailed:
               return "Keychain 认证失败"
           case .userCancelled:
               return "用户取消了 Keychain 操作"
           case .keychainNotAvailable:
               return "Keychain 不可用"
           case .unknown(let status):
               return "未知 Keychain 错误: \(status)"
           }
       }
   }
   ```

## 性能问题

### Q: 音量检测导致性能问题

**症状**: 启用音量检测后应用卡顿或 CPU 使用率过高

**解决方案**:

1. **优化检测间隔**:
   ```swift
   // 根据使用场景调整间隔
   func optimizeVolumeDetection(for useCase: VolumeUseCase) -> VolumeDetectionConfig {
       switch useCase {
       case .backgroundMonitoring:
           return VolumeDetectionConfig(
               detectionInterval: 1000,  // 1 秒间隔，减少 CPU 使用
               speakingThreshold: 0.4,
               smoothFactor: 0.5
           )
           
       case .activeConversation:
           return VolumeDetectionConfig(
               detectionInterval: 300,   // 300ms 间隔，平衡性能和响应性
               speakingThreshold: 0.3,
               smoothFactor: 0.3
           )
           
       case .musicVisualization:
           return VolumeDetectionConfig(
               detectionInterval: 100,   // 100ms 间隔，高响应性
               speakingThreshold: 0.2,
               smoothFactor: 0.1
           )
       }
   }
   
   enum VolumeUseCase {
       case backgroundMonitoring
       case activeConversation
       case musicVisualization
   }
   ```

2. **实现自适应性能调整**:
   ```swift
   class AdaptiveVolumeDetector: ObservableObject {
       private var performanceMonitor = PerformanceMonitor()
       private var currentConfig = VolumeDetectionConfig.default
       
       func adjustPerformance() {
           let cpuUsage = performanceMonitor.getCurrentCPUUsage()
           let memoryUsage = performanceMonitor.getCurrentMemoryUsage()
           
           if cpuUsage > 0.8 || memoryUsage > 0.9 {
               // 降低性能要求
               currentConfig = VolumeDetectionConfig(
                   detectionInterval: currentConfig.detectionInterval * 2,  // 加倍间隔
                   speakingThreshold: currentConfig.speakingThreshold,
                   smoothFactor: min(0.8, currentConfig.smoothFactor * 1.5)  // 增加平滑
               )
               
               print("性能优化：降低音量检测频率")
               
           } else if cpuUsage < 0.3 && memoryUsage < 0.5 {
               // 可以提高性能
               currentConfig = VolumeDetectionConfig(
                   detectionInterval: max(100, currentConfig.detectionInterval / 2),
                   speakingThreshold: currentConfig.speakingThreshold,
                   smoothFactor: max(0.1, currentConfig.smoothFactor / 1.5)
               )
               
               print("性能优化：提高音量检测频率")
           }
           
           // 应用新配置
           Task {
               try? await RealtimeManager.shared.updateVolumeDetectionConfig(currentConfig)
           }
       }
   }
   ```

### Q: UI 更新导致卡顿

**症状**: 频繁的 UI 更新导致界面卡顿

**解决方案**:

1. **实现 UI 更新节流**:
   ```swift
   class UIUpdateThrottler {
       private var lastUpdateTime: Date = Date()
       private let minimumInterval: TimeInterval
       private var pendingUpdate: (() -> Void)?
       private var updateTimer: Timer?
       
       init(minimumInterval: TimeInterval = 0.1) {
           self.minimumInterval = minimumInterval
       }
       
       func throttleUpdate(_ update: @escaping () -> Void) {
           let now = Date()
           let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
           
           if timeSinceLastUpdate >= minimumInterval {
               // 立即执行更新
               update()
               lastUpdateTime = now
               pendingUpdate = nil
               updateTimer?.invalidate()
           } else {
               // 延迟执行更新
               pendingUpdate = update
               updateTimer?.invalidate()
               
               let delay = minimumInterval - timeSinceLastUpdate
               updateTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                   self.pendingUpdate?()
                   self.lastUpdateTime = Date()
                   self.pendingUpdate = nil
               }
           }
       }
   }
   ```

2. **优化 SwiftUI 性能**:
   ```swift
   struct OptimizedVolumeView: View {
       let volumeInfos: [UserVolumeInfo]
       
       var body: some View {
           LazyVStack {  // 使用 LazyVStack 而不是 VStack
               ForEach(volumeInfos, id: \.userId) { volumeInfo in
                   VolumeRowView(volumeInfo: volumeInfo)
                       .equatable()  // 添加 Equatable 优化
               }
           }
           .drawingGroup()  // 将视图渲染为单个图层
       }
   }
   
   struct VolumeRowView: View, Equatable {
       let volumeInfo: UserVolumeInfo
       
       var body: some View {
           HStack {
               Text(volumeInfo.userId)
               Spacer()
               VolumeBarView(volume: volumeInfo.volume)
           }
       }
       
       static func == (lhs: VolumeRowView, rhs: VolumeRowView) -> Bool {
           return lhs.volumeInfo == rhs.volumeInfo
       }
   }
   ```

## 编译和构建问题

### Q: Swift 6.0 并发警告

**症状**: 编译时出现大量并发相关警告

**解决方案**:

1. **修复 Sendable 警告**:
   ```swift
   // ✅ 正确的 Sendable 实现
   struct UserVolumeInfo: Codable, Equatable, Sendable {
       let userId: String
       let volume: Float
       let isSpeaking: Bool
       let timestamp: Date
   }
   
   // ✅ 正确的回调类型
   func setVolumeHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void) {
       // ...
   }
   
   // ❌ 错误：缺少 Sendable
   func setVolumeHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void) {
       // 会产生并发警告
   }
   ```

2. **修复 MainActor 隔离问题**:
   ```swift
   @MainActor
   class RealtimeManager: ObservableObject {
       @Published var connectionState: ConnectionState = .disconnected
       
       // ✅ 正确：MainActor 隔离的方法
       func updateConnectionState(_ state: ConnectionState) {
           connectionState = state
       }
       
       // ✅ 正确：非隔离方法调用隔离方法
       nonisolated func handleConnectionChange(_ state: ConnectionState) {
           Task { @MainActor in
               updateConnectionState(state)
           }
       }
   }
   ```

### Q: 模块导入错误

**症状**: 编译时提示找不到模块或符号

**解决方案**:

1. **检查模块依赖**:
   ```swift
   // Package.swift
   let package = Package(
       name: "YourApp",
       platforms: [
           .iOS(.v13),
           .macOS(.v10_15)
       ],
       products: [
           .library(name: "YourApp", targets: ["YourApp"])
       ],
       dependencies: [
           .package(url: "https://github.com/your-org/RealtimeKit", from: "1.0.0")
       ],
       targets: [
           .target(
               name: "YourApp",
               dependencies: [
                   .product(name: "RealtimeKit", package: "RealtimeKit")
               ]
           )
       ]
   )
   ```

2. **检查平台兼容性**:
   ```swift
   #if canImport(UIKit)
   import UIKit
   
   // UIKit 特定代码
   extension UIViewController {
       // ...
   }
   #endif
   
   #if canImport(AppKit)
   import AppKit
   
   // macOS 特定代码
   extension NSViewController {
       // ...
   }
   #endif
   ```

## 调试工具和技巧

### 启用详细日志

```swift
// 在应用启动时启用调试日志
RealtimeManager.shared.setLogLevel(.debug)

// 或在配置时设置
let config = RealtimeConfig(
    appId: "your-app-id",
    appCertificate: "your-app-certificate",
    logLevel: .debug  // 启用详细日志
)
```

### 使用调试面板

```swift
struct DebugPanel: View {
    @StateObject private var manager = RealtimeManager.shared
    @State private var showingDebugInfo = false
    
    var body: some View {
        VStack {
            Button("显示调试信息") {
                showingDebugInfo.toggle()
            }
            
            if showingDebugInfo {
                debugInfoView
            }
        }
    }
    
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("连接状态: \(manager.connectionState.rawValue)")
            Text("音频设置: \(manager.audioSettings)")
            Text("音量信息数量: \(manager.volumeInfos.count)")
            Text("当前会话: \(manager.currentSession?.userId ?? "无")")
            
            Button("导出日志") {
                exportDebugLogs()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func exportDebugLogs() {
        // 导出调试日志的实现
        let logs = RealtimeLogger.exportLogs()
        // 保存或分享日志...
    }
}
```

### 网络诊断工具

```swift
class NetworkDiagnostics {
    static func runDiagnostics() async -> DiagnosticResult {
        var result = DiagnosticResult()
        
        // 检查网络连接
        result.networkConnectivity = await checkNetworkConnectivity()
        
        // 检查 DNS 解析
        result.dnsResolution = await checkDNSResolution()
        
        // 检查服务器可达性
        result.serverReachability = await checkServerReachability()
        
        // 测试延迟
        result.latency = await measureLatency()
        
        return result
    }
    
    private static func checkNetworkConnectivity() async -> Bool {
        // 实现网络连接检查
        return true
    }
    
    private static func checkDNSResolution() async -> Bool {
        // 实现 DNS 解析检查
        return true
    }
    
    private static func checkServerReachability() async -> Bool {
        // 实现服务器可达性检查
        return true
    }
    
    private static func measureLatency() async -> TimeInterval {
        // 实现延迟测量
        return 0.1
    }
}

struct DiagnosticResult {
    var networkConnectivity: Bool = false
    var dnsResolution: Bool = false
    var serverReachability: Bool = false
    var latency: TimeInterval = 0
}
```

通过使用这些故障排除方法和调试工具，您应该能够快速定位和解决 RealtimeKit 使用过程中遇到的大部分问题。如果问题仍然存在，请查看 [FAQ](FAQ.md) 或联系技术支持。