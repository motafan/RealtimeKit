import Foundation
import Combine

/// Main localization manager for RealtimeKit
/// Provides centralized language management and localized string access
/// 需求: 17.2, 17.3, 17.5, 18.1, 18.2
@MainActor
public class LocalizationManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = LocalizationManager()
    
    // MARK: - Published Properties
    
    /// Currently selected language
    @Published public private(set) var currentLanguage: SupportedLanguage = .english
    
    /// List of available languages
    @Published public private(set) var availableLanguages: [SupportedLanguage] = SupportedLanguage.allCases
    
    /// Whether the manager is ready for use
    @Published public private(set) var isReady: Bool = false
    
    // MARK: - Persistent Storage Properties (需求 18.1, 18.2)
    
    /// Automatically persisted language preference using @RealtimeStorage
    @RealtimeStorage("selectedLanguage", namespace: "RealtimeKit.Localization")
    private var persistedLanguage: SupportedLanguage = .english
    
    /// Automatically persisted custom language packs using @RealtimeStorage
    @RealtimeStorage("customLanguagePacks", namespace: "RealtimeKit.Localization")
    private var persistedCustomLanguagePacks: [String: [SupportedLanguage: String]] = [:]
    
    /// User preferences for localization behavior
    @RealtimeStorage("localizationPreferences", namespace: "RealtimeKit.Localization")
    private var userPreferences: LocalizationUserPreferences = LocalizationUserPreferences()
    
    // MARK: - Private Properties
    
    private var config: LocalizationConfig
    private var userDefaults: UserDefaults
    private var localizedStrings: [SupportedLanguage: [String: String]] = [:]
    private var customLocalizations: [String: [SupportedLanguage: String]] = [:]
    
    // MARK: - Initialization
    
    internal init(config: LocalizationConfig = .default, userDefaults: UserDefaults = .standard) {
        self.config = config
        self.userDefaults = userDefaults
        
        Task {
            await initialize()
        }
    }
    
    /// Create a test instance (for testing purposes only)
    internal static func createTestInstance(
        config: LocalizationConfig = LocalizationConfig(
            autoDetectSystemLanguage: false,
            fallbackLanguage: .english,
            persistLanguageSelection: false
        ),
        userDefaults: UserDefaults = UserDefaults(suiteName: "test-localization")!
    ) async -> LocalizationManager {
        // Clear any existing language preference
        userDefaults.removeObject(forKey: config.storageKey)
        
        let manager = LocalizationManager(config: config, userDefaults: userDefaults)
        
        // Wait for initialization
        while !manager.isReady {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Force set to English for tests and update error helper
        manager.currentLanguage = .english
        ErrorLocalizationHelper.updateCurrentLanguage(.english)
        
        return manager
    }
    
    /// Initialize the localization manager
    /// 需求: 17.2, 17.3, 17.5, 18.1, 18.2
    private func initialize() async {
        await loadBuiltInLocalizations()
        await loadPersistedCustomLocalizations()
        await detectAndSetInitialLanguage()
        isReady = true
    }
    
    // MARK: - Language Detection and Management
    
    /// Detect system language and set as current if supported
    /// 需求: 17.2, 17.3, 17.5 - 自动语言检测和系统语言适配功能
    private func detectAndSetInitialLanguage() async {
        var targetLanguage: SupportedLanguage = config.fallbackLanguage
        
        // Check for persisted language preference first (using @RealtimeStorage)
        // 需求: 18.1, 18.2 - 使用 @RealtimeStorage 自动持久化当前语言设置
        if config.persistLanguageSelection && persistedLanguage != .english {
            targetLanguage = persistedLanguage
        }
        
        // Auto-detect system language if enabled and user preferences allow it
        if userPreferences.autoDetectSystemLanguage && config.autoDetectSystemLanguage {
            let detectedLanguage = detectSystemLanguage()
            
            // Only use detected language if no persisted preference exists
            if persistedLanguage == .english && detectedLanguage != .english {
                targetLanguage = detectedLanguage
                userPreferences.lastLanguageDetection = Date()
            }
        }
        
        await setLanguage(targetLanguage, notifyObservers: false)
    }
    
    /// Load persisted custom localizations from @RealtimeStorage
    /// 需求: 18.1 - 使用 @RealtimeStorage 缓存和持久化自定义语言包
    private func loadPersistedCustomLocalizations() async {
        customLocalizations = persistedCustomLanguagePacks
    }
    
    /// Detect the system language
    public func detectSystemLanguage() -> SupportedLanguage {
        let systemLocale = Locale.current.identifier
        let preferredLanguages = Locale.preferredLanguages
        
        // Try preferred languages first
        for languageCode in preferredLanguages {
            if let supportedLanguage = SupportedLanguage(from: languageCode) {
                return supportedLanguage
            }
        }
        
        // Fallback to system locale
        if let supportedLanguage = SupportedLanguage(from: systemLocale) {
            return supportedLanguage
        }
        
        // Final fallback
        return config.fallbackLanguage
    }
    
    /// Set the current language
    /// - Parameters:
    ///   - language: The language to set
    ///   - notifyObservers: Whether to post notification about language change
    /// 需求: 17.2, 17.3, 18.1, 18.2 - 语言设置和自动持久化
    public func setLanguage(_ language: SupportedLanguage, notifyObservers: Bool = true) async {
        let previousLanguage = currentLanguage
        
        guard language != previousLanguage else { return }
        
        currentLanguage = language
        
        // Persist language selection using @RealtimeStorage (需求 18.1, 18.2)
        if config.persistLanguageSelection {
            persistedLanguage = language
        }
        
        // Update error localization helper
        ErrorLocalizationHelper.updateCurrentLanguage(language)
        
        // Notify observers if requested and user preferences allow it
        if notifyObservers && userPreferences.showLanguageChangeNotifications {
            NotificationCenter.default.post(
                name: .realtimeLanguageDidChange,
                object: self,
                userInfo: [
                    LocalizationNotificationKeys.previousLanguage: previousLanguage,
                    LocalizationNotificationKeys.currentLanguage: language
                ]
            )
        }
    }
    
    /// Switch to a different language
    /// - Parameter language: The target language
    public func switchLanguage(to language: SupportedLanguage) async {
        await setLanguage(language, notifyObservers: true)
    }
    
    // MARK: - Built-in Localizations
    
    /// Load built-in localization strings
    private func loadBuiltInLocalizations() async {
        localizedStrings = LocalizedStrings.builtInStrings
    }
    
    // MARK: - Custom Localizations
    
    /// Add custom localization for a key
    /// - Parameters:
    ///   - key: The localization key
    ///   - localizations: Dictionary mapping languages to localized strings
    /// 需求: 17.7, 17.8, 18.1 - 开发者自定义语言包支持和自动持久化
    public func addCustomLocalization(key: String, localizations: [SupportedLanguage: String]) {
        customLocalizations[key] = localizations
        
        // Persist custom localizations using @RealtimeStorage (需求 18.1)
        if userPreferences.cacheCustomLanguagePacks {
            persistedCustomLanguagePacks = customLocalizations
        }
    }
    
    /// Remove custom localization for a key
    /// - Parameter key: The localization key to remove
    /// 需求: 17.7, 17.8, 18.1 - 自定义语言包管理和持久化
    public func removeCustomLocalization(key: String) {
        customLocalizations.removeValue(forKey: key)
        
        // Update persisted custom localizations (需求 18.1)
        if userPreferences.cacheCustomLanguagePacks {
            persistedCustomLanguagePacks = customLocalizations
        }
    }
    
    // MARK: - String Retrieval
    
    /// Get localized string for the current language
    /// - Parameters:
    ///   - key: The localization key
    ///   - fallbackValue: Value to return if key is not found
    /// - Returns: Localized string or fallback value
    public func localizedString(for key: String, fallbackValue: String? = nil) -> String {
        return localizedString(for: key, language: currentLanguage, fallbackValue: fallbackValue)
    }
    
    /// Get localized string for a specific language
    /// - Parameters:
    ///   - key: The localization key
    ///   - language: The target language
    ///   - fallbackValue: Value to return if key is not found
    /// - Returns: Localized string or fallback value
    public func localizedString(for key: String, language: SupportedLanguage, fallbackValue: String? = nil) -> String {
        // Check custom localizations first
        if let customLocalizations = customLocalizations[key],
           let localizedString = customLocalizations[language] {
            return localizedString
        }
        
        // Check built-in localizations
        if let builtInLocalizations = localizedStrings[language],
           let localizedString = builtInLocalizations[key] {
            return localizedString
        }
        
        // Fallback to preferred fallback language if not current language
        // 需求: 17.4 - 本地化字符串获取和回退机制
        let fallbackLanguage = userPreferences.preferredFallbackLanguage
        if language != fallbackLanguage {
            // Check custom fallback language localizations first
            if let customLocalizations = customLocalizations[key],
               let fallbackString = customLocalizations[fallbackLanguage] {
                return fallbackString
            }
            
            // Check built-in fallback language localizations
            if let fallbackLocalizations = localizedStrings[fallbackLanguage],
               let fallbackString = fallbackLocalizations[key] {
                return fallbackString
            }
        }
        
        // Final fallback to English if fallback language is not English
        if fallbackLanguage != .english {
            // Check custom English localizations
            if let customLocalizations = customLocalizations[key],
               let englishString = customLocalizations[.english] {
                return englishString
            }
            
            // Check built-in English localizations
            if let englishLocalizations = localizedStrings[.english],
               let englishString = englishLocalizations[key] {
                return englishString
            }
        }
        
        // Return fallback value or key itself
        return fallbackValue ?? key
    }
    
    // MARK: - Formatted Strings
    
    /// Get formatted localized string with parameters
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Arguments for string formatting
    /// - Returns: Formatted localized string
    public func localizedString(for key: String, arguments: CVarArg...) -> String {
        let template = localizedString(for: key)
        return String(format: template, arguments: arguments)
    }
    
    /// Get formatted localized string with parameters for specific language
    /// - Parameters:
    ///   - key: The localization key
    ///   - language: The target language
    ///   - arguments: Arguments for string formatting
    /// - Returns: Formatted localized string
    public func localizedString(for key: String, language: SupportedLanguage, arguments: CVarArg...) -> String {
        let template = localizedString(for: key, language: language)
        return String(format: template, arguments: arguments)
    }
    
    // MARK: - Language Pack Support
    
    /// Load custom language pack from dictionary
    /// - Parameters:
    ///   - languagePack: Dictionary containing localized strings
    ///   - language: Target language for the pack
    ///   - merge: Whether to merge with existing strings or replace them
    /// 需求: 17.7, 17.8, 18.1 - 自定义语言包支持和缓存持久化
    public func loadLanguagePack(_ languagePack: [String: String], for language: SupportedLanguage, merge: Bool = true) {
        if merge {
            var existingStrings = localizedStrings[language] ?? [:]
            for (key, value) in languagePack {
                existingStrings[key] = value
            }
            localizedStrings[language] = existingStrings
        } else {
            localizedStrings[language] = languagePack
        }
        
        // Cache language pack if enabled and within limits (需求 18.1)
        if userPreferences.cacheCustomLanguagePacks {
            // Check cache limits
            if persistedCustomLanguagePacks.count < userPreferences.maxCachedLanguagePacks {
                // Add language pack entries to custom localizations for persistence
                for (key, value) in languagePack {
                    if customLocalizations[key] == nil {
                        customLocalizations[key] = [:]
                    }
                    customLocalizations[key]?[language] = value
                }
                persistedCustomLanguagePacks = customLocalizations
            }
        }
    }
    
    /// Load custom language pack from JSON data
    /// - Parameters:
    ///   - jsonData: JSON data containing localized strings
    ///   - language: Target language for the pack
    ///   - merge: Whether to merge with existing strings or replace them
    /// - Throws: DecodingError if JSON is invalid
    public func loadLanguagePack(from jsonData: Data, for language: SupportedLanguage, merge: Bool = true) throws {
        let decoder = JSONDecoder()
        let languagePack = try decoder.decode([String: String].self, from: jsonData)
        loadLanguagePack(languagePack, for: language, merge: merge)
    }
    
    /// Load custom language pack from file URL
    /// - Parameters:
    ///   - fileURL: URL to JSON file containing localized strings
    ///   - language: Target language for the pack
    ///   - merge: Whether to merge with existing strings or replace them
    /// - Throws: Error if file cannot be read or JSON is invalid
    public func loadLanguagePack(from fileURL: URL, for language: SupportedLanguage, merge: Bool = true) throws {
        let jsonData = try Data(contentsOf: fileURL)
        try loadLanguagePack(from: jsonData, for: language, merge: merge)
    }
    
    /// Export current language pack to JSON data
    /// - Parameter language: Language to export
    /// - Returns: JSON data containing the language pack
    /// - Throws: EncodingError if encoding fails
    public func exportLanguagePack(for language: SupportedLanguage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let languagePack = localizedStrings[language] ?? [:]
        return try encoder.encode(languagePack)
    }
    
    /// Check if a specific key exists in any language
    /// - Parameter key: The localization key to check
    /// - Returns: Dictionary mapping languages to availability
    public func checkKeyAvailability(for key: String) -> [SupportedLanguage: Bool] {
        var availability: [SupportedLanguage: Bool] = [:]
        
        for language in SupportedLanguage.allCases {
            let hasBuiltIn = localizedStrings[language]?[key] != nil
            let hasCustom = customLocalizations[key]?[language] != nil
            availability[language] = hasBuiltIn || hasCustom
        }
        
        return availability
    }
    
    /// Get missing keys for a specific language compared to English
    /// - Parameter language: Language to check
    /// - Returns: Set of keys that exist in English but not in the specified language
    public func getMissingKeys(for language: SupportedLanguage) -> Set<String> {
        guard language != .english else { return [] }
        
        let englishKeys = Set((localizedStrings[.english] ?? [:]).keys)
        let languageKeys = Set((localizedStrings[language] ?? [:]).keys)
        let customEnglishKeys = Set(customLocalizations.compactMap { key, localizations in
            localizations[.english] != nil ? key : nil
        })
        let customLanguageKeys = Set(customLocalizations.compactMap { key, localizations in
            localizations[language] != nil ? key : nil
        })
        
        let allEnglishKeys = englishKeys.union(customEnglishKeys)
        let allLanguageKeys = languageKeys.union(customLanguageKeys)
        
        return allEnglishKeys.subtracting(allLanguageKeys)
    }
    
    // MARK: - Utility Methods
    
    /// Check if a language is supported
    /// - Parameter language: The language to check
    /// - Returns: True if supported, false otherwise
    public func isLanguageSupported(_ language: SupportedLanguage) -> Bool {
        return availableLanguages.contains(language)
    }
    
    /// Get all available localization keys
    /// - Returns: Set of all available keys
    public func getAllLocalizationKeys() -> Set<String> {
        var allKeys = Set<String>()
        
        // Add built-in keys
        for languageStrings in localizedStrings.values {
            allKeys.formUnion(Set(languageStrings.keys))
        }
        
        // Add custom keys
        allKeys.formUnion(Set(customLocalizations.keys))
        
        return allKeys
    }
    
    /// Reset to default language
    public func resetToDefaultLanguage() async {
        await setLanguage(config.fallbackLanguage)
    }
    
    /// Clear all custom localizations
    /// 需求: 17.7, 18.1 - 自定义语言包管理和持久化清理
    public func clearCustomLocalizations() {
        customLocalizations.removeAll()
        
        // Clear persisted custom localizations (需求 18.1)
        persistedCustomLanguagePacks.removeAll()
    }
    
    // MARK: - User Preferences Management
    
    /// Update user preferences for localization behavior
    /// 需求: 18.1, 18.2 - 用户偏好自动持久化
    public func updateUserPreferences(_ preferences: LocalizationUserPreferences) {
        userPreferences = preferences
    }
    
    /// Get current user preferences
    /// 需求: 18.1, 18.2 - 用户偏好访问
    public func getUserPreferences() -> LocalizationUserPreferences {
        return userPreferences
    }
    
    /// Enable or disable automatic system language detection
    /// 需求: 17.2, 17.3, 18.1 - 自动语言检测配置
    public func setAutoDetectSystemLanguage(_ enabled: Bool) {
        userPreferences.autoDetectSystemLanguage = enabled
        
        if enabled {
            Task {
                let detectedLanguage = detectSystemLanguage()
                if detectedLanguage != currentLanguage {
                    await setLanguage(detectedLanguage)
                }
            }
        }
    }
    
    /// Set preferred fallback language
    /// 需求: 17.4, 18.1 - 回退语言配置和持久化
    public func setPreferredFallbackLanguage(_ language: SupportedLanguage) {
        userPreferences.preferredFallbackLanguage = language
    }
    
    /// Enable or disable language change notifications
    /// 需求: 17.6, 18.1 - 通知配置和持久化
    public func setShowLanguageChangeNotifications(_ enabled: Bool) {
        userPreferences.showLanguageChangeNotifications = enabled
    }
    
    /// Enable or disable custom language pack caching
    /// 需求: 18.1 - 缓存配置和持久化
    public func setCacheCustomLanguagePacks(_ enabled: Bool) {
        userPreferences.cacheCustomLanguagePacks = enabled
        
        if !enabled {
            // Clear cached language packs if caching is disabled
            persistedCustomLanguagePacks.removeAll()
        }
    }
    
    /// Set maximum number of cached language packs
    /// 需求: 18.1 - 缓存限制配置
    public func setMaxCachedLanguagePacks(_ maxCount: Int) {
        userPreferences.maxCachedLanguagePacks = max(1, maxCount)
        
        // Trim cached language packs if necessary
        if persistedCustomLanguagePacks.count > maxCount {
            let keysToRemove = Array(persistedCustomLanguagePacks.keys.prefix(persistedCustomLanguagePacks.count - maxCount))
            for key in keysToRemove {
                persistedCustomLanguagePacks.removeValue(forKey: key)
                customLocalizations.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension LocalizationManager {
    
    /// Subscript access to localized strings
    public subscript(key: String) -> String {
        return localizedString(for: key)
    }
    
    /// Subscript access with fallback value
    public subscript(key: String, fallback fallbackValue: String) -> String {
        return localizedString(for: key, fallbackValue: fallbackValue)
    }
}