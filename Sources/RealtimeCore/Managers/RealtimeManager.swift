// RealtimeManager.swift
// Core RealtimeManager class - Central coordinator for all RealtimeKit functionality

import Foundation
import Combine

/// Main manager class for RealtimeKit
@MainActor
public final class RealtimeManager: ObservableObject, @unchecked Sendable {
    
    /// Shared singleton instance
    public static let shared = RealtimeManager()
    
    // MARK: - Published Properties for SwiftUI (需求 3.2, 11.3)
    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var audioSettings: AudioSettings = .default
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var streamPushState: StreamPushState = .stopped
    @Published public private(set) var mediaRelayState: MediaRelayState?
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var speakingUsers: Set<String> = []
    @Published public private(set) var dominantSpeaker: String? = nil
    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var currentProvider: ProviderType?
    @Published public private(set) var availableProviders: Set<ProviderType> = []
    @Published public private(set) var supportedFeatures: Set<ProviderFeature> = []
    @Published public private(set) var providerSwitchInProgress: Bool = false
    @Published public private(set) var lastError: RealtimeError?
    
    // MARK: - Sub-managers (需求 3.1)
    private let factoryRegistry = ProviderFactoryRegistry()
    private var providerSwitchManager: ProviderSwitchManager!
    private let tokenManager = TokenManager()
    private let volumeIndicatorManager = VolumeIndicatorManager()
    private let mediaRelayManager = MediaRelayManager()
    private let streamPushManager = StreamPushManager()
    private let messageProcessorManager = RealtimeMessageProcessorManager()
    private let connectionStateManager = ConnectionStateManager()
    private let errorHandler = ErrorHandler.shared
    
    // MARK: - Storage managers (需求 3.5)
    private let audioSettingsStorage = AudioSettingsStorage()
    private let userSessionStorage = UserSessionStorage()
    
    // MARK: - Provider instances
    private var rtcProvider: RTCProvider?
    private var rtmProvider: RTMProvider?
    internal var currentConfig: RealtimeConfig?
    
    // MARK: - Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Combine Publishers for Advanced Reactive Support (需求 3.3, 11.3)
    
    /// Publisher for connection state changes
    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        $connectionState.eraseToAnyPublisher()
    }
    
    /// Publisher for audio settings changes
    public var audioSettingsPublisher: AnyPublisher<AudioSettings, Never> {
        $audioSettings.eraseToAnyPublisher()
    }
    
    /// Publisher for user session changes
    public var currentSessionPublisher: AnyPublisher<UserSession?, Never> {
        $currentSession.eraseToAnyPublisher()
    }
    
    /// Publisher for volume information updates
    public var volumeInfosPublisher: AnyPublisher<[UserVolumeInfo], Never> {
        $volumeInfos.eraseToAnyPublisher()
    }
    
    /// Publisher for speaking users changes
    public var speakingUsersPublisher: AnyPublisher<Set<String>, Never> {
        $speakingUsers.eraseToAnyPublisher()
    }
    
    /// Publisher for dominant speaker changes
    public var dominantSpeakerPublisher: AnyPublisher<String?, Never> {
        $dominantSpeaker.eraseToAnyPublisher()
    }
    
    /// Publisher for provider changes
    public var currentProviderPublisher: AnyPublisher<ProviderType?, Never> {
        $currentProvider.eraseToAnyPublisher()
    }
    
    /// Publisher for error state changes
    public var lastErrorPublisher: AnyPublisher<RealtimeError?, Never> {
        $lastError.eraseToAnyPublisher()
    }
    
    /// Combined publisher for system readiness state
    public var systemReadinessPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest3(
            $isInitialized,
            $connectionState,
            $providerSwitchInProgress
        )
        .map { isInitialized, connectionState, switchInProgress in
            return isInitialized && connectionState.isActive && !switchInProgress
        }
        .eraseToAnyPublisher()
    }
    
    /// Publisher for audio state summary
    public var audioStateSummaryPublisher: AnyPublisher<AudioStateSummary, Never> {
        $audioSettings
            .map { settings in
                AudioStateSummary(
                    isMuted: settings.microphoneMuted,
                    isStreamActive: settings.localAudioStreamActive,
                    mixingVolume: settings.audioMixingVolume,
                    playbackVolume: settings.playbackSignalVolume,
                    recordingVolume: settings.recordingSignalVolume
                )
            }
            .eraseToAnyPublisher()
    }
    
    private init() {
        self.providerSwitchManager = ProviderSwitchManager(factoryRegistry: self.factoryRegistry)
        self.setupBindings()
        self.setupDefaultProviders()
        Task {
            await self.restorePersistedSettings()
        }
        print("RealtimeManager initialized")
    }
    
    // MARK: - Configuration (需求 3.1, 2.3)
    
    /// Configure RealtimeManager with provider and configuration
    /// - Parameters:
    ///   - provider: Provider type to use
    ///   - config: RealtimeKit configuration
    public func configure(provider: ProviderType, config: RealtimeConfig) async throws {
        lastError = nil
        
        guard factoryRegistry.isProviderAvailable(provider) else {
            let error = RealtimeError.providerNotAvailable(provider)
            lastError = error
            throw error
        }
        
        currentConfig = config
        
        do {
            // Create provider instances using factory pattern (需求 2.2)
            guard let factory = factoryRegistry.getFactory(for: provider) else {
                let error = RealtimeError.providerNotAvailable(provider)
                lastError = error
                throw error
            }
            
            rtcProvider = factory.createRTCProvider()
            rtmProvider = factory.createRTMProvider()
            
            // Initialize providers with proper error handling
            try await rtcProvider?.initialize(config: RTCConfig(from: config))
            try await rtmProvider?.initialize(config: RTMConfig(from: config))
            
            // Setup integrations
            setupTokenManagement()
            setupVolumeIndicator()
            setupMessageProcessing()
            setupConnectionStateHandling()
            
            // Update state
            currentProvider = provider
            supportedFeatures = factory.supportedFeatures()
            isInitialized = true
            connectionState = .connected
            
            // Update provider switch manager
            factoryRegistry.setCurrentProvider(provider)
            
            // Sync audio settings with the new provider (需求 5.6)
            try await syncAudioSettingsWithProvider()
            
            print("RealtimeManager configured with provider: \(provider)")
            
        } catch {
            let realtimeError = error as? RealtimeError ?? RealtimeError.providerInitializationFailed(provider, error.localizedDescription)
            lastError = realtimeError
            
            // Cleanup on failure
            await cleanupCurrentProvider()
            throw realtimeError
        }
    }
    
    /// Switch to a different provider while preserving session state (需求 2.3)
    /// - Parameters:
    ///   - newProvider: Target provider type
    ///   - preserveSession: Whether to preserve current session
    public func switchProvider(to newProvider: ProviderType, preserveSession: Bool = true) async throws {
        guard newProvider != currentProvider else { return }
        
        guard !providerSwitchInProgress else {
            throw RealtimeError.operationInProgress("Provider switch already in progress")
        }
        
        providerSwitchInProgress = true
        lastError = nil
        
        defer {
            providerSwitchInProgress = false
        }
        
        do {
            // Use provider switch manager for coordinated switching
            let success = await providerSwitchManager.switchProvider(to: newProvider, preserveSession: preserveSession)
            
            if !success {
                if let error = providerSwitchManager.lastSwitchError {
                    lastError = error as? RealtimeError ?? RealtimeError.providerSwitchFailed(error.localizedDescription)
                    throw lastError!
                } else {
                    let error = RealtimeError.providerSwitchFailed("Unknown error during provider switch")
                    lastError = error
                    throw error
                }
            }
            
            // Update our state to match the switch manager
            currentProvider = providerSwitchManager.currentProvider
            if let provider = currentProvider {
                supportedFeatures = factoryRegistry.getSupportedFeatures(for: provider)
            }
            
            print("Successfully switched to provider: \(newProvider)")
            
        } catch {
            let realtimeError = error as? RealtimeError ?? RealtimeError.providerSwitchFailed(error.localizedDescription)
            lastError = realtimeError
            throw realtimeError
        }
    }
    
    // MARK: - Provider Registration (需求 2.2)
    
    /// Register a custom provider factory
    /// - Parameter factory: Provider factory to register
    public func registerProviderFactory(_ factory: ProviderFactory) {
        factoryRegistry.registerFactory(factory)
        updateAvailableProviders()
        
        // Set fallback chain for provider switch manager
        let providers = Array(factoryRegistry.getAvailableProviders())
        providerSwitchManager.setFallbackChain(providers)
    }
    
    /// Unregister a provider factory
    /// - Parameter providerType: Provider type to unregister
    public func unregisterProviderFactory(_ providerType: ProviderType) {
        factoryRegistry.unregisterFactory(providerType)
        updateAvailableProviders()
        
        // Update fallback chain
        let providers = Array(factoryRegistry.getAvailableProviders())
        providerSwitchManager.setFallbackChain(providers)
    }
    
    /// Get available providers
    /// - Returns: Set of available provider types
    public func getAvailableProviders() -> Set<ProviderType> {
        return factoryRegistry.getAvailableProviders()
    }
    
    /// Get supported features for a provider
    /// - Parameter provider: Provider type
    /// - Returns: Set of supported features
    public func getSupportedFeatures(for provider: ProviderType) -> Set<ProviderFeature> {
        return factoryRegistry.getSupportedFeatures(for: provider)
    }
    
    /// Check if a feature is supported by current provider
    /// - Parameter feature: Feature to check
    /// - Returns: True if feature is supported
    public func isFeatureSupported(_ feature: ProviderFeature) -> Bool {
        return supportedFeatures.contains(feature)
    }
    
    /// Get current provider information
    /// - Returns: Current provider info including type and features
    public func getCurrentProviderInfo() -> (type: ProviderType, features: Set<ProviderFeature>)? {
        guard let provider = currentProvider else { return nil }
        return (type: provider, features: supportedFeatures)
    }
    
    // MARK: - User Identity and Session Management (需求 4)
    
    /// Login user and create session (需求 4.1, 4.4)
    /// - Parameters:
    ///   - userId: Unique user identifier
    ///   - userName: Display name for the user
    ///   - userRole: Initial user role
    ///   - additionalInfo: Optional additional user information
    public func loginUser(
        userId: String,
        userName: String,
        userRole: UserRole,
        additionalInfo: [String: Any] = [:]
    ) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        // Validate user credentials
        guard !userId.isEmpty && !userName.isEmpty else {
            throw RealtimeError.invalidParameter("User ID and name cannot be empty")
        }
        
        // Create new session (需求 4.4)
        let session = UserSession(
            userId: userId,
            userName: userName,
            userRole: userRole
        )
        
        // Store session
        currentSession = session
        userSessionStorage.saveUserSession(session)
        
        // Configure initial permissions based on role (需求 4.2)
        try await configureRolePermissions(userRole)
        
        print("User logged in: \(userName) (\(userId)) with role \(userRole)")
    }
    
    /// Logout current user and clear session (需求 4.5)
    public func logoutUser() async throws {
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        // Leave room if currently in one
        if session.isInRoom {
            try await leaveRoom()
        }
        
        // Clear session data
        currentSession = nil
        userSessionStorage.clearUserSession()
        
        // Reset audio settings to default
        audioSettings = .default
        audioSettingsStorage.saveAudioSettings(audioSettings)
        
        print("User logged out: \(session.userName)")
    }
    
    /// Update user session activity (需求 4.5)
    public func updateSessionActivity() {
        guard let session = currentSession else { return }
        
        let updatedSession = session.updateLastActive()
        currentSession = updatedSession
        userSessionStorage.saveUserSession(updatedSession)
    }
    
    /// Get current user permissions (需求 4.2)
    /// - Returns: Set of permissions for current user
    public func getCurrentUserPermissions() -> UserPermissions? {
        guard let session = currentSession else { return nil }
        return UserPermissions(role: session.userRole)
    }
    
    /// Validate user permission for specific action (需求 4.2)
    /// - Parameter permission: Permission to check
    /// - Returns: True if user has permission
    public func hasPermission(_ permission: UserPermission) -> Bool {
        guard let permissions = getCurrentUserPermissions() else { return false }
        return permissions.hasPermission(permission)
    }
    
    // MARK: - Room Management
    
    /// Create a new room
    /// - Parameter roomId: Room identifier
    /// - Returns: Created room
    public func createRoom(roomId: String) async throws -> RTCRoom {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        // Check if user has room management permission
        guard hasPermission(.manageRoom) else {
            throw RealtimeError.insufficientPermissions(currentSession?.userRole ?? .audience)
        }
        
        return try await rtcProvider.createRoom(roomId: roomId)
    }
    
    /// Join a room with current user session
    /// - Parameters:
    ///   - roomId: Room identifier
    ///   - userRole: Optional role override for this room
    public func joinRoom(roomId: String, userRole: UserRole? = nil) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        let effectiveRole = userRole ?? session.userRole
        
        // Validate role permissions (需求 4.2)
        guard effectiveRole.hasAudioPermission || effectiveRole == .audience else {
            throw RealtimeError.insufficientPermissions(effectiveRole)
        }
        
        try await rtcProvider.joinRoom(roomId: roomId, userId: session.userId, userRole: effectiveRole)
        
        // Update session with room information (需求 4.4)
        let updatedSession = session.withRoom(roomId).withRole(effectiveRole)
        currentSession = updatedSession
        userSessionStorage.saveUserSession(updatedSession)
        
        // Configure audio based on role
        try await configureRolePermissions(effectiveRole)
        
        print("Joined room \(roomId) as \(session.userName) with role \(effectiveRole)")
    }
    
    /// Leave the current room
    public func leaveRoom() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        try await rtcProvider.leaveRoom()
        
        // Update session to remove room information
        let updatedSession = session.withRoom(nil)
        currentSession = updatedSession
        userSessionStorage.saveUserSession(updatedSession)
        
        print("Left room")
    }
    
    /// Switch user role in current room (需求 4.3)
    /// - Parameter newRole: New user role
    public func switchUserRole(_ newRole: UserRole) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        // Validate role transition (需求 4.2)
        guard session.userRole.canSwitchToRole.contains(newRole) else {
            throw RealtimeError.invalidRoleTransition(from: session.userRole, to: newRole)
        }
        
        try await rtcProvider.switchUserRole(newRole)
        
        // Update session with new role
        let updatedSession = session.withRole(newRole)
        currentSession = updatedSession
        userSessionStorage.saveUserSession(updatedSession)
        
        // Reconfigure permissions for new role
        try await configureRolePermissions(newRole)
        
        print("Switched to role: \(newRole)")
    }
    
    /// Get available role transitions for current user (需求 4.3)
    /// - Returns: Set of roles the user can switch to
    public func getAvailableRoleTransitions() -> Set<UserRole> {
        guard let session = currentSession else { return [] }
        return session.userRole.canSwitchToRole
    }
    
    // MARK: - Private Session Management Helpers
    
    private func configureRolePermissions(_ role: UserRole) async throws {
        guard let rtcProvider = rtcProvider else { return }
        
        // Configure audio permissions based on role
        if role.hasAudioPermission {
            try await rtcProvider.resumeLocalAudioStream()
        } else {
            try await rtcProvider.stopLocalAudioStream()
        }
        
        // Update audio settings to reflect role permissions
        if !role.hasAudioPermission {
            audioSettings = AudioSettings(
                microphoneMuted: true,
                audioMixingVolume: audioSettings.audioMixingVolume,
                playbackSignalVolume: audioSettings.playbackSignalVolume,
                recordingSignalVolume: audioSettings.recordingSignalVolume,
                localAudioStreamActive: false
            )
            audioSettingsStorage.saveAudioSettings(audioSettings)
        }
    }
    
    // MARK: - Audio Control (需求 5)
    
    /// Mute or unmute microphone (需求 5.1)
    /// - Parameter muted: True to mute, false to unmute
    public func muteMicrophone(_ muted: Bool) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.muteMicrophone(muted)
        
        audioSettings = AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: audioSettings.audioMixingVolume,
            playbackSignalVolume: audioSettings.playbackSignalVolume,
            recordingSignalVolume: audioSettings.recordingSignalVolume,
            localAudioStreamActive: audioSettings.localAudioStreamActive
        )
        
        audioSettingsStorage.saveAudioSettings(audioSettings)
    }
    
    /// Set audio mixing volume (需求 5.2)
    /// - Parameter volume: Volume level (0-100)
    public func setAudioMixingVolume(_ volume: Int) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setAudioMixingVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(audioMixing: clampedVolume)
        audioSettingsStorage.saveAudioSettings(audioSettings)
    }
    
    /// Set playback signal volume (需求 5.2)
    /// - Parameter volume: Volume level (0-100)
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setPlaybackSignalVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(playbackSignal: clampedVolume)
        audioSettingsStorage.saveAudioSettings(audioSettings)
    }
    
    /// Set recording signal volume (需求 5.2)
    /// - Parameter volume: Volume level (0-100)
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setRecordingSignalVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(recordingSignal: clampedVolume)
        audioSettingsStorage.saveAudioSettings(audioSettings)
    }
    
    /// Stop local audio stream (需求 5.3)
    public func stopLocalAudioStream() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.stopLocalAudioStream()
        
        audioSettings = AudioSettings(
            microphoneMuted: audioSettings.microphoneMuted,
            audioMixingVolume: audioSettings.audioMixingVolume,
            playbackSignalVolume: audioSettings.playbackSignalVolume,
            recordingSignalVolume: audioSettings.recordingSignalVolume,
            localAudioStreamActive: false
        )
        
        audioSettingsStorage.saveAudioSettings(audioSettings)
    }
    
    /// Resume local audio stream (需求 5.3)
    public func resumeLocalAudioStream() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.resumeLocalAudioStream()
        
        audioSettings = AudioSettings(
            microphoneMuted: audioSettings.microphoneMuted,
            audioMixingVolume: audioSettings.audioMixingVolume,
            playbackSignalVolume: audioSettings.playbackSignalVolume,
            recordingSignalVolume: audioSettings.recordingSignalVolume,
            localAudioStreamActive: true
        )
        
        audioSettingsStorage.saveAudioSettings(audioSettings)
    }
    
    // MARK: - Additional Audio Control Methods (需求 5)
    
    /// Get current microphone mute state
    /// - Returns: True if microphone is muted
    public func isMicrophoneMuted() -> Bool {
        return audioSettings.microphoneMuted
    }
    
    /// Get current audio mixing volume
    /// - Returns: Audio mixing volume (0-100)
    public func getAudioMixingVolume() -> Int {
        return audioSettings.audioMixingVolume
    }
    
    /// Get current playback signal volume
    /// - Returns: Playback signal volume (0-100)
    public func getPlaybackSignalVolume() -> Int {
        return audioSettings.playbackSignalVolume
    }
    
    /// Get current recording signal volume
    /// - Returns: Recording signal volume (0-100)
    public func getRecordingSignalVolume() -> Int {
        return audioSettings.recordingSignalVolume
    }
    
    /// Check if local audio stream is active
    /// - Returns: True if local audio stream is active
    public func isLocalAudioStreamActive() -> Bool {
        return audioSettings.localAudioStreamActive
    }
    
    /// Reset audio settings to default values (需求 5.5)
    public func resetAudioSettings() async throws {
        let defaultSettings = AudioSettings.default
        try await applyAudioSettings(defaultSettings)
        print("Audio settings reset to default")
    }
    
    /// Update multiple audio settings at once (需求 5.6)
    /// - Parameters:
    ///   - microphoneMuted: Optional microphone mute state
    ///   - audioMixingVolume: Optional audio mixing volume (0-100)
    ///   - playbackSignalVolume: Optional playback signal volume (0-100)
    ///   - recordingSignalVolume: Optional recording signal volume (0-100)
    ///   - localAudioStreamActive: Optional local audio stream state
    public func updateAudioSettings(
        microphoneMuted: Bool? = nil,
        audioMixingVolume: Int? = nil,
        playbackSignalVolume: Int? = nil,
        recordingSignalVolume: Int? = nil,
        localAudioStreamActive: Bool? = nil
    ) async throws {
        let newSettings = AudioSettings(
            microphoneMuted: microphoneMuted ?? audioSettings.microphoneMuted,
            audioMixingVolume: audioMixingVolume ?? audioSettings.audioMixingVolume,
            playbackSignalVolume: playbackSignalVolume ?? audioSettings.playbackSignalVolume,
            recordingSignalVolume: recordingSignalVolume ?? audioSettings.recordingSignalVolume,
            localAudioStreamActive: localAudioStreamActive ?? audioSettings.localAudioStreamActive
        )
        
        try await applyAudioSettings(newSettings)
    }
    
    /// Validate audio settings before applying (需求 5.4)
    /// - Parameter settings: Audio settings to validate
    /// - Returns: True if settings are valid
    public func validateAudioSettings(_ settings: AudioSettings) -> Bool {
        // Volume levels should be between 0 and 100
        guard settings.audioMixingVolume >= 0 && settings.audioMixingVolume <= 100 else {
            return false
        }
        
        guard settings.playbackSignalVolume >= 0 && settings.playbackSignalVolume <= 100 else {
            return false
        }
        
        guard settings.recordingSignalVolume >= 0 && settings.recordingSignalVolume <= 100 else {
            return false
        }
        
        return true
    }
    
    /// Get audio settings summary for debugging
    /// - Returns: Dictionary with current audio settings
    public func getAudioSettingsSummary() -> [String: Any] {
        return [
            "microphoneMuted": audioSettings.microphoneMuted,
            "audioMixingVolume": audioSettings.audioMixingVolume,
            "playbackSignalVolume": audioSettings.playbackSignalVolume,
            "recordingSignalVolume": audioSettings.recordingSignalVolume,
            "localAudioStreamActive": audioSettings.localAudioStreamActive,
            "lastModified": audioSettings.lastModified
        ]
    }
    
    // MARK: - Volume Indicator (需求 6)
    
    /// Enable volume indicator with configuration
    /// - Parameter config: Volume detection configuration
    public func enableVolumeIndicator(config: VolumeDetectionConfig = .default) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.enableVolumeIndicator(config: config)
    }
    
    /// Disable volume indicator
    public func disableVolumeIndicator() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.disableVolumeIndicator()
        volumeInfos = []
        speakingUsers = []
        dominantSpeaker = nil
    }
    
    // MARK: - Stream Push (需求 7)
    
    /// Start stream push
    /// - Parameter config: Stream push configuration
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.startStreamPush(config: config)
        streamPushState = .running
    }
    
    /// Stop stream push
    public func stopStreamPush() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.stopStreamPush()
        streamPushState = .stopped
    }
    
    // MARK: - Media Relay (需求 8)
    
    /// Start media relay
    /// - Parameter config: Media relay configuration
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.startMediaRelay(config: config)
        
        // Create destination states for all target channels
        var destinationStates: [String: RelayChannelState] = [:]
        for channel in config.destinationChannels {
            destinationStates[channel.channelName] = .connecting
        }
        
        mediaRelayState = MediaRelayState(
            overallState: .running,
            sourceChannel: config.sourceChannel.channelName,
            destinationStates: destinationStates,
            startTime: Date()
        )
    }
    
    /// Stop media relay
    public func stopMediaRelay() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtcProvider.stopMediaRelay()
        mediaRelayState = nil
    }
    
    // MARK: - Message Processing (需求 10)
    
    /// Send a message
    /// - Parameter message: Message to send
    public func sendMessage(_ message: RealtimeMessage) async throws {
        guard let rtmProvider = rtmProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        // Process message through pipeline first
        let processedMessage = try await messageProcessorManager.processMessage(message)
        
        if let finalMessage = processedMessage {
            try await rtmProvider.sendMessage(finalMessage)
        }
    }
    
    /// Register a message processor
    /// - Parameter processor: Message processor to register
    public func registerMessageProcessor(_ processor: MessageProcessor) {
        messageProcessorManager.registerProcessor(processor)
    }
    
    /// Subscribe to a channel
    /// - Parameter channel: Channel name
    public func subscribe(to channel: String) async throws {
        guard let rtmProvider = rtmProvider else {
            throw RealtimeError.providerNotInitialized(currentProvider ?? .mock)
        }
        
        try await rtmProvider.subscribe(to: channel)
    }
    
    // MARK: - Internal Methods
    
    internal func restoreSession(_ session: UserSession) async throws {
        currentSession = session
        userSessionStorage.saveUserSession(session)
    }
    
    internal func applyAudioSettings(_ settings: AudioSettings) async throws {
        guard let rtcProvider = rtcProvider else { return }
        
        try await rtcProvider.muteMicrophone(settings.microphoneMuted)
        try await rtcProvider.setAudioMixingVolume(settings.audioMixingVolume)
        try await rtcProvider.setPlaybackSignalVolume(settings.playbackSignalVolume)
        try await rtcProvider.setRecordingSignalVolume(settings.recordingSignalVolume)
        
        if settings.localAudioStreamActive {
            try await rtcProvider.resumeLocalAudioStream()
        } else {
            try await rtcProvider.stopLocalAudioStream()
        }
        
        audioSettings = settings
        audioSettingsStorage.saveAudioSettings(settings)
    }
    
    // MARK: - Connection Management (需求 13.2, 13.3)
    
    /// Get current connection state
    /// - Returns: Current overall connection state
    public func getConnectionState() -> ConnectionState {
        return connectionStateManager.overallConnectionState
    }
    
    /// Get detailed connection states
    /// - Returns: Tuple with RTC and RTM connection states
    public func getDetailedConnectionStates() -> (rtc: ConnectionState, rtm: ConnectionState) {
        return (
            rtc: connectionStateManager.rtcConnectionState,
            rtm: connectionStateManager.rtmConnectionState
        )
    }
    
    /// Check if currently connected
    /// - Returns: True if both RTC and RTM are connected
    public var isConnected: Bool {
        return connectionStateManager.isConnected
    }
    
    /// Check if currently reconnecting
    /// - Returns: True if reconnection is in progress
    public var isReconnecting: Bool {
        return connectionStateManager.isReconnecting
    }
    
    /// Get reconnection attempts count
    /// - Returns: Number of reconnection attempts made
    public var reconnectionAttempts: Int {
        return connectionStateManager.reconnectionAttempts
    }
    
    /// Manually trigger reconnection
    public func reconnect() async {
        await connectionStateManager.reconnect()
    }
    
    /// Cancel ongoing reconnection attempts
    public func cancelReconnection() {
        connectionStateManager.cancelReconnection()
    }
    
    /// Configure auto-reconnection settings
    /// - Parameters:
    ///   - enabled: Whether auto-reconnection is enabled
    ///   - maxAttempts: Maximum number of reconnection attempts
    ///   - baseDelay: Base delay between attempts
    ///   - maxDelay: Maximum delay between attempts
    public func configureAutoReconnection(
        enabled: Bool = true,
        maxAttempts: Int = 5,
        baseDelay: TimeInterval = 2.0,
        maxDelay: TimeInterval = 30.0
    ) {
        connectionStateManager.isAutoReconnectionEnabled = enabled
        connectionStateManager.maxReconnectionAttempts = maxAttempts
        connectionStateManager.baseReconnectionDelay = baseDelay
        connectionStateManager.maxReconnectionDelay = maxDelay
    }
    
    /// Get connection statistics
    /// - Returns: Connection statistics including uptime and reconnection info
    public func getConnectionStatistics() -> ConnectionStatistics {
        return connectionStateManager.connectionStats
    }
    
    /// Get connection history
    /// - Returns: Array of recent connection events
    public func getConnectionHistory() -> [ConnectionEvent] {
        return connectionStateManager.connectionHistory
    }
    
    /// Reset connection state and history
    public func resetConnectionState() {
        connectionStateManager.reset()
    }
    
    // MARK: - Error Management (需求 13.1, 13.4)
    
    /// Get recent errors
    /// - Returns: Array of recent error records
    public func getRecentErrors() -> [ErrorRecord] {
        return errorHandler.recentErrors
    }
    
    /// Get errors by category
    /// - Parameter category: Error category to filter by
    /// - Returns: Array of errors in the specified category
    public func getErrors(by category: ErrorCategory) -> [ErrorRecord] {
        return errorHandler.getErrors(by: category)
    }
    
    /// Get errors by severity
    /// - Parameter severity: Error severity to filter by
    /// - Returns: Array of errors with the specified severity
    public func getErrors(by severity: ErrorSeverity) -> [ErrorRecord] {
        return errorHandler.getErrors(by: severity)
    }
    
    /// Get error statistics
    /// - Returns: Error statistics including counts and recovery rates
    public func getErrorStatistics() -> ErrorStatistics {
        return errorHandler.errorStats
    }
    
    /// Clear error history
    public func clearErrorHistory() {
        errorHandler.clearErrorHistory()
    }
    
    /// Handle a custom error
    /// - Parameters:
    ///   - error: Error to handle
    ///   - context: Optional context information
    ///   - enableRecovery: Whether to attempt automatic recovery
    public func handleError(
        _ error: Error,
        context: String? = nil,
        enableRecovery: Bool = true
    ) async {
        await errorHandler.handleError(error, context: context, enableRecovery: enableRecovery)
    }
    
    // MARK: - Private Setup Methods
    
    private func setupBindings() {
        // Bind provider switch manager state
        providerSwitchManager.$currentProvider
            .assign(to: \.currentProvider, on: self)
            .store(in: &cancellables)
        
        providerSwitchManager.$switchingInProgress
            .assign(to: \.providerSwitchInProgress, on: self)
            .store(in: &cancellables)
        
        // Bind factory registry state
        factoryRegistry.$registeredFactories
            .map { Set($0.keys) }
            .assign(to: \.availableProviders, on: self)
            .store(in: &cancellables)
        
        // Update supported features when current provider changes
        $currentProvider
            .compactMap { [weak self] provider in
                guard let provider = provider else { return nil }
                return self?.factoryRegistry.getSupportedFeatures(for: provider)
            }
            .assign(to: \.supportedFeatures, on: self)
            .store(in: &cancellables)
        
        // Bind connection state manager
        connectionStateManager.$overallConnectionState
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        // Handle connection state changes
        connectionStateManager.onConnectionStateChanged = { [weak self] oldState, newState in
            Task { @MainActor in
                await self?.handleConnectionStateChange(from: oldState, to: newState)
            }
        }
        
        // Handle reconnection events
        connectionStateManager.onReconnectionAttempt = { attempt in
            Task { @MainActor in
                print("Reconnection attempt \(attempt)")
            }
        }
        
        connectionStateManager.onReconnectionSuccess = { [weak self] in
            Task { @MainActor in
                print("Reconnection successful")
                self?.lastError = nil
            }
        }
        
        connectionStateManager.onReconnectionFailed = { [weak self] error in
            Task { @MainActor in
                print("Reconnection failed: \(error)")
                await self?.errorHandler.handleError(error, context: "Reconnection")
            }
        }
    }
    
    private func setupDefaultProviders() {
        // Register default Agora provider factory
        let agoraFactory = AgoraProviderFactory()
        registerProviderFactory(agoraFactory)
        
        print("Default providers registered")
    }
    
    private func updateAvailableProviders() {
        availableProviders = factoryRegistry.getAvailableProviders()
    }
    
    private func setupTokenManagement() {
        rtcProvider?.onTokenWillExpire { [weak self] expiresIn in
            Task { @MainActor in
                await self?.tokenManager.handleTokenExpiration(
                    provider: self?.currentProvider ?? .mock,
                    expiresIn: expiresIn
                )
            }
        }
        
        rtmProvider?.onTokenWillExpire { [weak self] expiresIn in
            Task { @MainActor in
                await self?.tokenManager.handleTokenExpiration(
                    provider: self?.currentProvider ?? .mock,
                    expiresIn: expiresIn
                )
            }
        }
    }
    
    private func setupVolumeIndicator() {
        rtcProvider?.setVolumeIndicatorHandler { [weak self] volumeInfos in
            Task { @MainActor in
                self?.volumeIndicatorManager.processVolumeUpdate(volumeInfos)
                self?.volumeInfos = volumeInfos
                self?.speakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
                self?.dominantSpeaker = volumeInfos.filter { $0.isSpeaking }.max { $0.volume < $1.volume }?.userId
            }
        }
    }
    
    private func setupMessageProcessing() {
        rtmProvider?.setMessageHandler { [weak self] message in
            Task { @MainActor in
                do {
                    _ = try await self?.messageProcessorManager.processMessage(message)
                } catch {
                    print("Message processing failed: \(error)")
                }
            }
        }
    }
    
    private func setupConnectionStateHandling() {
        // Set up RTM connection state handling
        rtmProvider?.setConnectionStateHandler { [weak self] state in
            Task { @MainActor in
                self?.connectionStateManager.updateRTMConnectionState(state)
            }
        }
        
        // Set up RTC connection state handling (if provider supports it)
        // Note: This would need to be implemented in the RTCProvider protocol
        // For now, we'll simulate RTC connection state based on RTM state
        rtmProvider?.setConnectionStateHandler { [weak self] state in
            Task { @MainActor in
                // Simulate RTC state following RTM state
                self?.connectionStateManager.updateRTCConnectionState(state)
            }
        }
    }
    
    /// Handle connection state changes
    private func handleConnectionStateChange(from oldState: ConnectionState, to newState: ConnectionState) async {
        print("Connection state changed from \(oldState.displayName) to \(newState.displayName)")
        
        switch newState {
        case .connected:
            // Connection established
            lastError = nil
            
        case .disconnected:
            // Connection lost
            if oldState == .connected {
                let error = RealtimeError.connectionFailed("Connection lost")
                await errorHandler.handleError(error, context: "Connection State Change")
            }
            
        case .failed:
            // Connection failed
            let error = RealtimeError.connectionFailed("Connection failed")
            await errorHandler.handleError(error, context: "Connection State Change")
            
        case .connecting:
            // Connecting
            lastError = nil
            
        case .reconnecting:
            // Reconnecting
            print("Attempting to reconnect...")
        }
    }
    
    private func restorePersistedSettings() async {
        // Restore audio settings (需求 5.5)
        let restoredSettings = audioSettingsStorage.loadAudioSettings()
        audioSettings = restoredSettings
        
        // Restore user session (需求 3.5)
        if let session = userSessionStorage.loadUserSession() {
            currentSession = session
        }
        
        print("Restored persisted settings - Audio: \(restoredSettings), Session: \(currentSession?.userId ?? "none")")
    }
    
    /// Force save current audio settings (需求 5.4)
    public func saveAudioSettings() {
        audioSettingsStorage.saveAudioSettings(audioSettings)
    }
    
    /// Check if audio settings have been modified since last save
    /// - Returns: True if settings have been modified
    public func hasUnsavedAudioSettings() -> Bool {
        let savedSettings = audioSettingsStorage.loadAudioSettings()
        return savedSettings != audioSettings
    }
    
    /// Sync audio settings with provider after restoration (需求 5.6)
    private func syncAudioSettingsWithProvider() async throws {
        guard isInitialized else { return }
        
        do {
            try await applyAudioSettings(audioSettings)
            print("Audio settings synced with provider")
        } catch {
            print("Failed to sync audio settings with provider: \(error)")
            // Don't throw error here as this is a background sync operation
        }
    }
    
    private func cleanupCurrentProvider() async {
        do {
            try await rtcProvider?.leaveRoom()
        } catch {
            print("Error leaving room during provider cleanup: \(error)")
        }
        
        do {
            try await rtmProvider?.disconnect()
        } catch {
            print("Error disconnecting RTM during provider cleanup: \(error)")
        }
        
        rtcProvider = nil
        rtmProvider = nil
        isInitialized = false
        connectionState = .disconnected
        streamPushState = .stopped
        mediaRelayState = nil
        volumeInfos = []
        speakingUsers = []
        dominantSpeaker = nil
    }
    
    // MARK: - Error Handling and Recovery (需求 13)
    
    /// Clear the last error
    public func clearLastError() {
        lastError = nil
    }
    
    /// Retry the last failed operation
    public func retryLastOperation() async throws {
        guard let error = lastError else {
            throw RealtimeError.operationInProgress("No failed operation to retry")
        }
        
        guard error.isRecoverable else {
            throw RealtimeError.operationInProgress("Last error is not recoverable")
        }
        
        // Clear error and attempt to reconnect if needed
        lastError = nil
        
        if connectionState == .failed || connectionState == .disconnected {
            await reconnect()
        }
    }
    

    
    /// Get detailed system status
    public func getSystemStatus() -> RealtimeSystemStatus {
        return RealtimeSystemStatus(
            isInitialized: isInitialized,
            currentProvider: currentProvider,
            connectionState: connectionState,
            hasActiveSession: currentSession != nil,
            availableProviders: availableProviders,
            supportedFeatures: supportedFeatures,
            lastError: lastError,
            providerSwitchInProgress: providerSwitchInProgress
        )
    }
    
    // MARK: - SwiftUI Reactive Helpers (需求 11.3)
    
    /// Observe connection state changes with a callback
    /// - Parameter callback: Callback to execute when connection state changes
    /// - Returns: AnyCancellable for managing the subscription
    public func observeConnectionState(_ callback: @escaping (ConnectionState) -> Void) -> AnyCancellable {
        return connectionStatePublisher
            .sink(receiveValue: callback)
    }
    
    /// Observe audio settings changes with a callback
    /// - Parameter callback: Callback to execute when audio settings change
    /// - Returns: AnyCancellable for managing the subscription
    public func observeAudioSettings(_ callback: @escaping (AudioSettings) -> Void) -> AnyCancellable {
        return audioSettingsPublisher
            .sink(receiveValue: callback)
    }
    
    /// Observe speaking state changes with a callback
    /// - Parameter callback: Callback to execute when speaking users change
    /// - Returns: AnyCancellable for managing the subscription
    public func observeSpeakingUsers(_ callback: @escaping (Set<String>) -> Void) -> AnyCancellable {
        return speakingUsersPublisher
            .sink(receiveValue: callback)
    }
    
    /// Observe system readiness changes with a callback
    /// - Parameter callback: Callback to execute when system readiness changes
    /// - Returns: AnyCancellable for managing the subscription
    public func observeSystemReadiness(_ callback: @escaping (Bool) -> Void) -> AnyCancellable {
        return systemReadinessPublisher
            .sink(receiveValue: callback)
    }
    
    /// Create a debounced publisher for volume updates to reduce UI update frequency
    /// - Parameter interval: Debounce interval in seconds
    /// - Returns: Debounced volume publisher
    public func debouncedVolumePublisher(interval: TimeInterval = 0.1) -> AnyPublisher<[UserVolumeInfo], Never> {
        return volumeInfosPublisher
            .debounce(for: .seconds(interval), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Create a throttled publisher for frequent state updates
    /// - Parameter interval: Throttle interval in seconds
    /// - Returns: Throttled audio state publisher
    public func throttledAudioStatePublisher(interval: TimeInterval = 0.05) -> AnyPublisher<AudioStateSummary, Never> {
        return audioStateSummaryPublisher
            .throttle(for: .seconds(interval), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    /// Combine multiple state publishers for comprehensive UI updates
    /// - Returns: Combined state publisher
    public func combinedStatePublisher() -> AnyPublisher<RealtimeSystemStatus, Never> {
        return Publishers.CombineLatest4(
            $isInitialized,
            $connectionState,
            $currentSession,
            $lastError
        )
        .map { [weak self] isInitialized, connectionState, currentSession, lastError in
            guard let self = self else {
                return RealtimeSystemStatus(
                    isInitialized: false,
                    currentProvider: nil,
                    connectionState: .disconnected,
                    hasActiveSession: false,
                    availableProviders: [],
                    supportedFeatures: [],
                    lastError: nil,
                    providerSwitchInProgress: false
                )
            }
            
            return RealtimeSystemStatus(
                isInitialized: isInitialized,
                currentProvider: self.currentProvider,
                connectionState: connectionState,
                hasActiveSession: currentSession != nil,
                availableProviders: self.availableProviders,
                supportedFeatures: self.supportedFeatures,
                lastError: lastError,
                providerSwitchInProgress: self.providerSwitchInProgress
            )
        }
        .eraseToAnyPublisher()
    }
}

/// System status information
public struct RealtimeSystemStatus {
    public let isInitialized: Bool
    public let currentProvider: ProviderType?
    public let connectionState: ConnectionState
    public let hasActiveSession: Bool
    public let availableProviders: Set<ProviderType>
    public let supportedFeatures: Set<ProviderFeature>
    public let lastError: RealtimeError?
    public let providerSwitchInProgress: Bool
    
    /// Whether the system is ready for operations
    public var isReady: Bool {
        return isInitialized && connectionState.isActive && !providerSwitchInProgress
    }
    
    /// Whether the system has any issues
    public var hasIssues: Bool {
        return lastError != nil || connectionState == .failed || connectionState == .disconnected
    }
}

/// Audio state summary for reactive UI updates
public struct AudioStateSummary: Equatable {
    public let isMuted: Bool
    public let isStreamActive: Bool
    public let mixingVolume: Int
    public let playbackVolume: Int
    public let recordingVolume: Int
    
    public init(
        isMuted: Bool,
        isStreamActive: Bool,
        mixingVolume: Int,
        playbackVolume: Int,
        recordingVolume: Int
    ) {
        self.isMuted = isMuted
        self.isStreamActive = isStreamActive
        self.mixingVolume = mixingVolume
        self.playbackVolume = playbackVolume
        self.recordingVolume = recordingVolume
    }
    
    /// Whether audio is effectively enabled (not muted and stream active)
    public var isAudioEnabled: Bool {
        return !isMuted && isStreamActive
    }
    
    /// Average volume level across all volume controls
    public var averageVolume: Int {
        return (mixingVolume + playbackVolume + recordingVolume) / 3
    }
}