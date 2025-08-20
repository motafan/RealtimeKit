// MessageProcessors.swift
// Concrete implementations of message processors

import Foundation

// MARK: - Text Message Processor

/// Processor for text messages with content filtering and validation
@MainActor
public final class TextMessageProcessor: MessageProcessor {
    public nonisolated let identifier = "text_message_processor"
    public nonisolated let priority = 100
    
    private let maxContentLength: Int
    private let bannedWords: Set<String>
    private let enableProfanityFilter: Bool
    
    public init(
        maxContentLength: Int = 1000,
        bannedWords: Set<String> = [],
        enableProfanityFilter: Bool = false
    ) {
        self.maxContentLength = maxContentLength
        self.bannedWords = Set(bannedWords.map { $0.lowercased() })
        self.enableProfanityFilter = enableProfanityFilter
    }
    
    public nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
        return message.messageType == .text
    }
    
    public func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
        // Validate content length
        guard message.content.count <= maxContentLength else {
            throw MessageProcessingError(
                message: message,
                underlyingError: TextProcessingError.contentTooLong(maxContentLength),
                processorIdentifier: identifier
            )
        }
        
        // Check for banned words
        let lowercasedContent = message.content.lowercased()
        for bannedWord in bannedWords {
            if lowercasedContent.contains(bannedWord) {
                throw MessageProcessingError(
                    message: message,
                    underlyingError: TextProcessingError.bannedWordDetected(bannedWord),
                    processorIdentifier: identifier
                )
            }
        }
        
        // Apply profanity filter if enabled
        var processedContent = message.content
        if enableProfanityFilter {
            processedContent = applyProfanityFilter(processedContent)
        }
        
        // Add processing metadata
        let metadata = message.metadata.merging([
            "processed_by": identifier,
            "processed_at": ISO8601DateFormatter().string(from: Date()),
            "content_length": String(processedContent.count),
            "profanity_filtered": String(enableProfanityFilter)
        ]) { _, new in new }
        
        return RealtimeMessage(
            messageId: message.messageId,
            messageType: message.messageType,
            content: processedContent,
            senderId: message.senderId,
            senderName: message.senderName,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: metadata
        )
    }
    
    private func applyProfanityFilter(_ content: String) -> String {
        // Simple profanity filter implementation
        let profanityWords = ["badword1", "badword2"] // Add actual profanity words as needed
        var filteredContent = content
        
        for word in profanityWords {
            let replacement = String(repeating: "*", count: word.count)
            filteredContent = filteredContent.replacingOccurrences(
                of: word,
                with: replacement,
                options: .caseInsensitive
            )
        }
        
        return filteredContent
    }
}

// MARK: - System Message Processor

/// Processor for system messages with validation and formatting
@MainActor
public final class SystemMessageProcessor: MessageProcessor {
    public nonisolated let identifier = "system_message_processor"
    public nonisolated let priority = 90
    
    private let allowedSystemSenders: Set<String>
    private let enableTimestampValidation: Bool
    
    public init(
        allowedSystemSenders: Set<String> = ["system", "admin", "moderator"],
        enableTimestampValidation: Bool = true
    ) {
        self.allowedSystemSenders = allowedSystemSenders
        self.enableTimestampValidation = enableTimestampValidation
    }
    
    public nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
        return message.messageType == .system
    }
    
    public func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
        // Validate system sender
        guard allowedSystemSenders.contains(message.senderId) else {
            throw MessageProcessingError(
                message: message,
                underlyingError: SystemProcessingError.unauthorizedSystemSender(message.senderId),
                processorIdentifier: identifier
            )
        }
        
        // Validate timestamp if enabled
        if enableTimestampValidation {
            let now = Date()
            let timeDifference = abs(now.timeIntervalSince(message.timestamp))
            
            // System messages should not be older than 1 hour
            guard timeDifference <= 3600 else {
                throw MessageProcessingError(
                    message: message,
                    underlyingError: SystemProcessingError.timestampTooOld(timeDifference),
                    processorIdentifier: identifier
                )
            }
        }
        
        // Format system message content
        let formattedContent = formatSystemMessage(message.content)
        
        // Add processing metadata
        let metadata = message.metadata.merging([
            "processed_by": identifier,
            "processed_at": ISO8601DateFormatter().string(from: Date()),
            "system_validated": "true",
            "formatted": String(formattedContent != message.content)
        ]) { _, new in new }
        
        return RealtimeMessage(
            messageId: message.messageId,
            messageType: message.messageType,
            content: formattedContent,
            senderId: message.senderId,
            senderName: message.senderName,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: metadata
        )
    }
    
    private func formatSystemMessage(_ content: String) -> String {
        // Add system message formatting
        return "[SYSTEM] \(content)"
    }
}

// MARK: - Custom Message Processor

/// Processor for custom messages with metadata validation and transformation
@MainActor
public final class CustomMessageProcessor: MessageProcessor {
    public nonisolated let identifier = "custom_message_processor"
    public nonisolated let priority = 80
    
    private let requiredMetadataKeys: Set<String>
    private let metadataTransformers: [String: (String) -> String]
    
    public init(
        requiredMetadataKeys: Set<String> = [],
        metadataTransformers: [String: (String) -> String] = [:]
    ) {
        self.requiredMetadataKeys = requiredMetadataKeys
        self.metadataTransformers = metadataTransformers
    }
    
    public nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
        return message.messageType == .custom
    }
    
    public func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
        // Validate required metadata keys
        for requiredKey in requiredMetadataKeys {
            guard message.metadata[requiredKey] != nil else {
                throw MessageProcessingError(
                    message: message,
                    underlyingError: CustomProcessingError.missingRequiredMetadata(requiredKey),
                    processorIdentifier: identifier
                )
            }
        }
        
        // Apply metadata transformations
        var transformedMetadata = message.metadata
        for (key, transformer) in metadataTransformers {
            if let value = transformedMetadata[key] {
                transformedMetadata[key] = transformer(value)
            }
        }
        
        // Add processing metadata
        transformedMetadata = transformedMetadata.merging([
            "processed_by": identifier,
            "processed_at": ISO8601DateFormatter().string(from: Date()),
            "metadata_validated": "true",
            "transformations_applied": String(metadataTransformers.count)
        ]) { _, new in new }
        
        return RealtimeMessage(
            messageId: message.messageId,
            messageType: message.messageType,
            content: message.content,
            senderId: message.senderId,
            senderName: message.senderName,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: transformedMetadata
        )
    }
}

// MARK: - Message Filter Processor

/// Processor that filters messages based on configurable criteria
@MainActor
public final class MessageFilterProcessor: MessageProcessor {
    public nonisolated let identifier = "message_filter_processor"
    public nonisolated let priority = 200 // High priority to filter early
    
    private let filterCriteria: MessageFilterCriteria
    
    public init(filterCriteria: MessageFilterCriteria) {
        self.filterCriteria = filterCriteria
    }
    
    public nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
        return true // Can process all message types
    }
    
    public func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
        // Apply sender filters
        if let blockedSenders = filterCriteria.blockedSenders,
           blockedSenders.contains(message.senderId) {
            return nil // Filter out message
        }
        
        // Apply channel filters
        if let allowedChannels = filterCriteria.allowedChannels,
           let channelId = message.channelId,
           !allowedChannels.contains(channelId) {
            return nil // Filter out message
        }
        
        // Apply message type filters
        if let allowedMessageTypes = filterCriteria.allowedMessageTypes,
           !allowedMessageTypes.contains(message.messageType) {
            return nil // Filter out message
        }
        
        // Apply content filters
        if let contentFilters = filterCriteria.contentFilters {
            for filter in contentFilters {
                if message.content.lowercased().contains(filter.lowercased()) {
                    return nil // Filter out message
                }
            }
        }
        
        // Apply timestamp filters
        if let maxAge = filterCriteria.maxMessageAge {
            let messageAge = Date().timeIntervalSince(message.timestamp)
            if messageAge > maxAge {
                return nil // Filter out old message
            }
        }
        
        // Message passed all filters, add filter metadata
        let metadata = message.metadata.merging([
            "filtered_by": identifier,
            "filter_passed": "true",
            "filter_timestamp": ISO8601DateFormatter().string(from: Date())
        ]) { _, new in new }
        
        return RealtimeMessage(
            messageId: message.messageId,
            messageType: message.messageType,
            content: message.content,
            senderId: message.senderId,
            senderName: message.senderName,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: metadata
        )
    }
}

// MARK: - Message Validation Processor

/// Processor that validates message structure and content
@MainActor
public final class MessageValidationProcessor: MessageProcessor {
    public nonisolated let identifier = "message_validation_processor"
    public nonisolated let priority = 150 // High priority for early validation
    
    private let validationRules: MessageValidationRules
    
    public init(validationRules: MessageValidationRules = MessageValidationRules()) {
        self.validationRules = validationRules
    }
    
    public nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
        return true // Can validate all message types
    }
    
    public func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
        // Validate message ID
        if validationRules.validateMessageId {
            guard !message.messageId.isEmpty else {
                throw MessageProcessingError(
                    message: message,
                    underlyingError: ValidationError.emptyMessageId,
                    processorIdentifier: identifier
                )
            }
        }
        
        // Validate sender ID
        if validationRules.validateSenderId {
            guard !message.senderId.isEmpty else {
                throw MessageProcessingError(
                    message: message,
                    underlyingError: ValidationError.emptySenderId,
                    processorIdentifier: identifier
                )
            }
        }
        
        // Validate content
        if validationRules.validateContent {
            guard !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MessageProcessingError(
                    message: message,
                    underlyingError: ValidationError.emptyContent,
                    processorIdentifier: identifier
                )
            }
        }
        
        // Validate timestamp
        if validationRules.validateTimestamp {
            let now = Date()
            let timeDifference = message.timestamp.timeIntervalSince(now)
            
            // Message timestamp should not be too far in the future
            guard timeDifference <= validationRules.maxFutureTimestamp else {
                throw MessageProcessingError(
                    message: message,
                    underlyingError: ValidationError.timestampTooFarInFuture(timeDifference),
                    processorIdentifier: identifier
                )
            }
        }
        
        // Add validation metadata
        let metadata = message.metadata.merging([
            "validated_by": identifier,
            "validation_passed": "true",
            "validation_timestamp": ISO8601DateFormatter().string(from: Date())
        ]) { _, new in new }
        
        return RealtimeMessage(
            messageId: message.messageId,
            messageType: message.messageType,
            content: message.content,
            senderId: message.senderId,
            senderName: message.senderName,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: metadata
        )
    }
}

// MARK: - Supporting Types

public struct MessageFilterCriteria {
    public let blockedSenders: Set<String>?
    public let allowedChannels: Set<String>?
    public let allowedMessageTypes: Set<MessageType>?
    public let contentFilters: [String]?
    public let maxMessageAge: TimeInterval?
    
    public init(
        blockedSenders: Set<String>? = nil,
        allowedChannels: Set<String>? = nil,
        allowedMessageTypes: Set<MessageType>? = nil,
        contentFilters: [String]? = nil,
        maxMessageAge: TimeInterval? = nil
    ) {
        self.blockedSenders = blockedSenders
        self.allowedChannels = allowedChannels
        self.allowedMessageTypes = allowedMessageTypes
        self.contentFilters = contentFilters
        self.maxMessageAge = maxMessageAge
    }
}

public struct MessageValidationRules {
    public let validateMessageId: Bool
    public let validateSenderId: Bool
    public let validateContent: Bool
    public let validateTimestamp: Bool
    public let maxFutureTimestamp: TimeInterval
    
    public init(
        validateMessageId: Bool = true,
        validateSenderId: Bool = true,
        validateContent: Bool = true,
        validateTimestamp: Bool = true,
        maxFutureTimestamp: TimeInterval = 300 // 5 minutes
    ) {
        self.validateMessageId = validateMessageId
        self.validateSenderId = validateSenderId
        self.validateContent = validateContent
        self.validateTimestamp = validateTimestamp
        self.maxFutureTimestamp = maxFutureTimestamp
    }
}

// MARK: - Error Types

public enum TextProcessingError: Error, LocalizedError {
    case contentTooLong(Int)
    case bannedWordDetected(String)
    
    public var errorDescription: String? {
        switch self {
        case .contentTooLong(let maxLength):
            return "Text content exceeds maximum length of \(maxLength) characters"
        case .bannedWordDetected(let word):
            return "Banned word detected: \(word)"
        }
    }
}

public enum SystemProcessingError: Error, LocalizedError {
    case unauthorizedSystemSender(String)
    case timestampTooOld(TimeInterval)
    
    public var errorDescription: String? {
        switch self {
        case .unauthorizedSystemSender(let senderId):
            return "Unauthorized system sender: \(senderId)"
        case .timestampTooOld(let age):
            return "System message timestamp is too old: \(age) seconds"
        }
    }
}

public enum CustomProcessingError: Error, LocalizedError {
    case missingRequiredMetadata(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredMetadata(let key):
            return "Missing required metadata key: \(key)"
        }
    }
}

public enum ValidationError: Error, LocalizedError {
    case emptyMessageId
    case emptySenderId
    case emptyContent
    case timestampTooFarInFuture(TimeInterval)
    
    public var errorDescription: String? {
        switch self {
        case .emptyMessageId:
            return "Message ID cannot be empty"
        case .emptySenderId:
            return "Sender ID cannot be empty"
        case .emptyContent:
            return "Message content cannot be empty"
        case .timestampTooFarInFuture(let difference):
            return "Message timestamp is too far in the future: \(difference) seconds"
        }
    }
}