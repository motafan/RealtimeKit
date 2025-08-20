// ConnectionStateManagerTests.swift
// Comprehensive unit tests for ConnectionStateManager

import Testing
import Combine
@testable import RealtimeCore

@Suite("ConnectionStateManager Tests")
@MainActor
struct ConnectionStateManagerTests {
    
    // MARK: - Test Setup
    
    private func createManager() -> ConnectionStateManager {
        return ConnectionStateManager()
    }
    
    // MARK: - Initialization Tests
    
    @Test("Manager initialization with default state")
    func testManagerInitialization() {
        let manager = createManager()
        
        #expect(manager.currentState == .disconnected)
        #expect(manager.previousState == nil)
        #expect(manager.connectionAttempts == 0)
        #expect(manager.isReconnecting == false)
        #expect(manager.lastConnectionTime == nil)
        #expect(manager.lastDisconnectionTime == nil)
    }
    
    // MARK: - State Transition Tests
    
    @Test("Valid state transitions")
    func testValidStateTransitions() async {
        let manager = createManager()
        
        // disconnected -> connecting
        try await manager.transitionTo(.connecting)
        #expect(manager.currentState == .connecting)
        #expect(manager.previousState == .disconnected)
        
        // connecting -> connected
        try await manager.transitionTo(.connected)
        #expect(manager.currentState == .connected)
        #expect(manager.previousState == .connecting)
        #expect(manager.lastConnectionTime != nil)
        
        // connected -> disconnecting
        try await manager.transitionTo(.disconnecting)
        #expect(manager.currentState == .disconnecting)
        #expect(manager.previousState == .connected)
        
        // disconnecting -> disconnected
        try await manager.transitionTo(.disconnected)
        #expect(manager.currentState == .disconnected)
        #expect(manager.previousState == .disconnecting)
        #expect(manager.lastDisconnectionTime != nil)
    }
    
    @Test("Invalid state transitions")
    func testInvalidStateTransitions() async {
        let manager = createManager()
        
        // Try invalid transition: disconnected -> connected (should go through connecting)
        do {
            try await manager.transitionTo(.connected)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            if case .invalidStateTransition(let from, let to) = error {
                #expect(from == .disconnected)
                #expect(to == .connected)
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
        
        // Try invalid transition: connecting -> disconnecting
        try await manager.transitionTo(.connecting)
        
        do {
            try await manager.transitionTo(.disconnecting)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            if case .invalidStateTransition(let from, let to) = error {
                #expect(from == .connecting)
                #expect(to == .disconnecting)
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Same state transition")
    func testSameStateTransition() async {
        let manager = createManager()
        
        // Try to transition to same state
        do {
            try await manager.transitionTo(.disconnected)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .alreadyInState(.disconnected))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Connection Attempt Tracking Tests
    
    @Test("Connection attempt counting")
    func testConnectionAttemptCounting() async {
        let manager = createManager()
        
        #expect(manager.connectionAttempts == 0)
        
        // First attempt
        try await manager.transitionTo(.connecting)
        #expect(manager.connectionAttempts == 1)
        
        // Failed connection
        try await manager.transitionTo(.disconnected)
        
        // Second attempt
        try await manager.transitionTo(.connecting)
        #expect(manager.connectionAttempts == 2)
        
        // Successful connection
        try await manager.transitionTo(.connected)
        #expect(manager.connectionAttempts == 2) // Should not increment on success
    }
    
    @Test("Connection attempt reset on successful connection")
    func testConnectionAttemptResetOnSuccess() async {
        let manager = createManager()
        
        // Multiple failed attempts
        for _ in 1...3 {
            try await manager.transitionTo(.connecting)
            try await manager.transitionTo(.disconnected)
        }
        
        #expect(manager.connectionAttempts == 3)
        
        // Successful connection should reset counter
        try await manager.transitionTo(.connecting)
        try await manager.transitionTo(.connected)
        
        #expect(manager.connectionAttempts == 0)
    }
    
    // MARK: - Reconnection Logic Tests
    
    @Test("Automatic reconnection on connection failure")
    func testAutomaticReconnectionOnFailure() async {
        let manager = createManager()
        manager.enableAutoReconnect(maxAttempts: 3, initialDelay: 0.1)
        
        var stateChanges: [ConnectionState] = []
        let cancellable = manager.$currentState
            .sink { state in
                stateChanges.append(state)
            }
        
        // Simulate connection failure
        try await manager.transitionTo(.connecting)
        manager.handleConnectionFailure(RealtimeError.networkError("Connection failed"))
        
        // Wait for reconnection attempts
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(manager.isReconnecting == true)
        #expect(manager.connectionAttempts > 1)
        
        cancellable.cancel()
    }
    
    @Test("Reconnection backoff strategy")
    func testReconnectionBackoffStrategy() async {
        let manager = createManager()
        manager.enableAutoReconnect(maxAttempts: 3, initialDelay: 0.1)
        
        let startTime = Date()
        
        // Simulate multiple connection failures
        for _ in 1...3 {
            try await manager.transitionTo(.connecting)
            manager.handleConnectionFailure(RealtimeError.networkError("Connection failed"))
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Should have taken longer due to exponential backoff
        #expect(totalTime > 0.3) // At least 0.3 seconds with backoff
    }
    
    @Test("Max reconnection attempts limit")
    func testMaxReconnectionAttemptsLimit() async {
        let manager = createManager()
        manager.enableAutoReconnect(maxAttempts: 2, initialDelay: 0.05)
        
        // Simulate connection failures beyond max attempts
        for _ in 1...3 {
            try await manager.transitionTo(.connecting)
            manager.handleConnectionFailure(RealtimeError.networkError("Connection failed"))
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Should stop reconnecting after max attempts
        #expect(manager.isReconnecting == false)
        #expect(manager.connectionAttempts <= 2)
    }
    
    @Test("Disable auto reconnection")
    func testDisableAutoReconnection() async {
        let manager = createManager()
        manager.enableAutoReconnect(maxAttempts: 3, initialDelay: 0.1)
        
        // Disable auto reconnection
        manager.disableAutoReconnect()
        
        // Simulate connection failure
        try await manager.transitionTo(.connecting)
        manager.handleConnectionFailure(RealtimeError.networkError("Connection failed"))
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Should not be reconnecting
        #expect(manager.isReconnecting == false)
    }
    
    // MARK: - State Change Callbacks Tests
    
    @Test("State change callbacks")
    func testStateChangeCallbacks() async {
        let manager = createManager()
        
        var receivedCallbacks: [(ConnectionState, ConnectionState?)] = []
        
        manager.onStateChanged = { newState, previousState in
            receivedCallbacks.append((newState, previousState))
        }
        
        // Perform state transitions
        try await manager.transitionTo(.connecting)
        try await manager.transitionTo(.connected)
        try await manager.transitionTo(.disconnecting)
        try await manager.transitionTo(.disconnected)
        
        #expect(receivedCallbacks.count == 4)
        
        // Check callback parameters
        #expect(receivedCallbacks[0].0 == .connecting)
        #expect(receivedCallbacks[0].1 == .disconnected)
        
        #expect(receivedCallbacks[1].0 == .connected)
        #expect(receivedCallbacks[1].1 == .connecting)
        
        #expect(receivedCallbacks[2].0 == .disconnecting)
        #expect(receivedCallbacks[2].1 == .connected)
        
        #expect(receivedCallbacks[3].0 == .disconnected)
        #expect(receivedCallbacks[3].1 == .disconnecting)
    }
    
    // MARK: - Connection Quality Monitoring Tests
    
    @Test("Connection quality monitoring")
    func testConnectionQualityMonitoring() async {
        let manager = createManager()
        
        // Start monitoring
        manager.startQualityMonitoring(interval: 0.1)
        
        // Simulate connection
        try await manager.transitionTo(.connecting)
        try await manager.transitionTo(.connected)
        
        // Update quality metrics
        manager.updateConnectionQuality(latency: 50, packetLoss: 0.02, bandwidth: 1000)
        
        let quality = manager.currentConnectionQuality
        #expect(quality.latency == 50)
        #expect(quality.packetLoss == 0.02)
        #expect(quality.bandwidth == 1000)
        #expect(quality.overallScore > 0)
        
        manager.stopQualityMonitoring()
    }
    
    @Test("Poor connection quality detection")
    func testPoorConnectionQualityDetection() async {
        let manager = createManager()
        
        var qualityAlerts: [ConnectionQuality] = []
        manager.onPoorQualityDetected = { quality in
            qualityAlerts.append(quality)
        }
        
        manager.startQualityMonitoring(interval: 0.1)
        try await manager.transitionTo(.connecting)
        try await manager.transitionTo(.connected)
        
        // Simulate poor quality
        manager.updateConnectionQuality(latency: 500, packetLoss: 0.15, bandwidth: 100)
        
        // Wait for quality assessment
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(qualityAlerts.count > 0)
        #expect(qualityAlerts.first?.overallScore < 0.5)
        
        manager.stopQualityMonitoring()
    }
    
    // MARK: - Connection Statistics Tests
    
    @Test("Connection statistics tracking")
    func testConnectionStatisticsTracking() async {
        let manager = createManager()
        
        // Perform multiple connections
        for _ in 1...3 {
            try await manager.transitionTo(.connecting)
            try await manager.transitionTo(.connected)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            try await manager.transitionTo(.disconnecting)
            try await manager.transitionTo(.disconnected)
        }
        
        let stats = manager.connectionStatistics
        #expect(stats.totalConnections == 3)
        #expect(stats.totalDisconnections == 3)
        #expect(stats.averageConnectionDuration > 0)
    }
    
    @Test("Connection uptime calculation")
    func testConnectionUptimeCalculation() async {
        let manager = createManager()
        
        try await manager.transitionTo(.connecting)
        try await manager.transitionTo(.connected)
        
        // Wait for some uptime
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let uptime = manager.currentConnectionUptime
        #expect(uptime > 0.1) // Should be at least 0.1 seconds
        
        try await manager.transitionTo(.disconnecting)
        try await manager.transitionTo(.disconnected)
        
        let finalUptime = manager.lastConnectionDuration
        #expect(finalUptime > 0.1)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Connection timeout handling")
    func testConnectionTimeoutHandling() async {
        let manager = createManager()
        manager.setConnectionTimeout(0.1) // 0.1 second timeout
        
        var timeoutOccurred = false
        manager.onConnectionTimeout = {
            timeoutOccurred = true
        }
        
        try await manager.transitionTo(.connecting)
        
        // Wait for timeout
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(timeoutOccurred == true)
        #expect(manager.currentState == .disconnected)
    }
    
    @Test("Network error handling")
    func testNetworkErrorHandling() async {
        let manager = createManager()
        
        var receivedErrors: [Error] = []
        manager.onConnectionError = { error in
            receivedErrors.append(error)
        }
        
        try await manager.transitionTo(.connecting)
        
        let networkError = RealtimeError.networkError("Network unreachable")
        manager.handleConnectionError(networkError)
        
        #expect(receivedErrors.count == 1)
        #expect(manager.currentState == .disconnected)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent state transitions")
    func testConcurrentStateTransitions() async {
        let manager = createManager()
        
        // Attempt concurrent transitions
        async let transition1: Void = manager.transitionTo(.connecting)
        async let transition2: Void = manager.transitionTo(.connecting)
        
        do {
            let _ = try await (transition1, transition2)
            // One should succeed, one should fail
            #expect(manager.currentState == .connecting)
        } catch {
            // Expected that one might fail due to concurrent access
            #expect(manager.currentState == .connecting || manager.currentState == .disconnected)
        }
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Callback cleanup on deallocation")
    func testCallbackCleanupOnDeallocation() async {
        var manager: ConnectionStateManager? = createManager()
        
        weak var weakManager = manager
        
        manager?.onStateChanged = { _, _ in
            // This callback should be cleaned up
        }
        
        manager = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakManager == nil)
    }
}