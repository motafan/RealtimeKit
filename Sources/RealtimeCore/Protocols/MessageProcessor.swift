import Foundation

/// 消息处理器协议，用于定义消息处理管道中的处理器
/// 需求: 10.2, 10.3
public protocol MessageProcessor: AnyObject, Sendable {
    /// 支持的消息类型
    var supportedMessageTypes: [String] { get }
    
    /// 处理器名称
    var processorName: String { get }
    
    /// 处理器优先级（数值越高优先级越高）
    var priority: Int { get }
    
    /// 检查是否可以处理指定消息
    /// - Parameter message: 要检查的消息
    /// - Returns: 如果可以处理返回true，否则返回false
    func canProcess(_ message: RealtimeMessage) -> Bool
    
    /// 处理消息
    /// - Parameter message: 要处理的消息
    /// - Returns: 处理结果
    func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult
    
    /// 处理错误时的回调
    /// - Parameters:
    ///   - error: 处理过程中发生的错误
    ///   - message: 处理失败的消息
    /// - Returns: 错误处理结果
    func handleProcessingError(_ error: Error, for message: RealtimeMessage) async -> MessageProcessingResult
    
    /// 处理器初始化
    func initialize() async throws
    
    /// 处理器清理
    func cleanup() async
}

/// 消息处理结果
public enum MessageProcessingResult: Sendable {
    /// 处理成功，可选返回处理后的消息
    case processed(RealtimeMessage?)
    /// 处理失败
    case failed(Error)
    /// 跳过处理
    case skipped
    /// 需要重试，指定延迟时间
    case retry(after: TimeInterval)
    
    /// 检查是否处理成功
    public var isSuccess: Bool {
        switch self {
        case .processed: return true
        case .failed, .skipped, .retry: return false
        }
    }
    
    /// 获取处理后的消息（如果有）
    public var processedMessage: RealtimeMessage? {
        switch self {
        case .processed(let message): return message
        default: return nil
        }
    }
    
    /// 获取错误信息（如果有）
    public var error: Error? {
        switch self {
        case .failed(let error): return error
        default: return nil
        }
    }
    
    /// 获取重试延迟时间（如果需要重试）
    public var retryDelay: TimeInterval? {
        switch self {
        case .retry(let delay): return delay
        default: return nil
        }
    }
}

/// 消息处理器错误
public enum MessageProcessorError: Error, LocalizedError, Sendable {
    case processorNotFound(String)
    case processorAlreadyRegistered(String)
    case processingTimeout
    case invalidMessageType
    case processingChainFailed([Error])
    case initializationFailed(String)
    case cleanupFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .processorNotFound(let name):
            return "消息处理器未找到: \(name)"
        case .processorAlreadyRegistered(let name):
            return "消息处理器已注册: \(name)"
        case .processingTimeout:
            return "消息处理超时"
        case .invalidMessageType:
            return "无效的消息类型"
        case .processingChainFailed(let errors):
            return "处理链失败: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .initializationFailed(let reason):
            return "处理器初始化失败: \(reason)"
        case .cleanupFailed(let reason):
            return "处理器清理失败: \(reason)"
        }
    }
}

/// 消息处理器基类，提供默认实现
open class BaseMessageProcessor: MessageProcessor, @unchecked Sendable {
    public let processorName: String
    public let supportedMessageTypes: [String]
    public let priority: Int
    
    public init(name: String, supportedTypes: [String], priority: Int = 0) {
        self.processorName = name
        self.supportedMessageTypes = supportedTypes
        self.priority = priority
    }
    
    open func canProcess(_ message: RealtimeMessage) -> Bool {
        return supportedMessageTypes.contains(message.type.rawValue)
    }
    
    open func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        // 子类需要重写此方法
        return .skipped
    }
    
    open func handleProcessingError(_ error: Error, for message: RealtimeMessage) async -> MessageProcessingResult {
        // 默认错误处理：记录错误并返回失败结果
        print("处理器 \(processorName) 处理消息失败: \(error.localizedDescription)")
        return .failed(error)
    }
    
    open func initialize() async throws {
        // 默认初始化实现
    }
    
    open func cleanup() async {
        // 默认清理实现
    }
}

/// 消息过滤器协议
public protocol MessageFilter: AnyObject, Sendable {
    /// 过滤器名称
    var filterName: String { get }
    
    /// 检查消息是否应该被过滤
    /// - Parameter message: 要检查的消息
    /// - Returns: 如果消息应该被过滤返回true，否则返回false
    func shouldFilter(_ message: RealtimeMessage) -> Bool
    
    /// 过滤原因
    /// - Parameter message: 被过滤的消息
    /// - Returns: 过滤原因描述
    func filterReason(for message: RealtimeMessage) -> String
}

/// 消息转换器协议
public protocol MessageTransformer: AnyObject, Sendable {
    /// 转换器名称
    var transformerName: String { get }
    
    /// 支持的消息类型
    var supportedMessageTypes: [String] { get }
    
    /// 转换消息
    /// - Parameter message: 要转换的消息
    /// - Returns: 转换后的消息
    func transform(_ message: RealtimeMessage) async throws -> RealtimeMessage
}

/// 消息验证器协议
public protocol MessageValidatorProtocol: AnyObject, Sendable {
    /// 验证器名称
    var validatorName: String { get }
    
    /// 验证消息
    /// - Parameter message: 要验证的消息
    /// - Returns: 验证结果
    func validate(_ message: RealtimeMessage) async -> MessageValidationResult
}