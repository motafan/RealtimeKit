import Foundation
import RealtimeCore
import RealtimeMocking

/// Simplified RealtimeManager for SwiftUI Demo
@MainActor
public class SimpleRealtimeManager: ObservableObject {
    
    public static let shared = SimpleRealtimeManager()
    
    // MARK: - Published Properties
    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var audioSettings: AudioSettings = .default
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var speakingUsers: Set<String> = []
    @Published public private(set) var dominantSpeaker: String? = nil
    @Published public private(set) var streamPushState: StreamPushState = .stopped
    @Published public private(set) var mediaRelayState: MediaRelayState = .stopped
    
    // MARK: - Private Properties
    private var rtcProvider: RTCProvider?
    private var rtmProvider: RTMProvider?
    private var currentConfig: RealtimeConfig?
    private let volumeManager = VolumeIndicatorManager()
    
    private init() {
        setupVolumeManager()
    }
    
    // MARK: - Configuration
    public func configure(provider: ProviderType, config: RealtimeConfig) async throws {
        currentConfig = config
        
        // Create mock providers for demo
        if provider == .mock {
            rtcProvider = MockRTCProvider()
            rtmProvider = MockRTMProvider()
        }
        
        // Initialize providers
        try await rtcProvider?.initialize(config: RTCConfig(from: config))
        try await rtmProvider?.initialize(config: RTMConfig(from: config))
        
        connectionState = .connected
        print("SimpleRealtimeManager configured with \(provider.displayName)")
    }
    
    // MARK: - User Session Management
    public func loginUser(userId: String, userName: String, userRole: UserRole) async throws {
        let session = UserSession(userId: userId, userName: userName, userRole: userRole)
        currentSession = session
        print("User logged in: \(userName) (\(userRole.displayName))")
    }
    
    public func logoutUser() async throws {
        currentSession = nil
        print("User logged out")
    }
    
    // MARK: - Audio Control
    public func muteMicrophone(_ muted: Bool) async throws {
        try await rtcProvider?.muteMicrophone(muted)
        
        audioSettings = AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: audioSettings.audioMixingVolume,
            playbackSignalVolume: audioSettings.playbackSignalVolume,
            recordingSignalVolume: audioSettings.recordingSignalVolume,
            localAudioStreamActive: audioSettings.localAudioStreamActive
        )
        
        print("Microphone \(muted ? "muted" : "unmuted")")
    }
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider?.setAudioMixingVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(audioMixing: clampedVolume)
        print("Audio mixing volume set to \(clampedVolume)")
    }
    
    // MARK: - Volume Indicator
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        try await rtcProvider?.enableVolumeIndicator(config: config)
        
        // Setup volume callback
        rtcProvider?.setVolumeIndicatorHandler { [weak self] volumeInfos in
            Task { @MainActor in
                self?.handleVolumeUpdate(volumeInfos)
            }
        }
        
        // Start simulated volume updates for demo
        startSimulatedVolumeUpdates()
        
        print("Volume indicator enabled")
    }
    
    // MARK: - Stream Push
    public func startStreamPush(config: StreamPushConfig) async throws {
        try await rtcProvider?.startStreamPush(config: config)
        streamPushState = .running
        print("Stream push started")
    }
    
    public func stopStreamPush() async throws {
        try await rtcProvider?.stopStreamPush()
        streamPushState = .stopped
        print("Stream push stopped")
    }
    
    // MARK: - Media Relay
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        try await rtcProvider?.startMediaRelay(config: config)
        mediaRelayState = .running
        print("Media relay started")
    }
    
    public func stopMediaRelay() async throws {
        try await rtcProvider?.stopMediaRelay()
        mediaRelayState = .stopped
        print("Media relay stopped")
    }
    
    // MARK: - Private Methods
    private func setupVolumeManager() {
        volumeManager.onVolumeUpdate = { [weak self] volumeInfos in
            Task { @MainActor in
                self?.handleVolumeUpdate(volumeInfos)
            }
        }
    }
    
    private func handleVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        self.volumeInfos = volumeInfos
        
        let newSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        let newDominantSpeaker = volumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        
        speakingUsers = newSpeakingUsers
        dominantSpeaker = newDominantSpeaker
        
        volumeManager.processVolumeUpdate(volumeInfos)
    }
    
    // MARK: - Demo Simulation
    private func startSimulatedVolumeUpdates() {
        Task {
            while true {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                
                // Generate simulated volume data
                let simulatedVolumeInfos = generateSimulatedVolumeData()
                await handleVolumeUpdate(simulatedVolumeInfos)
            }
        }
    }
    
    private func generateSimulatedVolumeData() -> [UserVolumeInfo] {
        guard let session = currentSession else { return [] }
        
        let time = Date().timeIntervalSince1970
        let baseVolume = Float((sin(time * 2) + 1) * 0.3) // Oscillating volume
        let isSpeaking = baseVolume > 0.2
        
        return [
            UserVolumeInfo(
                userId: session.userId,
                volume: baseVolume,
                isSpeaking: isSpeaking,
                timestamp: Date()
            )
        ]
    }
}

// MARK: - Extensions for Demo Compatibility

extension SimpleRealtimeManager {
    /// Convenience property for demo
    public var volumeManager: VolumeIndicatorManager {
        return self.volumeManager
    }
}