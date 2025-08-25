import Foundation

// MARK: - Stream Push Validation Errors

/// 转推流配置验证错误
public enum StreamPushValidationError: LocalizedError {
    case invalidURL(String)
    case invalidResolution(width: Int, height: Int)
    case invalidBitrate(Int)
    case invalidFrameRate(Int)
    case invalidUserRegion(userId: String, reason: String)
    case invalidLayoutConfiguration(String)
    case invalidAudioConfiguration(String)
    case invalidWatermarkConfiguration(String)
    case emptyUserRegions
    case duplicateUserRegions([String])
    case regionOutOfBounds(userId: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid stream push URL: \(url)"
        case .invalidResolution(let width, let height):
            return "Invalid resolution: \(width)x\(height). Must be between 16x16 and 1920x1080"
        case .invalidBitrate(let bitrate):
            return "Invalid bitrate: \(bitrate). Must be between 1 and 10000 kbps"
        case .invalidFrameRate(let frameRate):
            return "Invalid frame rate: \(frameRate). Must be between 1 and 60 fps"
        case .invalidUserRegion(let userId, let reason):
            return "Invalid user region for \(userId): \(reason)"
        case .invalidLayoutConfiguration(let reason):
            return "Invalid layout configuration: \(reason)"
        case .invalidAudioConfiguration(let reason):
            return "Invalid audio configuration: \(reason)"
        case .invalidWatermarkConfiguration(let reason):
            return "Invalid watermark configuration: \(reason)"
        case .emptyUserRegions:
            return "User regions cannot be empty for custom layout"
        case .duplicateUserRegions(let userIds):
            return "Duplicate user regions found: \(userIds.joined(separator: ", "))"
        case .regionOutOfBounds(let userId):
            return "User region for \(userId) is out of canvas bounds"
        }
    }
}

/// 推流配置
/// 需求: 7.1, 7.5 - 支持设置推流 URL、分辨率、码率、帧率
public struct StreamPushConfig: Codable, Sendable {
    /// 推流URL
    public let url: String
    
    /// 推流布局配置
    public let layout: StreamLayout
    
    /// 音频配置
    public let audioConfig: StreamAudioConfig
    
    /// 视频配置
    public let videoConfig: StreamVideoConfig
    
    /// 是否启用转码
    public let enableTranscoding: Bool
    
    /// 自定义背景颜色（十六进制格式，如 "#FFFFFF"）
    public let backgroundColor: String
    
    /// 推流质量
    public let quality: StreamQuality
    
    /// 水印配置（可选）
    public let watermark: StreamWatermark?
    
    public init(
        url: String,
        layout: StreamLayout? = nil,
        audioConfig: StreamAudioConfig? = nil,
        videoConfig: StreamVideoConfig? = nil,
        enableTranscoding: Bool = true,
        backgroundColor: String = "#000000",
        quality: StreamQuality = .standard,
        watermark: StreamWatermark? = nil
    ) throws {
        // 验证配置 (需求 7.1)
        try Self.validateURL(url)
        try Self.validateBackgroundColor(backgroundColor)
        
        let finalLayout = layout ?? StreamLayout()
        let finalAudioConfig = audioConfig ?? StreamAudioConfig()
        let finalVideoConfig = videoConfig ?? StreamVideoConfig()
        
        try finalLayout.validate()
        try finalAudioConfig.validate()
        try finalVideoConfig.validate()
        
        if let watermark = watermark {
            try watermark.validate()
        }
        
        self.url = url
        self.layout = finalLayout
        self.audioConfig = finalAudioConfig
        self.videoConfig = finalVideoConfig
        self.enableTranscoding = enableTranscoding
        self.backgroundColor = backgroundColor
        self.quality = quality
        self.watermark = watermark
    }
    
    // MARK: - Validation Methods (需求 7.5)
    
    /// 验证推流配置
    public func validate() throws {
        try Self.validateURL(url)
        try layout.validate()
        try audioConfig.validate()
        try videoConfig.validate()
        try Self.validateBackgroundColor(backgroundColor)
        if let watermark = watermark {
            try watermark.validate()
        }
    }
    
    /// 验证推流URL
    private static func validateURL(_ url: String) throws {
        guard !url.isEmpty else {
            throw StreamPushValidationError.invalidURL("URL cannot be empty")
        }
        
        guard let urlComponents = URLComponents(string: url),
              let scheme = urlComponents.scheme else {
            throw StreamPushValidationError.invalidURL("Invalid URL format")
        }
        
        let supportedSchemes = ["rtmp", "rtmps", "http", "https"]
        guard supportedSchemes.contains(scheme.lowercased()) else {
            throw StreamPushValidationError.invalidURL("Unsupported URL scheme: \(scheme)")
        }
        
        guard let host = urlComponents.host, !host.isEmpty else {
            throw StreamPushValidationError.invalidURL("URL must contain a valid host")
        }
        
        // HTTP/HTTPS URLs should have a path for streaming endpoints
        if ["http", "https"].contains(scheme.lowercased()) {
            let path = urlComponents.path
            guard !path.isEmpty && path != "/" else {
                throw StreamPushValidationError.invalidURL("HTTP/HTTPS URLs must contain a valid path")
            }
        }
    }
    
    /// 验证背景颜色
    private static func validateBackgroundColor(_ color: String) throws {
        let hexPattern = "^#[0-9A-Fa-f]{6}$"
        let regex = try NSRegularExpression(pattern: hexPattern)
        let range = NSRange(location: 0, length: color.count)
        
        guard regex.firstMatch(in: color, options: [], range: range) != nil else {
            throw StreamPushValidationError.invalidLayoutConfiguration("Invalid background color format: \(color)")
        }
    }
}

/// 推流视频配置
/// 需求: 7.1 - 支持设置分辨率、码率、帧率
public struct StreamVideoConfig: Codable, Sendable {
    /// 视频宽度
    public let width: Int
    
    /// 视频高度
    public let height: Int
    
    /// 视频比特率 (kbps)
    public let bitrate: Int
    
    /// 视频帧率 (fps)
    public let frameRate: Int
    
    /// 视频编码格式
    public let codec: StreamVideoCodec
    
    public init(
        width: Int = 640,
        height: Int = 480,
        bitrate: Int = 1000,
        frameRate: Int = 15,
        codec: StreamVideoCodec = .h264
    ) {
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.codec = codec
    }
    
    /// 验证视频配置
    public func validate() throws {
        // 验证分辨率 (需求 7.1)
        guard width >= 16 && width <= 1920 && height >= 16 && height <= 1080 else {
            throw StreamPushValidationError.invalidResolution(width: width, height: height)
        }
        
        // 验证比特率
        guard bitrate >= 1 && bitrate <= 10000 else {
            throw StreamPushValidationError.invalidBitrate(bitrate)
        }
        
        // 验证帧率
        guard frameRate >= 1 && frameRate <= 60 else {
            throw StreamPushValidationError.invalidFrameRate(frameRate)
        }
    }
}

/// 推流视频编码格式
public enum StreamVideoCodec: String, CaseIterable, Codable, Sendable {
    /// H.264编码
    case h264 = "h264"
    /// H.265编码
    case h265 = "h265"
    /// VP8编码
    case vp8 = "vp8"
    /// VP9编码
    case vp9 = "vp9"
    
    /// 获取编码格式的中文显示名称
    public var displayName: String {
        switch self {
        case .h264:
            return "H.264"
        case .h265:
            return "H.265"
        case .vp8:
            return "VP8"
        case .vp9:
            return "VP9"
        }
    }
}

/// 推流布局配置
/// 需求: 7.2 - 支持自定义布局和多用户画面组合
public struct StreamLayout: Codable, Sendable {
    /// 布局类型
    public let type: StreamLayoutType
    
    /// 画布宽度
    public let canvasWidth: Int
    
    /// 画布高度
    public let canvasHeight: Int
    
    /// 用户区域配置
    public let userRegions: [StreamUserRegion]
    
    /// 背景图片URL（可选）
    public let backgroundImageUrl: String?
    
    public init(
        type: StreamLayoutType = .floating,
        canvasWidth: Int = 640,
        canvasHeight: Int = 480,
        userRegions: [StreamUserRegion] = [],
        backgroundImageUrl: String? = nil
    ) {
        self.type = type
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.userRegions = userRegions
        self.backgroundImageUrl = backgroundImageUrl
    }
    
    // MARK: - Validation Methods (需求 7.5)
    
    /// 验证布局配置
    public func validate() throws {
        try Self.validateCanvasSize(width: canvasWidth, height: canvasHeight)
        try Self.validateUserRegions(userRegions, canvasWidth: canvasWidth, canvasHeight: canvasHeight, layoutType: type)
    }
    
    /// 验证画布尺寸
    private static func validateCanvasSize(width: Int, height: Int) throws {
        guard width >= 16 && width <= 1920 && height >= 16 && height <= 1080 else {
            throw StreamPushValidationError.invalidResolution(width: width, height: height)
        }
    }
    
    /// 验证用户区域配置
    private static func validateUserRegions(_ regions: [StreamUserRegion], canvasWidth: Int, canvasHeight: Int, layoutType: StreamLayoutType) throws {
        // 自定义布局必须有用户区域
        if layoutType == .custom && regions.isEmpty {
            throw StreamPushValidationError.emptyUserRegions
        }
        
        // 检查重复用户ID
        let userIds = regions.map { $0.userId }
        let uniqueUserIds = Set(userIds)
        if userIds.count != uniqueUserIds.count {
            let duplicates = userIds.filter { userId in
                userIds.filter { $0 == userId }.count > 1
            }
            throw StreamPushValidationError.duplicateUserRegions(Array(Set(duplicates)))
        }
        
        // 验证每个用户区域
        for region in regions {
            try region.validate(canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        }
    }
}

/// 推流布局类型
public enum StreamLayoutType: String, CaseIterable, Codable, Sendable {
    /// 浮动布局
    case floating = "floating"
    /// 最佳适配布局
    case bestFit = "best_fit"
    /// 垂直布局
    case vertical = "vertical"
    /// 自定义布局
    case custom = "custom"
    
    /// 获取布局类型的中文显示名称
    public var displayName: String {
        switch self {
        case .floating:
            return "浮动布局"
        case .bestFit:
            return "最佳适配"
        case .vertical:
            return "垂直布局"
        case .custom:
            return "自定义布局"
        }
    }
}

/// 推流用户区域配置
public struct StreamUserRegion: Codable, Sendable {
    /// 用户ID
    public let userId: String
    
    /// X坐标
    public let x: Int
    
    /// Y坐标
    public let y: Int
    
    /// 宽度
    public let width: Int
    
    /// 高度
    public let height: Int
    
    /// 透明度（0.0-1.0）
    public let alpha: Double
    
    /// 渲染模式
    public let renderMode: StreamRenderMode
    
    public init(
        userId: String,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        alpha: Double = 1.0,
        renderMode: StreamRenderMode = .fit
    ) {
        self.userId = userId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.alpha = alpha
        self.renderMode = renderMode
    }
    
    /// 验证用户区域配置
    public func validate(canvasWidth: Int, canvasHeight: Int) throws {
        // 验证用户ID
        guard !userId.isEmpty else {
            throw StreamPushValidationError.invalidUserRegion(userId: userId, reason: "User ID cannot be empty")
        }
        
        // 验证尺寸
        guard width > 0 && height > 0 else {
            throw StreamPushValidationError.invalidUserRegion(userId: userId, reason: "Width and height must be positive")
        }
        
        // 验证透明度
        guard alpha >= 0.0 && alpha <= 1.0 else {
            throw StreamPushValidationError.invalidUserRegion(userId: userId, reason: "Alpha must be between 0.0 and 1.0")
        }
        
        // 验证区域是否在画布范围内
        guard x >= 0 && y >= 0 && x + width <= canvasWidth && y + height <= canvasHeight else {
            throw StreamPushValidationError.regionOutOfBounds(userId: userId)
        }
    }
}

/// 推流渲染模式
public enum StreamRenderMode: String, CaseIterable, Codable, Sendable {
    /// 适配模式
    case fit = "fit"
    /// 填充模式
    case fill = "fill"
    /// 裁剪模式
    case crop = "crop"
    
    /// 获取渲染模式的中文显示名称
    public var displayName: String {
        switch self {
        case .fit:
            return "适配"
        case .fill:
            return "填充"
        case .crop:
            return "裁剪"
        }
    }
}

/// 推流音频配置
public struct StreamAudioConfig: Codable, Sendable {
    /// 音频采样率
    public let sampleRate: Int
    
    /// 音频比特率 (kbps)
    public let bitrate: Int
    
    /// 音频声道数
    public let channels: Int
    
    /// 音频编码格式
    public let codec: StreamAudioCodec
    
    public init(
        sampleRate: Int = 48000,
        bitrate: Int = 128,
        channels: Int = 2,
        codec: StreamAudioCodec = .aac
    ) {
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        self.channels = channels
        self.codec = codec
    }
    
    /// 验证音频配置
    public func validate() throws {
        // 验证采样率
        let supportedSampleRates = [8000, 16000, 22050, 44100, 48000]
        guard supportedSampleRates.contains(sampleRate) else {
            throw StreamPushValidationError.invalidAudioConfiguration("Unsupported sample rate: \(sampleRate)")
        }
        
        // 验证比特率
        guard bitrate >= 32 && bitrate <= 320 else {
            throw StreamPushValidationError.invalidAudioConfiguration("Audio bitrate must be between 32 and 320 kbps")
        }
        
        // 验证声道数
        guard channels >= 1 && channels <= 2 else {
            throw StreamPushValidationError.invalidAudioConfiguration("Audio channels must be 1 (mono) or 2 (stereo)")
        }
    }
}

/// 推流音频编码格式
public enum StreamAudioCodec: String, CaseIterable, Codable, Sendable {
    /// AAC编码
    case aac = "aac"
    /// MP3编码
    case mp3 = "mp3"
    /// Opus编码
    case opus = "opus"
    
    /// 获取编码格式的中文显示名称
    public var displayName: String {
        switch self {
        case .aac:
            return "AAC"
        case .mp3:
            return "MP3"
        case .opus:
            return "Opus"
        }
    }
}

/// 推流质量
public enum StreamQuality: String, CaseIterable, Codable, Sendable {
    /// 低质量
    case low = "low"
    /// 标准质量
    case standard = "standard"
    /// 高质量
    case high = "high"
    /// 超高质量
    case ultra = "ultra"
    
    /// 获取质量的中文显示名称
    public var displayName: String {
        switch self {
        case .low:
            return "低质量"
        case .standard:
            return "标准质量"
        case .high:
            return "高质量"
        case .ultra:
            return "超高质量"
        }
    }
}

/// 推流水印配置
public struct StreamWatermark: Codable, Sendable {
    /// 水印图片URL
    public let imageUrl: String
    
    /// X坐标
    public let x: Int
    
    /// Y坐标
    public let y: Int
    
    /// 宽度
    public let width: Int
    
    /// 高度
    public let height: Int
    
    /// 透明度（0.0-1.0）
    public let alpha: Double
    
    public init(
        imageUrl: String,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        alpha: Double = 1.0
    ) {
        self.imageUrl = imageUrl
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.alpha = alpha
    }
    
    /// 验证水印配置
    public func validate() throws {
        try Self.validateImageUrl(imageUrl)
        try Self.validateDimensions(width: width, height: height)
        try Self.validateAlpha(alpha)
    }
    
    /// 验证图片URL
    private static func validateImageUrl(_ url: String) throws {
        guard !url.isEmpty else {
            throw StreamPushValidationError.invalidWatermarkConfiguration("Image URL cannot be empty")
        }
        
        guard let urlComponents = URLComponents(string: url),
              let scheme = urlComponents.scheme else {
            throw StreamPushValidationError.invalidWatermarkConfiguration("Invalid image URL format")
        }
        
        let supportedSchemes = ["http", "https", "file"]
        guard supportedSchemes.contains(scheme.lowercased()) else {
            throw StreamPushValidationError.invalidWatermarkConfiguration("Unsupported URL scheme: \(scheme)")
        }
    }
    
    /// 验证尺寸
    private static func validateDimensions(width: Int, height: Int) throws {
        guard width > 0 && height > 0 else {
            throw StreamPushValidationError.invalidWatermarkConfiguration("Width and height must be positive")
        }
        
        guard width <= 1920 && height <= 1080 else {
            throw StreamPushValidationError.invalidWatermarkConfiguration("Watermark size too large")
        }
    }
    
    /// 验证透明度
    private static func validateAlpha(_ alpha: Double) throws {
        guard alpha >= 0.0 && alpha <= 1.0 else {
            throw StreamPushValidationError.invalidWatermarkConfiguration("Alpha must be between 0.0 and 1.0")
        }
    }
}

// MARK: - Media Relay Models

/// 媒体中继配置验证错误
public enum MediaRelayValidationError: LocalizedError {
    case invalidChannelName(String)
    case invalidUserId(String)
    case invalidToken(String)
    case emptyDestinationChannels
    case tooManyDestinationChannels(Int, max: Int)
    case duplicateDestinationChannels([String])
    case sourceChannelInDestinations(String)
    case invalidRelayMode(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidChannelName(let name):
            return "Invalid channel name: \(name)"
        case .invalidUserId(let userId):
            return "Invalid user ID: \(userId)"
        case .invalidToken(let token):
            return "Invalid token: \(token)"
        case .emptyDestinationChannels:
            return "Destination channels cannot be empty"
        case .tooManyDestinationChannels(let count, let max):
            return "Too many destination channels: \(count), maximum allowed: \(max)"
        case .duplicateDestinationChannels(let channels):
            return "Duplicate destination channels: \(channels.joined(separator: ", "))"
        case .sourceChannelInDestinations(let channel):
            return "Source channel cannot be in destination channels: \(channel)"
        case .invalidRelayMode(let mode):
            return "Invalid relay mode: \(mode)"
        }
    }
}

/// 媒体中继配置
/// 需求: 8.1 - 支持一对一、一对多、多对多等中继模式
public struct MediaRelayConfig: Codable, Sendable {
    /// 源频道信息
    public let sourceChannel: MediaRelayChannelInfo
    
    /// 目标频道信息列表
    public let destinationChannels: [MediaRelayChannelInfo]
    
    /// 中继模式
    public let relayMode: MediaRelayMode
    
    /// 最大目标频道数量限制
    public static let maxDestinationChannels = 4
    
    public init(
        sourceChannel: MediaRelayChannelInfo,
        destinationChannels: [MediaRelayChannelInfo],
        relayMode: MediaRelayMode? = nil
    ) throws {
        // 验证配置 (需求 8.1, 8.4)
        try Self.validateConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels
        )
        
        self.sourceChannel = sourceChannel
        self.destinationChannels = destinationChannels
        
        // 自动推断中继模式
        if let mode = relayMode {
            self.relayMode = mode
        } else {
            self.relayMode = Self.inferRelayMode(destinationCount: destinationChannels.count)
        }
    }
    
    // MARK: - Validation Methods (需求 8.4)
    
    /// 验证媒体中继配置
    public func validate() throws {
        try Self.validateConfig(
            sourceChannel: sourceChannel,
            destinationChannels: destinationChannels
        )
    }
    
    /// 验证配置参数
    private static func validateConfig(
        sourceChannel: MediaRelayChannelInfo,
        destinationChannels: [MediaRelayChannelInfo]
    ) throws {
        // 验证源频道
        try sourceChannel.validate()
        
        // 验证目标频道不能为空
        guard !destinationChannels.isEmpty else {
            throw MediaRelayValidationError.emptyDestinationChannels
        }
        
        // 验证目标频道数量限制
        guard destinationChannels.count <= maxDestinationChannels else {
            throw MediaRelayValidationError.tooManyDestinationChannels(
                destinationChannels.count,
                max: maxDestinationChannels
            )
        }
        
        // 验证每个目标频道
        for channel in destinationChannels {
            try channel.validate()
        }
        
        // 检查重复的目标频道
        let channelNames = destinationChannels.map { $0.channelName }
        let uniqueChannelNames = Set(channelNames)
        if channelNames.count != uniqueChannelNames.count {
            let duplicates = channelNames.filter { name in
                channelNames.filter { $0 == name }.count > 1
            }
            throw MediaRelayValidationError.duplicateDestinationChannels(Array(Set(duplicates)))
        }
        
        // 验证源频道不在目标频道中
        if channelNames.contains(sourceChannel.channelName) {
            throw MediaRelayValidationError.sourceChannelInDestinations(sourceChannel.channelName)
        }
    }
    
    /// 自动推断中继模式
    private static func inferRelayMode(destinationCount: Int) -> MediaRelayMode {
        switch destinationCount {
        case 1:
            return .oneToOne
        case 2...maxDestinationChannels:
            return .oneToMany
        default:
            return .oneToMany
        }
    }
    
    /// 添加目标频道
    public func addingDestinationChannel(_ channel: MediaRelayChannelInfo) throws -> MediaRelayConfig {
        var newDestinations = destinationChannels
        
        // 检查是否已存在
        guard !newDestinations.contains(where: { $0.channelName == channel.channelName }) else {
            throw MediaRelayValidationError.duplicateDestinationChannels([channel.channelName])
        }
        
        // 检查数量限制
        guard newDestinations.count < Self.maxDestinationChannels else {
            throw MediaRelayValidationError.tooManyDestinationChannels(
                newDestinations.count + 1,
                max: Self.maxDestinationChannels
            )
        }
        
        newDestinations.append(channel)
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: newDestinations,
            relayMode: Self.inferRelayMode(destinationCount: newDestinations.count)
        )
    }
    
    /// 移除目标频道
    public func removingDestinationChannel(_ channelName: String) throws -> MediaRelayConfig {
        let newDestinations = destinationChannels.filter { $0.channelName != channelName }
        
        guard !newDestinations.isEmpty else {
            throw MediaRelayValidationError.emptyDestinationChannels
        }
        
        return try MediaRelayConfig(
            sourceChannel: sourceChannel,
            destinationChannels: newDestinations,
            relayMode: Self.inferRelayMode(destinationCount: newDestinations.count)
        )
    }
}

/// 媒体中继模式
/// 需求: 8.1 - 支持一对一、一对多、多对多等中继模式
public enum MediaRelayMode: String, CaseIterable, Codable, Sendable {
    /// 一对一中继
    case oneToOne = "one_to_one"
    /// 一对多中继
    case oneToMany = "one_to_many"
    /// 多对多中继（预留，当前版本不支持）
    case manyToMany = "many_to_many"
    
    /// 获取中继模式的中文显示名称
    public var displayName: String {
        switch self {
        case .oneToOne:
            return "一对一中继"
        case .oneToMany:
            return "一对多中继"
        case .manyToMany:
            return "多对多中继"
        }
    }
    
    /// 获取中继模式的描述
    public var description: String {
        switch self {
        case .oneToOne:
            return "将音视频流从源频道转发到一个目标频道"
        case .oneToMany:
            return "将音视频流从源频道转发到多个目标频道"
        case .manyToMany:
            return "支持多个源频道到多个目标频道的复杂中继"
        }
    }
    
    /// 获取支持的最大目标频道数
    public var maxDestinationChannels: Int {
        switch self {
        case .oneToOne:
            return 1
        case .oneToMany:
            return 4
        case .manyToMany:
            return 8 // 预留
        }
    }
}

/// 媒体中继频道信息
public struct MediaRelayChannelInfo: Codable, Sendable {
    /// 频道名称
    public let channelName: String
    
    /// 用户ID
    public let userId: String
    
    /// 认证令牌
    public let token: String
    
    /// 频道描述（可选）
    public let description: String?
    
    /// 创建时间
    public let createdAt: Date
    
    public init(
        channelName: String,
        userId: String,
        token: String,
        description: String? = nil
    ) {
        self.channelName = channelName
        self.userId = userId
        self.token = token
        self.description = description
        self.createdAt = Date()
    }
    
    /// 验证频道信息
    public func validate() throws {
        // 验证频道名称
        guard !channelName.isEmpty else {
            throw MediaRelayValidationError.invalidChannelName("Channel name cannot be empty")
        }
        
        guard channelName.count <= 64 else {
            throw MediaRelayValidationError.invalidChannelName("Channel name too long (max 64 characters)")
        }
        
        // 验证频道名称格式（只允许字母、数字、下划线、连字符）
        let channelNamePattern = "^[a-zA-Z0-9_-]+$"
        let regex = try NSRegularExpression(pattern: channelNamePattern)
        let range = NSRange(location: 0, length: channelName.count)
        
        guard regex.firstMatch(in: channelName, options: [], range: range) != nil else {
            throw MediaRelayValidationError.invalidChannelName("Channel name contains invalid characters")
        }
        
        // 验证用户ID
        guard !userId.isEmpty else {
            throw MediaRelayValidationError.invalidUserId("User ID cannot be empty")
        }
        
        guard userId.count <= 255 else {
            throw MediaRelayValidationError.invalidUserId("User ID too long (max 255 characters)")
        }
        
        // 验证Token
        guard !token.isEmpty else {
            throw MediaRelayValidationError.invalidToken("Token cannot be empty")
        }
        
        guard token.count <= 2048 else {
            throw MediaRelayValidationError.invalidToken("Token too long (max 2048 characters)")
        }
    }
}

/// 媒体中继详细状态
/// 需求: 8.3 - 提供每个目标频道的连接状态监控
public struct MediaRelayDetailedState: Codable, Sendable {
    /// 整体中继状态
    public let overallState: MediaRelayOverallState
    
    /// 源频道状态
    public let sourceChannelState: MediaRelayChannelState
    
    /// 目标频道状态列表
    public let destinationChannelStates: [MediaRelayChannelState]
    
    /// 中继开始时间
    public let startTime: Date?
    
    /// 最后更新时间
    public let lastUpdated: Date
    
    /// 中继统计信息
    public let statistics: MediaRelayStatistics?
    
    public init(
        overallState: MediaRelayOverallState,
        sourceChannelState: MediaRelayChannelState,
        destinationChannelStates: [MediaRelayChannelState],
        startTime: Date? = nil,
        statistics: MediaRelayStatistics? = nil
    ) {
        self.overallState = overallState
        self.sourceChannelState = sourceChannelState
        self.destinationChannelStates = destinationChannelStates
        self.startTime = startTime
        self.lastUpdated = Date()
        self.statistics = statistics
    }
    
    /// 获取特定频道的状态
    public func getChannelState(for channelName: String) -> MediaRelayChannelState? {
        if sourceChannelState.channelName == channelName {
            return sourceChannelState
        }
        return destinationChannelStates.first { $0.channelName == channelName }
    }
    
    /// 检查是否所有目标频道都已连接
    public var allDestinationsConnected: Bool {
        return destinationChannelStates.allSatisfy { $0.connectionState == .connected }
    }
    
    /// 获取连接的目标频道数量
    public var connectedDestinationCount: Int {
        return destinationChannelStates.filter { $0.connectionState == .connected }.count
    }
    
    /// 获取失败的目标频道数量
    public var failedDestinationCount: Int {
        return destinationChannelStates.filter { 
            if case .failure = $0.connectionState { return true }
            return false
        }.count
    }
}

/// 媒体中继整体状态
public enum MediaRelayOverallState: String, CaseIterable, Codable, Sendable {
    /// 空闲状态
    case idle = "idle"
    /// 连接中
    case connecting = "connecting"
    /// 运行中
    case running = "running"
    /// 暂停中
    case paused = "paused"
    /// 停止中
    case stopping = "stopping"
    /// 失败
    case failure = "failure"
    
    /// 获取状态的中文显示名称
    public var displayName: String {
        switch self {
        case .idle:
            return "空闲"
        case .connecting:
            return "连接中"
        case .running:
            return "运行中"
        case .paused:
            return "暂停中"
        case .stopping:
            return "停止中"
        case .failure:
            return "失败"
        }
    }
    
    /// 检查是否为活跃状态
    public var isActive: Bool {
        switch self {
        case .connecting, .running, .paused:
            return true
        case .idle, .stopping, .failure:
            return false
        }
    }
}

/// 媒体中继频道状态
public struct MediaRelayChannelState: Codable, Sendable {
    /// 频道名称
    public let channelName: String
    
    /// 连接状态
    public let connectionState: MediaRelayConnectionState
    
    /// 是否暂停
    public let isPaused: Bool
    
    /// 最后更新时间
    public let lastUpdated: Date
    
    /// 错误信息（如果有）
    public let error: String?
    
    /// 连接时间
    public let connectedAt: Date?
    
    /// 断开时间
    public let disconnectedAt: Date?
    
    public init(
        channelName: String,
        connectionState: MediaRelayConnectionState,
        isPaused: Bool = false,
        error: String? = nil,
        connectedAt: Date? = nil,
        disconnectedAt: Date? = nil
    ) {
        self.channelName = channelName
        self.connectionState = connectionState
        self.isPaused = isPaused
        self.error = error
        self.connectedAt = connectedAt
        self.disconnectedAt = disconnectedAt
        self.lastUpdated = Date()
    }
    
    /// 检查频道是否可用
    public var isAvailable: Bool {
        return connectionState == .connected && !isPaused
    }
}

/// 媒体中继连接状态
public enum MediaRelayConnectionState: String, CaseIterable, Codable, Sendable {
    /// 空闲
    case idle = "idle"
    /// 连接中
    case connecting = "connecting"
    /// 已连接
    case connected = "connected"
    /// 重连中
    case reconnecting = "reconnecting"
    /// 已断开
    case disconnected = "disconnected"
    /// 连接失败
    case failure = "failure"
    
    /// 获取连接状态的中文显示名称
    public var displayName: String {
        switch self {
        case .idle:
            return "空闲"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .reconnecting:
            return "重连中"
        case .disconnected:
            return "已断开"
        case .failure:
            return "连接失败"
        }
    }
    
    /// 检查是否为连接状态
    public var isConnected: Bool {
        return self == .connected
    }
    
    /// 检查是否为失败状态
    public var isFailure: Bool {
        return self == .failure
    }
}

/// 媒体中继统计信息
/// 需求: 8.6 - 提供详细的统计信息
public struct MediaRelayStatistics: Codable, Sendable {
    /// 总中继时长（秒）
    public let totalRelayDuration: TimeInterval
    
    /// 发送的总字节数
    public let totalBytesSent: UInt64
    
    /// 接收的总字节数
    public let totalBytesReceived: UInt64
    
    /// 发送的音频包数量
    public let audioPacketsSent: UInt64
    
    /// 发送的视频包数量
    public let videoPacketsSent: UInt64
    
    /// 丢包数量
    public let packetsLost: UInt64
    
    /// 平均延迟（毫秒）
    public let averageLatency: Double
    
    /// 每个目标频道的统计信息
    public let channelStatistics: [String: MediaRelayChannelStatistics]
    
    /// 统计开始时间
    public let startTime: Date
    
    /// 最后更新时间
    public let lastUpdated: Date
    
    public init(
        totalRelayDuration: TimeInterval = 0,
        totalBytesSent: UInt64 = 0,
        totalBytesReceived: UInt64 = 0,
        audioPacketsSent: UInt64 = 0,
        videoPacketsSent: UInt64 = 0,
        packetsLost: UInt64 = 0,
        averageLatency: Double = 0,
        channelStatistics: [String: MediaRelayChannelStatistics] = [:],
        startTime: Date? = nil
    ) {
        self.totalRelayDuration = totalRelayDuration
        self.totalBytesSent = totalBytesSent
        self.totalBytesReceived = totalBytesReceived
        self.audioPacketsSent = audioPacketsSent
        self.videoPacketsSent = videoPacketsSent
        self.packetsLost = packetsLost
        self.averageLatency = averageLatency
        self.channelStatistics = channelStatistics
        self.startTime = startTime ?? Date()
        self.lastUpdated = Date()
    }
    
    /// 计算丢包率
    public var packetLossRate: Double {
        let totalPackets = audioPacketsSent + videoPacketsSent
        guard totalPackets > 0 else { return 0.0 }
        return Double(packetsLost) / Double(totalPackets) * 100.0
    }
    
    /// 计算平均传输速率（字节/秒）
    public var averageTransferRate: Double {
        guard totalRelayDuration > 0 else { return 0.0 }
        return Double(totalBytesSent) / totalRelayDuration
    }
    
    /// 获取特定频道的统计信息
    public func getChannelStatistics(for channelName: String) -> MediaRelayChannelStatistics? {
        return channelStatistics[channelName]
    }
}

/// 媒体中继频道统计信息
public struct MediaRelayChannelStatistics: Codable, Sendable {
    /// 频道名称
    public let channelName: String
    
    /// 发送字节数
    public let bytesSent: UInt64
    
    /// 接收字节数
    public let bytesReceived: UInt64
    
    /// 发送的音频包数量
    public let audioPacketsSent: UInt64
    
    /// 发送的视频包数量
    public let videoPacketsSent: UInt64
    
    /// 丢包数量
    public let packetsLost: UInt64
    
    /// 延迟（毫秒）
    public let latency: Double
    
    /// 连接时长（秒）
    public let connectionDuration: TimeInterval
    
    /// 最后更新时间
    public let lastUpdated: Date
    
    public init(
        channelName: String,
        bytesSent: UInt64 = 0,
        bytesReceived: UInt64 = 0,
        audioPacketsSent: UInt64 = 0,
        videoPacketsSent: UInt64 = 0,
        packetsLost: UInt64 = 0,
        latency: Double = 0,
        connectionDuration: TimeInterval = 0
    ) {
        self.channelName = channelName
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.audioPacketsSent = audioPacketsSent
        self.videoPacketsSent = videoPacketsSent
        self.packetsLost = packetsLost
        self.latency = latency
        self.connectionDuration = connectionDuration
        self.lastUpdated = Date()
    }
    
    /// 计算丢包率
    public var packetLossRate: Double {
        let totalPackets = audioPacketsSent + videoPacketsSent
        guard totalPackets > 0 else { return 0.0 }
        return Double(packetsLost) / Double(totalPackets) * 100.0
    }
    
    /// 计算传输速率（字节/秒）
    public var transferRate: Double {
        guard connectionDuration > 0 else { return 0.0 }
        return Double(bytesSent) / connectionDuration
    }
}