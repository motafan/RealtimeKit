import Foundation
import SwiftUI
import RealtimeCore
import Combine

/// RealtimeSwiftUI 模块
/// 提供 SwiftUI 框架的集成支持
/// 需求: 11.2, 11.3, 15.6

#if canImport(SwiftUI)

// MARK: - SwiftUI 基础组件

/// RealtimeKit SwiftUI 集成的基础视图
@available(macOS 11.0, iOS 14.0, *)
public struct RealtimeView<Content: View>: View {
    
    // MARK: - Properties
    
    @StateObject private var realtimeManager = RealtimeManager.shared
    @State private var connectionState: ConnectionState = .disconnected
    @State private var volumeInfos: [UserVolumeInfo] = []
    
    private let content: () -> Content
    
    // MARK: - Initialization
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    // MARK: - Body
    
    public var body: some View {
        content()
            .environmentObject(realtimeManager)
            .environment(\.realtimeConnectionState, connectionState)
            .environment(\.realtimeVolumeInfos, volumeInfos)
            .onReceive(realtimeManager.$connectionState) { state in
                connectionState = state
            }
            .onReceive(realtimeManager.$volumeInfos) { infos in
                volumeInfos = infos
            }
    }
}

/// 音量可视化 SwiftUI 视图
@available(macOS 11.0, iOS 14.0, *)
public struct VolumeVisualizationView: View {
    
    // MARK: - Properties
    
    let volumeLevel: Float
    let isSpeaking: Bool
    
    var volumeColor: Color = .blue
    var speakingColor: Color = .green
    var backgroundColor: Color = Color.gray.opacity(0.2)
    
    // MARK: - Initialization
    
    public init(volumeLevel: Float, isSpeaking: Bool) {
        self.volumeLevel = volumeLevel
        self.isSpeaking = isSpeaking
    }
    
    // MARK: - Body
    
    public var body: some View {
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
            }
        }
        .frame(height: 8)
        .scaleEffect(isSpeaking ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSpeaking)
    }
}

/// 用户音量指示器视图
@available(macOS 11.0, iOS 14.0, *)
public struct UserVolumeIndicatorView: View {
    
    // MARK: - Properties
    
    let userVolumeInfo: UserVolumeInfo
    
    // MARK: - Body
    
    public var body: some View {
        HStack {
            Text("用户 \(userVolumeInfo.userId)")
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            VolumeVisualizationView(
                volumeLevel: Float(userVolumeInfo.volume) / 255.0,
                isSpeaking: userVolumeInfo.isSpeaking
            )
            .frame(width: 60)
            
            Text("\(userVolumeInfo.volumePercentage)%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(radius: 1)
        )
    }
}

/// 连接状态指示器视图
@available(macOS 11.0, iOS 14.0, *)
public struct ConnectionStateIndicatorView: View {
    
    // MARK: - Properties
    
    let connectionState: ConnectionState
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionState.indicatorColor)
                .frame(width: 8, height: 8)
                .scaleEffect(connectionState == .connecting || connectionState == .reconnecting ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                          value: connectionState == .connecting || connectionState == .reconnecting)
            
            Text(connectionState.displayName)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
        )
    }
}

/// 音频控制面板视图
@available(macOS 11.0, iOS 14.0, *)
public struct AudioControlPanelView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var audioSettings: AudioSettings = .default
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 16) {
            // 麦克风控制
            HStack {
                Image(systemName: audioSettings.microphoneMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(audioSettings.microphoneMuted ? .red : .blue)
                
                Text("麦克风")
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { !audioSettings.microphoneMuted },
                    set: { newValue in
                        Task {
                            try? await realtimeManager.muteMicrophone(!newValue)
                        }
                    }
                ))
            }
            
            // 音量控制
            VStack(alignment: .leading, spacing: 8) {
                Text("混音音量: \(audioSettings.audioMixingVolume)")
                    .font(.caption)
                
                Slider(
                    value: Binding(
                        get: { Double(audioSettings.audioMixingVolume) },
                        set: { newValue in
                            Task {
                                try? await realtimeManager.setAudioMixingVolume(Int(newValue))
                            }
                        }
                    ),
                    in: 0...100,
                    step: 1
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("播放音量: \(audioSettings.playbackSignalVolume)")
                    .font(.caption)
                
                Slider(
                    value: Binding(
                        get: { Double(audioSettings.playbackSignalVolume) },
                        set: { newValue in
                            Task {
                                try? await realtimeManager.setPlaybackSignalVolume(Int(newValue))
                            }
                        }
                    ),
                    in: 0...100,
                    step: 1
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .onReceive(realtimeManager.$audioSettings) { settings in
            audioSettings = settings
        }
    }
}

// MARK: - Environment Values

private struct RealtimeConnectionStateKey: EnvironmentKey {
    static let defaultValue: ConnectionState = .disconnected
}

private struct RealtimeVolumeInfosKey: EnvironmentKey {
    static let defaultValue: [UserVolumeInfo] = []
}

extension EnvironmentValues {
    var realtimeConnectionState: ConnectionState {
        get { self[RealtimeConnectionStateKey.self] }
        set { self[RealtimeConnectionStateKey.self] = newValue }
    }
    
    var realtimeVolumeInfos: [UserVolumeInfo] {
        get { self[RealtimeVolumeInfosKey.self] }
        set { self[RealtimeVolumeInfosKey.self] = newValue }
    }
}

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

#endif