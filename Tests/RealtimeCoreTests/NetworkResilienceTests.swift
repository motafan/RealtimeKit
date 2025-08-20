// NetworkResilienceTests.swift
// Comprehensive network resilience and error recovery tests

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Network Resilience Tests")
@MainActor
struct NetworkResilienceTests {
    
    // MARK: - Test Setup
    
    private func createRealtimeManager() -> RealtimeManager {
        let manager = RealtimeManager.shared
        manager.registerMockProvider()
        return manager
    }
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "network_test_app_id",
            appKey: "network_test_app_key",
            logLevel: .info
        )
    }
    
    // MARK: - Network Failure Recovery Tests
    
    @Test("Complete network failure and recovery")
    func testCompleteNetworkFailureAndRecovery() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var recoveryEvents: [NetworkRecoveryEvent] = []
        manager.onNetworkRecoveryEvent = { event in
            recoveryEvents.append(event)
        }
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "network_failure_room",
            userId: "network_user",
            userName: "Network User",
            userRole: .broadcaster
        )
        
        // Set up active session with all features
        try await manager.setAudioMixingVolume(80)
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://network.failure.test.com/live/failure_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Set up media relay
        let sourceChannel = try RelayChannelInfo(
            channelName: "network_failure_room",
            userId: "network_user"
        )
        let destChannel = try RelayChannelInfo(
            channelName: "network_backup_room",
            userId: "network_user"
        )
        try await manager.startOneToOneRelay(source: sourceChannel, destination: destChannel)
        
        // Verify initial state
        #expect(manager.connectionState == .connected)
        #expect(manager.streamPushState == .running)
        #expect(manager.isMediaRelayActive == true)
        
        print("Simulating complete network failure...")
        
        // Simulate complete network failure
        manager.simulateCompleteNetworkFailure()
        
        // Wait for failure detection
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should detect failure and start recovery
        #expect(manager.connectionState == .reconnecting || manager.connectionState == .disconnected)
        
        // Continue operations during failure (should queue or fail gracefully)
        for i in 1...10 {
            do {
                let message = RealtimeMessage.text("Failure message \(i)", from: "network_user")
                try await manager.sendMessage(message)
            } catch {
                // Expected to fail during network outage
                print("Message \(i) failed as expected during network failure")
            }
        }
        
        // Simulate network recovery after 3 seconds
        try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 more seconds
        
        print("Simulating network recovery...")
        manager.simulateNetworkRecovery()
        
        // Wait for recovery
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Should recover connection
        #expect(manager.connectionState == .connected)
        
        // Verify session state is restored
        #expect(manager.currentSession?.userId == "network_user")
        #expect(manager.audioSettings.audioMixingVolume == 80)
        
        // Test functionality after recovery
        let recoveryMessage = RealtimeMessage.text("Recovery test message", from: "network_user")
        try await manager.sendMessage(recoveryMessage)
        
        // Volume indicator should work
        let volumeInfos = [
            UserVolumeInfo(userId: "network_user", volume: 0.8, isSpeaking: true)
        ]
        manager.processVolumeUpdate(volumeInfos)
        
        // Stream and relay should be restored or restartable
        if manager.streamPushState != .running {
            try await manager.startStreamPush(config: streamConfig)
        }
        #expect(manager.streamPushState == .running)
        
        if !manager.isMediaRelayActive {
            try await manager.startOneToOneRelay(source: sourceChannel, destination: destChannel)
        }
        #expect(manager.isMediaRelayActive == true)
        
        print("Network failure recovery test completed with \(recoveryEvents.count) recovery events")
        
        // Cleanup
        try await manager.stopMediaRelay()
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
        
        // Verify recovery events were recorded
        #expect(recoveryEvents.count > 0)
        #expect(recoveryEvents.contains { $0.eventType == .networkFailureDetected })
        #expect(recoveryEvents.contains { $0.eventType == .recoveryAttempted })
    }
    
    @Test("Intermittent connectivity stress test")
    func testIntermittentConnectivityStressTest() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "intermittent_room",
            userId: "intermittent_user",
            userName: "Intermittent User",
            userRole: .broadcaster
        )
        
        var connectionEvents: [ConnectionEvent] = []
        manager.onConnectionStateChanged = { state in
            connectionEvents.append(ConnectionEvent(state: state, timestamp: Date()))
        }
        
        try await manager.enableVolumeIndicator()
        
        let testDuration: TimeInterval = 20.0 // 20 seconds of intermittent connectivity
        let startTime = Date()
        
        var successfulOperations = 0
        var failedOperations = 0
        let operationLock = NSLock()
        
        print("Starting intermittent connectivity stress test for \(testDuration) seconds...")
        
        // Generate intermittent network issues
        let networkTask = Task {
            var cycleCount = 0
            while Date().timeIntervalSince(startTime) < testDuration {
                cycleCount += 1
                
                // Simulate different types of network issues
                let issueType = cycleCount % 4
                
                switch issueType {
                case 0:
                    // Brief disconnection (1 second)
                    print("Cycle \(cycleCount): Brief disconnection")
                    manager.simulateConnectionLoss()
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    manager.simulateConnectionRecovery()
                    
                case 1:
                    // High latency (2 seconds)
                    print("Cycle \(cycleCount): High latency")
                    manager.simulateNetworkConditions(latency: 2.0, packetLoss: 0.05, bandwidth: 500)
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    manager.resetNetworkSimulation()
                    
                case 2:
                    // Packet loss (1.5 seconds)
                    print("Cycle \(cycleCount): High packet loss")
                    manager.simulateNetworkConditions(latency: 0.2, packetLoss: 0.3, bandwidth: 1000)
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    manager.resetNetworkSimulation()
                    
                case 3:
                    // Low bandwidth (2.5 seconds)
                    print("Cycle \(cycleCount): Low bandwidth")
                    manager.simulateNetworkConditions(latency: 0.3, packetLoss: 0.1, bandwidth: 32)
                    try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
                    manager.resetNetworkSimulation()
                    
                default:
                    break
                }
                
                // Good connection period (1 second)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        // Generate continuous operations during network issues
        let operationsTask = Task {
            var operationCount = 0
            
            while Date().timeIntervalSince(startTime) < testDuration {
                operationCount += 1
                
                // Try various operations
                do {
                    switch operationCount % 5 {
                    case 0:
                        // Message sending
                        let message = RealtimeMessage.text("Intermittent message \(operationCount)", from: "intermittent_user")
                        try await manager.sendMessage(message)
                        
                    case 1:
                        // Audio settings
                        try await manager.setAudioMixingVolume(operationCount % 101)
                        
                    case 2:
                        // Volume updates
                        let volumeInfos = [
                            UserVolumeInfo(userId: "intermittent_user", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                        ]
                        manager.processVolumeUpdate(volumeInfos)
                        
                    case 3:
                        // Microphone toggle
                        try await manager.muteMicrophone(operationCount % 2 == 0)
                        
                    case 4:
                        // Stream operations (if not already running)
                        if manager.streamPushState == .stopped && operationCount % 20 == 0 {
                            let streamConfig = try StreamPushConfig.standard720p(
                                pushUrl: "rtmp://intermittent.test.com/live/intermittent_stream"
                            )
                            try await manager.startStreamPush(config: streamConfig)
                        }
                        
                    default:
                        break
                    }
                    
                    operationLock.lock()
                    successfulOperations += 1
                    operationLock.unlock()
                    
                } catch {
                    operationLock.lock()
                    failedOperations += 1
                    operationLock.unlock()
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms between operations
            }
        }
        
        // Wait for both tasks to complete
        await networkTask.value
        await operationsTask.value
        
        let actualDuration = Date().timeIntervalSince(startTime)
        
        print("Intermittent connectivity stress test completed:")
        print("  Duration: \(String(format: "%.2f", actualDuration))s")
        print("  Successful operations: \(successfulOperations)")
        print("  Failed operations: \(failedOperations)")
        print("  Success rate: \(String(format: "%.1f", Double(successfulOperations) / Double(successfulOperations + failedOperations) * 100))%")
        print("  Connection events: \(connectionEvents.count)")
        
        // Analyze connection stability
        let connectionStates = connectionEvents.map { $0.state }
        let connectedCount = connectionStates.filter { $0 == .connected }.count
        let reconnectingCount = connectionStates.filter { $0 == .reconnecting }.count
        let disconnectedCount = connectionStates.filter { $0 == .disconnected }.count
        
        print("  Connected events: \(connectedCount)")
        print("  Reconnecting events: \(reconnectingCount)")
        print("  Disconnected events: \(disconnectedCount)")
        
        // Performance assertions
        #expect(successfulOperations > 0, "Should have some successful operations")
        let successRate = Double(successfulOperations) / Double(successfulOperations + failedOperations)
        #expect(successRate > 0.3, "Success rate should be > 30% even under intermittent connectivity")
        
        // Should eventually return to connected state
        #expect(manager.connectionState == .connected || manager.connectionState == .reconnecting)
        
        // Cleanup
        if manager.streamPushState == .running {
            try await manager.stopStreamPush()
        }
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
    
    @Test("Network quality adaptation test")
    func testNetworkQualityAdaptationTest() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "adaptation_room",
            userId: "adaptation_user",
            userName: "Adaptation User",
            userRole: .broadcaster
        )
        
        // Enable adaptive quality
        manager.enableAdaptiveQuality(true)
        
        var qualityAdaptations: [QualityAdaptation] = []
        manager.onQualityAdaptation = { adaptation in
            qualityAdaptations.append(adaptation)
        }
        
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://adaptation.test.com/live/adaptation_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Test different network conditions and verify adaptation
        let networkScenarios = [
            NetworkCondition(name: "Excellent", latency: 20, packetLoss: 0.001, bandwidth: 5000, expectedQuality: .high),
            NetworkCondition(name: "Good", latency: 50, packetLoss: 0.01, bandwidth: 2000, expectedQuality: .high),
            NetworkCondition(name: "Fair", latency: 150, packetLoss: 0.05, bandwidth: 1000, expectedQuality: .medium),
            NetworkCondition(name: "Poor", latency: 300, packetLoss: 0.1, bandwidth: 500, expectedQuality: .medium),
            NetworkCondition(name: "Very Poor", latency: 600, packetLoss: 0.2, bandwidth: 128, expectedQuality: .low),
            NetworkCondition(name: "Recovery", latency: 30, packetLoss: 0.005, bandwidth: 3000, expectedQuality: .high)
        ]
        
        for (index, scenario) in networkScenarios.enumerated() {
            print("Testing network scenario \(index + 1): \(scenario.name)")
            
            // Apply network conditions
            manager.simulateNetworkConditions(
                latency: TimeInterval(scenario.latency) / 1000.0,
                packetLoss: scenario.packetLoss,
                bandwidth: scenario.bandwidth
            )
            
            // Allow time for adaptation
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Generate activity to trigger adaptation
            for i in 1...20 {
                // Send messages
                let message = RealtimeMessage.text("Adaptation test \(i)", from: "adaptation_user")
                try? await manager.sendMessage(message)
                
                // Volume updates
                let volumeInfos = [
                    UserVolumeInfo(userId: "adaptation_user", volume: Float.random(in: 0.5...1.0), isSpeaking: true),
                    UserVolumeInfo(userId: "other_user", volume: Float.random(in: 0...0.3), isSpeaking: false)
                ]
                manager.processVolumeUpdate(volumeInfos)
                
                // Layout update
                if i % 5 == 0 {
                    let layout = StreamLayout(
                        backgroundColor: "#000000",
                        userRegions: [
                            UserRegion(userId: "adaptation_user", x: 0, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                        ]
                    )
                    try? await manager.updateStreamLayout(layout: layout)
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
            // Check current quality
            let currentQuality = manager.getCurrentStreamQuality()
            print("  Current quality: \(currentQuality)")
            
            // Allow more time for adaptation to settle
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Reset network conditions
        manager.resetNetworkSimulation()
        
        print("Network quality adaptation test completed:")
        print("  Quality adaptations: \(qualityAdaptations.count)")
        
        for (index, adaptation) in qualityAdaptations.enumerated() {
            print("  Adaptation \(index + 1): \(adaptation.fromQuality) → \(adaptation.toQuality) (reason: \(adaptation.reason))")
        }
        
        // Verify adaptations occurred
        #expect(qualityAdaptations.count > 0, "Should have quality adaptations")
        
        // Should have both downward and upward adaptations
        let downwardAdaptations = qualityAdaptations.filter { $0.toQuality.rawValue < $0.fromQuality.rawValue }
        let upwardAdaptations = qualityAdaptations.filter { $0.toQuality.rawValue > $0.fromQuality.rawValue }
        
        #expect(downwardAdaptations.count > 0, "Should have downward quality adaptations")
        #expect(upwardAdaptations.count > 0, "Should have upward quality adaptations")
        
        // Final quality should be high after recovery
        let finalQuality = manager.getCurrentStreamQuality()
        #expect(finalQuality == .high || finalQuality == .medium, "Should recover to good quality")
        
        // Cleanup
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
    
    @Test("Concurrent network stress with multiple features")
    func testConcurrentNetworkStressWithMultipleFeatures() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "concurrent_stress_room",
            userId: "stress_user",
            userName: "Stress User",
            userRole: .broadcaster
        )
        
        // Set up all features
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://concurrent.stress.test.com/live/stress_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        let sourceChannel = try RelayChannelInfo(
            channelName: "concurrent_stress_room",
            userId: "stress_user"
        )
        let destChannels = try (1...2).map { index in
            try RelayChannelInfo(
                channelName: "stress_dest_\(index)",
                userId: "stress_user"
            )
        }
        let relayConfig = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destChannels,
            relayMode: .oneToMany
        )
        try await manager.startMediaRelay(config: relayConfig)
        
        let testDuration: TimeInterval = 15.0 // 15 seconds of concurrent stress
        let startTime = Date()
        
        var featureMetrics: [String: FeatureMetric] = [:]
        let metricsLock = NSLock()
        
        print("Starting concurrent network stress test for \(testDuration) seconds...")
        
        // Apply varying network conditions during the test
        let networkStressTask = Task {
            var stressCount = 0
            while Date().timeIntervalSince(startTime) < testDuration {
                stressCount += 1
                
                let stressTypes = [
                    ("High Latency", 1.0, 0.05, 1000),
                    ("Packet Loss", 0.2, 0.15, 2000),
                    ("Low Bandwidth", 0.3, 0.08, 256),
                    ("Mixed Issues", 0.8, 0.12, 512),
                    ("Recovery", 0.05, 0.01, 3000)
                ]
                
                let (name, latency, packetLoss, bandwidth) = stressTypes[stressCount % stressTypes.count]
                print("Applying network stress: \(name)")
                
                manager.simulateNetworkConditions(
                    latency: latency,
                    packetLoss: packetLoss,
                    bandwidth: bandwidth
                )
                
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds per condition
            }
        }
        
        await withTaskGroup(of: Void.self) { group in
            // Message processing stress
            group.addTask {
                var successCount = 0
                var failCount = 0
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    let message = RealtimeMessage.text("Stress message \(successCount + failCount)", from: "stress_user")
                    do {
                        try await manager.sendMessage(message)
                        successCount += 1
                    } catch {
                        failCount += 1
                    }
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                
                metricsLock.lock()
                featureMetrics["Messages"] = FeatureMetric(
                    successful: successCount,
                    failed: failCount,
                    successRate: Double(successCount) / Double(successCount + failCount)
                )
                metricsLock.unlock()
            }
            
            // Volume processing stress
            group.addTask {
                var processCount = 0
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    let volumeInfos = [
                        UserVolumeInfo(userId: "stress_user", volume: Float.random(in: 0.5...1.0), isSpeaking: true),
                        UserVolumeInfo(userId: "stress_user_1", volume: Float.random(in: 0...0.5), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "stress_user_2", volume: Float.random(in: 0...0.4), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "stress_user_3", volume: Float.random(in: 0...0.3), isSpeaking: Bool.random())
                    ]
                    
                    manager.processVolumeUpdate(volumeInfos)
                    processCount += 1
                    
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                
                metricsLock.lock()
                featureMetrics["Volume"] = FeatureMetric(
                    successful: processCount,
                    failed: 0,
                    successRate: 1.0
                )
                metricsLock.unlock()
            }
            
            // Stream layout stress
            group.addTask {
                var successCount = 0
                var failCount = 0
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    let layout = StreamLayout(
                        backgroundColor: "#000000",
                        userRegions: [
                            UserRegion(userId: "stress_user", x: 0, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                        ]
                    )
                    
                    do {
                        try await manager.updateStreamLayout(layout: layout)
                        successCount += 1
                    } catch {
                        failCount += 1
                    }
                    
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                }
                
                metricsLock.lock()
                featureMetrics["Stream Layout"] = FeatureMetric(
                    successful: successCount,
                    failed: failCount,
                    successRate: Double(successCount) / Double(successCount + failCount)
                )
                metricsLock.unlock()
            }
            
            // Audio settings stress
            group.addTask {
                var successCount = 0
                var failCount = 0
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    do {
                        try await manager.setAudioMixingVolume(Int.random(in: 0...100))
                        try await manager.setPlaybackSignalVolume(Int.random(in: 0...100))
                        successCount += 2
                    } catch {
                        failCount += 2
                    }
                    
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                }
                
                metricsLock.lock()
                featureMetrics["Audio Settings"] = FeatureMetric(
                    successful: successCount,
                    failed: failCount,
                    successRate: Double(successCount) / Double(successCount + failCount)
                )
                metricsLock.unlock()
            }
        }
        
        // Wait for network stress task to complete
        await networkStressTask.value
        
        // Reset network conditions
        manager.resetNetworkSimulation()
        
        let actualDuration = Date().timeIntervalSince(startTime)
        
        print("Concurrent network stress test completed:")
        print("  Duration: \(String(format: "%.2f", actualDuration))s")
        
        for (feature, metric) in featureMetrics {
            print("  \(feature): \(metric.successful) success, \(metric.failed) failed (\(String(format: "%.1f", metric.successRate * 100))%)")
        }
        
        // Performance assertions - features should maintain reasonable success rates under stress
        for (feature, metric) in featureMetrics {
            #expect(metric.successRate > 0.2, "\(feature) should maintain > 20% success rate under network stress")
        }
        
        // System should remain connected or be attempting to reconnect
        #expect(manager.connectionState != .disconnected || manager.connectionState == .reconnecting)
        
        // Core features should still be active
        #expect(manager.volumeIndicatorEnabled == true)
        
        // Cleanup
        try await manager.stopMediaRelay()
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
    
    // MARK: - Helper Structures
    
    struct NetworkRecoveryEvent {
        let eventType: RecoveryEventType
        let timestamp: Date
        let description: String
        
        enum RecoveryEventType {
            case networkFailureDetected
            case recoveryAttempted
            case recoverySucceeded
            case recoveryFailed
        }
    }
    
    struct ConnectionEvent {
        let state: ConnectionState
        let timestamp: Date
    }
    
    struct NetworkCondition {
        let name: String
        let latency: Int        // milliseconds
        let packetLoss: Double  // 0.0 - 1.0
        let bandwidth: Int      // kbps
        let expectedQuality: StreamQuality
    }
    
    struct QualityAdaptation {
        let fromQuality: StreamQuality
        let toQuality: StreamQuality
        let reason: String
        let timestamp: Date
    }
    
    struct FeatureMetric {
        let successful: Int
        let failed: Int
        let successRate: Double
    }
    
    enum StreamQuality: Int, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        
        static func < (lhs: StreamQuality, rhs: StreamQuality) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
}