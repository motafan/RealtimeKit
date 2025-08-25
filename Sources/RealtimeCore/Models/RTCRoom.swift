import Foundation

/// RTC房间模型
/// 需求: 1.2, 1.3
public struct RTCRoomModel: Codable, Identifiable, Sendable {
    /// 房间唯一标识符
    public let id: String
    
    /// 房间名称
    public let name: String
    
    /// 房间描述
    public let description: String?
    
    /// 房间创建时间
    public let createdAt: Date
    
    /// 房间最大用户数
    public let maxUsers: Int
    
    /// 当前用户数
    public let currentUserCount: Int
    
    /// 房间状态
    public let status: RTCRoomStatus
    
    /// 房间配置
    public let config: RTCRoomConfig
    
    /// 房间创建者ID
    public let creatorId: String
    
    /// 是否需要密码
    public let requiresPassword: Bool
    
    /// 房间标签
    public let tags: [String]
    
    public init(
        id: String,
        name: String,
        description: String? = nil,
        createdAt: Date = Date(),
        maxUsers: Int = 100,
        currentUserCount: Int = 0,
        status: RTCRoomStatus = .active,
        config: RTCRoomConfig = RTCRoomConfig(),
        creatorId: String,
        requiresPassword: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.maxUsers = maxUsers
        self.currentUserCount = currentUserCount
        self.status = status
        self.config = config
        self.creatorId = creatorId
        self.requiresPassword = requiresPassword
        self.tags = tags
    }
}

/// RTC房间状态
public enum RTCRoomStatus: String, CaseIterable, Codable, Sendable {
    /// 活跃状态
    case active = "active"
    /// 暂停状态
    case paused = "paused"
    /// 已关闭
    case closed = "closed"
    /// 维护中
    case maintenance = "maintenance"
    
    /// 获取状态的中文显示名称
    public var displayName: String {
        switch self {
        case .active:
            return "活跃"
        case .paused:
            return "暂停"
        case .closed:
            return "已关闭"
        case .maintenance:
            return "维护中"
        }
    }
}

/// RTC房间配置
public struct RTCRoomConfig: Codable, Sendable {
    /// 是否启用音频录制
    public let enableAudioRecording: Bool
    
    /// 是否启用自动静音新用户
    public let autoMuteNewUsers: Bool
    
    /// 是否允许观众申请发言
    public let allowAudienceToSpeak: Bool
    
    /// 房间音频质量
    public let audioQuality: RTCAudioProfile
    
    /// 房间音频场景
    public let audioScenario: RTCAudioScenario
    
    /// 是否启用音量指示器
    public let enableVolumeIndicator: Bool
    
    /// 音量指示器更新间隔（毫秒）
    public let volumeIndicatorInterval: Int
    
    /// 是否启用回声消除
    public let enableEchoCancellation: Bool
    
    /// 是否启用噪声抑制
    public let enableNoiseSuppression: Bool
    
    public init(
        enableAudioRecording: Bool = false,
        autoMuteNewUsers: Bool = false,
        allowAudienceToSpeak: Bool = true,
        audioQuality: RTCAudioProfile = .default,
        audioScenario: RTCAudioScenario = .default,
        enableVolumeIndicator: Bool = true,
        volumeIndicatorInterval: Int = 200,
        enableEchoCancellation: Bool = true,
        enableNoiseSuppression: Bool = true
    ) {
        self.enableAudioRecording = enableAudioRecording
        self.autoMuteNewUsers = autoMuteNewUsers
        self.allowAudienceToSpeak = allowAudienceToSpeak
        self.audioQuality = audioQuality
        self.audioScenario = audioScenario
        self.enableVolumeIndicator = enableVolumeIndicator
        self.volumeIndicatorInterval = volumeIndicatorInterval
        self.enableEchoCancellation = enableEchoCancellation
        self.enableNoiseSuppression = enableNoiseSuppression
    }
}
