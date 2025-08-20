// VolumeEventProcessor.swift
// Asynchronous volume event processing system with thread safety

import Foundation
import Combine

/// Processor for handling volume events asynchronously with thread safety
@MainActor
public class VolumeEventProcessor: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var eventQueue: [VolumeEvent] = []
    @Published public private(set) var processedEventCount: Int = 0
    @Published public private(set) var failedEventCount: Int = 0
    
    // MARK: - Event Handlers
    public var onEventProcessed: ((VolumeEvent) -> Void)?
    public var onEventFailed: ((VolumeEvent, Error) -> Void)?
    public var onQueueEmpty: (() -> Void)?
    
    // MARK: - Private Properties
    private var eventHandlers: [VolumeEventType: [(VolumeEvent) async throws -> Void]] = [:]
    private var processingTask: Task<Void, Never>?
    private let maxQueueSize: Int = 1000
    private let processingDelay: TimeInterval = 0.01 // 10ms delay between events
    
    // MARK: - Initialization
    public init() {
        print("VolumeEventProcessor initialized")
    }
    
    deinit {
        processingTask?.cancel()
    }
    
    // MARK: - Event Handler Registration
    
    /// Register an async event handler for specific event types
    /// - Parameters:
    ///   - eventType: Type of volume event to handle
    ///   - handler: Async handler function
    public func registerHandler(
        for eventType: VolumeEventType,
        handler: @escaping (VolumeEvent) async throws -> Void
    ) {
        if eventHandlers[eventType] == nil {
            eventHandlers[eventType] = []
        }
        eventHandlers[eventType]?.append(handler)
        print("Registered handler for event type: \(eventType)")
    }
    
    /// Register a handler for all event types
    /// - Parameter handler: Universal event handler
    public func registerUniversalHandler(
        handler: @escaping (VolumeEvent) async throws -> Void
    ) {
        for eventType in VolumeEventType.allCases {
            registerHandler(for: eventType, handler: handler)
        }
    }
    
    /// Remove all handlers for a specific event type
    /// - Parameter eventType: Event type to clear handlers for
    public func clearHandlers(for eventType: VolumeEventType) {
        eventHandlers[eventType] = []
        print("Cleared handlers for event type: \(eventType)")
    }
    
    /// Remove all event handlers
    public func clearAllHandlers() {
        eventHandlers.removeAll()
        print("Cleared all event handlers")
    }
    
    // MARK: - Event Processing
    
    /// Process a volume event asynchronously
    /// - Parameter event: Volume event to process
    public func processEvent(_ event: VolumeEvent) {
        // Check queue size limit
        guard eventQueue.count < maxQueueSize else {
            print("Event queue full, dropping event: \(event)")
            return
        }
        
        eventQueue.append(event)
        
        // Start processing if not already running
        if !isProcessing {
            startProcessing()
        }
    }
    
    /// Process multiple events in batch
    /// - Parameter events: Array of volume events to process
    public func processEvents(_ events: [VolumeEvent]) {
        for event in events {
            processEvent(event)
        }
    }
    
    /// Start the event processing loop
    private func startProcessing() {
        processingTask = Task { @MainActor in
            isProcessing = true
            
            while !eventQueue.isEmpty {
                let event = eventQueue.removeFirst()
                
                do {
                    let wasProcessed = try await processEventInternal(event)
                    if wasProcessed {
                        processedEventCount += 1
                        onEventProcessed?(event)
                    }
                } catch {
                    failedEventCount += 1
                    onEventFailed?(event, error)
                    print("Failed to process event \(event): \(error)")
                }
                
                // Small delay to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
                
                // Check if task was cancelled
                if Task.isCancelled {
                    break
                }
            }
            
            isProcessing = false
            
            if eventQueue.isEmpty {
                onQueueEmpty?()
            }
        }
    }
    
    /// Process a single event internally
    /// - Parameter event: Volume event to process
    /// - Returns: True if event was processed by at least one handler
    private func processEventInternal(_ event: VolumeEvent) async throws -> Bool {
        let eventType = VolumeEventType.from(event)
        
        guard let handlers = eventHandlers[eventType], !handlers.isEmpty else {
            // No handlers registered for this event type
            return false
        }
        
        // Execute all handlers for this event type
        for handler in handlers {
            try await handler(event)
        }
        
        return true
    }
    
    // MARK: - Queue Management
    
    /// Clear the event queue
    public func clearQueue() {
        eventQueue.removeAll()
        print("Event queue cleared")
    }
    
    /// Stop processing and clear queue
    public func stop() {
        processingTask?.cancel()
        clearQueue()
        isProcessing = false
        print("Event processor stopped")
    }
    
    /// Get current queue size
    public func getQueueSize() -> Int {
        return eventQueue.count
    }
    
    /// Check if processor is currently processing events
    public func isCurrentlyProcessing() -> Bool {
        return isProcessing
    }
    
    // MARK: - Statistics
    
    /// Get processing statistics
    public func getStatistics() -> VolumeEventProcessingStats {
        return VolumeEventProcessingStats(
            processedCount: processedEventCount,
            failedCount: failedEventCount,
            queueSize: eventQueue.count,
            isProcessing: isProcessing
        )
    }
    
    /// Reset processing statistics
    public func resetStatistics() {
        processedEventCount = 0
        failedEventCount = 0
        print("Processing statistics reset")
    }
}

// MARK: - Supporting Types

/// Errors that can occur during volume event processing
public enum VolumeEventProcessingError: Error {
    case noHandlersRegistered
    case processingFailed(Error)
    case queueFull
}

/// Volume event type enumeration for handler registration
public enum VolumeEventType: CaseIterable {
    case userStartedSpeaking
    case userStoppedSpeaking
    case volumeChanged
    case dominantSpeakerChanged
    
    /// Create event type from volume event
    /// - Parameter event: Volume event
    /// - Returns: Corresponding event type
    static func from(_ event: VolumeEvent) -> VolumeEventType {
        switch event {
        case .userStartedSpeaking:
            return .userStartedSpeaking
        case .userStoppedSpeaking:
            return .userStoppedSpeaking
        case .volumeChanged:
            return .volumeChanged
        case .dominantSpeakerChanged:
            return .dominantSpeakerChanged
        }
    }
}

/// Statistics for volume event processing
public struct VolumeEventProcessingStats {
    public let processedCount: Int
    public let failedCount: Int
    public let queueSize: Int
    public let isProcessing: Bool
    
    /// Success rate as percentage
    public var successRate: Double {
        let total = processedCount + failedCount
        return total > 0 ? Double(processedCount) / Double(total) * 100.0 : 0.0
    }
}

// MARK: - Convenience Extensions

extension VolumeEventProcessor {
    
    /// Register a simple callback handler for an event type
    /// - Parameters:
    ///   - eventType: Event type to handle
    ///   - callback: Simple callback function
    public func registerCallback(
        for eventType: VolumeEventType,
        callback: @escaping (VolumeEvent) -> Void
    ) {
        registerHandler(for: eventType) { event in
            callback(event)
        }
    }
    
    /// Register handlers for speaking state changes
    /// - Parameters:
    ///   - onStartSpeaking: Handler for when user starts speaking
    ///   - onStopSpeaking: Handler for when user stops speaking
    public func registerSpeakingHandlers(
        onStartSpeaking: @escaping (String, Float) -> Void,
        onStopSpeaking: @escaping (String, Float) -> Void
    ) {
        registerCallback(for: .userStartedSpeaking) { event in
            if case .userStartedSpeaking(let userId, let volume) = event {
                onStartSpeaking(userId, volume)
            }
        }
        
        registerCallback(for: .userStoppedSpeaking) { event in
            if case .userStoppedSpeaking(let userId, let volume) = event {
                onStopSpeaking(userId, volume)
            }
        }
    }
    
    /// Register handler for dominant speaker changes
    /// - Parameter handler: Handler for dominant speaker changes
    public func registerDominantSpeakerHandler(
        handler: @escaping (String?) -> Void
    ) {
        registerCallback(for: .dominantSpeakerChanged) { event in
            if case .dominantSpeakerChanged(let userId) = event {
                handler(userId)
            }
        }
    }
    
    /// Register handler for volume changes
    /// - Parameter handler: Handler for volume changes
    public func registerVolumeChangeHandler(
        handler: @escaping (String, Float) -> Void
    ) {
        registerCallback(for: .volumeChanged) { event in
            if case .volumeChanged(let userId, let volume) = event {
                handler(userId, volume)
            }
        }
    }
}

// MARK: - Thread Safety Extensions

extension VolumeEventProcessor {
    
    /// Process event from any thread (thread-safe)
    /// - Parameter event: Volume event to process
    nonisolated public func processEventThreadSafe(_ event: VolumeEvent) {
        Task { @MainActor in
            processEvent(event)
        }
    }
    
    /// Process multiple events from any thread (thread-safe)
    /// - Parameter events: Array of volume events to process
    nonisolated public func processEventsThreadSafe(_ events: [VolumeEvent]) {
        Task { @MainActor in
            processEvents(events)
        }
    }
    
    /// Stop processing from any thread (thread-safe)
    nonisolated public func stopThreadSafe() {
        Task { @MainActor in
            stop()
        }
    }
}