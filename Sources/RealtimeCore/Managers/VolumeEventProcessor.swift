import Foundation
import Combine

/// 音量事件处理器 - 负责异步事件处理和线程安全保护
/// 需求: 6.3, 6.5
@MainActor
public class VolumeEventProcessor: ObservableObject {
    
    // MARK: - Event Queue Management
    
    /// 事件队列
    private var eventQueue: [VolumeEventItem] = []
    
    /// 事件处理器映射
    private var eventHandlers: [VolumeEventType: [VolumeEventHandler]] = [:]
    
    /// 事件处理统计
    @Published public private(set) var processingStats: VolumeEventProcessingStats = VolumeEventProcessingStats()
    
    /// 是否正在处理事件
    @Published public private(set) var isProcessing: Bool = false
    
    /// 最大队列大小
    private let maxQueueSize: Int = 1000
    
    /// 事件处理任务
    private var processingTask: Task<Void, Never>?
    
    /// 事件处理间隔（毫秒）
    private let processingInterval: TimeInterval = 0.05 // 50ms
    
    // MARK: - Initialization
    
    public init() {
        startEventProcessing()
    }
    
    deinit {
        processingTask?.cancel()
        processingTask = nil
    }
    
    // MARK: - Event Handler Registration
    
    /// 注册事件处理器
    /// - Parameters:
    ///   - eventType: 事件类型
    ///   - handler: 事件处理器
    public func registerEventHandler(for eventType: VolumeEventType, handler: @escaping VolumeEventHandler) {
        if eventHandlers[eventType] == nil {
            eventHandlers[eventType] = []
        }
        eventHandlers[eventType]?.append(handler)
        
        processingStats.registeredHandlers += 1
        print("Registered event handler for type: \(eventType)")
    }
    
    /// 注册多个事件类型的处理器
    /// - Parameters:
    ///   - eventTypes: 事件类型数组
    ///   - handler: 事件处理器
    public func registerEventHandler(for eventTypes: [VolumeEventType], handler: @escaping VolumeEventHandler) {
        for eventType in eventTypes {
            registerEventHandler(for: eventType, handler: handler)
        }
    }
    
    /// 取消注册事件处理器
    /// - Parameter eventType: 事件类型
    public func unregisterEventHandlers(for eventType: VolumeEventType) {
        let count = eventHandlers[eventType]?.count ?? 0
        eventHandlers[eventType] = nil
        
        processingStats.registeredHandlers -= count
        print("Unregistered \(count) event handlers for type: \(eventType)")
    }
    
    /// 取消注册所有事件处理器
    public func unregisterAllEventHandlers() {
        let totalCount = eventHandlers.values.reduce(0) { $0 + $1.count }
        eventHandlers.removeAll()
        
        processingStats.registeredHandlers = 0
        print("Unregistered all \(totalCount) event handlers")
    }
    
    // MARK: - Event Processing (需求 6.3, 6.5)
    
    /// 处理音量事件
    /// - Parameter event: 音量事件
    public func processEvent(_ event: VolumeEvent) {
        let eventItem = VolumeEventItem(
            event: event,
            timestamp: Date(),
            priority: getEventPriority(event)
        )
        
        // 线程安全地添加到队列
        addToQueue(eventItem)
    }
    
    /// 批量处理音量事件
    /// - Parameter events: 音量事件数组
    public func processEvents(_ events: [VolumeEvent]) {
        let eventItems = events.map { event in
            VolumeEventItem(
                event: event,
                timestamp: Date(),
                priority: getEventPriority(event)
            )
        }
        
        // 线程安全地批量添加到队列
        addToQueue(eventItems)
    }
    
    /// 线程安全地添加单个事件到队列
    /// - Parameter eventItem: 事件项
    private func addToQueue(_ eventItem: VolumeEventItem) {
        // 检查队列大小限制
        if eventQueue.count >= maxQueueSize {
            // 移除最旧的事件
            eventQueue.removeFirst()
            processingStats.droppedEvents += 1
        }
        
        // 按优先级插入事件
        insertEventByPriority(eventItem)
        processingStats.totalEventsReceived += 1
    }
    
    /// 线程安全地批量添加事件到队列
    /// - Parameter eventItems: 事件项数组
    private func addToQueue(_ eventItems: [VolumeEventItem]) {
        for eventItem in eventItems {
            addToQueue(eventItem)
        }
    }
    
    /// 按优先级插入事件
    /// - Parameter eventItem: 事件项
    private func insertEventByPriority(_ eventItem: VolumeEventItem) {
        let insertIndex = eventQueue.firstIndex { $0.priority.rawValue < eventItem.priority.rawValue } ?? eventQueue.count
        eventQueue.insert(eventItem, at: insertIndex)
    }
    
    /// 获取事件优先级
    /// - Parameter event: 音量事件
    /// - Returns: 事件优先级
    private func getEventPriority(_ event: VolumeEvent) -> VolumeEventPriority {
        switch event {
        case .dominantSpeakerChanged:
            return .high
        case .userStartedSpeaking, .userStoppedSpeaking:
            return .medium
        case .volumeUpdate:
            return .low
        }
    }
    
    // MARK: - Async Event Processing
    
    /// 启动事件处理
    private func startEventProcessing() {
        guard processingTask == nil else { return }
        
        processingTask = Task { @MainActor in
            await processEventQueue()
        }
        
        print("Volume event processing started")
    }
    
    /// 停止事件处理
    private func stopEventProcessing() {
        processingTask?.cancel()
        processingTask = nil
        
        print("Volume event processing stopped")
    }
    
    /// 异步处理事件队列
    private func processEventQueue() async {
        while !Task.isCancelled {
            if !eventQueue.isEmpty {
                isProcessing = true
                await processNextBatch()
                isProcessing = false
            }
            
            // 等待下一个处理周期
            try? await Task.sleep(nanoseconds: UInt64(processingInterval * 1_000_000_000))
        }
    }
    
    /// 处理下一批事件
    private func processNextBatch() async {
        let batchSize = min(10, eventQueue.count) // 每批最多处理10个事件
        let batch = Array(eventQueue.prefix(batchSize))
        eventQueue.removeFirst(batchSize)
        
        // 顺序处理事件以避免并发问题
        for eventItem in batch {
            await processEventItem(eventItem)
        }
    }
    
    /// 处理单个事件项
    /// - Parameter eventItem: 事件项
    private func processEventItem(_ eventItem: VolumeEventItem) async {
        let eventType = VolumeEventType.from(eventItem.event)
        let handlers = eventHandlers[eventType] ?? []
        
        guard !handlers.isEmpty else {
            processingStats.unhandledEvents += 1
            return
        }
        
        let startTime = Date()
        
        // 顺序执行所有处理器以避免并发问题
        var successCount = 0
        var failureCount = 0
        
        for handler in handlers {
            let result = await executeHandler(handler, with: eventItem.event)
            switch result {
            case .success:
                successCount += 1
            case .failure(let error):
                failureCount += 1
                print("Event handler failed: \(error)")
            case .timeout:
                failureCount += 1
                print("Event handler timed out")
            }
        }
        
        // 更新统计信息
        processingStats.totalEventsProcessed += 1
        processingStats.successfulHandlerExecutions += successCount
        processingStats.failedHandlerExecutions += failureCount
        
        let processingTime = Date().timeIntervalSince(startTime)
        processingStats.updateAverageProcessingTime(processingTime)
    }
    
    /// 执行事件处理器
    /// - Parameters:
    ///   - handler: 事件处理器
    ///   - event: 音量事件
    /// - Returns: 处理结果
    private func executeHandler(_ handler: @escaping VolumeEventHandler, with event: VolumeEvent) async -> VolumeEventHandlerResult {
        // 简化实现，直接执行处理器，不使用复杂的超时机制
        do {
            try await handler(event)
            return .success
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Queue Management
    
    /// 清空事件队列
    public func clearEventQueue() {
        let clearedCount = eventQueue.count
        eventQueue.removeAll()
        
        processingStats.droppedEvents += clearedCount
        print("Cleared \(clearedCount) events from queue")
    }
    
    /// 获取队列状态
    public var queueStatus: VolumeEventQueueStatus {
        return VolumeEventQueueStatus(
            queueSize: eventQueue.count,
            maxQueueSize: maxQueueSize,
            isProcessing: isProcessing,
            utilizationRate: Double(eventQueue.count) / Double(maxQueueSize)
        )
    }
    
    // MARK: - Statistics
    
    /// 重置处理统计
    public func resetStatistics() {
        processingStats = VolumeEventProcessingStats()
        print("Volume event processing statistics reset")
    }
    
    /// 获取性能指标
    public var performanceMetrics: VolumeEventPerformanceMetrics {
        return VolumeEventPerformanceMetrics(
            eventsPerSecond: calculateEventsPerSecond(),
            averageQueueSize: calculateAverageQueueSize(),
            processingEfficiency: calculateProcessingEfficiency(),
            handlerSuccessRate: calculateHandlerSuccessRate()
        )
    }
    
    private func calculateEventsPerSecond() -> Double {
        let uptime = processingStats.uptime
        guard uptime > 0 else { return 0 }
        return Double(processingStats.totalEventsProcessed) / uptime
    }
    
    private func calculateAverageQueueSize() -> Double {
        // 简化实现，实际应该维护历史队列大小
        return Double(eventQueue.count)
    }
    
    private func calculateProcessingEfficiency() -> Double {
        let total = processingStats.totalEventsReceived
        guard total > 0 else { return 0 }
        return Double(processingStats.totalEventsProcessed) / Double(total)
    }
    
    private func calculateHandlerSuccessRate() -> Double {
        let total = processingStats.successfulHandlerExecutions + processingStats.failedHandlerExecutions
        guard total > 0 else { return 0 }
        return Double(processingStats.successfulHandlerExecutions) / Double(total)
    }
}

// MARK: - Supporting Types

/// 音量事件项
private struct VolumeEventItem {
    let event: VolumeEvent
    let timestamp: Date
    let priority: VolumeEventPriority
}

/// 音量事件优先级
private enum VolumeEventPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

/// 音量事件类型
public enum VolumeEventType: String, CaseIterable {
    case userStartedSpeaking = "user_started_speaking"
    case userStoppedSpeaking = "user_stopped_speaking"
    case dominantSpeakerChanged = "dominant_speaker_changed"
    case volumeUpdate = "volume_update"
    
    static func from(_ event: VolumeEvent) -> VolumeEventType {
        switch event {
        case .userStartedSpeaking:
            return .userStartedSpeaking
        case .userStoppedSpeaking:
            return .userStoppedSpeaking
        case .dominantSpeakerChanged:
            return .dominantSpeakerChanged
        case .volumeUpdate:
            return .volumeUpdate
        }
    }
}

/// 音量事件处理器类型别名
public typealias VolumeEventHandler = (VolumeEvent) async throws -> Void

/// 事件处理器执行结果
private enum VolumeEventHandlerResult {
    case success
    case failure(Error)
    case timeout
}

/// 音量事件处理统计
public struct VolumeEventProcessingStats {
    /// 开始时间
    public let startTime: Date = Date()
    
    /// 注册的处理器数量
    public var registeredHandlers: Int = 0
    
    /// 接收到的总事件数
    public var totalEventsReceived: Int = 0
    
    /// 处理的总事件数
    public var totalEventsProcessed: Int = 0
    
    /// 丢弃的事件数
    public var droppedEvents: Int = 0
    
    /// 未处理的事件数
    public var unhandledEvents: Int = 0
    
    /// 成功执行的处理器数
    public var successfulHandlerExecutions: Int = 0
    
    /// 失败执行的处理器数
    public var failedHandlerExecutions: Int = 0
    
    /// 平均处理时间
    private var totalProcessingTime: TimeInterval = 0
    private var processingTimeCount: Int = 0
    
    /// 运行时长
    public var uptime: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
    
    /// 平均处理时间
    public var averageProcessingTime: TimeInterval {
        guard processingTimeCount > 0 else { return 0 }
        return totalProcessingTime / Double(processingTimeCount)
    }
    
    /// 更新平均处理时间
    mutating func updateAverageProcessingTime(_ time: TimeInterval) {
        totalProcessingTime += time
        processingTimeCount += 1
    }
}

/// 音量事件队列状态
public struct VolumeEventQueueStatus {
    /// 当前队列大小
    public let queueSize: Int
    
    /// 最大队列大小
    public let maxQueueSize: Int
    
    /// 是否正在处理
    public let isProcessing: Bool
    
    /// 队列利用率 (0.0 - 1.0)
    public let utilizationRate: Double
    
    /// 队列是否接近满载
    public var isNearCapacity: Bool {
        return utilizationRate > 0.8
    }
    
    /// 队列是否已满
    public var isFull: Bool {
        return queueSize >= maxQueueSize
    }
}

/// 音量事件性能指标
public struct VolumeEventPerformanceMetrics {
    /// 每秒处理事件数
    public let eventsPerSecond: Double
    
    /// 平均队列大小
    public let averageQueueSize: Double
    
    /// 处理效率 (0.0 - 1.0)
    public let processingEfficiency: Double
    
    /// 处理器成功率 (0.0 - 1.0)
    public let handlerSuccessRate: Double
    
    /// 性能等级
    public var performanceGrade: PerformanceGrade {
        let score = (processingEfficiency + handlerSuccessRate) / 2.0
        switch score {
        case 0.9...1.0:
            return .excellent
        case 0.8..<0.9:
            return .good
        case 0.7..<0.8:
            return .fair
        default:
            return .poor
        }
    }
}

/// 性能等级
public enum PerformanceGrade: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    public var displayName: String {
        switch self {
        case .excellent:
            return "优秀"
        case .good:
            return "良好"
        case .fair:
            return "一般"
        case .poor:
            return "较差"
        }
    }
    
    public var color: String {
        switch self {
        case .excellent:
            return "#4CAF50"
        case .good:
            return "#8BC34A"
        case .fair:
            return "#FFC107"
        case .poor:
            return "#F44336"
        }
    }
}