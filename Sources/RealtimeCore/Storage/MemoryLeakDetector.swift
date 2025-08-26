import Foundation

/// Memory leak detection and monitoring system
/// 需求: 14.1 - 编写内存泄漏检测和性能基准测试
public final class MemoryLeakDetector: @unchecked Sendable {
    
    // MARK: - Tracked Object Info
    
    private struct TrackedObjectInfo {
        let className: String
        let address: String
        let creationTime: Date
        let creationStack: [String]
        
        var age: TimeInterval {
            return Date().timeIntervalSince(creationTime)
        }
    }
    
    // MARK: - Properties
    
    private var trackedObjects: [ObjectIdentifier: TrackedObjectInfo] = [:]
    private let trackingQueue = DispatchQueue(label: "com.realtimekit.memory.tracking", attributes: .concurrent)
    private var isEnabled: Bool = false
    private var suspiciousAgeThreshold: TimeInterval = 300 // 5 minutes
    
    // MARK: - Statistics
    
    private var totalObjectsTracked: Int = 0
    private var totalObjectsReleased: Int = 0
    private var peakObjectCount: Int = 0
    
    // MARK: - Singleton
    
    public static let shared = MemoryLeakDetector()
    
    private init() {}
    
    // MARK: - Tracking Control
    
    /// Enable memory leak detection
    /// - Parameter suspiciousAgeThreshold: Age threshold for considering objects suspicious
    public func enable(suspiciousAgeThreshold: TimeInterval = 300) {
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?.isEnabled = true
            self?.suspiciousAgeThreshold = suspiciousAgeThreshold
            print("MemoryLeakDetector: Enabled with threshold \(suspiciousAgeThreshold)s")
        }
    }
    
    /// Disable memory leak detection
    public func disable() {
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?.isEnabled = false
            self?.trackedObjects.removeAll()
            print("MemoryLeakDetector: Disabled")
        }
    }
    
    /// Check if detection is enabled
    public var isDetectionEnabled: Bool {
        return trackingQueue.sync { isEnabled }
    }
    
    // MARK: - Object Tracking
    
    /// Start tracking an object for memory leaks
    /// - Parameter object: Object to track
    public func startTracking<T: AnyObject>(_ object: T) {
        guard isEnabled else { return }
        
        let objectId = ObjectIdentifier(object)
        let className = String(describing: type(of: object))
        let address = withUnsafePointer(to: object) { String(format: "%p", $0) }
        let stack = Thread.callStackSymbols
        
        trackingQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let info = TrackedObjectInfo(
                className: className,
                address: address,
                creationTime: Date(),
                creationStack: stack
            )
            
            self.trackedObjects[objectId] = info
            self.totalObjectsTracked += 1
            
            if self.trackedObjects.count > self.peakObjectCount {
                self.peakObjectCount = self.trackedObjects.count
            }
        }
    }
    
    /// Stop tracking an object (called when object is deallocated)
    /// - Parameter object: Object to stop tracking
    public func stopTracking<T: AnyObject>(_ object: T) {
        guard isEnabled else { return }
        
        let objectId = ObjectIdentifier(object)
        
        trackingQueue.async(flags: .barrier) { [weak self] in
            if self?.trackedObjects.removeValue(forKey: objectId) != nil {
                self?.totalObjectsReleased += 1
            }
        }
    }
    
    // MARK: - Leak Detection
    
    /// Get list of potentially leaked objects
    /// - Returns: Array of suspicious objects that might be leaked
    public func getSuspiciousObjects() -> [SuspiciousObjectInfo] {
        return trackingQueue.sync {
            let now = Date()
            
            return trackedObjects.compactMap { objectId, info in
                let age = now.timeIntervalSince(info.creationTime)
                
                if age > suspiciousAgeThreshold {
                    return SuspiciousObjectInfo(
                        className: info.className,
                        address: info.address,
                        age: age,
                        creationTime: info.creationTime,
                        creationStack: info.creationStack
                    )
                }
                
                return nil
            }.sorted { $0.age > $1.age }
        }
    }
    
    /// Check for potential memory leaks
    /// - Returns: Leak detection report
    public func detectLeaks() -> MemoryLeakReport {
        let suspiciousObjects = getSuspiciousObjects()
        let statistics = getStatistics()
        
        let report = MemoryLeakReport(
            suspiciousObjects: suspiciousObjects,
            statistics: statistics,
            detectionTime: Date(),
            suspiciousAgeThreshold: suspiciousAgeThreshold
        )
        
        if !suspiciousObjects.isEmpty {
            print("MemoryLeakDetector: Found \(suspiciousObjects.count) suspicious objects")
            for obj in suspiciousObjects.prefix(5) {
                print("  - \(obj.className) (age: \(String(format: "%.1f", obj.age))s)")
            }
        }
        
        return report
    }
    
    /// Get objects grouped by class name
    /// - Returns: Dictionary mapping class names to object counts
    public func getObjectCountsByClass() -> [String: Int] {
        return trackingQueue.sync {
            var counts: [String: Int] = [:]
            
            for (_, info) in trackedObjects {
                counts[info.className, default: 0] += 1
            }
            
            return counts
        }
    }
    
    // MARK: - Statistics
    
    /// Get memory tracking statistics
    /// - Returns: Current tracking statistics
    public func getStatistics() -> MemoryTrackingStatistics {
        return trackingQueue.sync {
            return MemoryTrackingStatistics(
                currentlyTracked: trackedObjects.count,
                totalTracked: totalObjectsTracked,
                totalReleased: totalObjectsReleased,
                peakObjectCount: peakObjectCount,
                isEnabled: isEnabled,
                suspiciousAgeThreshold: suspiciousAgeThreshold
            )
        }
    }
    
    /// Reset tracking statistics
    public func resetStatistics() {
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?.totalObjectsTracked = 0
            self?.totalObjectsReleased = 0
            self?.peakObjectCount = 0
        }
    }
    
    /// Clear all tracked objects
    public func clearTrackedObjects() {
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?.trackedObjects.removeAll()
        }
    }
}

// MARK: - Data Structures

/// Information about a suspicious object that might be leaked
public struct SuspiciousObjectInfo {
    public let className: String
    public let address: String
    public let age: TimeInterval
    public let creationTime: Date
    public let creationStack: [String]
    
    public var description: String {
        return """
        Suspicious Object:
        - Class: \(className)
        - Address: \(address)
        - Age: \(String(format: "%.1f", age))s
        - Created: \(creationTime)
        - Stack: \(creationStack.prefix(3).joined(separator: "\n  "))
        """
    }
}

/// Memory leak detection report
public struct MemoryLeakReport {
    public let suspiciousObjects: [SuspiciousObjectInfo]
    public let statistics: MemoryTrackingStatistics
    public let detectionTime: Date
    public let suspiciousAgeThreshold: TimeInterval
    
    public var hasSuspiciousObjects: Bool {
        return !suspiciousObjects.isEmpty
    }
    
    public var description: String {
        return """
        Memory Leak Detection Report (\(detectionTime)):
        - Suspicious Objects: \(suspiciousObjects.count)
        - Age Threshold: \(suspiciousAgeThreshold)s
        - Currently Tracked: \(statistics.currentlyTracked)
        - Peak Object Count: \(statistics.peakObjectCount)
        """
    }
}

/// Memory tracking statistics
public struct MemoryTrackingStatistics {
    public let currentlyTracked: Int
    public let totalTracked: Int
    public let totalReleased: Int
    public let peakObjectCount: Int
    public let isEnabled: Bool
    public let suspiciousAgeThreshold: TimeInterval
    
    public var releaseRate: Double {
        return totalTracked > 0 ? Double(totalReleased) / Double(totalTracked) : 0.0
    }
    
    public var description: String {
        return """
        Memory Tracking Statistics:
        - Currently Tracked: \(currentlyTracked)
        - Total Tracked: \(totalTracked)
        - Total Released: \(totalReleased)
        - Peak Object Count: \(peakObjectCount)
        - Release Rate: \(String(format: "%.2f%%", releaseRate * 100))
        - Enabled: \(isEnabled)
        """
    }
}

// MARK: - Trackable Protocol

/// Protocol for objects that want to be automatically tracked for memory leaks
public protocol MemoryTrackable: AnyObject {
    func startMemoryTracking()
    func stopMemoryTracking()
}

extension MemoryTrackable {
    public func startMemoryTracking() {
        MemoryLeakDetector.shared.startTracking(self)
    }
    
    public func stopMemoryTracking() {
        MemoryLeakDetector.shared.stopTracking(self)
    }
}

// MARK: - Automatic Tracking for RealtimeKit Classes

extension RealtimeManager: MemoryTrackable {
    /// Enable memory tracking for RealtimeManager
    public func enableMemoryTracking() {
        startMemoryTracking()
    }
}

extension LocalizationManager: MemoryTrackable {
    /// Enable memory tracking for LocalizationManager
    public func enableMemoryTracking() {
        startMemoryTracking()
    }
}

// MARK: - Memory Pressure Monitor

/// Monitor system memory pressure and provide warnings
public final class MemoryPressureMonitor: @unchecked Sendable {
    
    public enum MemoryPressureLevel: Sendable {
        case normal
        case warning
        case critical
        
        var description: String {
            switch self {
            case .normal: return "Normal"
            case .warning: return "Warning"
            case .critical: return "Critical"
            }
        }
    }
    
    private var currentPressureLevel: MemoryPressureLevel = .normal
    private var pressureChangeHandler: ((MemoryPressureLevel) -> Void)?
    
    public static let shared = MemoryPressureMonitor()
    
    private init() {
        setupMemoryPressureNotifications()
    }
    
    /// Set handler for memory pressure changes
    /// - Parameter handler: Closure to call when memory pressure changes
    public func setMemoryPressureHandler(_ handler: @escaping (MemoryPressureLevel) -> Void) {
        pressureChangeHandler = handler
    }
    
    /// Get current memory usage information
    /// - Returns: Memory usage statistics
    public func getMemoryUsage() -> MemoryUsageInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Int(info.resident_size)
            let virtualMemory = Int(info.virtual_size)
            
            return MemoryUsageInfo(
                usedMemory: usedMemory,
                virtualMemory: virtualMemory,
                pressureLevel: currentPressureLevel
            )
        } else {
            return MemoryUsageInfo(
                usedMemory: 0,
                virtualMemory: 0,
                pressureLevel: currentPressureLevel
            )
        }
    }
    
    private func setupMemoryPressureNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #endif
    }
    
    private func handleMemoryWarning() {
        currentPressureLevel = .warning
        pressureChangeHandler?(.warning)
        
        // Trigger cleanup in various managers
        LocalizationStringCache().performCleanup()
        WeakReferenceManager.shared.performCleanup()
        _ = DataBufferPool.shared.getStatistics() // Access the pool to ensure it's initialized
    }
}

/// Memory usage information
public struct MemoryUsageInfo: Sendable {
    public let usedMemory: Int
    public let virtualMemory: Int
    public let pressureLevel: MemoryPressureMonitor.MemoryPressureLevel
    
    public var usedMemoryMB: Double {
        return Double(usedMemory) / (1024 * 1024)
    }
    
    public var virtualMemoryMB: Double {
        return Double(virtualMemory) / (1024 * 1024)
    }
    
    public var description: String {
        return """
        Memory Usage:
        - Used: \(String(format: "%.1f", usedMemoryMB)) MB
        - Virtual: \(String(format: "%.1f", virtualMemoryMB)) MB
        - Pressure: \(pressureLevel.description)
        """
    }
}
