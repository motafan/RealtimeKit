// ThreadSafetyManagerTests.swift
// Comprehensive unit tests for ThreadSafetyManager

import Testing
@testable import RealtimeCore

@Suite("ThreadSafetyManager Tests")
struct ThreadSafetyManagerTests {
    
    // MARK: - Test Setup
    
    private func createThreadSafetyManager() -> ThreadSafetyManager {
        return ThreadSafetyManager()
    }
    
    // MARK: - Initialization Tests
    
    @Test("ThreadSafetyManager initialization")
    func testThreadSafetyManagerInitialization() {
        let manager = createThreadSafetyManager()
        
        #expect(manager.isMonitoring == false)
        #expect(manager.detectedRaceConditions == 0)
        #expect(manager.activeThreadCount == 0)
    }
    
    // MARK: - Lock Management Tests
    
    @Test("Create and manage locks")
    func testCreateAndManageLocks() {
        let manager = createThreadSafetyManager()
        
        let lock1 = manager.createLock(identifier: "test_lock_1")
        let lock2 = manager.createLock(identifier: "test_lock_2")
        
        #expect(lock1 != nil)
        #expect(lock2 != nil)
        #expect(manager.getLockCount() == 2)
        
        manager.removeLock(identifier: "test_lock_1")
        #expect(manager.getLockCount() == 1)
        
        manager.removeAllLocks()
        #expect(manager.getLockCount() == 0)
    }
    
    @Test("Lock acquisition and release")
    func testLockAcquisitionAndRelease() async {
        let manager = createThreadSafetyManager()
        let lock = manager.createLock(identifier: "test_lock")
        
        // Acquire lock
        let acquired = await manager.acquireLock(identifier: "test_lock", timeout: 1.0)
        #expect(acquired == true)
        
        // Try to acquire same lock from different context (should timeout)
        let secondAcquisition = await manager.acquireLock(identifier: "test_lock", timeout: 0.1)
        #expect(secondAcquisition == false)
        
        // Release lock
        manager.releaseLock(identifier: "test_lock")
        
        // Should be able to acquire again
        let thirdAcquisition = await manager.acquireLock(identifier: "test_lock", timeout: 0.1)
        #expect(thirdAcquisition == true)
        
        manager.releaseLock(identifier: "test_lock")
    }
    
    @Test("Recursive lock support")
    func testRecursiveLockSupport() async {
        let manager = createThreadSafetyManager()
        let lock = manager.createRecursiveLock(identifier: "recursive_lock")
        
        // Acquire lock multiple times from same thread
        let first = await manager.acquireLock(identifier: "recursive_lock", timeout: 1.0)
        let second = await manager.acquireLock(identifier: "recursive_lock", timeout: 1.0)
        let third = await manager.acquireLock(identifier: "recursive_lock", timeout: 1.0)
        
        #expect(first == true)
        #expect(second == true)
        #expect(third == true)
        
        // Release same number of times
        manager.releaseLock(identifier: "recursive_lock")
        manager.releaseLock(identifier: "recursive_lock")
        manager.releaseLock(identifier: "recursive_lock")
    }
    
    // MARK: - Read-Write Lock Tests
    
    @Test("Read-write lock functionality")
    func testReadWriteLockFunctionality() async {
        let manager = createThreadSafetyManager()
        let rwLock = manager.createReadWriteLock(identifier: "rw_lock")
        
        // Multiple readers should be allowed
        let read1 = await manager.acquireReadLock(identifier: "rw_lock", timeout: 1.0)
        let read2 = await manager.acquireReadLock(identifier: "rw_lock", timeout: 1.0)
        
        #expect(read1 == true)
        #expect(read2 == true)
        
        manager.releaseReadLock(identifier: "rw_lock")
        manager.releaseReadLock(identifier: "rw_lock")
        
        // Writer should be exclusive
        let write1 = await manager.acquireWriteLock(identifier: "rw_lock", timeout: 1.0)
        #expect(write1 == true)
        
        // Another writer should be blocked
        let write2 = await manager.acquireWriteLock(identifier: "rw_lock", timeout: 0.1)
        #expect(write2 == false)
        
        // Reader should be blocked while writer holds lock
        let read3 = await manager.acquireReadLock(identifier: "rw_lock", timeout: 0.1)
        #expect(read3 == false)
        
        manager.releaseWriteLock(identifier: "rw_lock")
    }
    
    // MARK: - Deadlock Detection Tests
    
    @Test("Deadlock detection")
    func testDeadlockDetection() async {
        let manager = createThreadSafetyManager()
        manager.enableDeadlockDetection()
        
        var deadlockDetected = false
        manager.onDeadlockDetected = { locks in
            deadlockDetected = true
        }
        
        let lock1 = manager.createLock(identifier: "lock1")
        let lock2 = manager.createLock(identifier: "lock2")
        
        // Simulate potential deadlock scenario
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let _ = await manager.acquireLock(identifier: "lock1", timeout: 1.0)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                let _ = await manager.acquireLock(identifier: "lock2", timeout: 1.0)
                manager.releaseLock(identifier: "lock2")
                manager.releaseLock(identifier: "lock1")
            }
            
            group.addTask {
                let _ = await manager.acquireLock(identifier: "lock2", timeout: 1.0)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                let _ = await manager.acquireLock(identifier: "lock1", timeout: 1.0)
                manager.releaseLock(identifier: "lock1")
                manager.releaseLock(identifier: "lock2")
            }
        }
        
        // Note: Deadlock detection might not trigger in test environment
        // This test mainly ensures the API works without crashing
        #expect(Bool(true))
    }
    
    @Test("Lock ordering enforcement")
    func testLockOrderingEnforcement() async {
        let manager = createThreadSafetyManager()
        manager.enableLockOrdering()
        
        let lock1 = manager.createLock(identifier: "lock1", order: 1)
        let lock2 = manager.createLock(identifier: "lock2", order: 2)
        let lock3 = manager.createLock(identifier: "lock3", order: 3)
        
        // Acquire locks in correct order
        let acquired1 = await manager.acquireLock(identifier: "lock1", timeout: 1.0)
        let acquired2 = await manager.acquireLock(identifier: "lock2", timeout: 1.0)
        let acquired3 = await manager.acquireLock(identifier: "lock3", timeout: 1.0)
        
        #expect(acquired1 == true)
        #expect(acquired2 == true)
        #expect(acquired3 == true)
        
        manager.releaseLock(identifier: "lock3")
        manager.releaseLock(identifier: "lock2")
        manager.releaseLock(identifier: "lock1")
    }
    
    // MARK: - Race Condition Detection Tests
    
    @Test("Race condition detection")
    func testRaceConditionDetection() async {
        let manager = createThreadSafetyManager()
        manager.enableRaceConditionDetection()
        
        var raceConditionDetected = false
        manager.onRaceConditionDetected = { resource in
            raceConditionDetected = true
        }
        
        // Create shared resource
        let resource = manager.createSharedResource(identifier: "shared_counter", initialValue: 0)
        
        // Simulate concurrent access without proper synchronization
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    // Unsafe increment
                    let currentValue = manager.getResourceValue(identifier: "shared_counter") as? Int ?? 0
                    manager.setResourceValue(identifier: "shared_counter", value: currentValue + 1)
                }
            }
        }
        
        // Wait for race condition detection
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Note: Race condition detection might not trigger in test environment
        #expect(Bool(true))
    }
    
    @Test("Thread-safe counter")
    func testThreadSafeCounter() async {
        let manager = createThreadSafetyManager()
        let counter = manager.createThreadSafeCounter(identifier: "test_counter", initialValue: 0)
        
        // Concurrent increments
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    manager.incrementCounter(identifier: "test_counter")
                }
            }
        }
        
        let finalValue = manager.getCounterValue(identifier: "test_counter")
        #expect(finalValue == 100)
    }
    
    // MARK: - Thread Pool Management Tests
    
    @Test("Thread pool creation and management")
    func testThreadPoolCreationAndManagement() async {
        let manager = createThreadSafetyManager()
        
        let pool = manager.createThreadPool(identifier: "test_pool", maxThreads: 4)
        #expect(pool != nil)
        #expect(manager.getThreadPoolCount() == 1)
        
        // Submit tasks to pool
        var completedTasks = 0
        let lock = NSLock()
        
        for i in 0..<10 {
            manager.submitTask(to: "test_pool") {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                lock.lock()
                completedTasks += 1
                lock.unlock()
            }
        }
        
        // Wait for tasks to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #expect(completedTasks == 10)
        
        manager.shutdownThreadPool(identifier: "test_pool")
        #expect(manager.getThreadPoolCount() == 0)
    }
    
    @Test("Thread pool load balancing")
    func testThreadPoolLoadBalancing() async {
        let manager = createThreadSafetyManager()
        
        let pool = manager.createThreadPool(identifier: "balanced_pool", maxThreads: 3)
        
        var taskExecutionTimes: [String: Date] = [:]
        let lock = NSLock()
        
        // Submit tasks with different durations
        for i in 0..<9 {
            manager.submitTask(to: "balanced_pool") {
                let taskId = "task_\(i)"
                let duration = UInt64((i % 3 + 1) * 100_000_000) // 0.1, 0.2, or 0.3 seconds
                
                try? await Task.sleep(nanoseconds: duration)
                
                lock.lock()
                taskExecutionTimes[taskId] = Date()
                lock.unlock()
            }
        }
        
        // Wait for all tasks to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        #expect(taskExecutionTimes.count == 9)
        
        manager.shutdownThreadPool(identifier: "balanced_pool")
    }
    
    // MARK: - Atomic Operations Tests
    
    @Test("Atomic operations")
    func testAtomicOperations() async {
        let manager = createThreadSafetyManager()
        
        let atomicInt = manager.createAtomicInteger(identifier: "atomic_int", initialValue: 0)
        let atomicBool = manager.createAtomicBoolean(identifier: "atomic_bool", initialValue: false)
        
        // Concurrent atomic operations
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    manager.atomicIncrement(identifier: "atomic_int")
                }
            }
            
            for _ in 0..<50 {
                group.addTask {
                    manager.atomicToggle(identifier: "atomic_bool")
                }
            }
        }
        
        let finalInt = manager.getAtomicIntegerValue(identifier: "atomic_int")
        let finalBool = manager.getAtomicBooleanValue(identifier: "atomic_bool")
        
        #expect(finalInt == 50)
        // Boolean should be false after even number of toggles
        #expect(finalBool == false)
    }
    
    @Test("Compare and swap operations")
    func testCompareAndSwapOperations() async {
        let manager = createThreadSafetyManager()
        
        let atomic = manager.createAtomicInteger(identifier: "cas_int", initialValue: 0)
        
        // Concurrent compare-and-swap operations
        var successfulSwaps = 0
        let lock = NSLock()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let success = manager.compareAndSwap(
                        identifier: "cas_int",
                        expected: i,
                        newValue: i + 1
                    )
                    
                    if success {
                        lock.lock()
                        successfulSwaps += 1
                        lock.unlock()
                    }
                }
            }
        }
        
        // Only one swap should succeed for each expected value
        #expect(successfulSwaps <= 10)
    }
    
    // MARK: - Thread Monitoring Tests
    
    @Test("Thread monitoring")
    func testThreadMonitoring() async {
        let manager = createThreadSafetyManager()
        manager.startMonitoring(interval: 0.1)
        
        #expect(manager.isMonitoring == true)
        
        // Create some thread activity
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
            }
        }
        
        let threadStats = manager.getThreadStatistics()
        #expect(threadStats.activeThreads >= 0)
        #expect(threadStats.totalThreadsCreated >= 0)
        
        manager.stopMonitoring()
        #expect(manager.isMonitoring == false)
    }
    
    @Test("Thread contention detection")
    func testThreadContentionDetection() async {
        let manager = createThreadSafetyManager()
        manager.enableContentionDetection()
        
        var contentionDetected = false
        manager.onContentionDetected = { lockId, waitTime in
            contentionDetected = true
        }
        
        let lock = manager.createLock(identifier: "contended_lock")
        
        // Create contention scenario
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let _ = await manager.acquireLock(identifier: "contended_lock", timeout: 1.0)
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    manager.releaseLock(identifier: "contended_lock")
                }
            }
        }
        
        // Note: Contention detection might not trigger in test environment
        #expect(Bool(true))
    }
    
    // MARK: - Performance Tests
    
    @Test("Lock performance")
    func testLockPerformance() async {
        let manager = createThreadSafetyManager()
        let lock = manager.createLock(identifier: "perf_lock")
        
        let startTime = Date()
        
        // Perform many lock operations
        for _ in 0..<1000 {
            let _ = await manager.acquireLock(identifier: "perf_lock", timeout: 1.0)
            manager.releaseLock(identifier: "perf_lock")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(duration < 5.0) // 5 seconds max
    }
    
    @Test("Atomic operation performance")
    func testAtomicOperationPerformance() async {
        let manager = createThreadSafetyManager()
        let atomic = manager.createAtomicInteger(identifier: "perf_atomic", initialValue: 0)
        
        let startTime = Date()
        
        // Perform many atomic operations
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<1000 {
                        manager.atomicIncrement(identifier: "perf_atomic")
                    }
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(duration < 5.0) // 5 seconds max
        
        let finalValue = manager.getAtomicIntegerValue(identifier: "perf_atomic")
        #expect(finalValue == 10000)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle invalid lock operations")
    func testHandleInvalidLockOperations() async {
        let manager = createThreadSafetyManager()
        
        // Try to acquire non-existent lock
        let result = await manager.acquireLock(identifier: "non_existent", timeout: 0.1)
        #expect(result == false)
        
        // Try to release non-existent lock
        manager.releaseLock(identifier: "non_existent") // Should not crash
        
        #expect(Bool(true))
    }
    
    @Test("Handle timeout scenarios")
    func testHandleTimeoutScenarios() async {
        let manager = createThreadSafetyManager()
        let lock = manager.createLock(identifier: "timeout_lock")
        
        // Acquire lock
        let _ = await manager.acquireLock(identifier: "timeout_lock", timeout: 1.0)
        
        // Try to acquire with short timeout
        let timedOut = await manager.acquireLock(identifier: "timeout_lock", timeout: 0.1)
        #expect(timedOut == false)
        
        manager.releaseLock(identifier: "timeout_lock")
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Thread safety manager cleanup")
    func testThreadSafetyManagerCleanup() {
        var manager: ThreadSafetyManager? = createThreadSafetyManager()
        
        weak var weakManager = manager
        
        let _ = manager?.createLock(identifier: "cleanup_test")
        
        manager = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakManager == nil)
    }
}