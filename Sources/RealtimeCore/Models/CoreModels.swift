import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 核心数据模型
/// 需求: 1.2, 1.3

// Note: ProviderFeature and ProviderFactory are defined in ProviderTypes.swift

// MARK: - Audio Settings

/// 音频设置模型 (需求 5.1, 5.2, 5.4)
public struct AudioSettings: Codable, Equatable, Sendable {
    public let microphoneMuted: Bool                // 需求 5.1
    public let audioMixingVolume: Int              // 0-100, 需求 5.2
    public let playbackSignalVolume: Int           // 0-100, 需求 5.2
    public let recordingSignalVolume: Int          // 0-100, 需求 5.2
    public let localAudioStreamActive: Bool        // 需求 5.3
    public let lastModified: Date                  // 用于同步检测
    public let settingsVersion: Int                // 设置版本号，用于兼容性
    
    /// 音量范围常量
    public static let volumeRange = 0...100
    public static let defaultVolume = 100
    
    public init(
        microphoneMuted: Bool = false,
        audioMixingVolume: Int = AudioSettings.defaultVolume,
        playbackSignalVolume: Int = AudioSettings.defaultVolume,
        recordingSignalVolume: Int = AudioSettings.defaultVolume,
        localAudioStreamActive: Bool = true,
        settingsVersion: Int = 1
    ) {
        self.microphoneMuted = microphoneMuted
        self.audioMixingVolume = Self.validateVolume(audioMixingVolume)
        self.playbackSignalVolume = Self.validateVolume(playbackSignalVolume)
        self.recordingSignalVolume = Self.validateVolume(recordingSignalVolume)
        self.localAudioStreamActive = localAudioStreamActive
        self.lastModified = Date()
        self.settingsVersion = settingsVersion
    }
    
    /// 音量范围验证 (需求 5.2)
    public static func validateVolume(_ volume: Int) -> Int {
        return max(volumeRange.lowerBound, min(volumeRange.upperBound, volume))
    }
    
    /// 检查音量是否在有效范围内
    public static func isValidVolume(_ volume: Int) -> Bool {
        return volumeRange.contains(volume)
    }
    
    /// 更新音量设置 (需求 5.4, 5.6)
    public func withUpdatedVolume(
        audioMixing: Int? = nil,
        playbackSignal: Int? = nil,
        recordingSignal: Int? = nil
    ) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: self.microphoneMuted,
            audioMixingVolume: audioMixing ?? self.audioMixingVolume,
            playbackSignalVolume: playbackSignal ?? self.playbackSignalVolume,
            recordingSignalVolume: recordingSignal ?? self.recordingSignalVolume,
            localAudioStreamActive: self.localAudioStreamActive,
            settingsVersion: self.settingsVersion
        )
    }
    
    /// 更新麦克风状态
    public func withUpdatedMicrophoneState(_ muted: Bool) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: self.audioMixingVolume,
            playbackSignalVolume: self.playbackSignalVolume,
            recordingSignalVolume: self.recordingSignalVolume,
            localAudioStreamActive: self.localAudioStreamActive,
            settingsVersion: self.settingsVersion
        )
    }
    
    /// 更新音频流状态
    public func withUpdatedStreamState(_ active: Bool) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: self.microphoneMuted,
            audioMixingVolume: self.audioMixingVolume,
            playbackSignalVolume: self.playbackSignalVolume,
            recordingSignalVolume: self.recordingSignalVolume,
            localAudioStreamActive: active,
            settingsVersion: self.settingsVersion
        )
    }
    
    /// 检查设置是否有效
    public var isValid: Bool {
        return Self.isValidVolume(audioMixingVolume) &&
               Self.isValidVolume(playbackSignalVolume) &&
               Self.isValidVolume(recordingSignalVolume)
    }
    
    /// 获取所有音量设置的平均值
    public var averageVolume: Int {
        return (audioMixingVolume + playbackSignalVolume + recordingSignalVolume) / 3
    }
    
    /// 检查是否为静音状态（所有音量都为0或麦克风静音）
    public var isSilent: Bool {
        return microphoneMuted || (audioMixingVolume == 0 && playbackSignalVolume == 0 && recordingSignalVolume == 0)
    }
    
    public static let `default` = AudioSettings()
}

// MARK: - Audio Settings Validation Errors

/// 音频设置验证错误
public enum AudioSettingsError: Error, LocalizedError {
    case invalidVolume(Int, validRange: ClosedRange<Int>)
    case incompatibleVersion(Int, supportedVersion: Int)
    case storageError(Error)
    case migrationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidVolume(let volume, let validRange):
            return "音量值 \(volume) 超出有效范围 \(validRange)"
        case .incompatibleVersion(let version, let supportedVersion):
            return "设置版本 \(version) 不兼容，支持的版本: \(supportedVersion)"
        case .storageError(let error):
            return "存储错误: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "数据迁移失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - User Session

/// 用户会话模型 (需求 4.4)
public struct UserSession: Codable, Equatable, Sendable {
    public let userId: String
    public let userName: String
    public let userRole: UserRole
    public let roomId: String?
    public let joinTime: Date
    public let lastActiveTime: Date
    public let sessionId: String
    public let deviceInfo: DeviceInfo?
    
    public init(
        userId: String, 
        userName: String, 
        userRole: UserRole, 
        roomId: String? = nil,
        deviceInfo: DeviceInfo? = nil
    ) {
        self.userId = userId
        self.userName = userName
        self.userRole = userRole
        self.roomId = roomId
        self.joinTime = Date()
        self.lastActiveTime = Date()
        self.sessionId = UUID().uuidString
        self.deviceInfo = deviceInfo
    }
    
    /// 创建更新了角色的新会话
    public func withUpdatedRole(_ newRole: UserRole) -> UserSession {
        return UserSession(
            userId: self.userId,
            userName: self.userName,
            userRole: newRole,
            roomId: self.roomId,
            deviceInfo: self.deviceInfo
        )
    }
    
    /// 创建更新了房间ID的新会话
    public func withUpdatedRoomId(_ newRoomId: String?) -> UserSession {
        return UserSession(
            userId: self.userId,
            userName: self.userName,
            userRole: self.userRole,
            roomId: newRoomId,
            deviceInfo: self.deviceInfo
        )
    }
    
    /// 检查会话是否有效（基于时间）
    public func isValid(maxInactiveTime: TimeInterval = 3600) -> Bool {
        return Date().timeIntervalSince(lastActiveTime) < maxInactiveTime
    }
    
    /// 检查用户是否在房间中
    public var isInRoom: Bool {
        return roomId != nil
    }
}

// MARK: - Device Info

/// 设备信息模型
public struct DeviceInfo: Codable, Equatable, Sendable {
    public let deviceId: String
    public let deviceModel: String
    public let systemVersion: String
    public let appVersion: String
    
    public init(
        deviceId: String,
        deviceModel: String,
        systemVersion: String,
        appVersion: String
    ) {
        self.deviceId = deviceId
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.appVersion = appVersion
    }
    
    /// 获取当前设备信息
    public static func current(appVersion: String) -> DeviceInfo {
        #if os(iOS)
        return DeviceInfo(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: appVersion
        )
        #elseif os(macOS)
        let processInfo = ProcessInfo.processInfo
        return DeviceInfo(
            deviceId: "mac-\(UUID().uuidString)",
            deviceModel: "Mac",
            systemVersion: processInfo.operatingSystemVersionString,
            appVersion: appVersion
        )
        #endif
    }
}



// MARK: - Realtime Config

/// RealtimeKit 统一配置
public struct RealtimeConfig: Codable, Sendable {
    public let appId: String
    public let appCertificate: String?
    public let region: RTCRegion
    public let enableLogging: Bool
    public let logLevel: RTCLogLevel
    
    public init(
        appId: String,
        appCertificate: String? = nil,
        region: RTCRegion = .global,
        enableLogging: Bool = true,
        logLevel: RTCLogLevel = .info
    ) {
        self.appId = appId
        self.appCertificate = appCertificate
        self.region = region
        self.enableLogging = enableLogging
        self.logLevel = logLevel
    }
}

// MARK: - Extensions for Config Conversion

extension RTCConfig {
    public init(from config: RealtimeConfig) {
        self.init(
            appId: config.appId,
            appCertificate: config.appCertificate,
            region: config.region,
            logConfig: RTCLogConfig(
                logLevel: config.logLevel,
                enableConsoleLog: config.enableLogging
            )
        )
    }
}

extension RTMConfig {
    public init(from config: RealtimeConfig) {
        self.init(
            appId: config.appId,
            logConfig: RTMLogConfig(
                logLevel: RTMLogLevel(rawValue: config.logLevel.rawValue) ?? .info,
                enableConsoleLog: config.enableLogging
            )
        )
    }
}
