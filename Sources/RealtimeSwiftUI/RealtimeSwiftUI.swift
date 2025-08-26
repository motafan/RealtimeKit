import Foundation
import SwiftUI
import RealtimeCore
import Combine

/// RealtimeSwiftUI 模块
/// 提供 SwiftUI 框架的集成支持和高级 UI 组件
/// 需求: 11.2, 11.3, 15.6, 17.3, 17.6, 18.10

#if canImport(SwiftUI)

// MARK: - SwiftUI 基础组件

/// RealtimeKit SwiftUI 集成的基础视图，支持响应式数据绑定和状态管理
/// 需求: 11.2, 11.3, 18.10 - SwiftUI 响应式支持和状态持久化
@available(macOS 13.0, iOS 16.0, *)
public struct RealtimeView<Content: View>: View {
    
    // MARK: - Properties
    
    @StateObject private var realtimeManager = RealtimeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var connectionState: ConnectionState = .disconnected
    @State private var volumeInfos: [UserVolumeInfo] = []
    @State private var speakingUsers: Set<String> = []
    @State private var dominantSpeaker: String? = nil
    
    /// View state with automatic persistence
    /// 需求: 18.10 - SwiftUI 数据绑定的兼容性
    @RealtimeStorage("realtimeViewState", namespace: "RealtimeKit.UI.SwiftUI")
    private var viewState: RealtimeViewState = RealtimeViewState()
    
    private let content: () -> Content
    
    // MARK: - Initialization
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    // MARK: - Body
    
    public var body: some View {
        content()
            .environmentObject(realtimeManager)
            .environmentObject(localizationManager)
            .environment(\.realtimeConnectionState, connectionState)
            .environment(\.realtimeVolumeInfos, volumeInfos)
            .environment(\.realtimeSpeakingUsers, speakingUsers)
            .environment(\.realtimeDominantSpeaker, dominantSpeaker)
            .onReceive(realtimeManager.$connectionState) { state in
                connectionState = state
                viewState.lastConnectionState = state
                viewState.connectionStateChangeCount += 1
            }
            .onReceive(realtimeManager.$volumeInfos) { infos in
                volumeInfos = infos
                viewState.lastVolumeUpdateCount = infos.count
                viewState.lastVolumeUpdateTime = Date()
            }
            .onReceive(realtimeManager.$speakingUsers) { users in
                speakingUsers = users
                viewState.maxSpeakingUsers = max(viewState.maxSpeakingUsers, users.count)
            }
            .onReceive(realtimeManager.$dominantSpeaker) { speaker in
                dominantSpeaker = speaker
                if speaker != nil {
                    viewState.dominantSpeakerChangeCount += 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
                viewState.currentLanguage = localizationManager.currentLanguage
                viewState.languageChangeCount += 1
            }
            .onAppear {
                viewState.viewAppearanceCount += 1
                viewState.lastAppearanceTime = Date()
            }
    }
}

/// Persistent state for RealtimeView
/// 需求: 18.1, 18.10 - 状态持久化和 SwiftUI 集成
public struct RealtimeViewState: Codable, Sendable {
    /// Number of times view has appeared
    public var viewAppearanceCount: Int = 0
    
    /// Last appearance time
    public var lastAppearanceTime: Date?
    
    /// Last connection state
    public var lastConnectionState: ConnectionState = .disconnected
    
    /// Number of connection state changes
    public var connectionStateChangeCount: Int = 0
    
    /// Last volume update count
    public var lastVolumeUpdateCount: Int = 0
    
    /// Last volume update time
    public var lastVolumeUpdateTime: Date?
    
    /// Maximum number of speaking users observed
    public var maxSpeakingUsers: Int = 0
    
    /// Number of dominant speaker changes
    public var dominantSpeakerChangeCount: Int = 0
    
    /// Current language
    public var currentLanguage: SupportedLanguage = .english
    
    /// Number of language changes
    public var languageChangeCount: Int = 0
    
    public init() {}
}

/// 高级音量波形可视化 SwiftUI 视图，支持动画效果
/// 需求: 11.2 - 音量波形可视化和动画效果
@available(macOS 13.0, iOS 16.0, *)
public struct VolumeVisualizationView: View {
    
    // MARK: - Properties
    
    let volumeLevel: Float
    let isSpeaking: Bool
    
    var volumeColor: Color = .blue
    var speakingColor: Color = .green
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var style: VolumeVisualizationStyle = .bar
    
    @State private var animationPhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    // MARK: - Initialization
    
    public init(
        volumeLevel: Float, 
        isSpeaking: Bool,
        style: VolumeVisualizationStyle = .bar
    ) {
        self.volumeLevel = volumeLevel
        self.isSpeaking = isSpeaking
        self.style = style
    }
    
    // MARK: - Body
    
    public var body: some View {
        Group {
            switch style {
            case .bar:
                barVisualization
            case .waveform:
                waveformVisualization
            case .circular:
                circularVisualization
            case .ripple:
                rippleVisualization
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: isSpeaking) { speaking in
            if speaking {
                startSpeakingAnimation()
            } else {
                stopSpeakingAnimation()
            }
        }
    }
    
    // MARK: - Bar Visualization
    
    private var barVisualization: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景条
                Rectangle()
                    .fill(backgroundColor)
                    .frame(height: 8)
                    .cornerRadius(4)
                
                // 音量条
                Rectangle()
                    .fill(isSpeaking ? speakingColor : volumeColor)
                    .frame(width: geometry.size.width * CGFloat(volumeLevel), height: 8)
                    .cornerRadius(4)
                    .animation(.easeInOut(duration: 0.2), value: volumeLevel)
                    .animation(.easeInOut(duration: 0.2), value: isSpeaking)
                
                // 脉冲效果
                if isSpeaking {
                    Rectangle()
                        .fill(speakingColor.opacity(0.3))
                        .frame(width: geometry.size.width * CGFloat(volumeLevel), height: 8)
                        .cornerRadius(4)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseScale)
                }
            }
        }
        .frame(height: 8)
        .scaleEffect(isSpeaking ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSpeaking)
    }
    
    // MARK: - Waveform Visualization
    
    private var waveformVisualization: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                let barHeight = calculateBarHeight(for: index)
                Rectangle()
                    .fill(isSpeaking ? speakingColor : volumeColor)
                    .frame(width: 3, height: barHeight)
                    .cornerRadius(1.5)
                    .animation(
                        .easeInOut(duration: 0.3)
                        .delay(Double(index) * 0.02),
                        value: volumeLevel
                    )
            }
        }
        .frame(height: 40)
    }
    
    // MARK: - Circular Visualization
    
    private var circularVisualization: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(backgroundColor, lineWidth: 4)
                .frame(width: 40, height: 40)
            
            // 音量圆环
            Circle()
                .trim(from: 0, to: CGFloat(volumeLevel))
                .stroke(
                    isSpeaking ? speakingColor : volumeColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: volumeLevel)
            
            // 中心指示器
            Circle()
                .fill(isSpeaking ? speakingColor : volumeColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isSpeaking ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSpeaking)
        }
    }
    
    // MARK: - Ripple Visualization
    
    private var rippleVisualization: some View {
        ZStack {
            // 多层波纹效果
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        (isSpeaking ? speakingColor : volumeColor)
                            .opacity(0.6 - Double(index) * 0.2),
                        lineWidth: 2
                    )
                    .frame(width: 20 + CGFloat(index * 10), height: 20 + CGFloat(index * 10))
                    .scaleEffect(1.0 + CGFloat(volumeLevel) * (1.0 + CGFloat(index) * 0.3))
                    .animation(
                        .easeInOut(duration: 0.8 + Double(index) * 0.2)
                        .repeatForever(autoreverses: true),
                        value: isSpeaking
                    )
            }
            
            // 中心圆
            Circle()
                .fill(isSpeaking ? speakingColor : volumeColor)
                .frame(width: 12, height: 12)
                .scaleEffect(1.0 + CGFloat(volumeLevel) * 0.5)
                .animation(.easeInOut(duration: 0.2), value: volumeLevel)
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 40
        
        // 创建波形效果
        let waveOffset = sin(animationPhase + Double(index) * 0.3) * 0.3
        let volumeEffect = Double(volumeLevel) * (1.0 + waveOffset)
        
        return baseHeight + CGFloat(volumeEffect) * (maxHeight - baseHeight)
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            animationPhase = .pi * 2
        }
    }
    
    private func startSpeakingAnimation() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
    
    private func stopSpeakingAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            pulseScale = 1.0
        }
    }
}

/// 音量可视化样式枚举
public enum VolumeVisualizationStyle: String, CaseIterable, Codable, Sendable {
    case bar = "bar"
    case waveform = "waveform"
    case circular = "circular"
    case ripple = "ripple"
    
    public var displayName: String {
        switch self {
        case .bar: return "Bar"
        case .waveform: return "Waveform"
        case .circular: return "Circular"
        case .ripple: return "Ripple"
        }
    }
}

/// 用户音量指示器视图，支持本地化和自定义样式
/// 需求: 17.3, 17.6 - 本地化 SwiftUI 组件和语言变化通知
@available(macOS 13.0, iOS 16.0, *)
public struct UserVolumeIndicatorView: View {
    
    // MARK: - Properties
    
    let userVolumeInfo: UserVolumeInfo
    let visualizationStyle: VolumeVisualizationStyle
    let showPercentage: Bool
    
    @StateObject private var localizationManager = LocalizationManager.shared
    
    /// User volume indicator state with automatic persistence
    /// 需求: 18.10 - SwiftUI 数据绑定的兼容性
    @RealtimeStorage("userVolumeIndicatorState", namespace: "RealtimeKit.UI.SwiftUI")
    private var indicatorState: UserVolumeIndicatorState = UserVolumeIndicatorState()
    
    // MARK: - Initialization
    
    public init(
        userVolumeInfo: UserVolumeInfo,
        visualizationStyle: VolumeVisualizationStyle = .bar,
        showPercentage: Bool = true
    ) {
        self.userVolumeInfo = userVolumeInfo
        self.visualizationStyle = visualizationStyle
        self.showPercentage = showPercentage
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack {
            // 用户标识
            HStack(spacing: 4) {
                if userVolumeInfo.isSpeaking {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                        .scaleEffect(1.1)
                        .animation(.easeInOut(duration: 0.2), value: userVolumeInfo.isSpeaking)
                }
                
                LocalizedText(
                    "user.volume.indicator.label",
                    arguments: userVolumeInfo.userId,
                    fallbackValue: "User \(userVolumeInfo.userId)"
                )
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
            }
            
            Spacer()
            
            // 音量可视化
            VolumeVisualizationView(
                volumeLevel: Float(userVolumeInfo.volume),
                isSpeaking: userVolumeInfo.isSpeaking,
                style: visualizationStyle
            )
            .frame(width: visualizationStyle == .waveform ? 80 : 60)
            
            // 音量百分比
            if showPercentage {
                Text("\(Int(userVolumeInfo.volume * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(userVolumeInfo.isSpeaking ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            userVolumeInfo.isSpeaking ? Color.green.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(userVolumeInfo.isSpeaking ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: userVolumeInfo.isSpeaking)
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            indicatorState.currentLanguage = localizationManager.currentLanguage
        }
        .onAppear {
            indicatorState.displayCount += 1
            indicatorState.lastDisplayTime = Date()
            
            if userVolumeInfo.isSpeaking {
                indicatorState.speakingDisplayCount += 1
            }
        }
    }
}

/// Persistent state for UserVolumeIndicatorView
/// 需求: 18.1, 18.10 - 状态持久化和 SwiftUI 集成
public struct UserVolumeIndicatorState: Codable, Sendable {
    /// Number of times indicator was displayed
    public var displayCount: Int = 0
    
    /// Number of times displayed while speaking
    public var speakingDisplayCount: Int = 0
    
    /// Last display time
    public var lastDisplayTime: Date?
    
    /// Current language
    public var currentLanguage: SupportedLanguage = .english
    
    /// Preferred visualization style
    public var preferredVisualizationStyle: VolumeVisualizationStyle = .bar
    
    /// Whether to show percentage
    public var showPercentage: Bool = true
    
    public init() {}
}

/// 连接状态指示器视图，支持本地化和动画效果
/// 需求: 17.3, 17.6 - 本地化 SwiftUI 组件和语言变化通知
@available(macOS 13.0, iOS 16.0, *)
public struct ConnectionStateIndicatorView: View {
    
    // MARK: - Properties
    
    let connectionState: ConnectionState
    let showText: Bool
    let style: ConnectionIndicatorStyle
    
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var pulseAnimation: Bool = false
    
    /// Connection state indicator state with automatic persistence
    /// 需求: 18.10 - SwiftUI 数据绑定的兼容性
    @RealtimeStorage("connectionStateIndicatorState", namespace: "RealtimeKit.UI.SwiftUI")
    private var indicatorState: ConnectionStateIndicatorState = ConnectionStateIndicatorState()
    
    // MARK: - Initialization
    
    public init(
        connectionState: ConnectionState,
        showText: Bool = true,
        style: ConnectionIndicatorStyle = .capsule
    ) {
        self.connectionState = connectionState
        self.showText = showText
        self.style = style
    }
    
    // MARK: - Body
    
    public var body: some View {
        Group {
            switch style {
            case .capsule:
                capsuleIndicator
            case .badge:
                badgeIndicator
            case .minimal:
                minimalIndicator
            }
        }
        .onAppear {
            indicatorState.displayCount += 1
            indicatorState.lastDisplayTime = Date()
            startAnimationIfNeeded()
        }
        .onChange(of: connectionState) { newState in
            indicatorState.stateChangeCount += 1
            indicatorState.lastState = newState
            startAnimationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            indicatorState.currentLanguage = localizationManager.currentLanguage
        }
    }
    
    // MARK: - Style Variants
    
    private var capsuleIndicator: some View {
        HStack(spacing: 8) {
            statusIndicator
            
            if showText {
                LocalizedText(
                    connectionState.localizationKey,
                    fallbackValue: connectionState.displayName
                )
                .font(.caption)
                .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(connectionState.indicatorColor.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(connectionState.indicatorColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var badgeIndicator: some View {
        HStack(spacing: 6) {
            statusIndicator
            
            if showText {
                LocalizedText(
                    connectionState.localizationKey,
                    fallbackValue: connectionState.displayName
                )
                .font(.caption2)
                .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(connectionState.indicatorColor)
        )
    }
    
    private var minimalIndicator: some View {
        statusIndicator
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(connectionState.indicatorColor)
            .frame(width: 8, height: 8)
            .scaleEffect(pulseAnimation ? 1.3 : 1.0)
            .opacity(pulseAnimation ? 0.7 : 1.0)
            .animation(
                connectionState.shouldAnimate ? 
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                    .easeInOut(duration: 0.2),
                value: pulseAnimation
            )
    }
    
    // MARK: - Helper Methods
    
    private func startAnimationIfNeeded() {
        pulseAnimation = connectionState.shouldAnimate
    }
}

/// 连接指示器样式枚举
public enum ConnectionIndicatorStyle: String, CaseIterable, Codable, Sendable {
    case capsule = "capsule"
    case badge = "badge"
    case minimal = "minimal"
    
    public var displayName: String {
        switch self {
        case .capsule: return "Capsule"
        case .badge: return "Badge"
        case .minimal: return "Minimal"
        }
    }
}

/// Persistent state for ConnectionStateIndicatorView
/// 需求: 18.1, 18.10 - 状态持久化和 SwiftUI 集成
public struct ConnectionStateIndicatorState: Codable, Sendable {
    /// Number of times indicator was displayed
    public var displayCount: Int = 0
    
    /// Number of state changes observed
    public var stateChangeCount: Int = 0
    
    /// Last display time
    public var lastDisplayTime: Date?
    
    /// Last connection state
    public var lastState: ConnectionState = .disconnected
    
    /// Current language
    public var currentLanguage: SupportedLanguage = .english
    
    /// Preferred indicator style
    public var preferredStyle: ConnectionIndicatorStyle = .capsule
    
    public init() {}
}

/// 音频控制面板视图，支持本地化和状态持久化
/// 需求: 17.3, 17.6, 18.10 - 本地化 SwiftUI 组件、语言变化通知和状态持久化
@available(macOS 13.0, iOS 16.0, *)
public struct AudioControlPanelView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var audioSettings: AudioSettings = .default
    @State private var isExpanded: Bool = true
    @State private var showAdvancedControls: Bool = false
    
    /// Audio control panel state with automatic persistence
    /// 需求: 18.10 - SwiftUI 数据绑定的兼容性
    @RealtimeStorage("audioControlPanelState", namespace: "RealtimeKit.UI.SwiftUI")
    private var panelState: AudioControlPanelState = AudioControlPanelState()
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // 面板标题和展开控制
            HStack {
                LocalizedText(
                    "audio.control.panel.title",
                    fallbackValue: "Audio Controls"
                )
                .font(.headline)
                .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                        panelState.isExpanded = isExpanded
                        panelState.toggleCount += 1
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if isExpanded {
                VStack(spacing: 16) {
                    // 麦克风控制
                    microphoneControl
                    
                    Divider()
                    
                    // 基础音量控制
                    basicVolumeControls
                    
                    // 高级控制切换
                    advancedControlsToggle
                    
                    if showAdvancedControls {
                        Divider()
                        advancedVolumeControls
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .onReceive(realtimeManager.$audioSettings) { settings in
            audioSettings = settings
            panelState.lastAudioSettingsUpdate = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            panelState.currentLanguage = localizationManager.currentLanguage
        }
        .onAppear {
            isExpanded = panelState.isExpanded
            showAdvancedControls = panelState.showAdvancedControls
            panelState.viewAppearanceCount += 1
        }
    }
    
    // MARK: - Microphone Control
    
    @available(macOS 13.0, iOS 16.0, *)
    private var microphoneControl: some View {
        HStack(spacing: 12) {
            // 麦克风图标
            ZStack {
                Circle()
                    .fill(audioSettings.microphoneMuted ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: audioSettings.microphoneMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(audioSettings.microphoneMuted ? .red : .blue)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                LocalizedText(
                    "audio.control.microphone.title",
                    fallbackValue: "Microphone"
                )
                .font(.subheadline)
                
                LocalizedText(
                    audioSettings.microphoneMuted ? 
                        "audio.control.microphone.muted" : 
                        "audio.control.microphone.active",
                    fallbackValue: audioSettings.microphoneMuted ? "Muted" : "Active"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { !audioSettings.microphoneMuted },
                set: { newValue in
                    Task {
                        try? await realtimeManager.muteMicrophone(!newValue)
                        panelState.microphoneToggleCount += 1
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
    
    // MARK: - Basic Volume Controls
    
    private var basicVolumeControls: some View {
        VStack(spacing: 16) {
            // 混音音量
            volumeSlider(
                titleKey: "audio.control.mixing.volume",
                titleFallback: "Mixing Volume",
                value: audioSettings.audioMixingVolume,
                icon: "speaker.wave.2.fill"
            ) { newValue in
                Task { @MainActor in
                    try? await realtimeManager.setAudioMixingVolume(Int(newValue))
                    panelState.mixingVolumeAdjustmentCount += 1
                }
            }
            
            // 播放音量
            volumeSlider(
                titleKey: "audio.control.playback.volume",
                titleFallback: "Playback Volume",
                value: audioSettings.playbackSignalVolume,
                icon: "speaker.fill"
            ) { newValue in
                Task { @MainActor in
                    try? await realtimeManager.setPlaybackSignalVolume(Int(newValue))
                    panelState.playbackVolumeAdjustmentCount += 1
                }
            }
        }
    }
    
    // MARK: - Advanced Controls Toggle
    
    private var advancedControlsToggle: some View {
        LocalizedButton(
            showAdvancedControls ? 
                "audio.control.advanced.hide" : 
                "audio.control.advanced.show",
            fallbackValue: showAdvancedControls ? "Hide Advanced" : "Show Advanced"
        ) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showAdvancedControls.toggle()
                panelState.showAdvancedControls = showAdvancedControls
                panelState.advancedToggleCount += 1
            }
        }
        .font(.caption)
        .foregroundColor(.blue)
    }
    
    // MARK: - Advanced Volume Controls
    
    private var advancedVolumeControls: some View {
        VStack(spacing: 16) {
            // 录制音量
            volumeSlider(
                titleKey: "audio.control.recording.volume",
                titleFallback: "Recording Volume",
                value: audioSettings.recordingSignalVolume,
                icon: "mic.fill"
            ) { newValue in
                Task { @MainActor in
                    try? await realtimeManager.setRecordingSignalVolume(Int(newValue))
                    panelState.recordingVolumeAdjustmentCount += 1
                }
            }
            
            // 音频流控制
            HStack {
                LocalizedText(
                    "audio.control.stream.title",
                    fallbackValue: "Audio Stream"
                )
                .font(.subheadline)
                
                Spacer()
                
                LocalizedButton(
                    audioSettings.localAudioStreamActive ? 
                        "audio.control.stream.stop" : 
                        "audio.control.stream.resume",
                    fallbackValue: audioSettings.localAudioStreamActive ? "Stop" : "Resume"
                ) {
                    Task {
                        if audioSettings.localAudioStreamActive {
                            try? await realtimeManager.stopLocalAudioStream()
                        } else {
                            try? await realtimeManager.resumeLocalAudioStream()
                        }
                        panelState.streamToggleCount += 1
                    }
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(audioSettings.localAudioStreamActive ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                )
                .foregroundColor(audioSettings.localAudioStreamActive ? .red : .green)
            }
        }
    }
    
    // MARK: - Volume Slider Helper
    
    private func volumeSlider(
        titleKey: String,
        titleFallback: String,
        value: Int,
        icon: String,
        onChanged: @Sendable @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                LocalizedText(titleKey, fallbackValue: titleFallback)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(value)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: onChanged
                ),
                in: 0...100,
                step: 1
            )
            .accentColor(.blue)
        }
    }
}

/// Persistent state for AudioControlPanelView
/// 需求: 18.1, 18.10 - 状态持久化和 SwiftUI 集成
public struct AudioControlPanelState: Codable, Sendable {
    /// Whether panel is expanded
    public var isExpanded: Bool = true
    
    /// Whether advanced controls are shown
    public var showAdvancedControls: Bool = false
    
    /// Number of times panel was toggled
    public var toggleCount: Int = 0
    
    /// Number of times advanced controls were toggled
    public var advancedToggleCount: Int = 0
    
    /// Number of microphone toggles
    public var microphoneToggleCount: Int = 0
    
    /// Number of mixing volume adjustments
    public var mixingVolumeAdjustmentCount: Int = 0
    
    /// Number of playback volume adjustments
    public var playbackVolumeAdjustmentCount: Int = 0
    
    /// Number of recording volume adjustments
    public var recordingVolumeAdjustmentCount: Int = 0
    
    /// Number of stream toggles
    public var streamToggleCount: Int = 0
    
    /// Number of view appearances
    public var viewAppearanceCount: Int = 0
    
    /// Last audio settings update time
    public var lastAudioSettingsUpdate: Date?
    
    /// Current language
    public var currentLanguage: SupportedLanguage = .english
    
    public init() {}
}

// MARK: - Advanced SwiftUI Components

/// 多用户音量列表视图，支持实时更新和动画效果
/// 需求: 11.2, 17.3, 18.10 - 音量波形可视化、本地化组件和状态持久化
@available(macOS 13.0, iOS 16.0, *)
public struct MultiUserVolumeListView: View {
    
    // MARK: - Properties
    
    @Environment(\.realtimeVolumeInfos) private var volumeInfos
    @Environment(\.realtimeSpeakingUsers) private var speakingUsers
    @Environment(\.realtimeDominantSpeaker) private var dominantSpeaker
    
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var visualizationStyle: VolumeVisualizationStyle = .bar
    @State private var showPercentages: Bool = true
    @State private var sortBySpeaking: Bool = true
    
    /// Multi-user volume list state with automatic persistence
    /// 需求: 18.10 - SwiftUI 数据绑定的兼容性
    @RealtimeStorage("multiUserVolumeListState", namespace: "RealtimeKit.UI.SwiftUI")
    private var listState: MultiUserVolumeListState = MultiUserVolumeListState()
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // 列表标题和控制
            listHeader
            
            Divider()
            
            // 音量列表
            if volumeInfos.isEmpty {
                emptyState
            } else {
                volumeList
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            listState.currentLanguage = localizationManager.currentLanguage
        }
        .onAppear {
            visualizationStyle = listState.preferredVisualizationStyle
            showPercentages = listState.showPercentages
            sortBySpeaking = listState.sortBySpeaking
            listState.viewAppearanceCount += 1
        }
    }
    
    // MARK: - List Header
    
    private var listHeader: some View {
        HStack {
            LocalizedText(
                "volume.list.title",
                fallbackValue: "Volume Indicators"
            )
            .font(.headline)
            .foregroundColor(.primary)
            
            Spacer()
            
            // 样式选择器
            Menu {
                ForEach(VolumeVisualizationStyle.allCases, id: \.self) { style in
                    Button(action: {
                        visualizationStyle = style
                        listState.preferredVisualizationStyle = style
                        listState.styleChangeCount += 1
                    }) {
                        HStack {
                            Text(style.displayName)
                            if visualizationStyle == style {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(action: {
                    showPercentages.toggle()
                    listState.showPercentages = showPercentages
                    listState.settingsChangeCount += 1
                }) {
                    HStack {
                        LocalizedText(
                            "volume.list.show.percentages",
                            fallbackValue: "Show Percentages"
                        )
                        if showPercentages {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    sortBySpeaking.toggle()
                    listState.sortBySpeaking = sortBySpeaking
                    listState.settingsChangeCount += 1
                }) {
                    HStack {
                        LocalizedText(
                            "volume.list.sort.by.speaking",
                            fallbackValue: "Sort by Speaking"
                        )
                        if sortBySpeaking {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            LocalizedText(
                "volume.list.empty.title",
                fallbackValue: "No Volume Data"
            )
            .font(.headline)
            .foregroundColor(.secondary)
            
            LocalizedText(
                "volume.list.empty.message",
                fallbackValue: "Volume indicators will appear here when users start speaking"
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .onAppear {
            listState.emptyStateDisplayCount += 1
        }
    }
    
    // MARK: - Volume List
    
    @available(macOS 13.0, iOS 16.0, *)
    private var volumeList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sortedVolumeInfos, id: \.userId) { volumeInfo in
                    UserVolumeIndicatorView(
                        userVolumeInfo: volumeInfo,
                        visualizationStyle: visualizationStyle,
                        showPercentage: showPercentages
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                volumeInfo.userId == dominantSpeaker ? 
                                    Color.blue.opacity(0.05) : 
                                    Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        volumeInfo.userId == dominantSpeaker ? 
                                            Color.blue.opacity(0.2) : 
                                            Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .scaleEffect(volumeInfo.userId == dominantSpeaker ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: dominantSpeaker)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onAppear {
            listState.dataDisplayCount += 1
            listState.lastItemCount = volumeInfos.count
        }
    }
    
    // MARK: - Computed Properties
    
    private var sortedVolumeInfos: [UserVolumeInfo] {
        if sortBySpeaking {
            return volumeInfos.sorted { first, second in
                if first.isSpeaking && !second.isSpeaking {
                    return true
                } else if !first.isSpeaking && second.isSpeaking {
                    return false
                } else if first.isSpeaking && second.isSpeaking {
                    return first.volume > second.volume
                } else {
                    return first.userId < second.userId
                }
            }
        } else {
            return volumeInfos.sorted { $0.userId < $1.userId }
        }
    }
}

/// Persistent state for MultiUserVolumeListView
/// 需求: 18.1, 18.10 - 状态持久化和 SwiftUI 集成
public struct MultiUserVolumeListState: Codable, Sendable {
    /// Current language
    public var currentLanguage: SupportedLanguage = .english
    
    /// Preferred visualization style
    public var preferredVisualizationStyle: VolumeVisualizationStyle = .bar
    
    /// Whether to show percentages
    public var showPercentages: Bool = true
    
    /// Whether to sort by speaking status
    public var sortBySpeaking: Bool = true
    
    /// Number of view appearances
    public var viewAppearanceCount: Int = 0
    
    /// Number of empty state displays
    public var emptyStateDisplayCount: Int = 0
    
    /// Number of data displays
    public var dataDisplayCount: Int = 0
    
    /// Last item count
    public var lastItemCount: Int = 0
    
    /// Number of style changes
    public var styleChangeCount: Int = 0
    
    /// Number of settings changes
    public var settingsChangeCount: Int = 0
    
    public init() {}
}

/// 实时状态仪表板视图，显示连接状态、音量信息等
/// 需求: 11.2, 11.3, 17.3, 18.10 - SwiftUI 响应式支持、本地化组件和状态持久化
@available(macOS 13.0, iOS 16.0, *)
public struct RealtimeStatusDashboardView: View {
    
    // MARK: - Properties
    
    @Environment(\.realtimeConnectionState) private var connectionState
    @Environment(\.realtimeVolumeInfos) private var volumeInfos
    @Environment(\.realtimeSpeakingUsers) private var speakingUsers
    @Environment(\.realtimeDominantSpeaker) private var dominantSpeaker
    
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @State private var isCompactMode: Bool = false
    @State private var showDetailedStats: Bool = false
    
    /// Dashboard state with automatic persistence
    /// 需求: 18.10 - SwiftUI 数据绑定的兼容性
    @RealtimeStorage("realtimeStatusDashboardState", namespace: "RealtimeKit.UI.SwiftUI")
    private var dashboardState: RealtimeStatusDashboardState = RealtimeStatusDashboardState()
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 16) {
            // 仪表板标题
            dashboardHeader
            
            if isCompactMode {
                compactDashboard
            } else {
                fullDashboard
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            dashboardState.currentLanguage = localizationManager.currentLanguage
        }
        .onAppear {
            isCompactMode = dashboardState.isCompactMode
            showDetailedStats = dashboardState.showDetailedStats
            dashboardState.viewAppearanceCount += 1
        }
    }
    
    // MARK: - Dashboard Header
    
    private var dashboardHeader: some View {
        HStack {
            LocalizedText(
                "dashboard.title",
                fallbackValue: "Realtime Status"
            )
            .font(.title2)
            .foregroundColor(.primary)
            
            Spacer()
            
            // 模式切换按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCompactMode.toggle()
                    dashboardState.isCompactMode = isCompactMode
                    dashboardState.modeToggleCount += 1
                }
            }) {
                Image(systemName: isCompactMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
    }
    
    // MARK: - Compact Dashboard
    
    @available(macOS 13.0, iOS 16.0, *)
    private var compactDashboard: some View {
        HStack(spacing: 16) {
            // 连接状态
            ConnectionStateIndicatorView(
                connectionState: connectionState,
                showText: false,
                style: .minimal
            )
            
            // 说话用户数量
            HStack(spacing: 4) {
                Image(systemName: "person.wave.2")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("\(speakingUsers.count)")
                    .font(.caption)
            }
            
            // 总用户数量
            HStack(spacing: 4) {
                Image(systemName: "person.3")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("\(volumeInfos.count)")
                    .font(.caption)
            }
            
            Spacer()
            
            // 主讲人指示器
            if let dominantSpeaker = dominantSpeaker {
                HStack(spacing: 4) {
                    Image(systemName: "crown")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    
                    Text(dominantSpeaker)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Full Dashboard
    
    @available(macOS 13.0, iOS 16.0, *)
    private var fullDashboard: some View {
        VStack(spacing: 16) {
            // 连接状态行
            connectionStatusRow
            
            Divider()
            
            // 音量统计行
            volumeStatsRow
            
            if showDetailedStats {
                Divider()
                detailedStatsSection
            }
            
            // 详细统计切换
            detailedStatsToggle
        }
    }
    
    // MARK: - Connection Status Row
    
    @available(macOS 13.0, iOS 16.0, *)
    private var connectionStatusRow: some View {
        HStack {
            LocalizedText(
                "dashboard.connection.status",
                fallbackValue: "Connection"
            )
            .font(.subheadline)
            
            Spacer()
            
            ConnectionStateIndicatorView(
                connectionState: connectionState,
                showText: true,
                style: .capsule
            )
        }
    }
    
    // MARK: - Volume Stats Row
    
    private var volumeStatsRow: some View {
        HStack(spacing: 24) {
            // 总用户数
            statItem(
                titleKey: "dashboard.total.users",
                titleFallback: "Total Users",
                value: "\(volumeInfos.count)",
                icon: "person.3",
                color: .blue
            )
            
            // 说话用户数
            statItem(
                titleKey: "dashboard.speaking.users",
                titleFallback: "Speaking",
                value: "\(speakingUsers.count)",
                icon: "person.wave.2",
                color: .green
            )
            
            // 主讲人
            VStack(alignment: .center, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "crown")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    LocalizedText(
                        "dashboard.dominant.speaker",
                        fallbackValue: "Speaker"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Text(dominantSpeaker ?? "-")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Detailed Stats Section
    
    private var detailedStatsSection: some View {
        VStack(spacing: 12) {
            LocalizedText(
                "dashboard.detailed.stats.title",
                fallbackValue: "Detailed Statistics"
            )
            .font(.subheadline)
            .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // 平均音量
                statCard(
                    titleKey: "dashboard.average.volume",
                    titleFallback: "Avg Volume",
                    value: String(format: "%.1f%%", averageVolume * 100),
                    icon: "speaker.wave.2",
                    color: .purple
                )
                
                // 最大音量
                statCard(
                    titleKey: "dashboard.max.volume",
                    titleFallback: "Max Volume",
                    value: String(format: "%.1f%%", maxVolume * 100),
                    icon: "speaker.wave.3",
                    color: .red
                )
                
                // 活跃时间
                statCard(
                    titleKey: "dashboard.active.time",
                    titleFallback: "Active Time",
                    value: formatActiveTime(),
                    icon: "clock",
                    color: .blue
                )
                
                // 语言设置
                statCard(
                    titleKey: "dashboard.current.language",
                    titleFallback: "Language",
                    value: localizationManager.currentLanguage.displayName,
                    icon: "globe",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Detailed Stats Toggle
    
    private var detailedStatsToggle: some View {
        LocalizedButton(
            showDetailedStats ? 
                "dashboard.hide.detailed.stats" : 
                "dashboard.show.detailed.stats",
            fallbackValue: showDetailedStats ? "Hide Details" : "Show Details"
        ) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showDetailedStats.toggle()
                dashboardState.showDetailedStats = showDetailedStats
                dashboardState.detailsToggleCount += 1
            }
        }
        .font(.caption)
        .foregroundColor(.blue)
    }
    
    // MARK: - Helper Views
    
    private func statItem(
        titleKey: String,
        titleFallback: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                LocalizedText(titleKey, fallbackValue: titleFallback)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    private func statCard(
        titleKey: String,
        titleFallback: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            LocalizedText(titleKey, fallbackValue: titleFallback)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Computed Properties
    
    private var averageVolume: Float {
        guard !volumeInfos.isEmpty else { return 0 }
        let totalVolume = volumeInfos.reduce(0) { $0 + $1.volume }
        return Float(totalVolume) / Float(volumeInfos.count)
    }
    
    private var maxVolume: Float {
        return Float(volumeInfos.map { $0.volume }.max() ?? 0)
    }
    
    private func formatActiveTime() -> String {
        let activeTime = dashboardState.totalActiveTime
        let hours = Int(activeTime) / 3600
        let minutes = (Int(activeTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Persistent state for RealtimeStatusDashboardView
/// 需求: 18.1, 18.10 - 状态持久化和 SwiftUI 集成
public struct RealtimeStatusDashboardState: Codable, Sendable {
    /// Current language
    public var currentLanguage: SupportedLanguage = .english
    
    /// Whether dashboard is in compact mode
    public var isCompactMode: Bool = false
    
    /// Whether to show detailed stats
    public var showDetailedStats: Bool = false
    
    /// Number of view appearances
    public var viewAppearanceCount: Int = 0
    
    /// Number of mode toggles
    public var modeToggleCount: Int = 0
    
    /// Number of details toggles
    public var detailsToggleCount: Int = 0
    
    /// Total active time in seconds
    public var totalActiveTime: TimeInterval = 0
    
    /// Last update time
    public var lastUpdateTime: Date?
    
    public init() {}
}

// MARK: - Environment Values (defined below as public)

// MARK: - Extensions

extension ConnectionState {
    var indicatorColor: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting, .reconnecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        case .suspended:
            return .yellow
        }
    }
}

// MARK: - Environment Keys

@available(macOS 11.0, iOS 14.0, *)
public struct RealtimeConnectionStateKey: EnvironmentKey {
    public static let defaultValue: ConnectionState = .disconnected
}

@available(macOS 11.0, iOS 14.0, *)
public struct RealtimeVolumeInfosKey: EnvironmentKey {
    public static let defaultValue: [UserVolumeInfo] = []
}

@available(macOS 11.0, iOS 14.0, *)
public struct RealtimeSpeakingUsersKey: EnvironmentKey {
    public static let defaultValue: Set<String> = []
}

@available(macOS 11.0, iOS 14.0, *)
public struct RealtimeDominantSpeakerKey: EnvironmentKey {
    public static let defaultValue: String? = nil
}

@available(macOS 11.0, iOS 14.0, *)
extension EnvironmentValues {
    public var realtimeConnectionState: ConnectionState {
        get { self[RealtimeConnectionStateKey.self] }
        set { self[RealtimeConnectionStateKey.self] = newValue }
    }
    
    public var realtimeVolumeInfos: [UserVolumeInfo] {
        get { self[RealtimeVolumeInfosKey.self] }
        set { self[RealtimeVolumeInfosKey.self] = newValue }
    }
    
    public var realtimeSpeakingUsers: Set<String> {
        get { self[RealtimeSpeakingUsersKey.self] }
        set { self[RealtimeSpeakingUsersKey.self] = newValue }
    }
    
    public var realtimeDominantSpeaker: String? {
        get { self[RealtimeDominantSpeakerKey.self] }
        set { self[RealtimeDominantSpeakerKey.self] = newValue }
    }
}

#endif
