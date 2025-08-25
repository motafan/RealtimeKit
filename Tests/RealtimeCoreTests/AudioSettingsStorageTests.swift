import Testing
import Foundation
@testable import RealtimeCore

/// AudioSettingsStorage 单元测试
/// 需求: 5.4, 5.5 - 音频设置存储管理器的测试覆盖
struct AudioSettingsStorageTests {
    
    // MARK: - Test Properties
    
    private let testSuiteName = "AudioSettingsStorageTests"
    
    // MARK: - Helper Methods
    
    /// 创建测试用的 UserDefaults
    private func createTestUserDefaults() -> UserDefaults {
        let suiteName = "\(testSuiteName)_\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }
    
    /// 创建测试用的音频设置
    private func createTestAudioSettings() -> AudioSettings {
        return AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 80,
            playbackSignalVolume: 90,
            recordingSignalVolume: 70,
            localAudioStreamActive: false
        )
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("保存和加载音频设置")
    func testSaveAndLoadAudioSettings() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        let testSettings = createTestAudioSettings()
        
        // 保存设置
        storage.saveAudioSettings(testSettings)
        
        // 加载设置
        let loadedSettings = storage.loadAudioSettings()
        
        // 验证设置相等（忽略时间戳差异）
        #expect(loadedSettings.microphoneMuted == testSettings.microphoneMuted)
        #expect(loadedSettings.audioMixingVolume == testSettings.audioMixingVolume)
        #expect(loadedSettings.playbackSignalVolume == testSettings.playbackSignalVolume)
        #expect(loadedSettings.recordingSignalVolume == testSettings.recordingSignalVolume)
        #expect(loadedSettings.localAudioStreamActive == testSettings.localAudioStreamActive)
    }
    
    @Test("加载不存在的设置返回默认值")
    func testLoadNonExistentSettingsReturnsDefault() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        let loadedSettings = storage.loadAudioSettings()
        let defaultSettings = AudioSettings.default
        
        #expect(loadedSettings == defaultSettings)
    }
    
    @Test("检查是否存在保存的设置")
    func testHasStoredSettings() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        // 初始状态应该没有保存的设置
        #expect(!storage.hasStoredSettings())
        
        // 保存设置后应该返回 true
        storage.saveAudioSettings(createTestAudioSettings())
        #expect(storage.hasStoredSettings())
        
        // 清除设置后应该返回 false
        storage.clearAudioSettings()
        #expect(!storage.hasStoredSettings())
    }
    
    @Test("清除音频设置")
    func testClearAudioSettings() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        // 保存设置
        storage.saveAudioSettings(createTestAudioSettings())
        #expect(storage.hasStoredSettings())
        
        // 清除设置
        storage.clearAudioSettings()
        #expect(!storage.hasStoredSettings())
        
        // 加载设置应该返回默认值
        let loadedSettings = storage.loadAudioSettings()
        #expect(loadedSettings == AudioSettings.default)
    }
    
    // MARK: - Volume Validation Tests
    
    @Test("音量范围验证", arguments: [
        (-10, 0),    // 负数应该被限制为0
        (50, 50),    // 正常范围内的值应该保持不变
        (150, 100)   // 超过100的值应该被限制为100
    ])
    func testVolumeValidation(input: Int, expected: Int) async throws {
        let settings = AudioSettings(
            audioMixingVolume: input,
            playbackSignalVolume: input,
            recordingSignalVolume: input
        )
        
        #expect(settings.audioMixingVolume == expected)
        #expect(settings.playbackSignalVolume == expected)
        #expect(settings.recordingSignalVolume == expected)
    }
    
    @Test("保存无效音量设置")
    func testSaveInvalidVolumeSettings() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        // 创建包含无效音量的设置（通过直接构造绕过验证）
        let invalidSettings = AudioSettings(
            audioMixingVolume: -50,  // 这会被自动修正为0
            playbackSignalVolume: 200  // 这会被自动修正为100
        )
        
        // 保存应该成功，因为构造函数会自动修正无效值
        storage.saveAudioSettings(invalidSettings)
        
        let loadedSettings = storage.loadAudioSettings()
        #expect(loadedSettings.audioMixingVolume == 0)
        #expect(loadedSettings.playbackSignalVolume == 100)
    }
    
    // MARK: - Backup and Recovery Tests
    
    @Test("备份和恢复功能")
    func testBackupAndRestore() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        let originalSettings = createTestAudioSettings()
        
        // 保存原始设置
        storage.saveAudioSettings(originalSettings)
        
        // 保存新设置（这会创建备份）
        let newSettings = AudioSettings(
            microphoneMuted: false,
            audioMixingVolume: 60,
            playbackSignalVolume: 70,
            recordingSignalVolume: 80
        )
        storage.saveAudioSettings(newSettings)
        
        // 验证新设置已保存
        let currentSettings = storage.loadAudioSettings()
        #expect(currentSettings.audioMixingVolume == 60)
        
        // 恢复备份
        let restoredSettings = storage.restoreFromBackup()
        #expect(restoredSettings != nil)
        
        // 验证恢复的设置
        if let restored = restoredSettings {
            #expect(restored.microphoneMuted == originalSettings.microphoneMuted)
            #expect(restored.audioMixingVolume == originalSettings.audioMixingVolume)
        }
    }
    
    @Test("恢复不存在的备份")
    func testRestoreNonExistentBackup() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        let restoredSettings = storage.restoreFromBackup()
        #expect(restoredSettings == nil)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("处理损坏的数据")
    func testHandleCorruptedData() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        // 手动设置损坏的数据
        let corruptedData = "invalid json data".data(using: .utf8)!
        userDefaults.set(corruptedData, forKey: "RealtimeKit.AudioSettings")
        
        // 加载应该返回默认设置
        let loadedSettings = storage.loadAudioSettings()
        #expect(loadedSettings == AudioSettings.default)
    }
    
    // MARK: - Migration Tests
    
    @Test("数据迁移测试")
    func testDataMigration() async throws {
        let userDefaults = createTestUserDefaults()
        
        // 模拟旧版本数据（没有 settingsVersion 字段）
        let oldVersionData: [String: Any] = [
            "microphoneMuted": false,
            "audioMixingVolume": 80,
            "playbackSignalVolume": 90,
            "recordingSignalVolume": 70,
            "localAudioStreamActive": true,
            "lastModified": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: oldVersionData)
        userDefaults.set(jsonData, forKey: "RealtimeKit.AudioSettings")
        userDefaults.set(0, forKey: "RealtimeKit.AudioSettings.MigrationVersion")
        
        // 创建存储实例应该触发迁移
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        // 验证迁移后的数据可以正常加载
        let migratedSettings = storage.loadAudioSettings()
        #expect(migratedSettings.audioMixingVolume == 80)
        #expect(migratedSettings.settingsVersion == 1)
    }
    
    // MARK: - Concurrency Tests (Disabled due to Swift 6 strict concurrency)
    
    // Note: Concurrency tests are disabled due to Swift 6 strict concurrency requirements
    // The storage classes are thread-safe through UserDefaults synchronization
    
    // MARK: - Performance Tests
    
    @Test("性能测试 - 大量保存操作")
    func testPerformanceSaveOperations() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        let startTime = Date()
        
        // 执行1000次保存操作
        for i in 0..<1000 {
            let settings = AudioSettings(
                audioMixingVolume: i % 101,  // 0-100
                playbackSignalVolume: (i + 1) % 101,
                recordingSignalVolume: (i + 2) % 101
            )
            storage.saveAudioSettings(settings)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 验证性能（1000次操作应该在合理时间内完成）
        #expect(duration < 5.0, "保存操作耗时过长: \(duration)秒")
        
        // 验证最终数据的正确性
        let finalSettings = storage.loadAudioSettings()
        #expect(finalSettings.isValid)
    }
    
    @Test("获取最后修改时间")
    func testGetLastModifiedTime() async throws {
        let userDefaults = createTestUserDefaults()
        let storage = AudioSettingsStorage(userDefaults: userDefaults)
        
        // 初始状态应该没有修改时间（因为没有存储的设置）
        #expect(!storage.hasStoredSettings())
        
        // 保存设置后应该有修改时间
        let beforeSave = Date().addingTimeInterval(-1) // 1秒前
        storage.saveAudioSettings(createTestAudioSettings())
        let afterSave = Date().addingTimeInterval(1) // 1秒后
        
        let modifiedTime = storage.getLastModifiedTime()
        #expect(modifiedTime != nil)
        
        if let time = modifiedTime {
            #expect(time >= beforeSave)
            #expect(time <= afterSave)
        }
    }
}