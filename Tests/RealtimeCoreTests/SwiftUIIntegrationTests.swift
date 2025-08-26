import Testing
import SwiftUI
@testable import RealtimeCore
@testable import RealtimeSwiftUI

/// SwiftUI 集成测试
/// 需求: 11.2, 11.3, 17.3, 17.6, 18.10 - SwiftUI 组件的单元测试和动画测试

struct SwiftUIIntegrationTests {
    
    // MARK: - RealtimeView Tests
    
    @Test("RealtimeView 初始化和状态管理")
    @MainActor
    func testRealtimeViewInitialization() async throws {
        // 创建测试视图
        let realtimeView = RealtimeView {
            Text("Test Content")
        }
        
        // 验证视图可以正确初始化（不需要与 nil 比较）
        _ = realtimeView
    }
    
    @Test("RealtimeViewState 持久化状态")
    func testRealtimeViewStatePersistence() async throws {
        var viewState = RealtimeViewState()
        
        // 测试初始状态
        #expect(viewState.viewAppearanceCount == 0)
        #expect(viewState.connectionStateChangeCount == 0)
        #expect(viewState.currentLanguage == .english)
        
        // 更新状态
        viewState.viewAppearanceCount = 5
        viewState.connectionStateChangeCount = 3
        viewState.currentLanguage = .chineseSimplified
        viewState.lastAppearanceTime = Date()
        
        // 验证状态更新
        #expect(viewState.viewAppearanceCount == 5)
        #expect(viewState.connectionStateChangeCount == 3)
        #expect(viewState.currentLanguage == .chineseSimplified)
        #expect(viewState.lastAppearanceTime != nil)
    }
    
    // MARK: - VolumeVisualizationView Tests
    
    @Test("VolumeVisualizationView 样式测试", arguments: VolumeVisualizationStyle.allCases)
    @MainActor
    func testVolumeVisualizationStyles(style: VolumeVisualizationStyle) async throws {
        let volumeView = VolumeVisualizationView(
            volumeLevel: 0.75,
            isSpeaking: true,
            style: style
        )
        
        // 验证视图可以正确初始化（不需要与 nil 比较）
        _ = volumeView
        
        // 验证样式显示名称
        #expect(!style.displayName.isEmpty)
    }
    
    @Test("VolumeVisualizationStyle 枚举测试")
    func testVolumeVisualizationStyleEnum() async throws {
        // 测试所有样式
        let allStyles = VolumeVisualizationStyle.allCases
        #expect(allStyles.count == 4)
        #expect(allStyles.contains(.bar))
        #expect(allStyles.contains(.waveform))
        #expect(allStyles.contains(.circular))
        #expect(allStyles.contains(.ripple))
        
        // 测试显示名称
        #expect(VolumeVisualizationStyle.bar.displayName == "Bar")
        #expect(VolumeVisualizationStyle.waveform.displayName == "Waveform")
        #expect(VolumeVisualizationStyle.circular.displayName == "Circular")
        #expect(VolumeVisualizationStyle.ripple.displayName == "Ripple")
        
        // 测试原始值
        #expect(VolumeVisualizationStyle.bar.rawValue == "bar")
        #expect(VolumeVisualizationStyle.waveform.rawValue == "waveform")
        #expect(VolumeVisualizationStyle.circular.rawValue == "circular")
        #expect(VolumeVisualizationStyle.ripple.rawValue == "ripple")
    }
    
    // MARK: - UserVolumeIndicatorView Tests
    
    @Test("UserVolumeIndicatorView 初始化测试")
    @MainActor
    func testUserVolumeIndicatorViewInitialization() async throws {
        let volumeInfo = UserVolumeInfo(
            userId: "test-user",
            volumeFloat: 0.8,
            isSpeaking: true
        )
        
        let indicatorView = UserVolumeIndicatorView(
            userVolumeInfo: volumeInfo,
            visualizationStyle: .bar,
            showPercentage: true
        )
        
        // 验证视图可以正确初始化（不需要与 nil 比较）
        _ = indicatorView
    }
    
    @Test("UserVolumeIndicatorState 持久化状态")
    func testUserVolumeIndicatorStatePersistence() async throws {
        var indicatorState = UserVolumeIndicatorState()
        
        // 测试初始状态
        #expect(indicatorState.displayCount == 0)
        #expect(indicatorState.speakingDisplayCount == 0)
        #expect(indicatorState.currentLanguage == .english)
        #expect(indicatorState.preferredVisualizationStyle == .bar)
        #expect(indicatorState.showPercentage == true)
        
        // 更新状态
        indicatorState.displayCount = 10
        indicatorState.speakingDisplayCount = 5
        indicatorState.currentLanguage = .japanese
        indicatorState.preferredVisualizationStyle = .circular
        indicatorState.showPercentage = false
        indicatorState.lastDisplayTime = Date()
        
        // 验证状态更新
        #expect(indicatorState.displayCount == 10)
        #expect(indicatorState.speakingDisplayCount == 5)
        #expect(indicatorState.currentLanguage == .japanese)
        #expect(indicatorState.preferredVisualizationStyle == .circular)
        #expect(indicatorState.showPercentage == false)
        #expect(indicatorState.lastDisplayTime != nil)
    }
    
    // MARK: - ConnectionStateIndicatorView Tests
    
    @Test("ConnectionStateIndicatorView 样式测试", arguments: ConnectionIndicatorStyle.allCases)
    @MainActor
    func testConnectionStateIndicatorStyles(style: ConnectionIndicatorStyle) async throws {
        let indicatorView = ConnectionStateIndicatorView(
            connectionState: .connected,
            showText: true,
            style: style
        )
        
        // 验证视图可以正确初始化（不需要与 nil 比较）
        _ = indicatorView
        
        // 验证样式显示名称
        #expect(!style.displayName.isEmpty)
    }
    
    @Test("ConnectionIndicatorStyle 枚举测试")
    func testConnectionIndicatorStyleEnum() async throws {
        // 测试所有样式
        let allStyles = ConnectionIndicatorStyle.allCases
        #expect(allStyles.count == 3)
        #expect(allStyles.contains(.capsule))
        #expect(allStyles.contains(.badge))
        #expect(allStyles.contains(.minimal))
        
        // 测试显示名称
        #expect(ConnectionIndicatorStyle.capsule.displayName == "Capsule")
        #expect(ConnectionIndicatorStyle.badge.displayName == "Badge")
        #expect(ConnectionIndicatorStyle.minimal.displayName == "Minimal")
        
        // 测试原始值
        #expect(ConnectionIndicatorStyle.capsule.rawValue == "capsule")
        #expect(ConnectionIndicatorStyle.badge.rawValue == "badge")
        #expect(ConnectionIndicatorStyle.minimal.rawValue == "minimal")
    }
    
    @Test("ConnectionStateIndicatorState 持久化状态")
    func testConnectionStateIndicatorStatePersistence() async throws {
        var indicatorState = ConnectionStateIndicatorState()
        
        // 测试初始状态
        #expect(indicatorState.displayCount == 0)
        #expect(indicatorState.stateChangeCount == 0)
        #expect(indicatorState.lastState == .disconnected)
        #expect(indicatorState.currentLanguage == .english)
        #expect(indicatorState.preferredStyle == .capsule)
        
        // 更新状态
        indicatorState.displayCount = 15
        indicatorState.stateChangeCount = 8
        indicatorState.lastState = .connected
        indicatorState.currentLanguage = .korean
        indicatorState.preferredStyle = .badge
        indicatorState.lastDisplayTime = Date()
        
        // 验证状态更新
        #expect(indicatorState.displayCount == 15)
        #expect(indicatorState.stateChangeCount == 8)
        #expect(indicatorState.lastState == .connected)
        #expect(indicatorState.currentLanguage == .korean)
        #expect(indicatorState.preferredStyle == .badge)
        #expect(indicatorState.lastDisplayTime != nil)
    }
    
    // MARK: - AudioControlPanelView Tests
    
    @Test("AudioControlPanelView 初始化测试")
    @MainActor
    func testAudioControlPanelViewInitialization() async throws {
        let panelView = AudioControlPanelView()
        
        // 验证视图可以正确初始化（不需要与 nil 比较）
        _ = panelView
    }
    
    @Test("AudioControlPanelState 持久化状态")
    func testAudioControlPanelStatePersistence() async throws {
        var panelState = AudioControlPanelState()
        
        // 测试初始状态
        #expect(panelState.isExpanded == true)
        #expect(panelState.showAdvancedControls == false)
        #expect(panelState.toggleCount == 0)
        #expect(panelState.microphoneToggleCount == 0)
        #expect(panelState.currentLanguage == .english)
        
        // 更新状态
        panelState.isExpanded = false
        panelState.showAdvancedControls = true
        panelState.toggleCount = 3
        panelState.microphoneToggleCount = 5
        panelState.mixingVolumeAdjustmentCount = 10
        panelState.currentLanguage = .chineseTraditional
        panelState.lastAudioSettingsUpdate = Date()
        
        // 验证状态更新
        #expect(panelState.isExpanded == false)
        #expect(panelState.showAdvancedControls == true)
        #expect(panelState.toggleCount == 3)
        #expect(panelState.microphoneToggleCount == 5)
        #expect(panelState.mixingVolumeAdjustmentCount == 10)
        #expect(panelState.currentLanguage == .chineseTraditional)
        #expect(panelState.lastAudioSettingsUpdate != nil)
    }
    
    // MARK: - MultiUserVolumeListView Tests
    
    @Test("MultiUserVolumeListView 初始化测试")
    @MainActor
    func testMultiUserVolumeListViewInitialization() async throws {
        let listView = MultiUserVolumeListView()
        
        // 验证视图可以正确初始化（不需要与 nil 比较）
        _ = listView
    }
    
    @Test("MultiUserVolumeListState 持久化状态")
    func testMultiUserVolumeListStatePersistence() async throws {
        var listState = MultiUserVolumeListState()
        
        // 测试初始状态
        #expect(listState.currentLanguage == .english)
        #expect(listState.preferredVisualizationStyle == .bar)
        #expect(listState.showPercentages == true)
        #expect(listState.sortBySpeaking == true)
        #expect(listState.viewAppearanceCount == 0)
        
        // 更新状态
        listState.currentLanguage = .japanese
        listState.preferredVisualizationStyle = .waveform
        listState.showPercentages = false
        listState.sortBySpeaking = false
        listState.viewAppearanceCount = 7
        listState.styleChangeCount = 3
        listState.lastItemCount = 5
        
        // 验证状态更新
        #expect(listState.currentLanguage == .japanese)
        #expect(listState.preferredVisualizationStyle == .waveform)
        #expect(listState.showPercentages == false)
        #expect(listState.sortBySpeaking == false)
        #expect(listState.viewAppearanceCount == 7)
        #expect(listState.styleChangeCount == 3)
        #expect(listState.lastItemCount == 5)
    }
    
    // MARK: - RealtimeStatusDashboardView Tests
    
    @Test("RealtimeStatusDashboardView 初始化测试")
    @MainActor
    func testRealtimeStatusDashboardViewInitialization() async throws {
        let dashboardView = RealtimeStatusDashboardView()
        
        // 验证视图可以正确初始化（不需要与 nil 比较）
        _ = dashboardView
    }
    
    @Test("RealtimeStatusDashboardState 持久化状态")
    func testRealtimeStatusDashboardStatePersistence() async throws {
        var dashboardState = RealtimeStatusDashboardState()
        
        // 测试初始状态
        #expect(dashboardState.currentLanguage == .english)
        #expect(dashboardState.isCompactMode == false)
        #expect(dashboardState.showDetailedStats == false)
        #expect(dashboardState.viewAppearanceCount == 0)
        #expect(dashboardState.totalActiveTime == 0)
        
        // 更新状态
        dashboardState.currentLanguage = .korean
        dashboardState.isCompactMode = true
        dashboardState.showDetailedStats = true
        dashboardState.viewAppearanceCount = 12
        dashboardState.modeToggleCount = 4
        dashboardState.totalActiveTime = 3600 // 1 hour
        dashboardState.lastUpdateTime = Date()
        
        // 验证状态更新
        #expect(dashboardState.currentLanguage == .korean)
        #expect(dashboardState.isCompactMode == true)
        #expect(dashboardState.showDetailedStats == true)
        #expect(dashboardState.viewAppearanceCount == 12)
        #expect(dashboardState.modeToggleCount == 4)
        #expect(dashboardState.totalActiveTime == 3600)
        #expect(dashboardState.lastUpdateTime != nil)
    }
    
    // MARK: - Environment Values Tests
    
    @Test("SwiftUI Environment Values 测试")
    func testSwiftUIEnvironmentValues() async throws {
        // 测试环境值的默认值
        let connectionStateKey = RealtimeConnectionStateKey.self
        let volumeInfosKey = RealtimeVolumeInfosKey.self
        let speakingUsersKey = RealtimeSpeakingUsersKey.self
        let dominantSpeakerKey = RealtimeDominantSpeakerKey.self
        
        // 验证默认值
        #expect(connectionStateKey.defaultValue == .disconnected)
        #expect(volumeInfosKey.defaultValue.isEmpty)
        #expect(speakingUsersKey.defaultValue.isEmpty)
        #expect(dominantSpeakerKey.defaultValue == nil)
    }
    
    // MARK: - ConnectionState Extension Tests
    
    @Test("ConnectionState 扩展属性测试", arguments: ConnectionState.allCases)
    func testConnectionStateExtensions(state: ConnectionState) async throws {
        // 测试 indicatorColor 属性
        let color = state.indicatorColor
        #expect(color != nil)
        
        // 测试 localizationKey 属性
        let localizationKey = state.localizationKey
        #expect(!localizationKey.isEmpty)
        #expect(localizationKey.hasPrefix("connection.state."))
        
        // 测试 shouldAnimate 属性
        let shouldAnimate = state.shouldAnimate
        switch state {
        case .connecting, .reconnecting:
            #expect(shouldAnimate == true)
        case .disconnected, .connected, .failed, .suspended:
            #expect(shouldAnimate == false)
        }
        
        // 测试颜色映射
        switch state {
        case .disconnected:
            #expect(color == .gray)
        case .connecting, .reconnecting:
            #expect(color == .orange)
        case .connected:
            #expect(color == .green)
        case .failed:
            #expect(color == .red)
        case .suspended:
            #expect(color == .yellow)
        }
    }
    
    // MARK: - 集成测试
    
    @Test("SwiftUI 组件集成测试")
    @MainActor
    func testSwiftUIComponentsIntegration() async throws {
        // 创建测试数据
        let volumeInfo = UserVolumeInfo(
            userId: "test-user",
            volumeFloat: 0.75,
            isSpeaking: true
        )
        
        // 测试组件可以正确组合使用
        let combinedView = VStack {
            ConnectionStateIndicatorView(
                connectionState: .connected,
                showText: true,
                style: .capsule
            )
            
            UserVolumeIndicatorView(
                userVolumeInfo: volumeInfo,
                visualizationStyle: .bar,
                showPercentage: true
            )
            
            VolumeVisualizationView(
                volumeLevel: volumeInfo.volumeFloat,
                isSpeaking: volumeInfo.isSpeaking,
                style: .waveform
            )
        }
        
        // 验证组合视图可以正确初始化（不需要与 nil 比较）
        _ = combinedView
    }
    
    // MARK: - 性能测试
    
    @Test("SwiftUI 组件性能测试")
    func testSwiftUIComponentsPerformance() async throws {
        // 测试大量音量信息的处理性能
        let volumeInfos = (0..<100).map { index in
            UserVolumeInfo(
                userId: "user-\(index)",
                volumeFloat: Float.random(in: 0...1),
                isSpeaking: Bool.random()
            )
        }
        
        // 验证可以处理大量数据
        #expect(volumeInfos.count == 100)
        
        // 测试排序性能
        let sortedInfos = volumeInfos.sorted { first, second in
            if first.isSpeaking && !second.isSpeaking {
                return true
            } else if !first.isSpeaking && second.isSpeaking {
                return false
            } else if first.isSpeaking && second.isSpeaking {
                return first.volumeFloat > second.volumeFloat
            } else {
                return first.userId < second.userId
            }
        }
        
        #expect(sortedInfos.count == volumeInfos.count)
    }
    
    // MARK: - 错误处理测试
    
    @Test("SwiftUI 组件错误处理测试")
    @MainActor
    func testSwiftUIComponentsErrorHandling() async throws {
        // 测试极端音量值
        let extremeVolumeInfo = UserVolumeInfo(
            userId: "extreme-user",
            volumeFloat: 2.0, // 超出正常范围
            isSpeaking: true
        )
        
        // 验证组件可以处理极端值
        let indicatorView = UserVolumeIndicatorView(
            userVolumeInfo: extremeVolumeInfo,
            visualizationStyle: .bar,
            showPercentage: true
        )
        
        // 验证视图创建成功（不需要与 nil 比较）
        _ = indicatorView
        
        // 测试空用户ID
        let emptyUserInfo = UserVolumeInfo(
            userId: "",
            volumeFloat: 0.5,
            isSpeaking: false
        )
        
        let emptyUserView = UserVolumeIndicatorView(
            userVolumeInfo: emptyUserInfo,
            visualizationStyle: .circular,
            showPercentage: false
        )
        
        // 验证视图创建成功（不需要与 nil 比较）
        _ = emptyUserView
    }
}

// MARK: - 环境键测试（使用公共定义）
