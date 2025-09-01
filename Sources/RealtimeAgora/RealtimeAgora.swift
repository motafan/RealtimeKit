import Foundation
import RealtimeCore

#if os(iOS)
@preconcurrency import AgoraRtcKit
@preconcurrency import AgoraRtmKit

/// 执行 Agora 异步操作的通用包装器
///
/// 提供统一的错误处理、日志记录和重试机制，用于包装 Agora SDK 的异步操作。
/// 
/// 功能特性：
/// - 统一错误处理和转换
/// - 结构化日志记录
/// - 操作超时控制
/// - 自动重试机制（可选）
/// - 性能监控
///
/// - Parameters:
///   - operation: 要执行的异步操作闭包
///   - operationName: 操作名称，用于日志记录和错误追踪
///   - timeout: 操作超时时间（秒），默认 30 秒
///   - retryCount: 重试次数，默认 0（不重试）
/// - Returns: Agora 通用响应对象
/// - Throws: RealtimeError 类型的错误
@discardableResult
func executeAgoraOperation(
    _ operation: @escaping @Sendable () async throws -> (response: AgoraRtmCommonResponse?, error: AgoraRtmErrorInfo?),
    operationName: String = "Unknown",
    timeout: TimeInterval = 30.0,
    retryCount: Int = 0
) async throws -> AgoraRtmCommonResponse {
    let startTime = CFAbsoluteTimeGetCurrent()
    var lastError: Error?
    
    // 重试循环
    for attempt in 0...retryCount {
        do {
            // 执行带超时的操作
            let result = try await withTimeout(timeout) {
                try await operation()
            }
            
            let (response, error) = result
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // 处理错误响应
            if let error = error {
                let agoraError = RealtimeError.internalError(
                    code: error.errorCode.rawValue,
                    description: error.reason
                )
                
                // 记录结构化错误日志
                logAgoraOperation(
                    name: operationName,
                    success: false,
                    executionTime: executionTime,
                    attempt: attempt + 1,
                    error: agoraError
                )
                
                // 判断是否应该重试
                if attempt < retryCount && shouldRetryError(error.errorCode) {
                    lastError = agoraError
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)) // 指数退避
                    continue
                }
                
                throw agoraError
            }
            
            // 处理成功响应
            guard let response = response else {
                let unknownError = RealtimeError.unknown(
                    reason: "Operation '\(operationName)' completed without response or error"
                )
                
                logAgoraOperation(
                    name: operationName,
                    success: false,
                    executionTime: executionTime,
                    attempt: attempt + 1,
                    error: unknownError
                )
                
                throw unknownError
            }
            
            // 记录成功日志
            logAgoraOperation(
                name: operationName,
                success: true,
                executionTime: executionTime,
                attempt: attempt + 1
            )
            
            return response
            
        } catch is CancellationError {
            let timeoutError = RealtimeError.operationTimeout(operation: operationName)
            logAgoraOperation(
                name: operationName,
                success: false,
                executionTime: CFAbsoluteTimeGetCurrent() - startTime,
                attempt: attempt + 1,
                error: timeoutError
            )
            throw timeoutError
            
        } catch let error as RealtimeError {
            // 已经是 RealtimeError，直接重新抛出
            lastError = error
            if attempt < retryCount && shouldRetryRealtimeError(error) {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                continue
            }
            throw error
            
        } catch {
            // 其他未知错误
            let wrappedError = RealtimeError.unknown(reason: "Unexpected error in '\(operationName)': \(error.localizedDescription)")
            lastError = wrappedError
            
            logAgoraOperation(
                name: operationName,
                success: false,
                executionTime: CFAbsoluteTimeGetCurrent() - startTime,
                attempt: attempt + 1,
                error: wrappedError
            )
            
            if attempt < retryCount {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                continue
            }
            
            throw wrappedError
        }
    }
    
    // 如果所有重试都失败了，抛出最后一个错误
    throw lastError ?? RealtimeError.unknown(reason: "All retry attempts failed for operation '\(operationName)'")
}

// MARK: - Helper Functions

/// 带超时的异步操作执行器
private func withTimeout<T: Sendable>(
    _ timeout: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // 添加主操作任务
        group.addTask {
            try await operation()
        }
        
        // 添加超时任务
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw CancellationError()
        }
        
        // 等待第一个完成的任务
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

/// 判断 Agora 错误是否应该重试
private func shouldRetryError(_ errorCode: AgoraRtmErrorCode) -> Bool {
    // 基于错误代码的数值范围进行判断，而不是具体的枚举值
    let code = errorCode.rawValue
    
    // 网络相关错误 (通常可重试)
    if code == -10001 || // 网络不可用
       code == -10002 || // 连接失败
       code == -10003 || // 超时
       code == -10025 || // 未连接
       code == -10026 {  // 连接中断
        return true
    }
    
    // 认证相关错误 (不应重试，需要用户干预)
    if code == -10004 || // 无效token
       code == -10005 || // token过期
       code == -10006 {  // 认证失败
        return false
    }
    
    // 状态相关错误 (不应重试)
    if code == -10007 || // 未登录
       code == -10008 || // 未加入频道
       code == -10009 {  // 重复操作
        return false
    }
    
    // 其他错误默认不重试
    return false
}

/// 判断 RealtimeError 是否应该重试
private func shouldRetryRealtimeError(_ error: RealtimeError) -> Bool {
    switch error {
    case .connectionError, .operationTimeout:
        return true
    case .invalidToken, .configurationError:
        return false
    default:
        return false
    }
}

/// 记录 Agora 操作的结构化日志
private func logAgoraOperation(
    name: String,
    success: Bool,
    executionTime: TimeInterval,
    attempt: Int,
    error: Error? = nil
) {
    let status = success ? "SUCCESS" : "FAILED"
    let timeString = String(format: "%.3f", executionTime * 1000) // 转换为毫秒
    let attemptInfo = attempt > 1 ? " (attempt \(attempt))" : ""
    
    if success {
        print("[Agora] \(status): \(name) completed in \(timeString)ms\(attemptInfo)")
    } else {
        let errorInfo = error?.localizedDescription ?? "Unknown error"
        print("[Agora] \(status): \(name) failed in \(timeString)ms\(attemptInfo) - \(errorInfo)")
    }
}

// MARK: - Backward Compatibility & Convenience Methods

/// 简化版本的 Agora 操作执行器（向后兼容）
///
/// 为简单操作提供便捷接口，使用默认配置
/// - Parameter operation: 要执行的异步操作闭包
/// - Returns: Agora 通用响应对象
/// - Throws: RealtimeError 类型的错误
@discardableResult
func performAgoraOperation(
    _ operation: @escaping @Sendable () async throws -> (response: AgoraRtmCommonResponse?, error: AgoraRtmErrorInfo?)
) async throws -> AgoraRtmCommonResponse {
    try await executeAgoraOperation(
        operation,
        operationName: "Agora Operation",
        timeout: 30.0,
        retryCount: 0
    )
}
#else
// macOS stub - Agora SDK not available
#endif


/// RealtimeAgora 模块
/// 提供声网 Agora SDK 的集成实现
/// 需求: 2.1, 1.1, 1.2, 17.1

#if os(iOS)

// MARK: - Agora Provider Factory

/// Agora 服务商工厂
/// 需求: 2.1, 1.1, 1.2
public class AgoraProviderFactory: NSObject, ProviderFactory {

    /// Agora 特定配置选项
    public struct AgoraConfiguration: Sendable {
        public let enableCloudProxy: Bool
        public let enableAudioVolumeIndication: Bool
        public let enableLocalizedErrors: Bool
        public let logLevel: AgoraLogLevel
        public let region: AgoraRegion
        
        public init(
            enableCloudProxy: Bool = false,
            enableAudioVolumeIndication: Bool = true,
            enableLocalizedErrors: Bool = true,
            logLevel: AgoraLogLevel = .info,
            region: AgoraRegion = .global
        ) {
            self.enableCloudProxy = enableCloudProxy
            self.enableAudioVolumeIndication = enableAudioVolumeIndication
            self.enableLocalizedErrors = enableLocalizedErrors
            self.logLevel = logLevel
            self.region = region
        }
        
        public static let `default` = AgoraConfiguration()
    }
    
    public let configuration: AgoraConfiguration
    
    public init(configuration: AgoraConfiguration = .default) {
        self.configuration = configuration
    }
    
    public func createRTCProvider() -> RTCProvider {
        return AgoraRTCProvider(configuration: configuration)
    }
    
    public func createRTMProvider() -> RTMProvider {
        return AgoraRTMProvider(configuration: configuration)
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return [
            .audioStreaming,
            .videoStreaming,
            .streamPush,
            .mediaRelay,
            .volumeIndicator,
            .messageProcessing
        ]
    }
}

// MARK: - Agora Configuration Types

/// Agora 日志级别
public enum AgoraLogLevel: String, CaseIterable, Codable, Sendable {
    case none = "none"
    case info = "info"
    case warn = "warn"
    case error = "error"
    case fatal = "fatal"
    
    public var displayName: String {
        switch self {
        case .none: return "无日志"
        case .info: return "信息"
        case .warn: return "警告"
        case .error: return "错误"
        case .fatal: return "致命错误"
        }
    }
    
    public var agoraLogLevel: AgoraLogFilter {
        switch self {
        case .none: return .off
        case .info: return .info
        case .warn: return .error  // Agora doesn't have .warn, use .error
        case .error: return .error
        case .fatal: return .error  // Agora doesn't have .fatal, use .error
        }
    }
}

/// Agora 区域设置
public enum AgoraRegion: String, CaseIterable, Codable, Sendable {
    case global = "global"
    case china = "china"
    case northAmerica = "north_america"
    case europe = "europe"
    case asia = "asia"
    
    public var displayName: String {
        switch self {
        case .global: return "全球"
        case .china: return "中国"
        case .northAmerica: return "北美"
        case .europe: return "欧洲"
        case .asia: return "亚洲"
        }
    }
}

// MARK: - Agora RTC Provider

/// Agora RTC 提供者实现
/// 需求: 2.1, 1.1, 1.2, 17.1
public class AgoraRTCProvider: NSObject, RTCProvider, @unchecked Sendable {

    // MARK: - Properties
    
    private var config: RTCConfig?
    private var currentRoom: RTCRoom?
    private var isMuted: Bool = false
    private var isLocalAudioActive: Bool = true
    private var volumeHandler: (@Sendable ([UserVolumeInfo]) -> Void)?
    private var volumeEventHandler: (@Sendable (VolumeEvent) -> Void)?
    private var tokenExpirationHandler: ((Int) -> Void)?
    
    // 音量控制
    private var audioMixingVolume: Int = 100
    private var playbackSignalVolume: Int = 100
    private var recordingSignalVolume: Int = 100
    
    // 音量指示器状态
    private var volumeIndicatorEnabled: Bool = false
    private var volumeDetectionConfig: VolumeDetectionConfig?
    
    // 推流和媒体中继状态
    private var streamPushActive: Bool = false
    private var streamPushConfig: StreamPushConfig?
    private var mediaRelayActive: Bool = false
    private var mediaRelayChannels: Set<String> = []


    private var agoraKit: AgoraRtcEngineKit?

    // Agora 配置
    private let configuration: AgoraProviderFactory.AgoraConfiguration

    // 音量检测状态跟踪
    private var previousSpeakingUsers: Set<String> = []
    
    // 连接状态
    private var isInitialized: Bool = false
    private var isConnected: Bool = false
    
    // MARK: - Initialization
    
    internal init(configuration: AgoraProviderFactory.AgoraConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }
    
    deinit {
        // 清理 Agora RTC Engine 资源
        agoraKit?.leaveChannel()
        AgoraRtcEngineKit.destroy()
    }
    
    // MARK: - RTCProvider Implementation
    
    public func initialize(config: RTCConfig) async throws {
        guard !config.appId.isEmpty else {
            let errorMessage =
                "Invalid Agora App ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        self.config = config
        
        // Agora SDK 初始化过程
        try await agoraInitialization(config: config)

        isInitialized = true
        print("Agora RTC Provider 初始化完成 - App ID: \(config.appId)")
    }
    
    public func createRoom(roomId: String) async throws -> RTCRoom {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !roomId.isEmpty else {
            let errorMessage =
                "Invalid room ID"
            throw RealtimeError.configurationError(errorMessage)
        }

        // 模拟 Agora 房间创建延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        let room = AgoraRTCRoom(roomId: roomId)
        currentRoom = room
        
        print("Agora: 创建房间 \(roomId)")
        return room
    }
    
    public func joinRoom(roomId: String, userId: String, userRole: UserRole, token: String?) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !roomId.isEmpty && !userId.isEmpty else {
            let errorMessage =
                "Invalid room ID or user ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 如果房间不存在，创建房间
        if currentRoom == nil {
            currentRoom = AgoraRTCRoom(roomId: roomId)
        }
        
        // Agora 加入房间过程
        try await agoraJoinRoom(roomId: roomId, userId: userId, userRole: userRole, token: token)
        
        isConnected = true
        print("Agora: 用户 \(userId) 以 \(userRole.displayName) 身份加入房间 \(roomId)")
    }
    
    public func leaveRoom() async throws {
        guard currentRoom != nil else {
            throw RealtimeError.noActiveSession
        }
                
        // Agora 离开房间过程
        try await agoraLeaveRoom()

        isConnected = false
        currentRoom = nil
        
        print("Agora: 离开房间")
    }
    
    public func switchUserRole(_ role: UserRole) async throws {
        guard isConnected else {
            let errorMessage =
                "Not connected to room"
            throw RealtimeError.connectionError(errorMessage)
        }
        
        // Agora 角色切换过程
        try await agoraRoleSwitch(role: role)

        print("Agora: 切换用户角色到 \(role.displayName)")
        
        // 根据角色调整音频权限
        if role.hasAudioPermission {
            try await resumeLocalAudioStream()
        } else {
            try await stopLocalAudioStream()
        }
    }
    
    // MARK: - Audio Stream Control
    
    public func muteMicrophone(_ muted: Bool) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        isMuted = muted
        let statusText = muted ? "静音" : "取消静音"
        
        print("Agora: 麦克风\(statusText)")
        
        // Agora SDK 的麦克风控制方法
        agoraKit.muteLocalAudioStream(muted)
    }
    
    public func isMicrophoneMuted() -> Bool {
        return isMuted
    }
    
    public func stopLocalAudioStream() async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        // Agora SDK 的音频流控制方法
         agoraKit.enableLocalAudio(false)

        isLocalAudioActive = false
        print("Agora: 停止本地音频流")

    }
    
    public func resumeLocalAudioStream() async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        isLocalAudioActive = true
        print("Agora: 恢复本地音频流")
        
        // Agora SDK 的音频流控制方法
         agoraKit.enableLocalAudio(true)
    }
    
    public func isLocalAudioStreamActive() -> Bool {
        return isLocalAudioActive
    }
    
    // MARK: - Volume Control
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        let validatedVolume = AudioSettings.validateVolume(volume)
        

        
        audioMixingVolume = validatedVolume
        print("Agora: 设置混音音量为 \(audioMixingVolume)")
        
        // 调用 Agora SDK 的音量控制方法
        agoraKit.adjustAudioMixingVolume(validatedVolume)
    }
    
    public func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        let validatedVolume = AudioSettings.validateVolume(volume)
        
        // 调用 Agora SDK 的音量控制方法
        agoraKit.adjustPlaybackSignalVolume(validatedVolume)

        playbackSignalVolume = validatedVolume
        print("Agora: 设置播放音量为 \(playbackSignalVolume)")
    }
    
    public func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        let validatedVolume = AudioSettings.validateVolume(volume)
        
        // 模拟 Agora 音量设置延迟
        try await Task.sleep(nanoseconds: 30_000_000) // 0.03秒
        
        recordingSignalVolume = validatedVolume
        print("Agora: 设置录音音量为 \(recordingSignalVolume)")
        
        // 调用 Agora SDK 的音量控制方法
        agoraKit.adjustRecordingSignalVolume(validatedVolume)
    }
    
    public func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    // MARK: - Stream Push
    
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard isConnected else {
            let errorMessage =
                "Not connected to room"
            throw RealtimeError.connectionError(errorMessage)
        }
        
        guard !config.url.isEmpty else {
            let errorMessage =
                "Invalid stream URL"
            throw RealtimeError.streamPushFailed(reason: errorMessage)
        }
        
        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }
        
        // 配置转码设置
        let transcoding = AgoraLiveTranscoding()
        transcoding.size = CGSize(width: config.videoConfig.width, height: config.videoConfig.height)
        transcoding.videoBitrate = config.videoConfig.bitrate
        transcoding.videoFramerate = config.videoConfig.frameRate
        transcoding.audioSampleRate = .type44100
        transcoding.audioBitrate = config.audioConfig.bitrate
        transcoding.audioChannels = config.audioConfig.channels
        
        // 开始推流
        let result = agoraKit.startRtmpStream(withTranscoding: config.url, transcoding: transcoding)
        
        guard result == 0 else {
            throw RealtimeError.streamPushFailed(reason: "Failed to start stream push: \(result)")
        }
        
        streamPushActive = true
        streamPushConfig = config
        
        print("Agora: 开始推流到 \(config.url)")
    }
    
    public func stopStreamPush() async throws {
        guard streamPushActive else {
            let errorMessage =
                "Stream push not active"
            throw RealtimeError.streamPushFailed(reason: errorMessage)
        }
        
        guard let agoraKit, let config = streamPushConfig else {
            throw RealtimeError.configurationError("Agora RTC Engine or stream config not available")
        }
        
        let result = agoraKit.stopRtmpStream(config.url)
        
        guard result == 0 else {
            throw RealtimeError.streamPushFailed(reason: "Failed to stop stream push: \(result)")
        }
        
        streamPushActive = false
        streamPushConfig = nil
        
        print("Agora: 停止推流")
    }
    
    public func updateStreamPushLayout(layout: StreamLayout) async throws {
        guard streamPushActive else {
            let errorMessage =
                "Stream push not active"
            throw RealtimeError.streamPushFailed(reason: errorMessage)
        }
        
        guard let config = streamPushConfig else {
            throw RealtimeError.configurationError("Stream config not available")
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        // 验证布局配置
        try layout.validate()
        
        // 更新转码设置
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
            // 浮动布局：用户可以自由定位
            break
        case .bestFit:
            // 最佳适配布局：自动调整用户区域以最佳适配画布
            configureBestFitLayout(transcoding: transcoding, layout: layout)
        case .vertical:
            // 垂直布局：用户垂直排列
            configureVerticalLayout(transcoding: transcoding, layout: layout)
        case .custom:
            // 自定义布局：使用用户提供的区域配置
            break
        }
        
        // Note: AgoraLiveTranscoding doesn't have backgroundImage property
        // Background images would need to be handled differently in Agora SDK
        
        // 更新转码配置 - 使用正确的方法名
        let result = agoraKit.updateRtmpTranscoding(transcoding)
        
        guard result == 0 else {
            throw RealtimeError.streamPushFailed(reason: "Failed to update stream layout: \(result)")
        }
        
        print("Agora: 更新推流布局成功 - 类型: \(layout.type.displayName), 画布: \(layout.canvasWidth)x\(layout.canvasHeight), 用户区域: \(layout.userRegions.count)")
    }
    
    // MARK: - Layout Configuration Helpers
    
    private func configureBestFitLayout(transcoding: AgoraLiveTranscoding, layout: StreamLayout) {
        // 最佳适配布局：根据用户数量自动计算最佳布局
        let userCount = layout.userRegions.count
        guard userCount > 0, let transcodingUsers = transcoding.transcodingUsers else { return }
        
        let canvasWidth = layout.canvasWidth
        let canvasHeight = layout.canvasHeight
        
        // 计算网格布局
        let cols = Int(ceil(sqrt(Double(userCount))))
        let rows = Int(ceil(Double(userCount) / Double(cols)))
        
        let userWidth = canvasWidth / cols
        let userHeight = canvasHeight / rows
        
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
    
    private func configureVerticalLayout(transcoding: AgoraLiveTranscoding, layout: StreamLayout) {
        // 垂直布局：用户垂直排列
        let userCount = layout.userRegions.count
        guard userCount > 0, let transcodingUsers = transcoding.transcodingUsers else { return }
        
        let canvasWidth = layout.canvasWidth
        let canvasHeight = layout.canvasHeight
        let userHeight = canvasHeight / userCount
        
        // 更新转码用户位置
        for (index, transcodingUser) in transcodingUsers.enumerated() {
            transcodingUser.rect = CGRect(
                x: 0,
                y: index * userHeight,
                width: canvasWidth,
                height: userHeight
            )
        }
    }
    
    // MARK: - Media Relay
    
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        guard isConnected else {
            let errorMessage =
                "Not connected to room"
            throw RealtimeError.connectionError(errorMessage)
        }

        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        guard !config.destinationChannels.isEmpty else {
            let errorMessage =
                "No destination channels specified"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }

        // 配置媒体中继
        let relayConfiguration = AgoraChannelMediaRelayConfiguration()
        
        // 设置源频道信息
        let sourceInfo = AgoraChannelMediaRelayInfo(token: config.sourceChannel.token)
        sourceInfo.channelName = config.sourceChannel.channelName
        relayConfiguration.sourceInfo = sourceInfo
        
        // 设置目标频道信息
        let destinationChannel = config.destinationChannels.first!
        let destinationInfo = AgoraChannelMediaRelayInfo(token: destinationChannel.token)
        relayConfiguration.setDestinationInfo(destinationInfo, forChannelName: destinationChannel.channelName)

        let result = agoraKit.startOrUpdateChannelMediaRelay(relayConfiguration)
        
        guard result == 0 else {
            throw RealtimeError.mediaRelayFailed(reason: "Failed to start media relay: \(result)")
        }
        
        mediaRelayActive = true
        mediaRelayChannels = Set(config.destinationChannels.map { $0.channelName })
        
        print("Agora: 开始媒体中继到 \(mediaRelayChannels.count) 个频道")
    }
    
    public func stopMediaRelay() async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }

        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        let result = agoraKit.stopChannelMediaRelay()
        
        guard result == 0 else {
            throw RealtimeError.mediaRelayFailed(reason: "Failed to stop media relay: \(result)")
        }
        
        mediaRelayActive = false
        mediaRelayChannels.removeAll()
        
        print("Agora: 停止媒体中继")
    }
    
    public func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }

        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        // 重新配置媒体中继
        let relayConfiguration = AgoraChannelMediaRelayConfiguration()
        
        // 设置源频道信息
        let sourceInfo = AgoraChannelMediaRelayInfo(token: config.sourceChannel.token)
        sourceInfo.channelName = config.sourceChannel.channelName
        sourceInfo.uid = 0
        relayConfiguration.sourceInfo = sourceInfo
        
        // 设置新的目标频道信息
        for destinationChannel in config.destinationChannels {
            let destinationInfo = AgoraChannelMediaRelayInfo(token: destinationChannel.token)
            destinationInfo.uid = 0
            relayConfiguration.setDestinationInfo(destinationInfo, forChannelName: destinationChannel.channelName)
        }
        
        let result = agoraKit.startOrUpdateChannelMediaRelay(relayConfiguration)
        
        guard result == 0 else {
            throw RealtimeError.mediaRelayFailed(reason: "Failed to update media relay: \(result)")
        }
        
        mediaRelayChannels = Set(config.destinationChannels.map { $0.channelName })
        
        print("Agora: 更新媒体中继频道到 \(mediaRelayChannels.count) 个频道")
    }
    
    public func pauseMediaRelay(toChannel: String) async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }

        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        guard mediaRelayChannels.contains(toChannel) else {
            let errorMessage =
                "Channel not found in relay"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        let result = agoraKit.pauseAllChannelMediaRelay()
        
        guard result == 0 else {
            throw RealtimeError.mediaRelayFailed(reason: "Failed to pause media relay: \(result)")
        }

        print("Agora: 暂停到频道 \(toChannel) 的媒体中继")
    }
    
    public func resumeMediaRelay(toChannel: String) async throws {
        guard mediaRelayActive else {
            let errorMessage =
                "Media relay not active"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }

        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        guard mediaRelayChannels.contains(toChannel) else {
            let errorMessage =
                "Channel not found in relay"
            throw RealtimeError.mediaRelayFailed(reason: errorMessage)
        }
        
        let result = agoraKit.resumeAllChannelMediaRelay()
        
        guard result == 0 else {
            throw RealtimeError.mediaRelayFailed(reason: "Failed to resume media relay: \(result)")
        }

        print("Agora: 恢复到频道 \(toChannel) 的媒体中继")
    }
    
    // MARK: - Volume Indicator
    
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        guard config.isValid else {
            throw RealtimeError.volumeDetectionFailed
        }
        
        volumeIndicatorEnabled = true
        volumeDetectionConfig = config
        
        print("Agora: 启用音量指示器，间隔 \(config.detectionInterval)ms")
        
        // 调用 Agora SDK 的音量指示器方法
        agoraKit.enableAudioVolumeIndication(config.detectionInterval, smooth: Int(config.smoothFactor), reportVad: true)
    }
    
    public func disableVolumeIndicator() async throws {
        guard volumeIndicatorEnabled else {
            throw RealtimeError.volumeDetectionFailed
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        volumeIndicatorEnabled = false
        volumeDetectionConfig = nil
        previousSpeakingUsers.removeAll()
        
        print("Agora: 禁用音量指示器")
        
        // 调用 Agora SDK 的禁用音量指示器方法
        agoraKit.enableAudioVolumeIndication(0, smooth: 3, reportVad: false)
    }
    
    public func setVolumeIndicatorHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void) {
        volumeHandler = handler
    }
    
    public func setVolumeEventHandler(_ handler: @escaping @Sendable (VolumeEvent) -> Void) {
        volumeEventHandler = handler
    }
    
    public func getCurrentVolumeInfos() -> [UserVolumeInfo] {
        // 在真实实现中，这里应该返回最近一次从 Agora SDK 获取的音量信息
        // 由于音量信息是通过回调异步获取的，这里返回空数组
        return []
    }
    
    public func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        // 在真实实现中，这里应该从缓存的音量信息中查找特定用户的数据
        // 由于音量信息是通过回调异步获取的，这里返回 nil
        return nil
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTC Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraKit else {
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        guard !newToken.isEmpty else {
            throw RealtimeError.invalidToken
        }
        
        // 模拟 Agora Token 更新延迟
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        print("Agora: 更新 Token")
        
        // 调用 Agora SDK 的 Token 更新方法
        agoraKit.renewToken(newToken)
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {
        tokenExpirationHandler = handler

        print("Agora RTC: Token 过期处理器已设置")
        // 设置 Agora SDK 的 Token 过期回调
        // 例如: 在 AgoraRtcEngineDelegate 中实现 rtcEngine(_:tokenPrivilegeWillExpire:)
    }
    
    // MARK: - Private Methods

    /// Agora SDK 初始化
    private func agoraInitialization(config: RTCConfig) async throws {
        let agoraConfig = AgoraRtcEngineConfig()
        agoraConfig.appId = config.appId
        agoraConfig.areaCode = .global
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: agoraConfig, delegate: self)
        
        // 配置音频设置
        agoraKit?.setAudioProfile(.default)
        agoraKit?.setAudioScenario(.gameStreaming)
        agoraKit?.enableAudio()
        
        // 根据配置启用音量指示器
        if configuration.enableAudioVolumeIndication {
            agoraKit?.enableAudioVolumeIndication(300, smooth: 3, reportVad: true)
        }
        
        // 设置日志级别
        agoraKit?.setLogFilter(configuration.logLevel.agoraLogLevel.rawValue)
    }
    
    private func agoraJoinRoom(roomId: String, userId: String, userRole: UserRole, token: String?) async throws {
        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        // 设置用户角色
        let clientRole: AgoraClientRole = userRole == .audience ? .audience : .broadcaster
        agoraKit.setClientRole(clientRole)

        guard let uid = UInt(userId) else {
            throw RealtimeError.configurationError("Failed to generate a valid user ID")
        }

        // 加入频道，使用提供的token
        let result = agoraKit.joinChannel(
            byToken: token,
            channelId: roomId,
            info: nil,
            uid: uid
        )
        
        guard result == 0 else {
            throw RealtimeError.connectionError("Failed to join channel: \(result)")
        }
    }

    /// Agora SDK 的离开频道方法
    private func agoraLeaveRoom() async throws {
        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }

        let result = agoraKit.leaveChannel()
        
        guard result == 0 else {
            throw RealtimeError.connectionError("Failed to leave channel: \(result)")
        }
    }

    /// Agora SDK 的角色切换方法
    private func agoraRoleSwitch(role: UserRole) async throws {
        guard let agoraKit else { 
            throw RealtimeError.configurationError("Agora RTC Engine not initialized")
        }
        
        let clientRole: AgoraClientRole = role == .audience ? .audience : .broadcaster
        let result = agoraKit.setClientRole(clientRole)
        
        guard result == 0 else {
            throw RealtimeError.configurationError("Failed to switch role: \(result)")
        }
    }
}

extension AgoraRTCProvider: AgoraRtcEngineDelegate {

    public func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        tokenExpirationHandler?(5 * 60)
    }

    public func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        guard volumeIndicatorEnabled else { return }
        
        let volumeInfos = speakers.map { speaker in
            let userId = speaker.uid == 0 ? "local_user" : String(speaker.uid)
            let threshold = volumeDetectionConfig?.speakingThreshold ?? 0.3
            let isSpeaking = Float(speaker.volume) / 255.0 > threshold
            
            return UserVolumeInfo(
                userId: userId,
                volume: Int(speaker.volume),
                vad: isSpeaking ? .speaking : .notSpeaking,
                timestamp: Date()
            )
        }
        
        // 调用音量处理器
        volumeHandler?(volumeInfos)
        
        // 检测说话状态变化
        let currentSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        
        // 检测开始说话的用户
        let startedSpeaking = currentSpeakingUsers.subtracting(previousSpeakingUsers)
        for userId in startedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                volumeEventHandler?(.userStartedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
            }
        }
        
        // 检测停止说话的用户
        let stoppedSpeaking = previousSpeakingUsers.subtracting(currentSpeakingUsers)
        for userId in stoppedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                volumeEventHandler?(.userStoppedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
            }
        }
        
        // 检测主讲人变化
        let dominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
        volumeEventHandler?(.dominantSpeakerChanged(userId: dominantSpeaker))
        
        volumeEventHandler?(.volumeUpdate(volumeInfos))
        
        previousSpeakingUsers = currentSpeakingUsers
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("Agora RTC: 成功加入频道 \(channel)，用户ID: \(uid)")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        print("Agora RTC: 离开频道，通话时长: \(stats.duration)秒")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("Agora RTC: 发生错误 - \(errorCode.rawValue)")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        print("Agora RTC: 连接状态变化 - 状态: \(state.rawValue), 原因: \(reason.rawValue)")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, rtmpStreamingChangedToState url: String, state: AgoraRtmpStreamingState, reason: AgoraRtmpStreamingReason) {
        print("Agora RTC: RTMP 推流状态变化 - URL: \(url), 状态: \(state.rawValue), 原因: \(reason.rawValue)")
        
        if state == .failure {
            streamPushActive = false
            streamPushConfig = nil
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, channelMediaRelayStateDidChange state: AgoraChannelMediaRelayState, error: AgoraChannelMediaRelayError) {
        print("Agora RTC: 媒体中继状态变化 - 状态: \(state.rawValue)")
        
        if state == .failure {
            mediaRelayActive = false
            mediaRelayChannels.removeAll()
        }
    }
}

// MARK: - Agora RTM Provider

/// Agora RTM 提供者实现
/// 需求: 2.1, 1.1, 1.2, 17.1
public class AgoraRTMProvider: NSObject, RTMProvider {

    // MARK: - Properties
    
    private var config: RTMConfig?
    private var _isLoggedIn: Bool = false
    private var joinedChannels: Set<String> = []
    private var userAttributes: [String: String] = [:]
    private var channelAttributes: [String: [String: String]] = [:]
    private var subscribedUsers: Set<String> = []
    
    // 事件处理器
    private var connectionStateHandler: ((RTMConnectionState, RTMConnectionChangeReason) -> Void)?
    private var peerMessageHandler: ((RTMMessage, String) -> Void)?
    private var channelMessageHandler: ((RTMMessage, RTMChannelMember, String) -> Void)?
    private var peersOnlineStatusHandler: (([String: Bool]) -> Void)?
    private var tokenExpirationHandler: (() -> Void)?
    
    // Agora 配置
    private let configuration: AgoraProviderFactory.AgoraConfiguration
    

    
    // 连接状态
    private var isInitialized: Bool = false

    private var agoraRtmKit: AgoraRtmClientKit?

    // MARK: - Initialization
    
    internal init(configuration: AgoraProviderFactory.AgoraConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }
    
    deinit {
        // 清理 Agora RTM 资源
        // Note: Cannot use async operations in deinit
        // Resources will be cleaned up automatically
    }
    
    // MARK: - RTMProvider Implementation
    
    public func initialize(config: RTMConfig) async throws {
        guard !config.appId.isEmpty else {
            let errorMessage =
                "Invalid Agora App ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        self.config = config
        
        // 延迟 RTM SDK 初始化到 login 时，因为 Agora RTM SDK 需要 userId
        // RTM SDK 将在 login 方法中完成初始化
        
        isInitialized = true
        print("Agora RTM Provider 配置完成 - App ID: \(config.appId)")
    }

    public func login(userId: String, token: String) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let config = self.config else {
            throw RealtimeError.configurationError("RTM configuration not available")
        }

        guard !userId.isEmpty else {
            let errorMessage =
                "Invalid user ID"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 如果 RTM SDK 还未初始化，现在进行初始化
        if agoraRtmKit == nil {
            try await agoraRTMInitialization(config: config, userId: userId)
        }
        
        guard let agoraRtmKit else {
            throw RealtimeError.configurationError("Agora RTM Engine initialization failed")
        }
        
        // 调用 Agora RTM SDK 的登录方法
        try await executeAgoraOperation(
            { await agoraRtmKit.login(token) },
            operationName: "RTM Login",
            timeout: 15.0,
            retryCount: 2
        )
        
        _isLoggedIn = true
        print("Agora RTM: 用户 \(userId) 登录")
        
        connectionStateHandler?(.connected, .loginSuccess)
    }
    
    public func logout() async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 调用 Agora RTM SDK 的登出方法
        try await agoraRTMLogout()

        _isLoggedIn = false
        joinedChannels.removeAll()
        userAttributes.removeAll()
        subscribedUsers.removeAll()
        
        print("Agora RTM: 用户登出")
        connectionStateHandler?(.disconnected, .logout)
    }
    
    public func isLoggedIn() -> Bool {
        return _isLoggedIn
    }
    
    // MARK: - Channel Management
    
    public func createChannel(channelId: String) -> RTMChannel {
        return AgoraRTMChannel(channelId: channelId)
    }
    
    public func joinChannel(channelId: String) async throws {

        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraRtmKit else {
            throw RealtimeError.configurationError("Agora RTM Engine not initialized")
        }

        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        guard !channelId.isEmpty else {
            let errorMessage =
                "Invalid channel ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 调用 Agora RTM SDK 的加入频道方法
        try await executeAgoraOperation(
            { await agoraRtmKit.subscribe(channelName: channelId, option: nil) },
            operationName: "RTM Subscribe Channel",
            timeout: 10.0,
            retryCount: 1
        )
        
        joinedChannels.insert(channelId)
        
        print("Agora RTM: 加入频道 \(channelId)")
    }
    
    public func leaveChannel(channelId: String) async throws {

        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraRtmKit else {
            throw RealtimeError.configurationError("Agora RTM Engine not initialized")
        }

        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 调用 Agora RTM SDK 的离开频道方法
        try await executeAgoraOperation(
            { await agoraRtmKit.unsubscribe(channelId) },
            operationName: "RTM Unsubscribe Channel",
            timeout: 10.0
        )

        joinedChannels.remove(channelId)
        
        print("Agora RTM: 离开频道 \(channelId)")

    }
    
    public func getChannelMembers(channelId: String) async throws -> [RTMChannelMember] {
        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 在真实实现中，这里应该调用 Agora RTM SDK 获取频道成员
        // 由于 Agora RTM 2.0 不直接提供获取频道成员的 API，
        // 需要通过其他方式（如 presence 功能）来实现
        return []
    }
    
    public func getChannelMemberCount(channelId: String) async throws -> Int {
        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 在真实实现中，这里应该调用 Agora RTM SDK 获取频道成员数量
        // 由于 Agora RTM 2.0 不直接提供获取频道成员数量的 API，
        // 需要通过其他方式来实现
        return 0
    }
    
    // MARK: - Message Sending
    
    public func sendPeerMessage(_ message: RTMMessage, toPeer peerId: String, options: RTMSendMessageOptions?) async throws {

        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }

        guard !peerId.isEmpty else {
            let errorMessage =
                "Invalid peer ID"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !message.text.isEmpty else {
            throw RealtimeError.invalidMessageFormat
        }
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的发送点对点消息方法
        // 注意：Agora RTM 2.0 使用不同的 API 结构
        print("Agora RTM: 发送点对点消息给 \(peerId): \(message.text)")
        
        // TODO: 实现 Agora RTM 2.0 的点对点消息发送
        // 需要使用 publish 方法发送到特定用户
    }
    
    public func sendChannelMessage(_ message: RTMMessage, toChannel channelId: String, options: RTMSendMessageOptions?) async throws {

        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraRtmKit else {
            throw RealtimeError.configurationError("Agora RTM Engine not initialized")
        }

        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }

        guard joinedChannels.contains(channelId) else {
            let errorMessage =
                "Not in channel"
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard !message.text.isEmpty else {
            throw RealtimeError.invalidMessageFormat
        }
        
        // 调用 Agora RTM SDK 的发送频道消息方法
        let jsonEncoder = JSONEncoder()
        let data: Data = try jsonEncoder.encode(message)
        
        try await executeAgoraOperation(
            {
                let publishOptions = AgoraRtmPublishOptions()
                publishOptions.customType = "RealtimeMessage"
                publishOptions.channelType = .message
                publishOptions.storeInHistory = false
                return await agoraRtmKit.publish(channelName: channelId, data: data, option: publishOptions)
            },
            operationName: "RTM Publish Message",
            timeout: 5.0,
            retryCount: 1
        )

        print("Agora RTM: 发送频道消息到 \(channelId): \(message.text)")
    }
    
    // MARK: - User Attributes
    
    public func setLocalUserAttributes(_ attributes: [String: String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        userAttributes = attributes
        print("Agora RTM: 设置本地用户属性 \(attributes.count) 个")
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的设置用户属性方法
        // 注意：Agora RTM 2.0 使用 storage 功能来管理用户属性
    }
    
    public func addOrUpdateLocalUserAttributes(_ attributes: [String: String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        for (key, value) in attributes {
            userAttributes[key] = value
        }
        print("Agora RTM: 添加或更新本地用户属性 \(attributes.count) 个")
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的添加或更新用户属性方法
    }
    
    public func deleteLocalUserAttributesByKeys(_ attributeKeys: [String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        for key in attributeKeys {
            userAttributes.removeValue(forKey: key)
        }
        print("Agora RTM: 删除本地用户属性 \(attributeKeys.count) 个")
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的删除用户属性方法
    }
    
    public func clearLocalUserAttributes() async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        userAttributes.removeAll()
        print("Agora RTM: 清除本地用户属性")
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的清除用户属性方法
    }
    
    public func getUserAttributes(userId: String) async throws -> [String: String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 获取用户属性
        // 目前返回本地缓存的属性（仅适用于当前用户）
        return userId == "current_user" ? userAttributes : [:]
    }
    
    public func getUsersAttributes(userIds: [String]) async throws -> [String: [String: String]] {
        return [:]
    }
    
    // MARK: - Channel Attributes
    
    public func setChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        channelAttributes[channelId] = attributes
        print("Agora RTM: 设置频道 \(channelId) 属性 \(attributes.count) 个")
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的设置频道属性方法
        // 注意：Agora RTM 2.0 使用 storage 功能来管理频道属性
    }
    
    public func addOrUpdateChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 添加或更新频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        if channelAttributes[channelId] == nil {
            channelAttributes[channelId] = [:]
        }
        
        for (key, value) in attributes {
            channelAttributes[channelId]![key] = value
        }
        print("Agora RTM: 添加或更新频道 \(channelId) 属性 \(attributes.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的添加或更新频道属性方法
        // 例如: agoraRtmKit.addOrUpdateChannel(channelId, attributes: attributes, options: options, completion: completion)
    }
    
    public func deleteChannelAttributesByKeys(channelId: String, attributeKeys: [String], options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 删除频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        if var attributes = channelAttributes[channelId] {
            for key in attributeKeys {
                attributes.removeValue(forKey: key)
            }
            channelAttributes[channelId] = attributes
        }
        print("Agora RTM: 删除频道 \(channelId) 属性 \(attributeKeys.count) 个")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的删除频道属性方法
        // 例如: agoraRtmKit.deleteChannel(channelId, attributesByKeys: attributeKeys, options: options, completion: completion)
    }
    
    public func clearChannelAttributes(channelId: String, options: RTMChannelAttributeOptions?) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 清除频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        channelAttributes.removeValue(forKey: channelId)
        print("Agora RTM: 清除频道 \(channelId) 属性")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的清除频道属性方法
        // 例如: agoraRtmKit.clearChannel(channelId, options: options, completion: completion)
    }
    
    public func getChannelAttributes(channelId: String) async throws -> [String: String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 获取频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        return channelAttributes[channelId] ?? [:]
    }
    
    public func getChannelAttributesByKeys(channelId: String, attributeKeys: [String]) async throws -> [String: String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 获取频道属性过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        guard let attributes = channelAttributes[channelId] else {
            return [:]
        }
        
        var result: [String: String] = [:]
        for key in attributeKeys {
            if let value = attributes[key] {
                result[key] = value
            }
        }
        return result
    }
    
    // MARK: - Online Status
    
    public func queryPeersOnlineStatus(userIds: [String]) async throws -> [String: Bool] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        print("Agora RTM: 查询 \(userIds.count) 个用户在线状态")
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的查询在线状态方法
        // 注意：Agora RTM 2.0 使用 presence 功能来查询用户在线状态
        // 目前返回空结果
        return [:]
    }
    
    public func subscribePeersOnlineStatus(userIds: [String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        for userId in userIds {
            subscribedUsers.insert(userId)
        }
        
        print("Agora RTM: 订阅 \(userIds.count) 个用户在线状态")
        
        // 在真实实现中，这里需要调用 Agora RTM SDK 的订阅在线状态方法
        // 注意：Agora RTM 2.0 使用 presence 功能来订阅用户在线状态
    }
    
    public func unsubscribePeersOnlineStatus(userIds: [String]) async throws {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 取消订阅在线状态过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        for userId in userIds {
            subscribedUsers.remove(userId)
        }
        
        print("Agora RTM: 取消订阅 \(userIds.count) 个用户在线状态")
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的取消订阅在线状态方法
        // 例如: agoraRtmKit.unsubscribePeersOnlineStatus(userIds, completion: completion)
    }
    
    public func querySubscribedPeersList() async throws -> [String] {
        guard _isLoggedIn else {
            let errorMessage =
                "Not logged in"
            throw RealtimeError.authenticationError(errorMessage)
        }
        
        // 模拟 Agora RTM 查询已订阅用户列表过程
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        return Array(subscribedUsers)
        
        // 在真实实现中，这里会调用 Agora RTM SDK 的查询已订阅用户列表方法
        // 例如: agoraRtmKit.getSubscribedPeersList(completion: completion)
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraRtmKit else {
            throw RealtimeError.configurationError("Agora RTM Engine not initialized")
        }

        guard !newToken.isEmpty else {
            throw RealtimeError.invalidToken
        }

        // 调用 Agora RTM SDK 的 Token 更新方法
        await agoraRtmKit.renewToken(newToken)

        print("Agora RTM: 更新 Token")

    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable () -> Void) {
        tokenExpirationHandler = handler

        print("Agora RTM: Token 过期处理器已设置")
        
        // 设置 Agora RTM SDK 的 Token 过期回调
        // 例如: 在 AgoraRtmDelegate 中实现 rtmKit(_:tokenPrivilegeWillExpire:)
    }
    
    // MARK: - Event Handlers
    
    public func onConnectionStateChanged(_ handler: @escaping @Sendable (RTMConnectionState, RTMConnectionChangeReason) -> Void) {
        connectionStateHandler = handler
    }
    
    public func onPeerMessageReceived(_ handler: @escaping @Sendable (RTMMessage, String) -> Void) {
        peerMessageHandler = handler
        print("Agora RTM: 点对点消息接收处理器已设置")
        
        // 在真实实现中，这里会设置 Agora RTM SDK 的点对点消息接收回调
        // 例如: 在 AgoraRtmDelegate 中实现 rtmKit(_:messageReceived:fromPeer:)
    }

    public func onChannelMessageReceived(_ handler: @escaping @Sendable (RTMMessage, RTMChannelMember, String) -> Void) {
        channelMessageHandler = handler
        print("Agora RTM: 频道消息接收处理器已设置")
        
        // 在真实实现中，这里会设置 Agora RTM SDK 的频道消息接收回调
        // 例如: 在 AgoraRtmChannelDelegate 中实现 rtmChannel(_:messageReceived:from:)
    }
    
    public func onPeersOnlineStatusChanged(_ handler: @escaping @Sendable ([String: Bool]) -> Void) {
        peersOnlineStatusHandler = handler
    }
    
    // MARK: - Private RTM Methods

    /// 调用 Agora RTM SDK 的初始化方法
    private func agoraRTMInitialization(config: RTMConfig, userId: String) async throws {
        // 调用 Agora RTM SDK 的初始化方法
        let agoraRtmClientConfig = AgoraRtmClientConfig(appId: config.appId, userId: userId)
        agoraRtmKit = try AgoraRtmClientKit(agoraRtmClientConfig, delegate: self)
    }
    


    /// Agora RTM SDK 的登出方法
    private func agoraRTMLogout() async throws {
        guard isInitialized else {
            let errorMessage =
                "RTM Provider not initialized"
            throw RealtimeError.configurationError(errorMessage)
        }

        guard let agoraRtmKit else {
            throw RealtimeError.configurationError("Agora RTM Engine not initialized")
        }
        // 调用 Agora RTM SDK 的登出方法
        await agoraRtmKit.logout()
    }
}

extension AgoraRTMProvider: AgoraRtmClientDelegate {

    public func rtmKit(_ rtmKit: AgoraRtmClientKit, tokenPrivilegeWillExpire channel: String?) {
        tokenExpirationHandler?()
    }

    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveMessageEvent event: AgoraRtmMessageEvent) {
        // 处理接收到的消息
        guard let data = event.message.rawData else { return }
        
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(RTMMessage.self, from: data)
            
            if event.channelType == .message {
                // 频道消息
                let member = RTMChannelMember(userId: event.publisher, role: .member)
                channelMessageHandler?(message, member, event.channelName)
            } else {
                // 点对点消息（在 RTM 2.0 中通过特殊频道实现）
                peerMessageHandler?(message, event.publisher)
            }
        } catch {
            print("Agora RTM: 解析消息失败 - \(error)")
        }
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceivePresenceEvent event: AgoraRtmPresenceEvent) {
        // 处理用户在线状态变化
        var statusChanges: [String: Bool] = [:]
        
        for snapshot in event.snapshot {
            statusChanges[snapshot.userId] = true
        }
        
        peersOnlineStatusHandler?(statusChanges)
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, connectionChangedToState state: AgoraRtmClientConnectionState, reason: AgoraRtmClientConnectionChangeReason) {
        // 处理连接状态变化
        let rtmState: RTMConnectionState
        let rtmReason: RTMConnectionChangeReason
        
        switch state {
        case .disconnected:
            rtmState = .disconnected
        case .connecting:
            rtmState = .connecting
        case .connected:
            rtmState = .connected
        case .reconnecting:
            rtmState = .reconnecting
        case .failed:
            rtmState = .failed
        default:
            rtmState = .disconnected
        }
        
        switch reason {
        case .changedConnecting:
            rtmReason = .interrupted
        case .changedJoinSuccess:
            rtmReason = .loginSuccess
        case .changedInterrupted:
            rtmReason = .interrupted
        case .changedBannedByServer:
            rtmReason = .bannedByServer
        case .changedJoinFailed:
            rtmReason = .loginSuccess
        case .changedLeaveChannel:
            rtmReason = .logout
        case .changedInvalidAppId:
            rtmReason = .interrupted
        case .changedInvalidToken:
            rtmReason = .tokenExpired
        case .changedTokenExpired:
            rtmReason = .tokenExpired
        case .changedSettingProxyServer:
            rtmReason = .interrupted
        case .changedClientIpAddressChanged:
            rtmReason = .interrupted
        case .changedKeepAliveTimeout:
            rtmReason = .interrupted
        case .changedRejoinSuccess:
            rtmReason = .loginSuccess
        default:
            rtmReason = .interrupted
        }
        
        connectionStateHandler?(rtmState, rtmReason)
    }
}

// MARK: - Agora RTC Room

/// Agora RTC Room 实现
/// 需求: 2.1, 1.1, 1.2
internal class AgoraRTCRoom: RTCRoom {
    public let roomId: String
    private var members: Set<String> = []
    private var createdAt: Date = Date()
    private var roomState: AgoraRoomState = .idle
    
    init(roomId: String) {
        self.roomId = roomId
    }
    
    /// 添加成员到房间
    internal func addMember(_ userId: String) {
        members.insert(userId)
        roomState = .active
    }
    
    /// 从房间移除成员
    internal func removeMember(_ userId: String) {
        members.remove(userId)
        if members.isEmpty {
            roomState = .idle
        }
    }
    
    /// 获取房间成员数量
    internal var memberCount: Int {
        return members.count
    }
    
    /// 检查用户是否在房间中
    internal func hasMember(_ userId: String) -> Bool {
        return members.contains(userId)
    }
    
    /// 获取房间状态
    internal var state: AgoraRoomState {
        return roomState
    }
}

/// Agora 房间状态
internal enum AgoraRoomState {
    case idle
    case active
    case destroyed
}

// MARK: - Agora RTM Channel

/// Agora RTM Channel 实现
/// 需求: 2.1, 1.1, 1.2
internal class AgoraRTMChannel: RTMChannel {
    public let channelId: String
    private var members: Set<String> = []
    private var messages: [RTMMessage] = []
    private var attributes: [String: String] = [:]
    private var createdAt: Date = Date()
    private var channelState: AgoraChannelState = .idle
    
    init(channelId: String) {
        self.channelId = channelId
    }
    
    /// 添加成员到频道
    internal func addMember(_ userId: String) {
        members.insert(userId)
        channelState = .active
    }
    
    /// 从频道移除成员
    internal func removeMember(_ userId: String) {
        members.remove(userId)
        if members.isEmpty {
            channelState = .idle
        }
    }
    
    /// 获取频道成员数量
    internal var memberCount: Int {
        return members.count
    }
    
    /// 检查用户是否在频道中
    internal func hasMember(_ userId: String) -> Bool {
        return members.contains(userId)
    }
    
    /// 添加消息到频道
    internal func addMessage(_ message: RTMMessage) {
        messages.append(message)
    }
    
    /// 获取频道消息数量
    internal var messageCount: Int {
        return messages.count
    }
    
    /// 设置频道属性
    internal func setAttribute(_ key: String, value: String) {
        attributes[key] = value
    }
    
    /// 获取频道属性
    internal func getAttribute(_ key: String) -> String? {
        return attributes[key]
    }
    
    /// 获取所有频道属性
    internal var allAttributes: [String: String] {
        return attributes
    }
    
    /// 获取频道状态
    internal var state: AgoraChannelState {
        return channelState
    }
}

/// Agora 频道状态
internal enum AgoraChannelState {
    case idle
    case active
    case destroyed
}

#else

// MARK: - macOS Stub Implementation

/// Agora 服务商工厂 (macOS 存根实现)
/// 需求: 2.1, 1.1, 1.2
public class AgoraProviderFactory: NSObject, ProviderFactory {
    
    /// Agora 特定配置选项
    public struct AgoraConfiguration: Sendable {
        public let enableCloudProxy: Bool
        public let enableAudioVolumeIndication: Bool
        public let enableLocalizedErrors: Bool
        
        public init(
            enableCloudProxy: Bool = false,
            enableAudioVolumeIndication: Bool = true,
            enableLocalizedErrors: Bool = true
        ) {
            self.enableCloudProxy = enableCloudProxy
            self.enableAudioVolumeIndication = enableAudioVolumeIndication
            self.enableLocalizedErrors = enableLocalizedErrors
        }
        
        public static let `default` = AgoraConfiguration()
    }
    
    public let configuration: AgoraConfiguration
    
    public init(configuration: AgoraConfiguration = .default) {
        self.configuration = configuration
    }
    
    public func createRTCProvider() -> RTCProvider {
        fatalError("Agora SDK is not available on macOS. Please use iOS for Agora integration.")
    }
    
    public func createRTMProvider() -> RTMProvider {
        fatalError("Agora SDK is not available on macOS. Please use iOS for Agora integration.")
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return []
    }
}

#endif
