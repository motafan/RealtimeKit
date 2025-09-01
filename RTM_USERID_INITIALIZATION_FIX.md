# RTM UserId 初始化问题修复

## 问题描述

在之前的实现中，`agoraRTMInitialization` 方法使用了硬编码的 "uninitialized" 作为 userId，这不符合 Agora RTM SDK 的要求，因为 SDK 需要真实的用户 ID 来进行初始化。

## 问题根源

- Agora RTM SDK 在初始化时需要提供 userId 参数
- 我们的架构设计是 `initialize` 和 `login` 分离，userId 只在 `login` 时提供
- 这导致了架构设计与 SDK 要求的不匹配

## 解决方案

采用延迟初始化策略：

1. **修改 `initialize` 方法**：
   - 移除对 `agoraRTMInitialization` 的调用
   - 只保存配置信息，不实际初始化 RTM SDK
   - 将实际的 SDK 初始化延迟到 `login` 时

2. **修改 `agoraRTMInitialization` 方法**：
   - 添加 `userId` 参数
   - 使用真实的 userId 而不是硬编码值

3. **修改 `login` 方法**：
   - 在登录时检查 RTM SDK 是否已初始化
   - 如果未初始化，使用提供的 userId 进行初始化
   - 然后执行登录操作

## 代码更改

### 1. 更新 `agoraRTMInitialization` 方法签名

```swift
// 之前
private func agoraRTMInitialization(config: RTMConfig) async throws {
    let agoraRtmClientConfig = AgoraRtmClientConfig(appId: config.appId, userId: "uninitialized")
    agoraRtmKit = try AgoraRtmClientKit(agoraRtmClientConfig, delegate: self)
}

// 之后
private func agoraRTMInitialization(config: RTMConfig, userId: String) async throws {
    let agoraRtmClientConfig = AgoraRtmClientConfig(appId: config.appId, userId: userId)
    agoraRtmKit = try AgoraRtmClientKit(agoraRtmClientConfig, delegate: self)
}
```

### 2. 修改 `initialize` 方法

```swift
// 之前
public func initialize(config: RTMConfig) async throws {
    // ... 验证逻辑 ...
    self.config = config
    try await agoraRTMInitialization(config: config)
    isInitialized = true
}

// 之后
public func initialize(config: RTMConfig) async throws {
    // ... 验证逻辑 ...
    self.config = config
    // 延迟 RTM SDK 初始化到 login 时
    isInitialized = true
}
```

### 3. 修改 `login` 方法

```swift
// 之前
public func login(userId: String, token: String) async throws {
    // ... 验证逻辑 ...
    guard let agoraRtmKit else {
        throw RealtimeError.configurationError("Agora RTM Engine not initialized")
    }
    // ... 登录逻辑 ...
}

// 之后
public func login(userId: String, token: String) async throws {
    // ... 验证逻辑 ...
    
    // 如果 RTM SDK 还未初始化，现在进行初始化
    if agoraRtmKit == nil {
        try await agoraRTMInitialization(config: config, userId: userId)
    }
    
    guard let agoraRtmKit else {
        throw RealtimeError.configurationError("Agora RTM Engine initialization failed")
    }
    // ... 登录逻辑 ...
}
```

## 验证结果

- ✅ RealtimeAgora 目标编译成功
- ✅ 移除了硬编码的 "uninitialized" userId
- ✅ RTM SDK 现在使用真实的用户 ID 进行初始化
- ✅ 保持了现有的 API 接口不变

## 影响分析

- **向后兼容性**：完全兼容，API 接口没有变化
- **性能影响**：最小，只是将初始化时机从 `initialize` 延迟到 `login`
- **功能完整性**：增强，现在使用正确的 userId 进行初始化

## 相关文件

- `Sources/RealtimeAgora/RealtimeAgora.swift` - 主要修改文件

## 测试状态

- RealtimeAgora 目标编译通过
- 需要进一步的集成测试来验证运行时行为