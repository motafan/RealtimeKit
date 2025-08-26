import Foundation

/// Generic object pool for managing frequently created objects
/// 需求: 14.1 - 实现对象池管理频繁创建的对象
public final class ObjectPool<T: AnyObject & Sendable>: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let createObject: () -> T
    private let resetObject: ((T) -> Void)?
    private let maxPoolSize: Int
    private var pool: [T] = []
    private let poolQueue = DispatchQueue(label: "com.realtimekit.objectpool", attributes: .concurrent)
    
    // MARK: - Statistics
    
    private var totalCreated: Int = 0
    private var totalReused: Int = 0
    private var currentPoolSize: Int = 0
    
    // MARK: - Initialization
    
    /// Initialize object pool
    /// - Parameters:
    ///   - maxPoolSize: Maximum number of objects to keep in pool
    ///   - createObject: Factory closure to create new objects
    ///   - resetObject: Optional closure to reset object state before reuse
    public init(
        maxPoolSize: Int = 50,
        createObject: @escaping () -> T,
        resetObject: ((T) -> Void)? = nil
    ) {
        self.maxPoolSize = maxPoolSize
        self.createObject = createObject
        self.resetObject = resetObject
    }
    
    // MARK: - Pool Operations
    
    /// Get an object from the pool or create a new one
    /// - Returns: Reused or newly created object
    public func getObject() -> T {
        return poolQueue.sync {
            if let object = pool.popLast() {
                currentPoolSize = pool.count
                totalReused += 1
                return object
            } else {
                totalCreated += 1
                return createObject()
            }
        }
    }
    
    /// Return an object to the pool for reuse
    /// - Parameter object: Object to return to pool
    public func returnObject(_ object: T) {
        // Reset object state if reset closure is provided (do this synchronously)
        resetObject?(object)
        
        // Note: We capture 'object' in the closure below. This is safe because:
        // 1. The ObjectPool is marked as @unchecked Sendable
        // 2. We use a barrier queue to ensure thread safety
        // 3. The object is only accessed within the synchronized block
        poolQueue.async(flags: .barrier) { [weak self, object] in
            guard let self = self else { return }
            
            // Add to pool if not at capacity
            if self.pool.count < self.maxPoolSize {
                self.pool.append(object)
                self.currentPoolSize = self.pool.count
            }
            // If pool is full, object will be deallocated
        }
    }
    
    /// Clear all objects from the pool
    public func clearPool() {
        poolQueue.async(flags: .barrier) { [weak self] in
            self?.pool.removeAll()
            self?.currentPoolSize = 0
        }
    }
    
    /// Get pool statistics
    /// - Returns: Pool usage statistics
    public func getStatistics() -> ObjectPoolStatistics {
        return poolQueue.sync {
            return ObjectPoolStatistics(
                totalCreated: totalCreated,
                totalReused: totalReused,
                currentPoolSize: currentPoolSize,
                maxPoolSize: maxPoolSize,
                reuseRate: totalCreated > 0 ? Double(totalReused) / Double(totalCreated + totalReused) : 0.0
            )
        }
    }
}

/// Object pool usage statistics
public struct ObjectPoolStatistics: Sendable {
    public let totalCreated: Int
    public let totalReused: Int
    public let currentPoolSize: Int
    public let maxPoolSize: Int
    public let reuseRate: Double
    
    public var description: String {
        return """
        ObjectPool Statistics:
        - Total Created: \(totalCreated)
        - Total Reused: \(totalReused)
        - Current Pool Size: \(currentPoolSize)/\(maxPoolSize)
        - Reuse Rate: \(String(format: "%.2f%%", reuseRate * 100))
        """
    }
}

// MARK: - Specialized Object Pools

/// Pool for dictionary wrappers that can be used for various data structures
public final class DictionaryWrapperPool: @unchecked Sendable {
    
    /// Wrapper class for dictionary to make it work with object pool
    private final class DictionaryWrapper: @unchecked Sendable {
        var dictionary: [String: Any] = [:]
        
        func removeAll() {
            dictionary.removeAll()
        }
        
        func setValue(_ value: Any?, forKey key: String) {
            dictionary[key] = value
        }
        
        func getValue(forKey key: String) -> Any? {
            return dictionary[key]
        }
    }
    
    private let pool = ObjectPool<DictionaryWrapper>(
        maxPoolSize: 100,
        createObject: {
            return DictionaryWrapper()
        },
        resetObject: { wrapper in
            wrapper.removeAll()
        }
    )
    
    public static let shared = DictionaryWrapperPool()
    
    private init() {}
    
    /// Get a reusable dictionary wrapper
    public func getDictionaryWrapper() -> [String: Any] {
        let wrapper = pool.getObject()
        return wrapper.dictionary
    }
    
    /// Return dictionary wrapper to pool
    public func returnDictionaryWrapper(_ dict: [String: Any]) {
        let wrapper = DictionaryWrapper()
        wrapper.dictionary = dict
        pool.returnObject(wrapper)
    }
    
    public func getStatistics() -> ObjectPoolStatistics {
        return pool.getStatistics()
    }
}

/// Pool for message dictionary objects
public final class MessageDictionaryPool: @unchecked Sendable {
    
    /// Wrapper class for dictionary to make it work with object pool
    private final class MessageDictionaryWrapper: @unchecked Sendable {
        var dictionary: [String: Any] = [:]
        
        func removeAll() {
            dictionary.removeAll()
        }
        
        func setValue(_ value: Any?, forKey key: String) {
            dictionary[key] = value
        }
        
        func getValue(forKey key: String) -> Any? {
            return dictionary[key]
        }
    }
    
    private let pool = ObjectPool<MessageDictionaryWrapper>(
        maxPoolSize: 200,
        createObject: {
            return MessageDictionaryWrapper()
        },
        resetObject: { wrapper in
            wrapper.removeAll()
        }
    )
    
    public static let shared = MessageDictionaryPool()
    
    private init() {}
    
    /// Get a reusable dictionary for message data
    public func getMessageDictionary() -> [String: Any] {
        let wrapper = pool.getObject()
        return wrapper.dictionary
    }
    
    /// Return dictionary to pool (creates new wrapper)
    public func returnMessageDictionary(_ dict: [String: Any]) {
        let wrapper = MessageDictionaryWrapper()
        wrapper.dictionary = dict
        pool.returnObject(wrapper)
    }
    
    public func getStatistics() -> ObjectPoolStatistics {
        return pool.getStatistics()
    }
}

/// Pool for temporary data buffers
public final class DataBufferPool: @unchecked Sendable {
    
    /// Wrapper class for data buffer to make it work with object pool
    private final class DataBufferWrapper: @unchecked Sendable {
        var data: Data = Data()
        
        func reset() {
            data.removeAll(keepingCapacity: true)
        }
        
        func reserveCapacity(_ capacity: Int) {
            data.reserveCapacity(capacity)
        }
    }
    
    private let pool = ObjectPool<DataBufferWrapper>(
        maxPoolSize: 50,
        createObject: {
            let wrapper = DataBufferWrapper()
            wrapper.reserveCapacity(1024)
            return wrapper
        },
        resetObject: { wrapper in
            wrapper.reset()
        }
    )
    
    public static let shared = DataBufferPool()
    
    private init() {}
    
    /// Get a reusable data buffer
    public func getBuffer() -> Data {
        let wrapper = pool.getObject()
        return wrapper.data
    }
    
    /// Return buffer to pool (creates new wrapper)
    public func returnBuffer(_ buffer: Data) {
        let wrapper = DataBufferWrapper()
        wrapper.data = buffer
        pool.returnObject(wrapper)
    }
    
    public func getStatistics() -> ObjectPoolStatistics {
        return pool.getStatistics()
    }
}
