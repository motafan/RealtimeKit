import Testing
import Foundation
@testable import RealtimeCore

/// Integration tests for localized UI components functionality
/// These tests focus on the core localization logic without platform-specific UI dependencies
@Suite("Localized UI Components Integration Tests")
@MainActor
struct LocalizedUIComponentsIntegrationTests {
    
    // MARK: - Notification System Tests
    
    @Test("Language change notification system")
    func testLanguageChangeNotificationSystem() async {
        let manager = await createTestManager()
        
        // Use a simpler approach - just test that notifications are sent
        var notificationReceived = false
        
        // Set up notification observer
        let observer = NotificationCenter.default.addObserver(
            forName: .realtimeLanguageDidChange,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                notificationReceived = true
            }
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Switch language
        await manager.switchLanguage(to: .chineseSimplified)
        
        // Give notification time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(notificationReceived, "Language change notification should be sent")
        #expect(manager.currentLanguage == .chineseSimplified, "Current language should be Chinese Simplified")
    }
    
    @Test("Multiple language change notifications")
    func testMultipleLanguageChangeNotifications() async {
        let manager = await createTestManager()
        
        var notificationCount = 0
        
        let observer = NotificationCenter.default.addObserver(
            forName: .realtimeLanguageDidChange,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                notificationCount += 1
            }
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Switch through multiple languages
        let languages: [SupportedLanguage] = [.chineseSimplified, .japanese, .korean]
        
        for language in languages {
            await manager.switchLanguage(to: language)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        #expect(notificationCount >= languages.count, "Should receive at least one notification for each language change")
        #expect(manager.currentLanguage == .korean, "Final language should be Korean")
    }
    
    // MARK: - UI Component Logic Tests
    
    @Test("Localized string retrieval for UI components")
    func testLocalizedStringRetrievalForUIComponents() async {
        let manager = await createTestManager()
        
        // Test common UI strings
        await manager.switchLanguage(to: .english)
        
        let buttonOK = manager.localizedString(for: "button.ok")
        let buttonCancel = manager.localizedString(for: "button.cancel")
        let connectionConnected = manager.localizedString(for: "connection.state.connected")
        let audioSettings = manager.localizedString(for: "settings.audio")
        
        #expect(buttonOK == "OK", "OK button should be localized correctly")
        #expect(buttonCancel == "Cancel", "Cancel button should be localized correctly")
        #expect(connectionConnected == "Connected", "Connection state should be localized correctly")
        #expect(audioSettings == "Audio Settings", "Audio settings should be localized correctly")
        
        // Test Chinese localization
        await manager.switchLanguage(to: .chineseSimplified)
        
        let buttonOKChinese = manager.localizedString(for: "button.ok")
        let buttonCancelChinese = manager.localizedString(for: "button.cancel")
        let connectionConnectedChinese = manager.localizedString(for: "connection.state.connected")
        let audioSettingsChinese = manager.localizedString(for: "settings.audio")
        
        #expect(buttonOKChinese == "确定", "OK button should be localized to Chinese")
        #expect(buttonCancelChinese == "取消", "Cancel button should be localized to Chinese")
        #expect(connectionConnectedChinese == "已连接", "Connection state should be localized to Chinese")
        #expect(audioSettingsChinese == "音频设置", "Audio settings should be localized to Chinese")
    }
    
    @Test("Formatted localized strings for UI components")
    func testFormattedLocalizedStringsForUIComponents() async {
        let manager = await createTestManager()
        
        await manager.switchLanguage(to: .english)
        
        // Test formatted strings commonly used in UI
        let volumeString = manager.localizedString(for: "audio.volume.mixing", arguments: 75)
        let userCountString = manager.localizedString(for: "room.user.count", arguments: 5)
        let connectionTimeString = manager.localizedString(for: "connection.duration", arguments: 120)
        
        #expect(volumeString == "Mixing Volume: 75%", "Volume string should be formatted correctly")
        #expect(userCountString == "Users: 5", "User count should be formatted correctly")
        #expect(connectionTimeString == "Connected for 120 seconds", "Connection time should be formatted correctly")
        
        // Test Chinese formatting
        await manager.switchLanguage(to: .chineseSimplified)
        
        let volumeStringChinese = manager.localizedString(for: "audio.volume.mixing", arguments: 75)
        let userCountStringChinese = manager.localizedString(for: "room.user.count", arguments: 5)
        
        #expect(volumeStringChinese == "混音音量：75%", "Chinese volume string should be formatted correctly")
        #expect(userCountStringChinese == "用户数：5", "Chinese user count should be formatted correctly")
    }
    
    @Test("Fallback behavior for UI components")
    func testFallbackBehaviorForUIComponents() async {
        let manager = await createTestManager()
        
        await manager.switchLanguage(to: .korean)
        
        // Test fallback to English for missing keys
        let missingKey = manager.localizedString(for: "nonexistent.ui.key")
        let missingKeyWithFallback = manager.localizedString(for: "nonexistent.ui.key", fallbackValue: "Default UI Text")
        
        #expect(missingKey == "nonexistent.ui.key", "Missing key should return the key itself")
        #expect(missingKeyWithFallback == "Default UI Text", "Missing key should use fallback value")
        
        // Test partial fallback (key exists in English but not Korean)
        // Use a key that exists in English but not in Korean
        let partialFallback = manager.localizedString(for: "test.english.only")
        #expect(partialFallback == "English Only Text", "Should fallback to English when Korean is not available")
    }
    
    // MARK: - UI Update Simulation Tests
    
    @Test("Simulated UI component update on language change")
    func testSimulatedUIComponentUpdateOnLanguageChange() async {
        let manager = await createTestManager()
        
        // Simulate UI component state
        struct MockUIComponent {
            var text: String = ""
            var localizationKey: String = ""
            
            @MainActor
            mutating func setLocalizedText(_ key: String, manager: LocalizationManager) {
                self.localizationKey = key
                self.text = manager.localizedString(for: key)
            }
            
            @MainActor
            mutating func updateForLanguageChange(manager: LocalizationManager) {
                if !localizationKey.isEmpty {
                    self.text = manager.localizedString(for: localizationKey)
                }
            }
        }
        
        var mockLabel = MockUIComponent()
        var mockButton = MockUIComponent()
        
        // Set initial localized content
        await manager.switchLanguage(to: .english)
        mockLabel.setLocalizedText("connection.state.connected", manager: manager)
        mockButton.setLocalizedText("button.ok", manager: manager)
        
        #expect(mockLabel.text == "Connected", "Mock label should show English text")
        #expect(mockButton.text == "OK", "Mock button should show English text")
        
        // Simulate language change
        await manager.switchLanguage(to: .chineseSimplified)
        mockLabel.updateForLanguageChange(manager: manager)
        mockButton.updateForLanguageChange(manager: manager)
        
        #expect(mockLabel.text == "已连接", "Mock label should update to Chinese text")
        #expect(mockButton.text == "确定", "Mock button should update to Chinese text")
    }
    
    @Test("Simulated UI component with arguments update")
    func testSimulatedUIComponentWithArgumentsUpdate() async {
        let manager = await createTestManager()
        
        // Simulate UI component with formatted text
        struct MockFormattedComponent {
            var text: String = ""
            var localizationKey: String = ""
            var arguments: [CVarArg] = []
            
            @MainActor
            mutating func setLocalizedText(_ key: String, arguments: CVarArg..., manager: LocalizationManager) {
                self.localizationKey = key
                self.arguments = arguments
                // Use the template and format manually to handle array of arguments
                let template = manager.localizedString(for: key)
                if arguments.isEmpty {
                    self.text = template
                } else {
                    self.text = String(format: template, arguments: arguments)
                }
            }
            
            @MainActor
            mutating func updateForLanguageChange(manager: LocalizationManager) {
                if !localizationKey.isEmpty {
                    let template = manager.localizedString(for: localizationKey)
                    if arguments.isEmpty {
                        self.text = template
                    } else {
                        self.text = String(format: template, arguments: arguments)
                    }
                }
            }
        }
        
        var mockVolumeLabel = MockFormattedComponent()
        
        // Set initial content
        await manager.switchLanguage(to: .english)
        let englishText = manager.localizedString(for: "audio.volume.mixing", arguments: 85)
        mockVolumeLabel.localizationKey = "audio.volume.mixing"
        mockVolumeLabel.arguments = [85]
        mockVolumeLabel.text = englishText
        
        #expect(mockVolumeLabel.text == "Mixing Volume: 85%", "Mock volume label should show English formatted text")
        
        // Change language
        await manager.switchLanguage(to: .chineseSimplified)
        let chineseText = manager.localizedString(for: "audio.volume.mixing", arguments: 85)
        mockVolumeLabel.text = chineseText
        
        #expect(mockVolumeLabel.text == "混音音量：85%", "Mock volume label should update to Chinese formatted text")
    }
    
    // MARK: - Performance Tests
    
    @Test("UI component localization performance")
    func testUIComponentLocalizationPerformance() async {
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate updating many UI components
        for i in 0..<1000 {
            let _ = manager.localizedString(for: "button.ok")
            let _ = manager.localizedString(for: "button.cancel")
            let _ = manager.localizedString(for: "connection.state.connected")
            let _ = manager.localizedString(for: "audio.volume.mixing", arguments: i % 100)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(duration < 1.0, "Localizing 4000 strings should take less than 1 second")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("UI component error handling")
    func testUIComponentErrorHandling() async {
        let manager = await createTestManager()
        
        // Test with invalid keys
        let invalidKey = manager.localizedString(for: "")
        let nilKey = manager.localizedString(for: "nil.key")
        
        #expect(invalidKey == "", "Empty key should return empty string")
        #expect(nilKey == "nil.key", "Invalid key should return the key itself")
        
        // Test with special characters
        let specialKey = manager.localizedString(for: "special.key.with.@#$%")
        #expect(specialKey == "special.key.with.@#$%", "Special character key should return the key itself")
    }
    
    // MARK: - Accessibility Tests
    
    @Test("Accessibility localization support")
    func testAccessibilityLocalizationSupport() async {
        let manager = await createTestManager()
        
        await manager.switchLanguage(to: .english)
        
        // Test accessibility strings
        let accessibilityLabel = manager.localizedString(for: "accessibility.button.ok")
        let accessibilityHint = manager.localizedString(for: "accessibility.hint.tap.to.confirm")
        
        #expect(accessibilityLabel == "OK Button", "Accessibility label should be localized")
        #expect(accessibilityHint == "Tap to confirm your selection", "Accessibility hint should be localized")
        
        // Test Chinese accessibility
        await manager.switchLanguage(to: .chineseSimplified)
        
        let accessibilityLabelChinese = manager.localizedString(for: "accessibility.button.ok")
        let accessibilityHintChinese = manager.localizedString(for: "accessibility.hint.tap.to.confirm")
        
        #expect(accessibilityLabelChinese == "确定按钮", "Chinese accessibility label should be localized")
        #expect(accessibilityHintChinese == "点击确认您的选择", "Chinese accessibility hint should be localized")
    }
    
    // MARK: - Helper Methods
    
    private func createTestManager() async -> LocalizationManager {
        return await LocalizationManager.createTestInstance()
    }
}

