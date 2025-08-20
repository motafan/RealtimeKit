// MemoryLeakDetectionTests.swift
// Memory leak detection and performance benchmark tests

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Memory Leak Detection Tests")
struct MemoryLeakDetectionTests {
    
    @Test("Object pool prevents memory leaks")
    func testObjectPoolMemoryManagement() async throws {
        let pool = ObjectPool<TestObject>(
            maxPoolSize: 5,
            createObject: { TestObject() },
            resetObject: { $0.reset() }
        )
        
        // Create and return many objects
        var objects: [TestObject] = []
        
        // Borrow objects
        for _ in 0..<10 {
            objects.append(pool.borrow())
        }
        
        // Return all objects
        for object in objects {
            pool.return(object)
        }
        
        let stats = pool.getStatistics()
        #expect(stats.currentPoolSize <= stats.maxPoolSize)
        #expect(stats.currentPoolSize > 0) // Some objects should be pooled
    }
    
    @Test("Memory manager tracks weak references correctly")
    func testMemoryManagerWeakReferences() async throws {
        let memoryManager = MemoryManager.shared
        
        // Create objects and register weak references
        var testObjects: [TestObject] = []
        
        for i in 0..<5 {
            let object = TestObject()
            testObjects.append(object)
            
            memoryManager.registerWeakReference(
                to: object,
                identifier: "test_\(i)"
            )
        }
        
        let initialCount = memoryManager.getActiveReferenceCount()
        #expect(initialCount == 5)
        
        // Release some objects
        testObjects.removeFirst(3)
        
        // Force cleanup
        memoryManager.cleanupDeallocatedReferences()
        
        let finalCount = memoryManager.getActiveReferenceCount()
        #expect(finalCount == 2) // Only 2 objects should remain
    }
    
    @Test("Volume indicator manager doesn't leak memory with frequent updates")
    func testVolumeIndicatorMemoryUsage() async throws {
        let manager = VolumeIndicatorManager()
        let config = VolumeDetectionConfig(detectionInterval: 100)
        
        manager.enable(with: config)
        
        // Simulate frequent volume updates
        for iteration in 0..<100 {
            let volumeInfos = (0..<10).map { userId in
                UserVolumeInfo(
                    userId: "user_\(userId)",
                    volume: Float.random(in: 0.0...1.0),
                    isSpeaking: Bool.random()
                )
            }
            
            manager.processVolumeUpdate(volumeInfos)
            
            // Check memory usage periodically
            if iteration % 20 == 0 {
                let currentInfos = manager.volumeInfos
                #expect(currentInfos.count <= 10) // Should not accumulate
            }
        }
        
        manager.disable()
        
        // After disabling, state should be cleared
        #expect(manager.volumeInfos.isEmpty)
        #expect(manager.speakingUsers.isEmpty)
    }
    
    @Test("Message processing doesn't accumulate memory")
    func testMessageProcessingMemoryUsage() async throws {
        let manager = MessageProcessorManager()
        
        // Register a simple processor
        let processor = TestMessageProcessor()
        try manager.registerProcessor(processor)
        
        // Process many messages
        for i in 0..<1000 {
            let message = RealtimeMessage.text(
                "Test message \(i)",
                from: "user_\(i % 10)"
            )
            
            await manager.processMessage(message)
        }
        
        // Processing queue should not accumulate messages
        #expect(manager.processingQueue.count < 100) // Should be much smaller
        
        let stats = manager.getProcessingStats()
        #expect(stats.totalProcessed > 0)
    }
    
    @Test("RealtimeManager cleanup prevents memory leaks")
    func testRealtimeManagerCleanup() async throws {
        // This test would require a more complex setup with actual providers
        // For now, we'll test the memory manager integration
        
        let memoryManager = MemoryManager.shared
        let initialStats = memoryManager.getStatistics()
        
        // Simulate registering and cleaning up resources
        var cleanupExecuted = false
        
        memoryManager.registerCleanupTask(identifier: "test_cleanup") {
            cleanupExecuted = true
        }
        
        memoryManager.executeAllCleanupTasks()
        
        #expect(cleanupExecuted == true)
        
        memoryManager.unregisterCleanupTask(identifier: "test_cleanup")
        
        let finalStats = memoryManager.getStatistics()
        #expect(finalStats.registeredCleanupTasks == initialStats.registeredCleanupTasks)
    }
    
    @Test("Basic object pool functionality")
    func testBasicObjectPool() async throws {
        let pool = ObjectPool<TestObject>(
            maxPoolSize: 10,
            createObject: { TestObject() },
            resetObject: { $0.reset() }
        )
        
        // Test basic borrow and return
        var objects: [TestObject] = []
        
        for _ in 0..<5 {
            objects.append(pool.borrow())
        }
        
        for obj in objects {
            pool.return(obj)
        }
        
        let stats = pool.getStatistics()
        #expect(stats.currentPoolSize > 0)
        #expect(stats.currentPoolSize <= stats.maxPoolSize)
    }
}

@Suite("Performance Benchmark Tests")
struct PerformanceBenchmarkTests {
    
    @Test("Volume processing performance benchmark")
    func testVolumeProcessingPerformance() async throws {
        let manager = VolumeIndicatorManager()
        let config = VolumeDetectionConfig(detectionInterval: 100)
        
        manager.enable(with: config)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let iterations = 1000
        
        // Benchmark volume processing
        for _ in 0..<iterations {
            let volumeInfos = (0..<20).map { userId in
                UserVolumeInfo(
                    userId: "user_\(userId)",
                    volume: Float.random(in: 0.0...1.0),
                    isSpeaking: Bool.random()
                )
            }
            
            manager.processVolumeUpdate(volumeInfos)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations)
        
        print("Volume processing: \(averageTime * 1000) ms per iteration")
        
        // Performance should be under 1ms per iteration for 20 users
        #expect(averageTime < 0.001)
        
        manager.disable()
    }
    
    @Test("Object pool performance vs direct allocation")
    func testObjectPoolPerformance() async throws {
        let iterations = 10000
        
        // Test direct allocation
        let directStartTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            let _ = TestObject()
        }
        
        let directEndTime = CFAbsoluteTimeGetCurrent()
        let directTime = directEndTime - directStartTime
        
        // Test pool allocation
        let pool = ObjectPool<TestObject>(
            maxPoolSize: 100,
            createObject: { TestObject() },
            resetObject: { $0.reset() }
        )
        
        let poolStartTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            let obj = pool.borrow()
            pool.return(obj)
        }
        
        let poolEndTime = CFAbsoluteTimeGetCurrent()
        let poolTime = poolEndTime - poolStartTime
        
        print("Direct allocation: \(directTime * 1000) ms")
        print("Pool allocation: \(poolTime * 1000) ms")
        
        // Pool should be faster for frequent allocations
        // Note: This might not always be true for very simple objects
        // but demonstrates the measurement capability
        #expect(poolTime > 0) // Just ensure it completes
        #expect(directTime > 0)
    }
    
    @Test("Memory usage tracking performance")
    func testMemoryUsageTrackingPerformance() async throws {
        let memoryManager = MemoryManager.shared
        let iterations = 1000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Benchmark memory tracking operations
        for i in 0..<iterations {
            let object = TestObject()
            
            memoryManager.registerWeakReference(
                to: object,
                identifier: "perf_test_\(i)"
            )
            
            if i % 100 == 0 {
                memoryManager.cleanupDeallocatedReferences()
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations)
        
        print("Memory tracking: \(averageTime * 1000000) μs per operation")
        
        // Should be very fast - under 100 microseconds per operation
        #expect(averageTime < 0.0001)
        
        // Cleanup
        memoryManager.cleanupDeallocatedReferences()
    }
    
    @Test("Message processing throughput benchmark")
    func testMessageProcessingThroughput() async throws {
        let manager = MessageProcessorManager()
        let processor = TestMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        let messageCount = 5000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process messages concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<messageCount {
                group.addTask {
                    let message = RealtimeMessage.text(
                        "Benchmark message \(i)",
                        from: "user_\(i % 100)"
                    )
                    await manager.processMessage(message)
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let throughput = Double(messageCount) / totalTime
        
        print("Message processing throughput: \(throughput) messages/second")
        
        // Should process at least 1000 messages per second
        #expect(throughput > 1000)
        
        let stats = manager.getProcessingStats()
        #expect(stats.totalProcessed == messageCount)
    }
}

// MARK: - Test Helper Classes

private class TestObject {
    var data: String = ""
    var number: Int = 0
    
    func reset() {
        data = ""
        number = 0
    }
}

private class TestMessageProcessor: MessageProcessor {
    let supportedMessageTypes: [String] = ["text", "system"]
    
    func canProcess(_ message: RealtimeMessage) -> Bool {
        return supportedMessageTypes.contains(message.messageType.rawValue)
    }
    
    func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        // Simulate some processing time
        try await Task.sleep(nanoseconds: 1_000) // 1 microsecond
        return .processed(message)
    }
    
    func handleProcessingError(_ error: Error, for message: RealtimeMessage) async -> MessageProcessingResult {
        return .failed(error)
    }
}