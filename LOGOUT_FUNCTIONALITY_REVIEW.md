# RealtimeManager 登出功能审查和修复报告

## 问题分析

### 发现的主要问题

1. **职责混淆**：原始的 `logoutUser()` 方法错误地包含了 RTC 相关的操作
   - 登出应该只处理 RTM（消息系统）的注销
   - 不应该自动调用 `leaveRoom()` 方法，因为这会断开音视频连接

2. **违反单一职责原则**：
   - 登出（logout）和离开房间（leaveRoom）是两个不同的概念
   - 用户可能希望保持音视频连接但登出消息系统
   - 或者只离开房间但保持登录状态

3. **状态管理不一致**：
   - `connectionState` 被错误地在登出时设置为 `disconnected`
   - 这个状态应该反映 RTC 连接状态，而不是 RTM 登录状态

## 修复内容

### 1. 重构 `logoutUser()` 方法

**修复前**：
```swift
public func logoutUser(reason: LogoutReason = .userInitiated) async throws {
    // 如果在房间中，先离开房间 ❌ 错误：不应该自动离开房间
    if session.isInRoom {
        try await leaveRoom()
    }
    
    // 登出RTM系统
    try await rtmProvider?.logout()
    
    connectionState = .disconnected // ❌ 错误：不应该修改 RTC 连接状态
}
```

**修复后**：
```swift
public func logoutUser(reason: LogoutReason = .userInitiated) async throws {
    // 只登出RTM系统 ✅ 正确：只处理消息系统注销
    try await rtmProvider?.logout()
    
    // 清理会话状态，但不修改 connectionState ✅ 正确：保持 RTC 状态独立
    currentSession = nil
    sessionStorage.clearUserSession()
}
```

### 2. 改进 `leaveRoom()` 方法

**修复后**：
```swift
public func leaveRoom() async throws {
    // 离开RTC房间（音视频通话）
    try await rtcProvider.leaveRoom()
    
    // 如果RTM已登录且在频道中，也离开RTM频道
    if let roomId = currentRoomId, rtmProvider?.isLoggedIn() == true {
        try await rtmProvider?.leaveChannel(channelId: roomId)
    }
    
    // 更新连接状态为断开 ✅ 正确：这里才应该修改连接状态
    connectionState = .disconnected
}
```

### 3. 新增细粒度控制方法

#### `disconnectAndLogout()` - 完全断开连接
```swift
public func disconnectAndLogout(reason: LogoutReason = .userInitiated) async throws {
    // 先离开房间（如果在房间中）
    if currentSession?.isInRoom == true {
        try await leaveRoom()
    }
    
    // 然后登出用户
    try await logoutUser(reason: reason)
}
```

#### `leaveRTCRoom()` - 只离开音视频房间
```swift
public func leaveRTCRoom() async throws {
    try await rtcProvider.leaveRoom()
    connectionState = .disconnected
    // 不影响 RTM 连接
}
```

#### `leaveRTMChannel()` - 只离开消息频道
```swift
public func leaveRTMChannel(channelId: String? = nil) async throws {
    let targetChannelId = channelId ?? currentSession?.roomId
    try await rtmProvider?.leaveChannel(channelId: targetChannelId)
    // 不影响 RTC 连接
}
```

### 4. 新增通知系统

添加了更细粒度的通知，以便应用层能够准确响应不同的操作：

```swift
extension Notification.Name {
    // 原有通知
    public static let userDidLogout = Notification.Name("RealtimeKit.userDidLogout")
    
    // 新增房间相关通知
    public static let didLeaveRoom = Notification.Name("RealtimeKit.didLeaveRoom")
    public static let didLeaveRTCRoom = Notification.Name("RealtimeKit.didLeaveRTCRoom")
    public static let didLeaveRTMChannel = Notification.Name("RealtimeKit.didLeaveRTMChannel")
    public static let didDisconnectAndLogout = Notification.Name("RealtimeKit.didDisconnectAndLogout")
}
```

## 使用指南

### 场景 1：用户主动登出（只注销消息系统）
```swift
// 只登出 RTM 消息系统，保持音视频连接
try await RealtimeManager.shared.logoutUser()
```

### 场景 2：离开房间（断开音视频和消息）
```swift
// 离开房间，同时断开 RTC 和 RTM 连接
try await RealtimeManager.shared.leaveRoom()
```

### 场景 3：完全断开连接并登出
```swift
// 先离开房间，再登出用户
try await RealtimeManager.shared.disconnectAndLogout()
```

### 场景 4：只离开音视频房间
```swift
// 只断开音视频连接，保持消息连接
try await RealtimeManager.shared.leaveRTCRoom()
```

### 场景 5：只离开消息频道
```swift
// 只离开消息频道，保持音视频连接
try await RealtimeManager.shared.leaveRTMChannel()
```

## 符合需求文档的改进

### 需求 1：统一 API 接口
- ✅ 明确分离了 RTCProvider 和 RTMProvider 的职责
- ✅ 提供了一致的 API 接口，避免了职责混淆

### 需求 2：服务商切换
- ✅ 登出功能不再错误地影响 RTC 连接状态
- ✅ 支持独立的 RTC 和 RTM 操作

### 需求 4：用户角色和会话管理
- ✅ 登出只清理用户会话状态，不影响连接状态
- ✅ 提供了更精确的状态管理

### 需求 10：消息处理系统
- ✅ RTM 登出操作与 RTC 操作完全分离
- ✅ 消息系统的生命周期管理更加清晰

## 向后兼容性

所有原有的方法签名都保持不变，只是内部实现更加合理：

- `logoutUser()` - 行为更加精确，只处理 RTM 登出
- `leaveRoom()` - 行为保持一致，但逻辑更清晰
- 新增的方法提供了更多选择，不影响现有代码

## 测试建议

1. **单元测试**：
   - 测试 `logoutUser()` 不会影响 RTC 连接状态
   - 测试 `leaveRoom()` 正确更新连接状态
   - 测试各种组合场景

2. **集成测试**：
   - 测试在不同服务商下的行为一致性
   - 测试通知系统的正确触发

3. **用户场景测试**：
   - 测试用户只想登出消息系统的场景
   - 测试用户只想离开音视频房间的场景
   - 测试完全断开连接的场景

## 总结

这次修复解决了 RealtimeManager 登出功能中的职责混淆问题，使得：

1. **RTM 登出**只处理消息系统的注销
2. **RTC 断开**只处理音视频连接的断开
3. **状态管理**更加精确和一致
4. **API 设计**更符合单一职责原则
5. **用户体验**更加灵活，支持多种使用场景

修复后的代码更好地符合了需求文档的设计原则，提供了更清晰的职责分离和更灵活的使用方式。