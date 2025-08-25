import Foundation

/// RealtimeCore 模块的主要导出文件
/// 提供核心协议、数据模型和基础功能
/// 需求: 1.1, 1.2, 1.3, 12.1, 12.2

// MARK: - 错误类型
public enum RealtimeError: Error, LocalizedError, Sendable, Equatable {
    // MARK: - Configuration Errors
    case configurationError(String)
    case providerNotAvailable(ProviderType)
    case invalidParameter(String)
    case invalidConfiguration(details: String?)
    
    // MARK: - Connection Errors
    case connectionError(String)
    case networkError(String)
    case connectionTimeout
    case connectionFailed(reason: String?)
    case networkUnavailable
    
    // MARK: - Authentication Errors
    case authenticationError(String)
    case tokenExpired
    case tokenRenewalFailed(reason: String?)
    case invalidToken
    
    // MARK: - Permission Errors
    case insufficientPermissions(UserRole)
    case permissionDenied(permission: String?)
    case invalidRoleTransition(from: UserRole, to: UserRole)
    
    // MARK: - Session Errors
    case noActiveSession
    case sessionAlreadyActive
    case userAlreadyInRoom
    case roomNotFound(roomId: String)
    case userNotFound(userId: String)
    
    // MARK: - Audio/Video Errors
    case audioDeviceUnavailable
    case microphonePermissionDenied
    case audioStreamFailed(reason: String?)
    case volumeDetectionFailed
    
    // MARK: - Stream Push Errors
    case streamPushNotSupported
    case streamPushConfigurationInvalid
    case streamPushFailed(reason: String?)
    case streamPushAlreadyActive
    
    // MARK: - Media Relay Errors
    case mediaRelayNotSupported
    case mediaRelayConfigurationInvalid
    case mediaRelayFailed(reason: String?)
    case mediaRelayChannelLimitExceeded
    
    // MARK: - Message Processing Errors
    case processorAlreadyRegistered(String)
    case processorNotFound(messageType: String)
    case messageProcessingFailed(reason: String?)
    case invalidMessageFormat
    
    // MARK: - Generic Errors
    case unknown(reason: String?)
    case operationCancelled
    case operationTimeout
    case internalError(code: Int, description: String?)
    
    // MARK: - LocalizedError Protocol Implementation
    public var errorDescription: String? {
        return getLocalizedErrorDescription()
    }
    
    public var failureReason: String? {
        return getLocalizedFailureReason()
    }
    
    public var recoverySuggestion: String? {
        return getLocalizedRecoverySuggestion()
    }
    
    // MARK: - Error Recovery Properties
    
    /// Check if this error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .connectionTimeout, .connectionFailed,
             .tokenExpired, .tokenRenewalFailed,
             .audioDeviceUnavailable, .audioStreamFailed,
             .streamPushFailed, .mediaRelayFailed,
             .volumeDetectionFailed, .messageProcessingFailed:
            return true
        case .configurationError, .providerNotAvailable, .invalidParameter, .invalidConfiguration,
             .authenticationError, .invalidToken,
             .insufficientPermissions, .permissionDenied, .invalidRoleTransition,
             .sessionAlreadyActive, .streamPushNotSupported, .mediaRelayNotSupported,
             .processorAlreadyRegistered, .invalidMessageFormat,
             .operationCancelled, .internalError:
            return false
        case .connectionError, .networkError, .noActiveSession, .userAlreadyInRoom,
             .roomNotFound, .userNotFound, .microphonePermissionDenied,
             .streamPushConfigurationInvalid, .mediaRelayConfigurationInvalid,
             .streamPushAlreadyActive, .mediaRelayChannelLimitExceeded,
             .processorNotFound, .unknown, .operationTimeout:
            return true
        }
    }
    
    /// Get suggested retry delay for recoverable errors
    public var retryDelay: TimeInterval? {
        guard isRecoverable else { return nil }
        
        switch self {
        case .networkUnavailable, .connectionTimeout:
            return 5.0
        case .connectionFailed, .connectionError, .networkError:
            return 3.0
        case .tokenExpired, .tokenRenewalFailed:
            return 1.0
        case .audioDeviceUnavailable, .audioStreamFailed:
            return 2.0
        case .streamPushFailed, .mediaRelayFailed:
            return 5.0
        case .volumeDetectionFailed, .messageProcessingFailed:
            return 2.0
        case .operationTimeout:
            return 1.0
        default:
            return 3.0
        }
    }
    
    /// Get error category for analytics/logging
    public var category: ErrorCategory {
        switch self {
        case .networkUnavailable, .connectionTimeout, .connectionFailed, .connectionError, .networkError:
            return .network
        case .insufficientPermissions, .permissionDenied, .invalidRoleTransition, .microphonePermissionDenied:
            return .permission
        case .configurationError, .providerNotAvailable, .invalidParameter, .invalidConfiguration,
             .authenticationError, .tokenExpired, .tokenRenewalFailed, .invalidToken:
            return .configuration
        case .noActiveSession, .sessionAlreadyActive, .userAlreadyInRoom, .roomNotFound, .userNotFound:
            return .session
        case .audioDeviceUnavailable, .audioStreamFailed, .volumeDetectionFailed:
            return .audio
        case .streamPushNotSupported, .streamPushConfigurationInvalid, .streamPushFailed, .streamPushAlreadyActive:
            return .streamPush
        case .mediaRelayNotSupported, .mediaRelayConfigurationInvalid, .mediaRelayFailed, .mediaRelayChannelLimitExceeded:
            return .mediaRelay
        case .processorAlreadyRegistered, .processorNotFound, .messageProcessingFailed, .invalidMessageFormat:
            return .messageProcessing
        case .unknown, .operationCancelled, .operationTimeout, .internalError:
            return .system
        }
    }
    
    /// Get error severity level
    public var severity: ErrorSeverity {
        switch self {
        case .configurationError, .providerNotAvailable, .invalidConfiguration,
             .authenticationError, .invalidToken,
             .insufficientPermissions, .permissionDenied,
             .streamPushNotSupported, .mediaRelayNotSupported,
             .internalError:
            return .critical
        case .connectionError, .networkError, .connectionFailed,
             .tokenExpired, .tokenRenewalFailed,
             .invalidRoleTransition, .sessionAlreadyActive,
             .audioDeviceUnavailable, .microphonePermissionDenied,
             .streamPushFailed, .mediaRelayFailed,
             .processorAlreadyRegistered, .invalidMessageFormat:
            return .high
        case .networkUnavailable, .connectionTimeout,
             .noActiveSession, .userAlreadyInRoom, .roomNotFound, .userNotFound,
             .audioStreamFailed, .volumeDetectionFailed,
             .streamPushConfigurationInvalid, .streamPushAlreadyActive,
             .mediaRelayConfigurationInvalid, .mediaRelayChannelLimitExceeded,
             .processorNotFound, .messageProcessingFailed,
             .operationTimeout:
            return .medium
        case .invalidParameter, .operationCancelled, .unknown:
            return .low
        }
    }
    
    // MARK: - Private Localization Methods
    
    private func getLocalizedErrorDescription() -> String {
        let key = localizationKey
        let arguments = localizationArguments
        return ErrorLocalizationHelper.getLocalizedString(for: key, arguments: arguments, fallbackValue: fallbackDescription)
    }
    
    private func getLocalizedFailureReason() -> String? {
        let reasonKey = localizationKey + ".reason"
        let localizedReason = ErrorLocalizationHelper.getLocalizedString(for: reasonKey, fallbackValue: nil)
        return localizedReason != reasonKey ? localizedReason : nil
    }
    
    private func getLocalizedRecoverySuggestion() -> String? {
        let suggestionKey = localizationKey + ".suggestion"
        let localizedSuggestion = ErrorLocalizationHelper.getLocalizedString(for: suggestionKey, fallbackValue: nil)
        return localizedSuggestion != suggestionKey ? localizedSuggestion : nil
    }
    
    private var localizationKey: String {
        switch self {
        // Configuration Errors
        case .configurationError:
            return "error.configuration"
        case .providerNotAvailable:
            return "error.provider.unavailable"
        case .invalidParameter:
            return "error.invalid.parameter"
        case .invalidConfiguration:
            return "error.invalid.configuration"
            
        // Connection Errors
        case .connectionError:
            return "error.connection"
        case .networkError:
            return "error.network"
        case .connectionTimeout:
            return "error.connection.timeout"
        case .connectionFailed:
            return "error.connection.failed"
        case .networkUnavailable:
            return "error.network.unavailable"
            
        // Authentication Errors
        case .authenticationError:
            return "error.authentication"
        case .tokenExpired:
            return "error.token.expired"
        case .tokenRenewalFailed:
            return "error.token.renewal.failed"
        case .invalidToken:
            return "error.invalid.token"
            
        // Permission Errors
        case .insufficientPermissions:
            return "error.insufficient.permissions"
        case .permissionDenied:
            return "error.permission.denied"
        case .invalidRoleTransition:
            return "error.invalid.role.transition"
            
        // Session Errors
        case .noActiveSession:
            return "error.no.active.session"
        case .sessionAlreadyActive:
            return "error.session.already.active"
        case .userAlreadyInRoom:
            return "error.user.already.in.room"
        case .roomNotFound:
            return "error.room.not.found"
        case .userNotFound:
            return "error.user.not.found"
            
        // Audio/Video Errors
        case .audioDeviceUnavailable:
            return "error.audio.device.unavailable"
        case .microphonePermissionDenied:
            return "error.microphone.permission.denied"
        case .audioStreamFailed:
            return "error.audio.stream.failed"
        case .volumeDetectionFailed:
            return "error.volume.detection.failed"
            
        // Stream Push Errors
        case .streamPushNotSupported:
            return "error.stream.push.not.supported"
        case .streamPushConfigurationInvalid:
            return "error.stream.push.configuration.invalid"
        case .streamPushFailed:
            return "error.stream.push.failed"
        case .streamPushAlreadyActive:
            return "error.stream.push.already.active"
            
        // Media Relay Errors
        case .mediaRelayNotSupported:
            return "error.media.relay.not.supported"
        case .mediaRelayConfigurationInvalid:
            return "error.media.relay.configuration.invalid"
        case .mediaRelayFailed:
            return "error.media.relay.failed"
        case .mediaRelayChannelLimitExceeded:
            return "error.media.relay.channel.limit.exceeded"
            
        // Message Processing Errors
        case .processorAlreadyRegistered:
            return "error.processor.already.registered"
        case .processorNotFound:
            return "error.processor.not.found"
        case .messageProcessingFailed:
            return "error.message.processing.failed"
        case .invalidMessageFormat:
            return "error.invalid.message.format"
            
        // Generic Errors
        case .unknown:
            return "error.unknown"
        case .operationCancelled:
            return "error.operation.cancelled"
        case .operationTimeout:
            return "error.operation.timeout"
        case .internalError:
            return "error.internal"
        }
    }
    
    private var localizationArguments: [CVarArg] {
        switch self {
        case .configurationError(let message):
            return [message]
        case .providerNotAvailable(let provider):
            return [provider.displayName]
        case .invalidParameter(let message):
            return [message]
        case .invalidConfiguration(let details):
            return details != nil ? [details!] : []
        case .connectionError(let message):
            return [message]
        case .networkError(let message):
            return [message]
        case .connectionFailed(let reason):
            return reason != nil ? [reason!] : []
        case .authenticationError(let message):
            return [message]
        case .tokenRenewalFailed(let reason):
            return reason != nil ? [reason!] : []
        case .insufficientPermissions(let role):
            return [role.displayName]
        case .permissionDenied(let permission):
            return permission != nil ? [permission!] : []
        case .invalidRoleTransition(let from, let to):
            return [from.displayName, to.displayName]
        case .roomNotFound(let roomId):
            return [roomId]
        case .userNotFound(let userId):
            return [userId]
        case .audioStreamFailed(let reason):
            return reason != nil ? [reason!] : []
        case .streamPushFailed(let reason):
            return reason != nil ? [reason!] : []
        case .mediaRelayFailed(let reason):
            return reason != nil ? [reason!] : []
        case .processorAlreadyRegistered(let messageType):
            return [messageType]
        case .processorNotFound(let messageType):
            return [messageType]
        case .messageProcessingFailed(let reason):
            return reason != nil ? [reason!] : []
        case .unknown(let reason):
            return reason != nil ? [reason!] : []
        case .internalError(let code, let description):
            return description != nil ? [code, description!] : [code]
        default:
            return []
        }
    }
    
    private var fallbackDescription: String {
        switch self {
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .providerNotAvailable(let provider):
            return "Provider not available: \(provider.displayName)"
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .invalidConfiguration(let details):
            return "Invalid configuration" + (details != nil ? ": \(details!)" : "")
        case .connectionError(let message):
            return "Connection error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .connectionTimeout:
            return "Connection timeout"
        case .connectionFailed(let reason):
            return "Connection failed" + (reason != nil ? ": \(reason!)" : "")
        case .networkUnavailable:
            return "Network unavailable"
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        case .tokenExpired:
            return "Token expired"
        case .tokenRenewalFailed(let reason):
            return "Token renewal failed" + (reason != nil ? ": \(reason!)" : "")
        case .invalidToken:
            return "Invalid token"
        case .insufficientPermissions(let role):
            return "Insufficient permissions for role: \(role.displayName)"
        case .permissionDenied(let permission):
            return "Permission denied" + (permission != nil ? ": \(permission!)" : "")
        case .invalidRoleTransition(let from, let to):
            return "Invalid role transition from \(from.displayName) to \(to.displayName)"
        case .noActiveSession:
            return "No active session"
        case .sessionAlreadyActive:
            return "Session already active"
        case .userAlreadyInRoom:
            return "User already in room"
        case .roomNotFound(let roomId):
            return "Room not found: \(roomId)"
        case .userNotFound(let userId):
            return "User not found: \(userId)"
        case .audioDeviceUnavailable:
            return "Audio device unavailable"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .audioStreamFailed(let reason):
            return "Audio stream failed" + (reason != nil ? ": \(reason!)" : "")
        case .volumeDetectionFailed:
            return "Volume detection failed"
        case .streamPushNotSupported:
            return "Stream push not supported"
        case .streamPushConfigurationInvalid:
            return "Stream push configuration invalid"
        case .streamPushFailed(let reason):
            return "Stream push failed" + (reason != nil ? ": \(reason!)" : "")
        case .streamPushAlreadyActive:
            return "Stream push already active"
        case .mediaRelayNotSupported:
            return "Media relay not supported"
        case .mediaRelayConfigurationInvalid:
            return "Media relay configuration invalid"
        case .mediaRelayFailed(let reason):
            return "Media relay failed" + (reason != nil ? ": \(reason!)" : "")
        case .mediaRelayChannelLimitExceeded:
            return "Media relay channel limit exceeded"
        case .processorAlreadyRegistered(let messageType):
            return "Processor already registered: \(messageType)"
        case .processorNotFound(let messageType):
            return "Processor not found: \(messageType)"
        case .messageProcessingFailed(let reason):
            return "Message processing failed" + (reason != nil ? ": \(reason!)" : "")
        case .invalidMessageFormat:
            return "Invalid message format"
        case .unknown(let reason):
            return "Unknown error" + (reason != nil ? ": \(reason!)" : "")
        case .operationCancelled:
            return "Operation cancelled"
        case .operationTimeout:
            return "Operation timeout"
        case .internalError(let code, let description):
            return "Internal error (\(code))" + (description != nil ? ": \(description!)" : "")
        }
    }
    
    // MARK: - Equatable Implementation
    public static func == (lhs: RealtimeError, rhs: RealtimeError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationError(let lhsMessage), .configurationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.providerNotAvailable(let lhsProvider), .providerNotAvailable(let rhsProvider)):
            return lhsProvider == rhsProvider
        case (.invalidParameter(let lhsMessage), .invalidParameter(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidConfiguration(let lhsDetails), .invalidConfiguration(let rhsDetails)):
            return lhsDetails == rhsDetails
        case (.connectionError(let lhsMessage), .connectionError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.connectionTimeout, .connectionTimeout):
            return true
        case (.connectionFailed(let lhsReason), .connectionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.authenticationError(let lhsMessage), .authenticationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.tokenExpired, .tokenExpired):
            return true
        case (.tokenRenewalFailed(let lhsReason), .tokenRenewalFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.invalidToken, .invalidToken):
            return true
        case (.insufficientPermissions(let lhsRole), .insufficientPermissions(let rhsRole)):
            return lhsRole == rhsRole
        case (.permissionDenied(let lhsPermission), .permissionDenied(let rhsPermission)):
            return lhsPermission == rhsPermission
        case (.invalidRoleTransition(let lhsFrom, let lhsTo), .invalidRoleTransition(let rhsFrom, let rhsTo)):
            return lhsFrom == rhsFrom && lhsTo == rhsTo
        case (.noActiveSession, .noActiveSession):
            return true
        case (.sessionAlreadyActive, .sessionAlreadyActive):
            return true
        case (.userAlreadyInRoom, .userAlreadyInRoom):
            return true
        case (.roomNotFound(let lhsRoomId), .roomNotFound(let rhsRoomId)):
            return lhsRoomId == rhsRoomId
        case (.userNotFound(let lhsUserId), .userNotFound(let rhsUserId)):
            return lhsUserId == rhsUserId
        case (.audioDeviceUnavailable, .audioDeviceUnavailable):
            return true
        case (.microphonePermissionDenied, .microphonePermissionDenied):
            return true
        case (.audioStreamFailed(let lhsReason), .audioStreamFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.volumeDetectionFailed, .volumeDetectionFailed):
            return true
        case (.streamPushNotSupported, .streamPushNotSupported):
            return true
        case (.streamPushConfigurationInvalid, .streamPushConfigurationInvalid):
            return true
        case (.streamPushFailed(let lhsReason), .streamPushFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.streamPushAlreadyActive, .streamPushAlreadyActive):
            return true
        case (.mediaRelayNotSupported, .mediaRelayNotSupported):
            return true
        case (.mediaRelayConfigurationInvalid, .mediaRelayConfigurationInvalid):
            return true
        case (.mediaRelayFailed(let lhsReason), .mediaRelayFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.mediaRelayChannelLimitExceeded, .mediaRelayChannelLimitExceeded):
            return true
        case (.processorAlreadyRegistered(let lhsType), .processorAlreadyRegistered(let rhsType)):
            return lhsType == rhsType
        case (.processorNotFound(let lhsType), .processorNotFound(let rhsType)):
            return lhsType == rhsType
        case (.messageProcessingFailed(let lhsReason), .messageProcessingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.invalidMessageFormat, .invalidMessageFormat):
            return true
        case (.unknown(let lhsReason), .unknown(let rhsReason)):
            return lhsReason == rhsReason
        case (.operationCancelled, .operationCancelled):
            return true
        case (.operationTimeout, .operationTimeout):
            return true
        case (.internalError(let lhsCode, let lhsDescription), .internalError(let rhsCode, let rhsDescription)):
            return lhsCode == rhsCode && lhsDescription == rhsDescription
        default:
            return false
        }
    }
}

// MARK: - Error Categories and Severity

/// Error categories for classification
public enum ErrorCategory: String, CaseIterable, Codable, Sendable {
    case network = "network"
    case permission = "permission"
    case configuration = "configuration"
    case session = "session"
    case audio = "audio"
    case streamPush = "stream_push"
    case mediaRelay = "media_relay"
    case messageProcessing = "message_processing"
    case localization = "localization"
    case system = "system"
}

/// Error severity levels
public enum ErrorSeverity: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        case .critical:
            return "严重"
        }
    }
}

// MARK: - 服务商类型
public enum ProviderType: String, CaseIterable, Codable, Sendable {
    case agora = "agora"
    case tencent = "tencent"
    case zego = "zego"
    case mock = "mock"
    
    public var displayName: String {
        switch self {
        case .agora:
            return "声网 Agora"
        case .tencent:
            return "腾讯云 TRTC"
        case .zego:
            return "即构 ZEGO"
        case .mock:
            return "模拟服务商"
        }
    }
}

// MARK: - 连接状态
public enum ConnectionState: String, CaseIterable, Codable, Sendable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .disconnected:
            return "已断开"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .reconnecting:
            return "重连中"
        case .failed:
            return "连接失败"
        }
    }
}

// MARK: - 推流状态
public enum StreamPushState: String, CaseIterable, Codable, Sendable {
    case stopped = "stopped"
    case starting = "starting"
    case running = "running"
    case stopping = "stopping"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .stopped:
            return "已停止"
        case .starting:
            return "启动中"
        case .running:
            return "运行中"
        case .stopping:
            return "停止中"
        case .failed:
            return "推流失败"
        }
    }
}

// MARK: - 媒体中继状态
public enum MediaRelayState: String, CaseIterable, Codable, Sendable {
    case stopped = "stopped"
    case starting = "starting"
    case running = "running"
    case stopping = "stopping"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .stopped:
            return "已停止"
        case .starting:
            return "启动中"
        case .running:
            return "运行中"
        case .stopping:
            return "停止中"
        case .failed:
            return "中继失败"
        }
    }
}

// MARK: - 音量事件 (已移动到 VolumeModels.swift)

// MARK: - 版本信息
public struct RealtimeKitVersion: Sendable {
    public static let current = "1.0.0"
    public static let buildNumber = "1"
    public static let swiftVersion = "6.2"
}