// StreamPushManagerTests.swift
// Comprehensive unit tests for StreamPushManager

import Testing
import Foundation
@testable import RealtimeCore

@Suite("StreamPushManager Tests")
@MainActor
struct StreamPushManagerTests {
    
    // MARK: - Test Setup
    
    private func createManager() -> StreamPushManager {
        return StreamPushManager()
    }
    
    private func createTestConfig() throws -> StreamPushConfig {
        return try StreamPushConfig.standard720p(
            pushUrl: "rtmp://test.example.com/live/stream"
        )
    }
    
    private func createCustomConfig() throws -> StreamPushConfig {
        return try StreamPushConfig(
            pushUrl: "rtmp://custom.example.com/live/custom",
            width: 1920,
            height: 1080,
            videoBitrate: 4000,
            videoFramerate: 60,
            audioBitrate: 256,
            audioSampleRate: 48000
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("Manager initialization")
    func testManagerInitialization() {
        let manager = createManager()
        
        #expect(manager.currentState == .stopped)
        #expect(manager.currentConfig == nil)
        #expect(manager.isActive == false)
        #expect(manager.statistics.totalStreams == 0)
        #expect(manager.statistics.totalDuration == 0)
    }
    
    // MARK: - Stream Push Start Tests
    
    @Test("Start stream push with valid config")
    func testStartStreamPushWithValidConfig() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var stateChanges: [StreamPushState] = []
        manager.onStateChanged = { state in
            stateChanges.append(state)
        }
        
        try await manager.startStreamPush(config: config)
        
        #expect(manager.currentState == .running)
        #expect(manager.currentConfig?.pushUrl == config.pushUrl)
        #expect(manager.isActive == true)
        #expect(stateChanges.contains(.starting))
        #expect(stateChanges.contains(.running))
    }
    
    @Test("Start stream push when already running")
    func testStartStreamPushWhenAlreadyRunning() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start first stream
        try await manager.startStreamPush(config: config)
        #expect(manager.currentState == .running)
        
        // Try to start another stream
        do {
            try await manager.startStreamPush(config: config)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .alreadyInState(.running))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Start stream push with invalid config")
    func testStartStreamPushWithInvalidConfig() async {
        let manager = createManager()
        
        do {
            let invalidConfig = try StreamPushConfig.standard720p(
                pushUrl: "http://invalid.url" // Invalid scheme
            )
            try await manager.startStreamPush(config: invalidConfig)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(manager.currentState == .stopped)
            #expect(manager.currentConfig == nil)
        }
    }
    
    // MARK: - Stream Push Stop Tests
    
    @Test("Stop stream push when running")
    func testStopStreamPushWhenRunning() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var stateChanges: [StreamPushState] = []
        manager.onStateChanged = { state in
            stateChanges.append(state)
        }
        
        // Start stream
        try await manager.startStreamPush(config: config)
        #expect(manager.currentState == .running)
        
        // Stop stream
        try await manager.stopStreamPush()
        
        #expect(manager.currentState == .stopped)
        #expect(manager.isActive == false)
        #expect(stateChanges.contains(.stopping))
        #expect(stateChanges.contains(.stopped))
    }
    
    @Test("Stop stream push when not running")
    func testStopStreamPushWhenNotRunning() async {
        let manager = createManager()
        
        do {
            try await manager.stopStreamPush()
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .alreadyInState(.stopped))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Layout Update Tests
    
    @Test("Update stream layout when running")
    func testUpdateStreamLayoutWhenRunning() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start stream
        try await manager.startStreamPush(config: config)
        
        let newLayout = StreamLayout(
            backgroundColor: "#FF0000",
            userRegions: [
                UserRegion(
                    userId: "user1",
                    x: 0, y: 0,
                    width: 640, height: 360,
                    zOrder: 1,
                    alpha: 1.0
                ),
                UserRegion(
                    userId: "user2",
                    x: 640, y: 0,
                    width: 640, height: 360,
                    zOrder: 2,
                    alpha: 0.8
                )
            ]
        )
        
        try await manager.updateStreamLayout(layout: newLayout)
        
        #expect(manager.currentLayout?.backgroundColor == "#FF0000")
        #expect(manager.currentLayout?.userRegions.count == 2)
    }
    
    @Test("Update stream layout when not running")
    func testUpdateStreamLayoutWhenNotRunning() async {
        let manager = createManager()
        
        let layout = StreamLayout(
            backgroundColor: "#000000",
            userRegions: []
        )
        
        do {
            try await manager.updateStreamLayout(layout: layout)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            #expect(error == .notInState(.running))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Update stream layout with invalid layout")
    func testUpdateStreamLayoutWithInvalidLayout() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        try await manager.startStreamPush(config: config)
        
        // Create layout with overlapping regions (invalid)
        let invalidLayout = StreamLayout(
            backgroundColor: "#000000",
            userRegions: [
                UserRegion(
                    userId: "user1",
                    x: 0, y: 0,
                    width: 1000, height: 1000, // Exceeds stream dimensions
                    zOrder: 1,
                    alpha: 1.0
                )
            ]
        )
        
        do {
            try await manager.updateStreamLayout(layout: invalidLayout)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            if case .invalidConfiguration(let message) = error {
                #expect(message.contains("layout"))
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Stream Statistics Tests
    
    @Test("Stream statistics tracking")
    func testStreamStatisticsTracking() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start and stop multiple streams
        for _ in 1...3 {
            try await manager.startStreamPush(config: config)
            
            // Simulate some streaming time
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            try await manager.stopStreamPush()
        }
        
        let stats = manager.statistics
        #expect(stats.totalStreams == 3)
        #expect(stats.totalDuration > 0.2) // At least 0.2 seconds total
        #expect(stats.averageStreamDuration > 0.05) // At least 0.05 seconds average
    }
    
    @Test("Stream quality metrics")
    func testStreamQualityMetrics() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        try await manager.startStreamPush(config: config)
        
        // Simulate quality updates
        manager.updateStreamQuality(
            videoBitrate: 1800,
            audioBitrate: 120,
            frameRate: 28,
            droppedFrames: 5
        )
        
        let quality = manager.currentQuality
        #expect(quality.videoBitrate == 1800)
        #expect(quality.audioBitrate == 120)
        #expect(quality.frameRate == 28)
        #expect(quality.droppedFrames == 5)
        #expect(quality.qualityScore < 1.0) // Should be less than perfect due to dropped frames
        
        try await manager.stopStreamPush()
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle stream connection failure")
    func testHandleStreamConnectionFailure() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var errorReceived: RealtimeError?
        manager.onError = { error in
            errorReceived = error
        }
        
        try await manager.startStreamPush(config: config)
        
        // Simulate connection failure
        let connectionError = RealtimeError.networkError("RTMP connection failed")
        manager.handleStreamError(connectionError)
        
        #expect(errorReceived != nil)
        #expect(manager.currentState == .error)
    }
    
    @Test("Handle stream encoding failure")
    func testHandleStreamEncodingFailure() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var errorReceived: RealtimeError?
        manager.onError = { error in
            errorReceived = error
        }
        
        try await manager.startStreamPush(config: config)
        
        // Simulate encoding failure
        let encodingError = RealtimeError.providerError("Video encoding failed", underlying: nil)
        manager.handleStreamError(encodingError)
        
        #expect(errorReceived != nil)
        #expect(manager.currentState == .error)
    }
    
    @Test("Automatic recovery from transient errors")
    func testAutomaticRecoveryFromTransientErrors() async throws {
        let manager = createManager()
        manager.enableAutoRecovery(maxAttempts: 3, retryDelay: 0.1)
        
        let config = try createTestConfig()
        
        var recoveryAttempts: [RealtimeError] = []
        manager.onRecoveryAttempt = { error in
            recoveryAttempts.append(error)
        }
        
        try await manager.startStreamPush(config: config)
        
        // Simulate transient network error
        let transientError = RealtimeError.networkError("Temporary connection loss")
        manager.handleStreamError(transientError)
        
        // Wait for recovery attempts
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(recoveryAttempts.count > 0)
    }
    
    // MARK: - Configuration Tests
    
    @Test("Stream configuration validation")
    func testStreamConfigurationValidation() throws {
        // Valid configurations
        #expect(throws: Never.self) {
            let _ = try StreamPushConfig.standard480p(pushUrl: "rtmp://test.com/live")
        }
        
        #expect(throws: Never.self) {
            let _ = try StreamPushConfig.standard720p(pushUrl: "rtmps://secure.test.com/live")
        }
        
        #expect(throws: Never.self) {
            let _ = try StreamPushConfig.standard1080p(pushUrl: "rtmp://hd.test.com/live")
        }
        
        // Invalid configurations
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig.standard720p(pushUrl: "http://invalid.com/stream")
        }
        
        #expect(throws: RealtimeError.self) {
            let _ = try StreamPushConfig(
                pushUrl: "rtmp://test.com/live",
                width: 0, // Invalid
                height: 720,
                videoBitrate: 2000,
                videoFramerate: 30,
                audioBitrate: 128,
                audioSampleRate: 44100
            )
        }
    }
    
    @Test("Stream layout validation")
    func testStreamLayoutValidation() {
        // Valid layout
        let validLayout = StreamLayout(
            backgroundColor: "#000000",
            userRegions: [
                UserRegion(
                    userId: "user1",
                    x: 0, y: 0,
                    width: 640, height: 360,
                    zOrder: 1,
                    alpha: 1.0
                )
            ]
        )
        #expect(validLayout.isValid(for: CGSize(width: 1280, height: 720)))
        
        // Invalid layout - region exceeds bounds
        let invalidLayout = StreamLayout(
            backgroundColor: "#000000",
            userRegions: [
                UserRegion(
                    userId: "user1",
                    x: 1000, y: 500, // Exceeds stream bounds
                    width: 640, height: 360,
                    zOrder: 1,
                    alpha: 1.0
                )
            ]
        )
        #expect(!invalidLayout.isValid(for: CGSize(width: 1280, height: 720)))
    }
    
    // MARK: - Performance Tests
    
    @Test("Stream start/stop performance")
    func testStreamStartStopPerformance() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        let startTime = Date()
        
        // Perform multiple start/stop cycles
        for _ in 1...5 {
            try await manager.startStreamPush(config: config)
            try await manager.stopStreamPush()
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 5.0) // 5 seconds for 5 cycles
    }
    
    @Test("Layout update performance")
    func testLayoutUpdatePerformance() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        try await manager.startStreamPush(config: config)
        
        let startTime = Date()
        
        // Perform multiple layout updates
        for i in 1...10 {
            let layout = StreamLayout(
                backgroundColor: "#000000",
                userRegions: [
                    UserRegion(
                        userId: "user\(i)",
                        x: i * 10, y: i * 10,
                        width: 200, height: 200,
                        zOrder: i,
                        alpha: 1.0
                    )
                ]
            )
            try await manager.updateStreamLayout(layout: layout)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 2.0) // 2 seconds for 10 updates
        
        try await manager.stopStreamPush()
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("Concurrent stream operations")
    func testConcurrentStreamOperations() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Start stream
        try await manager.startStreamPush(config: config)
        
        // Perform concurrent layout updates
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    let layout = StreamLayout(
                        backgroundColor: "#00000\(i)",
                        userRegions: [
                            UserRegion(
                                userId: "user\(i)",
                                x: 0, y: 0,
                                width: 100, height: 100,
                                zOrder: i,
                                alpha: 1.0
                            )
                        ]
                    )
                    
                    do {
                        try await manager.updateStreamLayout(layout: layout)
                    } catch {
                        // Some updates might fail due to concurrent access
                    }
                }
            }
        }
        
        // Should handle concurrent operations without crashing
        #expect(manager.currentState == .running)
        
        try await manager.stopStreamPush()
    }
    
    // MARK: - State Management Tests
    
    @Test("State transition validation")
    func testStateTransitionValidation() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        // Valid transitions
        #expect(manager.currentState == .stopped)
        
        try await manager.startStreamPush(config: config)
        #expect(manager.currentState == .running)
        
        try await manager.stopStreamPush()
        #expect(manager.currentState == .stopped)
    }
    
    @Test("State change notifications")
    func testStateChangeNotifications() async throws {
        let manager = createManager()
        let config = try createTestConfig()
        
        var stateChanges: [(StreamPushState, StreamPushState?)] = []
        manager.onStateChanged = { newState in
            stateChanges.append((newState, manager.previousState))
        }
        
        try await manager.startStreamPush(config: config)
        try await manager.stopStreamPush()
        
        #expect(stateChanges.count >= 4) // starting, running, stopping, stopped
        
        // Check state progression
        let states = stateChanges.map { $0.0 }
        #expect(states.contains(.starting))
        #expect(states.contains(.running))
        #expect(states.contains(.stopping))
        #expect(states.contains(.stopped))
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Manager cleanup on deallocation")
    func testManagerCleanupOnDeallocation() async throws {
        var manager: StreamPushManager? = createManager()
        
        weak var weakManager = manager
        
        let config = try createTestConfig()
        try await manager?.startStreamPush(config: config)
        try await manager?.stopStreamPush()
        
        manager = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakManager == nil)
    }
    
    // MARK: - Integration Tests
    
    @Test("End-to-end stream lifecycle")
    func testEndToEndStreamLifecycle() async throws {
        let manager = createManager()
        let config = try createCustomConfig()
        
        var events: [String] = []
        
        manager.onStateChanged = { state in
            events.append("state: \(state)")
        }
        
        manager.onError = { error in
            events.append("error: \(error.localizedDescription)")
        }
        
        // Complete lifecycle
        try await manager.startStreamPush(config: config)
        
        // Update layout during streaming
        let layout = StreamLayout(
            backgroundColor: "#FFFFFF",
            userRegions: [
                UserRegion(
                    userId: "presenter",
                    x: 0, y: 0,
                    width: 1920, height: 1080,
                    zOrder: 1,
                    alpha: 1.0
                )
            ]
        )
        try await manager.updateStreamLayout(layout: layout)
        
        // Simulate streaming time
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        try await manager.stopStreamPush()
        
        // Verify events occurred
        #expect(events.count >= 4)
        #expect(events.contains { $0.contains("starting") })
        #expect(events.contains { $0.contains("running") })
        #expect(events.contains { $0.contains("stopping") })
        #expect(events.contains { $0.contains("stopped") })
        
        // Verify final state
        #expect(manager.currentState == .stopped)
        #expect(manager.statistics.totalStreams == 1)
        #expect(manager.statistics.totalDuration > 0.1)
    }
}