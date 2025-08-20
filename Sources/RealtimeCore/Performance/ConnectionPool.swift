// ConnectionPool.swift
// Connection pool for network optimization

import Foundation
import Network

/// Connection pool for managing network connections efficiently
public final class ConnectionPool: ObservableObject, @unchecked Sendable {
    
    @Published public private(set) var activeConnections: Int = 0
    @Published public private(set) var availableConnections: Int = 0
    @Published public private(set) var totalConnectionsCreated: Int = 0
    
    private let maxConnections: Int
    private let connectionTimeout: TimeInterval
    private var connections: [PooledConnection] = []
    private var connectionQueue = DispatchQueue(label: "com.realtimekit.connectionpool", attributes: .concurrent)
    private let semaphore: DispatchSemaphore
    
    /// Initialize connection pool
    /// - Parameters:
    ///   - maxConnections: Maximum number of connections to maintain
    ///   - connectionTimeout: Timeout for idle connections
    public init(maxConnections: Int = 10, connectionTimeout: TimeInterval = 300) {
        self.maxConnections = maxConnections
        self.connectionTimeout = connectionTimeout
        self.semaphore = DispatchSemaphore(value: maxConnections)
        
        startConnectionCleanupTimer()
    }
    
    /// Borrow a connection from the pool
    /// - Parameter endpoint: Network endpoint to connect to
    /// - Returns: Pooled connection
    public func borrowConnection(for endpoint: NWEndpoint) async throws -> PooledConnection {
        // Wait for available connection slot
        _ = await withCheckedContinuation { continuation in
            connectionQueue.async {
                self.semaphore.wait()
                continuation.resume()
            }
        }
        
        return await withCheckedContinuation { continuation in
            connectionQueue.async(flags: .barrier) {
                // Try to find existing connection for endpoint
                if let existingIndex = self.connections.firstIndex(where: { 
                    $0.endpoint == endpoint && !$0.isInUse && $0.isConnected 
                }) {
                    let connection = self.connections[existingIndex]
                    connection.markAsInUse()
                    
                    Task { @MainActor in
                        self.activeConnections += 1
                        self.availableConnections -= 1
                    }
                    
                    continuation.resume(returning: connection)
                    return
                }
                
                // Create new connection
                let connection = PooledConnection(endpoint: endpoint, pool: self)
                self.connections.append(connection)
                connection.markAsInUse()
                
                Task { @MainActor in
                    self.totalConnectionsCreated += 1
                    self.activeConnections += 1
                }
                
                continuation.resume(returning: connection)
            }
        }
    }
    
    /// Return a connection to the pool
    /// - Parameter connection: Connection to return
    public func returnConnection(_ connection: PooledConnection) async {
        connectionQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            connection.markAsAvailable()
            
            Task { @MainActor in
                self.activeConnections -= 1
                self.availableConnections += 1
            }
            
            self.semaphore.signal()
        }
    }
    
    /// Close and remove a connection from the pool
    /// - Parameter connection: Connection to remove
    internal func removeConnection(_ connection: PooledConnection) async {
        connectionQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let index = self.connections.firstIndex(where: { $0 === connection }) {
                self.connections.remove(at: index)
            }
            
            Task { @MainActor in
                if connection.isInUse {
                    self.activeConnections -= 1
                } else {
                    self.availableConnections -= 1
                }
            }
            
            if connection.isInUse {
                self.semaphore.signal()
            }
        }
    }
    
    /// Start timer for cleaning up idle connections
    private func startConnectionCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.cleanupIdleConnections()
            }
        }
    }
    
    /// Clean up idle connections that have exceeded timeout
    private func cleanupIdleConnections() async {
        let now = Date()
        
        await withCheckedContinuation { continuation in
            connectionQueue.async(flags: .barrier) {
                let connectionsToRemove = self.connections.filter { connection in
                    !connection.isInUse && 
                    now.timeIntervalSince(connection.lastUsed) > self.connectionTimeout
                }
                
                for connection in connectionsToRemove {
                    connection.close()
                    if let index = self.connections.firstIndex(where: { $0 === connection }) {
                        self.connections.remove(at: index)
                    }
                }
                
                Task { @MainActor in
                    self.availableConnections -= connectionsToRemove.count
                }
                
                continuation.resume()
            }
        }
    }
    
    /// Get connection pool statistics
    /// - Returns: Pool statistics
    public func getStatistics() -> ConnectionPoolStatistics {
        return ConnectionPoolStatistics(
            maxConnections: maxConnections,
            activeConnections: activeConnections,
            availableConnections: availableConnections,
            totalConnectionsCreated: totalConnectionsCreated,
            utilizationPercentage: Double(activeConnections) / Double(maxConnections) * 100.0
        )
    }
    
    /// Close all connections and clean up
    public func shutdown() async {
        await withCheckedContinuation { continuation in
            connectionQueue.async(flags: .barrier) {
                for connection in self.connections {
                    connection.close()
                }
                self.connections.removeAll()
                
                Task { @MainActor in
                    self.activeConnections = 0
                    self.availableConnections = 0
                }
                
                continuation.resume()
            }
        }
    }
}

/// Pooled network connection wrapper
public final class PooledConnection: @unchecked Sendable {
    public let endpoint: NWEndpoint
    public private(set) var isInUse: Bool = false
    public private(set) var lastUsed: Date = Date()
    public private(set) var isConnected: Bool = false
    
    private weak var pool: ConnectionPool?
    private var connection: NWConnection?
    private let connectionQueue = DispatchQueue(label: "com.realtimekit.pooledconnection")
    
    /// Initialize pooled connection
    /// - Parameters:
    ///   - endpoint: Network endpoint
    ///   - pool: Parent connection pool
    internal init(endpoint: NWEndpoint, pool: ConnectionPool) {
        self.endpoint = endpoint
        self.pool = pool
        
        setupConnection()
    }
    
    /// Setup the underlying network connection
    private func setupConnection() {
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
            case .failed(_), .cancelled:
                self?.isConnected = false
                self?.handleConnectionFailure()
            default:
                break
            }
        }
        
        connection?.start(queue: connectionQueue)
    }
    
    /// Handle connection failure
    private func handleConnectionFailure() {
        Task { @MainActor in
            await pool?.removeConnection(self)
        }
    }
    
    /// Mark connection as in use
    internal func markAsInUse() {
        isInUse = true
        lastUsed = Date()
    }
    
    /// Mark connection as available
    internal func markAsAvailable() {
        isInUse = false
        lastUsed = Date()
    }
    
    /// Send data through the connection
    /// - Parameter data: Data to send
    public func send(_ data: Data) async throws {
        guard let connection = connection, isConnected else {
            throw NetworkError.connectionNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    /// Receive data from the connection
    /// - Parameter maxLength: Maximum length of data to receive
    /// - Returns: Received data
    public func receive(maxLength: Int = 65536) async throws -> Data {
        guard let connection = connection, isConnected else {
            throw NetworkError.connectionNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NetworkError.noDataReceived)
                }
            }
        }
    }
    
    /// Close the connection
    internal func close() {
        connection?.cancel()
        isConnected = false
    }
    
    /// Return connection to pool when done
    public func returnToPool() {
        Task { @MainActor in
            await pool?.returnConnection(self)
        }
    }
}

/// Connection pool statistics
public struct ConnectionPoolStatistics {
    public let maxConnections: Int
    public let activeConnections: Int
    public let availableConnections: Int
    public let totalConnectionsCreated: Int
    public let utilizationPercentage: Double
    
    public var efficiency: Double {
        guard totalConnectionsCreated > 0 else { return 100.0 }
        let reusedConnections = max(0, totalConnectionsCreated - maxConnections)
        return Double(reusedConnections) / Double(totalConnectionsCreated) * 100.0
    }
}

/// Network errors
public enum NetworkError: Error, LocalizedError {
    case connectionNotAvailable
    case noDataReceived
    case connectionTimeout
    
    public var errorDescription: String? {
        switch self {
        case .connectionNotAvailable:
            return "Connection is not available"
        case .noDataReceived:
            return "No data received from connection"
        case .connectionTimeout:
            return "Connection timed out"
        }
    }
}