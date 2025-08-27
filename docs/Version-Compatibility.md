# RealtimeKit 版本兼容性指南

本文档详细说明 RealtimeKit 各版本的兼容性信息，包括平台支持、依赖要求和迁移指南。

## 目录

- [版本概览](#版本概览)
- [平台兼容性](#平台兼容性)
- [Swift 版本兼容性](#swift-版本兼容性)
- [依赖兼容性](#依赖兼容性)
- [API 兼容性](#api-兼容性)
- [迁移指南](#迁移指南)
- [弃用政策](#弃用政策)

## 版本概览

| 版本 | 发布日期 | 状态 | 支持结束 | 主要特性 |
|------|----------|------|----------|----------|
| 1.0.0 | 2024-12 | 当前版本 | TBD | 初始版本，完整功能 |
| 1.1.0 | 2025-01 (计划) | 开发中 | TBD | 腾讯云 TRTC 支持 |
| 1.2.0 | 2025-02 (计划) | 计划中 | TBD | 即构 ZEGO 支持 |
| 2.0.0 | 2025-06 (计划) | 计划中 | TBD | 重大架构升级 |

## 平台兼容性

### iOS 兼容性

| RealtimeKit 版本 | 最低 iOS 版本 | 推荐 iOS 版本 | 最高测试版本 |
|------------------|---------------|---------------|--------------|
| 1.0.0 | iOS 13.0 | iOS 15.0+ | iOS 17.2 |
| 1.1.0 (计划) | iOS 13.0 | iOS 13.0+ | iOS 17.4 |
| 1.2.0 (计划) | iOS 13.0 | iOS 13.0+ | iOS 18.0 |
| 2.0.0 (计划) | iOS 15.0 | iOS 17.0+ | iOS 18.0+ |

#### iOS 版本特性支持

**iOS 13.0 - 最低支持版本**
- ✅ 基础 SwiftUI 支持
- ✅ Combine 框架
- ✅ Swift Concurrency (部分)
- ⚠️ 某些 SwiftUI 特性受限

**iOS 13.0 - 改进支持**
- ✅ 完整 SwiftUI 2.0 支持
- ✅ App Clips 支持
- ✅ Widget 支持
- ✅ 改进的 Swift Concurrency

**iOS 15.0+ - 推荐版本**
- ✅ 完整 Swift Concurrency 支持
- ✅ SwiftUI 3.0 新特性
- ✅ 异步图像加载
- ✅ 更好的性能和稳定性

### macOS 兼容性

| RealtimeKit 版本 | 最低 macOS 版本 | 推荐 macOS 版本 | 最高测试版本 |
|------------------|-----------------|-----------------|--------------|
| 1.0.0 | macOS 10.15 | macOS 12.0+ | macOS 14.2 |
| 1.1.0 (计划) | macOS 10.15 | macOS 10.15+ | macOS 14.4 |
| 1.2.0 (计划) | macOS 10.15 | macOS 10.15+ | macOS 15.0 |
| 2.0.0 (计划) | macOS 12.0 | macOS 14.0+ | macOS 15.0+ |

#### macOS 版本特性支持

**macOS 10.15 - 最低支持版本**
- ✅ 基础 SwiftUI 支持
- ✅ Catalyst 应用支持
- ✅ 基础 Combine 支持
- ⚠️ Swift Concurrency 受限

**macOS 10.15+ - 改进支持**
- ✅ 完整 SwiftUI 2.0 支持
- ✅ 原生 Apple Silicon 支持
- ✅ 改进的 Catalyst 支持
- ✅ 更好的性能

**macOS 12.0+ - 推荐版本**
- ✅ 完整 Swift Concurrency 支持
- ✅ SwiftUI 3.0 新特性
- ✅ 最佳性能和稳定性
- ✅ 完整的现代 macOS 特性

## Swift 版本兼容性

### Swift 版本要求

| RealtimeKit 版本 | 最低 Swift 版本 | 推荐 Swift 版本 | 支持的 Swift 版本 |
|------------------|-----------------|-----------------|-------------------|
| 1.0.0 | Swift 6.2 | Swift 6.2+ | 6.2+ |
| 1.1.0 (计划) | Swift 6.2 | Swift 6.3+ | 6.2 - 6.3 |
| 1.2.0 (计划) | Swift 6.3 | Swift 6.4+ | 6.3 - 6.4 |
| 2.0.0 (计划) | Swift 6.4 | Swift 6.5+ | 6.4+ |

### Swift 特性使用

#### Swift 6.2 特性
- ✅ **完整并发支持**: async/await, actors, structured concurrency
- ✅ **Sendable 协议**: 确保跨线程安全
- ✅ **Actor 隔离**: @MainActor 和自定义 actors
- ✅ **结构化并发**: TaskGroup, async let

#### Swift 6.3+ 特性 (计划)
- 🚧 **改进的并发检查**: 更严格的数据竞争检测
- 🚧 **新的属性包装器**: 更强大的状态管理
- 🚧 **性能优化**: 编译器优化改进

### Xcode 版本兼容性

| RealtimeKit 版本 | 最低 Xcode 版本 | 推荐 Xcode 版本 | 支持的 Xcode 版本 |
|------------------|-----------------|-----------------|-------------------|
| 1.0.0 | Xcode 15.0 | Xcode 15.2+ | 15.0 - 15.4 |
| 1.1.0 (计划) | Xcode 15.2 | Xcode 15.4+ | 15.2 - 16.0 |
| 1.2.0 (计划) | Xcode 15.4 | Xcode 16.0+ | 15.4 - 16.2 |
| 2.0.0 (计划) | Xcode 16.0 | Xcode 16.2+ | 16.0+ |

## 依赖兼容性

### 服务商 SDK 兼容性

#### Agora SDK

| RealtimeKit 版本 | Agora RTC SDK | Agora RTM SDK | 状态 |
|------------------|---------------|---------------|------|
| 1.0.0 | 4.0.0+ | 1.5.0+ | ✅ 支持 |
| 1.1.0 (计划) | 4.2.0+ | 2.0.0+ | 🚧 计划 |
| 1.2.0 (计划) | 4.3.0+ | 2.1.0+ | 🚧 计划 |

#### 腾讯云 TRTC SDK

| RealtimeKit 版本 | TRTC SDK | TIM SDK | 状态 |
|------------------|----------|---------|------|
| 1.0.0 | - | - | ❌ 不支持 |
| 1.1.0 (计划) | 11.0+ | 7.0+ | 🚧 开发中 |
| 1.2.0 (计划) | 11.2+ | 7.2+ | 🚧 计划 |

#### 即构 ZEGO SDK

| RealtimeKit 版本 | ZEGO Express SDK | ZEGO ZIM SDK | 状态 |
|------------------|------------------|--------------|------|
| 1.0.0 | - | - | ❌ 不支持 |
| 1.1.0 (计划) | - | - | ❌ 不支持 |
| 1.2.0 (计划) | 3.0+ | 2.5+ | 🚧 开发中 |

### 系统框架依赖

| 框架 | 最低版本 | 用途 | 必需性 |
|------|----------|------|--------|
| Foundation | iOS 13.0 / macOS 10.15 | 基础功能 | 必需 |
| SwiftUI | iOS 13.0 / macOS 10.15 | UI 组件 | 可选 |
| UIKit | iOS 13.0 | UIKit 集成 | 可选 |
| Combine | iOS 13.0 / macOS 10.15 | 响应式编程 | 必需 |
| AVFoundation | iOS 13.0 / macOS 10.15 | 音频处理 | 必需 |
| Network | iOS 12.0 / macOS 10.14 | 网络监控 | 可选 |

## API 兼容性

### 语义化版本控制

RealtimeKit 遵循 [语义化版本控制](https://semver.org/) 规范：

- **主版本号 (Major)**: 不兼容的 API 变更
- **次版本号 (Minor)**: 向后兼容的功能新增
- **修订号 (Patch)**: 向后兼容的问题修正

### API 稳定性保证

#### 1.x 系列 (当前)
- ✅ **公开 API**: 保证向后兼容
- ✅ **数据模型**: 保证结构兼容
- ✅ **协议接口**: 保证签名兼容
- ⚠️ **内部 API**: 可能变更，不建议使用

#### 2.x 系列 (计划)
- 🔄 **重大重构**: 可能包含破坏性变更
- 📚 **迁移指南**: 提供详细的迁移文档
- 🛠️ **迁移工具**: 提供自动化迁移工具

### API 变更历史

#### 1.0.0 → 1.1.0 (计划)
**新增 API**:
```swift
// 新增腾讯云 TRTC 支持
public enum ProviderType {
    case agora
    case tencent  // 新增
    case mock
}

// 新增视频功能
extension RealtimeManager {
    func enableVideo() async throws  // 新增
    func disableVideo() async throws  // 新增
}
```

**弃用 API**:
```swift
// 无弃用 API
```

**破坏性变更**:
```swift
// 无破坏性变更
```

#### 1.1.0 → 1.2.0 (计划)
**新增 API**:
```swift
// 新增即构 ZEGO 支持
public enum ProviderType {
    case agora
    case tencent
    case zego  // 新增
    case mock
}

// 新增录制功能
extension RealtimeManager {
    func startRecording(config: RecordingConfig) async throws  // 新增
    func stopRecording() async throws  // 新增
}
```

## 迁移指南

### 从 1.0.0 迁移到 1.1.0

#### 准备工作
1. **备份项目**: 确保代码已提交到版本控制
2. **测试覆盖**: 确保有足够的测试覆盖
3. **依赖检查**: 检查第三方依赖兼容性

#### 迁移步骤
```swift
// 1. 更新 Package.swift
dependencies: [
    .package(url: "https://github.com/your-org/RealtimeKit", from: "1.1.0")
]

// 2. 无需修改现有代码 (向后兼容)

// 3. 可选：使用新功能
try await RealtimeManager.shared.configure(
    provider: .tencent,  // 新的服务商选项
    config: config
)
```

### 从 1.x 迁移到 2.0.0 (计划)

#### 重大变更预告
1. **最低版本要求**: iOS 15.0+ / macOS 12.0+
2. **Swift 版本**: 最低 Swift 6.4
3. **API 重构**: 部分 API 可能重新设计
4. **性能优化**: 内部实现大幅优化

#### 迁移工具 (计划)
```bash
# 自动化迁移工具
swift run RealtimeKitMigrator --from 1.x --to 2.0 --path ./Sources
```

## 弃用政策

### 弃用时间线
1. **弃用声明**: 在次版本中标记为 `@available(*, deprecated)`
2. **弃用期**: 至少保持 2 个次版本的兼容性
3. **移除**: 在下一个主版本中完全移除

### 弃用示例
```swift
// 1.0.0 - 原始 API
func oldMethod() { }

// 1.1.0 - 标记弃用
@available(*, deprecated, message: "Use newMethod() instead")
func oldMethod() { }

func newMethod() { }  // 新的推荐方法

// 2.0.0 - 完全移除
// func oldMethod() { }  // 已移除
func newMethod() { }
```

### 当前弃用列表

#### 1.0.0
- 无弃用 API

#### 1.1.0 (计划)
- 无计划弃用 API

## 测试兼容性

### 测试框架支持

| RealtimeKit 版本 | Swift Testing | XCTest | 推荐框架 |
|------------------|---------------|--------|----------|
| 1.0.0 | ✅ 主要支持 | ⚠️ 有限支持 | Swift Testing |
| 1.1.0 (计划) | ✅ 完整支持 | ✅ 完整支持 | Swift Testing |
| 2.0.0 (计划) | ✅ 完整支持 | ✅ 完整支持 | Swift Testing |

### 测试迁移

#### 从 XCTest 迁移到 Swift Testing
```swift
// XCTest (旧)
import XCTest
@testable import RealtimeKit

class RealtimeKitTests: XCTestCase {
    func testAudioSettings() {
        let settings = AudioSettings()
        XCTAssertEqual(settings.audioMixingVolume, 100)
    }
}

// Swift Testing (新)
import Testing
@testable import RealtimeKit

@Suite("RealtimeKit Tests")
struct RealtimeKitTests {
    @Test("Audio settings default values")
    func audioSettingsDefaults() {
        let settings = AudioSettings()
        #expect(settings.audioMixingVolume == 100)
    }
}
```

## 性能兼容性

### 性能基准

| 指标 | 1.0.0 | 1.1.0 (目标) | 1.2.0 (目标) |
|------|-------|--------------|--------------|
| 启动时间 | <1s | <0.8s | <0.6s |
| 内存使用 | ~10MB | ~8MB | ~6MB |
| 连接延迟 | <2s | <1.5s | <1s |
| 音频延迟 | <100ms | <80ms | <60ms |

### 性能回归测试

每个版本都会进行性能回归测试，确保：
- 启动时间不超过前一版本的 110%
- 内存使用不超过前一版本的 105%
- 网络延迟不超过前一版本的 105%

## 支持政策

### 版本支持周期

| 版本类型 | 支持周期 | 安全更新 | 功能更新 |
|----------|----------|----------|----------|
| 当前版本 | 持续支持 | ✅ | ✅ |
| 前一主版本 | 12 个月 | ✅ | ❌ |
| 更早版本 | 不支持 | ❌ | ❌ |

### 获取支持

1. **文档**: 查看版本特定的文档
2. **GitHub Issues**: 报告兼容性问题
3. **社区论坛**: 获取社区帮助
4. **技术支持**: 联系官方技术支持

---

*本文档会随着新版本发布持续更新。如有疑问，请查看最新版本的文档或联系技术支持。*
