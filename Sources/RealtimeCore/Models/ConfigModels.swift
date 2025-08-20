// ConfigModels.swift
// Configuration models for RTC and RTM providers

import Foundation

/// Base configuration for RealtimeKit
public struct RealtimeConfig: Codable, Sendable {
    public let appId: String
    public let appKey: String?
    public let serverUrl: String?
    public let logLevel: LogLevel
    public let enableEncryption: Bool
    public let encryptionKey: String?
    
    /// Initialize RealtimeKit configuration
    /// - Parameters:
    ///   - appId: Application identifier from service provider
    ///   - appKey: Optional application key
    ///   - serverUrl: Optional custom server URL
    ///   - logLevel: Logging level
    ///   - enableEncryption: Whether to enable encryption
    ///   - encryptionKey: Optional encryption key
    public init(
        appId: String,
        appKey: String? = nil,
        serverUrl: String? = nil,
        logLevel: LogLevel = .info,
        enableEncryption: Bool = false,
        encryptionKey: String? = nil
    ) {
        self.appId = appId
        self.appKey = appKey
        self.serverUrl = serverUrl
        self.logLevel = logLevel
        self.enableEncryption = enableEncryption
        self.encryptionKey = encryptionKey
    }
}

/// RTC provider configuration
public struct RTCConfig: Codable, Sendable {
    public let appId: String
    public let token: String?
    public let serverUrl: String?
    public let logLevel: LogLevel
    public let enableEncryption: Bool
    public let encryptionKey: String?
    public let audioProfile: AudioProfile
    public let videoProfile: VideoProfile
    
    /// Initialize RTC configuration
    /// - Parameters:
    ///   - appId: Application identifier
    ///   - token: Optional authentication token
    ///   - serverUrl: Optional custom server URL
    ///   - logLevel: Logging level
    ///   - enableEncryption: Whether to enable encryption
    ///   - encryptionKey: Optional encryption key
    ///   - audioProfile: Audio quality profile
    ///   - videoProfile: Video quality profile
    public init(
        appId: String,
        token: String? = nil,
        serverUrl: String? = nil,
        logLevel: LogLevel = .info,
        enableEncryption: Bool = false,
        encryptionKey: String? = nil,
        audioProfile: AudioProfile = .default,
        videoProfile: VideoProfile = .default
    ) {
        self.appId = appId
        self.token = token
        self.serverUrl = serverUrl
        self.logLevel = logLevel
        self.enableEncryption = enableEncryption
        self.encryptionKey = encryptionKey
        self.audioProfile = audioProfile
        self.videoProfile = videoProfile
    }
    
    /// Create RTC config from RealtimeConfig
    /// - Parameter config: Base RealtimeKit configuration
    public init(from config: RealtimeConfig) {
        self.init(
            appId: config.appId,
            serverUrl: config.serverUrl,
            logLevel: config.logLevel,
            enableEncryption: config.enableEncryption,
            encryptionKey: config.encryptionKey
        )
    }
}

/// RTM provider configuration
public struct RTMConfig: Codable, Sendable {
    public let appId: String
    public let token: String?
    public let serverUrl: String?
    public let logLevel: LogLevel
    public let enableEncryption: Bool
    public let encryptionKey: String?
    public let heartbeatInterval: Int  // seconds
    public let connectionTimeout: Int  // seconds
    
    /// Initialize RTM configuration
    /// - Parameters:
    ///   - appId: Application identifier
    ///   - token: Optional authentication token
    ///   - serverUrl: Optional custom server URL
    ///   - logLevel: Logging level
    ///   - enableEncryption: Whether to enable encryption
    ///   - encryptionKey: Optional encryption key
    ///   - heartbeatInterval: Heartbeat interval in seconds
    ///   - connectionTimeout: Connection timeout in seconds
    public init(
        appId: String,
        token: String? = nil,
        serverUrl: String? = nil,
        logLevel: LogLevel = .info,
        enableEncryption: Bool = false,
        encryptionKey: String? = nil,
        heartbeatInterval: Int = 30,
        connectionTimeout: Int = 10
    ) {
        self.appId = appId
        self.token = token
        self.serverUrl = serverUrl
        self.logLevel = logLevel
        self.enableEncryption = enableEncryption
        self.encryptionKey = encryptionKey
        self.heartbeatInterval = max(10, heartbeatInterval)
        self.connectionTimeout = max(5, connectionTimeout)
    }
    
    /// Create RTM config from RealtimeConfig
    /// - Parameter config: Base RealtimeKit configuration
    public init(from config: RealtimeConfig) {
        self.init(
            appId: config.appId,
            serverUrl: config.serverUrl,
            logLevel: config.logLevel,
            enableEncryption: config.enableEncryption,
            encryptionKey: config.encryptionKey
        )
    }
}

/// Logging levels
public enum LogLevel: String, CaseIterable, Codable, Sendable {
    case verbose = "verbose"
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case none = "none"
    
    /// Display name for log level
    public var displayName: String {
        return rawValue.capitalized
    }
}

/// Audio quality profiles
public enum AudioProfile: String, CaseIterable, Codable, Sendable {
    case speechStandard = "speech_standard"
    case musicStandard = "music_standard"
    case musicHighQuality = "music_high_quality"
    case musicHighQualityStereo = "music_high_quality_stereo"
    
    /// Default audio profile
    public static let `default` = AudioProfile.speechStandard
    
    /// Display name for audio profile
    public var displayName: String {
        switch self {
        case .speechStandard: return "语音标准"
        case .musicStandard: return "音乐标准"
        case .musicHighQuality: return "音乐高质量"
        case .musicHighQualityStereo: return "音乐高质量立体声"
        }
    }
}

/// Video quality profiles
public enum VideoProfile: String, CaseIterable, Codable, Sendable {
    case portrait120p = "portrait_120p"
    case portrait240p = "portrait_240p"
    case portrait360p = "portrait_360p"
    case portrait480p = "portrait_480p"
    case portrait720p = "portrait_720p"
    case portrait1080p = "portrait_1080p"
    case landscape120p = "landscape_120p"
    case landscape240p = "landscape_240p"
    case landscape360p = "landscape_360p"
    case landscape480p = "landscape_480p"
    case landscape720p = "landscape_720p"
    case landscape1080p = "landscape_1080p"
    
    /// Default video profile
    public static let `default` = VideoProfile.portrait480p
    
    /// Display name for video profile
    public var displayName: String {
        switch self {
        case .portrait120p: return "竖屏 120p"
        case .portrait240p: return "竖屏 240p"
        case .portrait360p: return "竖屏 360p"
        case .portrait480p: return "竖屏 480p"
        case .portrait720p: return "竖屏 720p"
        case .portrait1080p: return "竖屏 1080p"
        case .landscape120p: return "横屏 120p"
        case .landscape240p: return "横屏 240p"
        case .landscape360p: return "横屏 360p"
        case .landscape480p: return "横屏 480p"
        case .landscape720p: return "横屏 720p"
        case .landscape1080p: return "横屏 1080p"
        }
    }
}