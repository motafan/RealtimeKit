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

/// A SwiftUI picker for selecting language with persistent state
/// 需求: 17.3, 18.1, 18.10 - 本地化 UI 组件和状态持久化
@available(iOS 14.0, macOS 11.0, *)
public struct LanguagePicker: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedLanguage: SupportedLanguage
    
    /// UI component localization state with automatic persistence
    /// 需求: 18.1, 18.10 - 使用 @RealtimeStorage 持久化 UI 组件的本地化状态
    @RealtimeStorage("languagePickerState", namespace: "RealtimeKit.UI.SwiftUI")
    private var pickerState: LanguagePickerState = LanguagePickerState()
    
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
                
                // Update persistent state
                pickerState.lastSelectedLanguage = newLanguage
                pickerState.selectionCount += 1
                pickerState.lastSelectionDate = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { notification in
            if let newLanguage = notification.userInfo?[LocalizationNotificationKeys.currentLanguage] as? SupportedLanguage {
                selectedLanguage = newLanguage
                
                // Update persistent state
                pickerState.currentDisplayLanguage = newLanguage
            }
        }
        .onAppear {
            // Restore state from persistence
            if let lastSelected = pickerState.lastSelectedLanguage,
               lastSelected != selectedLanguage {
                selectedLanguage = lastSelected
            }
            pickerState.currentDisplayLanguage = selectedLanguage
        }
    }
}

/// Persistent state for LanguagePicker component
/// 需求: 18.1 - UI 组件本地化状态持久化
public struct LanguagePickerState: Codable, Sendable {
    /// Last selected language by user
    public var lastSelectedLanguage: SupportedLanguage?
    
    /// Current display language
    public var currentDisplayLanguage: SupportedLanguage = .english
    
    /// Number of times user has changed language
    public var selectionCount: Int = 0
    
    /// Date of last language selection
    public var lastSelectionDate: Date?
    
    /// Whether picker should show language codes
    public var showLanguageCodes: Bool = false
    
    /// Whether picker should show native names
    public var showNativeNames: Bool = true
    
    public init(
        lastSelectedLanguage: SupportedLanguage? = nil,
        currentDisplayLanguage: SupportedLanguage = .english,
        selectionCount: Int = 0,
        lastSelectionDate: Date? = nil,
        showLanguageCodes: Bool = false,
        showNativeNames: Bool = true
    ) {
        self.lastSelectedLanguage = lastSelectedLanguage
        self.currentDisplayLanguage = currentDisplayLanguage
        self.selectionCount = selectionCount
        self.lastSelectionDate = lastSelectionDate
        self.showLanguageCodes = showLanguageCodes
        self.showNativeNames = showNativeNames
    }
}

// MARK: - Advanced Localized Components

/// A SwiftUI NavigationView with localized title and persistent state
/// 需求: 17.3, 18.1, 18.10 - 本地化 UI 组件和状态持久化
@available(iOS 14.0, macOS 11.0, *)
public struct LocalizedNavigationView<Content: View>: View {
    private let titleKey: String
    private let titleArguments: [CVarArg]
    private let content: () -> Content
    
    @StateObject private var localizationManager = LocalizationManager.shared
    
    /// Navigation view state with automatic persistence
    @RealtimeStorage("navigationViewState", namespace: "RealtimeKit.UI.SwiftUI")
    private var navigationState: NavigationViewState = NavigationViewState()
    
    /// Initialize with localized title
    /// - Parameters:
    ///   - titleKey: Localization key for navigation title
    ///   - titleArguments: Arguments for title formatting
    ///   - content: Navigation content
    public init(
        _ titleKey: String,
        titleArguments: CVarArg...,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.titleKey = titleKey
        self.titleArguments = titleArguments
        self.content = content
    }
    
    public var body: some View {
        NavigationView {
            content()
                .navigationTitle(localizedTitle)
                .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
                    // Update navigation state when language changes
                    navigationState.currentLanguage = localizationManager.currentLanguage
                    navigationState.lastLanguageChangeDate = Date()
                }
        }
        .onAppear {
            navigationState.viewAppearanceCount += 1
            navigationState.lastAppearanceDate = Date()
        }
    }
    
    private var localizedTitle: String {
        if titleArguments.isEmpty {
            return localizationManager.localizedString(for: titleKey)
        } else {
            return localizationManager.localizedString(for: titleKey, arguments: titleArguments)
        }
    }
}

/// Persistent state for NavigationView component
public struct NavigationViewState: Codable, Sendable {
    /// Current language for navigation
    public var currentLanguage: SupportedLanguage = .english
    
    /// Number of times view has appeared
    public var viewAppearanceCount: Int = 0
    
    /// Date of last view appearance
    public var lastAppearanceDate: Date?
    
    /// Date of last language change
    public var lastLanguageChangeDate: Date?
    
    public init(
        currentLanguage: SupportedLanguage = .english,
        viewAppearanceCount: Int = 0,
        lastAppearanceDate: Date? = nil,
        lastLanguageChangeDate: Date? = nil
    ) {
        self.currentLanguage = currentLanguage
        self.viewAppearanceCount = viewAppearanceCount
        self.lastAppearanceDate = lastAppearanceDate
        self.lastLanguageChangeDate = lastLanguageChangeDate
    }
}

/// A SwiftUI List with localized empty state
/// 需求: 17.3, 18.1 - 本地化 UI 组件和状态持久化
@available(iOS 14.0, macOS 11.0, *)
public struct LocalizedList<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let rowContent: (Data.Element) -> RowContent
    private let emptyStateKey: String
    private let emptyStateArguments: [CVarArg]
    
    @StateObject private var localizationManager = LocalizationManager.shared
    
    /// List state with automatic persistence
    @RealtimeStorage("localizedListState", namespace: "RealtimeKit.UI.SwiftUI")
    private var listState: LocalizedListState = LocalizedListState()
    
    /// Initialize with data and localized empty state
    /// - Parameters:
    ///   - data: The data collection
    ///   - id: Key path to unique identifier
    ///   - emptyStateKey: Localization key for empty state message
    ///   - emptyStateArguments: Arguments for empty state formatting
    ///   - rowContent: Row content builder
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        emptyStateKey: String,
        emptyStateArguments: CVarArg...,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.emptyStateKey = emptyStateKey
        self.emptyStateArguments = emptyStateArguments
        self.rowContent = rowContent
    }
    
    public var body: some View {
        Group {
            if data.isEmpty {
                VStack {
                    Image(systemName: "list.bullet")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    LocalizedText(emptyStateKey, arguments: emptyStateArguments)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .onAppear {
                    listState.emptyStateDisplayCount += 1
                    listState.lastEmptyStateDate = Date()
                }
            } else {
                List(data, id: id, rowContent: rowContent)
                    .onAppear {
                        listState.dataDisplayCount += 1
                        listState.lastDataDisplayDate = Date()
                        listState.lastItemCount = data.count
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
            listState.currentLanguage = localizationManager.currentLanguage
        }
    }
}

/// Persistent state for LocalizedList component
public struct LocalizedListState: Codable, Sendable {
    /// Current language for list
    public var currentLanguage: SupportedLanguage = .english
    
    /// Number of times empty state was displayed
    public var emptyStateDisplayCount: Int = 0
    
    /// Number of times data was displayed
    public var dataDisplayCount: Int = 0
    
    /// Last item count displayed
    public var lastItemCount: Int = 0
    
    /// Date of last empty state display
    public var lastEmptyStateDate: Date?
    
    /// Date of last data display
    public var lastDataDisplayDate: Date?
    
    public init(
        currentLanguage: SupportedLanguage = .english,
        emptyStateDisplayCount: Int = 0,
        dataDisplayCount: Int = 0,
        lastItemCount: Int = 0,
        lastEmptyStateDate: Date? = nil,
        lastDataDisplayDate: Date? = nil
    ) {
        self.currentLanguage = currentLanguage
        self.emptyStateDisplayCount = emptyStateDisplayCount
        self.dataDisplayCount = dataDisplayCount
        self.lastItemCount = lastItemCount
        self.lastEmptyStateDate = lastEmptyStateDate
        self.lastDataDisplayDate = lastDataDisplayDate
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
    
    /// Apply automatic language change updates with persistent state
    /// 需求: 17.6, 18.1 - 语言变化通知和 UI 自动更新机制，状态持久化
    @MainActor
    public func withLocalizedState<T: Codable>(
        _ stateKey: String,
        namespace: String = "RealtimeKit.UI.SwiftUI",
        defaultValue: T
    ) -> some View {
        self.modifier(LocalizedStateModifier(stateKey: stateKey, namespace: namespace, defaultValue: defaultValue))
    }
}

/// View modifier for automatic localized state management
/// 需求: 17.6, 18.1 - 语言变化通知和状态持久化
@available(iOS 14.0, macOS 11.0, *)
private struct LocalizedStateModifier<T: Codable>: ViewModifier {
    let stateKey: String
    let namespace: String
    let defaultValue: T
    
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var localizedState: T
    
    init(stateKey: String, namespace: String, defaultValue: T) {
        self.stateKey = stateKey
        self.namespace = namespace
        self.defaultValue = defaultValue
        self._localizedState = State(initialValue: defaultValue)
    }
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .realtimeLanguageDidChange)) { _ in
                // Trigger view update when language changes
            }
            .onAppear {
                // Initialize state if needed
                localizedState = defaultValue
            }
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