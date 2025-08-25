import Foundation

/// 音频状态信息
/// 需求: 5.1, 5.2, 5.3, 5.6 - 音频状态监控和管理
public struct AudioStatusInfo: Codable, Sendable {
    /// 当前音频设置
    public let settings: AudioSettings
    
    /// RTC Provider 是否已连接
    public let isProviderConnected: Bool
    
    /// 是否具有音频权限
    public let hasAudioPermission: Bool
    
    /// 当前用户角色
    public let currentUserRole: UserRole?
    
    /// 设置最后修改时间
    public let lastModified: Date
    
    /// 状态检查时间
    public let statusTime: Date
    
    /// 音频设备可用性
    public let audioDeviceAvailable: Bool
    
    /// 网络质量状态
    public let networkQuality: AudioNetworkQuality
    
    public init(
        settings: AudioSettings,
        isProviderConnected: Bool,
        hasAudioPermission: Bool,
        currentUserRole: UserRole?,
        lastModified: Date,
        statusTime: Date = Date(),
        audioDeviceAvailable: Bool = true,
        networkQuality: AudioNetworkQuality = .good
    ) {
        self.settings = settings
        self.isProviderConnected = isProviderConnected
        self.hasAudioPermission = hasAudioPermission
        self.currentUserRole = currentUserRole
        self.lastModified = lastModified
        self.statusTime = statusTime
        self.audioDeviceAvailable = audioDeviceAvailable
        self.networkQuality = networkQuality
    }
    
    /// 检查音频是否完全可用
    public var isAudioFullyAvailable: Bool {
        return isProviderConnected && 
               hasAudioPermission && 
               audioDeviceAvailable && 
               settings.localAudioStreamActive &&
               networkQuality != .poor
    }
    
    /// 检查麦克风是否可用
    public var isMicrophoneAvailable: Bool {
        return isAudioFullyAvailable && !settings.microphoneMuted
    }
    
    /// 获取音频状态摘要
    public var statusSummary: String {
        if isAudioFullyAvailable {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.status.fully_available")
        } else if !isProviderConnected {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.status.provider_disconnected")
        } else if !hasAudioPermission {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.status.permission_denied")
        } else if !audioDeviceAvailable {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.status.device_unavailable")
        } else if !settings.localAudioStreamActive {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.status.stream_inactive")
        } else if networkQuality == .poor {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.status.poor_network")
        } else {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.status.partially_available")
        }
    }
    
    /// 获取建议的操作
    public var suggestedActions: [AudioAction] {
        var actions: [AudioAction] = []
        
        if !isProviderConnected {
            actions.append(.reconnectProvider)
        }
        
        if !hasAudioPermission {
            actions.append(.requestPermission)
        }
        
        if !audioDeviceAvailable {
            actions.append(.checkAudioDevice)
        }
        
        if !settings.localAudioStreamActive {
            actions.append(.resumeAudioStream)
        }
        
        if settings.microphoneMuted {
            actions.append(.unmuteMicrophone)
        }
        
        if networkQuality == .poor {
            actions.append(.checkNetworkConnection)
        }
        
        return actions
    }
}

/// 音频网络质量
public enum AudioNetworkQuality: String, CaseIterable, Codable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .excellent:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.network.quality.excellent")
        case .good:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.network.quality.good")
        case .fair:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.network.quality.fair")
        case .poor:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.network.quality.poor")
        case .unknown:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.network.quality.unknown")
        }
    }
    
    public var color: String {
        switch self {
        case .excellent:
            return "#4CAF50" // 绿色
        case .good:
            return "#8BC34A" // 浅绿色
        case .fair:
            return "#FFC107" // 黄色
        case .poor:
            return "#F44336" // 红色
        case .unknown:
            return "#9E9E9E" // 灰色
        }
    }
}

/// 建议的音频操作
public enum AudioAction: String, CaseIterable, Sendable {
    case reconnectProvider = "reconnect_provider"
    case requestPermission = "request_permission"
    case checkAudioDevice = "check_audio_device"
    case resumeAudioStream = "resume_audio_stream"
    case unmuteMicrophone = "unmute_microphone"
    case checkNetworkConnection = "check_network_connection"
    case resetAudioSettings = "reset_audio_settings"
    case syncSettings = "sync_settings"
    
    public var displayName: String {
        switch self {
        case .reconnectProvider:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.reconnect_provider")
        case .requestPermission:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.request_permission")
        case .checkAudioDevice:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.check_audio_device")
        case .resumeAudioStream:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.resume_audio_stream")
        case .unmuteMicrophone:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.unmute_microphone")
        case .checkNetworkConnection:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.check_network_connection")
        case .resetAudioSettings:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.reset_audio_settings")
        case .syncSettings:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.sync_settings")
        }
    }
    
    public var description: String {
        switch self {
        case .reconnectProvider:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.reconnect_provider.description")
        case .requestPermission:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.request_permission.description")
        case .checkAudioDevice:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.check_audio_device.description")
        case .resumeAudioStream:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.resume_audio_stream.description")
        case .unmuteMicrophone:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.unmute_microphone.description")
        case .checkNetworkConnection:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.check_network_connection.description")
        case .resetAudioSettings:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.reset_audio_settings.description")
        case .syncSettings:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.action.sync_settings.description")
        }
    }
}

/// 音频设置验证结果
/// 需求: 5.4, 5.5 - 音频设置验证和错误处理
public struct AudioSettingsValidationResult: Sendable {
    /// 设置是否有效
    public let isValid: Bool
    
    /// 验证错误列表
    public let validationErrors: [AudioSettingsValidationError]
    
    /// 警告信息列表
    public let warnings: [String]
    
    /// 被验证的音频设置
    public let audioSettings: AudioSettings
    
    /// 验证时间
    public let validationTime: Date
    
    /// 建议的修复操作
    public let suggestedFixes: [AudioAction]
    
    public init(
        isValid: Bool,
        validationErrors: [AudioSettingsValidationError],
        warnings: [String],
        audioSettings: AudioSettings,
        validationTime: Date,
        suggestedFixes: [AudioAction] = []
    ) {
        self.isValid = isValid
        self.validationErrors = validationErrors
        self.warnings = warnings
        self.audioSettings = audioSettings
        self.validationTime = validationTime
        self.suggestedFixes = suggestedFixes.isEmpty ? Self.generateSuggestedFixes(for: validationErrors) : suggestedFixes
    }
    
    /// 获取验证摘要
    public var validationSummary: String {
        if isValid {
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.validation.success")
        } else {
            let errorCount = validationErrors.count
            let warningCount = warnings.count
            return ErrorLocalizationHelper.getLocalizedString(
                for: "audio.validation.failed",
                arguments: [errorCount, warningCount],
                fallbackValue: "Audio validation failed with \(errorCount) errors and \(warningCount) warnings"
            )
        }
    }
    
    /// 根据验证错误生成建议的修复操作
    private static func generateSuggestedFixes(for errors: [AudioSettingsValidationError]) -> [AudioAction] {
        var fixes: [AudioAction] = []
        
        for error in errors {
            switch error {
            case .invalidVolumeRange:
                fixes.append(.resetAudioSettings)
            case .permissionMismatch:
                fixes.append(.requestPermission)
            case .providerMismatch:
                fixes.append(.syncSettings)
            case .settingsCorrupted:
                fixes.append(.resetAudioSettings)
            }
        }
        
        return Array(Set(fixes)) // 去重
    }
}

/// 音频设置验证错误
public enum AudioSettingsValidationError: String, CaseIterable, Error, Sendable {
    case invalidVolumeRange = "invalid_volume_range"
    case permissionMismatch = "permission_mismatch"
    case providerMismatch = "provider_mismatch"
    case settingsCorrupted = "settings_corrupted"
    
    public var localizedDescription: String {
        switch self {
        case .invalidVolumeRange:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.validation.error.invalid_volume_range")
        case .permissionMismatch:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.validation.error.permission_mismatch")
        case .providerMismatch:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.validation.error.provider_mismatch")
        case .settingsCorrupted:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.validation.error.settings_corrupted")
        }
    }
}

/// 音频设置历史记录
/// 需求: 5.4, 5.5 - 音频设置变更历史和恢复
public struct AudioSettingsHistory: Codable, Sendable {
    /// 历史记录条目
    public let entries: [AudioSettingsHistoryEntry]
    
    /// 最大历史记录数量
    public let maxEntries: Int
    
    /// 最后更新时间
    public let lastUpdated: Date
    
    public init(
        entries: [AudioSettingsHistoryEntry] = [],
        maxEntries: Int = 10,
        lastUpdated: Date = Date()
    ) {
        self.entries = entries
        self.maxEntries = maxEntries
        self.lastUpdated = lastUpdated
    }
    
    /// 添加新的历史记录条目
    public func addingEntry(_ entry: AudioSettingsHistoryEntry) -> AudioSettingsHistory {
        var newEntries = entries
        newEntries.append(entry)
        
        // 保持最大条目数限制
        if newEntries.count > maxEntries {
            newEntries = Array(newEntries.suffix(maxEntries))
        }
        
        return AudioSettingsHistory(
            entries: newEntries,
            maxEntries: maxEntries,
            lastUpdated: Date()
        )
    }
    
    /// 获取最近的设置
    public var mostRecentSettings: AudioSettings? {
        return entries.last?.audioSettings
    }
    
    /// 获取指定时间之前的设置
    public func getSettingsBefore(_ date: Date) -> AudioSettings? {
        return entries.last { $0.timestamp < date }?.audioSettings
    }
}

/// 音频设置历史记录条目
public struct AudioSettingsHistoryEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let audioSettings: AudioSettings
    public let timestamp: Date
    public let changeReason: AudioSettingsChangeReason
    public let userRole: UserRole?
    
    public init(
        id: String = UUID().uuidString,
        audioSettings: AudioSettings,
        timestamp: Date = Date(),
        changeReason: AudioSettingsChangeReason,
        userRole: UserRole? = nil
    ) {
        self.id = id
        self.audioSettings = audioSettings
        self.timestamp = timestamp
        self.changeReason = changeReason
        self.userRole = userRole
    }
}

/// 音频设置变更原因
public enum AudioSettingsChangeReason: String, CaseIterable, Codable, Sendable {
    case userManual = "user_manual"
    case systemRestore = "system_restore"
    case roleChange = "role_change"
    case providerSwitch = "provider_switch"
    case errorRecovery = "error_recovery"
    case batchUpdate = "batch_update"
    case reset = "reset"
    
    public var displayName: String {
        switch self {
        case .userManual:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.change.reason.user_manual")
        case .systemRestore:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.change.reason.system_restore")
        case .roleChange:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.change.reason.role_change")
        case .providerSwitch:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.change.reason.provider_switch")
        case .errorRecovery:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.change.reason.error_recovery")
        case .batchUpdate:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.change.reason.batch_update")
        case .reset:
            return ErrorLocalizationHelper.getLocalizedString(for: "audio.change.reason.reset")
        }
    }
}

/// 扩展通知名称以支持音频事件
/// 需求: 5.6, 17.6 - 音频状态变化通知
extension Notification.Name {
    public static let audioMicrophoneStateChanged = Notification.Name("RealtimeKit.audioMicrophoneStateChanged")
    public static let audioVolumeChanged = Notification.Name("RealtimeKit.audioVolumeChanged")
    public static let audioStreamStateChanged = Notification.Name("RealtimeKit.audioStreamStateChanged")
    public static let audioBatchVolumeChanged = Notification.Name("RealtimeKit.audioBatchVolumeChanged")
    public static let audioSettingsReset = Notification.Name("RealtimeKit.audioSettingsReset")
    public static let audioSettingsSynced = Notification.Name("RealtimeKit.audioSettingsSynced")
    public static let audioDeviceChanged = Notification.Name("RealtimeKit.audioDeviceChanged")
    public static let audioNetworkQualityChanged = Notification.Name("RealtimeKit.audioNetworkQualityChanged")
}