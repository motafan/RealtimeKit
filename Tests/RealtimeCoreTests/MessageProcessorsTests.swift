// MessageProcessorsTests.swift
// Unit tests for concrete message processors

import Testing
@testable import RealtimeCore

@Suite("Message Processors Tests")
@MainActor
struct MessageProcessorsTests {
    
    // MARK: - Text Message Processor Tests
    
    @Test("Text processor initialization")
    func testTextProcessorInitialization() async {
        let processor = TextMessageProcessor(
            maxContentLength: 500,
            bannedWords: ["spam", "bad"],
            enableProfanityFilter: true
        )
        
        #expect(processor.identifier == "text_message_processor")
        #expect(processor.priority == 100)
    }
    
    @Test("Text processor can process text messages")
    func testTextProcessorCanProcessTextMessages() async {
        let processor = TextMessageProcessor()
        
        let textMessage = RealtimeMessage.text("Hello", from: "user1")
        let systemMessage = RealtimeMessage.system("System notification")
        
        #expect(processor.canProcess(textMessage))
        #expect(!processor.canProcess(systemMessage))
    }
    
    @Test("Text processor processes valid text message")
    func testTextProcessorProcessesValidTextMessage() async throws {
        let processor = TextMessageProcessor(maxContentLength: 100)
        let message = RealtimeMessage.text("Hello world!", from: "user1")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.content == "Hello world!")
        #expect(processedMessage?.getMetadata(for: "processed_by") == "text_message_processor")
        #expect(processedMessage?.getMetadata(for: "content_length") == "12")
    }
    
    @Test("Text processor rejects content that is too long")
    func testTextProcessorRejectsLongContent() async {
        let processor = TextMessageProcessor(maxContentLength: 10)
        let message = RealtimeMessage.text("This message is too long", from: "user1")
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "text_message_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Text processor detects banned words")
    func testTextProcessorDetectsBannedWords() async {
        let processor = TextMessageProcessor(bannedWords: ["spam", "bad"])
        let message = RealtimeMessage.text("This is spam content", from: "user1")
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "text_message_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Text processor applies profanity filter")
    func testTextProcessorAppliesProfanityFilter() async throws {
        let processor = TextMessageProcessor(enableProfanityFilter: true)
        let message = RealtimeMessage.text("This contains badword1", from: "user1")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.content.contains("*") == true)
        #expect(processedMessage?.getMetadata(for: "profanity_filtered") == "true")
    }
    
    // MARK: - System Message Processor Tests
    
    @Test("System processor initialization")
    func testSystemProcessorInitialization() async {
        let processor = SystemMessageProcessor(
            allowedSystemSenders: ["system", "admin"],
            enableTimestampValidation: false
        )
        
        #expect(processor.identifier == "system_message_processor")
        #expect(processor.priority == 90)
    }
    
    @Test("System processor can process system messages")
    func testSystemProcessorCanProcessSystemMessages() async {
        let processor = SystemMessageProcessor()
        
        let textMessage = RealtimeMessage.text("Hello", from: "user1")
        let systemMessage = RealtimeMessage.system("System notification")
        
        #expect(!processor.canProcess(textMessage))
        #expect(processor.canProcess(systemMessage))
    }
    
    @Test("System processor processes valid system message")
    func testSystemProcessorProcessesValidSystemMessage() async throws {
        let processor = SystemMessageProcessor()
        let message = RealtimeMessage.system("User joined the room")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.content == "[SYSTEM] User joined the room")
        #expect(processedMessage?.getMetadata(for: "processed_by") == "system_message_processor")
        #expect(processedMessage?.getMetadata(for: "system_validated") == "true")
    }
    
    @Test("System processor rejects unauthorized sender")
    func testSystemProcessorRejectsUnauthorizedSender() async {
        let processor = SystemMessageProcessor(allowedSystemSenders: ["system"])
        let message = RealtimeMessage(
            messageType: .system,
            content: "Unauthorized message",
            senderId: "hacker"
        )
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "system_message_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("System processor validates timestamp")
    func testSystemProcessorValidatesTimestamp() async {
        let processor = SystemMessageProcessor(enableTimestampValidation: true)
        let oldTimestamp = Date().addingTimeInterval(-7200) // 2 hours ago
        let message = RealtimeMessage(
            messageType: .system,
            content: "Old message",
            senderId: "system",
            timestamp: oldTimestamp
        )
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "system_message_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Custom Message Processor Tests
    
    @Test("Custom processor initialization")
    func testCustomProcessorInitialization() async {
        let transformers: [String: (String) -> String] = ["key1": { $0.uppercased() }]
        let processor = CustomMessageProcessor(
            requiredMetadataKeys: ["type", "version"],
            metadataTransformers: transformers
        )
        
        #expect(processor.identifier == "custom_message_processor")
        #expect(processor.priority == 80)
    }
    
    @Test("Custom processor can process custom messages")
    func testCustomProcessorCanProcessCustomMessages() async {
        let processor = CustomMessageProcessor()
        
        let textMessage = RealtimeMessage.text("Hello", from: "user1")
        let customMessage = RealtimeMessage.custom(
            content: "Custom data",
            from: "user1",
            metadata: ["type": "data"]
        )
        
        #expect(!processor.canProcess(textMessage))
        #expect(processor.canProcess(customMessage))
    }
    
    @Test("Custom processor processes valid custom message")
    func testCustomProcessorProcessesValidCustomMessage() async throws {
        let transformers: [String: (String) -> String] = ["type": { $0.uppercased() }]
        let processor = CustomMessageProcessor(
            requiredMetadataKeys: ["type"],
            metadataTransformers: transformers
        )
        
        let message = RealtimeMessage.custom(
            content: "Custom data",
            from: "user1",
            metadata: ["type": "data", "version": "1.0"]
        )
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.getMetadata(for: "type") == "DATA")
        #expect(processedMessage?.getMetadata(for: "processed_by") == "custom_message_processor")
        #expect(processedMessage?.getMetadata(for: "metadata_validated") == "true")
    }
    
    @Test("Custom processor rejects missing required metadata")
    func testCustomProcessorRejectsMissingRequiredMetadata() async {
        let processor = CustomMessageProcessor(requiredMetadataKeys: ["type", "version"])
        let message = RealtimeMessage.custom(
            content: "Custom data",
            from: "user1",
            metadata: ["type": "data"] // Missing "version"
        )
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "custom_message_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    // MARK: - Message Filter Processor Tests
    
    @Test("Filter processor initialization")
    func testFilterProcessorInitialization() async {
        let criteria = MessageFilterCriteria(
            blockedSenders: ["spammer"],
            allowedChannels: ["general"],
            allowedMessageTypes: [.text, .system]
        )
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        
        #expect(processor.identifier == "message_filter_processor")
        #expect(processor.priority == 200)
    }
    
    @Test("Filter processor can process all message types")
    func testFilterProcessorCanProcessAllMessageTypes() async {
        let criteria = MessageFilterCriteria()
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        
        let textMessage = RealtimeMessage.text("Hello", from: "user1")
        let systemMessage = RealtimeMessage.system("System notification")
        
        #expect(processor.canProcess(textMessage))
        #expect(processor.canProcess(systemMessage))
    }
    
    @Test("Filter processor allows valid messages")
    func testFilterProcessorAllowsValidMessages() async throws {
        let criteria = MessageFilterCriteria(
            allowedMessageTypes: [.text, .system]
        )
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        let message = RealtimeMessage.text("Hello world", from: "user1")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.getMetadata(for: "filtered_by") == "message_filter_processor")
        #expect(processedMessage?.getMetadata(for: "filter_passed") == "true")
    }
    
    @Test("Filter processor blocks messages from blocked senders")
    func testFilterProcessorBlocksBlockedSenders() async throws {
        let criteria = MessageFilterCriteria(blockedSenders: ["spammer"])
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        let message = RealtimeMessage.text("Spam message", from: "spammer")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage == nil)
    }
    
    @Test("Filter processor blocks messages from disallowed channels")
    func testFilterProcessorBlocksDisallowedChannels() async throws {
        let criteria = MessageFilterCriteria(allowedChannels: ["general"])
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        let message = RealtimeMessage.text("Hello", from: "user1", in: "private")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage == nil)
    }
    
    @Test("Filter processor blocks disallowed message types")
    func testFilterProcessorBlocksDisallowedMessageTypes() async throws {
        let criteria = MessageFilterCriteria(allowedMessageTypes: [.text])
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        let message = RealtimeMessage.system("System notification")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage == nil)
    }
    
    @Test("Filter processor blocks messages with banned content")
    func testFilterProcessorBlocksBannedContent() async throws {
        let criteria = MessageFilterCriteria(contentFilters: ["spam", "advertisement"])
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        let message = RealtimeMessage.text("This is spam content", from: "user1")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage == nil)
    }
    
    @Test("Filter processor blocks old messages")
    func testFilterProcessorBlocksOldMessages() async throws {
        let criteria = MessageFilterCriteria(maxMessageAge: 300) // 5 minutes
        let processor = MessageFilterProcessor(filterCriteria: criteria)
        let oldTimestamp = Date().addingTimeInterval(-600) // 10 minutes ago
        let message = RealtimeMessage(
            messageType: .text,
            content: "Old message",
            senderId: "user1",
            timestamp: oldTimestamp
        )
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage == nil)
    }
    
    // MARK: - Message Validation Processor Tests
    
    @Test("Validation processor initialization")
    func testValidationProcessorInitialization() async {
        let rules = MessageValidationRules(
            validateMessageId: true,
            validateSenderId: true,
            validateContent: false
        )
        let processor = MessageValidationProcessor(validationRules: rules)
        
        #expect(processor.identifier == "message_validation_processor")
        #expect(processor.priority == 150)
    }
    
    @Test("Validation processor can process all message types")
    func testValidationProcessorCanProcessAllMessageTypes() async {
        let processor = MessageValidationProcessor()
        
        let textMessage = RealtimeMessage.text("Hello", from: "user1")
        let systemMessage = RealtimeMessage.system("System notification")
        
        #expect(processor.canProcess(textMessage))
        #expect(processor.canProcess(systemMessage))
    }
    
    @Test("Validation processor validates valid message")
    func testValidationProcessorValidatesValidMessage() async throws {
        let processor = MessageValidationProcessor()
        let message = RealtimeMessage.text("Hello world", from: "user1")
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.getMetadata(for: "validated_by") == "message_validation_processor")
        #expect(processedMessage?.getMetadata(for: "validation_passed") == "true")
    }
    
    @Test("Validation processor rejects empty message ID")
    func testValidationProcessorRejectsEmptyMessageId() async {
        let processor = MessageValidationProcessor()
        let message = RealtimeMessage(
            messageId: "",
            messageType: .text,
            content: "Hello",
            senderId: "user1"
        )
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "message_validation_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Validation processor rejects empty sender ID")
    func testValidationProcessorRejectsEmptySenderId() async {
        let processor = MessageValidationProcessor()
        let message = RealtimeMessage(
            messageType: .text,
            content: "Hello",
            senderId: ""
        )
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "message_validation_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Validation processor rejects empty content")
    func testValidationProcessorRejectsEmptyContent() async {
        let processor = MessageValidationProcessor()
        let message = RealtimeMessage(
            messageType: .text,
            content: "   ",
            senderId: "user1"
        )
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "message_validation_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Validation processor rejects future timestamps")
    func testValidationProcessorRejectsFutureTimestamps() async {
        let processor = MessageValidationProcessor()
        let futureTimestamp = Date().addingTimeInterval(600) // 10 minutes in future
        let message = RealtimeMessage(
            messageType: .text,
            content: "Future message",
            senderId: "user1",
            timestamp: futureTimestamp
        )
        
        do {
            _ = try await processor.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as MessageProcessingError {
            #expect(error.processorIdentifier == "message_validation_processor")
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
    
    @Test("Validation processor allows disabled validations")
    func testValidationProcessorAllowsDisabledValidations() async throws {
        let rules = MessageValidationRules(
            validateMessageId: false,
            validateSenderId: false,
            validateContent: false,
            validateTimestamp: false
        )
        let processor = MessageValidationProcessor(validationRules: rules)
        let message = RealtimeMessage(
            messageId: "",
            messageType: .text,
            content: "",
            senderId: ""
        )
        
        let processedMessage = try await processor.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.getMetadata(for: "validation_passed") == "true")
    }
    
    // MARK: - Integration Tests
    
    @Test("Multiple processors work together")
    func testMultipleProcessorsWorkTogether() async throws {
        let manager = RealtimeMessageProcessorManager()
        
        // Register processors in different order to test priority
        let textProcessor = TextMessageProcessor(maxContentLength: 100)
        let validationProcessor = MessageValidationProcessor()
        let filterProcessor = MessageFilterProcessor(
            filterCriteria: MessageFilterCriteria(allowedMessageTypes: [.text])
        )
        
        manager.registerProcessor(textProcessor)
        manager.registerProcessor(validationProcessor)
        manager.registerProcessor(filterProcessor)
        
        let message = RealtimeMessage.text("Hello world", from: "user1")
        let processedMessage = try await manager.processMessage(message)
        
        #expect(processedMessage != nil)
        #expect(processedMessage?.getMetadata(for: "filtered_by") == "message_filter_processor")
        #expect(processedMessage?.getMetadata(for: "validated_by") == "message_validation_processor")
        #expect(processedMessage?.getMetadata(for: "processed_by") == "text_message_processor")
    }
    
    @Test("Processor chain stops on filter")
    func testProcessorChainStopsOnFilter() async throws {
        let manager = RealtimeMessageProcessorManager()
        
        let filterProcessor = MessageFilterProcessor(
            filterCriteria: MessageFilterCriteria(blockedSenders: ["blocked"])
        )
        let textProcessor = TextMessageProcessor()
        
        manager.registerProcessor(filterProcessor)
        manager.registerProcessor(textProcessor)
        
        let message = RealtimeMessage.text("Hello", from: "blocked")
        let processedMessage = try await manager.processMessage(message)
        
        #expect(processedMessage == nil)
    }
    
    @Test("Error in one processor stops chain")
    func testErrorInOneProcessorStopsChain() async {
        let manager = RealtimeMessageProcessorManager(maxRetries: 0)
        
        let validationProcessor = MessageValidationProcessor()
        let textProcessor = TextMessageProcessor()
        
        manager.registerProcessor(validationProcessor)
        manager.registerProcessor(textProcessor)
        
        let message = RealtimeMessage(
            messageId: "",
            messageType: .text,
            content: "Hello",
            senderId: "user1"
        )
        
        do {
            _ = try await manager.processMessage(message)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is MessageProcessingError)
        }
    }
}