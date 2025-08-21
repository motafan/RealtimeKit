// RealtimeMocking.swift
// Mock provider implementation for testing RealtimeKit

import Foundation
import RealtimeCore

/// RealtimeMocking version information
public struct RealtimeMockingVersion {
    public static let current = "1.0.0"
    public static let build = "1"
}

/// Mock RTC provider for testing
public final class MockRTCProvider: RTCProvider, @unchecked Sendable {
    
    // MARK: - Mock State
    public var isInitialized = false
    public var currentConfig: RTCConfig?
    public var currentRoom: RTCRoom?
    public var microphoneMuted = false
    public var localAudioStreamActive = true
    public var audioMixingVolume = 100
    public var playbackSignalVolume = 100
    public var recordingSignalVolume = 100
    public var volumeIndicatorEnabled = false
    public var streamPushActive = false
    public var mediaRelayActive = false
    
    // MARK: - Mock Handlers
    public var volumeIndicatorHandler: (@Sendable ([UserVolumeInfo]) -> Void)?
    public var volumeEventHandler: (@Sendable (VolumeEvent) -> Void)?
    public var tokenExpirationHandler: (@Sendable (Int) -> Void)?
    
    // MARK: - Mock Configuration
    public var shouldFailInitialization = false
    public var shouldFailRoomOperations = false
    public var shouldFailAudioOperations = false
    public var simulateTokenExpiration = false
    
    public init() {}
    
    // MARK: - RTCProvider Implementation
    
    public func initialize(config: RTCConfig) async throws {
        if shouldFailInitialization {
            throw RealtimeError.providerInitializationFailed(.mock, "Mock initialization failure")
        }
        
        currentConfig = config
        isInitialized = true
        print("MockRTCProvider initialized with config: \(config.appId)")
    }
    
    public func createRoom(roomId: String) async throws -> RTCRoom {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailRoomOperations {
            throw RealtimeError.roomCreationFailed("Mock room creation failure")
        }
        
        let room = RTCRoom(roomId: roomId, roomName: "Mock Room \(roomId)")
        currentRoom = room
        return room
    }
    
    public func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailRoomOperations {
            throw RealtimeError.roomJoinFailed("Mock room join failure")
        }
        
        currentRoom = RTCRoom(roomId: roomId)
        print("Mock: Joined room \(roomId) as \(userId) with role \(userRole)")
    }
    
    public func joinChannel(channelName: String, userId: String, userRole: UserRole) async throws {
        // Delegate to joinRoom for compatibility
        try await joinRoom(roomId: channelName, userId: userId, userRole: userRole)
    }
    
    public func leaveRoom() async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailRoomOperations {
            throw RealtimeError.roomLeaveFailed("Mock room leave failure")
        }
        
        currentRoom = nil
        print("Mock: Left room")
    }
    
    public func switchUserRole(_ role: UserRole) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        print("Mock: Switched to role \(role)")
    }
    
    // MARK: - Audio Stream Control
    
    public func muteMicrophone(_ muted: Bool) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailAudioOperations {
            throw RealtimeError.audioControlFailed("Mock microphone control failure")
        }
        
        microphoneMuted = muted
        print("Mock: Microphone muted: \(muted)")
    }
    
    public func isMicrophoneMuted() -> Bool {
        return microphoneMuted
    }
    
    public func stopLocalAudioStream() async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailAudioOperations {
            throw RealtimeError.audioStreamControlFailed("Mock audio stream control failure")
        }
        
        localAudioStreamActive = false
        print("Mock: Stopped local audio stream")
    }
    
    public func resumeLocalAudioStream() async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailAudioOperations {
            throw RealtimeError.audioStreamControlFailed("Mock audio stream control failure")
        }
        
        localAudioStreamActive = true
        print("Mock: Resumed local audio stream")
    }
    
    public func isLocalAudioStreamActive() -> Bool {
        return localAudioStreamActive
    }
    
    // MARK: - Volume Control
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        audioMixingVolume = max(0, min(100, volume))
        print("Mock: Set audio mixing volume: \(audioMixingVolume)")
    }
    
    public func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        playbackSignalVolume = max(0, min(100, volume))
        print("Mock: Set playback signal volume: \(playbackSignalVolume)")
    }
    
    public func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        recordingSignalVolume = max(0, min(100, volume))
        print("Mock: Set recording signal volume: \(recordingSignalVolume)")
    }
    
    public func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    // MARK: - Stream Push
    
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        streamPushActive = true
        print("Mock: Started stream push to: \(config.pushUrl)")
    }
    
    public func stopStreamPush() async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        streamPushActive = false
        print("Mock: Stopped stream push")
    }
    
    public func updateStreamPushLayout(layout: StreamLayout) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        print("Mock: Updated stream push layout")
    }
    
    // MARK: - Media Relay
    
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        mediaRelayActive = true
        print("Mock: Started media relay")
    }
    
    public func stopMediaRelay() async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        mediaRelayActive = false
        print("Mock: Stopped media relay")
    }
    
    public func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        print("Mock: Updated media relay channels")
    }
    
    public func pauseMediaRelay(toChannel: String) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        print("Mock: Paused media relay to channel: \(toChannel)")
    }
    
    public func resumeMediaRelay(toChannel: String) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        print("Mock: Resumed media relay to channel: \(toChannel)")
    }
    
    // MARK: - Volume Indicator
    
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        volumeIndicatorEnabled = true
        print("Mock: Enabled volume indicator")
        
        // Simulate volume updates
        simulateVolumeUpdates()
    }
    
    public func disableVolumeIndicator() async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        volumeIndicatorEnabled = false
        print("Mock: Disabled volume indicator")
    }
    
    public func setVolumeIndicatorHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void) {
        volumeIndicatorHandler = handler
        print("Mock: Set volume indicator handler")
    }
    
    public func setVolumeEventHandler(_ handler: @escaping @Sendable (VolumeEvent) -> Void) {
        volumeEventHandler = handler
        print("Mock: Set volume event handler")
    }
    
    public func getCurrentVolumeInfos() -> [UserVolumeInfo] {
        return [
            UserVolumeInfo(userId: "mock_user_1", volume: 0.5, isSpeaking: true),
            UserVolumeInfo(userId: "mock_user_2", volume: 0.2, isSpeaking: false)
        ]
    }
    
    public func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return getCurrentVolumeInfos().first { $0.userId == userId }
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        print("Mock: Renewed token: \(newToken)")
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {
        tokenExpirationHandler = handler
        print("Mock: Set token expiration handler")
        
        if simulateTokenExpiration {
            // Simulate token expiration in 5 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                handler(30) // 30 seconds until expiration
            }
        }
    }
    
    // MARK: - Mock Utilities
    
    /// Simulate volume updates for testing
    private func simulateVolumeUpdates() {
        guard volumeIndicatorEnabled else { return }
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            guard let self = self, self.volumeIndicatorEnabled else { return }
            
            let volumeInfos = [
                UserVolumeInfo(userId: "mock_user_1", volume: Float.random(in: 0.3...0.8), isSpeaking: true),
                UserVolumeInfo(userId: "mock_user_2", volume: Float.random(in: 0.0...0.2), isSpeaking: false)
            ]
            
            self.volumeIndicatorHandler?(volumeInfos)
            self.simulateVolumeUpdates() // Continue simulation
        }
    }
    
    /// Trigger mock token expiration
    public func triggerTokenExpiration() {
        tokenExpirationHandler?(30)
    }
    
    /// Reset mock state
    public func reset() {
        isInitialized = false
        currentConfig = nil
        currentRoom = nil
        microphoneMuted = false
        localAudioStreamActive = true
        audioMixingVolume = 100
        playbackSignalVolume = 100
        recordingSignalVolume = 100
        volumeIndicatorEnabled = false
        streamPushActive = false
        mediaRelayActive = false
        shouldFailInitialization = false
        shouldFailRoomOperations = false
        shouldFailAudioOperations = false
        simulateTokenExpiration = false
    }
}

/// Mock RTM provider for testing
public final class MockRTMProvider: RTMProvider, @unchecked Sendable {
    
    // MARK: - Mock State
    public var isInitialized = false
    public var currentConfig: RTMConfig?
    public var subscribedChannels: Set<String> = []
    public var connectionState: ConnectionState = .disconnected
    
    // MARK: - Mock Handlers
    public var messageHandler: (@Sendable (RealtimeMessage) -> Void)?
    public var connectionStateHandler: (@Sendable (ConnectionState) -> Void)?
    public var tokenExpirationHandler: (@Sendable (Int) -> Void)?
    
    // MARK: - Mock Configuration
    public var shouldFailInitialization = false
    public var shouldFailMessageOperations = false
    public var simulateTokenExpiration = false
    
    public init() {}
    
    // MARK: - RTMProvider Implementation
    
    public func initialize(config: RTMConfig) async throws {
        if shouldFailInitialization {
            throw RealtimeError.providerInitializationFailed(.mock, "Mock RTM initialization failure")
        }
        
        currentConfig = config
        isInitialized = true
        connectionState = .connected
        print("MockRTMProvider initialized with config: \(config.appId)")
    }
    
    public func sendMessage(_ message: RealtimeMessage) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailMessageOperations {
            throw RealtimeError.messageSendFailed("Mock message send failure")
        }
        
        print("Mock RTM: Sent message: \(message.content)")
        
        // Simulate message echo for testing
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            let echoMessage = RealtimeMessage.text(
                "Echo: \(message.content)",
                from: "mock_echo_user",
                senderName: "Mock Echo",
                in: message.channelId
            )
            self?.messageHandler?(echoMessage)
        }
    }
    
    public func subscribe(to channel: String) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        if shouldFailMessageOperations {
            throw RealtimeError.messageSubscriptionFailed("Mock subscription failure")
        }
        
        subscribedChannels.insert(channel)
        print("Mock RTM: Subscribed to channel: \(channel)")
    }
    
    public func unsubscribe(from channel: String) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        subscribedChannels.remove(channel)
        print("Mock RTM: Unsubscribed from channel: \(channel)")
    }
    
    public func setMessageHandler(_ handler: @escaping @Sendable (RealtimeMessage) -> Void) {
        messageHandler = handler
        print("Mock RTM: Set message handler")
    }
    
    public func setConnectionStateHandler(_ handler: @escaping @Sendable (ConnectionState) -> Void) {
        connectionStateHandler = handler
        print("Mock RTM: Set connection state handler")
    }
    
    public func processIncomingMessage(_ rawMessage: Any) async throws -> RealtimeMessage {
        // Mock message processing
        if let messageDict = rawMessage as? [String: Any],
           let content = messageDict["content"] as? String,
           let senderId = messageDict["senderId"] as? String {
            return RealtimeMessage.text(content, from: senderId)
        }
        
        return RealtimeMessage.system("Processed mock message")
    }
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.mock)
        }
        
        print("Mock RTM: Renewed token: \(newToken)")
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {
        tokenExpirationHandler = handler
        print("Mock RTM: Set token expiration handler")
        
        if simulateTokenExpiration {
            // Simulate token expiration in 5 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                handler(30) // 30 seconds until expiration
            }
        }
    }
    
    public func getConnectionState() -> ConnectionState {
        return connectionState
    }
    
    public func reconnect() async throws {
        connectionState = .connecting
        connectionStateHandler?(.connecting)
        
        // Simulate reconnection delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        connectionState = .connected
        connectionStateHandler?(.connected)
        print("Mock RTM: Reconnected")
    }
    
    public func disconnect() async throws {
        connectionState = .disconnected
        connectionStateHandler?(.disconnected)
        isInitialized = false
        subscribedChannels.removeAll()
        print("Mock RTM: Disconnected")
    }
    
    // MARK: - Mock Utilities
    
    /// Simulate incoming message
    public func simulateIncomingMessage(_ message: RealtimeMessage) {
        messageHandler?(message)
    }
    
    /// Simulate connection state change
    public func simulateConnectionStateChange(_ state: ConnectionState) {
        connectionState = state
        connectionStateHandler?(state)
    }
    
    /// Trigger mock token expiration
    public func triggerTokenExpiration() {
        tokenExpirationHandler?(30)
    }
    
    /// Reset mock state
    public func reset() {
        isInitialized = false
        currentConfig = nil
        subscribedChannels.removeAll()
        connectionState = .disconnected
        shouldFailInitialization = false
        shouldFailMessageOperations = false
        simulateTokenExpiration = false
    }
}

// MARK: - Mock Provider Factory

/// Mock provider factory for testing
public final class MockProviderFactory: ProviderFactory, @unchecked Sendable {
    public let providerType: ProviderType = .mock
    
    public init() {}
    
    public func createRTCProvider() -> RTCProvider {
        return MockRTCProvider()
    }
    
    public func createRTMProvider() -> RTMProvider {
        return MockRTMProvider()
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return Set(ProviderFeature.allCases) // Mock supports all features
    }
}

// MARK: - Convenience Registration

public extension RealtimeManager {
    
    /// Register mock provider factory for testing
    func registerMockProvider() {
        registerProviderFactory(MockProviderFactory())
    }
}