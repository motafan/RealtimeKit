import Foundation

/// Weak reference wrapper to prevent retain cycles
/// 需求: 14.1 - 添加弱引用和资源清理机制
public final class WeakReference<T: AnyObject>: @unchecked Sendable {
    public weak var value: T?
    
    public init(_ value: T) {
        self.value = value
    }
    
    public var isValid: Bool {
        return value != nil
    }
}

/// Manager for handling weak references and automatic cleanup
public final class WeakReferenceManager: @unchecked Sendable {
    
    // MARK: - Properties
    
    private var weakReferences: [String: WeakReference<AnyObject>] = [:]
    private let cleanupQueue = DispatchQueue(label: "com.realtimekit.weakref.cleanup", qos: .utility)
    private var cleanupTimer: Timer?
    private let cleanupInterval: TimeInterval = 30.0 // Clean up every 30 seconds
    
    // MARK: - Singleton
    
    public static let shared = WeakReferenceManager()
    
    private init() {
        startPeriodicCleanup()
    }
    
    deinit {
        stopPeriodicCleanup()
    }
    
    // MARK: - Reference Management
    
    /// Store a weak reference with a key
    /// - Parameters:
    ///   - object: Object to store weakly
    ///   - key: Unique key for the reference
    public func store<T: AnyObject>(_ object: T, forKey key: String) {
        let weakRef = WeakReference(object as AnyObject)
        cleanupQueue.async { [weak self] in
            self?.weakReferences[key] = weakRef
        }
    }
    
    /// Retrieve a weak reference by key
    /// - Parameter key: Key for the reference
    /// - Returns: The referenced object if still alive, nil otherwise
    public func retrieve<T: AnyObject>(forKey key: String, as type: T.Type) -> T? {
        return cleanupQueue.sync {
            return weakReferences[key]?.value as? T
        }
    }
    
    /// Remove a weak reference by key
    /// - Parameter key: Key for the reference to remove
    public func remove(forKey key: String) {
        cleanupQueue.async { [weak self] in
            self?.weakReferences.removeValue(forKey: key)
        }
    }
    
    /// Check if a reference exists and is still valid
    /// - Parameter key: Key to check
    /// - Returns: True if reference exists and object is still alive
    public func isValid(forKey key: String) -> Bool {
        return cleanupQueue.sync {
            return weakReferences[key]?.isValid ?? false
        }
    }
    
    /// Get all valid reference keys
    /// - Returns: Array of keys for valid references
    public func getValidKeys() -> [String] {
        return cleanupQueue.sync {
            return weakReferences.compactMap { key, weakRef in
                weakRef.isValid ? key : nil
            }
        }
    }
    
    /// Get count of stored references (including invalid ones)
    public var totalReferenceCount: Int {
        return cleanupQueue.sync {
            return weakReferences.count
        }
    }
    
    /// Get count of valid references
    public var validReferenceCount: Int {
        return cleanupQueue.sync {
            return weakReferences.values.filter { $0.isValid }.count
        }
    }
    
    // MARK: - Cleanup Management
    
    /// Start periodic cleanup of invalid references
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    /// Stop periodic cleanup
    private func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    /// Manually trigger cleanup of invalid references
    public func performCleanup() {
        cleanupQueue.async { [weak self] in
            guard let self = self else { return }
            
            let beforeCount = self.weakReferences.count
            
            // Remove invalid references
            self.weakReferences = self.weakReferences.filter { _, weakRef in
                return weakRef.isValid
            }
            
            let afterCount = self.weakReferences.count
            let cleanedCount = beforeCount - afterCount
            
            if cleanedCount > 0 {
                print("WeakReferenceManager: Cleaned up \(cleanedCount) invalid references")
            }
        }
    }
    
    /// Clear all references
    public func clearAll() {
        cleanupQueue.async { [weak self] in
            self?.weakReferences.removeAll()
        }
    }
    
    /// Get cleanup statistics
    /// - Returns: Statistics about reference management
    public func getStatistics() -> WeakReferenceStatistics {
        return cleanupQueue.sync {
            let total = weakReferences.count
            let valid = weakReferences.values.filter { $0.isValid }.count
            let invalid = total - valid
            
            return WeakReferenceStatistics(
                totalReferences: total,
                validReferences: valid,
                invalidReferences: invalid,
                cleanupInterval: cleanupInterval
            )
        }
    }
}

/// Statistics for weak reference management
public struct WeakReferenceStatistics: Sendable {
    public let totalReferences: Int
    public let validReferences: Int
    public let invalidReferences: Int
    public let cleanupInterval: TimeInterval
    
    public var description: String {
        return """
        WeakReference Statistics:
        - Total References: \(totalReferences)
        - Valid References: \(validReferences)
        - Invalid References: \(invalidReferences)
        - Cleanup Interval: \(cleanupInterval)s
        """
    }
}

// MARK: - Specialized Weak Reference Collections

/// Collection for managing weak references to delegates
public final class WeakDelegateCollection<T: AnyObject>: @unchecked Sendable {
    private var delegates: [WeakReference<T>] = []
    private let queue = DispatchQueue(label: "com.realtimekit.weakdelegates", attributes: .concurrent)
    
    /// Add a delegate
    public func add(_ delegate: T) {
        let weakRef = WeakReference(delegate)
        let delegateId = ObjectIdentifier(delegate)
        queue.async(flags: .barrier) { [weak self] in
            // Remove any existing reference to the same object
            self?.delegates.removeAll { weakReference in
                guard let existingDelegate = weakReference.value else { return true }
                return ObjectIdentifier(existingDelegate) == delegateId
            }
            // Add new reference
            self?.delegates.append(weakRef)
        }
    }
    
    /// Remove a delegate
    public func remove(_ delegate: T) {
        let delegateId = ObjectIdentifier(delegate)
        queue.async(flags: .barrier) { [weak self] in
            self?.delegates.removeAll { weakReference in
                guard let existingDelegate = weakReference.value else { return true }
                return ObjectIdentifier(existingDelegate) == delegateId
            }
        }
    }
    
    /// Get all valid delegates
    public func getAllDelegates() -> [T] {
        return queue.sync {
            return delegates.compactMap { $0.value }
        }
    }
    
    /// Execute a closure on all valid delegates
    public func forEach(_ closure: @escaping @Sendable (T) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let validDelegates = self.delegates.compactMap { $0.value }
            
            DispatchQueue.main.async {
                validDelegates.forEach { delegate in
                    closure(delegate)
                }
            }
        }
    }
    
    /// Clean up invalid references
    public func cleanup() {
        queue.async(flags: .barrier) { [weak self] in
            self?.delegates = self?.delegates.filter { $0.isValid } ?? []
        }
    }
    
    /// Get count of valid delegates
    public var count: Int {
        return queue.sync {
            return delegates.filter { $0.isValid }.count
        }
    }
    
    /// Check if collection is empty
    public var isEmpty: Bool {
        return count == 0
    }
}

// MARK: - Resource Cleanup Protocol

/// Protocol for objects that need explicit resource cleanup
public protocol ResourceCleanup: AnyObject {
    func cleanup()
}

/// Manager for tracking and cleaning up resources
public final class ResourceCleanupManager: @unchecked Sendable {
    
    private let weakReferenceManager = WeakReferenceManager.shared
    private var resourceCounter: Int = 0
    private let counterQueue = DispatchQueue(label: "com.realtimekit.resource.counter")
    
    public static let shared = ResourceCleanupManager()
    
    private init() {}
    
    /// Register a resource for cleanup tracking
    /// - Parameter resource: Resource that implements ResourceCleanup
    /// - Returns: Unique identifier for the resource
    @discardableResult
    public func register<T: ResourceCleanup>(_ resource: T) -> String {
        let resourceId = counterQueue.sync {
            resourceCounter += 1
            return "resource_\(resourceCounter)"
        }
        
        weakReferenceManager.store(resource, forKey: resourceId)
        return resourceId
    }
    
    /// Cleanup a specific resource by ID
    /// - Parameter resourceId: ID of the resource to cleanup
    public func cleanup(resourceId: String) {
        if let resource = weakReferenceManager.retrieve(forKey: resourceId, as: AnyObject.self) as? ResourceCleanup {
            resource.cleanup()
            weakReferenceManager.remove(forKey: resourceId)
        }
    }
    
    /// Cleanup all registered resources
    public func cleanupAll() {
        let validKeys = weakReferenceManager.getValidKeys()
        
        for key in validKeys {
            if let resource = weakReferenceManager.retrieve(forKey: key, as: AnyObject.self) as? ResourceCleanup {
                resource.cleanup()
            }
        }
        
        weakReferenceManager.clearAll()
    }
    
    /// Get count of registered resources
    public var registeredResourceCount: Int {
        return weakReferenceManager.validReferenceCount
    }
}
