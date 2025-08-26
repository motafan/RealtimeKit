import Foundation
import Network

/// Connection pool for managing network connections efficiently
/// 需求: 14.2 - 实现连接池和数据压缩优化
public final class ConnectionPool: @unchecked Sendable {
    
    // MARK: - Connection Info
    
    private struct ConnectionInfo {
        let connection: NWConnection
        let creationTime: Date
        let lastUsedTime: Date
        var isInUse: Bool
        let connectionId: String
        
        func withUpdatedLastUsed() -> ConnectionInfo {
            return ConnectionInfo(
                connection: connection,
                creationTime: creationTime,
                lastUsedTime: Date(),
                isInUse: isInUse,
                connectionId: connectionId
            )
        }
        
        func withUsageState(_ inUse: Bool) -> ConnectionInfo {
            return ConnectionInfo(
                connection: connection,
                creationTime: creationTime,
                lastUsedTime: lastUsedTime,
                isInUse: inUse,
                connectionId: connectionId
            )
        }
        
        var age: TimeInterval {
            return Date().timeIntervalSince(creationTime)
        }
        
        var idleTime: TimeInterval {
            return Date().timeIntervalSince(lastUsedTime)
        }
    }
    
    // MARK: - Properties
    
    private var connections: [String: ConnectionInfo] = [:]
    private let connectionQueue = DispatchQueue(label: "com.realtimekit.connectionpool", attributes: .concurrent)
    private let maxPoolSize: Int
    private let maxIdleTime: TimeInterval
    private let maxConnectionAge: TimeInterval
    private var cleanupTimer: Timer?
    
    // MARK: - Statistics
    
    private var totalConnectionsCreated: Int = 0
    private var totalConnectionsReused: Int = 0
    private var totalConnectionsClosed: Int = 0
    
    // MARK: - Initialization
    
    /// Initialize connection pool
    /// - Parameters:
    ///   - maxPoolSize: Maximum number of connections to maintain
    ///   - maxIdleTime: Maximum idle time before closing connection
    ///   - maxConnectionAge: Maximum age of a connection before renewal
    public init(
        maxPoolSize: Int = 10,
        maxIdleTime: TimeInterval = 300, // 5 minutes
        maxConnectionAge: TimeInterval = 3600 // 1 hour
    ) {
        self.maxPoolSize = maxPoolSize
        self.maxIdleTime = maxIdleTime
        self.maxConnectionAge = maxConnectionAge
        
        startPeriodicCleanup()
    }
    
    deinit {
        stopPeriodicCleanup()
        closeAllConnections()
    }
    
    // MARK: - Connection Management
    
    /// Get a connection from the pool or create a new one
    /// - Parameters:
    ///   - host: Target host
    ///   - port: Target port
    ///   - useTLS: Whether to use TLS
    /// - Returns: Network connection
    public func getConnection(host: String, port: UInt16, useTLS: Bool = true) -> NWConnection {
        let connectionKey = "\(host):\(port):\(useTLS)"
        
        return connectionQueue.sync {
            // Try to find an available connection
            if let connectionInfo = connections[connectionKey],
               !connectionInfo.isInUse,
               connectionInfo.connection.state == .ready,
               connectionInfo.idleTime < maxIdleTime,
               connectionInfo.age < maxConnectionAge {
                
                // Mark as in use and update last used time
                connections[connectionKey] = connectionInfo
                    .withUsageState(true)
                    .withUpdatedLastUsed()
                
                totalConnectionsReused += 1
                return connectionInfo.connection
            }
            
            // Create new connection
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: port)
            )
            
            let parameters: NWParameters
            if useTLS {
                parameters = .tls
            } else {
                parameters = .tcp
            }
            
            let connection = NWConnection(to: endpoint, using: parameters)
            let connectionId = UUID().uuidString
            
            let connectionInfo = ConnectionInfo(
                connection: connection,
                creationTime: Date(),
                lastUsedTime: Date(),
                isInUse: true,
                connectionId: connectionId
            )
            
            connections[connectionKey] = connectionInfo
            totalConnectionsCreated += 1
            
            // Start the connection
            connection.start(queue: .global(qos: .userInitiated))
            
            return connection
        }
    }
    
    /// Return a connection to the pool
    /// - Parameters:
    ///   - connection: Connection to return
    ///   - host: Target host
    ///   - port: Target port
    ///   - useTLS: Whether connection uses TLS
    public func returnConnection(_ connection: NWConnection, host: String, port: UInt16, useTLS: Bool = true) {
        let connectionKey = "\(host):\(port):\(useTLS)"
        
        connectionQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let connectionInfo = self.connections[connectionKey],
               connectionInfo.connection === connection {
                
                // Mark as not in use and update last used time
                self.connections[connectionKey] = connectionInfo
                    .withUsageState(false)
                    .withUpdatedLastUsed()
            }
        }
    }
    
    /// Close a specific connection
    /// - Parameters:
    ///   - host: Target host
    ///   - port: Target port
    ///   - useTLS: Whether connection uses TLS
    public func closeConnection(host: String, port: UInt16, useTLS: Bool = true) {
        let connectionKey = "\(host):\(port):\(useTLS)"
        
        connectionQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let connectionInfo = self.connections.removeValue(forKey: connectionKey) {
                connectionInfo.connection.cancel()
                self.totalConnectionsClosed += 1
            }
        }
    }
    
    /// Close all connections in the pool
    public func closeAllConnections() {
        connectionQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            for (_, connectionInfo) in self.connections {
                connectionInfo.connection.cancel()
                self.totalConnectionsClosed += 1
            }
            
            self.connections.removeAll()
        }
    }
    
    // MARK: - Pool Maintenance
    
    /// Start periodic cleanup of idle and old connections
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    /// Stop periodic cleanup
    private func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    /// Manually trigger cleanup of idle and old connections
    public func performCleanup() {
        connectionQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let _ = Date()
            var connectionsToRemove: [String] = []
            
            for (key, connectionInfo) in self.connections {
                let shouldRemove = !connectionInfo.isInUse && (
                    connectionInfo.idleTime > self.maxIdleTime ||
                    connectionInfo.age > self.maxConnectionAge ||
                    connectionInfo.connection.state != .ready
                )
                
                if shouldRemove {
                    connectionsToRemove.append(key)
                    connectionInfo.connection.cancel()
                    self.totalConnectionsClosed += 1
                }
            }
            
            for key in connectionsToRemove {
                self.connections.removeValue(forKey: key)
            }
            
            if !connectionsToRemove.isEmpty {
                print("ConnectionPool: Cleaned up \(connectionsToRemove.count) connections")
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Get connection pool statistics
    /// - Returns: Pool usage statistics
    public func getStatistics() -> ConnectionPoolStatistics {
        return connectionQueue.sync {
            let activeConnections = connections.values.filter { $0.isInUse }.count
            let idleConnections = connections.values.filter { !$0.isInUse }.count
            let totalConnections = connections.count
            
            return ConnectionPoolStatistics(
                totalConnections: totalConnections,
                activeConnections: activeConnections,
                idleConnections: idleConnections,
                maxPoolSize: maxPoolSize,
                totalCreated: totalConnectionsCreated,
                totalReused: totalConnectionsReused,
                totalClosed: totalConnectionsClosed,
                reuseRate: totalConnectionsCreated > 0 ? Double(totalConnectionsReused) / Double(totalConnectionsCreated + totalConnectionsReused) : 0.0
            )
        }
    }
    
    /// Get detailed connection information
    /// - Returns: Array of connection details
    public func getConnectionDetails() -> [ConnectionDetail] {
        return connectionQueue.sync {
            return connections.map { key, info in
                ConnectionDetail(
                    key: key,
                    connectionId: info.connectionId,
                    creationTime: info.creationTime,
                    lastUsedTime: info.lastUsedTime,
                    isInUse: info.isInUse,
                    state: info.connection.state,
                    age: info.age,
                    idleTime: info.idleTime
                )
            }
        }
    }
}

/// Connection pool usage statistics
public struct ConnectionPoolStatistics {
    public let totalConnections: Int
    public let activeConnections: Int
    public let idleConnections: Int
    public let maxPoolSize: Int
    public let totalCreated: Int
    public let totalReused: Int
    public let totalClosed: Int
    public let reuseRate: Double
    
    public var description: String {
        return """
        Connection Pool Statistics:
        - Total Connections: \(totalConnections)/\(maxPoolSize)
        - Active: \(activeConnections), Idle: \(idleConnections)
        - Total Created: \(totalCreated)
        - Total Reused: \(totalReused)
        - Total Closed: \(totalClosed)
        - Reuse Rate: \(String(format: "%.2f%%", reuseRate * 100))
        """
    }
}

/// Detailed connection information
public struct ConnectionDetail {
    public let key: String
    public let connectionId: String
    public let creationTime: Date
    public let lastUsedTime: Date
    public let isInUse: Bool
    public let state: NWConnection.State
    public let age: TimeInterval
    public let idleTime: TimeInterval
    
    public var description: String {
        return """
        Connection: \(key)
        - ID: \(connectionId)
        - State: \(state)
        - In Use: \(isInUse)
        - Age: \(String(format: "%.1f", age))s
        - Idle: \(String(format: "%.1f", idleTime))s
        """
    }
}

// MARK: - Global Connection Pool Manager

/// Global manager for connection pools
public final class ConnectionPoolManager: @unchecked Sendable {
    
    private var pools: [String: ConnectionPool] = [:]
    private let poolQueue = DispatchQueue(label: "com.realtimekit.poolmanager", attributes: .concurrent)
    
    public static let shared = ConnectionPoolManager()
    
    private init() {}
    
    /// Get or create a connection pool for a specific service
    /// - Parameter serviceName: Name of the service
    /// - Returns: Connection pool for the service
    public func getPool(for serviceName: String) -> ConnectionPool {
        return poolQueue.sync {
            if let existingPool = pools[serviceName] {
                return existingPool
            }
            
            let newPool = ConnectionPool()
            pools[serviceName] = newPool
            return newPool
        }
    }
    
    /// Remove a connection pool for a specific service
    /// - Parameter serviceName: Name of the service
    public func removePool(for serviceName: String) {
        poolQueue.async(flags: .barrier) { [weak self] in
            if let pool = self?.pools.removeValue(forKey: serviceName) {
                pool.closeAllConnections()
            }
        }
    }
    
    /// Get statistics for all pools
    /// - Returns: Dictionary of pool statistics
    public func getAllPoolStatistics() -> [String: ConnectionPoolStatistics] {
        return poolQueue.sync {
            var statistics: [String: ConnectionPoolStatistics] = [:]
            
            for (serviceName, pool) in pools {
                statistics[serviceName] = pool.getStatistics()
            }
            
            return statistics
        }
    }
    
    /// Perform cleanup on all pools
    public func performCleanupOnAllPools() {
        poolQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (_, pool) in self.pools {
                pool.performCleanup()
            }
        }
    }
    
    /// Close all pools
    public func closeAllPools() {
        poolQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            for (_, pool) in self.pools {
                pool.closeAllConnections()
            }
            
            self.pools.removeAll()
        }
    }
}
