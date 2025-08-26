import Foundation

/// Thread safety utilities and synchronization primitives
/// 需求: 14.2 - 添加线程安全保护和异步处理优化
public class ThreadSafetyManager {
    
    // MARK: - Thread-Safe Collections
    
    /// Thread-safe array wrapper
    public final class ThreadSafeArray<T: Sendable>: @unchecked Sendable {
        private var array: [T] = []
        private let queue = DispatchQueue(label: "com.realtimekit.threadsafe.array", attributes: .concurrent)
        
        public init() {}
        
        public init(_ array: [T]) {
            self.array = array
        }
        
        /// Append element to array
        public func append(_ element: T) {
            queue.async(flags: .barrier) { [weak self, element] in
                self?.array.append(element)
            }
        }
        
        /// Append multiple elements to array
        public func append(contentsOf elements: [T]) {
            queue.async(flags: .barrier) { [weak self, elements] in
                self?.array.append(contentsOf: elements)
            }
        }
        
        /// Remove element at index
        @discardableResult
        public func remove(at index: Int) -> T? {
            return queue.sync(flags: .barrier) { [weak self] in
                guard let self = self, index < self.array.count else { return nil }
                return self.array.remove(at: index)
            }
        }
        
        /// Remove all elements
        public func removeAll() {
            queue.async(flags: .barrier) { [weak self] in
                self?.array.removeAll()
            }
        }
        
        /// Get element at index
        public subscript(index: Int) -> T? {
            return queue.sync { [weak self] in
                guard let self = self, index < self.array.count else { return nil }
                return self.array[index]
            }
        }
        
        /// Get count of elements
        public var count: Int {
            return queue.sync { [weak self] in
                return self?.array.count ?? 0
            }
        }
        
        /// Check if array is empty
        public var isEmpty: Bool {
            return count == 0
        }
        
        /// Get all elements (copy)
        public var allElements: [T] {
            return queue.sync { [weak self] in
                return self?.array ?? []
            }
        }
        
        /// Perform operation on all elements
        public func forEach(_ operation: @escaping @Sendable (T) -> Void) {
            queue.async { [weak self] in
                let elements = self?.array ?? []
                elements.forEach(operation)
            }
        }
        
        /// Filter elements
        public func filter(_ predicate: @escaping (T) -> Bool) -> [T] {
            return queue.sync { [weak self] in
                return self?.array.filter(predicate) ?? []
            }
        }
        
        /// Map elements
        public func map<U>(_ transform: @escaping (T) -> U) -> [U] {
            return queue.sync { [weak self] in
                return self?.array.map(transform) ?? []
            }
        }
    }
    
    /// Thread-safe dictionary wrapper
    public final class ThreadSafeDictionary<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
        private var dictionary: [Key: Value] = [:]
        private let queue = DispatchQueue(label: "com.realtimekit.threadsafe.dictionary", attributes: .concurrent)
        
        public init() {}
        
        public init(_ dictionary: [Key: Value]) {
            self.dictionary = dictionary
        }
        
        /// Set value for key
        public func setValue(_ value: Value, forKey key: Key) {
            queue.async(flags: .barrier) { [weak self, key, value] in
                self?.dictionary[key] = value
            }
        }
        
        /// Get value for key
        public func getValue(forKey key: Key) -> Value? {
            return queue.sync { [weak self] in
                return self?.dictionary[key]
            }
        }
        
        /// Remove value for key
        @discardableResult
        public func removeValue(forKey key: Key) -> Value? {
            return queue.sync(flags: .barrier) { [weak self] in
                return self?.dictionary.removeValue(forKey: key)
            }
        }
        
        /// Remove all values
        public func removeAll() {
            queue.async(flags: .barrier) { [weak self] in
                self?.dictionary.removeAll()
            }
        }
        
        /// Subscript access
        public subscript(key: Key) -> Value? {
            get {
                return getValue(forKey: key)
            }
            set {
                if let value = newValue {
                    setValue(value, forKey: key)
                } else {
                    removeValue(forKey: key)
                }
            }
        }
        
        /// Get count of key-value pairs
        public var count: Int {
            return queue.sync { [weak self] in
                return self?.dictionary.count ?? 0
            }
        }
        
        /// Check if dictionary is empty
        public var isEmpty: Bool {
            return count == 0
        }
        
        /// Get all keys
        public var allKeys: [Key] {
            return queue.sync { [weak self] in
                return self?.dictionary.keys.map { $0 } ?? []
            }
        }
        
        /// Get all values
        public var allValues: [Value] {
            return queue.sync { [weak self] in
                return self?.dictionary.values.map { $0 } ?? []
            }
        }
        
        /// Get all key-value pairs
        public var allPairs: [(Key, Value)] {
            return queue.sync { [weak self] in
                return self?.dictionary.map { ($0.key, $0.value) } ?? []
            }
        }
        
        /// Perform operation on all key-value pairs
        public func forEach(_ operation: @escaping @Sendable (Key, Value) -> Void) {
            queue.async { [weak self] in
                let pairs = self?.dictionary.map { ($0.key, $0.value) } ?? []
                pairs.forEach { operation($0.0, $0.1) }
            }
        }
    }
    
    // MARK: - Atomic Operations
    
    /// Atomic counter
    public final class AtomicCounter: @unchecked Sendable {
        private var _value: Int = 0
        private let queue = DispatchQueue(label: "com.realtimekit.atomic.counter")
        
        public init(initialValue: Int = 0) {
            _value = initialValue
        }
        
        /// Get current value
        public var value: Int {
            return queue.sync { _value }
        }
        
        /// Increment and return new value
        @discardableResult
        public func increment() -> Int {
            return queue.sync(flags: .barrier) {
                _value += 1
                return _value
            }
        }
        
        /// Decrement and return new value
        @discardableResult
        public func decrement() -> Int {
            return queue.sync(flags: .barrier) {
                _value -= 1
                return _value
            }
        }
        
        /// Add value and return new value
        @discardableResult
        public func add(_ value: Int) -> Int {
            return queue.sync(flags: .barrier) {
                _value += value
                return _value
            }
        }
        
        /// Set value and return old value
        @discardableResult
        public func set(_ newValue: Int) -> Int {
            return queue.sync(flags: .barrier) {
                let oldValue = _value
                _value = newValue
                return oldValue
            }
        }
        
        /// Compare and swap
        public func compareAndSwap(expected: Int, newValue: Int) -> Bool {
            return queue.sync(flags: .barrier) {
                if _value == expected {
                    _value = newValue
                    return true
                }
                return false
            }
        }
        
        /// Reset to zero
        public func reset() {
            queue.async(flags: .barrier) { [weak self] in
                self?._value = 0
            }
        }
    }
    
    /// Atomic boolean
    public final class AtomicBool: @unchecked Sendable {
        private var _value: Bool = false
        private let queue = DispatchQueue(label: "com.realtimekit.atomic.bool")
        
        public init(initialValue: Bool = false) {
            _value = initialValue
        }
        
        /// Get current value
        public var value: Bool {
            return queue.sync { _value }
        }
        
        /// Set value and return old value
        @discardableResult
        public func set(_ newValue: Bool) -> Bool {
            return queue.sync(flags: .barrier) {
                let oldValue = _value
                _value = newValue
                return oldValue
            }
        }
        
        /// Toggle value and return new value
        @discardableResult
        public func toggle() -> Bool {
            return queue.sync(flags: .barrier) {
                _value.toggle()
                return _value
            }
        }
        
        /// Compare and swap
        public func compareAndSwap(expected: Bool, newValue: Bool) -> Bool {
            return queue.sync(flags: .barrier) {
                if _value == expected {
                    _value = newValue
                    return true
                }
                return false
            }
        }
    }
    
    // MARK: - Read-Write Lock
    
    /// Read-write lock for protecting shared resources
    public final class ReadWriteLock: @unchecked Sendable {
        private let queue = DispatchQueue(label: "com.realtimekit.readwrite.lock", attributes: .concurrent)
        
        /// Perform read operation
        public func read<T>(_ operation: () throws -> T) rethrows -> T {
            return try queue.sync {
                return try operation()
            }
        }
        
        /// Perform write operation
        public func write<T>(_ operation: () throws -> T) rethrows -> T {
            return try queue.sync(flags: .barrier) {
                return try operation()
            }
        }
        
        /// Perform async read operation
        public func readAsync<T>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
            return try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    Task {
                        do {
                            let result = try await operation()
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
        
        /// Perform async write operation
        public func writeAsync<T>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
            return try await withCheckedThrowingContinuation { continuation in
                queue.async(flags: .barrier) {
                    Task {
                        do {
                            let result = try await operation()
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Semaphore Utilities
    
    /// Semaphore-based resource limiter
    public final class ResourceLimiter: @unchecked Sendable {
        private let semaphore: DispatchSemaphore
        private let maxConcurrency: Int
        private let atomicActiveCount = AtomicCounter()
        
        public init(maxConcurrency: Int) {
            self.maxConcurrency = maxConcurrency
            self.semaphore = DispatchSemaphore(value: maxConcurrency)
        }
        
        /// Execute operation with resource limiting
        public func execute<T>(_ operation: () throws -> T) rethrows -> T {
            semaphore.wait()
            atomicActiveCount.increment()
            
            defer {
                atomicActiveCount.decrement()
                semaphore.signal()
            }
            
            return try operation()
        }
        
        /// Execute async operation with resource limiting
        public func executeAsync<T>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
            await withCheckedContinuation { continuation in
                semaphore.wait()
                continuation.resume()
            }
            atomicActiveCount.increment()
            
            defer {
                atomicActiveCount.decrement()
                semaphore.signal()
            }
            
            return try await operation()
        }
        
        /// Get current active operation count
        public var activeCount: Int {
            return atomicActiveCount.value
        }
        
        /// Get available resource count
        public var availableCount: Int {
            return maxConcurrency - activeCount
        }
    }
    
    // MARK: - Thread Pool
    
    /// Custom thread pool for CPU-intensive operations
    public final class ThreadPool: @unchecked Sendable {
        private let queues: [DispatchQueue]
        private let atomicRoundRobin = AtomicCounter()
        private let maxConcurrency: Int
        
        public init(maxConcurrency: Int = ProcessInfo.processInfo.processorCount) {
            self.maxConcurrency = maxConcurrency
            self.queues = (0..<maxConcurrency).map { index in
                DispatchQueue(
                    label: "com.realtimekit.threadpool.\(index)",
                    qos: .userInitiated
                )
            }
        }
        
        /// Submit work to thread pool
        public func submit<T>(_ work: @escaping @Sendable () throws -> T) -> Future<T> {
            let promise = Promise<T>()
            let queueIndex = atomicRoundRobin.increment() % maxConcurrency
            
            queues[queueIndex].async {
                do {
                    let result = try work()
                    promise.resolve(result)
                } catch {
                    promise.reject(error)
                }
            }
            
            return promise.future
        }
        
        /// Submit async work to thread pool
        public func submitAsync<T>(_ work: @escaping @Sendable () async throws -> T) -> Future<T> {
            let promise = Promise<T>()
            let queueIndex = atomicRoundRobin.increment() % maxConcurrency
            
            queues[queueIndex].async {
                Task {
                    do {
                        let result = try await work()
                        promise.resolve(result)
                    } catch {
                        promise.reject(error)
                    }
                }
            }
            
            return promise.future
        }
    }
    
    // MARK: - Future/Promise Implementation
    
    /// Simple future implementation for async operations
    public final class Future<T>: @unchecked Sendable {
        private var result: Result<T, Error>?
        private var callbacks: [(Result<T, Error>) -> Void] = []
        private let lock = NSLock()
        
        fileprivate init() {}
        
        /// Add completion callback
        public func onComplete(_ callback: @escaping (Result<T, Error>) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            
            if let result = result {
                callback(result)
            } else {
                callbacks.append(callback)
            }
        }
        
        /// Get result synchronously (blocks until complete)
        public func get() throws -> T {
            let semaphore = DispatchSemaphore(value: 0)
            var finalResult: Result<T, Error>?
            
            onComplete { result in
                finalResult = result
                semaphore.signal()
            }
            
            semaphore.wait()
            
            switch finalResult! {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
        
        /// Get result with timeout
        public func get(timeout: TimeInterval) throws -> T {
            let semaphore = DispatchSemaphore(value: 0)
            var finalResult: Result<T, Error>?
            
            onComplete { result in
                finalResult = result
                semaphore.signal()
            }
            
            let timeoutResult = semaphore.wait(timeout: .now() + timeout)
            
            if timeoutResult == .timedOut {
                throw ThreadSafetyError.timeout
            }
            
            switch finalResult! {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
        
        fileprivate func complete(with result: Result<T, Error>) {
            lock.lock()
            defer { lock.unlock() }
            
            guard self.result == nil else { return }
            
            self.result = result
            
            // Execute callbacks synchronously to avoid data races
            callbacks.forEach { $0(result) }
        }
    }
    
    /// Promise for completing futures
    public final class Promise<T>: @unchecked Sendable {
        public let future = Future<T>()
        
        public func resolve(_ value: T) {
            future.complete(with: .success(value))
        }
        
        public func reject(_ error: Error) {
            future.complete(with: .failure(error))
        }
    }
}

// MARK: - Thread Safety Errors

public enum ThreadSafetyError: Error, LocalizedError {
    case timeout
    case concurrencyLimitExceeded
    case deadlockDetected
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out"
        case .concurrencyLimitExceeded:
            return "Concurrency limit exceeded"
        case .deadlockDetected:
            return "Potential deadlock detected"
        }
    }
}

// MARK: - Global Thread Safety Manager

/// Global thread safety utilities
public final class GlobalThreadSafetyManager: @unchecked Sendable {
    
    /// Shared thread pool for CPU-intensive operations
    public static let sharedThreadPool = ThreadSafetyManager.ThreadPool()
    
    /// Shared resource limiter for network operations
    public static let networkResourceLimiter = ThreadSafetyManager.ResourceLimiter(maxConcurrency: 10)
    
    /// Shared resource limiter for file operations
    public static let fileResourceLimiter = ThreadSafetyManager.ResourceLimiter(maxConcurrency: 5)
    
    /// Execute CPU-intensive work on shared thread pool
    public static func executeCPUWork<T>(_ work: @escaping @Sendable () throws -> T) -> ThreadSafetyManager.Future<T> {
        return sharedThreadPool.submit(work)
    }
    
    /// Execute network operation with resource limiting
    public static func executeNetworkWork<T>(_ work: @escaping () throws -> T) throws -> T {
        return try networkResourceLimiter.execute(work)
    }
    
    /// Execute file operation with resource limiting
    public static func executeFileWork<T>(_ work: @escaping () throws -> T) throws -> T {
        return try fileResourceLimiter.execute(work)
    }
}
