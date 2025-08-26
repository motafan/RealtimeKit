import Foundation
import SwiftUI
import RealtimeCore

/// RealtimeSwiftUI Adaptive Layouts
/// 提供 iPad 自适应布局和多窗口支持
/// 需求: 11.3, 11.5 - iPad 自适应布局和多窗口支持

#if canImport(SwiftUI)

// MARK: - Adaptive Container

/// 自适应容器视图，根据设备和窗口大小调整布局
/// 需求: 11.5 - iPad 自适应布局和多窗口支持
@available(macOS 13.0, iOS 16.0, *)
public struct AdaptiveRealtimeContainer<Content: View>: View {
    
    // MARK: - Properties
    
    private let content: (AdaptiveLayoutContext) -> Content
    
    @State private var layoutContext: AdaptiveLayoutContext = AdaptiveLayoutContext()
    @State private var windowSize: CGSize = .zero
    
    /// Adaptive container state with automatic persistence
    /// 需求: 18.10 - 状态持久化
    @RealtimeStorage("adaptiveContainerState", namespace: "RealtimeKit.UI.Adaptive")
    private var containerState: AdaptiveContainerState = AdaptiveContainerState()
    
    // MARK: - Initialization
    
    public init(@ViewBuilder content: @escaping (AdaptiveLayoutContext) -> Content) {
        self.content = content
    }
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            content(layoutContext)
                .onAppear {
                    updateLayoutContext(for: geometry.size)
                    containerState.viewAppearanceCount += 1
                }
                .onChange(of: geometry.size) { newSize in
                    updateLayoutContext(for: newSize)
                    containerState.sizeChangeCount += 1
                }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateLayoutContext(for size: CGSize) {
        windowSize = size
        
        let deviceType = determineDeviceType()
        let sizeClass = determineSizeClass(for: size)
        let orientation = determineOrientation(for: size)
        let layoutMode = determineLayoutMode(deviceType: deviceType, sizeClass: sizeClass, orientation: orientation)
        
        layoutContext = AdaptiveLayoutContext(
            windowSize: size,
            deviceType: deviceType,
            sizeClass: sizeClass,
            orientation: orientation,
            layoutMode: layoutMode,
            isMultiWindow: isMultiWindowEnvironment(),
            safeAreaInsets: EdgeInsets() // 简化实现
        )
        
        containerState.lastLayoutMode = layoutMode
        containerState.lastUpdateTime = Date()
    }
    
    private func determineDeviceType() -> DeviceType {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return .phone
        case .pad:
            return .tablet
        case .mac:
            return .desktop
        default:
            return .phone
        }
        #elseif os(macOS)
        return .desktop
        #else
        return .desktop
        #endif
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
    
    private func isMultiWindowEnvironment() -> Bool {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            return UIApplication.shared.supportsMultipleScenes
        }
        return false
        #else
        return true
        #endif
    }
}

/// 自适应布局上下文
public struct AdaptiveLayoutContext {
    public let windowSize: CGSize
    public let deviceType: DeviceType
    public let sizeClass: AdaptiveSizeClass
    public let orientation: DeviceOrientation
    public let layoutMode: AdaptiveLayoutMode
    public let isMultiWindow: Bool
    public let safeAreaInsets: EdgeInsets
    
    public init(
        windowSize: CGSize = .zero,
        deviceType: DeviceType = .phone,
        sizeClass: AdaptiveSizeClass = .regular,
        orientation: DeviceOrientation = .portrait,
        layoutMode: AdaptiveLayoutMode = .singleColumn,
        isMultiWindow: Bool = false,
        safeAreaInsets: EdgeInsets = EdgeInsets()
    ) {
        self.windowSize = windowSize
        self.deviceType = deviceType
        self.sizeClass = sizeClass
        self.orientation = orientation
        self.layoutMode = layoutMode
        self.isMultiWindow = isMultiWindow
        self.safeAreaInsets = safeAreaInsets
    }
    
    /// 检查是否为紧凑布局
    public var isCompact: Bool {
        sizeClass == .compact || layoutMode == .singleColumn
    }
    
    /// 检查是否为宽屏布局
    public var isWideScreen: Bool {
        layoutMode == .sidebar || layoutMode == .threeColumn
    }
    
    /// 检查是否支持侧边栏
    public var supportsSidebar: Bool {
        layoutMode == .sidebar
    }
    
    /// 获取推荐的列数
    public var recommendedColumns: Int {
        switch layoutMode {
        case .singleColumn:
            return 1
        case .twoColumn:
            return 2
        case .threeColumn:
            return 3
        case .sidebar:
            return 2 // 侧边栏 + 主内容
        }
    }
}

/// 设备类型枚举
public enum DeviceType: String, CaseIterable, Codable, Sendable {
    case phone = "phone"
    case tablet = "tablet"
    case desktop = "desktop"
    
    public var displayName: String {
        switch self {
        case .phone: return "Phone"
        case .tablet: return "Tablet"
        case .desktop: return "Desktop"
        }
    }
}

/// 自适应尺寸类别
public enum AdaptiveSizeClass: String, CaseIterable, Codable, Sendable {
    case compact = "compact"
    case regular = "regular"
    case expanded = "expanded"
    
    public var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .regular: return "Regular"
        case .expanded: return "Expanded"
        }
    }
}

/// 设备方向枚举
public enum DeviceOrientation: String, CaseIterable, Codable, Sendable {
    case portrait = "portrait"
    case landscape = "landscape"
    
    public var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        }
    }
}

/// 自适应布局模式
public enum AdaptiveLayoutMode: String, CaseIterable, Codable, Sendable {
    case singleColumn = "single_column"
    case twoColumn = "two_column"
    case threeColumn = "three_column"
    case sidebar = "sidebar"
    
    public var displayName: String {
        switch self {
        case .singleColumn: return "Single Column"
        case .twoColumn: return "Two Column"
        case .threeColumn: return "Three Column"
        case .sidebar: return "Sidebar"
        }
    }
}

/// Adaptive Container 持久化状态
/// 需求: 18.10 - 状态持久化
public struct AdaptiveContainerState: Codable, Sendable {
    /// 视图出现次数
    public var viewAppearanceCount: Int = 0
    
    /// 尺寸变化次数
    public var sizeChangeCount: Int = 0
    
    /// 最后布局模式
    public var lastLayoutMode: AdaptiveLayoutMode = .singleColumn
    
    /// 最后更新时间
    public var lastUpdateTime: Date?
    
    public init() {}
}

// MARK: - Adaptive Realtime Dashboard

/// 自适应实时仪表板，支持多种布局模式
/// 需求: 11.3, 11.5, 17.3, 18.10 - 自适应布局、本地化支持和状态持久化
@available(macOS 13.0, iOS 16.0, *)
public struct AdaptiveRealtimeDashboard: View {
    
    // MARK: - Properties
    
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @StateObject private var connectionViewModel = ConnectionViewModel()
    @StateObject private var audioViewModel = AudioViewModel()
    @StateObject private var sessionViewModel = UserSessionViewModel()
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @State private var selectedTab: DashboardTab = .overview
    @State private var showingSidebar: Bool = true
    @State private var sidebarWidth: CGFloat = 300
    
    /// Dashboard state with automatic persistence
    /// 需求: 18.10 - 状态持久化
    @RealtimeStorage("adaptiveDashboardState", namespace: "RealtimeKit.UI.Adaptive")
    private var dashboardState: AdaptiveDashboardState = AdaptiveDashboardState()
    
    // MARK: - Body
    
    public var body: some View {
        AdaptiveRealtimeContainer { context in
            Group {
                switch context.layoutMode {
                case .singleColumn:
                    singleColumnLayout(context: context)
                case .twoColumn:
                    twoColumnLayout(context: context)
                case .threeColumn:
                    threeColumnLayout(context: context)
                case .sidebar:
                    sidebarLayout(context: context)
                }
            }
        }
        .environmentObject(connectionViewModel)
        .environmentObject(audioViewModel)
        .environmentObject(sessionViewModel)
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            dashboardState.currentLanguage = localizationManager.currentLanguage
        }
        .onAppear {
            selectedTab = dashboardState.lastSelectedTab
            showingSidebar = dashboardState.showingSidebar
            sidebarWidth = dashboardState.sidebarWidth
            dashboardState.viewAppearanceCount += 1
        }
    }
    
    // MARK: - Layout Variants
    
    private func singleColumnLayout(context: AdaptiveLayoutContext) -> some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标签栏
                tabBar
                
                Divider()
                
                // 内容区域
                ScrollView {
                    LazyVStack(spacing: 16) {
                        selectedTabContent
                    }
                    .padding()
                }
            }
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    private func twoColumnLayout(context: AdaptiveLayoutContext) -> some View {
        NavigationView {
            // 侧边栏
            List(DashboardTab.allCases, id: \.self) { tab in
                NavigationLink(destination: tabContent(for: tab)) {
                    Label(tab.displayName, systemImage: tab.iconName)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Dashboard")
            
            // 主内容
            selectedTabContent
                .navigationTitle(selectedTab.displayName)
        }
        .onAppear {
            dashboardState.layoutModeUsageCount[context.layoutMode.rawValue, default: 0] += 1
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private func threeColumnLayout(context: AdaptiveLayoutContext) -> some View {
        HStack(spacing: 0) {
            // 左侧边栏 - 导航
            VStack(spacing: 0) {
                sidebarHeader
                
                Divider()
                
                List(DashboardTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    Button(action: {
                        selectedTab = tab
                        dashboardState.lastSelectedTab = tab
                        dashboardState.tabSwitchCount += 1
                    }) {
                        Label(tab.displayName, systemImage: tab.iconName)
                            .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(SidebarListStyle())
                
                Spacer()
            }
            .frame(width: 250)
            .background(Color.gray.opacity(0.1))
            
            Divider()
            
            // 中央内容区域
            VStack(spacing: 0) {
                // 内容标题
                HStack {
                    LocalizedText(
                        selectedTab.localizationKey,
                        fallbackValue: selectedTab.displayName
                    )
                    .font(.title2)
                    
                    Spacer()
                    
                    // 刷新按钮
                    Button(action: {
                        Task {
                            await refreshCurrentTab()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding()
                
                Divider()
                
                // 主内容
                ScrollView {
                    LazyVStack(spacing: 16) {
                        selectedTabContent
                    }
                    .padding()
                }
            }
            .frame(minWidth: 400)
            
            Divider()
            
            // 右侧边栏 - 详细信息
            VStack(spacing: 0) {
                detailSidebarHeader
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        detailSidebarContent
                    }
                    .padding()
                }
            }
            .frame(width: 300)
            .background(Color.gray.opacity(0.1))
        }
        .onAppear {
            dashboardState.layoutModeUsageCount[context.layoutMode.rawValue, default: 0] += 1
        }
    }
    
    private func sidebarLayout(context: AdaptiveLayoutContext) -> some View {
        NavigationView {
            // 可折叠侧边栏
            VStack(spacing: 0) {
                sidebarHeader
                
                Divider()
                
                if showingSidebar {
                    List(DashboardTab.allCases, id: \.self) { tab in
                        NavigationLink(destination: tabContent(for: tab)) {
                            Label(tab.displayName, systemImage: tab.iconName)
                        }
                    }
                    .listStyle(SidebarListStyle())
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading))
                }
            }
            .background(Color.gray.opacity(0.1))
            
            // 主内容区域
            VStack(spacing: 0) {
                // 工具栏
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSidebar.toggle()
                            dashboardState.showingSidebar = showingSidebar
                            dashboardState.sidebarToggleCount += 1
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                    }
                    
                    Spacer()
                    
                    LocalizedText(
                        selectedTab.localizationKey,
                        fallbackValue: selectedTab.displayName
                    )
                    .font(.headline)
                    
                    Spacer()
                    
                    // 语言选择器
                    LanguagePicker()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                Divider()
                
                // 主内容
                selectedTabContent
            }
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .onAppear {
            dashboardState.layoutModeUsageCount[context.layoutMode.rawValue, default: 0] += 1
        }
    }
    
    // MARK: - Content Components
    
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                        dashboardState.lastSelectedTab = tab
                        dashboardState.tabSwitchCount += 1
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 20))
                            
                            Text(tab.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .background(Color.gray.opacity(0.1))
    }
    
    private var sidebarHeader: some View {
        HStack {
            LocalizedText(
                "dashboard.title",
                fallbackValue: "Realtime Dashboard"
            )
            .font(.headline)
            
            Spacer()
            
            ConnectionStateIndicatorView(
                connectionState: connectionViewModel.connectionState
            )
        }
        .padding()
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var detailSidebarHeader: some View {
        HStack {
            LocalizedText(
                "dashboard.details.title",
                fallbackValue: "Details"
            )
            .font(.headline)
            
            Spacer()
        }
        .padding()
    }
    
    private var detailSidebarContent: some View {
        Group {
            switch selectedTab {
            case .overview:
                overviewDetails
            case .audio:
                audioDetails
            case .connection:
                connectionDetails
            case .session:
                sessionDetails
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var selectedTabContent: some View {
        Group {
            switch selectedTab {
            case .overview:
                // RealtimeStatusDashboardView() // Implemented in main SwiftUI file
                Text("Overview Dashboard")
            case .audio:
                VStack(spacing: 16) {
                    AudioControlPanelView()
                    // MultiUserVolumeListView() // Implemented in main SwiftUI file
                    Text("Volume List")
                }
            case .connection:
                connectionTabContent
            case .session:
                sessionTabContent
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private func tabContent(for tab: DashboardTab) -> some View {
        Group {
            switch tab {
            case .overview:
                // RealtimeStatusDashboardView() // Implemented in main SwiftUI file
                Text("Overview Dashboard")
            case .audio:
                VStack(spacing: 16) {
                    AudioControlPanelView()
                    // MultiUserVolumeListView() // Implemented in main SwiftUI file
                    Text("Volume List")
                }
            case .connection:
                connectionTabContent
            case .session:
                sessionTabContent
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var connectionTabContent: some View {
        VStack(spacing: 16) {
            // 连接状态卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LocalizedText(
                        "connection.status.title",
                        fallbackValue: "Connection Status"
                    )
                    .font(.headline)
                    
                    Spacer()
                    
                    ConnectionStateIndicatorView(
                        connectionState: connectionViewModel.connectionState
                    )
                }
                
                if connectionViewModel.reconnectAttempts > 0 {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                        
                        LocalizedText(
                            "connection.reconnect.attempts",
                            arguments: connectionViewModel.reconnectAttempts,
                            fallbackValue: "Reconnect attempts: \(connectionViewModel.reconnectAttempts)"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                // 连接控制按钮
                HStack(spacing: 12) {
                    if connectionViewModel.canReconnect {
                        Button(action: {
                            Task {
                                await connectionViewModel.reconnect()
                            }
                        }) {
                            LocalizedText(
                                "connection.reconnect.button",
                                fallbackValue: "Reconnect"
                            )
                        }
                        .buttonStyle(DefaultButtonStyle())
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(connectionViewModel.isLoading)
                    }
                    
                    if connectionViewModel.isConnected {
                        Button(action: {
                            Task {
                                await connectionViewModel.disconnect()
                            }
                        }) {
                            LocalizedText(
                                "connection.disconnect.button",
                                fallbackValue: "Disconnect"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(connectionViewModel.isLoading)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            
            // 连接历史
            if !connectionViewModel.connectionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        LocalizedText(
                            "connection.history.title",
                            fallbackValue: "Connection History"
                        )
                        .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            connectionViewModel.clearHistory()
                        }) {
                            LocalizedText(
                                "connection.history.clear",
                                fallbackValue: "Clear"
                            )
                            .font(.caption)
                        }
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(connectionViewModel.connectionHistory.suffix(10)) { event in
                            connectionEventRow(event)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var sessionTabContent: some View {
        VStack(spacing: 16) {
            // 当前会话信息
            if let session = sessionViewModel.currentSession {
                VStack(alignment: .leading, spacing: 12) {
                    LocalizedText(
                        "session.current.title",
                        fallbackValue: "Current Session"
                    )
                    .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        sessionInfoRow(
                            titleKey: "session.user.id",
                            titleFallback: "User ID",
                            value: session.userId
                        )
                        
                        sessionInfoRow(
                            titleKey: "session.user.name",
                            titleFallback: "User Name",
                            value: session.userName
                        )
                        
                        sessionInfoRow(
                            titleKey: "session.user.role",
                            titleFallback: "Role",
                            value: sessionViewModel.getRoleDisplayName(session.userRole)
                        )
                        
                        sessionInfoRow(
                            titleKey: "session.duration",
                            titleFallback: "Duration",
                            value: sessionViewModel.formattedSessionDuration
                        )
                        
                        sessionInfoRow(
                            titleKey: "session.permissions",
                            titleFallback: "Permissions",
                            value: sessionViewModel.getPermissionDescription(session.userRole)
                        )
                    }
                    
                    // 角色切换
                    if !sessionViewModel.canSwitchRoles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            LocalizedText(
                                "session.role.switch.title",
                                fallbackValue: "Switch Role"
                            )
                            .font(.subheadline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(Array(sessionViewModel.canSwitchRoles), id: \.self) { role in
                                    Button(action: {
                                        Task {
                                            await sessionViewModel.switchRole(to: role)
                                        }
                                    }) {
                                        Text(sessionViewModel.getRoleDisplayName(role))
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.blue.opacity(0.1))
                                            )
                                            .foregroundColor(.blue)
                                    }
                                    .disabled(sessionViewModel.isLoading)
                                }
                            }
                        }
                    }
                    
                    // 登出按钮
                    Button(action: {
                        Task {
                            await sessionViewModel.logout()
                        }
                    }) {
                        LocalizedText(
                            "session.logout.button",
                            fallbackValue: "Logout"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(sessionViewModel.isLoading)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            } else {
                // 登录表单
                loginForm
            }
        }
    }
    
    // MARK: - Detail Components
    
    @available(macOS 13.0, iOS 16.0, *)
    private var overviewDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedText(
                "dashboard.overview.summary",
                fallbackValue: "System Summary"
            )
            .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                detailRow(
                    titleKey: "dashboard.connection.status",
                    titleFallback: "Connection",
                    value: connectionViewModel.connectionStatusText
                )
                
                detailRow(
                    titleKey: "dashboard.total.users",
                    titleFallback: "Users",
                    value: "\(audioViewModel.totalUserCount)"
                )
                
                detailRow(
                    titleKey: "dashboard.speaking.users",
                    titleFallback: "Speaking",
                    value: "\(audioViewModel.speakingUserCount)"
                )
                
                if let dominantSpeaker = audioViewModel.dominantSpeaker {
                    detailRow(
                        titleKey: "dashboard.dominant.speaker",
                        titleFallback: "Speaker",
                        value: dominantSpeaker
                    )
                }
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var audioDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedText(
                "dashboard.audio.details",
                fallbackValue: "Audio Details"
            )
            .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                detailRow(
                    titleKey: "audio.microphone.status",
                    titleFallback: "Microphone",
                    value: audioViewModel.isMicrophoneMuted ? "Muted" : "Active"
                )
                
                detailRow(
                    titleKey: "audio.mixing.volume",
                    titleFallback: "Mixing Volume",
                    value: "\(audioViewModel.audioSettings.audioMixingVolume)%"
                )
                
                detailRow(
                    titleKey: "audio.average.volume",
                    titleFallback: "Avg Volume",
                    value: String(format: "%.1f%%", audioViewModel.averageVolume * 100)
                )
                
                detailRow(
                    titleKey: "audio.max.volume",
                    titleFallback: "Max Volume",
                    value: String(format: "%.1f%%", audioViewModel.maxVolume * 100)
                )
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedText(
                "dashboard.connection.details",
                fallbackValue: "Connection Details"
            )
            .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                detailRow(
                    titleKey: "connection.current.state",
                    titleFallback: "State",
                    value: connectionViewModel.connectionStatusText
                )
                
                detailRow(
                    titleKey: "connection.quality",
                    titleFallback: "Quality",
                    value: connectionViewModel.connectionQualityText
                )
                
                if connectionViewModel.reconnectAttempts > 0 {
                    detailRow(
                        titleKey: "connection.reconnect.attempts",
                        titleFallback: "Reconnects",
                        value: "\(connectionViewModel.reconnectAttempts)"
                    )
                }
                
                detailRow(
                    titleKey: "connection.history.count",
                    titleFallback: "History",
                    value: "\(connectionViewModel.connectionHistory.count)"
                )
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var sessionDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedText(
                "dashboard.session.details",
                fallbackValue: "Session Details"
            )
            .font(.subheadline)
            
            if sessionViewModel.isLoggedIn {
                VStack(alignment: .leading, spacing: 8) {
                    detailRow(
                        titleKey: "session.status",
                        titleFallback: "Status",
                        value: "Active"
                    )
                    
                    if let userId = sessionViewModel.currentUserId {
                        detailRow(
                            titleKey: "session.user.id",
                            titleFallback: "User ID",
                            value: userId
                        )
                    }
                    
                    if let role = sessionViewModel.currentUserRole {
                        detailRow(
                            titleKey: "session.user.role",
                            titleFallback: "Role",
                            value: sessionViewModel.getRoleDisplayName(role)
                        )
                    }
                    
                    detailRow(
                        titleKey: "session.duration",
                        titleFallback: "Duration",
                        value: sessionViewModel.formattedSessionDuration
                    )
                }
            } else {
                detailRow(
                    titleKey: "session.status",
                    titleFallback: "Status",
                    value: "Not logged in"
                )
            }
        }
    }
    
    // MARK: - Helper Components
    
    private func detailRow(titleKey: String, titleFallback: String, value: String) -> some View {
        HStack {
            LocalizedText(titleKey, fallbackValue: titleFallback)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    private func sessionInfoRow(titleKey: String, titleFallback: String, value: String) -> some View {
        HStack {
            LocalizedText(titleKey, fallbackValue: titleFallback)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    private func connectionEventRow(_ event: ConnectionEvent) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(event.toState.indicatorColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(event.fromState.displayName) → \(event.toState.displayName)")
                        .font(.caption)
                    
                    Spacer()
                    
                    Text(event.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if event.reconnectAttempt > 0 {
                    Text("Attempt \(event.reconnectAttempt)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            LocalizedText(
                "session.login.title",
                fallbackValue: "Login"
            )
            .font(.headline)
            
            // 简化的登录表单
            VStack(spacing: 12) {
                LocalizedTextField(
                    "session.login.user.id",
                    text: .constant(""),
                    fallbackValue: "User ID"
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                LocalizedTextField(
                    "session.login.user.name",
                    text: .constant(""),
                    fallbackValue: "User Name"
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("Role", selection: .constant(UserRole.audience)) {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        Text(sessionViewModel.getRoleDisplayName(role))
                            .tag(role)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button(action: {
                    // 简化实现
                }) {
                    LocalizedText(
                        "session.login.button",
                        fallbackValue: "Login"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DefaultButtonStyle())
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(sessionViewModel.isLoading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        localizationManager.localizedString(
            for: "dashboard.navigation.title",
            fallbackValue: "Realtime Dashboard"
        )
    }
    
    // MARK: - Private Methods
    
    private func refreshCurrentTab() async {
        switch selectedTab {
        case .overview:
            await connectionViewModel.refresh()
            await audioViewModel.refresh()
        case .audio:
            await audioViewModel.refresh()
        case .connection:
            await connectionViewModel.refresh()
        case .session:
            await sessionViewModel.refresh()
        }
        
        dashboardState.refreshCount += 1
    }
}

/// 仪表板标签枚举
public enum DashboardTab: String, CaseIterable, Codable, Sendable {
    case overview = "overview"
    case audio = "audio"
    case connection = "connection"
    case session = "session"
    
    public var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .audio: return "Audio"
        case .connection: return "Connection"
        case .session: return "Session"
        }
    }
    
    public var iconName: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .audio: return "speaker.wave.2.fill"
        case .connection: return "wifi"
        case .session: return "person.circle.fill"
        }
    }
    
    public var localizationKey: String {
        return "dashboard.tab.\(rawValue)"
    }
}

/// Adaptive Dashboard 持久化状态
/// 需求: 18.10 - 状态持久化
public struct AdaptiveDashboardState: Codable, Sendable {
    /// 视图出现次数
    public var viewAppearanceCount: Int = 0
    
    /// 最后选择的标签
    public var lastSelectedTab: DashboardTab = .overview
    
    /// 标签切换次数
    public var tabSwitchCount: Int = 0
    
    /// 是否显示侧边栏
    public var showingSidebar: Bool = true
    
    /// 侧边栏宽度
    public var sidebarWidth: CGFloat = 300
    
    /// 侧边栏切换次数
    public var sidebarToggleCount: Int = 0
    
    /// 刷新次数
    public var refreshCount: Int = 0
    
    /// 布局模式使用次数
    public var layoutModeUsageCount: [String: Int] = [:]
    
    /// 当前语言
    public var currentLanguage: SupportedLanguage = .english
    
    public init() {}
}

#endif
