# AgoraProviderFactory updateStreamPushLayout 修复总结

## 问题描述

`AgoraProviderFactory` 中的 `updateStreamPushLayout` 方法存在以下问题：

1. **未使用布局参数**：方法接收了 `StreamLayout` 参数但没有正确使用其属性
2. **硬编码画布尺寸**：使用了配置中的固定尺寸而不是布局指定的尺寸
3. **空的布局类型处理**：不同布局类型的 switch 语句都是空的
4. **占位符实现**：使用了占位符代码而不是实际的 Agora SDK 调用
5. **缺少用户区域配置**：没有处理用户区域的布局设置

## 修复内容

### 1. 完整实现 updateStreamPushLayout 方法

```swift
public func updateStreamPushLayout(layout: StreamLayout) async throws {
    guard streamPushActive else {
        let errorMessage = "Stream push not active"
        throw RealtimeError.streamPushFailed(reason: errorMessage)
    }
    
    guard let config = streamPushConfig else {
        throw RealtimeError.configurationError("Stream config not available")
    }
    
    // 验证布局配置
    try layout.validate()
    
    // 更新转码设置 - 使用布局指定的画布尺寸
    let transcoding = AgoraLiveTranscoding()
    transcoding.size = CGSize(width: layout.canvasWidth, height: layout.canvasHeight)
    transcoding.videoBitrate = config.videoConfig.bitrate
    transcoding.videoFramerate = config.videoConfig.frameRate
    transcoding.audioSampleRate = .type44100
    transcoding.audioBitrate = config.audioConfig.bitrate
    transcoding.audioChannels = config.audioConfig.channels
    
    // 配置用户区域
    var transcodingUsers: [AgoraLiveTranscodingUser] = []
    for userRegion in layout.userRegions {
        let transcodingUser = AgoraLiveTranscodingUser()
        transcodingUser.uid = UInt(userRegion.userId) ?? 0
        transcodingUser.rect = CGRect(
            x: userRegion.x,
            y: userRegion.y,
            width: userRegion.width,
            height: userRegion.height
        )
        transcodingUser.alpha = userRegion.alpha
        // Note: AgoraLiveTranscodingUser doesn't have renderMode property
        // The render mode is handled by the Agora SDK internally
        
        transcodingUsers.append(transcodingUser)
    }
    
    transcoding.transcodingUsers = transcodingUsers
    
    // 根据布局类型进行特殊配置
    switch layout.type {
    case .floating:
        break // 浮动布局：用户可以自由定位
    case .bestFit:
        configureBestFitLayout(transcoding: transcoding, layout: layout)
    case .vertical:
        configureVerticalLayout(transcoding: transcoding, layout: layout)
    case .custom:
        break // 自定义布局：使用用户提供的区域配置
    }
    
    // Note: AgoraLiveTranscoding doesn't have backgroundImage property
    // Background images would need to be handled differently in Agora SDK
    
    // 更新转码配置
    let result = agoraKit?.updateRtmpTranscoding(transcoding) ?? -1
    
    guard result == 0 else {
        throw RealtimeError.streamPushFailed(reason: "Failed to update stream layout: \(result)")
    }
    
    print("Agora: 更新推流布局成功 - 类型: \(layout.type.displayName), 画布: \(layout.canvasWidth)x\(layout.canvasHeight), 用户区域: \(layout.userRegions.count)")
}
```

### 2. 添加布局配置辅助方法

#### 最佳适配布局
```swift
private func configureBestFitLayout(transcoding: AgoraLiveTranscoding, layout: StreamLayout) {
    // 根据用户数量自动计算最佳网格布局
    let userCount = layout.userRegions.count
    guard userCount > 0, let transcodingUsers = transcoding.transcodingUsers else { return }
    
    let cols = Int(ceil(sqrt(Double(userCount))))
    let rows = Int(ceil(Double(userCount) / Double(cols)))
    
    let userWidth = layout.canvasWidth / cols
    let userHeight = layout.canvasHeight / rows
    
    // 更新转码用户位置
    for (index, transcodingUser) in transcodingUsers.enumerated() {
        let row = index / cols
        let col = index % cols
        
        transcodingUser.rect = CGRect(
            x: col * userWidth,
            y: row * userHeight,
            width: userWidth,
            height: userHeight
        )
    }
}
```

#### 垂直布局
```swift
private func configureVerticalLayout(transcoding: AgoraLiveTranscoding, layout: StreamLayout) {
    // 用户垂直排列
    let userCount = layout.userRegions.count
    guard userCount > 0, let transcodingUsers = transcoding.transcodingUsers else { return }
    
    let userHeight = layout.canvasHeight / userCount
    
    // 更新转码用户位置
    for (index, transcodingUser) in transcodingUsers.enumerated() {
        transcodingUser.rect = CGRect(
            x: 0,
            y: index * userHeight,
            width: layout.canvasWidth,
            height: userHeight
        )
    }
}
```

## 修复的关键改进

1. **正确使用布局参数**：
   - 使用 `layout.canvasWidth` 和 `layout.canvasHeight` 设置画布尺寸
   - 处理 `layout.userRegions` 配置用户区域
   - 注意：背景图片功能需要通过其他方式实现（Agora SDK 限制）

2. **完整的用户区域配置**：
   - 正确映射用户ID、位置、尺寸和透明度
   - 注意：渲染模式由 Agora SDK 内部处理（API 限制）

3. **布局类型特殊处理**：
   - 最佳适配布局：自动计算网格布局
   - 垂直布局：用户垂直排列
   - 浮动布局和自定义布局：使用用户提供的配置

4. **错误处理和验证**：
   - 调用 `layout.validate()` 验证布局配置
   - 检查推流状态和必要的依赖
   - 提供详细的错误信息

5. **实际的 Agora SDK 调用**：
   - 使用 `agoraKit?.updateRtmpTranscoding(transcoding)` 安全调用（正确的 API 方法名）
   - 检查返回结果并抛出适当的错误
   - 处理可选的 `transcodingUsers` 数组

## SDK 限制说明

在实际实现过程中发现了一些 Agora SDK 的限制：

1. **AgoraLiveTranscodingUser 没有 renderMode 属性**：渲染模式由 SDK 内部处理
2. **AgoraLiveTranscoding 没有 backgroundImage 属性**：背景图片需要通过其他方式实现
3. **transcodingUsers 是可选数组**：需要安全解包才能使用
4. **正确的 API 方法名**：应使用 `updateRtmpTranscoding` 而不是 `setLiveTranscoding`

## 测试验证

- ✅ 代码编译通过
- ✅ RealtimeAgora 目标构建成功
- ✅ RealtimeCore 目标构建成功
- ✅ 布局验证逻辑正常工作

## 影响范围

此修复影响以下功能：
- 推流布局更新功能
- 多用户画面组合
- 自定义布局支持
- 实时布局调整

## 兼容性

- 保持了原有的方法签名
- 向后兼容现有的调用方式
- 支持所有定义的布局类型
- 遵循现有的错误处理模式