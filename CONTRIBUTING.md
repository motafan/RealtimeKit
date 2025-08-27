# 贡献指南

感谢您对 RealtimeKit 的关注！我们欢迎各种形式的贡献，包括但不限于代码、文档、测试、问题报告和功能建议。

## 目录

- [开发环境设置](#开发环境设置)
- [贡献类型](#贡献类型)
- [代码规范](#代码规范)
- [提交流程](#提交流程)
- [测试要求](#测试要求)
- [文档贡献](#文档贡献)
- [问题报告](#问题报告)
- [功能请求](#功能请求)

## 开发环境设置

### 系统要求

- **macOS**: 12.0 及以上版本
- **Xcode**: 15.0 及以上版本
- **Swift**: 6.2 及以上版本
- **Git**: 2.30 及以上版本

### 环境配置

1. **克隆仓库**：
   ```bash
   git clone https://github.com/your-org/RealtimeKit.git
   cd RealtimeKit
   ```

2. **安装依赖**：
   ```bash
   # 使用 Swift Package Manager 解析依赖
   swift package resolve
   
   # 或在 Xcode 中打开项目
   open Package.swift
   ```

3. **运行测试**：
   ```bash
   # 运行所有测试
   swift test
   
   # 运行特定模块测试
   swift test --filter RealtimeCoreTests
   ```

4. **运行示例应用**：
   ```bash
   # SwiftUI Demo
   swift run SwiftUIDemo
   
   # UIKit Demo
   swift run UIKitDemo
   ```

### 开发工具配置

推荐使用以下工具提高开发效率：

- **SwiftLint**: 代码风格检查
- **SwiftFormat**: 代码格式化
- **Sourcery**: 代码生成
- **Periphery**: 死代码检测

安装方式：
```bash
# 使用 Homebrew 安装
brew install swiftlint swiftformat sourcery periphery

# 或使用 Mint
mint install realm/SwiftLint
mint install nicklockwood/SwiftFormat
```

## 贡献类型

### 1. 代码贡献

- **新功能开发**: 实现新的 RTC/RTM 服务商支持
- **Bug 修复**: 修复已知问题和缺陷
- **性能优化**: 提升框架性能和资源使用效率
- **API 改进**: 优化现有 API 设计和易用性

### 2. 文档贡献

- **API 文档**: 完善接口说明和使用示例
- **教程文档**: 编写使用教程和最佳实践
- **翻译工作**: 将文档翻译为其他语言
- **示例代码**: 提供更多使用场景的示例

### 3. 测试贡献

- **单元测试**: 为现有功能编写测试用例
- **集成测试**: 测试组件间的协作
- **性能测试**: 测试框架性能表现
- **兼容性测试**: 测试不同平台和版本的兼容性

### 4. 社区贡献

- **问题回答**: 在 Issues 和 Discussions 中帮助其他用户
- **代码审查**: 参与 Pull Request 的审查
- **功能建议**: 提出有价值的功能改进建议
- **推广宣传**: 在社区中推广 RealtimeKit

## 代码规范

### Swift 代码风格

遵循 [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) 和以下规范：

#### 1. 命名规范

```swift
// ✅ 推荐：清晰的命名
class RealtimeManager: ObservableObject {
    func joinRoom(roomId: String, userId: String) async throws
    func setAudioMixingVolume(_ volume: Int) async throws
}

// ❌ 避免：模糊的命名
class RTManager {
    func join(_ id: String, _ uid: String) async throws
    func setVol(_ vol: Int) async throws
}
```

#### 2. 类型设计

```swift
// ✅ 推荐：使用枚举表示状态
enum ConnectionState: String, Codable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
}

// ✅ 推荐：使用结构体表示数据
struct UserVolumeInfo: Codable, Equatable, Sendable {
    let userId: String
    let volume: Float
    let isSpeaking: Bool
    let timestamp: Date
}

// ❌ 避免：使用字符串常量
let CONNECTION_STATE_CONNECTED = "connected"
```

#### 3. 错误处理

```swift
// ✅ 推荐：详细的错误类型
enum RealtimeError: LocalizedError, Equatable {
    case invalidConfiguration(String)
    case connectionFailed(String)
    case authenticationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let reason):
            return "配置无效: \(reason)"
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .authenticationFailed(let reason):
            return "认证失败: \(reason)"
        }
    }
}
```

#### 4. 并发安全

```swift
// ✅ 推荐：使用 MainActor 确保 UI 更新在主线程
@MainActor
class RealtimeManager: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    
    func updateConnectionState(_ state: ConnectionState) {
        connectionState = state  // 自动在主线程执行
    }
}

// ✅ 推荐：使用 Sendable 确保跨线程安全
struct UserVolumeInfo: Codable, Equatable, Sendable {
    // ...
}

// ✅ 推荐：正确的回调类型
func setVolumeHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void) {
    // ...
}
```

### 文档注释

使用标准的 Swift 文档注释格式：

```swift
/// 实时通信管理器，提供统一的 RTC/RTM 功能接口
///
/// RealtimeManager 是 RealtimeKit 的核心类，负责管理所有实时通信功能，
/// 包括用户会话、音频控制、音量检测等。
///
/// ## 使用示例
///
/// ```swift
/// let config = RealtimeConfig(appId: "your-app-id", appCertificate: "your-cert")
/// try await RealtimeManager.shared.configure(provider: .agora, config: config)
/// try await RealtimeManager.shared.joinRoom(roomId: "room-001")
/// ```
///
/// - Note: 在使用任何功能前，必须先调用 `configure` 方法进行初始化
/// - Warning: 所有方法都必须在主线程调用
@MainActor
public class RealtimeManager: ObservableObject {
    
    /// 加入指定房间
    ///
    /// - Parameters:
    ///   - roomId: 房间 ID，长度不超过 64 个字符
    ///   - userId: 用户 ID，长度不超过 32 个字符
    /// - Throws: `RealtimeError.invalidConfiguration` 如果配置无效
    /// - Throws: `RealtimeError.connectionFailed` 如果连接失败
    public func joinRoom(roomId: String, userId: String) async throws {
        // 实现...
    }
}
```

## 提交流程

### 1. Fork 和分支

```bash
# 1. Fork 仓库到您的 GitHub 账号

# 2. 克隆您的 Fork
git clone https://github.com/your-username/RealtimeKit.git
cd RealtimeKit

# 3. 添加上游仓库
git remote add upstream https://github.com/your-org/RealtimeKit.git

# 4. 创建功能分支
git checkout -b feature/your-feature-name
```

### 2. 开发和测试

```bash
# 1. 进行开发工作
# 编写代码、测试、文档...

# 2. 运行代码检查
swiftlint
swiftformat --lint .

# 3. 运行测试
swift test

# 4. 检查测试覆盖率
swift test --enable-code-coverage
```

### 3. 提交代码

```bash
# 1. 暂存更改
git add .

# 2. 提交更改（使用规范的提交消息）
git commit -m "feat: 添加新的音量检测算法

- 实现自适应阈值调整
- 添加噪音过滤功能
- 提高检测准确性 15%

Closes #123"

# 3. 推送到您的 Fork
git push origin feature/your-feature-name
```

### 4. 创建 Pull Request

1. 在 GitHub 上打开您的 Fork
2. 点击 "New Pull Request"
3. 选择目标分支（通常是 `main`）
4. 填写 PR 模板
5. 等待代码审查

### 提交消息规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**类型 (type)**:
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式化
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建工具、依赖更新等

**示例**:
```
feat(audio): 添加自适应音量检测

实现了基于环境噪音的自适应阈值调整算法，
提高了音量检测的准确性和稳定性。

- 添加噪音级别检测
- 实现动态阈值调整
- 优化检测性能

Closes #123
```

## 测试要求

### 1. 测试框架

RealtimeKit 使用 **Swift Testing** 框架（而不是 XCTest）：

```swift
import Testing
@testable import RealtimeKit

@Suite("RealtimeManager Tests")
struct RealtimeManagerTests {
    
    @Test("Should configure successfully with valid config")
    func testConfigureSuccess() async throws {
        let manager = RealtimeManager()
        let config = RealtimeConfig(appId: "test-app-id", appCertificate: "test-cert")
        
        try await manager.configure(provider: .mock, config: config)
        
        #expect(manager.isConfigured == true)
    }
    
    @Test("Should throw error with invalid config", arguments: [
        ("", "valid-cert"),
        ("valid-app-id", ""),
        ("", "")
    ])
    func testConfigureFailure(appId: String, appCert: String) async {
        let manager = RealtimeManager()
        let config = RealtimeConfig(appId: appId, appCertificate: appCert)
        
        await #expect(throws: RealtimeError.invalidConfiguration) {
            try await manager.configure(provider: .mock, config: config)
        }
    }
}
```

### 2. 测试覆盖率

- **最低要求**: 80% 代码覆盖率
- **推荐目标**: 90% 代码覆盖率
- **核心模块**: 95% 代码覆盖率

检查覆盖率：
```bash
swift test --enable-code-coverage
xcrun llvm-cov show .build/debug/RealtimeKitPackageTests.xctest/Contents/MacOS/RealtimeKitPackageTests -instr-profile .build/debug/codecov/default.profdata
```

### 3. 测试类型

#### 单元测试
```swift
@Suite("AudioSettings Tests")
struct AudioSettingsTests {
    
    @Test("Should validate volume range")
    func testVolumeValidation() {
        let settings = AudioSettings(audioMixingVolume: 150)  // 超出范围
        #expect(settings.audioMixingVolume == 100)  // 应该被限制为 100
    }
    
    @Test("Should update settings correctly")
    func testSettingsUpdate() {
        let original = AudioSettings.default
        let updated = original.withUpdatedVolume(audioMixing: 80)
        
        #expect(updated.audioMixingVolume == 80)
        #expect(updated.playbackSignalVolume == original.playbackSignalVolume)
    }
}
```

#### 集成测试
```swift
@Suite("RealtimeManager Integration Tests")
struct RealtimeManagerIntegrationTests {
    
    @Test("Should complete full room lifecycle")
    func testFullRoomLifecycle() async throws {
        let manager = RealtimeManager()
        let config = RealtimeConfig(appId: "test-app-id", appCertificate: "test-cert")
        
        // 配置
        try await manager.configure(provider: .mock, config: config)
        
        // 登录
        try await manager.loginUser(userId: "test-user", userName: "Test User", userRole: .broadcaster)
        #expect(manager.currentSession?.userId == "test-user")
        
        // 加入房间
        try await manager.joinRoom(roomId: "test-room")
        #expect(manager.connectionState == .connected)
        
        // 离开房间
        try await manager.leaveRoom()
        #expect(manager.connectionState == .disconnected)
        
        // 登出
        try await manager.logoutUser()
        #expect(manager.currentSession == nil)
    }
}
```

#### Mock 测试
```swift
class MockRTCProvider: RTCProvider {
    var joinRoomCalled = false
    var lastRoomId: String?
    
    func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        joinRoomCalled = true
        lastRoomId = roomId
    }
    
    // 实现其他必需方法...
}

@Suite("Mock Provider Tests")
struct MockProviderTests {
    
    @Test("Should track method calls")
    func testMockProvider() async throws {
        let mockProvider = MockRTCProvider()
        
        try await mockProvider.joinRoom(roomId: "test-room", userId: "test-user", userRole: .broadcaster)
        
        #expect(mockProvider.joinRoomCalled == true)
        #expect(mockProvider.lastRoomId == "test-room")
    }
}
```

## 文档贡献

### 1. 文档类型

- **API 文档**: 接口说明和参数描述
- **教程文档**: 分步骤的使用指南
- **示例代码**: 实际使用场景的代码示例
- **最佳实践**: 推荐的使用模式和技巧

### 2. 文档格式

使用 Markdown 格式，遵循以下结构：

```markdown
# 文档标题

简短的文档描述和目标读者说明。

## 目录

- [章节1](#章节1)
- [章节2](#章节2)

## 章节1

### 子章节

内容描述...

#### 代码示例

```swift
// 代码示例
let example = "示例代码"
```

#### 注意事项

> **注意**: 重要提示信息
> 
> **警告**: 需要特别注意的内容

## 参考链接

- [相关文档](link)
- [API 参考](link)
```

### 3. 多语言支持

优先使用中文编写文档，英文版本可以后续添加：

```
docs/
├── zh/                 # 中文文档
│   ├── api-reference.md
│   └── quick-start.md
└── en/                 # 英文文档
    ├── api-reference.md
    └── quick-start.md
```

## 问题报告

### 1. 报告模板

使用以下模板报告问题：

```markdown
## 问题描述

简要描述遇到的问题。

## 复现步骤

1. 第一步
2. 第二步
3. 第三步

## 预期行为

描述您期望发生的情况。

## 实际行为

描述实际发生的情况。

## 环境信息

- RealtimeKit 版本: 1.0.0
- iOS 版本: 17.0
- Xcode 版本: 15.0
- 设备型号: iPhone 15 Pro

## 相关代码

```swift
// 相关的代码片段
```

## 错误日志

```
错误日志内容
```

## 附加信息

其他可能有用的信息。
```

### 2. 问题分类

使用标签对问题进行分类：

- `bug`: 功能缺陷
- `enhancement`: 功能改进
- `documentation`: 文档相关
- `question`: 使用问题
- `performance`: 性能问题
- `compatibility`: 兼容性问题

## 功能请求

### 1. 请求模板

```markdown
## 功能描述

简要描述建议的新功能。

## 使用场景

描述这个功能的使用场景和目标用户。

## 建议的 API 设计

```swift
// 建议的 API 接口
func newFeature(parameter: String) async throws -> Result
```

## 替代方案

描述现有的替代解决方案。

## 优先级

- [ ] 低优先级
- [ ] 中优先级
- [x] 高优先级

## 愿意贡献

- [x] 我愿意实现这个功能
- [ ] 我需要帮助实现这个功能
- [ ] 我只是提出建议
```

### 2. 功能评估

功能请求会根据以下标准进行评估：

- **用户价值**: 对用户的实际价值
- **实现复杂度**: 开发和维护成本
- **兼容性影响**: 对现有 API 的影响
- **社区需求**: 社区的需求程度

## 代码审查

### 1. 审查清单

在提交 PR 前，请确保：

- [ ] 代码遵循项目规范
- [ ] 添加了适当的测试
- [ ] 更新了相关文档
- [ ] 通过了所有测试
- [ ] 没有引入新的警告
- [ ] 考虑了向后兼容性

### 2. 审查标准

代码审查会关注以下方面：

- **功能正确性**: 代码是否正确实现了预期功能
- **代码质量**: 代码是否清晰、可维护
- **性能影响**: 是否有性能问题
- **安全性**: 是否存在安全隐患
- **测试覆盖**: 测试是否充分

## 发布流程

### 1. 版本号规范

使用 [Semantic Versioning](https://semver.org/) 规范：

- **主版本号**: 不兼容的 API 更改
- **次版本号**: 向后兼容的功能添加
- **修订版本号**: 向后兼容的问题修复

### 2. 发布检查

发布前需要确保：

- [ ] 所有测试通过
- [ ] 文档已更新
- [ ] 变更日志已更新
- [ ] 版本号已更新
- [ ] 标签已创建

## 社区准则

### 1. 行为准则

我们致力于为所有人提供友好、安全和欢迎的环境：

- **尊重他人**: 尊重不同的观点和经验
- **建设性沟通**: 提供建设性的反馈和建议
- **包容性**: 欢迎所有背景的贡献者
- **专业性**: 保持专业和礼貌的交流

### 2. 沟通渠道

- **GitHub Issues**: 问题报告和功能请求
- **GitHub Discussions**: 一般讨论和问答
- **Pull Requests**: 代码审查和讨论
- **邮件**: 私人或敏感问题

## 致谢

感谢所有为 RealtimeKit 做出贡献的开发者！您的贡献让这个项目变得更好。

### 贡献者列表

贡献者信息会自动从 Git 历史中生成，包括：

- 代码贡献者
- 文档贡献者
- 问题报告者
- 功能建议者

---

再次感谢您对 RealtimeKit 的贡献！如果您有任何问题，请随时通过 GitHub Issues 或 Discussions 联系我们。