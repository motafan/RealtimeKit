import Foundation

/// Manager for handling error recovery and retry mechanisms
/// 需求: 13.4 - 错误恢复机制和用户友好的错误提示
@MainActor
public class ErrorRecoveryManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isRecovering: Bool = false
    @Published public private(set) var recoveryAttempts: [String: Int] = [:]
    @Published public private(set) var lastRecoveryError: RealtimeError?
    @Published public private(set) var recoveryHistory: [RecoveryAttempt] = []
    
    // MARK: - Configuration
    public struct RecoveryConfig: Sendable {
        let maxRetryAttempts: Int
        let baseRetryDelay: TimeInterval
        let exponentialBackoffMultiplier: Double
        let maxRetryDelay: TimeInterval
        
        public init(
            maxRetryAttempts: Int = 3,
            baseRetryDelay: TimeInterval = 1.0,
            exponentialBackoffMultiplier: Double = 2.0,
            maxRetryDelay: TimeInterval = 30.0
        ) {
            self.maxRetryAttempts = maxRetryAttempts
            self.baseRetryDelay = baseRetryDelay
            self.exponentialBackoffMultiplier = exponentialBackoffMultiplier
            self.maxRetryDelay = maxRetryDelay
        }
        
        public static let `default` = RecoveryConfig()
    }
    
    // MARK: - Private Properties
    private let config: RecoveryConfig
    private var recoveryTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Callbacks
    public var onRecoveryStarted: ((RealtimeError, Int) -> Void)?
    public var onRecoverySucceeded: ((RealtimeError, Int) -> Void)?
    public var onRecoveryFailed: ((RealtimeError, Int) -> Void)?
    public var onRecoveryExhausted: ((RealtimeError, Int) -> Void)?
    
    // MARK: - Initialization
    public init(config: RecoveryConfig = .default) {
        self.config = config
    }
    
    // MARK: - Public Methods
    
    /// Attempt to recover from an error with automatic retry
    /// - Parameters:
    ///   - error: The error to recover from
    ///   - operation: The operation to retry
    ///   - operationId: Unique identifier for the operation (for tracking retry attempts)
    /// - Returns: True if recovery succeeded, false otherwise
    @discardableResult
    public func attemptRecovery<T>(
        from error: RealtimeError,
        operation: @escaping () async throws -> T,
        operationId: String
    ) async -> Bool {
        
        guard error.isRecoverable else {
            await recordRecoveryAttempt(
                operationId: operationId,
                error: error,
                attemptNumber: 0,
                result: .notRecoverable
            )
            return false
        }
        
        let currentAttempts = recoveryAttempts[operationId] ?? 0
        
        guard currentAttempts < config.maxRetryAttempts else {
            await recordRecoveryAttempt(
                operationId: operationId,
                error: error,
                attemptNumber: currentAttempts,
                result: .exhausted
            )
            onRecoveryExhausted?(error, currentAttempts)
            return false
        }
        
        // Cancel any existing recovery task for this operation
        recoveryTasks[operationId]?.cancel()
        
        let recoveryTask = Task {
            await performRecovery(
                error: error,
                operation: operation,
                operationId: operationId,
                attemptNumber: currentAttempts + 1
            )
        }
        
        recoveryTasks[operationId] = recoveryTask
        await recoveryTask.value
        
        return recoveryAttempts[operationId] == nil // Success if attempts were cleared
    }
    
    /// Cancel recovery for a specific operation
    /// - Parameter operationId: The operation ID to cancel recovery for
    public func cancelRecovery(for operationId: String) {
        recoveryTasks[operationId]?.cancel()
        recoveryTasks.removeValue(forKey: operationId)
        recoveryAttempts.removeValue(forKey: operationId)
    }
    
    /// Cancel all ongoing recovery operations
    public func cancelAllRecovery() {
        for task in recoveryTasks.values {
            task.cancel()
        }
        recoveryTasks.removeAll()
        recoveryAttempts.removeAll()
        isRecovering = false
    }
    
    /// Get recovery statistics for an operation
    /// - Parameter operationId: The operation ID
    /// - Returns: Recovery statistics or nil if no attempts have been made
    public func getRecoveryStats(for operationId: String) -> RecoveryStats? {
        let attempts = recoveryHistory.filter { $0.operationId == operationId }
        guard !attempts.isEmpty else { return nil }
        
        let successfulAttempts = attempts.filter { $0.result == .succeeded }.count
        let failedAttempts = attempts.filter { $0.result == .failed }.count
        let totalAttempts = attempts.count
        
        return RecoveryStats(
            operationId: operationId,
            totalAttempts: totalAttempts,
            successfulAttempts: successfulAttempts,
            failedAttempts: failedAttempts,
            lastAttempt: attempts.last?.timestamp,
            averageRetryDelay: attempts.compactMap { $0.retryDelay }.reduce(0, +) / Double(max(1, attempts.count))
        )
    }
    
    /// Clear recovery history older than specified time interval
    /// - Parameter olderThan: Time interval to keep history for
    public func clearOldRecoveryHistory(olderThan: TimeInterval) {
        let cutoffDate = Date().addingTimeInterval(-olderThan)
        recoveryHistory.removeAll { $0.timestamp < cutoffDate }
    }
    
    // MARK: - Private Methods
    
    private func performRecovery<T>(
        error: RealtimeError,
        operation: @escaping () async throws -> T,
        operationId: String,
        attemptNumber: Int
    ) async {
        
        isRecovering = true
        recoveryAttempts[operationId] = attemptNumber
        lastRecoveryError = error
        
        onRecoveryStarted?(error, attemptNumber)
        
        // Calculate retry delay with exponential backoff
        let retryDelay = calculateRetryDelay(
            baseDelay: error.retryDelay ?? config.baseRetryDelay,
            attemptNumber: attemptNumber
        )
        
        await recordRecoveryAttempt(
            operationId: operationId,
            error: error,
            attemptNumber: attemptNumber,
            result: .started,
            retryDelay: retryDelay
        )
        
        // Wait for retry delay
        do {
            try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
        } catch {
            // Task was cancelled
            await recordRecoveryAttempt(
                operationId: operationId,
                error: error as? RealtimeError ?? RealtimeError.internalError(code: -1, description: error.localizedDescription),
                attemptNumber: attemptNumber,
                result: .cancelled
            )
            isRecovering = false
            return
        }
        
        // Attempt the operation
        do {
            _ = try await operation()
            
            // Success - clear retry attempts
            recoveryAttempts.removeValue(forKey: operationId)
            recoveryTasks.removeValue(forKey: operationId)
            
            await recordRecoveryAttempt(
                operationId: operationId,
                error: error,
                attemptNumber: attemptNumber,
                result: .succeeded
            )
            
            onRecoverySucceeded?(error, attemptNumber)
            
        } catch let newError {
            let realtimeError = newError as? RealtimeError ?? RealtimeError.unknown(reason: newError.localizedDescription)
            
            await recordRecoveryAttempt(
                operationId: operationId,
                error: realtimeError,
                attemptNumber: attemptNumber,
                result: .failed
            )
            
            onRecoveryFailed?(realtimeError, attemptNumber)
            
            // Check if we should continue retrying
            if attemptNumber < config.maxRetryAttempts && realtimeError.isRecoverable {
                // Schedule next retry
                let nextRecoveryTask = Task {
                    await performRecovery(
                        error: realtimeError,
                        operation: operation,
                        operationId: operationId,
                        attemptNumber: attemptNumber + 1
                    )
                }
                recoveryTasks[operationId] = nextRecoveryTask
                await nextRecoveryTask.value
            } else {
                // Exhausted retries or error is not recoverable
                recoveryAttempts.removeValue(forKey: operationId)
                recoveryTasks.removeValue(forKey: operationId)
                
                await recordRecoveryAttempt(
                    operationId: operationId,
                    error: realtimeError,
                    attemptNumber: attemptNumber,
                    result: .exhausted
                )
                
                onRecoveryExhausted?(realtimeError, attemptNumber)
            }
        }
        
        // Update recovery state
        isRecovering = !recoveryTasks.isEmpty
    }
    
    private func calculateRetryDelay(baseDelay: TimeInterval, attemptNumber: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(config.exponentialBackoffMultiplier, Double(attemptNumber - 1))
        return min(exponentialDelay, config.maxRetryDelay)
    }
    
    private func recordRecoveryAttempt(
        operationId: String,
        error: RealtimeError,
        attemptNumber: Int,
        result: RecoveryResult,
        retryDelay: TimeInterval? = nil
    ) async {
        let attempt = RecoveryAttempt(
            operationId: operationId,
            error: error,
            attemptNumber: attemptNumber,
            result: result,
            timestamp: Date(),
            retryDelay: retryDelay
        )
        
        recoveryHistory.append(attempt)
        
        // Keep only recent history to prevent memory growth
        if recoveryHistory.count > 1000 {
            recoveryHistory.removeFirst(recoveryHistory.count - 1000)
        }
    }
}

// MARK: - Supporting Types

/// Represents a recovery attempt
public struct RecoveryAttempt: Identifiable, Sendable {
    public let id = UUID()
    public let operationId: String
    public let error: RealtimeError
    public let attemptNumber: Int
    public let result: RecoveryResult
    public let timestamp: Date
    public let retryDelay: TimeInterval?
}

/// Result of a recovery attempt
public enum RecoveryResult: String, CaseIterable, Sendable {
    case started = "started"
    case succeeded = "succeeded"
    case failed = "failed"
    case cancelled = "cancelled"
    case exhausted = "exhausted"
    case notRecoverable = "not_recoverable"
    
    public var displayName: String {
        switch self {
        case .started:
            return "开始恢复"
        case .succeeded:
            return "恢复成功"
        case .failed:
            return "恢复失败"
        case .cancelled:
            return "恢复取消"
        case .exhausted:
            return "重试次数耗尽"
        case .notRecoverable:
            return "不可恢复"
        }
    }
}

/// Recovery statistics for an operation
public struct RecoveryStats: Sendable {
    public let operationId: String
    public let totalAttempts: Int
    public let successfulAttempts: Int
    public let failedAttempts: Int
    public let lastAttempt: Date?
    public let averageRetryDelay: TimeInterval
    
    public var successRate: Double {
        guard totalAttempts > 0 else { return 0.0 }
        return Double(successfulAttempts) / Double(totalAttempts)
    }
}

// MARK: - Error Recovery Extensions

extension RealtimeError {
    
    /// Create an error recovery manager operation for this error
    /// - Parameters:
    ///   - operation: The operation to retry
    ///   - operationId: Unique identifier for the operation
    ///   - recoveryManager: The recovery manager to use
    /// - Returns: True if recovery succeeded, false otherwise
    @MainActor
    public func attemptRecovery<T>(
        operation: @escaping () async throws -> T,
        operationId: String,
        using recoveryManager: ErrorRecoveryManager
    ) async -> Bool {
        return await recoveryManager.attemptRecovery(
            from: self,
            operation: operation,
            operationId: operationId
        )
    }
}