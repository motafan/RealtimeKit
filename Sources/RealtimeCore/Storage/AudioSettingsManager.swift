import Foundation

/// 音频设置管理器，使用新的自动持久化机制
/// 需求: 5.4, 5.5, 18.1, 18.2, 18.3
@MainActor
public class AudioSettingsManager: ObservableObject {
    
    // 使用新的 @RealtimeStorage 属性包装器，支持自动持久化
    @RealtimeStorage(wrappedValue: AudioSettings.default, "audio_settings", namespace: "RealtimeKit")
    public var settings: AudioSettings
    
    @RealtimeStorage(wrappedValue: [:], "audio_presets", namespace: "RealtimeKit")
    private var presets: [String: AudioSettings]
    
    @RealtimeStorage(wrappedValue: AudioPreferences(), "audio_preferences", namespace: "RealtimeKit")
    private var preferences: AudioPreferences
    
    // MARK: - Published Properties
    
    @Published public private(set) var isValid: Bool = true
    @Published public private(set) var lastModified: Date = Date()
    
    // MARK: - Event Handlers
    
    public var onSettingsChanged: ((AudioSettings) -> Void)?
    public var onValidationError: ((AudioSettingsError) -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        // 注册命名空间
        StorageManager.shared.registerNamespace("RealtimeKit")
        
        // 执行数据迁移（如果需要）
        performMigrationIfNeeded()
        
        // 验证当前设置
        validateCurrentSettings()
    }
    
    // MARK: - Migration Support
    
    /// 执行数据迁移（从旧的存储格式到新的格式）
    /// 需求: 18.3 - 向后兼容性和数据迁移支持
    private func performMigrationIfNeeded() {
        // 检查是否存在旧格式的数据
        let legacyKey = "RealtimeKit.AudioSettings"
        if UserDefaults.standard.object(forKey: legacyKey) != nil {
            // 迁移旧数据
            if let legacyData = UserDefaults.standard.data(forKey: legacyKey) {
                do {
                    // 尝试使用不同的日期解码策略
                    let decoder = JSONDecoder()
                    
                    // 首先尝试 ISO8601 格式
                    decoder.dateDecodingStrategy = .iso8601
                    var legacySettings: AudioSettings?
                    
                    do {
                        legacySettings = try decoder.decode(AudioSettings.self, from: legacyData)
                    } catch {
                        // 如果 ISO8601 失败，尝试默认格式
                        decoder.dateDecodingStrategy = .deferredToDate
                        do {
                            legacySettings = try decoder.decode(AudioSettings.self, from: legacyData)
                        } catch {
                            // 如果还是失败，尝试秒数格式
                            decoder.dateDecodingStrategy = .secondsSince1970
                            legacySettings = try decoder.decode(AudioSettings.self, from: legacyData)
                        }
                    }
                    
                    if let legacySettings = legacySettings {
                        // 迁移数据到新存储
                        settings = legacySettings
                        print("Migrated audio settings from legacy storage")
                        
                        // 清理旧数据
                        UserDefaults.standard.removeObject(forKey: legacyKey)
                    }
                } catch {
                    print("Failed to migrate legacy audio settings: \(error)")
                    // 即使迁移失败，也要清理旧数据以避免重复尝试
                    UserDefaults.standard.removeObject(forKey: legacyKey)
                }
            }
        }
    }
    
    // MARK: - Volume Control Methods
    
    /// 更新音频混音音量
    public func updateAudioMixingVolume(_ volume: Int) {
        guard AudioSettings.isValidVolume(volume) else {
            let error = AudioSettingsError.invalidVolume(volume, validRange: AudioSettings.volumeRange)
            onValidationError?(error)
            return
        }
        
        settings = settings.withUpdatedVolume(audioMixing: volume)
        notifySettingsChanged()
    }
    
    /// 更新播放信号音量
    public func updatePlaybackSignalVolume(_ volume: Int) {
        guard AudioSettings.isValidVolume(volume) else {
            let error = AudioSettingsError.invalidVolume(volume, validRange: AudioSettings.volumeRange)
            onValidationError?(error)
            return
        }
        
        settings = settings.withUpdatedVolume(playbackSignal: volume)
        notifySettingsChanged()
    }
    
    /// 更新录音信号音量
    public func updateRecordingSignalVolume(_ volume: Int) {
        guard AudioSettings.isValidVolume(volume) else {
            let error = AudioSettingsError.invalidVolume(volume, validRange: AudioSettings.volumeRange)
            onValidationError?(error)
            return
        }
        
        settings = settings.withUpdatedVolume(recordingSignal: volume)
        notifySettingsChanged()
    }
    
    /// 批量更新音量设置
    public func updateVolumes(
        audioMixing: Int? = nil,
        playbackSignal: Int? = nil,
        recordingSignal: Int? = nil
    ) {
        // 验证所有音量值
        if let volume = audioMixing, !AudioSettings.isValidVolume(volume) {
            let error = AudioSettingsError.invalidVolume(volume, validRange: AudioSettings.volumeRange)
            onValidationError?(error)
            return
        }
        
        if let volume = playbackSignal, !AudioSettings.isValidVolume(volume) {
            let error = AudioSettingsError.invalidVolume(volume, validRange: AudioSettings.volumeRange)
            onValidationError?(error)
            return
        }
        
        if let volume = recordingSignal, !AudioSettings.isValidVolume(volume) {
            let error = AudioSettingsError.invalidVolume(volume, validRange: AudioSettings.volumeRange)
            onValidationError?(error)
            return
        }
        
        settings = settings.withUpdatedVolume(
            audioMixing: audioMixing,
            playbackSignal: playbackSignal,
            recordingSignal: recordingSignal
        )
        notifySettingsChanged()
    }
    
    // MARK: - Microphone Control Methods
    
    /// 切换麦克风静音状态
    public func toggleMicrophone() {
        settings = settings.withUpdatedMicrophoneState(!settings.microphoneMuted)
        notifySettingsChanged()
    }
    
    /// 设置麦克风静音状态
    public func setMicrophoneMuted(_ muted: Bool) {
        settings = settings.withUpdatedMicrophoneState(muted)
        notifySettingsChanged()
    }
    
    // MARK: - Stream Control Methods
    
    /// 切换音频流状态
    public func toggleAudioStream() {
        settings = settings.withUpdatedStreamState(!settings.localAudioStreamActive)
        notifySettingsChanged()
    }
    
    /// 设置音频流状态
    public func setAudioStreamActive(_ active: Bool) {
        settings = settings.withUpdatedStreamState(active)
        notifySettingsChanged()
    }
    
    // MARK: - Preset Management
    
    /// 保存当前设置为预设
    public func savePreset(name: String) {
        presets[name] = settings
    }
    
    /// 加载预设
    public func loadPreset(name: String) -> Bool {
        guard let preset = presets[name] else { return false }
        
        settings = preset
        notifySettingsChanged()
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
    
    // MARK: - Settings Management
    
    /// 重置为默认设置
    public func resetToDefaults() {
        settings = AudioSettings.default
        notifySettingsChanged()
    }
    
    /// 导出设置
    public func exportSettings() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(settings)
        } catch {
            print("Failed to export audio settings: \(error)")
            return nil
        }
    }
    
    /// 导入设置
    public func importSettings(from data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            let importedSettings = try decoder.decode(AudioSettings.self, from: data)
            
            // 验证导入的设置
            guard importedSettings.isValid else {
                onValidationError?(AudioSettingsError.invalidVolume(0, validRange: AudioSettings.volumeRange))
                return false
            }
            
            settings = importedSettings
            notifySettingsChanged()
            return true
        } catch {
            print("Failed to import audio settings: \(error)")
            return false
        }
    }
    
    /// 清除存储的设置数据
    /// 需求: 18.2 - 支持数据清理
    public func resetStorage() {
        $settings.reset()
        $presets.remove()
        $preferences.reset()
        validateCurrentSettings()
        print("Audio settings storage reset successfully")
    }
    
    /// 检查存储健康状态
    /// 需求: 18.9 - 错误处理和降级机制
    public func checkStorageHealth() -> StorageHealthStatus {
        var issues: [String] = []
        
        // 检查设置存储
        if !$settings.hasValue() {
            issues.append("Settings not found in storage")
        }
        
        // 检查预设存储
        let presetCount = presets.count
        if presetCount > 100 {
            issues.append("Too many presets (\(presetCount)), may affect performance")
        }
        
        // 检查偏好设置
        if !$preferences.hasValue() {
            issues.append("Preferences not initialized")
        }
        
        return StorageHealthStatus(
            isHealthy: issues.isEmpty,
            issues: issues,
            lastChecked: Date()
        )
    }
    
    /// 执行存储维护
    /// 需求: 18.8 - 性能优化
    public func performStorageMaintenance() {
        // 清理过期的预设
        let maxAge: TimeInterval = 30 * 24 * 60 * 60 // 30天
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        var updatedPresets = presets
        var removedCount = 0
        
        for (name, preset) in presets {
            if preset.lastModified < cutoffDate {
                updatedPresets.removeValue(forKey: name)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            presets = updatedPresets
            print("Removed \(removedCount) expired audio presets")
        }
        
        // 更新统计信息
        StorageManager.shared.updateStatistics()
    }
    
    // MARK: - Validation Methods
    
    /// 验证当前设置
    public func validateSettings() -> [AudioSettingsError] {
        var errors: [AudioSettingsError] = []
        
        if !AudioSettings.isValidVolume(settings.audioMixingVolume) {
            errors.append(.invalidVolume(settings.audioMixingVolume, validRange: AudioSettings.volumeRange))
        }
        
        if !AudioSettings.isValidVolume(settings.playbackSignalVolume) {
            errors.append(.invalidVolume(settings.playbackSignalVolume, validRange: AudioSettings.volumeRange))
        }
        
        if !AudioSettings.isValidVolume(settings.recordingSignalVolume) {
            errors.append(.invalidVolume(settings.recordingSignalVolume, validRange: AudioSettings.volumeRange))
        }
        
        return errors
    }
    
    // MARK: - Private Methods
    
    private func validateCurrentSettings() {
        let errors = validateSettings()
        isValid = errors.isEmpty
        
        if !errors.isEmpty {
            errors.forEach { onValidationError?($0) }
        }
    }
    
    private func notifySettingsChanged() {
        lastModified = Date()
        validateCurrentSettings()
        onSettingsChanged?(settings)
    }
}

/// 音频偏好设置
public struct AudioPreferences: Codable, Sendable {
    public var autoSave: Bool = true
    public var validateOnChange: Bool = true
    public var enableVolumeSmoothing: Bool = true
    public var volumeSmoothingFactor: Float = 0.1
    
    public init() {}
}

/// 存储健康状态
public struct StorageHealthStatus: Codable, Sendable {
    public let isHealthy: Bool
    public let issues: [String]
    public let lastChecked: Date
    
    public init(isHealthy: Bool, issues: [String], lastChecked: Date) {
        self.isHealthy = isHealthy
        self.issues = issues
        self.lastChecked = lastChecked
    }
}