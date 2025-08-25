import SwiftUI
import RealtimeCore

// MARK: - SwiftUI Localized Components

/// A SwiftUI Text view that automatically localizes its content
@available(iOS 14.0, macOS 11.0, *)
public struct LocalizedText: View {
    private let key: String
    private let arguments: [CVarArg]
    private let fallbackValue: String?
    
    @StateObject private var localizationManager = LocalizationManager.shared
    
    /// Initialize with localization key
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Arguments for string formatting
    ///   - fallbackValue: Fallback value if key is not found
    public init(_ key: String, arguments: CVarArg..., fallbackValue: String? = nil) {
        self.key = key
        self.arguments = arguments
        self.fallbackValue = fallbackValue
    }
    
    public var body: some View {
        Text(localizedString)
            .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
                // Force view update when language changes
            }
    }
    
    private var localizedString: String {
        if arguments.isEmpty {
            return localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            return localizationManager.localizedString(for: key, arguments: arguments)
        }
    }
}

/// A SwiftUI Button with localized title
@available(iOS 14.0, macOS 11.0, *)
public struct LocalizedButton<Label: View>: View {
    private let key: String?
    private let arguments: [CVarArg]
    private let fallbackValue: String?
    private let action: () -> Void
    private let label: (() -> Label)?
    
    @StateObject private var localizationManager = LocalizationManager.shared
    
    /// Initialize with localization key for title
    /// - Parameters:
    ///   - titleKey: The localization key for button title
    ///   - arguments: Arguments for string formatting
    ///   - fallbackValue: Fallback value if key is not found
    ///   - action: Action to perform when button is tapped
    public init(
        _ titleKey: String,
        arguments: CVarArg...,
        fallbackValue: String? = nil,
        action: @escaping () -> Void
    ) where Label == Text {
        self.key = titleKey
        self.arguments = arguments
        self.fallbackValue = fallbackValue
        self.action = action
        self.label = nil
    }
    
    /// Initialize with custom label
    /// - Parameters:
    ///   - action: Action to perform when button is tapped
    ///   - label: Custom label view
    public init(
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.key = nil
        self.arguments = []
        self.fallbackValue = nil
        self.action = action
        self.label = label
    }
    
    public var body: some View {
        Button(action: action) {
            if let label = label {
                label()
            } else if let key = key {
                LocalizedText(key, arguments: arguments, fallbackValue: fallbackValue)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            // Force view update when language changes
        }
    }
}

/// A SwiftUI TextField with localized placeholder
@available(iOS 14.0, macOS 11.0, *)
public struct LocalizedTextField: View {
    private let placeholderKey: String
    private let placeholderArguments: [CVarArg]
    private let placeholderFallback: String?
    @Binding private var text: String
    
    @StateObject private var localizationManager = LocalizationManager.shared
    
    /// Initialize with localization key for placeholder
    /// - Parameters:
    ///   - placeholderKey: The localization key for placeholder text
    ///   - text: Binding to the text value
    ///   - arguments: Arguments for placeholder string formatting
    ///   - fallbackValue: Fallback value if key is not found
    public init(
        _ placeholderKey: String,
        text: Binding<String>,
        arguments: CVarArg...,
        fallbackValue: String? = nil
    ) {
        self.placeholderKey = placeholderKey
        self._text = text
        self.placeholderArguments = arguments
        self.placeholderFallback = fallbackValue
    }
    
    public var body: some View {
        TextField(localizedPlaceholder, text: $text)
            .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
                // Force view update when language changes
            }
    }
    
    private var localizedPlaceholder: String {
        if placeholderArguments.isEmpty {
            return localizationManager.localizedString(for: placeholderKey, fallbackValue: placeholderFallback)
        } else {
            return localizationManager.localizedString(for: placeholderKey, arguments: placeholderArguments)
        }
    }
}

/// A SwiftUI Alert with localized content
public struct LocalizedAlert {
    private let titleKey: String
    private let messageKey: String?
    private let titleArguments: [CVarArg]
    private let messageArguments: [CVarArg]
    private let primaryButtonKey: String?
    private let secondaryButtonKey: String?
    private let primaryAction: (() -> Void)?
    private let secondaryAction: (() -> Void)?
    
    /// Initialize localized alert
    /// - Parameters:
    ///   - titleKey: Localization key for alert title
    ///   - messageKey: Localization key for alert message
    ///   - titleArguments: Arguments for title formatting
    ///   - messageArguments: Arguments for message formatting
    ///   - primaryButtonKey: Localization key for primary button
    ///   - secondaryButtonKey: Localization key for secondary button
    ///   - primaryAction: Action for primary button
    ///   - secondaryAction: Action for secondary button
    public init(
        titleKey: String,
        messageKey: String? = nil,
        titleArguments: [CVarArg] = [],
        messageArguments: [CVarArg] = [],
        primaryButtonKey: String? = "button.ok",
        secondaryButtonKey: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.titleArguments = titleArguments
        self.messageArguments = messageArguments
        self.primaryButtonKey = primaryButtonKey
        self.secondaryButtonKey = secondaryButtonKey
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    /// Create SwiftUI Alert
    @MainActor
    public func alert() -> Alert {
        let localizationManager = LocalizationManager.shared
        
        let title = localizationManager.localizedString(for: titleKey, arguments: titleArguments)
        
        let message = messageKey.map { key in
            localizationManager.localizedString(for: key, arguments: messageArguments)
        }
        
        let primaryButtonTitle = primaryButtonKey.map { key in
            localizationManager.localizedString(for: key)
        } ?? "OK"
        
        if let secondaryButtonKey = secondaryButtonKey {
            let secondaryButtonTitle = localizationManager.localizedString(for: secondaryButtonKey)
            
            return Alert(
                title: Text(title),
                message: message.map { Text($0) },
                primaryButton: .default(Text(primaryButtonTitle), action: primaryAction),
                secondaryButton: .cancel(Text(secondaryButtonTitle), action: secondaryAction)
            )
        } else {
            return Alert(
                title: Text(title),
                message: message.map { Text($0) },
                dismissButton: .default(Text(primaryButtonTitle), action: primaryAction)
            )
        }
    }
}

// MARK: - Language Picker Component

/// A SwiftUI picker for selecting language
@available(iOS 14.0, macOS 11.0, *)
public struct LanguagePicker: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedLanguage: SupportedLanguage
    
    /// Initialize language picker
    /// - Parameter selectedLanguage: Currently selected language
    public init(selectedLanguage: SupportedLanguage? = nil) {
        self._selectedLanguage = State(initialValue: selectedLanguage ?? LocalizationManager.shared.currentLanguage)
    }
    
    public var body: some View {
        Picker("Language", selection: $selectedLanguage) {
            ForEach(localizationManager.availableLanguages, id: \.self) { language in
                Text(language.displayName)
                    .tag(language)
            }
        }
        .onChange(of: selectedLanguage) { newLanguage in
            Task {
                await localizationManager.switchLanguage(to: newLanguage)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { notification in
            if let newLanguage = notification.userInfo?[LocalizationNotificationKeys.currentLanguage] as? SupportedLanguage {
                selectedLanguage = newLanguage
            }
        }
    }
}

// MARK: - View Modifiers

@available(iOS 14.0, macOS 11.0, *)
extension View {
    /// Apply localized accessibility label
    /// - Parameters:
    ///   - key: Localization key for accessibility label
    ///   - arguments: Arguments for string formatting
    /// - Returns: View with localized accessibility label
    @MainActor
    public func localizedAccessibilityLabel(_ key: String, arguments: CVarArg...) -> some View {
        let localizationManager = LocalizationManager.shared
        let localizedLabel = localizationManager.localizedString(for: key, arguments: arguments)
        return self.accessibilityLabel(localizedLabel)
    }
    
    /// Apply localized accessibility hint
    /// - Parameters:
    ///   - key: Localization key for accessibility hint
    ///   - arguments: Arguments for string formatting
    /// - Returns: View with localized accessibility hint
    @MainActor
    public func localizedAccessibilityHint(_ key: String, arguments: CVarArg...) -> some View {
        let localizationManager = LocalizationManager.shared
        let localizedHint = localizationManager.localizedString(for: key, arguments: arguments)
        return self.accessibilityHint(localizedHint)
    }
}

// MARK: - Preview Helpers

#if DEBUG
@available(iOS 14.0, macOS 11.0, *)
extension LocalizedText {
    /// Preview helper for LocalizedText
    public static var previews: some View {
        VStack(spacing: 16) {
            LocalizedText("connection.state.connected")
            LocalizedText("user.role.broadcaster")
            LocalizedText("audio.volume.mixing", arguments: 75)
            LocalizedText("nonexistent.key", fallbackValue: "Fallback Text")
        }
        .padding()
    }
}

@available(iOS 14.0, macOS 11.0, *)
extension LocalizedButton where Label == Text {
    /// Preview helper for LocalizedButton
    public static var previews: some View {
        VStack(spacing: 16) {
            LocalizedButton("button.ok") {
                print("OK tapped")
            }
            
            LocalizedButton("button.cancel") {
                print("Cancel tapped")
            }
        }
        .padding()
    }
}
#endif