// AudioSettingsStorageTests.swift
// Comprehensive unit tests for AudioSettingsStorage

import Testing
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
        
        func removeValue(forKey key: String) {
            storage.removeValue(forKey: key)
        }
        
        func hasValue(forKey key: String) -> Bool {
            return storage[key] != nil
        }
        
        func getAllKeys() -> [String] {
            return Array(storage.keys)
        }
        
        func clear() {
            storage.removeAll()
        }
    }
    
    final class MockUserDefaults: UserDefaults {
        private var storage: [String: Any] = [:]
        
        override func set(_ value: Any?, forKey defaultName: String) {
            storage[defaultName] = value
        }
        
        override func data(forKey defaultName: String) -> Data? {
            return storage[defaultName] as? Data
        }
        
        override func removeObject(forKey defaultName: String) {
            storage.removeValue(forKey: defaultName)
        }
        
        override func object(forKey defaultName: String) -> Any? {
            return storage[defaultName]
        }
        
        func reset() {
            storage.removeAll()
        }
    }
    
    // MARK: - Test Setup
    
    private func createStorage() -> AudioSettingsStorage {
        let mockDefaults = MockUserDefaults()
        return AudioSettingsStorage(storage: MockStorageProvider())
    }
    
    private func createTestSettings() -> AudioSettings {
        return AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
    }
    
    // MARK: - Basic Storage Tests
    
    @Test("Save audio settings")
    func testSaveAudioSettings() throws {
        let storage = createStorage()
        let testSettings = createTestSettings()
        
        try storage.saveAudioSettings(testSettings)
        
        // Verify settings were saved by loading them back
        let loadedSettings = storage.loadAudioSettings()
        
        #expect(loadedSettings.microphoneMuted == testSettings.microphoneMuted)
        #expect(loadedSettings.audioMixingVolume == testSettings.audioMixingVolume)
        #expect(loadedSettings.playbackSignalVolume == testSettings.playbackSignalVolume)
        #expect(loadedSettings.recordingSignalVolume == testSettings.recordingSignalVolume)
        #expect(loadedSettings.localAudioStreamActive == testSettings.localAudioStreamActive)
    }
    
    @Test("Load audio settings when none exist")
    func testLoadAudioSettingsWhenNoneExist() {
        let storage = createStorage()
        
        let loadedSettings = storage.loadAudioSettings()
        
        // Should return default settings
        #expect(loadedSettings == AudioSettings.default)
    }
    
    @Test("Load audio settings after save")
    func testLoadAudioSettingsAfterSave() throws {
        let storage = createStorage()
        let testSettings = createTestSettings()
        
        try storage.saveAudioSettings(testSettings)
        let loadedSettings = storage.loadAudioSettings()
        
        #expect(loadedSettings.microphoneMuted == testSettings.microphoneMuted)
        #expect(loadedSettings.audioMixingVolume == testSettings.audioMixingVolume)
        #expect(loadedSettings.playbackSignalVolume == testSettings.playbackSignalVolume)
        #expect(loadedSettings.recordingSignalVolume == testSettings.recordingSignalVolume)
        #expect(loadedSettings.localAudioStreamActive == testSettings.localAudioStreamActive)
    }
    
    @Test("Clear audio settings")
    func testClearAudioSettings() throws {
        let storage = createStorage()
        let testSettings = createTestSettings()
        
        // Save settings first
        try storage.saveAudioSettings(testSettings)
        
        // Verify they exist
        let loadedSettings = storage.loadAudioSettings()
        #expect(loadedSettings != AudioSettings.default)
        
        // Clear settings
        storage.clearAudioSettings()
        
        // Should now return default settings
        let clearedSettings = storage.loadAudioSettings()
        #expect(clearedSettings == AudioSettings.default)
    }
    
    // MARK: - Settings Validation Tests
    
    @Test("Save settings with clamped values")
    func testSaveSettingsWithClampedValues() throws {
        let storage = createStorage()
        
        // Create settings with out-of-range values
        let invalidSettings = AudioSettings(
            microphoneMuted: false,
            audioMixingVolume: 150,    // Above maximum
            playbackSignalVolume: -10, // Below minimum
            recordingSignalVolume: 200, // Above maximum
            localAudioStreamActive: true
        )
        
        try storage.saveAudioSettings(invalidSettings)
        let loadedSettings = storage.loadAudioSettings()
        
        // Values should be clamped to valid ranges
        #expect(loadedSettings.audioMixingVolume == 100)
        #expect(loadedSettings.playbackSignalVolume == 0)
        #expect(loadedSettings.recordingSignalVolume == 100)
    }
    
    @Test("Settings equality comparison")
    func testSettingsEqualityComparison() throws {
        let storage = createStorage()
        let settings1 = createTestSettings()
        let settings2 = createTestSettings()
        
        #expect(settings1 == settings2)
        
        let differentSettings = AudioSettings(
            microphoneMuted: false, // Different from test settings
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        #expect(settings1 != differentSettings)
    }
    
    // MARK: - Settings Update Tests
    
    @Test("Update individual volume settings")
    func testUpdateIndividualVolumeSettings() throws {
        let storage = createStorage()
        let initialSettings = AudioSettings.default
        
        try storage.saveAudioSettings(initialSettings)
        
        // Update only audio mixing volume
        try storage.updateAudioMixingVolume(50)
        let updatedSettings = storage.loadAudioSettings()
        
        #expect(updatedSettings.audioMixingVolume == 50)
        #expect(updatedSettings.playbackSignalVolume == initialSettings.playbackSignalVolume)
        #expect(updatedSettings.recordingSignalVolume == initialSettings.recordingSignalVolume)
    }
    
    @Test("Update microphone mute state")
    func testUpdateMicrophoneMuteState() throws {
        let storage = createStorage()
        let initialSettings = AudioSettings.default
        
        try storage.saveAudioSettings(initialSettings)
        
        // Update mute state
        try storage.updateMicrophoneMuted(true)
        let updatedSettings = storage.loadAudioSettings()
        
        #expect(updatedSettings.microphoneMuted == true)
        #expect(updatedSettings.audioMixingVolume == initialSettings.audioMixingVolume)
    }
    
    @Test("Update local audio stream state")
    func testUpdateLocalAudioStreamState() throws {
        let storage = createStorage()
        let initialSettings = AudioSettings.default
        
        try storage.saveAudioSettings(initialSettings)
        
        // Update stream state
        try storage.updateLocalAudioStreamActive(false)
        let updatedSettings = storage.loadAudioSettings()
        
        #expect(updatedSettings.localAudioStreamActive == false)
        #expect(updatedSettings.microphoneMuted == initialSettings.microphoneMuted)
    }
    
    // MARK: - Settings History Tests
    
    @Test("Settings history tracking")
    func testSettingsHistoryTracking() throws {
        let storage = createStorage()
        storage.enableHistoryTracking(maxHistorySize: 5)
        
        // Save multiple different settings
        for i in 1...3 {
            let settings = AudioSettings(
                audioMixingVolume: i * 20,
                playbackSignalVolume: i * 25,
                recordingSignalVolume: i * 30
            )
            try storage.saveAudioSettings(settings)
        }
        
        let history = storage.getSettingsHistory()
        #expect(history.count == 3)
        
        // History should be in chronological order
        #expect(history[0].audioMixingVolume == 20)
        #expect(history[1].audioMixingVolume == 40)
        #expect(history[2].audioMixingVolume == 60)
    }
    
    @Test("Settings history size limit")
    func testSettingsHistorySizeLimit() throws {
        let storage = createStorage()
        storage.enableHistoryTracking(maxHistorySize: 3)
        
        // Save more settings than history limit
        for i in 1...5 {
            let settings = AudioSettings(audioMixingVolume: i * 10)
            try storage.saveAudioSettings(settings)
        }
        
        let history = storage.getSettingsHistory()
        #expect(history.count == 3)
        
        // Should contain the most recent settings
        #expect(history[0].audioMixingVolume == 30) // 3rd setting
        #expect(history[1].audioMixingVolume == 40) // 4th setting
        #expect(history[2].audioMixingVolume == 50) // 5th setting
    }
    
    @Test("Clear settings history")
    func testClearSettingsHistory() throws {
        let storage = createStorage()
        storage.enableHistoryTracking(maxHistorySize: 5)
        
        // Add some history
        for i in 1...3 {
            let settings = AudioSettings(audioMixingVolume: i * 20)
            try storage.saveAudioSettings(settings)
        }
        
        #expect(storage.getSettingsHistory().count == 3)
        
        storage.clearSettingsHistory()
        #expect(storage.getSettingsHistory().isEmpty)
    }
    
    // MARK: - Settings Backup and Restore Tests
    
    @Test("Backup and restore settings")
    func testBackupAndRestoreSettings() throws {
        let storage = createStorage()
        let testSettings = createTestSettings()
        
        try storage.saveAudioSettings(testSettings)
        
        // Create backup
        let backup = try storage.createBackup()
        #expect(backup != nil)
        
        // Clear current settings
        storage.clearAudioSettings()
        #expect(storage.loadAudioSettings() == AudioSettings.default)
        
        // Restore from backup
        try storage.restoreFromBackup(backup)
        let restoredSettings = storage.loadAudioSettings()
        
        #expect(restoredSettings == testSettings)
    }
    
    @Test("Export and import settings")
    func testExportAndImportSettings() throws {
        let storage = createStorage()
        let testSettings = createTestSettings()
        
        try storage.saveAudioSettings(testSettings)
        
        // Export settings
        let exportedData = try storage.exportSettings()
        #expect(exportedData.count > 0)
        
        // Clear current settings
        storage.clearAudioSettings()
        
        // Import settings
        try storage.importSettings(from: exportedData)
        let importedSettings = storage.loadAudioSettings()
        
        #expect(importedSettings == testSettings)
    }
    
    // MARK: - Settings Migration Tests
    
    @Test("Settings migration from older version")
    func testSettingsMigrationFromOlderVersion() throws {
        let storage = createStorage()
        
        // Simulate older version settings (missing some fields)
        let legacyData = """
        {
            "microphoneMuted": true,
            "audioMixingVolume": 75,
            "playbackSignalVolume": 80
        }
        """.data(using: .utf8)!
        
        // Manually set legacy data
        if let mockDefaults = storage.userDefaults as? MockUserDefaults {
            mockDefaults.set(legacyData, forKey: "RealtimeKit.AudioSettings")
        }
        
        // Load settings should handle migration
        let migratedSettings = storage.loadAudioSettings()
        
        #expect(migratedSettings.microphoneMuted == true)
        #expect(migratedSettings.audioMixingVolume == 75)
        #expect(migratedSettings.playbackSignalVolume == 80)
        #expect(migratedSettings.recordingSignalVolume == 100) // Default value
        #expect(migratedSettings.localAudioStreamActive == true) // Default value
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle corrupted settings data")
    func testHandleCorruptedSettingsData() throws {
        let storage = createStorage()
        
        // Set corrupted data
        let corruptedData = "corrupted_json_data".data(using: .utf8)!
        if let mockDefaults = storage.userDefaults as? MockUserDefaults {
            mockDefaults.set(corruptedData, forKey: "RealtimeKit.AudioSettings")
        }
        
        // Should return default settings when data is corrupted
        let loadedSettings = storage.loadAudioSettings()
        #expect(loadedSettings == AudioSettings.default)
    }
    
    @Test("Handle storage write failure")
    func testHandleStorageWriteFailure() {
        // This test would require a mock that can simulate write failures
        // For now, we'll test that the method doesn't crash with invalid data
        let storage = createStorage()
        let testSettings = createTestSettings()
        
        // Should not throw for normal operation
        #expect(throws: Never.self) {
            try storage.saveAudioSettings(testSettings)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Settings save/load performance")
    func testSettingsSaveLoadPerformance() throws {
        let storage = createStorage()
        let testSettings = createTestSettings()
        
        let startTime = Date()
        
        // Perform multiple save/load operations
        for _ in 1...100 {
            try storage.saveAudioSettings(testSettings)
            let _ = storage.loadAudioSettings()
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 1.0) // 1 second for 100 operations
    }
    
    @Test("Large settings history performance")
    func testLargeSettingsHistoryPerformance() throws {
        let storage = createStorage()
        storage.enableHistoryTracking(maxHistorySize: 1000)
        
        let startTime = Date()
        
        // Add many settings to history
        for i in 1...1000 {
            let settings = AudioSettings(audioMixingVolume: i % 100)
            try storage.saveAudioSettings(settings)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should handle large history efficiently
        #expect(duration < 2.0) // 2 seconds for 1000 operations
        
        let history = storage.getSettingsHistory()
        #expect(history.count == 1000)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent settings operations")
    func testConcurrentSettingsOperations() async throws {
        let storage = createStorage()
        
        await withTaskGroup(of: Void.self) { group in
            // Concurrent saves
            for i in 1...10 {
                group.addTask {
                    let settings = AudioSettings(audioMixingVolume: i * 10)
                    do {
                        try storage.saveAudioSettings(settings)
                    } catch {
                        // Handle potential concurrent access issues
                    }
                }
            }
            
            // Concurrent loads
            for _ in 1...10 {
                group.addTask {
                    let _ = storage.loadAudioSettings()
                }
            }
        }
        
        // Should handle concurrent operations without crashing
        let finalSettings = storage.loadAudioSettings()
        #expect(finalSettings.audioMixingVolume >= 0)
        #expect(finalSettings.audioMixingVolume <= 100)
    }
    
    // MARK: - Settings Validation Tests
    
    @Test("Settings validation on load")
    func testSettingsValidationOnLoad() throws {
        let storage = createStorage()
        
        // Create settings with invalid JSON structure but valid values
        let partiallyValidData = """
        {
            "microphoneMuted": true,
            "audioMixingVolume": 75,
            "invalidField": "should_be_ignored"
        }
        """.data(using: .utf8)!
        
        if let mockDefaults = storage.userDefaults as? MockUserDefaults {
            mockDefaults.set(partiallyValidData, forKey: "RealtimeKit.AudioSettings")
        }
        
        let loadedSettings = storage.loadAudioSettings()
        
        // Should load valid fields and use defaults for missing ones
        #expect(loadedSettings.microphoneMuted == true)
        #expect(loadedSettings.audioMixingVolume == 75)
        #expect(loadedSettings.playbackSignalVolume == 100) // Default
        #expect(loadedSettings.recordingSignalVolume == 100) // Default
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Storage cleanup on deallocation")
    func testStorageCleanupOnDeallocation() throws {
        var storage: AudioSettingsStorage? = createStorage()
        
        weak var weakStorage = storage
        
        let testSettings = createTestSettings()
        try storage?.saveAudioSettings(testSettings)
        
        storage = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakStorage == nil)
    }
}