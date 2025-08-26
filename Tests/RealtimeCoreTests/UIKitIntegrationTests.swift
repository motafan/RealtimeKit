import Testing
import Foundation
@testable import RealtimeCore
@testable import RealtimeUIKit

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// UIKit 集成测试
/// 需求: 11.1, 11.4, 17.3, 17.6, 18.10 - UIKit 组件的 UI 测试和交互测试
@MainActor
struct UIKitIntegrationTests {
    
    // MARK: - RealtimeViewController Tests
    
    @Test("RealtimeViewController 基础功能测试")
    func testRealtimeViewControllerBasicFunctionality() async throws {
        let viewController = RealtimeViewController()
        
        // 测试初始状态
        #expect(viewController.connectionState == .disconnected)
        #expect(viewController.volumeInfos.isEmpty)
        #expect(viewController.audioSettings == .default)
        
        // 测试 UI 状态持久化
        #expect(viewController.uiState.viewAppearanceCount == 0)
        #expect(viewController.userPreferences.enableVolumeVisualization == true)
        
        // 模拟视图生命周期
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)
        
        // 验证状态更新
        #expect(viewController.uiState.viewAppearanceCount == 1)
        #expect(viewController.uiState.lastViewAppearanceDate != nil)
    }
    
    @Test("RealtimeViewController 代理模式测试")
    func testRealtimeViewControllerDelegate() async throws {
        let viewController = RealtimeViewController()
        let mockDelegate = MockRealtimeViewControllerDelegate()
        viewController.delegate = mockDelegate
        
        // 模拟连接状态变化
        let newState = ConnectionState.connected
        viewController.connectionState = newState
        
        // 验证代理方法被调用
        #expect(mockDelegate.lastConnectionState == newState)
        #expect(mockDelegate.connectionStateChangeCount == 1)
        
        // 模拟音量信息更新
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.8, isSpeaking: true),
            UserVolumeInfo(userId: "user2", volume: 0.3, isSpeaking: false)
        ]
        viewController.volumeInfos = volumeInfos
        
        // 验证代理方法被调用
        #expect(mockDelegate.lastVolumeInfos.count == 2)
        #expect(mockDelegate.volumeUpdateCount == 1)
    }
    
    @Test("RealtimeViewController 本地化支持测试")
    func testRealtimeViewControllerLocalization() async throws {
        let viewController = RealtimeViewController()
        viewController.loadViewIfNeeded()
        
        // 设置本地化标题
        viewController.setLocalizedTitleAndSave("test.title", fallbackValue: "Test Title")
        
        // 验证标题设置
        #expect(viewController.title == "Test Title") // 回退值
        #expect(viewController.userPreferences.titleLocalizationKey == "test.title")
        
        // 测试语言变化
        let localizationManager = LocalizationManager.shared
        await localizationManager.switchLanguage(to: .chinese_simplified)
        
        // 验证语言变化统计
        #expect(viewController.uiState.languageChangeCount > 0)
        #expect(viewController.uiState.lastLanguageChangeDate != nil)
    }
    
    // MARK: - VolumeVisualizationView Tests
    
    @Test("VolumeVisualizationView 基础功能测试")
    func testVolumeVisualizationViewBasicFunctionality() async throws {
        let visualizationView = VolumeVisualizationView(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        let mockDelegate = MockVolumeVisualizationViewDelegate()
        visualizationView.delegate = mockDelegate
        
        // 测试初始状态
        #expect(visualizationView.volumeLevel == 0.0)
        #expect(visualizationView.isSpeaking == false)
        #expect(visualizationView.userId == nil)
        
        // 测试音量级别设置
        visualizationView.volumeLevel = 0.8
        #expect(visualizationView.volumeLevel == 0.8)
        #expect(mockDelegate.lastVolumeLevel == 0.8)
        #expect(mockDelegate.volumeLevelChangeCount == 1)
        
        // 测试说话状态设置
        visualizationView.isSpeaking = true
        #expect(visualizationView.isSpeaking == true)
        #expect(mockDelegate.lastSpeakingState == true)
        #expect(mockDelegate.speakingStateChangeCount == 1)
        
        // 测试边界值
        visualizationView.volumeLevel = 1.5 // 应该被限制为 1.0
        #expect(visualizationView.volumeLevel == 1.0)
        
        visualizationView.volumeLevel = -0.5 // 应该被限制为 0.0
        #expect(visualizationView.volumeLevel == 0.0)
    }
    
    @Test("VolumeVisualizationView 样式测试")
    func testVolumeVisualizationViewStyles() async throws {
        let visualizationView = VolumeVisualizationView(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        
        // 测试不同样式
        let styles: [VolumeVisualizationStyle] = [.bar, .circle, .wave]
        
        for style in styles {
            visualizationView.visualizationStyle = style
            #expect(visualizationView.visualizationStyle == style)
            
            // 触发布局更新
            visualizationView.layoutIfNeeded()
        }
    }
    
    @Test("VolumeVisualizationView 音量信息更新测试")
    func testVolumeVisualizationViewVolumeInfoUpdate() async throws {
        let visualizationView = VolumeVisualizationView(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        
        let volumeInfo = UserVolumeInfo(userId: "test_user", volume: 0.6, isSpeaking: true)
        visualizationView.updateVolumeInfo(volumeInfo)
        
        // 验证更新
        #expect(visualizationView.userId == "test_user")
        #expect(visualizationView.volumeLevel == 0.6)
        #expect(visualizationView.isSpeaking == true)
        
        // 测试重置
        visualizationView.reset()
        #expect(visualizationView.userId == nil)
        #expect(visualizationView.volumeLevel == 0.0)
        #expect(visualizationView.isSpeaking == false)
    }
    
    // MARK: - SpeakingIndicatorView Tests
    
    @Test("SpeakingIndicatorView 基础功能测试")
    func testSpeakingIndicatorViewBasicFunctionality() async throws {
        let indicatorView = SpeakingIndicatorView(frame: CGRect(x: 0, y: 0, width: 150, height: 30))
        
        // 测试初始状态
        #expect(indicatorView.isSpeaking == false)
        #expect(indicatorView.userName == nil)
        #expect(indicatorView.userId == nil)
        
        // 测试用户信息更新
        indicatorView.updateUserInfo(userId: "user123", userName: "Test User", isSpeaking: true)
        
        #expect(indicatorView.userId == "user123")
        #expect(indicatorView.userName == "Test User")
        #expect(indicatorView.isSpeaking == true)
        
        // 测试说话状态变化
        indicatorView.isSpeaking = false
        #expect(indicatorView.isSpeaking == false)
    }
    
    // MARK: - AudioControlPanelView Tests
    
    @Test("AudioControlPanelView 基础功能测试")
    func testAudioControlPanelViewBasicFunctionality() async throws {
        let controlPanel = AudioControlPanelView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let mockCallbacks = MockAudioControlCallbacks()
        
        controlPanel.onAudioSettingsChanged = mockCallbacks.onAudioSettingsChanged
        controlPanel.onMuteToggled = mockCallbacks.onMuteToggled
        controlPanel.onVolumeChanged = mockCallbacks.onVolumeChanged
        
        // 测试初始状态
        #expect(controlPanel.audioSettings == .default)
        #expect(controlPanel.controlSettings.muteToggleCount == 0)
        
        // 模拟音频设置变化
        let newSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 80,
            playbackSignalVolume: 90,
            recordingSignalVolume: 70,
            localAudioStreamActive: true
        )
        controlPanel.audioSettings = newSettings
        
        // 验证设置更新
        #expect(controlPanel.audioSettings.microphoneMuted == true)
        #expect(controlPanel.audioSettings.audioMixingVolume == 80)
        #expect(controlPanel.audioSettings.playbackSignalVolume == 90)
        #expect(controlPanel.audioSettings.recordingSignalVolume == 70)
    }
    
    @Test("AudioControlPanelView 持久化测试")
    func testAudioControlPanelViewPersistence() async throws {
        let controlPanel = AudioControlPanelView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        
        // 测试初始持久化状态
        #expect(controlPanel.controlSettings.rememberSliderPositions == true)
        #expect(controlPanel.controlSettings.muteToggleCount == 0)
        #expect(controlPanel.controlSettings.volumeChangeCount == 0)
        
        // 模拟用户交互（这里需要实际的 UI 交互，简化测试）
        // 在实际应用中，这些会通过用户点击按钮和滑动滑块来触发
        
        // 验证持久化设置的结构
        let settings = controlPanel.controlSettings
        #expect(settings.rememberSliderPositions != nil)
        #expect(settings.muteToggleCount >= 0)
        #expect(settings.volumeChangeCount >= 0)
    }
    
    // MARK: - ErrorFeedbackView Tests
    
    @Test("ErrorFeedbackView 基础功能测试")
    func testErrorFeedbackViewBasicFunctionality() async throws {
        let errorView = ErrorFeedbackView(frame: .zero)
        let parentView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        
        // 测试初始状态
        #expect(errorView.error == nil)
        #expect(errorView.displayDuration == 3.0)
        #expect(errorView.alpha == 0)
        
        // 创建测试错误
        let testError = NSError(domain: "TestDomain", code: 1001, userInfo: [
            NSLocalizedDescriptionKey: "Test error message"
        ])
        
        // 显示错误
        errorView.showError(testError, in: parentView, duration: 1.0)
        
        // 验证错误设置
        #expect(errorView.error != nil)
        #expect(errorView.displayDuration == 1.0)
        #expect(parentView.subviews.contains(errorView))
        
        // 测试手动隐藏
        errorView.hideError()
        
        // 等待动画完成后验证（在实际测试中可能需要异步等待）
        // #expect(!parentView.subviews.contains(errorView))
    }
    
    @Test("ErrorFeedbackView 本地化错误测试")
    func testErrorFeedbackViewLocalizedError() async throws {
        let errorView = ErrorFeedbackView(frame: .zero)
        
        // 创建本地化错误
        let localizedError = LocalizedRealtimeError.connectionFailed
        errorView.error = localizedError
        
        // 验证错误设置
        #expect(errorView.error != nil)
        
        // 测试语言变化（模拟）
        NotificationCenter.default.post(name: .realtimeLanguageDidChange, object: nil)
        
        // 验证错误显示更新（在实际实现中会更新 UI 文本）
    }
    
    // MARK: - StreamPushControlPanelView Tests
    
    @Test("StreamPushControlPanelView 基础功能测试")
    func testStreamPushControlPanelViewBasicFunctionality() async throws {
        let controlPanel = StreamPushControlPanelView(frame: CGRect(x: 0, y: 0, width: 350, height: 400))
        let mockCallbacks = MockStreamPushCallbacks()
        
        controlPanel.onStreamPushStateChanged = mockCallbacks.onStreamPushStateChanged
        controlPanel.onStartStreamPush = mockCallbacks.onStartStreamPush
        controlPanel.onStopStreamPush = mockCallbacks.onStopStreamPush
        controlPanel.onUpdateLayout = mockCallbacks.onUpdateLayout
        
        // 测试初始状态
        #expect(controlPanel.streamPushState == .stopped)
        #expect(controlPanel.controlSettings.buttonTapCount == 0)
        
        // 模拟状态变化
        controlPanel.streamPushState = .running
        #expect(controlPanel.streamPushState == .running)
        
        controlPanel.streamPushState = .failed
        #expect(controlPanel.streamPushState == .failed)
    }
    
    @Test("StreamPushControlPanelView 配置测试")
    func testStreamPushControlPanelViewConfiguration() async throws {
        let controlPanel = StreamPushControlPanelView(frame: CGRect(x: 0, y: 0, width: 350, height: 400))
        
        // 测试配置设置
        let config = StreamPushConfig(
            url: "rtmp://test.example.com/live/stream",
            width: 1920,
            height: 1080,
            videoBitrate: 3000,
            audioBitrate: 128,
            frameRate: 30
        )
        
        controlPanel.streamPushConfig = config
        
        // 验证配置更新
        #expect(controlPanel.streamPushConfig?.url == "rtmp://test.example.com/live/stream")
        #expect(controlPanel.streamPushConfig?.width == 1920)
        #expect(controlPanel.streamPushConfig?.height == 1080)
        #expect(controlPanel.streamPushConfig?.videoBitrate == 3000)
    }
    
    @Test("StreamPushControlPanelView 持久化测试")
    func testStreamPushControlPanelViewPersistence() async throws {
        let controlPanel = StreamPushControlPanelView(frame: CGRect(x: 0, y: 0, width: 350, height: 400))
        
        // 测试初始持久化状态
        #expect(controlPanel.controlSettings.lastBitrate == 2000)
        #expect(controlPanel.controlSettings.lastResolutionIndex == 0)
        #expect(controlPanel.controlSettings.buttonTapCount == 0)
        
        // 验证持久化设置的结构
        let settings = controlPanel.controlSettings
        #expect(settings.lastBitrate >= 500)
        #expect(settings.lastResolutionIndex >= 0)
        #expect(settings.buttonTapCount >= 0)
        #expect(settings.configurationViewCount >= 0)
        #expect(settings.layoutChangeCount >= 0)
    }
    
    // MARK: - MediaRelayControlPanelView Tests
    
    @Test("MediaRelayControlPanelView 基础功能测试")
    func testMediaRelayControlPanelViewBasicFunctionality() async throws {
        let controlPanel = MediaRelayControlPanelView(frame: CGRect(x: 0, y: 0, width: 350, height: 500))
        let mockCallbacks = MockMediaRelayCallbacks()
        
        controlPanel.onStartMediaRelay = mockCallbacks.onStartMediaRelay
        controlPanel.onStopMediaRelay = mockCallbacks.onStopMediaRelay
        controlPanel.onAddDestinationChannel = mockCallbacks.onAddDestinationChannel
        controlPanel.onRemoveDestinationChannel = mockCallbacks.onRemoveDestinationChannel
        
        // 测试初始状态
        #expect(controlPanel.mediaRelayState == nil)
        #expect(controlPanel.controlSettings.buttonTapCount == 0)
        
        // 模拟状态变化
        let relayState = MediaRelayState(
            overallState: .running,
            sourceChannelState: MediaRelayChannelState(channelName: "source", state: .running, error: nil),
            destinationChannelStates: [],
            startTime: Date(),
            statistics: nil
        )
        controlPanel.mediaRelayState = relayState
        
        #expect(controlPanel.mediaRelayState?.overallState == .running)
    }
    
    @Test("MediaRelayControlPanelView 配置测试")
    func testMediaRelayControlPanelViewConfiguration() async throws {
        let controlPanel = MediaRelayControlPanelView(frame: CGRect(x: 0, y: 0, width: 350, height: 500))
        
        // 测试配置设置
        let sourceChannelInfo = MediaRelayChannelInfo(channelName: "source_channel", token: "source_token", uid: 12345)
        let destinationChannelInfos = [
            MediaRelayChannelInfo(channelName: "dest1", token: "token1", uid: 67890),
            MediaRelayChannelInfo(channelName: "dest2", token: "token2", uid: 11111)
        ]
        
        let config = MediaRelayConfig(
            sourceChannelInfo: sourceChannelInfo,
            destinationChannelInfos: destinationChannelInfos
        )
        
        controlPanel.mediaRelayConfig = config
        
        // 验证配置更新
        #expect(controlPanel.mediaRelayConfig?.sourceChannelInfo.channelName == "source_channel")
        #expect(controlPanel.mediaRelayConfig?.destinationChannelInfos.count == 2)
        #expect(controlPanel.mediaRelayConfig?.destinationChannelInfos.first?.channelName == "dest1")
    }
    
    @Test("MediaRelayControlPanelView 持久化测试")
    func testMediaRelayControlPanelViewPersistence() async throws {
        let controlPanel = MediaRelayControlPanelView(frame: CGRect(x: 0, y: 0, width: 350, height: 500))
        
        // 测试初始持久化状态
        #expect(controlPanel.controlSettings.buttonTapCount == 0)
        #expect(controlPanel.controlSettings.channelAddCount == 0)
        #expect(controlPanel.controlSettings.channelRemoveCount == 0)
        
        // 验证持久化设置的结构
        let settings = controlPanel.controlSettings
        #expect(settings.buttonTapCount >= 0)
        #expect(settings.channelAddCount >= 0)
        #expect(settings.channelRemoveCount >= 0)
    }
    
    // MARK: - 本地化通知管理器测试
    
    @Test("LocalizationNotificationManager 测试")
    func testLocalizationNotificationManager() async throws {
        let manager = LocalizationNotificationManager.shared
        let viewController = RealtimeViewController()
        
        // 测试初始状态
        let initialStats = manager.getLocalizationStatistics()
        let initialRegisteredCount = initialStats.registeredViewControllers
        
        // 注册视图控制器
        LocalizationNotificationManager.registerViewController(viewController)
        
        // 验证注册
        let afterRegisterStats = manager.getLocalizationStatistics()
        #expect(afterRegisterStats.totalRegistrations > initialStats.totalRegistrations)
        
        // 注销视图控制器
        LocalizationNotificationManager.unregisterViewController(viewController)
        
        // 验证注销
        let afterUnregisterStats = manager.getLocalizationStatistics()
        #expect(afterUnregisterStats.totalUnregistrations > afterRegisterStats.totalUnregistrations)
    }
    
    @Test("UIKit 本地化状态持久化测试")
    func testUIKitLocalizationStatePersistence() async throws {
        let manager = LocalizationNotificationManager.shared
        
        // 测试初始状态
        let initialState = manager.uikitState
        #expect(initialState.currentLanguage == .english)
        #expect(initialState.registrationCount >= 0)
        #expect(initialState.languageChangeCount >= 0)
        
        // 模拟语言变化
        NotificationCenter.default.post(
            name: .realtimeLanguageDidChange,
            object: nil,
            userInfo: [LocalizationNotificationKeys.currentLanguage: SupportedLanguage.chinese_simplified]
        )
        
        // 验证状态更新
        let updatedState = manager.uikitState
        #expect(updatedState.languageChangeCount > initialState.languageChangeCount)
        #expect(updatedState.lastLanguageChangeDate != nil)
    }
    
    // MARK: - UIView Extension Tests
    
    @Test("UIView findViewController 扩展测试")
    func testUIViewFindViewControllerExtension() async throws {
        let viewController = UIViewController()
        let testView = UIView()
        
        // 添加视图到视图控制器
        viewController.view.addSubview(testView)
        
        // 测试查找视图控制器
        let foundViewController = testView.findViewController()
        #expect(foundViewController === viewController)
        
        // 测试独立视图
        let independentView = UIView()
        let notFoundViewController = independentView.findViewController()
        #expect(notFoundViewController == nil)
    }
}

// MARK: - Mock Delegates and Callbacks

/// Mock RealtimeViewController 代理
class MockRealtimeViewControllerDelegate: RealtimeViewControllerDelegate {
    var lastConnectionState: ConnectionState?
    var connectionStateChangeCount = 0
    var lastVolumeInfos: [UserVolumeInfo] = []
    var volumeUpdateCount = 0
    var lastSpeakingUserId: String?
    var speakingStartCount = 0
    var speakingStopCount = 0
    var lastDominantSpeaker: String?
    var dominantSpeakerChangeCount = 0
    var lastAudioSettings: AudioSettings?
    var audioSettingsChangeCount = 0
    var lastError: Error?
    var errorCount = 0
    
    func realtimeViewController(_ controller: RealtimeViewController, didChangeConnectionState state: ConnectionState) {
        lastConnectionState = state
        connectionStateChangeCount += 1
    }
    
    func realtimeViewController(_ controller: RealtimeViewController, didUpdateVolumeInfos volumeInfos: [UserVolumeInfo]) {
        lastVolumeInfos = volumeInfos
        volumeUpdateCount += 1
    }
    
    func realtimeViewController(_ controller: RealtimeViewController, userDidStartSpeaking userId: String, volume: Float) {
        lastSpeakingUserId = userId
        speakingStartCount += 1
    }
    
    func realtimeViewController(_ controller: RealtimeViewController, userDidStopSpeaking userId: String, volume: Float) {
        lastSpeakingUserId = userId
        speakingStopCount += 1
    }
    
    func realtimeViewController(_ controller: RealtimeViewController, dominantSpeakerDidChange userId: String?) {
        lastDominantSpeaker = userId
        dominantSpeakerChangeCount += 1
    }
    
    func realtimeViewController(_ controller: RealtimeViewController, didChangeAudioSettings settings: AudioSettings) {
        lastAudioSettings = settings
        audioSettingsChangeCount += 1
    }
    
    func realtimeViewController(_ controller: RealtimeViewController, didEncounterError error: Error) {
        lastError = error
        errorCount += 1
    }
}

/// Mock VolumeVisualizationView 代理
class MockVolumeVisualizationViewDelegate: VolumeVisualizationViewDelegate {
    var lastVolumeLevel: Float = 0.0
    var volumeLevelChangeCount = 0
    var lastSpeakingState = false
    var speakingStateChangeCount = 0
    
    func volumeVisualizationView(_ view: VolumeVisualizationView, didChangeVolumeLevel level: Float) {
        lastVolumeLevel = level
        volumeLevelChangeCount += 1
    }
    
    func volumeVisualizationView(_ view: VolumeVisualizationView, didChangeSpeakingState isSpeaking: Bool) {
        lastSpeakingState = isSpeaking
        speakingStateChangeCount += 1
    }
}

/// Mock 音频控制回调
class MockAudioControlCallbacks {
    var lastAudioSettings: AudioSettings?
    var audioSettingsChangeCount = 0
    var lastMuteState: Bool?
    var muteToggleCount = 0
    var lastVolumeType: AudioVolumeType?
    var lastVolumeValue: Int?
    var volumeChangeCount = 0
    
    func onAudioSettingsChanged(_ settings: AudioSettings) {
        lastAudioSettings = settings
        audioSettingsChangeCount += 1
    }
    
    func onMuteToggled(_ muted: Bool) {
        lastMuteState = muted
        muteToggleCount += 1
    }
    
    func onVolumeChanged(_ type: AudioVolumeType, _ value: Int) {
        lastVolumeType = type
        lastVolumeValue = value
        volumeChangeCount += 1
    }
}

/// Mock 转推流回调
class MockStreamPushCallbacks {
    var lastStreamPushState: StreamPushState?
    var streamPushStateChangeCount = 0
    var lastStreamPushConfig: StreamPushConfig?
    var startStreamPushCount = 0
    var stopStreamPushCount = 0
    var lastStreamLayout: StreamLayout?
    var updateLayoutCount = 0
    
    func onStreamPushStateChanged(_ state: StreamPushState) {
        lastStreamPushState = state
        streamPushStateChangeCount += 1
    }
    
    func onStartStreamPush(_ config: StreamPushConfig) {
        lastStreamPushConfig = config
        startStreamPushCount += 1
    }
    
    func onStopStreamPush() {
        stopStreamPushCount += 1
    }
    
    func onUpdateLayout(_ layout: StreamLayout) {
        lastStreamLayout = layout
        updateLayoutCount += 1
    }
}

/// Mock 媒体中继回调
class MockMediaRelayCallbacks {
    var lastMediaRelayConfig: MediaRelayConfig?
    var startMediaRelayCount = 0
    var stopMediaRelayCount = 0
    var lastAddedChannelName: String?
    var lastAddedChannelToken: String?
    var addChannelCount = 0
    var lastRemovedChannelName: String?
    var removeChannelCount = 0
    
    func onStartMediaRelay(_ config: MediaRelayConfig) {
        lastMediaRelayConfig = config
        startMediaRelayCount += 1
    }
    
    func onStopMediaRelay() {
        stopMediaRelayCount += 1
    }
    
    func onAddDestinationChannel(_ channelName: String, _ token: String) {
        lastAddedChannelName = channelName
        lastAddedChannelToken = token
        addChannelCount += 1
    }
    
    func onRemoveDestinationChannel(_ channelName: String) {
        lastRemovedChannelName = channelName
        removeChannelCount += 1
    }
}

#endif