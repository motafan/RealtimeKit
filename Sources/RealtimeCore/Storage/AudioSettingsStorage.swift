// AudioSettingsStorage.swift
// Audio settings storage manager with validation and migration

import Foundation
import Combine

/// Storage manager for audio settings with validation and migration support
public final class AudioSettingsStorage: ObservableObject, @unchecked Sendable {
    
    // MARK: - Storage Keys
    private enum StorageKeys {
        static let audioSettings = "audio.settings"
        static let settingsVersion = "audio.settings.version"
    }
    
    // MARK: - Properties
    private let storage: StorageProvider
    private let currentVersion = 1
    
    /// Current audio settings as a published property
    @Published public private(set) var currentSettings: AudioSettings
    
    // History tracking
    private var historyEnabled = false
    private var maxHistorySize = 10
    private var settingsHistory: [AudioSettings] = []
    
    // MARK: - Initialization
    
    /// Initialize audio settings storage
    /// - Parameter storage: Storage provider to use
    public init(storage: StorageProvider = UserDefaultsStorageProvider()) {
        self.storage = storage
        
        // Load settings from storage or use defaults
        do {
            if let storedSettings = try storage.getValue(AudioSettings.self, forKey: StorageKeys.audioSettings) {
                self.currentSettings = storedSettings
            } else {
                self.currentSettings = AudioSettings.default
            }
        } catch {
            print("AudioSettingsStorage: Failed to load settings, using defaults: \(error)")
            self.currentSettings = AudioSettings.default
        }
        
        // Perform migration if needed
        performMigrationIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Update audio settings with validation
    /// - Parameter settings: New audio settings
    /// - Throws: RealtimeError if validation fails
    public func updateSettings(_ settings: AudioSettings) throws {
        // Validate settings
        try validateSettings(settings)
        
        // Add to history if enabled
        if historyEnabled {
            settingsHistory.append(currentSettings)
            if settingsHistory.count > maxHistorySize {
                settingsHistory.removeFirst()
            }
        }
        
        // Save to storage
        try storage.setValue(settings, forKey: StorageKeys.audioSettings)
        
        // Update published property
        currentSettings = settings
    }
    
    /// Update microphone mute state
    /// - Parameter muted: New mute state
    public func updateMicrophoneMuted(_ muted: Bool) {
        let updatedSettings = currentSettings.withMicrophoneMuted(muted)
        try? updateSettings(updatedSettings)
    }
    
    /// Update audio mixing volume
    /// - Parameter volume: New volume (0-100)
    /// - Throws: RealtimeError if volume is out of range
    public func updateAudioMixingVolume(_ volume: Int) throws {
        guard volume >= 0 && volume <= 100 else {
            throw RealtimeError.parameterOutOfRange("audioMixingVolume", "0-100")
        }
        
        let updatedSettings = currentSettings.withAudioMixingVolume(volume)
        try updateSettings(updatedSettings)
    }
    
    /// Update playback signal volume
    /// - Parameter volume: New volume (0-100)
    /// - Throws: RealtimeError if volume is out of range
    public func updatePlaybackSignalVolume(_ volume: Int) throws {
        guard volume >= 0 && volume <= 100 else {
            throw RealtimeError.parameterOutOfRange("playbackSignalVolume", "0-100")
        }
        
        let updatedSettings = currentSettings.withPlaybackSignalVolume(volume)
        try updateSettings(updatedSettings)
    }
    
    /// Update recording signal volume
    /// - Parameter volume: New volume (0-100)
    /// - Throws: RealtimeError if volume is out of range
    public func updateRecordingSignalVolume(_ volume: Int) throws {
        guard volume >= 0 && volume <= 100 else {
            throw RealtimeError.parameterOutOfRange("recordingSignalVolume", "0-100")
        }
        
        let updatedSettings = currentSettings.withRecordingSignalVolume(volume)
        try updateSettings(updatedSettings)
    }
    
    /// Update local audio stream active state
    /// - Parameter active: New active state
    public func updateLocalAudioStreamActive(_ active: Bool) {
        let updatedSettings = currentSettings.withLocalAudioStreamActive(active)
        try? updateSettings(updatedSettings)
    }
    
    /// Reset to default settings
    public func resetToDefaults() {
        let defaultSettings = AudioSettings.default
        try? updateSettings(defaultSettings)
    }
    
    /// Clear all stored settings
    /// - Throws: RealtimeError if clearing fails
    public func clearAll() throws {
        do {
            try storage.removeValue(forKey: StorageKeys.audioSettings)
            try storage.removeValue(forKey: StorageKeys.settingsVersion)
            
            // Reset to defaults
            resetToDefaults()
        } catch {
            throw RealtimeError.storageError("Failed to clear audio settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func validateSettings(_ settings: AudioSettings) throws {
        // Validate volume ranges
        guard settings.audioMixingVolume >= 0 && settings.audioMixingVolume <= 100 else {
            throw RealtimeError.audioSettingsInvalid("Audio mixing volume must be between 0 and 100")
        }
        
        guard settings.playbackSignalVolume >= 0 && settings.playbackSignalVolume <= 100 else {
            throw RealtimeError.audioSettingsInvalid("Playback signal volume must be between 0 and 100")
        }
        
        guard settings.recordingSignalVolume >= 0 && settings.recordingSignalVolume <= 100 else {
            throw RealtimeError.audioSettingsInvalid("Recording signal volume must be between 0 and 100")
        }
    }
    
    private func performMigrationIfNeeded() {
        do {
            let storedVersion = try storage.getValue(Int.self, forKey: StorageKeys.settingsVersion) ?? 0
            if storedVersion < currentVersion {
                performMigration(from: storedVersion, to: currentVersion)
                try storage.setValue(currentVersion, forKey: StorageKeys.settingsVersion)
            }
        } catch {
            print("AudioSettingsStorage: Migration check failed: \(error)")
        }
    }
    
    private func performMigration(from oldVersion: Int, to newVersion: Int) {
        print("AudioSettingsStorage: Migrating from version \(oldVersion) to \(newVersion)")
        
        // Future migration logic can be added here
        switch oldVersion {
        case 0:
            // Initial migration - no action needed as defaults will be used
            break
        default:
            break
        }
    }
}

// MARK: - Convenience Extensions

#if canImport(SwiftUI)
import SwiftUI

public extension AudioSettingsStorage {
    
    /// Create a binding for SwiftUI integration
    /// - Parameter keyPath: KeyPath to the property
    /// - Returns: Binding for the property
    func binding<T>(for keyPath: WritableKeyPath<AudioSettings, T>) -> Binding<T> where T: Equatable {
        Binding(
            get: { self.currentSettings[keyPath: keyPath] },
            set: { newValue in
                var updatedSettings = self.currentSettings
                updatedSettings[keyPath: keyPath] = newValue
                try? self.updateSettings(updatedSettings)
            }
        )
    }
}
#endif

// MARK: - Binding Support for SwiftUI

#if canImport(SwiftUI)
public extension AudioSettingsStorage {
    
    /// Binding for microphone muted state
    var microphoneMutedBinding: Binding<Bool> {
        Binding(
            get: { self.currentSettings.microphoneMuted },
            set: { self.updateMicrophoneMuted($0) }
        )
    }
    
    /// Binding for audio mixing volume
    var audioMixingVolumeBinding: Binding<Int> {
        Binding(
            get: { self.currentSettings.audioMixingVolume },
            set: { try? self.updateAudioMixingVolume($0) }
        )
    }
    
    /// Binding for playback signal volume
    var playbackSignalVolumeBinding: Binding<Int> {
        Binding(
            get: { self.currentSettings.playbackSignalVolume },
            set: { try? self.updatePlaybackSignalVolume($0) }
        )
    }
    
    /// Binding for recording signal volume
    var recordingSignalVolumeBinding: Binding<Int> {
        Binding(
            get: { self.currentSettings.recordingSignalVolume },
            set: { try? self.updateRecordingSignalVolume($0) }
        )
    }
    
    /// Binding for local audio stream active state
    var localAudioStreamActiveBinding: Binding<Bool> {
        Binding(
            get: { self.currentSettings.localAudioStreamActive },
            set: { self.updateLocalAudioStreamActive($0) }
        )
    }
}
#endif

// MARK: - Legacy Method Support for RealtimeManager

public extension AudioSettingsStorage {
    
    /// Save audio settings (legacy method for RealtimeManager compatibility)
    /// - Parameter settings: Audio settings to save
    func saveAudioSettings(_ settings: AudioSettings) {
        try? updateSettings(settings)
    }
    
    /// Load audio settings (legacy method for RealtimeManager compatibility)
    /// - Returns: Current audio settings
    func loadAudioSettings() -> AudioSettings {
        return currentSettings
    }
    
    /// Clear audio settings (legacy method)
    func clearAudioSettings() {
        try? clearAll()
    }
    

    
    // MARK: - History Tracking Methods
    
    /// Enable history tracking
    func enableHistoryTracking(maxHistorySize: Int = 10) {
        self.historyEnabled = true
        self.maxHistorySize = maxHistorySize
    }
    
    /// Get settings history
    func getSettingsHistory() -> [AudioSettings] {
        return settingsHistory
    }
    
    /// Clear settings history
    func clearSettingsHistory() {
        settingsHistory.removeAll()
    }
    
    // MARK: - Backup and Restore Methods
    
    /// Create backup of current settings
    func createBackup() throws -> Data {
        return try JSONEncoder().encode(currentSettings)
    }
    
    /// Restore from backup
    func restoreFromBackup(_ backup: Data) throws {
        let settings = try JSONDecoder().decode(AudioSettings.self, from: backup)
        try updateSettings(settings)
    }
    
    /// Export settings to data
    func exportSettings() throws -> Data {
        return try createBackup()
    }
    
    /// Import settings from data
    func importSettings(from data: Data) throws {
        try restoreFromBackup(data)
    }
}