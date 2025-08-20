// MemoryLeakDetectionTests.swift
// Comprehensive memory leak detection and performance monitoring tests

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Memory Leak Detection Tests")
@MainActor
struct MemoryLeakDetectionTests {
    
    // MARK: - Test Setup
    
    private func createRealtimeManager() -> RealtimeManager {
        let manager = RealtimeManager.shared
        manager.registerMockProvider()
        return manager
    }
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "memory_test_app_id",
            appKey: "memory_test_app_key",
            logLevel: .error // Minimize logging overhead
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
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    // MARK: - Basic Memory Leak Tests
    
    @Test("Manager lifecycle memory leak detection")
    func testManagerLifecycleMemoryLeakDetection() async throws {
        let initialMemory = measureMemoryUsage()
        
        // Create and destroy managers multiple times
        for iteration in 1...50 {
            let manager = createRealtimeManager()
            let config = createTestConfig()
            
            try await manager.configure(provider: .mock, config: config)
            try await manager.loginUser(
                userId: "memory_user_\(iteration)",
                userName: "Memory User \(iteration)",
                userRole: .broadcaster
            )
            
            try await manager.joinRoom(
                roomId: "memory_room_\(iteration)",
                userId: "memory_user_\(iteration)",
                userName: "Memory User \(iteration)",
                userRole: .broadcaster
            )
            
            // Perform some operations
            try await manager.setAudioMixingVolume(75)
            try await manager.enableVolumeIndicator()
            
            let message = RealtimeMessage.text("Memory test \(iteration)", from: "memory_user_\(iteration)")
            try await manager.sendMessage(message)
            
            // Clean up
            try await manager.disableVolumeIndicator()
            try await manager.leaveRoom()
            try await manager.logoutUser()
            
            // Force cleanup
            manager.performMemoryCleanup()
            
            // Check memory growth periodically
            if iteration % 10 == 0 {
                let currentMemory = measureMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                print("Iteration \(iteration): Memory growth = \(memoryGrowth / 1_000_000) MB")
                
                // Memory growth should be bounded
                #expect(memoryGrowth < 50_000_000) // Less than 50MB growth
            }
        }
        
        // Final memory check
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Total memory growth after 50 iterations: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 100_000_000) // Less than 100MB total growth
    }
    
    @Test("Volume indicator memory leak detection")
    func testVolumeIndicatorMemoryLeakDetection() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "volume_memory_room",
            userId: "volume_user",
            userName: "Volume User",
            userRole: .broadcaster
        )
        
        let initialMemory = measureMemoryUsage()
        
        // Repeatedly enable/disable volume indicator
        for cycle in 1...100 {
            try await manager.enableVolumeIndicator()
            
            // Generate volume updates
            for update in 1...50 {
                let volumeInfos = [
                    UserVolumeInfo(userId: "user_\(update)", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                    UserVolumeInfo(userId: "user_\(update + 100)", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                ]
                manager.processVolumeUpdate(volumeInfos)
            }
            
            try await manager.disableVolumeIndicator()
            
            // Check memory periodically
            if cycle % 20 == 0 {
                let currentMemory = measureMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                print("Volume cycle \(cycle): Memory growth = \(memoryGrowth / 1_000_000) MB")
                #expect(memoryGrowth < 30_000_000) // Less than 30MB growth
            }
        }
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Volume indicator total memory growth: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 50_000_000) // Less than 50MB total growth
    }
    
    @Test("Stream push memory leak detection")
    func testStreamPushMemoryLeakDetection() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "stream_memory_room",
            userId: "stream_user",
            userName: "Stream User",
            userRole: .broadcaster
        )
        
        let initialMemory = measureMemoryUsage()
        
        // Repeatedly start/stop stream push
        for cycle in 1...30 {
            let streamConfig = try StreamPushConfig.standard720p(
                pushUrl: "rtmp://memory.test.com/live/stream_\(cycle)"
            )
            
            try await manager.startStreamPush(config: streamConfig)
            
            // Perform layout updates
            for layoutUpdate in 1...10 {
                let layout = StreamLayout(
                    backgroundColor: "#000000",
                    userRegions: [
                        UserRegion(
                            userId: "stream_user",
                            x: layoutUpdate * 10,
                            y: 0,
                            width: 1920 - (layoutUpdate * 20),
                            height: 1080,
                            zOrder: 1,
                            alpha: 1.0
                        )
                    ]
                )
                try await manager.updateStreamLayout(layout: layout)
            }
            
            try await manager.stopStreamPush()
            
            // Check memory periodically
            if cycle % 10 == 0 {
                let currentMemory = measureMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                print("Stream cycle \(cycle): Memory growth = \(memoryGrowth / 1_000_000) MB")
                #expect(memoryGrowth < 40_000_000) // Less than 40MB growth
            }
        }
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Stream push total memory growth: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 60_000_000) // Less than 60MB total growth
    }
    
    @Test("Media relay memory leak detection")
    func testMediaRelayMemoryLeakDetection() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let initialMemory = measureMemoryUsage()
        
        // Repeatedly start/stop media relay with different configurations
        for cycle in 1...25 {
            let sourceChannel = try RelayChannelInfo(
                channelName: "source_\(cycle)",
                userId: "relay_user_\(cycle)"
            )
            
            let destinationChannels = try (1...3).map { destIndex in
                try RelayChannelInfo(
                    channelName: "dest_\(cycle)_\(destIndex)",
                    userId: "dest_user_\(cycle)_\(destIndex)"
                )
            }
            
            let relayConfig = try MediaRelayConfig(
                sourceChannel: sourceChannel,
                destinationChannels: destinationChannels,
                relayMode: .oneToMany
            )
            
            try await manager.startMediaRelay(config: relayConfig)
            
            // Perform channel management operations
            for operation in 1...5 {
                let newChannel = try RelayChannelInfo(
                    channelName: "temp_\(cycle)_\(operation)",
                    userId: "temp_user_\(cycle)_\(operation)"
                )
                
                try await manager.addMediaRelayChannel(newChannel)
                try await manager.pauseMediaRelay(toChannel: "temp_\(cycle)_\(operation)")
                try await manager.resumeMediaRelay(toChannel: "temp_\(cycle)_\(operation)")
                try await manager.removeMediaRelayChannel("temp_\(cycle)_\(operation)")
            }
            
            try await manager.stopMediaRelay()
            
            // Check memory periodically
            if cycle % 5 == 0 {
                let currentMemory = measureMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                print("Relay cycle \(cycle): Memory growth = \(memoryGrowth / 1_000_000) MB")
                #expect(memoryGrowth < 35_000_000) // Less than 35MB growth
            }
        }
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Media relay total memory growth: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 50_000_000) // Less than 50MB total growth
    }
    
    @Test("Message processing memory leak detection")
    func testMessageProcessingMemoryLeakDetection() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let initialMemory = measureMemoryUsage()
        
        // Process large numbers of messages
        for batch in 1...20 {
            for messageIndex in 1...500 {
                let messageTypes: [RealtimeMessage] = [
                    .text("Text message \(batch)_\(messageIndex)", from: "user_\(messageIndex % 10)"),
                    .system("System message \(batch)_\(messageIndex)", metadata: ["batch": "\(batch)"]),
                    .custom("custom_type", data: ["index": messageIndex, "batch": batch], from: "user_\(messageIndex % 5)")
                ]
                
                let message = messageTypes[messageIndex % messageTypes.count]
                try await manager.sendMessage(message)
            }
            
            // Force message processing cleanup
            manager.performMessageProcessingCleanup()
            
            // Check memory periodically
            if batch % 5 == 0 {
                let currentMemory = measureMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                print("Message batch \(batch): Memory growth = \(memoryGrowth / 1_000_000) MB")
                #expect(memoryGrowth < 25_000_000) // Less than 25MB growth
            }
        }
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Message processing total memory growth: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 40_000_000) // Less than 40MB total growth
    }
    
    @Test("Storage operations memory leak detection")
    func testStorageOperationsMemoryLeakDetection() async throws {
        let audioStorage = AudioSettingsStorage()
        let sessionStorage = UserSessionStorage()
        
        let initialMemory = measureMemoryUsage()
        
        // Perform many storage operations
        for cycle in 1...1000 {
            // Audio settings operations
            let audioSettings = AudioSettings(
                microphoneMuted: cycle % 2 == 0,
                audioMixingVolume: cycle % 101,
                playbackSignalVolume: (cycle * 2) % 101,
                recordingSignalVolume: (cycle * 3) % 101,
                localAudioStreamActive: cycle % 3 == 0
            )
            
            try audioStorage.saveAudioSettings(audioSettings)
            let _ = audioStorage.loadAudioSettings()
            
            // User session operations
            let userSession = UserSession(
                userId: "storage_user_\(cycle)",
                userName: "Storage User \(cycle)",
                userRole: UserRole.allCases[cycle % UserRole.allCases.count],
                roomId: "storage_room_\(cycle % 10)"
            )
            
            sessionStorage.saveUserSession(userSession)
            let _ = sessionStorage.loadUserSession()
            
            // Check memory periodically
            if cycle % 200 == 0 {
                let currentMemory = measureMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                print("Storage cycle \(cycle): Memory growth = \(memoryGrowth / 1_000_000) MB")
                #expect(memoryGrowth < 15_000_000) // Less than 15MB growth
            }
        }
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Storage operations total memory growth: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 20_000_000) // Less than 20MB total growth
    }
    
    // MARK: - Concurrent Memory Leak Tests
    
    @Test("Concurrent operations memory leak detection")
    func testConcurrentOperationsMemoryLeakDetection() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "concurrent_memory_room",
            userId: "concurrent_user",
            userName: "Concurrent User",
            userRole: .broadcaster
        )
        
        let initialMemory = measureMemoryUsage()
        
        // Run concurrent operations that might cause memory leaks
        await withTaskGroup(of: Void.self) { group in
            // Volume processing task
            group.addTask {
                for cycle in 1...200 {
                    try? await manager.enableVolumeIndicator()
                    
                    for update in 1...20 {
                        let volumeInfos = [
                            UserVolumeInfo(userId: "concurrent_user", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                            UserVolumeInfo(userId: "other_user_\(update)", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                        ]
                        manager.processVolumeUpdate(volumeInfos)
                    }
                    
                    try? await manager.disableVolumeIndicator()
                }
            }
            
            // Message processing task
            group.addTask {
                for messageIndex in 1...2000 {
                    let message = RealtimeMessage.text("Concurrent message \(messageIndex)", from: "concurrent_user")
                    try? await manager.sendMessage(message)
                }
            }
            
            // Audio settings task
            group.addTask {
                for adjustment in 1...500 {
                    try? await manager.setAudioMixingVolume(adjustment % 101)
                    try? await manager.setPlaybackSignalVolume((adjustment * 2) % 101)
                    try? await manager.muteMicrophone(adjustment % 2 == 0)
                }
            }
            
            // Stream operations task
            group.addTask {
                for streamCycle in 1...50 {
                    let streamConfig = try? StreamPushConfig.standard720p(
                        pushUrl: "rtmp://concurrent.test.com/live/stream_\(streamCycle)"
                    )
                    
                    if let config = streamConfig {
                        try? await manager.startStreamPush(config: config)
                        
                        // Quick layout update
                        let layout = StreamLayout(
                            backgroundColor: "#000000",
                            userRegions: [
                                UserRegion(userId: "concurrent_user", x: 0, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                            ]
                        )
                        try? await manager.updateStreamLayout(layout: layout)
                        
                        try? await manager.stopStreamPush()
                    }
                }
            }
        }
        
        // Force cleanup
        manager.performMemoryCleanup()
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Concurrent operations total memory growth: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 80_000_000) // Less than 80MB total growth for concurrent operations
    }
    
    // MARK: - Error Condition Memory Leak Tests
    
    @Test("Error condition memory leak detection")
    func testErrorConditionMemoryLeakDetection() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        let initialMemory = measureMemoryUsage()
        
        // Simulate various error conditions that might cause memory leaks
        for errorCycle in 1...100 {
            try await manager.joinRoom(
                roomId: "error_room_\(errorCycle)",
                userId: "error_user_\(errorCycle)",
                userName: "Error User \(errorCycle)",
                userRole: .broadcaster
            )
            
            // Start operations
            try await manager.enableVolumeIndicator()
            
            let streamConfig = try StreamPushConfig.standard720p(
                pushUrl: "rtmp://error.test.com/live/error_stream_\(errorCycle)"
            )
            try await manager.startStreamPush(config: streamConfig)
            
            // Simulate various errors
            let errors = [
                RealtimeError.networkError("Simulated network error \(errorCycle)"),
                RealtimeError.audioDeviceError("Simulated audio error \(errorCycle)"),
                RealtimeError.streamPushError("Simulated stream error \(errorCycle)"),
                RealtimeError.volumeIndicatorError("Simulated volume error \(errorCycle)")
            ]
            
            let error = errors[errorCycle % errors.count]
            manager.handleError(error)
            
            // Attempt cleanup despite errors
            try? await manager.stopStreamPush()
            try? await manager.disableVolumeIndicator()
            try? await manager.leaveRoom()
            
            // Force error cleanup
            manager.performErrorCleanup()
            
            // Check memory periodically
            if errorCycle % 20 == 0 {
                let currentMemory = measureMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                
                print("Error cycle \(errorCycle): Memory growth = \(memoryGrowth / 1_000_000) MB")
                #expect(memoryGrowth < 60_000_000) // Less than 60MB growth even with errors
            }
        }
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Error condition total memory growth: \(totalGrowth / 1_000_000) MB")
        #expect(totalGrowth < 100_000_000) // Less than 100MB total growth with error handling
    }
    
    // MARK: - Long-Running Session Memory Test
    
    @Test("Long-running session memory stability")
    func testLongRunningSessionMemoryStability() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "long_running_room",
            userId: "long_running_user",
            userName: "Long Running User",
            userRole: .broadcaster
        )
        
        let initialMemory = measureMemoryUsage()
        var memoryReadings: [Int] = []
        
        // Simulate a long-running session (compressed time)
        let sessionDuration: TimeInterval = 5.0 // 5 seconds representing hours
        let startTime = Date()
        
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://longrun.test.com/live/long_session"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        var operationCount = 0
        
        while Date().timeIntervalSince(startTime) < sessionDuration {
            // Simulate typical ongoing operations
            
            // Volume updates (continuous)
            let volumeInfos = [
                UserVolumeInfo(userId: "long_running_user", volume: Float.random(in: 0.3...1.0), isSpeaking: true),
                UserVolumeInfo(userId: "participant_1", volume: Float.random(in: 0...0.5), isSpeaking: Bool.random()),
                UserVolumeInfo(userId: "participant_2", volume: Float.random(in: 0...0.4), isSpeaking: Bool.random())
            ]
            manager.processVolumeUpdate(volumeInfos)
            
            // Periodic messages
            if operationCount % 10 == 0 {
                let message = RealtimeMessage.text("Long session message \(operationCount)", from: "long_running_user")
                try await manager.sendMessage(message)
            }
            
            // Periodic layout updates
            if operationCount % 50 == 0 {
                let layout = StreamLayout(
                    backgroundColor: "#000000",
                    userRegions: [
                        UserRegion(userId: "long_running_user", x: 0, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                    ]
                )
                try await manager.updateStreamLayout(layout: layout)
            }
            
            // Periodic audio adjustments
            if operationCount % 100 == 0 {
                try await manager.setAudioMixingVolume(70 + (operationCount % 30))
            }
            
            // Memory monitoring
            if operationCount % 200 == 0 {
                let currentMemory = measureMemoryUsage()
                memoryReadings.append(currentMemory)
                
                let memoryGrowth = currentMemory - initialMemory
                print("Long session operation \(operationCount): Memory = \(currentMemory / 1_000_000) MB, Growth = \(memoryGrowth / 1_000_000) MB")
                
                // Memory should not grow unbounded
                #expect(memoryGrowth < 150_000_000) // Less than 150MB growth during long session
                
                // Perform periodic cleanup
                manager.performMemoryCleanup()
            }
            
            operationCount += 1
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
        
        let finalMemory = measureMemoryUsage()
        let totalGrowth = finalMemory - initialMemory
        
        print("Long-running session completed:")
        print("  Operations: \(operationCount)")
        print("  Memory readings: \(memoryReadings.count)")
        print("  Final memory growth: \(totalGrowth / 1_000_000) MB")
        
        // Verify memory stability
        #expect(totalGrowth < 200_000_000) // Less than 200MB total growth
        
        // Verify memory didn't grow continuously
        if memoryReadings.count >= 3 {
            let firstReading = memoryReadings[0]
            let lastReading = memoryReadings.last!
            let continuousGrowth = lastReading - firstReading
            
            #expect(continuousGrowth < 100_000_000) // Less than 100MB continuous growth
        }
    }
}