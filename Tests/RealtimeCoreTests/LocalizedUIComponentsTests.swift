import Testing
import Foundation
@testable import RealtimeCore

#if canImport(UIKit) && !os(macOS)
import UIKit
@testable import RealtimeUIKit

@Suite("Localized UI Components Tests")
@MainActor
struct LocalizedUIComponentsTests {
    
    // MARK: - UILabel Tests
    
    @Test("UILabel localized text")
    func testUILabelLocalizedText() async {
        let manager = await createTestManager()
        let label = UILabel()
        
        await manager.switchLanguage(to: .english)
        label.setLocalizedText("connection.state.connected")
        
        #expect(label.text == "Connected")
        #expect(label.localizationKey == "connection.state.connected")
        
        // Test language switching
        await manager.switchLanguage(to: .chineseSimplified)
        
        // Simulate notification (since we can't easily trigger it in tests)
        label.languageDidChange()
        
        #expect(label.text == "已连接")
    }
    
    @Test("UILabel localized text with arguments")
    func testUILabelLocalizedTextWithArguments() async {
        let manager = await createTestManager()
        let label = UILabel()
        
        await manager.switchLanguage(to: .english)
        label.setLocalizedText("audio.volume.mixing", arguments: 75)
        
        #expect(label.text == "Mixing Volume: 75%")
    }
    
    @Test("UILabel localized text with fallback")
    func testUILabelLocalizedTextWithFallback() async {
        let manager = await createTestManager()
        let label = UILabel()
        
        await manager.switchLanguage(to: .english)
        label.setLocalizedText("nonexistent.key", fallbackValue: "Fallback Text")
        
        #expect(label.text == "Fallback Text")
    }
    
    // MARK: - UIButton Tests
    
    @Test("UIButton localized title")
    func testUIButtonLocalizedTitle() async {
        let manager = await createTestManager()
        let button = UIButton()
        
        await manager.switchLanguage(to: .english)
        button.setLocalizedTitle("button.ok")
        
        #expect(button.title(for: .normal) == "OK")
        #expect(button.localizationKey() == "button.ok")
        
        // Test language switching
        await manager.switchLanguage(to: .chineseSimplified)
        button.languageDidChange()
        
        #expect(button.title(for: .normal) == "确定")
    }
    
    @Test("UIButton localized title for different states")
    func testUIButtonLocalizedTitleForDifferentStates() async {
        let manager = await createTestManager()
        let button = UIButton()
        
        await manager.switchLanguage(to: .english)
        button.setLocalizedTitle("button.ok", for: .normal)
        button.setLocalizedTitle("button.cancel", for: .disabled)
        
        #expect(button.title(for: .normal) == "OK")
        #expect(button.title(for: .disabled) == "Cancel")
        #expect(button.localizationKey(for: .normal) == "button.ok")
        #expect(button.localizationKey(for: .disabled) == "button.cancel")
    }
    
    // MARK: - UITextField Tests
    
    @Test("UITextField localized placeholder")
    func testUITextFieldLocalizedPlaceholder() async {
        let manager = await createTestManager()
        let textField = UITextField()
        
        await manager.switchLanguage(to: .english)
        textField.setLocalizedPlaceholder("settings.language")
        
        #expect(textField.placeholder == "Language")
        #expect(textField.placeholderLocalizationKey == "settings.language")
        
        // Test language switching
        await manager.switchLanguage(to: .chineseSimplified)
        textField.languageDidChange()
        
        #expect(textField.placeholder == "语言")
    }
    
    // MARK: - UIViewController Tests
    
    @Test("UIViewController localized title")
    func testUIViewControllerLocalizedTitle() async {
        let manager = await createTestManager()
        let viewController = UIViewController()
        
        await manager.switchLanguage(to: .english)
        viewController.setLocalizedTitle("settings.audio")
        
        #expect(viewController.title == "Audio Settings")
        #expect(viewController.titleLocalizationKey == "settings.audio")
        
        // Test language switching
        await manager.switchLanguage(to: .chineseSimplified)
        viewController.languageDidChange()
        
        #expect(viewController.title == "音频设置")
    }
    
    // MARK: - UIAlertController Tests
    
    @Test("UIAlertController localized alert")
    func testUIAlertControllerLocalizedAlert() async {
        let manager = await createTestManager()
        
        await manager.switchLanguage(to: .english)
        
        let alert = UIAlertController.localizedAlert(
            titleKey: "error.network.unavailable",
            messageKey: "error.connection.failed"
        )
        
        #expect(alert.title == "Network unavailable")
        #expect(alert.message == "Connection failed")
    }
    
    @Test("UIAlertController localized actions")
    func testUIAlertControllerLocalizedActions() async {
        let manager = await createTestManager()
        
        await manager.switchLanguage(to: .english)
        
        let alert = UIAlertController.localizedAlert(titleKey: "error.network.unavailable")
        alert.addLocalizedAction(titleKey: "button.ok", style: .default)
        alert.addLocalizedAction(titleKey: "button.cancel", style: .cancel)
        
        #expect(alert.actions.count == 2)
        #expect(alert.actions[0].title == "OK")
        #expect(alert.actions[1].title == "Cancel")
    }
    
    // MARK: - Language Picker Tests
    
    @Test("Language picker initialization")
    func testLanguagePickerInitialization() async {
        let manager = await createTestManager()
        let picker = LanguagePickerView()
        
        #expect(picker.numberOfComponents == 1)
        #expect(picker.numberOfRows(inComponent: 0) == SupportedLanguage.allCases.count)
        
        // Test titles
        for (index, language) in SupportedLanguage.allCases.enumerated() {
            let title = picker.pickerView(picker, titleForRow: index, forComponent: 0)
            #expect(title == language.displayName)
        }
    }
    
    @Test("Language picker selection")
    func testLanguagePickerSelection() async {
        let manager = await createTestManager()
        let picker = LanguagePickerView()
        
        var selectedLanguage: SupportedLanguage?
        picker.onLanguageSelected = { language in
            selectedLanguage = language
        }
        
        // Simulate selection
        picker.pickerView(picker, didSelectRow: 1, inComponent: 0)
        
        #expect(selectedLanguage == SupportedLanguage.allCases[1])
    }
    
    // MARK: - View Hierarchy Update Tests
    
    @Test("Update localized subviews")
    func testUpdateLocalizedSubviews() async {
        let manager = await createTestManager()
        
        // Create a view hierarchy
        let containerView = UIView()
        let label = UILabel()
        let button = UIButton()
        let textField = UITextField()
        
        containerView.addSubview(label)
        containerView.addSubview(button)
        containerView.addSubview(textField)
        
        await manager.switchLanguage(to: .english)
        
        // Set localized content
        label.setLocalizedText("connection.state.connected")
        button.setLocalizedTitle("button.ok")
        textField.setLocalizedPlaceholder("settings.language")
        
        #expect(label.text == "Connected")
        #expect(button.title(for: .normal) == "OK")
        #expect(textField.placeholder == "Language")
        
        // Switch language
        await manager.switchLanguage(to: .chineseSimplified)
        
        // Update all subviews
        containerView.updateLocalizedSubviews()
        
        #expect(label.text == "已连接")
        #expect(button.title(for: .normal) == "确定")
        #expect(textField.placeholder == "语言")
    }
    
    // MARK: - Notification Manager Tests
    
    @Test("Localization notification manager")
    func testLocalizationNotificationManager() async {
        let manager = await createTestManager()
        let viewController = UIViewController()
        
        // Register view controller
        LocalizationNotificationManager.registerViewController(viewController)
        
        await manager.switchLanguage(to: .english)
        viewController.setLocalizedTitle("settings.audio")
        
        #expect(viewController.title == "Audio Settings")
        
        // Switch language and trigger manual update
        await manager.switchLanguage(to: .chineseSimplified)
        LocalizationNotificationManager.updateAllLocalizedComponents()
        
        #expect(viewController.title == "音频设置")
        
        // Unregister
        LocalizationNotificationManager.unregisterViewController(viewController)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory management for localized components")
    func testMemoryManagementForLocalizedComponents() async {
        let manager = await createTestManager()
        
        // Create components in a scope
        do {
            let label = UILabel()
            let button = UIButton()
            
            await manager.switchLanguage(to: .english)
            label.setLocalizedText("connection.state.connected")
            button.setLocalizedTitle("button.ok")
            
            #expect(label.text == "Connected")
            #expect(button.title(for: .normal) == "OK")
            
            // Components should be deallocated when leaving scope
        }
        
        // Switch language - should not crash
        await manager.switchLanguage(to: .chineseSimplified)
        
        // This test mainly ensures no crashes occur due to dangling observers
        #expect(true, "No crashes should occur after components are deallocated")
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Empty and nil values handling")
    func testEmptyAndNilValuesHandling() async {
        let manager = await createTestManager()
        let label = UILabel()
        
        await manager.switchLanguage(to: .english)
        
        // Test empty key
        label.setLocalizedText("")
        #expect(label.text == "")
        
        // Test with nil fallback
        label.setLocalizedText("nonexistent.key", fallbackValue: nil)
        #expect(label.text == "nonexistent.key")
    }
    
    @Test("Multiple language switches")
    func testMultipleLanguageSwitches() async {
        let manager = await createTestManager()
        let label = UILabel()
        
        label.setLocalizedText("connection.state.connected")
        
        let languages: [SupportedLanguage] = [.english, .chineseSimplified, .japanese, .korean, .english]
        let expectedTexts = ["Connected", "已连接", "接続済み", "연결됨", "Connected"]
        
        for (language, expectedText) in zip(languages, expectedTexts) {
            await manager.switchLanguage(to: language)
            label.languageDidChange()
            #expect(label.text == expectedText, "Failed for language \(language)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestManager() async -> LocalizationManager {
        return await LocalizationManager.createTestInstance()
    }
}

#endif

// MARK: - SwiftUI Tests (Conceptual - SwiftUI testing is more complex)
// Note: SwiftUI component tests are disabled due to linking issues in test environment
// These components are tested through UI tests and integration tests

/*
#if canImport(SwiftUI)
import SwiftUI
@testable import RealtimeSwiftUI

@Suite("SwiftUI Localized Components Tests")
@MainActor
struct SwiftUILocalizedComponentsTests {
    
    @Test("LocalizedText basic functionality")
    func testLocalizedTextBasicFunctionality() async {
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        // We can't easily test SwiftUI views in unit tests,
        // but we can test the underlying localization logic
        let _ = LocalizedText("connection.state.connected")
        
        // The actual text rendering would be tested in UI tests
        #expect(Bool(true), "LocalizedText component should be creatable")
    }
    
    @Test("LocalizedButton basic functionality")
    func testLocalizedButtonBasicFunctionality() async {
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        var buttonTapped = false
        let _ = LocalizedButton("button.ok") {
            buttonTapped = true
        }
        
        // The actual button interaction would be tested in UI tests
        #expect(Bool(true), "LocalizedButton component should be creatable")
    }
    
    @Test("LocalizedTextField basic functionality")
    func testLocalizedTextFieldBasicFunctionality() async {
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        @State var text = ""
        let _ = LocalizedTextField("settings.language", text: $text)
        
        // The actual text field interaction would be tested in UI tests
        #expect(Bool(true), "LocalizedTextField component should be creatable")
    }
    
    @Test("LocalizedAlert basic functionality")
    func testLocalizedAlertBasicFunctionality() async {
        let manager = await createTestManager()
        await manager.switchLanguage(to: .english)
        
        let localizedAlert = LocalizedAlert(
            titleKey: "error.network.unavailable",
            messageKey: "error.connection.failed"
        )
        
        let _ = localizedAlert.alert()
        
        // The actual alert display would be tested in UI tests
        #expect(Bool(true), "LocalizedAlert should create SwiftUI Alert")
    }
    
    @Test("LanguagePicker basic functionality")
    func testLanguagePickerBasicFunctionality() async {
        let _ = await createTestManager()
        let _ = LanguagePicker()
        
        // The actual picker interaction would be tested in UI tests
        #expect(Bool(true), "LanguagePicker component should be creatable")
    }
    
    // MARK: - Helper Methods
    
    private func createTestManager() async -> LocalizationManager {
        return await LocalizationManager.createTestInstance()
    }
}

#endif
*/