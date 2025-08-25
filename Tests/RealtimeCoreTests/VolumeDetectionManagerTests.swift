import Testing
import Foundation
@testable import RealtimeCore

/// 音量检测管理器测试
/// 需求: 6.1, 6.2, 6.6, 测试要求 1, 18.1, 18.2
@Suite("Volume Detection Manager Tests")
@MainActor
struct VolumeDetectionManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test("音量检测管理器初始化")
    func testInitialization() async throws {
        let manager = VolumeDetectionManager()
        
        #expect(manager.config == VolumeDetectionConfig.default)
        #expect(!manager.isEnabled)
        #expect(manager.currentVolumeInfos.isEmpty)
        #expect(manager.dominantSpeaker == nil)
        #expect(manager.speakingUsers.isEmpty)
    }
    
    // MARK: - Detection Control Tests
    
    @Test("启用音量检测")
    func testEnableDetection() async throws {
        let manager = VolumeDetectionManager()
        
        manager.enableDetection()
        
        #expect(manager.isEnabled)
    }
    
    @Test("禁用音量检测")
    func testDisableDetection() async throws {
        let manager = VolumeDetectionManager()
        
        manager.enableDetection()
        #expect(manager.isEnabled)
        
        manager.disableDetection()
        
        #expect(!manager.isEnabled)
        #expect(manager.currentVolumeInfos.isEmpty)
        #expect(manager.dominantSpeaker == nil)
        #expect(manager.speakingUsers.isEmpty)
    }
    
    @Test("重复启用检测")
    func testRepeatedEnable() async throws {
        let manager = VolumeDetectionManager()
        
        manager.enableDetection()
        #expect(manager.isEnabled)
        
        // 重复启用应该没有副作用
        manager.enableDetection()
        #expect(manager.isEnabled)
    }
    
    @Test("重复禁用检测")
    func testRepeatedDisable() async throws {
        let manager = VolumeDetectionManager()
        
        manager.disableDetection()
        #expect(!manager.isEnabled)
        
        // 重复禁用应该没有副作用
        manager.disableDetection()
        #expect(!manager.isEnabled)
    }
    
    // MARK: - Configuration Tests
    
    @Test("更新检测配置")
    func testUpdateConfig() async throws {
        let manager = VolumeDetectionManager()
        
        let newConfig = VolumeDetectionConfig(
            detectionInterval: 500,
            speakingThreshold: 0.5,
            silenceThreshold: 0.1
        )
        
        manager.updateConfig(newConfig)
        
        #expect(manager.config.detectionInterval == 500)
        #expect(manager.config.speakingThreshold == 0.5)
        #expect(manager.config.silenceThreshold == 0.1)
    }
    
    @Test("更新无效配置")
    func testUpdateInvalidConfig() async throws {
        let manager = VolumeDetectionManager()
        let originalConfig = manager.config
        
        let invalidConfig = VolumeDetectionConfig(
            detectionInterval: 300,
            speakingThreshold: 0.1, // 小于静音阈值
            silenceThreshold: 0.3   // 大于说话阈值
        )
        
        manager.updateConfig(invalidConfig)
        
        // 配置应该保持不变
        #expect(manager.config.detectionInterval == originalConfig.detectionInterval)
        #expect(manager.config.speakingThreshold == originalConfig.speakingThreshold)
    }
    
    // MARK: - Volume Processing Tests
    
    @Test("处理音量数据")
    func testProcessVolumeData() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking),
            UserVolumeInfo(userId: "user2", volume: 50, vad: .notSpeaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        #expect(manager.currentVolumeInfos.count == 2)
        #expect(manager.speakingUsers.contains("user1"))
        #expect(!manager.speakingUsers.contains("user2"))
    }
    
    @Test("禁用状态下处理音量数据")
    func testProcessVolumeDataWhenDisabled() async throws {
        let manager = VolumeDetectionManager()
        // 不启用检测
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        #expect(manager.currentVolumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
    }
    
    @Test("过滤本地用户")
    func testFilterLocalUser() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        // 更新配置以排除本地用户
        let config = manager.config
        let newConfig = VolumeDetectionConfig(
            detectionInterval: config.detectionInterval,
            speakingThreshold: config.speakingThreshold,
            silenceThreshold: config.silenceThreshold,
            includeLocalUser: false
        )
        manager.updateConfig(newConfig)
        
        let volumeInfos = [
            UserVolumeInfo(userId: "local_user", volume: 100, vad: .speaking),
            UserVolumeInfo(userId: "remote_user", volume: 80, vad: .speaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        #expect(manager.currentVolumeInfos.count == 1)
        #expect(manager.currentVolumeInfos.first?.userId == "remote_user")
    }
    
    // MARK: - Speaking State Tests
    
    @Test("说话状态变化检测")
    func testSpeakingStateChange() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        var stateChanges: [(String, Bool)] = []
        manager.onSpeakingStateChanged = { userId, isSpeaking in
            stateChanges.append((userId, isSpeaking))
        }
        
        // 用户开始说话
        let volumeInfos1 = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking)
        ]
        manager.processVolumeData(volumeInfos1)
        
        #expect(stateChanges.count == 1)
        #expect(stateChanges[0].0 == "user1")
        #expect(stateChanges[0].1 == true)
        
        // 用户停止说话
        let volumeInfos2 = [
            UserVolumeInfo(userId: "user1", volume: 20, vad: .notSpeaking)
        ]
        manager.processVolumeData(volumeInfos2)
        
        #expect(stateChanges.count == 2)
        #expect(stateChanges[1].0 == "user1")
        #expect(stateChanges[1].1 == false)
    }
    
    // MARK: - Dominant Speaker Tests
    
    @Test("主讲人检测")
    func testDominantSpeakerDetection() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        var dominantSpeakerChanges: [String?] = []
        manager.onDominantSpeakerChanged = { speaker in
            dominantSpeakerChanges.append(speaker)
        }
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 200, vad: .speaking),
            UserVolumeInfo(userId: "user2", volume: 100, vad: .speaking),
            UserVolumeInfo(userId: "user3", volume: 50, vad: .notSpeaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        #expect(manager.dominantSpeaker == "user1")
        #expect(dominantSpeakerChanges.count == 1)
        #expect(dominantSpeakerChanges[0] == "user1")
    }
    
    @Test("主讲人变化")
    func testDominantSpeakerChange() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        var dominantSpeakerChanges: [String?] = []
        manager.onDominantSpeakerChanged = { speaker in
            dominantSpeakerChanges.append(speaker)
        }
        
        // 第一次：user1 是主讲人
        let volumeInfos1 = [
            UserVolumeInfo(userId: "user1", volume: 200, vad: .speaking),
            UserVolumeInfo(userId: "user2", volume: 100, vad: .speaking)
        ]
        manager.processVolumeData(volumeInfos1)
        
        #expect(manager.dominantSpeaker == "user1")
        
        // 第二次：user2 成为主讲人
        let volumeInfos2 = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking),
            UserVolumeInfo(userId: "user2", volume: 250, vad: .speaking)
        ]
        manager.processVolumeData(volumeInfos2)
        
        #expect(manager.dominantSpeaker == "user2")
        #expect(dominantSpeakerChanges.count == 2)
        #expect(dominantSpeakerChanges[1] == "user2")
    }
    
    @Test("无主讲人情况")
    func testNoDominantSpeaker() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 20, vad: .notSpeaking),
            UserVolumeInfo(userId: "user2", volume: 15, vad: .notSpeaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        #expect(manager.dominantSpeaker == nil)
    }
    
    // MARK: - Query Methods Tests
    
    @Test("获取用户音量信息")
    func testGetVolumeInfo() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking),
            UserVolumeInfo(userId: "user2", volume: 50, vad: .notSpeaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        let user1Info = manager.getVolumeInfo(for: "user1")
        #expect(user1Info != nil)
        #expect(user1Info?.volume == 100)
        
        let nonexistentInfo = manager.getVolumeInfo(for: "user3")
        #expect(nonexistentInfo == nil)
    }
    
    @Test("检查用户说话状态")
    func testIsUserSpeaking() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking),
            UserVolumeInfo(userId: "user2", volume: 50, vad: .notSpeaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        #expect(manager.isUserSpeaking("user1"))
        #expect(!manager.isUserSpeaking("user2"))
        #expect(!manager.isUserSpeaking("user3"))
    }
    
    // MARK: - History Tests
    
    @Test("音量历史记录")
    func testVolumeHistory() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        // 处理多次音量数据
        for i in 1...5 {
            let volumeInfos = [
                UserVolumeInfo(userId: "user1", volume: i * 20, vad: .speaking)
            ]
            manager.processVolumeData(volumeInfos)
        }
        
        let history = manager.getVolumeHistory(for: "user1")
        #expect(history.count == 5)
        #expect(history.last?.volume == 100)
    }
    
    @Test("获取音量历史限制数量")
    func testVolumeHistoryLimit() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        // 处理10次音量数据
        for i in 1...10 {
            let volumeInfos = [
                UserVolumeInfo(userId: "user1", volume: i * 10, vad: .speaking)
            ]
            manager.processVolumeData(volumeInfos)
        }
        
        let limitedHistory = manager.getVolumeHistory(for: "user1", limit: 3)
        #expect(limitedHistory.count == 3)
        #expect(limitedHistory.last?.volume == 100) // 最后一次的音量
    }
    
    @Test("清除音量历史")
    func testClearHistory() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking)
        ]
        manager.processVolumeData(volumeInfos)
        
        #expect(!manager.getVolumeHistory(for: "user1").isEmpty)
        
        manager.clearHistory(for: "user1")
        
        #expect(manager.getVolumeHistory(for: "user1").isEmpty)
    }
    
    @Test("清除所有历史")
    func testClearAllHistory() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking),
            UserVolumeInfo(userId: "user2", volume: 80, vad: .speaking)
        ]
        manager.processVolumeData(volumeInfos)
        
        #expect(!manager.getAllVolumeHistory().isEmpty)
        
        manager.clearHistory()
        
        #expect(manager.getAllVolumeHistory().isEmpty)
    }
    
    // MARK: - Preset Management Tests
    
    @Test("保存和加载预设")
    func testSaveAndLoadPreset() async throws {
        let manager = VolumeDetectionManager()
        
        let customConfig = VolumeDetectionConfig(
            detectionInterval: 500,
            speakingThreshold: 0.5
        )
        manager.updateConfig(customConfig)
        
        manager.savePreset(name: "自定义预设")
        
        // 修改配置
        let anotherConfig = VolumeDetectionConfig(
            detectionInterval: 200,
            speakingThreshold: 0.2
        )
        manager.updateConfig(anotherConfig)
        
        // 加载预设
        let loaded = manager.loadPreset(name: "自定义预设")
        
        #expect(loaded)
        #expect(manager.config.detectionInterval == 500)
        #expect(manager.config.speakingThreshold == 0.5)
    }
    
    @Test("删除预设")
    func testDeletePreset() async throws {
        let manager = VolumeDetectionManager()
        
        manager.savePreset(name: "测试预设")
        #expect(manager.getPresetNames().contains("测试预设"))
        
        manager.deletePreset(name: "测试预设")
        #expect(!manager.getPresetNames().contains("测试预设"))
    }
    
    // MARK: - State Management Tests
    
    @Test("重置状态")
    func testResetState() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking)
        ]
        manager.processVolumeData(volumeInfos)
        
        #expect(!manager.currentVolumeInfos.isEmpty)
        #expect(!manager.speakingUsers.isEmpty)
        
        manager.resetState()
        
        #expect(manager.currentVolumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
        #expect(manager.dominantSpeaker == nil)
    }
    
    @Test("重置存储数据")
    func testResetStorage() async throws {
        let manager = VolumeDetectionManager()
        
        // 修改配置和保存预设
        let customConfig = VolumeDetectionConfig(detectionInterval: 500)
        manager.updateConfig(customConfig)
        manager.savePreset(name: "测试预设")
        
        manager.resetStorage()
        
        #expect(manager.config == VolumeDetectionConfig.default)
        #expect(manager.getPresetNames().isEmpty)
    }
    
    // MARK: - @RealtimeStorage Integration Tests
    
    @Test("配置数据持久化")
    func testConfigPersistence() async throws {
        let manager1 = VolumeDetectionManager()
        
        let customConfig = VolumeDetectionConfig(
            detectionInterval: 500,
            speakingThreshold: 0.5,
            silenceThreshold: 0.1
        )
        manager1.updateConfig(customConfig)
        
        // 创建新的管理器实例
        let manager2 = VolumeDetectionManager()
        
        #expect(manager2.config.detectionInterval == 500)
        #expect(manager2.config.speakingThreshold == 0.5)
        #expect(manager2.config.silenceThreshold == 0.1)
    }
    
    @Test("预设数据持久化")
    func testPresetsPersistence() async throws {
        let manager1 = VolumeDetectionManager()
        
        let customConfig = VolumeDetectionConfig(detectionInterval: 500)
        manager1.updateConfig(customConfig)
        manager1.savePreset(name: "持久化预设")
        
        // 创建新的管理器实例
        let manager2 = VolumeDetectionManager()
        
        #expect(manager2.getPresetNames().contains("持久化预设"))
        
        let loaded = manager2.loadPreset(name: "持久化预设")
        #expect(loaded)
        #expect(manager2.config.detectionInterval == 500)
    }
    
    // MARK: - Event Handler Tests
    
    @Test("音量更新事件")
    func testVolumeUpdateEvent() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        var receivedVolumeInfos: [UserVolumeInfo]?
        manager.onVolumeUpdate = { volumeInfos in
            receivedVolumeInfos = volumeInfos
        }
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100, vad: .speaking)
        ]
        
        manager.processVolumeData(volumeInfos)
        
        #expect(receivedVolumeInfos != nil)
        #expect(receivedVolumeInfos?.count == 1)
        #expect(receivedVolumeInfos?.first?.userId == "user1")
    }
    
    // MARK: - Performance Tests
    
    @Test("大量音量数据处理性能")
    func testLargeVolumeDataPerformance() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        // 创建大量音量数据
        var volumeInfos: [UserVolumeInfo] = []
        for i in 1...100 {
            volumeInfos.append(UserVolumeInfo(
                userId: "user\(i)",
                volume: i % 255,
                vad: i % 2 == 0 ? .speaking : .notSpeaking
            ))
        }
        
        let startTime = Date()
        manager.processVolumeData(volumeInfos)
        let endTime = Date()
        
        #expect(manager.currentVolumeInfos.count == 100)
        #expect(endTime.timeIntervalSince(startTime) < 0.1) // 应该在100ms内完成
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("空音量数据处理")
    func testEmptyVolumeData() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        manager.processVolumeData([])
        
        #expect(manager.currentVolumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
        #expect(manager.dominantSpeaker == nil)
    }
    
    @Test("音量历史大小限制")
    func testVolumeHistorySizeLimit() async throws {
        let manager = VolumeDetectionManager()
        manager.enableDetection()
        
        // 处理大量音量数据（超过限制）
        for i in 1...150 {
            let volumeInfos = [
                UserVolumeInfo(userId: "user1", volume: i % 255, vad: .speaking)
            ]
            manager.processVolumeData(volumeInfos)
        }
        
        let history = manager.getVolumeHistory(for: "user1")
        #expect(history.count <= 100) // 应该被限制在100个以内
    }
}