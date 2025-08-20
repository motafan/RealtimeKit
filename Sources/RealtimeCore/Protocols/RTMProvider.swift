// RTMProvider.swift
// Core RTM (Real-Time Messaging) provider protocol

import Foundation

/// Protocol defining the interface for RTM service providers
public protocol RTMProvider: AnyObject, Sendable {
    
    // MARK: - Lifecycle Management
    
    /// Initialize the RTM provider with configuration
    /// - Parameter config: RTM configuration settings
    func initialize(config: RTMConfig) async throws
    
    /// Send a message to a channel or user
    /// - Parameter message: Message to send
    func sendMessage(_ message: RealtimeMessage) async throws
    
    /// Subscribe to a channel for receiving messages
    /// - Parameter channel: Channel name to subscribe to
    func subscribe(to channel: String) async throws
    
    /// Unsubscribe from a channel
    /// - Parameter channel: Channel name to unsubscribe from
    func unsubscribe(from channel: String) async throws
    
    // MARK: - Message Processing
    
    /// Set message handler for incoming messages
    /// - Parameter handler: Callback for received messages
    func setMessageHandler(_ handler: @escaping @Sendable (RealtimeMessage) -> Void)
    
    /// Set connection state change handler
    /// - Parameter handler: Callback for connection state changes
    func setConnectionStateHandler(_ handler: @escaping @Sendable (ConnectionState) -> Void)
    
    /// Process incoming raw message from provider
    /// - Parameter rawMessage: Raw message data from provider
    /// - Returns: Processed RealtimeMessage
    func processIncomingMessage(_ rawMessage: Any) async throws -> RealtimeMessage
    
    // MARK: - Token Management
    
    /// Renew authentication token
    /// - Parameter newToken: New authentication token
    func renewToken(_ newToken: String) async throws
    
    /// Set token expiration handler
    /// - Parameter handler: Callback when token will expire (seconds remaining)
    func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void)
    
    // MARK: - Connection Management
    
    /// Get current connection state
    /// - Returns: Current connection state
    func getConnectionState() -> ConnectionState
    
    /// Manually reconnect to the service
    func reconnect() async throws
    
    /// Disconnect from the service
    func disconnect() async throws
}