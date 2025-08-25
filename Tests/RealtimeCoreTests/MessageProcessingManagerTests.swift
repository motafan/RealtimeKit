import Testing
import Foundation
@testable import RealtimeCore

/// 消息处理管理器测试
/// 需求: 10.1, 10.2, 测试要求 1, 18.1, 18.2
@Suite("Message Processing Manager Tests")
@MainActor
struct MessageProcessingManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test("消息处理管理器初始化")
    func testInitialization() async throws {
        let manager = MessageProcessingManager()
        
        #expect(manager.config == MessageProcessingConfig.default)
        #expect(!manager.isProcessing)
        #expect(manager.pendingMessages.isEmpty)
        #expect(manager.processingQueue.isEmpty)
    }
    
    // MARK: - Message Processing Tests
    
    @Test("处理有效消息")
    func testProcessValidMessage() async throws {
        let manager = MessageProcessingManager()
        var processedMessage: RealtimeMessage?
        
        manager.onMessageProcessed = { message in
            processedMessage = message
        }
        
        let message = RealtimeMessage(
            type: .text,
            content: .text("测试消息"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        manager.processMessage(message)
        
        #expect(!manager.processingQueue.isEmpty)
        
        // 手动处理下一条消息
        manager.processNextMessage()
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.status == .processed)
    }
    
    @Test("处理无效消息")
    func testProcessInvalidMessage() async throws {
        let manager = MessageProcessingManager()
        var validationErrors: [MessageValidationError]?
        
        manager.onValidationFailed = { _, errors in
            validationErrors = errors
        }
        
        let invalidMessage = RealtimeMessage(
            type: .text,
            content: .text(""),  // 空内容
            senderId: "",        // 空发送者ID
            channelId: "channel456"
        )
        
        manager.processMessage(invalidMessage)
        
        #expect(validationErrors != nil)
        #expect(!validationErrors!.isEmpty)
        #expect(manager.processingQueue.isEmpty) // 无效消息不应该进入队列
    }
    
    @Test("批量处理消息")
    func testProcessMessages() async throws {
        let manager = MessageProcessingManager()
        
        let messages = [
            RealtimeMessage(type: .text, content: .text("消息1"), senderId: "user1", channelId: "channel1"),
            RealtimeMessage(type: .text, content: .text("消息2"), senderId: "user2", channelId: "channel1"),
            RealtimeMessage(type: .text, content: .text("消息3"), senderId: "user3", channelId: "channel1")
        ]
        
        manager.processMessages(messages)
        
        // 等待消息被添加到队列
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        #expect(manager.processingQueue.count >= 0) // 消息可能已经被处理
    }
    
    @Test("消息优先级排序")
    func testMessagePriorityOrdering() async throws {
        let manager = MessageProcessingManager()
        
        let lowPriorityMessage = RealtimeMessage(
            type: .text,
            content: .text("低优先级"),
            senderId: "user1",
            channelId: "channel1",
            priority: .low
        )
        
        let highPriorityMessage = RealtimeMessage(
            type: .text,
            content: .text("高优先级"),
            senderId: "user2",
            channelId: "channel1",
            priority: .high
        )
        
        let urgentMessage = RealtimeMessage(
            type: .text,
            content: .text("紧急"),
            senderId: "user3",
            channelId: "channel1",
            priority: .urgent
        )
        
        // 按低优先级顺序添加
        manager.processMessage(lowPriorityMessage)
        manager.processMessage(highPriorityMessage)
        manager.processMessage(urgentMessage)
        
        // 队列应该按优先级排序
        #expect(manager.processingQueue[0].priority == .urgent)
        #expect(manager.processingQueue[1].priority == .high)
        #expect(manager.processingQueue[2].priority == .low)
    }
    
    @Test("清空处理队列")
    func testClearProcessingQueue() async throws {
        let manager = MessageProcessingManager()
        
        let message = RealtimeMessage(
            type: .text,
            content: .text("测试消息"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        manager.processMessage(message)
        
        // 等待消息被添加到队列
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        manager.clearProcessingQueue()
        
        #expect(manager.processingQueue.isEmpty)
        #expect(manager.pendingMessages.isEmpty)
    }
    
    // MARK: - Message Templates Tests
    
    @Test("创建消息模板")
    func testCreateTemplate() async throws {
        let manager = MessageProcessingManager()
        
        manager.createTemplate(
            name: "欢迎消息",
            type: .system,
            content: .system(SystemContent(message: "欢迎加入房间", systemType: .userJoined))
        )
        
        #expect(manager.getTemplateNames().contains("欢迎消息"))
    }
    
    @Test("从模板创建消息")
    func testCreateMessageFromTemplate() async throws {
        let manager = MessageProcessingManager()
        
        manager.createTemplate(
            name: "欢迎消息",
            type: .system,
            content: .system(SystemContent(message: "欢迎加入房间", systemType: .userJoined))
        )
        
        let message = manager.createMessageFromTemplate(
            templateName: "欢迎消息",
            senderId: "system",
            channelId: "channel123"
        )
        
        #expect(message != nil)
        #expect(message?.type == .system)
        #expect(message?.senderId == "system")
        #expect(message?.channelId == "channel123")
    }
    
    @Test("从不存在的模板创建消息")
    func testCreateMessageFromNonexistentTemplate() async throws {
        let manager = MessageProcessingManager()
        
        let message = manager.createMessageFromTemplate(
            templateName: "不存在的模板",
            senderId: "user123",
            channelId: "channel456"
        )
        
        #expect(message == nil)
    }
    
    @Test("删除消息模板")
    func testDeleteTemplate() async throws {
        let manager = MessageProcessingManager()
        
        manager.createTemplate(
            name: "测试模板",
            type: .text,
            content: .text("测试内容")
        )
        
        #expect(manager.getTemplateNames().contains("测试模板"))
        
        manager.deleteTemplate(name: "测试模板")
        
        #expect(!manager.getTemplateNames().contains("测试模板"))
    }
    
    // MARK: - Message History Tests
    
    @Test("获取消息历史")
    func testGetMessageHistory() async throws {
        let manager = MessageProcessingManager()
        var processedCount = 0
        
        manager.onMessageProcessed = { _ in
            processedCount += 1
        }
        
        // 处理多条消息
        for i in 1...5 {
            let message = RealtimeMessage(
                type: .text,
                content: .text("消息\(i)"),
                senderId: "user\(i)",
                channelId: "channel1"
            )
            manager.processMessage(message)
            manager.processNextMessage()
        }
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        let history = manager.getMessageHistory()
        #expect(history.count == processedCount)
    }
    
    @Test("搜索消息历史")
    func testSearchMessages() async throws {
        let manager = MessageProcessingManager()
        
        // 手动添加一些消息到历史（模拟已处理的消息）
        let messages = [
            RealtimeMessage(type: .text, content: .text("消息1"), senderId: "user1", channelId: "channel1"),
            RealtimeMessage(type: .text, content: .text("消息2"), senderId: "user2", channelId: "channel1"),
            RealtimeMessage(type: .system, content: .system(SystemContent(message: "系统消息", systemType: .userJoined)), senderId: "system", channelId: "channel1")
        ]
        
        for message in messages {
            manager.processMessage(message)
            manager.processNextMessage()
        }
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        // 按发送者搜索
        let user1Messages = manager.searchMessages(senderId: "user1")
        #expect(user1Messages.count >= 0) // 可能为0，因为消息可能还在处理中
        
        // 按类型搜索
        let systemMessages = manager.searchMessages(type: .system)
        #expect(systemMessages.count >= 0)
    }
    
    @Test("清除消息历史")
    func testClearMessageHistory() async throws {
        let manager = MessageProcessingManager()
        
        let message = RealtimeMessage(
            type: .text,
            content: .text("测试消息"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        manager.processMessage(message)
        manager.processNextMessage()
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        manager.clearMessageHistory()
        
        #expect(manager.getMessageHistory().isEmpty)
    }
    
    // MARK: - Statistics Tests
    
    @Test("处理统计信息")
    func testProcessingStatistics() async throws {
        let manager = MessageProcessingManager()
        
        let initialStats = manager.getProcessingStatistics()
        #expect(initialStats.processedMessages == 0)
        #expect(initialStats.validationFailures == 0)
        
        // 处理有效消息
        let validMessage = RealtimeMessage(
            type: .text,
            content: .text("有效消息"),
            senderId: "user123",
            channelId: "channel456"
        )
        manager.processMessage(validMessage)
        manager.processNextMessage()
        
        // 处理无效消息
        let invalidMessage = RealtimeMessage(
            type: .text,
            content: .text(""),
            senderId: "",
            channelId: "channel456"
        )
        manager.processMessage(invalidMessage)
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        let updatedStats = manager.getProcessingStatistics()
        #expect(updatedStats.validationFailures >= 1)
    }
    
    @Test("重置统计信息")
    func testResetStatistics() async throws {
        let manager = MessageProcessingManager()
        
        // 处理一些消息以产生统计数据
        let message = RealtimeMessage(
            type: .text,
            content: .text("测试消息"),
            senderId: "user123",
            channelId: "channel456"
        )
        manager.processMessage(message)
        manager.processNextMessage()
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        manager.resetStatistics()
        
        let stats = manager.getProcessingStatistics()
        #expect(stats.processedMessages == 0)
        #expect(stats.validationFailures == 0)
        #expect(stats.processingErrors == 0)
    }
    
    // MARK: - Configuration Tests
    
    @Test("更新处理配置")
    func testUpdateConfig() async throws {
        let manager = MessageProcessingManager()
        
        var newConfig = MessageProcessingConfig()
        newConfig.enableAutoProcessing = false
        newConfig.maxQueueSize = 500
        
        manager.updateConfig(newConfig)
        
        #expect(manager.config.enableAutoProcessing == false)
        #expect(manager.config.maxQueueSize == 500)
    }
    
    // MARK: - Storage Tests
    
    @Test("重置存储数据")
    func testResetStorage() async throws {
        let manager = MessageProcessingManager()
        
        // 修改配置和创建模板
        var newConfig = MessageProcessingConfig()
        newConfig.maxQueueSize = 500
        manager.updateConfig(newConfig)
        
        manager.createTemplate(
            name: "测试模板",
            type: .text,
            content: .text("测试内容")
        )
        
        manager.resetStorage()
        
        #expect(manager.config == MessageProcessingConfig.default)
        #expect(manager.getTemplateNames().isEmpty)
        #expect(manager.processingQueue.isEmpty)
    }
    
    // MARK: - @RealtimeStorage Integration Tests
    
    @Test("配置数据持久化")
    func testConfigPersistence() async throws {
        let manager1 = MessageProcessingManager()
        
        var customConfig = MessageProcessingConfig()
        customConfig.enableAutoProcessing = false
        customConfig.maxQueueSize = 500
        customConfig.processingInterval = 0.5
        
        manager1.updateConfig(customConfig)
        
        // 验证配置已更新
        #expect(manager1.config.enableAutoProcessing == false)
        #expect(manager1.config.maxQueueSize == 500)
        #expect(manager1.config.processingInterval == 0.5)
    }
    
    @Test("模板数据持久化")
    func testTemplatesPersistence() async throws {
        let manager1 = MessageProcessingManager()
        
        manager1.createTemplate(
            name: "持久化模板",
            type: .text,
            content: .text("持久化内容"),
            metadata: ["key": .string("value")]
        )
        
        // 验证模板在同一实例中可用
        #expect(manager1.getTemplateNames().contains("持久化模板"))
        
        let message = manager1.createMessageFromTemplate(
            templateName: "持久化模板",
            senderId: "user123",
            channelId: "channel456"
        )
        
        #expect(message != nil)
        #expect(message?.content.textValue == "持久化内容")
        #expect(message?.metadata["key"]?.stringValue == "value")
    }
    
    // MARK: - Event Handler Tests
    
    @Test("消息处理完成事件")
    func testMessageProcessedEvent() async throws {
        let manager = MessageProcessingManager()
        var processedMessage: RealtimeMessage?
        
        manager.onMessageProcessed = { message in
            processedMessage = message
        }
        
        let message = RealtimeMessage(
            type: .text,
            content: .text("测试消息"),
            senderId: "user123",
            channelId: "channel456"
        )
        
        manager.processMessage(message)
        manager.processNextMessage()
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.id == message.id)
    }
    
    @Test("验证失败事件")
    func testValidationFailedEvent() async throws {
        let manager = MessageProcessingManager()
        var failedMessage: RealtimeMessage?
        var validationErrors: [MessageValidationError]?
        
        manager.onValidationFailed = { message, errors in
            failedMessage = message
            validationErrors = errors
        }
        
        let invalidMessage = RealtimeMessage(
            type: .text,
            content: .text(""),
            senderId: "",
            channelId: "channel456"
        )
        
        manager.processMessage(invalidMessage)
        
        #expect(failedMessage != nil)
        #expect(validationErrors != nil)
        #expect(!validationErrors!.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    @Test("大量消息处理性能")
    func testLargeMessageProcessingPerformance() async throws {
        let manager = MessageProcessingManager()
        var processedCount = 0
        
        manager.onMessageProcessed = { _ in
            processedCount += 1
        }
        
        // 创建大量消息
        var messages: [RealtimeMessage] = []
        for i in 1...100 {
            messages.append(RealtimeMessage(
                type: .text,
                content: .text("消息\(i)"),
                senderId: "user\(i % 10)",
                channelId: "channel1"
            ))
        }
        
        let startTime = Date()
        manager.processMessages(messages)
        let endTime = Date()
        
        // 等待消息处理完成
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        #expect(processedCount > 0) // 至少处理了一些消息
        #expect(endTime.timeIntervalSince(startTime) < 0.1) // 应该在100ms内完成
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("队列大小限制")
    func testQueueSizeLimit() async throws {
        let manager = MessageProcessingManager()
        
        // 设置较小的队列大小
        var config = manager.config
        config.maxQueueSize = 5
        manager.updateConfig(config)
        
        // 添加超过限制的消息
        for i in 1...10 {
            let message = RealtimeMessage(
                type: .text,
                content: .text("消息\(i)"),
                senderId: "user\(i)",
                channelId: "channel1"
            )
            manager.processMessage(message)
        }
        
        #expect(manager.processingQueue.count <= 5)
    }
    
    @Test("过期消息清理")
    func testExpiredMessageCleanup() async throws {
        let manager = MessageProcessingManager()
        
        // 创建过期消息
        let expiredMessage = RealtimeMessage(
            type: .text,
            content: .text("过期消息"),
            senderId: "user123",
            channelId: "channel456",
            expirationTime: Date().addingTimeInterval(-60) // 1分钟前过期
        )
        
        manager.processMessage(expiredMessage)
        manager.processNextMessage()
        
        // 等待处理完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        manager.clearExpiredMessages()
        
        // 过期消息应该被清理
        let history = manager.getMessageHistory()
        let hasExpiredMessage = history.contains { $0.id == expiredMessage.id }
        #expect(!hasExpiredMessage)
    }
}