// AudioSettingsStorageTests.swift
// Tests for AudioSettingsStorage

import Testing
import Combine
import Foundation
@testable import RealtimeCore

@Suite("AudioSettingsStorage Tests")
struct AudioSettingsStorageTests {
    
    // MARK: - Mock Storage Provider
    
    final class MockStorageProvider: StorageProvider {
        private var storage: [String: Data] = [:]
        
        func setValue<T: Codable>(_ value: T, forKey key: String) throws {
            let data = try JSONEncoder().encode(value)
            storage[key] = data
        }
        
        func getValue<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
            guard let data = storage[key] else { return nil }
            return try JSONDecoder().decode(type, from: data)
        }
        
        func removeValue(forKey key: String) throws {
            storage.removeValue(forKey: key)
        }
        
        func hasValue(forKey key: String) -> Bool {
            return storage[key] != nil
        }
        
        func clearAll() throws {
            storage.removeAll()
        }
        
        func reset() {
            storage.removeAll()
        }
    }
    
    // MARK: - Tests
    
    @Test("AudioSettingsStorage initialization test")
    func testAudioSettingsStorageInitialization() async throws {
        let mockStorage = MockStorageProvider()
        let settingsStorage = AudioSettingsStorage(storage: mockStorage)
        
        // Should initialize with default settings
        let settings = settingsStorage.currentSettings
        #expect(settings.microphoneMuted == false)
        #expect(settings.audioMixingVolume == 100)
        #expect(settings.playbackSignalVolume == 100)
        #expect(settings.recordingSignalVolume == 100)
        #expect(settings.localAudioStreamActive == true)
    }
    
    @Test("AudioSettingsStorage update settings test")
    func testUpdateSettings() async throws {
        let mockStorage = MockStorageProvider()
        let settingsStorage = AudioSettingsStorage(storage: mockStorage)
        
        let newSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        try settingsStorage.updateSettings(newSettings)
        
        let currentSettings = settingsStorage.currentSettings
        #expect(currentSettings.microphoneMuted == true)
        #expect(currentSettings.audioMixingVolume == 75)
        #expect(currentSettings.playbackSignalVolume == 80)
        #expect(currentSettings.recordingSignalVolume == 90)
        #expect(currentSettings.localAudioStreamActive == false)
    }
    
    @Test("AudioSettingsStorage individual property updates test")
    func testIndividualPropertyUpdates() async throws {
        let mockStorage = MockStorageProvider()
        let settingsStorage = AudioSettingsStorage(storage: mockStorage)
        
        // Test microphone mute update
        settingsStorage.updateMicrophoneMuted(true)
        #expect(settingsStorage.currentSettings.microphoneMuted == true)
        
        // Test volume updates
        try settingsStorage.updateAudioMixingVolume(50)
        #expect(settingsStorage.currentSettings.audioMixingVolume == 50)
        
        try settingsStorage.updatePlaybackSignalVolume(60)
        #expect(settingsStorage.currentSettings.playbackSignalVolume == 60)
        
        try settingsStorage.updateRecordingSignalVolume(70)
        #expect(settingsStorage.currentSettings.recordingSignalVolume == 70)
        
        // Test audio stream active update
        settingsStorage.updateLocalAudioStreamActive(false)
        #expect(settingsStorage.currentSettings.localAudioStreamActive == false)
    }
    
    @Test("AudioSettingsStorage validation test")
    func testSettingsValidation() async throws {
        let mockStorage = MockStorageProvider()
        let settingsStorage = AudioSettingsStorage(storage: mockStorage)
        
        // Test invalid volume ranges
        #expect(throws: RealtimeError.self) {
            try settingsStorage.updateAudioMixingVolume(-1)
        }
        
        #expect(throws: RealtimeError.self) {
            try settingsStorage.updateAudioMixingVolume(101)
        }
        
        #expect(throws: RealtimeError.self) {
            try settingsStorage.updatePlaybackSignalVolume(-1)
        }
        
        #expect(throws: RealtimeError.self) {
            try settingsStorage.updatePlaybackSignalVolume(101)
        }
        
        #expect(throws: RealtimeError.self) {
            try settingsStorage.updateRecordingSignalVolume(-1)
        }
        
        #expect(throws: RealtimeError.self) {
            try settingsStorage.updateRecordingSignalVolume(101)
        }
    }
    
    @Test("AudioSettingsStorage persistence test")
    func testSettingsPersistence() async throws {
        let mockStorage = MockStorageProvider()
        
        // Create first instance and update settings
        let settingsStorage1 = AudioSettingsStorage(storage: mockStorage)
        let testSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        try settingsStorage1.updateSettings(testSettings)
        
        // Create second instance with same storage - should load persisted settings
        let settingsStorage2 = AudioSettingsStorage(storage: mockStorage)
        
        let loadedSettings = settingsStorage2.currentSettings
        #expect(loadedSettings.microphoneMuted == true)
        #expect(loadedSettings.audioMixingVolume == 75)
        #expect(loadedSettings.playbackSignalVolume == 80)
        #expect(loadedSettings.recordingSignalVolume == 90)
        #expect(loadedSettings.localAudioStreamActive == false)
    }
    
    @Test("AudioSettingsStorage reset to defaults test")
    func testResetToDefaults() async throws {
        let mockStorage = MockStorageProvider()
        let settingsStorage = AudioSettingsStorage(storage: mockStorage)
        
        // Update to non-default settings
        let customSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 50,
            playbackSignalVolume: 60,
            recordingSignalVolume: 70,
            localAudioStreamActive: false
        )
        
        try settingsStorage.updateSettings(customSettings)
        #expect(settingsStorage.currentSettings.microphoneMuted == true)
        
        // Reset to defaults
        settingsStorage.resetToDefaults()
        
        let resetSettings = settingsStorage.currentSettings
        #expect(resetSettings.microphoneMuted == false)
        #expect(resetSettings.audioMixingVolume == 100)
        #expect(resetSettings.playbackSignalVolume == 100)
        #expect(resetSettings.recordingSignalVolume == 100)
        #expect(resetSettings.localAudioStreamActive == true)
    }
    
    @Test("AudioSettingsStorage clear all test")
    func testClearAll() async throws {
        let mockStorage = MockStorageProvider()
        let settingsStorage = AudioSettingsStorage(storage: mockStorage)
        
        // Update settings
        try settingsStorage.updateAudioMixingVolume(50)
        #expect(settingsStorage.currentSettings.audioMixingVolume == 50)
        
        // Clear all
        try settingsStorage.clearAll()
        
        // Should be reset to defaults
        let clearedSettings = settingsStorage.currentSettings
        #expect(clearedSettings.audioMixingVolume == 100)
    }
    
    @Test("AudioSettingsStorage reactive updates test")
    func testReactiveUpdates() async throws {
        let mockStorage = MockStorageProvider()
        let settingsStorage = AudioSettingsStorage(storage: mockStorage)
        
        var receivedSettings: [AudioSettings] = []
        let cancellable = settingsStorage.$currentSettings
            .sink { settings in
                receivedSettings.append(settings)
            }
        
        // Update microphone mute
        settingsStorage.updateMicrophoneMuted(true)
        
        // Give some time for the reactive update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Should have received at least 2 updates (initial + mute change)
        #expect(receivedSettings.count >= 2)
        #expect(receivedSettings.last?.microphoneMuted == true)
        
        cancellable.cancel()
    }
}