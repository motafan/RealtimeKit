// MessageProcessorManagerTests.swift
// Comprehensive unit tests for MessageProcessorManager

import Testing
import Foundation
@testable import RealtimeCore

@Suite("MessageProcessorManager Tests")
@MainActor
struct MessageProcessorManagerTests {
    
    // MARK: - Test Message Processors
    
    class TestTextMessageProcessor: MessageProcessor {
        let identifier = "test_text_processor"
        let priority = 100
        var processedMessages: [RealtimeMessage] = []
        var shouldFail = false
        var processingDelay: TimeInterval = 0
        
        func canProcess(_ message: RealtimeMessage) -> Bool {
            return message.type == .text
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            if processingDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
            }
            
            if shouldFail {
                throw RealtimeError.processingFailed("Test processor failure")
            }
            
            processedMessages.append(message)
            
            // Add processing metadata
            return message.withMetadata([
                "processed_by": identifier,
                "processed_at": Date().timeIntervalSince1970
            ])
        }
    }
    
    class TestSystemMessageProcessor: MessageProcessor {
        let identifier = "test_system_processor"
        let priority = 50
        var processedMessages: [RealtimeMessage] = []
        
        func canProcess(_ message: RealtimeMessage) -> Bool {
            return message.type == .system
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            processedMessages.append(message)
            return message.withMetadata(["system_processed": true])
        }
    }
    
    class TestFilterProcessor: MessageProcessor {
        let identifier = "test_filter_processor"
        let priority = 200
        let blockedUserIds: Set<String>
        
        init(blockedUserIds: Set<String> = []) {
            self.blockedUserIds = blockedUserIds
        }
        
        func canProcess(_ message: RealtimeMessage) -> Bool {
            return true // Process all messages
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            // Filter out messages from blocked users
            if blockedUserIds.contains(message.senderId) {
                return nil // Block the message
            }
            
            return message.withMetadata(["filter_checked": true])
        }
    }
    
    // MARK: - Test Setup
    
    private func createManager() -> MessageProcessorManager {
        return MessageProcessorManager()
    }
    
    private func createTextMessage(content: String = "Hello", from userId: String = "user1") -> RealtimeMessage {
        return RealtimeMessage.text(content, from: userId)
    }
    
    private func createSystemMessage(data: [String: Any] = ["action": "test"]) -> RealtimeMessage {
        return RealtimeMessage.system(data)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Manager initialization")
    func testManagerInitialization() {
        let manager = createManager()
        
        #expect(manager.registeredProcessors.isEmpty)
        #expect(manager.processingQueue.isEmpty)
        #expect(manager.processingStats.totalReceived == 0)
        #expect(manager.processingStats.totalProcessed == 0)
        #expect(manager.processingStats.totalFailed == 0)
        #expect(manager.isProcessing == false)
    }
    
    // MARK: - Processor Registration Tests
    
    @Test("Register single processor")
    func testRegisterSingleProcessor() throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        #expect(manager.registeredProcessors.count == 1)
        #expect(manager.registeredProcessors.contains(where: { $0.identifier == processor.identifier }))
    }
    
    @Test("Register multiple processors")
    func testRegisterMultipleProcessors() throws {
        let manager = createManager()
        let textProcessor = TestTextMessageProcessor()
        let systemProcessor = TestSystemMessageProcessor()
        
        try manager.registerProcessor(textProcessor)
        try manager.registerProcessor(systemProcessor)
        
        #expect(manager.registeredProcessors.count == 2)
        #expect(manager.registeredProcessors.contains(where: { $0.identifier == textProcessor.identifier }))
        #expect(manager.registeredProcessors.contains(where: { $0.identifier == systemProcessor.identifier }))
    }
    
    @Test("Register duplicate processor")
    func testRegisterDuplicateProcessor() throws {
        let manager = createManager()
        let processor1 = TestTextMessageProcessor()
        let processor2 = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor1)
        
        #expect(throws: RealtimeError.self) {
            try manager.registerProcessor(processor2)
        }
    }
    
    @Test("Unregister processor")
    func testUnregisterProcessor() throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        #expect(manager.registeredProcessors.count == 1)
        
        manager.unregisterProcessor(identifier: processor.identifier)
        #expect(manager.registeredProcessors.isEmpty)
    }
    
    @Test("Unregister non-existent processor")
    func testUnregisterNonExistentProcessor() {
        let manager = createManager()
        
        // Should not throw or crash
        manager.unregisterProcessor(identifier: "non_existent")
        
        #expect(manager.registeredProcessors.isEmpty)
    }
    
    // MARK: - Message Processing Tests
    
    @Test("Process single message")
    func testProcessSingleMessage() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        let message = createTextMessage(content: "Test message")
        await manager.processMessage(message)
        
        #expect(processor.processedMessages.count == 1)
        #expect(processor.processedMessages.first?.content.textContent == "Test message")
        #expect(manager.processingStats.totalReceived == 1)
        #expect(manager.processingStats.totalProcessed == 1)
    }
    
    @Test("Process message with no matching processor")
    func testProcessMessageWithNoMatchingProcessor() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        // Send system message to text processor
        let systemMessage = createSystemMessage()
        await manager.processMessage(systemMessage)
        
        #expect(processor.processedMessages.isEmpty)
        #expect(manager.processingStats.totalReceived == 1)
        #expect(manager.processingStats.totalSkipped == 1)
    }
    
    @Test("Process message with multiple processors")
    func testProcessMessageWithMultipleProcessors() async throws {
        let manager = createManager()
        let textProcessor = TestTextMessageProcessor()
        let filterProcessor = TestFilterProcessor()
        
        try manager.registerProcessor(filterProcessor) // Higher priority
        try manager.registerProcessor(textProcessor)
        
        let message = createTextMessage(content: "Test message")
        await manager.processMessage(message)
        
        // Both processors should process the message
        #expect(textProcessor.processedMessages.count == 1)
        #expect(manager.processingStats.totalProcessed == 1)
        
        // Check that filter processor ran first (higher priority)
        let processedMessage = textProcessor.processedMessages.first
        #expect(processedMessage?.metadata["filter_checked"] as? Bool == true)
    }
    
    @Test("Process message with processor priority ordering")
    func testProcessMessageWithProcessorPriorityOrdering() async throws {
        let manager = createManager()
        
        // Create processors with different priorities
        let lowPriorityProcessor = TestTextMessageProcessor()
        lowPriorityProcessor.priority = 10
        
        let highPriorityProcessor = TestFilterProcessor()
        // highPriorityProcessor.priority = 200 (default)
        
        try manager.registerProcessor(lowPriorityProcessor)
        try manager.registerProcessor(highPriorityProcessor)
        
        let message = createTextMessage()
        await manager.processMessage(message)
        
        // High priority processor should run first
        let processedMessage = lowPriorityProcessor.processedMessages.first
        #expect(processedMessage?.metadata["filter_checked"] as? Bool == true)
    }
    
    // MARK: - Message Filtering Tests
    
    @Test("Filter blocked messages")
    func testFilterBlockedMessages() async throws {
        let manager = createManager()
        let filterProcessor = TestFilterProcessor(blockedUserIds: ["blocked_user"])
        let textProcessor = TestTextMessageProcessor()
        
        try manager.registerProcessor(filterProcessor)
        try manager.registerProcessor(textProcessor)
        
        // Send message from blocked user
        let blockedMessage = createTextMessage(content: "Blocked message", from: "blocked_user")
        await manager.processMessage(blockedMessage)
        
        // Message should be filtered out
        #expect(textProcessor.processedMessages.isEmpty)
        #expect(manager.processingStats.totalFiltered == 1)
        
        // Send message from allowed user
        let allowedMessage = createTextMessage(content: "Allowed message", from: "allowed_user")
        await manager.processMessage(allowedMessage)
        
        // Message should be processed
        #expect(textProcessor.processedMessages.count == 1)
        #expect(manager.processingStats.totalProcessed == 1)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle processor failure")
    func testHandleProcessorFailure() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        processor.shouldFail = true
        
        try manager.registerProcessor(processor)
        
        var errorReceived: Error?
        manager.onProcessingError = { error in
            errorReceived = error
        }
        
        let message = createTextMessage()
        await manager.processMessage(message)
        
        #expect(errorReceived != nil)
        #expect(manager.processingStats.totalFailed == 1)
    }
    
    @Test("Continue processing after processor failure")
    func testContinueProcessingAfterProcessorFailure() async throws {
        let manager = createManager()
        let failingProcessor = TestTextMessageProcessor()
        failingProcessor.shouldFail = true
        failingProcessor.priority = 100
        
        let workingProcessor = TestTextMessageProcessor()
        workingProcessor.priority = 50
        
        try manager.registerProcessor(failingProcessor)
        try manager.registerProcessor(workingProcessor)
        
        let message = createTextMessage()
        await manager.processMessage(message)
        
        // Working processor should still process the message
        #expect(workingProcessor.processedMessages.count == 1)
        #expect(manager.processingStats.totalFailed == 1)
        #expect(manager.processingStats.totalProcessed == 1)
    }
    
    @Test("Retry failed processing")
    func testRetryFailedProcessing() async throws {
        let manager = createManager()
        manager.enableRetry(maxAttempts: 3, retryDelay: 0.05)
        
        let processor = TestTextMessageProcessor()
        var attemptCount = 0
        
        // Processor that fails first two times, then succeeds
        processor.processMessage = { message in
            attemptCount += 1
            if attemptCount < 3 {
                throw RealtimeError.processingFailed("Temporary failure")
            }
            processor.processedMessages.append(message)
            return message
        }
        
        try manager.registerProcessor(processor)
        
        let message = createTextMessage()
        await manager.processMessage(message)
        
        // Wait for retries
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(attemptCount == 3)
        #expect(processor.processedMessages.count == 1)
        #expect(manager.processingStats.totalProcessed == 1)
    }
    
    // MARK: - Concurrent Processing Tests
    
    @Test("Concurrent message processing")
    func testConcurrentMessageProcessing() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        processor.processingDelay = 0.05 // 50ms delay
        
        try manager.registerProcessor(processor)
        
        // Process multiple messages concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let message = createTextMessage(content: "Message \(i)")
                    await manager.processMessage(message)
                }
            }
        }
        
        #expect(processor.processedMessages.count == 10)
        #expect(manager.processingStats.totalProcessed == 10)
    }
    
    @Test("Processing queue management")
    func testProcessingQueueManagement() async throws {
        let manager = createManager()
        manager.setMaxQueueSize(5)
        
        let processor = TestTextMessageProcessor()
        processor.processingDelay = 0.1 // 100ms delay
        
        try manager.registerProcessor(processor)
        
        // Add more messages than queue capacity
        for i in 1...10 {
            let message = createTextMessage(content: "Message \(i)")
            await manager.processMessage(message)
        }
        
        // Queue should be limited to max size
        #expect(manager.processingQueue.count <= 5)
        #expect(manager.processingStats.totalDropped > 0)
    }
    
    // MARK: - Performance Tests
    
    @Test("Processing performance")
    func testProcessingPerformance() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        let startTime = Date()
        
        // Process many messages
        for i in 1...1000 {
            let message = createTextMessage(content: "Message \(i)")
            await manager.processMessage(message)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(duration < 2.0) // Should complete within 2 seconds
        #expect(processor.processedMessages.count == 1000)
        #expect(manager.processingStats.totalProcessed == 1000)
    }
    
    @Test("Memory usage during processing")
    func testMemoryUsageDuringProcessing() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        // Process many messages and verify memory doesn't grow unbounded
        for i in 1...10000 {
            let message = createTextMessage(content: "Message \(i)")
            await manager.processMessage(message)
            
            // Periodically check queue size
            if i % 1000 == 0 {
                #expect(manager.processingQueue.count < 100) // Should not accumulate
            }
        }
        
        #expect(processor.processedMessages.count == 10000)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Processing statistics tracking")
    func testProcessingStatisticsTracking() async throws {
        let manager = createManager()
        let textProcessor = TestTextMessageProcessor()
        let filterProcessor = TestFilterProcessor(blockedUserIds: ["blocked"])
        
        try manager.registerProcessor(filterProcessor)
        try manager.registerProcessor(textProcessor)
        
        // Process various types of messages
        await manager.processMessage(createTextMessage(content: "Normal message"))
        await manager.processMessage(createTextMessage(content: "Blocked message", from: "blocked"))
        await manager.processMessage(createSystemMessage()) // No processor
        
        let stats = manager.processingStats
        #expect(stats.totalReceived == 3)
        #expect(stats.totalProcessed == 1) // Only normal message
        #expect(stats.totalFiltered == 1)  // Blocked message
        #expect(stats.totalSkipped == 1)   // System message
    }
    
    @Test("Processing rate calculation")
    func testProcessingRateCalculation() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        let startTime = Date()
        
        // Process messages over time
        for i in 1...50 {
            let message = createTextMessage(content: "Message \(i)")
            await manager.processMessage(message)
            
            if i % 10 == 0 {
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms pause
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let rate = manager.processingStats.processingRate
        
        #expect(rate > 0)
        #expect(rate < 1000) // Reasonable rate
    }
    
    // MARK: - Configuration Tests
    
    @Test("Manager configuration")
    func testManagerConfiguration() throws {
        let manager = createManager()
        
        let config = MessageProcessorConfig(
            maxQueueSize: 1000,
            enableRetry: true,
            maxRetryAttempts: 5,
            retryDelay: 0.1,
            enableStatistics: true,
            processingTimeout: 30.0
        )
        
        manager.configure(with: config)
        
        #expect(manager.configuration.maxQueueSize == 1000)
        #expect(manager.configuration.enableRetry == true)
        #expect(manager.configuration.maxRetryAttempts == 5)
        #expect(manager.configuration.retryDelay == 0.1)
        #expect(manager.configuration.enableStatistics == true)
        #expect(manager.configuration.processingTimeout == 30.0)
    }
    
    // MARK: - Lifecycle Tests
    
    @Test("Manager start and stop")
    func testManagerStartAndStop() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        
        try manager.registerProcessor(processor)
        
        #expect(manager.isProcessing == false)
        
        manager.start()
        #expect(manager.isProcessing == true)
        
        // Process a message while running
        let message = createTextMessage()
        await manager.processMessage(message)
        
        #expect(processor.processedMessages.count == 1)
        
        manager.stop()
        #expect(manager.isProcessing == false)
        
        // Messages should not be processed when stopped
        await manager.processMessage(createTextMessage())
        #expect(processor.processedMessages.count == 1) // Still 1
    }
    
    @Test("Graceful shutdown")
    func testGracefulShutdown() async throws {
        let manager = createManager()
        let processor = TestTextMessageProcessor()
        processor.processingDelay = 0.1 // 100ms delay
        
        try manager.registerProcessor(processor)
        manager.start()
        
        // Start processing messages
        for i in 1...5 {
            let message = createTextMessage(content: "Message \(i)")
            await manager.processMessage(message)
        }
        
        // Initiate graceful shutdown
        await manager.gracefulShutdown(timeout: 1.0)
        
        #expect(manager.isProcessing == false)
        #expect(processor.processedMessages.count == 5)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Manager cleanup on deallocation")
    func testManagerCleanupOnDeallocation() async throws {
        var manager: MessageProcessorManager? = createManager()
        
        weak var weakManager = manager
        
        let processor = TestTextMessageProcessor()
        try manager?.registerProcessor(processor)
        
        manager = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakManager == nil)
    }
    
    // MARK: - Integration Tests
    
    @Test("End-to-end message processing pipeline")
    func testEndToEndMessageProcessingPipeline() async throws {
        let manager = createManager()
        
        // Set up processing pipeline
        let filterProcessor = TestFilterProcessor(blockedUserIds: ["spammer"])
        let textProcessor = TestTextMessageProcessor()
        let systemProcessor = TestSystemMessageProcessor()
        
        try manager.registerProcessor(filterProcessor)
        try manager.registerProcessor(textProcessor)
        try manager.registerProcessor(systemProcessor)
        
        manager.start()
        
        var processedMessages: [RealtimeMessage] = []
        manager.onMessageProcessed = { message in
            processedMessages.append(message)
        }
        
        // Process various messages
        await manager.processMessage(createTextMessage(content: "Hello world", from: "user1"))
        await manager.processMessage(createTextMessage(content: "Spam message", from: "spammer"))
        await manager.processMessage(createSystemMessage(data: ["action": "user_joined", "userId": "user2"]))
        await manager.processMessage(createTextMessage(content: "Another message", from: "user3"))
        
        // Wait for processing to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify results
        #expect(textProcessor.processedMessages.count == 2) // 2 text messages (spam filtered)
        #expect(systemProcessor.processedMessages.count == 1) // 1 system message
        #expect(processedMessages.count == 3) // 3 total processed (spam filtered out)
        
        let stats = manager.processingStats
        #expect(stats.totalReceived == 4)
        #expect(stats.totalProcessed == 3)
        #expect(stats.totalFiltered == 1)
        
        manager.stop()
    }
}