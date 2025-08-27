import Foundation

/// RealtimeKit 主模块
/// 统一导出所有子模块的功能
/// 需求: 12.1, 12.2

// MARK: - 核心模块导出
@_exported import RealtimeCore

// MARK: - UI 集成模块导出
#if canImport(UIKit)
@_exported import RealtimeUIKit
#endif

#if canImport(SwiftUI)
@_exported import RealtimeSwiftUI
#endif

// MARK: - 服务商实现模块导出
@_exported import RealtimeAgora

// MARK: - 测试模块导出
@_exported import RealtimeMocking

/// RealtimeKit 主要入口点
public final class RealtimeKit {
    /// 版本信息
    public static let version = RealtimeKitVersion.current
    
    /// 构建号
    public static let buildNumber = RealtimeKitVersion.buildNumber
    
    /// Swift 版本要求
    public static let requiredSwiftVersion = RealtimeKitVersion.swiftVersion
    
    /// 支持的平台
    public static let supportedPlatforms: [String] = {
        var platforms: [String] = []
        
        #if os(iOS)
        platforms.append("iOS 13.0+")
        #endif
        
        #if os(macOS)
        platforms.append("macOS 10.15+")
        #endif
        
        return platforms
    }()
    
    /// 可用的服务商
    public static let availableProviders: [ProviderType] = [
        .agora,
        .mock
    ]
    
    /// 初始化 RealtimeKit
    /// - Returns: 是否初始化成功
    public static func initialize() -> Bool {
        print("RealtimeKit \(version) 初始化成功")
        print("支持的平台: \(supportedPlatforms.joined(separator: ", "))")
        print("可用的服务商: \(availableProviders.map { $0.displayName }.joined(separator: ", "))")
        return true
    }
    
    private init() {}
}