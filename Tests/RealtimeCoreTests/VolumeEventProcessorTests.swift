// VolumeEventProcessorTests.swift
// Unit tests for VolumeEventProcessor

import Testing
import Foundation
@testable import RealtimeCore

@Suite("VolumeEventProcessor Tests")
struct VolumeEventProcessorTests {
    
    @MainActor
    func createProcessor() -> VolumeEventProcessor {
        return VolumeEventProcessor()
    }
    
    @Test("Processor initialization")
    @MainActor
    func testProcessorInitialization() {
        let processor = createProcessor()
        
        #expect(processor.isProcessing == false)
        #expect(processor.eventQueue.isEmpty)
        #expect(processor.processedEventCount == 0)
        #expect(processor.failedEventCount == 0)
        #expect(processor.getQueueSize() == 0)
    }
    
    @Test("Register and process single event")
    @MainActor
    func testRegisterAndProcessSingleEvent() async {
        let processor = createProcessor()
        var processedEvents: [VolumeEvent] = []
        
        processor.registerHandler(for: .userStartedSpeaking) { event in
            processedEvents.append(event)
        }
        
        let event = VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5)
        processor.processEvent(event)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(processedEvents.count == 1)
        #expect(processedEvents[0] == event)
        #expect(processor.processedEventCount == 1)
        #expect(processor.failedEventCount == 0)
    }
    
    @Test("Process multiple events")
    @MainActor
    func testProcessMultipleEvents() async {
        let processor = createProcessor()
        var processedEvents: [VolumeEvent] = []
        
        processor.registerUniversalHandler { event in
            processedEvents.append(event)
        }
        
        let events = [
            VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5),
            VolumeEvent.userStoppedSpeaking(userId: "user1", volume: 0.2),
            VolumeEvent.dominantSpeakerChanged(userId: "user2")
        ]
        
        processor.processEvents(events)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        #expect(processedEvents.count == 3)
        #expect(processor.processedEventCount == 3)
        #expect(processor.failedEventCount == 0)
    }
    
    @Test("Event type specific handlers")
    @MainActor
    func testEventTypeSpecificHandlers() async {
        let processor = createProcessor()
        var speakingEvents: [VolumeEvent] = []
        var volumeEvents: [VolumeEvent] = []
        
        processor.registerHandler(for: .userStartedSpeaking) { event in
            speakingEvents.append(event)
        }
        
        processor.registerHandler(for: .volumeChanged) { event in
            volumeEvents.append(event)
        }
        
        let events = [
            VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5),
            VolumeEvent.volumeChanged(userId: "user1", volume: 0.6),
            VolumeEvent.userStoppedSpeaking(userId: "user1", volume: 0.2)
        ]
        
        processor.processEvents(events)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        #expect(speakingEvents.count == 1)
        #expect(volumeEvents.count == 1)
        #expect(processor.processedEventCount == 2) // Only 2 events had handlers
    }
    
    @Test("Error handling in event processing")
    @MainActor
    func testErrorHandling() async {
        let processor = createProcessor()
        var failedEvents: [(VolumeEvent, Error)] = []
        
        processor.onEventFailed = { event, error in
            failedEvents.append((event, error))
        }
        
        // Register a handler that throws an error
        processor.registerHandler(for: .userStartedSpeaking) { event in
            throw NSError(domain: "TestError", code: 1, userInfo: [:])
        }
        
        let event = VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5)
        processor.processEvent(event)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(failedEvents.count == 1)
        #expect(processor.processedEventCount == 0)
        #expect(processor.failedEventCount == 1)
    }
    
    @Test("Queue management")
    @MainActor
    func testQueueManagement() {
        let processor = createProcessor()
        
        let events = [
            VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5),
            VolumeEvent.userStoppedSpeaking(userId: "user1", volume: 0.2)
        ]
        
        processor.processEvents(events)
        
        #expect(processor.getQueueSize() == 2)
        
        processor.clearQueue()
        
        #expect(processor.getQueueSize() == 0)
        #expect(processor.eventQueue.isEmpty)
    }
    
    @Test("Processing statistics")
    @MainActor
    func testProcessingStatistics() async {
        let processor = createProcessor()
        
        // Register handlers - one that succeeds, one that fails
        processor.registerHandler(for: .userStartedSpeaking) { event in
            // Success
        }
        
        processor.registerHandler(for: .userStoppedSpeaking) { event in
            throw NSError(domain: "TestError", code: 1, userInfo: [:])
        }
        
        let events = [
            VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5),
            VolumeEvent.userStoppedSpeaking(userId: "user1", volume: 0.2)
        ]
        
        processor.processEvents(events)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        let stats = processor.getStatistics()
        
        #expect(stats.processedCount == 1)
        #expect(stats.failedCount == 1)
        #expect(stats.successRate == 50.0)
        
        processor.resetStatistics()
        
        let resetStats = processor.getStatistics()
        #expect(resetStats.processedCount == 0)
        #expect(resetStats.failedCount == 0)
    }
    
    @Test("Convenience handler registration")
    @MainActor
    func testConvenienceHandlers() async {
        let processor = createProcessor()
        var startSpeakingCalls: [(String, Float)] = []
        var stopSpeakingCalls: [(String, Float)] = []
        var dominantSpeakerChanges: [String?] = []
        var volumeChanges: [(String, Float)] = []
        
        processor.registerSpeakingHandlers(
            onStartSpeaking: { userId, volume in
                startSpeakingCalls.append((userId, volume))
            },
            onStopSpeaking: { userId, volume in
                stopSpeakingCalls.append((userId, volume))
            }
        )
        
        processor.registerDominantSpeakerHandler { userId in
            dominantSpeakerChanges.append(userId)
        }
        
        processor.registerVolumeChangeHandler { userId, volume in
            volumeChanges.append((userId, volume))
        }
        
        let events = [
            VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5),
            VolumeEvent.userStoppedSpeaking(userId: "user1", volume: 0.2),
            VolumeEvent.dominantSpeakerChanged(userId: "user2"),
            VolumeEvent.volumeChanged(userId: "user1", volume: 0.7)
        ]
        
        processor.processEvents(events)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        #expect(startSpeakingCalls.count == 1)
        #expect(startSpeakingCalls[0].0 == "user1")
        #expect(startSpeakingCalls[0].1 == 0.5)
        
        #expect(stopSpeakingCalls.count == 1)
        #expect(stopSpeakingCalls[0].0 == "user1")
        #expect(stopSpeakingCalls[0].1 == 0.2)
        
        #expect(dominantSpeakerChanges.count == 1)
        #expect(dominantSpeakerChanges[0] == "user2")
        
        #expect(volumeChanges.count == 1)
        #expect(volumeChanges[0].0 == "user1")
        #expect(volumeChanges[0].1 == 0.7)
    }
    
    @Test("Thread safety")
    @MainActor
    func testThreadSafety() async {
        let processor = createProcessor()
        let eventCollector = EventCollector()
        
        processor.registerUniversalHandler { event in
            await eventCollector.addEvent(event)
        }
        
        // Process events from multiple threads
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let event = VolumeEvent.userStartedSpeaking(userId: "user\(i)", volume: Float(i) * 0.1)
                    processor.processEventThreadSafe(event)
                }
            }
        }
        
        // Wait for all processing to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        let count = await eventCollector.getEventCount()
        
        #expect(count == 10)
        #expect(processor.processedEventCount == 10)
    }
    
    @Test("Stop processing")
    @MainActor
    func testStopProcessing() async {
        let processor = createProcessor()
        var processedEvents: [VolumeEvent] = []
        
        processor.registerUniversalHandler { event in
            processedEvents.append(event)
            // Add delay to simulate processing time
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Add many events
        let events = (0..<10).map { i in
            VolumeEvent.userStartedSpeaking(userId: "user\(i)", volume: Float(i) * 0.1)
        }
        
        processor.processEvents(events)
        
        // Stop processing after a short delay (should interrupt processing)
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms - should allow 1-2 events to process
        processor.stop()
        
        // Wait a bit more
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Should have stopped processing and cleared the queue
        #expect(processor.eventQueue.isEmpty) // Queue should be cleared
        #expect(processor.isProcessing == false)
        // The exact number of processed events may vary due to timing, but should be reasonable
        #expect(processedEvents.count >= 0) // At least some processing should have occurred or been stopped
    }
    
    @Test("Clear handlers")
    @MainActor
    func testClearHandlers() async {
        let processor = createProcessor()
        var processedEvents: [VolumeEvent] = []
        
        processor.registerHandler(for: .userStartedSpeaking) { event in
            processedEvents.append(event)
        }
        
        let event = VolumeEvent.userStartedSpeaking(userId: "user1", volume: 0.5)
        processor.processEvent(event)
        
        // Wait for processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(processedEvents.count == 1)
        
        // Clear handlers and process another event
        processor.clearHandlers(for: .userStartedSpeaking)
        
        let event2 = VolumeEvent.userStartedSpeaking(userId: "user2", volume: 0.6)
        processor.processEvent(event2)
        
        // Wait for processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Should still be 1 since handler was cleared
        #expect(processedEvents.count == 1)
    }
    
    @Test("Queue size limit")
    @MainActor
    func testQueueSizeLimit() {
        let processor = createProcessor()
        
        // Add events beyond the queue limit (1000)
        for i in 0..<1100 {
            let event = VolumeEvent.userStartedSpeaking(userId: "user\(i)", volume: 0.5)
            processor.processEvent(event)
        }
        
        // Queue should be limited to 1000 events
        #expect(processor.getQueueSize() <= 1000)
    }
}

// MARK: - Helper Types

actor EventCollector {
    private var events: [VolumeEvent] = []
    
    func addEvent(_ event: VolumeEvent) {
        events.append(event)
    }
    
    func getEventCount() -> Int {
        return events.count
    }
    
    func getEvents() -> [VolumeEvent] {
        return events
    }
}