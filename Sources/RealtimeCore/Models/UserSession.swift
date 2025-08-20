// UserSession.swift
// User session data model

import Foundation

/// User session information
public struct UserSession: Codable, Equatable, Sendable {
    public let userId: String
    public let userName: String
    public let userRole: UserRole
    public let roomId: String?
    public let sessionId: String
    public let createdAt: Date
    public let lastActiveAt: Date
    
    /// Initialize a new user session
    /// - Parameters:
    ///   - userId: Unique user identifier
    ///   - userName: Display name for the user
    ///   - userRole: Role of the user in the session
    ///   - roomId: Optional room identifier if user is in a room
    ///   - sessionId: Unique session identifier
    ///   - createdAt: Session creation timestamp
    ///   - lastActiveAt: Last activity timestamp
    public init(
        userId: String,
        userName: String,
        userRole: UserRole,
        roomId: String? = nil,
        sessionId: String = UUID().uuidString,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.userId = userId
        self.userName = userName
        self.userRole = userRole
        self.roomId = roomId
        self.sessionId = sessionId
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
    
    /// Create a new session with updated room information
    /// - Parameter roomId: New room identifier
    /// - Returns: Updated user session
    public func withRoom(_ roomId: String?) -> UserSession {
        return UserSession(
            userId: userId,
            userName: userName,
            userRole: userRole,
            roomId: roomId,
            sessionId: sessionId,
            createdAt: createdAt,
            lastActiveAt: Date()
        )
    }
    
    /// Create a new session with updated user role
    /// - Parameter role: New user role
    /// - Returns: Updated user session
    public func withRole(_ role: UserRole) -> UserSession {
        return UserSession(
            userId: userId,
            userName: userName,
            userRole: role,
            roomId: roomId,
            sessionId: sessionId,
            createdAt: createdAt,
            lastActiveAt: Date()
        )
    }
    
    /// Update last active timestamp
    /// - Returns: Updated user session
    public func updateLastActive() -> UserSession {
        return UserSession(
            userId: userId,
            userName: userName,
            userRole: userRole,
            roomId: roomId,
            sessionId: sessionId,
            createdAt: createdAt,
            lastActiveAt: Date()
        )
    }
    
    /// Check if user is currently in a room
    public var isInRoom: Bool {
        return roomId != nil
    }
    
    /// Session duration in seconds
    public var duration: TimeInterval {
        return lastActiveAt.timeIntervalSince(createdAt)
    }
}

/// User permissions based on role
public struct UserPermissions: Sendable {
    public let role: UserRole
    
    public init(role: UserRole) {
        self.role = role
    }
    
    /// Check if user has specific permission
    /// - Parameter permission: Permission to check
    /// - Returns: True if user has permission
    public func hasPermission(_ permission: UserPermission) -> Bool {
        switch permission {
        case .audio:
            return role.hasAudioPermission
        case .video:
            return role.hasVideoPermission
        case .manageRoom:
            return role.canManageRoom
        case .sendMessage:
            return true // All roles can send messages
        case .receiveMessage:
            return true // All roles can receive messages
        case .switchRole:
            return !role.canSwitchToRole.isEmpty
        case .volumeControl:
            return role.hasAudioPermission
        case .streamPush:
            return role == .broadcaster || role == .moderator
        case .mediaRelay:
            return role == .broadcaster || role == .moderator
        }
    }
    
    /// Get all permissions for this role
    public var allPermissions: Set<UserPermission> {
        return Set(UserPermission.allCases.filter { hasPermission($0) })
    }
}

/// Available user permissions
public enum UserPermission: String, CaseIterable, Sendable {
    case audio = "audio"
    case video = "video"
    case manageRoom = "manage_room"
    case sendMessage = "send_message"
    case receiveMessage = "receive_message"
    case switchRole = "switch_role"
    case volumeControl = "volume_control"
    case streamPush = "stream_push"
    case mediaRelay = "media_relay"
    
    /// Display name for permission
    public var displayName: String {
        switch self {
        case .audio: return "音频权限"
        case .video: return "视频权限"
        case .manageRoom: return "房间管理"
        case .sendMessage: return "发送消息"
        case .receiveMessage: return "接收消息"
        case .switchRole: return "切换角色"
        case .volumeControl: return "音量控制"
        case .streamPush: return "转推流"
        case .mediaRelay: return "媒体中继"
        }
    }
}