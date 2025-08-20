# RealtimeKit Swift Package

RealtimeKit 是一个统一的 Swift Package，用于集成多家第三方 RTM (Real-Time Messaging) 和 RTC (Real-Time Communication) 服务提供商，为 iOS/macOS 应用提供统一的实时通信解决方案。

## 项目结构

```
RealtimeKit/
├── Package.swift                    # Swift Package 配置文件
├── README.md                       # 项目说明文档
├── Sources/                        # 源代码目录
│   ├── RealtimeKit/               # 主模块 (重新导出所有功能)
│   │   └── RealtimeKit.swift
│   ├── RealtimeCore/              # 核心模块
│   │   ├── RealtimeCore.swift     # 模块主文件
│   │   ├── Protocols/             # 核心协议定义
│   │   │   ├── RTCProvider.swift  # RTC 提供商协议
│   │   │   ├── RTMProvider.swift  # RTM 提供商协议
│   │   │   └── MessageProcessor.swift # 消息处理协议
│   │   ├── Models/                # 数据模型
│   │   │   ├── Enums.swift        # 核心枚举类型
│   │   │   ├── AudioSettings.swift # 音频设置模型
│   │   │   ├── UserSession.swift  # 用户会话模型
│   │   │   ├── VolumeModels.swift # 音量检测模型
│   │   │   ├── StreamModels.swift # 流媒体模型
│   │   │   ├── MessageModels.swift # 消息模型
│   │   │   ├── ConfigModels.swift # 配置模型
│   │   │   ├── RTCRoom.swift      # RTC 房间模型
│   │   │   └── RealtimeError.swift # 错误处理
│   │   └── Managers/              # 管理器类
│   │       └── RealtimeManager.swift # 主管理器 (占位符)
│   ├── RealtimeUIKit/             # UIKit 集成模块
│   │   └── RealtimeUIKit.swift
│   ├── RealtimeSwiftUI/           # SwiftUI 集成模块
│   │   └── RealtimeSwiftUI.swift
│   ├── RealtimeAgora/             # Agora 提供商实现
│   │   └── RealtimeAgora.swift
│   └── RealtimeMocking/           # 测试用 Mock 提供商
│       └── RealtimeMocking.swift
└── Tests/                         # 测试目录
    ├── RealtimeCoreTests/
    │   └── RealtimeCoreTests.swift
    ├── RealtimeUIKitTests/
    ├── RealtimeSwiftUITests/
    ├── RealtimeAgoraTests/
    └── RealtimeMockingTests/
        └── MockProviderTests.swift
```

## 模块说明

### RealtimeKit (主模块)
- 重新导出所有子模块的功能
- 提供统一的入口点
- 包含版本信息

### RealtimeCore (核心模块)
- **协议定义**: RTCProvider, RTMProvider, MessageProcessor
- **数据模型**: 用户角色、音频设置、音量检测、流媒体配置等
- **错误处理**: 统一的错误类型和本地化描述
- **管理器**: RealtimeManager 主管理器 (占位符实现)

### RealtimeUIKit (UIKit 集成)
- UIKit 专用的视图控制器和组件
- Delegate 模式的事件处理
- UIKit 特定的状态管理

### RealtimeSwiftUI (SwiftUI 集成)
- SwiftUI 声明式组件
- @Published 属性和响应式更新
- Environment 和 EnvironmentObject 支持

### RealtimeAgora (Agora 提供商)
- Agora SDK 的 RTCProvider 和 RTMProvider 实现
- 占位符实现，待后续任务完善

### RealtimeMocking (测试模块)
- Mock 提供商实现，用于单元测试
- 可配置的模拟行为和错误注入
- 完整的测试工具支持

## 平台和框架支持

### 平台兼容性
- **iOS**: 13.0 及以上版本
- **macOS**: 10.15 及以上版本
- **Swift**: 6.0 及以上版本

### 并发机制
- **Swift Concurrency**: 全面使用 async/await, actors, structured concurrency
- **线程安全**: 使用 actor 模式确保数据安全
- **异步操作**: 所有网络和 I/O 操作均为异步

### 框架支持
- **UIKit**: 完整的 UIKit 组件支持，适用于传统 MVC/MVVM 架构
- **SwiftUI**: 声明式 UI 组件，支持响应式数据绑定和状态管理
- **混合使用**: 支持在同一应用中同时使用 UIKit 和 SwiftUI 组件

## 核心特性

### 1. 统一的协议接口
- RTCProvider: 音视频通信功能
- RTMProvider: 实时消息功能
- MessageProcessor: 消息处理管道

### 2. 完整的数据模型
- 用户角色和权限系统
- 音频设置和持久化
- 音量检测和可视化
- 转推流和媒体中继配置

### 3. 错误处理系统
- 详细的错误类型定义
- 本地化错误描述
- 可恢复性标识

### 4. 双框架支持
- UIKit: Delegate 模式和传统回调
- SwiftUI: @Published 属性和响应式编程

## 使用方式

### 完整导入
```swift
import RealtimeKit
// 包含所有功能模块
```

### 按需导入
```swift
import RealtimeCore      // 仅核心功能
import RealtimeUIKit     // UIKit 集成
import RealtimeSwiftUI   // SwiftUI 集成
import RealtimeAgora     // Agora 提供商
import RealtimeMocking   // 测试模块
```

## 测试

项目使用 Swift Testing 框架进行测试：

```bash
swift test
```

测试覆盖：
- 核心数据模型验证
- Mock 提供商功能测试
- 错误处理测试
- 协议接口测试

## 开发状态

当前完成的任务：
- ✅ 项目基础结构建立
- ✅ 核心协议定义 (RTCProvider, RTMProvider)
- ✅ 基础数据模型和枚举类型
- ✅ Swift Package 配置和模块依赖
- ✅ Mock 提供商实现
- ✅ 基础测试框架

待实现的功能：
- 完整的 RealtimeManager 实现
- 音量指示器管理系统
- Token 自动续期管理
- 转推流和媒体中继功能
- UIKit 和 SwiftUI 组件
- Agora SDK 集成
- 完整的测试覆盖

## Swift 6.0 并发安全特性

项目已全面适配 Swift 6.0 的并发安全要求：

### 并发安全改进
- **Sendable 协议**: 所有回调函数和闭包都标记为 `@Sendable`，确保跨线程安全
- **Actor 隔离**: RealtimeManager 使用 `@MainActor` 确保 UI 更新的线程安全
- **结构化并发**: 使用 `async/await` 和 `Task` 替代传统的 `DispatchQueue`
- **数据竞争检测**: 通过 Swift 6.0 的编译时检查避免数据竞争

### 向后兼容性
- **iOS 13.0+**: 支持较旧的 iOS 版本，使用 `@ObservedObject` 替代 `@StateObject`
- **macOS 10.15+**: 支持较旧的 macOS 版本
- **条件编译**: 使用 `#if canImport(UIKit)` 确保跨平台兼容性

## 版本信息

- RealtimeKit: 1.0.0
- RealtimeCore: 1.0.0
- 最低支持: iOS 13.0, macOS 10.15
- Swift 版本: 6.0+
- 并发机制: Swift Concurrency (async/await, actors, structured concurrency)