// ConnectionStateManager.swift
// Connection state management and auto-reconnection for RealtimeKit

import Foundation
import Combine

/// Connection state manager with auto-reconnection capabilities
@MainActor
public class ConnectionStateManager: ObservableObject {
    @Published public private(set) var rtcConnectionState: ConnectionState = .disconnected
    @Published public private(set) var rtmConnectionState: ConnectionState = .disconnected
    @Published public private(set) var overallConnectionState: ConnectionState = .disconnected
    @Published public private(set) var reconnectionAttempts: Int = 0
    @Published public private(set) var lastConnectionError: RealtimeError?
    @Published public private(set) var connectionHistory: [ConnectionEvent] = []
    
    // Configuration
    public var maxReconnectionAttempts: Int = 5
    public var baseReconnectionDelay: TimeInterval = 2.0
    public var maxReconnectionDelay: TimeInterval = 30.0
    public var reconnectionBackoffMultiplier: Double = 2.0
    public var connectionTimeout: TimeInterval = 10.0
    public var isAutoReconnectionEnabled: Bool = true
    
    // Private properties
    private var reconnectionTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var networkMonitor: NetworkMonitor?
    private let maxHistoryCount = 100
    
    // Callbacks
    public var onConnectionStateChanged: ((ConnectionState, ConnectionState) -> Void)?
    public var onReconnectionAttempt: ((Int) -> Void)?
    public var onReconnectionSuccess: (() -> Void)?
    public var onReconnectionFailed: ((RealtimeError) -> Void)?
    
    public init() {
        setupNetworkMonitoring()
        updateOverallConnectionState()
    }
    
    deinit {
        // Cancel tasks synchronously in deinit
        reconnectionTask?.cancel()
        connectionTimeoutTask?.cancel()
        networkMonitor?.stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Update RTC connection state
    public func updateRTCConnectionState(_ newState: ConnectionState) {
        let oldState = rtcConnectionState
        rtcConnectionState = newState
        
        recordConnectionEvent(.rtcStateChanged(from: oldState, to: newState))
        updateOverallConnectionState()
        
        handleConnectionStateChange(from: oldState, to: newState, type: .rtc)
    }
    
    /// Update RTM connection state
    public func updateRTMConnectionState(_ newState: ConnectionState) {
        let oldState = rtmConnectionState
        rtmConnectionState = newState
        
        recordConnectionEvent(.rtmStateChanged(from: oldState, to: newState))
        updateOverallConnectionState()
        
        handleConnectionStateChange(from: oldState, to: newState, type: .rtm)
    }
    
    /// Manually trigger reconnection
    public func reconnect() async {
        guard !isReconnecting else { return }
        
        await startReconnection()
    }
    
    /// Cancel ongoing reconnection attempts
    public func cancelReconnection() {
        reconnectionTask?.cancel()
        reconnectionTask = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        
        if overallConnectionState == .reconnecting {
            updateOverallConnectionState()
        }
    }
    
    /// Reset connection state and attempts
    public func reset() {
        cancelReconnection()
        reconnectionAttempts = 0
        lastConnectionError = nil
        rtcConnectionState = .disconnected
        rtmConnectionState = .disconnected
        updateOverallConnectionState()
    }
    
    /// Check if currently reconnecting
    public var isReconnecting: Bool {
        return overallConnectionState == .reconnecting || reconnectionTask != nil
    }
    
    /// Check if connected
    public var isConnected: Bool {
        return overallConnectionState == .connected
    }
    
    /// Get connection statistics
    public var connectionStats: ConnectionStatistics {
        return ConnectionStatistics(
            totalConnections: connectionHistory.filter { 
                if case .connected = $0.eventType { return true }
                return false
            }.count,
            totalDisconnections: connectionHistory.filter {
                if case .disconnected = $0.eventType { return true }
                return false
            }.count,
            totalReconnectionAttempts: connectionHistory.filter {
                if case .reconnectionAttempt = $0.eventType { return true }
                return false
            }.count,
            averageConnectionDuration: calculateAverageConnectionDuration(),
            lastConnectionTime: connectionHistory.last?.timestamp
        )
    }
    
    // MARK: - Private Methods
    
    private func updateOverallConnectionState() {
        let oldState = overallConnectionState
        let newState = calculateOverallConnectionState()
        
        if oldState != newState {
            overallConnectionState = newState
            onConnectionStateChanged?(oldState, newState)
            
            recordConnectionEvent(.overallStateChanged(from: oldState, to: newState))
            
            // Handle state-specific logic
            switch newState {
            case .connected:
                handleConnectionEstablished()
            case .disconnected, .failed:
                handleConnectionLost()
            case .connecting:
                startConnectionTimeout()
            case .reconnecting:
                break // Handled separately
            }
        }
    }
    
    private func calculateOverallConnectionState() -> ConnectionState {
        // If reconnection is in progress, return reconnecting
        if reconnectionTask != nil {
            return .reconnecting
        }
        
        // Both must be connected for overall connected state
        if rtcConnectionState == .connected && rtmConnectionState == .connected {
            return .connected
        }
        
        // If either is connecting, overall is connecting
        if rtcConnectionState == .connecting || rtmConnectionState == .connecting {
            return .connecting
        }
        
        // If either failed, overall is failed
        if rtcConnectionState == .failed || rtmConnectionState == .failed {
            return .failed
        }
        
        // Default to disconnected
        return .disconnected
    }
    
    private func handleConnectionStateChange(
        from oldState: ConnectionState,
        to newState: ConnectionState,
        type: ConnectionType
    ) {
        switch newState {
        case .connected:
            if oldState != .connected {
                recordConnectionEvent(.connected(type: type))
            }
        case .disconnected:
            if oldState == .connected {
                recordConnectionEvent(.disconnected(type: type, reason: "Normal disconnection"))
            }
        case .failed:
            recordConnectionEvent(.connectionFailed(type: type, error: lastConnectionError))
            if isAutoReconnectionEnabled && !isReconnecting {
                Task {
                    await startReconnection()
                }
            }
        case .connecting:
            recordConnectionEvent(.connecting(type: type))
        case .reconnecting:
            break // Handled by reconnection logic
        }
    }
    
    private func handleConnectionEstablished() {
        // Reset reconnection attempts on successful connection
        reconnectionAttempts = 0
        lastConnectionError = nil
        cancelReconnection()
        
        onReconnectionSuccess?()
        recordConnectionEvent(.reconnectionSuccess)
    }
    
    private func handleConnectionLost() {
        // Connection lost, prepare for potential reconnection
        if isAutoReconnectionEnabled && !isReconnecting {
            Task {
                await startReconnection()
            }
        }
    }
    
    private func startReconnection() async {
        guard isAutoReconnectionEnabled else { return }
        guard reconnectionAttempts < maxReconnectionAttempts else {
            recordConnectionEvent(.reconnectionGiveUp(attempts: reconnectionAttempts))
            return
        }
        
        reconnectionTask = Task {
            await performReconnection()
        }
    }
    
    private func performReconnection() async {
        while reconnectionAttempts < maxReconnectionAttempts && !Task.isCancelled {
            reconnectionAttempts += 1
            
            recordConnectionEvent(.reconnectionAttempt(attempt: reconnectionAttempts))
            onReconnectionAttempt?(reconnectionAttempts)
            
            // Calculate delay with exponential backoff
            let delay = calculateReconnectionDelay()
            
            // Wait before attempting reconnection
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            guard !Task.isCancelled else { break }
            
            // Attempt reconnection
            do {
                let success = try await attemptReconnection()
                if success {
                    return // Reconnection successful
                }
            } catch {
                let realtimeError = error as? RealtimeError ?? .connectionFailed(error.localizedDescription)
                lastConnectionError = realtimeError
                recordConnectionEvent(.reconnectionFailed(attempt: reconnectionAttempts, error: realtimeError))
            }
        }
        
        // All reconnection attempts failed
        if reconnectionAttempts >= maxReconnectionAttempts {
            recordConnectionEvent(.reconnectionGiveUp(attempts: reconnectionAttempts))
            onReconnectionFailed?(lastConnectionError ?? .connectionFailed("Max reconnection attempts reached"))
        }
        
        reconnectionTask = nil
    }
    
    private func calculateReconnectionDelay() -> TimeInterval {
        let delay = baseReconnectionDelay * pow(reconnectionBackoffMultiplier, Double(reconnectionAttempts - 1))
        return min(delay, maxReconnectionDelay)
    }
    
    private func attemptReconnection() async throws -> Bool {
        // This would be implemented to actually attempt reconnection
        // For now, simulate reconnection attempt
        
        // Simulate network check
        guard await checkNetworkConnectivity() else {
            throw RealtimeError.networkError("No network connectivity")
        }
        
        // Simulate reconnection success/failure
        let success = Bool.random()
        
        if success {
            // Simulate successful reconnection
            rtcConnectionState = .connected
            rtmConnectionState = .connected
            updateOverallConnectionState()
        }
        
        return success
    }
    
    private func startConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        
        connectionTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(connectionTimeout * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            // Connection timeout occurred
            if overallConnectionState == .connecting {
                lastConnectionError = .connectionTimeout
                rtcConnectionState = .failed
                rtmConnectionState = .failed
                updateOverallConnectionState()
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NetworkMonitor()
        networkMonitor?.onNetworkStatusChanged = { [weak self] isConnected in
            Task { @MainActor in
                self?.handleNetworkStatusChange(isConnected: isConnected)
            }
        }
        networkMonitor?.startMonitoring()
    }
    
    private func handleNetworkStatusChange(isConnected: Bool) {
        recordConnectionEvent(.networkStatusChanged(isConnected: isConnected))
        
        if !isConnected {
            // Network lost
            if overallConnectionState == .connected {
                rtcConnectionState = .disconnected
                rtmConnectionState = .disconnected
                updateOverallConnectionState()
            }
        } else {
            // Network restored
            if overallConnectionState == .disconnected && isAutoReconnectionEnabled {
                Task {
                    await startReconnection()
                }
            }
        }
    }
    
    private func checkNetworkConnectivity() async -> Bool {
        return networkMonitor?.isNetworkAvailable ?? true
    }
    
    private func recordConnectionEvent(_ eventType: ConnectionEventType) {
        let event = ConnectionEvent(
            eventType: eventType,
            timestamp: Date()
        )
        
        connectionHistory.append(event)
        
        // Limit history size
        if connectionHistory.count > maxHistoryCount {
            connectionHistory.removeFirst()
        }
    }
    
    private func calculateAverageConnectionDuration() -> TimeInterval {
        var totalDuration: TimeInterval = 0
        var connectionCount = 0
        var lastConnectedTime: Date?
        
        for event in connectionHistory {
            switch event.eventType {
            case .connected:
                lastConnectedTime = event.timestamp
            case .disconnected, .connectionFailed:
                if let connectedTime = lastConnectedTime {
                    totalDuration += event.timestamp.timeIntervalSince(connectedTime)
                    connectionCount += 1
                    lastConnectedTime = nil
                }
            default:
                break
            }
        }
        
        return connectionCount > 0 ? totalDuration / Double(connectionCount) : 0
    }
}

// MARK: - Supporting Types

public enum ConnectionType: String, CaseIterable, Codable, Sendable {
    case rtc = "rtc"
    case rtm = "rtm"
    case overall = "overall"
}

public enum ConnectionEventType: Equatable, Sendable {
    case connecting(type: ConnectionType)
    case connected(type: ConnectionType)
    case disconnected(type: ConnectionType, reason: String)
    case connectionFailed(type: ConnectionType, error: RealtimeError?)
    case reconnectionAttempt(attempt: Int)
    case reconnectionSuccess
    case reconnectionFailed(attempt: Int, error: RealtimeError)
    case reconnectionGiveUp(attempts: Int)
    case networkStatusChanged(isConnected: Bool)
    case rtcStateChanged(from: ConnectionState, to: ConnectionState)
    case rtmStateChanged(from: ConnectionState, to: ConnectionState)
    case overallStateChanged(from: ConnectionState, to: ConnectionState)
}

public struct ConnectionEvent: Identifiable, Sendable {
    public let id = UUID()
    public let eventType: ConnectionEventType
    public let timestamp: Date
    
    public init(eventType: ConnectionEventType, timestamp: Date = Date()) {
        self.eventType = eventType
        self.timestamp = timestamp
    }
}

public struct ConnectionStatistics: Sendable {
    public let totalConnections: Int
    public let totalDisconnections: Int
    public let totalReconnectionAttempts: Int
    public let averageConnectionDuration: TimeInterval
    public let lastConnectionTime: Date?
    
    public init(
        totalConnections: Int,
        totalDisconnections: Int,
        totalReconnectionAttempts: Int,
        averageConnectionDuration: TimeInterval,
        lastConnectionTime: Date?
    ) {
        self.totalConnections = totalConnections
        self.totalDisconnections = totalDisconnections
        self.totalReconnectionAttempts = totalReconnectionAttempts
        self.averageConnectionDuration = averageConnectionDuration
        self.lastConnectionTime = lastConnectionTime
    }
}

// MARK: - Network Monitor

private final class NetworkMonitor: @unchecked Sendable {
    var isNetworkAvailable: Bool = true
    var onNetworkStatusChanged: ((Bool) -> Void)?
    private var timer: Timer?
    
    func startMonitoring() {
        // Simulate network monitoring
        // In a real implementation, this would use Network framework
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            let newStatus = Bool.random() ? true : (Bool.random() ? false : true) // Mostly connected
            if newStatus != self?.isNetworkAvailable {
                self?.isNetworkAvailable = newStatus
                self?.onNetworkStatusChanged?(newStatus)
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}