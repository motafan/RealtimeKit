import Foundation
import Combine

// MARK: - StreamPushState Extensions

/// 转推流状态扩展
/// 需求: 7.3 - 提供实时状态监控和错误处理
extension StreamPushState {
    /// 是否可以启动转推流
    public var canStart: Bool {
        return self == .stopped || self == .failed
    }
    
    /// 是否可以停止转推流
    public var canStop: Bool {
        return self == .running || self == .starting
    }
    
    /// 是否可以更新布局
    public var canUpdateLayout: Bool {
        return self == .running
    }
}

/// 转推流错误
public enum StreamPushError: LocalizedError {
    case invalidConfiguration(String)
    case startFailed(String)
    case stopFailed(String)
    case layoutUpdateFailed(String)
    case invalidState(current: StreamPushState, expected: StreamPushState)
    case providerNotAvailable
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let reason):
            return "Invalid stream push configuration: \(reason)"
        case .startFailed(let reason):
            return "Failed to start stream push: \(reason)"
        case .stopFailed(let reason):
            return "Failed to stop stream push: \(reason)"
        case .layoutUpdateFailed(let reason):
            return "Failed to update stream layout: \(reason)"
        case .invalidState(let current, let expected):
            return "Invalid state transition from \(current) to \(expected)"
        case .providerNotAvailable:
            return "Stream push provider is not available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// 转推流管理器
/// 需求: 7.2, 7.3, 7.4 - 管理转推流生命周期、状态管理和错误恢复机制
@MainActor
public class StreamPushManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var state: StreamPushState = .stopped
    @Published public private(set) var currentConfig: StreamPushConfig?
    @Published public private(set) var lastError: StreamPushError?
    @Published public private(set) var startTime: Date?
    @Published public private(set) var statistics: StreamPushStatistics = StreamPushStatistics()
    
    // MARK: - Private Properties
    
    private weak var rtcProvider: RTCProvider?
    private var stateTransitionTimer: Timer?
    private var retryCount: Int = 0
    private let maxRetryCount: Int = 3
    private let retryDelay: TimeInterval = 5.0
    private let enableAutoRetry: Bool
    
    // MARK: - Event Handlers
    
    public var onStateChanged: ((StreamPushState) -> Void)?
    public var onError: ((StreamPushError) -> Void)?
    public var onStatisticsUpdated: ((StreamPushStatistics) -> Void)?
    
    // MARK: - Initialization
    
    public init(rtcProvider: RTCProvider? = nil, enableAutoRetry: Bool = true) {
        self.rtcProvider = rtcProvider
        self.enableAutoRetry = enableAutoRetry
    }
    
    deinit {
        // Note: Timer cleanup will happen automatically when the object is deallocated
        // We can't access @MainActor properties from deinit
    }
    
    // MARK: - Public Methods
    
    /// 设置 RTC Provider
    /// 需求: 7.2 - 转推流启动功能
    public func setRTCProvider(_ provider: RTCProvider) {
        rtcProvider = provider
    }
    
    /// 启动转推流
    /// 需求: 7.2 - 转推流启动功能
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard state.canStart else {
            throw StreamPushError.invalidState(current: state, expected: .stopped)
        }
        
        guard let _ = rtcProvider else {
            throw StreamPushError.providerNotAvailable
        }
        
        // 验证配置
        do {
            try config.validate()
        } catch {
            throw StreamPushError.invalidConfiguration(error.localizedDescription)
        }
        
        // 更新状态为启动中
        updateState(.starting)
        currentConfig = config
        lastError = nil
        retryCount = 0
        
        do {
            // 调用内部方法启动转推流
            try await performStreamStart(config: config)
            
            // 启动成功，更新状态
            updateState(.running)
            startTime = Date()
            statistics.reset()
            
            // 启动统计更新定时器
            startStatisticsTimer()
            
        } catch {
            // 启动失败，更新状态和错误信息
            let streamError = StreamPushError.startFailed(error.localizedDescription)
            updateState(.failed)
            lastError = streamError
            onError?(streamError)
            
            // 尝试自动重试（如果启用）
            if enableAutoRetry {
                await attemptRetry()
            }
            
            throw streamError
        }
    }
    
    /// 停止转推流
    /// 需求: 7.5 - 优雅地停止推流并清理资源
    public func stopStreamPush() async throws {
        guard state.canStop else {
            throw StreamPushError.invalidState(current: state, expected: .running)
        }
        
        guard let provider = rtcProvider else {
            throw StreamPushError.providerNotAvailable
        }
        
        // 更新状态为停止中
        updateState(.stopping)
        
        do {
            // 调用底层 Provider 停止转推流
            try await provider.stopStreamPush()
            
            // 停止成功，清理资源
            cleanupResources()
            updateState(.stopped)
            
        } catch {
            // 停止失败，但仍然清理资源
            let streamError = StreamPushError.stopFailed(error.localizedDescription)
            cleanupResources()
            updateState(.failed)
            lastError = streamError
            onError?(streamError)
            
            throw streamError
        }
    }
    
    /// 更新转推流布局
    /// 需求: 7.4 - 支持动态更新流布局
    public func updateStreamLayout(_ layout: StreamLayout) async throws {
        guard state.canUpdateLayout else {
            throw StreamPushError.invalidState(current: state, expected: .running)
        }
        
        guard let provider = rtcProvider else {
            throw StreamPushError.providerNotAvailable
        }
        
        guard var config = currentConfig else {
            throw StreamPushError.invalidConfiguration("No active stream configuration")
        }
        
        // 验证新布局
        do {
            try layout.validate()
        } catch {
            throw StreamPushError.layoutUpdateFailed(error.localizedDescription)
        }
        
        do {
            // 调用底层 Provider 更新布局
            try await provider.updateStreamPushLayout(layout: layout)
            
            // 更新配置中的布局
            config = try StreamPushConfig(
                url: config.url,
                layout: layout,
                audioConfig: config.audioConfig,
                videoConfig: config.videoConfig,
                enableTranscoding: config.enableTranscoding,
                backgroundColor: config.backgroundColor,
                quality: config.quality,
                watermark: config.watermark
            )
            currentConfig = config
            
            // 更新统计信息
            statistics.layoutUpdateCount += 1
            
        } catch {
            let streamError = StreamPushError.layoutUpdateFailed(error.localizedDescription)
            lastError = streamError
            onError?(streamError)
            
            throw streamError
        }
    }
    
    /// 获取当前转推流状态
    public func getCurrentState() -> StreamPushState {
        return state
    }
    
    /// 获取转推流统计信息
    public func getStatistics() -> StreamPushStatistics {
        return statistics
    }
    
    /// 重置错误状态
    public func resetError() {
        lastError = nil
        if state == .failed {
            updateState(.stopped)
        }
    }
    
    // MARK: - Private Methods
    
    /// 更新状态
    private func updateState(_ newState: StreamPushState) {
        let oldState = state
        state = newState
        
        // 触发状态变化回调
        onStateChanged?(newState)
        
        // 记录状态转换
        print("StreamPushManager: State changed from \(oldState) to \(newState)")
        
        // 处理状态转换超时
        handleStateTransitionTimeout(newState)
    }
    
    /// 处理状态转换超时
    private func handleStateTransitionTimeout(_ state: StreamPushState) {
        stateTransitionTimer?.invalidate()
        
        // 对于中间状态，设置超时处理
        if state == .starting || state == .stopping {
            stateTransitionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if self.state == .starting {
                        let error = StreamPushError.startFailed("Start operation timed out")
                        self.updateState(.failed)
                        self.lastError = error
                        self.onError?(error)
                    } else if self.state == .stopping {
                        let error = StreamPushError.stopFailed("Stop operation timed out")
                        self.updateState(.failed)
                        self.lastError = error
                        self.onError?(error)
                    }
                }
            }
        }
    }
    
    /// 尝试自动重试
    private func attemptRetry() async {
        guard retryCount < maxRetryCount else {
            print("StreamPushManager: Max retry count reached, giving up")
            return
        }
        
        retryCount += 1
        print("StreamPushManager: Attempting retry \(retryCount)/\(maxRetryCount) in \(retryDelay) seconds")
        
        // 等待重试延迟
        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
        
        // 如果状态仍然是失败，尝试重新启动
        if state == .failed, let config = currentConfig {
            do {
                try await performStreamStart(config: config)
                
                // 启动成功，更新状态
                updateState(.running)
                startTime = Date()
                statistics.reset()
                
                // 启动统计更新定时器
                startStatisticsTimer()
                
            } catch {
                print("StreamPushManager: Retry \(retryCount) failed: \(error)")
                // 如果还有重试次数，继续重试
                if retryCount < maxRetryCount {
                    await attemptRetry()
                } else {
                    print("StreamPushManager: All retries exhausted, giving up")
                }
            }
        }
    }
    
    /// 执行流启动（内部方法，不重置重试计数）
    private func performStreamStart(config: StreamPushConfig) async throws {
        guard let provider = rtcProvider else {
            throw StreamPushError.providerNotAvailable
        }
        
        updateState(.starting)
        try await provider.startStreamPush(config: config)
    }
    
    /// 清理资源
    private func cleanupResources() {
        stateTransitionTimer?.invalidate()
        stateTransitionTimer = nil
        startTime = nil
        retryCount = 0
        
        // 停止统计更新定时器
        stopStatisticsTimer()
    }
    
    /// 启动统计更新定时器
    private func startStatisticsTimer() {
        // 这里可以实现定期更新统计信息的逻辑
        // 例如从 RTC Provider 获取实时统计数据
    }
    
    /// 停止统计更新定时器
    private func stopStatisticsTimer() {
        // 停止统计更新定时器
    }
}

/// 转推流统计信息
/// 需求: 7.3 - 提供实时状态监控
public struct StreamPushStatistics: Codable, Sendable {
    /// 总推流时长（秒）
    public var totalDuration: TimeInterval = 0
    
    /// 布局更新次数
    public var layoutUpdateCount: Int = 0
    
    /// 错误次数
    public var errorCount: Int = 0
    
    /// 重试次数
    public var retryCount: Int = 0
    
    /// 平均比特率 (kbps)
    public var averageBitrate: Double = 0
    
    /// 丢帧率 (%)
    public var frameDropRate: Double = 0
    
    /// 网络延迟 (ms)
    public var networkLatency: Double = 0
    
    /// 最后更新时间
    public var lastUpdated: Date = Date()
    
    /// 重置统计信息
    public mutating func reset() {
        totalDuration = 0
        layoutUpdateCount = 0
        errorCount = 0
        retryCount = 0
        averageBitrate = 0
        frameDropRate = 0
        networkLatency = 0
        lastUpdated = Date()
    }
    
    /// 更新统计信息
    public mutating func update(
        duration: TimeInterval? = nil,
        bitrate: Double? = nil,
        frameDropRate: Double? = nil,
        latency: Double? = nil
    ) {
        if let duration = duration {
            self.totalDuration = duration
        }
        if let bitrate = bitrate {
            self.averageBitrate = bitrate
        }
        if let frameDropRate = frameDropRate {
            self.frameDropRate = frameDropRate
        }
        if let latency = latency {
            self.networkLatency = latency
        }
        self.lastUpdated = Date()
    }
}
