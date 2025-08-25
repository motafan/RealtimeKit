import Testing
import Foundation
@testable import RealtimeCore

/// Tests for the connection state management system
/// 需求: 13.2, 13.3, 17.6 - 连接状态管理和自动重连机制
@Suite("Connection State Manager Tests")
@MainActor
struct ConnectionStateManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test("ConnectionStateManager initialization")
    func testConnectionStateManagerInitialization() async throws {
        let manager = ConnectionStateManager()
        
        #expect(manager.connectionState == .disconnected)
        #expect(manager.networkStatus == .unknown)
        #expect(manager.reconnectionAttempts == 0)
        #expect(manager.lastConnectionError == nil)
        #expect(manager.connectionHistory.isEmpty)
        #expect(manager.isAutoReconnectEnabled == true)
    }
    
    @Test("ConnectionStateManager custom configuration")
    func testConnectionStateManagerCustomConfiguration() async throws {
        let config = ConnectionStateManager.ReconnectionConfig(
            maxReconnectionAttempts: 3,
            baseReconnectionDelay: 1.0,
            maxReconnectionDelay: 15.0,
            exponentialBackoffMultiplier: 1.5,
            networkMonitoringEnabled: false,
            connectionTimeoutInterval: 5.0
        )
        
        let manager = ConnectionStateManager(config: config)
        #expect(manager.connectionState == .disconnected)
        #expect(manager.isAutoReconnectEnabled == true)
    }
    
    // MARK: - Connection State Tests
    
    @Test("Connection state updates")
    func testConnectionStateUpdates() async throws {
        let manager = ConnectionStateManager()
        var stateChanges: [(ConnectionState, ConnectionState)] = []
        
        await MainActor.run {
            manager.onConnectionStateChanged = { oldState, newState in
                stateChanges.append((oldState, newState))
            }
        }
        
        // Test state transitions
        manager.updateConnectionState(.connecting)
        #expect(manager.connectionState == .connecting)
        #expect(stateChanges.count == 1)
        #expect(stateChanges[0].0 == .disconnected)
        #expect(stateChanges[0].1 == .connecting)
        
        manager.updateConnectionState(.connected)
        #expect(manager.connectionState == .connected)
        #expect(stateChanges.count == 2)
        #expect(stateChanges[1].0 == .connecting)
        #expect(stateChanges[1].1 == .connected)
        
        manager.updateConnectionState(.disconnected)
        #expect(manager.connectionState == .disconnected)
        #expect(stateChanges.count == 3)
    }
    
    @Test("Connection state history tracking")
    func testConnectionStateHistoryTracking() async throws {
        let manager = ConnectionStateManager()
        
        manager.updateConnectionState(.connecting)
        manager.updateConnectionState(.connected)
        manager.updateConnectionState(.disconnected)
        
        #expect(manager.connectionHistory.count == 3)
        #expect(manager.connectionHistory[0].state == .connecting)
        #expect(manager.connectionHistory[1].state == .connected)
        #expect(manager.connectionHistory[2].state == .disconnected)
        
        // Check that previous state is tracked
        #expect(manager.connectionHistory[1].previousState == .connecting)
        #expect(manager.connectionHistory[2].previousState == .connected)
    }
    
    @Test("Connection error tracking")
    func testConnectionErrorTracking() async throws {
        let manager = ConnectionStateManager()
        let error = RealtimeError.networkUnavailable
        
        manager.setLastConnectionError(error)
        #expect(manager.lastConnectionError == error)
        
        manager.updateConnectionState(.failed)
        
        // Check that error is recorded in history
        let failedEvent = manager.connectionHistory.first { $0.state == .failed }
        #expect(failedEvent?.error == error)
    }
    
    // MARK: - Reconnection Tests
    
    @Test("Automatic reconnection success")
    func testAutomaticReconnectionSuccess() async throws {
        let config = ConnectionStateManager.ReconnectionConfig(
            maxReconnectionAttempts: 3,
            baseReconnectionDelay: 0.1, // Short delay for testing
            maxReconnectionDelay: 1.0,
            exponentialBackoffMultiplier: 1.0,
            networkMonitoringEnabled: false,
            connectionTimeoutInterval: 1.0
        )
        
        let manager = ConnectionStateManager(config: config)
        var callCount = 0
        var reconnectionStartedCount = 0
        var reconnectionSucceeded = false
        
        await MainActor.run {
            manager.onReconnectionStarted = { _ in
                reconnectionStartedCount += 1
            }
            
            manager.onReconnectionSucceeded = { _ in
                reconnectionSucceeded = true
            }
        }
        
        let operation: () async throws -> Void = {
            callCount += 1
            if callCount == 1 {
                throw RealtimeError.networkUnavailable
            }
            // Simulate successful connection
            manager.updateConnectionState(.connected)
        }
        
        manager.updateConnectionState(.disconnected)
        manager.startReconnection(operation: operation)
        
        // Wait for reconnection to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(reconnectionStartedCount > 0)
        #expect(reconnectionSucceeded == true)
        #expect(manager.connectionState == .connected)
        #expect(manager.reconnectionAttempts == 0) // Reset on success
    }
    
    @Test("Reconnection exhausted")
    func testReconnectionExhausted() async throws {
        let config = ConnectionStateManager.ReconnectionConfig(
            maxReconnectionAttempts: 2,
            baseReconnectionDelay: 0.1,
            maxReconnectionDelay: 1.0,
            exponentialBackoffMultiplier: 1.0,
            networkMonitoringEnabled: false,
            connectionTimeoutInterval: 1.0
        )
        
        let manager = ConnectionStateManager(config: config)
        var reconnectionExhausted = false
        var exhaustedAttempts = 0
        
        await MainActor.run {
            manager.onReconnectionExhausted = { attempts in
                reconnectionExhausted = true
                exhaustedAttempts = attempts
            }
        }
        
        let operation: () async throws -> Void = {
            throw RealtimeError.networkUnavailable
        }
        
        manager.updateConnectionState(.disconnected)
        manager.startReconnection(operation: operation)
        
        // Wait for reconnection attempts to exhaust
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #expect(reconnectionExhausted == true)
        #expect(exhaustedAttempts == 2)
        #expect(manager.connectionState == .failed)
    }
    
    @Test("Stop reconnection")
    func testStopReconnection() async throws {
        let manager = ConnectionStateManager()
        
        let operation: () async throws -> Void = {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            throw RealtimeError.networkUnavailable
        }
        
        manager.updateConnectionState(.disconnected)
        manager.startReconnection(operation: operation)
        
        // Stop reconnection immediately
        manager.stopReconnection()
        
        #expect(manager.connectionState == .disconnected)
    }
    
    @Test("Disable auto reconnection")
    func testDisableAutoReconnection() async throws {
        let manager = ConnectionStateManager()
        
        manager.setAutoReconnectEnabled(false)
        #expect(manager.isAutoReconnectEnabled == false)
        
        let operation: () async throws -> Void = {
            throw RealtimeError.networkUnavailable
        }
        
        manager.updateConnectionState(.disconnected)
        manager.startReconnection(operation: operation)
        
        // Should not start reconnection when disabled
        #expect(manager.connectionState == .disconnected)
    }
    
    @Test("Force reconnection")
    func testForceReconnection() async throws {
        let config = ConnectionStateManager.ReconnectionConfig(
            maxReconnectionAttempts: 1,
            baseReconnectionDelay: 0.1,
            maxReconnectionDelay: 1.0,
            exponentialBackoffMultiplier: 1.0,
            networkMonitoringEnabled: false,
            connectionTimeoutInterval: 1.0
        )
        
        let manager = ConnectionStateManager(config: config)
        var operationCalled = false
        
        let operation: () async throws -> Void = {
            operationCalled = true
            manager.updateConnectionState(.connected)
        }
        
        await manager.forceReconnection(operation: operation)
        
        // Wait for operation to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(operationCalled == true)
        #expect(manager.connectionState == .connected)
    }
    
    // MARK: - Connection Statistics Tests
    
    @Test("Connection statistics")
    func testConnectionStatistics() async throws {
        let manager = ConnectionStateManager()
        
        // Simulate connection events
        manager.updateConnectionState(.connecting)
        manager.updateConnectionState(.connected)
        manager.updateConnectionState(.disconnected)
        manager.updateConnectionState(.failed)
        
        let stats = manager.getConnectionStats()
        
        #expect(stats.currentState == .failed)
        #expect(stats.totalConnections == 1)
        #expect(stats.totalDisconnections == 1)
        #expect(stats.totalFailures == 1)
        #expect(stats.connectionSuccessRate == 0.5) // 1 success out of 2 attempts (1 connection + 1 failure)
    }
    
    @Test("Clear old connection history")
    func testClearOldConnectionHistory() async throws {
        let manager = ConnectionStateManager()
        
        // Add some connection events
        manager.updateConnectionState(.connecting)
        manager.updateConnectionState(.connected)
        manager.updateConnectionState(.disconnected)
        
        #expect(manager.connectionHistory.count == 3)
        
        // Clear history (in real scenario, this would clear old entries)
        manager.clearOldConnectionHistory(olderThan: 3600) // 1 hour
        
        // Since all events are recent, they should still be there
        #expect(manager.connectionHistory.count == 3)
    }
    
    // MARK: - Localization Tests
    
    @Test("Localized state descriptions")
    func testLocalizedStateDescriptions() async throws {
        let manager = ConnectionStateManager()
        
        let description = manager.getLocalizedStateDescription()
        #expect(!description.isEmpty)
        
        let networkDescription = manager.getLocalizedNetworkStatusDescription()
        #expect(!networkDescription.isEmpty)
    }
    
    // MARK: - Network Status Tests
    
    @Test("NetworkStatus properties")
    func testNetworkStatusProperties() async throws {
        #expect(NetworkStatus.wifi.isConnected == true)
        #expect(NetworkStatus.cellular.isConnected == true)
        #expect(NetworkStatus.limited.isConnected == true)
        #expect(NetworkStatus.unavailable.isConnected == false)
        #expect(NetworkStatus.unknown.isConnected == false)
        
        #expect(NetworkStatus.wifi.isSuitableForRealtime == true)
        #expect(NetworkStatus.cellular.isSuitableForRealtime == true)
        #expect(NetworkStatus.limited.isSuitableForRealtime == false)
        #expect(NetworkStatus.unavailable.isSuitableForRealtime == false)
        #expect(NetworkStatus.unknown.isSuitableForRealtime == false)
    }
    
    @Test("NetworkStatus display names")
    func testNetworkStatusDisplayNames() async throws {
        #expect(NetworkStatus.unknown.displayName == "未知")
        #expect(NetworkStatus.unavailable.displayName == "网络不可用")
        #expect(NetworkStatus.wifi.displayName == "WiFi")
        #expect(NetworkStatus.cellular.displayName == "蜂窝网络")
        #expect(NetworkStatus.limited.displayName == "受限网络")
    }
    
    @Test("NetworkStatus localized descriptions")
    func testNetworkStatusLocalizedDescriptions() async throws {
        let wifiDescription = NetworkStatus.wifi.getLocalizedDescription()
        #expect(!wifiDescription.isEmpty)
        
        let unavailableDescription = NetworkStatus.unavailable.getLocalizedDescription()
        #expect(!unavailableDescription.isEmpty)
    }
    
    // MARK: - Connection State Extensions Tests
    
    @Test("ConnectionState operational status")
    func testConnectionStateOperationalStatus() async throws {
        #expect(ConnectionState.connected.isOperational == true)
        #expect(ConnectionState.disconnected.isOperational == false)
        #expect(ConnectionState.connecting.isOperational == false)
        #expect(ConnectionState.reconnecting.isOperational == false)
        #expect(ConnectionState.failed.isOperational == false)
    }
    
    @Test("ConnectionState error status")
    func testConnectionStateErrorStatus() async throws {
        #expect(ConnectionState.failed.hasError == true)
        #expect(ConnectionState.connected.hasError == false)
        #expect(ConnectionState.disconnected.hasError == false)
        #expect(ConnectionState.connecting.hasError == false)
        #expect(ConnectionState.reconnecting.hasError == false)
    }
    
    @Test("ConnectionState localized descriptions")
    func testConnectionStateLocalizedDescriptions() async throws {
        let connectedDescription = ConnectionState.connected.getLocalizedDescription()
        #expect(!connectedDescription.isEmpty)
        
        let failedDescription = ConnectionState.failed.getLocalizedDescription()
        #expect(!failedDescription.isEmpty)
    }
    
    // MARK: - Connection Event Tests
    
    @Test("ConnectionEvent creation")
    func testConnectionEventCreation() async throws {
        let error = RealtimeError.networkUnavailable
        let event = ConnectionEvent(
            state: .failed,
            previousState: .connected,
            timestamp: Date(),
            error: error,
            networkStatus: .unavailable,
            reconnectionAttempt: 2
        )
        
        #expect(event.state == .failed)
        #expect(event.previousState == .connected)
        #expect(event.error == error)
        #expect(event.networkStatus == .unavailable)
        #expect(event.reconnectionAttempt == 2)
    }
    
    // MARK: - Connection Stats Tests
    
    @Test("ConnectionStats calculations")
    func testConnectionStatsCalculations() async throws {
        let stats = ConnectionStats(
            currentState: .connected,
            networkStatus: .wifi,
            totalConnections: 8,
            totalDisconnections: 3,
            totalFailures: 2,
            reconnectionAttempts: 1,
            averageConnectionDuration: 120.0,
            lastConnectionTime: Date(),
            lastDisconnectionTime: Date().addingTimeInterval(-60)
        )
        
        #expect(stats.connectionSuccessRate == 0.8) // 8 successes out of 10 attempts (8 + 2)
        #expect(stats.averageReconnectionTime == 5.0) // 5.0 * 1 attempt
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test("Reconnection with non-recoverable error")
    func testReconnectionWithNonRecoverableError() async throws {
        let config = ConnectionStateManager.ReconnectionConfig(
            maxReconnectionAttempts: 3,
            baseReconnectionDelay: 0.1,
            maxReconnectionDelay: 1.0,
            exponentialBackoffMultiplier: 1.0,
            networkMonitoringEnabled: false,
            connectionTimeoutInterval: 1.0
        )
        
        let manager = ConnectionStateManager(config: config)
        var reconnectionExhausted = false
        
        await MainActor.run {
            manager.onReconnectionExhausted = { _ in
                reconnectionExhausted = true
            }
        }
        
        let operation: () async throws -> Void = {
            throw RealtimeError.configurationError("Non-recoverable error")
        }
        
        manager.updateConnectionState(.disconnected)
        manager.startReconnection(operation: operation)
        
        // Wait for reconnection to fail
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(reconnectionExhausted == true)
        #expect(manager.connectionState == .failed)
    }
    
    @Test("Multiple concurrent reconnection attempts")
    func testMultipleConcurrentReconnectionAttempts() async throws {
        let manager = ConnectionStateManager()
        
        let operation1: () async throws -> Void = {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            manager.updateConnectionState(.connected)
        }
        
        let operation2: () async throws -> Void = {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            manager.updateConnectionState(.connected)
        }
        
        manager.updateConnectionState(.disconnected)
        
        // Start multiple reconnection attempts
        manager.startReconnection(operation: operation1)
        manager.startReconnection(operation: operation2) // Should cancel the first one
        
        // Wait for reconnection to complete
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        #expect(manager.connectionState == .connected)
    }
    
    @Test("Connection timeout handling")
    func testConnectionTimeoutHandling() async throws {
        let config = ConnectionStateManager.ReconnectionConfig(
            maxReconnectionAttempts: 1,
            baseReconnectionDelay: 0.1,
            maxReconnectionDelay: 1.0,
            exponentialBackoffMultiplier: 1.0,
            networkMonitoringEnabled: false,
            connectionTimeoutInterval: 0.2 // Short timeout for testing
        )
        
        let manager = ConnectionStateManager(config: config)
        var timeoutOccurred = false
        
        await MainActor.run {
            manager.onConnectionTimeout = {
                timeoutOccurred = true
            }
        }
        
        manager.updateConnectionState(.connecting)
        
        // Wait for timeout to occur
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        #expect(timeoutOccurred == true)
        #expect(manager.connectionState == .failed)
        #expect(manager.lastConnectionError == .connectionTimeout)
    }
}

// MARK: - Test Helpers

extension ConnectionStateManagerTests {
    
    /// Helper to create a mock successful connection operation
    private func createSuccessfulConnectionOperation(manager: ConnectionStateManager) -> () async throws -> Void {
        return {
            manager.updateConnectionState(.connected)
        }
    }
    
    /// Helper to create a mock failing connection operation
    private func createFailingConnectionOperation(error: RealtimeError) -> () async throws -> Void {
        return {
            throw error
        }
    }
    
    /// Helper to create a mock delayed connection operation
    private func createDelayedConnectionOperation(
        delay: TimeInterval,
        manager: ConnectionStateManager,
        shouldSucceed: Bool = true
    ) -> () async throws -> Void {
        return {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if shouldSucceed {
                manager.updateConnectionState(.connected)
            } else {
                throw RealtimeError.networkUnavailable
            }
        }
    }
}
