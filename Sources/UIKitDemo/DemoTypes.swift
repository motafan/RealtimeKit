import Foundation
import RealtimeCore

// MARK: - Demo-specific types and extensions

/// Permission types for demo
public enum Permission {
    case audio
    case video
}

/// Device information for demo
public struct DeviceInfo: Codable {
    let deviceId: String
    let deviceName: String
    let osVersion: String
    let appVersion: String
    
    public init(deviceId: String, deviceName: String, osVersion: String, appVersion: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.appVersion = appVersion
    }
}

/// Async operation types for demo
public enum AsyncOperationType {
    case login
    case logout
    case configure
    case switchProvider
    case audioOperation
    case volumeOperation
    case streamPush
    case mediaRelay
}

/// Async operation events for demo
public enum AsyncOperationEvent {
    case started(AsyncOperationType)
    case completed(AsyncOperationType)
    case failed(AsyncOperationType, LocalizedRealtimeError)
}

/// State change events for demo
public enum StateChangeEvent {
    case connectionStateChanged(ConnectionState)
    case sessionChanged(UserSession?)
    case providerChanged(ProviderType)
    case audioSettingsChanged(AudioSettings)
    case volumeInfoChanged([UserVolumeInfo])
    case userStartedSpeaking(String, Float)
    case userStoppedSpeaking(String)
    case dominantSpeakerChanged(String?)
}

/// Localized text update for demo
public struct LocalizedTextUpdate {
    let connectionState: String
    let userRole: String
    let providerName: String
    let updateTime: Date
}

/// Combined realtime state for demo
public struct CombinedRealtimeState {
    let session: UserSession?
    let connectionState: ConnectionState
    let audioSettings: AudioSettings
    let audioStatus: AudioStatusInfo
    let updateTime: Date
}

/// Localized text snapshot for demo
public struct LocalizedTextSnapshot {
    let connectionState: String
    let userRole: String
    let providerName: String
}

/// Reactive state snapshot for demo
public struct ReactiveStateSnapshot {
    let session: UserSession?
    let connectionState: ConnectionState
    let audioSettings: AudioSettings
    let audioStatus: AudioStatusInfo
    let volumeInfos: [UserVolumeInfo]
    let speakingUsers: Set<String>
    let dominantSpeaker: String?
    let localizedTexts: LocalizedTextSnapshot
    let isPerformingOperation: Bool
    let lastError: LocalizedRealtimeError?
    let snapshotTime: Date
}

// MARK: - Extensions for demo

extension UserVolumeInfo {
    /// Convert Int volume to Float for compatibility
    var volumeFloat: Float {
        return Float(volume)
    }
}

extension AudioSettings {
    /// Calculate average volume for demo display
    var averageVolume: Int {
        return (audioMixingVolume + playbackSignalVolume + recordingSignalVolume) / 3
    }
}

extension AudioStatusInfo {
    /// Status summary for demo display
    var statusSummary: String {
        if isProviderConnected && hasAudioPermission {
            return "Audio Ready"
        } else if !isProviderConnected {
            return "Not Connected"
        } else {
            return "No Audio Permission"
        }
    }
}

extension ConnectionState {
    /// Check if state is transitioning
    var isTransitioning: Bool {
        switch self {
        case .connecting, .reconnecting:
            return true
        default:
            return false
        }
    }
}

extension RealtimeError {
    /// Create configuration error
    static func configurationError(_ message: String) -> RealtimeError {
        return .invalidConfiguration(message)
    }
    
    /// Create invalid parameter error
    static func invalidParameter(_ message: String) -> RealtimeError {
        return .invalidConfiguration(message)
    }
    
    /// Create insufficient permissions error
    static func insufficientPermissions(_ role: UserRole) -> RealtimeError {
        return .invalidConfiguration("Insufficient permissions for role: \(role.rawValue)")
    }
    
    /// Create no active session error
    static var noActiveSession: RealtimeError {
        return .invalidConfiguration("No active session")
    }
}