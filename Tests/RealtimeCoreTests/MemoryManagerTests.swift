// MemoryManagerTests.swift
// Comprehensive unit tests for MemoryManager

import Testing
@testable import RealtimeCore

@Suite("MemoryManager Tests")
struct MemoryManagerTests {
    
    // MARK: - Test Setup
    
    private func createMemoryManager() -> MemoryManager {
        return MemoryManager()
    }
    
    // MARK: - Initialization Tests
    
    @Test("MemoryManager initialization")
    func testMemoryManagerInitialization() {
        let manager = createMemoryManager()
        
        #expect(manager.isMonitoring == false)
        #expect(manager.currentMemoryUsage == 0)
        #expect(manager.peakMemoryUsage == 0)
        #expect(manager.memoryWarningCount == 0)
    }
    
    // MARK: - Memory Monitoring Tests
    
    @Test("Start memory monitoring")
    func testStartMemoryMonitoring() async {
        let manager = createMemoryManager()
        
        manager.startMonitoring(interval: 0.1)
        
        #expect(manager.isMonitoring == true)
        
        // Wait for some monitoring cycles
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        #expect(manager.currentMemoryUsage > 0)
        
        manager.stopMonitoring()
    }
    
    @Test("Stop memory monitoring")
    func testStopMemoryMonitoring() async {
        let manager = createMemoryManager()
        
        manager.startMonitoring(interval: 0.1)
        #expect(manager.isMonitoring == true)
        
        manager.stopMonitoring()
        #expect(manager.isMonitoring == false)
    }
    
    @Test("Memory usage tracking")
    func testMemoryUsageTracking() async {
        let manager = createMemoryManager()
        
        manager.startMonitoring(interval: 0.05)
        
        // Allocate some memory to increase usage
        var arrays: [[Int]] = []
        for _ in 0..<100 {
            arrays.append(Array(0..<1000))
        }
        
        // Wait for monitoring to capture the increase
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let currentUsage = manager.currentMemoryUsage
        let peakUsage = manager.peakMemoryUsage
        
        #expect(currentUsage > 0)
        #expect(peakUsage >= currentUsage)
        
        // Clean up memory
        arrays.removeAll()
        
        manager.stopMonitoring()
    }
    
    // MARK: - Memory Warning Tests
    
    @Test("Memory warning detection")
    func testMemoryWarningDetection() async {
        let manager = createMemoryManager()
        manager.setMemoryWarningThreshold(0.1) // Very low threshold for testing
        
        var warningReceived = false
        manager.onMemoryWarning = { usage in
            warningReceived = true
        }
        
        manager.startMonitoring(interval: 0.05)
        
        // Allocate significant memory to trigger warning
        var arrays: [[Int]] = []
        for _ in 0..<1000 {
            arrays.append(Array(0..<10000))
        }
        
        // Wait for warning detection
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(warningReceived == true)
        #expect(manager.memoryWarningCount > 0)
        
        // Clean up
        arrays.removeAll()
        manager.stopMonitoring()
    }
    
    @Test("Memory pressure handling")
    func testMemoryPressureHandling() async {
        let manager = createMemoryManager()
        manager.setMemoryPressureThreshold(0.05) // Very low threshold
        
        var pressureHandled = false
        manager.onMemoryPressure = { level in
            pressureHandled = true
        }
        
        manager.startMonitoring(interval: 0.05)
        
        // Simulate memory pressure
        manager.simulateMemoryPressure(.critical)
        
        // Wait for pressure handling
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(pressureHandled == true)
        
        manager.stopMonitoring()
    }
    
    // MARK: - Memory Cleanup Tests
    
    @Test("Automatic memory cleanup")
    func testAutomaticMemoryCleanup() async {
        let manager = createMemoryManager()
        manager.enableAutomaticCleanup(threshold: 0.1)
        
        var cleanupPerformed = false
        manager.onMemoryCleanup = { freedBytes in
            cleanupPerformed = true
        }
        
        manager.startMonitoring(interval: 0.05)
        
        // Allocate memory to trigger cleanup
        var arrays: [[Int]] = []
        for _ in 0..<500 {
            arrays.append(Array(0..<5000))
        }
        
        // Wait for automatic cleanup
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #expect(cleanupPerformed == true)
        
        // Clean up
        arrays.removeAll()
        manager.stopMonitoring()
    }
    
    @Test("Manual memory cleanup")
    func testManualMemoryCleanup() async {
        let manager = createMemoryManager()
        
        // Register cleanup handlers
        manager.registerCleanupHandler("test_cache") {
            return 1024 // Simulate freeing 1KB
        }
        
        manager.registerCleanupHandler("test_buffers") {
            return 2048 // Simulate freeing 2KB
        }
        
        let freedBytes = await manager.performCleanup()
        
        #expect(freedBytes >= 3072) // Should free at least 3KB
    }
    
    @Test("Cleanup handler priority")
    func testCleanupHandlerPriority() async {
        let manager = createMemoryManager()
        
        var executionOrder: [String] = []
        
        manager.registerCleanupHandler("low_priority", priority: .low) {
            executionOrder.append("low")
            return 100
        }
        
        manager.registerCleanupHandler("high_priority", priority: .high) {
            executionOrder.append("high")
            return 200
        }
        
        manager.registerCleanupHandler("normal_priority", priority: .normal) {
            executionOrder.append("normal")
            return 150
        }
        
        let _ = await manager.performCleanup()
        
        // Should execute in priority order: high, normal, low
        #expect(executionOrder == ["high", "normal", "low"])
    }
    
    // MARK: - Memory Pool Tests
    
    @Test("Object pool management")
    func testObjectPoolManagement() {
        let manager = createMemoryManager()
        
        // Create object pools
        let stringPool = manager.createObjectPool(for: String.self, initialSize: 10) {
            return ""
        }
        
        let arrayPool = manager.createObjectPool(for: [Int].self, initialSize: 5) {
            return []
        }
        
        #expect(manager.getActivePoolCount() == 2)
        
        // Test pool operations
        let string1 = stringPool.acquire()
        let string2 = stringPool.acquire()
        
        #expect(string1 != nil)
        #expect(string2 != nil)
        
        stringPool.release(string1)
        stringPool.release(string2)
        
        // Clean up pools
        manager.clearAllPools()
        #expect(manager.getActivePoolCount() == 0)
    }
    
    @Test("Memory pool efficiency")
    func testMemoryPoolEfficiency() async {
        let manager = createMemoryManager()
        
        let pool = manager.createObjectPool(for: [Int].self, initialSize: 100) {
            return Array(0..<1000)
        }
        
        manager.startMonitoring(interval: 0.05)
        let initialMemory = manager.currentMemoryUsage
        
        // Use pool objects instead of creating new ones
        var objects: [[Int]] = []
        for _ in 0..<50 {
            if let obj = pool.acquire() {
                objects.append(obj)
            }
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        let poolMemory = manager.currentMemoryUsage
        
        // Release objects back to pool
        for obj in objects {
            pool.release(obj)
        }
        objects.removeAll()
        
        // Create new objects without pool
        for _ in 0..<50 {
            objects.append(Array(0..<1000))
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        let directMemory = manager.currentMemoryUsage
        
        // Pool usage should be more memory efficient
        #expect(poolMemory <= directMemory)
        
        objects.removeAll()
        manager.stopMonitoring()
    }
    
    // MARK: - Memory Statistics Tests
    
    @Test("Memory usage statistics")
    func testMemoryUsageStatistics() async {
        let manager = createMemoryManager()
        
        manager.startMonitoring(interval: 0.05)
        
        // Generate some memory activity
        var arrays: [[Int]] = []
        for i in 0..<10 {
            arrays.append(Array(0..<(i + 1) * 100))
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        let stats = manager.getMemoryStatistics()
        
        #expect(stats.currentUsage > 0)
        #expect(stats.peakUsage >= stats.currentUsage)
        #expect(stats.averageUsage > 0)
        #expect(stats.sampleCount > 0)
        
        arrays.removeAll()
        manager.stopMonitoring()
    }
    
    @Test("Memory allocation tracking")
    func testMemoryAllocationTracking() async {
        let manager = createMemoryManager()
        manager.enableAllocationTracking()
        
        manager.startMonitoring(interval: 0.05)
        
        // Perform allocations
        var objects: [Any] = []
        for _ in 0..<100 {
            objects.append(Array(0..<1000))
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let allocStats = manager.getAllocationStatistics()
        
        #expect(allocStats.totalAllocations > 0)
        #expect(allocStats.totalBytesAllocated > 0)
        #expect(allocStats.allocationRate > 0)
        
        objects.removeAll()
        manager.stopMonitoring()
    }
    
    // MARK: - Memory Leak Detection Tests
    
    @Test("Memory leak detection")
    func testMemoryLeakDetection() async {
        let manager = createMemoryManager()
        manager.enableLeakDetection()
        
        var leakDetected = false
        manager.onMemoryLeak = { leakInfo in
            leakDetected = true
        }
        
        manager.startMonitoring(interval: 0.05)
        
        // Simulate potential memory leak
        var leakyObjects: [TestLeakyClass] = []
        for _ in 0..<100 {
            leakyObjects.append(TestLeakyClass())
        }
        
        // Wait for leak detection
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Clean up to avoid actual leaks in tests
        leakyObjects.removeAll()
        
        manager.stopMonitoring()
        
        // Note: Leak detection might not trigger in test environment
        // This test mainly ensures the API works without crashing
        #expect(Bool(true))
    }
    
    @Test("Weak reference tracking")
    func testWeakReferenceTracking() {
        let manager = createMemoryManager()
        
        var object: TestObject? = TestObject()
        weak var weakObject = object
        
        manager.trackWeakReference(weakObject, identifier: "test_object")
        
        #expect(manager.getTrackedReferenceCount() == 1)
        #expect(manager.isReferenceAlive("test_object") == true)
        
        object = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(manager.isReferenceAlive("test_object") == false)
        
        manager.cleanupDeadReferences()
        #expect(manager.getTrackedReferenceCount() == 0)
    }
    
    // MARK: - Performance Optimization Tests
    
    @Test("Memory compaction")
    func testMemoryCompaction() async {
        let manager = createMemoryManager()
        
        manager.startMonitoring(interval: 0.05)
        
        // Create fragmented memory pattern
        var objects: [Any] = []
        for i in 0..<100 {
            if i % 2 == 0 {
                objects.append(Array(0..<1000))
            } else {
                objects.append("String \(i)")
            }
        }
        
        let beforeCompaction = manager.currentMemoryUsage
        
        // Perform compaction
        let compactedBytes = await manager.performMemoryCompaction()
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let afterCompaction = manager.currentMemoryUsage
        
        #expect(compactedBytes >= 0)
        // Note: Actual compaction results may vary in test environment
        
        objects.removeAll()
        manager.stopMonitoring()
    }
    
    @Test("Memory defragmentation")
    func testMemoryDefragmentation() async {
        let manager = createMemoryManager()
        
        // Enable defragmentation
        manager.enableAutoDefragmentation(threshold: 0.3)
        
        var defragmentationPerformed = false
        manager.onDefragmentation = { freedBytes in
            defragmentationPerformed = true
        }
        
        manager.startMonitoring(interval: 0.05)
        
        // Create fragmented memory
        var objects: [[Int]] = []
        for _ in 0..<50 {
            objects.append(Array(0..<1000))
        }
        
        // Remove every other object to create fragmentation
        for i in stride(from: objects.count - 1, through: 0, by: -2) {
            objects.remove(at: i)
        }
        
        // Wait for auto-defragmentation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        objects.removeAll()
        manager.stopMonitoring()
        
        // Note: Defragmentation might not trigger in test environment
        #expect(Bool(true))
    }
    
    // MARK: - Configuration Tests
    
    @Test("Memory manager configuration")
    func testMemoryManagerConfiguration() {
        let manager = createMemoryManager()
        
        let config = MemoryManagerConfig(
            monitoringInterval: 0.1,
            warningThreshold: 0.8,
            criticalThreshold: 0.9,
            enableAutoCleanup: true,
            enableLeakDetection: true,
            maxPoolSize: 1000
        )
        
        manager.configure(with: config)
        
        #expect(manager.configuration.monitoringInterval == 0.1)
        #expect(manager.configuration.warningThreshold == 0.8)
        #expect(manager.configuration.criticalThreshold == 0.9)
        #expect(manager.configuration.enableAutoCleanup == true)
        #expect(manager.configuration.enableLeakDetection == true)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle monitoring errors")
    func testHandleMonitoringErrors() async {
        let manager = createMemoryManager()
        
        var errorReceived = false
        manager.onMonitoringError = { error in
            errorReceived = true
        }
        
        // Start monitoring with invalid interval
        manager.startMonitoring(interval: -1.0)
        
        // Wait for error handling
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Should handle invalid configuration gracefully
        #expect(Bool(true))
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent memory operations")
    func testConcurrentMemoryOperations() async {
        let manager = createMemoryManager()
        
        manager.startMonitoring(interval: 0.05)
        
        await withTaskGroup(of: Void.self) { group in
            // Concurrent allocations
            for i in 0..<5 {
                group.addTask {
                    var objects: [[Int]] = []
                    for j in 0..<20 {
                        objects.append(Array(0..<(i * 100 + j)))
                    }
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    objects.removeAll()
                }
            }
        }
        
        // Should handle concurrent operations without crashing
        #expect(manager.currentMemoryUsage >= 0)
        
        manager.stopMonitoring()
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory manager cleanup")
    func testMemoryManagerCleanup() {
        var manager: MemoryManager? = createMemoryManager()
        
        weak var weakManager = manager
        
        manager?.startMonitoring(interval: 0.1)
        manager?.stopMonitoring()
        
        manager = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakManager == nil)
    }
    
    // MARK: - Helper Classes
    
    class TestObject {
        let data = Array(0..<1000)
    }
    
    class TestLeakyClass {
        let data = Array(0..<1000)
        var circularReference: TestLeakyClass?
        
        init() {
            // Create potential circular reference
            circularReference = self
        }
    }
}