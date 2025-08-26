import Foundation

/// 消息处理管理器，实现消息处理管道系统
/// 需求: 10.1, 10.2, 10.3, 18.1, 18.2
/// 注意: @RealtimeStorage 集成将在任务 3.3, 3.4 完成后实现
@MainActor
public class MessageProcessingManager: ObservableObject {
    
    // TODO: 在任务 3.3, 3.4 完成后，将这些属性迁移到 @RealtimeStorage
    public var config: MessageProcessingConfig = MessageProcessingConfig()
    private var templates: [String: MessageTemplate] = [:]
    private var messageHistory: [RealtimeMessage] = []
    private var statistics: MessageProcessingStatistics = MessageProcessingStatistics()
    
    // MARK: - Message Processing Pipeline Properties
    
    /// 注册的消息处理器（按类型索引）
    private var processors: [String: MessageProcessor] = [:]
    
    /// 处理器链（按优先级排序）
    private var processingChain: [MessageProcessor] = []
    
    /// 消息过滤器
    private var filters: [MessageFilter] = []
    
    /// 消息转换器
    private var transformers: [MessageTransformer] = []
    
    /// 消息验证器
    private var validators: [MessageValidatorProtocol] = []
    
    /// 处理中的消息（用于避免重复处理）
    private var processingMessages: Set<String> = []
    
    /// 重试计数器
    private var retryCounters: [String: Int] = [:]
    
    // MARK: - Published Properties
    
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var pendingMessages: [RealtimeMessage] = []
    @Published public private(set) var processingQueue: [RealtimeMessage] = []
    @Published public private(set) var registeredProcessors: [String] = []
    @Published public private(set) var processingStats: MessageProcessingStats = MessageProcessingStats()
    
    // MARK: - Private Properties
    
    private let processingQueue_internal = DispatchQueue(label: "message.processing", qos: .userInitiated)
    private var processingTimer: Timer?
    
    // MARK: - Event Handlers
    
    public var onMessageProcessed: ((RealtimeMessage) -> Void)?
    public var onProcessingError: ((RealtimeMessage, Error) -> Void)?
    public var onValidationFailed: ((RealtimeMessage, [MessageValidationError]) -> Void)?
    public var onProcessorRegistered: ((MessageProcessor) -> Void)?
    public var onProcessorUnregistered: ((String) -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        startProcessingTimer()
    }
    
    deinit {
        // Note: Cannot use async operations in deinit
        // Cleanup will be handled by explicit cleanup calls
    }
    
    // MARK: - Processor Registration and Management (需求 10.2)
    
    /// 注册消息处理器
    /// - Parameter processor: 要注册的处理器
    /// - Throws: 如果处理器已存在则抛出错误
    public func registerProcessor<T: MessageProcessor>(_ processor: T) throws {
        // 检查是否已注册同名处理器
        if processors[processor.processorName] != nil {
            throw MessageProcessorError.processorAlreadyRegistered(processor.processorName)
        }
        
        // 注册处理器
        processors[processor.processorName] = processor
        
        // 重新构建处理链（按优先级排序）
        rebuildProcessingChain()
        
        // 更新发布的属性
        registeredProcessors = Array(processors.keys).sorted()
        
        // 异步初始化处理器
        Task {
            do {
                try await processor.initialize()
            } catch {
                print("处理器 \(processor.processorName) 初始化失败: \(error.localizedDescription)")
            }
        }
        
        // 触发事件
        onProcessorRegistered?(processor)
        
        print("已注册消息处理器: \(processor.processorName)")
    }
    
    /// 注销消息处理器
    /// - Parameter processorName: 处理器名称
    /// - Throws: 如果处理器不存在则抛出错误
    public func unregisterProcessor(named processorName: String) throws {
        guard let processor = processors[processorName] else {
            throw MessageProcessorError.processorNotFound(processorName)
        }
        
        // 清理处理器
        Task {
            await processor.cleanup()
        }
        
        // 移除处理器
        processors.removeValue(forKey: processorName)
        
        // 重新构建处理链
        rebuildProcessingChain()
        
        // 更新发布的属性
        registeredProcessors = Array(processors.keys).sorted()
        
        // 触发事件
        onProcessorUnregistered?(processorName)
        
        print("已注销消息处理器: \(processorName)")
    }
    
    /// 根据消息类型注销处理器
    /// - Parameter messageType: 消息类型
    public func unregisterProcessor(for messageType: String) throws {
        let processorsToRemove = processors.values.filter { processor in
            processor.supportedMessageTypes.contains(messageType)
        }
        
        for processor in processorsToRemove {
            try unregisterProcessor(named: processor.processorName)
        }
    }
    
    /// 获取已注册的处理器
    /// - Parameter processorName: 处理器名称
    /// - Returns: 处理器实例，如果不存在返回nil
    public func getProcessor(named processorName: String) -> MessageProcessor? {
        return processors[processorName]
    }
    
    /// 注册默认的消息处理器
    /// 包括文本、系统、图片和自定义消息处理器
    public func registerDefaultProcessors() {
        do {
            // 注册文本消息处理器
            try registerProcessor(TextMessageProcessor())
            
            // 注册系统消息处理器
            try registerProcessor(SystemMessageProcessor())
            
            // 注册图片消息处理器
            try registerProcessor(ImageMessageProcessor())
            
            // 注册自定义消息处理器
            try registerProcessor(CustomMessageProcessor())
            
            print("已注册所有默认消息处理器")
        } catch {
            print("注册默认消息处理器失败: \(error)")
        }
    }
    
    /// 获取支持指定消息类型的处理器
    /// - Parameter messageType: 消息类型
    /// - Returns: 支持该类型的处理器数组
    public func getProcessors(for messageType: String) -> [MessageProcessor] {
        return processors.values.filter { processor in
            processor.supportedMessageTypes.contains(messageType)
        }.sorted { $0.priority > $1.priority }
    }
    
    /// 清理所有处理器
    public func cleanupAllProcessors() async {
        for processor in processors.values {
            await processor.cleanup()
        }
        processors.removeAll()
        processingChain.removeAll()
        registeredProcessors.removeAll()
    }
    
    /// 重新构建处理链
    private func rebuildProcessingChain() {
        processingChain = processors.values.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - Filter Management
    
    /// 注册消息过滤器
    /// - Parameter filter: 要注册的过滤器
    public func registerFilter(_ filter: MessageFilter) {
        filters.append(filter)
        print("已注册消息过滤器: \(filter.filterName)")
    }
    
    /// 注销消息过滤器
    /// - Parameter filterName: 过滤器名称
    public func unregisterFilter(named filterName: String) {
        filters.removeAll { $0.filterName == filterName }
        print("已注销消息过滤器: \(filterName)")
    }
    
    // MARK: - Transformer Management
    
    /// 注册消息转换器
    /// - Parameter transformer: 要注册的转换器
    public func registerTransformer(_ transformer: MessageTransformer) {
        transformers.append(transformer)
        print("已注册消息转换器: \(transformer.transformerName)")
    }
    
    /// 注销消息转换器
    /// - Parameter transformerName: 转换器名称
    public func unregisterTransformer(named transformerName: String) {
        transformers.removeAll { $0.transformerName == transformerName }
        print("已注销消息转换器: \(transformerName)")
    }
    
    // MARK: - Validator Management
    
    /// 注册消息验证器
    /// - Parameter validator: 要注册的验证器
    public func registerValidator(_ validator: MessageValidatorProtocol) {
        validators.append(validator)
        print("已注册消息验证器: \(validator.validatorName)")
    }
    
    /// 注销消息验证器
    /// - Parameter validatorName: 验证器名称
    public func unregisterValidator(named validatorName: String) {
        validators.removeAll { $0.validatorName == validatorName }
        print("已注销消息验证器: \(validatorName)")
    }
    
    // MARK: - Message Processing (需求 10.3, 10.4)
    
    /// 处理消息
    public func processMessage(_ message: RealtimeMessage) async {
        // 检查是否已在处理中
        guard !processingMessages.contains(message.id) else {
            print("消息 \(message.id) 已在处理中，跳过")
            return
        }
        
        // 标记为处理中
        processingMessages.insert(message.id)
        defer { processingMessages.remove(message.id) }
        
        // 更新统计信息
        processingStats.totalReceived += 1
        
        do {
            // 执行完整的处理管道
            let result = try await processMessageThroughPipeline(message)
            await handleProcessingResult(result, for: message)
        } catch {
            await handleProcessingError(error, for: message)
        }
    }
    
    /// 批量处理消息
    public func processMessages(_ messages: [RealtimeMessage]) async {
        for message in messages {
            await processMessage(message)
        }
    }
    
    /// 处理下一条消息
    public func processNextMessage() {
        guard !processingQueue.isEmpty else { return }
        
        let message = processingQueue.removeFirst()
        pendingMessages = processingQueue
        
        Task {
            await processMessage(message)
        }
    }
    
    /// 清空处理队列
    public func clearProcessingQueue() {
        processingQueue.removeAll()
        pendingMessages.removeAll()
    }
    
    /// 通过完整管道处理消息
    private func processMessageThroughPipeline(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        var currentMessage = message
        
        // 1. 消息过滤阶段（在验证之前进行，以便过滤过期消息等）
        if config.enableFiltering {
            let filterResult = await filterMessage(currentMessage)
            if !filterResult.passed {
                return .skipped
            }
        }
        
        // 2. 消息验证阶段（跳过过期检查，因为已经在过滤阶段处理）
        if config.enableValidation {
            let validationResult = await validateMessageExcludingExpiration(currentMessage)
            guard validationResult.isValid else {
                onValidationFailed?(currentMessage, validationResult.errors)
                return .failed(MessageProcessorError.invalidMessageType)
            }
        }
        
        // 3. 消息转换阶段
        currentMessage = try await transformMessage(currentMessage)
        
        // 4. 处理器链处理阶段
        let processingResult = try await processMessageThroughChain(currentMessage)
        
        return processingResult
    }
    
    /// 通过处理器链处理消息
    private func processMessageThroughChain(_ message: RealtimeMessage) async throws -> MessageProcessingResult {
        var currentMessage = message
        var lastResult: MessageProcessingResult = .skipped
        var processedCount = 0
        
        // 获取支持该消息类型的处理器
        let supportedProcessors = processingChain.filter { $0.canProcess(currentMessage) }
        
        guard !supportedProcessors.isEmpty else {
            // 没有支持的处理器，直接跳过
            return .skipped
        }
        
        // 按优先级顺序处理
        for processor in supportedProcessors {
            do {
                let result = try await processor.process(currentMessage)
                
                switch result {
                case .processed(let processedMessage):
                    if let processed = processedMessage {
                        currentMessage = processed
                    }
                    lastResult = result
                    processedCount += 1
                    
                    // 如果配置为单处理器模式，处理完成后退出
                    if config.singleProcessorMode {
                        return lastResult
                    }
                    
                case .failed(let error):
                    let errorResult = await processor.handleProcessingError(error, for: currentMessage)
                    if case .retry(let delay) = errorResult {
                        return .retry(after: delay)
                    }
                    return errorResult
                    
                case .skipped:
                    continue
                    
                case .retry(let delay):
                    return .retry(after: delay)
                }
            } catch {
                let errorResult = await processor.handleProcessingError(error, for: currentMessage)
                if case .retry(let delay) = errorResult {
                    return .retry(after: delay)
                }
                return errorResult
            }
        }
        
        // 如果至少有一个处理器成功处理了消息，返回成功结果
        if processedCount > 0 {
            return .processed(currentMessage)
        }
        
        return lastResult
    }
    
    /// 验证消息
    private func validateMessage(_ message: RealtimeMessage) async -> MessageValidationResult {
        // 使用内置验证器
        let builtinResult = MessageValidator.validate(message)
        guard builtinResult.isValid else {
            return builtinResult
        }
        
        // 使用自定义验证器
        for validator in validators {
            let result = await validator.validate(message)
            if !result.isValid {
                return result
            }
        }
        
        return .valid
    }
    
    /// 验证消息（排除过期检查）
    private func validateMessageExcludingExpiration(_ message: RealtimeMessage) async -> MessageValidationResult {
        // 使用内置验证器（排除过期检查）
        let builtinResult = MessageValidator.validateExcludingExpiration(message)
        guard builtinResult.isValid else {
            return builtinResult
        }
        
        // 使用自定义验证器
        for validator in validators {
            let result = await validator.validate(message)
            if !result.isValid {
                return result
            }
        }
        
        return .valid
    }
    
    /// 过滤消息
    private func filterMessage(_ message: RealtimeMessage) async -> FilterResult {
        for filter in filters {
            if filter.shouldFilter(message) {
                let reason = filter.filterReason(for: message)
                print("消息被过滤: \(reason)")
                return FilterResult(passed: false, reason: reason)
            }
        }
        return FilterResult(passed: true, reason: nil)
    }
    
    /// 转换消息
    private func transformMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage {
        var currentMessage = message
        
        for transformer in transformers {
            if transformer.supportedMessageTypes.contains(message.type.rawValue) {
                currentMessage = try await transformer.transform(currentMessage)
            }
        }
        
        return currentMessage
    }
    
    /// 处理处理结果
    private func handleProcessingResult(_ result: MessageProcessingResult, for message: RealtimeMessage) async {
        switch result {
        case .processed(let processedMessage):
            processingStats.totalProcessed += 1
            let finalMessage = processedMessage ?? message.withStatus(.processed)
            addToHistory(finalMessage)
            onMessageProcessed?(finalMessage)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .messageProcessed,
                object: finalMessage
            )
            
        case .failed(let error):
            await handleProcessingError(error, for: message)
            
        case .skipped:
            processingStats.totalSkipped += 1
            print("消息 \(message.id) 被跳过处理")
            
        case .retry(let delay):
            await scheduleRetry(for: message, after: delay)
        }
    }
    
    /// 处理处理错误
    private func handleProcessingError(_ error: Error, for message: RealtimeMessage) async {
        processingStats.totalFailed += 1
        
        // 检查重试次数
        let retryCount = retryCounters[message.id] ?? 0
        if retryCount < config.maxRetryCount {
            retryCounters[message.id] = retryCount + 1
            await scheduleRetry(for: message, after: config.retryDelay)
        } else {
            // 达到最大重试次数，记录错误
            let failedMessage = message.withStatus(.failed)
            addToHistory(failedMessage)
            onProcessingError?(message, error)
            
            // 清除重试计数
            retryCounters.removeValue(forKey: message.id)
            
            // 发送错误通知
            NotificationCenter.default.post(
                name: .messageProcessingFailed,
                object: MessageProcessingError(message: message, error: error)
            )
        }
    }
    
    /// 安排重试
    private func scheduleRetry(for message: RealtimeMessage, after delay: TimeInterval) async {
        print("消息 \(message.id) 将在 \(delay) 秒后重试")
        
        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await processMessage(message)
        }
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
    
    /// 处理消息（同步版本，用于向后兼容）
    public func processMessage(_ message: RealtimeMessage) {
        Task {
            await processMessage(message)
        }
    }
    
    private func performMessageProcessing(_ message: RealtimeMessage) async {
        isProcessing = true
        defer { isProcessing = false }
        
        await processMessage(message)
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
    public var singleProcessorMode: Bool = false // 是否只使用第一个匹配的处理器
    public var maxRetryCount: Int = 3
    public var retryDelay: TimeInterval = 1.0
    public var processingTimeout: TimeInterval = 30.0
    
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

/// 消息处理统计信息（新版本，用于处理管道）
public struct MessageProcessingStats: Codable, Sendable {
    public var totalReceived: Int = 0
    public var totalProcessed: Int = 0
    public var totalFailed: Int = 0
    public var totalSkipped: Int = 0
    public var retryCount: [String: Int] = [:]
    
    public init() {}
    
    public mutating func reset() {
        totalReceived = 0
        totalProcessed = 0
        totalFailed = 0
        totalSkipped = 0
        retryCount.removeAll()
    }
    
    public func shouldRetry(for messageType: String) -> Bool {
        let count = retryCount[messageType] ?? 0
        return count < 3
    }
}

/// 过滤结果
public struct FilterResult {
    public let passed: Bool
    public let reason: String?
    
    public init(passed: Bool, reason: String? = nil) {
        self.passed = passed
        self.reason = reason
    }
}

/// 消息处理错误信息
public struct MessageProcessingError {
    public let message: RealtimeMessage
    public let error: Error
    public let timestamp: Date = Date()
    
    public init(message: RealtimeMessage, error: Error) {
        self.message = message
        self.error = error
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    public static let messageProcessed = Notification.Name("RealtimeKit.messageProcessed")
    public static let messageProcessingFailed = Notification.Name("RealtimeKit.messageProcessingFailed")
}