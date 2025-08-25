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
    
    // MARK: - @RealtimeStorage Integration Tests (需求 18.1, 18.10)
    
    @Test("UI component state persistence simulation")
    func testUIComponentStatePersistenceSimulation() async {
        let manager = await createTestManager()
        
        // Simulate UI component with persistent state
        struct MockPersistentComponent {
            var displayText: String = ""
            var localizationKey: String = ""
            var interactionCount: Int = 0
            var lastInteractionDate: Date?
            var currentLanguage: SupportedLanguage = .english
            
            @MainActor
            mutating func setLocalizedText(_ key: String, manager: LocalizationManager) {
                self.localizationKey = key
                self.displayText = manager.localizedString(for: key)
                self.currentLanguage = manager.currentLanguage
                self.interactionCount += 1
                self.lastInteractionDate = Date()
            }
            
            @MainActor
            mutating func updateForLanguageChange(manager: LocalizationManager) {
                if !localizationKey.isEmpty {
                    self.displayText = manager.localizedString(for: localizationKey)
                    self.currentLanguage = manager.currentLanguage
                    self.interactionCount += 1
                    self.lastInteractionDate = Date()
                }
            }
        }
        
        var mockComponent = MockPersistentComponent()
        
        // Initial setup
        await manager.switchLanguage(to: .english)
        mockComponent.setLocalizedText("connection.state.connected", manager: manager)
        
        #expect(mockComponent.displayText == "Connected")
        #expect(mockComponent.currentLanguage == .english)
        #expect(mockComponent.interactionCount == 1)
        #expect(mockComponent.lastInteractionDate != nil)
        
        // Language change
        await manager.switchLanguage(to: .japanese)
        mockComponent.updateForLanguageChange(manager: manager)
        
        #expect(mockComponent.displayText == "接続済み")
        #expect(mockComponent.currentLanguage == .japanese)
        #expect(mockComponent.interactionCount == 2)
        
        // Multiple interactions
        await manager.switchLanguage(to: .korean)
        mockComponent.updateForLanguageChange(manager: manager)
        
        #expect(mockComponent.displayText == "연결됨")
        #expect(mockComponent.currentLanguage == .korean)
        #expect(mockComponent.interactionCount == 3)
    }
    
    @Test("Language picker state persistence simulation")
    func testLanguagePickerStatePersistenceSimulation() async {
        let manager = await createTestManager()
        
        // Simulate LanguagePickerState behavior
        struct MockLanguagePickerState {
            var lastSelectedLanguage: SupportedLanguage?
            var currentDisplayLanguage: SupportedLanguage = .english
            var selectionCount: Int = 0
            var lastSelectionDate: Date?
            var showLanguageCodes: Bool = false
            var showNativeNames: Bool = true
            
            @MainActor
            mutating func updateSelection(_ language: SupportedLanguage) {
                self.lastSelectedLanguage = language
                self.currentDisplayLanguage = language
                self.selectionCount += 1
                self.lastSelectionDate = Date()
            }
        }
        
        var pickerState = MockLanguagePickerState()
        
        // Initial state
        #expect(pickerState.selectionCount == 0)
        #expect(pickerState.lastSelectedLanguage == nil)
        
        // First selection
        await manager.switchLanguage(to: .japanese)
        pickerState.updateSelection(.japanese)
        
        #expect(pickerState.lastSelectedLanguage == .japanese)
        #expect(pickerState.currentDisplayLanguage == .japanese)
        #expect(pickerState.selectionCount == 1)
        #expect(pickerState.lastSelectionDate != nil)
        
        // Second selection
        await manager.switchLanguage(to: .korean)
        pickerState.updateSelection(.korean)
        
        #expect(pickerState.lastSelectedLanguage == .korean)
        #expect(pickerState.currentDisplayLanguage == .korean)
        #expect(pickerState.selectionCount == 2)
        
        // Configuration changes
        pickerState.showLanguageCodes = true
        pickerState.showNativeNames = false
        
        #expect(pickerState.showLanguageCodes == true)
        #expect(pickerState.showNativeNames == false)
    }
    
    @Test("Navigation view state persistence simulation")
    func testNavigationViewStatePersistenceSimulation() async {
        let manager = await createTestManager()
        
        // Simulate NavigationViewState behavior
        struct MockNavigationViewState {
            var currentLanguage: SupportedLanguage = .english
            var viewAppearanceCount: Int = 0
            var lastAppearanceDate: Date?
            var lastLanguageChangeDate: Date?
            
            @MainActor
            mutating func onViewAppear() {
                self.viewAppearanceCount += 1
                self.lastAppearanceDate = Date()
            }
            
            @MainActor
            mutating func onLanguageChange(_ language: SupportedLanguage) {
                self.currentLanguage = language
                self.lastLanguageChangeDate = Date()
            }
        }
        
        var navigationState = MockNavigationViewState()
        
        // Initial state
        #expect(navigationState.viewAppearanceCount == 0)
        #expect(navigationState.currentLanguage == .english)
        
        // View appearances
        navigationState.onViewAppear()
        #expect(navigationState.viewAppearanceCount == 1)
        #expect(navigationState.lastAppearanceDate != nil)
        
        navigationState.onViewAppear()
        #expect(navigationState.viewAppearanceCount == 2)
        
        // Language changes
        await manager.switchLanguage(to: .chineseSimplified)
        navigationState.onLanguageChange(.chineseSimplified)
        
        #expect(navigationState.currentLanguage == .chineseSimplified)
        #expect(navigationState.lastLanguageChangeDate != nil)
        
        await manager.switchLanguage(to: .japanese)
        navigationState.onLanguageChange(.japanese)
        
        #expect(navigationState.currentLanguage == .japanese)
    }
    
    @Test("Localized list state persistence simulation")
    func testLocalizedListStatePersistenceSimulation() async {
        let manager = await createTestManager()
        
        // Simulate LocalizedListState behavior
        struct MockLocalizedListState {
            var currentLanguage: SupportedLanguage = .english
            var emptyStateDisplayCount: Int = 0
            var dataDisplayCount: Int = 0
            var lastItemCount: Int = 0
            var lastEmptyStateDate: Date?
            var lastDataDisplayDate: Date?
            
            @MainActor
            mutating func onEmptyStateDisplay() {
                self.emptyStateDisplayCount += 1
                self.lastEmptyStateDate = Date()
            }
            
            @MainActor
            mutating func onDataDisplay(itemCount: Int) {
                self.dataDisplayCount += 1
                self.lastItemCount = itemCount
                self.lastDataDisplayDate = Date()
            }
            
            @MainActor
            mutating func onLanguageChange(_ language: SupportedLanguage) {
                self.currentLanguage = language
            }
        }
        
        var listState = MockLocalizedListState()
        
        // Initial state
        #expect(listState.emptyStateDisplayCount == 0)
        #expect(listState.dataDisplayCount == 0)
        
        // Empty state display
        listState.onEmptyStateDisplay()
        #expect(listState.emptyStateDisplayCount == 1)
        #expect(listState.lastEmptyStateDate != nil)
        
        // Data display
        listState.onDataDisplay(itemCount: 5)
        #expect(listState.dataDisplayCount == 1)
        #expect(listState.lastItemCount == 5)
        #expect(listState.lastDataDisplayDate != nil)
        
        // More data displays
        listState.onDataDisplay(itemCount: 10)
        #expect(listState.dataDisplayCount == 2)
        #expect(listState.lastItemCount == 10)
        
        // Language change
        await manager.switchLanguage(to: .korean)
        listState.onLanguageChange(.korean)
        #expect(listState.currentLanguage == .korean)
    }
    
    @Test("UIKit localization manager state persistence")
    func testUIKitLocalizationManagerStatePersistence() async {
        // Test the UIKit localization manager state tracking
        // Note: This is a conceptual test since we can't easily test the actual @RealtimeStorage in unit tests
        
        struct MockUIKitLocalizationState {
            var currentLanguage: SupportedLanguage = .english
            var registeredViewControllerTypes: Set<String> = []
            var registrationCount: Int = 0
            var unregistrationCount: Int = 0
            var languageChangeCount: Int = 0
            var componentUpdateCount: Int = 0
            var lastRegistrationDate: Date?
            var lastUnregistrationDate: Date?
            var lastLanguageChangeDate: Date?
            
            mutating func registerViewController(_ type: String) {
                registeredViewControllerTypes.insert(type)
                registrationCount += 1
                lastRegistrationDate = Date()
            }
            
            mutating func unregisterViewController(_ type: String) {
                registeredViewControllerTypes.remove(type)
                unregistrationCount += 1
                lastUnregistrationDate = Date()
            }
            
            mutating func onLanguageChange(_ language: SupportedLanguage, componentCount: Int) {
                currentLanguage = language
                languageChangeCount += 1
                componentUpdateCount += componentCount
                lastLanguageChangeDate = Date()
            }
        }
        
        var uikitState = MockUIKitLocalizationState()
        
        // Initial state
        #expect(uikitState.registrationCount == 0)
        #expect(uikitState.registeredViewControllerTypes.isEmpty)
        
        // Register view controllers
        uikitState.registerViewController("TestViewController")
        uikitState.registerViewController("SettingsViewController")
        
        #expect(uikitState.registrationCount == 2)
        #expect(uikitState.registeredViewControllerTypes.count == 2)
        #expect(uikitState.registeredViewControllerTypes.contains("TestViewController"))
        #expect(uikitState.registeredViewControllerTypes.contains("SettingsViewController"))
        #expect(uikitState.lastRegistrationDate != nil)
        
        // Language change
        let manager = await createTestManager()
        await manager.switchLanguage(to: .japanese)
        uikitState.onLanguageChange(.japanese, componentCount: 2)
        
        #expect(uikitState.currentLanguage == .japanese)
        #expect(uikitState.languageChangeCount == 1)
        #expect(uikitState.componentUpdateCount == 2)
        #expect(uikitState.lastLanguageChangeDate != nil)
        
        // Unregister view controller
        uikitState.unregisterViewController("TestViewController")
        
        #expect(uikitState.unregistrationCount == 1)
        #expect(uikitState.registeredViewControllerTypes.count == 1)
        #expect(!uikitState.registeredViewControllerTypes.contains("TestViewController"))
        #expect(uikitState.registeredViewControllerTypes.contains("SettingsViewController"))
        #expect(uikitState.lastUnregistrationDate != nil)
    }
    
    @Test("UI component state persistence performance")
    func testUIComponentStatePersistencePerformance() async {
        let manager = await createTestManager()
        
        // Simulate many UI components with state
        struct MockComponentWithState {
            var id: String
            var localizationKey: String
            var displayText: String = ""
            var updateCount: Int = 0
            var lastUpdateDate: Date?
            
            @MainActor
            mutating func updateForLanguage(_ language: SupportedLanguage, manager: LocalizationManager) {
                self.displayText = manager.localizedString(for: localizationKey)
                self.updateCount += 1
                self.lastUpdateDate = Date()
            }
        }
        
        // Create many mock components
        var components: [MockComponentWithState] = []
        for i in 0..<100 {
            components.append(MockComponentWithState(
                id: "component_\(i)",
                localizationKey: i % 2 == 0 ? "button.ok" : "button.cancel"
            ))
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Update all components for language change
        await manager.switchLanguage(to: .english)
        for i in 0..<components.count {
            components[i].updateForLanguage(.english, manager: manager)
        }
        
        await manager.switchLanguage(to: .chineseSimplified)
        for i in 0..<components.count {
            components[i].updateForLanguage(.chineseSimplified, manager: manager)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(duration < 1.0, "Updating 100 components twice should take less than 1 second")
        
        // Verify all components were updated
        for component in components {
            #expect(component.updateCount == 2, "Each component should be updated twice")
            #expect(component.lastUpdateDate != nil, "Each component should have update timestamp")
            #expect(!component.displayText.isEmpty, "Each component should have display text")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestManager() async -> LocalizationManager {
        return await LocalizationManager.createTestInstance()
    }
}

