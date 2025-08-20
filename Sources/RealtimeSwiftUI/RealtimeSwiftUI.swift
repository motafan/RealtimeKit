// RealtimeSwiftUI.swift
// SwiftUI integration module for RealtimeKit

import SwiftUI
import Combine
import RealtimeCore

/// RealtimeSwiftUI version information
public struct RealtimeSwiftUIVersion {
    public static let current = "1.0.0"
    public static let build = "1"
}

// MARK: - SwiftUI Environment and ViewModifiers

/// Environment key for RealtimeManager
@available(iOS 13.0, macOS 10.15, *)
public struct RealtimeManagerKey: EnvironmentKey {
    @MainActor
    public static var defaultValue: RealtimeManager {
        RealtimeManager.shared
    }
}

@available(iOS 13.0, macOS 10.15, *)
public extension EnvironmentValues {
    var realtimeManager: RealtimeManager {
        get { self[RealtimeManagerKey.self] }
        set { self[RealtimeManagerKey.self] = newValue }
    }
}

/// View modifier for RealtimeKit integration
@available(iOS 13.0, macOS 10.15, *)
public struct RealtimeKitModifier: ViewModifier {
    @ObservedObject private var manager = RealtimeManager.shared
    
    public func body(content: Content) -> some View {
        content
            .environment(\.realtimeManager, manager)
            .environmentObject(manager)
    }
}

@available(iOS 13.0, macOS 10.15, *)
public extension View {
    /// Add RealtimeKit support to a SwiftUI view
    func withRealtimeKit() -> some View {
        modifier(RealtimeKitModifier())
    }
}

// MARK: - Base SwiftUI Views

/// Enhanced base view for RealtimeKit SwiftUI integration with reactive state management
@available(iOS 13.0, macOS 10.15, *)
public struct RealtimeView<Content: View>: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var showConnectionAlert = false
    @State private var connectionAlertMessage = ""
    
    private let content: Content
    private let onConnectionStateChange: ((ConnectionState) -> Void)?
    private let onAudioSettingsChange: ((AudioSettings) -> Void)?
    
    public init(
        onConnectionStateChange: ((ConnectionState) -> Void)? = nil,
        onAudioSettingsChange: ((AudioSettings) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onConnectionStateChange = onConnectionStateChange
        self.onAudioSettingsChange = onAudioSettingsChange
    }
    
    public var body: some View {
        content
            .onReceive(realtimeManager.$connectionState) { state in
                handleConnectionStateChange(state)
            }
            .onReceive(realtimeManager.$audioSettings) { settings in
                handleAudioSettingsChange(settings)
            }
            .onReceive(realtimeManager.$currentSession) { session in
                handleSessionChange(session)
            }
            .alert(isPresented: $showConnectionAlert) {
                Alert(
                    title: Text("连接状态变化"),
                    message: Text(connectionAlertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
    }
    
    private func handleConnectionStateChange(_ state: ConnectionState) {
        onConnectionStateChange?(state)
        
        switch state {
        case .connecting:
            connectionAlertMessage = "正在连接..."
        case .connected:
            connectionAlertMessage = "连接成功"
        case .disconnected:
            connectionAlertMessage = "连接已断开"
        case .reconnecting:
            connectionAlertMessage = "正在重新连接..."
        case .failed:
            connectionAlertMessage = "连接失败"
            showConnectionAlert = true
        }
    }
    
    private func handleAudioSettingsChange(_ settings: AudioSettings) {
        onAudioSettingsChange?(settings)
    }
    
    private func handleSessionChange(_ session: UserSession?) {
        // Handle session changes for UI updates
        if session == nil {
            // User logged out, reset UI state
        }
    }
}

// MARK: - Volume Visualization Components

/// Volume waveform visualization view with animations
@available(iOS 13.0, macOS 10.15, *)
public struct VolumeWaveformView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var animationPhase: Double = 0
    @State private var volumeBars: [Float] = Array(repeating: 0.0, count: 20)
    
    private let barCount: Int
    private let barSpacing: CGFloat
    private let animationDuration: Double
    
    public init(
        barCount: Int = 20,
        barSpacing: CGFloat = 2,
        animationDuration: Double = 0.1
    ) {
        self.barCount = barCount
        self.barSpacing = barSpacing
        self.animationDuration = animationDuration
    }
    
    public var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                VolumeBar(
                    height: CGFloat(volumeBars[index]) * 50,
                    isActive: volumeBars[index] > 0.1
                )
                .animation(
                    .easeInOut(duration: animationDuration),
                    value: volumeBars[index]
                )
            }
        }
        .onReceive(realtimeManager.$volumeInfos) { volumeInfos in
            updateVolumeVisualization(volumeInfos)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func updateVolumeVisualization(_ volumeInfos: [UserVolumeInfo]) {
        guard let localUserVolume = volumeInfos.first?.volume else { return }
        
        // Generate waveform pattern based on volume
        let newBars = (0..<barCount).map { index in
            let normalizedIndex = Float(index) / Float(barCount - 1)
            let waveOffset = sin(Double(normalizedIndex) * .pi * 2 + animationPhase) * 0.3
            return max(0, localUserVolume + Float(waveOffset))
        }
        
        volumeBars = newBars
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            animationPhase += 0.2
            if animationPhase > .pi * 2 {
                animationPhase = 0
            }
        }
    }
}

/// Individual volume bar component
@available(iOS 13.0, macOS 10.15, *)
private struct VolumeBar: View {
    let height: CGFloat
    let isActive: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(isActive ? Color.green : Color.gray.opacity(0.3))
            .frame(width: 3, height: max(2, height))
            .scaleEffect(y: isActive ? 1.0 : 0.3, anchor: .bottom)
    }
}

/// Speaking indicator view with pulse animation
@available(iOS 13.0, macOS 10.15, *)
public struct SpeakingIndicatorView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var pulseScale: CGFloat = 1.0
    
    let userId: String
    let size: CGFloat
    
    public init(userId: String, size: CGFloat = 40) {
        self.userId = userId
        self.size = size
    }
    
    public var body: some View {
        Circle()
            .fill(isSpeaking ? Color.green : Color.clear)
            .frame(width: size, height: size)
            .scaleEffect(pulseScale)
            .opacity(isSpeaking ? 0.8 : 0.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isSpeaking)
            .onReceive(realtimeManager.$speakingUsers) { speakingUsers in
                if speakingUsers.contains(userId) && !isSpeaking {
                    startPulseAnimation()
                } else if !speakingUsers.contains(userId) && isSpeaking {
                    stopPulseAnimation()
                }
            }
    }
    
    private var isSpeaking: Bool {
        realtimeManager.speakingUsers.contains(userId)
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
    
    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0
        }
    }
}

/// Volume level indicator with real-time updates
@available(iOS 13.0, macOS 10.15, *)
public struct VolumeLevelView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var currentVolume: Float = 0.0
    
    let userId: String
    let showLabel: Bool
    
    public init(userId: String, showLabel: Bool = true) {
        self.userId = userId
        self.showLabel = showLabel
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            // Volume progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(volumeColor)
                        .frame(width: geometry.size.width * CGFloat(currentVolume), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            if showLabel {
                Text("\(Int(currentVolume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onReceive(realtimeManager.$volumeInfos) { volumeInfos in
            if let userVolume = volumeInfos.first(where: { $0.userId == userId }) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    currentVolume = userVolume.volume
                }
            }
        }
    }
    
    private var volumeColor: Color {
        switch currentVolume {
        case 0.0..<0.3:
            return .green
        case 0.3..<0.7:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Audio Control Components

/// Audio control panel with SwiftUI reactive bindings
@available(iOS 13.0, macOS 10.15, *)
public struct AudioControlPanel: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var showVolumeSliders = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            // Microphone control
            HStack {
                Button(action: toggleMicrophone) {
                    Image(systemName: realtimeManager.audioSettings.microphoneMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundColor(realtimeManager.audioSettings.microphoneMuted ? .red : .primary)
                }
                .buttonStyle(.bordered)
                
                Text(realtimeManager.audioSettings.microphoneMuted ? "麦克风已静音" : "麦克风开启")
                    .font(.body)
                
                Spacer()
            }
            
            // Volume controls toggle
            Button(action: { showVolumeSliders.toggle() }) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("音量控制")
                    Spacer()
                    Image(systemName: showVolumeSliders ? "chevron.up" : "chevron.down")
                }
            }
            .buttonStyle(.bordered)
            
            if showVolumeSliders {
                VolumeControlsView()
                    .transition(.slide)
            }
        }
        .padding()
        .background(Color.primary.colorInvert())
        .cornerRadius(12)
        .shadow(radius: 2)
        .animation(.easeInOut, value: showVolumeSliders)
    }
    
    private func toggleMicrophone() {
        Task {
            do {
                try await realtimeManager.muteMicrophone(!realtimeManager.audioSettings.microphoneMuted)
            } catch {
                print("Failed to toggle microphone: \(error)")
            }
        }
    }
}

/// Volume controls with sliders
@available(iOS 13.0, macOS 10.15, *)
public struct VolumeControlsView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            VolumeSlider(
                title: "混音音量",
                value: Binding(
                    get: { Double(realtimeManager.audioSettings.audioMixingVolume) },
                    set: { newValue in
                        Task {
                            try? await realtimeManager.setAudioMixingVolume(Int(newValue))
                        }
                    }
                )
            )
            
            VolumeSlider(
                title: "播放音量",
                value: Binding(
                    get: { Double(realtimeManager.audioSettings.playbackSignalVolume) },
                    set: { newValue in
                        Task {
                            try? await realtimeManager.setPlaybackSignalVolume(Int(newValue))
                        }
                    }
                )
            )
            
            VolumeSlider(
                title: "录制音量",
                value: Binding(
                    get: { Double(realtimeManager.audioSettings.recordingSignalVolume) },
                    set: { newValue in
                        Task {
                            try? await realtimeManager.setRecordingSignalVolume(Int(newValue))
                        }
                    }
                )
            )
        }
    }
}

/// Individual volume slider component
@available(iOS 13.0, macOS 10.15, *)
private struct VolumeSlider: View {
    let title: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: 0...100, step: 1)
                .accentColor(.blue)
        }
    }
}

// MARK: - Connection State Components

/// Connection state indicator view
@available(iOS 13.0, macOS 10.15, *)
public struct ConnectionStateView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var isAnimating = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionColor)
                .frame(width: 12, height: 12)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
            
            Text(connectionText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onReceive(realtimeManager.$connectionState) { state in
            updateAnimation(for: state)
        }
    }
    
    private var connectionColor: Color {
        switch realtimeManager.connectionState {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .yellow
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }
    
    private var connectionText: String {
        switch realtimeManager.connectionState {
        case .connected:
            return "已连接"
        case .connecting:
            return "连接中"
        case .reconnecting:
            return "重连中"
        case .disconnected:
            return "未连接"
        case .failed:
            return "连接失败"
        }
    }
    
    private func updateAnimation(for state: ConnectionState) {
        switch state {
        case .connecting, .reconnecting:
            isAnimating = true
        default:
            isAnimating = false
        }
    }
}

/// User session info view
@available(iOS 13.0, macOS 10.15, *)
public struct UserSessionView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    
    public init() {}
    
    public var body: some View {
        Group {
            if let session = realtimeManager.currentSession {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.userName)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(session.userRole.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(roleColor(session.userRole))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    if let roomId = session.roomId {
                        Text("房间: \(roomId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("加入时间: \(formatTime(session.createdAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.primary.colorInvert())
                .cornerRadius(8)
                .shadow(radius: 1)
            } else {
                Text("未登录")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .broadcaster:
            return .red
        case .coHost:
            return .orange
        case .moderator:
            return .blue
        case .audience:
            return .gray
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - User List Components

/// User list view with volume indicators
@available(iOS 13.0, macOS 10.15, *)
public struct UserListView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    @State private var users: [UserVolumeInfo] = []
    
    public init() {}
    
    public var body: some View {
        List {
            ForEach(users, id: \.userId) { user in
                UserRowView(user: user)
            }
        }
        .onReceive(realtimeManager.$volumeInfos) { volumeInfos in
            users = volumeInfos.sorted { $0.volume > $1.volume }
        }
        .navigationBarTitle("用户列表")
    }
}

/// Individual user row in the list
@available(iOS 13.0, macOS 10.15, *)
private struct UserRowView: View {
    @EnvironmentObject private var realtimeManager: RealtimeManager
    let user: UserVolumeInfo
    
    var body: some View {
        HStack {
            // Speaking indicator
            SpeakingIndicatorView(userId: user.userId, size: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.userId)
                    .font(.body)
                
                if user.isSpeaking {
                    Text("正在说话")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("静音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Volume level
            VolumeLevelView(userId: user.userId, showLabel: false)
                .frame(width: 60)
            
            // Dominant speaker indicator
            if realtimeManager.dominantSpeaker == user.userId {
                Text("👑")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Utility Views

/// Loading view with animation
@available(iOS 13.0, macOS 10.15, *)
public struct RealtimeLoadingView: View {
    @State private var isAnimating = false
    
    let message: String
    
    public init(message: String = "加载中...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.colorInvert())
    }
}

/// Error view with retry option
@available(iOS 13.0, macOS 10.15, *)
public struct RealtimeErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    
    public init(error: Error, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("发生错误")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let onRetry = onRetry {
                Button("重试", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.colorInvert())
    }
}

// MARK: - Preview Helpers

#if DEBUG
@available(iOS 13.0, macOS 10.15, *)
struct RealtimeSwiftUI_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VolumeWaveformView()
                .previewDisplayName("Volume Waveform")
            
            AudioControlPanel()
                .previewDisplayName("Audio Control Panel")
            
            ConnectionStateView()
                .previewDisplayName("Connection State")
            
            UserSessionView()
                .previewDisplayName("User Session")
        }
        .environmentObject(RealtimeManager.shared)
    }
}
#endif

// MARK: - ViewModel Layer for MVVM Architecture

/// Base ViewModel protocol for RealtimeKit SwiftUI components
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public protocol RealtimeViewModel: ObservableObject {
    var isLoading: Bool { get }
    var error: Error? { get }
    
    func handleError(_ error: Error)
    func clearError()
}

/// Main ViewModel for RealtimeKit functionality
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public class RealtimeMainViewModel: RealtimeViewModel {
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var currentSession: UserSession? = nil
    @Published public var audioSettings: AudioSettings = .default
    
    private let realtimeManager: RealtimeManager
    private var cancellables = Set<AnyCancellable>()
    
    public init(realtimeManager: RealtimeManager = RealtimeManager.shared) {
        self.realtimeManager = realtimeManager
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind RealtimeManager published properties to ViewModel
        realtimeManager.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        realtimeManager.$currentSession
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentSession, on: self)
            .store(in: &cancellables)
        
        realtimeManager.$audioSettings
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioSettings, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - User Actions
    
    public func loginUser(userId: String, userName: String, userRole: UserRole) async {
        isLoading = true
        clearError()
        
        do {
            try await realtimeManager.loginUser(userId: userId, userName: userName, userRole: userRole)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    public func logoutUser() async {
        isLoading = true
        clearError()
        
        do {
            try await realtimeManager.logoutUser()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    public func switchUserRole(_ newRole: UserRole) async {
        isLoading = true
        clearError()
        
        do {
            try await realtimeManager.switchUserRole(newRole)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Error Handling
    
    public func handleError(_ error: Error) {
        self.error = error
    }
    
    public func clearError() {
        self.error = nil
    }
}

/// ViewModel for audio controls
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public class AudioControlViewModel: RealtimeViewModel {
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    @Published public var audioSettings: AudioSettings = .default
    @Published public var isMicrophoneMuted: Bool = false
    @Published public var audioMixingVolume: Double = 100
    @Published public var playbackSignalVolume: Double = 100
    @Published public var recordingSignalVolume: Double = 100
    
    private let realtimeManager: RealtimeManager
    private var cancellables = Set<AnyCancellable>()
    
    public init(realtimeManager: RealtimeManager = RealtimeManager.shared) {
        self.realtimeManager = realtimeManager
        setupBindings()
    }
    
    private func setupBindings() {
        realtimeManager.$audioSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.audioSettings = settings
                self?.isMicrophoneMuted = settings.microphoneMuted
                self?.audioMixingVolume = Double(settings.audioMixingVolume)
                self?.playbackSignalVolume = Double(settings.playbackSignalVolume)
                self?.recordingSignalVolume = Double(settings.recordingSignalVolume)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Audio Control Actions
    
    public func toggleMicrophone() async {
        isLoading = true
        clearError()
        
        do {
            try await realtimeManager.muteMicrophone(!isMicrophoneMuted)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    public func setAudioMixingVolume(_ volume: Double) async {
        clearError()
        
        do {
            try await realtimeManager.setAudioMixingVolume(Int(volume))
        } catch {
            handleError(error)
        }
    }
    
    public func setPlaybackSignalVolume(_ volume: Double) async {
        clearError()
        
        do {
            try await realtimeManager.setPlaybackSignalVolume(Int(volume))
        } catch {
            handleError(error)
        }
    }
    
    public func setRecordingSignalVolume(_ volume: Double) async {
        clearError()
        
        do {
            try await realtimeManager.setRecordingSignalVolume(Int(volume))
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Error Handling
    
    public func handleError(_ error: Error) {
        self.error = error
    }
    
    public func clearError() {
        self.error = nil
    }
}

/// ViewModel for volume visualization
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public class VolumeVisualizationViewModel: RealtimeViewModel {
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    @Published public var volumeInfos: [UserVolumeInfo] = []
    @Published public var speakingUsers: Set<String> = []
    @Published public var dominantSpeaker: String? = nil
    @Published public var isVolumeDetectionEnabled: Bool = false
    
    private let realtimeManager: RealtimeManager
    private var cancellables = Set<AnyCancellable>()
    
    public init(realtimeManager: RealtimeManager = RealtimeManager.shared) {
        self.realtimeManager = realtimeManager
        setupBindings()
    }
    
    private func setupBindings() {
        realtimeManager.$volumeInfos
            .receive(on: DispatchQueue.main)
            .assign(to: \.volumeInfos, on: self)
            .store(in: &cancellables)
        
        realtimeManager.$speakingUsers
            .receive(on: DispatchQueue.main)
            .assign(to: \.speakingUsers, on: self)
            .store(in: &cancellables)
        
        realtimeManager.$dominantSpeaker
            .receive(on: DispatchQueue.main)
            .assign(to: \.dominantSpeaker, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Volume Detection Actions
    
    public func enableVolumeDetection(config: VolumeDetectionConfig = .default) async {
        isLoading = true
        clearError()
        
        do {
            try await realtimeManager.enableVolumeIndicator(config: config)
            isVolumeDetectionEnabled = true
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    public func disableVolumeDetection() async {
        isLoading = true
        clearError()
        
        do {
            try await realtimeManager.disableVolumeIndicator()
            isVolumeDetectionEnabled = false
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    public var sortedVolumeInfos: [UserVolumeInfo] {
        volumeInfos.sorted { $0.volume > $1.volume }
    }
    
    public var activeSpeakers: [UserVolumeInfo] {
        volumeInfos.filter { $0.isSpeaking }
    }
    
    // MARK: - Error Handling
    
    public func handleError(_ error: Error) {
        self.error = error
    }
    
    public func clearError() {
        self.error = nil
    }
}

/// ViewModel for user management
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public class UserManagementViewModel: RealtimeViewModel {
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    @Published public var users: [UserVolumeInfo] = []
    @Published public var currentSession: UserSession? = nil
    
    private let realtimeManager: RealtimeManager
    private var cancellables = Set<AnyCancellable>()
    
    public init(realtimeManager: RealtimeManager = RealtimeManager.shared) {
        self.realtimeManager = realtimeManager
        setupBindings()
    }
    
    private func setupBindings() {
        realtimeManager.$volumeInfos
            .receive(on: DispatchQueue.main)
            .assign(to: \.users, on: self)
            .store(in: &cancellables)
        
        realtimeManager.$currentSession
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentSession, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - User Management Actions
    
    public func refreshUserList() async {
        isLoading = true
        clearError()
        
        // In a real implementation, this would fetch updated user data
        try? await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    public var sortedUsers: [UserVolumeInfo] {
        users.sorted { user1, user2 in
            // Sort by speaking status first, then by volume
            if user1.isSpeaking != user2.isSpeaking {
                return user1.isSpeaking && !user2.isSpeaking
            }
            return user1.volume > user2.volume
        }
    }
    
    public var speakingUsersCount: Int {
        users.filter { $0.isSpeaking }.count
    }
    
    // MARK: - Error Handling
    
    public func handleError(_ error: Error) {
        self.error = error
    }
    
    public func clearError() {
        self.error = nil
    }
}

// MARK: - Adaptive Layout Support

/// Adaptive layout configuration for different screen sizes
@available(iOS 13.0, macOS 10.15, *)
public struct AdaptiveLayoutConfiguration {
    public let isCompact: Bool
    public let isRegular: Bool
    public let isPad: Bool
    public let isMac: Bool
    
    public init(horizontalSizeClass: UserInterfaceSizeClass?, verticalSizeClass: UserInterfaceSizeClass?) {
        self.isCompact = horizontalSizeClass == .compact || verticalSizeClass == .compact
        self.isRegular = horizontalSizeClass == .regular && verticalSizeClass == .regular
        
        #if os(iOS)
        self.isPad = UIDevice.current.userInterfaceIdiom == .pad
        self.isMac = false
        #elseif os(macOS)
        self.isPad = false
        self.isMac = true
        #else
        self.isPad = false
        self.isMac = false
        #endif
    }
    
    public var shouldUseCompactLayout: Bool {
        return isCompact && !isPad
    }
    
    public var shouldUseSidebarLayout: Bool {
        return isRegular || isPad || isMac
    }
    
    public var maxColumns: Int {
        if isMac {
            return 3
        } else if isPad && isRegular {
            return 2
        } else {
            return 1
        }
    }
}

/// Adaptive RealtimeKit main view
@available(iOS 13.0, macOS 10.15, *)
public struct AdaptiveRealtimeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ObservedObject private var mainViewModel = RealtimeMainViewModel()
    @ObservedObject private var audioViewModel = AudioControlViewModel()
    @ObservedObject private var volumeViewModel = VolumeVisualizationViewModel()
    @ObservedObject private var userViewModel = UserManagementViewModel()
    
    public init() {}
    
    public var body: some View {
        let layoutConfig = AdaptiveLayoutConfiguration(
            horizontalSizeClass: horizontalSizeClass,
            verticalSizeClass: verticalSizeClass
        )
        
        Group {
            if layoutConfig.shouldUseSidebarLayout {
                SidebarLayoutView(
                    mainViewModel: mainViewModel,
                    audioViewModel: audioViewModel,
                    volumeViewModel: volumeViewModel,
                    userViewModel: userViewModel,
                    layoutConfig: layoutConfig
                )
            } else {
                CompactLayoutView(
                    mainViewModel: mainViewModel,
                    audioViewModel: audioViewModel,
                    volumeViewModel: volumeViewModel,
                    userViewModel: userViewModel
                )
            }
        }
        .environmentObject(mainViewModel)
        .environmentObject(audioViewModel)
        .environmentObject(volumeViewModel)
        .environmentObject(userViewModel)
    }
}

/// Sidebar layout for iPad and Mac
@available(iOS 13.0, macOS 10.15, *)
private struct SidebarLayoutView: View {
    @ObservedObject var mainViewModel: RealtimeMainViewModel
    @ObservedObject var audioViewModel: AudioControlViewModel
    @ObservedObject var volumeViewModel: VolumeVisualizationViewModel
    @ObservedObject var userViewModel: UserManagementViewModel
    let layoutConfig: AdaptiveLayoutConfiguration
    
    var body: some View {
        NavigationView {
            // Sidebar
            List {
                Group {
                    Text("连接状态")
                        .font(.headline)
                    ConnectionStateView()
                }
                
                Group {
                    Text("用户信息")
                        .font(.headline)
                    UserSessionView()
                }
                
                Group {
                    Text("音频控制")
                        .font(.headline)
                    NavigationLink("音频设置", destination: AudioControlDetailView().environmentObject(audioViewModel))
                }
                
                Group {
                    Text("用户列表")
                        .font(.headline)
                    NavigationLink("所有用户", destination: UserListDetailView().environmentObject(userViewModel))
                }
            }
            .navigationBarTitle("RealtimeKit")
            
            // Main content
            VStack {
                if layoutConfig.maxColumns >= 2 {
                    HStack {
                        VolumeWaveformView()
                            .frame(maxWidth: .infinity)
                        
                        if layoutConfig.maxColumns >= 3 {
                            UserListView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    VolumeWaveformView()
                }
                
                Spacer()
            }
            .navigationBarTitle("音量可视化")
        }
    }
}

/// Compact layout for iPhone
@available(iOS 13.0, macOS 10.15, *)
private struct CompactLayoutView: View {
    @ObservedObject var mainViewModel: RealtimeMainViewModel
    @ObservedObject var audioViewModel: AudioControlViewModel
    @ObservedObject var volumeViewModel: VolumeVisualizationViewModel
    @ObservedObject var userViewModel: UserManagementViewModel
    
    var body: some View {
        TabView {
            // Main tab
            VStack {
                ConnectionStateView()
                    .padding()
                
                VolumeWaveformView()
                    .padding()
                
                Spacer()
                
                AudioControlPanel()
                    .padding()
            }
            .tabItem {
                Text("📊")
                Text("主界面")
            }
            
            // Users tab
            UserListView()
                .tabItem {
                    Text("👥")
                    Text("用户")
                }
            
            // Settings tab
            SettingsView()
                .tabItem {
                    Text("⚙️")
                    Text("设置")
                }
        }
    }
}

/// Audio control detail view for sidebar navigation
@available(iOS 13.0, macOS 10.15, *)
private struct AudioControlDetailView: View {
    @EnvironmentObject private var audioViewModel: AudioControlViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AudioControlPanel()
            
            VolumeControlsView()
            
            Spacer()
        }
        .padding()
        .navigationBarTitle("音频控制")
    }
}

/// User list detail view for sidebar navigation
@available(iOS 13.0, macOS 10.15, *)
private struct UserListDetailView: View {
    @EnvironmentObject private var userViewModel: UserManagementViewModel
    
    var body: some View {
        VStack {
            if userViewModel.isLoading {
                RealtimeLoadingView(message: "加载用户列表...")
            } else {
                UserListView()
            }
        }
        .navigationBarTitle("用户列表")
        .navigationBarItems(trailing: 
            Button("刷新") {
                Task {
                    await userViewModel.refreshUserList()
                }
            }
        )
    }
}

/// Settings view
@available(iOS 13.0, macOS 10.15, *)
private struct SettingsView: View {
    @EnvironmentObject private var mainViewModel: RealtimeMainViewModel
    
    var body: some View {
        NavigationView {
            List {
                Group {
                    Text("用户设置")
                        .font(.headline)
                    if let session = mainViewModel.currentSession {
                        VStack(alignment: .leading) {
                            Text("用户名: \(session.userName)")
                            Text("角色: \(session.userRole.displayName)")
                        }
                    } else {
                        Text("未登录")
                            .foregroundColor(.secondary)
                    }
                }
                
                Group {
                    Text("应用信息")
                        .font(.headline)
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(RealtimeSwiftUIVersion.current)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationBarTitle("设置")
        }
    }
}

// MARK: - Combine Data Flow and Async State Management

/// Async state management for RealtimeKit operations
@available(iOS 13.0, macOS 10.15, *)
public enum AsyncState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
    
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    public var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

/// Publisher for RealtimeKit events
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public class RealtimeEventPublisher: ObservableObject {
    public static let shared = RealtimeEventPublisher()
    
    // Event publishers
    public let connectionStateChanged = PassthroughSubject<ConnectionState, Never>()
    public let userJoined = PassthroughSubject<UserSession, Never>()
    public let userLeft = PassthroughSubject<String, Never>()
    public let volumeUpdated = PassthroughSubject<[UserVolumeInfo], Never>()
    public let speakingStateChanged = PassthroughSubject<(userId: String, isSpeaking: Bool), Never>()
    public let dominantSpeakerChanged = PassthroughSubject<String?, Never>()
    public let audioSettingsChanged = PassthroughSubject<AudioSettings, Never>()
    public let errorOccurred = PassthroughSubject<Error, Never>()
    
    private init() {}
    
    // MARK: - Event Publishing Methods
    
    public func publishConnectionStateChange(_ state: ConnectionState) {
        connectionStateChanged.send(state)
    }
    
    public func publishUserJoined(_ user: UserSession) {
        userJoined.send(user)
    }
    
    public func publishUserLeft(_ userId: String) {
        userLeft.send(userId)
    }
    
    public func publishVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        volumeUpdated.send(volumeInfos)
    }
    
    public func publishSpeakingStateChange(userId: String, isSpeaking: Bool) {
        speakingStateChanged.send((userId: userId, isSpeaking: isSpeaking))
    }
    
    public func publishDominantSpeakerChange(_ userId: String?) {
        dominantSpeakerChanged.send(userId)
    }
    
    public func publishAudioSettingsChange(_ settings: AudioSettings) {
        audioSettingsChanged.send(settings)
    }
    
    public func publishError(_ error: Error) {
        errorOccurred.send(error)
    }
}

/// Async operation manager for RealtimeKit
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public class AsyncOperationManager: ObservableObject {
    @Published public var loginState: AsyncState<UserSession> = .idle
    @Published public var connectionState: AsyncState<ConnectionState> = .idle
    @Published public var audioOperationState: AsyncState<AudioSettings> = .idle
    @Published public var volumeDetectionState: AsyncState<Bool> = .idle
    
    private let realtimeManager: RealtimeManager
    private let eventPublisher: RealtimeEventPublisher
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        realtimeManager: RealtimeManager = RealtimeManager.shared,
        eventPublisher: RealtimeEventPublisher = RealtimeEventPublisher.shared
    ) {
        self.realtimeManager = realtimeManager
        self.eventPublisher = eventPublisher
        setupEventSubscriptions()
    }
    
    private func setupEventSubscriptions() {
        // Subscribe to connection state changes
        eventPublisher.connectionStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = .success(state)
            }
            .store(in: &cancellables)
        
        // Subscribe to audio settings changes
        eventPublisher.audioSettingsChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.audioOperationState = .success(settings)
            }
            .store(in: &cancellables)
        
        // Subscribe to errors
        eventPublisher.errorOccurred
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleAsyncError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Async Operations
    
    public func performLogin(userId: String, userName: String, userRole: UserRole) async {
        loginState = .loading
        
        do {
            try await realtimeManager.loginUser(userId: userId, userName: userName, userRole: userRole)
            
            if let session = realtimeManager.currentSession {
                loginState = .success(session)
                eventPublisher.publishUserJoined(session)
            }
        } catch {
            loginState = .failure(error)
            eventPublisher.publishError(error)
        }
    }
    
    public func performLogout() async {
        loginState = .loading
        
        do {
            try await realtimeManager.logoutUser()
            loginState = .idle
        } catch {
            loginState = .failure(error)
            eventPublisher.publishError(error)
        }
    }
    
    public func performConnection(config: RealtimeConfig) async {
        connectionState = .loading
        
        do {
            try await realtimeManager.configure(provider: .agora, config: config)
            let state = realtimeManager.connectionState
            connectionState = .success(state)
            eventPublisher.publishConnectionStateChange(state)
        } catch {
            connectionState = .failure(error)
            eventPublisher.publishError(error)
        }
    }
    
    public func performAudioOperation<T>(_ operation: () async throws -> T) async -> AsyncState<T> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            eventPublisher.publishError(error)
            return .failure(error)
        }
    }
    
    public func enableVolumeDetection(config: VolumeDetectionConfig = .default) async {
        volumeDetectionState = .loading
        
        do {
            try await realtimeManager.enableVolumeIndicator(config: config)
            volumeDetectionState = .success(true)
        } catch {
            volumeDetectionState = .failure(error)
            eventPublisher.publishError(error)
        }
    }
    
    public func disableVolumeDetection() async {
        volumeDetectionState = .loading
        
        do {
            try await realtimeManager.disableVolumeIndicator()
            volumeDetectionState = .success(false)
        } catch {
            volumeDetectionState = .failure(error)
            eventPublisher.publishError(error)
        }
    }
    
    private func handleAsyncError(_ error: Error) {
        // Update relevant states based on error type
        if error is RealtimeError {
            switch error as! RealtimeError {
            case .connectionFailed, .networkError:
                connectionState = .failure(error)
            case .authenticationFailed, .noActiveSession:
                loginState = .failure(error)
            default:
                break
            }
        }
    }
}

/// Reactive data store for RealtimeKit state
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public class RealtimeDataStore: ObservableObject {
    // Core state
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var currentSession: UserSession? = nil
    @Published public var audioSettings: AudioSettings = .default
    
    // Volume and user state
    @Published public var volumeInfos: [UserVolumeInfo] = []
    @Published public var speakingUsers: Set<String> = []
    @Published public var dominantSpeaker: String? = nil
    
    // UI state
    @Published public var isVolumeDetectionEnabled: Bool = false
    @Published public var selectedUser: String? = nil
    @Published public var showingErrorAlert: Bool = false
    @Published public var currentError: Error? = nil
    
    private let eventPublisher: RealtimeEventPublisher
    private var cancellables = Set<AnyCancellable>()
    
    public init(eventPublisher: RealtimeEventPublisher = RealtimeEventPublisher.shared) {
        self.eventPublisher = eventPublisher
        setupDataBindings()
    }
    
    private func setupDataBindings() {
        // Connection state updates
        eventPublisher.connectionStateChanged
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        // Volume updates
        eventPublisher.volumeUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumeInfos in
                self?.volumeInfos = volumeInfos
                self?.updateSpeakingUsers(from: volumeInfos)
            }
            .store(in: &cancellables)
        
        // Speaking state changes
        eventPublisher.speakingStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (userId, isSpeaking) in
                if isSpeaking {
                    self?.speakingUsers.insert(userId)
                } else {
                    self?.speakingUsers.remove(userId)
                }
            }
            .store(in: &cancellables)
        
        // Dominant speaker changes
        eventPublisher.dominantSpeakerChanged
            .receive(on: DispatchQueue.main)
            .assign(to: \.dominantSpeaker, on: self)
            .store(in: &cancellables)
        
        // Audio settings updates
        eventPublisher.audioSettingsChanged
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioSettings, on: self)
            .store(in: &cancellables)
        
        // Error handling
        eventPublisher.errorOccurred
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.currentError = error
                self?.showingErrorAlert = true
            }
            .store(in: &cancellables)
        
        // User session updates
        eventPublisher.userJoined
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.currentSession = session
            }
            .store(in: &cancellables)
        
        eventPublisher.userLeft
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.currentSession = nil
            }
            .store(in: &cancellables)
    }
    
    private func updateSpeakingUsers(from volumeInfos: [UserVolumeInfo]) {
        let newSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        
        // Detect changes and publish events
        let startedSpeaking = newSpeakingUsers.subtracting(speakingUsers)
        let stoppedSpeaking = speakingUsers.subtracting(newSpeakingUsers)
        
        for userId in startedSpeaking {
            eventPublisher.publishSpeakingStateChange(userId: userId, isSpeaking: true)
        }
        
        for userId in stoppedSpeaking {
            eventPublisher.publishSpeakingStateChange(userId: userId, isSpeaking: false)
        }
        
        speakingUsers = newSpeakingUsers
        
        // Update dominant speaker
        let newDominantSpeaker = volumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        
        if newDominantSpeaker != dominantSpeaker {
            dominantSpeaker = newDominantSpeaker
            eventPublisher.publishDominantSpeakerChange(newDominantSpeaker)
        }
    }
    
    // MARK: - Computed Properties
    
    public var sortedVolumeInfos: [UserVolumeInfo] {
        volumeInfos.sorted { $0.volume > $1.volume }
    }
    
    public var activeSpeakers: [UserVolumeInfo] {
        volumeInfos.filter { $0.isSpeaking }
    }
    
    public var isConnected: Bool {
        connectionState == .connected
    }
    
    public var hasActiveSession: Bool {
        currentSession != nil
    }
    
    // MARK: - Actions
    
    public func clearError() {
        currentError = nil
        showingErrorAlert = false
    }
    
    public func selectUser(_ userId: String?) {
        selectedUser = userId
    }
}

/// Combine-based reactive coordinator for complex data flows
@available(iOS 13.0, macOS 10.15, *)
public class RealtimeReactiveCoordinator: ObservableObject {
    @Published public var isFullyInitialized: Bool = false
    @Published public var systemHealth: SystemHealth = .unknown
    
    private let dataStore: RealtimeDataStore
    private let operationManager: AsyncOperationManager
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        dataStore: RealtimeDataStore? = nil,
        operationManager: AsyncOperationManager? = nil
    ) {
        self.dataStore = dataStore ?? RealtimeDataStore()
        self.operationManager = operationManager ?? AsyncOperationManager()
        setupReactiveCoordination()
    }
    
    private func setupReactiveCoordination() {
        // Monitor system initialization
        Publishers.CombineLatest3(
            dataStore.$connectionState,
            dataStore.$currentSession,
            dataStore.$isVolumeDetectionEnabled
        )
        .map { connectionState, session, volumeEnabled in
            connectionState == .connected && session != nil && volumeEnabled
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.isFullyInitialized, on: self)
        .store(in: &cancellables)
        
        // Monitor system health
        Publishers.CombineLatest4(
            dataStore.$connectionState,
            operationManager.$loginState,
            operationManager.$audioOperationState,
            operationManager.$volumeDetectionState
        )
        .map { connectionState, loginState, audioState, volumeState in
            self.calculateSystemHealth(
                connectionState: connectionState,
                loginState: loginState,
                audioState: audioState,
                volumeState: volumeState
            )
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.systemHealth, on: self)
        .store(in: &cancellables)
        
        // Auto-recovery mechanisms
        dataStore.$connectionState
            .filter { $0 == .failed(RealtimeError.networkError("Connection lost")) }
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.attemptAutoRecovery()
                }
            }
            .store(in: &cancellables)
    }
    
    private func calculateSystemHealth() -> SystemHealth {
        // Simplified health calculation
        return .healthy
    }
    
    private func attemptAutoRecovery() async {
        // Implement auto-recovery logic
        print("Attempting auto-recovery...")
        
        // Try to reconnect
        let config = RealtimeConfig(
            appId: "test-app-id"
        )
        
        await operationManager.performConnection(config: config)
    }
}

public enum SystemHealth {
    case unknown
    case initializing
    case healthy
    case degraded
    case failed
    
    public var color: Color {
        switch self {
        case .unknown, .initializing:
            return .yellow
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .failed:
            return .red
        }
    }
    
    public var description: String {
        switch self {
        case .unknown:
            return "未知状态"
        case .initializing:
            return "初始化中"
        case .healthy:
            return "运行正常"
        case .degraded:
            return "性能降级"
        case .failed:
            return "系统故障"
        }
    }
}