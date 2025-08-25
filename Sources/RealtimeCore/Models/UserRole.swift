import Foundation

/// 用户在房间中的角色类型
/// 需求: 4.1, 4.2, 4.4
public enum UserRole: String, CaseIterable, Codable, Sendable {
    /// 主播角色 - 可以发布音频和视频流
    case broadcaster = "broadcaster"
    
    /// 观众角色 - 只能接收音频和视频流
    case audience = "audience"
    
    /// 连麦嘉宾角色 - 可以发布音频和视频流，但权限低于主播
    case coHost = "co_host"
    
    /// 主持人角色 - 具有房间管理权限，可以发布音频流
    case moderator = "moderator"
    
    /// 获取角色的本地化显示名称
    public var displayName: String {
        switch self {
        case .broadcaster:
            return ErrorLocalizationHelper.getLocalizedString(for: "user.role.broadcaster")
        case .audience:
            return ErrorLocalizationHelper.getLocalizedString(for: "user.role.audience")
        case .coHost:
            return ErrorLocalizationHelper.getLocalizedString(for: "user.role.cohost")
        case .moderator:
            return ErrorLocalizationHelper.getLocalizedString(for: "user.role.moderator")
        }
    }
    
    /// 检查角色是否具有音频权限 (需求 4.2)
    public var hasAudioPermission: Bool {
        switch self {
        case .broadcaster, .coHost, .moderator:
            return true
        case .audience:
            return false
        }
    }
    
    /// 检查角色是否具有视频权限 (需求 4.2)
    public var hasVideoPermission: Bool {
        switch self {
        case .broadcaster, .coHost:
            return true
        case .audience, .moderator:
            return false
        }
    }
    
    /// 检查角色是否具有管理权限
    public var hasModeratorPrivileges: Bool {
        switch self {
        case .moderator:
            return true
        case .broadcaster, .audience, .coHost:
            return false
        }
    }
    
    /// 获取可以切换到的角色集合 (需求 4.3)
    public var canSwitchToRole: Set<UserRole> {
        switch self {
        case .broadcaster:
            return [.moderator]
        case .audience:
            return [.coHost]
        case .coHost:
            return [.audience, .broadcaster]
        case .moderator:
            return [.broadcaster]
        }
    }
    
    /// 检查是否可以切换到指定角色 (需求 4.3)
    public func canSwitchTo(_ role: UserRole) -> Bool {
        return canSwitchToRole.contains(role)
    }
    
    /// 权限级别，用于权限比较
    public var permissionLevel: Int {
        switch self {
        case .audience:
            return 0
        case .coHost:
            return 1
        case .broadcaster:
            return 2
        case .moderator:
            return 3
        }
    }
    
    /// 检查是否具有比指定角色更高的权限
    public func hasHigherPermissionThan(_ role: UserRole) -> Bool {
        return self.permissionLevel > role.permissionLevel
    }
}

// MARK: - Convenience Properties (向后兼容)

extension UserRole {
    /// 检查角色是否可以发布音频 (向后兼容)
    @available(*, deprecated, renamed: "hasAudioPermission")
    public var canPublishAudio: Bool {
        return hasAudioPermission
    }
}