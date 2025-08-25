import Testing
import Foundation
@testable import RealtimeCore

@Suite("Localized Strings Tests")
@MainActor
struct LocalizedStringsTests {
    
    // MARK: - Built-in Strings Tests
    
    @Test("Built-in strings availability")
    func testBuiltInStringsAvailability() async {
        let manager = await createTestManager()
        
        // Verify the manager starts with English
        #expect(manager.currentLanguage == .english, "Manager should start with English, got \(manager.currentLanguage)")
        
        // Test direct access to built-in strings to verify they're loaded correctly
        // Note: LocalizedStrings is internal, so we test through the manager
        
        // Test that built-in strings are loaded through the manager
        let englishString = manager.localizedString(for: "connection.state.connected", language: .english)
        #expect(englishString == "Connected", "Built-in English string should be available, got '\(englishString)'")
        
        await manager.switchLanguage(to: .chineseSimplified)
        let chineseString = manager.localizedString(for: "connection.state.connected")
        #expect(chineseString == "已连接", "Built-in Chinese string should be available")
        
        await manager.switchLanguage(to: .japanese)
        let japaneseString = manager.localizedString(for: "connection.state.connected")
        #expect(japaneseString == "接続済み", "Built-in Japanese string should be available")
    }
    
    @Test("Built-in strings for all languages")
    func testBuiltInStringsForAllLanguages() async {
        let manager = await createTestManager()
        
        let testKey = "user.role.broadcaster"
        let expectedValues: [SupportedLanguage: String] = [
            .english: "Broadcaster",
            .chineseSimplified: "主播",
            .chineseTraditional: "主播",
            .japanese: "配信者",
            .korean: "방송자"
        ]
        
        for (language, expectedValue) in expectedValues {
            await manager.switchLanguage(to: language)
            let actualValue = manager.localizedString(for: testKey)
            #expect(actualValue == expectedValue, "Built-in string for \(language) should match expected value")
        }
    }
    
    @Test("Formatted built-in strings")
    func testFormattedBuiltInStrings() async {
        let manager = await createTestManager()
        
        await manager.switchLanguage(to: .english)
        let englishFormatted = manager.localizedString(for: "audio.volume.mixing", arguments: 75)
        #expect(englishFormatted == "Mixing Volume: 75%", "Formatted English string should work")
        
        await manager.switchLanguage(to: .chineseSimplified)
        let chineseFormatted = manager.localizedString(for: "audio.volume.mixing", arguments: 50)
        #expect(chineseFormatted == "混音音量：50%", "Formatted Chinese string should work")
    }
    
    // MARK: - Language Pack Tests
    
    @Test("Load custom language pack from dictionary")
    func testLoadLanguagePackFromDictionary() async {
        let manager = await createTestManager()
        
        let customPack = [
            "custom.greeting": "Hello World",
            "custom.farewell": "Goodbye"
        ]
        
        manager.loadLanguagePack(customPack, for: .english, merge: true)
        
        // Verify the manager is using English
        #expect(manager.currentLanguage == .english, "Manager should be using English, got \(manager.currentLanguage)")
        
        #expect(manager.localizedString(for: "custom.greeting") == "Hello World")
        #expect(manager.localizedString(for: "custom.farewell") == "Goodbye")
        
        // Test that built-in strings are still available
        let builtInString = manager.localizedString(for: "connection.state.connected")
        #expect(builtInString == "Connected", "Built-in string should be 'Connected', got '\(builtInString)'")
    }
    
    @Test("Load custom language pack with merge vs replace")
    func testLanguagePackMergeVsReplace() async {
        let manager = await createTestManager()
        
        let pack1 = ["key1": "Value1", "key2": "Value2"]
        let pack2 = ["key2": "Updated Value2", "key3": "Value3"]
        
        // Load first pack
        manager.loadLanguagePack(pack1, for: .english, merge: true)
        #expect(manager.localizedString(for: "key1") == "Value1")
        #expect(manager.localizedString(for: "key2") == "Value2")
        
        // Load second pack with merge
        manager.loadLanguagePack(pack2, for: .english, merge: true)
        #expect(manager.localizedString(for: "key1") == "Value1", "key1 should still exist after merge")
        #expect(manager.localizedString(for: "key2") == "Updated Value2", "key2 should be updated")
        #expect(manager.localizedString(for: "key3") == "Value3", "key3 should be added")
        
        // Load third pack with replace
        let pack3 = ["key4": "Value4"]
        manager.loadLanguagePack(pack3, for: .english, merge: false)
        #expect(manager.localizedString(for: "key1") == "key1", "key1 should be gone after replace")
        #expect(manager.localizedString(for: "key4") == "Value4", "key4 should exist after replace")
    }
    
    @Test("Load language pack from JSON data")
    func testLoadLanguagePackFromJSON() async throws {
        let manager = await createTestManager()
        
        let jsonString = """
        {
            "test.json.key1": "JSON Value 1",
            "test.json.key2": "JSON Value 2"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        try manager.loadLanguagePack(from: jsonData, for: .english, merge: true)
        
        #expect(manager.localizedString(for: "test.json.key1") == "JSON Value 1")
        #expect(manager.localizedString(for: "test.json.key2") == "JSON Value 2")
    }
    
    @Test("Load language pack from invalid JSON")
    func testLoadLanguagePackFromInvalidJSON() async {
        let manager = await createTestManager()
        
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        
        do {
            try manager.loadLanguagePack(from: invalidJSON, for: .english, merge: true)
            #expect(Bool(false), "Should throw error for invalid JSON")
        } catch {
            // Expected to throw
            #expect(error is DecodingError, "Should throw DecodingError")
        }
    }
    
    @Test("Export language pack to JSON")
    func testExportLanguagePackToJSON() async throws {
        let manager = await createTestManager()
        
        let customPack = [
            "export.key1": "Export Value 1",
            "export.key2": "Export Value 2"
        ]
        
        manager.loadLanguagePack(customPack, for: .english, merge: true)
        
        let exportedData = try manager.exportLanguagePack(for: .english)
        let exportedString = String(data: exportedData, encoding: .utf8)!
        
        #expect(exportedString.contains("export.key1"), "Exported JSON should contain custom keys")
        #expect(exportedString.contains("Export Value 1"), "Exported JSON should contain custom values")
        
        // Test that exported data can be re-imported
        let newManager = await createTestManager()
        try newManager.loadLanguagePack(from: exportedData, for: .korean, merge: false)
        
        await newManager.switchLanguage(to: .korean)
        #expect(newManager.localizedString(for: "export.key1") == "Export Value 1")
    }
    
    // MARK: - Key Availability Tests
    
    @Test("Check key availability across languages")
    func testCheckKeyAvailability() async {
        let manager = await createTestManager()
        
        // Add custom localization for some languages only
        manager.addCustomLocalization(key: "partial.key", localizations: [
            .english: "English Text",
            .japanese: "日本語テキスト"
        ])
        
        let availability = manager.checkKeyAvailability(for: "partial.key")
        
        #expect(availability[.english] == true, "Should be available in English")
        #expect(availability[.japanese] == true, "Should be available in Japanese")
        #expect(availability[.chineseSimplified] == false, "Should not be available in Chinese Simplified")
        #expect(availability[.korean] == false, "Should not be available in Korean")
    }
    
    @Test("Check built-in key availability")
    func testCheckBuiltInKeyAvailability() async {
        let manager = await createTestManager()
        
        let availability = manager.checkKeyAvailability(for: "connection.state.connected")
        
        // All languages should have this built-in key
        for language in SupportedLanguage.allCases {
            #expect(availability[language] == true, "\(language) should have built-in key")
        }
    }
    
    @Test("Get missing keys for language")
    func testGetMissingKeysForLanguage() async {
        let manager = await createTestManager()
        
        // Add English-only custom localization
        manager.addCustomLocalization(key: "english.only.key", localizations: [
            .english: "English Only"
        ])
        
        let missingKeys = manager.getMissingKeys(for: .korean)
        
        #expect(missingKeys.contains("english.only.key"), "Korean should be missing the English-only key")
        
        // English should have no missing keys compared to itself
        let englishMissingKeys = manager.getMissingKeys(for: .english)
        #expect(englishMissingKeys.isEmpty, "English should have no missing keys compared to itself")
    }
    
    // MARK: - Fallback Mechanism Tests
    
    @Test("Fallback to built-in strings")
    func testFallbackToBuiltInStrings() async {
        let manager = await createTestManager()
        
        // Switch to a language and test fallback
        await manager.switchLanguage(to: .korean)
        
        // This key exists in built-in strings for all languages
        let result = manager.localizedString(for: "connection.state.connected")
        #expect(result == "연결됨", "Should get Korean built-in string")
        
        // Test fallback for non-existent key
        let fallbackResult = manager.localizedString(for: "nonexistent.key")
        #expect(fallbackResult == "nonexistent.key", "Should return key itself when not found")
    }
    
    @Test("Complex fallback scenario")
    func testComplexFallbackScenario() async {
        let manager = await createTestManager()
        
        // Add partial custom localization
        manager.addCustomLocalization(key: "complex.key", localizations: [
            .english: "English Custom",
            .chineseSimplified: "中文自定义"
        ])
        
        // Test different languages
        await manager.switchLanguage(to: .english)
        #expect(manager.localizedString(for: "complex.key") == "English Custom")
        
        await manager.switchLanguage(to: .chineseSimplified)
        #expect(manager.localizedString(for: "complex.key") == "中文自定义")
        
        // Test fallback to English for missing language
        await manager.switchLanguage(to: .japanese)
        #expect(manager.localizedString(for: "complex.key") == "English Custom", "Should fallback to English")
        
        // Test Korean fallback
        await manager.switchLanguage(to: .korean)
        #expect(manager.localizedString(for: "complex.key") == "English Custom", "Should fallback to English")
    }
    
    // MARK: - @RealtimeStorage Integration Tests (需求 18.1)
    
    @Test("Custom language pack persistence with RealtimeStorage")
    func testCustomLanguagePackPersistenceWithRealtimeStorage() async {
        let manager = await createTestManager()
        
        // Enable custom language pack caching
        manager.setCacheCustomLanguagePacks(true)
        
        // Add custom language pack
        let customPack = [
            "persistent.greeting": "Hello from Storage",
            "persistent.farewell": "Goodbye from Storage"
        ]
        
        manager.loadLanguagePack(customPack, for: .english, merge: true)
        
        // Verify strings are available
        #expect(manager.localizedString(for: "persistent.greeting") == "Hello from Storage")
        #expect(manager.localizedString(for: "persistent.farewell") == "Goodbye from Storage")
        
        // Test that the language pack is cached (in real usage, this would persist across app restarts)
        let preferences = manager.getUserPreferences()
        #expect(preferences.cacheCustomLanguagePacks == true, "Caching should be enabled")
    }
    
    @Test("Language pack caching limits with RealtimeStorage")
    func testLanguagePackCachingLimitsWithRealtimeStorage() async {
        let manager = await createTestManager()
        
        // Set a low cache limit
        manager.setMaxCachedLanguagePacks(3)
        manager.setCacheCustomLanguagePacks(true)
        
        // Add multiple language packs
        for i in 1...5 {
            let pack = ["cache.test.\(i)": "Cached Value \(i)"]
            manager.loadLanguagePack(pack, for: .english, merge: true)
        }
        
        // All should be available in memory (the limit applies to persistence)
        for i in 1...5 {
            let value = manager.localizedString(for: "cache.test.\(i)")
            #expect(value == "Cached Value \(i)", "All values should be available in memory")
        }
        
        // Verify cache limit setting
        let preferences = manager.getUserPreferences()
        #expect(preferences.maxCachedLanguagePacks == 3, "Cache limit should be set to 3")
    }
    
    @Test("Disable language pack caching")
    func testDisableLanguagePackCaching() async {
        let manager = await createTestManager()
        
        // Initially enable caching
        manager.setCacheCustomLanguagePacks(true)
        
        // Add a language pack
        let pack = ["cache.disable.test": "Should not be cached"]
        manager.loadLanguagePack(pack, for: .english, merge: true)
        
        // Disable caching
        manager.setCacheCustomLanguagePacks(false)
        
        // Verify caching is disabled
        let preferences = manager.getUserPreferences()
        #expect(preferences.cacheCustomLanguagePacks == false, "Caching should be disabled")
        
        // The string should still be available in memory
        #expect(manager.localizedString(for: "cache.disable.test") == "Should not be cached")
    }
    
    @Test("Custom localization with RealtimeStorage persistence")
    func testCustomLocalizationWithRealtimeStoragePersistence() async {
        let manager = await createTestManager()
        
        // Enable caching
        manager.setCacheCustomLanguagePacks(true)
        
        // Add custom localization
        manager.addCustomLocalization(key: "storage.test.key", localizations: [
            .english: "English Storage Test",
            .japanese: "日本語ストレージテスト",
            .korean: "한국어 저장소 테스트"
        ])
        
        // Test in different languages
        await manager.switchLanguage(to: .english)
        #expect(manager.localizedString(for: "storage.test.key") == "English Storage Test")
        
        await manager.switchLanguage(to: .japanese)
        #expect(manager.localizedString(for: "storage.test.key") == "日本語ストレージテスト")
        
        await manager.switchLanguage(to: .korean)
        #expect(manager.localizedString(for: "storage.test.key") == "한국어 저장소 테스트")
        
        // Remove custom localization
        manager.removeCustomLocalization(key: "storage.test.key")
        
        // Should fallback to key name
        #expect(manager.localizedString(for: "storage.test.key") == "storage.test.key")
    }
    
    @Test("Language pack JSON import/export with persistence")
    func testLanguagePackJSONImportExportWithPersistence() async throws {
        let manager = await createTestManager()
        
        // Enable caching
        manager.setCacheCustomLanguagePacks(true)
        
        // Create a comprehensive language pack
        let languagePack = [
            "json.import.greeting": "Hello from JSON",
            "json.import.farewell": "Goodbye from JSON",
            "json.import.formatted": "User %@ has %d messages"
        ]
        
        // Convert to JSON and import
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(languagePack)
        
        try manager.loadLanguagePack(from: jsonData, for: .english, merge: true)
        
        // Test imported strings
        #expect(manager.localizedString(for: "json.import.greeting") == "Hello from JSON")
        #expect(manager.localizedString(for: "json.import.farewell") == "Goodbye from JSON")
        
        // Test formatted string
        let formatted = manager.localizedString(for: "json.import.formatted", arguments: "John", 5)
        #expect(formatted == "User John has 5 messages")
        
        // Export the language pack
        let exportedData = try manager.exportLanguagePack(for: .english)
        let exportedString = String(data: exportedData, encoding: .utf8)!
        
        // Verify exported content contains our custom strings
        #expect(exportedString.contains("json.import.greeting"), "Exported JSON should contain custom keys")
        #expect(exportedString.contains("Hello from JSON"), "Exported JSON should contain custom values")
    }
    
    // MARK: - Performance Tests
    
    @Test("String retrieval performance")
    func testStringRetrievalPerformance() async {
        let manager = await createTestManager()
        
        let startTime = Date()
        
        // Perform many string retrievals
        for _ in 0..<1000 {
            _ = manager.localizedString(for: "connection.state.connected")
            _ = manager.localizedString(for: "user.role.broadcaster")
            _ = manager.localizedString(for: "audio.microphone.muted")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(duration < 1.0, "String retrieval should be fast (completed in \(duration) seconds)")
    }
    
    @Test("Language pack loading performance")
    func testLanguagePackLoadingPerformance() async {
        let manager = await createTestManager()
        
        // Create a large language pack
        var largePack: [String: String] = [:]
        for i in 0..<1000 {
            largePack["performance.key.\(i)"] = "Performance Value \(i)"
        }
        
        let startTime = Date()
        manager.loadLanguagePack(largePack, for: .english, merge: true)
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 0.5, "Large language pack loading should be fast (completed in \(duration) seconds)")
        
        // Verify a few random keys
        #expect(manager.localizedString(for: "performance.key.0") == "Performance Value 0")
        #expect(manager.localizedString(for: "performance.key.500") == "Performance Value 500")
        #expect(manager.localizedString(for: "performance.key.999") == "Performance Value 999")
    }
    
    // MARK: - Helper Methods
    
    private func createTestManager() async -> LocalizationManager {
        let config = LocalizationConfig(
            autoDetectSystemLanguage: false,
            fallbackLanguage: .english,
            persistLanguageSelection: false
        )
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return await LocalizationManager.createTestInstance(config: config, userDefaults: userDefaults)
    }
}