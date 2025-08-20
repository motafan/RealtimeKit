// ErrorRecovery.swift
// Error recovery mechanisms for RealtimeKit

import Foundation

/// Error recovery strategy for different types of errors
public enum ErrorRecoveryStrategy: Sendable {
    case none                           // No recovery possible
    case retry(maxAttempts: Int, delay: TimeInterval)
    case reconnect(maxAttempts: Int, backoffMultiplier: Double)
    case fallback(to: ProviderType)
    case userIntervention(message: String)
    case automatic(strategy: AutoRecoveryStrategy)
}

/// Automatic recovery strategies
public enum AutoRecoveryStrategy: Sendable {
    case exponentialBackoff(baseDelay: TimeInterval, maxDelay: TimeInterval)
    case linearBackoff(delay: TimeInterval)
    case immediateRetry(maxAttempts: Int)
}

/// Error recovery context containing information about the error and recovery attempts
public struct ErrorRecoveryContext: Sendable {
    public let error: RealtimeError
    public let attemptCount: Int
    public let lastAttemptTime: Date
    public let recoveryStrategy: ErrorRecoveryStrategy
    public let metadata: [String: String]
    
    public init(
        error: RealtimeError,
        attemptCount: Int = 0,
        lastAttemptTime: Date = Date(),
        recoveryStrategy: ErrorRecoveryStrategy,
        metadata: [String: String] = [:]
    ) {
        self.error = error
        self.attemptCount = attemptCount
        self.lastAttemptTime = lastAttemptTime
        self.recoveryStrategy = recoveryStrategy
        self.metadata = metadata
    }
    
    /// Whether recovery should be attempted based on the strategy
    public var shouldAttemptRecovery: Bool {
        switch recoveryStrategy {
        case .none, .userIntervention:
            return false
        case .retry(let maxAttempts, _):
            return attemptCount < maxAttempts
        case .reconnect(let maxAttempts, _):
            return attemptCount < maxAttempts
        case .fallback:
            return attemptCount == 0
        case .automatic(let strategy):
            switch strategy {
            case .immediateRetry(let maxAttempts):
                return attemptCount < maxAttempts
            case .exponentialBackoff, .linearBackoff:
                return attemptCount < 5 // Default max attempts for backoff strategies
            }
        }
    }
    
    /// Calculate delay before next recovery attempt
    public var nextAttemptDelay: TimeInterval {
        switch recoveryStrategy {
        case .retry(_, let delay):
            return delay
        case .reconnect(_, let backoffMultiplier):
            return TimeInterval(pow(backoffMultiplier, Double(attemptCount)))
        case .automatic(let strategy):
            switch strategy {
            case .exponentialBackoff(let baseDelay, let maxDelay):
                let delay = baseDelay * pow(2.0, Double(attemptCount))
                return min(delay, maxDelay)
            case .linearBackoff(let delay):
                return delay * Double(attemptCount + 1)
            case .immediateRetry:
                return 0.1 // Small delay to prevent tight loops
            }
        default:
            return 0
        }
    }
}

/// Error recovery manager that handles automatic error recovery
@MainActor
public class ErrorRecoveryManager: ObservableObject {
    @Published public private(set) var activeRecoveries: [String: ErrorRecoveryContext] = [:]
    @Published public private(set) var recoveryHistory: [ErrorRecoveryContext] = []
    
    private var recoveryTasks: [String: Task<Void, Never>] = [:]
    
    /// Register an error for recovery
    public func registerError(
        _ error: RealtimeError,
        identifier: String = UUID().uuidString,
        strategy: ErrorRecoveryStrategy? = nil
    ) async {
        let recoveryStrategy = strategy ?? defaultRecoveryStrategy(for: error)
        let context = ErrorRecoveryContext(
            error: error,
            recoveryStrategy: recoveryStrategy
        )
        
        activeRecoveries[identifier] = context
        
        if context.shouldAttemptRecovery {
            await startRecovery(for: identifier, context: context)
        }
    }
    
    /// Start recovery process for a specific error
    private func startRecovery(for identifier: String, context: ErrorRecoveryContext) async {
        // Cancel any existing recovery task for this identifier
        recoveryTasks[identifier]?.cancel()
        
        recoveryTasks[identifier] = Task {
            await performRecovery(for: identifier, context: context)
        }
    }
    
    /// Perform the actual recovery based on the strategy
    private func performRecovery(for identifier: String, context: ErrorRecoveryContext) async {
        guard !Task.isCancelled else { return }
        
        // Wait for the calculated delay
        let delay = context.nextAttemptDelay
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        guard !Task.isCancelled else { return }
        
        do {
            switch context.recoveryStrategy {
            case .retry:
                try await performRetryRecovery(for: identifier, context: context)
            case .reconnect:
                try await performReconnectRecovery(for: identifier, context: context)
            case .fallback(let providerType):
                try await performFallbackRecovery(to: providerType, for: identifier, context: context)
            case .automatic(let strategy):
                try await performAutomaticRecovery(strategy: strategy, for: identifier, context: context)
            case .none, .userIntervention:
                break // No automatic recovery
            }
        } catch {
            await handleRecoveryFailure(for: identifier, context: context, error: error)
        }
    }
    
    /// Perform retry-based recovery
    private func performRetryRecovery(for identifier: String, context: ErrorRecoveryContext) async throws {
        let updatedContext = ErrorRecoveryContext(
            error: context.error,
            attemptCount: context.attemptCount + 1,
            lastAttemptTime: Date(),
            recoveryStrategy: context.recoveryStrategy,
            metadata: context.metadata
        )
        
        activeRecoveries[identifier] = updatedContext
        
        // Attempt to retry the original operation
        let success = await retryOriginalOperation(for: context.error)
        
        if success {
            await completeRecovery(for: identifier, context: updatedContext)
        } else if updatedContext.shouldAttemptRecovery {
            await startRecovery(for: identifier, context: updatedContext)
        } else {
            await failRecovery(for: identifier, context: updatedContext)
        }
    }
    
    /// Perform reconnection-based recovery
    private func performReconnectRecovery(for identifier: String, context: ErrorRecoveryContext) async throws {
        let updatedContext = ErrorRecoveryContext(
            error: context.error,
            attemptCount: context.attemptCount + 1,
            lastAttemptTime: Date(),
            recoveryStrategy: context.recoveryStrategy,
            metadata: context.metadata
        )
        
        activeRecoveries[identifier] = updatedContext
        
        // Attempt to reconnect
        let success = await attemptReconnection()
        
        if success {
            await completeRecovery(for: identifier, context: updatedContext)
        } else if updatedContext.shouldAttemptRecovery {
            await startRecovery(for: identifier, context: updatedContext)
        } else {
            await failRecovery(for: identifier, context: updatedContext)
        }
    }
    
    /// Perform fallback recovery to another provider
    private func performFallbackRecovery(to providerType: ProviderType, for identifier: String, context: ErrorRecoveryContext) async throws {
        let updatedContext = ErrorRecoveryContext(
            error: context.error,
            attemptCount: context.attemptCount + 1,
            lastAttemptTime: Date(),
            recoveryStrategy: context.recoveryStrategy,
            metadata: context.metadata
        )
        
        activeRecoveries[identifier] = updatedContext
        
        // Attempt to switch to fallback provider
        let success = await switchToFallbackProvider(providerType)
        
        if success {
            await completeRecovery(for: identifier, context: updatedContext)
        } else {
            await failRecovery(for: identifier, context: updatedContext)
        }
    }
    
    /// Perform automatic recovery with specific strategy
    private func performAutomaticRecovery(strategy: AutoRecoveryStrategy, for identifier: String, context: ErrorRecoveryContext) async throws {
        let updatedContext = ErrorRecoveryContext(
            error: context.error,
            attemptCount: context.attemptCount + 1,
            lastAttemptTime: Date(),
            recoveryStrategy: context.recoveryStrategy,
            metadata: context.metadata
        )
        
        activeRecoveries[identifier] = updatedContext
        
        let success = await retryOriginalOperation(for: context.error)
        
        if success {
            await completeRecovery(for: identifier, context: updatedContext)
        } else if updatedContext.shouldAttemptRecovery {
            await startRecovery(for: identifier, context: updatedContext)
        } else {
            await failRecovery(for: identifier, context: updatedContext)
        }
    }
    
    /// Complete successful recovery
    private func completeRecovery(for identifier: String, context: ErrorRecoveryContext) async {
        activeRecoveries.removeValue(forKey: identifier)
        recoveryTasks.removeValue(forKey: identifier)
        recoveryHistory.append(context)
        
        // Notify about successful recovery
        NotificationCenter.default.post(
            name: .errorRecoveryCompleted,
            object: context
        )
    }
    
    /// Handle recovery failure
    private func failRecovery(for identifier: String, context: ErrorRecoveryContext) async {
        activeRecoveries.removeValue(forKey: identifier)
        recoveryTasks.removeValue(forKey: identifier)
        recoveryHistory.append(context)
        
        // Notify about failed recovery
        NotificationCenter.default.post(
            name: .errorRecoveryFailed,
            object: context
        )
    }
    
    /// Handle recovery failure during execution
    private func handleRecoveryFailure(for identifier: String, context: ErrorRecoveryContext, error: Error) async {
        print("Recovery failed for \(identifier): \(error)")
        await failRecovery(for: identifier, context: context)
    }
    
    /// Determine default recovery strategy for an error
    private func defaultRecoveryStrategy(for error: RealtimeError) -> ErrorRecoveryStrategy {
        switch error {
        case .connectionTimeout, .networkError:
            return .automatic(strategy: .exponentialBackoff(baseDelay: 1.0, maxDelay: 30.0))
        case .connectionFailed:
            return .reconnect(maxAttempts: 3, backoffMultiplier: 2.0)
        case .tokenExpired, .tokenRenewalFailed:
            return .retry(maxAttempts: 2, delay: 1.0)
        case .providerNotAvailable:
            return .fallback(to: .mock)
        case .authenticationFailed, .microphonePermissionDenied, .storagePermissionDenied:
            return .userIntervention(message: error.errorDescription ?? "需要用户干预")
        default:
            return .retry(maxAttempts: 1, delay: 0.5)
        }
    }
    
    /// Retry the original operation that caused the error
    private func retryOriginalOperation(for error: RealtimeError) async -> Bool {
        // This would be implemented to retry the specific operation
        // For now, return a simulated result
        return Bool.random()
    }
    
    /// Attempt to reconnect to the service
    private func attemptReconnection() async -> Bool {
        // This would be implemented to attempt reconnection
        // For now, return a simulated result
        return Bool.random()
    }
    
    /// Switch to a fallback provider
    private func switchToFallbackProvider(_ providerType: ProviderType) async -> Bool {
        // This would be implemented to switch providers
        // For now, return a simulated result
        return Bool.random()
    }
    
    /// Cancel all active recoveries
    public func cancelAllRecoveries() {
        for task in recoveryTasks.values {
            task.cancel()
        }
        recoveryTasks.removeAll()
        activeRecoveries.removeAll()
    }
    
    /// Cancel recovery for a specific identifier
    public func cancelRecovery(for identifier: String) {
        recoveryTasks[identifier]?.cancel()
        recoveryTasks.removeValue(forKey: identifier)
        activeRecoveries.removeValue(forKey: identifier)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let errorRecoveryCompleted = Notification.Name("RealtimeKit.errorRecoveryCompleted")
    static let errorRecoveryFailed = Notification.Name("RealtimeKit.errorRecoveryFailed")
    static let errorRecoveryStarted = Notification.Name("RealtimeKit.errorRecoveryStarted")
}