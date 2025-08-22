import Foundation

/// 推流配置
/// 需求: 1.2, 1.3
public struct StreamPushConfig: Codable {
    /// 推流URL
    public let url: String
    
    /// 推流布局配置
    public let layout: StreamLayout
    
    /// 音频配置
    public let audioConfig: StreamAudioConfig
    
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
        layout: StreamLayout = StreamLayout(),
        audioConfig: StreamAudioConfig = StreamAudioConfig(),
        enableTranscoding: Bool = true,
        backgroundColor: String = "#000000",
        quality: StreamQuality = .standard,
        watermark: StreamWatermark? = nil
    ) {
        self.url = url
        self.layout = layout
        self.audioConfig = audioConfig
        self.enableTranscoding = enableTranscoding
        self.backgroundColor = backgroundColor
        self.quality = quality
        self.watermark = watermark
    }
}

/// 推流布局配置
public struct StreamLayout: Codable {
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
}

/// 推流布局类型
public enum StreamLayoutType: String, CaseIterable, Codable {
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
public struct StreamUserRegion: Codable {
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
        self.alpha = max(0.0, min(1.0, alpha))
        self.renderMode = renderMode
    }
}

/// 推流渲染模式
public enum StreamRenderMode: String, CaseIterable, Codable {
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
public struct StreamAudioConfig: Codable {
    /// 音频采样率
    public let sampleRate: Int
    
    /// 音频比特率
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
}

/// 推流音频编码格式
public enum StreamAudioCodec: String, CaseIterable, Codable {
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
public enum StreamQuality: String, CaseIterable, Codable {
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
public struct StreamWatermark: Codable {
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
        self.alpha = max(0.0, min(1.0, alpha))
    }
}

/// 媒体中继配置
public struct MediaRelayConfig: Codable {
    /// 源频道信息
    public let sourceChannel: MediaRelayChannelInfo
    
    /// 目标频道信息列表
    public let destinationChannels: [MediaRelayChannelInfo]
    
    public init(
        sourceChannel: MediaRelayChannelInfo,
        destinationChannels: [MediaRelayChannelInfo]
    ) {
        self.sourceChannel = sourceChannel
        self.destinationChannels = destinationChannels
    }
}

/// 媒体中继频道信息
public struct MediaRelayChannelInfo: Codable {
    /// 频道名称
    public let channelName: String
    
    /// 用户ID
    public let userId: String
    
    /// 认证令牌
    public let token: String
    
    public init(
        channelName: String,
        userId: String,
        token: String
    ) {
        self.channelName = channelName
        self.userId = userId
        self.token = token
    }
}