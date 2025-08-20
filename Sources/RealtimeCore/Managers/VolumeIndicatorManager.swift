// VolumeIndicatorManager.swift
// Volume indicator management system for real-time volume processing

import Foundation
import Combine

/// Manager for volume indicator functionality with real-time processing
@MainActor
public class VolumeIndicatorManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var speakingUsers: Set<String> = []
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var dominantSpeaker: String? = nil
    @Published public private(set) var config: VolumeDetectionConfig = .default
    
    // MARK: - Event Handlers
    public var onVolumeUpdate: (([UserVolumeInfo]) -> Void)?
    public var onVolumeEvent: ((VolumeEvent) -> Void)?
    public var onUserStartSpeaking: ((String, UserVolumeInfo) -> Void)?
    public var onUserStopSpeaking: ((String, UserVolumeInfo) -> Void)?
    public var onDominantSpeakerChanged: ((String?) -> Void)?
    
    // MARK: - Private Properties
    private var previousVolumeInfos: [String: UserVolumeInfo] = [:]
    private var previousSpeakingUsers: Set<String> = []
    private var previousDominantSpeaker: String? = nil
    private var volumeHistory: [String: [Float]] = [:]
    private let maxHistorySize: Int = 5
    private let eventProcessor = VolumeEventProcessor()
    
    // MARK: - Initialization
    public init() {
        print("VolumeIndicatorManager initialized")
        setupEventProcessor()
    }
    
    /// Setup the event processor with default handlers
    private func setupEventProcessor() {
        // Forward events to the callback handlers
        eventProcessor.onEventProcessed = { [weak self] event in
            self?.onVolumeEvent?(event)
        }
        
        // Register convenience handlers
        eventProcessor.registerSpeakingHandlers(
            onStartSpeaking: { [weak self] userId, volume in
                // Create a volume info from the event data for consistency
                let volumeInfo = UserVolumeInfo(userId: userId, volume: volume, isSpeaking: true)
                self?.onUserStartSpeaking?(userId, volumeInfo)
            },
            onStopSpeaking: { [weak self] userId, volume in
                // Create a volume info from the event data
                let volumeInfo = UserVolumeInfo(userId: userId, volume: volume, isSpeaking: false)
                self?.onUserStopSpeaking?(userId, volumeInfo)
            }
        )
        
        eventProcessor.registerDominantSpeakerHandler { [weak self] userId in
            self?.onDominantSpeakerChanged?(userId)
        }
    }
    
    // MARK: - Configuration
    
    /// Enable volume indicator with configuration
    /// - Parameter config: Volume detection configuration
    public func enable(with config: VolumeDetectionConfig) {
        guard config.isValid else {
            print("Invalid volume detection config: speaking threshold must be greater than silence threshold")
            return
        }
        
        self.config = config
        self.isEnabled = true
        
        // Clear previous state when enabling with new config
        clearState()
        
        print("Volume indicator enabled with config: interval=\(config.detectionInterval)ms, threshold=\(config.speakingThreshold)")
    }
    
    /// Disable volume indicator
    public func disable() {
        self.isEnabled = false
        clearState()
        print("Volume indicator disabled")
    }
    
    /// Update configuration while enabled
    /// - Parameter config: New volume detection configuration
    public func updateConfig(_ config: VolumeDetectionConfig) {
        guard config.isValid else {
            print("Invalid volume detection config: speaking threshold must be greater than silence threshold")
            return
        }
        
        self.config = config
        print("Volume indicator config updated")
    }
    
    // MARK: - Volume Processing
    
    /// Process incoming volume update from RTC provider
    /// - Parameter volumeInfos: Array of user volume information
    public func processVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        guard isEnabled else { return }
        
        // Filter local user if not included in config
        let filteredVolumeInfos = config.includeLocalUser ? volumeInfos : volumeInfos.filter { !isLocalUser($0.userId) }
        
        // Apply smoothing filter to volume data
        let smoothedVolumeInfos = applySmoothingFilter(filteredVolumeInfos)
        
        // Update speaking states based on thresholds
        let processedVolumeInfos = updateSpeakingStates(smoothedVolumeInfos)
        
        // Store current state
        self.volumeInfos = processedVolumeInfos
        
        // Detect and handle state changes
        detectStateChanges(processedVolumeInfos)
        
        // Update volume history for smoothing
        updateVolumeHistory(processedVolumeInfos)
        
        // Trigger callbacks
        onVolumeUpdate?(processedVolumeInfos)
    }
    
    /// Get current volume info for specific user
    /// - Parameter userId: User identifier
    /// - Returns: Volume info if available
    public func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return volumeInfos.first { $0.userId == userId }
    }
    
    /// Get current speaking users
    /// - Returns: Set of user IDs currently speaking
    public func getCurrentSpeakingUsers() -> Set<String> {
        return speakingUsers
    }
    
    /// Get current dominant speaker
    /// - Returns: User ID of dominant speaker, if any
    public func getCurrentDominantSpeaker() -> String? {
        return dominantSpeaker
    }
    
    // MARK: - Private Methods
    
    /// Apply smoothing filter to volume data to reduce noise
    /// - Parameter volumeInfos: Raw volume information
    /// - Returns: Smoothed volume information
    private func applySmoothingFilter(_ volumeInfos: [UserVolumeInfo]) -> [UserVolumeInfo] {
        return volumeInfos.map { volumeInfo in
            let userId = volumeInfo.userId
            let currentVolume = volumeInfo.volume
            
            // Get previous volume for smoothing
            let previousVolume = previousVolumeInfos[userId]?.volume ?? 0.0
            
            // Apply exponential moving average for smoothing
            // When smoothFactor is 0, use current volume directly (no smoothing)
            let smoothedVolume = config.smoothFactor == 0.0 ? currentVolume : previousVolume * (1.0 - config.smoothFactor) + currentVolume * config.smoothFactor
            
            return UserVolumeInfo(
                userId: userId,
                volume: smoothedVolume,
                isSpeaking: volumeInfo.isSpeaking, // Will be updated in next step
                timestamp: volumeInfo.timestamp
            )
        }
    }
    
    /// Update speaking states based on volume thresholds
    /// - Parameter volumeInfos: Volume information with smoothed volumes
    /// - Returns: Volume information with updated speaking states
    private func updateSpeakingStates(_ volumeInfos: [UserVolumeInfo]) -> [UserVolumeInfo] {
        return volumeInfos.map { volumeInfo in
            let userId = volumeInfo.userId
            let volume = volumeInfo.volume
            let previousSpeaking = previousVolumeInfos[userId]?.isSpeaking ?? false
            
            // Determine speaking state with hysteresis to prevent flapping
            let isSpeaking: Bool
            if previousSpeaking {
                // If was speaking, use silence threshold to stop
                isSpeaking = volume > config.silenceThreshold
            } else {
                // If was not speaking, use speaking threshold to start
                isSpeaking = volume > config.speakingThreshold
            }
            
            
            return UserVolumeInfo(
                userId: userId,
                volume: volume,
                isSpeaking: isSpeaking,
                timestamp: volumeInfo.timestamp
            )
        }
    }
    
    /// Detect and handle state changes (speaking, dominant speaker)
    /// - Parameter volumeInfos: Current volume information
    private func detectStateChanges(_ volumeInfos: [UserVolumeInfo]) {
        let currentSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        let currentDominantSpeaker = findDominantSpeaker(volumeInfos)
        
        // Detect speaking state changes
        detectSpeakingStateChanges(
            previous: previousSpeakingUsers,
            current: currentSpeakingUsers,
            volumeInfos: volumeInfos
        )
        
        // Detect dominant speaker changes
        if currentDominantSpeaker != previousDominantSpeaker {
            dominantSpeaker = currentDominantSpeaker
            eventProcessor.processEvent(.dominantSpeakerChanged(userId: currentDominantSpeaker))
            previousDominantSpeaker = currentDominantSpeaker
        }
        
        // Update state
        speakingUsers = currentSpeakingUsers
        previousSpeakingUsers = currentSpeakingUsers
        
        // Update previous volume infos for next iteration
        for volumeInfo in volumeInfos {
            previousVolumeInfos[volumeInfo.userId] = volumeInfo
        }
    }
    
    /// Detect speaking state changes and trigger events
    /// - Parameters:
    ///   - previous: Previous speaking users
    ///   - current: Current speaking users
    ///   - volumeInfos: Current volume information
    private func detectSpeakingStateChanges(
        previous: Set<String>,
        current: Set<String>,
        volumeInfos: [UserVolumeInfo]
    ) {
        let startedSpeaking = current.subtracting(previous)
        let stoppedSpeaking = previous.subtracting(current)
        
        // Handle users who started speaking
        for userId in startedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                eventProcessor.processEvent(.userStartedSpeaking(userId: userId, volume: volumeInfo.volume))
            }
        }
        
        // Handle users who stopped speaking
        for userId in stoppedSpeaking {
            // Find the current volume info for the user who stopped speaking
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                eventProcessor.processEvent(.userStoppedSpeaking(userId: userId, volume: volumeInfo.volume))
            }
        }
        
        // Handle volume changes for all users
        for volumeInfo in volumeInfos {
            let previousVolume = previousVolumeInfos[volumeInfo.userId]?.volume ?? 0.0
            if abs(volumeInfo.volume - previousVolume) > 0.05 { // Only trigger if significant change
                eventProcessor.processEvent(.volumeChanged(userId: volumeInfo.userId, volume: volumeInfo.volume))
            }
        }
    }
    
    /// Find the dominant speaker (user with highest volume among speaking users)
    /// - Parameter volumeInfos: Current volume information
    /// - Returns: User ID of dominant speaker, if any
    private func findDominantSpeaker(_ volumeInfos: [UserVolumeInfo]) -> String? {
        let speakingUsers = volumeInfos.filter { $0.isSpeaking }
        
        guard !speakingUsers.isEmpty else { return nil }
        
        // Find user with maximum volume
        let dominantUser = speakingUsers.max { $0.volume < $1.volume }
        return dominantUser?.userId
    }
    
    /// Update volume history for advanced smoothing algorithms
    /// - Parameter volumeInfos: Current volume information
    private func updateVolumeHistory(_ volumeInfos: [UserVolumeInfo]) {
        for volumeInfo in volumeInfos {
            let userId = volumeInfo.userId
            
            if volumeHistory[userId] == nil {
                volumeHistory[userId] = []
            }
            
            volumeHistory[userId]?.append(volumeInfo.volume)
            
            // Keep only recent history
            if let history = volumeHistory[userId], history.count > maxHistorySize {
                volumeHistory[userId] = Array(history.suffix(maxHistorySize))
            }
        }
    }
    
    /// Check if user ID represents the local user
    /// - Parameter userId: User identifier to check
    /// - Returns: True if this is the local user
    private func isLocalUser(_ userId: String) -> Bool {
        // This would typically be determined by comparing with current session
        // For now, we'll use a simple heuristic or delegate to RealtimeManager
        return userId.hasPrefix("local_") || userId == "self"
    }
    
    /// Clear all state when disabling or reconfiguring
    private func clearState() {
        volumeInfos.removeAll()
        speakingUsers.removeAll()
        dominantSpeaker = nil
        previousVolumeInfos.removeAll()
        previousSpeakingUsers.removeAll()
        previousDominantSpeaker = nil
        volumeHistory.removeAll()
        eventProcessor.clearQueue()
    }
    
    // MARK: - Event Processor Access
    
    /// Get the event processor for advanced event handling
    /// - Returns: The volume event processor instance
    public func getEventProcessor() -> VolumeEventProcessor {
        return eventProcessor
    }
    
    /// Register a custom event handler
    /// - Parameters:
    ///   - eventType: Type of volume event to handle
    ///   - handler: Async handler function
    public func registerEventHandler(
        for eventType: VolumeEventType,
        handler: @escaping (VolumeEvent) async throws -> Void
    ) {
        eventProcessor.registerHandler(for: eventType, handler: handler)
    }
    
    /// Get event processing statistics
    /// - Returns: Current processing statistics
    public func getEventProcessingStats() -> VolumeEventProcessingStats {
        return eventProcessor.getStatistics()
    }
}

// MARK: - Advanced Volume Processing

extension VolumeIndicatorManager {
    
    /// Get average volume for a user over recent history
    /// - Parameter userId: User identifier
    /// - Returns: Average volume over recent samples
    public func getAverageVolume(for userId: String) -> Float {
        guard let history = volumeHistory[userId], !history.isEmpty else { return 0.0 }
        return history.reduce(0, +) / Float(history.count)
    }
    
    /// Get volume trend for a user (increasing, decreasing, stable)
    /// - Parameter userId: User identifier
    /// - Returns: Volume trend indicator
    public func getVolumeTrend(for userId: String) -> VolumeTrend {
        guard let history = volumeHistory[userId], history.count >= 3 else { return .stable }
        
        let recent = Array(history.suffix(3))
        let first = recent[0]
        let last = recent[2]
        let threshold: Float = 0.1
        
        if last - first > threshold {
            return .increasing
        } else if first - last > threshold {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    /// Check if user has been consistently speaking
    /// - Parameters:
    ///   - userId: User identifier
    ///   - duration: Duration to check in seconds
    /// - Returns: True if user has been speaking consistently
    public func hasBeenSpeakingConsistently(userId: String, duration: TimeInterval) -> Bool {
        guard let volumeInfo = getVolumeInfo(for: userId) else { return false }
        
        // Simple implementation - in a real scenario, you'd track speaking duration
        return volumeInfo.isSpeaking && volumeInfo.volume > config.speakingThreshold * 1.2
    }
}

/// Volume trend indicator
public enum VolumeTrend {
    case increasing
    case decreasing
    case stable
}