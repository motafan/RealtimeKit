import Testing
import Foundation
@testable import RealtimeCore

/// 音频设置管理器测试（使用新的自动持久化机制）
/// 需求: 5.4, 5.5, 18.1, 18.2, 18.3, 测试要求 1
@Suite("Audio Settings Manager Tests")
@MainActor
struct AudioSettingsManagerTests {
    
    // Helper function to compare AudioSettings ignoring timestamp
    private func audioSettingsEqual(_ lhs: AudioSettings, _ rhs: AudioSettings, ignoreTimestamp: Bool = true) -> Bool {
        if ignoreTimestamp {
            return lhs.microphoneMuted == rhs.microphoneMuted &&
                   lhs.audioMixingVolume == rhs.audioMixingVolume &&
                   lhs.playbackSignalVolume == rhs.playbackSignalVolume &&
                   lhs.recordingSignalVolume == rhs.recordingSignalVolume &&
                   lhs.localAudioStreamActive == rhs.localAudioStreamActive &&
                   lhs.settingsVersion == rhs.settingsVersion
        } else {
            return lhs == rhs
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("音频设置管理器初始化")
    func testInitialization() async throws {
        // 清理之前的数据
        let cleanup = AudioSettingsManager()
        cleanup.resetStorage()
        
        let manager = AudioSettingsManager()
        
        #expect(audioSettingsEqual(manager.settings, AudioSettings.default))
        #expect(manager.isValid)
        #expect(manager.lastModified <= Date())
    }
    
    // MARK: - Migration Tests
    
    @Test("数据迁移功能")
    func testDataMigration() async throws {
        // 首先清理所有数据
        let cleanup = AudioSettingsManager()
        cleanup.resetStorage()
        UserDefaults.standard.removeObject(forKey: "RealtimeKit.AudioSettings")
        
        // 模拟旧格式数据
        let legacySettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 80,
            playbackSignalVolume: 90,
            recordingSignalVolume: 70
        )
        
        // 将旧数据写入 UserDefaults
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacySettings)
        UserDefaults.standard.set(legacyData, forKey: "RealtimeKit.AudioSettings")
        
        // 创建管理器，应该自动迁移数据
        let manager = AudioSettingsManager()
        
        // 验证数据已迁移
        #expect(manager.settings.microphoneMuted == true)
        #expect(manager.settings.audioMixingVolume == 80)
        #expect(manager.settings.playbackSignalVolume == 90)
        #expect(manager.settings.recordingSignalVolume == 70)
        
        // 验证旧数据已清理
        #expect(UserDefaults.standard.object(forKey: "RealtimeKit.AudioSettings") == nil)
    }
    
    // MARK: - Storage Health Tests
    
    @Test("存储健康状态检查")
    func testStorageHealthCheck() async throws {
        let manager = AudioSettingsManager()
        
        // 检查健康状态
        let healthStatus = manager.checkStorageHealth()
        
        // 健康状态可能有一些预期的问题，比如偏好设置未初始化
        #expect(healthStatus.lastChecked <= Date())
        
        // 如果有问题，应该是预期的问题
        if !healthStatus.isHealthy {
            #expect(healthStatus.issues.contains { $0.contains("Preferences") })
        }
    }
    
    @Test("存储维护功能")
    func testStorageMaintenance() async throws {
        let manager = AudioSettingsManager()
        
        // 添加一些预设
        manager.savePreset(name: "test_preset_1")
        manager.savePreset(name: "test_preset_2")
        
        let presetsBefore = manager.getPresetNames()
        #expect(presetsBefore.count >= 2)
        
        // 执行存储维护
        manager.performStorageMaintenance()
        
        // 验证维护完成（在这个测试中，预设不会被删除，因为它们是新创建的）
        let presetsAfter = manager.getPresetNames()
        #expect(presetsAfter.count == presetsBefore.count)
    }
    
    // MARK: - Auto-Persistence Tests
    
    @Test("自动持久化功能")
    func testAutoPersistence() async throws {
        // 创建第一个管理器实例
        let manager1 = AudioSettingsManager()
        manager1.resetStorage() // 清理数据
        
        // 修改设置
        manager1.updateAudioMixingVolume(75)
        manager1.setMicrophoneMuted(true)
        
        // 创建第二个管理器实例，验证数据自动持久化
        let manager2 = AudioSettingsManager()
        
        #expect(manager2.settings.audioMixingVolume == 75)
        #expect(manager2.settings.microphoneMuted == true)
    }
    
    @Test("命名空间隔离")
    func testNamespaceIsolation() async throws {
        let manager = AudioSettingsManager()
        
        // 验证使用了正确的命名空间
        #expect(StorageManager.shared.registeredNamespaces.contains("RealtimeKit"))
        
        // 设置一些值
        manager.updateAudioMixingVolume(85)
        
        // 直接访问 UserDefaults 验证键名包含命名空间
        let hasNamespacedKey = UserDefaults.standard.dictionaryRepresentation().keys.contains { key in
            key.contains("RealtimeKit.audio_settings")
        }
        #expect(hasNamespacedKey == true)
    }
    
    // MARK: - Volume Control Tests
    
    @Test("更新音频混音音量")
    func testUpdateAudioMixingVolume() async throws {
        let manager = AudioSettingsManager()
        var settingsChanged = false
        
        manager.onSettingsChanged = { _ in
            settingsChanged = true
        }
        
        manager.updateAudioMixingVolume(75)
        
        #expect(manager.settings.audioMixingVolume == 75)
        #expect(settingsChanged)
        #expect(manager.isValid)
    }
    
    @Test("更新播放信号音量")
    func testUpdatePlaybackSignalVolume() async throws {
        let manager = AudioSettingsManager()
        
        manager.updatePlaybackSignalVolume(80)
        
        #expect(manager.settings.playbackSignalVolume == 80)
        #expect(manager.isValid)
    }
    
    @Test("更新录音信号音量")
    func testUpdateRecordingSignalVolume() async throws {
        let manager = AudioSettingsManager()
        
        manager.updateRecordingSignalVolume(90)
        
        #expect(manager.settings.recordingSignalVolume == 90)
        #expect(manager.isValid)
    }
    
    @Test("批量更新音量设置")
    func testUpdateVolumes() async throws {
        let manager = AudioSettingsManager()
        
        manager.updateVolumes(
            audioMixing: 70,
            playbackSignal: 80,
            recordingSignal: 90
        )
        
        #expect(manager.settings.audioMixingVolume == 70)
        #expect(manager.settings.playbackSignalVolume == 80)
        #expect(manager.settings.recordingSignalVolume == 90)
        #expect(manager.isValid)
    }
    
    @Test("无效音量值应该触发验证错误", arguments: [-10, 150, 200])
    func testInvalidVolumeValidation(invalidVolume: Int) async throws {
        let manager = AudioSettingsManager()
        var validationError: AudioSettingsError?
        
        manager.onValidationError = { error in
            validationError = error
        }
        
        manager.updateAudioMixingVolume(invalidVolume)
        
        #expect(validationError != nil)
        #expect(manager.settings.audioMixingVolume == AudioSettings.defaultVolume) // 应该保持默认值
    }
    
    // MARK: - Microphone Control Tests
    
    @Test("切换麦克风静音状态")
    func testToggleMicrophone() async throws {
        let manager = AudioSettingsManager()
        
        let originalState = manager.settings.microphoneMuted
        manager.toggleMicrophone()
        
        #expect(manager.settings.microphoneMuted == !originalState)
    }
    
    @Test("设置麦克风静音状态")
    func testSetMicrophoneMuted() async throws {
        let manager = AudioSettingsManager()
        
        manager.setMicrophoneMuted(true)
        #expect(manager.settings.microphoneMuted)
        
        manager.setMicrophoneMuted(false)
        #expect(!manager.settings.microphoneMuted)
    }
    
    // MARK: - Stream Control Tests
    
    @Test("切换音频流状态")
    func testToggleAudioStream() async throws {
        let manager = AudioSettingsManager()
        
        let originalState = manager.settings.localAudioStreamActive
        manager.toggleAudioStream()
        
        #expect(manager.settings.localAudioStreamActive == !originalState)
    }
    
    @Test("设置音频流状态")
    func testSetAudioStreamActive() async throws {
        let manager = AudioSettingsManager()
        
        manager.setAudioStreamActive(false)
        #expect(!manager.settings.localAudioStreamActive)
        
        manager.setAudioStreamActive(true)
        #expect(manager.settings.localAudioStreamActive)
    }
    
    // MARK: - Preset Management Tests
    
    @Test("保存和加载预设")
    func testSaveAndLoadPreset() async throws {
        let manager = AudioSettingsManager()
        
        // 修改设置
        manager.updateAudioMixingVolume(75)
        manager.setMicrophoneMuted(true)
        
        // 保存预设
        manager.savePreset(name: "测试预设")
        
        // 修改设置
        manager.updateAudioMixingVolume(50)
        manager.setMicrophoneMuted(false)
        
        // 加载预设
        let loaded = manager.loadPreset(name: "测试预设")
        
        #expect(loaded)
        #expect(manager.settings.audioMixingVolume == 75)
        #expect(manager.settings.microphoneMuted)
    }
    
    @Test("加载不存在的预设")
    func testLoadNonexistentPreset() async throws {
        let manager = AudioSettingsManager()
        
        let loaded = manager.loadPreset(name: "不存在的预设")
        
        #expect(!loaded)
    }
    
    @Test("删除预设")
    func testDeletePreset() async throws {
        let manager = AudioSettingsManager()
        
        manager.savePreset(name: "测试预设")
        #expect(manager.getPresetNames().contains("测试预设"))
        
        manager.deletePreset(name: "测试预设")
        #expect(!manager.getPresetNames().contains("测试预设"))
    }
    
    @Test("获取预设名称")
    func testGetPresetNames() async throws {
        let manager = AudioSettingsManager()
        
        manager.savePreset(name: "预设A")
        manager.savePreset(name: "预设B")
        manager.savePreset(name: "预设C")
        
        let names = manager.getPresetNames()
        #expect(names.count == 3)
        #expect(names.contains("预设A"))
        #expect(names.contains("预设B"))
        #expect(names.contains("预设C"))
        #expect(names == names.sorted()) // 应该是排序的
    }
    
    // MARK: - Settings Management Tests
    
    @Test("重置为默认设置")
    func testResetToDefaults() async throws {
        let manager = AudioSettingsManager()
        
        // 修改设置
        manager.updateAudioMixingVolume(50)
        manager.setMicrophoneMuted(true)
        
        // 重置
        manager.resetToDefaults()
        
        #expect(audioSettingsEqual(manager.settings, AudioSettings.default))
    }
    
    @Test("导出设置")
    func testExportSettings() async throws {
        let manager = AudioSettingsManager()
        
        manager.updateAudioMixingVolume(75)
        
        let exportedData = manager.exportSettings()
        
        #expect(exportedData != nil)
        #expect(!exportedData!.isEmpty)
    }
    
    @Test("导入设置")
    func testImportSettings() async throws {
        let manager1 = AudioSettingsManager()
        
        // 修改设置
        manager1.updateAudioMixingVolume(75)
        manager1.setMicrophoneMuted(true)
        
        // 导出设置
        let exportedData = manager1.exportSettings()!
        
        // 创建新的管理器并导入设置
        let manager2 = AudioSettingsManager()
        let imported = manager2.importSettings(from: exportedData)
        
        #expect(imported)
        #expect(manager2.settings.audioMixingVolume == 75)
        #expect(manager2.settings.microphoneMuted)
    }
    
    @Test("导入无效设置数据")
    func testImportInvalidSettings() async throws {
        let manager = AudioSettingsManager()
        let invalidData = "invalid json".data(using: .utf8)!
        
        let imported = manager.importSettings(from: invalidData)
        
        #expect(!imported)
        #expect(audioSettingsEqual(manager.settings, AudioSettings.default)) // 应该保持默认值
    }
    
    // MARK: - Validation Tests
    
    @Test("验证设置")
    func testValidateSettings() async throws {
        let manager = AudioSettingsManager()
        
        // 有效设置
        let errors = manager.validateSettings()
        #expect(errors.isEmpty)
        #expect(manager.isValid)
    }
    
    @Test("验证无效设置")
    func testValidateInvalidSettings() async throws {
        let manager = AudioSettingsManager()
        
        // 直接设置无效的设置（绕过验证）
        manager.settings = AudioSettings(
            audioMixingVolume: 150, // 无效值
            playbackSignalVolume: -10, // 无效值
            recordingSignalVolume: 50
        )
        
        let errors = manager.validateSettings()
        #expect(errors.count >= 2) // 至少有两个错误
        #expect(!manager.isValid)
    }
    
    // MARK: - Storage Tests
    
    @Test("重置存储数据")
    func testResetStorage() async throws {
        let manager = AudioSettingsManager()
        
        // 修改设置和预设
        manager.updateAudioMixingVolume(75)
        manager.savePreset(name: "测试预设")
        
        manager.resetStorage()
        
        #expect(audioSettingsEqual(manager.settings, AudioSettings.default))
        #expect(manager.getPresetNames().isEmpty)
    }
    
    // MARK: - @RealtimeStorage Integration Tests
    
    @Test("设置数据持久化")
    func testSettingsPersistence() async throws {
        let manager1 = AudioSettingsManager()
        
        manager1.updateAudioMixingVolume(75)
        manager1.updatePlaybackSignalVolume(85)
        manager1.setMicrophoneMuted(true)
        
        // 创建新的管理器实例，应该能够恢复设置
        let manager2 = AudioSettingsManager()
        
        #expect(manager2.settings.audioMixingVolume == 75)
        #expect(manager2.settings.playbackSignalVolume == 85)
        #expect(manager2.settings.microphoneMuted)
    }
    
    @Test("预设数据持久化")
    func testPresetsPersistence() async throws {
        let manager1 = AudioSettingsManager()
        
        manager1.updateAudioMixingVolume(75)
        manager1.savePreset(name: "测试预设")
        
        // 创建新的管理器实例
        let manager2 = AudioSettingsManager()
        
        #expect(manager2.getPresetNames().contains("测试预设"))
        
        let loaded = manager2.loadPreset(name: "测试预设")
        #expect(loaded)
        #expect(manager2.settings.audioMixingVolume == 75)
    }
    
    // MARK: - Event Handler Tests
    
    @Test("设置变化事件")
    func testSettingsChangedEvent() async throws {
        let manager = AudioSettingsManager()
        var changedSettings: AudioSettings?
        
        manager.onSettingsChanged = { settings in
            changedSettings = settings
        }
        
        manager.updateAudioMixingVolume(75)
        
        #expect(changedSettings != nil)
        #expect(changedSettings?.audioMixingVolume == 75)
    }
    
    @Test("验证错误事件")
    func testValidationErrorEvent() async throws {
        let manager = AudioSettingsManager()
        var validationError: AudioSettingsError?
        
        manager.onValidationError = { error in
            validationError = error
        }
        
        manager.updateAudioMixingVolume(150) // 无效值
        
        #expect(validationError != nil)
        if case .invalidVolume(let volume, _) = validationError {
            #expect(volume == 150)
        } else {
            #expect(Bool(false), "Expected invalidVolume error")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("大量预设性能测试")
    func testLargePresetsPerformance() async throws {
        let manager = AudioSettingsManager()
        
        // 创建大量预设
        for i in 1...100 {
            manager.updateAudioMixingVolume(i % 100)
            manager.savePreset(name: "预设\(i)")
        }
        
        let startTime = Date()
        let names = manager.getPresetNames()
        let endTime = Date()
        
        #expect(names.count == 100)
        #expect(endTime.timeIntervalSince(startTime) < 0.1) // 应该在100ms内完成
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("边界值音量测试", arguments: [0, 100])
    func testBoundaryVolumeValues(volume: Int) async throws {
        let manager = AudioSettingsManager()
        
        manager.updateAudioMixingVolume(volume)
        
        #expect(manager.settings.audioMixingVolume == volume)
        #expect(manager.isValid)
    }
    
    @Test("最后修改时间更新")
    func testLastModifiedUpdate() async throws {
        let manager = AudioSettingsManager()
        let initialTime = manager.lastModified
        
        // 等待一小段时间
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01秒
        
        manager.updateAudioMixingVolume(75)
        
        #expect(manager.lastModified > initialTime)
    }
}