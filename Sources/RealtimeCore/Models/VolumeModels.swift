// VolumeModels.swift
// Volume detection and user volume information models

import Foundation

/// Configuration for volume detection
public struct VolumeDetectionConfig: Codable, Equatable, Sendable {
    public let detectionInterval: Int      // 检测间隔（毫秒）
    public let speakingThreshold: Float    // 说话音量阈值 (0.0 - 1.0)
    public let silenceThreshold: Float     // 静音音量阈值
    public let includeLocalUser: Bool      // 是否包含本地用户
    public let smoothFactor: Float         // 平滑处理参数 (0.0 - 1.0)
    
    /// Initialize volume detection configuration
    /// - Parameters:
    ///   - detectionInterval: Detection interval in milliseconds
    ///   - speakingThreshold: Volume threshold for speaking detection (0.0 - 1.0)
    ///   - silenceThreshold: Volume threshold for silence detection
    ///   - includeLocalUser: Whether to include local user in detection
    ///   - smoothFactor: Smoothing factor for volume data (0.0 - 1.0)
    public init(
        detectionInterval: Int = 300,
        speakingThreshold: Float = 0.3,
        silenceThreshold: Float = 0.05,
        includeLocalUser: Bool = true,
        smoothFactor: Float = 0.3
    ) {
        self.detectionInterval = max(100, detectionInterval) // Minimum 100ms
        self.speakingThreshold = max(0.0, min(1.0, speakingThreshold))
        self.silenceThreshold = max(0.0, min(1.0, silenceThreshold))
        self.includeLocalUser = includeLocalUser
        self.smoothFactor = max(0.0, min(1.0, smoothFactor))
    }
    
    /// Default volume detection configuration
    public static let `default` = VolumeDetectionConfig()
    
    /// Validate that speaking threshold is greater than silence threshold
    public var isValid: Bool {
        return speakingThreshold > silenceThreshold
    }
}

/// User volume information
public struct UserVolumeInfo: Codable, Equatable, Sendable {
    public let userId: String
    public let volume: Float           // 音量级别 (0.0 - 1.0)
    public let isSpeaking: Bool        // 是否正在说话
    public let timestamp: Date         // 时间戳
    
    /// Initialize user volume information
    /// - Parameters:
    ///   - userId: User identifier
    ///   - volume: Volume level (0.0 - 1.0)
    ///   - isSpeaking: Whether user is currently speaking
    ///   - timestamp: Timestamp of the volume measurement
    public init(
        userId: String,
        volume: Float,
        isSpeaking: Bool,
        timestamp: Date = Date()
    ) {
        self.userId = userId
        self.volume = max(0.0, min(1.0, volume))
        self.isSpeaking = isSpeaking
        self.timestamp = timestamp
    }
    
    /// Volume level as percentage (0-100)
    public var volumePercentage: Int {
        return Int(volume * 100)
    }
    
    /// Check if volume is above speaking threshold
    /// - Parameter threshold: Speaking threshold to compare against
    /// - Returns: True if volume is above threshold
    public func isAboveThreshold(_ threshold: Float) -> Bool {
        return volume > threshold
    }
    
    /// Create updated volume info with new volume level
    /// - Parameter newVolume: New volume level
    /// - Returns: Updated volume info
    public func withVolume(_ newVolume: Float) -> UserVolumeInfo {
        return UserVolumeInfo(
            userId: userId,
            volume: newVolume,
            isSpeaking: isSpeaking,
            timestamp: Date()
        )
    }
    
    /// Create updated volume info with new speaking state
    /// - Parameter speaking: New speaking state
    /// - Returns: Updated volume info
    public func withSpeakingState(_ speaking: Bool) -> UserVolumeInfo {
        return UserVolumeInfo(
            userId: userId,
            volume: volume,
            isSpeaking: speaking,
            timestamp: Date()
        )
    }
}