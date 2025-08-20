// MessageModels.swift
// Message models for RTM communication

import Foundation

/// Real-time message for RTM communication
public struct RealtimeMessage: Codable, Equatable, Sendable {
    public let messageId: String
    public let messageType: MessageType
    public let content: String
    public let senderId: String
    public let senderName: String?
    public let channelId: String?
    public let timestamp: Date
    public let metadata: [String: String]
    
    /// Initialize a realtime message
    /// - Parameters:
    ///   - messageId: Unique message identifier
    ///   - messageType: Type of the message
    ///   - content: Message content
    ///   - senderId: Sender user identifier
    ///   - senderName: Optional sender display name
    ///   - channelId: Optional channel identifier
    ///   - timestamp: Message timestamp
    ///   - metadata: Additional metadata
    public init(
        messageId: String = UUID().uuidString,
        messageType: MessageType,
        content: String,
        senderId: String,
        senderName: String? = nil,
        channelId: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.messageId = messageId
        self.messageType = messageType
        self.content = content
        self.senderId = senderId
        self.senderName = senderName
        self.channelId = channelId
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    /// Create a text message
    /// - Parameters:
    ///   - text: Message text content
    ///   - senderId: Sender user identifier
    ///   - senderName: Optional sender display name
    ///   - channelId: Optional channel identifier
    /// - Returns: Text message
    public static func text(
        _ text: String,
        from senderId: String,
        senderName: String? = nil,
        in channelId: String? = nil
    ) -> RealtimeMessage {
        return RealtimeMessage(
            messageType: .text,
            content: text,
            senderId: senderId,
            senderName: senderName,
            channelId: channelId
        )
    }
    
    /// Create a system message
    /// - Parameters:
    ///   - content: System message content
    ///   - channelId: Optional channel identifier
    /// - Returns: System message
    public static func system(
        _ content: String,
        in channelId: String? = nil
    ) -> RealtimeMessage {
        return RealtimeMessage(
            messageType: .system,
            content: content,
            senderId: "system",
            senderName: "System",
            channelId: channelId
        )
    }
    
    /// Create a custom message with metadata
    /// - Parameters:
    ///   - content: Message content
    ///   - senderId: Sender user identifier
    ///   - metadata: Custom metadata
    ///   - channelId: Optional channel identifier
    /// - Returns: Custom message
    public static func custom(
        content: String,
        from senderId: String,
        metadata: [String: String],
        in channelId: String? = nil
    ) -> RealtimeMessage {
        return RealtimeMessage(
            messageType: .custom,
            content: content,
            senderId: senderId,
            channelId: channelId,
            metadata: metadata
        )
    }
    
    /// Check if message is from system
    public var isSystemMessage: Bool {
        return messageType == .system || senderId == "system"
    }
    
    /// Get metadata value for key
    /// - Parameter key: Metadata key
    /// - Returns: Metadata value if exists
    public func getMetadata(for key: String) -> String? {
        return metadata[key]
    }
    
    /// Create new message with additional metadata
    /// - Parameter newMetadata: Additional metadata to add
    /// - Returns: Updated message
    public func withMetadata(_ newMetadata: [String: String]) -> RealtimeMessage {
        var updatedMetadata = metadata
        for (key, value) in newMetadata {
            updatedMetadata[key] = value
        }
        
        return RealtimeMessage(
            messageId: messageId,
            messageType: messageType,
            content: content,
            senderId: senderId,
            senderName: senderName,
            channelId: channelId,
            timestamp: timestamp,
            metadata: updatedMetadata
        )
    }
}