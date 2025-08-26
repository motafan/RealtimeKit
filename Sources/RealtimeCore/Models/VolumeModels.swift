import Foundation

/// 用户音量信息 (需求 6.2)
public struct UserVolumeInfo: Codable, Identifiable, Sendable, Equatable {
    /// 用户ID
    public let id: String
    
    /// 用户ID（为了兼容性保留）
    public let userId: String
    
    /// 音量级别（0-255）
    public let volume: Int
    
    /// 语音活动检测（VAD）状态
    public let vad: VoiceActivityStatus
    
    /// 音量更新时间戳
    public let timestamp: Date
    
    /// 音量的浮点表示 (0.0 - 1.0)
    public var volumeFloat: Float {
        return Float(volume) / 255.0
    }
    
    /// 是否正在说话
    public var isSpeaking: Bool {
        return vad == .speaking
    }
    
    /// 音量百分比（0-100）
    public var volumePercentage: Int {
        return Int((Double(volume) / 255.0) * 100.0)
    }
    
    /// 音量强度级别
    public var volumeLevel: VolumeLevel {
        let percentage = volumePercentage
        switch percentage {
        case 0...10:
            return .silent
        case 11...30:
            return .low
        case 31...60:
            return .medium
        case 61...80:
            return .high
        default:
            return .veryHigh
        }
    }
    
    public init(
        userId: String,
        volume: Int,
        vad: VoiceActivityStatus = .notSpeaking,
        timestamp: Date = Date()
    ) {
        self.id = userId
        self.userId = userId
        self.volume = max(0, min(255, volume))
        self.vad = vad
        self.timestamp = timestamp
    }
    
    /// 使用浮点音量值创建
    public init(
        userId: String,
        volumeFloat: Float,
        isSpeaking: Bool,
        timestamp: Date = Date()
    ) {
        self.id = userId
        self.userId = userId
        self.volume = Int(max(0.0, min(1.0, volumeFloat)) * 255.0)
        self.vad = isSpeaking ? .speaking : .notSpeaking
        self.timestamp = timestamp
    }
    
    /// 检查音量信息是否过期
    public func isExpired(maxAge: TimeInterval = 5.0) -> Bool {
        return Date().timeIntervalSince(timestamp) > maxAge
    }
}

/// 音量强度级别
public enum VolumeLevel: String, CaseIterable, Codable, Sendable {
    case silent = "silent"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    public var displayName: String {
        switch self {
        case .silent:
            return "静音"
        case .low:
            return "低音量"
        case .medium:
            return "中等音量"
        case .high:
            return "高音量"
        case .veryHigh:
            return "很高音量"
        }
    }
    
    public var color: String {
        switch self {
        case .silent:
            return "#CCCCCC"
        case .low:
            return "#4CAF50"
        case .medium:
            return "#FFC107"
        case .high:
            return "#FF9800"
        case .veryHigh:
            return "#F44336"
        }
    }
}

/// 语音活动状态
public enum VoiceActivityStatus: String, CaseIterable, Codable, Sendable {
    /// 未说话
    case notSpeaking = "not_speaking"
    /// 正在说话
    case speaking = "speaking"
    /// 静音状态
    case muted = "muted"
    
    /// 获取状态的中文显示名称
    public var displayName: String {
        switch self {
        case .notSpeaking:
            return "未说话"
        case .speaking:
            return "正在说话"
        case .muted:
            return "静音"
        }
    }
}

// MARK: - Volume Events

/// 音量事件类型 (需求 6.3)
public enum VolumeEvent: Equatable, Sendable {
    case userStartedSpeaking(userId: String, volume: Float)
    case userStoppedSpeaking(userId: String, volume: Float)
    case dominantSpeakerChanged(userId: String?)
    case volumeUpdate([UserVolumeInfo])
    
    /// 事件类型名称
    public var eventType: String {
        switch self {
        case .userStartedSpeaking:
            return "user_started_speaking"
        case .userStoppedSpeaking:
            return "user_stopped_speaking"
        case .dominantSpeakerChanged:
            return "dominant_speaker_changed"
        case .volumeUpdate:
            return "volume_update"
        }
    }
    
    /// 事件描述
    public var description: String {
        switch self {
        case .userStartedSpeaking(let userId, let volume):
            return "用户 \(userId) 开始说话，音量: \(Int(volume * 100))%"
        case .userStoppedSpeaking(let userId, let volume):
            return "用户 \(userId) 停止说话，音量: \(Int(volume * 100))%"
        case .dominantSpeakerChanged(let userId):
            if let userId = userId {
                return "主讲人变更为: \(userId)"
            } else {
                return "没有主讲人"
            }
        case .volumeUpdate(let volumeInfos):
            return "音量更新，\(volumeInfos.count) 个用户"
        }
    }
}



/// 音量检测配置 (需求 6.1, 6.2, 6.6)
public struct VolumeDetectionConfig: Codable, Sendable, Equatable {
    /// 检测间隔（毫秒）(需求 6.1)
    public let detectionInterval: Int
    
    /// 说话音量阈值 (0.0 - 1.0) (需求 6.1)
    public let speakingThreshold: Float
    
    /// 静音音量阈值 (0.0 - 1.0)
    public let silenceThreshold: Float
    
    /// 是否包含本地用户
    public let includeLocalUser: Bool
    
    /// 平滑处理参数 (0.0 - 1.0) (需求 6.6)
    public let smoothFactor: Float
    
    /// 是否启用平滑滤波
    public let enableSmoothing: Bool
    
    /// 音量阈值（0-255），用于兼容旧版本
    public let volumeThreshold: Int
    
    /// VAD检测灵敏度（0.0-1.0）
    public let vadSensitivity: Double
    
    /// 说话状态持续时间阈值（毫秒）
    public let speakingDurationThreshold: Int
    
    /// 静音状态持续时间阈值（毫秒）
    public let silenceDurationThreshold: Int
    
    public init(
        detectionInterval: Int = 300,
        speakingThreshold: Float = 0.3,
        silenceThreshold: Float = 0.05,
        includeLocalUser: Bool = true,
        smoothFactor: Float = 0.3,
        enableSmoothing: Bool = true,
        volumeThreshold: Int = 10,
        vadSensitivity: Double = 0.5,
        speakingDurationThreshold: Int = 300,
        silenceDurationThreshold: Int = 500
    ) {
        self.detectionInterval = max(100, min(5000, detectionInterval))
        self.speakingThreshold = max(0.0, min(1.0, speakingThreshold))
        self.silenceThreshold = max(0.0, min(1.0, silenceThreshold))
        self.includeLocalUser = includeLocalUser
        self.smoothFactor = max(0.0, min(1.0, smoothFactor))
        self.enableSmoothing = enableSmoothing
        self.volumeThreshold = max(0, min(255, volumeThreshold))
        self.vadSensitivity = max(0.0, min(1.0, vadSensitivity))
        self.speakingDurationThreshold = max(100, speakingDurationThreshold)
        self.silenceDurationThreshold = max(100, silenceDurationThreshold)
    }
    
    /// 向后兼容的初始化方法
    public init(
        interval: Int = 200,
        smooth: Bool = true,
        reportLocalVolume: Bool = true,
        volumeThreshold: Int = 10,
        vadSensitivity: Double = 0.5,
        speakingDurationThreshold: Int = 300,
        silenceDurationThreshold: Int = 500
    ) {
        self.init(
            detectionInterval: interval,
            speakingThreshold: 0.3,
            silenceThreshold: 0.05,
            includeLocalUser: reportLocalVolume,
            smoothFactor: smooth ? 0.3 : 0.0,
            enableSmoothing: smooth,
            volumeThreshold: volumeThreshold,
            vadSensitivity: vadSensitivity,
            speakingDurationThreshold: speakingDurationThreshold,
            silenceDurationThreshold: silenceDurationThreshold
        )
    }
    
    /// 向后兼容属性
    public var interval: Int { detectionInterval }
    public var smooth: Bool { enableSmoothing }
    public var reportLocalVolume: Bool { includeLocalUser }
    
    /// 验证配置是否有效
    public var isValid: Bool {
        return detectionInterval >= 100 && detectionInterval <= 5000 &&
               speakingThreshold >= 0.0 && speakingThreshold <= 1.0 &&
               silenceThreshold >= 0.0 && silenceThreshold <= 1.0 &&
               smoothFactor >= 0.0 && smoothFactor <= 1.0 &&
               speakingThreshold > silenceThreshold
    }
    
    public static let `default` = VolumeDetectionConfig(
        detectionInterval: 300,
        speakingThreshold: 0.3,
        silenceThreshold: 0.05,
        includeLocalUser: true,
        smoothFactor: 0.3,
        enableSmoothing: true
    )
}

// MARK: - Volume Smoothing Filter

/// 音量平滑滤波器 (需求 6.6)
public class VolumeSmoothingFilter {
    private var previousValues: [String: Float] = [:]
    private let config: VolumeDetectionConfig
    
    public init(config: VolumeDetectionConfig) {
        self.config = config
    }
    
    /// 应用平滑滤波算法
    public func applySmoothingFilter(to volumeInfos: [UserVolumeInfo]) -> [UserVolumeInfo] {
        guard config.enableSmoothing else { return volumeInfos }
        
        return volumeInfos.map { volumeInfo in
            let currentVolume = Float(volumeInfo.volume) / 255.0
            let previousVolume = previousValues[volumeInfo.userId] ?? currentVolume
            
            // 指数移动平均滤波
            let smoothedVolume = previousVolume * (1.0 - config.smoothFactor) + currentVolume * config.smoothFactor
            previousValues[volumeInfo.userId] = smoothedVolume
            
            let smoothedVolumeInt = Int(smoothedVolume * 255.0)
            
            // 保持原始的VAD状态，让后续的阈值检测来决定说话状态
            return UserVolumeInfo(
                userId: volumeInfo.userId,
                volume: smoothedVolumeInt,
                vad: volumeInfo.vad,
                timestamp: volumeInfo.timestamp
            )
        }
    }
    
    /// 重置滤波器状态
    public func reset() {
        previousValues.removeAll()
    }
    
    /// 重置特定用户的滤波器状态
    public func reset(for userId: String) {
        previousValues.removeValue(forKey: userId)
    }
}