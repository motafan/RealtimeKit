import Testing
import Foundation
@testable import RealtimeCore
@testable import RealtimeAgora
@testable import RealtimeMocking

/// Provider Factory and Switching Tests
/// 需求: 2.2, 2.3, 2.4, 17.6 - 服务商工厂和切换机制测试
@MainActor
@Suite(.serialized)
struct ProviderFactoryTests {
    
    // MARK: - Helper Methods
    
    /// 重置管理器状态的辅助方法
    private func resetManagerState(_ manager: RealtimeManager) async {
        // 登出用户
        if manager.currentSession != nil {
            try? await manager.logoutUser()
        }
        
        // 等待状态清理
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        
        // 重置连接状态
        // 注意：这里我们不能直接访问私有属性，所以只能通过公共方法来重置
    }
    
    // MARK: - Provider Factory Tests
    
    @Test("Provider Factory Registration")
    func testProviderFactoryRegistration() async throws {
        let manager = RealtimeManager.shared
        
        // 注册 Agora 工厂
        let agoraFactory = AgoraProviderFactory()
        manager.registerProviderFactory(.agora, factory: agoraFactory)
        
        // 验证工厂注册
        let registeredFactory = manager.getProviderFactory(for: .agora)
        #expect(registeredFactory != nil)
        
        // 验证支持的功能
        let features = manager.getSupportedFeatures(for: .agora)
        #expect(features.contains(.audioStreaming))
        #expect(features.contains(.volumeIndicator))
        #expect(features.contains(.streamPush))
        #expect(features.contains(.mediaRelay))
    }
    
    @Test("Provider Factory Creation")
    func testProviderFactoryCreation() {
        let agoraFactory = AgoraProviderFactory()
        
        // 测试创建 RTC Provider
        let rtcProvider = agoraFactory.createRTCProvider()
        #expect(rtcProvider is AgoraRTCProvider)
        
        // 测试创建 RTM Provider
        let rtmProvider = agoraFactory.createRTMProvider()
        #expect(rtmProvider is AgoraRTMProvider)
        
        // 测试支持的功能
        let features = agoraFactory.supportedFeatures()
        #expect(features.count > 0)
        #expect(features.contains(.audioStreaming))
    }
    
    @Test("Mock Provider Factory")
    func testMockProviderFactory() {
        // 测试 RealtimeMocking 模块的 MockProviderFactory
        let mockingFactory = RealtimeMocking.MockProviderFactory()
        
        let rtcProvider = mockingFactory.createRTCProvider()
        #expect(rtcProvider is MockRTCProvider)
        
        let rtmProvider = mockingFactory.createRTMProvider()
        #expect(rtmProvider is MockRTMProvider)
        
        // Mock 应该支持所有功能
        let features = mockingFactory.supportedFeatures()
        #expect(features == Set(ProviderFeature.allCases))
        
        // 测试 RealtimeCore 内部的 MockProviderFactory
        let coreFactory = MockProviderFactory()
        let coreRtcProvider = coreFactory.createRTCProvider()
        #expect(coreRtcProvider is InternalMockRTCProvider) // 验证类型正确
        
        let coreFeatures = coreFactory.supportedFeatures()
        #expect(coreFeatures == Set(ProviderFeature.allCases))
    }
    
    // MARK: - Provider Switching Tests
    
    @Test("Provider Switching Basic")
    func testProviderSwitchingBasic() async throws {
        let manager = RealtimeManager.shared
        
        // 完全重置管理器状态
        await resetManagerState(manager)
        
        // 注册多个工厂
        manager.registerProviderFactory(.agora, factory: AgoraProviderFactory())
        manager.registerProviderFactory(.mock, factory: MockProviderFactory())
        
        // 配置初始服务商
        let config = RealtimeConfig(
            appId: "test_app_id_basic",
            region: .global
        )
        
        try await manager.configure(provider: .mock, config: config)
        #expect(manager.currentProvider == .mock)
        
        // 建立用户会话以便进行切换
        try await manager.loginUser(
            userId: "test_user_basic",
            userName: "Test User Basic", 
            userRole: .broadcaster
        )
        
        // 切换到 Agora
        try await manager.switchProvider(to: .agora, preserveSession: false)
        #expect(manager.currentProvider == .agora)
        
        // 切换回 Mock
        try await manager.switchProvider(to: .mock, preserveSession: false)
        #expect(manager.currentProvider == .mock)
        
        // 清理
        try? await manager.logoutUser()
    }
    
    @Test("Provider Switching with Session Preservation")
    func testProviderSwitchingWithSessionPreservation() async throws {
        let manager = RealtimeManager.shared
        
        // 完全重置管理器状态
        await resetManagerState(manager)
        
        // 注册工厂
        manager.registerProviderFactory(.agora, factory: AgoraProviderFactory())
        manager.registerProviderFactory(.mock, factory: MockProviderFactory())
        
        // 配置和登录
        let config = RealtimeConfig(appId: "test_app_id_preservation")
        try await manager.configure(provider: .mock, config: config)
        
        try await manager.loginUser(
            userId: "test_user_preservation",
            userName: "Test User Preservation",
            userRole: .broadcaster
        )
        
        let originalSession = manager.currentSession
        #expect(originalSession != nil)
        
        // 切换服务商并保持会话
        try await manager.switchProvider(to: .agora, preserveSession: true)
        
        // 验证会话保持
        let newSession = manager.currentSession
        #expect(newSession?.userId == originalSession?.userId)
        #expect(newSession?.userRole == originalSession?.userRole)
        
        // 清理
        try? await manager.logoutUser()
    }
    
    @Test("Provider Fallback Chain")
    func testProviderFallbackChain() async throws {
        let manager = RealtimeManager.shared
        
        // 完全重置管理器状态
        await resetManagerState(manager)
        
        // 只注册 Mock 工厂（模拟其他服务商不可用）
        manager.registerProviderFactory(.mock, factory: MockProviderFactory())
        
        // 设置降级链
        manager.setFallbackChain([.tencent, .mock])
        
        let config = RealtimeConfig(appId: "test_app_id_fallback")
        try await manager.configure(provider: .mock, config: config)
        
        // 建立用户会话
        try await manager.loginUser(
            userId: "test_user_fallback",
            userName: "Test User Fallback",
            userRole: .broadcaster
        )
        
        // 尝试切换到不可用的服务商，应该降级到 Mock
        do {
            try await manager.switchProvider(to: .tencent, preserveSession: false)
            // 如果没有抛出错误，说明降级成功
            #expect(manager.currentProvider == .mock)
        } catch {
            // 如果抛出错误，验证是正确的错误类型
            if case RealtimeError.providerNotAvailable = error {
                // 这是预期的错误
            } else if case RealtimeError.allProvidersFailed = error {
                // 这也是预期的错误（所有降级选项都失败）
            } else {
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        }
        
        // 清理
        try? await manager.logoutUser()
    }
    
    @Test("Provider Feature Compatibility")
    func testProviderFeatureCompatibility() async throws {
        let manager = RealtimeManager.shared
        
        // 注册不同的工厂
        manager.registerProviderFactory(.agora, factory: AgoraProviderFactory())
        manager.registerProviderFactory(.mock, factory: MockProviderFactory())
        
        // 检查 Agora 功能
        let agoraFeatures = manager.getSupportedFeatures(for: .agora)
        #expect(agoraFeatures.contains(.audioStreaming))
        #expect(agoraFeatures.contains(.streamPush))
        #expect(agoraFeatures.contains(.mediaRelay))
        
        // 检查 Mock 功能（应该支持所有功能）
        let mockFeatures = manager.getSupportedFeatures(for: .mock)
        #expect(mockFeatures == Set(ProviderFeature.allCases))
        
        // 检查不存在的服务商
        let unknownFeatures = manager.getSupportedFeatures(for: .tencent)
        #expect(unknownFeatures.isEmpty)
    }
    
    @Test("Provider Switching Error Handling")
    func testProviderSwitchingErrorHandling() async throws {
        let manager = RealtimeManager.shared
        
        // 完全重置管理器状态
        await resetManagerState(manager)
        
        // 只注册 Mock 工厂
        manager.registerProviderFactory(.mock, factory: MockProviderFactory())
        
        let config = RealtimeConfig(appId: "test_app_id_error")
        try await manager.configure(provider: .mock, config: config)
        
        // 建立用户会话
        try await manager.loginUser(
            userId: "test_user_error",
            userName: "Test User Error",
            userRole: .broadcaster
        )
        
        // 尝试切换到未注册的服务商
        do {
            try await manager.switchProvider(to: .tencent, preserveSession: false)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as RealtimeError {
            switch error {
            case .providerNotAvailable(let provider):
                #expect(provider == .tencent)
            case .allProvidersFailed:
                // 这也是可接受的错误类型
                break
            default:
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
        
        // 清理
        try? await manager.logoutUser()
    }
    
    @Test("Provider Switching Performance")
    func testProviderSwitchingPerformance() async throws {
        let manager = RealtimeManager.shared
        
        // 完全重置管理器状态
        await resetManagerState(manager)
        
        // 注册工厂
        manager.registerProviderFactory(.agora, factory: AgoraProviderFactory())
        manager.registerProviderFactory(.mock, factory: MockProviderFactory())
        
        let config = RealtimeConfig(appId: "test_app_id_performance")
        try await manager.configure(provider: .mock, config: config)
        
        // 建立用户会话以便进行切换
        try await manager.loginUser(
            userId: "test_user_performance",
            userName: "Test User Performance",
            userRole: .broadcaster
        )
        
        // 测试多次切换的性能
        let startTime = Date()
        
        for i in 0..<5 {
            let targetProvider: ProviderType = (i % 2 == 0) ? .agora : .mock
            try await manager.switchProvider(to: targetProvider, preserveSession: false)
            #expect(manager.currentProvider == targetProvider)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 验证切换在合理时间内完成
        #expect(duration < 10.0) // 应该在10秒内完成5次切换
        print("5次服务商切换耗时: \(duration)秒")
        
        // 清理
        try? await manager.logoutUser()
    }
    
    // MARK: - Localized Provider Switching Tests
    
    @Test("Localized Provider Names")
    func testLocalizedProviderNames() async throws {
        // 测试服务商名称本地化
        #expect(ProviderType.agora.displayName.count > 0)
        #expect(ProviderType.tencent.displayName.count > 0)
        #expect(ProviderType.zego.displayName.count > 0)
        #expect(ProviderType.mock.displayName.count > 0)
        
        // 测试服务商描述
        #expect(ProviderType.agora.description.count > 0)
        #expect(ProviderType.mock.description.count > 0)
    }
    
    @Test("Provider Priority")
    func testProviderPriority() async throws {
        // 测试服务商优先级
        #expect(ProviderType.agora.priority < ProviderType.tencent.priority)
        #expect(ProviderType.tencent.priority < ProviderType.zego.priority)
        #expect(ProviderType.zego.priority < ProviderType.mock.priority)
        
        // Mock 应该是最低优先级
        #expect(ProviderType.mock.priority == 999)
        
        // 生产环境服务商检查
        #expect(ProviderType.agora.isProductionProvider == true)
        #expect(ProviderType.mock.isProductionProvider == false)
    }
}