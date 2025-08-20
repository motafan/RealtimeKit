// PerformanceStressTests.swift
// Comprehensive performance and stress tests for RealtimeKit

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Performance and Stress Tests")
@MainActor
struct PerformanceStressTests {
    
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
            logLevel: .error // Reduce logging for performance tests
        )
    }
    
    // MARK: - Message Processing Performance Tests
    
    @Test("High volume message processing performance")
    func testHighVolumeMessageProcessingPerformance() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let messageCount = 10000
        let startTime = Date()
        
        // Process many messages rapidly
        for i in 1...messageCount {
            let message = RealtimeMessage.text("Message \(i)", from: "user_\(i % 100)")
            try await manager.sendMessage(message)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let messagesPerSecond = Double(messageCount) / duration
        
        #expect(duration < 10.0) // Should complete within 10 seconds
        #expect(messagesPerSecond > 500) // Should process at least 500 messages/second
        
        print("Processed \(messageCount) messages in \(duration) seconds (\(messagesPerSecond) msg/sec)")
    }
    
    @Test("Concurrent message processing stress test")
    func testConcurrentMessageProcessingStressTest() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let concurrentTasks = 50
        let messagesPerTask = 100
        var completedTasks = 0
        let lock = NSLock()
        
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for taskId in 1...concurrentTasks {
                group.addTask {
                    for messageId in 1...messagesPerTask {
                        let message = RealtimeMessage.text(
                            "Task \(taskId) Message \(messageId)",
                            from: "user_\(taskId)"
                        )
                        
                        do {
                            try await manager.sendMessage(message)
                        } catch {
                            // Handle errors gracefully in stress test
                        }
                    }
                    
                    lock.lock()
                    completedTasks += 1
                    lock.unlock()
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let totalMessages = concurrentTasks * messagesPerTask
        
        #expect(completedTasks == concurrentTasks)
        #expect(duration < 15.0) // Should complete within 15 seconds
        
        print("Processed \(totalMessages) messages concurrently in \(duration) seconds")
    }
    
    // MARK: - Volume Indicator Performance Tests
    
    @Test("Volume indicator high frequency updates")
    func testVolumeIndicatorHighFrequencyUpdates() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        try await manager.enableVolumeIndicator()
        
        let updateCount = 5000
        let userCount = 50
        let startTime = Date()
        
        // Generate high frequency volume updates
        for i in 1...updateCount {
            var volumeInfos: [UserVolumeInfo] = []
            
            for userId in 1...userCount {
                let volume = Float.random(in: 0...1)
                let isSpeaking = volume > 0.3
                
                volumeInfos.append(UserVolumeInfo(
                    userId: "user_\(userId)",
                    volume: volume,
                    isSpeaking: isSpeaking
                ))
            }
            
            manager.processVolumeUpdate(volumeInfos)
            
            // Small delay to simulate realistic update frequency
            if i % 100 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let updatesPerSecond = Double(updateCount) / duration
        
        #expect(duration < 5.0) // Should complete within 5 seconds
        #expect(updatesPerSecond > 500) // Should handle at least 500 updates/second
        
        print("Processed \(updateCount) volume updates in \(duration) seconds (\(updatesPerSecond) updates/sec)")
        
        try await manager.disableVolumeIndicator()
    }
    
    @Test("Volume indicator memory usage under load")
    func testVolumeIndicatorMemoryUsageUnderLoad() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        try await manager.enableVolumeIndicator()
        
        let initialMemory = manager.getCurrentMemoryUsage()
        
        // Generate continuous volume updates for extended period
        for cycle in 1...100 {
            for update in 1...100 {
                var volumeInfos: [UserVolumeInfo] = []
                
                for userId in 1...100 {
                    volumeInfos.append(UserVolumeInfo(
                        userId: "user_\(userId)",
                        volume: Float.random(in: 0...1),
                        isSpeaking: Bool.random()
                    ))
                }
                
                manager.processVolumeUpdate(volumeInfos)
            }
            
            // Check memory usage periodically
            if cycle % 20 == 0 {
                let currentMemory = manager.getCurrentMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                // Memory growth should be bounded
                #expect(memoryGrowth < 50_000_000) // Less than 50MB growth
            }
        }
        
        try await manager.disableVolumeIndicator()
    }
    
    // MARK: - Stream Push Performance Tests
    
    @Test("Stream push rapid start/stop cycles")
    func testStreamPushRapidStartStopCycles() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        let streamConfig = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://test.example.com/live/stream"
        )
        
        let cycleCount = 50
        let startTime = Date()
        
        for i in 1...cycleCount {
            try await manager.startStreamPush(config: streamConfig)
            
            // Brief streaming period
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            try await manager.stopStreamPush()
            
            if i % 10 == 0 {
                print("Completed \(i) stream cycles")
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let cyclesPerSecond = Double(cycleCount) / duration
        
        #expect(duration < 30.0) // Should complete within 30 seconds
        #expect(cyclesPerSecond > 1.0) // Should handle at least 1 cycle/second
        
        print("Completed \(cycleCount) stream cycles in \(duration) seconds (\(cyclesPerSecond) cycles/sec)")
    }
    
    @Test("Stream layout update performance")
    func testStreamLayoutUpdatePerformance() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://test.example.com/live/hd_stream"
        )
        
        try await manager.startStreamPush(config: streamConfig)
        
        let updateCount = 1000
        let startTime = Date()
        
        // Rapid layout updates
        for i in 1...updateCount {
            let userCount = (i % 10) + 1 // 1-10 users
            var userRegions: [UserRegion] = []
            
            for userId in 1...userCount {
                let x = (userId - 1) * (1920 / userCount)
                let width = 1920 / userCount
                
                userRegions.append(UserRegion(
                    userId: "user_\(userId)",
                    x: x, y: 0,
                    width: width, height: 1080,
                    zOrder: userId,
                    alpha: 1.0
                ))
            }
            
            let layout = StreamLayout(
                backgroundColor: "#000000",
                userRegions: userRegions
            )
            
            try await manager.updateStreamLayout(layout: layout)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let updatesPerSecond = Double(updateCount) / duration
        
        #expect(duration < 10.0) // Should complete within 10 seconds
        #expect(updatesPerSecond > 50) // Should handle at least 50 updates/second
        
        print("Completed \(updateCount) layout updates in \(duration) seconds (\(updatesPerSecond) updates/sec)")
        
        try await manager.stopStreamPush()
    }
    
    // MARK: - Media Relay Performance Tests
    
    @Test("Media relay channel management performance")
    func testMediaRelayChannelManagementPerformance() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let sourceChannel = RelayChannelInfo(
            channelName: "source_channel",
            token: "source_token",
            userId: "source_user"
        )
        
        let initialTarget = RelayChannelInfo(
            channelName: "initial_target",
            token: "initial_token",
            userId: "initial_user"
        )
        
        let relayConfig = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [initialTarget]
        )
        
        try await manager.startMediaRelay(config: relayConfig)
        
        let operationCount = 500
        let startTime = Date()
        
        // Rapid channel add/remove operations
        for i in 1...operationCount {
            let channel = RelayChannelInfo(
                channelName: "temp_channel_\(i)",
                token: "temp_token_\(i)",
                userId: "temp_user_\(i)"
            )
            
            try await manager.addMediaRelayChannel(channel)
            try await manager.removeMediaRelayChannel("temp_channel_\(i)")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let operationsPerSecond = Double(operationCount * 2) / duration // Add + Remove
        
        #expect(duration < 15.0) // Should complete within 15 seconds
        #expect(operationsPerSecond > 50) // Should handle at least 50 operations/second
        
        print("Completed \(operationCount * 2) channel operations in \(duration) seconds (\(operationsPerSecond) ops/sec)")
        
        try await manager.stopMediaRelay()
    }
    
    // MARK: - Storage Performance Tests
    
    @Test("Storage high volume operations")
    func testStorageHighVolumeOperations() async throws {
        let storage = AudioSettingsStorage()
        
        let operationCount = 10000
        let startTime = Date()
        
        // Rapid save/load operations
        for i in 1...operationCount {
            let settings = AudioSettings(
                microphoneMuted: i % 2 == 0,
                audioMixingVolume: i % 101,
                playbackSignalVolume: (i * 2) % 101,
                recordingSignalVolume: (i * 3) % 101,
                localAudioStreamActive: i % 3 == 0
            )
            
            try storage.saveAudioSettings(settings)
            let _ = storage.loadAudioSettings()
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let operationsPerSecond = Double(operationCount * 2) / duration // Save + Load
        
        #expect(duration < 5.0) // Should complete within 5 seconds
        #expect(operationsPerSecond > 1000) // Should handle at least 1000 operations/second
        
        print("Completed \(operationCount * 2) storage operations in \(duration) seconds (\(operationsPerSecond) ops/sec)")
    }
    
    @Test("Storage concurrent access stress test")
    func testStorageConcurrentAccessStressTest() async throws {
        let storage = AudioSettingsStorage()
        
        let concurrentTasks = 20
        let operationsPerTask = 100
        var completedOperations = 0
        let lock = NSLock()
        
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for taskId in 1...concurrentTasks {
                group.addTask {
                    for opId in 1...operationsPerTask {
                        let settings = AudioSettings(
                            audioMixingVolume: (taskId * 10 + opId) % 101
                        )
                        
                        do {
                            try storage.saveAudioSettings(settings)
                            let _ = storage.loadAudioSettings()
                            
                            lock.lock()
                            completedOperations += 2
                            lock.unlock()
                        } catch {
                            // Handle concurrent access errors gracefully
                        }
                    }
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(completedOperations > 0)
        #expect(duration < 10.0) // Should complete within 10 seconds
        
        print("Completed \(completedOperations) concurrent storage operations in \(duration) seconds")
    }
    
    // MARK: - Memory Stress Tests
    
    @Test("Memory usage under sustained load")
    func testMemoryUsageUnderSustainedLoad() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let initialMemory = manager.getCurrentMemoryUsage()
        var peakMemory = initialMemory
        
        // Sustained load simulation
        for cycle in 1...50 {
            // Join and leave rooms rapidly
            for roomId in 1...20 {
                try await manager.joinRoom(
                    roomId: "room_\(roomId)",
                    userId: "user_\(roomId)",
                    userName: "User \(roomId)",
                    userRole: .broadcaster
                )
                
                // Generate some activity
                for _ in 1...10 {
                    let message = RealtimeMessage.text("Message", from: "user_\(roomId)")
                    try await manager.sendMessage(message)
                }
                
                try await manager.leaveRoom()
            }
            
            // Check memory usage
            let currentMemory = manager.getCurrentMemoryUsage()
            peakMemory = max(peakMemory, currentMemory)
            
            // Force garbage collection periodically
            if cycle % 10 == 0 {
                manager.performMemoryCleanup()
                
                let cleanedMemory = manager.getCurrentMemoryUsage()
                let memoryGrowth = cleanedMemory - initialMemory
                
                // Memory growth should be reasonable
                #expect(memoryGrowth < 100_000_000) // Less than 100MB growth
                
                print("Cycle \(cycle): Memory usage \(cleanedMemory / 1_000_000)MB (growth: \(memoryGrowth / 1_000_000)MB)")
            }
        }
        
        let finalMemory = manager.getCurrentMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        #expect(totalGrowth < 200_000_000) // Less than 200MB total growth
        
        print("Memory test completed. Initial: \(initialMemory / 1_000_000)MB, Peak: \(peakMemory / 1_000_000)MB, Final: \(finalMemory / 1_000_000)MB")
    }
    
    @Test("Memory leak detection under error conditions")
    func testMemoryLeakDetectionUnderErrorConditions() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let initialMemory = manager.getCurrentMemoryUsage()
        
        // Create many objects and simulate errors
        for i in 1...100 {
            try await manager.joinRoom(
                roomId: "room_\(i)",
                userId: "user_\(i)",
                userName: "User \(i)",
                userRole: .broadcaster
            )
            
            // Start various operations
            try await manager.enableVolumeIndicator()
            
            let streamConfig = try StreamPushConfig.standard720p(
                pushUrl: "rtmp://test.example.com/live/stream_\(i)"
            )
            try await manager.startStreamPush(config: streamConfig)
            
            // Simulate errors
            let error = RealtimeError.networkError("Simulated error \(i)")
            manager.handleNetworkError(error)
            
            // Cleanup
            try await manager.stopStreamPush()
            try await manager.disableVolumeIndicator()
            try await manager.leaveRoom()
        }
        
        // Force cleanup
        manager.performMemoryCleanup()
        
        let finalMemory = manager.getCurrentMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        // Memory should not leak significantly
        #expect(memoryGrowth < 50_000_000) // Less than 50MB growth after cleanup
        
        print("Memory leak test: Initial \(initialMemory / 1_000_000)MB, Final \(finalMemory / 1_000_000)MB, Growth \(memoryGrowth / 1_000_000)MB")
    }
    
    // MARK: - CPU Performance Tests
    
    @Test("CPU usage under high load")
    func testCPUUsageUnderHighLoad() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "test_room",
            userId: "test_user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        let startTime = Date()
        let testDuration: TimeInterval = 5.0 // 5 seconds of high load
        
        // Start multiple intensive operations
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://test.example.com/live/hd_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Generate high CPU load
        await withTaskGroup(of: Void.self) { group in
            // Volume updates
            group.addTask {
                while Date().timeIntervalSince(startTime) < testDuration {
                    var volumeInfos: [UserVolumeInfo] = []
                    for userId in 1...100 {
                        volumeInfos.append(UserVolumeInfo(
                            userId: "user_\(userId)",
                            volume: Float.random(in: 0...1),
                            isSpeaking: Bool.random()
                        ))
                    }
                    manager.processVolumeUpdate(volumeInfos)
                    
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
            
            // Message processing
            group.addTask {
                var messageCount = 0
                while Date().timeIntervalSince(startTime) < testDuration {
                    let message = RealtimeMessage.text("Message \(messageCount)", from: "user_\(messageCount % 100)")
                    try? await manager.sendMessage(message)
                    messageCount += 1
                    
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
            }
            
            // Layout updates
            group.addTask {
                var layoutCount = 0
                while Date().timeIntervalSince(startTime) < testDuration {
                    let layout = StreamLayout(
                        backgroundColor: "#000000",
                        userRegions: [
                            UserRegion(
                                userId: "user_\(layoutCount % 10)",
                                x: layoutCount % 1920,
                                y: 0,
                                width: 200,
                                height: 200,
                                zOrder: 1,
                                alpha: 1.0
                            )
                        ]
                    )
                    
                    try? await manager.updateStreamLayout(layout: layout)
                    layoutCount += 1
                    
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
            }
        }
        
        let endTime = Date()
        let actualDuration = endTime.timeIntervalSince(startTime)
        
        #expect(actualDuration <= testDuration + 1.0) // Should complete within reasonable time
        
        // System should remain responsive
        #expect(manager.connectionState == .connected)
        #expect(manager.streamPushState == .running)
        
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        
        print("High load test completed in \(actualDuration) seconds")
    }
    
    // MARK: - Network Simulation Tests
    
    @Test("Performance under simulated network conditions")
    func testPerformanceUnderSimulatedNetworkConditions() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        // Simulate various network conditions
        let networkConditions: [(latency: TimeInterval, packetLoss: Double, bandwidth: Int)] = [
            (0.05, 0.01, 1000),   // Good connection
            (0.1, 0.05, 500),     // Moderate connection
            (0.3, 0.1, 100),      // Poor connection
            (0.5, 0.2, 50)        // Very poor connection
        ]
        
        for (index, condition) in networkConditions.enumerated() {
            print("Testing network condition \(index + 1): latency=\(condition.latency)s, loss=\(condition.packetLoss), bandwidth=\(condition.bandwidth)kbps")
            
            // Apply network simulation
            manager.simulateNetworkConditions(
                latency: condition.latency,
                packetLoss: condition.packetLoss,
                bandwidth: condition.bandwidth
            )
            
            try await manager.joinRoom(
                roomId: "test_room_\(index)",
                userId: "test_user",
                userName: "Test User",
                userRole: .broadcaster
            )
            
            let startTime = Date()
            let messageCount = 100
            
            // Send messages under network conditions
            for i in 1...messageCount {
                let message = RealtimeMessage.text("Message \(i)", from: "test_user")
                try await manager.sendMessage(message)
            }
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let messagesPerSecond = Double(messageCount) / duration
            
            print("  Processed \(messageCount) messages in \(duration)s (\(messagesPerSecond) msg/sec)")
            
            // Performance should degrade gracefully
            if condition.bandwidth >= 500 {
                #expect(messagesPerSecond > 50) // Good conditions
            } else if condition.bandwidth >= 100 {
                #expect(messagesPerSecond > 20) // Moderate conditions
            } else {
                #expect(messagesPerSecond > 5)  // Poor conditions
            }
            
            try await manager.leaveRoom()
        }
        
        // Reset network conditions
        manager.resetNetworkSimulation()
    }
}