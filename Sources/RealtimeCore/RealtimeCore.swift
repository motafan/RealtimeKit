import Foundation

/// RealtimeCore 模块的主要导出文件
/// 提供核心协议、数据模型和基础功能
/// 需求: 1.1, 1.2, 1.3, 12.1, 12.2

// MARK: - 错误类型
public enum RealtimeError: Error, LocalizedError, Sendable {
    case configurationError(String)
    case connectionError(String)
    case authenticationError(String)
    case providerNotAvailable(ProviderType)
    case insufficientPermissions(UserRole)
    case noActiveSession
    case invalidRoleTransition(from: UserRole, to: UserRole)
    case processorAlreadyRegistered(String)
    case tokenExpired
    case networkError(String)
    case invalidParameter(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationError(let message):
            return "配置错误: \(message)"
        case .connectionError(let message):
            return "连接错误: \(message)"
        case .authenticationError(let message):
            return "认证错误: \(message)"
        case .providerNotAvailable(let provider):
            return "服务提供商不可用: \(provider.rawValue)"
        case .insufficientPermissions(let role):
            return "权限不足: \(role.displayName)"
        case .noActiveSession:
            return "没有活跃的会话"
        case .invalidRoleTransition(let from, let to):
            return "无效的角色转换: 从 \(from.displayName) 到 \(to.displayName)"
        case .processorAlreadyRegistered(let messageType):
            return "消息处理器已注册: \(messageType)"
        case .tokenExpired:
            return "Token 已过期"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .invalidParameter(let message):
            return "参数错误: \(message)"
        }
    }
}

// MARK: - 服务商类型
public enum ProviderType: String, CaseIterable, Codable, Sendable {
    case agora = "agora"
    case tencent = "tencent"
    case zego = "zego"
    case mock = "mock"
    
    public var displayName: String {
        switch self {
        case .agora:
            return "声网 Agora"
        case .tencent:
            return "腾讯云 TRTC"
        case .zego:
            return "即构 ZEGO"
        case .mock:
            return "模拟服务商"
        }
    }
}

// MARK: - 连接状态
public enum ConnectionState: String, CaseIterable, Codable, Sendable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .disconnected:
            return "已断开"
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

// MARK: - 推流状态
public enum StreamPushState: String, CaseIterable, Codable, Sendable {
    case stopped = "stopped"
    case starting = "starting"
    case running = "running"
    case stopping = "stopping"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .stopped:
            return "已停止"
        case .starting:
            return "启动中"
        case .running:
            return "运行中"
        case .stopping:
            return "停止中"
        case .failed:
            return "推流失败"
        }
    }
}

// MARK: - 媒体中继状态
public enum MediaRelayState: String, CaseIterable, Codable, Sendable {
    case stopped = "stopped"
    case starting = "starting"
    case running = "running"
    case stopping = "stopping"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .stopped:
            return "已停止"
        case .starting:
            return "启动中"
        case .running:
            return "运行中"
        case .stopping:
            return "停止中"
        case .failed:
            return "中继失败"
        }
    }
}

// MARK: - 音量事件 (已移动到 VolumeModels.swift)

// MARK: - 版本信息
public struct RealtimeKitVersion: Sendable {
    public static let current = "1.0.0"
    public static let buildNumber = "1"
    public static let swiftVersion = "6.2"
}