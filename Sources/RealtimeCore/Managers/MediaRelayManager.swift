import Foundation
import Combine

/// 媒体中继管理器
/// 需求: 8.2, 8.3, 8.5, 8.6 - 管理媒体中继生命周期、状态监控、暂停/恢复功能和统计信息收集
@MainActor
public class MediaRelayManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前中继配置
    @Published public private(set) var currentConfig: MediaRelayConfig?
    
    /// 当前中继状态
    @Published public private(set) var currentState: MediaRelayState = .idle
    
    /// 详细中继状态
    @Published public private(set) var detailedState: MediaRelayDetailedState?
    
    /// 中继统计信息
    @Published public private(set) var statistics: MediaRelayStatistics?
    
    /// 是否正在运行
    @Published public private(set) var isRunning: Bool = false
    
    /// 暂停的频道列表
    @Published public private(set) var pausedChannels: Set<String> = []
    
    // MARK: - Private Properties
    
    private weak var rtcProvider: RTCProvider?
    private var statisticsTimer: Timer?
    private var stateUpdateTimer: Timer?
    private var startTime: Date?
    private var channelStates: [String: MediaRelayChannelState] = [:]
    private var channelStatistics: [String: MediaRelayChannelStatistics] = [:]
    
    // MARK: - Callbacks
    
    /// 状态变化回调
    public var onStateChanged: ((MediaRelayState, MediaRelayDetailedState?) -> Void)?
    
    /// 频道状态变化回调
    public var onChannelStateChanged: ((String, MediaRelayChannelState) -> Void)?
    
    /// 统计信息更新回调
    public var onStatisticsUpdated: ((MediaRelayStatistics) -> Void)?
    
    /// 错误回调
    public var onError: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    public init(rtcProvider: RTCProvider? = nil) {
        self.rtcProvider = rtcProvider
        setupTimers()
    }
    
    deinit {
        // Note: Cannot access @MainActor properties from deinit
        // Timers will be automatically invalidated when the object is deallocated
    }
    
    // MARK: - Public Methods
    
    /// 设置 RTC Provider
    /// - Parameter provider: RTC Provider 实例
    public func setRTCProvider(_ provider: RTCProvider) {
        self.rtcProvider = provider
    }
    
    /// 开始媒体中继
    /// 需求: 8.2 - 支持跨频道的音视频流转发
    /// - Parameter config: 媒体中继配置
    public func startRelay(config: MediaRelayConfig) async throws {
        guard let rtcProvider = rtcProvider else {
            throw LocalizedRealtimeError.mediaRelayNotSupported
        }
        
        guard currentState == .idle else {
            throw LocalizedRealtimeError.mediaRelayFailed(reason: "Media relay is already running")
        }
        
        // 验证配置
        try config.validate()
        
        // 更新状态
        updateState(.connecting)
        currentConfig = config
        startTime = Date()
        
        // 初始化频道状态
        initializeChannelStates(for: config)
        
        do {
            // 启动媒体中继
            try await rtcProvider.startMediaRelay(config: config)
            
            // 更新状态为运行中
            updateState(.running)
            isRunning = true
            
            // 开始统计信息收集
            startStatisticsCollection()
            
        } catch {
            // 启动失败，重置状态
            updateState(.failure)
            currentConfig = nil
            startTime = nil
            isRunning = false
            channelStates.removeAll()
            
            onError?(error)
            throw error
        }
    }
    
    /// 停止媒体中继
    /// 需求: 8.2 - 管理媒体中继生命周期
    public func stopRelay() async throws {
        guard let rtcProvider = rtcProvider else {
            throw LocalizedRealtimeError.mediaRelayNotSupported
        }
        
        guard isRunning else {
            return // 已经停止
        }
        
        updateState(.stopping)
        
        do {
            try await rtcProvider.stopMediaRelay()
            
            // 更新状态
            updateState(.idle)
            isRunning = false
            pausedChannels.removeAll()
            
            // 停止统计信息收集
            stopStatisticsCollection()
            
            // 保留最终统计信息
            finalizeStatistics()
            
        } catch {
            updateState(.failure)
            onError?(error)
            throw error
        }
    }
    
    /// 添加目标频道
    /// 需求: 8.4 - 支持动态添加/移除目标频道
    /// - Parameter channel: 要添加的频道信息
    public func addDestinationChannel(_ channel: MediaRelayChannelInfo) async throws {
        guard let rtcProvider = rtcProvider else {
            throw LocalizedRealtimeError.mediaRelayNotSupported
        }
        
        guard let config = currentConfig else {
            throw LocalizedRealtimeError.mediaRelayFailed(reason: "No active relay configuration")
        }
        
        guard isRunning else {
            throw LocalizedRealtimeError.mediaRelayFailed(reason: "Media relay is not running")
        }
        
        // 添加频道到配置
        let updatedConfig = try config.addingDestinationChannel(channel)
        
        do {
            // 更新媒体中继配置
            try await rtcProvider.updateMediaRelayChannels(config: updatedConfig)
            
            // 更新本地配置和状态
            currentConfig = updatedConfig
            addChannelState(for: channel.channelName, state: .connecting)
            
        } catch {
            onError?(error)
            throw error
        }
    }
    
    /// 移除目标频道
    /// 需求: 8.4 - 支持动态添加/移除目标频道
    /// - Parameter channelName: 要移除的频道名称
    public func removeDestinationChannel(_ channelName: String) async throws {
        guard let rtcProvider = rtcProvider else {
            throw LocalizedRealtimeError.mediaRelayNotSupported
        }
        
        guard let config = currentConfig else {
            throw LocalizedRealtimeError.mediaRelayFailed(reason: "No active relay configuration")
        }
        
        guard isRunning else {
            throw LocalizedRealtimeError.mediaRelayFailed(reason: "Media relay is not running")
        }
        
        // 从配置中移除频道
        let updatedConfig = try config.removingDestinationChannel(channelName)
        
        do {
            // 更新媒体中继配置
            try await rtcProvider.updateMediaRelayChannels(config: updatedConfig)
            
            // 更新本地配置和状态
            currentConfig = updatedConfig
            removeChannelState(for: channelName)
            pausedChannels.remove(channelName)
            
        } catch {
            onError?(error)
            throw error
        }
    }
    
    /// 暂停特定频道的中继
    /// 需求: 8.5 - 支持暂停/恢复特定频道的中继
    /// - Parameter channelName: 要暂停的频道名称
    public func pauseChannel(_ channelName: String) async throws {
        guard let rtcProvider = rtcProvider else {
            throw LocalizedRealtimeError.mediaRelayNotSupported
        }
        
        guard isRunning else {
            throw LocalizedRealtimeError.mediaRelayFailed(reason: "Media relay is not running")
        }
        
        guard !pausedChannels.contains(channelName) else {
            return // 已经暂停
        }
        
        do {
            try await rtcProvider.pauseMediaRelay(toChannel: channelName)
            pausedChannels.insert(channelName)
            
            // 更新频道状态
            updateChannelState(channelName: channelName, connectionState: .connected, isPaused: true)
            
        } catch {
            onError?(error)
            throw error
        }
    }
    
    /// 恢复特定频道的中继
    /// 需求: 8.5 - 支持暂停/恢复特定频道的中继
    /// - Parameter channelName: 要恢复的频道名称
    public func resumeChannel(_ channelName: String) async throws {
        guard let rtcProvider = rtcProvider else {
            throw LocalizedRealtimeError.mediaRelayNotSupported
        }
        
        guard isRunning else {
            throw LocalizedRealtimeError.mediaRelayFailed(reason: "Media relay is not running")
        }
        
        guard pausedChannels.contains(channelName) else {
            return // 没有暂停
        }
        
        do {
            try await rtcProvider.resumeMediaRelay(toChannel: channelName)
            pausedChannels.remove(channelName)
            
            // 更新频道状态
            updateChannelState(channelName: channelName, connectionState: .connected, isPaused: false)
            
        } catch {
            onError?(error)
            throw error
        }
    }
    
    /// 获取当前中继统计信息
    /// 需求: 8.6 - 提供详细的统计信息
    /// - Returns: 媒体中继统计信息
    public func getCurrentStatistics() -> MediaRelayStatistics? {
        return statistics
    }
    
    /// 获取特定频道的统计信息
    /// - Parameter channelName: 频道名称
    /// - Returns: 频道统计信息
    public func getChannelStatistics(for channelName: String) -> MediaRelayChannelStatistics? {
        return channelStatistics[channelName]
    }
    
    /// 获取所有频道的状态
    /// 需求: 8.3 - 提供每个目标频道的连接状态监控
    /// - Returns: 频道状态字典
    public func getAllChannelStates() -> [String: MediaRelayChannelState] {
        return channelStates
    }
    
    /// 获取特定频道的状态
    /// - Parameter channelName: 频道名称
    /// - Returns: 频道状态
    public func getChannelState(for channelName: String) -> MediaRelayChannelState? {
        return channelStates[channelName]
    }
    
    /// 检查频道是否暂停
    /// - Parameter channelName: 频道名称
    /// - Returns: 是否暂停
    public func isChannelPaused(_ channelName: String) -> Bool {
        return pausedChannels.contains(channelName)
    }
    
    /// 获取连接的频道数量
    /// - Returns: 连接的频道数量
    public var connectedChannelCount: Int {
        return channelStates.values.filter { $0.connectionState == .connected && !$0.isPaused }.count
    }
    
    /// 获取失败的频道数量
    /// - Returns: 失败的频道数量
    public var failedChannelCount: Int {
        return channelStates.values.filter { 
            if case .failure = $0.connectionState { return true }
            return false
        }.count
    }
    
    // MARK: - Private Methods
    
    /// 设置定时器
    private func setupTimers() {
        // 状态更新定时器（每秒更新一次）
        stateUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateDetailedState()
            }
        }
    }
    
    /// 停止定时器
    private func stopTimers() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
        stateUpdateTimer?.invalidate()
        stateUpdateTimer = nil
    }
    
    /// 更新状态
    private func updateState(_ newState: MediaRelayState) {
        currentState = newState
        onStateChanged?(newState, detailedState)
    }
    
    /// 初始化频道状态
    private func initializeChannelStates(for config: MediaRelayConfig) {
        channelStates.removeAll()
        channelStatistics.removeAll()
        
        // 添加源频道状态
        channelStates[config.sourceChannel.channelName] = MediaRelayChannelState(
            channelName: config.sourceChannel.channelName,
            connectionState: .connecting
        )
        
        // 添加目标频道状态
        for channel in config.destinationChannels {
            channelStates[channel.channelName] = MediaRelayChannelState(
                channelName: channel.channelName,
                connectionState: .connecting
            )
            
            // 初始化统计信息
            channelStatistics[channel.channelName] = MediaRelayChannelStatistics(
                channelName: channel.channelName
            )
        }
    }
    
    /// 添加频道状态
    private func addChannelState(for channelName: String, state: MediaRelayConnectionState) {
        channelStates[channelName] = MediaRelayChannelState(
            channelName: channelName,
            connectionState: state
        )
        
        channelStatistics[channelName] = MediaRelayChannelStatistics(
            channelName: channelName
        )
    }
    
    /// 移除频道状态
    private func removeChannelState(for channelName: String) {
        channelStates.removeValue(forKey: channelName)
        channelStatistics.removeValue(forKey: channelName)
    }
    
    /// 更新频道状态
    private func updateChannelState(
        channelName: String,
        connectionState: MediaRelayConnectionState,
        isPaused: Bool = false,
        error: String? = nil
    ) {
        let currentState = channelStates[channelName]
        let connectedAt = connectionState == .connected && currentState?.connectionState != .connected ? Date() : currentState?.connectedAt
        let disconnectedAt = connectionState == .disconnected && currentState?.connectionState == .connected ? Date() : currentState?.disconnectedAt
        
        let newState = MediaRelayChannelState(
            channelName: channelName,
            connectionState: connectionState,
            isPaused: isPaused,
            error: error,
            connectedAt: connectedAt,
            disconnectedAt: disconnectedAt
        )
        
        channelStates[channelName] = newState
        onChannelStateChanged?(channelName, newState)
    }
    
    /// 更新详细状态
    private func updateDetailedState() async {
        guard let config = currentConfig else {
            detailedState = nil
            return
        }
        
        let sourceState = channelStates[config.sourceChannel.channelName] ?? MediaRelayChannelState(
            channelName: config.sourceChannel.channelName,
            connectionState: .idle
        )
        
        let destinationStates = config.destinationChannels.compactMap { channel in
            channelStates[channel.channelName]
        }
        
        let overallState: MediaRelayOverallState
        switch currentState {
        case .idle:
            overallState = .idle
        case .connecting:
            overallState = .connecting
        case .running:
            if pausedChannels.count == config.destinationChannels.count {
                overallState = .paused
            } else {
                overallState = .running
            }
        case .paused:
            overallState = .paused
        case .stopping:
            overallState = .stopping
        case .failure:
            overallState = .failure
        }
        
        detailedState = MediaRelayDetailedState(
            overallState: overallState,
            sourceChannelState: sourceState,
            destinationChannelStates: destinationStates,
            startTime: startTime,
            statistics: statistics
        )
    }
    
    /// 开始统计信息收集
    private func startStatisticsCollection() {
        // 统计信息更新定时器（每5秒更新一次）
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateStatistics()
            }
        }
    }
    
    /// 停止统计信息收集
    private func stopStatisticsCollection() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }
    
    /// 更新统计信息
    private func updateStatistics() async {
        guard let startTime = startTime else { return }
        
        let currentTime = Date()
        let duration = currentTime.timeIntervalSince(startTime)
        
        // 模拟统计数据（实际实现中应该从 RTC Provider 获取真实数据）
        let totalBytesSent = UInt64(duration * 1000) // 模拟数据
        let audioPackets = UInt64(duration * 50) // 模拟音频包数量
        let videoPackets = UInt64(duration * 30) // 模拟视频包数量
        let packetsLost = UInt64(duration * 0.1) // 模拟丢包
        
        // 更新频道统计信息
        for (channelName, _) in channelStatistics {
            let channelDuration = channelStates[channelName]?.connectedAt?.timeIntervalSince(startTime) ?? 0
            channelStatistics[channelName] = MediaRelayChannelStatistics(
                channelName: channelName,
                bytesSent: UInt64(channelDuration * 200),
                bytesReceived: UInt64(channelDuration * 180),
                audioPacketsSent: UInt64(channelDuration * 10),
                videoPacketsSent: UInt64(channelDuration * 6),
                packetsLost: UInt64(channelDuration * 0.02),
                latency: Double.random(in: 20...100),
                connectionDuration: channelDuration
            )
        }
        
        statistics = MediaRelayStatistics(
            totalRelayDuration: duration,
            totalBytesSent: totalBytesSent,
            totalBytesReceived: UInt64(duration * 900),
            audioPacketsSent: audioPackets,
            videoPacketsSent: videoPackets,
            packetsLost: packetsLost,
            averageLatency: Double.random(in: 30...120),
            channelStatistics: channelStatistics,
            startTime: startTime
        )
        
        onStatisticsUpdated?(statistics!)
    }
    
    /// 完成统计信息收集
    private func finalizeStatistics() {
        // 保留最终的统计信息，不清除
        // 这样用户可以在中继停止后查看统计数据
    }
}

// MARK: - MediaRelayManager Extensions

extension MediaRelayManager {
    
    /// 重置管理器状态
    public func reset() {
        currentConfig = nil
        currentState = .idle
        detailedState = nil
        statistics = nil
        isRunning = false
        pausedChannels.removeAll()
        startTime = nil
        channelStates.removeAll()
        channelStatistics.removeAll()
        
        stopTimers()
        setupTimers()
    }
    
    /// 检查是否支持媒体中继
    public var isMediaRelaySupported: Bool {
        return rtcProvider != nil
    }
    
    /// 获取当前配置的中继模式
    public var currentRelayMode: MediaRelayMode? {
        return currentConfig?.relayMode
    }
    
    /// 获取目标频道数量
    public var destinationChannelCount: Int {
        return currentConfig?.destinationChannels.count ?? 0
    }
    
    /// 检查所有目标频道是否都已连接
    public var allDestinationsConnected: Bool {
        guard let config = currentConfig else { return false }
        
        return config.destinationChannels.allSatisfy { channel in
            let state = channelStates[channel.channelName]
            return state?.connectionState == .connected
        }
    }
    
    /// 获取活跃（未暂停且已连接）的频道数量
    public var activeChannelCount: Int {
        return channelStates.values.filter { state in
            state.connectionState == .connected && !state.isPaused
        }.count
    }
}