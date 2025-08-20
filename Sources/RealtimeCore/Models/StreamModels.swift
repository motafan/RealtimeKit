// StreamModels.swift
// Stream push and media relay configuration models

import Foundation

/// Stream push configuration for live streaming
public struct StreamPushConfig: Codable, Equatable, Sendable {
    public let pushUrl: String
    public let width: Int
    public let height: Int
    public let bitrate: Int        // kbps
    public let frameRate: Int      // fps
    public let layout: StreamLayout
    
    /// Initialize stream push configuration with validation
    /// - Parameters:
    ///   - pushUrl: RTMP push URL
    ///   - width: Video width in pixels
    ///   - height: Video height in pixels
    ///   - bitrate: Video bitrate in kbps
    ///   - frameRate: Video frame rate in fps
    ///   - layout: Stream layout configuration
    /// - Throws: RealtimeError if configuration is invalid
    public init(
        pushUrl: String,
        width: Int,
        height: Int,
        bitrate: Int,
        frameRate: Int,
        layout: StreamLayout
    ) throws {
        // Validate push URL
        try Self.validatePushUrl(pushUrl)
        
        // Validate dimensions
        try Self.validateDimensions(width: width, height: height)
        
        // Validate bitrate
        try Self.validateBitrate(bitrate)
        
        // Validate frame rate
        try Self.validateFrameRate(frameRate)
        
        // Validate layout
        try layout.validate()
        
        self.pushUrl = pushUrl
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.layout = layout
    }
    
    /// Create configuration without validation (for internal use)
    internal init(
        pushUrl: String,
        width: Int,
        height: Int,
        bitrate: Int,
        frameRate: Int,
        layout: StreamLayout,
        skipValidation: Bool
    ) {
        self.pushUrl = pushUrl
        self.width = max(1, width)
        self.height = max(1, height)
        self.bitrate = max(1, bitrate)
        self.frameRate = max(1, min(60, frameRate))
        self.layout = layout
    }
    
    /// Video resolution as string
    public var resolution: String {
        return "\(width)x\(height)"
    }
    
    /// Check if configuration is valid
    public var isValid: Bool {
        do {
            try Self.validatePushUrl(pushUrl)
            try Self.validateDimensions(width: width, height: height)
            try Self.validateBitrate(bitrate)
            try Self.validateFrameRate(frameRate)
            try layout.validate()
            return true
        } catch {
            return false
        }
    }
    
    /// Validate the entire configuration
    /// - Throws: RealtimeError if configuration is invalid
    public func validate() throws {
        try Self.validatePushUrl(pushUrl)
        try Self.validateDimensions(width: width, height: height)
        try Self.validateBitrate(bitrate)
        try Self.validateFrameRate(frameRate)
        try layout.validate()
    }
    
    // MARK: - Validation Methods
    
    /// Validate push URL format
    /// - Parameter pushUrl: RTMP push URL
    /// - Throws: RealtimeError.invalidStreamConfig if URL is invalid
    private static func validatePushUrl(_ pushUrl: String) throws {
        guard !pushUrl.isEmpty else {
            throw RealtimeError.invalidStreamConfig("Push URL cannot be empty")
        }
        
        guard pushUrl.hasPrefix("rtmp://") || pushUrl.hasPrefix("rtmps://") else {
            throw RealtimeError.invalidStreamConfig("Push URL must start with rtmp:// or rtmps://")
        }
        
        guard URL(string: pushUrl) != nil else {
            throw RealtimeError.invalidStreamConfig("Invalid push URL format")
        }
    }
    
    /// Validate video dimensions
    /// - Parameters:
    ///   - width: Video width in pixels
    ///   - height: Video height in pixels
    /// - Throws: RealtimeError.invalidStreamConfig if dimensions are invalid
    private static func validateDimensions(width: Int, height: Int) throws {
        guard width > 0 && height > 0 else {
            throw RealtimeError.invalidStreamConfig("Width and height must be greater than 0")
        }
        
        guard width >= 160 && height >= 120 else {
            throw RealtimeError.invalidStreamConfig("Minimum resolution is 160x120")
        }
        
        guard width <= 1920 && height <= 1080 else {
            throw RealtimeError.invalidStreamConfig("Maximum resolution is 1920x1080")
        }
        
        // Check for common aspect ratios
        let aspectRatio = Double(width) / Double(height)
        let commonRatios = [16.0/9.0, 4.0/3.0, 1.0, 9.0/16.0, 3.0/4.0]
        let tolerance = 0.1
        
        let isValidRatio = commonRatios.contains { abs($0 - aspectRatio) < tolerance }
        guard isValidRatio else {
            throw RealtimeError.invalidStreamConfig("Unsupported aspect ratio: \(String(format: "%.2f", aspectRatio))")
        }
    }
    
    /// Validate bitrate
    /// - Parameter bitrate: Video bitrate in kbps
    /// - Throws: RealtimeError.invalidStreamConfig if bitrate is invalid
    private static func validateBitrate(_ bitrate: Int) throws {
        guard bitrate > 0 else {
            throw RealtimeError.invalidStreamConfig("Bitrate must be greater than 0")
        }
        
        guard bitrate >= 100 else {
            throw RealtimeError.invalidStreamConfig("Minimum bitrate is 100 kbps")
        }
        
        guard bitrate <= 10000 else {
            throw RealtimeError.invalidStreamConfig("Maximum bitrate is 10000 kbps")
        }
    }
    
    /// Validate frame rate
    /// - Parameter frameRate: Video frame rate in fps
    /// - Throws: RealtimeError.invalidStreamConfig if frame rate is invalid
    private static func validateFrameRate(_ frameRate: Int) throws {
        guard frameRate > 0 else {
            throw RealtimeError.invalidStreamConfig("Frame rate must be greater than 0")
        }
        
        let validFrameRates = [15, 24, 25, 30, 60]
        guard validFrameRates.contains(frameRate) else {
            throw RealtimeError.invalidStreamConfig("Supported frame rates: \(validFrameRates.map(String.init).joined(separator: ", "))")
        }
    }
    
    // MARK: - Predefined Configurations
    
    /// Standard 720p configuration
    /// - Parameters:
    ///   - pushUrl: RTMP push URL
    ///   - layout: Stream layout (default: single user)
    /// - Returns: StreamPushConfig for 720p streaming
    public static func standard720p(pushUrl: String, layout: StreamLayout = .singleUser) throws -> StreamPushConfig {
        return try StreamPushConfig(
            pushUrl: pushUrl,
            width: 1280,
            height: 720,
            bitrate: 2000,
            frameRate: 30,
            layout: layout
        )
    }
    
    /// Standard 1080p configuration
    /// - Parameters:
    ///   - pushUrl: RTMP push URL
    ///   - layout: Stream layout (default: single user)
    /// - Returns: StreamPushConfig for 1080p streaming
    public static func standard1080p(pushUrl: String, layout: StreamLayout = .singleUser) throws -> StreamPushConfig {
        return try StreamPushConfig(
            pushUrl: pushUrl,
            width: 1920,
            height: 1080,
            bitrate: 4000,
            frameRate: 30,
            layout: layout
        )
    }
}

/// Stream layout configuration
public struct StreamLayout: Codable, Equatable, Sendable {
    public let backgroundColor: String     // Hex color code
    public let userRegions: [UserRegion]   // User video regions
    
    /// Initialize stream layout with validation
    /// - Parameters:
    ///   - backgroundColor: Background color in hex format
    ///   - userRegions: Array of user video regions
    /// - Throws: RealtimeError if layout configuration is invalid
    public init(
        backgroundColor: String = "#000000",
        userRegions: [UserRegion] = []
    ) throws {
        try Self.validateBackgroundColor(backgroundColor)
        try Self.validateUserRegions(userRegions)
        
        self.backgroundColor = backgroundColor
        self.userRegions = userRegions
    }
    
    /// Create layout without validation (for internal use)
    internal init(
        backgroundColor: String,
        userRegions: [UserRegion],
        skipValidation: Bool
    ) {
        self.backgroundColor = backgroundColor
        self.userRegions = userRegions
    }
    
    /// Validate the entire layout configuration
    /// - Throws: RealtimeError if layout is invalid
    public func validate() throws {
        try Self.validateBackgroundColor(backgroundColor)
        try Self.validateUserRegions(userRegions)
    }
    
    /// Check if layout is valid
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
    
    /// Get total coverage area of all user regions
    public var totalCoverage: Float {
        return userRegions.reduce(0) { $0 + ($1.width * $1.height) }
    }
    
    /// Check if regions overlap
    public var hasOverlappingRegions: Bool {
        for i in 0..<userRegions.count {
            for j in (i+1)..<userRegions.count {
                if userRegions[i].overlaps(with: userRegions[j]) {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Validation Methods
    
    /// Validate background color format
    /// - Parameter color: Hex color string
    /// - Throws: RealtimeError.invalidStreamConfig if color format is invalid
    private static func validateBackgroundColor(_ color: String) throws {
        guard !color.isEmpty else {
            throw RealtimeError.invalidStreamConfig("Background color cannot be empty")
        }
        
        guard color.hasPrefix("#") else {
            throw RealtimeError.invalidStreamConfig("Background color must start with #")
        }
        
        let hexString = String(color.dropFirst())
        guard hexString.count == 6 else {
            throw RealtimeError.invalidStreamConfig("Background color must be 6-digit hex format (#RRGGBB)")
        }
        
        guard hexString.allSatisfy({ $0.isHexDigit }) else {
            throw RealtimeError.invalidStreamConfig("Background color contains invalid hex characters")
        }
    }
    
    /// Validate user regions array
    /// - Parameter regions: Array of user regions
    /// - Throws: RealtimeError.invalidStreamConfig if regions are invalid
    private static func validateUserRegions(_ regions: [UserRegion]) throws {
        guard regions.count <= 16 else {
            throw RealtimeError.invalidStreamConfig("Maximum 16 user regions allowed")
        }
        
        // Validate each region
        for region in regions {
            try region.validate()
        }
        
        // Check for duplicate user IDs
        let userIds = regions.map { $0.userId }
        let uniqueUserIds = Set(userIds)
        guard userIds.count == uniqueUserIds.count else {
            throw RealtimeError.invalidStreamConfig("Duplicate user IDs in layout regions")
        }
        
        // Check z-order conflicts
        let zOrders = regions.map { $0.zOrder }
        let uniqueZOrders = Set(zOrders)
        if zOrders.count != uniqueZOrders.count {
            // Allow same z-order but warn about potential rendering issues
            print("Warning: Multiple regions have the same z-order, rendering order may be unpredictable")
        }
    }
    
    // MARK: - Layout Manipulation
    
    /// Add a user region to the layout
    /// - Parameter region: User region to add
    /// - Returns: New layout with the added region
    /// - Throws: RealtimeError if the resulting layout would be invalid
    public func addingRegion(_ region: UserRegion) throws -> StreamLayout {
        var newRegions = userRegions
        
        // Remove existing region for the same user
        newRegions.removeAll { $0.userId == region.userId }
        
        // Add new region
        newRegions.append(region)
        
        return try StreamLayout(
            backgroundColor: backgroundColor,
            userRegions: newRegions
        )
    }
    
    /// Remove a user region from the layout
    /// - Parameter userId: User ID to remove
    /// - Returns: New layout without the specified user
    public func removingRegion(for userId: String) throws -> StreamLayout {
        let newRegions = userRegions.filter { $0.userId != userId }
        
        return try StreamLayout(
            backgroundColor: backgroundColor,
            userRegions: newRegions
        )
    }
    
    /// Update background color
    /// - Parameter color: New background color
    /// - Returns: New layout with updated background color
    /// - Throws: RealtimeError if color format is invalid
    public func withBackgroundColor(_ color: String) throws -> StreamLayout {
        return try StreamLayout(
            backgroundColor: color,
            userRegions: userRegions
        )
    }
    
    // MARK: - Predefined Layouts
    
    /// Default single user layout
    public static let singleUser = StreamLayout(
        backgroundColor: "#000000",
        userRegions: [
            UserRegion(
                userId: "default_user",
                x: 0, y: 0,
                width: 1.0, height: 1.0,
                zOrder: 1,
                alpha: 1.0,
                skipValidation: true
            )
        ],
        skipValidation: true
    )
    
    /// Picture-in-picture layout (main + small overlay)
    /// - Parameters:
    ///   - mainUserId: Main user ID
    ///   - overlayUserId: Overlay user ID
    /// - Returns: PiP layout configuration
    public static func pictureInPicture(mainUserId: String, overlayUserId: String) throws -> StreamLayout {
        return try StreamLayout(
            backgroundColor: "#000000",
            userRegions: [
                try UserRegion(
                    userId: mainUserId,
                    x: 0, y: 0,
                    width: 1.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                ),
                try UserRegion(
                    userId: overlayUserId,
                    x: 0.7, y: 0.05,
                    width: 0.25, height: 0.25,
                    zOrder: 2,
                    alpha: 1.0
                )
            ]
        )
    }
    
    /// Side-by-side layout for two users
    /// - Parameters:
    ///   - leftUserId: Left user ID
    ///   - rightUserId: Right user ID
    /// - Returns: Side-by-side layout configuration
    public static func sideBySide(leftUserId: String, rightUserId: String) throws -> StreamLayout {
        return try StreamLayout(
            backgroundColor: "#000000",
            userRegions: [
                try UserRegion(
                    userId: leftUserId,
                    x: 0, y: 0,
                    width: 0.5, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                ),
                try UserRegion(
                    userId: rightUserId,
                    x: 0.5, y: 0,
                    width: 0.5, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            ]
        )
    }
    
    /// Grid layout for multiple users
    /// - Parameter userIds: Array of user IDs (max 9)
    /// - Returns: Grid layout configuration
    /// - Throws: RealtimeError if too many users or invalid configuration
    public static func grid(userIds: [String]) throws -> StreamLayout {
        guard !userIds.isEmpty else {
            throw RealtimeError.invalidStreamConfig("At least one user ID required for grid layout")
        }
        
        guard userIds.count <= 9 else {
            throw RealtimeError.invalidStreamConfig("Maximum 9 users supported in grid layout")
        }
        
        let rows: Int
        let cols: Int
        
        switch userIds.count {
        case 1:
            rows = 1; cols = 1
        case 2:
            rows = 1; cols = 2
        case 3, 4:
            rows = 2; cols = 2
        case 5, 6:
            rows = 2; cols = 3
        case 7, 8, 9:
            rows = 3; cols = 3
        default:
            rows = 3; cols = 3
        }
        
        let regionWidth = 1.0 / Float(cols)
        let regionHeight = 1.0 / Float(rows)
        
        var regions: [UserRegion] = []
        
        for (index, userId) in userIds.enumerated() {
            let row = index / cols
            let col = index % cols
            
            let x = Float(col) * regionWidth
            let y = Float(row) * regionHeight
            
            let region = try UserRegion(
                userId: userId,
                x: x, y: y,
                width: regionWidth, height: regionHeight,
                zOrder: 1,
                alpha: 1.0
            )
            regions.append(region)
        }
        
        return try StreamLayout(
            backgroundColor: "#000000",
            userRegions: regions
        )
    }
}

/// User video region in stream layout
public struct UserRegion: Codable, Equatable, Sendable {
    public let userId: String
    public let x: Float           // Normalized x position (0.0 - 1.0)
    public let y: Float           // Normalized y position (0.0 - 1.0)
    public let width: Float       // Normalized width (0.0 - 1.0)
    public let height: Float      // Normalized height (0.0 - 1.0)
    public let zOrder: Int        // Layer order (higher = front)
    public let alpha: Float       // Transparency (0.0 - 1.0)
    
    /// Initialize user region with validation
    /// - Parameters:
    ///   - userId: User identifier
    ///   - x: Normalized x position (0.0 - 1.0)
    ///   - y: Normalized y position (0.0 - 1.0)
    ///   - width: Normalized width (0.0 - 1.0)
    ///   - height: Normalized height (0.0 - 1.0)
    ///   - zOrder: Layer order
    ///   - alpha: Transparency (0.0 - 1.0)
    /// - Throws: RealtimeError if parameters are invalid
    public init(
        userId: String,
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        zOrder: Int = 1,
        alpha: Float = 1.0
    ) throws {
        try Self.validateUserId(userId)
        try Self.validatePosition(x: x, y: y)
        try Self.validateSize(width: width, height: height)
        try Self.validateBounds(x: x, y: y, width: width, height: height)
        try Self.validateZOrder(zOrder)
        try Self.validateAlpha(alpha)
        
        self.userId = userId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.zOrder = zOrder
        self.alpha = alpha
    }
    
    /// Create region without validation (for internal use)
    internal init(
        userId: String,
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        zOrder: Int,
        alpha: Float,
        skipValidation: Bool
    ) {
        self.userId = userId
        self.x = max(0.0, min(1.0, x))
        self.y = max(0.0, min(1.0, y))
        self.width = max(0.0, min(1.0, width))
        self.height = max(0.0, min(1.0, height))
        self.zOrder = zOrder
        self.alpha = max(0.0, min(1.0, alpha))
    }
    
    /// Validate the user region
    /// - Throws: RealtimeError if region is invalid
    public func validate() throws {
        try Self.validateUserId(userId)
        try Self.validatePosition(x: x, y: y)
        try Self.validateSize(width: width, height: height)
        try Self.validateBounds(x: x, y: y, width: width, height: height)
        try Self.validateZOrder(zOrder)
        try Self.validateAlpha(alpha)
    }
    
    /// Check if region is valid
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
    
    /// Get the right edge of the region
    public var right: Float {
        return x + width
    }
    
    /// Get the bottom edge of the region
    public var bottom: Float {
        return y + height
    }
    
    /// Get the area of the region
    public var area: Float {
        return width * height
    }
    
    /// Check if this region overlaps with another region
    /// - Parameter other: Another user region
    /// - Returns: True if regions overlap
    public func overlaps(with other: UserRegion) -> Bool {
        return !(right <= other.x || x >= other.right || bottom <= other.y || y >= other.bottom)
    }
    
    /// Check if this region contains a point
    /// - Parameters:
    ///   - pointX: X coordinate of the point
    ///   - pointY: Y coordinate of the point
    /// - Returns: True if point is inside the region
    public func contains(pointX: Float, pointY: Float) -> Bool {
        return pointX >= x && pointX <= right && pointY >= y && pointY <= bottom
    }
    
    // MARK: - Validation Methods
    
    /// Validate user ID
    /// - Parameter userId: User identifier
    /// - Throws: RealtimeError.invalidStreamConfig if user ID is invalid
    private static func validateUserId(_ userId: String) throws {
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeError.invalidStreamConfig("User ID cannot be empty or whitespace")
        }
        
        guard userId.count <= 64 else {
            throw RealtimeError.invalidStreamConfig("User ID cannot exceed 64 characters")
        }
        
        // Check for valid characters (alphanumeric, underscore, hyphen)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard userId.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            throw RealtimeError.invalidStreamConfig("User ID can only contain alphanumeric characters, underscore, and hyphen")
        }
    }
    
    /// Validate position coordinates
    /// - Parameters:
    ///   - x: X position
    ///   - y: Y position
    /// - Throws: RealtimeError.invalidStreamConfig if position is invalid
    private static func validatePosition(x: Float, y: Float) throws {
        guard x >= 0.0 && x <= 1.0 else {
            throw RealtimeError.parameterOutOfRange("x position", "0.0 - 1.0")
        }
        
        guard y >= 0.0 && y <= 1.0 else {
            throw RealtimeError.parameterOutOfRange("y position", "0.0 - 1.0")
        }
    }
    
    /// Validate size dimensions
    /// - Parameters:
    ///   - width: Region width
    ///   - height: Region height
    /// - Throws: RealtimeError.invalidStreamConfig if size is invalid
    private static func validateSize(width: Float, height: Float) throws {
        guard width > 0.0 && width <= 1.0 else {
            throw RealtimeError.parameterOutOfRange("width", "0.0 - 1.0 (exclusive of 0)")
        }
        
        guard height > 0.0 && height <= 1.0 else {
            throw RealtimeError.parameterOutOfRange("height", "0.0 - 1.0 (exclusive of 0)")
        }
        
        // Minimum size check (at least 5% of screen)
        guard width >= 0.05 && height >= 0.05 else {
            throw RealtimeError.invalidStreamConfig("Minimum region size is 5% of screen width and height")
        }
    }
    
    /// Validate that region stays within bounds
    /// - Parameters:
    ///   - x: X position
    ///   - y: Y position
    ///   - width: Region width
    ///   - height: Region height
    /// - Throws: RealtimeError.invalidStreamConfig if region exceeds bounds
    private static func validateBounds(x: Float, y: Float, width: Float, height: Float) throws {
        guard x + width <= 1.0 else {
            throw RealtimeError.invalidStreamConfig("Region extends beyond right edge (x + width > 1.0)")
        }
        
        guard y + height <= 1.0 else {
            throw RealtimeError.invalidStreamConfig("Region extends beyond bottom edge (y + height > 1.0)")
        }
    }
    
    /// Validate z-order
    /// - Parameter zOrder: Layer order
    /// - Throws: RealtimeError.invalidStreamConfig if z-order is invalid
    private static func validateZOrder(_ zOrder: Int) throws {
        guard zOrder >= 0 && zOrder <= 100 else {
            throw RealtimeError.parameterOutOfRange("zOrder", "0 - 100")
        }
    }
    
    /// Validate alpha transparency
    /// - Parameter alpha: Transparency value
    /// - Throws: RealtimeError.invalidStreamConfig if alpha is invalid
    private static func validateAlpha(_ alpha: Float) throws {
        guard alpha >= 0.0 && alpha <= 1.0 else {
            throw RealtimeError.parameterOutOfRange("alpha", "0.0 - 1.0")
        }
    }
    
    // MARK: - Region Manipulation
    
    /// Move the region to a new position
    /// - Parameters:
    ///   - newX: New X position
    ///   - newY: New Y position
    /// - Returns: New region at the specified position
    /// - Throws: RealtimeError if the new position would be invalid
    public func moveTo(x newX: Float, y newY: Float) throws -> UserRegion {
        return try UserRegion(
            userId: userId,
            x: newX, y: newY,
            width: width, height: height,
            zOrder: zOrder,
            alpha: alpha
        )
    }
    
    /// Resize the region
    /// - Parameters:
    ///   - newWidth: New width
    ///   - newHeight: New height
    /// - Returns: New region with the specified size
    /// - Throws: RealtimeError if the new size would be invalid
    public func resizeTo(width newWidth: Float, height newHeight: Float) throws -> UserRegion {
        return try UserRegion(
            userId: userId,
            x: x, y: y,
            width: newWidth, height: newHeight,
            zOrder: zOrder,
            alpha: alpha
        )
    }
    
    /// Change the z-order of the region
    /// - Parameter newZOrder: New z-order
    /// - Returns: New region with the specified z-order
    /// - Throws: RealtimeError if the z-order is invalid
    public func withZOrder(_ newZOrder: Int) throws -> UserRegion {
        return try UserRegion(
            userId: userId,
            x: x, y: y,
            width: width, height: height,
            zOrder: newZOrder,
            alpha: alpha
        )
    }
    
    /// Change the transparency of the region
    /// - Parameter newAlpha: New alpha value
    /// - Returns: New region with the specified transparency
    /// - Throws: RealtimeError if the alpha value is invalid
    public func withAlpha(_ newAlpha: Float) throws -> UserRegion {
        return try UserRegion(
            userId: userId,
            x: x, y: y,
            width: width, height: height,
            zOrder: zOrder,
            alpha: newAlpha
        )
    }
}

/// Media relay configuration for cross-channel streaming (需求 8.1)
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
    
    /// Add a destination channel
    /// - Parameter channel: Channel to add
    /// - Returns: New configuration with the added channel
    /// - Throws: RealtimeError if the resulting configuration would be invalid
    public func addingDestination(_ channel: RelayChannelInfo) throws -> MediaRelayConfig {
        var newDestinations = destinationChannels
        
        // Remove existing channel with same name
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
    
    /// Remove a destination channel
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
    
    /// Validate media relay configuration
    /// - Parameters:
    ///   - sourceChannel: Source channel information
    ///   - destinationChannels: Array of destination channels
    ///   - relayMode: Relay mode
    ///   - enableAudio: Whether audio is enabled
    ///   - enableVideo: Whether video is enabled
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
        
        guard destinationChannels.count <= 10 else {
            throw RealtimeError.invalidMediaRelayConfig("Maximum 10 destination channels allowed")
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
        
        // Ensure source channel is not in destinations
        guard !channelNames.contains(sourceChannel.channelName) else {
            throw RealtimeError.invalidMediaRelayConfig("Source channel cannot be a destination channel")
        }
        
        // Validate relay mode compatibility
        try validateRelayModeCompatibility(relayMode: relayMode, destinationCount: destinationChannels.count)
        
        // Ensure at least one media type is enabled
        guard enableAudio || enableVideo else {
            throw RealtimeError.invalidMediaRelayConfig("At least one media type (audio or video) must be enabled")
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
            guard destinationCount >= 2 else {
                throw RealtimeError.invalidMediaRelayConfig("Many-to-many relay mode requires at least 2 destination channels")
            }
        }
    }
    
    // MARK: - Predefined Configurations
    
    /// Create a simple one-to-one relay configuration
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

/// Media relay mode enumeration (需求 8.1)
public enum MediaRelayMode: String, CaseIterable, Codable, Sendable {
    case oneToOne = "one_to_one"        // 1对1中继
    case oneToMany = "one_to_many"      // 1对多中继
    case manyToMany = "many_to_many"    // 多对多中继
    
    /// Display name for the relay mode
    public var displayName: String {
        switch self {
        case .oneToOne: return "一对一中继"
        case .oneToMany: return "一对多中继"
        case .manyToMany: return "多对多中继"
        }
    }
    
    /// Description of the relay mode
    public var description: String {
        switch self {
        case .oneToOne: return "将单个源频道的媒体流转发到单个目标频道"
        case .oneToMany: return "将单个源频道的媒体流转发到多个目标频道"
        case .manyToMany: return "在多个频道之间进行双向媒体流转发"
        }
    }
}

/// Relay channel information with validation (需求 8.4)
public struct RelayChannelInfo: Codable, Equatable, Sendable {
    public let channelName: String
    public let token: String?
    public let userId: String
    public let uid: UInt?  // Optional numeric user ID for some providers
    
    /// Initialize relay channel information with validation
    /// - Parameters:
    ///   - channelName: Channel name
    ///   - token: Optional authentication token
    ///   - userId: User identifier for this channel
    ///   - uid: Optional numeric user ID
    /// - Throws: RealtimeError if parameters are invalid
    public init(
        channelName: String,
        token: String? = nil,
        userId: String,
        uid: UInt? = nil
    ) throws {
        try Self.validateChannelName(channelName)
        try Self.validateUserId(userId)
        try Self.validateToken(token)
        
        self.channelName = channelName
        self.token = token
        self.userId = userId
        self.uid = uid
    }
    
    /// Create channel info without validation (for internal use)
    internal init(
        channelName: String,
        token: String?,
        userId: String,
        uid: UInt?,
        skipValidation: Bool
    ) {
        self.channelName = channelName
        self.token = token
        self.userId = userId
        self.uid = uid
    }
    
    /// Check if channel info is valid
    public var isValid: Bool {
        do {
            try validate()
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
        try Self.validateToken(token)
    }
    
    /// Update the token for this channel
    /// - Parameter newToken: New authentication token
    /// - Returns: New RelayChannelInfo with updated token
    public func withToken(_ newToken: String?) throws -> RelayChannelInfo {
        return try RelayChannelInfo(
            channelName: channelName,
            token: newToken,
            userId: userId,
            uid: uid
        )
    }
    
    // MARK: - Validation Methods
    
    /// Validate channel name
    /// - Parameter channelName: Channel name to validate
    /// - Throws: RealtimeError if channel name is invalid
    private static func validateChannelName(_ channelName: String) throws {
        guard !channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeError.invalidMediaRelayConfig("Channel name cannot be empty or whitespace")
        }
        
        guard channelName.count <= 64 else {
            throw RealtimeError.invalidMediaRelayConfig("Channel name cannot exceed 64 characters")
        }
        
        // Check for valid characters (alphanumeric, underscore, hyphen)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard channelName.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            throw RealtimeError.invalidMediaRelayConfig("Channel name can only contain alphanumeric characters, underscore, and hyphen")
        }
    }
    
    /// Validate user ID
    /// - Parameter userId: User ID to validate
    /// - Throws: RealtimeError if user ID is invalid
    private static func validateUserId(_ userId: String) throws {
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeError.invalidMediaRelayConfig("User ID cannot be empty or whitespace")
        }
        
        guard userId.count <= 64 else {
            throw RealtimeError.invalidMediaRelayConfig("User ID cannot exceed 64 characters")
        }
        
        // Check for valid characters (alphanumeric, underscore, hyphen)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard userId.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
            throw RealtimeError.invalidMediaRelayConfig("User ID can only contain alphanumeric characters, underscore, and hyphen")
        }
    }
    
    /// Validate token format
    /// - Parameter token: Token to validate (optional)
    /// - Throws: RealtimeError if token format is invalid
    private static func validateToken(_ token: String?) throws {
        guard let token = token else { return }
        
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeError.invalidMediaRelayConfig("Token cannot be empty or whitespace")
        }
        
        guard token.count <= 512 else {
            throw RealtimeError.invalidMediaRelayConfig("Token cannot exceed 512 characters")
        }
    }
}

/// Media relay state information (需求 8.3, 8.5)
public struct MediaRelayState: Codable, Equatable, Sendable {
    public let overallState: RelayState
    public let sourceChannel: String
    public let destinationStates: [String: RelayChannelState]
    public let startTime: Date?
    public let lastUpdateTime: Date
    
    /// Initialize media relay state
    /// - Parameters:
    ///   - overallState: Overall relay state
    ///   - sourceChannel: Source channel name
    ///   - destinationStates: Dictionary of destination channel states
    ///   - startTime: When the relay started (nil if not started)
    ///   - lastUpdateTime: Last state update time
    public init(
        overallState: RelayState,
        sourceChannel: String,
        destinationStates: [String: RelayChannelState] = [:],
        startTime: Date? = nil,
        lastUpdateTime: Date = Date()
    ) {
        self.overallState = overallState
        self.sourceChannel = sourceChannel
        self.destinationStates = destinationStates
        self.startTime = startTime
        self.lastUpdateTime = lastUpdateTime
    }
    
    /// Get state for a specific destination channel
    /// - Parameter channelName: Name of the destination channel
    /// - Returns: RelayChannelState if found, nil otherwise
    public func stateForDestination(_ channelName: String) -> RelayChannelState? {
        return destinationStates[channelName]
    }
    
    /// Check if all destinations are connected
    public var allDestinationsConnected: Bool {
        return !destinationStates.isEmpty && destinationStates.values.allSatisfy { $0 == .connected }
    }
    
    /// Get list of connected destination channels
    public var connectedDestinations: [String] {
        return destinationStates.compactMap { key, value in
            value == .connected ? key : nil
        }
    }
    
    /// Get list of failed destination channels
    public var failedDestinations: [String] {
        return destinationStates.compactMap { key, value in
            if case .failure = value { return key } else { return nil }
        }
    }
    
    /// Get relay duration if started
    public var relayDuration: TimeInterval? {
        guard let startTime = startTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Update state for a destination channel
    /// - Parameters:
    ///   - channelName: Name of the destination channel
    ///   - newState: New state for the channel
    /// - Returns: New MediaRelayState with updated destination state
    public func updatingDestination(_ channelName: String, state newState: RelayChannelState) -> MediaRelayState {
        var newDestinationStates = destinationStates
        newDestinationStates[channelName] = newState
        
        // Update overall state based on destination states
        let newOverallState = calculateOverallState(from: newDestinationStates)
        
        return MediaRelayState(
            overallState: newOverallState,
            sourceChannel: sourceChannel,
            destinationStates: newDestinationStates,
            startTime: startTime,
            lastUpdateTime: Date()
        )
    }
    
    /// Calculate overall state from destination states
    /// - Parameter destinationStates: Dictionary of destination states
    /// - Returns: Overall relay state
    private func calculateOverallState(from destinationStates: [String: RelayChannelState]) -> RelayState {
        guard !destinationStates.isEmpty else { return .stopped }
        
        let states = Array(destinationStates.values)
        
        // If any destination has failed, overall state is failure
        if states.contains(where: { if case .failure = $0 { return true } else { return false } }) {
            return .failure(MediaRelayError.destinationConnectionFailed)
        }
        
        // If any destination is connecting, overall state is connecting
        if states.contains(.connecting) {
            return .connecting
        }
        
        // If all destinations are connected, overall state is running
        if states.allSatisfy({ $0 == .connected }) {
            return .running
        }
        
        // Mixed states - consider as connecting
        return .connecting
    }
}

/// Overall relay state enumeration (需求 8.3)
public enum RelayState: Codable, Equatable, Sendable {
    case stopped
    case connecting
    case running
    case failure(MediaRelayError)
    
    /// Display name for the relay state
    public var displayName: String {
        switch self {
        case .stopped: return "已停止"
        case .connecting: return "连接中"
        case .running: return "运行中"
        case .failure: return "失败"
        }
    }
    
    /// Check if the relay is active (connecting or running)
    public var isActive: Bool {
        switch self {
        case .connecting, .running: return true
        case .stopped, .failure: return false
        }
    }
}

/// Individual channel relay state (需求 8.3)
public enum RelayChannelState: Codable, Equatable, Sendable {
    case idle
    case connecting
    case connected
    case paused
    case disconnected
    case failure(MediaRelayError)
    
    /// Display name for the channel state
    public var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .paused: return "已暂停"
        case .disconnected: return "已断开"
        case .failure: return "失败"
        }
    }
    
    /// Check if the channel is active (connecting, connected, or paused)
    public var isActive: Bool {
        switch self {
        case .connecting, .connected, .paused: return true
        case .idle, .disconnected, .failure: return false
        }
    }
}

/// Media relay error types (需求 8.3)
public enum MediaRelayError: Error, Codable, Equatable, Sendable {
    case invalidConfiguration(String)
    case sourceChannelConnectionFailed
    case destinationConnectionFailed
    case serverConnectionLost
    case serverNoResponse
    case tokenExpired
    case insufficientPermissions
    case networkError(String)
    case providerError(String)
    case unknown(String)
    
    /// Localized error description
    public var localizedDescription: String {
        switch self {
        case .invalidConfiguration(let message):
            return "配置无效: \(message)"
        case .sourceChannelConnectionFailed:
            return "源频道连接失败"
        case .destinationConnectionFailed:
            return "目标频道连接失败"
        case .serverConnectionLost:
            return "服务器连接丢失"
        case .serverNoResponse:
            return "服务器无响应"
        case .tokenExpired:
            return "Token已过期"
        case .insufficientPermissions:
            return "权限不足"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .providerError(let message):
            return "服务商错误: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
    
    /// Check if the error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .invalidConfiguration, .insufficientPermissions:
            return false
        case .sourceChannelConnectionFailed, .destinationConnectionFailed,
             .serverConnectionLost, .serverNoResponse, .tokenExpired,
             .networkError, .providerError, .unknown:
            return true
        }
    }
}

/// Media relay statistics (需求 8.6)
public struct MediaRelayStatistics: Codable, Equatable, Sendable {
    public let totalRelayTime: TimeInterval
    public let audioBytesSent: UInt64
    public let videoBytesSent: UInt64
    public let audioPacketsSent: UInt64
    public let videoPacketsSent: UInt64
    public let destinationStats: [String: RelayChannelStatistics]
    public let lastUpdateTime: Date
    
    /// Initialize media relay statistics
    /// - Parameters:
    ///   - totalRelayTime: Total time the relay has been active
    ///   - audioBytesSent: Total audio bytes sent
    ///   - videoBytesSent: Total video bytes sent
    ///   - audioPacketsSent: Total audio packets sent
    ///   - videoPacketsSent: Total video packets sent
    ///   - destinationStats: Per-destination statistics
    ///   - lastUpdateTime: Last statistics update time
    public init(
        totalRelayTime: TimeInterval = 0,
        audioBytesSent: UInt64 = 0,
        videoBytesSent: UInt64 = 0,
        audioPacketsSent: UInt64 = 0,
        videoPacketsSent: UInt64 = 0,
        destinationStats: [String: RelayChannelStatistics] = [:],
        lastUpdateTime: Date = Date()
    ) {
        self.totalRelayTime = totalRelayTime
        self.audioBytesSent = audioBytesSent
        self.videoBytesSent = videoBytesSent
        self.audioPacketsSent = audioPacketsSent
        self.videoPacketsSent = videoPacketsSent
        self.destinationStats = destinationStats
        self.lastUpdateTime = lastUpdateTime
    }
    
    /// Total bytes sent (audio + video)
    public var totalBytesSent: UInt64 {
        return audioBytesSent + videoBytesSent
    }
    
    /// Total packets sent (audio + video)
    public var totalPacketsSent: UInt64 {
        return audioPacketsSent + videoPacketsSent
    }
    
    /// Average bitrate in kbps
    public var averageBitrate: Double {
        guard totalRelayTime > 0 else { return 0 }
        return Double(totalBytesSent * 8) / (totalRelayTime * 1000)
    }
    
    /// Get statistics for a specific destination
    /// - Parameter channelName: Name of the destination channel
    /// - Returns: RelayChannelStatistics if found, nil otherwise
    public func statisticsForDestination(_ channelName: String) -> RelayChannelStatistics? {
        return destinationStats[channelName]
    }
}

/// Per-channel relay statistics (需求 8.6)
public struct RelayChannelStatistics: Codable, Equatable, Sendable {
    public let channelName: String
    public let connectionTime: TimeInterval
    public let audioBytesSent: UInt64
    public let videoBytesSent: UInt64
    public let audioPacketsSent: UInt64
    public let videoPacketsSent: UInt64
    public let packetsLost: UInt64
    public let averageLatency: TimeInterval
    public let lastUpdateTime: Date
    
    /// Initialize channel statistics
    /// - Parameters:
    ///   - channelName: Name of the channel
    ///   - connectionTime: Time connected to this channel
    ///   - audioBytesSent: Audio bytes sent to this channel
    ///   - videoBytesSent: Video bytes sent to this channel
    ///   - audioPacketsSent: Audio packets sent to this channel
    ///   - videoPacketsSent: Video packets sent to this channel
    ///   - packetsLost: Number of packets lost
    ///   - averageLatency: Average latency to this channel
    ///   - lastUpdateTime: Last update time
    public init(
        channelName: String,
        connectionTime: TimeInterval = 0,
        audioBytesSent: UInt64 = 0,
        videoBytesSent: UInt64 = 0,
        audioPacketsSent: UInt64 = 0,
        videoPacketsSent: UInt64 = 0,
        packetsLost: UInt64 = 0,
        averageLatency: TimeInterval = 0,
        lastUpdateTime: Date = Date()
    ) {
        self.channelName = channelName
        self.connectionTime = connectionTime
        self.audioBytesSent = audioBytesSent
        self.videoBytesSent = videoBytesSent
        self.audioPacketsSent = audioPacketsSent
        self.videoPacketsSent = videoPacketsSent
        self.packetsLost = packetsLost
        self.averageLatency = averageLatency
        self.lastUpdateTime = lastUpdateTime
    }
    
    /// Total bytes sent to this channel
    public var totalBytesSent: UInt64 {
        return audioBytesSent + videoBytesSent
    }
    
    /// Total packets sent to this channel
    public var totalPacketsSent: UInt64 {
        return audioPacketsSent + videoPacketsSent
    }
    
    /// Packet loss rate (0.0 - 1.0)
    public var packetLossRate: Double {
        let totalPackets = totalPacketsSent + packetsLost
        guard totalPackets > 0 else { return 0 }
        return Double(packetsLost) / Double(totalPackets)
    }
    
    /// Average bitrate for this channel in kbps
    public var averageBitrate: Double {
        guard connectionTime > 0 else { return 0 }
        return Double(totalBytesSent * 8) / (connectionTime * 1000)
    }
}

// MARK: - Extensions

extension Character {
    /// Check if character is a valid hexadecimal digit
    var isHexDigit: Bool {
        return isASCII && (isNumber || ("a"..."f").contains(lowercased()) || ("A"..."F").contains(self))
    }
}