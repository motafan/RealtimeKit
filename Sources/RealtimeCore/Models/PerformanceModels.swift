import Foundation

/// Performance statistics for localization operations
/// 需求: 14.2, 14.3 - 性能监控和优化
public struct LocalizationPerformanceStatistics: Sendable {
    public let cacheHits: Int
    public let cacheMisses: Int
    public let bundleAccesses: Int
    public let cacheStatistics: LocalizationCacheStatistics
    public let threadSafeCustomLocalizationCount: Int
    public let estimatedMemoryUsage: Int
    
    public var hitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0.0
    }
    
    public var description: String {
        return """
        Localization Performance Statistics:
        - Cache Hits: \(cacheHits)
        - Cache Misses: \(cacheMisses)
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Bundle Accesses: \(bundleAccesses)
        - Custom Localizations: \(threadSafeCustomLocalizationCount)
        - Memory Usage: \(estimatedMemoryUsage) bytes
        - Cache Details: \(cacheStatistics.description)
        """
    }
}

/// Memory usage information for localization
public struct LocalizationMemoryUsage: Sendable {
    public let cacheMemory: Int
    public let customLocalizationsMemory: Int
    public let totalMemory: Int
    
    public var cacheMemoryMB: Double {
        return Double(cacheMemory) / (1024 * 1024)
    }
    
    public var customLocalizationsMemoryMB: Double {
        return Double(customLocalizationsMemory) / (1024 * 1024)
    }
    
    public var totalMemoryMB: Double {
        return Double(totalMemory) / (1024 * 1024)
    }
    
    public var description: String {
        return """
        Localization Memory Usage:
        - Cache Memory: \(String(format: "%.2f", cacheMemoryMB)) MB
        - Custom Localizations: \(String(format: "%.2f", customLocalizationsMemoryMB)) MB
        - Total Memory: \(String(format: "%.2f", totalMemoryMB)) MB
        """
    }
}

/// Network performance statistics
/// 需求: 14.2 - 网络性能优化
public struct NetworkPerformanceStatistics: Sendable {
    public let totalConnections: Int
    public let activeConnections: Int
    public let connectionPoolHits: Int
    public let connectionPoolMisses: Int
    public let totalDataTransferred: Int
    public let compressedDataTransferred: Int
    public let averageCompressionRatio: Double
    public let averageConnectionTime: TimeInterval
    public let averageRequestTime: TimeInterval
    
    public var connectionReuseRate: Double {
        let total = connectionPoolHits + connectionPoolMisses
        return total > 0 ? Double(connectionPoolHits) / Double(total) : 0.0
    }
    
    public var compressionSavings: Int {
        return totalDataTransferred - compressedDataTransferred
    }
    
    public var compressionSavingsPercentage: Double {
        return totalDataTransferred > 0 ? Double(compressionSavings) / Double(totalDataTransferred) * 100 : 0.0
    }
    
    public var description: String {
        return """
        Network Performance Statistics:
        - Total Connections: \(totalConnections)
        - Active Connections: \(activeConnections)
        - Connection Reuse Rate: \(String(format: "%.2f%%", connectionReuseRate * 100))
        - Data Transferred: \(totalDataTransferred) bytes
        - Compression Savings: \(String(format: "%.2f%%", compressionSavingsPercentage))
        - Avg Connection Time: \(String(format: "%.3f", averageConnectionTime))s
        - Avg Request Time: \(String(format: "%.3f", averageRequestTime))s
        """
    }
}

/// Thread safety performance statistics
/// 需求: 14.3 - 线程安全性能监控
public struct ThreadSafetyPerformanceStatistics: Sendable {
    public let totalLockAcquisitions: Int
    public let totalLockContentions: Int
    public let averageLockHoldTime: TimeInterval
    public let maxLockHoldTime: TimeInterval
    public let activeThreadCount: Int
    public let queuedOperationCount: Int
    public let completedOperationCount: Int
    public let failedOperationCount: Int
    
    public var lockContentionRate: Double {
        return totalLockAcquisitions > 0 ? Double(totalLockContentions) / Double(totalLockAcquisitions) : 0.0
    }
    
    public var operationSuccessRate: Double {
        let total = completedOperationCount + failedOperationCount
        return total > 0 ? Double(completedOperationCount) / Double(total) : 0.0
    }
    
    public var description: String {
        return """
        Thread Safety Performance Statistics:
        - Lock Acquisitions: \(totalLockAcquisitions)
        - Lock Contentions: \(totalLockContentions)
        - Contention Rate: \(String(format: "%.2f%%", lockContentionRate * 100))
        - Avg Lock Hold Time: \(String(format: "%.4f", averageLockHoldTime))s
        - Max Lock Hold Time: \(String(format: "%.4f", maxLockHoldTime))s
        - Active Threads: \(activeThreadCount)
        - Queued Operations: \(queuedOperationCount)
        - Operation Success Rate: \(String(format: "%.2f%%", operationSuccessRate * 100))
        """
    }
}

/// Overall system performance statistics
/// 需求: 14.1, 14.2, 14.3, 14.4 - 综合性能监控
public struct SystemPerformanceStatistics: Sendable {
    public let memoryUsage: MemoryUsageInfo
    public let localizationStats: LocalizationPerformanceStatistics
    public let networkStats: NetworkPerformanceStatistics
    public let threadSafetyStats: ThreadSafetyPerformanceStatistics
    public let objectPoolStats: [String: ObjectPoolStatistics]
    public let weakReferenceStats: WeakReferenceStatistics
    public let timestamp: Date
    
    public var description: String {
        return """
        System Performance Statistics (\(timestamp)):
        
        Memory Usage:
        \(memoryUsage.description)
        
        Localization Performance:
        \(localizationStats.description)
        
        Network Performance:
        \(networkStats.description)
        
        Thread Safety Performance:
        \(threadSafetyStats.description)
        
        Object Pool Statistics:
        \(objectPoolStats.map { "\($0.key): \($0.value.description)" }.joined(separator: "\n"))
        
        Weak Reference Statistics:
        \(weakReferenceStats.description)
        """
    }
}

/// Performance optimization recommendations
/// 需求: 14.1, 14.2, 14.3, 14.4 - 性能优化建议
public struct PerformanceOptimizationRecommendations: Sendable {
    public let memoryRecommendations: [String]
    public let networkRecommendations: [String]
    public let threadSafetyRecommendations: [String]
    public let localizationRecommendations: [String]
    public let priority: OptimizationPriority
    public let estimatedImpact: OptimizationImpact
    
    public enum OptimizationPriority: Sendable {
        case low
        case medium
        case high
        case critical
        
        var description: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }
    
    public enum OptimizationImpact: Sendable {
        case minimal
        case moderate
        case significant
        case major
        
        var description: String {
            switch self {
            case .minimal: return "Minimal"
            case .moderate: return "Moderate"
            case .significant: return "Significant"
            case .major: return "Major"
            }
        }
    }
    
    public var description: String {
        let allRecommendations = memoryRecommendations + networkRecommendations + 
                                threadSafetyRecommendations + localizationRecommendations
        
        return """
        Performance Optimization Recommendations:
        Priority: \(priority.description)
        Estimated Impact: \(estimatedImpact.description)
        
        Recommendations:
        \(allRecommendations.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
    }
}

/// Performance monitoring configuration
/// 需求: 14.1, 14.2, 14.3, 14.4 - 性能监控配置
public struct PerformanceMonitoringConfig: Sendable {
    public let enableMemoryTracking: Bool
    public let enableNetworkMonitoring: Bool
    public let enableThreadSafetyMonitoring: Bool
    public let enableLocalizationMonitoring: Bool
    public let monitoringInterval: TimeInterval
    public let alertThresholds: PerformanceAlertThresholds
    
    @MainActor
    public static let `default` = PerformanceMonitoringConfig(
        enableMemoryTracking: true,
        enableNetworkMonitoring: true,
        enableThreadSafetyMonitoring: true,
        enableLocalizationMonitoring: true,
        monitoringInterval: 60.0, // 1 minute
        alertThresholds: .default
    )
}

/// Performance alert thresholds
public struct PerformanceAlertThresholds: Sendable {
    public let maxMemoryUsageMB: Double
    public let minCacheHitRate: Double
    public let maxAverageResponseTime: TimeInterval
    public let maxLockContentionRate: Double
    public let maxActiveThreadCount: Int
    
    @MainActor
    public static let `default` = PerformanceAlertThresholds(
        maxMemoryUsageMB: 100.0,
        minCacheHitRate: 0.8, // 80%
        maxAverageResponseTime: 1.0, // 1 second
        maxLockContentionRate: 0.1, // 10%
        maxActiveThreadCount: 50
    )
}

/// Performance alert
public struct PerformanceAlert: Sendable {
    public let type: AlertType
    public let severity: AlertSeverity
    public let message: String
    public let currentValue: Double
    public let thresholdValue: Double
    public let timestamp: Date
    public let recommendations: [String]
    
    public enum AlertType: Sendable {
        case memoryUsage
        case cacheHitRate
        case responseTime
        case lockContention
        case threadCount
    }
    
    public enum AlertSeverity: Sendable {
        case info
        case warning
        case error
        case critical
        
        var description: String {
            switch self {
            case .info: return "Info"
            case .warning: return "Warning"
            case .error: return "Error"
            case .critical: return "Critical"
            }
        }
    }
    
    public var description: String {
        return """
        Performance Alert [\(severity.description)]:
        Type: \(type)
        Message: \(message)
        Current: \(currentValue), Threshold: \(thresholdValue)
        Time: \(timestamp)
        Recommendations: \(recommendations.joined(separator: ", "))
        """
    }
}