// MemoryManager.swift
// Memory management utilities with weak references and resource cleanup

import Foundation
import Combine

/// Memory manager for tracking and cleaning up resources
@MainActor
public final class MemoryManager: ObservableObject {
    public static let shared = MemoryManager()
    
    @Published public private(set) var memoryUsage: MemoryUsageInfo = MemoryUsageInfo()
    @Published public private(set) var isMemoryPressureHigh: Bool = false
    
    private var weakReferences: [WeakReference] = []
    private var cleanupTasks: [String: () -> Void] = [:]
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var memoryMonitorTimer: Timer?
    
    private init() {
        setupMemoryPressureMonitoring()
        startMemoryMonitoring()
    }
    
    // Note: Cleanup is handled by the system when the object is deallocated
    
    // MARK: - Weak Reference Management
    
    /// Register a weak reference for automatic cleanup
    /// - Parameters:
    ///   - object: Object to hold weakly
    ///   - identifier: Unique identifier for the reference
    ///   - cleanup: Optional cleanup block to execute when object is deallocated
    public func registerWeakReference<T: AnyObject>(
        to object: T,
        identifier: String,
        cleanup: (() -> Void)? = nil
    ) {
        let weakRef = WeakReference(
            identifier: identifier,
            object: object,
            cleanup: cleanup
        )
        
        weakReferences.append(weakRef)
        
        if let cleanup = cleanup {
            cleanupTasks[identifier] = cleanup
        }
    }
    
    /// Unregister a weak reference
    /// - Parameter identifier: Identifier of the reference to remove
    public func unregisterWeakReference(identifier: String) {
        weakReferences.removeAll { $0.identifier == identifier }
        cleanupTasks.removeValue(forKey: identifier)
    }
    
    /// Clean up all deallocated weak references
    public func cleanupDeallocatedReferences() {
        let deallocatedRefs = weakReferences.filter { $0.object == nil }
        
        for ref in deallocatedRefs {
            ref.cleanup?()
            cleanupTasks.removeValue(forKey: ref.identifier)
        }
        
        weakReferences.removeAll { $0.object == nil }
        
        print("Cleaned up \(deallocatedRefs.count) deallocated references")
    }
    
    /// Get count of active weak references
    /// - Returns: Number of active references
    public func getActiveReferenceCount() -> Int {
        return weakReferences.filter { $0.object != nil }.count
    }
    
    /// Get count of deallocated references pending cleanup
    /// - Returns: Number of deallocated references
    public func getDeallocatedReferenceCount() -> Int {
        return weakReferences.filter { $0.object == nil }.count
    }
    
    // MARK: - Memory Monitoring
    
    /// Setup memory pressure monitoring
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        memoryPressureSource?.resume()
    }
    
    /// Start periodic memory monitoring
    private func startMemoryMonitoring() {
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
                self?.cleanupDeallocatedReferences()
            }
        }
    }
    
    /// Stop memory monitoring
    private func stopMemoryMonitoring() {
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
    }
    
    /// Handle memory pressure events
    private func handleMemoryPressure() {
        isMemoryPressureHigh = true
        
        // Trigger aggressive cleanup
        performAggressiveCleanup()
        
        // Reset pressure flag after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.isMemoryPressureHigh = false
        }
        
        print("Memory pressure detected - performed aggressive cleanup")
    }
    
    /// Update current memory usage information
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        memoryUsage = usage
        
        // Trigger cleanup if memory usage is high
        if usage.usedMemoryMB > 100 { // Threshold: 100MB
            cleanupDeallocatedReferences()
        }
    }
    
    /// Get current memory usage
    /// - Returns: Memory usage information
    private func getCurrentMemoryUsage() -> MemoryUsageInfo {
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
        
        if kerr == KERN_SUCCESS {
            let usedMemoryBytes = info.resident_size
            let usedMemoryMB = Double(usedMemoryBytes) / 1024.0 / 1024.0
            
            return MemoryUsageInfo(
                usedMemoryMB: usedMemoryMB,
                activeReferences: getActiveReferenceCount(),
                deallocatedReferences: getDeallocatedReferenceCount()
            )
        } else {
            return MemoryUsageInfo()
        }
    }
    
    /// Perform aggressive cleanup during memory pressure
    private func performAggressiveCleanup() {
        // Clean up deallocated references
        cleanupDeallocatedReferences()
        
        // Clear object pools
        ObjectPoolManager.shared.clearAllPools()
        
        // Execute all registered cleanup tasks
        for (_, cleanup) in cleanupTasks {
            cleanup()
        }
        
        // Trigger garbage collection hint
        autoreleasepool {
            // Force autorelease pool drain
        }
    }
    
    // MARK: - Resource Management
    
    /// Register a cleanup task
    /// - Parameters:
    ///   - identifier: Unique identifier for the task
    ///   - cleanup: Cleanup block to execute
    public func registerCleanupTask(identifier: String, cleanup: @escaping () -> Void) {
        cleanupTasks[identifier] = cleanup
    }
    
    /// Unregister a cleanup task
    /// - Parameter identifier: Identifier of the task to remove
    public func unregisterCleanupTask(identifier: String) {
        cleanupTasks.removeValue(forKey: identifier)
    }
    
    /// Execute all cleanup tasks
    public func executeAllCleanupTasks() {
        for (_, cleanup) in cleanupTasks {
            cleanup()
        }
    }
    
    /// Get memory management statistics
    /// - Returns: Current memory management statistics
    public func getStatistics() -> MemoryManagementStatistics {
        return MemoryManagementStatistics(
            memoryUsage: memoryUsage,
            activeReferences: getActiveReferenceCount(),
            deallocatedReferences: getDeallocatedReferenceCount(),
            registeredCleanupTasks: cleanupTasks.count,
            isMemoryPressureHigh: isMemoryPressureHigh
        )
    }
}

/// Weak reference wrapper with cleanup capability
private class WeakReference {
    let identifier: String
    weak var object: AnyObject?
    let cleanup: (() -> Void)?
    
    init(identifier: String, object: AnyObject, cleanup: (() -> Void)? = nil) {
        self.identifier = identifier
        self.object = object
        self.cleanup = cleanup
    }
}

/// Memory usage information
public struct MemoryUsageInfo {
    public let usedMemoryMB: Double
    public let activeReferences: Int
    public let deallocatedReferences: Int
    public let timestamp: Date
    
    public init(
        usedMemoryMB: Double = 0.0,
        activeReferences: Int = 0,
        deallocatedReferences: Int = 0
    ) {
        self.usedMemoryMB = usedMemoryMB
        self.activeReferences = activeReferences
        self.deallocatedReferences = deallocatedReferences
        self.timestamp = Date()
    }
}

/// Memory management statistics
public struct MemoryManagementStatistics {
    public let memoryUsage: MemoryUsageInfo
    public let activeReferences: Int
    public let deallocatedReferences: Int
    public let registeredCleanupTasks: Int
    public let isMemoryPressureHigh: Bool
    
    public var memoryEfficiency: Double {
        let totalReferences = activeReferences + deallocatedReferences
        guard totalReferences > 0 else { return 100.0 }
        return Double(activeReferences) / Double(totalReferences) * 100.0
    }
}