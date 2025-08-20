// ErrorHandler.swift
// Centralized error handling for RealtimeKit

import Foundation
import Combine

/// Centralized error handler for RealtimeKit
@MainActor
public class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()
    
    @Published public private(set) var recentErrors: [ErrorRecord] = []
    @Published public private(set) var errorStats: ErrorStatistics = ErrorStatistics()
    
    private let recoveryManager = ErrorRecoveryManager()
    private let maxRecentErrors = 50
    private var errorSubscriptions: Set<AnyCancellable> = []
    
    private init() {
        setupErrorRecoveryNotifications()
    }
    
    /// Handle an error with optional recovery
    public func handleError(
        _ error: RealtimeError,
        context: String? = nil,
        enableRecovery: Bool = true,
        userInfo: [String: String] = [:]
    ) async {
        let errorRecord = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date(),
            userInfo: userInfo
        )
        
        // Add to recent errors
        recentErrors.insert(errorRecord, at: 0)
        if recentErrors.count > maxRecentErrors {
            recentErrors.removeLast()
        }
        
        // Update statistics
        updateErrorStatistics(for: error)
        
        // Log the error
        logError(errorRecord)
        
        // Attempt recovery if enabled and error is recoverable
        if enableRecovery && error.isRecoverable {
            await recoveryManager.registerError(
                error,
                identifier: errorRecord.id.uuidString
            )
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: .realtimeErrorOccurred,
            object: errorRecord
        )
    }
    
    /// Handle Swift Error by converting to RealtimeError
    public func handleError(
        _ error: Error,
        context: String? = nil,
        enableRecovery: Bool = true,
        userInfo: [String: String] = [:]
    ) async {
        let realtimeError: RealtimeError
        
        if let rtError = error as? RealtimeError {
            realtimeError = rtError
        } else {
            // Convert generic error to RealtimeError
            realtimeError = .operationFailed(.mock, error.localizedDescription)
        }
        
        await handleError(
            realtimeError,
            context: context,
            enableRecovery: enableRecovery,
            userInfo: userInfo
        )
    }
    
    /// Get errors by category
    public func getErrors(by category: ErrorCategory) -> [ErrorRecord] {
        return recentErrors.filter { $0.error.category == category }
    }
    
    /// Get errors by severity
    public func getErrors(by severity: ErrorSeverity) -> [ErrorRecord] {
        return recentErrors.filter { $0.error.severity == severity }
    }
    
    /// Clear error history
    public func clearErrorHistory() {
        recentErrors.removeAll()
        errorStats = ErrorStatistics()
    }
    
    /// Get error recovery manager
    public var errorRecoveryManager: ErrorRecoveryManager {
        return recoveryManager
    }
    
    // MARK: - Private Methods
    
    private func updateErrorStatistics(for error: RealtimeError) {
        errorStats.totalErrors += 1
        errorStats.errorsByCategory[error.category, default: 0] += 1
        errorStats.errorsBySeverity[error.severity, default: 0] += 1
        
        if error.isRecoverable {
            errorStats.recoverableErrors += 1
        } else {
            errorStats.nonRecoverableErrors += 1
        }
    }
    
    private func logError(_ errorRecord: ErrorRecord) {
        let logLevel = logLevelForSeverity(errorRecord.error.severity)
        let contextString = errorRecord.context.map { " [\($0)]" } ?? ""
        
        print("[\(logLevel)] RealtimeKit Error\(contextString): \(errorRecord.error.errorDescription ?? "Unknown error")")
        
        if !errorRecord.userInfo.isEmpty {
            print("  User Info: \(errorRecord.userInfo)")
        }
        
        if let suggestion = errorRecord.error.recoverySuggestion {
            print("  Suggestion: \(suggestion)")
        }
    }
    
    private func logLevelForSeverity(_ severity: ErrorSeverity) -> String {
        switch severity {
        case .low: return "INFO"
        case .medium: return "WARN"
        case .high: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    private func setupErrorRecoveryNotifications() {
        NotificationCenter.default.publisher(for: .errorRecoveryCompleted)
            .sink { [weak self] notification in
                if let context = notification.object as? ErrorRecoveryContext {
                    Task { @MainActor in
                        self?.handleRecoveryCompleted(context)
                    }
                }
            }
            .store(in: &errorSubscriptions)
        
        NotificationCenter.default.publisher(for: .errorRecoveryFailed)
            .sink { [weak self] notification in
                if let context = notification.object as? ErrorRecoveryContext {
                    Task { @MainActor in
                        self?.handleRecoveryFailed(context)
                    }
                }
            }
            .store(in: &errorSubscriptions)
    }
    
    private func handleRecoveryCompleted(_ context: ErrorRecoveryContext) {
        errorStats.successfulRecoveries += 1
        print("✅ Error recovery completed for: \(context.error.errorCode)")
    }
    
    private func handleRecoveryFailed(_ context: ErrorRecoveryContext) {
        errorStats.failedRecoveries += 1
        print("❌ Error recovery failed for: \(context.error.errorCode)")
    }
}

/// Record of an error occurrence
public struct ErrorRecord: Identifiable, Sendable {
    public let id = UUID()
    public let error: RealtimeError
    public let context: String?
    public let timestamp: Date
    public let userInfo: [String: String] // Changed to String: String for Sendable compliance
    
    public init(
        error: RealtimeError,
        context: String? = nil,
        timestamp: Date = Date(),
        userInfo: [String: String] = [:]
    ) {
        self.error = error
        self.context = context
        self.timestamp = timestamp
        self.userInfo = userInfo
    }
}

/// Error statistics for monitoring and debugging
public struct ErrorStatistics: Sendable {
    public var totalErrors: Int = 0
    public var recoverableErrors: Int = 0
    public var nonRecoverableErrors: Int = 0
    public var successfulRecoveries: Int = 0
    public var failedRecoveries: Int = 0
    public var errorsByCategory: [ErrorCategory: Int] = [:]
    public var errorsBySeverity: [ErrorSeverity: Int] = [:]
    
    /// Recovery success rate
    public var recoverySuccessRate: Double {
        let totalRecoveryAttempts = successfulRecoveries + failedRecoveries
        guard totalRecoveryAttempts > 0 else { return 0.0 }
        return Double(successfulRecoveries) / Double(totalRecoveryAttempts)
    }
    
    /// Most common error category
    public var mostCommonCategory: ErrorCategory? {
        return errorsByCategory.max(by: { $0.value < $1.value })?.key
    }
    
    /// Most common error severity
    public var mostCommonSeverity: ErrorSeverity? {
        return errorsBySeverity.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let realtimeErrorOccurred = Notification.Name("RealtimeKit.errorOccurred")
}

// MARK: - Error Handler Extensions
extension ErrorHandler {
    /// Convenience method for handling connection errors
    public func handleConnectionError(_ error: Error, context: String = "Connection") async {
        let realtimeError: RealtimeError
        
        if error.localizedDescription.contains("timeout") {
            realtimeError = .connectionTimeout
        } else if error.localizedDescription.contains("network") {
            realtimeError = .networkError(error.localizedDescription)
        } else {
            realtimeError = .connectionFailed(error.localizedDescription)
        }
        
        await handleError(realtimeError, context: context)
    }
    
    /// Convenience method for handling authentication errors
    public func handleAuthenticationError(_ error: Error, provider: ProviderType) async {
        let realtimeError: RealtimeError
        
        if error.localizedDescription.contains("token") {
            if error.localizedDescription.contains("expired") {
                realtimeError = .tokenExpired(provider)
            } else {
                realtimeError = .invalidToken(provider)
            }
        } else {
            realtimeError = .authenticationFailed
        }
        
        await handleError(realtimeError, context: "Authentication")
    }
    
    /// Convenience method for handling audio errors
    public func handleAudioError(_ error: Error, context: String = "Audio") async {
        let realtimeError: RealtimeError
        
        if error.localizedDescription.contains("permission") {
            realtimeError = .microphonePermissionDenied
        } else if error.localizedDescription.contains("volume") {
            realtimeError = .volumeControlFailed(error.localizedDescription)
        } else {
            realtimeError = .audioControlFailed(error.localizedDescription)
        }
        
        await handleError(realtimeError, context: context)
    }
}