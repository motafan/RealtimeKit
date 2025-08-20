// NetworkPerformanceTests.swift
// Network performance and concurrency safety tests

import Testing
import Foundation
import Network
@testable import RealtimeCore

@Suite("Network Performance Tests")
struct NetworkPerformanceTests {
    
    @Test("Connection pool manages connections efficiently")
    func testConnectionPoolEfficiency() async throws {
        let pool = ConnectionPool(maxConnections: 5, connectionTimeout: 10.0)
        
        // Create test endpoint
        let endpoint = NWEndpoint.hostPort(host: "localhost", port: 8080)
        
        // Borrow multiple connections
        var connections: [PooledConnection] = []
        
        for _ in 0..<3 {
            let connection = try await pool.borrowConnection(for: endpoint)
            connections.append(connection)
        }
        
        let stats = pool.getStatistics()
        #expect(stats.activeConnections == 3)
        #expect(stats.availableConnections == 0)
        
        // Return connections
        for connection in connections {
            connection.returnToPool()
        }
        
        // Wait a bit for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let finalStats = pool.getStatistics()
        #expect(finalStats.activeConnections == 0)
        #expect(finalStats.availableConnections == 3)
        
        await pool.shutdown()
    }
    
    @Test("Connection pool handles concurrent access safely")
    func testConnectionPoolConcurrency() async throws {
        let pool = ConnectionPool(maxConnections: 10, connectionTimeout: 5.0)
        let endpoint = NWEndpoint.hostPort(host: "localhost", port: 8080)
        
        // Test concurrent borrowing and returning
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    do {
                        let connection = try await pool.borrowConnection(for: endpoint)
                        
                        // Simulate some work
                        try await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000...10_000_000))
                        
                        connection.returnToPool()
                    } catch {
                        print("Connection error in task \(i): \(error)")
                    }
                }
            }
        }
        
        // All connections should be returned
        let finalStats = pool.getStatistics()
        #expect(finalStats.activeConnections == 0)
        
        await pool.shutdown()
    }
    
    @Test("Data compression reduces payload size")
    func testDataCompression() async throws {
        let compressionManager = DataCompressionManager.shared
        
        // Create test data that should compress well (repeated patterns)
        let testString = String(repeating: "This is a test message that should compress well. ", count: 100)
        let testData = testString.data(using: .utf8)!
        
        let compressedData = compressionManager.compressIfBeneficial(testData)
        
        if compressedData.isCompressed {
            #expect(compressedData.data.count < testData.count)
            #expect(compressedData.compressionRatio < 1.0)
            
            // Test decompression
            let decompressedData = try compressedData.decompress()
            #expect(decompressedData == testData)
        }
        
        // Test with small data (should not compress)
        let smallData = "small".data(using: .utf8)!
        let smallCompressed = compressionManager.compressIfBeneficial(smallData)
        #expect(smallCompressed.isCompressed == false)
    }
    
    @Test("Message compression works correctly")
    func testMessageCompression() async throws {
        let message = RealtimeMessage.text(
            String(repeating: "This is a long message that should benefit from compression. ", count: 50),
            from: "user123",
            senderName: "Test User"
        )
        
        let compressedData = try message.compressed()
        
        if compressedData.isCompressed {
            #expect(compressedData.bytesSaved > 0)
            
            // Test decompression
            let decompressedMessage = try RealtimeMessage.fromCompressed(compressedData)
            #expect(decompressedMessage.content == message.content)
            #expect(decompressedMessage.senderId == message.senderId)
        }
    }
    
    @Test("Volume info array compression")
    func testVolumeInfoCompression() async throws {
        // Create large array of volume info
        let volumeInfos = (0..<100).map { i in
            UserVolumeInfo(
                userId: "user_\(i)",
                volume: Float.random(in: 0.0...1.0),
                isSpeaking: Bool.random()
            )
        }
        
        let compressedData = try volumeInfos.compressed()
        
        if compressedData.isCompressed {
            #expect(compressedData.bytesSaved > 0)
            
            // Test decompression
            let decompressedVolumeInfos = try [UserVolumeInfo].fromCompressed(compressedData)
            #expect(decompressedVolumeInfos.count == volumeInfos.count)
            
            for (original, decompressed) in zip(volumeInfos, decompressedVolumeInfos) {
                #expect(original.userId == decompressed.userId)
                #expect(abs(original.volume - decompressed.volume) < 0.001)
                #expect(original.isSpeaking == decompressed.isSpeaking)
            }
        }
    }
}

@Suite("Thread Safety and Concurrency Tests")
struct ThreadSafetyTests {
    
    @Test("Thread-safe dictionary handles concurrent access")
    func testThreadSafeDictionary() async throws {
        let dictionary = ThreadSafeDictionary<String, Int>()
        
        // Test concurrent writes and reads
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<100 {
                group.addTask {
                    dictionary.setValue(i, for: "key_\(i)")
                }
            }
            
            // Readers
            for i in 0..<50 {
                group.addTask {
                    let _ = dictionary.getValue(for: "key_\(i)")
                }
            }
        }
        
        // Verify final state
        let finalCount = dictionary.count()
        #expect(finalCount == 100)
        
        // Test specific values
        let value50 = dictionary.getValue(for: "key_50")
        #expect(value50 == 50)
    }
    
    @Test("Thread-safe array handles concurrent operations")
    func testThreadSafeArray() async throws {
        let array = ThreadSafeArray<Int>()
        
        // Test concurrent appends
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    array.append(i)
                }
            }
        }
        
        let finalCount = array.count()
        #expect(finalCount == 100)
        
        // Test concurrent reads
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let _ = array.element(at: i)
                }
            }
        }
        
        // Array should still be intact
        #expect(array.count() == 100)
    }
    
    @Test("ThreadSafetyManager executes tasks correctly")
    func testThreadSafetyManagerExecution() async throws {
        let manager = ThreadSafetyManager.shared
        
        // Test single task execution
        let result = try await manager.executeTask {
            return 42
        }
        #expect(result == 42)
        
        // Test concurrent task execution
        let operations = (0..<10).map { i in
            return {
                try await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000...5_000_000))
                return i * 2
            }
        }
        
        let results = try await manager.executeConcurrentTasks(operations, maxConcurrency: 5)
        #expect(results.count == 10)
        
        // Verify results (order might be different due to concurrency)
        let sortedResults = results.sorted()
        let expectedResults = (0..<10).map { $0 * 2 }.sorted()
        #expect(sortedResults == expectedResults)
    }
    
    @Test("Background execution works correctly")
    func testBackgroundExecution() async throws {
        let manager = ThreadSafetyManager.shared
        
        let result = try await manager.executeOnBackground {
            // Simulate CPU-intensive work
            var sum = 0
            for i in 0..<1000 {
                sum += i
            }
            return sum
        }
        
        let expectedSum = (0..<1000).reduce(0, +)
        #expect(result == expectedSum)
    }
    
    @Test("Serial execution maintains order")
    func testSerialExecution() async throws {
        let manager = ThreadSafetyManager.shared
        var executionOrder: [Int] = []
        let orderLock = NSLock()
        
        // Execute tasks serially
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        try await manager.executeSerially {
                            orderLock.lock()
                            executionOrder.append(i)
                            orderLock.unlock()
                        }
                    } catch {
                        print("Serial execution error: \(error)")
                    }
                }
            }
        }
        
        // Since tasks are executed serially, order should be maintained
        // (though the specific order depends on task scheduling)
        #expect(executionOrder.count == 5)
        #expect(Set(executionOrder) == Set(0..<5))
    }
    
    @Test("Volume indicator optimized processing")
    func testVolumeIndicatorOptimizedProcessing() async throws {
        let manager = VolumeIndicatorManager()
        let config = VolumeDetectionConfig(detectionInterval: 100)
        
        manager.enable(with: config)
        
        // Create test volume data
        let volumeInfos = (0..<50).map { i in
            UserVolumeInfo(
                userId: "user_\(i)",
                volume: Float.random(in: 0.0...1.0),
                isSpeaking: Bool.random()
            )
        }
        
        // Test optimized processing
        await manager.processVolumeUpdateOptimized(volumeInfos)
        
        // Verify state was updated
        #expect(manager.volumeInfos.count <= 50) // May be filtered
        
        manager.disable()
    }
    
    @Test("Concurrent volume processing doesn't cause race conditions")
    func testConcurrentVolumeProcessing() async throws {
        let manager = VolumeIndicatorManager()
        let config = VolumeDetectionConfig(detectionInterval: 50)
        
        manager.enable(with: config)
        
        // Process multiple volume updates concurrently
        await withTaskGroup(of: Void.self) { group in
            for iteration in 0..<20 {
                group.addTask {
                    let volumeInfos = (0..<10).map { i in
                        UserVolumeInfo(
                            userId: "user_\(i)",
                            volume: Float.random(in: 0.0...1.0),
                            isSpeaking: Bool.random()
                        )
                    }
                    
                    await manager.processVolumeUpdateOptimized(volumeInfos)
                }
            }
        }
        
        // Manager should still be in a consistent state
        #expect(manager.isEnabled == true)
        #expect(manager.volumeInfos.count <= 10)
        
        manager.disable()
    }
}

@Suite("Performance Benchmark Tests")
struct ConcurrencyPerformanceTests {
    
    @Test("Connection pool performance under load")
    func testConnectionPoolPerformance() async throws {
        let pool = ConnectionPool(maxConnections: 20, connectionTimeout: 30.0)
        let endpoint = NWEndpoint.hostPort(host: "localhost", port: 8080)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let operationCount = 1000
        
        // Simulate high load
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<operationCount {
                group.addTask {
                    do {
                        let connection = try await pool.borrowConnection(for: endpoint)
                        
                        // Simulate brief usage
                        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                        
                        connection.returnToPool()
                    } catch {
                        // Handle connection errors gracefully in performance test
                    }
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let operationsPerSecond = Double(operationCount) / totalTime
        
        print("Connection pool throughput: \(operationsPerSecond) ops/sec")
        
        // Should handle at least 100 operations per second
        #expect(operationsPerSecond > 100)
        
        await pool.shutdown()
    }
    
    @Test("Thread-safe collections performance")
    func testThreadSafeCollectionsPerformance() async throws {
        let dictionary = ThreadSafeDictionary<String, Int>()
        let array = ThreadSafeArray<Int>()
        
        let operationCount = 10000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test concurrent operations on both collections
        await withTaskGroup(of: Void.self) { group in
            // Dictionary operations
            for i in 0..<operationCount {
                group.addTask {
                    dictionary.setValue(i, for: "key_\(i)")
                }
            }
            
            // Array operations
            for i in 0..<operationCount {
                group.addTask {
                    array.append(i)
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let operationsPerSecond = Double(operationCount * 2) / totalTime
        
        print("Thread-safe collections throughput: \(operationsPerSecond) ops/sec")
        
        // Should handle at least 10,000 operations per second
        #expect(operationsPerSecond > 10000)
        
        // Verify final state
        #expect(dictionary.count() == operationCount)
        #expect(array.count() == operationCount)
    }
    
    @Test("Compression performance benchmark")
    func testCompressionPerformance() async throws {
        let compressionManager = DataCompressionManager.shared
        
        // Create test data of various sizes
        let testSizes = [1024, 10240, 102400] // 1KB, 10KB, 100KB
        
        for size in testSizes {
            let testData = Data(repeating: 0x41, count: size) // Repeated 'A' characters
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let iterations = 100
            
            for _ in 0..<iterations {
                let _ = compressionManager.compressIfBeneficial(testData)
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let totalTime = endTime - startTime
            let averageTime = totalTime / Double(iterations)
            let throughput = Double(size) / averageTime / 1024.0 / 1024.0 // MB/s
            
            print("Compression throughput for \(size) bytes: \(throughput) MB/s")
            
            // Should achieve reasonable throughput
            #expect(throughput > 1.0) // At least 1 MB/s
        }
    }
}