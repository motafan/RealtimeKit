// MessageProcessorManagerTests.swift
// Unit tests for MessageProcessorManager

import Testing
@testable import RealtimeCore

@Suite("MessageProcessorManager Tests")
@MainActor
struct MessageProcessorManagerTests {
    
    // MARK: - Test Processors
    
    @MainActor
    class TestTextProcessor: MessageProcessor {
        nonisolated let identifier = "test_text_processor"
        nonisolated let priority = 100
        var processCallCount = 0
        var shouldThrowError = false
        var shouldFilterMessage = false
        
        nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
            return message.messageType == .text
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            processCallCount += 1
            
            if shouldThrowError {
                throw TestError.processingFailed
            }
            
            if shouldFilterMessage {
                return nil
            }
            
            // Add processed metadata
            return message.withMetadata(["processed_by": identifier])
        }
    }
    
    @MainActor
    class TestSystemProcessor: MessageProcessor {
        nonisolated let identifier = "test_system_processor"
        nonisolated let priority = 50
        var processCallCount = 0
        
        nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
            return message.messageType == .system
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            processCallCount += 1
            return message.withMetadata(["system_processed": "true"])
        }
    }
    
    @MainActor
    class TestUniversalProcessor: MessageProcessor {
        nonisolated let identifier = "test_universal_processor"
        nonisolated let priority = 10
        var processCallCount = 0
        
        nonisolated func canProcess(_ message: RealtimeMessage) -> Bool {
            return true
        }
        
        func processMessage(_ message: RealtimeMessage) async throws -> RealtimeMessage? {
            processCallCount += 1
            return message.withMetadata(["universal_processed": "true"])
        }
    }
    
    enum TestError: Error {
        case processingFailed
    }
    
    // MARK: - Test Cases
    
    @Test("Manager initialization")
    func testManagerInitialization() async {
        let manager = RealtimeMessageProcessorManager()
        
        #expect(manager.getRegisteredProcessors().isEmpty)
        #expect(manager.processingQueue.isEmpty)
        #expect(manager.processingStats.totalReceived == 0)
        #expect(!manager.isProcessing)
    }
    
    @Test("Processor registration")
    func testProcessorRegistration() async {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        let systemProcessor = TestSystemProcessor()
        
        manager.registerProcessor(textProcessor)
        manager.registerProcessor(systemProcessor)
        
        let processors = manager.getRegisteredProcessors()
        #expect(processors.count == 2)
        
        // Should be sorted by priority (higher first)
        #expect(processors[0].identifier == "test_text_processor")
        #expect(processors[1].identifier == "test_system_processor")
        
        #expect(manager.isProcessorRegistered(withIdentifier: "test_text_processor"))
        #expect(manager.isProcessorRegistered(withIdentifier: "test_system_processor"))
    }
    
    @Test("Processor unregistration")
    func testProcessorUnregistration() async {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        
        manager.registerProcessor(textProcessor)
        #expect(manager.isProcessorRegistered(withIdentifier: "test_text_processor"))
        
        manager.unregisterProcessor(withIdentifier: "test_text_processor")
        #expect(!manager.isProcessorRegistered(withIdentifier: "test_text_processor"))
        #expect(manager.getRegisteredProcessors().isEmpty)
    }
    
    @Test("Message processing with single processor")
    func testMessageProcessingWithSingleProcessor() async throws {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        
        manager.registerProcessor(textProcessor)
        
        let message = RealtimeMessage.text("Hello", from: "user1")
        let processedMessage = try await manager.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.getMetadata(for: "processed_by") == "test_text_processor")
        #expect(textProcessor.processCallCount == 1)
        #expect(manager.processingStats.totalReceived == 1)
        #expect(manager.processingStats.totalProcessed == 1)
    }
    
    @Test("Message processing with multiple processors")
    func testMessageProcessingWithMultipleProcessors() async throws {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        let universalProcessor = TestUniversalProcessor()
        
        manager.registerProcessor(textProcessor)
        manager.registerProcessor(universalProcessor)
        
        let message = RealtimeMessage.text("Hello", from: "user1")
        let processedMessage = try await manager.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.getMetadata(for: "processed_by") == "test_text_processor")
        #expect(processedMessage?.getMetadata(for: "universal_processed") == "true")
        #expect(textProcessor.processCallCount == 1)
        #expect(universalProcessor.processCallCount == 1)
    }
    
    @Test("Message filtering")
    func testMessageFiltering() async throws {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        textProcessor.shouldFilterMessage = true
        
        manager.registerProcessor(textProcessor)
        
        let message = RealtimeMessage.text("Hello", from: "user1")
        let processedMessage = try await manager.processMessage(message)
        
        #expect(processedMessage == nil)
        #expect(textProcessor.processCallCount == 1)
        #expect(manager.processingStats.totalReceived == 1)
        #expect(manager.processingStats.totalSkipped == 1)
    }
    
    @Test("Processor priority ordering")
    func testProcessorPriorityOrdering() async {
        let manager = RealtimeMessageProcessorManager()
        let lowPriorityProcessor = TestUniversalProcessor() // priority 10
        let highPriorityProcessor = TestTextProcessor() // priority 100
        
        // Register in reverse priority order
        manager.registerProcessor(lowPriorityProcessor)
        manager.registerProcessor(highPriorityProcessor)
        
        let processors = manager.getRegisteredProcessors()
        #expect(processors.count == 2)
        #expect(processors[0].priority > processors[1].priority)
        #expect(processors[0].identifier == "test_text_processor")
        #expect(processors[1].identifier == "test_universal_processor")
    }
    
    @Test("Message type filtering")
    func testMessageTypeFiltering() async throws {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        let systemProcessor = TestSystemProcessor()
        
        manager.registerProcessor(textProcessor)
        manager.registerProcessor(systemProcessor)
        
        // Process text message
        let textMessage = RealtimeMessage.text("Hello", from: "user1")
        let processedTextMessage = try await manager.processMessage(textMessage)
        
        #expect(processedTextMessage?.getMetadata(for: "processed_by") == "test_text_processor")
        #expect(processedTextMessage?.getMetadata(for: "system_processed") == nil)
        #expect(textProcessor.processCallCount == 1)
        #expect(systemProcessor.processCallCount == 0)
        
        // Process system message
        let systemMessage = RealtimeMessage.system("System notification")
        let processedSystemMessage = try await manager.processMessage(systemMessage)
        
        #expect(processedSystemMessage?.getMetadata(for: "processed_by") == nil)
        #expect(processedSystemMessage?.getMetadata(for: "system_processed") == "true")
        #expect(textProcessor.processCallCount == 1)
        #expect(systemProcessor.processCallCount == 1)
    }
    
    @Test("Error handling")
    func testErrorHandling() async {
        let manager = RealtimeMessageProcessorManager(maxRetries: 0, retryDelay: 0.1) // No retries
        let textProcessor = TestTextProcessor()
        textProcessor.shouldThrowError = true
        
        manager.registerProcessor(textProcessor)
        
        let message = RealtimeMessage.text("Hello", from: "user1")
        
        do {
            _ = try await manager.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is MessageProcessingError)
            #expect(manager.processingStats.totalReceived == 1)
            #expect(manager.processingStats.totalFailed == 1)
        }
    }
    
    @Test("Retry logic")
    func testRetryLogic() async {
        let manager = RealtimeMessageProcessorManager(maxRetries: 2, retryDelay: 0.1)
        let message = RealtimeMessage.text("Hello", from: "user1")
        
        let result = await manager.processMessageWithRetry(message)
        
        switch result {
        case .processed:
            #expect(Bool(true), "Message should be processed when no processors are registered")
        case .failed, .skipped, .retry:
            #expect(Bool(false), "Unexpected result type")
        }
    }
    
    @Test("Statistics tracking")
    func testStatisticsTracking() async throws {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        let filteringProcessor = TestTextProcessor()
        filteringProcessor.shouldFilterMessage = true
        
        manager.registerProcessor(textProcessor)
        
        // Process successful message
        let message1 = RealtimeMessage.text("Hello", from: "user1")
        _ = try await manager.processMessage(message1)
        
        // Process filtered message
        manager.clearAllProcessors()
        manager.registerProcessor(filteringProcessor)
        let message2 = RealtimeMessage.text("Filtered", from: "user2")
        _ = try await manager.processMessage(message2)
        
        let stats = manager.processingStats
        #expect(stats.totalReceived == 2)
        #expect(stats.totalProcessed == 1) // One successful
        #expect(stats.totalSkipped == 1) // One filtered
    }
    
    @Test("Clear all processors")
    func testClearAllProcessors() async {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        let systemProcessor = TestSystemProcessor()
        
        manager.registerProcessor(textProcessor)
        manager.registerProcessor(systemProcessor)
        
        #expect(manager.getRegisteredProcessors().count == 2)
        
        manager.clearAllProcessors()
        
        #expect(manager.getRegisteredProcessors().isEmpty)
        #expect(!manager.isProcessorRegistered(withIdentifier: "test_text_processor"))
        #expect(!manager.isProcessorRegistered(withIdentifier: "test_system_processor"))
    }
    
    @Test("Get processor by identifier")
    func testGetProcessorByIdentifier() async {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        
        manager.registerProcessor(textProcessor)
        
        let retrievedProcessor = manager.getProcessor(withIdentifier: "test_text_processor")
        #expect(retrievedProcessor != nil)
        #expect(retrievedProcessor?.identifier == "test_text_processor")
        
        let nonExistentProcessor = manager.getProcessor(withIdentifier: "non_existent")
        #expect(nonExistentProcessor == nil)
    }
    
    @Test("Duplicate processor registration")
    func testDuplicateProcessorRegistration() async {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor1 = TestTextProcessor()
        let textProcessor2 = TestTextProcessor()
        
        manager.registerProcessor(textProcessor1)
        manager.registerProcessor(textProcessor2) // Should not replace the first one
        
        #expect(manager.getRegisteredProcessors().count == 1)
        #expect(manager.isProcessorRegistered(withIdentifier: "test_text_processor"))
    }
    
    @Test("Processing queue management")
    func testProcessingQueueManagement() async throws {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TestTextProcessor()
        
        manager.registerProcessor(textProcessor)
        
        #expect(manager.processingQueue.isEmpty)
        #expect(!manager.isProcessing)
        
        let message = RealtimeMessage.text("Hello", from: "user1")
        _ = try await manager.processMessage(message)
        
        // After processing, queue should be empty
        #expect(manager.processingQueue.isEmpty)
        #expect(!manager.isProcessing)
    }
}