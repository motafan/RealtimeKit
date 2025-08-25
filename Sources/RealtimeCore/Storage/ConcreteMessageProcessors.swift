import Foundation

// MARK: - Text Message Processor (需求 10.4)

/// 文本消息处理器
public final class TextMessageProcessor: BaseMessageProcessor, @unchecked Sendable {
    
    public init() {
        super.init(
            name: "TextMessageProcessor",
            supportedTypes: [RealtimeMessageType.text.rawValue],
            priority: 100
        )
    }
    
    public override func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        guard case .text(let text) = message.content else {
            return .skipped
        }
        
        // 处理文本消息
        let processedText = await processTextContent(text)
        let processedContent = MessageContent.text(processedText)
        
        let processedMessage = RealtimeMessage(
            id: message.id,
            type: message.type,
            content: processedContent,
            senderId: message.senderId,
            receiverId: message.receiverId,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: message.metadata,
            status: .processed,
            priority: message.priority,
            expirationTime: message.expirationTime,
            processingFlags: message.processingFlags
        )
        
        return .processed(processedMessage)
    }
    
    private func processTextContent(_ text: String) async -> String {
        // 文本处理逻辑：去除多余空格、过滤敏感词等
        var processedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 去除多余的空格
        processedText = processedText.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // 简单的敏感词过滤
        let sensitiveWords = ["spam", "垃圾", "广告"]
        for word in sensitiveWords {
            processedText = processedText.replacingOccurrences(
                of: word,
                with: String(repeating: "*", count: word.count),
                options: .caseInsensitive
            )
        }
        
        return processedText
    }
}

// MARK: - System Message Processor (需求 10.4)

/// 系统消息处理器
public final class SystemMessageProcessor: BaseMessageProcessor, @unchecked Sendable {
    
    public init() {
        super.init(
            name: "SystemMessageProcessor",
            supportedTypes: [RealtimeMessageType.system.rawValue],
            priority: 200
        )
    }
    
    public override func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        guard case .system(let systemContent) = message.content else {
            return .skipped
        }
        
        // 处理系统消息
        let processedContent = await processSystemContent(systemContent, message: message)
        
        let processedMessage = RealtimeMessage(
            id: message.id,
            type: message.type,
            content: .system(processedContent),
            senderId: message.senderId,
            receiverId: message.receiverId,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: message.metadata,
            status: .processed,
            priority: message.priority,
            expirationTime: message.expirationTime,
            processingFlags: message.processingFlags
        )
        
        return .processed(processedMessage)
    }
    
    private func processSystemContent(_ content: SystemContent, message: RealtimeMessage) async -> SystemContent {
        // 根据系统消息类型进行不同处理
        switch content.systemType {
        case .userJoined:
            return processUserJoinedMessage(content, message: message)
        case .userLeft:
            return processUserLeftMessage(content, message: message)
        case .userRoleChanged:
            return processUserRoleChangedMessage(content, message: message)
        case .connectionLost, .connectionRestored:
            return processConnectionMessage(content, message: message)
        default:
            return content
        }
    }
    
    private func processUserJoinedMessage(_ content: SystemContent, message: RealtimeMessage) -> SystemContent {
        var parameters = content.parameters
        parameters["processedAt"] = ISO8601DateFormatter().string(from: Date())
        parameters["processorName"] = processorName
        
        return SystemContent(
            message: content.message,
            systemType: content.systemType,
            parameters: parameters
        )
    }
    
    private func processUserLeftMessage(_ content: SystemContent, message: RealtimeMessage) -> SystemContent {
        var parameters = content.parameters
        parameters["processedAt"] = ISO8601DateFormatter().string(from: Date())
        parameters["processorName"] = processorName
        
        return SystemContent(
            message: content.message,
            systemType: content.systemType,
            parameters: parameters
        )
    }
    
    private func processUserRoleChangedMessage(_ content: SystemContent, message: RealtimeMessage) -> SystemContent {
        var parameters = content.parameters
        parameters["processedAt"] = ISO8601DateFormatter().string(from: Date())
        parameters["processorName"] = processorName
        
        return SystemContent(
            message: content.message,
            systemType: content.systemType,
            parameters: parameters
        )
    }
    
    private func processConnectionMessage(_ content: SystemContent, message: RealtimeMessage) -> SystemContent {
        var parameters = content.parameters
        parameters["processedAt"] = ISO8601DateFormatter().string(from: Date())
        parameters["processorName"] = processorName
        parameters["priority"] = "high" // 连接相关消息设为高优先级
        
        return SystemContent(
            message: content.message,
            systemType: content.systemType,
            parameters: parameters
        )
    }
}

// MARK: - Image Message Processor (需求 10.4)

/// 图片消息处理器
public final class ImageMessageProcessor: BaseMessageProcessor, @unchecked Sendable {
    
    public init() {
        super.init(
            name: "ImageMessageProcessor",
            supportedTypes: [RealtimeMessageType.image.rawValue],
            priority: 80
        )
    }
    
    public override func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        guard case .image(let imageContent) = message.content else {
            return .skipped
        }
        
        // 处理图片消息
        let processedContent = await processImageContent(imageContent)
        
        let processedMessage = RealtimeMessage(
            id: message.id,
            type: message.type,
            content: .image(processedContent),
            senderId: message.senderId,
            receiverId: message.receiverId,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: message.metadata,
            status: .processed,
            priority: message.priority,
            expirationTime: message.expirationTime,
            processingFlags: message.processingFlags
        )
        
        return .processed(processedMessage)
    }
    
    private func processImageContent(_ content: ImageContent) async -> ImageContent {
        // 图片处理逻辑：验证URL、生成缩略图等
        var processedContent = content
        
        // 验证图片URL
        if !isValidImageURL(content.url) {
            print("警告: 无效的图片URL: \(content.url)")
        }
        
        // 如果没有缩略图，尝试生成
        if content.thumbnailUrl == nil {
            // 这里可以集成图片处理服务来生成缩略图
            // 暂时使用原图URL作为缩略图
            processedContent = ImageContent(
                url: content.url,
                thumbnailUrl: content.url,
                width: content.width,
                height: content.height,
                fileSize: content.fileSize,
                mimeType: content.mimeType ?? "image/jpeg"
            )
        }
        
        return processedContent
    }
    
    private func isValidImageURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // 检查URL格式
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        
        // 检查文件扩展名
        let validExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        let pathExtension = url.pathExtension.lowercased()
        
        return validExtensions.contains(pathExtension)
    }
}

// MARK: - Custom Message Processor (需求 10.4)

/// 自定义消息处理器
public final class CustomMessageProcessor: BaseMessageProcessor, @unchecked Sendable {
    
    private let customHandler: (@Sendable (RealtimeMessage) async throws -> MessageProcessingResult)?
    
    public init(
        name: String = "CustomMessageProcessor",
        supportedTypes: [String] = [RealtimeMessageType.custom.rawValue],
        priority: Int = 50,
        customHandler: (@Sendable (RealtimeMessage) async throws -> MessageProcessingResult)? = nil
    ) {
        self.customHandler = customHandler
        super.init(name: name, supportedTypes: supportedTypes, priority: priority)
    }
    
    public override func process(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        // 如果有自定义处理器，使用自定义处理器
        if let handler = customHandler {
            return try await handler(message)
        }
        
        // 默认自定义消息处理
        guard case .custom(let customContent) = message.content else {
            return .skipped
        }
        
        let processedContent = await processCustomContent(customContent)
        
        let processedMessage = RealtimeMessage(
            id: message.id,
            type: message.type,
            content: .custom(processedContent),
            senderId: message.senderId,
            receiverId: message.receiverId,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: message.metadata,
            status: .processed,
            priority: message.priority,
            expirationTime: message.expirationTime,
            processingFlags: message.processingFlags
        )
        
        return .processed(processedMessage)
    }
    
    private func processCustomContent(_ content: CustomContent) async -> CustomContent {
        // 自定义内容处理逻辑
        var processedData = content.data
        
        // 添加处理时间戳
        processedData["processedAt"] = .string(ISO8601DateFormatter().string(from: Date()))
        processedData["processorName"] = .string(processorName)
        
        return CustomContent(
            data: processedData,
            customType: content.customType
        )
    }
}

// MARK: - Message Filter Implementations (需求 10.5)

/// 垃圾消息过滤器
public final class SpamMessageFilter: MessageFilter, @unchecked Sendable {
    public let filterName = "SpamMessageFilter"
    
    private let spamKeywords = ["spam", "垃圾", "广告", "推广", "免费", "赚钱"]
    
    public func shouldFilter(_ message: RealtimeMessage) -> Bool {
        guard case .text(let text) = message.content else {
            return false
        }
        
        let lowercaseText = text.lowercased()
        return spamKeywords.contains { keyword in
            lowercaseText.contains(keyword.lowercased())
        }
    }
    
    public func filterReason(for message: RealtimeMessage) -> String {
        return "消息包含垃圾信息关键词"
    }
}

/// 过期消息过滤器
public final class ExpiredMessageFilter: MessageFilter, @unchecked Sendable {
    public let filterName = "ExpiredMessageFilter"
    
    public func shouldFilter(_ message: RealtimeMessage) -> Bool {
        return message.isExpired
    }
    
    public func filterReason(for message: RealtimeMessage) -> String {
        return "消息已过期"
    }
}

/// 重复消息过滤器
public final class DuplicateMessageFilter: MessageFilter, @unchecked Sendable {
    public let filterName = "DuplicateMessageFilter"
    
    private var processedMessageIds: Set<String> = []
    private let maxCacheSize = 10000
    
    public func shouldFilter(_ message: RealtimeMessage) -> Bool {
        if processedMessageIds.contains(message.id) {
            return true
        }
        
        // 添加到缓存
        processedMessageIds.insert(message.id)
        
        // 限制缓存大小
        if processedMessageIds.count > maxCacheSize {
            let idsToRemove = Array(processedMessageIds.prefix(processedMessageIds.count - maxCacheSize))
            for id in idsToRemove {
                processedMessageIds.remove(id)
            }
        }
        
        return false
    }
    
    public func filterReason(for message: RealtimeMessage) -> String {
        return "重复消息"
    }
}

// MARK: - Message Transformer Implementations (需求 10.5)

/// 文本格式化转换器
public final class TextFormattingTransformer: MessageTransformer, @unchecked Sendable {
    public let transformerName = "TextFormattingTransformer"
    public let supportedMessageTypes = [RealtimeMessageType.text.rawValue]
    
    public func transform(_ message: RealtimeMessage) async throws -> RealtimeMessage {
        guard case .text(let text) = message.content else {
            return message
        }
        
        // 格式化文本
        let formattedText = formatText(text)
        let transformedContent = MessageContent.text(formattedText)
        
        return RealtimeMessage(
            id: message.id,
            type: message.type,
            content: transformedContent,
            senderId: message.senderId,
            receiverId: message.receiverId,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: message.metadata,
            status: message.status,
            priority: message.priority,
            expirationTime: message.expirationTime,
            processingFlags: message.processingFlags
        )
    }
    
    private func formatText(_ text: String) -> String {
        var formatted = text
        
        // 去除多余空格
        formatted = formatted.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // 首字母大写
        if !formatted.isEmpty {
            formatted = formatted.prefix(1).uppercased() + formatted.dropFirst()
        }
        
        // 确保句子以标点符号结尾
        let punctuation = [".", "!", "?", "。", "！", "？"]
        if !punctuation.contains(where: { formatted.hasSuffix($0) }) {
            formatted += "。"
        }
        
        return formatted
    }
}

/// 消息元数据增强转换器
public final class MetadataEnhancementTransformer: MessageTransformer, @unchecked Sendable {
    public let transformerName = "MetadataEnhancementTransformer"
    public let supportedMessageTypes = RealtimeMessageType.allCases.map { $0.rawValue }
    
    public func transform(_ message: RealtimeMessage) async throws -> RealtimeMessage {
        var enhancedMetadata = message.metadata
        
        // 添加处理时间戳
        enhancedMetadata["transformedAt"] = .string(ISO8601DateFormatter().string(from: Date()))
        
        // 添加转换器信息
        enhancedMetadata["transformerName"] = .string(transformerName)
        
        // 添加消息长度信息
        if case .text(let text) = message.content {
            enhancedMetadata["textLength"] = .int(text.count)
        }
        
        // 添加消息类型信息
        enhancedMetadata["messageType"] = .string(message.type.rawValue)
        
        return RealtimeMessage(
            id: message.id,
            type: message.type,
            content: message.content,
            senderId: message.senderId,
            receiverId: message.receiverId,
            channelId: message.channelId,
            timestamp: message.timestamp,
            metadata: enhancedMetadata,
            status: message.status,
            priority: message.priority,
            expirationTime: message.expirationTime,
            processingFlags: message.processingFlags
        )
    }
}

// MARK: - Message Validator Implementations (需求 10.5)

/// 消息内容验证器
public final class MessageContentValidator: MessageValidatorProtocol, @unchecked Sendable {
    public let validatorName = "MessageContentValidator"
    
    public func validate(_ message: RealtimeMessage) async -> MessageValidationResult {
        var errors: [MessageValidationError] = []
        
        // 验证消息内容不为空
        if message.content.isEmpty {
            errors.append(.emptyContent)
        }
        
        // 验证文本消息长度
        if case .text(let text) = message.content {
            if text.count > 10000 {
                errors.append(.contentTypeMismatch) // 重用现有错误类型
            }
        }
        
        // 验证发送者ID
        if message.senderId.isEmpty {
            errors.append(.emptySenderId)
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

/// 消息权限验证器
public final class MessagePermissionValidator: MessageValidatorProtocol, @unchecked Sendable {
    public let validatorName = "MessagePermissionValidator"
    
    private let allowedSenders: Set<String>
    
    public init(allowedSenders: Set<String> = []) {
        self.allowedSenders = allowedSenders
    }
    
    public func validate(_ message: RealtimeMessage) async -> MessageValidationResult {
        // 如果没有限制发送者，则通过验证
        if allowedSenders.isEmpty {
            return .valid
        }
        
        // 检查发送者是否在允许列表中
        if allowedSenders.contains(message.senderId) {
            return .valid
        } else {
            return .invalid([.emptySenderId]) // 重用现有错误类型
        }
    }
}