#if canImport(UIKit)
import UIKit
import RealtimeCore

// MARK: - UILabel Localized Extensions

extension UILabel {
    
    /// Set localized text using a localization key
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Arguments for string formatting
    ///   - fallbackValue: Fallback value if key is not found
    public func setLocalizedText(_ key: String, arguments: CVarArg..., fallbackValue: String? = nil) {
        let localizationManager = LocalizationManager.shared
        
        if arguments.isEmpty {
            self.text = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            self.text = localizationManager.localizedString(for: key, arguments: arguments)
        }
        
        // Store the key for automatic updates
        objc_setAssociatedObject(self, &AssociatedKeys.localizationKey, key, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.localizationArguments, arguments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.localizationFallback, fallbackValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Register for language change notifications
        registerForLanguageChangeNotifications()
    }
    
    /// Get the current localization key
    public var localizationKey: String? {
        return objc_getAssociatedObject(self, &AssociatedKeys.localizationKey) as? String
    }
    
    private func registerForLanguageChangeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .realtimeLanguageDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    @objc internal func languageDidChange() {
        guard let key = objc_getAssociatedObject(self, &AssociatedKeys.localizationKey) as? String else { return }
        
        let arguments = objc_getAssociatedObject(self, &AssociatedKeys.localizationArguments) as? [CVarArg] ?? []
        let fallbackValue = objc_getAssociatedObject(self, &AssociatedKeys.localizationFallback) as? String
        
        let localizationManager = LocalizationManager.shared
        
        if arguments.isEmpty {
            self.text = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            self.text = localizationManager.localizedString(for: key, arguments: arguments)
        }
    }
}

// MARK: - UIButton Localized Extensions

extension UIButton {
    
    /// Set localized title for a specific control state
    /// - Parameters:
    ///   - key: The localization key
    ///   - state: The control state
    ///   - arguments: Arguments for string formatting
    ///   - fallbackValue: Fallback value if key is not found
    public func setLocalizedTitle(_ key: String, for state: UIControl.State = .normal, arguments: CVarArg..., fallbackValue: String? = nil) {
        let localizationManager = LocalizationManager.shared
        
        let localizedTitle: String
        if arguments.isEmpty {
            localizedTitle = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            localizedTitle = localizationManager.localizedString(for: key, arguments: arguments)
        }
        
        self.setTitle(localizedTitle, for: state)
        
        // Store the key for automatic updates
        let stateKey = "title_\(state.rawValue)"
        objc_setAssociatedObject(self, stateKey, key, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, "\(stateKey)_args", arguments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, "\(stateKey)_fallback", fallbackValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Register for language change notifications
        registerForLanguageChangeNotifications()
    }
    
    /// Get the current localization key for a specific state
    /// - Parameter state: The control state
    /// - Returns: The localization key if set
    public func localizationKey(for state: UIControl.State = .normal) -> String? {
        let stateKey = "title_\(state.rawValue)"
        return objc_getAssociatedObject(self, stateKey) as? String
    }
    
    private func registerForLanguageChangeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .realtimeLanguageDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    @objc internal func languageDidChange() {
        let localizationManager = LocalizationManager.shared
        
        // Update all stored localized titles
        let states: [UIControl.State] = [.normal, .highlighted, .disabled, .selected]
        
        for state in states {
            let stateKey = "title_\(state.rawValue)"
            guard let key = objc_getAssociatedObject(self, stateKey) as? String else { continue }
            
            let arguments = objc_getAssociatedObject(self, "\(stateKey)_args") as? [CVarArg] ?? []
            let fallbackValue = objc_getAssociatedObject(self, "\(stateKey)_fallback") as? String
            
            let localizedTitle: String
            if arguments.isEmpty {
                localizedTitle = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
            } else {
                localizedTitle = localizationManager.localizedString(for: key, arguments: arguments)
            }
            
            self.setTitle(localizedTitle, for: state)
        }
    }
}

// MARK: - UITextField Localized Extensions

extension UITextField {
    
    /// Set localized placeholder text
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Arguments for string formatting
    ///   - fallbackValue: Fallback value if key is not found
    public func setLocalizedPlaceholder(_ key: String, arguments: CVarArg..., fallbackValue: String? = nil) {
        let localizationManager = LocalizationManager.shared
        
        if arguments.isEmpty {
            self.placeholder = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            self.placeholder = localizationManager.localizedString(for: key, arguments: arguments)
        }
        
        // Store the key for automatic updates
        objc_setAssociatedObject(self, &AssociatedKeys.placeholderKey, key, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.placeholderArguments, arguments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.placeholderFallback, fallbackValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Register for language change notifications
        registerForLanguageChangeNotifications()
    }
    
    /// Get the current placeholder localization key
    public var placeholderLocalizationKey: String? {
        return objc_getAssociatedObject(self, &AssociatedKeys.placeholderKey) as? String
    }
    
    private func registerForLanguageChangeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .realtimeLanguageDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    @objc internal func languageDidChange() {
        guard let key = objc_getAssociatedObject(self, &AssociatedKeys.placeholderKey) as? String else { return }
        
        let arguments = objc_getAssociatedObject(self, &AssociatedKeys.placeholderArguments) as? [CVarArg] ?? []
        let fallbackValue = objc_getAssociatedObject(self, &AssociatedKeys.placeholderFallback) as? String
        
        let localizationManager = LocalizationManager.shared
        
        if arguments.isEmpty {
            self.placeholder = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            self.placeholder = localizationManager.localizedString(for: key, arguments: arguments)
        }
    }
}

// MARK: - UIAlertController Localized Extensions

extension UIAlertController {
    
    /// Create a localized alert controller
    /// - Parameters:
    ///   - titleKey: Localization key for title
    ///   - messageKey: Localization key for message
    ///   - preferredStyle: Alert style
    ///   - titleArguments: Arguments for title formatting
    ///   - messageArguments: Arguments for message formatting
    /// - Returns: Configured UIAlertController
    public static func localizedAlert(
        titleKey: String,
        messageKey: String? = nil,
        preferredStyle: UIAlertController.Style = .alert,
        titleArguments: [CVarArg] = [],
        messageArguments: [CVarArg] = []
    ) -> UIAlertController {
        let localizationManager = LocalizationManager.shared
        
        let title = localizationManager.localizedString(for: titleKey, arguments: titleArguments)
        
        let message = messageKey.map { key in
            localizationManager.localizedString(for: key, arguments: messageArguments)
        }
        
        return UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
    }
    
    /// Add a localized action to the alert
    /// - Parameters:
    ///   - titleKey: Localization key for action title
    ///   - style: Action style
    ///   - arguments: Arguments for title formatting
    ///   - handler: Action handler
    public func addLocalizedAction(
        titleKey: String,
        style: UIAlertAction.Style = .default,
        arguments: [CVarArg] = [],
        handler: ((UIAlertAction) -> Void)? = nil
    ) {
        let localizationManager = LocalizationManager.shared
        let title = localizationManager.localizedString(for: titleKey, arguments: arguments)
        
        let action = UIAlertAction(title: title, style: style, handler: handler)
        self.addAction(action)
    }
}

// MARK: - UIViewController Localized Extensions

extension UIViewController {
    
    /// Set localized title
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Arguments for string formatting
    ///   - fallbackValue: Fallback value if key is not found
    public func setLocalizedTitle(_ key: String, arguments: CVarArg..., fallbackValue: String? = nil) {
        let localizationManager = LocalizationManager.shared
        
        if arguments.isEmpty {
            self.title = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            self.title = localizationManager.localizedString(for: key, arguments: arguments)
        }
        
        // Store the key for automatic updates
        objc_setAssociatedObject(self, &AssociatedKeys.titleKey, key, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.titleArguments, arguments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.titleFallback, fallbackValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Register for language change notifications
        registerForLanguageChangeNotifications()
    }
    
    /// Get the current title localization key
    public var titleLocalizationKey: String? {
        return objc_getAssociatedObject(self, &AssociatedKeys.titleKey) as? String
    }
    
    private func registerForLanguageChangeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .realtimeLanguageDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    @objc internal func languageDidChange() {
        guard let key = objc_getAssociatedObject(self, &AssociatedKeys.titleKey) as? String else { return }
        
        let arguments = objc_getAssociatedObject(self, &AssociatedKeys.titleArguments) as? [CVarArg] ?? []
        let fallbackValue = objc_getAssociatedObject(self, &AssociatedKeys.titleFallback) as? String
        
        let localizationManager = LocalizationManager.shared
        
        if arguments.isEmpty {
            self.title = localizationManager.localizedString(for: key, fallbackValue: fallbackValue)
        } else {
            self.title = localizationManager.localizedString(for: key, arguments: arguments)
        }
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var localizationKey: UInt8 = 0
    static var localizationArguments: UInt8 = 1
    static var localizationFallback: UInt8 = 2
    static var placeholderKey: UInt8 = 3
    static var placeholderArguments: UInt8 = 4
    static var placeholderFallback: UInt8 = 5
    static var titleKey: UInt8 = 6
    static var titleArguments: UInt8 = 7
    static var titleFallback: UInt8 = 8
}

// MARK: - Language Change Notification Helper

/// Helper class for managing language change notifications in UIKit
public class LocalizationNotificationManager {
    
    /// Manually trigger language change update for all registered UI components
    public static func updateAllLocalizedComponents() {
        NotificationCenter.default.post(name: .realtimeLanguageDidChange, object: nil)
    }
    
    /// Register a view controller for automatic localization updates
    /// - Parameter viewController: The view controller to register
    public static func registerViewController(_ viewController: UIViewController) {
        viewController.registerForLanguageChangeNotifications()
    }
    
    /// Unregister a view controller from localization updates
    /// - Parameter viewController: The view controller to unregister
    public static func unregisterViewController(_ viewController: UIViewController) {
        NotificationCenter.default.removeObserver(viewController, name: .realtimeLanguageDidChange, object: nil)
    }
}

// MARK: - Convenience Methods

extension UIView {
    
    /// Recursively update all localized subviews
    public func updateLocalizedSubviews() {
        // Update self if it's a localized component
        if let label = self as? UILabel, label.localizationKey != nil {
            label.languageDidChange()
        } else if let button = self as? UIButton, button.localizationKey() != nil {
            button.languageDidChange()
        } else if let textField = self as? UITextField, textField.placeholderLocalizationKey != nil {
            textField.languageDidChange()
        }
        
        // Recursively update subviews
        for subview in subviews {
            subview.updateLocalizedSubviews()
        }
    }
}

// MARK: - Language Picker for UIKit

/// A UIKit picker view for language selection
public class LanguagePickerView: UIPickerView {
    
    private let localizationManager = LocalizationManager.shared
    private var languages: [SupportedLanguage] = []
    
    /// Callback for language selection
    public var onLanguageSelected: ((SupportedLanguage) -> Void)?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupPicker()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPicker()
    }
    
    private func setupPicker() {
        languages = localizationManager.availableLanguages
        dataSource = self
        delegate = self
        
        // Set current language as selected
        if let currentIndex = languages.firstIndex(of: localizationManager.currentLanguage) {
            selectRow(currentIndex, inComponent: 0, animated: false)
        }
        
        // Register for language change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .realtimeLanguageDidChange,
            object: nil
        )
    }
    
    @objc private func languageDidChange() {
        if let currentIndex = languages.firstIndex(of: localizationManager.currentLanguage) {
            selectRow(currentIndex, inComponent: 0, animated: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - LanguagePickerView DataSource and Delegate

extension LanguagePickerView: UIPickerViewDataSource, UIPickerViewDelegate {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return languages.count
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return languages[row].displayName
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedLanguage = languages[row]
        onLanguageSelected?(selectedLanguage)
        
        Task {
            await localizationManager.switchLanguage(to: selectedLanguage)
        }
    }
}

#endif