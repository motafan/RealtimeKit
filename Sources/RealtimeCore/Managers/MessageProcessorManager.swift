// MessageProcessorManager.swift
// Implementation of message processing pipeline manager

import Foundation

/// Result of message processing
public enum MessageProcessingResult: Equatable, Sendable {
    case processed(RealtimeMessage?)
    case failed(MessageProcessingError)
    case skipped
    case retry(after: TimeInterval)
    
    public static func == (lhs: MessageProcessingResult, rhs: MessageProcessingResult) -> Bool {
        switch (lhs, rhs) {
        case (.processed(let lhsMessage), .processed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.skipped, .skipped):
            return true
        case (.retry(let lhsDelay), .retry(let rhsDelay)):
            return lhsDelay == rhsDelay
        default:
            return false
        }
    }
}

/// Error information for message processing failures
public struct MessageProcessingError: Error, Equatable, Sendable {
    public let message: RealtimeMessage
    public let underlyingError: String
    public let processorIdentifier: String
    public let timestamp: Date
    
    public init(message: RealtimeMessage, underlyingError: Error, processorIdentifier: String) {
        self.message = message
        self.underlyingError = underlyingError.localizedDescription
        self.processorIdentifier = processorIdentifier
        self.timestamp = Date()
    }
    
    public var localizedDescription: String {
        return "Message processing failed in \(processorIdentifier): \(underlyingError)"
    }
}

/// Statistics for message processing
public struct MessageProcessingStats: Sendable {
    public private(set) var totalReceived: Int = 0
    public private(set) var totalProcessed: Int = 0
    public private(set) var totalFailed: Int = 0
    public private(set) var totalSkipped: Int = 0
    public private(set) var retryCount: [String: Int] = [:]
    
    public mutating func incrementReceived() {
        totalReceived += 1
    }
    
    public mutating func incrementProcessed() {
        totalProcessed += 1
    }
    
    public mutating func incrementFailed() {
        totalFailed += 1
    }
    
    public mutating func incrementSkipped() {
        totalSkipped += 1
    }
    
    public mutating func incrementRetry(for messageType: String) {
        retryCount[messageType, default: 0] += 1
    }
    
    public func shouldRetry(for messageType: String, maxRetries: Int = 3) -> Bool {
        let count = retryCount[messageType] ?? 0
        return count < maxRetries
    }
}

/// Implementation of message processor manager
@MainActor
public final class RealtimeMessageProcessorManager: MessageProcessorManager, ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var processingQueue: [RealtimeMessage] = []
    @Published public private(set) var processingStats: MessageProcessingStats = MessageProcessingStats()
    @Published public private(set) var isProcessing: Bool = false
    
    // MARK: - Private Properties
    private var processors: [String: MessageProcessor] = [:]
    private var processingChain: [MessageProcessor] = []
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    
    // MARK: - Callbacks
    public var onMessageProcessed: ((RealtimeMessage) -> Void)?
    public var onProcessingFailed: ((MessageProcessingError) -> Void)?
    public var onProcessingCompleted: ((MessageProcessingStats) -> Void)?
    
    // MARK: - Initialization
    public init(maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    // MARK: - MessageProcessorManager Protocol
    
    public func registerProcessor(_ processor: MessageProcessor) {
        // Check if processor is already registered
        if processors[processor.identifier] != nil {
            print("Warning: Processor with identifier '\(processor.identifier)' is already registered")
            return
        }
        
        processors[processor.identifier] = processor
        rebuildProcessingChain()
        
        print("Registered message processor: \(processor.identifier) with priority \(processor.priority)")
    }
    
    public func unregisterProcessor(withIdentifier identifier: String) {
        if processors.removeValue(forKey: identifier) != nil {
            rebuildProcessingChain()
            print("Unregistered message processor: \(identifier)")
        } else {
            print("Warning: No processor found with identifier '\(identifier)'")
        }
    }
    
    public func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
        processingQueue.append(message)
        processingStats.incrementReceived()
        isProcessing = true
        
        defer {
            processingQueue.removeAll { $0.messageId == message.messageId }
            isProcessing = processingQueue.count > 0
        }
        
        do {
            let result = try await processMessageThroughChain(message)
            return try await handleProcessingResult(result, for: message)
        } catch {
            let processingError = MessageProcessingError(
                message: message,
                underlyingError: error,
                processorIdentifier: "MessageProcessorManager"
            )
            await handleProcessingError(processingError)
            throw error
        }
    }
    
    public func getRegisteredProcessors() -> [MessageProcessor] {
        return processingChain
    }
    
    // MARK: - Additional Public Methods
    
    /// Process message with retry logic
    public func processMessageWithRetry(_ message: RealtimeMessage) async -> MessageProcessingResult {
        do {
            let processedMessage = try await processMessage(message)
            return .processed(processedMessage)
        } catch {
            let processingError = MessageProcessingError(
                message: message,
                underlyingError: error,
                processorIdentifier: "MessageProcessorManager"
            )
            
            if processingStats.shouldRetry(for: message.messageType.rawValue, maxRetries: maxRetries) {
                processingStats.incrementRetry(for: message.messageType.rawValue)
                return .retry(after: retryDelay)
            } else {
                return .failed(processingError)
            }
        }
    }
    
    /// Clear all processors
    public func clearAllProcessors() {
        processors.removeAll()
        processingChain.removeAll()
        print("Cleared all message processors")
    }
    
    /// Get processor by identifier
    public func getProcessor(withIdentifier identifier: String) -> MessageProcessor? {
        return processors[identifier]
    }
    
    /// Check if processor is registered
    public func isProcessorRegistered(withIdentifier identifier: String) -> Bool {
        return processors[identifier] != nil
    }
    
    // MARK: - Private Methods
    
    private func rebuildProcessingChain() {
        processingChain = processors.values.sorted { $0.priority > $1.priority }
    }
    
    private func processMessageThroughChain(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        var currentMessage: RealtimeMessage? = message
        
        for processor in processingChain {
            guard let messageToProcess = currentMessage else {
                // Message was filtered out by previous processor
                return .processed(nil)
            }
            
            if processor.canProcess(messageToProcess) {
                do {
                    let processedMessage = try await processor.processMessage(messageToProcess)
                    currentMessage = processedMessage
                    
                    if processedMessage == nil {
                        // Message was filtered out
                        return .processed(nil)
                    }
                } catch {
                    let processingError = MessageProcessingError(
                        message: messageToProcess,
                        underlyingError: error,
                        processorIdentifier: processor.identifier
                    )
                    
                    // Check if we should retry
                    if processingStats.shouldRetry(for: messageToProcess.messageType.rawValue, maxRetries: maxRetries) {
                        processingStats.incrementRetry(for: messageToProcess.messageType.rawValue)
                        return .retry(after: retryDelay)
                    } else {
                        return .failed(processingError)
                    }
                }
            }
        }
        
        return .processed(currentMessage)
    }
    
    private func handleProcessingResult(_ result: MessageProcessingResult, for message: RealtimeMessage) async throws -> RealtimeMessage? {
        switch result {
        case .processed(let processedMessage):
            if processedMessage != nil {
                processingStats.incrementProcessed()
                onMessageProcessed?(processedMessage!)
            } else {
                processingStats.incrementSkipped()
            }
            onProcessingCompleted?(processingStats)
            return processedMessage
            
        case .failed(let error):
            processingStats.incrementFailed()
            await handleProcessingError(error)
            throw error
            
        case .skipped:
            processingStats.incrementSkipped()
            onProcessingCompleted?(processingStats)
            return nil
            
        case .retry(let delay):
            // Wait and retry
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await processMessage(message)
        }
    }
    
    private func handleProcessingError(_ error: MessageProcessingError) async {
        print("Message processing error: \(error.localizedDescription)")
        onProcessingFailed?(error)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    public static let messageProcessed = Notification.Name("RealtimeKit.messageProcessed")
    public static let messageProcessingFailed = Notification.Name("RealtimeKit.messageProcessingFailed")
    public static let messageProcessingCompleted = Notification.Name("RealtimeKit.messageProcessingCompleted")
}