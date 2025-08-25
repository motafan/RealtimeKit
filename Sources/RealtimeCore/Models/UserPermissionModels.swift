import Foundation

/// 用户权限类型
/// 需求: 4.2, 4.5 - 用户权限检查和验证
public enum UserPermission: String, CaseIterable, Codable, Sendable {
    /// 音频权限
    case audio = "audio"
    /// 视频权限
    case video = "video"
    /// 主持人权限
    case moderator = "moderator"
    /// 推流权限
    case streamPush = "stream_push"
    /// 媒体中继权限
    case mediaRelay = "media_relay"
    /// 音量指示器权限
    case volumeIndicator = "volume_indicator"
    /// 角色切换权限
    case roleSwitch = "role_switch"
    
    /// 获取权限的本地化显示名称
    public var displayName: String {
        switch self {
        case .audio:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.audio")
        case .video:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.video")
        case .moderator:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.moderator")
        case .streamPush:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.stream_push")
        case .mediaRelay:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.media_relay")
        case .volumeIndicator:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.volume_indicator")
        case .roleSwitch:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.role_switch")
        }
    }
    
    /// 获取权限的描述信息
    public var description: String {
        switch self {
        case .audio:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.audio.description")
        case .video:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.video.description")
        case .moderator:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.moderator.description")
        case .streamPush:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.stream_push.description")
        case .mediaRelay:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.media_relay.description")
        case .volumeIndicator:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.volume_indicator.description")
        case .roleSwitch:
            return ErrorLocalizationHelper.getLocalizedString(for: "permission.role_switch.description")
        }
    }
    
    /// 检查权限是否为敏感权限
    public var isSensitive: Bool {
        switch self {
        case .moderator, .streamPush, .mediaRelay:
            return true
        case .audio, .video, .volumeIndicator, .roleSwitch:
            return false
        }
    }
}

/// 登出原因
/// 需求: 4.5 - 会话状态管理
public enum LogoutReason: String, CaseIterable, Codable, Sendable {
    /// 用户主动登出
    case userInitiated = "user_initiated"
    /// 会话过期
    case sessionExpired = "session_expired"
    /// 网络错误
    case networkError = "network_error"
    /// 服务器错误
    case serverError = "server_error"
    /// 被踢出
    case kicked = "kicked"
    /// Token 过期
    case tokenExpired = "token_expired"
    /// 应用错误
    case error = "error"
    /// 系统维护
    case maintenance = "maintenance"
    
    /// 获取登出原因的本地化显示名称
    public var displayName: String {
        switch self {
        case .userInitiated:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.user_initiated")
        case .sessionExpired:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.session_expired")
        case .networkError:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.network_error")
        case .serverError:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.server_error")
        case .kicked:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.kicked")
        case .tokenExpired:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.token_expired")
        case .error:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.error")
        case .maintenance:
            return ErrorLocalizationHelper.getLocalizedString(for: "logout.reason.maintenance")
        }
    }
    
    /// 检查是否为可恢复的登出原因
    public var isRecoverable: Bool {
        switch self {
        case .networkError, .serverError, .tokenExpired:
            return true
        case .userInitiated, .sessionExpired, .kicked, .error, .maintenance:
            return false
        }
    }
    
    /// 获取建议的重试延迟时间
    public var retryDelay: TimeInterval? {
        guard isRecoverable else { return nil }
        
        switch self {
        case .networkError:
            return 5.0
        case .serverError:
            return 10.0
        case .tokenExpired:
            return 2.0
        default:
            return nil
        }
    }
}

/// 用户权限检查结果
/// 需求: 4.2, 4.5 - 权限验证结果
public struct UserPermissionCheckResult: Sendable {
    /// 是否具有权限
    public let hasPermission: Bool
    
    /// 权限类型
    public let permission: UserPermission
    
    /// 用户角色
    public let userRole: UserRole
    
    /// 检查时间
    public let checkTime: Date
    
    /// 拒绝原因（如果没有权限）
    public let denialReason: String?
    
    /// 建议的替代权限（如果有）
    public let suggestedAlternatives: [UserPermission]
    
    public init(
        hasPermission: Bool,
        permission: UserPermission,
        userRole: UserRole,
        checkTime: Date = Date(),
        denialReason: String? = nil,
        suggestedAlternatives: [UserPermission] = []
    ) {
        self.hasPermission = hasPermission
        self.permission = permission
        self.userRole = userRole
        self.checkTime = checkTime
        self.denialReason = denialReason
        self.suggestedAlternatives = suggestedAlternatives
    }
}

/// 用户会话验证结果
/// 需求: 4.4, 4.5 - 会话状态验证
public struct UserSessionValidationResult: Sendable {
    /// 会话是否有效
    public let isValid: Bool
    
    /// 验证时间
    public let validationTime: Date
    
    /// 验证错误（如果有）
    public let validationErrors: [SessionValidationError]
    
    /// 会话统计信息
    public let sessionStats: UserSessionStats?
    
    /// 建议的修复操作
    public let suggestedActions: [SessionAction]
    
    public init(
        isValid: Bool,
        validationTime: Date = Date(),
        validationErrors: [SessionValidationError] = [],
        sessionStats: UserSessionStats? = nil,
        suggestedActions: [SessionAction] = []
    ) {
        self.isValid = isValid
        self.validationTime = validationTime
        self.validationErrors = validationErrors
        self.sessionStats = sessionStats
        self.suggestedActions = suggestedActions
    }
}

/// 会话验证错误
/// 需求: 4.5 - 会话状态验证错误
public enum SessionValidationError: String, CaseIterable, Error, Sendable {
    case sessionExpired = "session_expired"
    case userIdMismatch = "user_id_mismatch"
    case rolePermissionMismatch = "role_permission_mismatch"
    case deviceMismatch = "device_mismatch"
    case sessionCorrupted = "session_corrupted"
    case inactivityTimeout = "inactivity_timeout"
    
    public var localizedDescription: String {
        switch self {
        case .sessionExpired:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.validation.expired")
        case .userIdMismatch:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.validation.user_id_mismatch")
        case .rolePermissionMismatch:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.validation.role_permission_mismatch")
        case .deviceMismatch:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.validation.device_mismatch")
        case .sessionCorrupted:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.validation.corrupted")
        case .inactivityTimeout:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.validation.inactivity_timeout")
        }
    }
}

/// 建议的会话操作
/// 需求: 4.5 - 会话管理建议操作
public enum SessionAction: String, CaseIterable, Sendable {
    case refreshSession = "refresh_session"
    case relogin = "relogin"
    case switchRole = "switch_role"
    case updatePermissions = "update_permissions"
    case clearSession = "clear_session"
    case contactSupport = "contact_support"
    
    public var displayName: String {
        switch self {
        case .refreshSession:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.refresh")
        case .relogin:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.relogin")
        case .switchRole:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.switch_role")
        case .updatePermissions:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.update_permissions")
        case .clearSession:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.clear_session")
        case .contactSupport:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.contact_support")
        }
    }
    
    public var description: String {
        switch self {
        case .refreshSession:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.refresh.description")
        case .relogin:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.relogin.description")
        case .switchRole:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.switch_role.description")
        case .updatePermissions:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.update_permissions.description")
        case .clearSession:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.clear_session.description")
        case .contactSupport:
            return ErrorLocalizationHelper.getLocalizedString(for: "session.action.contact_support.description")
        }
    }
}

/// 角色权限比较结果
/// 需求: 4.2, 4.3 - 角色权限比较和切换
public struct RolePermissionComparison: Sendable {
    /// 源角色
    public let fromRole: UserRole
    
    /// 目标角色
    public let toRole: UserRole
    
    /// 获得的权限
    public let gainedPermissions: [UserPermission]
    
    /// 失去的权限
    public let lostPermissions: [UserPermission]
    
    /// 保持不变的权限
    public let unchangedPermissions: [UserPermission]
    
    /// 比较时间
    public let comparisonTime: Date
    
    public init(
        fromRole: UserRole,
        toRole: UserRole,
        gainedPermissions: [UserPermission],
        lostPermissions: [UserPermission],
        unchangedPermissions: [UserPermission],
        comparisonTime: Date = Date()
    ) {
        self.fromRole = fromRole
        self.toRole = toRole
        self.gainedPermissions = gainedPermissions
        self.lostPermissions = lostPermissions
        self.unchangedPermissions = unchangedPermissions
        self.comparisonTime = comparisonTime
    }
    
    /// 检查是否有权限变化
    public var hasPermissionChanges: Bool {
        return !gainedPermissions.isEmpty || !lostPermissions.isEmpty
    }
    
    /// 检查是否为权限升级
    public var isUpgrade: Bool {
        return gainedPermissions.count > lostPermissions.count
    }
    
    /// 检查是否为权限降级
    public var isDowngrade: Bool {
        return lostPermissions.count > gainedPermissions.count
    }
    
    /// 获取权限变化摘要
    public var changeSummary: String {
        if !hasPermissionChanges {
            return ErrorLocalizationHelper.getLocalizedString(for: "role.permission.no_changes")
        }
        
        var summary = ""
        
        if !gainedPermissions.isEmpty {
            let gainedNames = gainedPermissions.map { $0.displayName }.joined(separator: ", ")
            summary += ErrorLocalizationHelper.getLocalizedString(
                for: "role.permission.gained",
                arguments: [gainedNames],
                fallbackValue: "Gained permissions: \(gainedNames)"
            )
        }
        
        if !lostPermissions.isEmpty {
            if !summary.isEmpty { summary += "\n" }
            let lostNames = lostPermissions.map { $0.displayName }.joined(separator: ", ")
            summary += ErrorLocalizationHelper.getLocalizedString(
                for: "role.permission.lost",
                arguments: [lostNames],
                fallbackValue: "Lost permissions: \(lostNames)"
            )
        }
        
        return summary
    }
}

/// 扩展通知名称以支持用户会话事件
/// 需求: 4.5, 17.6 - 会话事件通知
extension Notification.Name {
    public static let userDidLogin = Notification.Name("RealtimeKit.userDidLogin")
    public static let userDidLogout = Notification.Name("RealtimeKit.userDidLogout")
    public static let userRoleDidChange = Notification.Name("RealtimeKit.userRoleDidChange")
    public static let userPermissionDenied = Notification.Name("RealtimeKit.userPermissionDenied")
    public static let sessionDidExpire = Notification.Name("RealtimeKit.sessionDidExpire")
    public static let sessionValidationFailed = Notification.Name("RealtimeKit.sessionValidationFailed")
}