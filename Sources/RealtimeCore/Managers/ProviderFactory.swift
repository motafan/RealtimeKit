// ProviderFactory.swift
// Factory pattern for creating RTC and RTM providers

import Foundation

/// Protocol for creating provider instances
public protocol ProviderFactory: Sendable {
    /// Create an RTC provider instance
    func createRTCProvider() -> RTCProvider
    
    /// Create an RTM provider instance
    func createRTMProvider() -> RTMProvider
    
    /// Get supported features for this provider
    func supportedFeatures() -> Set<ProviderFeature>
    
    /// Get provider type
    var providerType: ProviderType { get }
}

/// Features supported by providers
public enum ProviderFeature: String, CaseIterable, Sendable {
    case audioStreaming = "audio_streaming"
    case videoStreaming = "video_streaming"
    case streamPush = "stream_push"
    case mediaRelay = "media_relay"
    case volumeIndicator = "volume_indicator"
    case messageProcessing = "message_processing"
    case tokenManagement = "token_management"
    case encryption = "encryption"
    
    /// Display name for the feature
    public var displayName: String {
        switch self {
        case .audioStreaming: return "音频流"
        case .videoStreaming: return "视频流"
        case .streamPush: return "转推流"
        case .mediaRelay: return "媒体中继"
        case .volumeIndicator: return "音量指示器"
        case .messageProcessing: return "消息处理"
        case .tokenManagement: return "Token 管理"
        case .encryption: return "加密"
        }
    }
}

// Mock provider factory will be implemented in RealtimeMocking module to avoid circular dependency

/// Agora provider factory (placeholder - actual implementation in RealtimeAgora module)
public final class AgoraProviderFactory: ProviderFactory, @unchecked Sendable {
    public let providerType: ProviderType = .agora
    
    public init() {}
    
    public func createRTCProvider() -> RTCProvider {
        // This will be overridden by the actual AgoraProviderFactory in RealtimeAgora module
        fatalError("Agora RTC provider not yet implemented - use RealtimeAgora.AgoraProviderFactory")
    }
    
    public func createRTMProvider() -> RTMProvider {
        // This will be overridden by the actual AgoraProviderFactory in RealtimeAgora module
        fatalError("Agora RTM provider not yet implemented - use RealtimeAgora.AgoraProviderFactory")
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return [
            .audioStreaming,
            .videoStreaming,
            .streamPush,
            .mediaRelay,
            .volumeIndicator,
            .messageProcessing,
            .tokenManagement,
            .encryption
        ]
    }
}

/// Provider factory registry for managing multiple providers
@MainActor
public final class ProviderFactoryRegistry: ObservableObject {
    @Published public private(set) var registeredFactories: [ProviderType: ProviderFactory] = [:]
    @Published public private(set) var currentProvider: ProviderType?
    
    public init() {
        // Default factories will be registered by their respective modules
    }
    
    /// Register a provider factory
    /// - Parameter factory: Provider factory to register
    public func registerFactory(_ factory: ProviderFactory) {
        registeredFactories[factory.providerType] = factory
        print("Registered provider factory: \(factory.providerType)")
    }
    
    /// Unregister a provider factory
    /// - Parameter providerType: Provider type to unregister
    public func unregisterFactory(_ providerType: ProviderType) {
        registeredFactories.removeValue(forKey: providerType)
        if currentProvider == providerType {
            currentProvider = nil
        }
        print("Unregistered provider factory: \(providerType)")
    }
    
    /// Get factory for provider type
    /// - Parameter providerType: Provider type
    /// - Returns: Provider factory if registered
    public func getFactory(for providerType: ProviderType) -> ProviderFactory? {
        return registeredFactories[providerType]
    }
    
    /// Get all available provider types
    /// - Returns: Set of available provider types
    public func getAvailableProviders() -> Set<ProviderType> {
        return Set(registeredFactories.keys)
    }
    
    /// Check if provider is available
    /// - Parameter providerType: Provider type to check
    /// - Returns: True if provider is available
    public func isProviderAvailable(_ providerType: ProviderType) -> Bool {
        return registeredFactories[providerType] != nil
    }
    
    /// Get supported features for provider
    /// - Parameter providerType: Provider type
    /// - Returns: Set of supported features
    public func getSupportedFeatures(for providerType: ProviderType) -> Set<ProviderFeature> {
        return registeredFactories[providerType]?.supportedFeatures() ?? []
    }
    
    /// Set current provider
    /// - Parameter providerType: Provider type to set as current
    public func setCurrentProvider(_ providerType: ProviderType) {
        guard isProviderAvailable(providerType) else {
            print("Warning: Attempted to set unavailable provider: \(providerType)")
            return
        }
        currentProvider = providerType
    }
}

/// Provider switching manager for handling provider transitions
@MainActor
public final class ProviderSwitchManager: ObservableObject {
    @Published public private(set) var currentProvider: ProviderType?
    @Published public private(set) var switchingInProgress: Bool = false
    @Published public private(set) var lastSwitchError: Error?
    
    private let factoryRegistry: ProviderFactoryRegistry
    private var fallbackChain: [ProviderType] = [.mock] // Default fallback
    
    public init(factoryRegistry: ProviderFactoryRegistry) {
        self.factoryRegistry = factoryRegistry
    }
    
    /// Set fallback provider chain
    /// - Parameter chain: Array of provider types in fallback order
    public func setFallbackChain(_ chain: [ProviderType]) {
        fallbackChain = chain.filter { factoryRegistry.isProviderAvailable($0) }
    }
    
    /// Switch to a new provider
    /// - Parameters:
    ///   - newProvider: Target provider type
    ///   - preserveSession: Whether to preserve current session state
    /// - Returns: True if switch was successful
    public func switchProvider(to newProvider: ProviderType, preserveSession: Bool = true) async -> Bool {
        guard factoryRegistry.isProviderAvailable(newProvider) else {
            lastSwitchError = RealtimeError.providerNotAvailable(newProvider)
            return false
        }
        
        guard !switchingInProgress else {
            lastSwitchError = RealtimeError.operationInProgress("Provider switch already in progress")
            return false
        }
        
        switchingInProgress = true
        lastSwitchError = nil
        
        defer {
            switchingInProgress = false
        }
        
        do {
            // Perform the switch through RealtimeManager
            try await RealtimeManager.shared.switchProvider(to: newProvider, preserveSession: preserveSession)
            currentProvider = newProvider
            factoryRegistry.setCurrentProvider(newProvider)
            return true
        } catch {
            lastSwitchError = error
            
            // Try fallback providers if the switch failed
            if let fallbackProvider = findAvailableFallback() {
                do {
                    try await RealtimeManager.shared.switchProvider(to: fallbackProvider, preserveSession: false)
                    currentProvider = fallbackProvider
                    factoryRegistry.setCurrentProvider(fallbackProvider)
                    print("Switched to fallback provider: \(fallbackProvider)")
                    return true
                } catch {
                    lastSwitchError = error
                }
            }
            
            return false
        }
    }
    
    /// Find the first available fallback provider
    /// - Returns: Available fallback provider type
    private func findAvailableFallback() -> ProviderType? {
        return fallbackChain.first { factoryRegistry.isProviderAvailable($0) }
    }
    
    /// Get current provider info
    /// - Returns: Current provider information
    public func getCurrentProviderInfo() -> (type: ProviderType, features: Set<ProviderFeature>)? {
        guard let current = currentProvider else { return nil }
        let features = factoryRegistry.getSupportedFeatures(for: current)
        return (type: current, features: features)
    }
}