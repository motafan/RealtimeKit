import Foundation

// MARK: - Supported Languages

/// Enumeration of supported languages for localization
public enum SupportedLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    
    /// Display name of the language in its native form
    public var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chineseSimplified:
            return "简体中文"
        case .chineseTraditional:
            return "繁體中文"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        }
    }
    
    /// Language code for system integration
    public var languageCode: String {
        return rawValue
    }
    
    /// Initialize from system locale identifier
    public init?(from localeIdentifier: String) {
        // Handle common locale variations
        let normalizedIdentifier = localeIdentifier.lowercased()
        
        if normalizedIdentifier.hasPrefix("en") {
            self = .english
        } else if normalizedIdentifier.hasPrefix("zh-hans") || normalizedIdentifier.hasPrefix("zh-cn") {
            self = .chineseSimplified
        } else if normalizedIdentifier.hasPrefix("zh-hant") || normalizedIdentifier.hasPrefix("zh-tw") || normalizedIdentifier.hasPrefix("zh-hk") {
            self = .chineseTraditional
        } else if normalizedIdentifier.hasPrefix("ja") {
            self = .japanese
        } else if normalizedIdentifier.hasPrefix("ko") {
            self = .korean
        } else {
            return nil
        }
    }
}

// MARK: - Localization Configuration

/// Configuration for localization behavior
public struct LocalizationConfig: Sendable {
    /// Whether to automatically detect system language on startup
    public let autoDetectSystemLanguage: Bool
    
    /// Fallback language when requested language is not available
    public let fallbackLanguage: SupportedLanguage
    
    /// Whether to persist language selection
    public let persistLanguageSelection: Bool
    
    /// UserDefaults key for storing language preference
    public let storageKey: String
    
    public init(
        autoDetectSystemLanguage: Bool = true,
        fallbackLanguage: SupportedLanguage = .english,
        persistLanguageSelection: Bool = true,
        storageKey: String = "RealtimeKit.SelectedLanguage"
    ) {
        self.autoDetectSystemLanguage = autoDetectSystemLanguage
        self.fallbackLanguage = fallbackLanguage
        self.persistLanguageSelection = persistLanguageSelection
        self.storageKey = storageKey
    }
    
    public static let `default` = LocalizationConfig()
}

// MARK: - Localization Events

/// Notification for language change events
extension Notification.Name {
    public static let realtimeLanguageDidChange = Notification.Name("RealtimeKit.languageDidChange")
}

/// User info keys for language change notifications
public struct LocalizationNotificationKeys {
    public static let previousLanguage = "previousLanguage"
    public static let currentLanguage = "currentLanguage"
}

// MARK: - User Preferences

/// User preferences for localization behavior
/// 需求: 18.1, 18.2 - 自动状态持久化
public struct LocalizationUserPreferences: Codable, Sendable {
    /// Whether to automatically detect system language changes
    public var autoDetectSystemLanguage: Bool
    
    /// Whether to show language change notifications
    public var showLanguageChangeNotifications: Bool
    
    /// Preferred fallback language when translation is missing
    public var preferredFallbackLanguage: SupportedLanguage
    
    /// Whether to cache custom language packs
    public var cacheCustomLanguagePacks: Bool
    
    /// Maximum number of custom language packs to cache
    public var maxCachedLanguagePacks: Int
    
    /// Last language detection timestamp
    public var lastLanguageDetection: Date?
    
    public init(
        autoDetectSystemLanguage: Bool = true,
        showLanguageChangeNotifications: Bool = true,
        preferredFallbackLanguage: SupportedLanguage = .english,
        cacheCustomLanguagePacks: Bool = true,
        maxCachedLanguagePacks: Int = 10,
        lastLanguageDetection: Date? = nil
    ) {
        self.autoDetectSystemLanguage = autoDetectSystemLanguage
        self.showLanguageChangeNotifications = showLanguageChangeNotifications
        self.preferredFallbackLanguage = preferredFallbackLanguage
        self.cacheCustomLanguagePacks = cacheCustomLanguagePacks
        self.maxCachedLanguagePacks = maxCachedLanguagePacks
        self.lastLanguageDetection = lastLanguageDetection
    }
}