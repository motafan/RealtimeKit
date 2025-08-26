import Foundation

/// Localized error types for RealtimeKit
public enum LocalizedRealtimeError: Error, LocalizedError, CustomStringConvertible {
    
    // MARK: - Network Errors
    case networkUnavailable
    case connectionTimeout
    case connectionFailed(reason: String?)
    
    // MARK: - Permission Errors
    case permissionDenied(permission: String?)
    case insufficientPermissions(role: UserRole)
    case invalidRoleTransition(from: UserRole, to: UserRole)
    
    // MARK: - Configuration Errors
    case invalidConfiguration(details: String?)
    case providerUnavailable(provider: String)
    case invalidToken
    case tokenExpired
    case tokenRenewalFailed(reason: String?)
    
    // MARK: - Session Errors
    case noActiveSession
    case sessionAlreadyActive
    case userAlreadyInRoom
    case roomNotFound(roomId: String)
    case userNotFound(userId: String)
    
    // MARK: - Audio/Video Errors
    case audioDeviceUnavailable
    case microphonePermissionDenied
    case audioStreamFailed(reason: String?)
    case volumeDetectionFailed
    
    // MARK: - Stream Push Errors
    case streamPushNotSupported
    case streamPushConfigurationInvalid
    case streamPushFailed(reason: String?)
    case streamPushAlreadyActive
    
    // MARK: - Media Relay Errors
    case mediaRelayNotSupported
    case mediaRelayConfigurationInvalid
    case mediaRelayFailed(reason: String?)
    case mediaRelayChannelLimitExceeded
    
    // MARK: - Message Processing Errors
    case processorAlreadyRegistered(messageType: String)
    case processorNotFound(messageType: String)
    case messageProcessingFailed(reason: String?)
    case invalidMessageFormat
    
    // MARK: - Localization Errors
    case localizationKeyNotFound(key: String)
    case languagePackLoadFailed(reason: String?)
    case unsupportedLanguage(language: String)
    
    // MARK: - Generic Errors
    case unknown(reason: String?)
    case operationCancelled
    case operationTimeout
    case internalError(code: Int, description: String?)
    
    // MARK: - LocalizedError Protocol
    
    public var errorDescription: String? {
        let description = getLocalizedString(for: localizationKey, arguments: localizationArguments)
        
        // Log error when accessed (for analytics and debugging)
        Task { @MainActor in
            LocalizedErrorManager.shared.logError(self)
        }
        
        return description
    }
    
    public var failureReason: String? {
        let reasonKey = localizationKey + ".reason"
        let localizedReason = getLocalizedString(for: reasonKey, fallbackValue: nil)
        
        // Return localized reason if available, otherwise return nil
        return localizedReason != reasonKey ? localizedReason : nil
    }
    
    public var recoverySuggestion: String? {
        let suggestionKey = localizationKey + ".suggestion"
        let localizedSuggestion = getLocalizedString(for: suggestionKey, fallbackValue: nil)
        
        // Return localized suggestion if available, otherwise return nil
        return localizedSuggestion != suggestionKey ? localizedSuggestion : nil
    }
    
    // MARK: - CustomStringConvertible Protocol
    
    public var description: String {
        return errorDescription ?? "Unknown error"
    }
    
    // MARK: - Private Helper Methods
    
    private func getLocalizedString(for key: String, arguments: [CVarArg] = [], fallbackValue: String? = nil) -> String {
        // Use a synchronous approach to get localized strings for errors
        // This avoids actor isolation issues with the LocalizedError protocol
        return ErrorLocalizationHelper.getLocalizedString(for: key, arguments: arguments, fallbackValue: fallbackValue)
    }
    
    // MARK: - Private Properties
    
    private var localizationKey: String {
        switch self {
        // Network Errors
        case .networkUnavailable:
            return "error.network.unavailable"
        case .connectionTimeout:
            return "error.connection.timeout"
        case .connectionFailed:
            return "error.connection.failed"
            
        // Permission Errors
        case .permissionDenied:
            return "error.permission.denied"
        case .insufficientPermissions:
            return "error.insufficient.permissions"
        case .invalidRoleTransition:
            return "error.invalid.role.transition"
            
        // Configuration Errors
        case .invalidConfiguration:
            return "error.invalid.configuration"
        case .providerUnavailable:
            return "error.provider.unavailable"
        case .invalidToken:
            return "error.invalid.token"
        case .tokenExpired:
            return "error.token.expired"
        case .tokenRenewalFailed:
            return "error.token.renewal.failed"
            
        // Session Errors
        case .noActiveSession:
            return "error.no.active.session"
        case .sessionAlreadyActive:
            return "error.session.already.active"
        case .userAlreadyInRoom:
            return "error.user.already.in.room"
        case .roomNotFound:
            return "error.room.not.found"
        case .userNotFound:
            return "error.user.not.found"
            
        // Audio/Video Errors
        case .audioDeviceUnavailable:
            return "error.audio.device.unavailable"
        case .microphonePermissionDenied:
            return "error.microphone.permission.denied"
        case .audioStreamFailed:
            return "error.audio.stream.failed"
        case .volumeDetectionFailed:
            return "error.volume.detection.failed"
            
        // Stream Push Errors
        case .streamPushNotSupported:
            return "error.stream.push.not.supported"
        case .streamPushConfigurationInvalid:
            return "error.stream.push.configuration.invalid"
        case .streamPushFailed:
            return "error.stream.push.failed"
        case .streamPushAlreadyActive:
            return "error.stream.push.already.active"
            
        // Media Relay Errors
        case .mediaRelayNotSupported:
            return "error.media.relay.not.supported"
        case .mediaRelayConfigurationInvalid:
            return "error.media.relay.configuration.invalid"
        case .mediaRelayFailed:
            return "error.media.relay.failed"
        case .mediaRelayChannelLimitExceeded:
            return "error.media.relay.channel.limit.exceeded"
            
        // Message Processing Errors
        case .processorAlreadyRegistered:
            return "error.processor.already.registered"
        case .processorNotFound:
            return "error.processor.not.found"
        case .messageProcessingFailed:
            return "error.message.processing.failed"
        case .invalidMessageFormat:
            return "error.invalid.message.format"
            
        // Localization Errors
        case .localizationKeyNotFound:
            return "error.localization.key.not.found"
        case .languagePackLoadFailed:
            return "error.language.pack.load.failed"
        case .unsupportedLanguage:
            return "error.unsupported.language"
            
        // Generic Errors
        case .unknown:
            return "error.unknown"
        case .operationCancelled:
            return "error.operation.cancelled"
        case .operationTimeout:
            return "error.operation.timeout"
        case .internalError:
            return "error.internal"
        }
    }
    
    private var localizationArguments: [CVarArg] {
        switch self {
        case .connectionFailed(let reason):
            return reason != nil ? [reason!] : []
        case .permissionDenied(let permission):
            return permission != nil ? [permission!] : []
        case .insufficientPermissions(let role):
            return [role.displayName]
        case .invalidRoleTransition(let from, let to):
            return [from.displayName, to.displayName]
        case .invalidConfiguration(let details):
            return details != nil ? [details!] : []
        case .providerUnavailable(let provider):
            return [provider]
        case .tokenRenewalFailed(let reason):
            return reason != nil ? [reason!] : []
        case .roomNotFound(let roomId):
            return [roomId]
        case .userNotFound(let userId):
            return [userId]
        case .audioStreamFailed(let reason):
            return reason != nil ? [reason!] : []
        case .streamPushFailed(let reason):
            return reason != nil ? [reason!] : []
        case .mediaRelayFailed(let reason):
            return reason != nil ? [reason!] : []
        case .processorAlreadyRegistered(let messageType):
            return [messageType]
        case .processorNotFound(let messageType):
            return [messageType]
        case .messageProcessingFailed(let reason):
            return reason != nil ? [reason!] : []
        case .localizationKeyNotFound(let key):
            return [key]
        case .languagePackLoadFailed(let reason):
            return reason != nil ? [reason!] : []
        case .unsupportedLanguage(let language):
            return [language]
        case .unknown(let reason):
            return reason != nil ? [reason!] : []
        case .internalError(let code, let description):
            return description != nil ? [code, description!] : [code]
        default:
            return []
        }
    }
}

// MARK: - Error Factory

/// Factory for creating localized errors
public struct LocalizedErrorFactory {
    
    /// Create a localized error from a generic error
    /// - Parameter error: The original error
    /// - Returns: A localized RealtimeKit error
    public static func createLocalizedError(from error: Error) -> LocalizedRealtimeError {
        if let localizedError = error as? LocalizedRealtimeError {
            return localizedError
        }
        
        // Map common system errors to localized errors
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return mapURLError(nsError)
            case "AVAudioSessionErrorDomain":
                return mapAudioError(nsError)
            default:
                return .unknown(reason: nsError.localizedDescription)
            }
        }
        
        return .unknown(reason: error.localizedDescription)
    }
    
    private static func mapURLError(_ error: NSError) -> LocalizedRealtimeError {
        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .connectionTimeout
        case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
            return .connectionFailed(reason: error.localizedDescription)
        default:
            return .connectionFailed(reason: error.localizedDescription)
        }
    }
    
    private static func mapAudioError(_ error: NSError) -> LocalizedRealtimeError {
        switch error.code {
        case -50 /* kAudioSessionIncompatibleCategory */:
            return .audioDeviceUnavailable
        default:
            return .audioStreamFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Error Handling Extensions

extension LocalizedRealtimeError {
    
    /// Check if this error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .connectionTimeout, .connectionFailed,
             .tokenExpired, .tokenRenewalFailed,
             .audioDeviceUnavailable, .audioStreamFailed,
             .streamPushFailed, .mediaRelayFailed:
            return true
        case .permissionDenied, .insufficientPermissions, .invalidRoleTransition,
             .invalidConfiguration, .providerUnavailable, .invalidToken,
             .noActiveSession, .sessionAlreadyActive,
             .streamPushNotSupported, .mediaRelayNotSupported,
             .invalidMessageFormat, .unsupportedLanguage:
            return false
        default:
            return false
        }
    }
    
    /// Get suggested retry delay for recoverable errors
    public var retryDelay: TimeInterval? {
        guard isRecoverable else { return nil }
        
        switch self {
        case .networkUnavailable, .connectionTimeout:
            return 5.0
        case .connectionFailed:
            return 3.0
        case .tokenExpired, .tokenRenewalFailed:
            return 1.0
        case .audioDeviceUnavailable, .audioStreamFailed:
            return 2.0
        case .streamPushFailed, .mediaRelayFailed:
            return 5.0
        default:
            return 3.0
        }
    }
    
    /// Get error category for analytics/logging
    public var category: ErrorCategory {
        switch self {
        case .networkUnavailable, .connectionTimeout, .connectionFailed:
            return .network
        case .permissionDenied, .insufficientPermissions, .invalidRoleTransition, .microphonePermissionDenied:
            return .permission
        case .invalidConfiguration, .providerUnavailable, .invalidToken, .tokenExpired, .tokenRenewalFailed:
            return .configuration
        case .noActiveSession, .sessionAlreadyActive, .userAlreadyInRoom, .roomNotFound, .userNotFound:
            return .session
        case .audioDeviceUnavailable, .audioStreamFailed, .volumeDetectionFailed:
            return .audio
        case .streamPushNotSupported, .streamPushConfigurationInvalid, .streamPushFailed, .streamPushAlreadyActive:
            return .streamPush
        case .mediaRelayNotSupported, .mediaRelayConfigurationInvalid, .mediaRelayFailed, .mediaRelayChannelLimitExceeded:
            return .mediaRelay
        case .processorAlreadyRegistered, .processorNotFound, .messageProcessingFailed, .invalidMessageFormat:
            return .messageProcessing
        case .localizationKeyNotFound, .languagePackLoadFailed, .unsupportedLanguage:
            return .localization
        case .unknown, .operationCancelled, .operationTimeout, .internalError:
            return .system
        }
    }
}

// MARK: - Error Display Preferences

/// User preferences for error message display
/// 需求: 17.6, 18.1 - 错误消息显示偏好和持久化
public struct ErrorDisplayPreferences: Codable, Sendable {
    /// Whether to show detailed error messages
    public var showDetailedErrors: Bool
    
    /// Whether to show recovery suggestions
    public var showRecoverySuggestions: Bool
    
    /// Whether to show failure reasons
    public var showFailureReasons: Bool
    
    /// Whether to use localized error messages
    public var useLocalizedMessages: Bool
    
    /// Preferred language for error messages (overrides system language)
    public var preferredErrorLanguage: SupportedLanguage?
    
    /// Whether to log errors for debugging
    public var enableErrorLogging: Bool
    
    /// Maximum number of recent errors to keep in memory
    public var maxRecentErrors: Int
    
    /// Categories of errors to suppress from display
    public var suppressedErrorCategories: Set<ErrorCategory>
    
    public init(
        showDetailedErrors: Bool = true,
        showRecoverySuggestions: Bool = true,
        showFailureReasons: Bool = true,
        useLocalizedMessages: Bool = true,
        preferredErrorLanguage: SupportedLanguage? = nil,
        enableErrorLogging: Bool = true,
        maxRecentErrors: Int = 50,
        suppressedErrorCategories: Set<ErrorCategory> = []
    ) {
        self.showDetailedErrors = showDetailedErrors
        self.showRecoverySuggestions = showRecoverySuggestions
        self.showFailureReasons = showFailureReasons
        self.useLocalizedMessages = useLocalizedMessages
        self.preferredErrorLanguage = preferredErrorLanguage
        self.enableErrorLogging = enableErrorLogging
        self.maxRecentErrors = maxRecentErrors
        self.suppressedErrorCategories = suppressedErrorCategories
    }
}

// MARK: - Error Localization Helper

/// Helper class for synchronous error localization
/// This avoids actor isolation issues with the LocalizedError protocol
/// 需求: 17.1, 17.6, 18.1 - 本地化错误处理和持久化
internal struct ErrorLocalizationHelper {
    
    /// Current language for error localization (atomic)
    private static let _currentLanguageQueue = DispatchQueue(label: "ErrorLocalizationHelper.currentLanguage", attributes: .concurrent)
    private static nonisolated(unsafe) var _currentLanguage: SupportedLanguage = .english
    
    /// Error display preferences (atomic)
    private static let _preferencesQueue = DispatchQueue(label: "ErrorLocalizationHelper.preferences", attributes: .concurrent)
    private static nonisolated(unsafe) var _errorDisplayPreferences: ErrorDisplayPreferences = ErrorDisplayPreferences()
    
    /// Recent errors for debugging and analytics
    private static let _recentErrorsQueue = DispatchQueue(label: "ErrorLocalizationHelper.recentErrors", attributes: .concurrent)
    private static nonisolated(unsafe) var _recentErrors: [LocalizedRealtimeError] = []
    
    /// Update the current language for error localization
    /// 需求: 17.6 - 动态语言切换
    static func updateCurrentLanguage(_ language: SupportedLanguage) {
        _currentLanguageQueue.sync(flags: .barrier) {
            _currentLanguage = language
        }
    }
    
    /// Update error display preferences
    /// 需求: 18.1 - 使用 @RealtimeStorage 持久化错误消息显示偏好
    static func updateErrorDisplayPreferences(_ preferences: ErrorDisplayPreferences) {
        _preferencesQueue.sync(flags: .barrier) {
            _errorDisplayPreferences = preferences
        }
    }
    
    /// Reset to default language (for testing)
    internal static func resetToDefaultLanguage() {
        updateCurrentLanguage(.english)
        updateErrorDisplayPreferences(ErrorDisplayPreferences())
    }
    
    /// Get current language (thread-safe)
    /// 需求: 17.6 - 错误消息的本地化和动态语言切换
    private static func getCurrentLanguage() -> SupportedLanguage {
        return _currentLanguageQueue.sync {
            // Check if user has a preferred error language
            let preferences = getErrorDisplayPreferences()
            return preferences.preferredErrorLanguage ?? _currentLanguage
        }
    }
    
    /// Get error display preferences (thread-safe)
    private static func getErrorDisplayPreferences() -> ErrorDisplayPreferences {
        return _preferencesQueue.sync {
            return _errorDisplayPreferences
        }
    }
    
    /// Log error for debugging and analytics
    /// 需求: 17.6 - 错误处理流程集成
    static func logError(_ error: LocalizedRealtimeError) {
        let preferences = getErrorDisplayPreferences()
        
        guard preferences.enableErrorLogging else { return }
        
        // Don't log suppressed error categories
        guard !preferences.suppressedErrorCategories.contains(error.category) else { return }
        
        _recentErrorsQueue.sync(flags: .barrier) {
            _recentErrors.append(error)
            
            // Keep only the most recent errors
            if _recentErrors.count > preferences.maxRecentErrors {
                _recentErrors.removeFirst(_recentErrors.count - preferences.maxRecentErrors)
            }
        }
        
        // Log to console for debugging
        print("RealtimeKit Error [\(error.category.rawValue)]: \(error.description)")
    }
    
    /// Get recent errors for debugging
    static func getRecentErrors() -> [LocalizedRealtimeError] {
        return _recentErrorsQueue.sync {
            return Array(_recentErrors)
        }
    }
    
    /// Clear recent errors
    static func clearRecentErrors() {
        _recentErrorsQueue.sync(flags: .barrier) {
            _recentErrors.removeAll()
        }
    }
    
    /// Get localized string for error messages (synchronous)
    /// 需求: 17.1, 17.6 - 多语言错误消息和动态语言切换
    static func getLocalizedString(for key: String, arguments: [CVarArg] = [], fallbackValue: String? = nil) -> String {
        let preferences = getErrorDisplayPreferences()
        
        // Return non-localized message if localization is disabled
        guard preferences.useLocalizedMessages else {
            return fallbackValue ?? key
        }
        
        let currentLanguage = getCurrentLanguage()
        
        // Get the localized string from built-in strings
        if let localizedString = getBuiltInString(for: key, language: currentLanguage) {
            if arguments.isEmpty {
                return localizedString
            } else {
                return String(format: localizedString, arguments: arguments)
            }
        }
        
        // Fallback to English if not current language
        if currentLanguage != .english,
           let englishString = getBuiltInString(for: key, language: .english) {
            if arguments.isEmpty {
                return englishString
            } else {
                return String(format: englishString, arguments: arguments)
            }
        }
        
        // Return fallback value or key itself
        return fallbackValue ?? key
    }
    
    /// Get formatted error message with preferences applied
    /// 需求: 17.6 - 错误消息显示偏好
    static func getFormattedErrorMessage(for error: LocalizedRealtimeError) -> String {
        let preferences = getErrorDisplayPreferences()
        
        // Check if this error category is suppressed
        guard !preferences.suppressedErrorCategories.contains(error.category) else {
            return ""
        }
        
        var message = error.errorDescription ?? "Unknown error"
        
        // Add failure reason if enabled and available
        if preferences.showFailureReasons, let failureReason = error.failureReason {
            message += "\n\nReason: \(failureReason)"
        }
        
        // Add recovery suggestion if enabled and available
        if preferences.showRecoverySuggestions, let recoverySuggestion = error.recoverySuggestion {
            message += "\n\nSuggestion: \(recoverySuggestion)"
        }
        
        // Add detailed information if enabled
        if preferences.showDetailedErrors {
            message += "\n\nCategory: \(error.category.rawValue)"
            if error.isRecoverable {
                message += "\nRecoverable: Yes"
                if let retryDelay = error.retryDelay {
                    message += " (retry after \(retryDelay)s)"
                }
            } else {
                message += "\nRecoverable: No"
            }
        }
        
        return message
    }
    
    private static func getBuiltInString(for key: String, language: SupportedLanguage) -> String? {
        // Use NSLocalizedString with appropriate bundle
        let bundle = getBundleForLanguage(language)
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        return localizedString != key ? localizedString : nil
    }
    
    private static func getBundleForLanguage(_ language: SupportedLanguage) -> Bundle {
        let languageCode = language.languageCode
        let bundle = Bundle.module
        
        if let path = bundle.path(forResource: languageCode, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            return localizedBundle
        }
        
        return bundle
    }
}

// MARK: - Error Manager with @RealtimeStorage Integration

/// Error manager that integrates with LocalizationManager and @RealtimeStorage
/// 需求: 17.1, 17.6, 18.1 - 本地化错误处理系统和持久化
@MainActor
public class LocalizedErrorManager: ObservableObject {
    
    /// Singleton instance
    public static let shared = LocalizedErrorManager()
    
    /// Error display preferences with automatic persistence
    /// 需求: 18.1 - 使用 @RealtimeStorage 持久化错误消息显示偏好
    @RealtimeStorage("errorDisplayPreferences", namespace: "RealtimeKit.ErrorHandling")
    public var errorDisplayPreferences: ErrorDisplayPreferences = ErrorDisplayPreferences()
    
    /// Recent errors for display and debugging
    @Published public private(set) var recentErrors: [LocalizedRealtimeError] = []
    
    /// Whether error logging is currently active
    @Published public private(set) var isLoggingActive: Bool = true
    
    private init() {
        // Initialize error localization helper with persisted preferences
        ErrorLocalizationHelper.updateErrorDisplayPreferences(errorDisplayPreferences)
        
        // Set up language change observation
        NotificationCenter.default.addObserver(
            forName: .realtimeLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let currentLanguage = notification.userInfo?[LocalizationNotificationKeys.currentLanguage] as? SupportedLanguage {
                ErrorLocalizationHelper.updateCurrentLanguage(currentLanguage)
                Task { @MainActor in
                    self?.refreshRecentErrors()
                }
            }
        }
        
        // Load recent errors
        refreshRecentErrors()
    }
    
    /// Update error display preferences
    /// 需求: 18.1 - 自动持久化错误消息显示偏好
    public func updateErrorDisplayPreferences(_ preferences: ErrorDisplayPreferences) {
        errorDisplayPreferences = preferences
        ErrorLocalizationHelper.updateErrorDisplayPreferences(preferences)
        isLoggingActive = preferences.enableErrorLogging
        
        // Refresh recent errors with new preferences
        refreshRecentErrors()
    }
    
    /// Log an error with localization and preferences applied
    /// 需求: 17.1, 17.6 - 本地化错误处理和集成
    public func logError(_ error: LocalizedRealtimeError) {
        ErrorLocalizationHelper.logError(error)
        refreshRecentErrors()
    }
    
    /// Get formatted error message for display
    /// 需求: 17.6 - 错误消息显示偏好
    public func getFormattedErrorMessage(for error: LocalizedRealtimeError) -> String {
        return ErrorLocalizationHelper.getFormattedErrorMessage(for: error)
    }
    
    /// Clear all recent errors
    public func clearRecentErrors() {
        ErrorLocalizationHelper.clearRecentErrors()
        recentErrors.removeAll()
    }
    
    /// Enable or disable specific error categories
    /// 需求: 17.6 - 错误类别管理
    public func setErrorCategorySuppressed(_ category: ErrorCategory, suppressed: Bool) {
        var preferences = errorDisplayPreferences
        if suppressed {
            preferences.suppressedErrorCategories.insert(category)
        } else {
            preferences.suppressedErrorCategories.remove(category)
        }
        updateErrorDisplayPreferences(preferences)
    }
    
    /// Check if an error category is suppressed
    public func isErrorCategorySuppressed(_ category: ErrorCategory) -> Bool {
        return errorDisplayPreferences.suppressedErrorCategories.contains(category)
    }
    
    /// Set preferred error language
    /// 需求: 17.6 - 错误消息语言偏好
    public func setPreferredErrorLanguage(_ language: SupportedLanguage?) {
        var preferences = errorDisplayPreferences
        preferences.preferredErrorLanguage = language
        updateErrorDisplayPreferences(preferences)
    }
    
    /// Enable or disable detailed error messages
    public func setShowDetailedErrors(_ enabled: Bool) {
        var preferences = errorDisplayPreferences
        preferences.showDetailedErrors = enabled
        updateErrorDisplayPreferences(preferences)
    }
    
    /// Enable or disable recovery suggestions
    public func setShowRecoverySuggestions(_ enabled: Bool) {
        var preferences = errorDisplayPreferences
        preferences.showRecoverySuggestions = enabled
        updateErrorDisplayPreferences(preferences)
    }
    
    /// Enable or disable failure reasons
    public func setShowFailureReasons(_ enabled: Bool) {
        var preferences = errorDisplayPreferences
        preferences.showFailureReasons = enabled
        updateErrorDisplayPreferences(preferences)
    }
    
    /// Enable or disable error logging
    public func setErrorLoggingEnabled(_ enabled: Bool) {
        var preferences = errorDisplayPreferences
        preferences.enableErrorLogging = enabled
        updateErrorDisplayPreferences(preferences)
    }
    
    /// Set maximum number of recent errors to keep
    public func setMaxRecentErrors(_ maxCount: Int) {
        var preferences = errorDisplayPreferences
        preferences.maxRecentErrors = max(1, maxCount)
        updateErrorDisplayPreferences(preferences)
    }
    
    /// Refresh recent errors from the helper
    private func refreshRecentErrors() {
        recentErrors = ErrorLocalizationHelper.getRecentErrors()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}