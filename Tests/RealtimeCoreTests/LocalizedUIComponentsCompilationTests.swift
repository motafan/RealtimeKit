import Testing
import Foundation
@testable import RealtimeCore

#if canImport(SwiftUI) && canImport(UIKit) && !os(macOS)
import SwiftUI
import UIKit
@testable import RealtimeSwiftUI
@testable import RealtimeUIKit

/// Compilation tests for localized UI components
/// These tests verify that the components can be instantiated and compiled correctly
@Suite("Localized UI Components Compilation Tests")
@MainActor
struct LocalizedUIComponentsCompilationTests {
    
    // MARK: - SwiftUI Component Compilation Tests
    
    @Test("SwiftUI LocalizedText compilation")
    func testSwiftUILocalizedTextCompilation() async {
        // Test that LocalizedText can be instantiated
        let _ = LocalizedText("button.ok")
        let _ = LocalizedText("audio.volume.mixing", arguments: 75)
        let _ = LocalizedText("nonexistent.key", fallbackValue: "Fallback")
        
        #expect(Bool(true), "LocalizedText components should compile and instantiate")
    }
    
    @Test("SwiftUI LocalizedButton compilation")
    func testSwiftUILocalizedButtonCompilation() async {
        // Test that LocalizedButton can be instantiated
        let _ = LocalizedButton("button.ok") { }
        let _ = LocalizedButton("button.cancel", arguments: 123) { }
        
        #expect(Bool(true), "LocalizedButton components should compile and instantiate")
    }
    
    @Test("SwiftUI LocalizedTextField compilation")
    func testSwiftUILocalizedTextFieldCompilation() async {
        // Test that LocalizedTextField can be instantiated
        @State var text = ""
        let _ = LocalizedTextField("settings.language", text: $text)
        let _ = LocalizedTextField("placeholder.key", text: $text, fallbackValue: "Default")
        
        #expect(Bool(true), "LocalizedTextField components should compile and instantiate")
    }
    
    @Test("SwiftUI LocalizedAlert compilation")
    func testSwiftUILocalizedAlertCompilation() async {
        // Test that LocalizedAlert can be instantiated
        let alert1 = LocalizedAlert(titleKey: "error.network.unavailable")
        let alert2 = LocalizedAlert(
            titleKey: "error.connection.failed",
            messageKey: "error.connection.timeout",
            primaryButtonKey: "button.retry",
            secondaryButtonKey: "button.cancel"
        )
        
        let _ = alert1.alert()
        let _ = alert2.alert()
        
        #expect(Bool(true), "LocalizedAlert components should compile and instantiate")
    }
    
    @Test("SwiftUI LanguagePicker compilation")
    func testSwiftUILanguagePickerCompilation() async {
        // Test that LanguagePicker can be instantiated
        let _ = LanguagePicker()
        let _ = LanguagePicker(selectedLanguage: .english)
        
        #expect(Bool(true), "LanguagePicker components should compile and instantiate")
    }
    
    // MARK: - UIKit Component Compilation Tests
    
    @Test("UIKit localized extensions compilation")
    func testUIKitLocalizedExtensionsCompilation() async {
        // Test that UIKit extensions can be used
        let label = UILabel()
        let button = UIButton()
        let textField = UITextField()
        let viewController = UIViewController()
        
        // Test setting localized content
        label.setLocalizedText("connection.state.connected")
        label.setLocalizedText("audio.volume.mixing", arguments: 85)
        
        button.setLocalizedTitle("button.ok")
        button.setLocalizedTitle("button.cancel", for: .disabled)
        
        textField.setLocalizedPlaceholder("settings.language")
        
        viewController.setLocalizedTitle("settings.audio")
        
        // Test getting localization keys
        let _ = label.localizationKey
        let _ = button.localizationKey()
        let _ = textField.placeholderLocalizationKey
        let _ = viewController.titleLocalizationKey
        
        #expect(Bool(true), "UIKit localized extensions should compile and work")
    }
    
    @Test("UIKit localized alert compilation")
    func testUIKitLocalizedAlertCompilation() async {
        // Test that localized alerts can be created
        let alert = UIAlertController.localizedAlert(
            titleKey: "error.network.unavailable",
            messageKey: "error.connection.failed"
        )
        
        alert.addLocalizedAction(titleKey: "button.ok")
        alert.addLocalizedAction(titleKey: "button.cancel", style: .cancel)
        
        #expect(alert.actions.count == 2, "Alert should have two actions")
        #expect(Bool(true), "UIKit localized alerts should compile and work")
    }
    
    @Test("UIKit language picker compilation")
    func testUIKitLanguagePickerCompilation() async {
        // Test that LanguagePickerView can be instantiated
        let picker = LanguagePickerView()
        
        // Test picker properties
        #expect(picker.numberOfComponents == 1, "Language picker should have one component")
        #expect(picker.numberOfRows(inComponent: 0) > 0, "Language picker should have rows")
        
        // Test data source methods
        let title = picker.pickerView(picker, titleForRow: 0, forComponent: 0)
        #expect(title != nil, "Language picker should provide titles")
        
        #expect(Bool(true), "UIKit LanguagePickerView should compile and work")
    }
    
    // MARK: - View Modifier Compilation Tests
    
    @Test("SwiftUI view modifiers compilation")
    func testSwiftUIViewModifiersCompilation() async {
        // Test that view modifiers can be used
        let text = Text("Test")
            .localizedAccessibilityLabel("accessibility.button.ok")
            .localizedAccessibilityHint("accessibility.hint.tap.to.confirm")
        
        let _ = text
        
        #expect(Bool(true), "SwiftUI localized view modifiers should compile")
    }
    
    // MARK: - Helper Methods
    
    private func createTestManager() async -> LocalizationManager {
        return await LocalizationManager.createTestInstance()
    }
}

#else

/// Placeholder test suite for platforms where UI components are not available
@Suite("Localized UI Components Compilation Tests (Unavailable)")
struct LocalizedUIComponentsCompilationTestsUnavailable {
    
    @Test("UI components not available on this platform")
    func testUIComponentsNotAvailable() {
        #expect(Bool(true), "UI components are not available on this platform")
    }
}

#endif