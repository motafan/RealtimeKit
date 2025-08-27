# RealtimeManager 架构修复示例

## 🔧 修复前的问题

```swift
// ❌ 错误的实现 - 职责混乱
func loginUser() {
    // 创建用户会话
    // RTM登录 
    // RTC音频流控制 ← 这里不应该有RTC操作
}

func joinRoom() {
    // 仅处理RTC房间加入
    // 缺少RTM频道加入
}
```

## ✅ 修复后的正确架构

### 1. 用户登录流程
```swift
// 仅处理用户身份认证和消息系统登录
try await realtimeManager.loginUser(
    userId: "user123",
    userName: "张三", 
    userRole: .broadcaster
)
// ✅ 创建用户会话
// ✅ RTM系统登录（消息功能）
// ❌ 不再处理RTC音频流（职责分离）
```

### 2. 加入房间流程
```swift
// 处理音视频通话和消息频道加入
try await realtimeManager.joinRoom(roomId: "room456")
// ✅ RTC房间加入（音视频通话）
// ✅ 根据用户角色配置音频流
// ✅ RTM频道加入（消息通信）
```

### 3. 离开房间流程
```swift
try await realtimeManager.leaveRoom()
// ✅ RTC房间离开（音视频通话）
// ✅ RTM频道离开（消息通信）
// ✅ 清理房间状态
```

### 4. 用户登出流程
```swift
try await realtimeManager.logoutUser()
// ✅ RTM系统登出
// ✅ 清理用户会话
```

## 🎯 职责分离

| 组件 | 职责 | API示例 |
|------|------|---------|
| **RTM Provider** | 实时消息系统 | `login()`, `logout()`, `joinChannel()`, `sendMessage()` |
| **RTC Provider** | 音视频通话系统 | `joinRoom()`, `leaveRoom()`, `muteMicrophone()`, `resumeLocalAudioStream()` |
| **RealtimeManager** | 统一管理和协调 | `loginUser()`, `joinRoom()`, `leaveRoom()`, `logoutUser()` |

## 📱 完整使用示例

```swift
let manager = RealtimeManager.shared

// 1. 配置服务商
try await manager.configure(provider: .agora, config: config)

// 2. 用户登录（仅消息系统）
try await manager.loginUser(
    userId: "user123",
    userName: "张三",
    userRole: .broadcaster
)

// 3. 加入房间（音视频 + 消息）
try await manager.joinRoom(roomId: "room456")

// 4. 进行音视频通话和消息交流...

// 5. 离开房间
try await manager.leaveRoom()

// 6. 用户登出
try await manager.logoutUser()
```

## 🔍 架构优势

1. **职责清晰**: RTM负责消息，RTC负责音视频
2. **流程合理**: 登录→加入房间→离开房间→登出
3. **易于理解**: 每个方法的职责单一明确
4. **便于测试**: 可以独立测试RTM和RTC功能
5. **扩展性好**: 可以独立扩展消息或音视频功能