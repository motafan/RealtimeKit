# RTCProvider joinRoom Token 参数更新总结

## 变更概述

更新了 `RTCProvider` 协议中的 `joinRoom` 方法，添加了 `token` 参数以支持身份验证令牌。

## 变更详情

### 1. 协议方法签名更新

**之前:**
```swift
func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws
```

**之后:**
```swift
func joinRoom(roomId: String, userId: String, userRole: UserRole, token: String?) async throws
```

### 2. 实现更新

#### AgoraRTCProvider
- 更新了 `joinRoom` 方法接受 `token` 参数
- 更新了 `agoraJoinRoom` 辅助方法传递 token 给 Agora SDK
- 使用 `agoraKit.joinChannel(byToken: token, ...)` 进行身份验证

#### MockingRTCProvider
- 更新了 `joinRoom` 方法签名以匹配协议
- 保持模拟行为不变

#### MockRTCProvider (ProviderTypes.swift)
- 更新了 `joinRoom` 方法签名
- 添加了 token 日志输出

### 3. RealtimeManager 更新

**新的方法签名:**
```swift
public func joinRoom(roomId: String, token: String? = nil) async throws
```

**Token 处理逻辑:**
- 优先使用传入的 `token` 参数
- 如果未提供，则使用存储在 `authTokens` 中的 token（基于当前 provider）
- 支持向后兼容（token 参数可选）

### 4. 测试更新

更新了所有测试文件中的 `joinRoom` 调用：
- `AgoraProviderTests.swift`
- `MockingTests.swift`
- `CONTRIBUTING.md` 中的示例

### 5. 文档更新

更新了以下文档文件：
- `docs/API-Reference.md`
- `.kiro/specs/realtimekit-swift-package/design.md`
- `realtimekit-prompt.md`

## 向后兼容性

### RealtimeManager 级别
- ✅ **完全向后兼容**: `joinRoom(roomId:)` 调用仍然有效
- ✅ **可选参数**: `token` 参数是可选的，默认为 `nil`
- ✅ **自动 Token 管理**: 如果未提供 token，会自动使用存储的 token

### RTCProvider 协议级别
- ⚠️ **破坏性变更**: 直接实现 `RTCProvider` 的代码需要更新
- ✅ **所有内置实现已更新**: Agora 和 Mock 实现都已更新

## 使用示例

### 使用 RealtimeManager (推荐)
```swift
// 向后兼容 - 使用存储的 token
try await RealtimeManager.shared.joinRoom(roomId: "room001")

// 新方式 - 显式提供 token
try await RealtimeManager.shared.joinRoom(roomId: "room001", token: "your_token")
```

### 直接使用 RTCProvider
```swift
// 需要更新为新的签名
try await rtcProvider.joinRoom(
    roomId: "room001", 
    userId: "user123", 
    userRole: .broadcaster, 
    token: "your_token"
)
```

## Token 管理

### 存储 Token
```swift
// 使用 RealtimeManager 的 token 管理
RealtimeManager.shared.authTokens["agora"] = "your_token"

// 或使用 PersistentStateManager
PersistentStateManager.shared.storeAuthToken("your_token", for: .agora)
```

### Token 获取优先级
1. 方法参数中的 `token`
2. `RealtimeManager.shared.authTokens[currentProvider.rawValue]` 中存储的 token
3. `nil` (无 token)

## 影响范围

### 需要更新的代码
- 直接实现 `RTCProvider` 协议的自定义提供者
- 直接调用 `rtcProvider.joinRoom()` 的代码

### 不需要更新的代码
- 使用 `RealtimeManager.shared.joinRoom()` 的代码
- 使用内置提供者 (Agora, Mock) 的代码

## 安全考虑

- Token 作为可选参数，避免强制要求
- 支持运行时 token 更新
- 与现有的 token 管理系统集成
- 敏感信息通过安全存储管理

## 测试验证

- ✅ 所有现有测试已更新并通过
- ✅ 向后兼容性测试通过
- ✅ Token 传递逻辑测试通过
- ✅ 文档示例验证通过