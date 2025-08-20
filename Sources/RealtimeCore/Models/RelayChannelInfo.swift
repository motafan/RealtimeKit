import Foundation

/// Relay channel information with validation (需求 8.4)
public struct RelayChannelInfo: Codable, Equatable, Sendable {
    public let channelName: String
    public let token: String?
    public let userId: String
    public let uid: UInt
    public var state: MediaRelayChannelState
    
    /// Initialize relay channel information with validation
    /// - Parameters:
    ///   - channelName: Channel name (must be non-empty and valid)
    ///   - token: Authentication token (optional)
    ///   - userId: User identifier
    ///   - uid: User unique identifier (default: 0)
    ///   - state: Channel state (default: idle)
    /// - Throws: RealtimeError if parameters are invalid
    public init(
        channelName: String,
        token: String? = nil,
        userId: String,
        uid: UInt = 0,
        state: MediaRelayChannelState = .idle
    ) throws {
        try Self.validateChannelName(channelName)
        try Self.validateUserId(userId)
        if let token = token {
            try Self.validateToken(token)
        }
        
        self.channelName = channelName
        self.token = token
        self.userId = userId
        self.uid = uid
        self.state = state
    }
    
    /// Create channel info without validation (for internal use)
    internal init(
        channelName: String,
        token: String?,
        userId: String,
        uid: UInt,
        state: MediaRelayChannelState,
        skipValidation: Bool
    ) {
        self.channelName = channelName
        self.token = token
        self.userId = userId
        self.uid = uid
        self.state = state
    }
    
    /// Check if channel info is valid
    public var isValid: Bool {
        do {
            try Self.validateChannelName(channelName)
            try Self.validateUserId(userId)
            if let token = token {
                try Self.validateToken(token)
            }
            return true
        } catch {
            return false
        }
    }
    
    /// Validate the channel information
    /// - Throws: RealtimeError if channel info is invalid
    public func validate() throws {
        try Self.validateChannelName(channelName)
        try Self.validateUserId(userId)
        if let token = token {
            try Self.validateToken(token)
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validate channel name
    /// - Parameter channelName: Channel name to validate
    /// - Throws: RealtimeError.invalidChannelName if name is invalid
    private static func validateChannelName(_ channelName: String) throws {
        guard !channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeError.invalidChannelName("Channel name cannot be empty or whitespace")
        }
        
        guard channelName.count <= 64 else {
            throw RealtimeError.invalidChannelName("Channel name cannot exceed 64 characters")
        }
        
        // Check for valid characters (alphanumeric, underscore, hyphen)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard channelName.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            throw RealtimeError.invalidChannelName("Channel name can only contain alphanumeric characters, underscore, and hyphen")
        }
    }
    
    /// Validate user ID
    /// - Parameter userId: User ID to validate
    /// - Throws: RealtimeError.invalidUserId if user ID is invalid
    private static func validateUserId(_ userId: String) throws {
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeError.invalidUserId("User ID cannot be empty or whitespace")
        }
        
        guard userId.count <= 255 else {
            throw RealtimeError.invalidUserId("User ID cannot exceed 255 characters")
        }
    }
    
    /// Validate token
    /// - Parameter token: Token to validate
    /// - Throws: RealtimeError.invalidToken if token is invalid
    private static func validateToken(_ token: String) throws {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeError.invalidToken("Token cannot be empty or whitespace")
        }
        
        guard token.count >= 10 else {
            throw RealtimeError.invalidToken("Token must be at least 10 characters long")
        }
        
        guard token.count <= 2048 else {
            throw RealtimeError.invalidToken("Token cannot exceed 2048 characters")
        }
    }
    
    // MARK: - Channel Info Manipulation
    
    /// Update the token for this channel
    /// - Parameter newToken: New authentication token
    /// - Returns: New RelayChannelInfo with updated token
    /// - Throws: RealtimeError if token is invalid
    public func withToken(_ newToken: String?) throws -> RelayChannelInfo {
        return try RelayChannelInfo(
            channelName: channelName,
            token: newToken,
            userId: userId,
            uid: uid,
            state: state
        )
    }
    
    /// Update the user ID for this channel
    /// - Parameter newUserId: New user identifier
    /// - Returns: New RelayChannelInfo with updated user ID
    /// - Throws: RealtimeError if user ID is invalid
    public func withUserId(_ newUserId: String) throws -> RelayChannelInfo {
        return try RelayChannelInfo(
            channelName: channelName,
            token: token,
            userId: newUserId,
            uid: uid,
            state: state
        )
    }
    
    /// Update the UID for this channel
    /// - Parameter newUid: New user unique identifier
    /// - Returns: New RelayChannelInfo with updated UID
    public func withUid(_ newUid: UInt) throws -> RelayChannelInfo {
        return try RelayChannelInfo(
            channelName: channelName,
            token: token,
            userId: userId,
            uid: newUid,
            state: state
        )
    }
    
    /// Update the state for this channel
    /// - Parameter newState: New channel state
    /// - Returns: New RelayChannelInfo with updated state
    public func withState(_ newState: MediaRelayChannelState) throws -> RelayChannelInfo {
        return try RelayChannelInfo(
            channelName: channelName,
            token: token,
            userId: userId,
            uid: uid,
            state: newState
        )
    }
}