//
//  ConfigurationModels.swift
//  RealtimeCore
//
//  Created by Kiro on 8/27/25.
//

import Foundation

/// Configuration for RealtimeKit initialization
public struct RealtimeConfiguration {
    /// The provider type to use
    public let provider: ProviderType
    
    /// Application ID for the service provider
    public let appId: String
    
    /// Whether to enable debug logging
    public let enableLogging: Bool
    
    /// Optional app certificate for enhanced security
    public let appCertificate: String?
    
    /// Custom storage configuration
    public let storageConfig: StorageConfiguration?
    
    /// Localization configuration
    public let localizationConfig: LocalizationConfiguration?
    
    public init(
        provider: ProviderType,
        appId: String,
        enableLogging: Bool = false,
        appCertificate: String? = nil,
        storageConfig: StorageConfiguration? = nil,
        localizationConfig: LocalizationConfiguration? = nil
    ) {
        self.provider = provider
        self.appId = appId
        self.enableLogging = enableLogging
        self.appCertificate = appCertificate
        self.storageConfig = storageConfig
        self.localizationConfig = localizationConfig
    }
}

/// Storage configuration options
public struct StorageConfiguration {
    /// Default storage backend to use
    public let defaultBackend: StorageBackendType
    
    /// Whether to enable automatic state persistence
    public let enableAutoPersistence: Bool
    
    /// Storage namespace for the application
    public let namespace: String
    
    public init(
        defaultBackend: StorageBackendType = .userDefaults,
        enableAutoPersistence: Bool = true,
        namespace: String = "RealtimeKit"
    ) {
        self.defaultBackend = defaultBackend
        self.enableAutoPersistence = enableAutoPersistence
        self.namespace = namespace
    }
}

/// Storage backend types
public enum StorageBackendType {
    case userDefaults
    case keychain
    case memory
}

/// Localization configuration options
public struct LocalizationConfiguration {
    /// Default language to use
    public let defaultLanguage: SupportedLanguage
    
    /// Whether to auto-detect system language
    public let autoDetectSystemLanguage: Bool
    
    /// Custom localization strings
    public let customStrings: [String: [SupportedLanguage: String]]
    
    public init(
        defaultLanguage: SupportedLanguage = .english,
        autoDetectSystemLanguage: Bool = true,
        customStrings: [String: [SupportedLanguage: String]] = [:]
    ) {
        self.defaultLanguage = defaultLanguage
        self.autoDetectSystemLanguage = autoDetectSystemLanguage
        self.customStrings = customStrings
    }
}