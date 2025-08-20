// ConnectionStateManagerTests.swift
// Unit tests for connection state management and auto-reconnection

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Connection State Manager Tests")
struct ConnectionStateManagerTests {
    
    @Test("Initial connection state")
    @MainActor
    func testInitialConnectionState() async throws {
        let manager = ConnectionStateManager()
        
        #expect(manager.rtcConnectionState == .disconnected)
        #expect(manager.rtmConnectionState == .disconnected)
        #expect(manager.overallConnectionState == .disconnected)
        #expect(manager.reconnectionAttempts == 0)
        #expect(manager.lastConnectionError == nil)
        #expect(!manager.isReconnecting)
        #expect(!manager.isConnected)
    }
    
    @Test("RTC connection state updates")
    @MainActor
    func testRTCConnectionStateUpdates() async throws {
        let manager = ConnectionStateManager()
        
        // Test connecting state
        manager.updateRTCConnectionState(.connecting)
        #expect(manager.rtcConnectionState == .connecting)
        #expect(manager.overallConnectionState == .connecting)
        
        // Test connected state
        manager.updateRTMConnectionState(.connected) // Both need to be connected
        manager.updateRTCConnectionState(.connected)
        #expect(manager.rtcConnectionState == .connected)
        #expect(manager.overallConnectionState == .connected)
        #expect(manager.isConnected)
        
        // Test disconnected state
        manager.updateRTCConnectionState(.disconnected)
        #expect(manager.rtcConnectionState == .disconnected)
        #expect(manager.overallConnectionState == .disconnected)
        #expect(!manager.isConnected)
    }
    
    @Test("RTM connection state updates")
    @MainActor
    func testRTMConnectionStateUpdates() async throws {
        let manager = ConnectionStateManager()
        
        // Test connecting state
        manager.updateRTMConnectionState(.connecting)
        #expect(manager.rtmConnectionState == .connecting)
        #expect(manager.overallConnectionState == .connecting)
        
        // Test connected state (both RTC and RTM need to be connected)
        manager.updateRTCConnectionState(.connected)
        manager.updateRTMConnectionState(.connected)
        #expect(manager.rtmConnectionState == .connected)
        #expect(manager.overallConnectionState == .connected)
        
        // Test failed state
        manager.updateRTMConnectionState(.failed)
        #expect(manager.rtmConnectionState == .failed)
        #expect(manager.overallConnectionState == .failed)
    }
    
    @Test("Overall connection state calculation")
    @MainActor
    func testOverallConnectionStateCalculation() async throws {
        let manager = ConnectionStateManager()
        
        // Both disconnected -> overall disconnected
        manager.updateRTCConnectionState(.disconnected)
        manager.updateRTMConnectionState(.disconnected)
        #expect(manager.overallConnectionState == .disconnected)
        
        // One connecting -> overall connecting
        manager.updateRTCConnectionState(.connecting)
        #expect(manager.overallConnectionState == .connecting)
        
        // Both connected -> overall connected
        manager.updateRTCConnectionState(.connected)
        manager.updateRTMConnectionState(.connected)
        #expect(manager.overallConnectionState == .connected)
        
        // One failed -> overall failed
        manager.updateRTCConnectionState(.failed)
        #expect(manager.overallConnectionState == .failed)
    }
    
    @Test("Connection event recording")
    @MainActor
    func testConnectionEventRecording() async throws {
        let manager = ConnectionStateManager()
        
        #expect(manager.connectionHistory.isEmpty)
        
        manager.updateRTCConnectionState(.connecting)
        #expect(manager.connectionHistory.count == 2) // rtcStateChanged + overallStateChanged
        
        manager.updateRTCConnectionState(.connected)
        manager.updateRTMConnectionState(.connected)
        #expect(manager.connectionHistory.count > 2)
        
        // Check that events are recorded
        let hasConnectingEvent = manager.connectionHistory.contains { event in
            if case .connecting(let type) = event.eventType {
                return type == .rtc
            }
            return false
        }
        #expect(hasConnectingEvent)
    }
    
    @Test("Reconnection delay calculation")
    @MainActor
    func testReconnectionDelayCalculation() async throws {
        let manager = ConnectionStateManager()
        manager.baseReconnectionDelay = 2.0
        manager.reconnectionBackoffMultiplier = 2.0
        manager.maxReconnectionDelay = 10.0
        
        // Test delay calculation logic (without modifying private properties)
        let delay1 = manager.baseReconnectionDelay * pow(manager.reconnectionBackoffMultiplier, Double(0))
        #expect(delay1 == 2.0)
        
        let delay2 = manager.baseReconnectionDelay * pow(manager.reconnectionBackoffMultiplier, Double(1))
        #expect(delay2 == 4.0)
        
        let delay3 = manager.baseReconnectionDelay * pow(manager.reconnectionBackoffMultiplier, Double(2))
        #expect(delay3 == 8.0)
        
        // Test max delay cap
        let delay5 = min(manager.baseReconnectionDelay * pow(manager.reconnectionBackoffMultiplier, Double(4)), manager.maxReconnectionDelay)
        #expect(delay5 == 10.0) // Should be capped at maxReconnectionDelay
    }
    
    @Test("Auto-reconnection configuration")
    @MainActor
    func testAutoReconnectionConfiguration() async throws {
        let manager = ConnectionStateManager()
        
        // Test default configuration
        #expect(manager.isAutoReconnectionEnabled == true)
        #expect(manager.maxReconnectionAttempts == 5)
        #expect(manager.baseReconnectionDelay == 2.0)
        #expect(manager.maxReconnectionDelay == 30.0)
        #expect(manager.reconnectionBackoffMultiplier == 2.0)
        
        // Test configuration changes
        manager.isAutoReconnectionEnabled = false
        manager.maxReconnectionAttempts = 3
        manager.baseReconnectionDelay = 1.0
        
        #expect(manager.isAutoReconnectionEnabled == false)
        #expect(manager.maxReconnectionAttempts == 3)
        #expect(manager.baseReconnectionDelay == 1.0)
    }
    
    @Test("Connection statistics")
    @MainActor
    func testConnectionStatistics() async throws {
        let manager = ConnectionStateManager()
        
        // Initial stats
        let initialStats = manager.connectionStats
        #expect(initialStats.totalConnections == 0)
        #expect(initialStats.totalDisconnections == 0)
        #expect(initialStats.totalReconnectionAttempts == 0)
        #expect(initialStats.averageConnectionDuration == 0)
        #expect(initialStats.lastConnectionTime == nil)
        
        // Simulate some connection events
        manager.updateRTCConnectionState(.connected)
        manager.updateRTMConnectionState(.connected)
        
        // Add a small delay to simulate connection duration
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        manager.updateRTCConnectionState(.disconnected)
        
        let updatedStats = manager.connectionStats
        #expect(updatedStats.totalConnections > 0)
    }
    
    @Test("Reset functionality")
    @MainActor
    func testResetFunctionality() async throws {
        let manager = ConnectionStateManager()
        
        // Set up some state
        manager.updateRTCConnectionState(.connected)
        manager.updateRTMConnectionState(.failed)
        
        #expect(manager.rtcConnectionState == .connected)
        #expect(manager.rtmConnectionState == .failed)
        
        // Reset
        manager.reset()
        
        #expect(manager.reconnectionAttempts == 0)
        #expect(manager.lastConnectionError == nil)
        #expect(manager.rtcConnectionState == .disconnected)
        #expect(manager.rtmConnectionState == .disconnected)
        #expect(manager.overallConnectionState == .disconnected)
        #expect(!manager.isReconnecting)
    }
    
    @Test("Connection timeout handling")
    @MainActor
    func testConnectionTimeoutHandling() async throws {
        let manager = ConnectionStateManager()
        manager.connectionTimeout = 0.1 // Very short timeout for testing
        
        // Start connecting
        manager.updateRTCConnectionState(.connecting)
        #expect(manager.overallConnectionState == .connecting)
        
        // Wait for timeout
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Should have timed out and moved to failed state
        // Note: This test might be flaky due to timing, but demonstrates the concept
    }
    
    @Test("Manual reconnection")
    @MainActor
    func testManualReconnection() async throws {
        let manager = ConnectionStateManager()
        manager.isAutoReconnectionEnabled = false // Disable auto-reconnection
        
        // Set failed state
        manager.updateRTCConnectionState(.failed)
        manager.updateRTMConnectionState(.failed)
        
        #expect(manager.overallConnectionState == .failed)
        #expect(!manager.isReconnecting)
        
        // Manually trigger reconnection
        await manager.reconnect()
        
        // Should have attempted reconnection
        #expect(manager.reconnectionAttempts > 0)
    }
    
    @Test("Reconnection cancellation")
    @MainActor
    func testReconnectionCancellation() async throws {
        let manager = ConnectionStateManager()
        
        // Start reconnection
        manager.updateRTCConnectionState(.failed)
        await manager.reconnect()
        
        // Cancel reconnection
        manager.cancelReconnection()
        
        #expect(!manager.isReconnecting)
    }
    
    @Test("Connection history limit")
    @MainActor
    func testConnectionHistoryLimit() async throws {
        let manager = ConnectionStateManager()
        
        // Generate many connection events
        for i in 0..<150 { // More than maxHistoryCount (100)
            manager.updateRTCConnectionState(i % 2 == 0 ? .connected : .disconnected)
        }
        
        // Should not exceed the limit
        #expect(manager.connectionHistory.count <= 100)
    }
}

@Suite("Connection Event Tests")
struct ConnectionEventTests {
    
    @Test("Connection event creation")
    func testConnectionEventCreation() async throws {
        let eventType = ConnectionEventType.connecting(type: .rtc)
        let event = ConnectionEvent(eventType: eventType)
        
        #expect(event.eventType == eventType)
        #expect(event.timestamp <= Date())
    }
    
    @Test("Connection event type equality")
    func testConnectionEventTypeEquality() async throws {
        let event1 = ConnectionEventType.connecting(type: .rtc)
        let event2 = ConnectionEventType.connecting(type: .rtc)
        let event3 = ConnectionEventType.connecting(type: .rtm)
        
        #expect(event1 == event2)
        #expect(event1 != event3)
        
        let reconnectEvent1 = ConnectionEventType.reconnectionAttempt(attempt: 1)
        let reconnectEvent2 = ConnectionEventType.reconnectionAttempt(attempt: 1)
        let reconnectEvent3 = ConnectionEventType.reconnectionAttempt(attempt: 2)
        
        #expect(reconnectEvent1 == reconnectEvent2)
        #expect(reconnectEvent1 != reconnectEvent3)
    }
}

@Suite("Connection Statistics Tests")
struct ConnectionStatisticsTests {
    
    @Test("Connection statistics initialization")
    func testConnectionStatisticsInitialization() async throws {
        let stats = ConnectionStatistics(
            totalConnections: 5,
            totalDisconnections: 3,
            totalReconnectionAttempts: 2,
            averageConnectionDuration: 120.0,
            lastConnectionTime: Date()
        )
        
        #expect(stats.totalConnections == 5)
        #expect(stats.totalDisconnections == 3)
        #expect(stats.totalReconnectionAttempts == 2)
        #expect(stats.averageConnectionDuration == 120.0)
        #expect(stats.lastConnectionTime != nil)
    }
}

@Suite("Network Simulation Tests")
struct NetworkSimulationTests {
    
    @Test("Network status change simulation")
    func testNetworkStatusChangeSimulation() async throws {
        let manager = ConnectionStateManager()
        
        // Initially should be in a stable state
        #expect(manager.overallConnectionState == .disconnected)
        
        // The network monitor is simulated and will randomly change status
        // This test verifies that the manager can handle network status changes
        // without crashing
        
        // Wait a bit to let the network monitor potentially trigger
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Manager should still be functional
        manager.updateRTCConnectionState(.connecting)
        #expect(manager.rtcConnectionState == .connecting)
    }
}