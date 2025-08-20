// RTCProvider.swift
// Core RTC (Real-Time Communication) provider protocol

import Foundation

/// Protocol defining the interface for RTC service providers
public protocol RTCProvider: AnyObject, Sendable {
    
    // MARK: - Lifecycle Management
    
    /// Initialize the RTC provider with configuration
    /// - Parameter config: RTC configuration settings
    func initialize(config: RTCConfig) async throws
    
    /// Create a new room
    /// - Parameter roomId: Unique identifier for the room
    /// - Returns: RTCRoom instance
    func createRoom(roomId: String) async throws -> RTCRoom
    
    /// Join an existing room
    /// - Parameters:
    ///   - roomId: Room identifier to join
    ///   - userId: User identifier
    ///   - userRole: User role in the room
    func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws
    
    /// Leave the current room
    func leaveRoom() async throws
    
    /// Switch user role in the current room
    /// - Parameter role: New user role
    func switchUserRole(_ role: UserRole) async throws
    
    // MARK: - Audio Stream Control
    
    /// Mute or unmute the microphone
    /// - Parameter muted: True to mute, false to unmute
    func muteMicrophone(_ muted: Bool) async throws
    
    /// Check if microphone is currently muted
    /// - Returns: True if muted, false otherwise
    func isMicrophoneMuted() -> Bool
    
    /// Stop local audio stream
    func stopLocalAudioStream() async throws
    
    /// Resume local audio stream
    func resumeLocalAudioStream() async throws
    
    /// Check if local audio stream is active
    /// - Returns: True if active, false otherwise
    func isLocalAudioStreamActive() -> Bool
    
    // MARK: - Volume Control
    
    /// Set audio mixing volume
    /// - Parameter volume: Volume level (0-100)
    func setAudioMixingVolume(_ volume: Int) async throws
    
    /// Get current audio mixing volume
    /// - Returns: Current volume level (0-100)
    func getAudioMixingVolume() -> Int
    
    /// Set playback signal volume
    /// - Parameter volume: Volume level (0-100)
    func setPlaybackSignalVolume(_ volume: Int) async throws
    
    /// Get current playback signal volume
    /// - Returns: Current volume level (0-100)
    func getPlaybackSignalVolume() -> Int
    
    /// Set recording signal volume
    /// - Parameter volume: Volume level (0-100)
    func setRecordingSignalVolume(_ volume: Int) async throws
    
    /// Get current recording signal volume
    /// - Returns: Current volume level (0-100)
    func getRecordingSignalVolume() -> Int
    
    // MARK: - Stream Push (转推流)
    
    /// Start stream push to external platform
    /// - Parameter config: Stream push configuration
    func startStreamPush(config: StreamPushConfig) async throws
    
    /// Stop current stream push
    func stopStreamPush() async throws
    
    /// Update stream push layout
    /// - Parameter layout: New stream layout configuration
    func updateStreamPushLayout(layout: StreamLayout) async throws
    
    // MARK: - Media Relay (跨媒体流中继)
    
    /// Start media relay to other channels
    /// - Parameter config: Media relay configuration
    func startMediaRelay(config: MediaRelayConfig) async throws
    
    /// Stop media relay
    func stopMediaRelay() async throws
    
    /// Update media relay channels
    /// - Parameter config: Updated media relay configuration
    func updateMediaRelayChannels(config: MediaRelayConfig) async throws
    
    /// Pause media relay to specific channel
    /// - Parameter toChannel: Target channel to pause
    func pauseMediaRelay(toChannel: String) async throws
    
    /// Resume media relay to specific channel
    /// - Parameter toChannel: Target channel to resume
    func resumeMediaRelay(toChannel: String) async throws
    
    // MARK: - Volume Indicator (音量指示器)
    
    /// Enable volume indicator with configuration
    /// - Parameter config: Volume detection configuration
    func enableVolumeIndicator(config: VolumeDetectionConfig) async throws
    
    /// Disable volume indicator
    func disableVolumeIndicator() async throws
    
    /// Set volume indicator update handler
    /// - Parameter handler: Callback for volume updates
    func setVolumeIndicatorHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void)
    
    /// Set volume event handler for speaking state changes
    /// - Parameter handler: Callback for volume events
    func setVolumeEventHandler(_ handler: @escaping @Sendable (VolumeEvent) -> Void)
    
    /// Get current volume information for all users
    /// - Returns: Array of user volume information
    func getCurrentVolumeInfos() -> [UserVolumeInfo]
    
    /// Get volume information for specific user
    /// - Parameter userId: User identifier
    /// - Returns: User volume information if available
    func getVolumeInfo(for userId: String) -> UserVolumeInfo?
    
    // MARK: - Token Management
    
    /// Renew authentication token
    /// - Parameter newToken: New authentication token
    func renewToken(_ newToken: String) async throws
    
    /// Set token expiration handler
    /// - Parameter handler: Callback when token will expire (seconds remaining)
    func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void)
}