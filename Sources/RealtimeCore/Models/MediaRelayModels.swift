import Foundation

// MARK: - Media Relay State
public struct MediaRelayState: Equatable, Sendable {
    public let overallState: MediaRelayOverallState
    public var channelStates: [String: MediaRelayChannelState]
    public let startTime: Date?
    
    public init(
        overallState: MediaRelayOverallState,
        channelStates: [String: MediaRelayChannelState] = [:],
        startTime: Date? = nil
    ) {
        self.overallState = overallState
        self.channelStates = channelStates
        self.startTime = startTime
    }
    
    public var activeChannelCount: Int {
        return channelStates.values.filter { $0 == .running }.count
    }
    
    public var totalChannelCount: Int {
        return channelStates.count
    }
    
    public func stateForDestination(_ channelName: String) -> RelayChannelState? {
        return channelStates[channelName].map { state in
            switch state {
            case .idle: return .idle
            case .connecting: return .connecting
            case .running: return .running
            case .paused: return .paused
            case .error: return .error
            }
        }
    }
}

// MARK: - Media Relay Overall State
public enum MediaRelayOverallState: Equatable, Sendable {
    case idle
    case connecting
    case running
    case paused
    case error(Error)
    
    public static func == (lhs: MediaRelayOverallState, rhs: MediaRelayOverallState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.connecting, .connecting), (.running, .running), (.paused, .paused):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Media Relay Channel State
public enum MediaRelayChannelState: String, Codable, CaseIterable, Sendable {
    case idle = "idle"
    case connecting = "connecting"
    case running = "running"
    case paused = "paused"
    case error = "error"
    
    public var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .connecting: return "连接中"
        case .running: return "运行中"
        case .paused: return "已暂停"
        case .error: return "错误"
        }
    }
}

// MARK: - Media Relay Configuration
public struct MediaRelayConfig: Codable, Equatable, Sendable {
    public let sourceChannel: RelayChannelInfo
    public let destinationChannels: [RelayChannelInfo]
    public let relayMode: MediaRelayMode
    public let enableAudio: Bool
    public let enableVideo: Bool
    
    /// Initialize media relay configuration with validation
    /// - Parameters:
    ///   - sourceChannel: Source channel information
    ///   - destinationChannels: Array of destination channels
    ///   - relayMode: Relay mode (one-to-one, one-to-many, many-to-many)
    ///   - enableAudio: Whether to relay audio streams
    ///   - enableVideo: Whether to relay video streams
    /// - Throws: RealtimeError if configuration is invalid
    public init(
        sourceChannel: RelayChannelInfo,
        destinationChannels: [RelayChannelInfo],
        relayMode: MediaRelayMode = .oneToMany,
        enableAudio: Bool = true,
        enableVideo: Bool = true
    ) throws {
        try Self.validateConfiguration(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels,
            relayMode: relayMode,
            enableAudio: enableAudio,
            enableVideo: enableVideo
        )
        
        self.sourceChannel = sourceChannel
        self.destinationChannels = destinationChannels
        self.relayMode = relayMode
        self.enableAudio = enableAudio
        self.enableVideo = enableVideo
    }
    
    /// Create configuration without validation (for internal use)
    internal init(
        sourceChannel: RelayChannelInfo,
        destinationChannels: [RelayChannelInfo],
        relayMode: MediaRelayMode,
        enableAudio: Bool,
        enableVideo: Bool,
        skipValidation: Bool
    ) {
        self.sourceChannel = sourceChannel
        self.destinationChannels = destinationChannels
        self.relayMode = relayMode
        self.enableAudio = enableAudio
        self.enableVideo = enableVideo
    }
    
    /// Check if configuration is valid
    public var isValid: Bool {
        do {
            try Self.validateConfiguration(
                sourceChannel: sourceChannel,
                destinationChannels: destinationChannels,
                relayMode: relayMode,
                enableAudio: enableAudio,
                enableVideo: enableVideo
            )
            return true
        } catch {
            return false
        }
    }
    
    /// Validate the entire configuration
    /// - Throws: RealtimeError if configuration is invalid
    public func validate() throws {
        try Self.validateConfiguration(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels,
            relayMode: relayMode,
            enableAudio: enableAudio,
            enableVideo: enableVideo
        )
    }
    
    /// Get destination channel by name
    /// - Parameter channelName: Name of the destination channel
    /// - Returns: RelayChannelInfo if found, nil otherwise
    public func destinationChannel(named channelName: String) -> RelayChannelInfo? {
        return destinationChannels.first { $0.channelName == channelName }
    }
    
    /// Add a destination channel to the configuration
    /// - Parameter channel: Channel to add
    /// - Returns: New configuration with the added channel
    /// - Throws: RealtimeError if the resulting configuration would be invalid
    public func addingDestination(_ channel: RelayChannelInfo) throws -> MediaRelayConfig {
        var newDestinations = destinationChannels
        
        // Remove existing channel with the same name
        newDestinations.removeAll { $0.channelName == channel.channelName }
        
        // Add new channel
        newDestinations.append(channel)
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: newDestinations,
            relayMode: relayMode,
            enableAudio: enableAudio,
            enableVideo: enableVideo
        )
    }
    
    /// Remove a destination channel from the configuration
    /// - Parameter channelName: Name of the channel to remove
    /// - Returns: New configuration without the specified channel
    /// - Throws: RealtimeError if the resulting configuration would be invalid
    public func removingDestination(named channelName: String) throws -> MediaRelayConfig {
        let newDestinations = destinationChannels.filter { $0.channelName != channelName }
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: newDestinations,
            relayMode: relayMode,
            enableAudio: enableAudio,
            enableVideo: enableVideo
        )
    }
    
    // MARK: - Validation Methods
    
    /// Validate the entire configuration
    /// - Throws: RealtimeError if configuration is invalid
    private static func validateConfiguration(
        sourceChannel: RelayChannelInfo,
        destinationChannels: [RelayChannelInfo],
        relayMode: MediaRelayMode,
        enableAudio: Bool,
        enableVideo: Bool
    ) throws {
        // Validate source channel
        try sourceChannel.validate()
        
        // Validate destination channels
        guard !destinationChannels.isEmpty else {
            throw RealtimeError.invalidMediaRelayConfig("At least one destination channel is required")
        }
        
        guard destinationChannels.count <= 16 else {
            throw RealtimeError.invalidMediaRelayConfig("Maximum 16 destination channels allowed")
        }
        
        // Validate each destination channel
        for channel in destinationChannels {
            try channel.validate()
        }
        
        // Check for duplicate channel names
        let channelNames = destinationChannels.map { $0.channelName }
        let uniqueChannelNames = Set(channelNames)
        guard channelNames.count == uniqueChannelNames.count else {
            throw RealtimeError.invalidMediaRelayConfig("Duplicate destination channel names")
        }
        
        // Validate relay mode compatibility
        try validateRelayModeCompatibility(relayMode: relayMode, destinationCount: destinationChannels.count)
        
        // Validate media settings
        guard enableAudio || enableVideo else {
            throw RealtimeError.invalidMediaRelayConfig("At least audio or video must be enabled")
        }
    }
    
    /// Validate relay mode compatibility with destination count
    /// - Parameters:
    ///   - relayMode: Relay mode
    ///   - destinationCount: Number of destination channels
    /// - Throws: RealtimeError if mode is incompatible with destination count
    private static func validateRelayModeCompatibility(relayMode: MediaRelayMode, destinationCount: Int) throws {
        switch relayMode {
        case .oneToOne:
            guard destinationCount == 1 else {
                throw RealtimeError.invalidMediaRelayConfig("One-to-one relay mode requires exactly 1 destination channel")
            }
        case .oneToMany:
            guard destinationCount >= 1 else {
                throw RealtimeError.invalidMediaRelayConfig("One-to-many relay mode requires at least 1 destination channel")
            }
        case .manyToMany:
            guard destinationCount >= 1 else {
                throw RealtimeError.invalidMediaRelayConfig("Many-to-many relay mode requires at least 1 destination channel")
            }
        }
    }
    
    // MARK: - Static Factory Methods
    
    /// Create a one-to-one relay configuration
    /// - Parameters:
    ///   - sourceChannel: Source channel
    ///   - destinationChannel: Single destination channel
    /// - Returns: MediaRelayConfig for one-to-one relay
    public static func oneToOne(
        source sourceChannel: RelayChannelInfo,
        destination destinationChannel: RelayChannelInfo
    ) throws -> MediaRelayConfig {
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: [destinationChannel],
            relayMode: .oneToOne,
            enableAudio: true,
            enableVideo: true
        )
    }
    
    /// Create a one-to-many relay configuration
    /// - Parameters:
    ///   - sourceChannel: Source channel
    ///   - destinationChannels: Multiple destination channels
    /// - Returns: MediaRelayConfig for one-to-many relay
    public static func oneToMany(
        source sourceChannel: RelayChannelInfo,
        destinations destinationChannels: [RelayChannelInfo]
    ) throws -> MediaRelayConfig {
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels,
            relayMode: .oneToMany,
            enableAudio: true,
            enableVideo: true
        )
    }
}

// MARK: - Media Relay Mode
public enum MediaRelayMode: String, CaseIterable, Codable, Sendable {
    case oneToOne = "one_to_one"        // 1对1中继
    case oneToMany = "one_to_many"      // 1对多中继
    case manyToMany = "many_to_many"    // 多对多中继
    
    public var displayName: String {
        switch self {
        case .oneToOne: return "一对一中继"
        case .oneToMany: return "一对多中继"
        case .manyToMany: return "多对多中继"
        }
    }
    
    public var description: String {
        switch self {
        case .oneToOne: return "将单个源频道的媒体流转发到单个目标频道"
        case .oneToMany: return "将单个源频道的媒体流转发到多个目标频道"
        case .manyToMany: return "在多个频道之间进行双向媒体流转发"
        }
    }
}

// MARK: - Media Relay Statistics
public struct MediaRelayStats: Codable, Equatable {
    public let totalDataTransferred: Int64
    public let averageBitrate: Int
    public let packetsLost: Int
    public let latency: Int
    public let startTime: Date
    public let duration: TimeInterval
    public let channelStats: [String: MediaRelayChannelStats]
    
    public init(
        totalDataTransferred: Int64 = 0,
        averageBitrate: Int = 0,
        packetsLost: Int = 0,
        latency: Int = 0,
        startTime: Date = Date(),
        duration: TimeInterval = 0,
        channelStats: [String: MediaRelayChannelStats] = [:]
    ) {
        self.totalDataTransferred = totalDataTransferred
        self.averageBitrate = averageBitrate
        self.packetsLost = packetsLost
        self.latency = latency
        self.startTime = startTime
        self.duration = duration
        self.channelStats = channelStats
    }
}

// MARK: - Media Relay Channel Statistics
public struct MediaRelayChannelStats: Codable, Equatable {
    public let channelName: String
    public let dataTransferred: Int64
    public let bitrate: Int
    public let packetsLost: Int
    public let latency: Int
    public let connectionQuality: NetworkQuality
    
    public init(
        channelName: String,
        dataTransferred: Int64 = 0,
        bitrate: Int = 0,
        packetsLost: Int = 0,
        latency: Int = 0,
        connectionQuality: NetworkQuality = .unknown
    ) {
        self.channelName = channelName
        self.dataTransferred = dataTransferred
        self.bitrate = bitrate
        self.packetsLost = packetsLost
        self.latency = latency
        self.connectionQuality = connectionQuality
    }
}

// MARK: - Media Relay Event
public enum MediaRelayEvent {
    case channelConnected(String)
    case channelDisconnected(String)
    case channelError(String, Error)
    case dataTransferUpdate(MediaRelayStats)
    case networkQualityChanged(String, NetworkQuality)
}

// MARK: - Media Relay Error
public enum MediaRelayError: Error, LocalizedError {
    case channelNotFound(String)
    case invalidConfiguration
    case connectionFailed(String)
    case tokenExpired(String)
    case networkError(String)
    case providerError(String)
    
    public var errorDescription: String? {
        switch self {
        case .channelNotFound(let channel):
            return "频道未找到: \(channel)"
        case .invalidConfiguration:
            return "无效的中继配置"
        case .connectionFailed(let channel):
            return "连接失败: \(channel)"
        case .tokenExpired(let channel):
            return "Token已过期: \(channel)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .providerError(let message):
            return "服务商错误: \(message)"
        }
    }
}

// MARK: - Media Relay Statistics
public struct MediaRelayStatistics: Codable, Equatable, Sendable {
    public let totalRelayTime: TimeInterval
    public let audioBytesSent: Int64
    public let videoBytesSent: Int64
    public let packetsLost: Int
    public let averageLatency: Int
    public let destinationStats: [String: RelayChannelStatistics]
    
    public init(
        totalRelayTime: TimeInterval = 0,
        audioBytesSent: Int64 = 0,
        videoBytesSent: Int64 = 0,
        packetsLost: Int = 0,
        averageLatency: Int = 0,
        destinationStats: [String: RelayChannelStatistics] = [:]
    ) {
        self.totalRelayTime = totalRelayTime
        self.audioBytesSent = audioBytesSent
        self.videoBytesSent = videoBytesSent
        self.packetsLost = packetsLost
        self.averageLatency = averageLatency
        self.destinationStats = destinationStats
    }
}

// MARK: - Relay Channel Statistics
public struct RelayChannelStatistics: Codable, Equatable, Sendable {
    public let channelName: String
    public let bytesSent: Int64
    public let packetsLost: Int
    public let latency: Int
    public let connectionQuality: NetworkQuality
    
    public init(
        channelName: String,
        bytesSent: Int64 = 0,
        packetsLost: Int = 0,
        latency: Int = 0,
        connectionQuality: NetworkQuality = .unknown
    ) {
        self.channelName = channelName
        self.bytesSent = bytesSent
        self.packetsLost = packetsLost
        self.latency = latency
        self.connectionQuality = connectionQuality
    }
}

// MARK: - Relay Channel State
public enum RelayChannelState: String, Codable, CaseIterable, Sendable {
    case idle = "idle"
    case connecting = "connecting"
    case running = "running"
    case paused = "paused"
    case error = "error"
    
    public var isActive: Bool {
        return self == .running
    }
    
    public var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .connecting: return "连接中"
        case .running: return "运行中"
        case .paused: return "已暂停"
        case .error: return "错误"
        }
    }
}