// MessageProcessor.swift
// Protocol for message processing pipeline

import Foundation

/// Protocol for processing messages in a pipeline
@MainActor
public protocol MessageProcessor: AnyObject, Sendable {
    
    /// Process a message and return the processed result
    /// - Parameter message: Message to process
    /// - Returns: Processed message or nil if message should be filtered out
    func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage?
    
    /// Check if this processor can handle the given message type
    /// - Parameter message: Message to check
    /// - Returns: True if processor can handle this message
    nonisolated func canProcess(_ message: RealtimeMessage) -> Bool
    
    /// Priority of this processor in the processing chain (higher = earlier)
    nonisolated var priority: Int { get }
    
    /// Unique identifier for this processor
    nonisolated var identifier: String { get }
}

/// Protocol for managing message processing pipeline
@MainActor
public protocol MessageProcessorManager: AnyObject {
    
    /// Register a message processor
    /// - Parameter processor: Processor to register
    func registerProcessor(_ processor: MessageProcessor)
    
    /// Unregister a message processor
    /// - Parameter identifier: Identifier of processor to remove
    func unregisterProcessor(withIdentifier identifier: String)
    
    /// Process a message through all registered processors
    /// - Parameter message: Message to process
    /// - Returns: Final processed message or nil if filtered out
    func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage?
    
    /// Get all registered processors
    /// - Returns: Array of registered processors sorted by priority
    func getRegisteredProcessors() -> [MessageProcessor]
}