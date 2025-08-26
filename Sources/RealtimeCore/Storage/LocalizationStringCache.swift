import Foundation

/// Optimized cache for localized strings to improve performance
/// 需求: 14.1 - 优化本地化字符串缓存和内存使用
public final class LocalizationStringCache: @unchecked Sendable {
    
    // MARK: - Cache Entry
    
    private struct CacheEntry {
        let value: String
        let timestamp: Date
        let accessCount: Int
        
        func withIncrementedAccess() -> CacheEntry {
            return CacheEntry(
                value: value,
                timestamp: timestamp,
                accessCount: accessCount + 1
            )
        }
    }
    
    // MARK: - Properties
    
    private var cache: [String: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.realtimekit.localization.cache", attributes: .concurrent)
    private let maxCacheSize: Int
    private let maxAge: TimeInterval
    private var cleanupTimer: Timer?
    
    // MARK: - Statistics
    
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0
    
    // MARK: - Initialization
    
    /// Initialize localization string cache
    /// - Parameters:
    ///   - maxCacheSize: Maximum number of entries to cache
    ///   - maxAge: Maximum age of cache entries in seconds
    public init(maxCacheSize: Int = 1000, maxAge: TimeInterval = 3600) {
        self.maxCacheSize = maxCacheSize
        self.maxAge = maxAge
        
        startPeriodicCleanup()
    }
    
    deinit {
        stopPeriodicCleanup()
    }
    
    // MARK: - Cache Operations
    
    /// Get cached string value
    /// - Parameter key: Cache key
    /// - Returns: Cached string if available and valid
    public func getValue(for key: String) -> String? {
        return cacheQueue.sync {
            guard let entry = cache[key] else {
                missCount += 1
                return nil
            }
            
            // Check if entry is expired
            if Date().timeIntervalSince(entry.timestamp) > maxAge {
                cache.removeValue(forKey: key)
                missCount += 1
                return nil
            }
            
            // Update access count
            cache[key] = entry.withIncrementedAccess()
            hitCount += 1
            return entry.value
        }
    }
    
    /// Store string value in cache
    /// - Parameters:
    ///   - value: String value to cache
    ///   - key: Cache key
    public func setValue(_ value: String, for key: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let entry = CacheEntry(
                value: value,
                timestamp: Date(),
                accessCount: 1
            )
            
            self.cache[key] = entry
            
            // Evict entries if cache is full
            if self.cache.count > self.maxCacheSize {
                self.evictLeastRecentlyUsed()
            }
        }
    }
    
    /// Remove cached value
    /// - Parameter key: Cache key to remove
    public func removeValue(for key: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.cache.removeValue(forKey: key)
        }
    }
    
    /// Clear all cached values
    public func clearAll() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
        }
    }
    
    /// Check if key exists in cache
    /// - Parameter key: Cache key to check
    /// - Returns: True if key exists and is valid
    public func containsKey(_ key: String) -> Bool {
        return cacheQueue.sync {
            guard let entry = cache[key] else { return false }
            
            // Check if entry is expired
            if Date().timeIntervalSince(entry.timestamp) > maxAge {
                cache.removeValue(forKey: key)
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Cache Management
    
    /// Evict least recently used entries
    private func evictLeastRecentlyUsed() {
        let entriesToEvict = cache.count - maxCacheSize + 1
        
        // Sort by access count (ascending) and timestamp (ascending)
        let sortedEntries = cache.sorted { lhs, rhs in
            if lhs.value.accessCount == rhs.value.accessCount {
                return lhs.value.timestamp < rhs.value.timestamp
            }
            return lhs.value.accessCount < rhs.value.accessCount
        }
        
        // Remove least used entries
        for i in 0..<min(entriesToEvict, sortedEntries.count) {
            let keyToRemove = sortedEntries[i].key
            cache.removeValue(forKey: keyToRemove)
            evictionCount += 1
        }
    }
    
    /// Start periodic cleanup of expired entries
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    /// Stop periodic cleanup
    private func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    /// Manually trigger cleanup of expired entries
    public func performCleanup() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            let beforeCount = self.cache.count
            
            // Remove expired entries
            self.cache = self.cache.filter { _, entry in
                return now.timeIntervalSince(entry.timestamp) <= self.maxAge
            }
            
            let afterCount = self.cache.count
            let cleanedCount = beforeCount - afterCount
            
            if cleanedCount > 0 {
                print("LocalizationStringCache: Cleaned up \(cleanedCount) expired entries")
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Get cache statistics
    /// - Returns: Cache performance statistics
    public func getStatistics() -> LocalizationCacheStatistics {
        return cacheQueue.sync {
            let totalRequests = hitCount + missCount
            let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
            
            return LocalizationCacheStatistics(
                cacheSize: cache.count,
                maxCacheSize: maxCacheSize,
                hitCount: hitCount,
                missCount: missCount,
                evictionCount: evictionCount,
                hitRate: hitRate,
                maxAge: maxAge
            )
        }
    }
    
    /// Reset statistics counters
    public func resetStatistics() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.hitCount = 0
            self?.missCount = 0
            self?.evictionCount = 0
        }
    }
    
    /// Get memory usage estimate
    /// - Returns: Estimated memory usage in bytes
    public func getEstimatedMemoryUsage() -> Int {
        return cacheQueue.sync {
            var totalSize = 0
            
            for (key, entry) in cache {
                totalSize += key.utf8.count
                totalSize += entry.value.utf8.count
                totalSize += MemoryLayout<CacheEntry>.size
            }
            
            return totalSize
        }
    }
}

/// Statistics for localization string cache
public struct LocalizationCacheStatistics: Sendable {
    public let cacheSize: Int
    public let maxCacheSize: Int
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int
    public let hitRate: Double
    public let maxAge: TimeInterval
    
    public var description: String {
        return """
        LocalizationCache Statistics:
        - Cache Size: \(cacheSize)/\(maxCacheSize)
        - Hit Count: \(hitCount)
        - Miss Count: \(missCount)
        - Eviction Count: \(evictionCount)
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Max Age: \(maxAge)s
        """
    }
}

// MARK: - Optimized Localization Manager Extension

extension LocalizationManager {
    
    /// Cached localization string cache
    private static let stringCache = LocalizationStringCache()
    
    /// Get localized string with caching
    /// - Parameters:
    ///   - key: Localization key
    ///   - language: Target language
    ///   - fallbackValue: Fallback value if not found
    /// - Returns: Cached or newly retrieved localized string
    public func cachedLocalizedString(for key: String, language: SupportedLanguage? = nil, fallbackValue: String? = nil) -> String {
        let targetLanguage = language ?? currentLanguage
        let cacheKey = "\(targetLanguage.languageCode):\(key)"
        
        // Try to get from cache first
        if let cachedValue = Self.stringCache.getValue(for: cacheKey) {
            return cachedValue
        }
        
        // Get from localization system
        let localizedValue = localizedString(for: key, language: targetLanguage, fallbackValue: fallbackValue)
        
        // Cache the result
        Self.stringCache.setValue(localizedValue, for: cacheKey)
        
        return localizedValue
    }
    
    /// Preload commonly used strings into cache
    /// - Parameter keys: Array of keys to preload
    public func preloadStringsToCache(_ keys: [String]) {
        for key in keys {
            for language in SupportedLanguage.allCases {
                let _ = cachedLocalizedString(for: key, language: language)
            }
        }
    }
    
    /// Clear localization string cache
    public func clearStringCache() {
        Self.stringCache.clearAll()
    }
    
    /// Get cache statistics
    /// - Returns: Cache performance statistics
    public func getCacheStatistics() -> LocalizationCacheStatistics {
        return Self.stringCache.getStatistics()
    }
    
    /// Get estimated cache memory usage
    /// - Returns: Estimated memory usage in bytes
    public func getCacheMemoryUsage() -> Int {
        return Self.stringCache.getEstimatedMemoryUsage()
    }
}