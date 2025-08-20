// MessageProcessingIntegrationTests.swift
// Integration tests for the complete message processing pipeline

import Testing
@testable import RealtimeCore

@Suite("Message Processing Integration Tests")
@MainActor
struct MessageProcessingIntegrationTests {
    
    @Test("Complete message processing pipeline")
    func testCompleteMessageProcessingPipeline() async throws {
        let manager = RealtimeMessageProcessorManager()
        
        // Set up a complete processing pipeline
        let filterProcessor = MessageFilterProcessor(
            filterCriteria: MessageFilterCriteria(
                allowedMessageTypes: [.text, .system, .custom],
                contentFilters: ["spam", "advertisement"]
            )
        )
        
        let validationProcessor = MessageValidationProcessor(
            validationRules: MessageValidationRules(
                validateMessageId: true,
                validateSenderId: true,
                validateContent: true,
                validateTimestamp: true
            )
        )
        
        let textProcessor = TextMessageProcessor(
            maxContentLength: 200,
            bannedWords: ["badword"],
            enableProfanityFilter: true
        )
        
        let systemProcessor = SystemMessageProcessor(
            allowedSystemSenders: ["system", "admin"],
            enableTimestampValidation: true
        )
        
        let customProcessor = CustomMessageProcessor(
            requiredMetadataKeys: ["type"],
            metadataTransformers: ["type": { $0.uppercased() }]
        )
        
        // Register processors (they will be sorted by priority)
        manager.registerProcessor(textProcessor)      // Priority 100
        manager.registerProcessor(systemProcessor)    // Priority 90
        manager.registerProcessor(customProcessor)    // Priority 80
        manager.registerProcessor(validationProcessor) // Priority 150
        manager.registerProcessor(filterProcessor)    // Priority 200
        
        // Test text message processing
        let textMessage = RealtimeMessage.text("Hello world!", from: "user1")
        let processedTextMessage = try await manager.processMessage(textMessage)
        
        #expect(processedTextMessage != nil)
        #expect(processedTextMessage?.getMetadata(for: "filtered_by") == "message_filter_processor")
        #expect(processedTextMessage?.getMetadata(for: "validated_by") == "message_validation_processor")
        #expect(processedTextMessage?.getMetadata(for: "processed_by") == "text_message_processor")
        
        // Test system message processing
        let systemMessage = RealtimeMessage.system("User joined the room")
        let processedSystemMessage = try await manager.processMessage(systemMessage)
        
        #expect(processedSystemMessage != nil)
        #expect(processedSystemMessage?.content == "[SYSTEM] User joined the room")
        #expect(processedSystemMessage?.getMetadata(for: "system_validated") == "true")
        
        // Test custom message processing
        let customMessage = RealtimeMessage.custom(
            content: "Custom data",
            from: "user1",
            metadata: ["type": "notification"]
        )
        let processedCustomMessage = try await manager.processMessage(customMessage)
        
        #expect(processedCustomMessage != nil)
        #expect(processedCustomMessage?.getMetadata(for: "type") == "NOTIFICATION")
        #expect(processedCustomMessage?.getMetadata(for: "metadata_validated") == "true")
        
        // Verify processing statistics
        let stats = manager.processingStats
        #expect(stats.totalReceived == 3)
        #expect(stats.totalProcessed == 3)
        #expect(stats.totalFailed == 0)
    }
    
    @Test("Message filtering in pipeline")
    func testMessageFilteringInPipeline() async throws {
        let manager = RealtimeMessageProcessorManager()
        
        // Set up filter that blocks spam
        let filterProcessor = MessageFilterProcessor(
            filterCriteria: MessageFilterCriteria(
                blockedSenders: ["spammer"],
                contentFilters: ["spam"]
            )
        )
        
        let textProcessor = TextMessageProcessor()
        
        manager.registerProcessor(filterProcessor)
        manager.registerProcessor(textProcessor)
        
        // Test message that should be filtered out
        let spamMessage = RealtimeMessage.text("This is spam content", from: "user1")
        let filteredMessage = try await manager.processMessage(spamMessage)
        
        #expect(filteredMessage == nil)
        
        // Test message from blocked sender
        let blockedMessage = RealtimeMessage.text("Hello", from: "spammer")
        let blockedResult = try await manager.processMessage(blockedMessage)
        
        #expect(blockedResult == nil)
        
        // Test valid message
        let validMessage = RealtimeMessage.text("Hello world", from: "user1")
        let validResult = try await manager.processMessage(validMessage)
        
        #expect(validResult != nil)
        #expect(validResult?.getMetadata(for: "processed_by") == "text_message_processor")
        
        // Verify statistics
        let stats = manager.processingStats
        #expect(stats.totalReceived == 3)
        #expect(stats.totalProcessed == 1) // Only one message made it through
    }
    
    @Test("Error handling in pipeline")
    func testErrorHandlingInPipeline() async {
        let manager = RealtimeMessageProcessorManager(maxRetries: 0)
        
        // Set up processors with validation that will fail
        let validationProcessor = MessageValidationProcessor()
        let textProcessor = TextMessageProcessor()
        
        manager.registerProcessor(validationProcessor)
        manager.registerProcessor(textProcessor)
        
        // Test message with empty sender ID (should fail validation)
        let invalidMessage = RealtimeMessage(
            messageType: .text,
            content: "Hello",
            senderId: ""
        )
        
        do {
            _ = try await manager.processMessage(invalidMessage)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "message_validation_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
        
        // Verify statistics
        let stats = manager.processingStats
        #expect(stats.totalReceived == 1)
        #expect(stats.totalFailed == 1)
        #expect(stats.totalProcessed == 0)
    }
    
    @Test("Processor priority ordering")
    func testProcessorPriorityOrdering() async throws {
        let manager = RealtimeMessageProcessorManager()
        
        // Create processors with different priorities
        let lowPriorityProcessor = CustomMessageProcessor() // Priority 80
        let mediumPriorityProcessor = TextMessageProcessor() // Priority 100
        let highPriorityProcessor = MessageValidationProcessor() // Priority 150
        let veryHighPriorityProcessor = MessageFilterProcessor(
            filterCriteria: MessageFilterCriteria()
        ) // Priority 200
        
        // Register in random order
        manager.registerProcessor(mediumPriorityProcessor)
        manager.registerProcessor(lowPriorityProcessor)
        manager.registerProcessor(veryHighPriorityProcessor)
        manager.registerProcessor(highPriorityProcessor)
        
        let processors = manager.getRegisteredProcessors()
        
        // Should be sorted by priority (highest first)
        #expect(processors.count == 4)
        #expect(processors[0].priority == 200) // Filter processor
        #expect(processors[1].priority == 150) // Validation processor
        #expect(processors[2].priority == 100) // Text processor
        #expect(processors[3].priority == 80)  // Custom processor
    }
    
    @Test("Message transformation through pipeline")
    func testMessageTransformationThroughPipeline() async throws {
        let manager = RealtimeMessageProcessorManager()
        
        // Set up processors that transform the message
        let customProcessor = CustomMessageProcessor(
            requiredMetadataKeys: ["version"],
            metadataTransformers: [
                "version": { "v\($0)" },
                "status": { $0.uppercased() }
            ]
        )
        
        manager.registerProcessor(customProcessor)
        
        let originalMessage = RealtimeMessage.custom(
            content: "Original content",
            from: "user1",
            metadata: [
                "version": "1.0",
                "status": "active"
            ]
        )
        
        let transformedMessage = try await manager.processMessage(originalMessage)
        
        #expect(transformedMessage != nil)
        #expect(transformedMessage?.getMetadata(for: "version") == "v1.0")
        #expect(transformedMessage?.getMetadata(for: "status") == "ACTIVE")
        #expect(transformedMessage?.getMetadata(for: "processed_by") == "custom_message_processor")
        #expect(transformedMessage?.getMetadata(for: "metadata_validated") == "true")
    }
    
    @Test("Concurrent message processing")
    func testConcurrentMessageProcessing() async throws {
        let manager = RealtimeMessageProcessorManager()
        
        let textProcessor = TextMessageProcessor()
        let validationProcessor = MessageValidationProcessor()
        
        manager.registerProcessor(textProcessor)
        manager.registerProcessor(validationProcessor)
        
        // Process multiple messages concurrently
        let messages = (1...10).map { i in
            RealtimeMessage.text("Message \(i)", from: "user\(i)")
        }
        
        let results = try await withThrowingTaskGroup(of: RealtimeMessage?.self) { group in
            for message in messages {
                group.addTask {
                    return try await manager.processMessage(message)
                }
            }
            
            var processedMessages: [RealtimeMessage?] = []
            for try await result in group {
                processedMessages.append(result)
            }
            return processedMessages
        }
        
        #expect(results.count == 10)
        #expect(results.allSatisfy { $0 != nil })
        
        // Verify all messages were processed
        let stats = manager.processingStats
        #expect(stats.totalReceived == 10)
        #expect(stats.totalProcessed == 10)
        #expect(stats.totalFailed == 0)
    }
    
    @Test("Message processor callbacks")
    func testMessageProcessorCallbacks() async throws {
        let manager = RealtimeMessageProcessorManager()
        let textProcessor = TextMessageProcessor()
        
        manager.registerProcessor(textProcessor)
        
        var processedMessages: [RealtimeMessage] = []
        var completedStats: [MessageProcessingStats] = []
        
        manager.onMessageProcessed = { message in
            processedMessages.append(message)
        }
        
        manager.onProcessingCompleted = { stats in
            completedStats.append(stats)
        }
        
        let message = RealtimeMessage.text("Hello world", from: "user1")
        let result = try await manager.processMessage(message)
        
        #expect(result != nil)
        #expect(processedMessages.count == 1)
        #expect(processedMessages[0].content == "Hello world")
        #expect(completedStats.count == 1)
        #expect(completedStats[0].totalProcessed == 1)
    }
}