import Foundation

/// Performance benchmarking and profiling system
/// 需求: 14.1 - 编写内存泄漏检测和性能基准测试
public final class PerformanceBenchmark: @unchecked Sendable {
    
    // MARK: - Benchmark Result
    
    public struct BenchmarkResult: Sendable, Codable {
        public let name: String
        public let executionTime: TimeInterval
        public let iterations: Int
        public let averageTime: TimeInterval
        public let minTime: TimeInterval
        public let maxTime: TimeInterval
        public let standardDeviation: Double
        public let timestamp: Date
        
        public var description: String {
            return """
            Benchmark: \(name)
            - Execution Time: \(String(format: "%.4f", executionTime))s
            - Iterations: \(iterations)
            - Average: \(String(format: "%.4f", averageTime))s
            - Min: \(String(format: "%.4f", minTime))s
            - Max: \(String(format: "%.4f", maxTime))s
            - Std Dev: \(String(format: "%.4f", standardDeviation))s
            """
        }
    }
    
    // MARK: - Properties
    
    private var benchmarkResults: [String: [BenchmarkResult]] = [:]
    private let benchmarkQueue = DispatchQueue(label: "com.realtimekit.benchmark", qos: .userInitiated)
    
    // MARK: - Singleton
    
    public static let shared = PerformanceBenchmark()
    
    private init() {}
    
    // MARK: - Benchmarking Methods
    
    /// Measure execution time of a synchronous operation
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of iterations to run
    ///   - operation: Operation to benchmark
    /// - Returns: Benchmark result
    @discardableResult
    public func measure<T>(
        name: String,
        iterations: Int = 1,
        operation: () throws -> T
    ) rethrows -> BenchmarkResult {
        var times: [TimeInterval] = []
        var results: [T] = []
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            let iterationStart = CFAbsoluteTimeGetCurrent()
            let result = try operation()
            let iterationEnd = CFAbsoluteTimeGetCurrent()
            
            times.append(iterationEnd - iterationStart)
            results.append(result)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        let result = createBenchmarkResult(
            name: name,
            totalTime: totalTime,
            times: times,
            iterations: iterations
        )
        
        storeBenchmarkResult(result)
        return result
    }
    
    /// Measure execution time of an asynchronous operation
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of iterations to run
    ///   - operation: Async operation to benchmark
    /// - Returns: Benchmark result
    @discardableResult
    public func measureAsync<T>(
        name: String,
        iterations: Int = 1,
        operation: () async throws -> T
    ) async rethrows -> BenchmarkResult {
        var times: [TimeInterval] = []
        var results: [T] = []
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            let iterationStart = CFAbsoluteTimeGetCurrent()
            let result = try await operation()
            let iterationEnd = CFAbsoluteTimeGetCurrent()
            
            times.append(iterationEnd - iterationStart)
            results.append(result)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        let result = createBenchmarkResult(
            name: name,
            totalTime: totalTime,
            times: times,
            iterations: iterations
        )
        
        storeBenchmarkResult(result)
        return result
    }
    
    /// Measure memory allocation during operation
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - operation: Operation to measure
    /// - Returns: Memory allocation info
    public func measureMemoryAllocation<T>(
        name: String,
        operation: () throws -> T
    ) rethrows -> MemoryAllocationResult<T> {
        let memoryBefore = MemoryPressureMonitor.shared.getMemoryUsage()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = try operation()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let memoryAfter = MemoryPressureMonitor.shared.getMemoryUsage()
        
        let allocationResult = MemoryAllocationResult(
            name: name,
            result: result,
            executionTime: endTime - startTime,
            memoryBefore: memoryBefore.usedMemory,
            memoryAfter: memoryAfter.usedMemory,
            memoryDelta: memoryAfter.usedMemory - memoryBefore.usedMemory,
            timestamp: Date()
        )
        
        return allocationResult
    }
    
    // MARK: - Specialized Benchmarks
    
    /// Benchmark localization string retrieval performance
    /// - Parameters:
    ///   - keys: Array of localization keys to test
    ///   - languages: Array of languages to test
    ///   - iterations: Number of iterations per key/language combination
    /// - Returns: Localization benchmark results
    @MainActor
    public func benchmarkLocalization(
        keys: [String],
        languages: [SupportedLanguage] = SupportedLanguage.allCases,
        iterations: Int = 100
    ) -> LocalizationBenchmarkResult {
        let localizationManager = LocalizationManager.shared
        var results: [String: BenchmarkResult] = [:]
        
        // Benchmark cached vs uncached retrieval
        for language in languages {
            let languageName = language.displayName
            
            // Benchmark uncached retrieval
            localizationManager.clearStringCache()
            let uncachedResult = measure(
                name: "Localization_Uncached_\(languageName)",
                iterations: iterations
            ) {
                for key in keys {
                    _ = localizationManager.localizedString(for: key, language: language)
                }
            }
            results["uncached_\(languageName)"] = uncachedResult
            
            // Benchmark cached retrieval
            let cachedResult = measure(
                name: "Localization_Cached_\(languageName)",
                iterations: iterations
            ) {
                for key in keys {
                    _ = localizationManager.cachedLocalizedString(for: key, language: language)
                }
            }
            results["cached_\(languageName)"] = cachedResult
        }
        
        return LocalizationBenchmarkResult(
            keys: keys,
            languages: languages,
            iterations: iterations,
            results: results,
            timestamp: Date()
        )
    }
    
    /// Benchmark object pool performance
    /// - Parameters:
    ///   - poolSize: Size of the object pool
    ///   - iterations: Number of get/return operations
    /// - Returns: Object pool benchmark result
    public func benchmarkObjectPool(
        poolSize: Int = 50,
        iterations: Int = 1000
    ) -> ObjectPoolBenchmarkResult {
        // Use DataBufferPool for benchmarking since NSMutableData is not Sendable
        let dataBufferPool = DataBufferPool.shared
        
        // Benchmark pool operations
        let poolResult = measure(
            name: "ObjectPool_Operations",
            iterations: 1
        ) {
            var buffers: [Data] = []
            
            // Get objects from pool
            for _ in 0..<iterations {
                buffers.append(dataBufferPool.getBuffer())
            }
            
            // Return objects to pool
            for buffer in buffers {
                dataBufferPool.returnBuffer(buffer)
            }
        }
        
        // Benchmark direct allocation (for comparison)
        let directResult = measure(
            name: "Direct_Allocation",
            iterations: 1
        ) {
            var buffers: [Data] = []
            
            for _ in 0..<iterations {
                var data = Data(capacity: 1024)
                data.removeAll(keepingCapacity: true) // Simulate reset
                buffers.append(data)
            }
        }
        
        let poolStats = dataBufferPool.getStatistics()
        
        return ObjectPoolBenchmarkResult(
            poolSize: poolSize,
            iterations: iterations,
            poolResult: poolResult,
            directResult: directResult,
            poolStatistics: poolStats,
            timestamp: Date()
        )
    }
    
    /// Benchmark weak reference manager performance
    /// - Parameters:
    ///   - objectCount: Number of objects to manage
    ///   - iterations: Number of operations
    /// - Returns: Weak reference benchmark result
    public func benchmarkWeakReferences(
        objectCount: Int = 1000,
        iterations: Int = 100
    ) -> WeakReferenceBenchmarkResult {
        let weakRefManager = WeakReferenceManager.shared
        
        // Create test objects
        var testObjects: [NSObject] = []
        for _ in 0..<objectCount {
            testObjects.append(NSObject())
        }
        
        // Benchmark storing references
        let storeResult = measure(
            name: "WeakReference_Store",
            iterations: iterations
        ) {
            for (index, object) in testObjects.enumerated() {
                weakRefManager.store(object, forKey: "test_\(index)")
            }
        }
        
        // Benchmark retrieving references
        let retrieveResult = measure(
            name: "WeakReference_Retrieve",
            iterations: iterations
        ) {
            for index in 0..<objectCount {
                _ = weakRefManager.retrieve(forKey: "test_\(index)", as: NSObject.self)
            }
        }
        
        // Benchmark cleanup
        testObjects.removeAll() // Release objects
        
        let cleanupResult = measure(
            name: "WeakReference_Cleanup",
            iterations: 1
        ) {
            weakRefManager.performCleanup()
        }
        
        let stats = weakRefManager.getStatistics()
        
        return WeakReferenceBenchmarkResult(
            objectCount: objectCount,
            iterations: iterations,
            storeResult: storeResult,
            retrieveResult: retrieveResult,
            cleanupResult: cleanupResult,
            statistics: stats,
            timestamp: Date()
        )
    }
    
    // MARK: - Result Management
    
    /// Get all benchmark results for a specific name
    /// - Parameter name: Benchmark name
    /// - Returns: Array of benchmark results
    public func getResults(for name: String) -> [BenchmarkResult] {
        return benchmarkQueue.sync {
            return benchmarkResults[name] ?? []
        }
    }
    
    /// Get all benchmark results
    /// - Returns: Dictionary of all benchmark results
    public func getAllResults() -> [String: [BenchmarkResult]] {
        return benchmarkQueue.sync {
            return benchmarkResults
        }
    }
    
    /// Clear all benchmark results
    public func clearResults() {
        benchmarkQueue.async(flags: .barrier) { [weak self] in
            self?.benchmarkResults.removeAll()
        }
    }
    
    /// Clear results for a specific benchmark
    /// - Parameter name: Benchmark name
    public func clearResults(for name: String) {
        benchmarkQueue.async(flags: .barrier) { [weak self] in
            self?.benchmarkResults.removeValue(forKey: name)
        }
    }
    
    /// Export benchmark results to JSON
    /// - Returns: JSON data containing all results
    public func exportResults() throws -> Data {
        let results = getAllResults()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(results)
    }
    
    // MARK: - Private Methods
    
    private func createBenchmarkResult(
        name: String,
        totalTime: TimeInterval,
        times: [TimeInterval],
        iterations: Int
    ) -> BenchmarkResult {
        let averageTime = times.reduce(0, +) / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        
        // Calculate standard deviation
        let variance = times.reduce(0) { sum, time in
            let diff = time - averageTime
            return sum + (diff * diff)
        } / Double(times.count)
        let standardDeviation = sqrt(variance)
        
        return BenchmarkResult(
            name: name,
            executionTime: totalTime,
            iterations: iterations,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime,
            standardDeviation: standardDeviation,
            timestamp: Date()
        )
    }
    
    private func storeBenchmarkResult(_ result: BenchmarkResult) {
        benchmarkQueue.async(flags: .barrier) { [weak self] in
            if self?.benchmarkResults[result.name] == nil {
                self?.benchmarkResults[result.name] = []
            }
            self?.benchmarkResults[result.name]?.append(result)
        }
    }
}

// MARK: - Specialized Benchmark Results

/// Memory allocation measurement result
public struct MemoryAllocationResult<T> {
    public let name: String
    public let result: T
    public let executionTime: TimeInterval
    public let memoryBefore: Int
    public let memoryAfter: Int
    public let memoryDelta: Int
    public let timestamp: Date
    
    public var memoryDeltaMB: Double {
        return Double(memoryDelta) / (1024 * 1024)
    }
    
    public var description: String {
        return """
        Memory Allocation: \(name)
        - Execution Time: \(String(format: "%.4f", executionTime))s
        - Memory Before: \(memoryBefore) bytes
        - Memory After: \(memoryAfter) bytes
        - Memory Delta: \(memoryDelta) bytes (\(String(format: "%.2f", memoryDeltaMB)) MB)
        """
    }
}

/// Localization benchmark result
public struct LocalizationBenchmarkResult {
    public let keys: [String]
    public let languages: [SupportedLanguage]
    public let iterations: Int
    public let results: [String: PerformanceBenchmark.BenchmarkResult]
    public let timestamp: Date
    
    public var description: String {
        let resultSummary = results.map { key, result in
            "\(key): \(String(format: "%.4f", result.averageTime))s avg"
        }.joined(separator: "\n")
        
        return """
        Localization Benchmark:
        - Keys: \(keys.count)
        - Languages: \(languages.count)
        - Iterations: \(iterations)
        Results:
        \(resultSummary)
        """
    }
}

/// Object pool benchmark result
public struct ObjectPoolBenchmarkResult {
    public let poolSize: Int
    public let iterations: Int
    public let poolResult: PerformanceBenchmark.BenchmarkResult
    public let directResult: PerformanceBenchmark.BenchmarkResult
    public let poolStatistics: ObjectPoolStatistics
    public let timestamp: Date
    
    public var performanceImprovement: Double {
        return (directResult.averageTime - poolResult.averageTime) / directResult.averageTime
    }
    
    public var description: String {
        return """
        Object Pool Benchmark:
        - Pool Size: \(poolSize)
        - Iterations: \(iterations)
        - Pool Time: \(String(format: "%.4f", poolResult.averageTime))s
        - Direct Time: \(String(format: "%.4f", directResult.averageTime))s
        - Improvement: \(String(format: "%.2f%%", performanceImprovement * 100))
        - Pool Stats: \(poolStatistics.reuseRate * 100)% reuse rate
        """
    }
}

/// Weak reference benchmark result
public struct WeakReferenceBenchmarkResult {
    public let objectCount: Int
    public let iterations: Int
    public let storeResult: PerformanceBenchmark.BenchmarkResult
    public let retrieveResult: PerformanceBenchmark.BenchmarkResult
    public let cleanupResult: PerformanceBenchmark.BenchmarkResult
    public let statistics: WeakReferenceStatistics
    public let timestamp: Date
    
    public var description: String {
        return """
        Weak Reference Benchmark:
        - Object Count: \(objectCount)
        - Iterations: \(iterations)
        - Store Time: \(String(format: "%.4f", storeResult.averageTime))s
        - Retrieve Time: \(String(format: "%.4f", retrieveResult.averageTime))s
        - Cleanup Time: \(String(format: "%.4f", cleanupResult.averageTime))s
        - Final Stats: \(statistics.validReferences)/\(statistics.totalReferences) valid
        """
    }
}
