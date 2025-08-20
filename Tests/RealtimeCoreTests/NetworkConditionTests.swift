// NetworkConditionTests.swift
// Tests for handling various network conditions and connectivity scenarios

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Network Condition Tests")
@MainActor
struct NetworkConditionTests {
    
    // MARK: - Test Setup
    
    private func createRealtimeManager() -> RealtimeManager {
        let manager = RealtimeManager.shared
        manager.registerMockProvider()
        return manager
    }
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "test_app_id",
            appKey: "test_app_key",
            logLevel: .error // Reduce logging for network tests
        )
    }
    
    // MARK: - Connection Quality Tests
    
    @Test("Handle poor network conditions")
    func testHandlePoorNetworkConditions() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        // Simulate poor network conditions
        let poorConditions = NetworkConditions(
            latency: 500,        // 500ms latency
            packetLoss: 0.15,    // 15% packet loss
            bandwidth: 64,       // 64 kbps
            jitter: 100          // 100ms jitter
        )
        
        manager.simulateNetworkConditions(poorConditions)
        
        try await manager.joinRoom(
            roomId: "poor_network_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Test message sending under poor conditions
        let messageCount = 50
        var successfulMessages = 0
        var failedMessages = 0
        
        for i in 1...messageCount {
            do {
                let message = RealtimeMessage.text("Message \(i)", from: "test_user")
                try await manager.sendMessage(message)
                successfulMessages += 1
            } catch {
                failedMessages += 1
            }
        }
        
        // Should handle degraded performance gracefully
        #expect(successfulMessages > 0) // Some messages should succeed
        #expect(manager.connectionState != .disconnected) // Should maintain connection
        
        print("Poor network: \(successfulMessages) successful, \(failedMessages) failed messages")
        
        // Test audio settings under poor conditions
        try await manager.setAudioMixingVolume(75)
        #expect(manager.audioSettings.audioMixingVolume == 75)
        
        manager.resetNetworkSimulation()
    }
    
    @Test("Handle intermittent connectivity")
    func testHandleIntermittentConnectivity() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var connectionStateChanges: [ConnectionState] = []
        manager.onConnectionStateChanged = { state in
            connectionStateChanges.append(state)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "intermittent_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.connectionState == .connected)
        
        // Simulate connection drops and recoveries
        for cycle in 1...5 {
            print("Simulating connection drop cycle \(cycle)")
            
            // Simulate connection loss
            manager.simulateConnectionLoss()
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Simulate connection recovery
            manager.simulateConnectionRecovery()
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        // Should have multiple state changes
        #expect(connectionStateChanges.count >= 5)
        #expect(connectionStateChanges.contains(.reconnecting))
        
        // Should end up connected
        #expect(manager.connectionState == .connected)
    }
    
    @Test("Handle network timeout scenarios")
    func testHandleNetworkTimeoutScenarios() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        // Configure timeout settings
        manager.setNetworkTimeouts(
            connectionTimeout: 5.0,
            messageTimeout: 3.0,
            reconnectTimeout: 10.0
        )
        
        try await manager.joinRoom(
            roomId: "timeout_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Simulate network delays that cause timeouts
        manager.simulateNetworkDelay(8.0) // 8 second delay
        
        let startTime = Date()
        
        do {
            let message = RealtimeMessage.text("Timeout test message", from: "test_user")
            try await manager.sendMessage(message)
        } catch let error as RealtimeError {
            let duration = Date().timeIntervalSince(startTime)
            
            // Should timeout within expected time
            #expect(duration <= 4.0) // Should timeout before 4 seconds
            
            if case .networkTimeout = error {
                // Expected timeout error
            } else {
                throw error
            }
        }
        
        manager.resetNetworkSimulation()
    }
    
    @Test("Handle bandwidth limitations")
    func testHandleBandwidthLimitations() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "bandwidth_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Test different bandwidth scenarios
        let bandwidthScenarios = [
            (bandwidth: 1000, name: "High bandwidth"),
            (bandwidth: 256, name: "Medium bandwidth"),
            (bandwidth: 64, name: "Low bandwidth"),
            (bandwidth: 32, name: "Very low bandwidth")
        ]
        
        for scenario in bandwidthScenarios {
            print("Testing \(scenario.name): \(scenario.bandwidth) kbps")
            
            manager.simulateBandwidthLimit(scenario.bandwidth)
            
            // Test stream push under bandwidth constraints
            if scenario.bandwidth >= 256 {
                // Should support 720p
                let streamConfig = try StreamPushConfig.standard720p(
                    pushUrl: "rtmp://test.example.com/live/bandwidth_test"
                )
                try await manager.startStreamPush(config: streamConfig)
                #expect(manager.streamPushState == .running)
                try await manager.stopStreamPush()
            } else if scenario.bandwidth >= 64 {
                // Should support 480p
                let streamConfig = try StreamPushConfig.standard480p(
                    pushUrl: "rtmp://test.example.com/live/bandwidth_test"
                )
                try await manager.startStreamPush(config: streamConfig)
                #expect(manager.streamPushState == .running)
                try await manager.stopStreamPush()
            } else {
                // Very low bandwidth - stream push might fail
                let streamConfig = try StreamPushConfig.standard480p(
                    pushUrl: "rtmp://test.example.com/live/bandwidth_test"
                )
                
                do {
                    try await manager.startStreamPush(config: streamConfig)
                    try await manager.stopStreamPush()
                } catch {
                    // Expected to fail on very low bandwidth
                    print("Stream push failed on very low bandwidth as expected")
                }
            }
            
            // Test message throughput
            let messageCount = 20
            let startTime = Date()
            
            for i in 1...messageCount {
                let message = RealtimeMessage.text("Bandwidth test \(i)", from: "test_user")
                try await manager.sendMessage(message)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let throughput = Double(messageCount) / duration
            
            print("  Throughput: \(throughput) messages/sec")
            
            // Lower bandwidth should result in lower throughput
            if scenario.bandwidth >= 256 {
                #expect(throughput > 10) // High bandwidth
            } else {
                #expect(throughput > 2)  // Low bandwidth but still functional
            }
        }
        
        manager.resetNetworkSimulation()
    }
    
    // MARK: - Reconnection Tests
    
    @Test("Automatic reconnection with exponential backoff")
    func testAutomaticReconnectionWithExponentialBackoff() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var reconnectionAttempts: [(attempt: Int, delay: TimeInterval)] = []
        manager.onReconnectionAttempt = { attempt, delay in
            reconnectionAttempts.append((attempt: attempt, delay: delay))
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "reconnect_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Enable automatic reconnection with exponential backoff
        manager.enableAutoReconnect(
            maxAttempts: 5,
            initialDelay: 0.1,
            maxDelay: 2.0,
            backoffMultiplier: 2.0
        )
        
        // Simulate persistent connection failure
        manager.simulatePersistentConnectionFailure()
        
        // Wait for reconnection attempts
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        #expect(reconnectionAttempts.count > 0)
        
        // Verify exponential backoff
        if reconnectionAttempts.count >= 2 {
            let firstDelay = reconnectionAttempts[0].delay
            let secondDelay = reconnectionAttempts[1].delay
            #expect(secondDelay >= firstDelay * 1.5) // Should increase
        }
        
        // Simulate connection recovery
        manager.simulateConnectionRecovery()
        
        // Should eventually reconnect
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        #expect(manager.connectionState == .connected)
    }
    
    @Test("Reconnection with session restoration")
    func testReconnectionWithSessionRestoration() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "restore_room",
            userId: "restore_user",
            userName: "Restore User",
            userRole: .broadcaster
        )
        
        // Set up state before disconnection
        try await manager.setAudioMixingVolume(85)
        try await manager.muteMicrophone(true)
        try await manager.enableVolumeIndicator()
        
        let originalSession = manager.currentSession
        let originalSettings = manager.audioSettings
        
        // Simulate disconnection
        manager.simulateConnectionLoss()
        
        // Wait for disconnection
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Simulate reconnection
        manager.simulateConnectionRecovery()
        
        // Wait for session restoration
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify session and settings are restored
        #expect(manager.currentSession?.userId == originalSession?.userId)
        #expect(manager.currentSession?.roomId == originalSession?.roomId)
        #expect(manager.audioSettings.audioMixingVolume == originalSettings.audioMixingVolume)
        #expect(manager.audioSettings.microphoneMuted == originalSettings.microphoneMuted)
        #expect(manager.volumeIndicatorEnabled == true)
    }
    
    // MARK: - Network Quality Adaptation Tests
    
    @Test("Adaptive quality based on network conditions")
    func testAdaptiveQualityBasedOnNetworkConditions() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "adaptive_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Enable adaptive quality
        manager.enableAdaptiveQuality(true)
        
        var qualityChanges: [(condition: String, quality: StreamQuality)] = []
        manager.onQualityChanged = { condition, quality in
            qualityChanges.append((condition: condition, quality: quality))
        }
        
        // Start with good conditions
        let goodConditions = NetworkConditions(
            latency: 50,
            packetLoss: 0.01,
            bandwidth: 2000,
            jitter: 10
        )
        
        manager.simulateNetworkConditions(goodConditions)
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://test.example.com/live/adaptive_test"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Gradually degrade network conditions
        let degradedConditions = NetworkConditions(
            latency: 200,
            packetLoss: 0.05,
            bandwidth: 500,
            jitter: 50
        )
        
        manager.simulateNetworkConditions(degradedConditions)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let poorConditions = NetworkConditions(
            latency: 500,
            packetLoss: 0.15,
            bandwidth: 128,
            jitter: 100
        )
        
        manager.simulateNetworkConditions(poorConditions)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should adapt quality downward
        #expect(qualityChanges.count > 0)
        
        // Improve conditions
        manager.simulateNetworkConditions(goodConditions)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should adapt quality upward
        let finalQuality = manager.getCurrentStreamQuality()
        #expect(finalQuality.resolution.width >= 720) // Should improve back to at least 720p
        
        try await manager.stopStreamPush()
        manager.resetNetworkSimulation()
    }
    
    // MARK: - Concurrent Network Operations Tests
    
    @Test("Concurrent operations under network stress")
    func testConcurrentOperationsUnderNetworkStress() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "stress_room",
            userId: "stress_user",
            userName: "Stress User",
            userRole: .broadcaster
        )
        
        // Simulate network stress
        let stressConditions = NetworkConditions(
            latency: 300,
            packetLoss: 0.1,
            bandwidth: 256,
            jitter: 80
        )
        
        manager.simulateNetworkConditions(stressConditions)
        
        var completedTasks = 0
        let taskLock = NSLock()
        
        await withTaskGroup(of: Void.self) { group in
            // Message sending task
            group.addTask {
                for i in 1...50 {
                    do {
                        let message = RealtimeMessage.text("Stress message \(i)", from: "stress_user")
                        try await manager.sendMessage(message)
                    } catch {
                        // Handle network errors gracefully
                    }
                }
                
                taskLock.lock()
                completedTasks += 1
                taskLock.unlock()
            }
            
            // Volume updates task
            group.addTask {
                try? await manager.enableVolumeIndicator()
                
                for i in 1...100 {
                    let volumeInfos = [
                        UserVolumeInfo(userId: "user1", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "user2", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                    ]
                    manager.processVolumeUpdate(volumeInfos)
                    
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                
                taskLock.lock()
                completedTasks += 1
                taskLock.unlock()
            }
            
            // Audio settings task
            group.addTask {
                for i in 1...20 {
                    do {
                        try await manager.setAudioMixingVolume(i * 5)
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    } catch {
                        // Handle network errors gracefully
                    }
                }
                
                taskLock.lock()
                completedTasks += 1
                taskLock.unlock()
            }
        }
        
        #expect(completedTasks == 3)
        #expect(manager.connectionState != .disconnected)
        
        manager.resetNetworkSimulation()
    }
    
    // MARK: - Network Monitoring Tests
    
    @Test("Network quality monitoring and reporting")
    func testNetworkQualityMonitoringAndReporting() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var qualityReports: [NetworkQualityReport] = []
        manager.onNetworkQualityReport = { report in
            qualityReports.append(report)
        }
        
        try await manager.configure(provider: .mock, config: config)
        
        // Enable network quality monitoring
        manager.enableNetworkQualityMonitoring(interval: 0.1) // 100ms intervals
        
        try await manager.joinRoom(
            roomId: "monitoring_room",
            userId: "monitor_user",
            userName: "Monitor User",
            userRole: .broadcaster
        )
        
        // Simulate various network conditions over time
        let conditions = [
            NetworkConditions(latency: 50, packetLoss: 0.01, bandwidth: 2000, jitter: 10),
            NetworkConditions(latency: 100, packetLoss: 0.03, bandwidth: 1000, jitter: 20),
            NetworkConditions(latency: 200, packetLoss: 0.08, bandwidth: 500, jitter: 50),
            NetworkConditions(latency: 400, packetLoss: 0.15, bandwidth: 128, jitter: 100)
        ]
        
        for (index, condition) in conditions.enumerated() {
            print("Applying network condition \(index + 1)")
            manager.simulateNetworkConditions(condition)
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }
        
        // Should have received multiple quality reports
        #expect(qualityReports.count >= 4)
        
        // Verify quality degradation is detected
        let firstReport = qualityReports.first!
        let lastReport = qualityReports.last!
        
        #expect(firstReport.overallQuality > lastReport.overallQuality)
        #expect(lastReport.latency > firstReport.latency)
        #expect(lastReport.packetLoss > firstReport.packetLoss)
        
        manager.disableNetworkQualityMonitoring()
        manager.resetNetworkSimulation()
    }
    
    // MARK: - Helper Structures
    
    struct NetworkConditions {
        let latency: Int        // milliseconds
        let packetLoss: Double  // 0.0 - 1.0
        let bandwidth: Int      // kbps
        let jitter: Int         // milliseconds
    }
    
    struct StreamQuality {
        let resolution: (width: Int, height: Int)
        let bitrate: Int
        let framerate: Int
    }
    
    struct NetworkQualityReport {
        let timestamp: Date
        let overallQuality: Double  // 0.0 - 1.0
        let latency: Int
        let packetLoss: Double
        let bandwidth: Int
        let jitter: Int
    }
}