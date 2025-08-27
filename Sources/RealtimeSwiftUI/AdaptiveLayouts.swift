//
//  AdaptiveLayouts.swift
//  RealtimeKit
//
//  Created by RealtimeKit on 2024-12-19.
//

import SwiftUI
import RealtimeCore

#if canImport(SwiftUI)

// MARK: - Helper Modifiers

// MARK: - Adaptive Dashboard

/// 需求: 11.3, 11.5, 17.3, 18.10 - 自适应布局、本地化支持和状态持久化
@available(macOS 10.15, iOS 13.0, *)
public struct AdaptiveRealtimeDashboard: View {
    
    // MARK: - Properties
    
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @ObservedObject private var connectionViewModel = ConnectionViewModel()
    @ObservedObject private var audioViewModel = AudioViewModel()
    @ObservedObject private var sessionViewModel = UserSessionViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var selectedTab: DashboardTab = .overview
    @State private var showingSidebar: Bool = true
    @State private var sidebarWidth: CGFloat = 300
    
    /// Dashboard state with automatic persistence
    /// 需求: 18.10 - 状态持久化
    @RealtimeStorage("adaptiveDashboardState", namespace: "RealtimeKit.UI.Adaptive")
    private var dashboardState: AdaptiveDashboardState = AdaptiveDashboardState()
    
    // MARK: - Body
    
    public var body: some View {
        VStack {
            Text("Adaptive Realtime Dashboard")
                .font(.title)
                .padding()
            
            Text("Dashboard content will be implemented here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            
            Spacer()
        }
    }
}

// MARK: - Dashboard Tab Enum

/// 仪表板标签枚举
public enum DashboardTab: String, CaseIterable, Codable, Sendable {
    case overview = "overview"
    case audio = "audio"
    case connection = "connection"
    case session = "session"
    
    public var displayName: String {
        switch self {
        case .overview:
            return "Overview"
        case .audio:
            return "Audio"
        case .connection:
            return "Connection"
        case .session:
            return "Session"
        }
    }
    
    public var iconName: String {
        switch self {
        case .overview:
            return "chart.bar"
        case .audio:
            return "speaker.wave.2"
        case .connection:
            return "network"
        case .session:
            return "person.circle"
        }
    }
}

// MARK: - Dashboard State

/// Adaptive Dashboard 持久化状态
/// 需求: 18.10 - 状态持久化
public struct AdaptiveDashboardState: Codable, Sendable {
    /// 视图出现次数
    public var viewAppearanceCount: Int = 0
    
    /// 侧边栏是否显示
    public var showingSidebar: Bool = true
    
    /// 侧边栏宽度
    public var sidebarWidth: CGFloat = 300
    
    /// 选中的标签
    public var selectedTab: DashboardTab = .overview
    
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