import Foundation

/// RTC服务配置
/// 需求: 1.1, 1.2
public struct RTCConfig: Codable {
    /// 应用ID
    public let appId: String
    
    /// 应用证书（可选）
    public let appCertificate: String?
    
    /// 服务器区域设置
    public let region: RTCRegion
    
    /// 音频配置
    public let audioConfig: RTCAudioConfig
    
    /// 日志配置
    public let logConfig: RTCLogConfig
    
    /// 是否启用云代理
    public let enableCloudProxy: Bool
    
    /// 自定义服务器配置（可选）
    public let customServerConfig: RTCCustomServerConfig?
    
    public init(
        appId: String,
        appCertificate: String? = nil,
        region: RTCRegion = .global,
        audioConfig: RTCAudioConfig = RTCAudioConfig(),
        logConfig: RTCLogConfig = RTCLogConfig(),
        enableCloudProxy: Bool = false,
        customServerConfig: RTCCustomServerConfig? = nil
    ) {
        self.appId = appId
        self.appCertificate = appCertificate
        self.region = region
        self.audioConfig = audioConfig
        self.logConfig = logConfig
        self.enableCloudProxy = enableCloudProxy
        self.customServerConfig = customServerConfig
    }
}

/// RTC服务器区域
public enum RTCRegion: String, CaseIterable, Codable, Sendable {
    /// 全球
    case global = "global"
    /// 中国大陆
    case china = "china"
    /// 北美
    case northAmerica = "north_america"
    /// 欧洲
    case europe = "europe"
    /// 亚太
    case asiaPacific = "asia_pacific"
    
    /// 获取区域的中文显示名称
    public var displayName: String {
        switch self {
        case .global:
            return "全球"
        case .china:
            return "中国大陆"
        case .northAmerica:
            return "北美"
        case .europe:
            return "欧洲"
        case .asiaPacific:
            return "亚太"
        }
    }
}

/// RTC音频配置
public struct RTCAudioConfig: Codable {
    /// 音频场景
    public let audioScenario: RTCAudioScenario
    
    /// 音频质量
    public let audioProfile: RTCAudioProfile
    
    /// 是否启用音频处理
    public let enableAudioProcessing: Bool
    
    /// 是否启用回声消除
    public let enableEchoCancellation: Bool
    
    /// 是否启用噪声抑制
    public let enableNoiseSuppression: Bool
    
    /// 是否启用自动增益控制
    public let enableAutoGainControl: Bool
    
    public init(
        audioScenario: RTCAudioScenario = .default,
        audioProfile: RTCAudioProfile = .default,
        enableAudioProcessing: Bool = true,
        enableEchoCancellation: Bool = true,
        enableNoiseSuppression: Bool = true,
        enableAutoGainControl: Bool = true
    ) {
        self.audioScenario = audioScenario
        self.audioProfile = audioProfile
        self.enableAudioProcessing = enableAudioProcessing
        self.enableEchoCancellation = enableEchoCancellation
        self.enableNoiseSuppression = enableNoiseSuppression
        self.enableAutoGainControl = enableAutoGainControl
    }
}

/// RTC音频场景
public enum RTCAudioScenario: String, CaseIterable, Codable {
    /// 默认场景
    case `default` = "default"
    /// 聊天室场景
    case chatRoom = "chat_room"
    /// 教育场景
    case education = "education"
    /// 游戏语音场景
    case gameStreaming = "game_streaming"
    /// 展示场景
    case showRoom = "show_room"
    /// 会议场景
    case meeting = "meeting"
    
    /// 获取场景的中文显示名称
    public var displayName: String {
        switch self {
        case .default:
            return "默认"
        case .chatRoom:
            return "聊天室"
        case .education:
            return "教育"
        case .gameStreaming:
            return "游戏语音"
        case .showRoom:
            return "展示"
        case .meeting:
            return "会议"
        }
    }
}

/// RTC音频质量配置
public enum RTCAudioProfile: String, CaseIterable, Codable {
    /// 默认质量
    case `default` = "default"
    /// 语音标准质量
    case speechStandard = "speech_standard"
    /// 音乐标准质量
    case musicStandard = "music_standard"
    /// 音乐标准立体声质量
    case musicStandardStereo = "music_standard_stereo"
    /// 音乐高质量
    case musicHighQuality = "music_high_quality"
    /// 音乐高质量立体声
    case musicHighQualityStereo = "music_high_quality_stereo"
    
    /// 获取质量的中文显示名称
    public var displayName: String {
        switch self {
        case .default:
            return "默认"
        case .speechStandard:
            return "语音标准"
        case .musicStandard:
            return "音乐标准"
        case .musicStandardStereo:
            return "音乐标准立体声"
        case .musicHighQuality:
            return "音乐高质量"
        case .musicHighQualityStereo:
            return "音乐高质量立体声"
        }
    }
}

/// RTC日志配置
public struct RTCLogConfig: Codable {
    /// 日志级别
    public let logLevel: RTCLogLevel
    
    /// 日志文件路径（可选）
    public let logFilePath: String?
    
    /// 日志文件大小限制（字节）
    public let logFileSize: Int
    
    /// 是否启用控制台日志
    public let enableConsoleLog: Bool
    
    public init(
        logLevel: RTCLogLevel = .info,
        logFilePath: String? = nil,
        logFileSize: Int = 1024 * 1024, // 1MB
        enableConsoleLog: Bool = true
    ) {
        self.logLevel = logLevel
        self.logFilePath = logFilePath
        self.logFileSize = logFileSize
        self.enableConsoleLog = enableConsoleLog
    }
}

/// RTC日志级别
public enum RTCLogLevel: String, CaseIterable, Codable, Sendable {
    /// 无日志
    case none = "none"
    /// 错误
    case error = "error"
    /// 警告
    case warning = "warning"
    /// 信息
    case info = "info"
    /// 调试
    case debug = "debug"
    
    /// 获取级别的中文显示名称
    public var displayName: String {
        switch self {
        case .none:
            return "无"
        case .error:
            return "错误"
        case .warning:
            return "警告"
        case .info:
            return "信息"
        case .debug:
            return "调试"
        }
    }
}

/// RTC自定义服务器配置
public struct RTCCustomServerConfig: Codable {
    /// 自定义服务器地址
    public let serverAddress: String
    
    /// 自定义端口
    public let port: Int
    
    /// 是否使用HTTPS
    public let useHTTPS: Bool
    
    public init(
        serverAddress: String,
        port: Int = 443,
        useHTTPS: Bool = true
    ) {
        self.serverAddress = serverAddress
        self.port = port
        self.useHTTPS = useHTTPS
    }
}