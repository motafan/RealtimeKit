// RealtimeError.swift
// Comprehensive error handling for RealtimeKit

import Foundation

/// Comprehensive error types for RealtimeKit
public enum RealtimeError: Error, LocalizedError, Equatable {
    
    // MARK: - Configuration Errors
    case configurationError(String)
    case invalidConfiguration(String)
    case missingConfiguration(String)
    
    // MARK: - Connection Errors
    case connectionFailed(String)
    case connectionTimeout
    case networkError(String)
    case networkTimeout
    case authenticationFailed
    case noActiveSession
    
    // MARK: - Token Management Errors
    case tokenExpired(ProviderType)
    case tokenRenewalFailed(ProviderType, String)
    case invalidToken(ProviderType)
    case tokenNotProvided(ProviderType)
    
    // MARK: - Room Management Errors
    case roomCreationFailed(String)
    case roomJoinFailed(String)
    case roomLeaveFailed(String)
    case roomNotFound(String)
    case roomCapacityExceeded(String)
    case userRoleSwitchFailed(String)
    
    // MARK: - Audio Control Errors
    case audioControlFailed(String)
    case microphonePermissionDenied
    case audioStreamControlFailed(String)
    case volumeControlFailed(String)
    case audioSettingsInvalid(String)
    
    // MARK: - Stream Push Errors
    case streamPushStartFailed(String)
    case streamPushStopFailed(String)
    case streamPushUpdateFailed(String)
    case invalidStreamConfig(String)
    case streamLayoutUpdateFailed(String)
    
    // MARK: - Media Relay Errors
    case mediaRelayStartFailed(String)
    case mediaRelayStopFailed(String)
    case mediaRelayUpdateFailed(String)
    case invalidMediaRelayConfig(String)
    case relayChannelConnectionFailed(String)
    case relayChannelNotFound(String)
    case mediaRelayPauseFailed(String)
    case mediaRelayResumeFailed(String)
    
    // MARK: - Volume Indicator Errors
    case volumeIndicatorStartFailed(String)
    case volumeIndicatorStopFailed(String)
    case invalidVolumeConfig(String)
    case volumeDetectionFailed(String)
    
    // MARK: - Message Processing Errors
    case messageProcessingFailed(String)
    case unsupportedMessageType(String)
    case messageHandlerNotFound
    case messageSendFailed(String)
    case messageSubscriptionFailed(String)
    
    // MARK: - Provider Errors
    case providerNotInitialized(ProviderType)
    case providerAlreadyInitialized(ProviderType)
    case providerInitializationFailed(ProviderType, String)
    case unsupportedProvider(String)
    case providerSwitchFailed(String)
    case providerNotAvailable(ProviderType)
    case configurationMissing
    case operationInProgress(String)
    case operationFailed(ProviderType, String)
    case insufficientPermissions(UserRole)
    case invalidRoleTransition(from: UserRole, to: UserRole)
    case notLoggedIn(ProviderType)
    case invalidMessageFormat(ProviderType, String)
    
    // MARK: - Storage Errors
    case storageError(String)
    case dataCorrupted(String)
    case storagePermissionDenied
    
    // MARK: - Validation Errors
    case invalidParameter(String)
    case parameterOutOfRange(String, String)
    case requiredParameterMissing(String)
    case invalidChannelName(String)
    case invalidUserId(String)
    case invalidTokenString(String)
    
    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        // Configuration Errors
        case .configurationError(let message):
            return "配置错误: \(message)"
        case .invalidConfiguration(let message):
            return "无效配置: \(message)"
        case .missingConfiguration(let message):
            return "缺少配置: \(message)"
            
        // Connection Errors
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        case .connectionTimeout:
            return "连接超时"
        case .networkTimeout:
            return "网络超时"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .authenticationFailed:
            return "身份验证失败"
        case .noActiveSession:
            return "没有活跃的用户会话"
            
        // Token Management Errors
        case .tokenExpired(let provider):
            return "\(provider.displayName) Token 已过期"
        case .tokenRenewalFailed(let provider, let message):
            return "\(provider.displayName) Token 续期失败: \(message)"
        case .invalidToken(let provider):
            return "\(provider.displayName) Token 无效"
        case .tokenNotProvided(let provider):
            return "\(provider.displayName) 未提供 Token"
            
        // Room Management Errors
        case .roomCreationFailed(let message):
            return "房间创建失败: \(message)"
        case .roomJoinFailed(let message):
            return "加入房间失败: \(message)"
        case .roomLeaveFailed(let message):
            return "离开房间失败: \(message)"
        case .roomNotFound(let roomId):
            return "房间不存在: \(roomId)"
        case .roomCapacityExceeded(let message):
            return "房间人数已满: \(message)"
        case .userRoleSwitchFailed(let message):
            return "用户角色切换失败: \(message)"
            
        // Audio Control Errors
        case .audioControlFailed(let message):
            return "音频控制失败: \(message)"
        case .microphonePermissionDenied:
            return "麦克风权限被拒绝"
        case .audioStreamControlFailed(let message):
            return "音频流控制失败: \(message)"
        case .volumeControlFailed(let message):
            return "音量控制失败: \(message)"
        case .audioSettingsInvalid(let message):
            return "音频设置无效: \(message)"
            
        // Stream Push Errors
        case .streamPushStartFailed(let message):
            return "转推流启动失败: \(message)"
        case .streamPushStopFailed(let message):
            return "转推流停止失败: \(message)"
        case .streamPushUpdateFailed(let message):
            return "转推流更新失败: \(message)"
        case .invalidStreamConfig(let message):
            return "转推流配置无效: \(message)"
        case .streamLayoutUpdateFailed(let message):
            return "转推流布局更新失败: \(message)"
            
        // Media Relay Errors
        case .mediaRelayStartFailed(let message):
            return "媒体中继启动失败: \(message)"
        case .mediaRelayStopFailed(let message):
            return "媒体中继停止失败: \(message)"
        case .mediaRelayUpdateFailed(let message):
            return "媒体中继更新失败: \(message)"
        case .invalidMediaRelayConfig(let message):
            return "媒体中继配置无效: \(message)"
        case .relayChannelConnectionFailed(let channel):
            return "中继频道连接失败: \(channel)"
        case .relayChannelNotFound(let channel):
            return "中继频道不存在: \(channel)"
        case .mediaRelayPauseFailed(let message):
            return "媒体中继暂停失败: \(message)"
        case .mediaRelayResumeFailed(let message):
            return "媒体中继恢复失败: \(message)"
            
        // Volume Indicator Errors
        case .volumeIndicatorStartFailed(let message):
            return "音量指示器启动失败: \(message)"
        case .volumeIndicatorStopFailed(let message):
            return "音量指示器停止失败: \(message)"
        case .invalidVolumeConfig(let message):
            return "音量检测配置无效: \(message)"
        case .volumeDetectionFailed(let message):
            return "音量检测失败: \(message)"
            
        // Message Processing Errors
        case .messageProcessingFailed(let message):
            return "消息处理失败: \(message)"
        case .unsupportedMessageType(let type):
            return "不支持的消息类型: \(type)"
        case .messageHandlerNotFound:
            return "未找到消息处理器"
        case .messageSendFailed(let message):
            return "消息发送失败: \(message)"
        case .messageSubscriptionFailed(let message):
            return "消息订阅失败: \(message)"
            
        // Provider Errors
        case .providerNotInitialized(let provider):
            return "\(provider.displayName) 提供商未初始化"
        case .providerAlreadyInitialized(let provider):
            return "\(provider.displayName) 提供商已初始化"
        case .providerInitializationFailed(let provider, let message):
            return "\(provider.displayName) 初始化失败: \(message)"
        case .unsupportedProvider(let provider):
            return "不支持的提供商: \(provider)"
        case .providerSwitchFailed(let message):
            return "提供商切换失败: \(message)"
        case .providerNotAvailable(let provider):
            return "提供商不可用: \(provider.displayName)"
        case .configurationMissing:
            return "缺少配置信息"
        case .operationInProgress(let operation):
            return "操作正在进行中: \(operation)"
        case .operationFailed(let provider, let message):
            return "\(provider.displayName) 操作失败: \(message)"
        case .insufficientPermissions(let role):
            return "权限不足: \(role.displayName)"
        case .invalidRoleTransition(let from, let to):
            return "无效的角色转换: 从 \(from.displayName) 到 \(to.displayName)"
        case .notLoggedIn(let provider):
            return "\(provider.displayName) 未登录"
        case .invalidMessageFormat(let provider, let message):
            return "\(provider.displayName) 消息格式无效: \(message)"
            
        // Storage Errors
        case .storageError(let message):
            return "存储错误: \(message)"
        case .dataCorrupted(let message):
            return "数据损坏: \(message)"
        case .storagePermissionDenied:
            return "存储权限被拒绝"
            
        // Validation Errors
        case .invalidParameter(let parameter):
            return "无效参数: \(parameter)"
        case .parameterOutOfRange(let parameter, let range):
            return "参数超出范围: \(parameter) (\(range))"
        case .requiredParameterMissing(let parameter):
            return "缺少必需参数: \(parameter)"
        case .invalidChannelName(let message):
            return "无效的频道名称: \(message)"
        case .invalidUserId(let message):
            return "无效的用户ID: \(message)"
        case .invalidTokenString(let message):
            return "无效的Token: \(message)"
        }
    }
    
    /// Error code for programmatic handling
    public var errorCode: String {
        switch self {
        case .configurationError: return "CONFIG_ERROR"
        case .invalidConfiguration: return "INVALID_CONFIG"
        case .missingConfiguration: return "MISSING_CONFIG"
        case .connectionFailed: return "CONNECTION_FAILED"
        case .connectionTimeout: return "CONNECTION_TIMEOUT"
        case .networkTimeout: return "NETWORK_TIMEOUT"
        case .networkError: return "NETWORK_ERROR"
        case .authenticationFailed: return "AUTH_FAILED"
        case .noActiveSession: return "NO_ACTIVE_SESSION"
        case .tokenExpired: return "TOKEN_EXPIRED"
        case .tokenRenewalFailed: return "TOKEN_RENEWAL_FAILED"
        case .invalidToken: return "INVALID_TOKEN"
        case .tokenNotProvided: return "TOKEN_NOT_PROVIDED"
        case .roomCreationFailed: return "ROOM_CREATION_FAILED"
        case .roomJoinFailed: return "ROOM_JOIN_FAILED"
        case .roomLeaveFailed: return "ROOM_LEAVE_FAILED"
        case .roomNotFound: return "ROOM_NOT_FOUND"
        case .roomCapacityExceeded: return "ROOM_CAPACITY_EXCEEDED"
        case .userRoleSwitchFailed: return "USER_ROLE_SWITCH_FAILED"
        case .audioControlFailed: return "AUDIO_CONTROL_FAILED"
        case .microphonePermissionDenied: return "MICROPHONE_PERMISSION_DENIED"
        case .audioStreamControlFailed: return "AUDIO_STREAM_CONTROL_FAILED"
        case .volumeControlFailed: return "VOLUME_CONTROL_FAILED"
        case .audioSettingsInvalid: return "AUDIO_SETTINGS_INVALID"
        case .streamPushStartFailed: return "STREAM_PUSH_START_FAILED"
        case .streamPushStopFailed: return "STREAM_PUSH_STOP_FAILED"
        case .streamPushUpdateFailed: return "STREAM_PUSH_UPDATE_FAILED"
        case .invalidStreamConfig: return "INVALID_STREAM_CONFIG"
        case .streamLayoutUpdateFailed: return "STREAM_LAYOUT_UPDATE_FAILED"
        case .mediaRelayStartFailed: return "MEDIA_RELAY_START_FAILED"
        case .mediaRelayStopFailed: return "MEDIA_RELAY_STOP_FAILED"
        case .mediaRelayUpdateFailed: return "MEDIA_RELAY_UPDATE_FAILED"
        case .invalidMediaRelayConfig: return "INVALID_MEDIA_RELAY_CONFIG"
        case .relayChannelConnectionFailed: return "RELAY_CHANNEL_CONNECTION_FAILED"
        case .relayChannelNotFound: return "RELAY_CHANNEL_NOT_FOUND"
        case .mediaRelayPauseFailed: return "MEDIA_RELAY_PAUSE_FAILED"
        case .mediaRelayResumeFailed: return "MEDIA_RELAY_RESUME_FAILED"
        case .volumeIndicatorStartFailed: return "VOLUME_INDICATOR_START_FAILED"
        case .volumeIndicatorStopFailed: return "VOLUME_INDICATOR_STOP_FAILED"
        case .invalidVolumeConfig: return "INVALID_VOLUME_CONFIG"
        case .volumeDetectionFailed: return "VOLUME_DETECTION_FAILED"
        case .messageProcessingFailed: return "MESSAGE_PROCESSING_FAILED"
        case .unsupportedMessageType: return "UNSUPPORTED_MESSAGE_TYPE"
        case .messageHandlerNotFound: return "MESSAGE_HANDLER_NOT_FOUND"
        case .messageSendFailed: return "MESSAGE_SEND_FAILED"
        case .messageSubscriptionFailed: return "MESSAGE_SUBSCRIPTION_FAILED"
        case .providerNotInitialized: return "PROVIDER_NOT_INITIALIZED"
        case .providerAlreadyInitialized: return "PROVIDER_ALREADY_INITIALIZED"
        case .providerInitializationFailed: return "PROVIDER_INITIALIZATION_FAILED"
        case .unsupportedProvider: return "UNSUPPORTED_PROVIDER"
        case .providerSwitchFailed: return "PROVIDER_SWITCH_FAILED"
        case .providerNotAvailable: return "PROVIDER_NOT_AVAILABLE"
        case .configurationMissing: return "CONFIGURATION_MISSING"
        case .operationInProgress: return "OPERATION_IN_PROGRESS"
        case .operationFailed: return "OPERATION_FAILED"
        case .insufficientPermissions: return "INSUFFICIENT_PERMISSIONS"
        case .invalidRoleTransition: return "INVALID_ROLE_TRANSITION"
        case .notLoggedIn: return "NOT_LOGGED_IN"
        case .invalidMessageFormat: return "INVALID_MESSAGE_FORMAT"
        case .storageError: return "STORAGE_ERROR"
        case .dataCorrupted: return "DATA_CORRUPTED"
        case .storagePermissionDenied: return "STORAGE_PERMISSION_DENIED"
        case .invalidParameter: return "INVALID_PARAMETER"
        case .parameterOutOfRange: return "PARAMETER_OUT_OF_RANGE"
        case .requiredParameterMissing: return "REQUIRED_PARAMETER_MISSING"
        case .invalidChannelName: return "INVALID_CHANNEL_NAME"
        case .invalidUserId: return "INVALID_USER_ID"
        case .invalidTokenString: return "INVALID_TOKEN_STRING"
        }
    }
    
    /// Whether this error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .connectionTimeout, .networkError, .tokenExpired, .tokenRenewalFailed:
            return true
        case .authenticationFailed, .invalidToken, .microphonePermissionDenied, .storagePermissionDenied:
            return false
        default:
            return true
        }
    }
    
    /// Severity level of the error
    public var severity: ErrorSeverity {
        switch self {
        case .authenticationFailed, .invalidToken, .storagePermissionDenied, .microphonePermissionDenied:
            return .critical
        case .connectionFailed, .networkError, .providerInitializationFailed, .roomJoinFailed:
            return .high
        case .connectionTimeout, .tokenExpired, .volumeControlFailed, .audioControlFailed:
            return .medium
        case .invalidParameter, .parameterOutOfRange, .audioSettingsInvalid:
            return .low
        default:
            return .medium
        }
    }
    
    /// Category of the error for grouping and handling
    public var category: ErrorCategory {
        switch self {
        case .connectionFailed, .connectionTimeout, .networkError, .authenticationFailed:
            return .connection
        case .tokenExpired, .tokenRenewalFailed, .invalidToken, .tokenNotProvided:
            return .authentication
        case .audioControlFailed, .microphonePermissionDenied, .audioStreamControlFailed, .volumeControlFailed, .audioSettingsInvalid:
            return .audio
        case .streamPushStartFailed, .streamPushStopFailed, .streamPushUpdateFailed, .invalidStreamConfig, .streamLayoutUpdateFailed:
            return .streaming
        case .mediaRelayStartFailed, .mediaRelayStopFailed, .mediaRelayUpdateFailed, .invalidMediaRelayConfig, .relayChannelConnectionFailed, .relayChannelNotFound, .mediaRelayPauseFailed, .mediaRelayResumeFailed:
            return .mediaRelay
        case .volumeIndicatorStartFailed, .volumeIndicatorStopFailed, .invalidVolumeConfig, .volumeDetectionFailed:
            return .volumeDetection
        case .messageProcessingFailed, .unsupportedMessageType, .messageHandlerNotFound, .messageSendFailed, .messageSubscriptionFailed:
            return .messaging
        case .providerNotInitialized, .providerAlreadyInitialized, .providerInitializationFailed, .unsupportedProvider, .providerSwitchFailed, .providerNotAvailable:
            return .provider
        case .storageError, .dataCorrupted, .storagePermissionDenied:
            return .storage
        case .invalidParameter, .parameterOutOfRange, .requiredParameterMissing:
            return .validation
        default:
            return .general
        }
    }
    
    /// User-friendly recovery suggestions
    public var recoverySuggestion: String? {
        switch self {
        case .connectionTimeout, .networkError:
            return "请检查网络连接并重试"
        case .authenticationFailed:
            return "请检查用户凭据并重新登录"
        case .tokenExpired:
            return "Token 已过期，正在自动续期"
        case .microphonePermissionDenied:
            return "请在设置中允许麦克风权限"
        case .storagePermissionDenied:
            return "请在设置中允许存储权限"
        case .roomCapacityExceeded:
            return "房间人数已满，请稍后再试"
        case .providerNotAvailable:
            return "服务暂时不可用，正在尝试切换到备用服务"
        case .volumeControlFailed:
            return "音量控制失败，请检查音频设备"
        case .invalidParameter, .parameterOutOfRange:
            return "请检查输入参数是否正确"
        default:
            return "操作失败，请重试"
        }
    }
}

/// Error severity levels
public enum ErrorSeverity: String, CaseIterable, Codable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        switch self {
        case .low: return "轻微"
        case .medium: return "中等"
        case .high: return "严重"
        case .critical: return "致命"
        }
    }
}

/// Error categories for grouping related errors
public enum ErrorCategory: String, CaseIterable, Codable, Sendable {
    case connection = "connection"
    case authentication = "authentication"
    case audio = "audio"
    case streaming = "streaming"
    case mediaRelay = "media_relay"
    case volumeDetection = "volume_detection"
    case messaging = "messaging"
    case provider = "provider"
    case storage = "storage"
    case validation = "validation"
    case general = "general"
    
    public var displayName: String {
        switch self {
        case .connection: return "连接"
        case .authentication: return "认证"
        case .audio: return "音频"
        case .streaming: return "推流"
        case .mediaRelay: return "媒体中继"
        case .volumeDetection: return "音量检测"
        case .messaging: return "消息"
        case .provider: return "服务商"
        case .storage: return "存储"
        case .validation: return "验证"
        case .general: return "通用"
        }
    }
}