import Foundation

/// 连接状态枚举
/// 需求: 13.2, 13.3
public enum ConnectionState: String, CaseIterable, Codable, Sendable {
    /// 断开连接
    case disconnected = "disconnected"
    /// 连接中
    case connecting = "connecting"
    /// 已连接
    case connected = "connected"
    /// 重连中
    case reconnecting = "reconnecting"
    /// 连接失败
    case failed = "failed"
    /// 连接暂停
    case suspended = "suspended"
    
    /// 获取状态的本地化显示名称
    public var displayName: String {
        switch self {
        case .disconnected:
            return ErrorLocalizationHelper.getLocalizedString(for: "connection.state.disconnected")
        case .connecting:
            return ErrorLocalizationHelper.getLocalizedString(for: "connection.state.connecting")
        case .connected:
            return ErrorLocalizationHelper.getLocalizedString(for: "connection.state.connected")
        case .reconnecting:
            return ErrorLocalizationHelper.getLocalizedString(for: "connection.state.reconnecting")
        case .failed:
            return ErrorLocalizationHelper.getLocalizedString(for: "connection.state.failed")
        case .suspended:
            return ErrorLocalizationHelper.getLocalizedString(for: "connection.state.suspended")
        }
    }
    
    /// 检查是否为活跃连接状态
    public var isActive: Bool {
        switch self {
        case .connected:
            return true
        case .disconnected, .connecting, .reconnecting, .failed, .suspended:
            return false
        }
    }
    
    /// 检查是否为过渡状态
    public var isTransitioning: Bool {
        switch self {
        case .connecting, .reconnecting:
            return true
        case .disconnected, .connected, .failed, .suspended:
            return false
        }
    }
    
    /// 检查是否可以尝试连接
    public var canAttemptConnection: Bool {
        switch self {
        case .disconnected, .failed, .suspended:
            return true
        case .connecting, .connected, .reconnecting:
            return false
        }
    }
    
    /// 获取本地化键
    public var localizationKey: String {
        switch self {
        case .disconnected:
            return "connection.state.disconnected"
        case .connecting:
            return "connection.state.connecting"
        case .connected:
            return "connection.state.connected"
        case .reconnecting:
            return "connection.state.reconnecting"
        case .failed:
            return "connection.state.failed"
        case .suspended:
            return "connection.state.suspended"
        }
    }
    
    /// 检查是否应该显示动画
    public var shouldAnimate: Bool {
        switch self {
        case .connecting, .reconnecting:
            return true
        case .disconnected, .connected, .failed, .suspended:
            return false
        }
    }
}

/// 推流状态枚举
/// 需求: 7.3, 7.4
public enum StreamPushState: String, CaseIterable, Codable, Sendable {
    /// 停止状态
    case stopped = "stopped"
    /// 启动中
    case starting = "starting"
    /// 运行中
    case running = "running"
    /// 暂停中
    case pausing = "pausing"
    /// 已暂停
    case paused = "paused"
    /// 恢复中
    case resuming = "resuming"
    /// 停止中
    case stopping = "stopping"
    /// 失败
    case failed = "failed"
    
    /// 获取状态的本地化显示名称
    public var displayName: String {
        switch self {
        case .stopped:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.stopped")
        case .starting:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.starting")
        case .running:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.running")
        case .pausing:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.pausing")
        case .paused:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.paused")
        case .resuming:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.resuming")
        case .stopping:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.stopping")
        case .failed:
            return ErrorLocalizationHelper.getLocalizedString(for: "stream.push.state.failed")
        }
    }
    
    /// 检查是否为活跃状态
    public var isActive: Bool {
        switch self {
        case .running, .paused:
            return true
        case .stopped, .starting, .pausing, .resuming, .stopping, .failed:
            return false
        }
    }
    
    /// 检查是否为过渡状态
    public var isTransitioning: Bool {
        switch self {
        case .starting, .pausing, .resuming, .stopping:
            return true
        case .stopped, .running, .paused, .failed:
            return false
        }
    }
}

/// 媒体中继状态枚举
/// 需求: 8.3, 8.5
public enum MediaRelayState: String, CaseIterable, Codable, Sendable {
    /// 空闲状态
    case idle = "idle"
    /// 连接中
    case connecting = "connecting"
    /// 运行中
    case running = "running"
    /// 暂停中
    case paused = "paused"
    /// 停止中
    case stopping = "stopping"
    /// 失败
    case failure = "failure"
    
    /// 获取状态的本地化显示名称
    public var displayName: String {
        switch self {
        case .idle:
            return ErrorLocalizationHelper.getLocalizedString(for: "media.relay.state.idle")
        case .connecting:
            return ErrorLocalizationHelper.getLocalizedString(for: "media.relay.state.connecting")
        case .running:
            return ErrorLocalizationHelper.getLocalizedString(for: "media.relay.state.running")
        case .paused:
            return ErrorLocalizationHelper.getLocalizedString(for: "media.relay.state.paused")
        case .stopping:
            return ErrorLocalizationHelper.getLocalizedString(for: "media.relay.state.stopping")
        case .failure:
            return ErrorLocalizationHelper.getLocalizedString(for: "media.relay.state.failure")
        }
    }
    
    /// 检查是否为活跃状态
    public var isActive: Bool {
        switch self {
        case .connecting, .running, .paused:
            return true
        case .idle, .stopping, .failure:
            return false
        }
    }
}

// Note: RealtimeError and ErrorCategory are defined in RealtimeCore.swift to avoid duplicates

/// RTC Room 协议
/// 需求: 1.1, 1.2
public protocol RTCRoom: AnyObject {
    var roomId: String { get }
}

/// RTM Channel 协议
/// 需求: 1.1, 1.2
public protocol RTMChannel: AnyObject {
    var channelId: String { get }
}

/// 用户会话统计信息
/// 需求: 4.5
public struct UserSessionStats: Codable, Sendable {
    public let sessionId: String
    public let userId: String
    public let sessionDuration: TimeInterval
    public let inactiveDuration: TimeInterval
    public let isValid: Bool
    
    public init(
        sessionId: String,
        userId: String,
        sessionDuration: TimeInterval,
        inactiveDuration: TimeInterval,
        isValid: Bool
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.sessionDuration = sessionDuration
        self.inactiveDuration = inactiveDuration
        self.isValid = isValid
    }
    
    /// 格式化会话持续时间
    public var formattedSessionDuration: String {
        let totalSeconds = Int(sessionDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// 格式化非活跃时间
    public var formattedInactiveDuration: String {
        let totalSeconds = Int(inactiveDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

/// 通知键常量
/// 需求: 17.6
public struct LocalizationNotificationKeys {
    public static let previousLanguage = "previousLanguage"
    public static let currentLanguage = "currentLanguage"
}

/// 通知名称扩展
/// 需求: 17.6
extension Notification.Name {
    public static let realtimeLanguageDidChange = Notification.Name("RealtimeKit.languageDidChange")
    public static let realtimeVolumeInfoUpdated = Notification.Name("RealtimeKit.volumeInfoUpdated")
    public static let tokenRenewed = Notification.Name("RealtimeKit.tokenRenewed")
    public static let tokenRenewalFailed = Notification.Name("RealtimeKit.tokenRenewalFailed")
}