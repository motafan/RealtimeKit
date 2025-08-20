// ComprehensiveIntegrationTests.swift
// Additional comprehensive integration tests for multi-provider compatibility and end-to-end scenarios

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Comprehensive Integration Tests")
@MainActor
struct ComprehensiveIntegrationTests {
    
    // MARK: - Test Setup
    
    private func createRealtimeManager() -> RealtimeManager {
        let manager = RealtimeManager.shared
        manager.registerMockProvider()
        return manager
    }
    
    private func createTestConfig() -> RealtimeConfig {
        return RealtimeConfig(
            appId: "integration_test_app_id",
            appKey: "integration_test_app_key",
            logLevel: .info
        )
    }
    
    // MARK: - Multi-Provider Compatibility Tests
    
    @Test("Cross-provider feature parity validation")
    func testCrossProviderFeatureParity() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        // Test multiple providers (using mock for demonstration)
        let providers: [ProviderType] = [.mock, .mock] // In real implementation: [.agora, .tencent, .zego]
        var providerResults: [ProviderType: ProviderTestResults] = [:]
        
        for (index, provider) in providers.enumerated() {
            print("Testing provider: \(provider) (iteration \(index + 1))")
            
            try await manager.configure(provider: provider, config: config)
            
            var results = ProviderTestResults(provider: provider)
            
            // Test basic connectivity
            let connectStart = Date()
            try await manager.joinRoom(
                roomId: "parity_test_room_\(index)",
                userId: "parity_user_\(index)",
                userName: "Parity User \(index)",
                userRole: .broadcaster
            )
            results.connectionTime = Date().timeIntervalSince(connectStart)
            results.connectionSuccessful = manager.connectionState == .connected
            
            // Test audio features
            let audioStart = Date()
            try await manager.setAudioMixingVolume(75)
            try await manager.setPlaybackSignalVolume(85)
            try await manager.setRecordingSignalVolume(90)
            try await manager.muteMicrophone(false)
            results.audioConfigTime = Date().timeIntervalSince(audioStart)
            results.audioFeaturesWorking = (
                manager.audioSettings.audioMixingVolume == 75 &&
                manager.audioSettings.playbackSignalVolume == 85 &&
                manager.audioSettings.recordingSignalVolume == 90 &&
                !manager.audioSettings.microphoneMuted
            )
            
            // Test volume indicator
            let volumeStart = Date()
            try await manager.enableVolumeIndicator()
            
            // Generate volume data
            for _ in 1...10 {
                let volumeInfos = [
                    UserVolumeInfo(userId: "parity_user_\(index)", volume: Float.random(in: 0.5...1.0), isSpeaking: true),
                    UserVolumeInfo(userId: "other_user", volume: Float.random(in: 0...0.3), isSpeaking: false)
                ]
                manager.processVolumeUpdate(volumeInfos)
            }
            
            results.volumeIndicatorTime = Date().timeIntervalSince(volumeStart)
            results.volumeIndicatorWorking = manager.volumeIndicatorEnabled
            
            // Test message processing
            let messageStart = Date()
            var messagesSent = 0
            for i in 1...20 {
                let message = RealtimeMessage.text("Parity test message \(i)", from: "parity_user_\(index)")
                try await manager.sendMessage(message)
                messagesSent += 1
            }
            results.messageProcessingTime = Date().timeIntervalSince(messageStart)
            results.messagesProcessed = messagesSent
            
            // Test stream push (if supported)
            if manager.supportsFeature(.streamPush) {
                let streamStart = Date()
                let streamConfig = try StreamPushConfig.standard720p(
                    pushUrl: "rtmp://parity.test.com/live/stream_\(index)"
                )
                try await manager.startStreamPush(config: streamConfig)
                
                // Test layout update
                let layout = StreamLayout(
                    backgroundColor: "#000000",
                    userRegions: [
                        UserRegion(userId: "parity_user_\(index)", x: 0, y: 0, width: 1280, height: 720, zOrder: 1, alpha: 1.0)
                    ]
                )
                try await manager.updateStreamLayout(layout: layout)
                
                try await manager.stopStreamPush()
                results.streamPushTime = Date().timeIntervalSince(streamStart)
                results.streamPushWorking = true
            }
            
            // Test media relay (if supported)
            if manager.supportsFeature(.mediaRelay) {
                let relayStart = Date()
                let sourceChannel = try RelayChannelInfo(
                    channelName: "parity_test_room_\(index)",
                    userId: "parity_user_\(index)"
                )
                let destChannel = try RelayChannelInfo(
                    channelName: "parity_dest_room_\(index)",
                    userId: "parity_user_\(index)"
                )
                
                try await manager.startOneToOneRelay(source: sourceChannel, destination: destChannel)
                try await manager.stopMediaRelay()
                
                results.mediaRelayTime = Date().timeIntervalSince(relayStart)
                results.mediaRelayWorking = true
            }
            
            // Cleanup
            try await manager.disableVolumeIndicator()
            try await manager.leaveRoom()
            
            providerResults[provider] = results
        }
        
        // Analyze results for parity
        print("\nProvider Parity Analysis:")
        for (provider, results) in providerResults {
            print("Provider \(provider):")
            print("  Connection: \(results.connectionSuccessful ? "✓" : "✗") (\(String(format: "%.3f", results.connectionTime))s)")
            print("  Audio: \(results.audioFeaturesWorking ? "✓" : "✗") (\(String(format: "%.3f", results.audioConfigTime))s)")
            print("  Volume: \(results.volumeIndicatorWorking ? "✓" : "✗") (\(String(format: "%.3f", results.volumeIndicatorTime))s)")
            print("  Messages: \(results.messagesProcessed)/20 (\(String(format: "%.3f", results.messageProcessingTime))s)")
            print("  Stream: \(results.streamPushWorking ? "✓" : "✗") (\(String(format: "%.3f", results.streamPushTime))s)")
            print("  Relay: \(results.mediaRelayWorking ? "✓" : "✗") (\(String(format: "%.3f", results.mediaRelayTime))s)")
        }
        
        // Verify all providers support core features
        for (provider, results) in providerResults {
            #expect(results.connectionSuccessful, "Provider \(provider) should support connection")
            #expect(results.audioFeaturesWorking, "Provider \(provider) should support audio features")
            #expect(results.volumeIndicatorWorking, "Provider \(provider) should support volume indicator")
            #expect(results.messagesProcessed == 20, "Provider \(provider) should process all messages")
        }
    }
    
    @Test("Provider switching under load")
    func testProviderSwitchingUnderLoad() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        var switchEvents: [(from: ProviderType, to: ProviderType, duration: TimeInterval)] = []
        
        // Start with first provider
        try await manager.configure(provider: .mock, config: config)
        try await manager.joinRoom(
            roomId: "switch_load_room",
            userId: "switch_user",
            userName: "Switch User",
            userRole: .broadcaster
        )
        
        // Set up active session
        try await manager.setAudioMixingVolume(80)
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard1080p(
            pushUrl: "rtmp://switch.test.com/live/load_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Generate continuous load
        let loadTask = Task {
            var messageCount = 0
            while !Task.isCancelled {
                // Send messages
                let message = RealtimeMessage.text("Load message \(messageCount)", from: "switch_user")
                try? await manager.sendMessage(message)
                messageCount += 1
                
                // Volume updates
                let volumeInfos = [
                    UserVolumeInfo(userId: "switch_user", volume: Float.random(in: 0.5...1.0), isSpeaking: true),
                    UserVolumeInfo(userId: "load_user_1", volume: Float.random(in: 0...0.5), isSpeaking: Bool.random()),
                    UserVolumeInfo(userId: "load_user_2", volume: Float.random(in: 0...0.4), isSpeaking: Bool.random())
                ]
                manager.processVolumeUpdate(volumeInfos)
                
                // Layout updates
                if messageCount % 10 == 0 {
                    let layout = StreamLayout(
                        backgroundColor: "#000000",
                        userRegions: [
                            UserRegion(userId: "switch_user", x: 0, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                        ]
                    )
                    try? await manager.updateStreamLayout(layout: layout)
                }
                
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
        
        // Perform provider switches under load
        let providers: [ProviderType] = [.mock, .mock, .mock] // Simulate different providers
        
        for (index, targetProvider) in providers.enumerated() {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second of load
            
            let switchStart = Date()
            let currentProvider = manager.currentProvider
            
            print("Switching from \(currentProvider) to \(targetProvider) under load...")
            
            try await manager.switchProvider(to: targetProvider, preserveSession: true)
            
            let switchDuration = Date().timeIntervalSince(switchStart)
            switchEvents.append((from: currentProvider, to: targetProvider, duration: switchDuration))
            
            // Verify session continuity
            #expect(manager.connectionState == .connected)
            #expect(manager.currentSession?.userId == "switch_user")
            #expect(manager.streamPushState == .running)
            #expect(manager.volumeIndicatorEnabled == true)
            #expect(manager.audioSettings.audioMixingVolume == 80)
            
            print("Switch completed in \(String(format: "%.3f", switchDuration))s")
        }
        
        // Stop load generation
        loadTask.cancel()
        
        // Cleanup
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
        
        // Analyze switch performance
        print("\nProvider Switch Performance:")
        for (index, event) in switchEvents.enumerated() {
            print("Switch \(index + 1): \(event.from) → \(event.to) in \(String(format: "%.3f", event.duration))s")
            #expect(event.duration < 5.0, "Provider switch should complete within 5 seconds")
        }
        
        let averageSwitchTime = switchEvents.map { $0.duration }.reduce(0, +) / Double(switchEvents.count)
        print("Average switch time: \(String(format: "%.3f", averageSwitchTime))s")
        #expect(averageSwitchTime < 3.0, "Average switch time should be under 3 seconds")
    }
    
    // MARK: - Network Resilience Integration Tests
    
    @Test("End-to-end network resilience")
    func testEndToEndNetworkResilience() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        var networkEvents: [NetworkResilienceEvent] = []
        manager.onNetworkEvent = { event in
            networkEvents.append(event)
        }
        
        // Start comprehensive session
        try await manager.joinRoom(
            roomId: "resilience_room",
            userId: "resilience_user",
            userName: "Resilience User",
            userRole: .broadcaster
        )
        
        try await manager.enableVolumeIndicator()
        
        let streamConfig = try StreamPushConfig.standard720p(
            pushUrl: "rtmp://resilience.test.com/live/resilience_stream"
        )
        try await manager.startStreamPush(config: streamConfig)
        
        // Set up media relay
        let sourceChannel = try RelayChannelInfo(
            channelName: "resilience_room",
            userId: "resilience_user"
        )
        let destChannel = try RelayChannelInfo(
            channelName: "resilience_backup",
            userId: "resilience_user"
        )
        try await manager.startOneToOneRelay(source: sourceChannel, destination: destChannel)
        
        // Test various network conditions
        let networkScenarios = [
            NetworkScenario(name: "High Latency", latency: 500, packetLoss: 0.05, bandwidth: 500),
            NetworkScenario(name: "Packet Loss", latency: 100, packetLoss: 0.15, bandwidth: 1000),
            NetworkScenario(name: "Low Bandwidth", latency: 200, packetLoss: 0.02, bandwidth: 64),
            NetworkScenario(name: "Connection Drop", latency: 0, packetLoss: 1.0, bandwidth: 0),
            NetworkScenario(name: "Recovery", latency: 50, packetLoss: 0.01, bandwidth: 2000)
        ]
        
        for scenario in networkScenarios {
            print("Testing network scenario: \(scenario.name)")
            
            // Apply network conditions
            manager.simulateNetworkConditions(
                latency: TimeInterval(scenario.latency) / 1000.0,
                packetLoss: scenario.packetLoss,
                bandwidth: scenario.bandwidth
            )
            
            // Generate activity under network stress
            let scenarioStart = Date()
            
            await withTaskGroup(of: Void.self) { group in
                // Message sending
                group.addTask {
                    for i in 1...20 {
                        let message = RealtimeMessage.text("Resilience message \(i)", from: "resilience_user")
                        do {
                            try await manager.sendMessage(message)
                        } catch {
                            print("Message \(i) failed under \(scenario.name): \(error)")
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    }
                }
                
                // Volume updates
                group.addTask {
                    for i in 1...30 {
                        let volumeInfos = [
                            UserVolumeInfo(userId: "resilience_user", volume: Float.random(in: 0.5...1.0), isSpeaking: true)
                        ]
                        manager.processVolumeUpdate(volumeInfos)
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    }
                }
                
                // Stream layout updates
                group.addTask {
                    for i in 1...5 {
                        let layout = StreamLayout(
                            backgroundColor: "#000000",
                            userRegions: [
                                UserRegion(userId: "resilience_user", x: i * 10, y: 0, width: 1280, height: 720, zOrder: 1, alpha: 1.0)
                            ]
                        )
                        do {
                            try await manager.updateStreamLayout(layout: layout)
                        } catch {
                            print("Layout update \(i) failed under \(scenario.name): \(error)")
                        }
                        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
                    }
                }
            }
            
            let scenarioDuration = Date().timeIntervalSince(scenarioStart)
            print("Scenario \(scenario.name) completed in \(String(format: "%.2f", scenarioDuration))s")
            
            // Verify system resilience
            if scenario.name != "Connection Drop" {
                #expect(manager.connectionState != .disconnected, "Should maintain connection under \(scenario.name)")
            }
            
            // Allow recovery time
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        
        // Reset network conditions
        manager.resetNetworkSimulation()
        
        // Verify final state
        #expect(manager.connectionState == .connected)
        #expect(manager.streamPushState == .running)
        #expect(manager.isMediaRelayActive == true)
        
        // Cleanup
        try await manager.stopMediaRelay()
        try await manager.stopStreamPush()
        try await manager.disableVolumeIndicator()
        try await manager.leaveRoom()
        
        print("Network resilience test completed with \(networkEvents.count) network events")
    }
    
    // MARK: - Performance Benchmark Tests
    
    @Test("Comprehensive performance benchmarks")
    func testComprehensivePerformanceBenchmarks() async throws {
        let manager = createRealtimeManager()
        let config = createTestConfig()
        
        try await manager.configure(provider: .mock, config: config)
        
        var benchmarkResults: [String: BenchmarkResult] = [:]
        
        // Benchmark 1: Connection Performance
        let connectionBenchmark = await measurePerformance("Connection") {
            for i in 1...10 {
                try await manager.joinRoom(
                    roomId: "benchmark_room_\(i)",
                    userId: "benchmark_user_\(i)",
                    userName: "Benchmark User \(i)",
                    userRole: .broadcaster
                )
                try await manager.leaveRoom()
            }
        }
        benchmarkResults["Connection"] = connectionBenchmark
        
        // Set up for remaining benchmarks
        try await manager.joinRoom(
            roomId: "benchmark_room",
            userId: "benchmark_user",
            userName: "Benchmark User",
            userRole: .broadcaster
        )
        
        // Benchmark 2: Message Processing Performance
        let messageBenchmark = await measurePerformance("Message Processing") {
            for i in 1...1000 {
                let message = RealtimeMessage.text("Benchmark message \(i)", from: "benchmark_user")
                try await manager.sendMessage(message)
            }
        }
        benchmarkResults["Message Processing"] = messageBenchmark
        
        // Benchmark 3: Volume Indicator Performance
        let volumeBenchmark = await measurePerformance("Volume Indicator") {
            try await manager.enableVolumeIndicator()
            
            for i in 1...500 {
                let volumeInfos = [
                    UserVolumeInfo(userId: "user_1", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                    UserVolumeInfo(userId: "user_2", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                    UserVolumeInfo(userId: "user_3", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                    UserVolumeInfo(userId: "user_4", volume: Float.random(in: 0...1), isSpeaking: Bool.random()),
                    UserVolumeInfo(userId: "user_5", volume: Float.random(in: 0...1), isSpeaking: Bool.random())
                ]
                manager.processVolumeUpdate(volumeInfos)
            }
            
            try await manager.disableVolumeIndicator()
        }
        benchmarkResults["Volume Indicator"] = volumeBenchmark
        
        // Benchmark 4: Stream Push Performance
        let streamBenchmark = await measurePerformance("Stream Push") {
            let streamConfig = try StreamPushConfig.standard1080p(
                pushUrl: "rtmp://benchmark.test.com/live/benchmark_stream"
            )
            
            try await manager.startStreamPush(config: streamConfig)
            
            // Perform layout updates
            for i in 1...50 {
                let layout = StreamLayout(
                    backgroundColor: "#000000",
                    userRegions: [
                        UserRegion(userId: "benchmark_user", x: i % 100, y: 0, width: 1920, height: 1080, zOrder: 1, alpha: 1.0)
                    ]
                )
                try await manager.updateStreamLayout(layout: layout)
            }
            
            try await manager.stopStreamPush()
        }
        benchmarkResults["Stream Push"] = streamBenchmark
        
        // Benchmark 5: Audio Settings Performance
        let audioBenchmark = await measurePerformance("Audio Settings") {
            for i in 1...200 {
                try await manager.setAudioMixingVolume(i % 101)
                try await manager.setPlaybackSignalVolume((i * 2) % 101)
                try await manager.setRecordingSignalVolume((i * 3) % 101)
                try await manager.muteMicrophone(i % 2 == 0)
            }
        }
        benchmarkResults["Audio Settings"] = audioBenchmark
        
        // Benchmark 6: Media Relay Performance
        let relayBenchmark = await measurePerformance("Media Relay") {
            for i in 1...10 {
                let sourceChannel = try RelayChannelInfo(
                    channelName: "benchmark_room",
                    userId: "benchmark_user"
                )
                let destChannel = try RelayChannelInfo(
                    channelName: "benchmark_dest_\(i)",
                    userId: "benchmark_user"
                )
                
                try await manager.startOneToOneRelay(source: sourceChannel, destination: destChannel)
                
                // Add/remove channels
                for j in 1...5 {
                    let tempChannel = try RelayChannelInfo(
                        channelName: "temp_\(i)_\(j)",
                        userId: "benchmark_user"
                    )
                    try await manager.addMediaRelayChannel(tempChannel)
                    try await manager.removeMediaRelayChannel("temp_\(i)_\(j)")
                }
                
                try await manager.stopMediaRelay()
            }
        }
        benchmarkResults["Media Relay"] = relayBenchmark
        
        // Print benchmark results
        print("\nPerformance Benchmark Results:")
        print("=" * 50)
        
        for (name, result) in benchmarkResults.sorted(by: { $0.key < $1.key }) {
            print("\(name):")
            print("  Duration: \(String(format: "%.3f", result.duration))s")
            print("  Operations: \(result.operations)")
            print("  Ops/sec: \(String(format: "%.1f", result.operationsPerSecond))")
            print("  Memory: \(result.memoryUsage / 1_000_000)MB")
            print("")
        }
        
        // Verify performance requirements
        #expect(benchmarkResults["Connection"]!.operationsPerSecond > 2, "Connection performance should be > 2 ops/sec")
        #expect(benchmarkResults["Message Processing"]!.operationsPerSecond > 100, "Message processing should be > 100 ops/sec")
        #expect(benchmarkResults["Volume Indicator"]!.operationsPerSecond > 200, "Volume indicator should be > 200 ops/sec")
        #expect(benchmarkResults["Stream Push"]!.operationsPerSecond > 10, "Stream push should be > 10 ops/sec")
        #expect(benchmarkResults["Audio Settings"]!.operationsPerSecond > 50, "Audio settings should be > 50 ops/sec")
        #expect(benchmarkResults["Media Relay"]!.operationsPerSecond > 1, "Media relay should be > 1 ops/sec")
        
        try await manager.leaveRoom()
    }
    
    // MARK: - Helper Functions
    
    private func measurePerformance(_ name: String, operations: Int? = nil, _ block: () async throws -> Void) async -> BenchmarkResult {
        let startTime = Date()
        let startMemory = measureMemoryUsage()
        
        try? await block()
        
        let endTime = Date()
        let endMemory = measureMemoryUsage()
        
        let duration = endTime.timeIntervalSince(startTime)
        let memoryUsage = endMemory - startMemory
        let operationCount = operations ?? 1
        let operationsPerSecond = Double(operationCount) / duration
        
        return BenchmarkResult(
            duration: duration,
            operations: operationCount,
            operationsPerSecond: operationsPerSecond,
            memoryUsage: memoryUsage
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
    
    // MARK: - Helper Structures
    
    struct ProviderTestResults {
        let provider: ProviderType
        var connectionTime: TimeInterval = 0
        var connectionSuccessful: Bool = false
        var audioConfigTime: TimeInterval = 0
        var audioFeaturesWorking: Bool = false
        var volumeIndicatorTime: TimeInterval = 0
        var volumeIndicatorWorking: Bool = false
        var messageProcessingTime: TimeInterval = 0
        var messagesProcessed: Int = 0
        var streamPushTime: TimeInterval = 0
        var streamPushWorking: Bool = false
        var mediaRelayTime: TimeInterval = 0
        var mediaRelayWorking: Bool = false
    }
    
    struct NetworkScenario {
        let name: String
        let latency: Int        // milliseconds
        let packetLoss: Double  // 0.0 - 1.0
        let bandwidth: Int      // kbps
    }
    
    struct NetworkResilienceEvent {
        let timestamp: Date
        let eventType: String
        let description: String
    }
    
    struct BenchmarkResult {
        let duration: TimeInterval
        let operations: Int
        let operationsPerSecond: Double
        let memoryUsage: Int
    }
}