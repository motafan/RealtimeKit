// AdvancedPerformanceTests.swift
// Advanced performance tests including benchmarks, stress tests, and scalability validation

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Advanced Performance Tests")
@MainActor
struct AdvancedPerformanceTests {
    
    // MARK: - Test Setup
    
    private func createRealtimeManager() -> RealtimeManager {
        let manager = RealtimeManager.shared
        manager.registerMockProvider()
        return manager
    }
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "perf_test_app_id",
            appKey: "perf_test_app_key",
            logLevel: .error // Minimize logging overhead for performance tests
        )
    }
    
    private func measureMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
    
    // MARK: - Scalability Tests
    
    @Test("Large-scale user simulation")
    func testLargeScaleUserSimulation() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "large_scale_room",
            userId: "host_user",
            userName: "Host User",
            userRole: .broadcaster
        )
        
        let userCount = 1000
        let startTime = Date()
        let initialMemory = measureMemoryUsage()
        
        print("Simulating \(userCount) users...")
        
        // Enable volume indicator for large user base
        try await manager.enableVolumeIndicator()
        
        // Simulate large number of users with volume updates
        for batch in 0..<10 {
            let batchStart = Date()
            var volumeInfos: [UserVolumeInfo] = []
            
            // Create batch of 100 users
            for userIndex in 0..<100 {
                let userId = "user_\(batch * 100 + userIndex)"
                let volume = Float.random(in: 0...1)
                let isSpeaking = volume > 0.3
                
                volumeInfos.append(UserVolumeInfo(
                    userId: userId,
                    volume: volume,
                    isSpeaking: isSpeaking
                ))
            }
            
            manager.processVolumeUpdate(volumeInfos)
            
            let batchDuration = Date().timeIntervalSince(batchStart)
            print("Batch \(batch + 1): \(volumeInfos.count) users processed in \(String(format: "%.3f", batchDuration))s")
            
            // Verify performance doesn't degrade significantly
            #expect(batchDuration < 0.5, "Batch processing should complete within 0.5 seconds")
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let finalMemory = measureMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        print("Large scale simulation completed:")
        print("  Total users: \(userCount)")
        print("  Total time: \(String(format: "%.3f", totalDuration))s")
        print("  Users/sec: \(String(format: "%.1f", Double(userCount) / totalDuration))")
        print("  Memory growth: \(memoryGrowth / 1_000_000)MB")
        
        // Performance assertions
        #expect(totalDuration < 10.0, "Should process 1000 users within 10 seconds")
        #expect(memoryGrowth < 100_000_000, "Memory growth should be less than 100MB")
        
        // Verify system remains responsive
        #expect(manager.volumeIndicatorEnabled == true)
        #expect(manager.connectionState == .connected)
        
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
    
    @Test("Concurrent session stress test")
    func testConcurrentSessionStressTest() async throws {
        let sessionCount = 20
        let operationsPerSession = 50
        
        var completedSessions = 0
        var totalOperations = 0
        let lock = NSLock()
        
        let startTime = Date()
        let initialMemory = measureMemoryUsage()
        
        print("Starting \(sessionCount) concurrent sessions with \(operationsPerSession) operations each...")
        
        await withTaskGroup(of: Void.self) { group in
            for sessionId in 1...sessionCount {
                group.addTask {
                    let manager = self.createRealtimeManager()
                    let config = self.createTestConfig()
                    
                    do {
                        try await manager.configure(provider: .mock, config: config)
                        try await manager.joinRoom(
                            roomId: "concurrent_room_\(sessionId)",
                            userId: "concurrent_user_\(sessionId)",
                            userName: "Concurrent User \(sessionId)",
                            userRole: .broadcaster
                        )
                        
                        // Perform operations
                        for opIndex in 1...operationsPerSession {
                            // Mix of different operations
                            switch opIndex % 5 {
                            case 0:
                                // Message sending
                                let message = RealtimeMessage.text("Concurrent message \(opIndex)", from: "concurrent_user_\(sessionId)")
                                try await manager.sendMessage(message)
                                
                            case 1:
                                // Audio settings
                                try await manager.setAudioMixingVolume(opIndex % 101)
                                
                            case 2:
                                // Volume updates
                                let volumeInfos = [
                                    UserVolumeInfo(userId: "concurrent_user_\(sessionId)", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                                ]
                                manager.processVolumeUpdate(volumeInfos)
                                
                            case 3:
                                // Microphone toggle
                                try await manager.muteMicrophone(opIndex % 2 == 0)
                                
                            case 4:
                                // Stream operations (if supported)
                                if opIndex % 10 == 0 {
                                    let streamConfig = try? StreamPushConfig.standard720p(
                                        pushUrl: "rtmp://concurrent.test.com/live/session_\(sessionId)"
                                    )
                                    if let config = streamConfig {
                                        try? await manager.startStreamPush(config: config)
                                        try? await manager.stopStreamPush()
                                    }
                                }
                                
                            default:
                                break
                            }
                            
                            lock.lock()
                            totalOperations += 1
                            lock.unlock()
                        }
                        
                        try await manager.leaveRoom()
                        
                        lock.lock()
                        completedSessions += 1
                        lock.unlock()
                        
                    } catch {
                        print("Session \(sessionId) failed: \(error)")
                    }
                }
            }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let finalMemory = measureMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        print("Concurrent session stress test completed:")
        print("  Completed sessions: \(completedSessions)/\(sessionCount)")
        print("  Total operations: \(totalOperations)")
        print("  Total time: \(String(format: "%.3f", totalDuration))s")
        print("  Operations/sec: \(String(format: "%.1f", Double(totalOperations) / totalDuration))")
        print("  Memory growth: \(memoryGrowth / 1_000_000)MB")
        
        // Performance assertions
        #expect(completedSessions >= sessionCount * 8 / 10, "At least 80% of sessions should complete successfully")
        #expect(totalOperations >= sessionCount * operationsPerSession * 8 / 10, "At least 80% of operations should complete")
        #expect(totalDuration < 30.0, "Should complete within 30 seconds")
        #expect(memoryGrowth < 200_000_000, "Memory growth should be less than 200MB")
    }
    
    @Test("High-frequency operation stress test")
    func testHighFrequencyOperationStressTest() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "high_freq_room",
            userId: "high_freq_user",
            userName: "High Frequency User",
            userRole: .broadcaster
        )
        
        let testDuration: TimeInterval = 10.0 // 10 seconds of high-frequency operations
        let startTime = Date()
        let initialMemory = measureMemoryUsage()
        
        var operationCounts: [String: Int] = [:]
        let countLock = NSLock()
        
        print("Starting high-frequency operations for \(testDuration) seconds...")
        
        try await manager.enableVolumeIndicator()
        
        await withTaskGroup(of: Void.self) { group in
            // High-frequency volume updates (100 Hz)
            group.addTask {
                var count = 0
                while Date().timeIntervalSince(startTime) < testDuration {
                    let volumeInfos = [
                        UserVolumeInfo(userId: "high_freq_user", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "user_1", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                        UserVolumeInfo(userId: "user_2", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                    ]
                    manager.processVolumeUpdate(volumeInfos)
                    count += 1
                    
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms = 100 Hz
                }
                
                countLock.lock()
                operationCounts["Volume Updates"] = count
                countLock.unlock()
            }
            
            // High-frequency message sending (50 Hz)
            group.addTask {
                var count = 0
                while Date().timeIntervalSince(startTime) < testDuration {
                    let message = RealtimeMessage.text("High freq message \(count)", from: "high_freq_user")
                    try? await manager.sendMessage(message)
                    count += 1
                    
                    try? await Task.sleep(nanoseconds: 20_000_000) // 20ms = 50 Hz
                }
                
                countLock.lock()
                operationCounts["Messages"] = count
                countLock.unlock()
            }
            
            // Medium-frequency audio adjustments (10 Hz)
            group.addTask {
                var count = 0
                while Date().timeIntervalSince(startTime) < testDuration {
                    try? await manager.setAudioMixingVolume(count % 101)
                    count += 1
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms = 10 Hz
                }
                
                countLock.lock()
                operationCounts["Audio Adjustments"] = count
                countLock.unlock()
            }
            
            // Low-frequency stream layout updates (2 Hz)
            group.addTask {
                let streamConfig = try? StreamPushConfig.standard720p(
                    pushUrl: "rtmp://highfreq.test.com/live/high_freq_stream"
                )
                
                if let config = streamConfig {
                    try? await manager.startStreamPush(config: config)
                    
                    var count = 0
                    while Date().timeIntervalSince(startTime) < testDuration {
                        let layout = StreamLayout(
                            backgroundColor: "#000000",
                            userRegions: [
                                UserRegion(userId: "high_freq_user", x: count % 100, y: 0, width: 1280, height: 720, zOrder: 1, alpha: 1.0)
                            ]
                        )
                        try? await manager.updateStreamLayout(layout: layout)
                        count += 1
                        
                        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms = 2 Hz
                    }
                    
                    try? await manager.stopStreamPush()
                    
                    countLock.lock()
                    operationCounts["Layout Updates"] = count
                    countLock.unlock()
                }
            }
        }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        let finalMemory = measureMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        print("High-frequency operation test completed:")
        print("  Actual duration: \(String(format: "%.3f", actualDuration))s")
        
        var totalOperations = 0
        for (operation, count) in operationCounts {
            let frequency = Double(count) / actualDuration
            print("  \(operation): \(count) operations (\(String(format: "%.1f", frequency)) Hz)")
            totalOperations += count
        }
        
        print("  Total operations: \(totalOperations)")
        print("  Overall rate: \(String(format: "%.1f", Double(totalOperations) / actualDuration)) ops/sec")
        print("  Memory growth: \(memoryGrowth / 1_000_000)MB")
        
        // Performance assertions
        #expect(operationCounts["Volume Updates"] ?? 0 >= 800, "Should achieve ~100 Hz volume updates")
        #expect(operationCounts["Messages"] ?? 0 >= 400, "Should achieve ~50 Hz message sending")
        #expect(operationCounts["Audio Adjustments"] ?? 0 >= 80, "Should achieve ~10 Hz audio adjustments")
        #expect(operationCounts["Layout Updates"] ?? 0 >= 15, "Should achieve ~2 Hz layout updates")
        #expect(memoryGrowth < 150_000_000, "Memory growth should be less than 150MB")
        
        // System should remain responsive
        #expect(manager.connectionState == .connected)
        #expect(manager.volumeIndicatorEnabled == true)
        
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
    
    // MARK: - Memory Pressure Tests
    
    @Test("Memory pressure resilience test")
    func testMemoryPressureResilienceTest() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "memory_pressure_room",
            userId: "memory_user",
            userName: "Memory User",
            userRole: .broadcaster
        )
        
        let initialMemory = measureMemoryUsage()
        var memoryReadings: [(time: TimeInterval, memory: Int)] = []
        
        print("Starting memory pressure test...")
        
        // Create memory pressure by generating large amounts of data
        let startTime = Date()
        
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://memory.pressure.test.com/live/pressure_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Generate sustained memory pressure
        for cycle in 1...100 {
            let cycleStart = Date()
            
            // Generate large volume updates
            var volumeInfos: [UserVolumeInfo] = []
            for userId in 1...200 {
                volumeInfos.append(UserVolumeInfo(
                    userId: "pressure_user_\(userId)",
                    volume: Float.random(in: 0...1),
                    isSpeaking: Bool.random()
                ))
            }
            manager.processVolumeUpdate(volumeInfos)
            
            // Send batch of messages
            for messageIndex in 1...50 {
                let message = RealtimeMessage.text(
                    "Memory pressure message \(cycle)_\(messageIndex) with extra data: " + String(repeating: "x", count: 100),
                    from: "memory_user"
                )
                try await manager.sendMessage(message)
            }
            
            // Complex layout updates
            let layout = StreamLayout(
                backgroundColor: "#000000",
                userRegions: (1...20).map { index in
                    UserRegion(
                        userId: "pressure_user_\(index)",
                        x: (index % 4) * 480,
                        y: (index / 4) * 270,
                        width: 480,
                        height: 270,
                        zOrder: index,
                        alpha: 1.0
                    )
                }
            )
            try await manager.updateStreamLayout(layout: layout)
            
            // Monitor memory usage
            let currentMemory = measureMemoryUsage()
            let elapsedTime = Date().timeIntervalSince(startTime)
            memoryReadings.append((time: elapsedTime, memory: currentMemory))
            
            let memoryGrowth = currentMemory - initialMemory
            
            if cycle % 10 == 0 {
                print("Cycle \(cycle): Memory = \(currentMemory / 1_000_000)MB, Growth = \(memoryGrowth / 1_000_000)MB")
                
                // Verify memory doesn't grow unbounded
                #expect(memoryGrowth < 500_000_000, "Memory growth should not exceed 500MB")
                
                // Perform cleanup to test memory management
                manager.performMemoryCleanup()
            }
            
            let cycleDuration = Date().timeIntervalSince(cycleStart)
            
            // Verify performance doesn't degrade significantly under memory pressure
            #expect(cycleDuration < 1.0, "Cycle should complete within 1 second even under memory pressure")
        }
        
        // Final cleanup and verification
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        
        // Force garbage collection
        manager.performMemoryCleanup()
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Memory pressure test completed:")
        print("  Initial memory: \(initialMemory / 1_000_000)MB")
        print("  Final memory: \(finalMemory / 1_000_000)MB")
        print("  Total growth: \(totalGrowth / 1_000_000)MB")
        print("  Memory readings: \(memoryReadings.count)")
        
        // Analyze memory growth pattern
        if memoryReadings.count >= 3 {
            let firstReading = memoryReadings[0].memory
            let midReading = memoryReadings[memoryReadings.count / 2].memory
            let lastReading = memoryReadings.last!.memory
            
            let firstHalfGrowth = midReading - firstReading
            let secondHalfGrowth = lastReading - midReading
            
            print("  First half growth: \(firstHalfGrowth / 1_000_000)MB")
            print("  Second half growth: \(secondHalfGrowth / 1_000_000)MB")
            
            // Memory growth should stabilize (second half growth should be less than first half)
            #expect(secondHalfGrowth <= firstHalfGrowth * 2, "Memory growth should stabilize over time")
        }
        
        // Final assertions
        #expect(totalGrowth < 300_000_000, "Total memory growth should be less than 300MB after cleanup")
        #expect(manager.connectionState == .connected, "Connection should remain stable under memory pressure")
        
        try await manager.leaveRoom()
    }
    
    // MARK: - CPU Performance Tests
    
    @Test("CPU intensive operations performance")
    func testCPUIntensiveOperationsPerformance() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "cpu_intensive_room",
            userId: "cpu_user",
            userName: "CPU User",
            userRole: .broadcaster
        )
        
        let testDuration: TimeInterval = 15.0 // 15 seconds of CPU intensive operations
        let startTime = Date()
        
        var performanceMetrics: [String: PerformanceMetric] = [:]
        let metricsLock = NSLock()
        
        print("Starting CPU intensive operations for \(testDuration) seconds...")
        
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://cpu.intensive.test.com/live/cpu_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Set up media relay for additional CPU load
        let sourceChannel = try RelayChannelInfo(
            channelName: "cpu_intensive_room",
            userId: "cpu_user"
        )
        let destChannels = try (1...3).map { index in
            try RelayChannelInfo(
                channelName: "cpu_dest_\(index)",
                userId: "cpu_user"
            )
        }
        let relayConfig = try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destChannels,
            relayMode: .oneToMany
        )
        try await manager.startMediaRelay(config: relayConfig)
        
        await withTaskGroup(of: Void.self) { group in
            // Complex volume processing
            group.addTask {
                var operationCount = 0
                let taskStart = Date()
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    // Generate complex volume data with many users
                    var volumeInfos: [UserVolumeInfo] = []
                    for userId in 1...100 {
                        volumeInfos.append(UserVolumeInfo(
                            userId: "cpu_user_\(userId)",
                            volume: Float.random(in: 0...1),
                            isSpeaking: Bool.random()
                        ))
                    }
                    
                    manager.processVolumeUpdate(volumeInfos)
                    operationCount += 1
                    
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                
                let taskDuration = Date().timeIntervalSince(taskStart)
                metricsLock.lock()
                performanceMetrics["Volume Processing"] = PerformanceMetric(
                    operations: operationCount,
                    duration: taskDuration,
                    operationsPerSecond: Double(operationCount) / taskDuration
                )
                metricsLock.unlock()
            }
            
            // Intensive message processing
            group.addTask {
                var operationCount = 0
                let taskStart = Date()
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    // Send complex messages
                    let messageTypes: [RealtimeMessage] = [
                        .text("CPU intensive text message with lots of data: " + String(repeating: "data", count: 50), from: "cpu_user"),
                        .system("CPU intensive system message", metadata: [
                            "timestamp": Date().timeIntervalSince1970,
                            "data": Array(1...100).map { "item_\($0)" },
                            "complex_object": ["nested": ["deep": ["value": "cpu_test"]]]
                        ]),
                        .custom("cpu_intensive", data: [
                            "large_array": Array(1...1000),
                            "computation_result": Array(1...100).reduce(0, +)
                        ], from: "cpu_user")
                    ]
                    
                    for message in messageTypes {
                        try? await manager.sendMessage(message)
                        operationCount += 1
                    }
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                
                let taskDuration = Date().timeIntervalSince(taskStart)
                metricsLock.lock()
                performanceMetrics["Message Processing"] = PerformanceMetric(
                    operations: operationCount,
                    duration: taskDuration,
                    operationsPerSecond: Double(operationCount) / taskDuration
                )
                metricsLock.unlock()
            }
            
            // Complex layout computations
            group.addTask {
                var operationCount = 0
                let taskStart = Date()
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    // Generate complex layouts with many regions
                    let userCount = 25 // 5x5 grid
                    let regionWidth = 1920 / 5
                    let regionHeight = 1080 / 5
                    
                    let userRegions = (0..<userCount).map { index in
                        let row = index / 5
                        let col = index % 5
                        
                        return UserRegion(
                            userId: "cpu_layout_user_\(index)",
                            x: col * regionWidth,
                            y: row * regionHeight,
                            width: regionWidth,
                            height: regionHeight,
                            zOrder: index + 1,
                            alpha: Float.random(in: 0.5...1.0)
                        )
                    }
                    
                    let layout = StreamLayout(
                        backgroundColor: String(format: "#%06x", Int.random(in: 0...0xFFFFFF)),
                        userRegions: userRegions
                    )
                    
                    try? await manager.updateStreamLayout(layout: layout)
                    operationCount += 1
                    
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                }
                
                let taskDuration = Date().timeIntervalSince(taskStart)
                metricsLock.lock()
                performanceMetrics["Layout Updates"] = PerformanceMetric(
                    operations: operationCount,
                    duration: taskDuration,
                    operationsPerSecond: Double(operationCount) / taskDuration
                )
                metricsLock.unlock()
            }
            
            // Rapid audio adjustments
            group.addTask {
                var operationCount = 0
                let taskStart = Date()
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    // Perform multiple audio adjustments
                    try? await manager.setAudioMixingVolume(Int.random(in: 0...100))
                    try? await manager.setPlaybackSignalVolume(Int.random(in: 0...100))
                    try? await manager.setRecordingSignalVolume(Int.random(in: 0...100))
                    try? await manager.muteMicrophone(Bool.random())
                    
                    operationCount += 4 // 4 operations per cycle
                    
                    try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                }
                
                let taskDuration = Date().timeIntervalSince(taskStart)
                metricsLock.lock()
                performanceMetrics["Audio Adjustments"] = PerformanceMetric(
                    operations: operationCount,
                    duration: taskDuration,
                    operationsPerSecond: Double(operationCount) / taskDuration
                )
                metricsLock.unlock()
            }
        }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        
        print("CPU intensive operations completed:")
        print("  Actual duration: \(String(format: "%.3f", actualDuration))s")
        
        var totalOperations = 0
        for (operation, metric) in performanceMetrics {
            print("  \(operation): \(metric.operations) ops (\(String(format: "%.1f", metric.operationsPerSecond)) ops/sec)")
            totalOperations += metric.operations
        }
        
        print("  Total operations: \(totalOperations)")
        print("  Overall rate: \(String(format: "%.1f", Double(totalOperations) / actualDuration)) ops/sec")
        
        // Performance assertions - should maintain reasonable performance under CPU load
        #expect(performanceMetrics["Volume Processing"]?.operationsPerSecond ?? 0 > 10, "Volume processing should maintain > 10 ops/sec")
        #expect(performanceMetrics["Message Processing"]?.operationsPerSecond ?? 0 > 5, "Message processing should maintain > 5 ops/sec")
        #expect(performanceMetrics["Layout Updates"]?.operationsPerSecond ?? 0 > 2, "Layout updates should maintain > 2 ops/sec")
        #expect(performanceMetrics["Audio Adjustments"]?.operationsPerSecond ?? 0 > 15, "Audio adjustments should maintain > 15 ops/sec")
        
        // System should remain stable under CPU load
        #expect(manager.connectionState == .connected)
        #expect(manager.streamPushState == .running)
        #expect(manager.isMediaRelayActive == true)
        
        // Cleanup
        try await manager.stopMediaRelay()
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
    }
    
    // MARK: - Helper Structures
    
    struct PerformanceMetric {
        let operations: Int
        let duration: TimeInterval
        let operationsPerSecond: Double
    }
}