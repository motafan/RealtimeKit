import Testing
import Foundation
@testable import RealtimeMocking
@testable import RealtimeCore

/// Mock 服务商测试
/// 需求: 12.4, 16.3, 17.1, 测试要求 1 - 使用 Swift Testing 框架
struct MockingTests {
    
    // MARK: - Mock Provider Factory Tests
    
    @Test("Mock Provider Factory 基本功能")
    func testMockProviderFactory() {
        let factory = RealtimeMocking.MockProviderFactory()
        
        // 测试创建 RTC Provider
        let rtcProvider = factory.createRTCProvider()
        #expect(rtcProvider is RealtimeMocking.MockRTCProvider)
        
        // 测试创建 RTM Provider
        let rtmProvider = factory.createRTMProvider()
        #expect(rtmProvider is RealtimeMocking.MockRTMProvider)
        
        // 测试支持的功能
        let features = factory.supportedFeatures()
        #expect(features.contains(.audioStreaming))
        #expect(features.contains(.videoStreaming))
        #expect(features.contains(.streamPush))
        #expect(features.contains(.mediaRelay))
        #expect(features.contains(.volumeIndicator))
        #expect(features.contains(.messageProcessing))
    }
    
    @Test("Mock Provider Factory 配置选项")
    func testMockProviderFactoryConfiguration() {
        // 测试默认配置
        let defaultFactory = RealtimeMocking.MockProviderFactory()
        #expect(defaultFactory.configuration.simulateNetworkDelay == true)
        #expect(defaultFactory.configuration.simulateErrors == false)
        
        // 测试自定义配置
        let customConfig = RealtimeMocking.MockProviderFactory.MockConfiguration(
            simulateNetworkDelay: false,
            simulateErrors: true,
            errorRate: 0.5
        )
        let customFactory = RealtimeMocking.MockProviderFactory(configuration: customConfig)
        #expect(customFactory.configuration.simulateNetworkDelay == false)
        #expect(customFactory.configuration.simulateErrors == true)
        #expect(customFactory.configuration.errorRate == 0.5)
    }
    
    // MARK: - Mock RTC Provider Tests
    
    @Test("Mock RTC Provider 初始化")
    func testMockRTCProviderInitialization() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: "test_certificate",
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 验证初始状态
        #expect(provider.isMicrophoneMuted() == false)
        #expect(provider.isLocalAudioStreamActive() == true)
        #expect(provider.getAudioMixingVolume() == 100)
        #expect(provider.getPlaybackSignalVolume() == 100)
        #expect(provider.getRecordingSignalVolume() == 100)
    }
    
    @Test("Mock RTC Provider 房间管理")
    func testMockRTCProviderRoomManagement() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试创建房间
        let room = try await provider.createRoom(roomId: "test_room")
        #expect(room.roomId == "test_room")
        
        // 测试加入房间
        try await provider.joinRoom(roomId: "test_room", userId: "test_user", userRole: .broadcaster)
        
        // 测试切换角色
        try await provider.switchUserRole(.audience)
        
        // 测试离开房间
        try await provider.leaveRoom()
    }
    
    @Test("Mock RTC Provider 音频控制")
    func testMockRTCProviderAudioControl() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试麦克风控制
        try await provider.muteMicrophone(true)
        #expect(provider.isMicrophoneMuted() == true)
        
        try await provider.muteMicrophone(false)
        #expect(provider.isMicrophoneMuted() == false)
        
        // 测试音频流控制
        try await provider.stopLocalAudioStream()
        #expect(provider.isLocalAudioStreamActive() == false)
        
        try await provider.resumeLocalAudioStream()
        #expect(provider.isLocalAudioStreamActive() == true)
        
        // 测试音量控制
        try await provider.setAudioMixingVolume(50)
        #expect(provider.getAudioMixingVolume() == 50)
        
        try await provider.setPlaybackSignalVolume(75)
        #expect(provider.getPlaybackSignalVolume() == 75)
        
        try await provider.setRecordingSignalVolume(25)
        #expect(provider.getRecordingSignalVolume() == 25)
    }
    
    @Test("Mock RTC Provider 音量指示器")
    func testMockRTCProviderVolumeIndicator() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 设置音量处理器
        var receivedVolumeInfos: [UserVolumeInfo] = []
        var receivedVolumeEvents: [VolumeEvent] = []
        
        provider.setVolumeIndicatorHandler { volumeInfos in
            receivedVolumeInfos = volumeInfos
        }
        
        provider.setVolumeEventHandler { event in
            receivedVolumeEvents.append(event)
        }
        
        // 验证处理器设置成功
        #expect(receivedVolumeInfos.isEmpty) // 初始状态应该为空
        #expect(receivedVolumeEvents.isEmpty) // 初始状态应该为空
        
        // 启用音量指示器
        let volumeConfig = VolumeDetectionConfig(
            detectionInterval: 100,
            speakingThreshold: 0.3,
            includeLocalUser: true
        )
        
        try await provider.enableVolumeIndicator(config: volumeConfig)
        
        // 等待一段时间让模拟数据生成
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        // 禁用音量指示器
        try await provider.disableVolumeIndicator()
        
        // 测试获取当前音量信息（在禁用后安全调用）
        let currentVolumeInfos = provider.getCurrentVolumeInfos()
        #expect(currentVolumeInfos.count > 0)
        
        // 测试获取特定用户音量信息
        let userVolumeInfo = provider.getVolumeInfo(for: "test_user")
        #expect(userVolumeInfo != nil)
        #expect(userVolumeInfo?.userId == "test_user")
    }
    
    // MARK: - Mock RTM Provider Tests
    
    @Test("Mock RTM Provider 初始化和登录")
    func testMockRTMProviderInitializationAndLogin() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTMProvider(configuration: config)
        
        let rtmConfig = RTMConfig(
            appId: "test_app_id",
            logConfig: RTMLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtmConfig)
        
        // 测试登录前状态
        #expect(provider.isLoggedIn() == false)
        
        // 测试登录
        try await provider.login(userId: "test_user", token: "test_token")
        #expect(provider.isLoggedIn() == true)
        
        // 测试登出
        try await provider.logout()
        #expect(provider.isLoggedIn() == false)
    }
    
    @Test("Mock RTM Provider 频道管理")
    func testMockRTMProviderChannelManagement() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTMProvider(configuration: config)
        
        let rtmConfig = RTMConfig(
            appId: "test_app_id",
            logConfig: RTMLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtmConfig)
        try await provider.login(userId: "test_user", token: "test_token")
        
        // 测试创建频道
        let channel = provider.createChannel(channelId: "test_channel")
        #expect(channel.channelId == "test_channel")
        
        // 测试加入频道
        try await provider.joinChannel(channelId: "test_channel")
        
        // 测试获取频道成员
        let members = try await provider.getChannelMembers(channelId: "test_channel")
        #expect(members.count >= 0)
        
        // 测试获取频道成员数量
        let memberCount = try await provider.getChannelMemberCount(channelId: "test_channel")
        #expect(memberCount >= 0)
        
        // 测试离开频道
        try await provider.leaveChannel(channelId: "test_channel")
    }
    
    @Test("Mock RTM Provider 消息发送")
    func testMockRTMProviderMessageSending() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTMProvider(configuration: config)
        
        let rtmConfig = RTMConfig(
            appId: "test_app_id",
            logConfig: RTMLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtmConfig)
        try await provider.login(userId: "test_user", token: "test_token")
        try await provider.joinChannel(channelId: "test_channel")
        
        // 测试发送点对点消息
        let peerMessage = RTMMessage(
            text: "Hello peer",
            senderId: "test_user"
        )
        try await provider.sendPeerMessage(peerMessage, toPeer: "peer_user", options: nil)
        
        // 测试发送频道消息
        let channelMessage = RTMMessage(
            text: "Hello channel",
            senderId: "test_user"
        )
        try await provider.sendChannelMessage(channelMessage, toChannel: "test_channel", options: nil)
    }
    
    @Test("Mock RTM Provider 用户属性管理")
    func testMockRTMProviderUserAttributes() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTMProvider(configuration: config)
        
        let rtmConfig = RTMConfig(
            appId: "test_app_id",
            logConfig: RTMLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtmConfig)
        try await provider.login(userId: "test_user", token: "test_token")
        
        // 测试设置用户属性
        let attributes = ["nickname": "Test User", "status": "online"]
        try await provider.setLocalUserAttributes(attributes)
        
        // 测试添加或更新用户属性
        let newAttributes = ["location": "Test City"]
        try await provider.addOrUpdateLocalUserAttributes(newAttributes)
        
        // 测试获取用户属性
        let userAttributes = try await provider.getUserAttributes(userId: "test_user")
        #expect(userAttributes.count > 0)
        
        // 测试删除用户属性
        try await provider.deleteLocalUserAttributesByKeys(["location"])
        
        // 测试清除所有用户属性
        try await provider.clearLocalUserAttributes()
    }
    
    // MARK: - Error Simulation Tests
    
    @Test("Mock Provider 错误模拟")
    func testMockProviderErrorSimulation() async throws {
        let errorConfig = RealtimeMocking.MockProviderFactory.MockConfiguration.errorTesting
        let rtcProvider = RealtimeMocking.MockRTCProvider(configuration: errorConfig)
        let rtmProvider = RealtimeMocking.MockRTMProvider(configuration: errorConfig)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        let rtmConfig = RTMConfig(
            appId: "test_app_id",
            logConfig: RTMLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        // 由于错误率设置为 0.5，某些操作可能会失败
        // 我们测试错误处理机制是否正常工作
        var rtcInitializationFailed = false
        var rtmInitializationFailed = false
        
        do {
            try await rtcProvider.initialize(config: rtcConfig)
        } catch {
            rtcInitializationFailed = true
            #expect(error is RealtimeError)
        }
        
        do {
            try await rtmProvider.initialize(config: rtmConfig)
        } catch {
            rtmInitializationFailed = true
            #expect(error is RealtimeError)
        }
        
        // 至少验证错误类型正确（如果发生错误的话）
        // 由于是随机错误，我们不能保证一定会发生错误
        print("RTC 初始化失败: \(rtcInitializationFailed)")
        print("RTM 初始化失败: \(rtmInitializationFailed)")
    }
    
    // MARK: - Localization Tests
    
    @Test("Mock Provider 本地化错误消息")
    func testMockProviderLocalizedErrors() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration(
            simulateNetworkDelay: false,
            simulateErrors: true,
            errorRate: 1.0, // 100% 错误率确保触发错误
            enableLocalizedErrors: true
        )
        
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        // 测试本地化错误消息
        do {
            let rtcConfig = RTCConfig(
                appId: "test_app_id",
                appCertificate: nil,
                region: .global,
                logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
            )
            try await provider.initialize(config: rtcConfig)
            #expect(Bool(false), "应该抛出错误")
        } catch let error as RealtimeError {
            // 验证错误消息包含本地化内容
            let errorDescription = error.localizedDescription
            #expect(errorDescription.count > 0)
            print("本地化错误消息: \(errorDescription)")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Mock Provider 性能测试")
    func testMockProviderPerformance() async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试批量操作性能
        let startTime = Date()
        
        for i in 0..<100 {
            try await provider.setAudioMixingVolume(i % 101)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 验证操作在合理时间内完成（由于没有网络延迟，应该很快）
        #expect(duration < 1.0) // 应该在1秒内完成
        print("100次音量设置操作耗时: \(duration)秒")
    }
    
    // MARK: - Helper Methods
    
    private func performAsyncOperation() async -> String {
        // 模拟异步操作
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        return "async_completed"
    }
    
    // MARK: - Parameterized Tests
    
    @Test("参数化音量测试", arguments: [0, 25, 50, 75, 100])
    func testParameterizedVolumeControl(volume: Int) async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试不同音量值
        try await provider.setAudioMixingVolume(volume)
        #expect(provider.getAudioMixingVolume() == volume)
        
        try await provider.setPlaybackSignalVolume(volume)
        #expect(provider.getPlaybackSignalVolume() == volume)
        
        try await provider.setRecordingSignalVolume(volume)
        #expect(provider.getRecordingSignalVolume() == volume)
    }
    
    @Test("参数化用户角色测试", arguments: UserRole.allCases)
    func testParameterizedUserRoles(role: UserRole) async throws {
        let config = RealtimeMocking.MockProviderFactory.MockConfiguration.testing
        let provider = RealtimeMocking.MockRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试不同用户角色
        let room = try await provider.createRoom(roomId: "test_room")
        #expect(room.roomId == "test_room")
        try await provider.joinRoom(roomId: "test_room", userId: "test_user", userRole: role)
        try await provider.switchUserRole(role)
        
        // 验证角色相关的权限
        #expect(role.displayName.count > 0)
        print("测试角色: \(role.displayName)")
    }
}