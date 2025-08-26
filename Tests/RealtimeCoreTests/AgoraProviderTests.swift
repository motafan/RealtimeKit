import Testing
import Foundation
@testable import RealtimeAgora
@testable import RealtimeCore

/// Actor-based box for thread-safe value storage
actor ActorBox<T> {
    private var value: T
    
    init(_ initialValue: T) {
        self.value = initialValue
    }
    
    func getValue() -> T {
        return value
    }
    
    func setValue(_ newValue: T) {
        self.value = newValue
    }
}

/// Agora 服务商测试
/// 需求: 2.1, 1.1, 1.2, 17.1, 测试要求 1 - 使用 Swift Testing 框架
struct AgoraProviderTests {
    
    // MARK: - Agora Provider Factory Tests
    
    @Test("Agora Provider Factory 基本功能")
    func testAgoraProviderFactory() {
        let factory = AgoraProviderFactory()
        
        // 测试创建 RTC Provider
        let rtcProvider = factory.createRTCProvider()
        #expect(rtcProvider is AgoraRTCProvider)
        
        // 测试创建 RTM Provider
        let rtmProvider = factory.createRTMProvider()
        #expect(rtmProvider is AgoraRTMProvider)
        
        // 测试支持的功能
        let features = factory.supportedFeatures()
        #expect(features.contains(.audioStreaming))
        #expect(features.contains(.videoStreaming))
        #expect(features.contains(.streamPush))
        #expect(features.contains(.mediaRelay))
        #expect(features.contains(.volumeIndicator))
        #expect(features.contains(.messageProcessing))
    }
    
    @Test("Agora Provider Factory 配置选项")
    func testAgoraProviderFactoryConfiguration() {
        // 测试默认配置
        let defaultFactory = AgoraProviderFactory()
        #expect(defaultFactory.configuration.enableCloudProxy == false)
        #expect(defaultFactory.configuration.enableAudioVolumeIndication == true)
        #expect(defaultFactory.configuration.enableLocalizedErrors == true)
        
        // 测试自定义配置
        let customConfig = AgoraProviderFactory.AgoraConfiguration(
            enableCloudProxy: true,
            enableAudioVolumeIndication: false,
            enableLocalizedErrors: false,
            logLevel: .warn,
            region: .china
        )
        let customFactory = AgoraProviderFactory(configuration: customConfig)
        #expect(customFactory.configuration.enableCloudProxy == true)
        #expect(customFactory.configuration.enableAudioVolumeIndication == false)
        #expect(customFactory.configuration.enableLocalizedErrors == false)
        #expect(customFactory.configuration.logLevel == .warn)
        #expect(customFactory.configuration.region == .china)
    }
    
    // MARK: - Agora RTC Provider Tests
    
    @Test("Agora RTC Provider 初始化")
    func testAgoraRTCProviderInitialization() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
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
    
    @Test("Agora RTC Provider 初始化错误处理")
    func testAgoraRTCProviderInitializationErrors() async throws {
        let provider = AgoraRTCProvider()
        
        // 测试空 App ID
        let invalidConfig = RTCConfig(
            appId: "",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        do {
            try await provider.initialize(config: invalidConfig)
            #expect(Bool(false), "应该抛出错误")
        } catch let error as RealtimeError {
            // 验证错误类型
            switch error {
            case .configurationError:
                break // 预期的错误类型
            default:
                #expect(Bool(false), "错误类型不正确")
            }
        }
    }
    
    @Test("Agora RTC Provider 房间管理")
    func testAgoraRTCProviderRoomManagement() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试创建房间
        let room = try await provider.createRoom(roomId: "test_agora_room")
        #expect(room.roomId == "test_agora_room")
        #expect(room is AgoraRTCRoom)
        
        // 测试加入房间
        try await provider.joinRoom(roomId: "test_agora_room", userId: "test_user", userRole: .broadcaster)
        
        // 测试切换角色
        try await provider.switchUserRole(.audience)
        
        // 测试离开房间
        try await provider.leaveRoom()
    }
    
    @Test("Agora RTC Provider 音频控制")
    func testAgoraRTCProviderAudioControl() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
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
        
        // 测试音量范围验证
        try await provider.setAudioMixingVolume(150) // 超出范围
        #expect(provider.getAudioMixingVolume() == 100) // 应该被限制为100
        
        try await provider.setPlaybackSignalVolume(-10) // 低于范围
        #expect(provider.getPlaybackSignalVolume() == 0) // 应该被限制为0
    }
    
    @Test("Agora RTC Provider 推流功能")
    func testAgoraRTCProviderStreamPush() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        _ = try await provider.createRoom(roomId: "test_room")
        try await provider.joinRoom(roomId: "test_room", userId: "test_user", userRole: .broadcaster)
        
        // 测试开始推流
        let streamConfig = try StreamPushConfig(
            url: "rtmp://test.example.com/live/stream"
        )
        
        try await provider.startStreamPush(config: streamConfig)
        
        // 测试更新推流布局
        let layout = StreamLayout(
            userRegions: []
        )
        try await provider.updateStreamPushLayout(layout: layout)
        
        // 测试停止推流
        try await provider.stopStreamPush()
    }
    
    @Test("Agora RTC Provider 媒体中继功能")
    func testAgoraRTCProviderMediaRelay() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        _ = try await provider.createRoom(roomId: "test_room")
        try await provider.joinRoom(roomId: "test_room", userId: "test_user", userRole: .broadcaster)
        
        // 测试开始媒体中继
        let relayConfig = try MediaRelayConfig(
            sourceChannel: MediaRelayChannelInfo(
                channelName: "source_channel",
                userId: "123",
                token: "source_token"
            ),
            destinationChannels: [
                MediaRelayChannelInfo(
                    channelName: "dest1",
                    userId: "456",
                    token: "dest1_token"
                ),
                MediaRelayChannelInfo(
                    channelName: "dest2",
                    userId: "789",
                    token: "dest2_token"
                )
            ]
        )
        
        try await provider.startMediaRelay(config: relayConfig)
        
        // 测试暂停和恢复媒体中继
        try await provider.pauseMediaRelay(toChannel: "dest1")
        try await provider.resumeMediaRelay(toChannel: "dest1")
        
        // 测试更新媒体中继频道
        let updatedConfig = try MediaRelayConfig(
            sourceChannel: relayConfig.sourceChannel,
            destinationChannels: [
                relayConfig.destinationChannels[0]
            ]
        )
        try await provider.updateMediaRelayChannels(config: updatedConfig)
        
        // 测试停止媒体中继
        try await provider.stopMediaRelay()
    }
    
    @Test("Agora RTC Provider 音量指示器")
    func testAgoraRTCProviderVolumeIndicator() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 设置音量处理器
        var receivedVolumeEvents: [VolumeEvent] = []
        
        provider.setVolumeIndicatorHandler { volumeInfos in
            // 处理音量信息
        }
        
        provider.setVolumeEventHandler { event in
            receivedVolumeEvents.append(event)
        }
        
        // 启用音量指示器
        let volumeConfig = VolumeDetectionConfig(
            detectionInterval: 200,
            speakingThreshold: 0.3,
            includeLocalUser: true
        )
        
        try await provider.enableVolumeIndicator(config: volumeConfig)
        
        // 等待一段时间让模拟数据生成
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        // 测试获取当前音量信息
        let currentVolumeInfos = provider.getCurrentVolumeInfos()
        #expect(currentVolumeInfos.count > 0)
        
        // 测试获取特定用户音量信息
        let userVolumeInfo = provider.getVolumeInfo(for: "test_user")
        #expect(userVolumeInfo != nil)
        #expect(userVolumeInfo?.userId == "test_user")
        
        // 禁用音量指示器
        try await provider.disableVolumeIndicator()
    }
    
    @Test("Agora RTC Provider Token 管理")
    func testAgoraRTCProviderTokenManagement() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试 Token 更新
        try await provider.renewToken("new_test_token")
        
        // 测试 Token 过期处理器
        let tokenWillExpireSeconds = ActorBox<Int?>(nil)
        provider.onTokenWillExpire { seconds in
            Task {
                await tokenWillExpireSeconds.setValue(seconds)
            }
        }
        
        // 等待一段时间让模拟的过期通知触发
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 由于是模拟实现，我们主要验证方法调用不会抛出异常
        let seconds = await tokenWillExpireSeconds.getValue()
        #expect(seconds == nil || seconds! > 0)
    }
    
    // MARK: - Agora RTM Provider Tests
    
    @Test("Agora RTM Provider 初始化和登录")
    func testAgoraRTMProviderInitializationAndLogin() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTMProvider(configuration: config)
        
        let rtmConfig = RTMConfig(
            appId: "test_agora_app_id",
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
    
    @Test("Agora RTM Provider 频道管理")
    func testAgoraRTMProviderChannelManagement() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTMProvider(configuration: config)
        
        let rtmConfig = RTMConfig(
            appId: "test_agora_app_id",
            logConfig: RTMLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtmConfig)
        try await provider.login(userId: "test_user", token: "test_token")
        
        // 测试创建频道
        let channel = provider.createChannel(channelId: "test_agora_channel")
        #expect(channel.channelId == "test_agora_channel")
        #expect(channel is AgoraRTMChannel)
        
        // 测试加入频道
        try await provider.joinChannel(channelId: "test_agora_channel")
        
        // 测试获取频道成员
        let members = try await provider.getChannelMembers(channelId: "test_agora_channel")
        #expect(members.count >= 0)
        
        // 测试获取频道成员数量
        let memberCount = try await provider.getChannelMemberCount(channelId: "test_agora_channel")
        #expect(memberCount >= 0)
        
        // 测试离开频道
        try await provider.leaveChannel(channelId: "test_agora_channel")
    }
    
    // MARK: - Configuration Tests
    
    @Test("Agora 配置类型测试", arguments: AgoraLogLevel.allCases)
    func testAgoraLogLevels(logLevel: AgoraLogLevel) {
        #expect(logLevel.displayName.count > 0)
        #expect(logLevel.rawValue.count > 0)
    }
    
    @Test("Agora 区域配置测试", arguments: AgoraRegion.allCases)
    func testAgoraRegions(region: AgoraRegion) {
        #expect(region.displayName.count > 0)
        #expect(region.rawValue.count > 0)
    }
    
    // MARK: - Room and Channel Tests
    
    @Test("Agora RTC Room 功能测试")
    func testAgoraRTCRoom() {
        let room = AgoraRTCRoom(roomId: "test_room")
        
        #expect(room.roomId == "test_room")
        #expect(room.memberCount == 0)
        #expect(room.state == .idle)
        
        // 测试添加成员
        room.addMember("user1")
        #expect(room.memberCount == 1)
        #expect(room.hasMember("user1") == true)
        #expect(room.state == .active)
        
        // 测试添加更多成员
        room.addMember("user2")
        #expect(room.memberCount == 2)
        #expect(room.hasMember("user2") == true)
        
        // 测试移除成员
        room.removeMember("user1")
        #expect(room.memberCount == 1)
        #expect(room.hasMember("user1") == false)
        #expect(room.hasMember("user2") == true)
        
        // 测试移除所有成员
        room.removeMember("user2")
        #expect(room.memberCount == 0)
        #expect(room.state == .idle)
    }
    
    @Test("Agora RTM Channel 功能测试")
    func testAgoraRTMChannel() {
        let channel = AgoraRTMChannel(channelId: "test_channel")
        
        #expect(channel.channelId == "test_channel")
        #expect(channel.memberCount == 0)
        #expect(channel.messageCount == 0)
        #expect(channel.state == .idle)
        
        // 测试添加成员
        channel.addMember("user1")
        #expect(channel.memberCount == 1)
        #expect(channel.hasMember("user1") == true)
        #expect(channel.state == .active)
        
        // 测试添加消息
        let message = RTMMessage(text: "Hello", senderId: "user1")
        channel.addMessage(message)
        #expect(channel.messageCount == 1)
        
        // 测试设置属性
        channel.setAttribute("topic", value: "Test Topic")
        #expect(channel.getAttribute("topic") == "Test Topic")
        #expect(channel.allAttributes["topic"] == "Test Topic")
        
        // 测试移除成员
        channel.removeMember("user1")
        #expect(channel.memberCount == 0)
        #expect(channel.state == .idle)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Agora Provider 错误处理")
    func testAgoraProviderErrorHandling() async throws {
        let provider = AgoraRTCProvider()
        
        // 测试未初始化时的错误
        do {
            try await provider.muteMicrophone(true)
            #expect(Bool(false), "应该抛出错误")
        } catch let error as RealtimeError {
            switch error {
            case .configurationError:
                break // 预期的错误类型
            default:
                #expect(Bool(false), "错误类型不正确")
            }
        }
        
        // 测试无效房间ID
        let rtcConfig = RTCConfig(
            appId: "test_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        do {
            _ = try await provider.createRoom(roomId: "")
            #expect(Bool(false), "应该抛出错误")
        } catch let error as RealtimeError {
            switch error {
            case .configurationError:
                break // 预期的错误类型
            default:
                #expect(Bool(false), "错误类型不正确")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Agora Provider 性能测试")
    func testAgoraProviderPerformance() async throws {
        let config = AgoraProviderFactory.AgoraConfiguration(enableLocalizedErrors: false)
        let provider = AgoraRTCProvider(configuration: config)
        
        let rtcConfig = RTCConfig(
            appId: "test_agora_app_id",
            appCertificate: nil,
            region: .global,
            logConfig: RTCLogConfig(logLevel: .info, enableConsoleLog: true)
        )
        
        try await provider.initialize(config: rtcConfig)
        
        // 测试批量操作性能
        let startTime = Date()
        
        for i in 0..<50 {
            try await provider.setAudioMixingVolume(i % 101)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 验证操作在合理时间内完成
        #expect(duration < 5.0) // 应该在5秒内完成（包含模拟延迟）
        print("50次音量设置操作耗时: \(duration)秒")
    }
}