// RTCRoom.swift
// RTC room model and related types

import Foundation

/// RTC room representation
public struct RTCRoom: Codable, Equatable, Sendable {
    public let roomId: String
    public let roomName: String?
    public let createdAt: Date
    public let maxUsers: Int
    public let isPrivate: Bool
    public let metadata: [String: String]
    
    /// Initialize RTC room
    /// - Parameters:
    ///   - roomId: Unique room identifier
    ///   - roomName: Optional display name for the room
    ///   - createdAt: Room creation timestamp
    ///   - maxUsers: Maximum number of users allowed
    ///   - isPrivate: Whether the room is private
    ///   - metadata: Additional room metadata
    public init(
        roomId: String,
        roomName: String? = nil,
        createdAt: Date = Date(),
        maxUsers: Int = 100,
        isPrivate: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.roomId = roomId
        self.roomName = roomName
        self.createdAt = createdAt
        self.maxUsers = max(1, maxUsers)
        self.isPrivate = isPrivate
        self.metadata = metadata
    }
    
    /// Display name for the room
    public var displayName: String {
        return roomName ?? roomId
    }
    
    /// Get metadata value for key
    /// - Parameter key: Metadata key
    /// - Returns: Metadata value if exists
    public func getMetadata(for key: String) -> String? {
        return metadata[key]
    }
    
    /// Create new room with updated metadata
    /// - Parameter newMetadata: Additional metadata to add
    /// - Returns: Updated room
    public func withMetadata(_ newMetadata: [String: String]) -> RTCRoom {
        var updatedMetadata = metadata
        for (key, value) in newMetadata {
            updatedMetadata[key] = value
        }
        
        return RTCRoom(
            roomId: roomId,
            roomName: roomName,
            createdAt: createdAt,
            maxUsers: maxUsers,
            isPrivate: isPrivate,
            metadata: updatedMetadata
        )
    }
}