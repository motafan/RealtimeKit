// StreamPushManager.swift
// Stream push management with state control and error recovery

import Foundation
import Combine

/// Stream push manager for controlling live streaming functionality
@MainActor
public class StreamPushManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentState: StreamPushState = .stopped
    @Published public private(set) var currentConfig: StreamPushConfig?
    @Published public private(set) var lastError: RealtimeError?
    @Published public private(set) var statistics: StreamPushStatistics = StreamPushStatistics()
    
    // MARK: - Private Properties
    
    private var rtcProvider: RTCProvider?
    private var retryCount: Int = 0
    private var maxRetryCount: Int = 3
    private var retryTimer: Timer?
    private var statisticsTimer: Timer?
    
    // MARK: - Event Handlers
    
    public var onStateChanged: ((StreamPushState, StreamPushState) -> Void)?
    public var onError: ((RealtimeError) -> Void)?
    public var onStatisticsUpdate: ((StreamPushStatistics) -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        setupStatisticsTimer()
    }
    

    
    // MARK: - Configuration
    
    /// Configure the stream push manager with an RTC provider
    /// - Parameter provider: RTC provider instance
    public func configure(with provider: RTCProvider) {
        self.rtcProvider = provider
    }
    
    // MARK: - Stream Push Control
    
    /// Start stream push with the specified configuration
    /// - Parameter config: Stream push configuration
    /// - Throws: RealtimeError if start fails
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard currentState == .stopped || currentState == .failed else {
            throw RealtimeError.streamPushStartFailed("Stream push is already active or starting")
        }
        
        // Validate configuration
        try config.validate()
        
        // Update state
        await updateState(.starting)
        currentConfig = config
        lastError = nil
        retryCount = 0
        
        do {
            // Start stream push via provider
            try await rtcProvider.startStreamPush(config: config)
            
            // Update state to running
            await updateState(.running)
            
            // Reset statistics
            statistics = StreamPushStatistics()
            statistics.startTime = Date()
            
        } catch {
            let realtimeError = error as? RealtimeError ?? RealtimeError.streamPushStartFailed(error.localizedDescription)
            await handleError(realtimeError)
            throw realtimeError
        }
    }
    
    /// Stop stream push
    /// - Throws: RealtimeError if stop fails
    public func stopStreamPush() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard currentState == .running || currentState == .starting || currentState == .failed else {
            throw RealtimeError.streamPushStopFailed("No active stream push to stop")
        }
        
        // Update state
        await updateState(.stopping)
        
        // Cancel any retry attempts
        retryTimer?.invalidate()
        retryTimer = nil
        
        do {
            // Stop stream push via provider
            try await rtcProvider.stopStreamPush()
            
            // Update state to stopped
            await updateState(.stopped)
            
            // Finalize statistics
            statistics.endTime = Date()
            
            // Clear configuration
            currentConfig = nil
            
        } catch {
            let realtimeError = error as? RealtimeError ?? RealtimeError.streamPushStopFailed(error.localizedDescription)
            await handleError(realtimeError)
            throw realtimeError
        }
    }
    
    /// Update stream push layout
    /// - Parameter layout: New stream layout
    /// - Throws: RealtimeError if update fails
    public func updateLayout(_ layout: StreamLayout) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard currentState == .running else {
            throw RealtimeError.streamLayoutUpdateFailed("Stream push is not running")
        }
        
        guard let config = currentConfig else {
            throw RealtimeError.streamLayoutUpdateFailed("No active stream configuration")
        }
        
        // Validate new layout
        try layout.validate()
        
        do {
            // Create updated configuration
            let updatedConfig = StreamPushConfig(
                pushUrl: config.pushUrl,
                width: config.width,
                height: config.height,
                bitrate: config.bitrate,
                framerate: config.framerate,
                layout: layout
            )
            
            // Update layout via provider
            try await rtcProvider.updateStreamPushLayout(layout: layout)
            
            // Update current configuration
            currentConfig = updatedConfig
            
            // Update statistics
            statistics.layoutUpdateCount += 1
            
        } catch {
            let realtimeError = error as? RealtimeError ?? RealtimeError.streamLayoutUpdateFailed(error.localizedDescription)
            await handleError(realtimeError)
            throw realtimeError
        }
    }
    
    /// Update stream push configuration (restart required)
    /// - Parameter config: New stream push configuration
    /// - Throws: RealtimeError if update fails
    public func updateConfiguration(_ config: StreamPushConfig) async throws {
        guard currentState == .running else {
            throw RealtimeError.streamPushUpdateFailed("Stream push is not running")
        }
        
        // Validate new configuration
        try config.validate()
        
        do {
            // Stop current stream
            try await stopStreamPush()
            
            // Start with new configuration
            try await startStreamPush(config: config)
            
        } catch {
            let realtimeError = error as? RealtimeError ?? RealtimeError.streamPushUpdateFailed(error.localizedDescription)
            await handleError(realtimeError)
            throw realtimeError
        }
    }
    
    // MARK: - Error Recovery
    
    /// Handle stream push errors with automatic recovery
    /// - Parameter error: The error that occurred
    private func handleError(_ error: RealtimeError) async {
        lastError = error
        onError?(error)
        
        // Update statistics
        statistics.errorCount += 1
        
        // Update state to failed
        await updateState(.failed)
        
        // Attempt recovery if error is recoverable
        if error.isRecoverable && retryCount < maxRetryCount {
            await scheduleRetry()
        } else {
            // Give up and stop
            currentConfig = nil
            retryCount = 0
        }
    }
    
    /// Schedule automatic retry after a delay
    private func scheduleRetry() async {
        retryCount += 1
        
        let retryDelay = calculateRetryDelay(attempt: retryCount)
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.attemptRecovery()
            }
        }
    }
    
    /// Calculate exponential backoff delay for retry attempts
    /// - Parameter attempt: Current retry attempt number
    /// - Returns: Delay in seconds
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 2.0
        let maxDelay: TimeInterval = 30.0
        let delay = baseDelay * pow(2.0, Double(attempt - 1))
        return min(delay, maxDelay)
    }
    
    /// Attempt to recover from error by restarting stream push
    private func attemptRecovery() async {
        guard let config = currentConfig else { return }
        
        do {
            try await startStreamPush(config: config)
            
            // Recovery successful
            statistics.recoveryCount += 1
            
        } catch {
            // Recovery failed, will be handled by handleError
            print("Stream push recovery attempt \(retryCount) failed: \(error)")
        }
    }
    
    // MARK: - State Management
    
    /// Update stream push state and notify observers
    /// - Parameter newState: New stream push state
    private func updateState(_ newState: StreamPushState) async {
        let oldState = currentState
        currentState = newState
        
        // Update statistics
        statistics.stateChangeCount += 1
        
        // Notify observers
        onStateChanged?(oldState, newState)
        
        print("Stream push state changed: \(oldState.displayName) -> \(newState.displayName)")
    }
    
    // MARK: - Statistics
    
    /// Setup timer for periodic statistics updates
    private func setupStatisticsTimer() {
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatistics()
            }
        }
    }
    
    /// Stop statistics timer
    private func stopStatisticsTimer() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }
    
    /// Update streaming statistics
    private func updateStatistics() {
        guard currentState == .running else { return }
        
        // Update duration
        if let startTime = statistics.startTime {
            statistics.duration = Date().timeIntervalSince(startTime)
        }
        
        // Notify observers
        onStatisticsUpdate?(statistics)
    }
    
    // MARK: - Public Utilities
    
    /// Check if stream push is currently active
    public var isActive: Bool {
        return currentState.isActive
    }
    
    /// Check if stream push can be started
    public var canStart: Bool {
        return currentState == .stopped || currentState == .failed
    }
    
    /// Check if stream push can be stopped
    public var canStop: Bool {
        return currentState == .running || currentState == .starting
    }
    
    /// Get current stream push duration
    public var currentDuration: TimeInterval {
        guard let startTime = statistics.startTime, currentState == .running else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Reset error state and retry count
    public func resetErrorState() {
        lastError = nil
        retryCount = 0
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// Cleanup resources and stop all timers
    public func cleanup() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
    }
}

// MARK: - StreamPushStatistics

/// Statistics for stream push operations
public struct StreamPushStatistics: Codable, Equatable, Sendable {
    public var startTime: Date?
    public var endTime: Date?
    public var duration: TimeInterval = 0
    public var stateChangeCount: Int = 0
    public var layoutUpdateCount: Int = 0
    public var errorCount: Int = 0
    public var recoveryCount: Int = 0
    
    public init() {}
    
    /// Success rate based on errors and recoveries
    public var successRate: Double {
        let totalAttempts = max(1, stateChangeCount)
        let successfulAttempts = totalAttempts - errorCount + recoveryCount
        return Double(successfulAttempts) / Double(totalAttempts)
    }
    
    /// Average time between errors
    public var averageTimeBetweenErrors: TimeInterval {
        guard errorCount > 0, duration > 0 else { return 0 }
        return duration / Double(errorCount)
    }
    
    /// Whether the stream has been stable (no errors in last 5 minutes)
    public var isStable: Bool {
        guard let startTime = startTime else { return false }
        let stableThreshold: TimeInterval = 300 // 5 minutes
        return Date().timeIntervalSince(startTime) > stableThreshold && errorCount == 0
    }
}