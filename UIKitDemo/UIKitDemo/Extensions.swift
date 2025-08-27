//
//  Extensions.swift
//  UIKitDemo
//
//  Created by Kiro on 8/27/25.
//

import Foundation
import RealtimeKit

// MARK: - Notification Names
extension Notification.Name {
    static let realtimeConnectionStateChanged = Notification.Name("RealtimeConnectionStateChanged")
    static let localizationLanguageChanged = Notification.Name("LocalizationLanguageChanged")
    static let realtimeUserSessionChanged = Notification.Name("RealtimeUserSessionChanged")
}

// MARK: - UserRole Display Names
extension UserRole {
    var demoDisplayName: String {
        switch self {
        case .broadcaster:
            return LocalizationManager.shared.localizedString(for: "user.role.broadcaster")
        case .coHost:
            return LocalizationManager.shared.localizedString(for: "user.role.cohost")
        case .moderator:
            return LocalizationManager.shared.localizedString(for: "user.role.moderator")
        case .audience:
            return LocalizationManager.shared.localizedString(for: "user.role.audience")
        }
    }
}

// MARK: - SupportedLanguage Display Names
extension SupportedLanguage {
    var demoDisplayName: String {
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
}