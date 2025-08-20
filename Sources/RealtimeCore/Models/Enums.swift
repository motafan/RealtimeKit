// Enums.swift
// Core enumeration types for RealtimeKit

import Foundation

/// User roles in a real-time communication session
public enum UserRole: String, CaseIterable, Codable, Sendable {
    case broadcaster = "broadcaster"    // 主播
    case audience = "audience"         // 观众
    case coHost = "co_host"           // 连麦嘉宾
    case moderator = "moderator"      // 主持人
    
    /// Localized display name for the role
    public var displayName: String {
        switch self {
        case .broadcaster: return "主播"
        case .audience: return "观众"
        case .coHost: return "连麦嘉宾"
        case .moderator: return "主持人"
        }
    }
    
    /// Whether this role has audio permission
    public var hasAudioPermission: Bool {
        switch self {
        case .broadcaster, .coHost, .moderator: return true
        case .audience: return false
        }
    }
    
    /// Whether this role has video permission
    public var hasVideoPermission: Bool {
        switch self {
        case .broadcaster, .coHost: return true
        case .audience, .moderator: return false
        }
    }
    
    /// Whether this role can manage the room
    public var canManageRoom: Bool {
        switch self {
        case .broadcaster, .moderator: return true
        case .audience, .coHost: return false
        }
    }
    
    /// Roles that this role can switch to
    public var canSwitchToRole: Set<UserRole> {
        switch self {
        case .broadcaster: return [.moderator]
        case .audience: return [.coHost]
        case .coHost: return [.audience, .broadcaster]
        case .moderator: return [.broadcaster]
        }
    }
}

/// Connection state for RTM/RTC providers
public enum ConnectionState: String, CaseIterable, Codable, Sendable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
    
    /// Localized display name for the state
    public var displayName: String {
        switch self {
        case .disconnected: return "已断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .reconnecting: return "重连中"
        case .failed: return "连接失败"
        }
    }
    
    /// Whether the connection is active
    public var isActive: Bool {
        return self == .connected
    }
}

/// Stream push state for live streaming
public enum StreamPushState: String, CaseIterable, Codable, Sendable {
    case stopped = "stopped"
    case starting = "starting"
    case running = "running"
    case stopping = "stopping"
    case failed = "failed"
    
    /// Localized display name for the state
    public var displayName: String {
        switch self {
        case .stopped: return "已停止"
        case .starting: return "启动中"
        case .running: return "推流中"
        case .stopping: return "停止中"
        case .failed: return "推流失败"
        }
    }
    
    /// Whether stream push is active
    public var isActive: Bool {
        return self == .running
    }
}



/// Provider types supported by RealtimeKit
public enum ProviderType: String, CaseIterable, Codable, Sendable {
    case agora = "agora"
    case tencent = "tencent"
    case zego = "zego"
    case mock = "mock"
    
    /// Display name for the provider
    public var displayName: String {
        switch self {
        case .agora: return "声网 Agora"
        case .tencent: return "腾讯云 TRTC"
        case .zego: return "即构 ZEGO"
        case .mock: return "Mock Provider"
        }
    }
}

/// Message types for RTM communication
public enum MessageType: String, CaseIterable, Codable, Sendable {
    case text = "text"
    case image = "image"
    case audio = "audio"
    case video = "video"
    case file = "file"
    case custom = "custom"
    case system = "system"
    
    /// Display name for the message type
    public var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .audio: return "音频"
        case .video: return "视频"
        case .file: return "文件"
        case .custom: return "自定义"
        case .system: return "系统消息"
        }
    }
}

/// Volume events for speaking state changes
public enum VolumeEvent: Equatable, Sendable {
    case userStartedSpeaking(userId: String, volume: Float)
    case userStoppedSpeaking(userId: String, volume: Float)
    case volumeChanged(userId: String, volume: Float)
    case dominantSpeakerChanged(userId: String?)
    
    /// User ID associated with this event
    public var userId: String? {
        switch self {
        case .userStartedSpeaking(let userId, _),
             .userStoppedSpeaking(let userId, _),
             .volumeChanged(let userId, _):
            return userId
        case .dominantSpeakerChanged(let userId):
            return userId
        }
    }
    
    /// Volume level associated with this event
    public var volume: Float? {
        switch self {
        case .userStartedSpeaking(_, let volume),
             .userStoppedSpeaking(_, let volume),
             .volumeChanged(_, let volume):
            return volume
        case .dominantSpeakerChanged:
            return nil
        }
    }
}