// MediaRelayManager.swift
// Media relay management for cross-channel streaming

import Foundation
import Combine

/// Media relay manager for cross-channel streaming (需求 8.2, 8.3, 8.5, 8.6)
@MainActor
public class MediaRelayManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var currentState: MediaRelayState?
    @Published public private(set) var currentConfig: MediaRelayConfig?
    @Published public private(set) var statistics: MediaRelayStatistics = MediaRelayStatistics()
    @Published public private(set) var isRelayActive: Bool = false
    
    // MARK: - Private Properties
    private var rtcProvider: RTCProvider?
    private var statisticsTimer: Timer?
    private var stateUpdateHandlers: [(MediaRelayState) -> Void] = []
    private var statisticsUpdateHandlers: [(MediaRelayStatistics) -> Void] = []
    
    // MARK: - Initialization
    public init() {
        setupStatisticsTimer()
    }
    
    deinit {
        // Timer will be invalidated when the manager is deallocated
        // No need to explicitly invalidate here due to Sendable constraints
    }
    
    /// Cleanup resources and stop timers
    public func cleanup() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }
    
    // MARK: - Configuration
    
    /// Configure the media relay manager with an RTC provider
    /// - Parameter provider: RTC provider instance
    public func configure(with provider: RTCProvider) {
        self.rtcProvider = provider
    }
    
    // MARK: - Relay Control (需求 8.2)
    
    /// Start media relay with the specified configuration
    /// - Parameter config: Media relay configuration
    /// - Throws: RealtimeError if relay cannot be started
    public func startRelay(config: MediaRelayConfig) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        // Validate configuration
        try config.validate()
        
        // Update state to connecting
        updateState(.init(
            overallState: .connecting,
            sourceChannel: config.sourceChannel.channelName,
            destinationStates: Dictionary(
                uniqueKeysWithValues: config.destinationChannels.map { 
                    ($0.channelName, RelayChannelState.connecting) 
                }
            ),
            startTime: Date()
        ))
        
        do {
            // Start relay through provider
            try await rtcProvider.startMediaRelay(config: config)
            
            // Update configuration and state
            currentConfig = config
            isRelayActive = true
            
            // Initialize statistics
            resetStatistics(for: config)
            
            // Update state to running
            updateState(.init(
                overallState: .running,
                sourceChannel: config.sourceChannel.channelName,
                destinationStates: Dictionary(
                    uniqueKeysWithValues: config.destinationChannels.map { 
                        ($0.channelName, RelayChannelState.connected) 
                    }
                ),
                startTime: currentState?.startTime ?? Date()
            ))
            
        } catch {
            // Update state to failure
            updateState(.init(
                overallState: .failure(MediaRelayError.sourceChannelConnectionFailed),
                sourceChannel: config.sourceChannel.channelName,
                destinationStates: Dictionary(
                    uniqueKeysWithValues: config.destinationChannels.map { 
                        ($0.channelName, RelayChannelState.failure(MediaRelayError.destinationConnectionFailed)) 
                    }
                ),
                startTime: nil
            ))
            
            throw RealtimeError.mediaRelayStartFailed(error.localizedDescription)
        }
    }
    
    /// Stop the current media relay
    /// - Throws: RealtimeError if relay cannot be stopped
    public func stopRelay() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isRelayActive else {
            return // Already stopped
        }
        
        do {
            // Stop relay through provider
            try await rtcProvider.stopMediaRelay()
            
            // Update state
            updateState(.init(
                overallState: .stopped,
                sourceChannel: currentState?.sourceChannel ?? "",
                destinationStates: [:],
                startTime: nil
            ))
            
            // Reset configuration and flags
            currentConfig = nil
            isRelayActive = false
            
        } catch {
            throw RealtimeError.mediaRelayStopFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Channel Management (需求 8.4)
    
    /// Add a destination channel to the current relay
    /// - Parameter channel: Channel information to add
    /// - Throws: RealtimeError if channel cannot be added
    public func addDestinationChannel(_ channel: RelayChannelInfo) async throws {
        guard let currentConfig = currentConfig else {
            throw RealtimeError.invalidMediaRelayConfig("No active relay configuration")
        }
        
        guard isRelayActive else {
            throw RealtimeError.invalidMediaRelayConfig("Relay is not active")
        }
        
        // Validate channel
        try channel.validate()
        
        // Check if channel already exists
        if currentConfig.destinationChannel(named: channel.channelName) != nil {
            throw RealtimeError.invalidMediaRelayConfig("Channel '\(channel.channelName)' already exists")
        }
        
        do {
            // Create updated configuration
            let updatedConfig = try currentConfig.addingDestination(channel)
            
            // Update relay through provider
            try await rtcProvider?.updateMediaRelayChannels(config: updatedConfig)
            
            // Update local configuration
            self.currentConfig = updatedConfig
            
            // Update state with new channel
            if let currentState = currentState {
                let updatedState = currentState.updatingDestination(
                    channel.channelName, 
                    state: .connecting
                )
                updateState(updatedState)
            }
            
        } catch {
            throw RealtimeError.mediaRelayUpdateFailed("Failed to add channel: \(error.localizedDescription)")
        }
    }
    
    /// Remove a destination channel from the current relay
    /// - Parameter channelName: Name of the channel to remove
    /// - Throws: RealtimeError if channel cannot be removed
    public func removeDestinationChannel(_ channelName: String) async throws {
        guard let currentConfig = currentConfig else {
            throw RealtimeError.invalidMediaRelayConfig("No active relay configuration")
        }
        
        guard isRelayActive else {
            throw RealtimeError.invalidMediaRelayConfig("Relay is not active")
        }
        
        // Check if channel exists
        guard currentConfig.destinationChannel(named: channelName) != nil else {
            throw RealtimeError.relayChannelNotFound(channelName)
        }
        
        do {
            // Create updated configuration
            let updatedConfig = try currentConfig.removingDestination(named: channelName)
            
            // Update relay through provider
            try await rtcProvider?.updateMediaRelayChannels(config: updatedConfig)
            
            // Update local configuration
            self.currentConfig = updatedConfig
            
            // Update state by removing channel
            if let currentState = currentState {
                var newDestinationStates = currentState.destinationStates
                newDestinationStates.removeValue(forKey: channelName)
                
                let updatedState = MediaRelayState(
                    overallState: currentState.overallState,
                    sourceChannel: currentState.sourceChannel,
                    destinationStates: newDestinationStates,
                    startTime: currentState.startTime
                )
                updateState(updatedState)
            }
            
        } catch {
            throw RealtimeError.mediaRelayUpdateFailed("Failed to remove channel: \(error.localizedDescription)")
        }
    }
    
    /// Pause relay to a specific destination channel (需求 8.5)
    /// - Parameter channelName: Name of the channel to pause
    /// - Throws: RealtimeError if channel cannot be paused
    public func pauseRelayToChannel(_ channelName: String) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isRelayActive else {
            throw RealtimeError.invalidMediaRelayConfig("Relay is not active")
        }
        
        guard let currentConfig = currentConfig,
              currentConfig.destinationChannel(named: channelName) != nil else {
            throw RealtimeError.relayChannelNotFound(channelName)
        }
        
        do {
            // Pause relay through provider
            try await rtcProvider.pauseMediaRelay(toChannel: channelName)
            
            // Update state
            if let currentState = currentState {
                let updatedState = currentState.updatingDestination(channelName, state: .paused)
                updateState(updatedState)
            }
            
        } catch {
            throw RealtimeError.mediaRelayPauseFailed("Failed to pause channel '\(channelName)': \(error.localizedDescription)")
        }
    }
    
    /// Resume relay to a specific destination channel (需求 8.5)
    /// - Parameter channelName: Name of the channel to resume
    /// - Throws: RealtimeError if channel cannot be resumed
    public func resumeRelayToChannel(_ channelName: String) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isRelayActive else {
            throw RealtimeError.invalidMediaRelayConfig("Relay is not active")
        }
        
        guard let currentConfig = currentConfig,
              currentConfig.destinationChannel(named: channelName) != nil else {
            throw RealtimeError.relayChannelNotFound(channelName)
        }
        
        do {
            // Resume relay through provider
            try await rtcProvider.resumeMediaRelay(toChannel: channelName)
            
            // Update state
            if let currentState = currentState {
                let updatedState = currentState.updatingDestination(channelName, state: .connected)
                updateState(updatedState)
            }
            
        } catch {
            throw RealtimeError.mediaRelayResumeFailed("Failed to resume channel '\(channelName)': \(error.localizedDescription)")
        }
    }
    
    // MARK: - State Management (需求 8.3)
    
    /// Update the current relay state
    /// - Parameter newState: New relay state
    private func updateState(_ newState: MediaRelayState) {
        currentState = newState
        
        // Notify handlers
        for handler in stateUpdateHandlers {
            handler(newState)
        }
    }
    
    /// Add a state update handler
    /// - Parameter handler: Handler to call when state changes
    public func addStateUpdateHandler(_ handler: @escaping (MediaRelayState) -> Void) {
        stateUpdateHandlers.append(handler)
    }
    
    /// Handle state update from provider
    /// - Parameters:
    ///   - channelName: Name of the channel that changed state
    ///   - newState: New state for the channel
    public func handleChannelStateUpdate(_ channelName: String, newState: RelayChannelState) {
        guard let currentState = currentState else { return }
        
        let updatedState = currentState.updatingDestination(channelName, state: newState)
        updateState(updatedState)
    }
    
    // MARK: - Statistics Management (需求 8.6)
    
    /// Get current relay statistics
    /// - Returns: Current MediaRelayStatistics
    public func getStatistics() -> MediaRelayStatistics {
        return statistics
    }
    
    /// Add a statistics update handler
    /// - Parameter handler: Handler to call when statistics are updated
    public func addStatisticsUpdateHandler(_ handler: @escaping (MediaRelayStatistics) -> Void) {
        statisticsUpdateHandlers.append(handler)
    }
    
    /// Update relay statistics
    /// - Parameter newStats: New statistics data
    public func updateStatistics(_ newStats: MediaRelayStatistics) {
        statistics = newStats
        
        // Notify handlers
        for handler in statisticsUpdateHandlers {
            handler(newStats)
        }
    }
    
    /// Reset statistics for a new relay configuration
    /// - Parameter config: Relay configuration
    private func resetStatistics(for config: MediaRelayConfig) {
        let destinationStats: [String: RelayChannelStatistics] = Dictionary(
            uniqueKeysWithValues: config.destinationChannels.map { channel in
                (channel.channelName, RelayChannelStatistics(channelName: channel.channelName))
            }
        )
        
        statistics = MediaRelayStatistics(
            destinationStats: destinationStats
        )
    }
    
    /// Setup periodic statistics updates
    private func setupStatisticsTimer() {
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateStatisticsFromProvider()
            }
        }
    }
    
    /// Update statistics from provider
    private func updateStatisticsFromProvider() async {
        guard isRelayActive,
              let currentState = currentState,
              let startTime = currentState.startTime else {
            return
        }
        
        // Calculate total relay time
        let totalRelayTime = Date().timeIntervalSince(startTime)
        
        // Create updated statistics (in a real implementation, this would come from the provider)
        let updatedStats = MediaRelayStatistics(
            totalRelayTime: totalRelayTime,
            audioBytesSent: statistics.audioBytesSent,
            videoBytesSent: statistics.videoBytesSent,
            packetsLost: statistics.packetsLost,
            averageLatency: statistics.averageLatency,
            destinationStats: statistics.destinationStats
        )
        
        updateStatistics(updatedStats)
    }
    
    // MARK: - Utility Methods
    
    /// Check if relay is active for a specific channel
    /// - Parameter channelName: Name of the channel to check
    /// - Returns: True if relay is active for the channel
    public func isRelayActive(for channelName: String) -> Bool {
        guard let currentState = currentState else { return false }
        
        if let channelState = currentState.stateForDestination(channelName) {
            return channelState.isActive
        }
        
        return false
    }
    
    /// Get list of all destination channels
    /// - Returns: Array of destination channel names
    public func getDestinationChannels() -> [String] {
        return currentConfig?.destinationChannels.map { $0.channelName } ?? []
    }
    
    /// Get relay configuration for a specific channel
    /// - Parameter channelName: Name of the channel
    /// - Returns: RelayChannelInfo if found, nil otherwise
    public func getChannelInfo(_ channelName: String) -> RelayChannelInfo? {
        return currentConfig?.destinationChannel(named: channelName)
    }
}

// MARK: - Extensions

extension MediaRelayManager {
    
    /// Convenience method to start a simple one-to-one relay
    /// - Parameters:
    ///   - sourceChannel: Source channel information
    ///   - destinationChannel: Destination channel information
    /// - Throws: RealtimeError if relay cannot be started
    public func startOneToOneRelay(
        source sourceChannel: RelayChannelInfo,
        destination destinationChannel: RelayChannelInfo
    ) async throws {
        let config = try MediaRelayConfig.oneToOne(
            source: sourceChannel,
            destination: destinationChannel
        )
        
        try await startRelay(config: config)
    }
    
    /// Convenience method to start a one-to-many relay
    /// - Parameters:
    ///   - sourceChannel: Source channel information
    ///   - destinationChannels: Array of destination channels
    /// - Throws: RealtimeError if relay cannot be started
    public func startOneToManyRelay(
        source sourceChannel: RelayChannelInfo,
        destinations destinationChannels: [RelayChannelInfo]
    ) async throws {
        let config = try MediaRelayConfig.oneToMany(
            source: sourceChannel,
            destinations: destinationChannels
        )
        
        try await startRelay(config: config)
    }
}