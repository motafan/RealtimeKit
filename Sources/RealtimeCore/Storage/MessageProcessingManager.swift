import Foundation

/// 消息处理管理器，准备集成 @RealtimeStorage 支持
/// 需求: 10.1, 10.2, 18.1, 18.2
/// 注意: @RealtimeStorage 集成将在任务 3.3, 3.4 完成后实现
@MainActor
public class MessageProcessingManager: ObservableObject {
    
    // TODO: 在任务 3.3, 3.4 完成后，将这些属性迁移到 @RealtimeStorage
    public var config: MessageProcessingConfig = MessageProcessingConfig()
    private var templates: [String: MessageTemplate] = [:]
    private var messageHistory: [RealtimeMessage] = []
    private var statistics: MessageProcessingStatistics = MessageProcessingStatistics()
    
    // MARK: - Published Properties
    
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var pendingMessages: [RealtimeMessage] = []
    @Published public private(set) var processingQueue: [RealtimeMessage] = []
    
    // MARK: - Private Properties
    
    private let processingQueue_internal = DispatchQueue(label: "message.processing", qos: .userInitiated)
    private var processingTimer: Timer?
    
    // MARK: - Event Handlers
    
    public var onMessageProcessed: ((RealtimeMessage) -> Void)?
    public var onProcessingError: ((RealtimeMessage, Error) -> Void)?
    public var onValidationFailed: ((RealtimeMessage, [MessageValidationError]) -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        startProcessingTimer()
    }
    
    // TODO: 在任务 3.3, 3.4 完成后，实现正确的资源清理
    
    // MARK: - Message Processing
    
    /// 处理消息
    public func processMessage(_ message: RealtimeMessage) {
        // 验证消息
        let validationResult = MessageValidator.validate(message)
        guard validationResult.isValid else {
            onValidationFailed?(message, validationResult.errors)
            statistics.validationFailures += 1
            return
        }
        
        // 添加到处理队列
        addToProcessingQueue(message)
        
        // 如果启用了自动处理，立即处理
        if config.enableAutoProcessing {
            processNextMessage()
        }
    }
    
    /// 批量处理消息
    public func processMessages(_ messages: [RealtimeMessage]) {
        for message in messages {
            processMessage(message)
        }
    }
    
    /// 处理下一条消息
    public func processNextMessage() {
        guard !processingQueue.isEmpty else { return }
        
        let message = processingQueue.removeFirst()
        
        Task {
            await performMessageProcessing(message)
        }
    }
    
    /// 清空处理队列
    public func clearProcessingQueue() {
        processingQueue.removeAll()
        pendingMessages.removeAll()
    }
    
    // MARK: - Message Templates
    
    /// 创建消息模板
    public func createTemplate(
        name: String,
        type: RealtimeMessageType,
        content: MessageContent,
        metadata: [String: MessageMetadataValue] = [:],
        processingFlags: MessageProcessingFlags = MessageProcessingFlags()
    ) {
        let template = MessageTemplate(
            name: name,
            type: type,
            content: content,
            metadata: metadata,
            processingFlags: processingFlags
        )
        
        templates[name] = template
    }
    
    /// 从模板创建消息
    public func createMessageFromTemplate(
        templateName: String,
        senderId: String,
        receiverId: String? = nil,
        channelId: String? = nil
    ) -> RealtimeMessage? {
        guard let template = templates[templateName] else { return nil }
        
        return RealtimeMessage(
            type: template.type,
            content: template.content,
            senderId: senderId,
            receiverId: receiverId,
            channelId: channelId,
            metadata: template.metadata,
            processingFlags: template.processingFlags
        )
    }
    
    /// 删除消息模板
    public func deleteTemplate(name: String) {
        templates.removeValue(forKey: name)
    }
    
    /// 获取所有模板名称
    public func getTemplateNames() -> [String] {
        return Array(templates.keys).sorted()
    }
    
    // MARK: - Message History
    
    /// 获取消息历史
    public func getMessageHistory(limit: Int = 50) -> [RealtimeMessage] {
        return Array(messageHistory.suffix(limit))
    }
    
    /// 搜索消息历史
    public func searchMessages(
        senderId: String? = nil,
        type: RealtimeMessageType? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) -> [RealtimeMessage] {
        return messageHistory.filter { message in
            if let senderId = senderId, message.senderId != senderId {
                return false
            }
            
            if let type = type, message.type != type {
                return false
            }
            
            if let dateRange = dateRange, !dateRange.contains(message.timestamp) {
                return false
            }
            
            return true
        }
    }
    
    /// 清除消息历史
    public func clearMessageHistory() {
        messageHistory.removeAll()
    }
    
    /// 清除过期消息
    public func clearExpiredMessages() {
        let now = Date()
        messageHistory.removeAll { message in
            message.isExpired || (now.timeIntervalSince(message.timestamp) > config.messageRetentionTime)
        }
    }
    
    // MARK: - Statistics
    
    /// 获取处理统计信息
    public func getProcessingStatistics() -> MessageProcessingStatistics {
        return statistics
    }
    
    /// 重置统计信息
    public func resetStatistics() {
        statistics = MessageProcessingStatistics()
    }
    
    // MARK: - Configuration
    
    /// 更新处理配置
    public func updateConfig(_ newConfig: MessageProcessingConfig) {
        config = newConfig
        
        if config.enableAutoProcessing && !isProcessing {
            startProcessingTimer()
        } else if !config.enableAutoProcessing && isProcessing {
            stopProcessingTimer()
        }
    }
    
    /// 重置存储数据
    /// TODO: 在任务 3.3, 3.4 完成后，实现真正的持久化存储重置
    public func resetStorage() {
        config = MessageProcessingConfig()
        templates.removeAll()
        messageHistory.removeAll()
        statistics = MessageProcessingStatistics()
        clearProcessingQueue()
    }
    
    // MARK: - Private Methods
    
    private func addToProcessingQueue(_ message: RealtimeMessage) {
        // 根据优先级插入消息
        let insertIndex = processingQueue.firstIndex { $0.priority.numericValue < message.priority.numericValue } ?? processingQueue.count
        processingQueue.insert(message, at: insertIndex)
        
        // 限制队列大小
        if processingQueue.count > config.maxQueueSize {
            processingQueue.removeFirst(processingQueue.count - config.maxQueueSize)
        }
        
        pendingMessages = processingQueue
    }
    
    private func performMessageProcessing(_ message: RealtimeMessage) async {
        isProcessing = true
        
        // 模拟消息处理
        let processedMessage = message.withStatus(.processed)
        
        // 添加到历史记录
        addToHistory(processedMessage)
        statistics.processedMessages += 1
        onMessageProcessed?(processedMessage)
        isProcessing = false
        pendingMessages = processingQueue
    }
    
    private func addToHistory(_ message: RealtimeMessage) {
        messageHistory.append(message)
        
        // 限制历史记录大小
        if messageHistory.count > config.maxHistorySize {
            messageHistory.removeFirst(messageHistory.count - config.maxHistorySize)
        }
    }
    
    private func startProcessingTimer() {
        guard config.enableAutoProcessing else { return }
        
        stopProcessingTimer()
        processingTimer = Timer.scheduledTimer(withTimeInterval: config.processingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processNextMessage()
            }
        }
    }
    
    private func stopProcessingTimer() {
        processingTimer?.invalidate()
        processingTimer = nil
    }
}

/// 消息处理配置
public struct MessageProcessingConfig: Codable, Sendable, Equatable {
    public var enableAutoProcessing: Bool = true
    public var processingInterval: TimeInterval = 0.1
    public var maxQueueSize: Int = 1000
    public var maxHistorySize: Int = 10000
    public var messageRetentionTime: TimeInterval = 86400 // 24 hours
    public var enableValidation: Bool = true
    public var enableFiltering: Bool = true
    
    @MainActor
    public static let `default` = MessageProcessingConfig()
    
    public init() {}
}

/// 消息模板
public struct MessageTemplate: Codable, Sendable {
    public let name: String
    public let type: RealtimeMessageType
    public let content: MessageContent
    public let metadata: [String: MessageMetadataValue]
    public let processingFlags: MessageProcessingFlags
    
    public init(
        name: String,
        type: RealtimeMessageType,
        content: MessageContent,
        metadata: [String: MessageMetadataValue] = [:],
        processingFlags: MessageProcessingFlags = MessageProcessingFlags()
    ) {
        self.name = name
        self.type = type
        self.content = content
        self.metadata = metadata
        self.processingFlags = processingFlags
    }
}

/// 消息处理统计信息
public struct MessageProcessingStatistics: Codable, Sendable {
    public var processedMessages: Int = 0
    public var validationFailures: Int = 0
    public var processingErrors: Int = 0
    public var averageProcessingTime: TimeInterval = 0
    public var lastProcessedTime: Date?
    
    public init() {}
    
    public mutating func reset() {
        processedMessages = 0
        validationFailures = 0
        processingErrors = 0
        averageProcessingTime = 0
        lastProcessedTime = nil
    }
}