# RealtimeKit 本地化指南

本指南详细介绍如何在 RealtimeKit 中使用多语言支持功能，包括内置本地化、自定义语言包和最佳实践。

## 目录

- [概述](#概述)
- [支持的语言](#支持的语言)
- [基础使用](#基础使用)
- [自定义语言包](#自定义语言包)
- [UI 组件本地化](#ui-组件本地化)
- [错误消息本地化](#错误消息本地化)
- [动态语言切换](#动态语言切换)
- [最佳实践](#最佳实践)
- [故障排除](#故障排除)

## 概述

RealtimeKit 提供完整的多语言支持，包括：

- **自动语言检测**: 根据系统设置自动选择合适的语言
- **动态语言切换**: 运行时切换语言，UI 实时更新
- **内置语言包**: 支持 5 种主要语言
- **自定义语言包**: 支持开发者添加自定义语言
- **参数化消息**: 支持带参数的本地化字符串
- **回退机制**: 缺少特定语言时自动回退到英文

## 支持的语言

RealtimeKit 内置支持以下语言：

| 语言 | 代码 | 显示名称 | 本地名称 |
|------|------|----------|----------|
| 英文 | `en` | English | English |
| 中文（简体） | `zh-Hans` | Simplified Chinese | 简体中文 |
| 中文（繁体） | `zh-Hant` | Traditional Chinese | 繁體中文 |
| 日文 | `ja` | Japanese | 日本語 |
| 韩文 | `ko` | Korean | 한국어 |

## 基础使用

### 1. 自动语言检测

RealtimeKit 会在初始化时自动检测系统语言：

```swift
import RealtimeKit

// 系统会自动检测并设置语言
let currentLanguage = LocalizationManager.shared.currentLanguage
print("当前语言: \(currentLanguage.displayName)")

// 手动检测系统语言
let systemLanguage = LocalizationManager.shared.detectSystemLanguage()
print("系统语言: \(systemLanguage.nativeName)")
```

### 2. 获取本地化字符串

使用 `LocalizationManager` 获取本地化字符串：

```swift
// 基础用法
let welcomeMessage = LocalizationManager.shared.localizedString(for: "welcome_message")

// 带参数的本地化字符串
let userGreeting = LocalizationManager.shared.localizedString(
    for: "user_greeting",
    arguments: ["张三", "直播间001"]
)

// 使用便捷方法
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    func localized(with arguments: [String]) -> String {
        return LocalizationManager.shared.localizedString(for: self, arguments: arguments)
    }
}

// 使用扩展
let message = "connection_status".localized
let greeting = "user_joined".localized(with: ["Alice"])
```

### 3. 手动切换语言

```swift
// 切换到简体中文
LocalizationManager.shared.setLanguage(.simplifiedChinese)

// 切换到英文
LocalizationManager.shared.setLanguage(.english)

// 切换到日文
LocalizationManager.shared.setLanguage(.japanese)
```

## 自定义语言包

### 1. 创建自定义语言包

您可以添加自定义语言或覆盖内置字符串：

```swift
// 创建自定义语言包
let customStrings: [String: String] = [
    "welcome_message": "欢迎使用我的应用！",
    "connection_status": "连接状态",
    "user_joined": "{0} 加入了房间",
    "audio_volume": "音量: {0}%",
    "error_network": "网络连接失败，请检查网络设置"
]

// 注册自定义语言包
LocalizationManager.shared.registerCustomStrings(
    customStrings,
    for: .simplifiedChinese
)

// 添加新语言
enum CustomLanguage: String, CaseIterable {
    case vietnamese = "vi"
    case thai = "th"
}

extension SupportedLanguage {
    static let vietnamese = SupportedLanguage(rawValue: "vi")!
    static let thai = SupportedLanguage(rawValue: "th")!
}

let vietnameseStrings: [String: String] = [
    "welcome_message": "Chào mừng bạn!",
    "connection_status": "Trạng thái kết nối",
    // ... 更多字符串
]

LocalizationManager.shared.registerCustomStrings(
    vietnameseStrings,
    for: .vietnamese
)
```

### 2. 从文件加载语言包

```swift
// 从 JSON 文件加载
func loadLanguagePackFromJSON(fileName: String, language: SupportedLanguage) {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let strings = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
        print("无法加载语言包: \(fileName)")
        return
    }
    
    LocalizationManager.shared.registerCustomStrings(strings, for: language)
}

// 使用示例
loadLanguagePackFromJSON(fileName: "custom_zh_Hans", language: .simplifiedChinese)
```

### 3. 动态下载语言包

```swift
class RemoteLanguagePackManager {
    func downloadLanguagePack(for language: SupportedLanguage) async throws {
        let url = URL(string: "https://api.yourapp.com/language-packs/\(language.rawValue).json")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let strings = try JSONDecoder().decode([String: String].self, from: data)
        
        // 缓存到本地
        try saveLanguagePackToCache(strings, for: language)
        
        // 注册到本地化管理器
        await MainActor.run {
            LocalizationManager.shared.registerCustomStrings(strings, for: language)
        }
    }
    
    private func saveLanguagePackToCache(_ strings: [String: String], for language: SupportedLanguage) throws {
        let cacheURL = getCacheURL(for: language)
        let data = try JSONEncoder().encode(strings)
        try data.write(to: cacheURL)
    }
    
    private func getCacheURL(for language: SupportedLanguage) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("language_\(language.rawValue).json")
    }
}
```

## UI 组件本地化

### 1. SwiftUI 本地化组件

RealtimeKit 提供了专门的 SwiftUI 本地化组件：

```swift
import SwiftUI
import RealtimeKit

struct LocalizedContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 本地化文本
            LocalizedText("welcome_message")
                .font(.title)
            
            // 带参数的本地化文本
            LocalizedText("user_count", arguments: ["42"])
                .font(.body)
            
            // 本地化按钮
            LocalizedButton("join_room") {
                // 加入房间逻辑
            }
            .buttonStyle(.borderedProminent)
            
            // 本地化标签
            LocalizedLabel("audio_settings", systemImage: "speaker.wave.2")
            
            // 自定义样式的本地化文本
            LocalizedText("connection_status")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}

// 自定义本地化组件
struct LocalizedTextField: View {
    let key: String
    @Binding var text: String
    
    var body: some View {
        TextField(
            LocalizationManager.shared.localizedString(for: key),
            text: $text
        )
    }
}

// 使用示例
LocalizedTextField(key: "enter_room_id", text: $roomId)
```

### 2. UIKit 本地化扩展

RealtimeKit 为 UIKit 组件提供了本地化扩展：

```swift
import UIKit
import RealtimeKit

class LocalizedViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalizedUI()
        observeLanguageChanges()
    }
    
    private func setupLocalizedUI() {
        // 使用本地化扩展
        titleLabel.setLocalizedText("room_title")
        joinButton.setLocalizedTitle("join_room", for: .normal)
        
        // 带参数的本地化
        statusLabel.setLocalizedText("user_count", arguments: ["0"])
        
        // 导航栏本地化
        navigationItem.title = "main_title".localized
    }
    
    private func observeLanguageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageDidChange,
            object: nil
        )
    }
    
    @objc private func languageDidChange() {
        // 语言切换时更新 UI
        setupLocalizedUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// UIKit 扩展示例
extension UILabel {
    func setLocalizedText(_ key: String, arguments: [String] = []) {
        text = LocalizationManager.shared.localizedString(for: key, arguments: arguments)
    }
}

extension UIButton {
    func setLocalizedTitle(_ key: String, for state: UIControl.State, arguments: [String] = []) {
        let title = LocalizationManager.shared.localizedString(for: key, arguments: arguments)
        setTitle(title, for: state)
    }
}
```

### 3. 动态 UI 更新

实现语言切换时的 UI 自动更新：

```swift
// SwiftUI 自动更新
struct LanguageAwareView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack {
            Text(localizationManager.localizedString(for: "welcome_message"))
            
            Button(localizationManager.localizedString(for: "change_language")) {
                // 切换语言
                let newLanguage: SupportedLanguage = localizationManager.currentLanguage == .english ? .simplifiedChinese : .english
                localizationManager.setLanguage(newLanguage)
            }
        }
    }
}

// UIKit 手动更新
class LanguageAwareViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 监听语言变化
        LocalizationManager.shared.$currentLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLocalizedContent()
            }
            .store(in: &cancellables)
    }
    
    private func updateLocalizedContent() {
        // 更新所有本地化内容
        title = "main_title".localized
        // 更新其他 UI 元素...
    }
}
```

## 错误消息本地化

### 1. 本地化错误类型

RealtimeKit 的所有错误都支持本地化：

```swift
// 错误会自动使用当前语言显示
do {
    try await RealtimeManager.shared.joinRoom(roomId: "invalid-room")
} catch let error as RealtimeError {
    // 错误描述会根据当前语言显示
    showAlert(title: "error_title".localized, message: error.localizedDescription)
}

// 自定义错误本地化
enum CustomError: LocalizedError {
    case roomFull
    case userBanned
    case networkTimeout
    
    var errorDescription: String? {
        switch self {
        case .roomFull:
            return LocalizationManager.shared.localizedString(for: "error.room_full")
        case .userBanned:
            return LocalizationManager.shared.localizedString(for: "error.user_banned")
        case .networkTimeout:
            return LocalizationManager.shared.localizedString(for: "error.network_timeout")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .roomFull:
            return LocalizationManager.shared.localizedString(for: "error.room_full.reason")
        case .userBanned:
            return LocalizationManager.shared.localizedString(for: "error.user_banned.reason")
        case .networkTimeout:
            return LocalizationManager.shared.localizedString(for: "error.network_timeout.reason")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .roomFull:
            return LocalizationManager.shared.localizedString(for: "error.room_full.suggestion")
        case .userBanned:
            return LocalizationManager.shared.localizedString(for: "error.user_banned.suggestion")
        case .networkTimeout:
            return LocalizationManager.shared.localizedString(for: "error.network_timeout.suggestion")
        }
    }
}
```

### 2. 错误处理最佳实践

```swift
// 统一的错误处理器
class LocalizedErrorHandler {
    static func handleError(_ error: Error, in viewController: UIViewController) {
        let title = "error_title".localized
        let message: String
        let actions: [UIAlertAction]
        
        if let realtimeError = error as? RealtimeError {
            message = realtimeError.localizedDescription
            actions = createActionsForRealtimeError(realtimeError)
        } else if let customError = error as? CustomError {
            message = customError.localizedDescription
            actions = createActionsForCustomError(customError)
        } else {
            message = "error_unknown".localized
            actions = [UIAlertAction(title: "ok".localized, style: .default)]
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        actions.forEach { alert.addAction($0) }
        
        viewController.present(alert, animated: true)
    }
    
    private static func createActionsForRealtimeError(_ error: RealtimeError) -> [UIAlertAction] {
        switch error {
        case .networkUnavailable:
            return [
                UIAlertAction(title: "retry".localized, style: .default) { _ in
                    // 重试逻辑
                },
                UIAlertAction(title: "cancel".localized, style: .cancel)
            ]
        case .tokenExpired:
            return [
                UIAlertAction(title: "refresh_token".localized, style: .default) { _ in
                    // 刷新 Token 逻辑
                },
                UIAlertAction(title: "logout".localized, style: .destructive) { _ in
                    // 登出逻辑
                }
            ]
        default:
            return [UIAlertAction(title: "ok".localized, style: .default)]
        }
    }
}
```

## 动态语言切换

### 1. 语言选择器

创建用户友好的语言选择界面：

```swift
// SwiftUI 语言选择器
struct LanguagePickerView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(SupportedLanguage.allCases, id: \.rawValue) { language in
                    LanguageRow(
                        language: language,
                        isSelected: language == localizationManager.currentLanguage
                    ) {
                        localizationManager.setLanguage(language)
                    }
                }
            }
            .navigationTitle("select_language".localized)
        }
    }
}

struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(language.displayName)
                    .font(.body)
                Text(language.nativeName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// UIKit 语言选择器
class LanguageSelectionViewController: UITableViewController {
    private let languages = SupportedLanguage.allCases
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "select_language".localized
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LanguageCell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell", for: indexPath)
        let language = languages[indexPath.row]
        
        cell.textLabel?.text = language.displayName
        cell.detailTextLabel?.text = language.nativeName
        
        if language == LocalizationManager.shared.currentLanguage {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedLanguage = languages[indexPath.row]
        LocalizationManager.shared.setLanguage(selectedLanguage)
        
        tableView.reloadData()
        navigationController?.popViewController(animated: true)
    }
}
```

### 2. 持久化语言设置

使用 `@RealtimeStorage` 自动持久化语言设置：

```swift
extension LocalizationManager {
    @RealtimeStorage("selected_language", defaultValue: SupportedLanguage.english)
    private var persistedLanguage: SupportedLanguage
    
    func loadPersistedLanguage() {
        if persistedLanguage != currentLanguage {
            setLanguage(persistedLanguage)
        }
    }
    
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        persistedLanguage = language  // 自动持久化
        
        // 通知语言变化
        NotificationCenter.default.post(
            name: .languageDidChange,
            object: language
        )
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("RealtimeKit.languageDidChange")
}
```

## 最佳实践

### 1. 字符串键命名规范

使用一致的命名规范：

```swift
// ✅ 推荐：层次化命名
"connection.status.connected"
"connection.status.disconnected"
"connection.error.timeout"
"connection.error.network_unavailable"

"audio.volume.mixing"
"audio.volume.playback"
"audio.volume.recording"

"user.role.broadcaster"
"user.role.audience"
"user.role.cohost"

"error.authentication.failed"
"error.authentication.token_expired"
"error.network.unavailable"
"error.network.timeout"

// ❌ 避免：不一致的命名
"connectedStatus"
"disconnected_state"
"AudioVolumeLevel"
"user_broadcaster_role"
```

### 2. 参数化字符串格式

使用一致的参数格式：

```swift
// ✅ 推荐：使用 {0}, {1} 格式
"user_joined": "{0} 加入了房间 {1}"
"audio_volume": "音量: {0}%"
"connection_time": "连接时间: {0} 秒"

// 使用示例
let message = LocalizationManager.shared.localizedString(
    for: "user_joined",
    arguments: ["Alice", "Room001"]
)
// 结果: "Alice 加入了房间 Room001"

// ❌ 避免：不一致的参数格式
"user_joined": "%@ 加入了房间 %@"  // Objective-C 风格
"audio_volume": "音量: ${volume}%"   // 模板字符串风格
```

### 3. 回退策略

实现完善的回退机制：

```swift
extension LocalizationManager {
    func localizedString(for key: String, arguments: [String] = []) -> String {
        // 1. 尝试当前语言
        if let string = getLocalizedString(for: key, language: currentLanguage, arguments: arguments) {
            return string
        }
        
        // 2. 尝试英文回退
        if currentLanguage != .english,
           let string = getLocalizedString(for: key, language: .english, arguments: arguments) {
            return string
        }
        
        // 3. 返回键名作为最后回退
        return key
    }
    
    private func getLocalizedString(for key: String, language: SupportedLanguage, arguments: [String]) -> String? {
        // 1. 检查自定义字符串
        if let customString = customStrings[language]?[key] {
            return formatString(customString, with: arguments)
        }
        
        // 2. 检查内置字符串
        if let builtinString = builtinStrings[language]?[key] {
            return formatString(builtinString, with: arguments)
        }
        
        return nil
    }
    
    private func formatString(_ template: String, with arguments: [String]) -> String {
        var result = template
        for (index, argument) in arguments.enumerated() {
            result = result.replacingOccurrences(of: "{\(index)}", with: argument)
        }
        return result
    }
}
```

### 4. 性能优化

缓存本地化字符串以提高性能：

```swift
class LocalizationCache {
    private var cache: [String: [String: String]] = [:]
    private let cacheQueue = DispatchQueue(label: "localization.cache", attributes: .concurrent)
    
    func getCachedString(for key: String, language: SupportedLanguage) -> String? {
        return cacheQueue.sync {
            return cache[language.rawValue]?[key]
        }
    }
    
    func setCachedString(_ string: String, for key: String, language: SupportedLanguage) {
        cacheQueue.async(flags: .barrier) {
            if self.cache[language.rawValue] == nil {
                self.cache[language.rawValue] = [:]
            }
            self.cache[language.rawValue]?[key] = string
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}
```

## 故障排除

### 常见问题及解决方案

#### Q: 语言切换后 UI 没有更新

**A: 确保正确监听语言变化通知**

```swift
// SwiftUI - 使用 @StateObject
struct MyView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        Text(localizationManager.localizedString(for: "my_text"))
    }
}

// UIKit - 监听通知
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
```

#### Q: 自定义字符串没有生效

**A: 检查注册时机和键名**

```swift
// ✅ 确保在使用前注册
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 先注册自定义字符串
        registerCustomStrings()
        
        // 再配置 RealtimeKit
        configureRealtimeKit()
        
        return true
    }
    
    private func registerCustomStrings() {
        let customStrings = [
            "welcome_message": "欢迎使用我的应用！"  // 确保键名正确
        ]
        
        LocalizationManager.shared.registerCustomStrings(
            customStrings,
            for: .simplifiedChinese
        )
    }
}
```

#### Q: 参数化字符串显示异常

**A: 检查参数格式和数量**

```swift
// ✅ 正确的参数格式
"user_greeting": "你好 {0}，欢迎来到 {1}！"

// 使用时确保参数数量匹配
let greeting = LocalizationManager.shared.localizedString(
    for: "user_greeting",
    arguments: ["张三", "直播间001"]  // 参数数量要匹配
)

// ❌ 错误：参数数量不匹配
let greeting = LocalizationManager.shared.localizedString(
    for: "user_greeting",
    arguments: ["张三"]  // 缺少第二个参数
)
```

#### Q: 某些语言显示乱码

**A: 检查字符编码和字体支持**

```swift
// 确保字符串使用 UTF-8 编码
let chineseString = "你好世界"  // 确保源文件是 UTF-8 编码

// 检查字体是否支持特定字符
extension UIFont {
    func supportsCharacter(_ character: Character) -> Bool {
        let string = String(character)
        let size = string.size(withAttributes: [.font: self])
        return size.width > 0
    }
}

// 为不同语言使用合适的字体
extension UILabel {
    func setLocalizedText(_ key: String, language: SupportedLanguage? = nil) {
        let currentLanguage = language ?? LocalizationManager.shared.currentLanguage
        text = LocalizationManager.shared.localizedString(for: key)
        
        // 根据语言调整字体
        switch currentLanguage {
        case .simplifiedChinese, .traditionalChinese:
            font = UIFont.systemFont(ofSize: font.pointSize)  // 系统字体支持中文
        case .japanese:
            font = UIFont.systemFont(ofSize: font.pointSize)  // 系统字体支持日文
        case .korean:
            font = UIFont.systemFont(ofSize: font.pointSize)  // 系统字体支持韩文
        default:
            break
        }
    }
}
```

通过遵循本指南，您可以充分利用 RealtimeKit 的本地化功能，为全球用户提供优秀的多语言体验。