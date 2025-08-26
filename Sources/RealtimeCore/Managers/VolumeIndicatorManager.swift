import Foundation
import Combine

/// 音量指示器管理器 - 负责实时音量处理和说话状态检测
/// 需求: 6.2, 6.3, 6.4, 6.6
@MainActor
public class VolumeIndicatorManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前所有用户的音量信息
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    
    /// 当前正在说话的用户ID集合
    @Published public private(set) var speakingUsers: Set<String> = []
    
    /// 音量指示器是否已启用
    @Published public private(set) var isEnabled: Bool = false
    
    /// 当前主讲人用户ID
    @Published public private(set) var dominantSpeaker: String? = nil
    
    /// 音量检测统计信息
    @Published public private(set) var detectionStats: VolumeDetectionStats = VolumeDetectionStats()
    
    // MARK: - Event Handlers
    
    /// 音量更新回调
    public var onVolumeUpdate: (([UserVolumeInfo]) -> Void)?
    
    /// 用户开始说话回调
    public var onUserStartSpeaking: ((String, UserVolumeInfo) -> Void)?
    
    /// 用户停止说话回调
    public var onUserStopSpeaking: ((String, UserVolumeInfo) -> Void)?
    
    /// 主讲人变化回调
    public var onDominantSpeakerChanged: ((String?) -> Void)?
    
    /// 音量事件回调
    public var onVolumeEvent: ((VolumeEvent) -> Void)?
    
    // MARK: - Private Properties
    
    private var config: VolumeDetectionConfig = .default
    private var smoothingFilter: VolumeSmoothingFilter
    private var previousSpeakingUsers: Set<String> = []
    private var previousDominantSpeaker: String? = nil
    private var userSpeakingStates: [String: SpeakingState] = [:]
    private var volumeHistory: [String: [Float]] = [:]
    private let maxHistorySize = 10
    
    /// 音量事件处理器
    private let eventProcessor = VolumeEventProcessor()
    
    // MARK: - Initialization
    
    public init() {
        self.smoothingFilter = VolumeSmoothingFilter(config: .default)
        setupEventProcessor()
    }
    
    // MARK: - Event Processor Setup
    
    /// 设置事件处理器
    private func setupEventProcessor() {
        // 注册默认事件处理器
        eventProcessor.registerEventHandler(for: .userStartedSpeaking) { [weak self] event in
            await self?.handleUserStartedSpeaking(event)
        }
        
        eventProcessor.registerEventHandler(for: .userStoppedSpeaking) { [weak self] event in
            await self?.handleUserStoppedSpeaking(event)
        }
        
        eventProcessor.registerEventHandler(for: .dominantSpeakerChanged) { [weak self] event in
            await self?.handleDominantSpeakerChanged(event)
        }
        
        eventProcessor.registerEventHandler(for: .volumeUpdate) { [weak self] event in
            await self?.handleVolumeUpdate(event)
        }
    }
    
    // MARK: - Event Handlers
    
    /// 处理用户开始说话事件
    private func handleUserStartedSpeaking(_ event: VolumeEvent) async {
        if case .userStartedSpeaking(let userId, _) = event {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                onUserStartSpeaking?(userId, volumeInfo)
            }
        }
    }
    
    /// 处理用户停止说话事件
    private func handleUserStoppedSpeaking(_ event: VolumeEvent) async {
        if case .userStoppedSpeaking(let userId, _) = event {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                onUserStopSpeaking?(userId, volumeInfo)
            }
        }
    }
    
    /// 处理主讲人变化事件
    private func handleDominantSpeakerChanged(_ event: VolumeEvent) async {
        if case .dominantSpeakerChanged(let userId) = event {
            onDominantSpeakerChanged?(userId)
        }
    }
    
    /// 处理音量更新事件
    private func handleVolumeUpdate(_ event: VolumeEvent) async {
        if case .volumeUpdate(let volumeInfos) = event {
            onVolumeUpdate?(volumeInfos)
        }
    }
    
    // MARK: - Configuration
    
    /// 更新音量检测配置
    /// - Parameter config: 新的音量检测配置
    public func updateConfig(_ config: VolumeDetectionConfig) {
        guard config.isValid else {
            print("Invalid volume detection config provided")
            return
        }
        
        self.config = config
        self.smoothingFilter = VolumeSmoothingFilter(config: config)
        
        // 重置状态以应用新配置
        if isEnabled {
            resetDetectionState()
        }
    }
    
    /// 启用音量检测
    /// - Parameter config: 音量检测配置
    public func enable(with config: VolumeDetectionConfig = .default) {
        updateConfig(config)
        isEnabled = true
        resetDetectionState()
        
        detectionStats.enabledAt = Date()
        print("Volume indicator enabled with config: \(config)")
    }
    
    /// 禁用音量检测
    public func disable() {
        isEnabled = false
        resetDetectionState()
        
        detectionStats.disabledAt = Date()
        print("Volume indicator disabled")
    }
    
    // MARK: - Volume Processing (需求 6.2, 6.6)
    
    /// 处理音量更新数据
    /// - Parameter volumeInfos: 原始音量信息数组
    public func processVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        guard isEnabled else { return }
        
        detectionStats.totalUpdatesReceived += 1
        
        // 过滤本地用户（如果配置要求）
        let filteredVolumeInfos = config.includeLocalUser ? volumeInfos : volumeInfos.filter { !isLocalUser($0.userId) }
        
        // 应用平滑滤波算法 (需求 6.6)
        let smoothedVolumeInfos = smoothingFilter.applySmoothingFilter(to: filteredVolumeInfos)
        
        // 应用阈值检测和说话状态判断
        let processedVolumeInfos = applyThresholdDetection(smoothedVolumeInfos)
        
        // 更新音量历史记录
        updateVolumeHistory(processedVolumeInfos)
        
        // 检测说话状态变化 (需求 6.3)
        let newSpeakingUsers = Set(processedVolumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        detectSpeakingStateChanges(previous: previousSpeakingUsers, current: newSpeakingUsers, volumeInfos: processedVolumeInfos)
        
        // 检测主讲人变化 (需求 6.4)
        let newDominantSpeaker = identifyDominantSpeaker(processedVolumeInfos)
        if newDominantSpeaker != previousDominantSpeaker {
            dominantSpeaker = newDominantSpeaker
            eventProcessor.processEvent(.dominantSpeakerChanged(userId: newDominantSpeaker))
            previousDominantSpeaker = newDominantSpeaker
            
            detectionStats.dominantSpeakerChanges += 1
        }
        
        // 更新状态
        self.volumeInfos = processedVolumeInfos
        self.speakingUsers = newSpeakingUsers
        previousSpeakingUsers = newSpeakingUsers
        
        // 使用事件处理器异步处理事件
        eventProcessor.processEvent(.volumeUpdate(processedVolumeInfos))
        
        detectionStats.totalUpdatesProcessed += 1
        detectionStats.lastUpdateTime = Date()
    }
    
    // MARK: - Threshold Detection (需求 6.1, 6.2)
    
    /// 应用阈值检测算法
    /// - Parameter volumeInfos: 平滑处理后的音量信息
    /// - Returns: 应用阈值检测后的音量信息
    private func applyThresholdDetection(_ volumeInfos: [UserVolumeInfo]) -> [UserVolumeInfo] {
        return volumeInfos.map { volumeInfo in
            let volumeFloat = volumeInfo.volumeFloat
            
            // 获取或创建用户的说话状态
            var speakingState = userSpeakingStates[volumeInfo.userId] ?? SpeakingState()
            
            // 应用阈值检测逻辑
            let currentTime = Date()
            let isSpeaking: Bool
            
            if volumeFloat > config.speakingThreshold {
                // 音量超过说话阈值
                if !speakingState.isSpeaking {
                    speakingState.speakingStartTime = currentTime
                }
                speakingState.isSpeaking = true
                speakingState.lastVolumeTime = currentTime
                isSpeaking = true
            } else if volumeFloat < config.silenceThreshold {
                // 音量低于静音阈值
                if speakingState.isSpeaking {
                    // 如果之前在说话，检查静音持续时间
                    if speakingState.silenceStartTime == nil {
                        speakingState.silenceStartTime = currentTime
                    }
                    let silenceDuration = currentTime.timeIntervalSince(speakingState.silenceStartTime!) * 1000
                    if silenceDuration > Double(config.silenceDurationThreshold) {
                        speakingState.isSpeaking = false
                    }
                } else {
                    // 如果之前就不在说话，保持静音状态
                    speakingState.silenceStartTime = speakingState.silenceStartTime ?? currentTime
                }
                isSpeaking = speakingState.isSpeaking
            } else {
                // 音量在阈值之间，保持当前状态
                isSpeaking = speakingState.isSpeaking
                if isSpeaking {
                    speakingState.lastVolumeTime = currentTime
                }
            }
            
            // 更新用户说话状态
            userSpeakingStates[volumeInfo.userId] = speakingState
            
            // 创建更新后的音量信息
            return UserVolumeInfo(
                userId: volumeInfo.userId,
                volume: volumeInfo.volume,
                vad: isSpeaking ? .speaking : .notSpeaking,
                timestamp: volumeInfo.timestamp
            )
        }
    }
    
    // MARK: - Speaking State Detection (需求 6.3)
    
    /// 检测说话状态变化
    /// - Parameters:
    ///   - previous: 之前正在说话的用户集合
    ///   - current: 当前正在说话的用户集合
    ///   - volumeInfos: 当前音量信息数组
    private func detectSpeakingStateChanges(
        previous: Set<String>,
        current: Set<String>,
        volumeInfos: [UserVolumeInfo]
    ) {
        let startedSpeaking = current.subtracting(previous)
        let stoppedSpeaking = previous.subtracting(current)
        
        // 处理开始说话的用户
        for userId in startedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                eventProcessor.processEvent(.userStartedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
                
                detectionStats.speakingStartEvents += 1
                print("User \(userId) started speaking with volume: \(Int(volumeInfo.volumeFloat * 100))%")
            }
        }
        
        // 处理停止说话的用户
        for userId in stoppedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                eventProcessor.processEvent(.userStoppedSpeaking(userId: userId, volume: volumeInfo.volumeFloat))
                
                detectionStats.speakingStopEvents += 1
                print("User \(userId) stopped speaking with volume: \(Int(volumeInfo.volumeFloat * 100))%")
            }
        }
    }
    
    // MARK: - Dominant Speaker Identification (需求 6.4)
    
    /// 识别主讲人
    /// - Parameter volumeInfos: 当前音量信息数组
    /// - Returns: 主讲人用户ID，如果没有则返回nil
    private func identifyDominantSpeaker(_ volumeInfos: [UserVolumeInfo]) -> String? {
        let speakingUsers = volumeInfos.filter { $0.isSpeaking }
        
        guard !speakingUsers.isEmpty else { return nil }
        
        // 找到音量最大的说话用户
        let dominantUser = speakingUsers.max { user1, user2 in
            // 优先考虑音量，然后考虑说话持续时间
            if user1.volumeFloat != user2.volumeFloat {
                return user1.volumeFloat < user2.volumeFloat
            }
            
            // 如果音量相同，选择说话时间更长的用户
            let state1 = userSpeakingStates[user1.userId]
            let state2 = userSpeakingStates[user2.userId]
            
            let duration1 = state1?.speakingDuration ?? 0
            let duration2 = state2?.speakingDuration ?? 0
            
            return duration1 < duration2
        }
        
        return dominantUser?.userId
    }
    
    // MARK: - Volume History Management
    
    /// 更新音量历史记录
    /// - Parameter volumeInfos: 当前音量信息数组
    private func updateVolumeHistory(_ volumeInfos: [UserVolumeInfo]) {
        for volumeInfo in volumeInfos {
            var history = volumeHistory[volumeInfo.userId] ?? []
            history.append(volumeInfo.volumeFloat)
            
            // 限制历史记录大小
            if history.count > maxHistorySize {
                history.removeFirst()
            }
            
            volumeHistory[volumeInfo.userId] = history
        }
    }
    
    // MARK: - Utility Methods
    
    /// 重置检测状态
    private func resetDetectionState() {
        volumeInfos.removeAll()
        speakingUsers.removeAll()
        dominantSpeaker = nil
        previousSpeakingUsers.removeAll()
        previousDominantSpeaker = nil
        userSpeakingStates.removeAll()
        volumeHistory.removeAll()
        smoothingFilter.reset()
        
        detectionStats = VolumeDetectionStats()
    }
    
    /// 判断是否为本地用户
    /// - Parameter userId: 用户ID
    /// - Returns: 是否为本地用户
    private func isLocalUser(_ userId: String) -> Bool {
        // 简单的本地用户判断逻辑
        return userId.hasPrefix("local_") || userId == "0" || userId.contains("local")
    }
    
    // MARK: - Public Query Methods
    
    /// 获取指定用户的音量信息
    /// - Parameter userId: 用户ID
    /// - Returns: 用户音量信息，如果不存在则返回nil
    public func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return volumeInfos.first { $0.userId == userId }
    }
    
    /// 获取指定用户的音量历史
    /// - Parameter userId: 用户ID
    /// - Returns: 音量历史数组
    public func getVolumeHistory(for userId: String) -> [Float] {
        return volumeHistory[userId] ?? []
    }
    
    /// 获取指定用户的平均音量
    /// - Parameter userId: 用户ID
    /// - Returns: 平均音量值
    public func getAverageVolume(for userId: String) -> Float {
        let history = getVolumeHistory(for: userId)
        guard !history.isEmpty else { return 0.0 }
        return history.reduce(0, +) / Float(history.count)
    }
    
    /// 检查用户是否正在说话
    /// - Parameter userId: 用户ID
    /// - Returns: 是否正在说话
    public func isUserSpeaking(_ userId: String) -> Bool {
        return speakingUsers.contains(userId)
    }
    
    /// 获取当前说话用户数量
    /// - Returns: 说话用户数量
    public var speakingUserCount: Int {
        return speakingUsers.count
    }
    
    /// 获取总用户数量
    /// - Returns: 总用户数量
    public var totalUserCount: Int {
        return volumeInfos.count
    }
    
    // MARK: - Event Processing Access
    
    /// 注册自定义事件处理器
    /// - Parameters:
    ///   - eventType: 事件类型
    ///   - handler: 事件处理器
    public func registerEventHandler(for eventType: VolumeEventType, handler: @escaping VolumeEventHandler) {
        eventProcessor.registerEventHandler(for: eventType, handler: handler)
    }
    
    /// 取消注册事件处理器
    /// - Parameter eventType: 事件类型
    public func unregisterEventHandlers(for eventType: VolumeEventType) {
        eventProcessor.unregisterEventHandlers(for: eventType)
    }
    
    /// 获取事件处理统计信息
    public var eventProcessingStats: VolumeEventProcessingStats {
        return eventProcessor.processingStats
    }
    
    /// 获取事件队列状态
    public var eventQueueStatus: VolumeEventQueueStatus {
        return eventProcessor.queueStatus
    }
    
    /// 获取事件处理性能指标
    public var eventPerformanceMetrics: VolumeEventPerformanceMetrics {
        return eventProcessor.performanceMetrics
    }
    
    /// 清空事件队列
    public func clearEventQueue() {
        eventProcessor.clearEventQueue()
    }
    
    /// 重置事件处理统计
    public func resetEventStatistics() {
        eventProcessor.resetStatistics()
    }
}

// MARK: - Supporting Types

/// 用户说话状态
private struct SpeakingState {
    var isSpeaking: Bool = false
    var speakingStartTime: Date?
    var silenceStartTime: Date?
    var lastVolumeTime: Date?
    
    /// 说话持续时间（秒）
    var speakingDuration: TimeInterval {
        guard let startTime = speakingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    /// 静音持续时间（秒）
    var silenceDuration: TimeInterval {
        guard let startTime = silenceStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
}

/// 音量检测统计信息
public struct VolumeDetectionStats {
    /// 启用时间
    public var enabledAt: Date?
    
    /// 禁用时间
    public var disabledAt: Date?
    
    /// 最后更新时间
    public var lastUpdateTime: Date?
    
    /// 接收到的总更新次数
    public var totalUpdatesReceived: Int = 0
    
    /// 处理的总更新次数
    public var totalUpdatesProcessed: Int = 0
    
    /// 说话开始事件数量
    public var speakingStartEvents: Int = 0
    
    /// 说话停止事件数量
    public var speakingStopEvents: Int = 0
    
    /// 主讲人变化次数
    public var dominantSpeakerChanges: Int = 0
    
    /// 处理成功率
    public var processingSuccessRate: Double {
        guard totalUpdatesReceived > 0 else { return 0.0 }
        return Double(totalUpdatesProcessed) / Double(totalUpdatesReceived)
    }
    
    /// 运行时长（秒）
    public var uptime: TimeInterval {
        guard let enabledAt = enabledAt else { return 0 }
        let endTime = disabledAt ?? Date()
        return endTime.timeIntervalSince(enabledAt)
    }
}