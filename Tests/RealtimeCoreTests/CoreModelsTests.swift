import Testing
import Foundation
@testable import RealtimeCore

/// 核心数据模型测试
/// 需求: 测试要求 1 - 使用 Swift Testing 框架
struct CoreModelsTests {
    
    // MARK: - UserRole Tests (需求 4.1, 4.2, 4.4, 测试要求 1)
    
    @Test("用户角色音频权限验证")
    func testUserRoleAudioPermissions() {
        // 测试主播权限
        #expect(UserRole.broadcaster.hasAudioPermission)
        #expect(!UserRole.broadcaster.hasModeratorPrivileges)
        
        // 测试观众权限
        #expect(!UserRole.audience.hasAudioPermission)
        #expect(!UserRole.audience.hasModeratorPrivileges)
        
        // 测试连麦嘉宾权限
        #expect(UserRole.coHost.hasAudioPermission)
        #expect(!UserRole.coHost.hasModeratorPrivileges)
        
        // 测试主持人权限
        #expect(UserRole.moderator.hasAudioPermission)
        #expect(UserRole.moderator.hasModeratorPrivileges)
    }
    
    @Test("用户角色视频权限验证")
    func testUserRoleVideoPermissions() {
        // 测试主播权限
        #expect(UserRole.broadcaster.hasVideoPermission)
        
        // 测试观众权限
        #expect(!UserRole.audience.hasVideoPermission)
        
        // 测试连麦嘉宾权限
        #expect(UserRole.coHost.hasVideoPermission)
        
        // 测试主持人权限（主持人不能发布视频）
        #expect(!UserRole.moderator.hasVideoPermission)
    }
    
    @Test("用户角色显示名称")
    func testUserRoleDisplayNames() {
        // 测试本地化显示名称不为空
        #expect(!UserRole.broadcaster.displayName.isEmpty)
        #expect(!UserRole.audience.displayName.isEmpty)
        #expect(!UserRole.coHost.displayName.isEmpty)
        #expect(!UserRole.moderator.displayName.isEmpty)
        
        // 测试英文fallback值（测试环境中的实际行为）
        #expect(UserRole.broadcaster.displayName == "Broadcaster")
        #expect(UserRole.audience.displayName == "Audience")
        #expect(UserRole.coHost.displayName == "Co-host")
        #expect(UserRole.moderator.displayName == "Moderator")
    }
    
    @Test("用户角色切换权限验证")
    func testUserRoleSwitchPermissions() {
        // 测试主播可以切换的角色
        #expect(UserRole.broadcaster.canSwitchToRole == [.moderator])
        #expect(UserRole.broadcaster.canSwitchTo(.moderator))
        #expect(!UserRole.broadcaster.canSwitchTo(.audience))
        
        // 测试观众可以切换的角色
        #expect(UserRole.audience.canSwitchToRole == [.coHost])
        #expect(UserRole.audience.canSwitchTo(.coHost))
        #expect(!UserRole.audience.canSwitchTo(.broadcaster))
        
        // 测试连麦嘉宾可以切换的角色
        #expect(UserRole.coHost.canSwitchToRole == [.audience, .broadcaster])
        #expect(UserRole.coHost.canSwitchTo(.audience))
        #expect(UserRole.coHost.canSwitchTo(.broadcaster))
        #expect(!UserRole.coHost.canSwitchTo(.moderator))
        
        // 测试主持人可以切换的角色
        #expect(UserRole.moderator.canSwitchToRole == [.broadcaster])
        #expect(UserRole.moderator.canSwitchTo(.broadcaster))
        #expect(!UserRole.moderator.canSwitchTo(.audience))
    }
    
    @Test("用户角色权限级别验证")
    func testUserRolePermissionLevels() {
        #expect(UserRole.audience.permissionLevel == 0)
        #expect(UserRole.coHost.permissionLevel == 1)
        #expect(UserRole.broadcaster.permissionLevel == 2)
        #expect(UserRole.moderator.permissionLevel == 3)
        
        // 测试权限比较
        #expect(UserRole.moderator.hasHigherPermissionThan(.broadcaster))
        #expect(UserRole.broadcaster.hasHigherPermissionThan(.coHost))
        #expect(UserRole.coHost.hasHigherPermissionThan(.audience))
        #expect(!UserRole.audience.hasHigherPermissionThan(.coHost))
    }
    
    @Test("用户角色参数化权限测试", arguments: [
        (UserRole.broadcaster, true, true, false),
        (UserRole.audience, false, false, false),
        (UserRole.coHost, true, true, false),
        (UserRole.moderator, true, false, true)
    ])
    func testUserRolePermissionsParameterized(
        role: UserRole,
        expectedAudio: Bool,
        expectedVideo: Bool,
        expectedModerator: Bool
    ) {
        #expect(role.hasAudioPermission == expectedAudio)
        #expect(role.hasVideoPermission == expectedVideo)
        #expect(role.hasModeratorPrivileges == expectedModerator)
    }
    
    // MARK: - AudioSettings Tests (需求 5.1, 5.2, 5.4, 测试要求 1)
    
    @Test("音频设置默认值")
    func testAudioSettingsDefaults() {
        let settings = AudioSettings.default
        
        #expect(!settings.microphoneMuted)
        #expect(settings.audioMixingVolume == 100)
        #expect(settings.playbackSignalVolume == 100)
        #expect(settings.recordingSignalVolume == 100)
        #expect(settings.localAudioStreamActive)
        #expect(settings.settingsVersion == 1)
        #expect(settings.isValid)
        #expect(!settings.isSilent)
    }
    
    @Test("音频设置音量范围验证", arguments: [
        (-10, 0),    // 负值应该被限制为0
        (50, 50),    // 正常值保持不变
        (150, 100),  // 超过100的值应该被限制为100
        (0, 0),      // 边界值：最小值
        (100, 100)   // 边界值：最大值
    ])
    func testAudioSettingsVolumeValidation(input: Int, expected: Int) {
        let settings = AudioSettings(audioMixingVolume: input)
        #expect(settings.audioMixingVolume == expected)
        
        // 测试所有音量参数的验证
        let settingsAll = AudioSettings(
            audioMixingVolume: input,
            playbackSignalVolume: input,
            recordingSignalVolume: input
        )
        #expect(settingsAll.audioMixingVolume == expected)
        #expect(settingsAll.playbackSignalVolume == expected)
        #expect(settingsAll.recordingSignalVolume == expected)
    }
    
    @Test("音频设置静态验证方法")
    func testAudioSettingsStaticValidation() {
        // 测试音量验证方法
        #expect(AudioSettings.validateVolume(-10) == 0)
        #expect(AudioSettings.validateVolume(50) == 50)
        #expect(AudioSettings.validateVolume(150) == 100)
        
        // 测试音量有效性检查
        #expect(!AudioSettings.isValidVolume(-1))
        #expect(AudioSettings.isValidVolume(0))
        #expect(AudioSettings.isValidVolume(50))
        #expect(AudioSettings.isValidVolume(100))
        #expect(!AudioSettings.isValidVolume(101))
    }
    
    @Test("音频设置更新方法")
    func testAudioSettingsUpdate() {
        let originalSettings = AudioSettings.default
        let updatedSettings = originalSettings.withUpdatedVolume(
            audioMixing: 80,
            playbackSignal: 90
        )
        
        #expect(updatedSettings.audioMixingVolume == 80)
        #expect(updatedSettings.playbackSignalVolume == 90)
        #expect(updatedSettings.recordingSignalVolume == originalSettings.recordingSignalVolume)
        #expect(updatedSettings.microphoneMuted == originalSettings.microphoneMuted)
        #expect(updatedSettings.settingsVersion == originalSettings.settingsVersion)
    }
    
    @Test("音频设置麦克风状态更新")
    func testAudioSettingsMicrophoneUpdate() {
        let originalSettings = AudioSettings.default
        let mutedSettings = originalSettings.withUpdatedMicrophoneState(true)
        
        #expect(mutedSettings.microphoneMuted)
        #expect(mutedSettings.audioMixingVolume == originalSettings.audioMixingVolume)
        #expect(mutedSettings.isSilent) // 麦克风静音时应该是静音状态
        
        let unmutedSettings = mutedSettings.withUpdatedMicrophoneState(false)
        #expect(!unmutedSettings.microphoneMuted)
        #expect(!unmutedSettings.isSilent) // 取消静音后不应该是静音状态
    }
    
    @Test("音频设置流状态更新")
    func testAudioSettingsStreamUpdate() {
        let originalSettings = AudioSettings.default
        let inactiveSettings = originalSettings.withUpdatedStreamState(false)
        
        #expect(!inactiveSettings.localAudioStreamActive)
        #expect(inactiveSettings.audioMixingVolume == originalSettings.audioMixingVolume)
        
        let activeSettings = inactiveSettings.withUpdatedStreamState(true)
        #expect(activeSettings.localAudioStreamActive)
    }
    
    @Test("音频设置计算属性")
    func testAudioSettingsComputedProperties() {
        let settings = AudioSettings(
            audioMixingVolume: 60,
            playbackSignalVolume: 80,
            recordingSignalVolume: 100
        )
        
        // 测试平均音量计算
        #expect(settings.averageVolume == 80) // (60 + 80 + 100) / 3 = 80
        
        // 测试静音状态检测
        let silentSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 50
        )
        #expect(silentSettings.isSilent)
        
        let zeroVolumeSettings = AudioSettings(
            audioMixingVolume: 0,
            playbackSignalVolume: 0,
            recordingSignalVolume: 0
        )
        #expect(zeroVolumeSettings.isSilent)
    }
    
    @Test("音频设置编码解码功能")
    func testAudioSettingsEncodingDecoding() throws {
        let originalSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 85,
            recordingSignalVolume: 95,
            localAudioStreamActive: false
        )
        
        // 测试编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSettings)
        #expect(!data.isEmpty)
        
        // 测试解码
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(AudioSettings.self, from: data)
        
        #expect(decodedSettings.microphoneMuted == originalSettings.microphoneMuted)
        #expect(decodedSettings.audioMixingVolume == originalSettings.audioMixingVolume)
        #expect(decodedSettings.playbackSignalVolume == originalSettings.playbackSignalVolume)
        #expect(decodedSettings.recordingSignalVolume == originalSettings.recordingSignalVolume)
        #expect(decodedSettings.localAudioStreamActive == originalSettings.localAudioStreamActive)
    }
    
    // MARK: - UserSession Tests (需求 4.4, 测试要求 1)
    
    @Test("用户会话创建")
    func testUserSessionCreation() {
        let deviceInfo = DeviceInfo(
            deviceId: "test_device_123",
            deviceModel: "iPhone 15",
            systemVersion: "17.0",
            appVersion: "1.0.0"
        )
        
        let session = UserSession(
            userId: "test_user_123",
            userName: "测试用户",
            userRole: .broadcaster,
            roomId: "test_room_456",
            deviceInfo: deviceInfo
        )
        
        #expect(session.userId == "test_user_123")
        #expect(session.userName == "测试用户")
        #expect(session.userRole == .broadcaster)
        #expect(session.roomId == "test_room_456")
        #expect(session.deviceInfo == deviceInfo)
        #expect(!session.sessionId.isEmpty)
        #expect(session.isInRoom)
    }
    
    @Test("用户会话角色更新")
    func testUserSessionRoleUpdate() {
        let originalSession = UserSession(
            userId: "test_user_123",
            userName: "测试用户",
            userRole: .audience
        )
        
        let updatedSession = originalSession.withUpdatedRole(.coHost)
        
        #expect(updatedSession.userId == originalSession.userId)
        #expect(updatedSession.userName == originalSession.userName)
        #expect(updatedSession.userRole == .coHost)
        #expect(updatedSession.sessionId != originalSession.sessionId) // 新会话应该有新的ID
    }
    
    @Test("用户会话房间ID更新")
    func testUserSessionRoomIdUpdate() {
        let originalSession = UserSession(
            userId: "test_user_123",
            userName: "测试用户",
            userRole: .broadcaster,
            roomId: "room_1"
        )
        
        let updatedSession = originalSession.withUpdatedRoomId("room_2")
        
        #expect(updatedSession.roomId == "room_2")
        #expect(updatedSession.userId == originalSession.userId)
        #expect(updatedSession.userRole == originalSession.userRole)
        #expect(updatedSession.isInRoom)
        
        // 测试离开房间
        let leftRoomSession = originalSession.withUpdatedRoomId(nil)
        #expect(leftRoomSession.roomId == nil)
        #expect(!leftRoomSession.isInRoom)
    }
    
    @Test("用户会话有效性验证")
    func testUserSessionValidity() {
        let session = UserSession(
            userId: "test_user_123",
            userName: "测试用户",
            userRole: .broadcaster
        )
        
        // 新创建的会话应该是有效的
        #expect(session.isValid())
        #expect(session.isValid(maxInactiveTime: 3600))
        
        // 测试超时情况（这里我们无法真正等待时间，所以测试极短的超时时间）
        #expect(!session.isValid(maxInactiveTime: -1))
    }
    
    @Test("设备信息创建")
    func testDeviceInfoCreation() {
        let deviceInfo = DeviceInfo(
            deviceId: "test_device_123",
            deviceModel: "iPhone 15 Pro",
            systemVersion: "17.1",
            appVersion: "1.2.0"
        )
        
        #expect(deviceInfo.deviceId == "test_device_123")
        #expect(deviceInfo.deviceModel == "iPhone 15 Pro")
        #expect(deviceInfo.systemVersion == "17.1")
        #expect(deviceInfo.appVersion == "1.2.0")
    }
    
    // MARK: - ProviderType Tests
    
    @Test("服务商类型显示名称")
    func testProviderTypeDisplayNames() {
        // 测试显示名称不为空（在测试环境中可能返回英文fallback值）
        #expect(!ProviderType.agora.displayName.isEmpty)
        #expect(!ProviderType.tencent.displayName.isEmpty)
        #expect(!ProviderType.zego.displayName.isEmpty)
        #expect(!ProviderType.mock.displayName.isEmpty)
        
        // 测试英文fallback值（测试环境中的实际行为）
        #expect(ProviderType.agora.displayName == "Agora")
        #expect(ProviderType.tencent.displayName == "Tencent Cloud")
        #expect(ProviderType.zego.displayName == "ZEGO")
        #expect(ProviderType.mock.displayName == "Mock Provider")
    }
    
    // MARK: - ConnectionState Tests
    
    @Test("连接状态显示名称")
    func testConnectionStateDisplayNames() {
        // 测试显示名称不为空（在测试环境中可能返回英文fallback值）
        #expect(!ConnectionState.disconnected.displayName.isEmpty)
        #expect(!ConnectionState.connecting.displayName.isEmpty)
        #expect(!ConnectionState.connected.displayName.isEmpty)
        #expect(!ConnectionState.reconnecting.displayName.isEmpty)
        #expect(!ConnectionState.failed.displayName.isEmpty)
        
        // 测试英文fallback值（测试环境中的实际行为）
        #expect(ConnectionState.disconnected.displayName == "Disconnected")
        #expect(ConnectionState.connecting.displayName == "Connecting")
        #expect(ConnectionState.connected.displayName == "Connected")
        #expect(ConnectionState.reconnecting.displayName == "Reconnecting")
        #expect(ConnectionState.failed.displayName == "Connection Failed")
    }
    
    // MARK: - VolumeDetectionConfig Tests (需求 6.1, 6.2, 6.6, 测试要求 1)
    
    @Test("音量检测配置默认值")
    func testVolumeDetectionConfigDefaults() {
        let config = VolumeDetectionConfig.default
        
        #expect(config.detectionInterval == 300)
        #expect(config.speakingThreshold == 0.3)
        #expect(config.silenceThreshold == 0.05)
        #expect(config.includeLocalUser)
        #expect(config.smoothFactor == 0.3)
        #expect(config.enableSmoothing)
        #expect(config.isValid)
        
        // 测试向后兼容属性
        #expect(config.interval == config.detectionInterval)
        #expect(config.smooth == config.enableSmoothing)
        #expect(config.reportLocalVolume == config.includeLocalUser)
    }
    
    @Test("音量检测配置参数验证")
    func testVolumeDetectionConfigValidation() {
        // 测试检测间隔限制
        let config1 = VolumeDetectionConfig(detectionInterval: 50) // 小于最小值100
        #expect(config1.detectionInterval == 100)
        
        let config2 = VolumeDetectionConfig(detectionInterval: 6000) // 大于最大值5000
        #expect(config2.detectionInterval == 5000)
        
        // 测试阈值限制
        let config3 = VolumeDetectionConfig(speakingThreshold: -0.1) // 小于0.0
        #expect(config3.speakingThreshold == 0.0)
        
        let config4 = VolumeDetectionConfig(speakingThreshold: 1.5) // 大于1.0
        #expect(config4.speakingThreshold == 1.0)
        
        let config5 = VolumeDetectionConfig(silenceThreshold: -0.1) // 小于0.0
        #expect(config5.silenceThreshold == 0.0)
        
        let config6 = VolumeDetectionConfig(silenceThreshold: 1.5) // 大于1.0
        #expect(config6.silenceThreshold == 1.0)
        
        // 测试平滑因子限制
        let config7 = VolumeDetectionConfig(smoothFactor: -0.1) // 小于0.0
        #expect(config7.smoothFactor == 0.0)
        
        let config8 = VolumeDetectionConfig(smoothFactor: 1.5) // 大于1.0
        #expect(config8.smoothFactor == 1.0)
    }
    
    @Test("音量检测配置有效性验证")
    func testVolumeDetectionConfigValidity() {
        // 有效配置
        let validConfig = VolumeDetectionConfig(
            detectionInterval: 300,
            speakingThreshold: 0.3,
            silenceThreshold: 0.1
        )
        #expect(validConfig.isValid)
        
        // 无效配置：说话阈值小于等于静音阈值
        let invalidConfig = VolumeDetectionConfig(
            detectionInterval: 300,
            speakingThreshold: 0.1,
            silenceThreshold: 0.3
        )
        #expect(!invalidConfig.isValid)
    }
    
    @Test("音量检测配置向后兼容初始化")
    func testVolumeDetectionConfigBackwardCompatibility() {
        let config = VolumeDetectionConfig(
            interval: 500,
            smooth: false,
            reportLocalVolume: false,
            volumeThreshold: 20
        )
        
        #expect(config.detectionInterval == 500)
        #expect(!config.enableSmoothing)
        #expect(!config.includeLocalUser)
        #expect(config.volumeThreshold == 20)
    }
    
    // MARK: - UserVolumeInfo Tests (需求 6.2, 测试要求 1)
    
    @Test("用户音量信息创建")
    func testUserVolumeInfoCreation() {
        let volumeInfo = UserVolumeInfo(
            userId: "user123",
            volume: 128,
            vad: .speaking
        )
        
        #expect(volumeInfo.userId == "user123")
        #expect(volumeInfo.id == "user123") // id 应该等于 userId
        #expect(volumeInfo.volume == 128)
        #expect(volumeInfo.vad == .speaking)
        #expect(volumeInfo.isSpeaking)
        #expect(volumeInfo.volumePercentage == 50) // 128/255 * 100 ≈ 50
        #expect(volumeInfo.volumeFloat == Float(128) / 255.0)
        #expect(volumeInfo.volumeLevel == .medium)
    }
    
    @Test("用户音量信息浮点初始化")
    func testUserVolumeInfoFloatInit() {
        let volumeInfo = UserVolumeInfo(
            userId: "user456",
            volumeFloat: 0.8,
            isSpeaking: true
        )
        
        #expect(volumeInfo.userId == "user456")
        #expect(volumeInfo.volume == Int(0.8 * 255)) // 204
        #expect(volumeInfo.isSpeaking)
        #expect(volumeInfo.vad == .speaking)
        #expect(volumeInfo.volumeLevel == .high) // 0.8 * 100 = 80% → high (61-80%)
    }
    
    @Test("用户音量信息音量范围验证")
    func testUserVolumeInfoVolumeValidation() {
        // 测试音量范围限制
        let volumeInfo1 = UserVolumeInfo(userId: "user1", volume: -10)
        #expect(volumeInfo1.volume == 0)
        
        let volumeInfo2 = UserVolumeInfo(userId: "user2", volume: 300)
        #expect(volumeInfo2.volume == 255)
        
        let volumeInfo3 = UserVolumeInfo(userId: "user3", volume: 127)
        #expect(volumeInfo3.volume == 127)
    }
    
    @Test("用户音量信息音量级别测试", arguments: [
        (0, VolumeLevel.silent),      // 0% → silent
        (25, VolumeLevel.silent),     // 9.8% → silent (0-10%)
        (76, VolumeLevel.low),        // 29.8% → low (11-30%)
        (153, VolumeLevel.medium),    // 60% → medium (31-60%)
        (255, VolumeLevel.veryHigh)   // 100% → veryHigh (81-100%)
    ])
    func testUserVolumeInfoVolumeLevel(volume: Int, expectedLevel: VolumeLevel) {
        let volumeInfo = UserVolumeInfo(userId: "test", volume: volume)
        #expect(volumeInfo.volumeLevel == expectedLevel)
    }
    
    @Test("用户音量信息过期检测")
    func testUserVolumeInfoExpiration() {
        let volumeInfo = UserVolumeInfo(userId: "user", volume: 100)
        
        // 新创建的音量信息不应该过期
        #expect(!volumeInfo.isExpired())
        #expect(!volumeInfo.isExpired(maxAge: 1.0))
        
        // 测试极短的过期时间
        #expect(volumeInfo.isExpired(maxAge: -1.0))
    }
    
    // MARK: - Volume Smoothing Filter Tests (需求 6.6, 测试要求 1)
    
    @Test("音量平滑滤波器基本功能")
    func testVolumeSmoothingFilterBasic() {
        let config = VolumeDetectionConfig(smoothFactor: 0.5, enableSmoothing: true)
        let filter = VolumeSmoothingFilter(config: config)
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 100),
            UserVolumeInfo(userId: "user2", volume: 200)
        ]
        
        let smoothedInfos = filter.applySmoothingFilter(to: volumeInfos)
        
        #expect(smoothedInfos.count == 2)
        #expect(smoothedInfos[0].userId == "user1")
        #expect(smoothedInfos[1].userId == "user2")
        
        // 第一次应用滤波，结果应该与输入相同（没有历史数据）
        #expect(smoothedInfos[0].volume == 100)
        #expect(smoothedInfos[1].volume == 200)
    }
    
    @Test("音量平滑滤波器平滑效果")
    func testVolumeSmoothingFilterSmoothing() {
        let config = VolumeDetectionConfig(smoothFactor: 0.3, enableSmoothing: true)
        let filter = VolumeSmoothingFilter(config: config)
        
        // 第一次应用
        let volumeInfos1 = [UserVolumeInfo(userId: "user1", volume: 100)]
        let smoothed1 = filter.applySmoothingFilter(to: volumeInfos1)
        #expect(smoothed1[0].volume == 100)
        
        // 第二次应用，音量变化较大
        let volumeInfos2 = [UserVolumeInfo(userId: "user1", volume: 200)]
        let smoothed2 = filter.applySmoothingFilter(to: volumeInfos2)
        
        // 平滑后的音量应该在100和200之间
        #expect(smoothed2[0].volume > 100)
        #expect(smoothed2[0].volume < 200)
    }
    
    @Test("音量平滑滤波器禁用平滑")
    func testVolumeSmoothingFilterDisabled() {
        let config = VolumeDetectionConfig(enableSmoothing: false)
        let filter = VolumeSmoothingFilter(config: config)
        
        let volumeInfos = [UserVolumeInfo(userId: "user1", volume: 100)]
        let result = filter.applySmoothingFilter(to: volumeInfos)
        
        // 禁用平滑时，输出应该与输入相同
        #expect(result == volumeInfos)
    }
    
    @Test("音量平滑滤波器重置功能")
    func testVolumeSmoothingFilterReset() {
        let config = VolumeDetectionConfig(smoothFactor: 0.5, enableSmoothing: true)
        let filter = VolumeSmoothingFilter(config: config)
        
        // 应用一些数据
        let volumeInfos = [UserVolumeInfo(userId: "user1", volume: 100)]
        _ = filter.applySmoothingFilter(to: volumeInfos)
        
        // 重置滤波器
        filter.reset()
        
        // 重置后再次应用相同数据，结果应该与第一次相同
        let result = filter.applySmoothingFilter(to: volumeInfos)
        #expect(result[0].volume == 100)
    }
    
    // MARK: - Volume Event Tests (需求 6.3, 测试要求 1)
    
    @Test("音量事件类型和描述")
    func testVolumeEventTypes() {
        let startEvent = VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.8)
        #expect(startEvent.eventType == "user_started_speaking")
        #expect(startEvent.description.contains("user1"))
        #expect(startEvent.description.contains("80%"))
        
        let stopEvent = VolumeEvent.userStoppedSpeaking(userId: "user2", volume: 0.3)
        #expect(stopEvent.eventType == "user_stopped_speaking")
        #expect(stopEvent.description.contains("user2"))
        
        let dominantEvent = VolumeEvent.dominantSpeakerChanged(userId: "user3")
        #expect(dominantEvent.eventType == "dominant_speaker_changed")
        #expect(dominantEvent.description.contains("user3"))
        
        let noDominantEvent = VolumeEvent.dominantSpeakerChanged(userId: nil)
        #expect(noDominantEvent.description.contains("没有主讲人"))
        
        let updateEvent = VolumeEvent.volumeUpdate([])
        #expect(updateEvent.eventType == "volume_update")
        #expect(updateEvent.description.contains("0 个用户"))
    }
    
    // MARK: - RealtimeMessage Tests (需求 10.1, 10.2, 测试要求 1)
    
    @Test("实时消息创建")
    func testRealtimeMessageCreation() {
        let message = RealtimeMessage(
            type: .text,
            content: .text("Hello, World!"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        #expect(!message.id.isEmpty)
        #expect(message.type == .text)
        #expect(message.content.textValue == "Hello, World!")
        #expect(message.senderId == "user123")
        #expect(message.channelId == "channel456")
        #expect(message.receiverId == nil)
        #expect(message.status == .pending)
        #expect(message.priority == .normal)
        #expect(message.isChannelMessage)
        #expect(!message.isDirectMessage)
        #expect(!message.isExpired)
    }
    
    @Test("实时消息点对点消息")
    func testRealtimeMessageDirectMessage() {
        let message = RealtimeMessage(
            type: .text,
            content: .text("Private message"),
            senderId: "user123",
            receiverId: "user456"
        )
        
        #expect(message.isDirectMessage)
        #expect(!message.isChannelMessage)
        #expect(message.receiverId == "user456")
        #expect(message.channelId == nil)
    }
    
    @Test("实时消息状态更新")
    func testRealtimeMessageStatusUpdate() {
        let originalMessage = RealtimeMessage(
            type: .text,
            content: .text("Test message"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        let processedMessage = originalMessage.withStatus(.processed)
        
        #expect(processedMessage.id == originalMessage.id)
        #expect(processedMessage.status == .processed)
        #expect(processedMessage.content.textValue == originalMessage.content.textValue)
        #expect(originalMessage.status == .pending) // 原消息不变
    }
    
    @Test("实时消息元数据更新")
    func testRealtimeMessageMetadataUpdate() {
        let originalMessage = RealtimeMessage(
            type: .text,
            content: .text("Test message"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        let newMetadata: [String: MessageMetadataValue] = [
            "processed_by": .string("processor_1"),
            "processing_time": .double(0.123),
            "retry_count": .int(0)
        ]
        
        let updatedMessage = originalMessage.withMetadata(newMetadata)
        
        #expect(updatedMessage.metadata["processed_by"]?.stringValue == "processor_1")
        #expect(updatedMessage.metadata["processing_time"] == .double(0.123))
        #expect(updatedMessage.metadata["retry_count"]?.intValue == 0)
    }
    
    @Test("实时消息过期检测")
    func testRealtimeMessageExpiration() {
        let expiredMessage = RealtimeMessage(
            type: .text,
            content: .text("Expired message"),
            senderId: "user123",
            channelId: "channel456",
            expirationTime: Date().addingTimeInterval(-60) // 1分钟前过期
        )
        
        #expect(expiredMessage.isExpired)
        
        let validMessage = RealtimeMessage(
            type: .text,
            content: .text("Valid message"),
            senderId: "user123",
            channelId: "channel456",
            expirationTime: Date().addingTimeInterval(60) // 1分钟后过期
        )
        
        #expect(!validMessage.isExpired)
        
        let noExpirationMessage = RealtimeMessage(
            type: .text,
            content: .text("No expiration"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        #expect(!noExpirationMessage.isExpired)
    }
    
    @Test("消息内容类型测试")
    func testMessageContentTypes() {
        // 文本内容
        let textContent = MessageContent.text("Hello")
        #expect(textContent.textValue == "Hello")
        #expect(!textContent.isEmpty)
        
        let emptyTextContent = MessageContent.text("")
        #expect(emptyTextContent.isEmpty)
        
        // 图片内容
        let imageContent = MessageContent.image(ImageContent(
            url: "https://example.com/image.jpg",
            width: 800,
            height: 600
        ))
        #expect(imageContent.textValue == nil)
        #expect(!imageContent.isEmpty)
        
        // 系统内容
        let systemContent = MessageContent.system(SystemContent(
            message: "User joined",
            systemType: .userJoined
        ))
        #expect(systemContent.textValue == "User joined")
        #expect(!systemContent.isEmpty)
        
        let emptySystemContent = MessageContent.system(SystemContent(
            message: "",
            systemType: .userJoined
        ))
        #expect(emptySystemContent.isEmpty)
    }
    
    @Test("消息类型特殊处理标记")
    func testMessageTypeSpecialProcessing() {
        #expect(RealtimeMessageType.text.requiresSpecialProcessing == false)
        #expect(RealtimeMessageType.image.requiresSpecialProcessing == false)
        #expect(RealtimeMessageType.system.requiresSpecialProcessing == true)
        #expect(RealtimeMessageType.command.requiresSpecialProcessing == true)
        #expect(RealtimeMessageType.notification.requiresSpecialProcessing == true)
    }
    
    @Test("消息优先级数值")
    func testMessagePriorityValues() {
        #expect(MessagePriority.low.numericValue == 0)
        #expect(MessagePriority.normal.numericValue == 1)
        #expect(MessagePriority.high.numericValue == 2)
        #expect(MessagePriority.urgent.numericValue == 3)
    }
    
    // MARK: - Message Validation Tests (需求 10.2, 测试要求 1)
    
    @Test("消息验证 - 有效消息")
    func testMessageValidationValid() {
        let validMessage = RealtimeMessage(
            type: .text,
            content: .text("Valid message"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        let result = MessageValidator.validate(validMessage)
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
    }
    
    @Test("消息验证 - 空发送者ID")
    func testMessageValidationEmptySenderId() {
        let invalidMessage = RealtimeMessage(
            type: .text,
            content: .text("Message with empty sender"),
            senderId: "",
            channelId: "channel456"
        )
        
        let result = MessageValidator.validate(invalidMessage)
        #expect(!result.isValid)
        #expect(result.errors.contains(.emptySenderId))
    }
    
    @Test("消息验证 - 空内容")
    func testMessageValidationEmptyContent() {
        let invalidMessage = RealtimeMessage(
            type: .text,
            content: .text(""),
            senderId: "user123",
            channelId: "channel456"
        )
        
        let result = MessageValidator.validate(invalidMessage)
        #expect(!result.isValid)
        #expect(result.errors.contains(.emptyContent))
    }
    
    @Test("消息验证 - 内容类型不匹配")
    func testMessageValidationContentTypeMismatch() {
        let invalidMessage = RealtimeMessage(
            type: .image, // 类型是图片
            content: .text("This is text content"), // 但内容是文本
            senderId: "user123",
            channelId: "channel456"
        )
        
        let result = MessageValidator.validate(invalidMessage)
        #expect(!result.isValid)
        #expect(result.errors.contains(.contentTypeMismatch))
    }
    
    @Test("消息验证 - 消息过期")
    func testMessageValidationExpired() {
        let expiredMessage = RealtimeMessage(
            type: .text,
            content: .text("Expired message"),
            senderId: "user123",
            channelId: "channel456",
            expirationTime: Date().addingTimeInterval(-60)
        )
        
        let result = MessageValidator.validate(expiredMessage)
        #expect(!result.isValid)
        #expect(result.errors.contains(.messageExpired))
    }
    
    @Test("消息验证 - 无效接收者")
    func testMessageValidationInvalidRecipient() {
        // 同时指定接收者和频道
        let invalidMessage1 = RealtimeMessage(
            type: .text,
            content: .text("Invalid recipient"),
            senderId: "user123",
            receiverId: "user456",
            channelId: "channel789"
        )
        
        let result1 = MessageValidator.validate(invalidMessage1)
        #expect(!result1.isValid)
        #expect(result1.errors.contains(.invalidRecipient))
        
        // 既不指定接收者也不指定频道
        let invalidMessage2 = RealtimeMessage(
            type: .text,
            content: .text("Missing recipient"),
            senderId: "user123"
        )
        
        let result2 = MessageValidator.validate(invalidMessage2)
        #expect(!result2.isValid)
        #expect(result2.errors.contains(.missingRecipient))
    }
    
    @Test("消息编码解码功能")
    func testRealtimeMessageEncodingDecoding() throws {
        let originalMessage = RealtimeMessage(
            type: .text,
            content: .text("Test encoding"),
            senderId: "user123",
            channelId: "channel456",
            metadata: [
                "key1": .string("value1"),
                "key2": .int(42),
                "key3": .bool(true)
            ],
            priority: .high
        )
        
        // 测试编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalMessage)
        #expect(!data.isEmpty)
        
        // 测试解码
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(RealtimeMessage.self, from: data)
        
        #expect(decodedMessage.id == originalMessage.id)
        #expect(decodedMessage.type == originalMessage.type)
        #expect(decodedMessage.content == originalMessage.content)
        #expect(decodedMessage.senderId == originalMessage.senderId)
        #expect(decodedMessage.channelId == originalMessage.channelId)
        #expect(decodedMessage.priority == originalMessage.priority)
        #expect(decodedMessage.metadata["key1"]?.stringValue == "value1")
        #expect(decodedMessage.metadata["key2"]?.intValue == 42)
        #expect(decodedMessage.metadata["key3"]?.boolValue == true)
    }
    
    // MARK: - RealtimeError Tests
    
    @Test("错误类型描述")
    func testRealtimeErrorDescriptions() {
        let configError = RealtimeError.configurationError("测试配置错误")
        #expect(configError.errorDescription?.contains("测试配置错误") == true)
        
        let providerError = RealtimeError.providerNotAvailable(.agora)
        #expect(!providerError.errorDescription!.isEmpty)
        
        let permissionError = RealtimeError.insufficientPermissions(.audience)
        #expect(!permissionError.errorDescription!.isEmpty)
        
        let sessionError = RealtimeError.noActiveSession
        #expect(!sessionError.errorDescription!.isEmpty)
    }
}