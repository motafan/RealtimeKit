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
        return getLocalizedString(for: localizationKey, arguments: localizationArguments)
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
            return .system
        case .unknown, .operationCancelled, .operationTimeout, .internalError:
            return .system
        }
    }
}



// MARK: - Error Localization Helper

/// Helper class for synchronous error localization
/// This avoids actor isolation issues with the LocalizedError protocol
internal struct ErrorLocalizationHelper {
    
    /// Current language for error localization (atomic)
    private static let _currentLanguageQueue = DispatchQueue(label: "ErrorLocalizationHelper.currentLanguage", attributes: .concurrent)
    private static nonisolated(unsafe) var _currentLanguage: SupportedLanguage = .english
    
    /// Update the current language for error localization
    static func updateCurrentLanguage(_ language: SupportedLanguage) {
        _currentLanguageQueue.sync(flags: .barrier) {
            _currentLanguage = language
        }
    }
    
    /// Reset to default language (for testing)
    internal static func resetToDefaultLanguage() {
        updateCurrentLanguage(.english)
    }
    
    /// Get current language (thread-safe)
    private static func getCurrentLanguage() -> SupportedLanguage {
        return _currentLanguageQueue.sync {
            return _currentLanguage
        }
    }
    
    /// Get localized string for error messages (synchronous)
    static func getLocalizedString(for key: String, arguments: [CVarArg] = [], fallbackValue: String? = nil) -> String {
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
    
    private static func getBuiltInString(for key: String, language: SupportedLanguage) -> String? {
        return LocalizedStrings.builtInStrings[language]?[key]
    }
}