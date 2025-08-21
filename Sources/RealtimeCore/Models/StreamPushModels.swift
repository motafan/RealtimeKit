import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
#endif

// Stream Push State is defined in Enums.swift

// MARK: - Stream Push Configuration
public struct StreamPushConfig: Codable, Equatable, Sendable {
    public let pushUrl: String
    public let width: Int
    public let height: Int
    public let bitrate: Int
    public let framerate: Int
    public let layout: StreamLayout
    public let backgroundColor: String  // Hex color string instead of PlatformColor
    
    public init(
        pushUrl: String,
        width: Int,
        height: Int,
        bitrate: Int,
        framerate: Int,
        layout: StreamLayout,
        backgroundColor: String = "#000000"  // Default to black
    ) {
        self.pushUrl = pushUrl
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.framerate = framerate
        self.layout = layout
        self.backgroundColor = backgroundColor
    }
    
    /// Validate the stream push configuration
    /// - Throws: RealtimeError if configuration is invalid
    public func validate() throws {
        guard !pushUrl.isEmpty else {
            throw RealtimeError.invalidStreamConfig("Push URL cannot be empty")
        }
        
        guard width > 0 && height > 0 else {
            throw RealtimeError.invalidStreamConfig("Width and height must be greater than 0")
        }
        
        guard bitrate > 0 else {
            throw RealtimeError.invalidStreamConfig("Bitrate must be greater than 0")
        }
        
        guard framerate > 0 else {
            throw RealtimeError.invalidStreamConfig("Frame rate must be greater than 0")
        }
    }
    
    // MARK: - Convenience Initializers
    
    /// Create a standard 720p stream configuration
    public static func standard720p(pushUrl: String) throws -> StreamPushConfig {
        return StreamPushConfig(
            pushUrl: pushUrl,
            width: 1280,
            height: 720,
            bitrate: 1000,
            framerate: 30,
            layout: .single,
            backgroundColor: "#000000"
        )
    }
    
    /// Create a standard 1080p stream configuration
    public static func standard1080p(pushUrl: String) throws -> StreamPushConfig {
        return StreamPushConfig(
            pushUrl: pushUrl,
            width: 1920,
            height: 1080,
            bitrate: 2000,
            framerate: 30,
            layout: .single,
            backgroundColor: "#000000"
        )
    }
    
    /// Create a standard 480p stream configuration
    public static func standard480p(pushUrl: String) throws -> StreamPushConfig {
        return StreamPushConfig(
            pushUrl: pushUrl,
            width: 854,
            height: 480,
            bitrate: 500,
            framerate: 30,
            layout: .single,
            backgroundColor: "#000000"
        )
    }
}

// MARK: - Stream Layout
public enum StreamLayout: Codable, Equatable, Sendable {
    case single
    case dual
    case quad
    case custom([StreamLayoutRegion])
    
    /// Create a custom layout with background color and user regions
    public static func customLayout(backgroundColor: String, userRegions: [StreamLayoutRegion]) -> StreamLayout {
        return .custom(userRegions)
    }
    
    public var displayName: String {
        switch self {
        case .single: return "单人布局"
        case .dual: return "双人布局"
        case .quad: return "四人布局"
        case .custom: return "自定义布局"
        }
    }
    
    /// Validate the stream layout
    /// - Throws: RealtimeError if layout is invalid
    public func validate() throws {
        switch self {
        case .custom(let regions):
            guard !regions.isEmpty else {
                throw RealtimeError.invalidStreamConfig("Custom layout must have at least one region")
            }
            guard regions.count <= 16 else {
                throw RealtimeError.invalidStreamConfig("Custom layout cannot have more than 16 regions")
            }
        default:
            break
        }
    }
}

// MARK: - Stream Layout Region
public struct StreamLayoutRegion: Codable, Equatable, Sendable {
    public let userId: String
    public let x: Float
    public let y: Float
    public let width: Float
    public let height: Float
    public let zOrder: Int
    public let alpha: Float
    
    public init(
        userId: String,
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        zOrder: Int = 0,
        alpha: Float = 1.0
    ) {
        self.userId = userId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.zOrder = zOrder
        self.alpha = alpha
    }
}

// MARK: - Stream Push Statistics
public struct StreamPushStats: Codable, Equatable, Sendable {
    public let startTime: Date
    public let duration: TimeInterval
    public let totalFramesSent: Int64
    public let totalBytesSent: Int64
    public let averageBitrate: Int
    public let currentBitrate: Int
    public let frameRate: Int
    public let droppedFrames: Int64
    public let networkQuality: NetworkQuality
    
    public init(
        startTime: Date = Date(),
        duration: TimeInterval = 0,
        totalFramesSent: Int64 = 0,
        totalBytesSent: Int64 = 0,
        averageBitrate: Int = 0,
        currentBitrate: Int = 0,
        frameRate: Int = 0,
        droppedFrames: Int64 = 0,
        networkQuality: NetworkQuality = .unknown
    ) {
        self.startTime = startTime
        self.duration = duration
        self.totalFramesSent = totalFramesSent
        self.totalBytesSent = totalBytesSent
        self.averageBitrate = averageBitrate
        self.currentBitrate = currentBitrate
        self.frameRate = frameRate
        self.droppedFrames = droppedFrames
        self.networkQuality = networkQuality
    }
}

// MARK: - Network Quality
public enum NetworkQuality: String, Codable, CaseIterable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case poor = "poor"
    case bad = "bad"
    case veryBad = "very_bad"
    case down = "down"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .poor: return "一般"
        case .bad: return "较差"
        case .veryBad: return "很差"
        case .down: return "断开"
        case .unknown: return "未知"
        }
    }
    
    public var colorHex: String {
        switch self {
        case .excellent: return "#00FF00"  // Green
        case .good: return "#0000FF"       // Blue
        case .poor: return "#FFFF00"       // Yellow
        case .bad: return "#FFA500"        // Orange
        case .veryBad, .down: return "#FF0000"  // Red
        case .unknown: return "#808080"    // Gray
        }
    }
}

// MARK: - Type Aliases for Backward Compatibility
public typealias UserRegion = StreamLayoutRegion