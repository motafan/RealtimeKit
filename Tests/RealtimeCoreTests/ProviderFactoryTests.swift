// ProviderFactoryTests.swift
// Comprehensive unit tests for ProviderFactory

import Testing
@testable import RealtimeCore
@testable import RealtimeMocking

@Suite("ProviderFactory Tests")
struct ProviderFactoryTests {
    
    // MARK: - Test Setup
    
    private func createFactory() -> ProviderFactory {
        return ProviderFactory()
    }
    
    // MARK: - Initialization Tests
    
    @Test("ProviderFactory initialization")
    func testProviderFactoryInitialization() {
        let factory = createFactory()
        
        #expect(factory.registeredProviders.isEmpty)
        #expect(factory.defaultProvider == nil)
    }
    
    // MARK: - Provider Registration Tests
    
    @Test("Register mock provider factory")
    func testRegisterMockProviderFactory() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        #expect(factory.registeredProviders.contains(.mock))
        #expect(factory.isProviderRegistered(.mock))
    }
    
    @Test("Register multiple provider factories")
    func testRegisterMultipleProviderFactories() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        let agoraFactory = AgoraProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        try factory.registerProvider(.agora, factory: agoraFactory)
        
        #expect(factory.registeredProviders.count == 2)
        #expect(factory.registeredProviders.contains(.mock))
        #expect(factory.registeredProviders.contains(.agora))
    }
    
    @Test("Register duplicate provider factory")
    func testRegisterDuplicateProviderFactory() throws {
        let factory = createFactory()
        let mockFactory1 = MockProviderFactory()
        let mockFactory2 = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory1)
        
        #expect(throws: RealtimeError.self) {
            try factory.registerProvider(.mock, factory: mockFactory2)
        }
    }
    
    @Test("Unregister provider factory")
    func testUnregisterProviderFactory() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        #expect(factory.isProviderRegistered(.mock))
        
        factory.unregisterProvider(.mock)
        #expect(!factory.isProviderRegistered(.mock))
    }
    
    @Test("Unregister non-existent provider")
    func testUnregisterNonExistentProvider() {
        let factory = createFactory()
        
        // Should not throw or crash
        factory.unregisterProvider(.agora)
        
        #expect(factory.registeredProviders.isEmpty)
    }
    
    // MARK: - Provider Creation Tests
    
    @Test("Create RTC provider")
    func testCreateRTCProvider() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        let rtcProvider = try factory.createRTCProvider(type: .mock)
        
        #expect(rtcProvider is MockRTCProvider)
    }
    
    @Test("Create RTM provider")
    func testCreateRTMProvider() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        let rtmProvider = try factory.createRTMProvider(type: .mock)
        
        #expect(rtmProvider is MockRTMProvider)
    }
    
    @Test("Create provider with unregistered type")
    func testCreateProviderWithUnregisteredType() {
        let factory = createFactory()
        
        #expect(throws: RealtimeError.self) {
            let _ = try factory.createRTCProvider(type: .agora)
        }
        
        #expect(throws: RealtimeError.self) {
            let _ = try factory.createRTMProvider(type: .agora)
        }
    }
    
    // MARK: - Default Provider Tests
    
    @Test("Set default provider")
    func testSetDefaultProvider() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        factory.setDefaultProvider(.mock)
        
        #expect(factory.defaultProvider == .mock)
    }
    
    @Test("Set unregistered default provider")
    func testSetUnregisteredDefaultProvider() {
        let factory = createFactory()
        
        #expect(throws: RealtimeError.self) {
            factory.setDefaultProvider(.agora)
        }
    }
    
    @Test("Create provider with default type")
    func testCreateProviderWithDefaultType() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        factory.setDefaultProvider(.mock)
        
        let rtcProvider = try factory.createRTCProvider()
        let rtmProvider = try factory.createRTMProvider()
        
        #expect(rtcProvider is MockRTCProvider)
        #expect(rtmProvider is MockRTMProvider)
    }
    
    @Test("Create provider without default type")
    func testCreateProviderWithoutDefaultType() {
        let factory = createFactory()
        
        #expect(throws: RealtimeError.self) {
            let _ = try factory.createRTCProvider()
        }
        
        #expect(throws: RealtimeError.self) {
            let _ = try factory.createRTMProvider()
        }
    }
    
    // MARK: - Provider Features Tests
    
    @Test("Get supported features for provider")
    func testGetSupportedFeaturesForProvider() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        let features = factory.getSupportedFeatures(for: .mock)
        
        #expect(features.contains(.audioStreaming))
        #expect(features.contains(.messageProcessing))
        #expect(features.contains(.volumeIndicator))
    }
    
    @Test("Get features for unregistered provider")
    func testGetFeaturesForUnregisteredProvider() {
        let factory = createFactory()
        
        let features = factory.getSupportedFeatures(for: .agora)
        
        #expect(features.isEmpty)
    }
    
    @Test("Check feature support")
    func testCheckFeatureSupport() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        #expect(factory.supportsFeature(.audioStreaming, for: .mock))
        #expect(factory.supportsFeature(.messageProcessing, for: .mock))
        #expect(!factory.supportsFeature(.videoStreaming, for: .mock))
    }
    
    // MARK: - Provider Validation Tests
    
    @Test("Validate provider configuration")
    func testValidateProviderConfiguration() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        let config = RealtimeConfig(
            appId: "test_app_id",
            appKey: "test_app_key",
            logLevel: .debug
        )
        
        let isValid = factory.validateConfiguration(config, for: .mock)
        #expect(isValid)
    }
    
    @Test("Validate invalid provider configuration")
    func testValidateInvalidProviderConfiguration() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        let invalidConfig = RealtimeConfig(
            appId: "", // Empty app ID
            appKey: "test_app_key",
            logLevel: .debug
        )
        
        let isValid = factory.validateConfiguration(invalidConfig, for: .mock)
        #expect(!isValid)
    }
    
    // MARK: - Provider Lifecycle Tests
    
    @Test("Provider factory lifecycle")
    func testProviderFactoryLifecycle() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        // Register
        try factory.registerProvider(.mock, factory: mockFactory)
        #expect(factory.isProviderRegistered(.mock))
        
        // Create providers
        let rtcProvider = try factory.createRTCProvider(type: .mock)
        let rtmProvider = try factory.createRTMProvider(type: .mock)
        
        #expect(rtcProvider is MockRTCProvider)
        #expect(rtmProvider is MockRTMProvider)
        
        // Unregister
        factory.unregisterProvider(.mock)
        #expect(!factory.isProviderRegistered(.mock))
        
        // Should fail to create after unregistering
        #expect(throws: RealtimeError.self) {
            let _ = try factory.createRTCProvider(type: .mock)
        }
    }
    
    // MARK: - Provider Discovery Tests
    
    @Test("Get available providers")
    func testGetAvailableProviders() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        let agoraFactory = AgoraProviderFactory()
        
        #expect(factory.getAvailableProviders().isEmpty)
        
        try factory.registerProvider(.mock, factory: mockFactory)
        #expect(factory.getAvailableProviders() == [.mock])
        
        try factory.registerProvider(.agora, factory: agoraFactory)
        #expect(factory.getAvailableProviders().count == 2)
        #expect(factory.getAvailableProviders().contains(.mock))
        #expect(factory.getAvailableProviders().contains(.agora))
    }
    
    @Test("Get providers by feature")
    func testGetProvidersByFeature() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        let agoraFactory = AgoraProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        try factory.registerProvider(.agora, factory: agoraFactory)
        
        let audioProviders = factory.getProvidersSupporting(.audioStreaming)
        let videoProviders = factory.getProvidersSupporting(.videoStreaming)
        
        #expect(audioProviders.contains(.mock))
        #expect(audioProviders.contains(.agora))
        #expect(videoProviders.contains(.agora))
        #expect(!videoProviders.contains(.mock))
    }
    
    // MARK: - Configuration Tests
    
    @Test("Provider factory configuration")
    func testProviderFactoryConfiguration() throws {
        let factory = createFactory()
        
        let config = ProviderFactoryConfig(
            enableFeatureValidation: true,
            enableConfigurationValidation: true,
            allowDuplicateRegistration: false
        )
        
        factory.configure(with: config)
        
        #expect(factory.configuration.enableFeatureValidation)
        #expect(factory.configuration.enableConfigurationValidation)
        #expect(!factory.configuration.allowDuplicateRegistration)
    }
    
    @Test("Feature validation enforcement")
    func testFeatureValidationEnforcement() throws {
        let factory = createFactory()
        
        let config = ProviderFactoryConfig(
            enableFeatureValidation: true,
            enableConfigurationValidation: false,
            allowDuplicateRegistration: false
        )
        
        factory.configure(with: config)
        
        let mockFactory = MockProviderFactory()
        try factory.registerProvider(.mock, factory: mockFactory)
        
        // Should validate that mock provider doesn't support video streaming
        #expect(!factory.supportsFeature(.videoStreaming, for: .mock))
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle provider creation failure")
    func testHandleProviderCreationFailure() throws {
        let factory = createFactory()
        let failingFactory = FailingProviderFactory()
        
        try factory.registerProvider(.mock, factory: failingFactory)
        
        #expect(throws: RealtimeError.self) {
            let _ = try factory.createRTCProvider(type: .mock)
        }
    }
    
    @Test("Handle provider initialization failure")
    func testHandleProviderInitializationFailure() throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        let rtcProvider = try factory.createRTCProvider(type: .mock)
        
        // Mock provider should handle initialization gracefully
        let config = RTCConfig(
            appId: "test_app_id",
            appKey: "test_app_key",
            logLevel: .debug
        )
        
        // Should not throw for mock provider
        try await rtcProvider.initialize(config: config)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent provider registration")
    func testConcurrentProviderRegistration() async throws {
        let factory = createFactory()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    let mockFactory = MockProviderFactory()
                    let providerType = ProviderType.allCases[i % ProviderType.allCases.count]
                    
                    do {
                        try factory.registerProvider(providerType, factory: mockFactory)
                    } catch {
                        // Some registrations may fail due to duplicates
                    }
                }
            }
        }
        
        // Should have at least some providers registered
        #expect(!factory.registeredProviders.isEmpty)
    }
    
    @Test("Concurrent provider creation")
    func testConcurrentProviderCreation() async throws {
        let factory = createFactory()
        let mockFactory = MockProviderFactory()
        
        try factory.registerProvider(.mock, factory: mockFactory)
        
        var createdProviders: [RTCProvider] = []
        let lock = NSLock()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        let provider = try factory.createRTCProvider(type: .mock)
                        lock.lock()
                        createdProviders.append(provider)
                        lock.unlock()
                    } catch {
                        // Handle creation errors
                    }
                }
            }
        }
        
        #expect(createdProviders.count == 10)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Provider factory memory management")
    func testProviderFactoryMemoryManagement() throws {
        var factory: ProviderFactory? = createFactory()
        let mockFactory = MockProviderFactory()
        
        weak var weakFactory = factory
        
        try factory?.registerProvider(.mock, factory: mockFactory)
        
        factory = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakFactory == nil)
    }
    
    // MARK: - Helper Classes
    
    class FailingProviderFactory: RealtimeProviderFactory {
        func createRTCProvider() -> RTCProvider {
            fatalError("Provider creation failed")
        }
        
        func createRTMProvider() -> RTMProvider {
            fatalError("Provider creation failed")
        }
        
        func supportedFeatures() -> Set<ProviderFeature> {
            return []
        }
        
        func validateConfiguration(_ config: RealtimeConfig) -> Bool {
            return false
        }
    }
    
    class AgoraProviderFactory: RealtimeProviderFactory {
        func createRTCProvider() -> RTCProvider {
            return MockRTCProvider() // Using mock for testing
        }
        
        func createRTMProvider() -> RTMProvider {
            return MockRTMProvider() // Using mock for testing
        }
        
        func supportedFeatures() -> Set<ProviderFeature> {
            return [.audioStreaming, .videoStreaming, .streamPush, .mediaRelay]
        }
        
        func validateConfiguration(_ config: RealtimeConfig) -> Bool {
            return !config.appId.isEmpty && !config.appKey.isEmpty
        }
    }
}