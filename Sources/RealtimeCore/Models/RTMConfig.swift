import Foundation

/// RTM服务配置
/// 需求: 1.1, 1.2
public struct RTMConfig: Codable, Sendable {
    /// 应用ID
    public let appId: String
    
    /// 服务器区域设置
    public let region: RTMRegion
    
    /// 日志配置
    public let logConfig: RTMLogConfig
    
    /// 是否启用云代理
    public let enableCloudProxy: Bool
    
    /// 连接超时时间（秒）
    public let connectionTimeout: TimeInterval
    
    /// 消息重试次数
    public let messageRetryCount: Int
    
    /// 是否启用加密
    public let enableEncryption: Bool
    
    /// 加密密钥（启用加密时必需）
    public let encryptionKey: String?
    
    /// 自定义服务器配置（可选）
    public let customServerConfig: RTMCustomServerConfig?
    
    public init(
        appId: String,
        region: RTMRegion = .global,
        logConfig: RTMLogConfig = RTMLogConfig(),
        enableCloudProxy: Bool = false,
        connectionTimeout: TimeInterval = 30.0,
        messageRetryCount: Int = 3,
        enableEncryption: Bool = false,
        encryptionKey: String? = nil,
        customServerConfig: RTMCustomServerConfig? = nil
    ) {
        self.appId = appId
        self.region = region
        self.logConfig = logConfig
        self.enableCloudProxy = enableCloudProxy
        self.connectionTimeout = connectionTimeout
        self.messageRetryCount = messageRetryCount
        self.enableEncryption = enableEncryption
        self.encryptionKey = encryptionKey
        self.customServerConfig = customServerConfig
    }
}

/// RTM服务器区域
public enum RTMRegion: String, CaseIterable, Codable, Sendable {
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

/// RTM日志配置
public struct RTMLogConfig: Codable, Sendable {
    /// 日志级别
    public let logLevel: RTMLogLevel
    
    /// 日志文件路径（可选）
    public let logFilePath: String?
    
    /// 日志文件大小限制（字节）
    public let logFileSize: Int
    
    /// 是否启用控制台日志
    public let enableConsoleLog: Bool
    
    public init(
        logLevel: RTMLogLevel = .info,
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

/// RTM日志级别
public enum RTMLogLevel: String, CaseIterable, Codable, Sendable {
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

/// RTM自定义服务器配置
public struct RTMCustomServerConfig: Codable, Sendable {
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

/// RTM连接状态
public enum RTMConnectionState: String, CaseIterable, Codable, Sendable {
    /// 断开连接
    case disconnected = "disconnected"
    /// 连接中
    case connecting = "connecting"
    /// 已连接
    case connected = "connected"
    /// 重连中
    case reconnecting = "reconnecting"
    /// 连接失败
    case failed = "failed"
    
    /// 获取状态的中文显示名称
    public var displayName: String {
        switch self {
        case .disconnected:
            return "断开连接"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .reconnecting:
            return "重连中"
        case .failed:
            return "连接失败"
        }
    }
}

/// RTM连接状态变化原因
public enum RTMConnectionChangeReason: String, CaseIterable, Codable, Sendable {
    /// 用户主动登录
    case login = "login"
    /// 登录成功
    case loginSuccess = "login_success"
    /// 登录失败
    case loginFailure = "login_failure"
    /// 登录超时
    case loginTimeout = "login_timeout"
    /// 网络中断
    case interrupted = "interrupted"
    /// 用户主动登出
    case logout = "logout"
    /// 被服务器踢出
    case bannedByServer = "banned_by_server"
    /// 远程登录
    case remoteLogin = "remote_login"
    /// Token过期
    case tokenExpired = "token_expired"
    
    /// 获取原因的中文显示名称
    public var displayName: String {
        switch self {
        case .login:
            return "用户登录"
        case .loginSuccess:
            return "登录成功"
        case .loginFailure:
            return "登录失败"
        case .loginTimeout:
            return "登录超时"
        case .interrupted:
            return "网络中断"
        case .logout:
            return "用户登出"
        case .bannedByServer:
            return "被服务器踢出"
        case .remoteLogin:
            return "远程登录"
        case .tokenExpired:
            return "Token过期"
        }
    }
}
