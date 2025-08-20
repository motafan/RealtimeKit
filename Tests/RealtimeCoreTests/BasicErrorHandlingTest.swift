// BasicErrorHandlingTest.swift
// Basic test to verify error handling functionality

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Basic Error Handling Test")
struct BasicErrorHandlingTest {
    
    @Test("RealtimeError basic properties")
    @MainActor
    func testBasicErrorProperties() async throws {
        // Test basic error properties
        let error = RealtimeError.connectionTimeout
        
        #expect(error.isRecoverable == true)
        #expect(error.severity == .medium)
        #expect(error.category == .connection)
        #expect(error.errorCode == "CONNECTION_TIMEOUT")
        #expect(error.errorDescription == "连接超时")
        #expect(error.recoverySuggestion == "请检查网络连接并重试")
    }
    
    @Test("Error recovery context creation")
    @MainActor
    func testErrorRecoveryContext() async throws {
        let error = RealtimeError.networkError("Test network error")
        let strategy = ErrorRecoveryStrategy.retry(maxAttempts: 3, delay: 1.0)
        
        let context = ErrorRecoveryContext(
            error: error,
            recoveryStrategy: strategy
        )
        
        #expect(context.error == error)
        #expect(context.shouldAttemptRecovery == true)
        #expect(context.nextAttemptDelay == 1.0)
    }
    
    @Test("Connection state manager basic functionality")
    @MainActor
    func testConnectionStateManager() async throws {
        let manager = ConnectionStateManager()
        
        // Test initial state
        #expect(manager.rtcConnectionState == .disconnected)
        #expect(manager.rtmConnectionState == .disconnected)
        #expect(manager.overallConnectionState == .disconnected)
        #expect(!manager.isConnected)
        #expect(!manager.isReconnecting)
        
        // Test state updates
        manager.updateRTCConnectionState(.connecting)
        #expect(manager.rtcConnectionState == .connecting)
        #expect(manager.overallConnectionState == .connecting)
        
        manager.updateRTMConnectionState(.connected)
        manager.updateRTCConnectionState(.connected)
        #expect(manager.overallConnectionState == .connected)
        #expect(manager.isConnected)
    }
}