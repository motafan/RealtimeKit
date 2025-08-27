import Testing
import Foundation
@testable import RealtimeCore

/// 服务商切换管理器测试
/// 需求: 2.2, 2.3, 2.4, 17.6
@MainActor
struct ProviderSwitchManagerTests {
    
    // MARK: - Test Properties
    
    private var switchManager: ProviderSwitchManager!
    private var mockFactory: MockProviderFactory!
    private var agoraFactory: AgoraProviderFactory!
    
    // MARK: - Setup and Teardown
    
    init() async {
        switchManager = ProviderSwitchManager()
        mockFactory = MockProviderFactory()
        agoraFactory = AgoraProviderFactory()
    }
    
    // MARK: - Provider Registration Tests (需求 2.2)
    
    @Test("Provider factory registration")
    func testProviderFactoryRegistration() async {
        // 注册 Mock 工厂
        switchManager.registerProvider(.mock, factory: mockFactory)
        
        // 验证注册成功
        #expect(switchManager.availableProviders.contains(.mock))
        #expect(switchManager.getProviderFactory(for: .mock) != nil)
        
        // 验证支持的功能
        let features = switchManager.getSupportedFeatures(for: .mock)
        #expect(!features.isEmpty)
        #expect(features.contains(.audioStreaming))
    }
    
    @Test("Multiple provider registration")
    func testMultipleProviderRegistration() async {
        // 注册多个服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        switchManager.registerProvider(.agora, factory: agoraFactory)
        
        // 验证都已注册
        #expect(switchManager.availableProviders.count == 2)
        #expect(switchManager.availableProviders.contains(.mock))
        #expect(switchManager.availableProviders.contains(.agora))
        
        // 验证按优先级排序
        let sortedProviders = switchManager.availableProviders
        #expect(sortedProviders.first?.priority ?? Int.max <= sortedProviders.last?.priority ?? Int.min)
    }
    
    @Test("Provider unregistration")
    func testProviderUnregistration() async {
        // 先注册
        switchManager.registerProvider(.mock, factory: mockFactory)
        #expect(switchManager.availableProviders.contains(.mock))
        
        // 注销
        switchManager.unregisterProvider(.mock)
        #expect(!switchManager.availableProviders.contains(.mock))
        #expect(switchManager.getProviderFactory(for: .mock) == nil)
    }
    
    // MARK: - Provider Switching Tests (需求 2.3)
    
    @Test("Basic provider switching")
    func testBasicProviderSwitching() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        switchManager.registerProvider(.agora, factory: agoraFactory)
        
        // 初始状态应该是 mock
        #expect(switchManager.currentProvider == .mock)
        
        // 切换到 Agora
        let success = await switchManager.switchProvider(to: .agora, preserveSession: true, reason: "测试切换")
        
        // 验证切换成功
        #expect(success)
        #expect(switchManager.currentProvider == .agora)
        #expect(!switchManager.switchingInProgress)
    }
    
    @Test("Switch to same provider")
    func testSwitchToSameProvider() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        
        // 切换到相同的服务商
        let success = await switchManager.switchProvider(to: .mock, preserveSession: true, reason: "相同服务商")
        
        // 应该成功但不执行实际切换
        #expect(success)
        #expect(switchManager.currentProvider == .mock)
    }
    
    @Test("Switch to unavailable provider")
    func testSwitchToUnavailableProvider() async {
        // 不注册任何服务商，尝试切换到未注册的服务商
        let success = await switchManager.switchProvider(to: .agora, preserveSession: true, reason: "不可用服务商")
        
        // 应该失败
        #expect(!success)
        #expect(switchManager.lastSwitchError != nil)
    }
    
    @Test("Provider switching with session preservation")
    func testProviderSwitchingWithSessionPreservation() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        switchManager.registerProvider(.agora, factory: agoraFactory)
        
        // 切换并保持会话
        let success = await switchManager.switchProvider(to: .agora, preserveSession: true, reason: "保持会话")
        
        #expect(success)
        #expect(switchManager.currentProvider == .agora)
    }
    
    @Test("Provider switching without session preservation")
    func testProviderSwitchingWithoutSessionPreservation() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        switchManager.registerProvider(.agora, factory: agoraFactory)
        
        // 切换不保持会话
        let success = await switchManager.switchProvider(to: .agora, preserveSession: false, reason: "不保持会话")
        
        #expect(success)
        #expect(switchManager.currentProvider == .agora)
    }
    
    // MARK: - Fallback Tests (需求 2.4)
    
    @Test("Fallback chain configuration")
    func testFallbackChainConfiguration() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        switchManager.registerProvider(.agora, factory: agoraFactory)
        
        // 设置降级链
        let fallbackChain: [ProviderType] = [.agora, .mock]
        switchManager.setFallbackChain(fallbackChain)
        
        // 验证降级链设置
        let configuredChain = switchManager.getFallbackChain()
        #expect(configuredChain == fallbackChain)
    }
    
    @Test("Automatic fallback on provider failure")
    func testAutomaticFallbackOnProviderFailure() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        switchManager.registerProvider(.agora, factory: agoraFactory)
        
        // 设置降级链
        switchManager.setFallbackChain([.agora, .mock])
        
        // 模拟当前服务商故障，触发降级
        let fallbackSuccess = await switchManager.attemptFallbackSwitch(reason: "服务商故障测试")
        
        // 验证降级成功
        #expect(fallbackSuccess)
    }
    
    @Test("Fallback with unhealthy providers")
    func testFallbackWithUnhealthyProviders() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        switchManager.registerProvider(.agora, factory: agoraFactory)
        
        // 设置降级链
        switchManager.setFallbackChain([.agora, .mock])
        
        // 标记 Agora 为不健康
        switchManager.resetProviderHealthStatus(.agora)
        if var healthStatus = switchManager.getProviderHealthStatus(.agora) {
            healthStatus.status = .unhealthy
            healthStatus.errorCount = 5
        }
        
        // 尝试降级
        let fallbackSuccess = await switchManager.attemptFallbackSwitch(reason: "不健康服务商测试")
        
        // 应该跳过不健康的服务商
        #expect(fallbackSuccess)
    }
    
    // MARK: - Health Monitoring Tests
    
    @Test("Provider health status initialization")
    func testProviderHealthStatusInitialization() async {
        // 注册服务商
        switchManager.registerProvider(.mock, factory: mockFactory)
        
        // 验证健康状态已初始化
        let hea