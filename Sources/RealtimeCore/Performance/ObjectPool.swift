// ObjectPool.swift
// Generic object pool for memory optimization

import Foundation

/// Generic object pool for managing frequently created objects
public final class ObjectPool<T: AnyObject>: @unchecked Sendable {
    private let createObject: () -> T
    private let resetObject: ((T) -> Void)?
    private let maxPoolSize: Int
    private var pool: [T] = []
    private let queue = DispatchQueue(label: "com.realtimekit.objectpool", attributes: .concurrent)
    
    /// Initialize object pool
    /// - Parameters:
    ///   - maxPoolSize: Maximum number of objects to keep in pool
    ///   - createObject: Factory function to create new objects
    ///   - resetObject: Optional function to reset object state before reuse
    public init(
        maxPoolSize: Int = 10,
        createObject: @escaping () -> T,
        resetObject: ((T) -> Void)? = nil
    ) {
        self.maxPoolSize = maxPoolSize
        self.createObject = createObject
        self.resetObject = resetObject
    }
    
    /// Borrow an object from the pool
    /// - Returns: Object from pool or newly created object
    public func borrow() -> T {
        return queue.sync {
            if let object = pool.popLast() {
                return object
            } else {
                return createObject()
            }
        }
    }
    
    /// Return an object to the pool
    /// - Parameter object: Object to return to pool
    public func `return`(_ object: T) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Reset object state if reset function provided
            self.resetObject?(object)
            
            // Only keep object if pool isn't full
            if self.pool.count < self.maxPoolSize {
                self.pool.append(object)
            }
        }
    }
    
    /// Use an object temporarily with automatic return
    /// - Parameter block: Block to execute with borrowed object
    /// - Returns: Result of the block execution
    public func withBorrowedObject<R>(_ block: (T) throws -> R) rethrows -> R {
        let object = borrow()
        defer { self.return(object) }
        return try block(object)
    }
    
    /// Clear all objects from pool
    public func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.pool.removeAll()
        }
    }
    
    /// Get current pool statistics
    /// - Returns: Pool statistics
    public func getStatistics() -> ObjectPoolStatistics {
        return queue.sync {
            return ObjectPoolStatistics(
                currentPoolSize: pool.count,
                maxPoolSize: maxPoolSize
            )
        }
    }
}

/// Object pool statistics
public struct ObjectPoolStatistics {
    public let currentPoolSize: Int
    public let maxPoolSize: Int
    
    public var utilizationPercentage: Double {
        guard maxPoolSize > 0 else { return 0.0 }
        return Double(currentPoolSize) / Double(maxPoolSize) * 100.0
    }
}

/// Thread-safe object pool manager for multiple object types
@MainActor
public final class ObjectPoolManager {
    public static let shared = ObjectPoolManager()
    
    private var pools: [String: Any] = [:]
    
    private init() {}
    
    /// Register an object pool for a specific type
    /// - Parameters:
    ///   - type: Object type
    ///   - pool: Object pool instance
    public func registerPool<T: AnyObject>(for type: T.Type, pool: ObjectPool<T>) {
        let key = String(describing: type)
        pools[key] = pool
    }
    
    /// Get object pool for a specific type
    /// - Parameter type: Object type
    /// - Returns: Object pool if registered
    public func getPool<T: AnyObject>(for type: T.Type) -> ObjectPool<T>? {
        let key = String(describing: type)
        return pools[key] as? ObjectPool<T>
    }
    
    /// Clear all pools
    public func clearAllPools() {
        for (_, pool) in pools {
            if let objectPool = pool as? AnyObjectPool {
                objectPool.clear()
            }
        }
    }
    
    /// Get statistics for all pools
    /// - Returns: Dictionary of pool statistics by type name
    public func getAllStatistics() -> [String: ObjectPoolStatistics] {
        var statistics: [String: ObjectPoolStatistics] = [:]
        
        for (key, pool) in pools {
            if let objectPool = pool as? AnyObjectPool {
                statistics[key] = objectPool.getStatistics()
            }
        }
        
        return statistics
    }
}

/// Type-erased protocol for object pool operations
private protocol AnyObjectPool {
    func clear()
    func getStatistics() -> ObjectPoolStatistics
}

extension ObjectPool: AnyObjectPool {}