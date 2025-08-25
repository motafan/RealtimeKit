import Foundation

/// 音量检测管理器，集成 @RealtimeStorage 支持
/// 需求: 6.1, 6.2, 6.6, 18.1, 18.2
public class VolumeDetectionManager: ObservableObject {
    
    @RealtimeStorage(wrappedValue: VolumeDetectionConfig.default, "volume_detection_config")
    public var config: VolumeDetectionConfig
    
    @RealtimeStorage(wrappedValue: [:], "volume_detection_presets")
    private var presets: [String: VolumeDetectionConfig]
    
    @RealtimeStorage(wrappedValue: [:], "volume_history")
    private var volumeHistory: [String: [UserVolumeInfo]]
    
    // MARK: - Published Properties
    
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var currentVolumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var dominantSpeaker: String?
    @Published public private(set) var speakingUsers: Set<String> = []
    
    // MARK: - Private Properties
    
    private let smoothingFilter: VolumeSmoothingFilter
    private var detectionTimer: Timer?
    
    // MARK: - Event Handlers
    
    public var onVolumeUpdate: (([UserVolumeInfo]) -> Void)?
    public var onSpeakingStateChanged: ((String, Bool) -> Void)?
    public var onDominantSpeakerChanged: ((String?) -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        self.smoothingFilter = VolumeSmoothingFilter(config: VolumeDetectionConfig.default)
    }
    
    deinit {
        stopDetection()
    }
    
    // MARK: - Detection Control
    
    /// 启用音量检测
    public func enableDetection() {
        guard !isEnabled else { return }
        
        isEnabled = true
        startDetectionTimer()
        print("Volume detection enabled with config: \(config)")
    }
    
    /// 禁用音量检测
    public func disableDetection() {
        guard isEnabled else { return }
        
        isEnabled = false
        stopDetection()
        clearCurrentState()
        print("Volume detection disabled")
    }
    
    /// 更新检测配置
    public func updateConfig(_ newConfig: VolumeDetectionConfig) {
        guard newConfig.isValid else {
            print("Invalid volume detection config provided")
            return
        }
        
        config = newConfig
        smoothingFilter.reset()
        
        if isEnabled {
            restartDetection()
        }
    }
    
    // MARK: - Volume Processing
    
    /// 处理音量数据
    public func processVolumeData(_ volumeInfos: [UserVolumeInfo]) {
        guard isEnabled else { return }
        
        // 过滤本地用户（如果配置要求）
        let filteredInfos = config.includeLocalUser ? volumeInfos : volumeInfos.filter { !$0.userId.hasPrefix("local") }
        
        // 应用平滑滤波
        let smoothedInfos = smoothingFilter.applySmoothingFilter(to: filteredInfos)
        
        // 更新当前音量信息
        currentVolumeInfos = smoothedInfos
        
        // 更新说话状态
        updateSpeakingStates(smoothedInfos)
        
        // 更新主讲人
        updateDominantSpeaker(smoothedInfos)
        
        // 保存到历史记录
        saveToHistory(smoothedInfos)
        
        // 触发回调
        onVolumeUpdate?(smoothedInfos)
    }
    
    // MARK: - Query Methods
    
    /// 获取用户音量信息
    public func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return currentVolumeInfos.first { $0.userId == userId }
    }
    
    /// 检查用户是否正在说话
    public func isUserSpeaking(_ userId: String) -> Bool {
        return speakingUsers.contains(userId)
    }
    
    /// 获取音量历史记录
    public func getVolumeHistory(for userId: String, limit: Int = 10) -> [UserVolumeInfo] {
        guard let history = volumeHistory[userId] else { return [] }
        return Array(history.suffix(limit))
    }
    
    /// 获取所有用户的音量历史
    public func getAllVolumeHistory() -> [String: [UserVolumeInfo]] {
        return volumeHistory
    }
    
    // MARK: - Preset Management
    
    /// 保存当前配置为预设
    public func savePreset(name: String) {
        presets[name] = config
    }
    
    /// 加载预设配置
    public func loadPreset(name: String) -> Bool {
        guard let preset = presets[name] else { return false }
        
        updateConfig(preset)
        return true
    }
    
    /// 删除预设
    public func deletePreset(name: String) {
        presets.removeValue(forKey: name)
    }
    
    /// 获取所有预设名称
    public func getPresetNames() -> [String] {
        return Array(presets.keys).sorted()
    }
    
    // MARK: - History Management
    
    /// 清除音量历史
    public func clearHistory(for userId: String? = nil) {
        if let userId = userId {
            volumeHistory.removeValue(forKey: userId)
        } else {
            volumeHistory.removeAll()
        }
    }
    
    /// 清除过期的历史记录
    public func clearExpiredHistory(maxAge: TimeInterval = 3600) {
        let cutoffTime = Date().addingTimeInterval(-maxAge)
        
        for (userId, history) in volumeHistory {
            let filteredHistory = history.filter { $0.timestamp > cutoffTime }
            if filteredHistory.isEmpty {
                volumeHistory.removeValue(forKey: userId)
            } else {
                volumeHistory[userId] = filteredHistory
            }
        }
    }
    
    // MARK: - State Management
    
    /// 重置状态
    public func resetState() {
        clearCurrentState()
        smoothingFilter.reset()
    }
    
    /// 重置存储数据
    public func resetStorage() {
        $config.reset()
        $presets.remove()
        $volumeHistory.remove()
        resetState()
    }
    
    // MARK: - Private Methods
    
    private func startDetectionTimer() {
        stopDetection()
        
        let interval = TimeInterval(config.detectionInterval) / 1000.0
        detectionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performDetectionCycle()
        }
    }
    
    private func stopDetection() {
        detectionTimer?.invalidate()
        detectionTimer = nil
    }
    
    private func restartDetection() {
        if isEnabled {
            startDetectionTimer()
        }
    }
    
    private func performDetectionCycle() {
        // 这里可以集成实际的音量检测逻辑
        // 目前作为占位符实现
    }
    
    private func updateSpeakingStates(_ volumeInfos: [UserVolumeInfo]) {
        let newSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        
        // 检测说话状态变化
        for userId in newSpeakingUsers {
            if !speakingUsers.contains(userId) {
                onSpeakingStateChanged?(userId, true)
            }
        }
        
        for userId in speakingUsers {
            if !newSpeakingUsers.contains(userId) {
                onSpeakingStateChanged?(userId, false)
            }
        }
        
        speakingUsers = newSpeakingUsers
    }
    
    private func updateDominantSpeaker(_ volumeInfos: [UserVolumeInfo]) {
        let speakingInfos = volumeInfos.filter { $0.isSpeaking }
        let newDominantSpeaker = speakingInfos.max(by: { $0.volume < $1.volume })?.userId
        
        if newDominantSpeaker != dominantSpeaker {
            dominantSpeaker = newDominantSpeaker
            onDominantSpeakerChanged?(newDominantSpeaker)
        }
    }
    
    private func saveToHistory(_ volumeInfos: [UserVolumeInfo]) {
        for info in volumeInfos {
            var userHistory = volumeHistory[info.userId] ?? []
            userHistory.append(info)
            
            // 限制历史记录大小
            let maxHistorySize = 100
            if userHistory.count > maxHistorySize {
                userHistory.removeFirst(userHistory.count - maxHistorySize)
            }
            
            volumeHistory[info.userId] = userHistory
        }
    }
    
    private func clearCurrentState() {
        currentVolumeInfos.removeAll()
        dominantSpeaker = nil
        speakingUsers.removeAll()
    }
}