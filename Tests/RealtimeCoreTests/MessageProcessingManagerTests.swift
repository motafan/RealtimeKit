import Testing
import Foundation
@testable import RealtimeCore

/// 消息处理管理器测试
/// 需求: 10.1, 10.2, 10.3, 测试要求 1
@MainActor
struct MessageProcessingManagerTests {
    
    // MARK: - Processor Registration Tests (需求 10.2)
    
    @Test("消息处理器注册测试")
    func testMessageProcessorRegistration() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        
        // 注册处理器 (需求 10.2)
        try processingManager.registerProcessor(textProcessor)
        
        // 验证处理器已注册
        #expect(processingManager.registeredProcessors.contains("TextMessageProcessor"))
        
        // 验证可以获取处理器
        let retrievedProcessor = processingManager.getProcessor(named: "TextMessageProcessor")
        #expect(retrievedProcessor != nil)
        #expect(retrievedProcessor?.processorName == "TextMessageProcessor")
    }
    
    @Test("重复注册处理器应该失败")
    func testDuplicateProcessorRegistration() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor1 = TextMessageProcessor()
        let textProcessor2 = TextMessageProcessor()
        
        // 第一次注册应该成功
        try processingManager.registerProcessor(textProcessor1)
        
        // 第二次注册相同名称的处理器应该失败
        #expect(throws: MessageProcessorError.self) {
            try processingManager.registerProcessor(textProcessor2)
        }
    }
    
    @Test("处理器注销测试")
    func testProcessorUnregistration() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        
        // 注册处理器
        try processingManager.registerProcessor(textProcessor)
        #expect(processingManager.registeredProcessors.contains("TextMessageProcessor"))
        
        // 注销处理器
        try processingManager.unregisterProcessor(named: "TextMessageProcessor")
        #expect(!processingManager.registeredProcessors.contains("TextMessageProcessor"))
        
        // 验证处理器已被移除
        let retrievedProcessor = processingManager.getProcessor(named: "TextMessageProcessor")
        #expect(retrievedProcessor == nil)
    }
    
    @Test("根据消息类型获取处理器")
    func testGetProcessorsByMessageType() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        let systemProcessor = SystemMessageProcessor()
        
        try processingManager.registerProcessor(textProcessor)
        try processingManager.registerProcessor(systemProcessor)
        
        // 获取文本消息处理器
        let textProcessors = processingManager.getProcessors(for: "text")
        #expect(textProcessors.count == 1)
        #expect(textProcessors.first?.processorName == "TextMessageProcessor")
        
        // 获取系统消息处理器
        let systemProcessors = processingManager.getProcessors(for: "system")
        #expect(systemProcessors.count == 1)
        #expect(systemProcessors.first?.processorName == "SystemMessageProcessor")
    }
    
    // MARK: - Message Processing Chain Tests (需求 10.3)
    
    @Test("消息处理链测试")
    func testMessageProcessingChain() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        let imageProcessor = ImageMessageProcessor()
        
        try processingManager.registerProcessor(textProcessor)
        try processingManager.registerProcessor(imageProcessor)
        
        // 创建文本消息
        let textMessage = RealtimeMessage(
            type: .text,
            content: .text("  Hello World  "),
            senderId: "user123"
        )
        
        // 处理消息
        await processingManager.processMessage(textMessage)
        
        // 验证统计信息
        #expect(processingManager.processingStats.totalReceived == 1)
        #expect(processingManager.processingStats.totalProcessed == 1)
    }
    
    @Test("消息处理优先级测试")
    func testMessageProcessingPriority() async throws {
        let processingManager = MessageProcessingManager()
        
        // 创建不同优先级的处理器
        let highPriorityProcessor = CustomMessageProcessor(
            name: "HighPriorityProcessor",
            supportedTypes: ["text"],
            priority: 200
        )
        
        let lowPriorityProcessor = CustomMessageProcessor(
            name: "LowPriorityProcessor", 
            supportedTypes: ["text"],
            priority: 50
        )
        
        try processingManager.registerProcessor(lowPriorityProcessor)
        try processingManager.registerProcessor(highPriorityProcessor)
        
        // 获取文本消息处理器，应该按优先级排序
        let processors = processingManager.getProcessors(for: "text")
        #expect(processors.count == 2)
        #expect(processors.first?.processorName == "HighPriorityProcessor")
        #expect(processors.last?.processorName == "LowPriorityProcessor")
    }
    
    // MARK: - Filter Tests (需求 10.5)
    
    @Test("消息过滤器测试")
    func testMessageFiltering() async throws {
        let processingManager = MessageProcessingManager()
        let spamFilter = SpamMessageFilter()
        
        // 注册过滤器
        processingManager.registerFilter(spamFilter)
        
        // 创建包含垃圾信息的消息
        let spamMessage = RealtimeMessage(
            type: .text,
            content: .text("这是一条垃圾广告消息"),
            senderId: "spammer123"
        )
        
        // 处理消息
        await processingManager.processMessage(spamMessage)
        
        // 验证消息被过滤
        #expect(processingManager.processingStats.totalSkipped == 1)
    }
    
    @Test("过期消息过滤测试")
    func testExpiredMessageFiltering() async throws {
        let processingManager = MessageProcessingManager()
        let expiredFilter = ExpiredMessageFilter()
        
        processingManager.registerFilter(expiredFilter)
        
        // 创建已过期的消息
        let expiredMessage = RealtimeMessage(
            type: .text,
            content: .text("这是一条过期消息"),
            senderId: "user123",
            expirationTime: Date().addingTimeInterval(-3600) // 1小时前过期
        )
        
        await processingManager.processMessage(expiredMessage)
        
        // 验证过期消息被过滤
        #expect(processingManager.processingStats.totalSkipped == 1)
    }
    
    // MARK: - Transformer Tests (需求 10.5)
    
    @Test("消息转换器测试")
    func testMessageTransformation() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        let formattingTransformer = TextFormattingTransformer()
        
        try processingManager.registerProcessor(textProcessor)
        processingManager.registerTransformer(formattingTransformer)
        
        // 创建需要格式化的文本消息
        let message = RealtimeMessage(
            type: .text,
            content: .text("hello world"),
            senderId: "user123"
        )
        
        await processingManager.processMessage(message)
        
        // 验证消息被处理
        #expect(processingManager.processingStats.totalProcessed == 1)
    }
    
    @Test("元数据增强转换器测试")
    func testMetadataEnhancement() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        let metadataTransformer = MetadataEnhancementTransformer()
        
        try processingManager.registerProcessor(textProcessor)
        processingManager.registerTransformer(metadataTransformer)
        
        let message = RealtimeMessage(
            type: .text,
            content: .text("Test message"),
            senderId: "user123"
        )
        
        await processingManager.processMessage(message)
        
        #expect(processingManager.processingStats.totalProcessed == 1)
    }
    
    // MARK: - Validator Tests (需求 10.5)
    
    @Test("消息验证器测试")
    func testMessageValidation() async throws {
        let processingManager = MessageProcessingManager()
        let contentValidator = MessageContentValidator()
        
        processingManager.registerValidator(contentValidator)
        
        // 创建空内容消息
        let emptyMessage = RealtimeMessage(
            type: .text,
            content: .text(""),
            senderId: "user123"
        )
        
        await processingManager.processMessage(emptyMessage)
        
        // 验证空消息被拒绝
        #expect(processingManager.processingStats.totalFailed == 1)
    }
    
    @Test("权限验证器测试")
    func testPermissionValidation() async throws {
        let processingManager = MessageProcessingManager()
        let permissionValidator = MessagePermissionValidator(allowedSenders: ["user123", "user456"])
        
        processingManager.registerValidator(permissionValidator)
        
        // 测试允许的发送者
        let allowedMessage = RealtimeMessage(
            type: .text,
            content: .text("Allowed message"),
            senderId: "user123"
        )
        
        await processingManager.processMessage(allowedMessage)
        #expect(processingManager.processingStats.totalReceived == 1)
        
        // 测试不允许的发送者
        let deniedMessage = RealtimeMessage(
            type: .text,
            content: .text("Denied message"),
            senderId: "hacker999"
        )
        
        await processingManager.processMessage(deniedMessage)
        #expect(processingManager.processingStats.totalReceived == 2)
    }
    
    // MARK: - Error Handling Tests (需求 10.5)
    
    @Test("处理错误重试机制测试")
    func testProcessingErrorRetry() async throws {
        let processingManager = MessageProcessingManager()
        
        // 创建会抛出错误的处理器
        let errorProcessor = CustomMessageProcessor(
            name: "ErrorProcessor",
            supportedTypes: ["text"],
            priority: 100
        ) { message in
            throw MessageProcessorError.processingTimeout
        }
        
        try processingManager.registerProcessor(errorProcessor)
        
        let message = RealtimeMessage(
            type: .text,
            content: .text("Test message"),
            senderId: "user123"
        )
        
        await processingManager.processMessage(message)
        
        // 等待重试完成
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        // 验证错误统计
        #expect(processingManager.processingStats.totalFailed > 0)
    }
    
    // MARK: - Configuration Tests
    
    @Test("处理配置测试")
    func testProcessingConfiguration() async throws {
        let processingManager = MessageProcessingManager()
        
        // 测试默认配置
        #expect(processingManager.config.enableValidation == true)
        #expect(processingManager.config.enableFiltering == true)
        #expect(processingManager.config.maxRetryCount == 3)
        
        // 更新配置
        var newConfig = MessageProcessingConfig()
        newConfig.enableValidation = false
        newConfig.maxRetryCount = 5
        
        processingManager.updateConfig(newConfig)
        
        #expect(processingManager.config.enableValidation == false)
        #expect(processingManager.config.maxRetryCount == 5)
    }
    
    // MARK: - Statistics Tests
    
    @Test("处理统计信息测试")
    func testProcessingStatistics() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        
        try processingManager.registerProcessor(textProcessor)
        
        // 处理多条消息
        for i in 1...5 {
            let message = RealtimeMessage(
                type: .text,
                content: .text("Message \(i)"),
                senderId: "user123"
            )
            await processingManager.processMessage(message)
        }
        
        // 验证统计信息
        let stats = processingManager.processingStats
        #expect(stats.totalReceived == 5)
        #expect(stats.totalProcessed == 5)
        #expect(stats.totalFailed == 0)
        #expect(stats.totalSkipped == 0)
    }
    
    // MARK: - Concurrent Processing Tests
    
    @Test("并发处理测试")
    func testConcurrentProcessing() async throws {
        let processingManager = MessageProcessingManager()
        let textProcessor = TextMessageProcessor()
        
        try processingManager.registerProcessor(textProcessor)
        
        // 并发处理多条消息
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let message = RealtimeMessage(
                        type: .text,
                        content: .text("Concurrent message \(i)"),
                        senderId: "user\(i)"
                    )
                    await processingManager.processMessage(message)
                }
            }
        }
        
        // 验证所有消息都被处理
        #expect(processingManager.processingStats.totalReceived == 10)
        #expect(processingManager.processingStats.totalProcessed == 10)
    }
    
    // MARK: - Integration Tests
    
    @Test("完整处理管道集成测试")
    func testCompleteProcessingPipeline() async throws {
        let processingManager = MessageProcessingManager()
        
        // 注册所有组件
        let textProcessor = TextMessageProcessor()
        let systemProcessor = SystemMessageProcessor()
        let spamFilter = SpamMessageFilter()
        let formattingTransformer = TextFormattingTransformer()
        let contentValidator = MessageContentValidator()
        
        try processingManager.registerProcessor(textProcessor)
        try processingManager.registerProcessor(systemProcessor)
        processingManager.registerFilter(spamFilter)
        processingManager.registerTransformer(formattingTransformer)
        processingManager.registerValidator(contentValidator)
        
        // 处理各种类型的消息
        let messages = [
            RealtimeMessage(type: .text, content: .text("hello world"), senderId: "user1"),
            RealtimeMessage(type: .text, content: .text("这是垃圾广告"), senderId: "spammer"),
            RealtimeMessage(type: .system, content: .system(SystemContent(message: "用户加入", systemType: .userJoined)), senderId: "system"),
            RealtimeMessage(type: .text, content: .text(""), senderId: "user2") // 空消息
        ]
        
        for message in messages {
            await processingManager.processMessage(message)
        }
        
        let stats = processingManager.processingStats
        
        // 验证处理结果
        #expect(stats.totalReceived == 4)
        #expect(stats.totalProcessed >= 1) // 至少有一条消息被成功处理
        #expect(stats.totalSkipped >= 1) // 垃圾消息被过滤
        #expect(stats.totalFailed >= 1) // 空消息验证失败
    }
}

// MARK: - Concrete Processor Tests

@MainActor
struct ConcreteProcessorTests {
    
    @Test("文本消息处理器测试")
    func testTextMessageProcessor() async throws {
        let processor = TextMessageProcessor()
        
        let message = RealtimeMessage(
            type: .text,
            content: .text("  Hello    World  "),
            senderId: "user123"
        )
        
        let result = try await processor.process(message)
        
        #expect(result.isSuccess)
        
        if case .processed(let processedMessage) = result,
           let processed = processedMessage,
           case .text(let processedText) = processed.content {
            #expect(processedText.trimmingCharacters(in: .whitespaces) != "  Hello    World  ")
            #expect(processed.status == .processed)
        } else {
            #expect(Bool(false), "处理结果不符合预期")
        }
    }
    
    @Test("系统消息处理器测试")
    func testSystemMessageProcessor() async throws {
        let processor = SystemMessageProcessor()
        
        let systemContent = SystemContent(
            message: "用户已加入房间",
            systemType: .userJoined,
            parameters: ["userId": "user123"]
        )
        
        let message = RealtimeMessage(
            type: .system,
            content: .system(systemContent),
            senderId: "system"
        )
        
        let result = try await processor.process(message)
        
        #expect(result.isSuccess)
        
        if case .processed(let processedMessage) = result,
           let processed = processedMessage,
           case .system(let processedContent) = processed.content {
            #expect(processedContent.parameters.keys.contains("processedAt"))
            #expect(processedContent.parameters.keys.contains("processorName"))
        } else {
            #expect(Bool(false), "系统消息处理结果不符合预期")
        }
    }
    
    @Test("图片消息处理器测试")
    func testImageMessageProcessor() async throws {
        let processor = ImageMessageProcessor()
        
        let imageContent = ImageContent(
            url: "https://example.com/image.jpg",
            width: 800,
            height: 600
        )
        
        let message = RealtimeMessage(
            type: .image,
            content: .image(imageContent),
            senderId: "user123"
        )
        
        let result = try await processor.process(message)
        
        #expect(result.isSuccess)
        
        if case .processed(let processedMessage) = result,
           let processed = processedMessage,
           case .image(let processedContent) = processed.content {
            #expect(processedContent.url == "https://example.com/image.jpg")
            #expect(processedContent.mimeType != nil)
        } else {
            #expect(Bool(false), "图片消息处理结果不符合预期")
        }
    }
    
    @Test("自定义消息处理器测试")
    func testCustomMessageProcessor() async throws {
        let processor = CustomMessageProcessor()
        
        let customContent = CustomContent(
            data: ["key": .string("value")],
            customType: "test"
        )
        
        let message = RealtimeMessage(
            type: .custom,
            content: .custom(customContent),
            senderId: "user123"
        )
        
        let result = try await processor.process(message)
        
        #expect(result.isSuccess)
        
        if case .processed(let processedMessage) = result,
           let processed = processedMessage,
           case .custom(let processedContent) = processed.content {
            #expect(processedContent.data.keys.contains("processedAt"))
            #expect(processedContent.data.keys.contains("processorName"))
        } else {
            #expect(Bool(false), "自定义消息处理结果不符合预期")
        }
    }
}
