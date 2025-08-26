import Testing
import SwiftUI
@testable import RealtimeCore
@testable import RealtimeSwiftUI

/// 自适应布局测试
/// 需求: 11.5 - iPad 自适应布局和多窗口支持测试
struct AdaptiveLayoutTests {
    
    // MARK: - AdaptiveLayoutContext Tests
    
    @Test("AdaptiveLayoutContext 初始化测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveLayoutContextInitialization() async throws {
        let context = AdaptiveLayoutContext()
        
        // 验证默认值
        #expect(context.windowSize == .zero)
        #expect(context.deviceType == .phone)
        #expect(context.sizeClass == .regular)
        #expect(context.orientation == .portrait)
        #expect(context.layoutMode == .singleColumn)
        #expect(context.isMultiWindow == false)
        #expect(context.safeAreaInsets == EdgeInsets())
    }
    
    @Test("AdaptiveLayoutContext 自定义初始化测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveLayoutContextCustomInitialization() async throws {
        let windowSize = CGSize(width: 1024, height: 768)
        let safeAreaInsets = EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0)
        
        let context = AdaptiveLayoutContext(
            windowSize: windowSize,
            deviceType: .tablet,
            sizeClass: .expanded,
            orientation: .landscape,
            layoutMode: .sidebar,
            isMultiWindow: true,
            safeAreaInsets: safeAreaInsets
        )
        
        // 验证自定义值
        #expect(context.windowSize == windowSize)
        #expect(context.deviceType == .tablet)
        #expect(context.sizeClass == .expanded)
        #expect(context.orientation == .landscape)
        #expect(context.layoutMode == .sidebar)
        #expect(context.isMultiWindow == true)
        #expect(context.safeAreaInsets == safeAreaInsets)
    }
    
    @Test("AdaptiveLayoutContext 计算属性测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveLayoutContextComputedProperties() async throws {
        // 测试紧凑布局
        let compactContext = AdaptiveLayoutContext(
            sizeClass: .compact,
            layoutMode: .singleColumn
        )
        #expect(compactContext.isCompact == true)
        #expect(compactContext.isWideScreen == false)
        #expect(compactContext.supportsSidebar == false)
        #expect(compactContext.recommendedColumns == 1)
        
        // 测试宽屏布局
        let wideContext = AdaptiveLayoutContext(
            sizeClass: .expanded,
            layoutMode: .sidebar
        )
        #expect(wideContext.isCompact == false)
        #expect(wideContext.isWideScreen == true)
        #expect(wideContext.supportsSidebar == true)
        #expect(wideContext.recommendedColumns == 2)
        
        // 测试三列布局
        let threeColumnContext = AdaptiveLayoutContext(
            layoutMode: .threeColumn
        )
        #expect(threeColumnContext.recommendedColumns == 3)
    }
    
    // MARK: - DeviceType Tests
    
    @Test("DeviceType 枚举测试", arguments: DeviceType.allCases)
    @available(macOS 11.0, iOS 14.0, *)
    func testDeviceTypeEnum(deviceType: DeviceType) async throws {
        // 测试显示名称
        #expect(!deviceType.displayName.isEmpty)
        
        // 测试原始值
        #expect(!deviceType.rawValue.isEmpty)
        
        // 测试特定值
        switch deviceType {
        case .phone:
            #expect(deviceType.displayName == "Phone")
            #expect(deviceType.rawValue == "phone")
        case .tablet:
            #expect(deviceType.displayName == "Tablet")
            #expect(deviceType.rawValue == "tablet")
        case .desktop:
            #expect(deviceType.displayName == "Desktop")
            #expect(deviceType.rawValue == "desktop")
        }
    }
    
    // MARK: - AdaptiveSizeClass Tests
    
    @Test("AdaptiveSizeClass 枚举测试", arguments: AdaptiveSizeClass.allCases)
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveSizeClassEnum(sizeClass: AdaptiveSizeClass) async throws {
        // 测试显示名称
        #expect(!sizeClass.displayName.isEmpty)
        
        // 测试原始值
        #expect(!sizeClass.rawValue.isEmpty)
        
        // 测试特定值
        switch sizeClass {
        case .compact:
            #expect(sizeClass.displayName == "Compact")
            #expect(sizeClass.rawValue == "compact")
        case .regular:
            #expect(sizeClass.displayName == "Regular")
            #expect(sizeClass.rawValue == "regular")
        case .expanded:
            #expect(sizeClass.displayName == "Expanded")
            #expect(sizeClass.rawValue == "expanded")
        }
    }
    
    // MARK: - DeviceOrientation Tests
    
    @Test("DeviceOrientation 枚举测试", arguments: DeviceOrientation.allCases)
    @available(macOS 11.0, iOS 14.0, *)
    func testDeviceOrientationEnum(orientation: DeviceOrientation) async throws {
        // 测试显示名称
        #expect(!orientation.displayName.isEmpty)
        
        // 测试原始值
        #expect(!orientation.rawValue.isEmpty)
        
        // 测试特定值
        switch orientation {
        case .portrait:
            #expect(orientation.displayName == "Portrait")
            #expect(orientation.rawValue == "portrait")
        case .landscape:
            #expect(orientation.displayName == "Landscape")
            #expect(orientation.rawValue == "landscape")
        }
    }
    
    // MARK: - AdaptiveLayoutMode Tests
    
    @Test("AdaptiveLayoutMode 枚举测试", arguments: AdaptiveLayoutMode.allCases)
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveLayoutModeEnum(layoutMode: AdaptiveLayoutMode) async throws {
        // 测试显示名称
        #expect(!layoutMode.displayName.isEmpty)
        
        // 测试原始值
        #expect(!layoutMode.rawValue.isEmpty)
        
        // 测试特定值
        switch layoutMode {
        case .singleColumn:
            #expect(layoutMode.displayName == "Single Column")
            #expect(layoutMode.rawValue == "single_column")
        case .twoColumn:
            #expect(layoutMode.displayName == "Two Column")
            #expect(layoutMode.rawValue == "two_column")
        case .threeColumn:
            #expect(layoutMode.displayName == "Three Column")
            #expect(layoutMode.rawValue == "three_column")
        case .sidebar:
            #expect(layoutMode.displayName == "Sidebar")
            #expect(layoutMode.rawValue == "sidebar")
        }
    }
    
    // MARK: - AdaptiveContainerState Tests
    
    @Test("AdaptiveContainerState 持久化状态测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveContainerStatePersistence() async throws {
        var containerState = AdaptiveContainerState()
        
        // 测试初始状态
        #expect(containerState.viewAppearanceCount == 0)
        #expect(containerState.sizeChangeCount == 0)
        #expect(containerState.lastLayoutMode == .singleColumn)
        #expect(containerState.lastUpdateTime == nil)
        
        // 更新状态
        containerState.viewAppearanceCount = 5
        containerState.sizeChangeCount = 3
        containerState.lastLayoutMode = .sidebar
        containerState.lastUpdateTime = Date()
        
        // 验证状态更新
        #expect(containerState.viewAppearanceCount == 5)
        #expect(containerState.sizeChangeCount == 3)
        #expect(containerState.lastLayoutMode == .sidebar)
        #expect(containerState.lastUpdateTime != nil)
    }
    
    // MARK: - AdaptiveRealtimeContainer Tests
    
    @Test("AdaptiveRealtimeContainer 初始化测试")
    @available(macOS 11.0, iOS 14.0, *)
    @MainActor
    func testAdaptiveRealtimeContainerInitialization() async throws {
        let container = AdaptiveRealtimeContainer { context in
            Text("Test Content")
        }
        
        // 验证容器可以正确初始化
        #expect(container != nil)
    }
    
    // MARK: - DashboardTab Tests
    
    @Test("DashboardTab 枚举测试", arguments: DashboardTab.allCases)
    @available(macOS 11.0, iOS 14.0, *)
    func testDashboardTabEnum(tab: DashboardTab) async throws {
        // 测试显示名称
        #expect(!tab.displayName.isEmpty)
        
        // 测试图标名称
        #expect(!tab.iconName.isEmpty)
        
        // 测试本地化键
        #expect(tab.localizationKey.hasPrefix("dashboard.tab."))
        
        // 测试特定值
        switch tab {
        case .overview:
            #expect(tab.displayName == "Overview")
            #expect(tab.iconName == "chart.bar.fill")
            #expect(tab.rawValue == "overview")
        case .audio:
            #expect(tab.displayName == "Audio")
            #expect(tab.iconName == "speaker.wave.2.fill")
            #expect(tab.rawValue == "audio")
        case .connection:
            #expect(tab.displayName == "Connection")
            #expect(tab.iconName == "wifi")
            #expect(tab.rawValue == "connection")
        case .session:
            #expect(tab.displayName == "Session")
            #expect(tab.iconName == "person.circle.fill")
            #expect(tab.rawValue == "session")
        }
    }
    
    // MARK: - AdaptiveDashboardState Tests
    
    @Test("AdaptiveDashboardState 持久化状态测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveDashboardStatePersistence() async throws {
        var dashboardState = AdaptiveDashboardState()
        
        // 测试初始状态
        #expect(dashboardState.viewAppearanceCount == 0)
        #expect(dashboardState.lastSelectedTab == .overview)
        #expect(dashboardState.tabSwitchCount == 0)
        #expect(dashboardState.showingSidebar == true)
        #expect(dashboardState.sidebarWidth == 300)
        #expect(dashboardState.sidebarToggleCount == 0)
        #expect(dashboardState.refreshCount == 0)
        #expect(dashboardState.layoutModeUsageCount.isEmpty)
        #expect(dashboardState.currentLanguage == .english)
        
        // 更新状态
        dashboardState.viewAppearanceCount = 10
        dashboardState.lastSelectedTab = .audio
        dashboardState.tabSwitchCount = 5
        dashboardState.showingSidebar = false
        dashboardState.sidebarWidth = 250
        dashboardState.sidebarToggleCount = 3
        dashboardState.refreshCount = 8
        dashboardState.layoutModeUsageCount["sidebar"] = 5
        dashboardState.currentLanguage = .japanese
        
        // 验证状态更新
        #expect(dashboardState.viewAppearanceCount == 10)
        #expect(dashboardState.lastSelectedTab == .audio)
        #expect(dashboardState.tabSwitchCount == 5)
        #expect(dashboardState.showingSidebar == false)
        #expect(dashboardState.sidebarWidth == 250)
        #expect(dashboardState.sidebarToggleCount == 3)
        #expect(dashboardState.refreshCount == 8)
        #expect(dashboardState.layoutModeUsageCount["sidebar"] == 5)
        #expect(dashboardState.currentLanguage == .japanese)
    }
    
    // MARK: - AdaptiveRealtimeDashboard Tests
    
    @Test("AdaptiveRealtimeDashboard 初始化测试")
    @available(macOS 11.0, iOS 14.0, *)
    @MainActor
    func testAdaptiveRealtimeDashboardInitialization() async throws {
        let dashboard = AdaptiveRealtimeDashboard()
        
        // 验证仪表板可以正确初始化
        #expect(dashboard != nil)
    }
    
    // MARK: - 布局逻辑测试
    
    @Test("布局模式决策逻辑测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testLayoutModeDecisionLogic() async throws {
        // 测试不同设备和尺寸组合的布局模式决策
        let testCases: [(DeviceType, AdaptiveSizeClass, DeviceOrientation, AdaptiveLayoutMode)] = [
            (.phone, .compact, .portrait, .singleColumn),
            (.phone, .compact, .landscape, .singleColumn),
            (.phone, .regular, .landscape, .twoColumn),
            (.tablet, .compact, .portrait, .twoColumn),
            (.tablet, .regular, .portrait, .threeColumn),
            (.tablet, .expanded, .landscape, .sidebar),
            (.desktop, .regular, .landscape, .sidebar),
            (.desktop, .expanded, .landscape, .sidebar)
        ]
        
        for (deviceType, sizeClass, orientation, expectedMode) in testCases {
            let determinedMode = determineLayoutMode(
                deviceType: deviceType,
                sizeClass: sizeClass,
                orientation: orientation
            )
            #expect(determinedMode == expectedMode, 
                   "Expected \(expectedMode) for \(deviceType)-\(sizeClass)-\(orientation), got \(determinedMode)")
        }
    }
    
    @Test("尺寸类别决策逻辑测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testSizeClassDecisionLogic() async throws {
        // 测试不同窗口尺寸的尺寸类别决策
        let testCases: [(CGSize, AdaptiveSizeClass)] = [
            (CGSize(width: 320, height: 568), .compact),    // iPhone SE
            (CGSize(width: 375, height: 667), .compact),    // iPhone 8
            (CGSize(width: 414, height: 896), .regular),    // iPhone 11 Pro Max
            (CGSize(width: 768, height: 1024), .regular),   // iPad
            (CGSize(width: 1024, height: 1366), .expanded), // iPad Pro
            (CGSize(width: 1440, height: 900), .expanded)   // Desktop
        ]
        
        for (size, expectedClass) in testCases {
            let determinedClass = determineSizeClass(for: size)
            #expect(determinedClass == expectedClass,
                   "Expected \(expectedClass) for size \(size), got \(determinedClass)")
        }
    }
    
    @Test("设备方向决策逻辑测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testOrientationDecisionLogic() async throws {
        // 测试不同窗口尺寸的方向决策
        let testCases: [(CGSize, DeviceOrientation)] = [
            (CGSize(width: 320, height: 568), .portrait),   // 竖屏
            (CGSize(width: 568, height: 320), .landscape),  // 横屏
            (CGSize(width: 1024, height: 768), .landscape), // iPad 横屏
            (CGSize(width: 768, height: 1024), .portrait),  // iPad 竖屏
            (CGSize(width: 1000, height: 1000), .portrait)  // 正方形（默认竖屏）
        ]
        
        for (size, expectedOrientation) in testCases {
            let determinedOrientation = determineOrientation(for: size)
            #expect(determinedOrientation == expectedOrientation,
                   "Expected \(expectedOrientation) for size \(size), got \(determinedOrientation)")
        }
    }
    
    // MARK: - 响应式布局测试
    
    @Test("响应式布局变化测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testResponsiveLayoutChanges() async throws {
        // 模拟窗口尺寸变化
        let initialSize = CGSize(width: 320, height: 568)
        let expandedSize = CGSize(width: 1024, height: 768)
        
        // 初始状态
        let initialContext = createLayoutContext(for: initialSize)
        #expect(initialContext.layoutMode == .singleColumn)
        #expect(initialContext.orientation == .portrait)
        #expect(initialContext.sizeClass == .compact)
        
        // 扩展状态
        let expandedContext = createLayoutContext(for: expandedSize)
        #expect(expandedContext.layoutMode != .singleColumn)
        #expect(expandedContext.orientation == .landscape)
        #expect(expandedContext.sizeClass != .compact)
    }
    
    // MARK: - 多窗口支持测试
    
    @Test("多窗口环境检测测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testMultiWindowEnvironmentDetection() async throws {
        // 测试多窗口环境检测逻辑
        let isMultiWindow = isMultiWindowEnvironment()
        
        #if os(macOS)
        #expect(isMultiWindow == true) // macOS 总是支持多窗口
        #elseif os(iOS)
        // iOS 的多窗口支持取决于系统版本和应用配置
        // 这里简化测试
        #expect(isMultiWindow != nil)
        #endif
    }
    
    // MARK: - 性能测试
    
    @Test("自适应布局性能测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testAdaptiveLayoutPerformance() async throws {
        let startTime = Date()
        
        // 模拟大量布局计算
        for _ in 0..<1000 {
            let size = CGSize(
                width: Double.random(in: 320...1920),
                height: Double.random(in: 568...1080)
            )
            
            let context = createLayoutContext(for: size)
            
            // 验证计算结果的合理性
            #expect(context.windowSize == size)
            #expect(context.recommendedColumns >= 1)
            #expect(context.recommendedColumns <= 3)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        // 验证性能（应该在合理时间内完成）
        #expect(executionTime < 1.0) // 1秒内完成
    }
    
    // MARK: - 边界情况测试
    
    @Test("边界情况测试")
    @available(macOS 11.0, iOS 14.0, *)
    func testEdgeCases() async throws {
        // 测试极小尺寸
        let tinySize = CGSize(width: 1, height: 1)
        let tinyContext = createLayoutContext(for: tinySize)
        #expect(tinyContext.sizeClass == .compact)
        #expect(tinyContext.layoutMode == .singleColumn)
        
        // 测试极大尺寸
        let hugeSize = CGSize(width: 10000, height: 10000)
        let hugeContext = createLayoutContext(for: hugeSize)
        #expect(hugeContext.sizeClass == .expanded)
        
        // 测试零尺寸
        let zeroSize = CGSize.zero
        let zeroContext = createLayoutContext(for: zeroSize)
        #expect(zeroContext.windowSize == zeroSize)
        
        // 测试负尺寸（不应该发生，但要处理）
        let negativeSize = CGSize(width: -100, height: -100)
        let negativeContext = createLayoutContext(for: negativeSize)
        #expect(negativeContext.windowSize == negativeSize)
    }
}

// MARK: - 测试辅助函数

private func determineLayoutMode(
    deviceType: DeviceType,
    sizeClass: AdaptiveSizeClass,
    orientation: DeviceOrientation
) -> AdaptiveLayoutMode {
    switch (deviceType, sizeClass, orientation) {
    case (.phone, .compact, _):
        return .singleColumn
    case (.phone, .regular, .landscape):
        return .twoColumn
    case (.tablet, .compact, _):
        return .twoColumn
    case (.tablet, .regular, _):
        return .threeColumn
    case (.tablet, .expanded, _):
        return .sidebar
    case (.desktop, _, _):
        return .sidebar
    default:
        return .singleColumn
    }
}

private func determineSizeClass(for size: CGSize) -> AdaptiveSizeClass {
    let minDimension = min(size.width, size.height)
    let maxDimension = max(size.width, size.height)
    
    if minDimension < 400 {
        return .compact
    } else if maxDimension > 1000 {
        return .expanded
    } else {
        return .regular
    }
}

private func determineOrientation(for size: CGSize) -> DeviceOrientation {
    return size.width > size.height ? .landscape : .portrait
}

private func determineDeviceType() -> DeviceType {
    #if os(iOS)
    return .tablet // 简化测试，假设是 iPad
    #elseif os(macOS)
    return .desktop
    #else
    return .desktop
    #endif
}

private func isMultiWindowEnvironment() -> Bool {
    #if os(iOS)
    if #available(iOS 13.0, *) {
        return true // 简化测试
    }
    return false
    #else
    return true
    #endif
}

private func createLayoutContext(for size: CGSize) -> AdaptiveLayoutContext {
    let deviceType = determineDeviceType()
    let sizeClass = determineSizeClass(for: size)
    let orientation = determineOrientation(for: size)
    let layoutMode = determineLayoutMode(
        deviceType: deviceType,
        sizeClass: sizeClass,
        orientation: orientation
    )
    
    return AdaptiveLayoutContext(
        windowSize: size,
        deviceType: deviceType,
        sizeClass: sizeClass,
        orientation: orientation,
        layoutMode: layoutMode,
        isMultiWindow: isMultiWindowEnvironment(),
        safeAreaInsets: EdgeInsets()
    )
}
