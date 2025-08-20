// AudioSettings.swift
// Audio settings data model with validation

import Foundation

/// Audio settings configuration with validation
public struct AudioSettings: Codable, Equatable, Sendable {
    public let microphoneMuted: Bool
    public let audioMixingVolume: Int        // 0-100
    public let playbackSignalVolume: Int     // 0-100
    public let recordingSignalVolume: Int    // 0-100
    public let localAudioStreamActive: Bool
    public let lastModified: Date            // Timestamp for synchronization
    
    /// Initialize audio settings with validation
    /// - Parameters:
    ///   - microphoneMuted: Whether microphone is muted
    ///   - audioMixingVolume: Audio mixing volume (0-100)
    ///   - playbackSignalVolume: Playback signal volume (0-100)
    ///   - recordingSignalVolume: Recording signal volume (0-100)
    ///   - localAudioStreamActive: Whether local audio stream is active
    ///   - lastModified: Timestamp for synchronization (defaults to current time)
    public init(
        microphoneMuted: Bool = false,
        audioMixingVolume: Int = 100,
        playbackSignalVolume: Int = 100,
        recordingSignalVolume: Int = 100,
        localAudioStreamActive: Bool = true,
        lastModified: Date = Date()
    ) {
        self.microphoneMuted = microphoneMuted
        self.audioMixingVolume = Self.validateVolume(audioMixingVolume)
        self.playbackSignalVolume = Self.validateVolume(playbackSignalVolume)
        self.recordingSignalVolume = Self.validateVolume(recordingSignalVolume)
        self.localAudioStreamActive = localAudioStreamActive
        self.lastModified = lastModified
    }
    
    /// Default audio settings
    public static let `default` = AudioSettings()
    
    /// Validate volume range (0-100)
    private static func validateVolume(_ volume: Int) -> Int {
        return max(0, min(100, volume))
    }
    
    /// Create new settings with updated microphone mute state
    /// - Parameter muted: New mute state
    /// - Returns: Updated audio settings
    public func withMicrophoneMuted(_ muted: Bool) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: audioMixingVolume,
            playbackSignalVolume: playbackSignalVolume,
            recordingSignalVolume: recordingSignalVolume,
            localAudioStreamActive: localAudioStreamActive,
            lastModified: Date()
        )
    }
    
    /// Create new settings with updated audio mixing volume
    /// - Parameter volume: New volume level (0-100)
    /// - Returns: Updated audio settings
    public func withAudioMixingVolume(_ volume: Int) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: microphoneMuted,
            audioMixingVolume: volume,
            playbackSignalVolume: playbackSignalVolume,
            recordingSignalVolume: recordingSignalVolume,
            localAudioStreamActive: localAudioStreamActive,
            lastModified: Date()
        )
    }
    
    /// Create new settings with updated playback signal volume
    /// - Parameter volume: New volume level (0-100)
    /// - Returns: Updated audio settings
    public func withPlaybackSignalVolume(_ volume: Int) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: microphoneMuted,
            audioMixingVolume: audioMixingVolume,
            playbackSignalVolume: volume,
            recordingSignalVolume: recordingSignalVolume,
            localAudioStreamActive: localAudioStreamActive,
            lastModified: Date()
        )
    }
    
    /// Create new settings with updated recording signal volume
    /// - Parameter volume: New volume level (0-100)
    /// - Returns: Updated audio settings
    public func withRecordingSignalVolume(_ volume: Int) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: microphoneMuted,
            audioMixingVolume: audioMixingVolume,
            playbackSignalVolume: playbackSignalVolume,
            recordingSignalVolume: volume,
            localAudioStreamActive: localAudioStreamActive,
            lastModified: Date()
        )
    }
    
    /// Create new settings with updated local audio stream state
    /// - Parameter active: New stream active state
    /// - Returns: Updated audio settings
    public func withLocalAudioStreamActive(_ active: Bool) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: microphoneMuted,
            audioMixingVolume: audioMixingVolume,
            playbackSignalVolume: playbackSignalVolume,
            recordingSignalVolume: recordingSignalVolume,
            localAudioStreamActive: active,
            lastModified: Date()
        )
    }
}

// MARK: - Convenience Methods

public extension AudioSettings {
    
    /// Create new settings with updated volume levels
    /// - Parameters:
    ///   - audioMixing: New audio mixing volume (optional)
    ///   - playbackSignal: New playback signal volume (optional)
    ///   - recordingSignal: New recording signal volume (optional)
    /// - Returns: Updated audio settings
    func withUpdatedVolume(
        audioMixing: Int? = nil,
        playbackSignal: Int? = nil,
        recordingSignal: Int? = nil
    ) -> AudioSettings {
        return AudioSettings(
            microphoneMuted: microphoneMuted,
            audioMixingVolume: audioMixing ?? audioMixingVolume,
            playbackSignalVolume: playbackSignal ?? playbackSignalVolume,
            recordingSignalVolume: recordingSignal ?? recordingSignalVolume,
            localAudioStreamActive: localAudioStreamActive,
            lastModified: Date()
        )
    }
}