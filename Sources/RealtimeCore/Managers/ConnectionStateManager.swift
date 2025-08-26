import Foundation
import Network

/// Manager for handling connection state and automatic reconnection
/// 需求: 13.2, 13.3, 17.6 - 连接状态管理和自动重连机制
@MainActor
public class ConnectionStateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var networkStatus: NetworkStatus = .unknown
    @Published public private(set) var reconnectionAttempts: Int = 0
    @Published public private(set) var lastConnectionError: RealtimeError?
    @Published public private(set) var connectionHistory: [ConnectionEvent] = []
    @Published public private(set) var isAutoReconnectEnabled: Bool = true
    
    // MARK: - Configuration
    public struct ReconnectionConfig: Sendable {
        let maxReconnectionAttempts: Int
        let baseReconnectionDelay: TimeInterval
        let maxReconnectionDelay: TimeInterval
        let exponentialBackoffMultiplier: Double
        let networkMonitoringEnabled: Bool
        let connectionTimeoutInterval: TimeInterval
        
        public init(
            maxReconnectionAttempts: Int = 5,
            baseReconnectionDelay: TimeInterval = 2.0,
            maxReconnectionDelay: TimeInterval = 30.0,
            exponentialBackoffMultiplier: Double = 2.0,
            networkMonitoringEnabled: Bool = true,
            connectionTimeoutInterval: TimeInterval = 10.0
        ) {
            self.maxReconnectionAttempts = maxReconnectionAttempts
            self.baseReconnectionDelay = baseReconnectionDelay
            self.maxReconnectionDelay = maxReconnectionDelay
            self.exponentialBackoffMultiplier = exponentialBackoffMultiplier
            self.networkMonitoringEnabled = networkMonitoringEnabled
            self.connectionTimeoutInterval = connectionTimeoutInterval
        }
        
        public static let `default` = ReconnectionConfig()
    }
    
    // MARK: - Private Properties
    private let config: ReconnectionConfig
    private let networkMonitor: NWPathMonitor
    private let networkQueue = DispatchQueue(label: "RealtimeKit.NetworkMonitor")
    private var reconnectionTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    
    // MARK: - Callbacks
    public var onConnectionStateChanged: ((ConnectionState, ConnectionState) -> Void)?
    public var onNetworkStatusChanged: ((NetworkStatus) -> Void)?
    public var onReconnectionStarted: ((Int) -> Void)?
    public var onReconnectionSucceeded: ((Int) -> Void)?
    public var onReconnectionFailed: ((Int, RealtimeError) -> Void)?
    public var onReconnectionExhausted: ((Int) -> Void)?
    public var onConnectionTimeout: (() -> Void)?
    
    // MARK: - Initialization
    public init(config: ReconnectionConfig = .default) {
        self.config = config
        self.networkMonitor = NWPathMonitor()
        
        if config.networkMonitoringEnabled {
            setupNetworkMonitoring()
        }
    }
    
    deinit {
        networkMonitor.cancel()
        reconnectionTask?.cancel()
        connectionTimeoutTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Update the connection state
    /// - Parameter newState: The new connection state
    public func updateConnectionState(_ newState: ConnectionState) {
        let oldState = connectionState
        connectionState = newState
        
        recordConnectionEvent(
            state: newState,
            previousState: oldState,
            error: lastConnectionError
        )
        
        onConnectionStateChanged?(oldState, newState)
        
        // Handle state-specific logic
        switch newState {
        case .connected:
            handleConnectionEstablished()
        case .disconnected:
            handleConnectionLost()
        case .failed:
            handleConnectionFailed()
        case .connecting:
            startConnectionTimeout()
        case .reconnecting:
            // Reconnection logic is handled separately
            break
        case .suspended:
            // Handle suspended state
            break
        }
    }
    
    /// Set the last connection error
    /// - Parameter error: The error that caused connection issues
    public func setLastConnectionError(_ error: RealtimeError?) {
        lastConnectionError = error
    }
    
    /// Start automatic reconnection process
    /// - Parameter operation: The connection operation to retry
    public func startReconnection(operation: @escaping () async throws -> Void) {
        guard isAutoReconnectEnabled else { return }
        guard connectionState == .disconnected || connectionState == .failed else { return }
        
        // Cancel any existing reconnection task
        reconnectionTask?.cancel()
        
        reconnectionTask = Task {
            await performReconnection(operation: operation)
        }
    }
    
    /// Stop automatic reconnection
    public func stopReconnection() {
        reconnectionTask?.cancel()
        reconnectionTask = nil
        
        if connectionState == .reconnecting {
            updateConnectionState(.disconnected)
        }
    }
    
    /// Enable or disable automatic reconnection
    /// - Parameter enabled: Whether to enable automatic reconnection
    public func setAutoReconnectEnabled(_ enabled: Bool) {
        isAutoReconnectEnabled = enabled
        
        if !enabled {
            stopReconnection()
        }
    }
    
    /// Force a reconnection attempt
    /// - Parameter operation: The connection operation to retry
    public func forceReconnection(operation: @escaping () async throws -> Void) async {
        stopReconnection()
        reconnectionAttempts = 0
        await performReconnection(operation: operation)
    }
    
    /// Get connection statistics
    /// - Returns: Connection statistics
    public func getConnectionStats() -> ConnectionStats {
        let totalConnections = connectionHistory.filter { $0.state == .connected }.count
        let totalDisconnections = connectionHistory.filter { $0.state == .disconnected }.count
        let totalFailures = connectionHistory.filter { $0.state == .failed }.count
        
        let connectionDurations = calculateConnectionDurations()
        let averageConnectionDuration = connectionDurations.isEmpty ? 0 : connectionDurations.reduce(0, +) / Double(connectionDurations.count)
        
        return ConnectionStats(
            currentState: connectionState,
            networkStatus: networkStatus,
            totalConnections: totalConnections,
            totalDisconnections: totalDisconnections,
            totalFailures: totalFailures,
            reconnectionAttempts: reconnectionAttempts,
            averageConnectionDuration: averageConnectionDuration,
            lastConnectionTime: connectionHistory.last { $0.state == .connected }?.timestamp,
            lastDisconnectionTime: connectionHistory.last { $0.state == .disconnected }?.timestamp
        )
    }
    
    /// Clear connection history older than specified time interval
    /// - Parameter olderThan: Time interval to keep history for
    public func clearOldConnectionHistory(olderThan: TimeInterval) {
        let cutoffDate = Date().addingTimeInterval(-olderThan)
        connectionHistory.removeAll { $0.timestamp < cutoffDate }
    }
    
    /// Get localized connection state description
    /// - Returns: Localized description of current connection state
    public func getLocalizedStateDescription() -> String {
        return ErrorLocalizationHelper.getLocalizedString(
            for: "connection.state.\(connectionState.rawValue)",
            fallbackValue: connectionState.displayName
        )
    }
    
    /// Get localized network status description
    /// - Returns: Localized description of current network status
    public func getLocalizedNetworkStatusDescription() -> String {
        return ErrorLocalizationHelper.getLocalizedString(
            for: "network.status.\(networkStatus.rawValue)",
            fallbackValue: networkStatus.displayName
        )
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.handleNetworkPathUpdate(path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) async {
        let newStatus: NetworkStatus
        
        switch path.status {
        case .satisfied:
            if path.isExpensive {
                newStatus = .cellular
            } else {
                newStatus = .wifi
            }
        case .unsatisfied:
            newStatus = .unavailable
        case .requiresConnection:
            newStatus = .limited
        @unknown default:
            newStatus = .unknown
        }
        
        let oldStatus = networkStatus
        networkStatus = newStatus
        
        if oldStatus != newStatus {
            onNetworkStatusChanged?(newStatus)
            
            // Handle network status changes
            switch newStatus {
            case .unavailable:
                if connectionState == .connected {
                    setLastConnectionError(.networkUnavailable)
                    updateConnectionState(.disconnected)
                }
            case .wifi, .cellular, .limited:
                if connectionState == .disconnected && oldStatus == .unavailable {
                    // Network became available, attempt reconnection
                    if isAutoReconnectEnabled {
                        // This would need to be called with the appropriate connection operation
                        // The actual implementation would depend on the specific use case
                    }
                }
            case .unknown:
                break
            }
        }
    }
    
    private func handleConnectionEstablished() {
        reconnectionAttempts = 0
        lastConnectionError = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
    }
    
    private func handleConnectionLost() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        
        // Start reconnection if enabled and network is available
        if isAutoReconnectEnabled && networkStatus != .unavailable {
            // Reconnection would be started by the caller with the appropriate operation
        }
    }
    
    private func handleConnectionFailed() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        
        // Start reconnection if enabled
        if isAutoReconnectEnabled {
            // Reconnection would be started by the caller with the appropriate operation
        }
    }
    
    private func startConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        
        connectionTimeoutTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(config.connectionTimeoutInterval * 1_000_000_000))
                
                // If still connecting after timeout, mark as failed
                if connectionState == .connecting {
                    setLastConnectionError(.connectionTimeout)
                    updateConnectionState(.failed)
                    onConnectionTimeout?()
                }
            } catch {
                // Task was cancelled, which is expected when connection succeeds
            }
        }
    }
    
    private func performReconnection(operation: @escaping () async throws -> Void) async {
        guard isAutoReconnectEnabled else { return }
        
        while reconnectionAttempts < config.maxReconnectionAttempts {
            reconnectionAttempts += 1
            updateConnectionState(.reconnecting)
            
            onReconnectionStarted?(reconnectionAttempts)
            
            // Calculate delay with exponential backoff
            let delay = calculateReconnectionDelay(attemptNumber: reconnectionAttempts)
            
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                // Task was cancelled
                return
            }
            
            // Check if network is available
            if networkStatus == .unavailable {
                setLastConnectionError(.networkUnavailable)
                onReconnectionFailed?(reconnectionAttempts, .networkUnavailable)
                continue
            }
            
            // Attempt reconnection
            do {
                try await operation()
                
                // Success
                onReconnectionSucceeded?(reconnectionAttempts)
                return
                
            } catch let error {
                let realtimeError = error as? RealtimeError ?? RealtimeError.connectionFailed(reason: error.localizedDescription)
                setLastConnectionError(realtimeError)
                onReconnectionFailed?(reconnectionAttempts, realtimeError)
                
                // Check if error is recoverable
                if !realtimeError.isRecoverable {
                    break
                }
            }
        }
        
        // Exhausted all attempts
        updateConnectionState(.failed)
        onReconnectionExhausted?(reconnectionAttempts)
    }
    
    private func calculateReconnectionDelay(attemptNumber: Int) -> TimeInterval {
        let exponentialDelay = config.baseReconnectionDelay * pow(config.exponentialBackoffMultiplier, Double(attemptNumber - 1))
        return min(exponentialDelay, config.maxReconnectionDelay)
    }
    
    private func recordConnectionEvent(
        state: ConnectionState,
        previousState: ConnectionState?,
        error: RealtimeError?
    ) {
        let event = ConnectionEvent(
            state: state,
            previousState: previousState,
            timestamp: Date(),
            error: error,
            networkStatus: networkStatus,
            reconnectionAttempt: state == .reconnecting ? reconnectionAttempts : nil
        )
        
        connectionHistory.append(event)
        
        // Keep only recent history to prevent memory growth
        if connectionHistory.count > 1000 {
            connectionHistory.removeFirst(connectionHistory.count - 1000)
        }
    }
    
    private func calculateConnectionDurations() -> [TimeInterval] {
        var durations: [TimeInterval] = []
        var connectionStartTime: Date?
        
        for event in connectionHistory {
            switch event.state {
            case .connected:
                connectionStartTime = event.timestamp
            case .disconnected, .failed:
                if let startTime = connectionStartTime {
                    durations.append(event.timestamp.timeIntervalSince(startTime))
                    connectionStartTime = nil
                }
            default:
                break
            }
        }
        
        return durations
    }
}

// MARK: - Supporting Types

/// Network status enumeration
public enum NetworkStatus: String, CaseIterable, Sendable {
    case unknown = "unknown"
    case unavailable = "unavailable"
    case wifi = "wifi"
    case cellular = "cellular"
    case limited = "limited"
    
    public var displayName: String {
        switch self {
        case .unknown:
            return "未知"
        case .unavailable:
            return "网络不可用"
        case .wifi:
            return "WiFi"
        case .cellular:
            return "蜂窝网络"
        case .limited:
            return "受限网络"
        }
    }
    
    public var isConnected: Bool {
        switch self {
        case .wifi, .cellular, .limited:
            return true
        case .unknown, .unavailable:
            return false
        }
    }
}

/// Connection event for history tracking
public struct ConnectionEvent: Identifiable, Sendable {
    public let id = UUID()
    public let state: ConnectionState
    public let previousState: ConnectionState?
    public let timestamp: Date
    public let error: RealtimeError?
    public let networkStatus: NetworkStatus
    public let reconnectionAttempt: Int?
}

/// Connection statistics
public struct ConnectionStats: Sendable {
    public let currentState: ConnectionState
    public let networkStatus: NetworkStatus
    public let totalConnections: Int
    public let totalDisconnections: Int
    public let totalFailures: Int
    public let reconnectionAttempts: Int
    public let averageConnectionDuration: TimeInterval
    public let lastConnectionTime: Date?
    public let lastDisconnectionTime: Date?
    
    public var connectionSuccessRate: Double {
        let totalAttempts = totalConnections + totalFailures
        guard totalAttempts > 0 else { return 0.0 }
        return Double(totalConnections) / Double(totalAttempts)
    }
    
    public var averageReconnectionTime: TimeInterval {
        guard reconnectionAttempts > 0 else { return 0.0 }
        // This would need to be calculated based on actual reconnection timing data
        // For now, return an estimated value
        return 5.0 * Double(reconnectionAttempts)
    }
}

// MARK: - Connection State Extensions

extension ConnectionState {
    
    /// Check if the connection state allows for operations
    public var isOperational: Bool {
        switch self {
        case .connected:
            return true
        case .disconnected, .connecting, .reconnecting, .failed, .suspended:
            return false
        }
    }
    
    /// Check if the connection state indicates a problem
    public var hasError: Bool {
        switch self {
        case .failed:
            return true
        case .disconnected, .connecting, .connected, .reconnecting, .suspended:
            return false
        }
    }
    
    /// Get the localized description for the connection state
    public func getLocalizedDescription() -> String {
        return ErrorLocalizationHelper.getLocalizedString(
            for: "connection.state.\(self.rawValue)",
            fallbackValue: self.displayName
        )
    }
}

// MARK: - Network Status Extensions

extension NetworkStatus {
    
    /// Get the localized description for the network status
    public func getLocalizedDescription() -> String {
        return ErrorLocalizationHelper.getLocalizedString(
            for: "network.status.\(self.rawValue)",
            fallbackValue: self.displayName
        )
    }
    
    /// Check if the network status is suitable for real-time communication
    public var isSuitableForRealtime: Bool {
        switch self {
        case .wifi:
            return true
        case .cellular:
            return true // May want to add configuration for this
        case .limited:
            return false
        case .unknown, .unavailable:
            return false
        }
    }
}