import Foundation
import Combine
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// RealtimeManager 核心管理器
/// 统一管理所有实时通信功能
/// 需求: 3.1, 3.2, 2.3, 17.2

@MainActor
public class RealtimeManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = RealtimeManager()
    
    // MARK: - Published Properties for SwiftUI (需求 3.2, 3.3, 11.3, 17.3, 18.10)
    
    /// 当前用户会话（响应式）
    @Published public internal(set) var currentSession: UserSession?
    
    /// 连接状态（响应式）
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    
    /// 推流状态（响应式）
    @Published public private(set) var streamPushState: StreamPushState = .stopped
    
    /// 媒体中继状态（响应式）
    @Published public private(set) var mediaRelayState: MediaRelayState?
    
    /// 音量信息列表（响应式）
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    
    /// 正在说话的用户集合（响应式）
    @Published public private(set) var speakingUsers: Set<String> = []
    
    /// 主讲人用户ID（响应式）
    @Published public private(set) var dominantSpeaker: String? = nil
    
    /// 服务商切换进行中标志（响应式）
    @Published public private(set) var switchingInProgress: Bool = false
    
    /// 本地化的连接状态显示文本（响应式）
    @Published public private(set) var localizedConnectionState: String = ""
    
    /// 本地化的用户角色显示文本（响应式）
    @Published public private(set) var localizedUserRole: String = ""
    
    /// 本地化的服务商显示文本（响应式）
    @Published public private(set) var localizedProviderName: String = ""
    
    /// 音频状态信息（响应式）
    @Published public private(set) var audioStatusInfo: AudioStatusInfo = AudioStatusInfo(
        settings: .default,
        isProviderConnected: false,
        hasAudioPermission: false,
        currentUserRole: nil,
        lastModified: Date()
    )
    
    /// 错误状态（响应式）
    @Published public private(set) var lastError: LocalizedRealtimeError?
    
    /// 是否正在执行异步操作（响应式）
    @Published public private(set) var isPerformingAsyncOperation: Bool = false
    
    // MARK: - Persistent State Properties (需求 18.1, 18.2, 18.3, 18.10)
    
    /// 音频设置的自动持久化和响应式更新 (需求 3.2, 5.4, 5.5, 18.1, 18.2)
    @Published public private(set) var audioSettings: AudioSettings = .default
    
    /// 音频设置的持久化存储 (需求 18.1, 18.2)
    @RealtimeStorage("audioSettings", namespace: "RealtimeKit.Manager")
    private var _persistedAudioSettings: AudioSettings = .default
    
    /// 当前服务商的自动持久化 (需求 18.1, 18.2)
    @RealtimeStorage("currentProvider", namespace: "RealtimeKit.Manager")
    public var currentProvider: ProviderType = .mock
    
    /// 可用服务商列表的自动持久化 (需求 18.1, 18.2)
    @RealtimeStorage("availableProviders", namespace: "RealtimeKit.Manager")
    public var availableProviders: [ProviderType] = []
    
    /// 连接历史记录的自动持久化 (需求 18.1, 18.2)
    @RealtimeStorage("connectionHistory", namespace: "RealtimeKit.Manager")
    internal var connectionHistory: [ConnectionHistoryEntry] = []
    
    /// 用户偏好设置的自动持久化 (需求 18.1, 18.2)
    @RealtimeStorage("userPreferences", namespace: "RealtimeKit.Manager")
    internal var userPreferences: RealtimeManagerPreferences = RealtimeManagerPreferences()
    
    /// 敏感认证令牌的安全存储 (需求 18.2, 18.5)
    @SecureRealtimeStorage("authTokens", namespace: "RealtimeKit.Manager")
    internal var authTokens: [String: String] = [:]
    
    /// 应用状态恢复信息的自动持久化 (需求 18.1, 18.3)
    @RealtimeStorage("appStateRecovery", namespace: "RealtimeKit.Manager")
    internal var appStateRecovery: AppStateRecoveryInfo = AppStateRecoveryInfo()
    
    // MARK: - Private Properties - Core Managers
    
    private let settingsStorage = AudioSettingsStorage()
    internal let sessionStorage = UserSessionStorage()
    private let tokenManager = TokenManager()
    internal let volumeManager = VolumeIndicatorManager()
    private let mediaRelayManager = MediaRelayManager()
    private let streamPushManager = StreamPushManager()
    private let localizationManager = LocalizationManager.shared // 需求: 17.2
    private let messageProcessingManager = MessageProcessingManager()
    
    // MARK: - Combine Publishers and Cancellables (需求 3.3, 11.3, 11.5)
    
    /// Combine 取消令牌集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 异步数据流主题
    private let asyncOperationSubject = PassthroughSubject<AsyncOperationEvent, Never>()
    private let errorSubject = PassthroughSubject<LocalizedRealtimeError, Never>()
    private let stateChangeSubject = PassthroughSubject<StateChangeEvent, Never>()
    
    // MARK: - Private Properties - Provider Management (需求 2.3)
    
    internal var rtcProvider: RTCProvider?
    internal var rtmProvider: RTMProvider?
    internal var currentConfig: RealtimeConfig?
    private let providerSwitchManager = ProviderSwitchManager()
    
    // MARK: - Initialization
    
    private init() {
        // 从持久化存储恢复音频设置 (需求: 18.1, 18.3)
        audioSettings = _persistedAudioSettings
        
        // 初始化默认服务商工厂
        setupDefaultProviderFactories()
        
        // 设置本地化管理器监听 (需求: 17.2)
        setupLocalizationObserver()
        
        // 设置持久化状态监听 (需求: 18.1, 18.2, 18.3)
        setupPersistentStateObservers()
        
        // 设置响应式数据流 (需求: 3.3, 11.3, 11.5)
        setupReactiveDataStreams()
        
        // 初始化本地化文本 (需求: 17.3)
        updateLocalizedTexts()
        
        // 执行应用启动时的自动状态恢复 (需求: 18.3)
        Task {
            await performStartupStateRecovery()
        }
    }
    
    deinit {
        // 清理通知观察者
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Provider Factory Management (需求 2.2, 2.3)
    
    /// 注册服务商工厂
    /// - Parameters:
    ///   - type: 服务商类型
    ///   - factory: 服务商工厂实例
    public func registerProviderFactory(_ type: ProviderType, factory: ProviderFactory) {
        providerSwitchManager.registerProvider(type, factory: factory)
        availableProviders = providerSwitchManager.availableProviders
        print("已注册服务商工厂: \(type.displayName)")
    }
    
    /// 获取已注册的服务商工厂
    /// - Parameter type: 服务商类型
    /// - Returns: 服务商工厂实例，如果未注册则返回 nil
    public func getProviderFactory(for type: ProviderType) -> ProviderFactory? {
        return providerSwitchManager.getProviderFactory(for: type)
    }
    
    /// 获取服务商支持的功能特性
    /// - Parameter type: 服务商类型
    /// - Returns: 支持的功能特性集合
    public func getSupportedFeatures(for type: ProviderType) -> Set<ProviderFeature> {
        return providerSwitchManager.getSupportedFeatures(for: type)
    }
    
    /// 设置服务商降级链
    /// - Parameter chain: 降级链，按优先级排序
    public func setFallbackChain(_ chain: [ProviderType]) {
        providerSwitchManager.setFallbackChain(chain)
        print("设置降级链: \(chain.map { $0.displayName }.joined(separator: " -> "))")
    }
    
    /// 设置默认服务商工厂
    private func setupDefaultProviderFactories() {
        // Mock 工厂已在 ProviderSwitchManager 中注册
    }
    
    /// 设置本地化管理器监听 (需求: 17.2)
    private func setupLocalizationObserver() {
        NotificationCenter.default.addObserver(
            forName: .realtimeLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 语言变化时更新错误消息和用户界面
            Task { @MainActor in
                self?.handleLanguageChange()
            }
        }
    }
    
    /// 处理语言变化通知 (需求: 17.2)
    private func handleLanguageChange() {
        // 这里可以添加语言变化后的处理逻辑
        // 例如更新错误消息、重新加载本地化资源等
        print("语言已切换到: \(localizationManager.currentLanguage.displayName)")
    }
    
    /// 设置持久化状态监听 (需求: 18.1, 18.2, 18.3)
    private func setupPersistentStateObservers() {
        #if os(iOS)
        // 监听应用进入后台
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        
        // 监听应用即将终止
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillTerminate()
            }
        }
        
        // 监听应用从后台返回
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillEnterForeground()
            }
        }
        #elseif os(macOS)
        // 监听应用即将终止
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillTerminate()
            }
        }
        
        // 监听应用变为活跃
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillEnterForeground()
            }
        }
        
        // 监听应用失去焦点
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        #endif
    }
    
    /// 执行应用启动时的自动状态恢复 (需求: 18.3)
    private func performStartupStateRecovery() async {
        do {
            // 检查是否需要恢复状态
            guard appStateRecovery.canAttemptRecovery else {
                print("状态恢复: 已达到最大尝试次数，跳过恢复")
                return
            }
            
            // 检查恢复信息是否过期
            if appStateRecovery.isRecoveryInfoExpired() {
                print("状态恢复: 恢复信息已过期，清理过期信息")
                appStateRecovery = AppStateRecoveryInfo()
                return
            }
            
            print("开始执行应用启动状态恢复...")
            
            // 增加恢复尝试次数
            appStateRecovery = appStateRecovery.withIncrementedRecoveryAttempts()
            
            // 恢复音频设置 (音频设置已通过 @RealtimeStorage 自动恢复)
            if appStateRecovery.needsAudioSettingsRecovery {
                print("恢复音频设置...")
                // 需要手动同步到 RTC Provider，因为 @RealtimeStorage 只恢复本地状态
                do {
                    try await applyAudioSettingsToProvider(audioSettings)
                    print("音频设置已同步到 RTC Provider")
                } catch {
                    print("音频设置同步失败: \(error)")
                }
            }
            
            // 恢复用户会话
            if appStateRecovery.needsSessionRecovery {
                print("恢复用户会话...")
                await restoreUserSession()
            }
            
            // 恢复连接状态
            if let lastProvider = appStateRecovery.lastUsedProvider,
               let config = currentConfig {
                print("恢复连接状态，使用服务商: \(lastProvider.displayName)")
                do {
                    try await configure(provider: lastProvider, config: config)
                } catch {
                    print("连接状态恢复失败，尝试降级: \(error)")
                    try await attemptFallback(originalError: error)
                }
            }
            
            // 标记恢复完成
            appStateRecovery = appStateRecovery.withResetRecoveryAttempts()
            print("应用启动状态恢复完成")
            
        } catch {
            print("应用启动状态恢复失败: \(error)")
        }
    }
    
    /// 恢复用户会话
    private func restoreUserSession() async {
        if let session = sessionStorage.loadUserSession() {
            currentSession = session
            print("用户会话恢复完成: \(session.userName) (\(session.userRole.displayName))")
        }
    }
    
    /// 处理应用进入后台 (需求: 18.1, 18.3)
    private func handleAppDidEnterBackground() {
        // 保存当前状态
        updateAppStateRecoveryInfo()
        
        // 记录连接历史
        if connectionState == .connected {
            recordConnectionHistory(success: true)
        }
        
        print("应用进入后台，状态已保存")
    }
    
    /// 处理应用即将终止 (需求: 18.1, 18.3)
    private func handleAppWillTerminate() {
        // 标记正常退出
        appStateRecovery = appStateRecovery.withNormalExit()
        
        // 记录连接历史
        recordConnectionHistory(success: true)
        
        print("应用即将终止，状态已保存")
    }
    
    /// 处理应用从后台返回 (需求: 18.3)
    private func handleAppWillEnterForeground() {
        // 检查连接状态，如果需要则重新连接
        if userPreferences.enableAutoReconnect && connectionState == .disconnected {
            Task {
                await attemptAutoReconnect()
            }
        }
        
        print("应用从后台返回")
    }
    
    /// 更新应用状态恢复信息 (需求: 18.1, 18.3)
    private func updateAppStateRecoveryInfo() {
        var recoveryInfo = appStateRecovery
        recoveryInfo.lastSuccessfulConnection = connectionState == .connected ? Date() : recoveryInfo.lastSuccessfulConnection
        recoveryInfo.lastUsedProvider = currentProvider
        recoveryInfo.lastRoomId = currentSession?.roomId
        recoveryInfo.lastUserRole = currentSession?.userRole
        recoveryInfo.needsSessionRecovery = currentSession != nil
        recoveryInfo.needsAudioSettingsRecovery = true
        
        appStateRecovery = recoveryInfo
    }
    
    /// 记录连接历史 (需求: 18.1, 18.2)
    private func recordConnectionHistory(success: Bool, error: String? = nil) {
        guard userPreferences.enableConnectionHistory else { return }
        
        let entry = ConnectionHistoryEntry(
            provider: currentProvider,
            success: success,
            errorMessage: error,
            roomId: currentSession?.roomId,
            userId: currentSession?.userId
        )
        
        connectionHistory.append(entry)
        
        // 保持历史记录数量限制
        let maxEntries = userPreferences.maxConnectionHistoryEntries
        if connectionHistory.count > maxEntries {
            connectionHistory = Array(connectionHistory.suffix(maxEntries))
        }
    }
    
    /// 尝试自动重连 (需求: 18.3)
    private func attemptAutoReconnect() async {
        guard userPreferences.enableAutoReconnect else { return }
        
        var attempts = 0
        while attempts < userPreferences.maxReconnectAttempts && connectionState != .connected {
            attempts += 1
            
            do {
                print("尝试自动重连 (\(attempts)/\(userPreferences.maxReconnectAttempts))...")
                
                if let config = currentConfig {
                    try await configure(provider: currentProvider, config: config)
                    print("自动重连成功")
                    return
                }
                
            } catch {
                print("自动重连失败 (\(attempts)/\(userPreferences.maxReconnectAttempts)): \(error)")
                
                if attempts < userPreferences.maxReconnectAttempts {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(userPreferences.reconnectInterval * 1_000_000_000))
                    } catch {
                        print("重连延迟被中断: \(error)")
                        break
                    }
                }
            }
        }
        
        print("自动重连已达到最大尝试次数")
    }
    
    // MARK: - SwiftUI Reactive Support and Combine Integration (需求 3.3, 11.3, 11.5, 17.3, 18.10)
    
    /// 异步操作事件发布者
    public var asyncOperationPublisher: AnyPublisher<AsyncOperationEvent, Never> {
        return asyncOperationSubject.eraseToAnyPublisher()
    }
    
    /// 错误事件发布者
    public var errorPublisher: AnyPublisher<LocalizedRealtimeError, Never> {
        return errorSubject.eraseToAnyPublisher()
    }
    
    /// 状态变化事件发布者
    public var stateChangePublisher: AnyPublisher<StateChangeEvent, Never> {
        return stateChangeSubject.eraseToAnyPublisher()
    }
    
    /// 用户会话变化发布者
    public var sessionPublisher: AnyPublisher<UserSession?, Never> {
        return $currentSession.eraseToAnyPublisher()
    }
    
    /// 连接状态变化发布者
    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        return $connectionState.eraseToAnyPublisher()
    }
    
    /// 音频设置变化发布者（与 @RealtimeStorage 兼容）
    public var audioSettingsPublisher: AnyPublisher<AudioSettings, Never> {
        return $audioSettings.eraseToAnyPublisher()
    }
    
    /// 音量信息变化发布者
    public var volumeInfoPublisher: AnyPublisher<[UserVolumeInfo], Never> {
        return $volumeInfos.eraseToAnyPublisher()
    }
    
    /// 说话用户变化发布者
    public var speakingUsersPublisher: AnyPublisher<Set<String>, Never> {
        return $speakingUsers.eraseToAnyPublisher()
    }
    
    /// 主讲人变化发布者
    public var dominantSpeakerPublisher: AnyPublisher<String?, Never> {
        return $dominantSpeaker.eraseToAnyPublisher()
    }
    
    /// 本地化文本变化发布者（需求 17.3）
    public var localizedTextPublisher: AnyPublisher<LocalizedTextUpdate, Never> {
        return Publishers.CombineLatest3(
            $localizedConnectionState,
            $localizedUserRole,
            $localizedProviderName
        )
        .map { connectionState, userRole, providerName in
            LocalizedTextUpdate(
                connectionState: connectionState,
                userRole: userRole,
                providerName: providerName,
                updateTime: Date()
            )
        }
        .eraseToAnyPublisher()
    }
    
    /// 组合状态发布者（用于复杂的 UI 状态绑定）
    public var combinedStatePublisher: AnyPublisher<CombinedRealtimeState, Never> {
        return Publishers.CombineLatest4(
            $currentSession.eraseToAnyPublisher(),
            $connectionState.eraseToAnyPublisher(),
            $audioSettings.eraseToAnyPublisher(),
            $audioStatusInfo.eraseToAnyPublisher()
        )
        .map { session, connectionState, audioSettings, audioStatus in
            CombinedRealtimeState(
                session: session,
                connectionState: connectionState,
                audioSettings: audioSettings,
                audioStatus: audioStatus,
                updateTime: Date()
            )
        }
        .eraseToAnyPublisher()
    }
    
    /// 设置响应式数据流监听 (需求 3.3, 11.3, 11.5)
    private func setupReactiveDataStreams() {
        // 监听连接状态变化并更新本地化文本 (需求 17.3)
        $connectionState
            .sink { [weak self] state in
                self?.updateLocalizedConnectionState(state)
                self?.stateChangeSubject.send(.connectionStateChanged(state))
            }
            .store(in: &cancellables)
        
        // 监听用户会话变化并更新本地化文本 (需求 17.3)
        $currentSession
            .sink { [weak self] session in
                self?.updateLocalizedUserRole(session?.userRole)
                self?.stateChangeSubject.send(.sessionChanged(session))
            }
            .store(in: &cancellables)
        
        // 监听服务商变化并更新本地化文本 (需求 17.3)
        $currentProvider
            .sink { [weak self] (provider: ProviderType) in
                self?.updateLocalizedProviderName(provider)
                self?.stateChangeSubject.send(.providerChanged(provider))
            }
            .store(in: &cancellables)
        
        // 监听音频设置变化并更新状态信息 (需求 18.10)
        $audioSettings
            .sink { [weak self] (settings: AudioSettings) in
                self?.updateAudioStatusInfo()
                self?.stateChangeSubject.send(.audioSettingsChanged(settings))
            }
            .store(in: &cancellables)
        
        // 监听音量信息变化并处理说话状态 (需求 6.3, 6.4)
        $volumeInfos
            .sink { [weak self] volumeInfos in
                self?.processSpeakingStateChanges(volumeInfos)
                self?.stateChangeSubject.send(.volumeInfoChanged(volumeInfos))
            }
            .store(in: &cancellables)
        
        // 监听错误状态变化
        $lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorSubject.send(error)
            }
            .store(in: &cancellables)
    }
    
    /// 更新本地化的连接状态文本 (需求 17.3)
    private func updateLocalizedConnectionState(_ state: ConnectionState) {
        localizedConnectionState = state.displayName
    }
    
    /// 更新本地化的用户角色文本 (需求 17.3)
    private func updateLocalizedUserRole(_ role: UserRole?) {
        localizedUserRole = role?.displayName ?? localizationManager.localizedString(for: "user.role.none")
    }
    
    /// 更新本地化的服务商名称文本 (需求 17.3)
    private func updateLocalizedProviderName(_ provider: ProviderType) {
        localizedProviderName = provider.displayName
    }
    
    /// 更新音频状态信息
    private func updateAudioStatusInfo() {
        audioStatusInfo = AudioStatusInfo(
            settings: audioSettings,
            isProviderConnected: rtcProvider != nil,
            hasAudioPermission: hasPermission(.audio),
            currentUserRole: currentUserRole,
            lastModified: audioSettings.lastModified
        )
    }
    
    /// 处理说话状态变化 (需求 6.3, 6.4)
    private func processSpeakingStateChanges(_ volumeInfos: [UserVolumeInfo]) {
        let newSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        let newDominantSpeaker = volumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        
        // 检测说话状态变化
        let startedSpeaking = newSpeakingUsers.subtracting(speakingUsers)
        let stoppedSpeaking = speakingUsers.subtracting(newSpeakingUsers)
        
        // 更新状态
        speakingUsers = newSpeakingUsers
        dominantSpeaker = newDominantSpeaker
        
        // 发送事件
        for userId in startedSpeaking {
            if let volumeInfo = volumeInfos.first(where: { $0.userId == userId }) {
                stateChangeSubject.send(.userStartedSpeaking(userId, volumeInfo.volumeFloat))
            }
        }
        
        for userId in stoppedSpeaking {
            stateChangeSubject.send(.userStoppedSpeaking(userId))
        }
        
        if dominantSpeaker != newDominantSpeaker {
            stateChangeSubject.send(.dominantSpeakerChanged(newDominantSpeaker))
        }
    }
    
    /// 执行异步操作并发送事件 (需求 11.5)
    private func performAsyncOperation<T>(
        _ operation: @escaping () async throws -> T,
        operationType: AsyncOperationType
    ) async -> Result<T, Error> {
        isPerformingAsyncOperation = true
        asyncOperationSubject.send(.started(operationType))
        
        do {
            let result = try await operation()
            asyncOperationSubject.send(.completed(operationType))
            isPerformingAsyncOperation = false
            return .success(result)
        } catch {
            let localizedError = LocalizedErrorFactory.createLocalizedError(from: error)
            lastError = localizedError
            asyncOperationSubject.send(.failed(operationType, localizedError))
            isPerformingAsyncOperation = false
            return .failure(error)
        }
    }
    
    /// 重置错误状态
    public func clearLastError() {
        lastError = nil
    }
    
    /// 获取当前的响应式状态快照
    public func getCurrentReactiveState() -> ReactiveStateSnapshot {
        return ReactiveStateSnapshot(
            session: currentSession,
            connectionState: connectionState,
            audioSettings: audioSettings,
            audioStatus: audioStatusInfo,
            volumeInfos: volumeInfos,
            speakingUsers: speakingUsers,
            dominantSpeaker: dominantSpeaker,
            localizedTexts: LocalizedTextSnapshot(
                connectionState: localizedConnectionState,
                userRole: localizedUserRole,
                providerName: localizedProviderName
            ),
            isPerformingOperation: isPerformingAsyncOperation,
            lastError: lastError,
            snapshotTime: Date()
        )
    }
    
    /// 创建 SwiftUI Binding 用于双向数据绑定 (需求 18.10)
    /// 注意：此 Binding 会自动同步设置到 RTC Provider
    public func createAudioSettingsBinding() -> Binding<AudioSettings> {
        return Binding(
            get: { [weak self] in
                self?.audioSettings ?? .default
            },
            set: { [weak self] newValue in
                Task { @MainActor in
                    await self?.updateAudioSettings { _ in newValue }
                }
            }
        )
    }
    
    /// 创建用户偏好设置的 SwiftUI Binding (需求 18.10)
    public func createUserPreferencesBinding() -> Binding<RealtimeManagerPreferences> {
        return Binding(
            get: { [weak self] in
                self?.userPreferences ?? RealtimeManagerPreferences()
            },
            set: { [weak self] newValue in
                self?.updateUserPreferences(newValue)
            }
        )
    }
    
    /// 为 SwiftUI 提供便捷的状态检查方法
    public var isConnected: Bool { connectionState == .connected }
    public var isConnecting: Bool { connectionState.isTransitioning }
    public var hasActiveSession: Bool { currentSession != nil }
    public var canPerformAudioOperations: Bool { hasPermission(.audio) && isConnected }
    public var isAudioMuted: Bool { audioSettings.microphoneMuted }
    public var isAudioStreamActive: Bool { audioSettings.localAudioStreamActive }
    
    /// 为 SwiftUI 提供格式化的显示文本
    public var formattedConnectionDuration: String {
        guard let session = currentSession else { return "00:00:00" }
        let duration = Date().timeIntervalSince(session.joinTime)
        return formatDuration(duration)
    }
    
    public var formattedAudioStatus: String {
        return audioStatusInfo.statusSummary
    }
    
    public var formattedVolumeLevel: String {
        let avgVolume = audioSettings.averageVolume
        return localizationManager.localizedString(
            for: "audio.volume.level.format",
            arguments: avgVolume
        )
    }
    
    /// 格式化时长显示
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    /// 初始化本地化文本 (需求: 17.3)
    private func updateLocalizedTexts() {
        updateLocalizedConnectionState(connectionState)
        updateLocalizedUserRole(currentSession?.userRole)
        updateLocalizedProviderName(currentProvider)
        updateAudioStatusInfo()
    }
    
    // MARK: - Configuration (需求 3.1, 2.3)
    
    /// 配置 RealtimeManager 使用指定的服务商
    /// Configure RealtimeManager with RealtimeConfiguration
    /// - Parameter config: The configuration to use
    public func configure(with config: RealtimeConfiguration) async throws {
        // Create RealtimeConfig from RealtimeConfiguration
        let realtimeConfig = RealtimeConfig(
            appId: config.appId,
            appCertificate: config.appCertificate,
            enableLogging: config.enableLogging
        )
        
        try await configure(provider: config.provider, config: realtimeConfig)
        
        // Apply storage configuration if provided
        if let storageConfig = config.storageConfig {
            await applyStorageConfiguration(storageConfig)
        }
        
        // Apply localization configuration if provided
        if let localizationConfig = config.localizationConfig {
            await applyLocalizationConfiguration(localizationConfig)
        }
    }
    
    /// - Parameters:
    ///   - provider: 服务商类型
    ///   - config: 实时通信配置
    public func configure(provider: ProviderType, config: RealtimeConfig) async throws {
        currentConfig = config
        
        // 使用工厂模式创建服务商实例 (需求 2.2)
        guard let factory = providerSwitchManager.getProviderFactory(for: provider) else {
            throw RealtimeError.providerNotAvailable(provider)
        }
        
        rtcProvider = factory.createRTCProvider()
        rtmProvider = factory.createRTMProvider()
        
        // 初始化服务商
        try await rtcProvider?.initialize(config: RTCConfig(from: config))
        try await rtmProvider?.initialize(config: RTMConfig(from: config))
        
        // 设置事件处理
        setupEventHandlers()
        
        // 设置 Token 管理
        setupTokenManagement()
        
        // 集成子管理器 (需求 3.1)
        setupSubManagers()
        
        // 应用持久化设置
        try await applyPersistedSettings()
        
        // 更新状态
        currentProvider = provider
        connectionState = .connected
        
        print("RealtimeManager 配置完成，使用服务商: \(provider.displayName)")
    }
    
    /// 切换到不同的服务商 (需求 2.3, 2.4)
    /// - Parameters:
    ///   - newProvider: 新的服务商类型
    ///   - preserveSession: 是否保持会话状态
    public func switchProvider(to newProvider: ProviderType, preserveSession: Bool = true) async throws {
        switchingInProgress = true
        defer { switchingInProgress = false }
        
        do {
            try await providerSwitchManager.switchProvider(
                to: newProvider,
                preserveSession: preserveSession
            )
            
            // 更新当前服务商状态
            currentProvider = providerSwitchManager.currentProvider
            
        } catch {
            print("服务商切换失败: \(error)")
            throw error
        }
    }
    
    /// 尝试降级处理 (需求 2.4)
    private func attemptFallback(originalError: Error) async throws {
        try await providerSwitchManager.attemptFallback(originalError: originalError)
        currentProvider = providerSwitchManager.currentProvider
    }
    
    /// 集成所有子管理器 (需求 3.1)
    private func setupSubManagers() {
        // 集成音量管理器
        volumeManager.onVolumeUpdate = { [weak self] volumeInfos in
            Task { @MainActor in
                self?.handleVolumeUpdate(volumeInfos)
            }
        }
        
        // 集成媒体中继管理器
        mediaRelayManager.onStateChanged = { [weak self] (state: MediaRelayState, detailedState: MediaRelayDetailedState?) in
            Task { @MainActor in
                self?.mediaRelayState = state
            }
        }
        
        // 集成转推流管理器
        streamPushManager.onStateChanged = { [weak self] state in
            Task { @MainActor in
                self?.streamPushState = state
            }
        }
        
        // 集成消息处理管理器
        messageProcessingManager.registerDefaultProcessors()
    }
    
    // MARK: - User Identity and Session Management (需求 4.1, 4.2, 4.3, 4.5, 17.6, 18.2)
    
    /// 用户登录，创建新的用户会话
    /// - Parameters:
    ///   - userId: 用户唯一标识符
    ///   - userName: 用户显示名称
    ///   - userRole: 用户角色
    ///   - deviceInfo: 设备信息（可选）
    /// - Throws: 配置错误、权限错误等
    public func loginUser(
        userId: String, 
        userName: String, 
        userRole: UserRole,
        deviceInfo: DeviceInfo? = nil
    ) async throws {
        // 验证配置状态
        guard rtmProvider != nil else {
            let errorMessage = localizationManager.localizedString(for: "error.manager.not.configured")
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 验证输入参数
        try validateLoginParameters(userId: userId, userName: userName, userRole: userRole)
        
        // 创建新的用户会话
        let session = UserSession(userId: userId, userName: userName, userRole: userRole)
        
        // 获取RTM Token（如果需要）
        let rtmToken = try await getOrGenerateRTMToken(for: userId)
        
        // 登录RTM系统（仅处理消息系统登录）
        try await rtmProvider?.login(userId: userId, token: rtmToken)
        
        // 保存用户会话
        currentSession = session
        sessionStorage.saveUserSession(session)
        
        print("用户登录成功: \(userName) (\(userRole.displayName))")
        print("RTM系统登录完成，可以发送和接收消息")
    }
    
    /// 用户登出（简化版本）
    public func logoutUser() async throws {
        try await logoutUser(reason: .userInitiated)
    }
    
    /// 完全断开连接并登出
    /// 此方法会依次执行：1) 离开房间 2) 登出用户
    /// 适用于需要完全清理所有连接和会话状态的场景
    /// - Parameter reason: 登出原因（可选）
    public func disconnectAndLogout(reason: LogoutReason = .userInitiated) async throws {
        // 先离开房间（如果在房间中）
        if currentSession?.isInRoom == true {
            do {
                try await leaveRoom()
            } catch {
                print("离开房间时出错: \(error)")
                // 继续执行登出，即使离开房间失败
            }
        }
        
        // 然后登出用户
        try await logoutUser(reason: reason)
        
        // 发送完全断开连接通知
        NotificationCenter.default.post(
            name: .didDisconnectAndLogout,
            object: self,
            userInfo: [
                "reason": reason,
                "timestamp": Date()
            ]
        )
    }
    
    /// 验证登录参数
    private func validateLoginParameters(userId: String, userName: String, userRole: UserRole) throws {
        guard !userId.isEmpty else {
            throw RealtimeError.invalidParameter("userId cannot be empty")
        }
        
        guard !userName.isEmpty else {
            throw RealtimeError.invalidParameter("userName cannot be empty")
        }
    }
    

    
    // MARK: - Audio Control and Settings Management (需求 5.1, 5.2, 5.3, 5.5, 5.6, 17.6, 18.2)
    
    /// 设置音频混音音量
    /// - Parameter volume: 音量级别 (0-100)
    /// - Throws: 配置错误、参数错误等
    public func setAudioMixingVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        
        // 先更新 RTC Provider
        try await rtcProvider?.setAudioMixingVolume(clampedVolume)
        
        // 然后更新本地设置（这会自动触发持久化）
        await updateAudioSettings { settings in
            settings.withUpdatedVolume(audioMixing: clampedVolume)
        }
    }
    
    /// 静音/取消静音麦克风
    /// - Parameter muted: true 表示静音，false 表示取消静音
    /// - Throws: 配置错误、权限错误等
    public func muteMicrophone(_ muted: Bool) async throws {
        // 先更新 RTC Provider
        try await rtcProvider?.muteMicrophone(muted)
        
        // 然后更新本地设置
        await updateAudioSettings { settings in
            settings.withUpdatedMicrophoneState(muted)
        }
    }
    
    /// 启用音量指示器
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        try await rtcProvider?.enableVolumeIndicator(config: config)
        
        // 设置音量回调
        rtcProvider?.setVolumeIndicatorHandler { [weak self] volumeInfos in
            Task { @MainActor in
                self?.handleVolumeUpdate(volumeInfos)
            }
        }
    }
    
    /// 禁用音量指示器
    public func disableVolumeIndicator() async throws {
        try await rtcProvider?.disableVolumeIndicator()
        
        // 清除音量数据
        volumeInfos.removeAll()
        speakingUsers.removeAll()
        dominantSpeaker = nil
        
        print("音量指示器已禁用")
    }
    
    /// 开始转推流
    public func startStreamPush(config: StreamPushConfig) async throws {
        try await rtcProvider?.startStreamPush(config: config)
        streamPushState = .running
    }
    
    /// 停止转推流
    public func stopStreamPush() async throws {
        try await rtcProvider?.stopStreamPush()
        streamPushState = .stopped
    }
    
    /// 开始媒体中继
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        try await rtcProvider?.startMediaRelay(config: config)
        mediaRelayState = .running
    }
    
    /// 停止媒体中继
    public func stopMediaRelay() async throws {
        try await rtcProvider?.stopMediaRelay()
        mediaRelayState = .idle
    }
    
    /// 处理音量更新
    private func handleVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        self.volumeInfos = volumeInfos
        volumeManager.processVolumeUpdate(volumeInfos)
    }
    
    /// 应用持久化设置
    private func applyPersistedSettings() async throws {
        try await applyAudioSettings(audioSettings)
    }
    
    /// 统一更新音频设置的方法 (需求 3.2, 5.4, 5.6, 18.2)
    /// 此方法确保音频设置的更新同时反映到 RTC Provider 和持久化存储
    /// - Parameter updateBlock: 音频设置更新闭包
    @MainActor
    private func updateAudioSettings(_ updateBlock: (AudioSettings) -> AudioSettings) async {
        let newSettings = updateBlock(audioSettings)
        
        // 更新本地设置（触发 @Published）
        audioSettings = newSettings
        
        // 更新持久化存储（触发 @RealtimeStorage）
        _persistedAudioSettings = newSettings
        
        // 异步同步到 RTC Provider，不阻塞 UI
        Task {
            do {
                try await applyAudioSettingsToProvider(newSettings)
            } catch {
                print("Failed to sync audio settings to RTC Provider: \(error)")
                // 可以在这里触发错误处理或重试机制
            }
        }
    }
    
    /// 应用音频设置到 RTC Provider (需求 5.6)
    /// 此方法只负责与 RTC Provider 的同步，不修改本地状态
    internal func applyAudioSettingsToProvider(_ settings: AudioSettings) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        try await rtcProvider.muteMicrophone(settings.microphoneMuted)
        try await rtcProvider.setAudioMixingVolume(settings.audioMixingVolume)
        try await rtcProvider.setPlaybackSignalVolume(settings.playbackSignalVolume)
        try await rtcProvider.setRecordingSignalVolume(settings.recordingSignalVolume)
        
        if settings.localAudioStreamActive {
            try await rtcProvider.resumeLocalAudioStream()
        } else {
            try await rtcProvider.stopLocalAudioStream()
        }
    }
    
    /// 应用音频设置到 RTC Provider（向后兼容方法）
    internal func applyAudioSettings(_ settings: AudioSettings) async throws {
        try await applyAudioSettingsToProvider(settings)
    }
    
    /// 设置事件处理器
    private func setupEventHandlers() {
        // 设置连接状态处理器
        rtmProvider?.onConnectionStateChanged { [weak self] state, reason in
            Task { @MainActor in
                // 将 RTMConnectionState 转换为 ConnectionState
                let connectionState: ConnectionState
                switch state {
                case .disconnected:
                    connectionState = .disconnected
                case .connecting:
                    connectionState = .connecting
                case .connected:
                    connectionState = .connected
                case .reconnecting:
                    connectionState = .reconnecting
                case .failed:
                    connectionState = .failed
                }
                self?.connectionState = connectionState
            }
        }
    }
    
    /// 设置 Token 管理
    private func setupTokenManagement() {
        rtcProvider?.onTokenWillExpire { [weak self] expiresIn in
            Task { @MainActor in
                await self?.tokenManager.handleTokenExpiration(
                    provider: self?.currentProvider ?? .mock,
                    expiresIn: expiresIn
                )
            }
        }
        
        rtmProvider?.onTokenWillExpire { [weak self] in
            Task { @MainActor in
                await self?.tokenManager.handleTokenExpiration(
                    provider: self?.currentProvider ?? .mock,
                    expiresIn: 60 // 默认 60 秒
                )
            }
        }
    }
    
    /// 更新用户偏好设置
    private func updateUserPreferences(_ preferences: RealtimeManagerPreferences) {
        userPreferences = preferences
    }
    
    /// 恢复会话状态
    internal func restoreSession(_ session: UserSession) async throws {
        currentSession = session
        sessionStorage.saveUserSession(session)
    }
    
    // MARK: - User Identity and Session Management (需求 4.1, 4.2, 4.3, 4.5, 17.6, 18.2)
    

    
    /// 用户登出，清理会话状态
    /// 注意：登出只处理 RTM 消息系统的注销，不会自动离开 RTC 音视频房间
    /// 如需离开音视频房间，请单独调用 leaveRoom() 方法
    /// - Parameter reason: 登出原因（可选）
    public func logoutUser(reason: LogoutReason = .userInitiated) async throws {
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        // 登出RTM系统（只处理消息系统）
        do {
            try await rtmProvider?.logout()
        } catch {
            print("RTM登出时出错: \(error)")
        }
        
        // 记录连接历史
        recordConnectionHistory(success: reason != .error)
        
        // 清理会话状态
        currentSession = nil
        sessionStorage.clearUserSession()
        
        // 注意：不修改 connectionState，因为 RTC 连接可能仍然活跃
        // connectionState 应该反映 RTC 连接状态，而不是 RTM 登录状态
        
        // 更新应用状态恢复信息
        var recoveryInfo = appStateRecovery
        recoveryInfo.needsSessionRecovery = false
        appStateRecovery = recoveryInfo
        
        // 发送本地化的登出通知 (需求 17.6)
        let logoutMessage = localizationManager.localizedString(
            for: "user.logout.success",
            arguments: session.userName, reason.displayName
        )
        print(logoutMessage)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .userDidLogout,
            object: self,
            userInfo: [
                "userId": session.userId,
                "userName": session.userName,
                "reason": reason,
                "session": session
            ]
        )
    }
    
    /// 切换用户角色
    /// - Parameter newRole: 新的用户角色
    /// - Throws: 会话错误、权限错误、角色转换错误等
    public func switchUserRole(_ newRole: UserRole) async throws {
        guard let currentSession = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        // 验证角色转换是否允许 (需求 4.3)
        guard currentSession.userRole.canSwitchTo(newRole) else {
            throw RealtimeError.invalidRoleTransition(from: currentSession.userRole, to: newRole)
        }
        
        // 验证新角色的权限
        try validateUserPermissions(for: newRole)
        
        // 通知 RTC Provider 角色变更
        try await rtcProvider?.switchUserRole(newRole)
        
        // 更新会话信息
        let updatedSession = currentSession.withUpdatedRole(newRole)
        self.currentSession = updatedSession
        sessionStorage.saveUserSession(updatedSession)
        
        // 根据新角色配置音频权限 (需求 4.2)
        try await configureAudioPermissions(for: newRole)
        
        // 更新应用状态恢复信息
        updateAppStateRecoveryInfo()
        
        // 发送本地化的角色切换成功通知 (需求 17.6)
        let switchMessage = localizationManager.localizedString(
            for: "user.role.switch.success",
            arguments: currentSession.userRole.displayName, newRole.displayName
        )
        print(switchMessage)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .userRoleDidChange,
            object: self,
            userInfo: [
                "userId": updatedSession.userId,
                "userName": updatedSession.userName,
                "previousRole": currentSession.userRole,
                "newRole": newRole,
                "session": updatedSession
            ]
        )
    }
    
    /// 获取当前用户会话信息
    /// - Returns: 当前用户会话，如果没有活跃会话则返回 nil
    public func getCurrentSession() -> UserSession? {
        return currentSession
    }
    
    /// 检查用户是否已登录
    /// - Returns: 如果有活跃会话返回 true，否则返回 false
    public var isUserLoggedIn: Bool {
        return currentSession != nil
    }
    
    /// 检查用户是否在房间中
    /// - Returns: 如果用户在房间中返回 true，否则返回 false
    public var isUserInRoom: Bool {
        return currentSession?.isInRoom ?? false
    }
    
    /// 获取当前用户角色
    /// - Returns: 当前用户角色，如果没有活跃会话则返回 nil
    public var currentUserRole: UserRole? {
        return currentSession?.userRole
    }
    
    /// 检查当前用户是否具有指定权限
    /// - Parameter permission: 要检查的权限类型
    /// - Returns: 如果具有权限返回 true，否则返回 false
    public func hasPermission(_ permission: UserPermission) -> Bool {
        guard let role = currentUserRole else { return false }
        return checkPermission(permission, for: role)
    }
    
    /// 获取当前用户可以切换到的角色列表
    /// - Returns: 可切换的角色数组
    public func getAvailableRoleSwitches() -> [UserRole] {
        guard let currentRole = currentUserRole else { return [] }
        return Array(currentRole.canSwitchToRole)
    }
    
    /// 获取用户会话统计信息
    /// - Returns: 会话统计信息，如果没有活跃会话则返回 nil
    public func getSessionStatistics() -> UserSessionStats? {
        guard let session = currentSession else { return nil }
        
        let sessionDuration = Date().timeIntervalSince(session.joinTime)
        let inactiveDuration = Date().timeIntervalSince(session.lastActiveTime)
        
        return UserSessionStats(
            sessionId: session.sessionId,
            userId: session.userId,
            sessionDuration: sessionDuration,
            inactiveDuration: inactiveDuration,
            isValid: session.isValid()
        )
    }
    
    /// 更新用户会话的最后活跃时间
    public func updateUserActivity() {
        guard let session = currentSession else { return }
        sessionStorage.updateLastActiveTime(for: session)
    }
    
    // MARK: - Private Session Management Methods
    

    
    /// 验证用户权限 (需求 4.2)
    private func validateUserPermissions(for role: UserRole) throws {
        // 这里可以添加更复杂的权限验证逻辑
        // 例如检查服务商是否支持特定角色等
        
        let supportedFeatures = getSupportedFeatures(for: currentProvider)
        
        // 检查音频权限
        if role.hasAudioPermission && !supportedFeatures.contains(.audioStreaming) {
            throw RealtimeError.insufficientPermissions(role)
        }
        
        // 检查视频权限
        if role.hasVideoPermission && !supportedFeatures.contains(.videoStreaming) {
            throw RealtimeError.insufficientPermissions(role)
        }
    }
    
    /// 根据角色配置音频权限 (需求 4.2)
    private func configureAudioPermissions(for role: UserRole) async throws {
        guard let rtcProvider = rtcProvider else { return }
        
        if role.hasAudioPermission {
            // 启用音频流
            try await rtcProvider.resumeLocalAudioStream()
            
            // 如果当前是静音状态且新角色有音频权限，可以选择取消静音
            if audioSettings.microphoneMuted && userPreferences.enableAudioSettingsRestore {
                try await rtcProvider.muteMicrophone(false)
                await updateAudioSettings { settings in
                    settings.withUpdatedMicrophoneState(false)
                }
            }
            
            // 确保音频流状态正确
            await updateAudioSettings { settings in
                settings.withUpdatedStreamState(true)
            }
        } else {
            // 禁用音频流
            try await rtcProvider.stopLocalAudioStream()
            
            // 强制静音
            try await rtcProvider.muteMicrophone(true)
            
            // 更新本地设置
            await updateAudioSettings { settings in
                settings.withUpdatedMicrophoneState(true).withUpdatedStreamState(false)
            }
        }
        
        let permissionMessage = localizationManager.localizedString(
            for: role.hasAudioPermission ? "user.audio.permission.enabled" : "user.audio.permission.disabled",
            arguments: role.displayName
        )
        print(permissionMessage)
    }
    
    /// 检查特定权限
    private func checkPermission(_ permission: UserPermission, for role: UserRole) -> Bool {
        switch permission {
        case .audio:
            return role.hasAudioPermission
        case .video:
            return role.hasVideoPermission
        case .moderator:
            return role.hasModeratorPrivileges
        case .streamPush:
            return role == .broadcaster || role == .moderator
        case .mediaRelay:
            return role == .broadcaster || role == .moderator
        case .volumeIndicator:
            return true // 所有角色都可以查看音量指示器
        case .roleSwitch:
            return !role.canSwitchToRole.isEmpty
        }
    }
    
    // MARK: - Advanced Permission and Session Management (需求 4.2, 4.5, 17.6)
    
    /// 执行详细的权限检查
    /// - Parameter permission: 要检查的权限
    /// - Returns: 权限检查结果
    public func checkPermissionDetailed(_ permission: UserPermission) -> UserPermissionCheckResult {
        guard let role = currentUserRole else {
            return UserPermissionCheckResult(
                hasPermission: false,
                permission: permission,
                userRole: .audience, // 默认角色
                denialReason: localizationManager.localizedString(for: "error.no.active.session")
            )
        }
        
        let hasPermission = checkPermission(permission, for: role)
        
        if hasPermission {
            return UserPermissionCheckResult(
                hasPermission: true,
                permission: permission,
                userRole: role
            )
        } else {
            let denialReason = localizationManager.localizedString(
                for: "error.permission.denied.detailed",
                arguments: permission.displayName, role.displayName
            )
            
            let suggestedAlternatives = getSuggestedAlternativePermissions(for: permission, currentRole: role)
            
            return UserPermissionCheckResult(
                hasPermission: false,
                permission: permission,
                userRole: role,
                denialReason: denialReason,
                suggestedAlternatives: suggestedAlternatives
            )
        }
    }
    
    /// 验证当前用户会话
    /// - Returns: 会话验证结果
    public func validateCurrentSession() -> UserSessionValidationResult {
        guard let session = currentSession else {
            return UserSessionValidationResult(
                isValid: false,
                validationErrors: [.sessionExpired],
                suggestedActions: [.relogin]
            )
        }
        
        var validationErrors: [SessionValidationError] = []
        var suggestedActions: [SessionAction] = []
        
        // 检查会话是否过期
        if !session.isValid() {
            validationErrors.append(.sessionExpired)
            suggestedActions.append(.relogin)
        }
        
        // 检查非活跃时间
        let inactiveTime = Date().timeIntervalSince(session.lastActiveTime)
        if inactiveTime > 30 * 60 { // 30分钟
            validationErrors.append(.inactivityTimeout)
            suggestedActions.append(.refreshSession)
        }
        
        // 检查角色权限一致性
        if !validateRolePermissions(for: session.userRole) {
            validationErrors.append(.rolePermissionMismatch)
            suggestedActions.append(.updatePermissions)
        }
        
        // 检查设备信息一致性（如果有）
        if let sessionDevice = session.deviceInfo {
            let currentDevice = DeviceInfo.current(appVersion: "1.0.0")
            if sessionDevice.deviceId != currentDevice.deviceId {
                validationErrors.append(.deviceMismatch)
                suggestedActions.append(.relogin)
            }
        }
        
        let isValid = validationErrors.isEmpty
        let sessionStats = getSessionStatistics()
        
        return UserSessionValidationResult(
            isValid: isValid,
            validationErrors: validationErrors,
            sessionStats: sessionStats,
            suggestedActions: suggestedActions
        )
    }
    
    /// 请求权限（带用户提示）
    /// - Parameters:
    ///   - permission: 请求的权限
    ///   - showUserPrompt: 是否显示用户提示
    /// - Returns: 是否获得权限
    public func requestPermission(_ permission: UserPermission, showUserPrompt: Bool = true) async -> Bool {
        let checkResult = checkPermissionDetailed(permission)
        
        if checkResult.hasPermission {
            return true
        }
        
        // 发送权限被拒绝的通知 (需求 17.6)
        NotificationCenter.default.post(
            name: .userPermissionDenied,
            object: self,
            userInfo: [
                "permission": permission,
                "userRole": checkResult.userRole,
                "denialReason": checkResult.denialReason ?? "",
                "suggestedAlternatives": checkResult.suggestedAlternatives
            ]
        )
        
        if showUserPrompt {
            let promptMessage = localizationManager.localizedString(
                for: "permission.request.denied.prompt",
                arguments: permission.displayName, checkResult.denialReason ?? ""
            )
            print(promptMessage)
            
            // 如果有建议的替代权限，显示给用户
            if !checkResult.suggestedAlternatives.isEmpty {
                let alternativesMessage = localizationManager.localizedString(
                    for: "permission.request.alternatives",
                    arguments: checkResult.suggestedAlternatives.map { $0.displayName }.joined(separator: ", ")
                )
                print(alternativesMessage)
            }
        }
        
        return false
    }
    
    /// 批量检查权限
    /// - Parameter permissions: 要检查的权限列表
    /// - Returns: 权限检查结果字典
    public func checkPermissions(_ permissions: [UserPermission]) -> [UserPermission: UserPermissionCheckResult] {
        var results: [UserPermission: UserPermissionCheckResult] = [:]
        
        for permission in permissions {
            results[permission] = checkPermissionDetailed(permission)
        }
        
        return results
    }
    
    /// 获取用户角色的完整权限列表
    /// - Parameter role: 用户角色（可选，默认使用当前角色）
    /// - Returns: 权限列表
    public func getUserPermissions(for role: UserRole? = nil) -> [UserPermission] {
        let targetRole = role ?? currentUserRole ?? .audience
        
        return UserPermission.allCases.filter { permission in
            checkPermission(permission, for: targetRole)
        }
    }
    
    /// 比较两个角色的权限差异
    /// - Parameters:
    ///   - fromRole: 源角色
    ///   - toRole: 目标角色
    /// - Returns: 权限变化信息
    public func compareRolePermissions(from fromRole: UserRole, to toRole: UserRole) -> RolePermissionComparison {
        let fromPermissions = Set(getUserPermissions(for: fromRole))
        let toPermissions = Set(getUserPermissions(for: toRole))
        
        let gainedPermissions = toPermissions.subtracting(fromPermissions)
        let lostPermissions = fromPermissions.subtracting(toPermissions)
        let unchangedPermissions = fromPermissions.intersection(toPermissions)
        
        return RolePermissionComparison(
            fromRole: fromRole,
            toRole: toRole,
            gainedPermissions: Array(gainedPermissions),
            lostPermissions: Array(lostPermissions),
            unchangedPermissions: Array(unchangedPermissions)
        )
    }
    
    /// 刷新用户会话
    /// - Returns: 刷新是否成功
    @discardableResult
    public func refreshUserSession() async -> Bool {
        guard let session = currentSession else { return false }
        
        do {
            // 更新最后活跃时间
            updateUserActivity()
            
            // 重新验证权限
            try validateUserPermissions(for: session.userRole)
            
            // 重新配置音频权限
            try await configureAudioPermissions(for: session.userRole)
            
            // 更新应用状态恢复信息
            updateAppStateRecoveryInfo()
            
            let refreshMessage = localizationManager.localizedString(
                for: "session.refresh.success",
                arguments: session.userName
            )
            print(refreshMessage)
            
            return true
            
        } catch {
            let errorMessage = localizationManager.localizedString(
                for: "session.refresh.failed",
                arguments: error.localizedDescription
            )
            print(errorMessage)
            
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// 验证角色权限一致性
    private func validateRolePermissions(for role: UserRole) -> Bool {
        // 检查当前服务商是否支持角色所需的功能
        let supportedFeatures = getSupportedFeatures(for: currentProvider)
        
        if role.hasAudioPermission && !supportedFeatures.contains(.audioStreaming) {
            return false
        }
        
        if role.hasVideoPermission && !supportedFeatures.contains(.videoStreaming) {
            return false
        }
        
        return true
    }
    
    /// 获取建议的替代权限
    private func getSuggestedAlternativePermissions(for permission: UserPermission, currentRole: UserRole) -> [UserPermission] {
        var alternatives: [UserPermission] = []
        
        switch permission {
        case .audio:
            if !currentRole.hasAudioPermission {
                alternatives.append(.volumeIndicator) // 可以查看音量指示器
            }
        case .video:
            if !currentRole.hasVideoPermission {
                alternatives.append(.audio) // 可以使用音频
            }
        case .streamPush, .mediaRelay:
            if currentRole != .broadcaster && currentRole != .moderator {
                alternatives.append(.audio)
                alternatives.append(.video)
            }
        case .moderator:
            if !currentRole.hasModeratorPrivileges {
                alternatives.append(.roleSwitch) // 可以尝试切换角色
            }
        default:
            break
        }
        
        return alternatives.filter { checkPermission($0, for: currentRole) }
    }
    
    // MARK: - Room Management
    
    public func createRoom(roomId: String) async throws -> RTCRoom {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        let room = try await rtcProvider.createRoom(roomId: roomId)
        print("创建房间: \(roomId)")
        return room
    }
    
    public func joinRoom(roomId: String) async throws {
        guard let rtcProvider = rtcProvider,
              let currentSession = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        // 验证角色权限
        guard currentSession.userRole.hasAudioPermission || currentSession.userRole == .audience else {
            throw RealtimeError.insufficientPermissions(currentSession.userRole)
        }
        
        // 加入RTC房间（音视频通话）
        try await rtcProvider.joinRoom(
            roomId: roomId,
            userId: currentSession.userId,
            userRole: currentSession.userRole
        )
        
        // 根据角色配置音频权限（这里才是正确的地方）
        if currentSession.userRole.hasAudioPermission {
            try await rtcProvider.resumeLocalAudioStream()
        } else {
            try await rtcProvider.stopLocalAudioStream()
        }
        
        // 如果RTM已登录，也加入RTM频道用于消息通信
        if rtmProvider?.isLoggedIn() == true {
            try await rtmProvider?.joinChannel(channelId: roomId)
        }
        
        // 更新会话信息
        let updatedSession = UserSession(
            userId: currentSession.userId,
            userName: currentSession.userName,
            userRole: currentSession.userRole,
            roomId: roomId
        )
        
        self.currentSession = updatedSession
        sessionStorage.saveUserSession(updatedSession)
        
        print("加入房间成功: \(roomId)")
        print("RTC音视频通话已连接，角色: \(currentSession.userRole.displayName)")
        if rtmProvider?.isLoggedIn() == true {
            print("RTM消息频道已加入")
        }
    }
    
    /// 离开当前房间
    /// 此方法会同时离开 RTC 音视频房间和 RTM 消息频道
    public func leaveRoom() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        // 获取当前房间ID用于RTM频道离开
        let currentRoomId = currentSession?.roomId
        
        // 离开RTC房间（音视频通话）
        try await rtcProvider.leaveRoom()
        
        // 如果RTM已登录且在频道中，也离开RTM频道
        if let roomId = currentRoomId, rtmProvider?.isLoggedIn() == true {
            try await rtmProvider?.leaveChannel(channelId: roomId)
        }
        
        // 更新连接状态为断开
        connectionState = .disconnected
        
        // 清除房间信息，但保留用户会话
        if let currentSession = currentSession {
            let updatedSession = UserSession(
                userId: currentSession.userId,
                userName: currentSession.userName,
                userRole: currentSession.userRole,
                roomId: nil
            )
            
            self.currentSession = updatedSession
            sessionStorage.saveUserSession(updatedSession)
        }
        
        print("离开房间成功")
        print("RTC音视频通话已断开")
        if currentRoomId != nil && rtmProvider?.isLoggedIn() == true {
            print("RTM消息频道已离开")
        }
        
        // 发送离开房间通知
        NotificationCenter.default.post(
            name: .didLeaveRoom,
            object: self,
            userInfo: [
                "roomId": currentRoomId ?? "",
                "userId": currentSession?.userId ?? "",
                "leftRTC": true,
                "leftRTM": currentRoomId != nil && rtmProvider?.isLoggedIn() == true
            ]
        )
    }
    
    /// 只离开 RTM 消息频道，不影响 RTC 音视频连接
    /// - Parameter channelId: 要离开的频道ID，如果为 nil 则使用当前房间ID
    public func leaveRTMChannel(channelId: String? = nil) async throws {
        guard rtmProvider?.isLoggedIn() == true else {
            throw RealtimeError.configurationError("RTM Provider 未登录")
        }
        
        let targetChannelId = channelId ?? currentSession?.roomId
        guard let roomId = targetChannelId else {
            throw RealtimeError.noActiveSession
        }
        
        try await rtmProvider?.leaveChannel(channelId: roomId)
        print("已离开RTM消息频道: \(roomId)")
        
        // 发送离开RTM频道通知
        NotificationCenter.default.post(
            name: .didLeaveRTMChannel,
            object: self,
            userInfo: [
                "channelId": roomId,
                "userId": currentSession?.userId ?? ""
            ]
        )
    }
    
    /// 只离开 RTC 音视频房间，不影响 RTM 消息连接
    public func leaveRTCRoom() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        try await rtcProvider.leaveRoom()
        connectionState = .disconnected
        
        // 清除房间信息，但保留用户会话
        if let currentSession = currentSession {
            let updatedSession = UserSession(
                userId: currentSession.userId,
                userName: currentSession.userName,
                userRole: currentSession.userRole,
                roomId: nil
            )
            
            self.currentSession = updatedSession
            sessionStorage.saveUserSession(updatedSession)
        }
        
        print("已离开RTC音视频房间")
        
        // 发送离开RTC房间通知
        NotificationCenter.default.post(
            name: .didLeaveRTCRoom,
            object: self,
            userInfo: [
                "roomId": currentSession?.roomId ?? "",
                "userId": currentSession?.userId ?? ""
            ]
        )
    }
    
    // MARK: - Audio Control and Settings Management (需求 5.1, 5.2, 5.3, 5.5, 5.6, 17.6, 18.2)
    

    

    
    /// 设置播放信号音量
    /// - Parameter volume: 音量级别 (0-100)
    /// - Throws: 配置错误、参数错误等
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        // 验证音量范围 (需求 5.2)
        guard AudioSettings.isValidVolume(volume) else {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.invalid.volume",
                arguments: volume, AudioSettings.volumeRange.lowerBound, AudioSettings.volumeRange.upperBound
            )
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard let rtcProvider = rtcProvider else {
            let errorMessage = localizationManager.localizedString(for: "error.rtc.provider.not.configured")
            throw RealtimeError.configurationError(errorMessage)
        }
        
        let clampedVolume = AudioSettings.validateVolume(volume)
        
        do {
            try await rtcProvider.setPlaybackSignalVolume(clampedVolume)
            
            // 更新音频设置，@RealtimeStorage 会自动持久化 (需求 18.2)
            await updateAudioSettings { settings in
                settings.withUpdatedVolume(playbackSignal: clampedVolume)
            }
            
            // 发送本地化的状态提示 (需求 17.6)
            let statusMessage = localizationManager.localizedString(
                for: "audio.playback.volume.set",
                arguments: clampedVolume
            )
            print(statusMessage)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .audioVolumeChanged,
                object: self,
                userInfo: [
                    "volumeType": "playback",
                    "volume": clampedVolume,
                    "audioSettings": audioSettings
                ]
            )
            
        } catch {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.volume.operation.failed",
                arguments: "playback", error.localizedDescription
            )
            throw RealtimeError.configurationError(errorMessage)
        }
    }
    
    /// 设置录音信号音量
    /// - Parameter volume: 音量级别 (0-100)
    /// - Throws: 配置错误、参数错误等
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        // 验证音量范围 (需求 5.2)
        guard AudioSettings.isValidVolume(volume) else {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.invalid.volume",
                arguments: volume, AudioSettings.volumeRange.lowerBound, AudioSettings.volumeRange.upperBound
            )
            throw RealtimeError.configurationError(errorMessage)
        }
        
        guard let rtcProvider = rtcProvider else {
            let errorMessage = localizationManager.localizedString(for: "error.rtc.provider.not.configured")
            throw RealtimeError.configurationError(errorMessage)
        }
        
        let clampedVolume = AudioSettings.validateVolume(volume)
        
        do {
            try await rtcProvider.setRecordingSignalVolume(clampedVolume)
            
            // 更新音频设置，@RealtimeStorage 会自动持久化 (需求 18.2)
            await updateAudioSettings { settings in
                settings.withUpdatedVolume(recordingSignal: clampedVolume)
            }
            
            // 发送本地化的状态提示 (需求 17.6)
            let statusMessage = localizationManager.localizedString(
                for: "audio.recording.volume.set",
                arguments: clampedVolume
            )
            print(statusMessage)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .audioVolumeChanged,
                object: self,
                userInfo: [
                    "volumeType": "recording",
                    "volume": clampedVolume,
                    "audioSettings": audioSettings
                ]
            )
            
        } catch {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.volume.operation.failed",
                arguments: "recording", error.localizedDescription
            )
            throw RealtimeError.configurationError(errorMessage)
        }
    }
    
    /// 停止本地音频流
    /// - Throws: 配置错误、权限错误等
    public func stopLocalAudioStream() async throws {
        guard hasPermission(.audio) else {
            throw RealtimeError.insufficientPermissions(currentUserRole ?? .audience)
        }
        
        guard let rtcProvider = rtcProvider else {
            let errorMessage = localizationManager.localizedString(for: "error.rtc.provider.not.configured")
            throw RealtimeError.configurationError(errorMessage)
        }
        
        do {
            try await rtcProvider.stopLocalAudioStream()
            
            // 更新音频设置，@RealtimeStorage 会自动持久化 (需求 18.2)
            await updateAudioSettings { settings in
                settings.withUpdatedStreamState(false)
            }
            
            // 发送本地化的状态提示 (需求 17.6)
            let statusMessage = localizationManager.localizedString(for: "audio.stream.stopped")
            print(statusMessage)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .audioStreamStateChanged,
                object: self,
                userInfo: [
                    "active": false,
                    "audioSettings": audioSettings
                ]
            )
            
        } catch {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.stream.operation.failed",
                arguments: "stop", error.localizedDescription
            )
            throw RealtimeError.configurationError(errorMessage)
        }
    }
    
    /// 恢复本地音频流
    /// - Throws: 配置错误、权限错误等
    public func resumeLocalAudioStream() async throws {
        guard hasPermission(.audio) else {
            throw RealtimeError.insufficientPermissions(currentUserRole ?? .audience)
        }
        
        guard let rtcProvider = rtcProvider else {
            let errorMessage = localizationManager.localizedString(for: "error.rtc.provider.not.configured")
            throw RealtimeError.configurationError(errorMessage)
        }
        
        do {
            try await rtcProvider.resumeLocalAudioStream()
            
            // 更新音频设置，@RealtimeStorage 会自动持久化 (需求 18.2)
            await updateAudioSettings { settings in
                settings.withUpdatedStreamState(true)
            }
            
            // 发送本地化的状态提示 (需求 17.6)
            let statusMessage = localizationManager.localizedString(for: "audio.stream.resumed")
            print(statusMessage)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .audioStreamStateChanged,
                object: self,
                userInfo: [
                    "active": true,
                    "audioSettings": audioSettings
                ]
            )
            
        } catch {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.stream.operation.failed",
                arguments: "resume", error.localizedDescription
            )
            throw RealtimeError.configurationError(errorMessage)
        }
    }
    
    /// 批量设置音频音量
    /// - Parameters:
    ///   - mixingVolume: 混音音量（可选）
    ///   - playbackVolume: 播放音量（可选）
    ///   - recordingVolume: 录音音量（可选）
    /// - Throws: 配置错误、参数错误等
    public func setAudioVolumes(
        mixingVolume: Int? = nil,
        playbackVolume: Int? = nil,
        recordingVolume: Int? = nil
    ) async throws {
        var errors: [String] = []
        
        // 批量设置音量，收集所有错误
        if let mixing = mixingVolume {
            do {
                try await setAudioMixingVolume(mixing)
            } catch {
                errors.append("Mixing: \(error.localizedDescription)")
            }
        }
        
        if let playback = playbackVolume {
            do {
                try await setPlaybackSignalVolume(playback)
            } catch {
                errors.append("Playback: \(error.localizedDescription)")
            }
        }
        
        if let recording = recordingVolume {
            do {
                try await setRecordingSignalVolume(recording)
            } catch {
                errors.append("Recording: \(error.localizedDescription)")
            }
        }
        
        // 如果有错误，抛出合并的错误信息
        if !errors.isEmpty {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.batch.volume.failed",
                arguments: errors.joined(separator: "; ")
            )
            throw RealtimeError.configurationError(errorMessage)
        }
        
        // 发送批量更新通知
        NotificationCenter.default.post(
            name: .audioBatchVolumeChanged,
            object: self,
            userInfo: [
                "mixingVolume": mixingVolume as Any,
                "playbackVolume": playbackVolume as Any,
                "recordingVolume": recordingVolume as Any,
                "audioSettings": audioSettings
            ]
        )
    }
    
    /// 重置音频设置为默认值
    /// - Throws: 配置错误等
    public func resetAudioSettings() async throws {
        let defaultSettings = AudioSettings.default
        
        do {
            // 批量应用默认设置
            try await setAudioVolumes(
                mixingVolume: defaultSettings.audioMixingVolume,
                playbackVolume: defaultSettings.playbackSignalVolume,
                recordingVolume: defaultSettings.recordingSignalVolume
            )
            
            // 重置麦克风状态
            try await muteMicrophone(defaultSettings.microphoneMuted)
            
            // 重置音频流状态
            if defaultSettings.localAudioStreamActive {
                try await resumeLocalAudioStream()
            } else {
                try await stopLocalAudioStream()
            }
            
            // 发送本地化的重置成功提示 (需求 17.6)
            let resetMessage = localizationManager.localizedString(for: "audio.settings.reset.success")
            print(resetMessage)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .audioSettingsReset,
                object: self,
                userInfo: [
                    "audioSettings": audioSettings
                ]
            )
            
        } catch {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.settings.reset.failed",
                arguments: error.localizedDescription
            )
            throw RealtimeError.configurationError(errorMessage)
        }
    }
    
    /// 获取当前音频状态信息
    /// - Returns: 音频状态信息
    public func getAudioStatus() -> AudioStatusInfo {
        return AudioStatusInfo(
            settings: audioSettings,
            isProviderConnected: rtcProvider != nil,
            hasAudioPermission: hasPermission(.audio),
            currentUserRole: currentUserRole,
            lastModified: audioSettings.lastModified
        )
    }
    
    /// 验证音频设置的完整性
    /// - Returns: 验证结果
    public func validateAudioSettings() -> AudioSettingsValidationResult {
        var validationErrors: [AudioSettingsValidationError] = []
        var warnings: [String] = []
        
        // 验证音量范围
        if !audioSettings.isValid {
            validationErrors.append(.invalidVolumeRange)
        }
        
        // 检查权限一致性
        if audioSettings.localAudioStreamActive && !hasPermission(.audio) {
            validationErrors.append(.permissionMismatch)
        }
        
        // 检查设置版本兼容性
        if audioSettings.settingsVersion > 1 {
            warnings.append(localizationManager.localizedString(for: "audio.settings.version.warning"))
        }
        
        // 检查静音状态一致性
        if audioSettings.microphoneMuted && audioSettings.localAudioStreamActive {
            warnings.append(localizationManager.localizedString(for: "audio.settings.mute.inconsistency"))
        }
        
        return AudioSettingsValidationResult(
            isValid: validationErrors.isEmpty,
            validationErrors: validationErrors,
            warnings: warnings,
            audioSettings: audioSettings,
            validationTime: Date()
        )
    }
    
    /// 同步音频设置到 RTC Provider (需求 5.6)
    /// - Parameter settings: 要同步的音频设置（可选，默认使用当前设置）
    /// - Throws: 同步错误
    public func syncAudioSettingsToProvider(_ settings: AudioSettings? = nil) async throws {
        let targetSettings = settings ?? audioSettings
        
        guard let rtcProvider = rtcProvider else {
            let errorMessage = localizationManager.localizedString(for: "error.rtc.provider.not.configured")
            throw RealtimeError.configurationError(errorMessage)
        }
        
        do {
            // 同步所有音频设置到 RTC Provider
            try await rtcProvider.muteMicrophone(targetSettings.microphoneMuted)
            try await rtcProvider.setAudioMixingVolume(targetSettings.audioMixingVolume)
            try await rtcProvider.setPlaybackSignalVolume(targetSettings.playbackSignalVolume)
            try await rtcProvider.setRecordingSignalVolume(targetSettings.recordingSignalVolume)
            
            if targetSettings.localAudioStreamActive {
                try await rtcProvider.resumeLocalAudioStream()
            } else {
                try await rtcProvider.stopLocalAudioStream()
            }
            
            // 如果同步的不是当前设置，更新当前设置
            if settings != nil {
                await updateAudioSettings { _ in targetSettings }
            }
            
            let syncMessage = localizationManager.localizedString(for: "audio.settings.sync.success")
            print(syncMessage)
            
        } catch {
            let errorMessage = localizationManager.localizedString(
                for: "error.audio.settings.sync.failed",
                arguments: error.localizedDescription
            )
            throw RealtimeError.configurationError(errorMessage)
        }
    }
    // MARK: - Private Methods
    
    // MARK: - Public Persistent State Management (需求: 18.1, 18.2, 18.3)
    
    /// 获取连接历史记录
    /// - Returns: 连接历史记录数组
    public func getConnectionHistory() -> [ConnectionHistoryEntry] {
        return connectionHistory
    }
    
    /// 清除连接历史记录
    public func clearConnectionHistory() {
        connectionHistory.removeAll()
        print("连接历史记录已清除")
    }
    
    /// 更新用户偏好设置（公共接口）
    /// - Parameter preferences: 新的用户偏好设置
    public func updateUserPreferencesPublic(_ preferences: RealtimeManagerPreferences) {
        userPreferences = preferences
        
        // 更新降级链
        setFallbackChain(preferences.preferredFallbackChain)
        
        print("用户偏好设置已更新")
    }
    
    /// 获取用户偏好设置
    /// - Returns: 当前用户偏好设置
    public func getUserPreferences() -> RealtimeManagerPreferences {
        return userPreferences
    }
    
    /// 存储认证令牌到安全存储
    /// - Parameters:
    ///   - token: 认证令牌
    ///   - provider: 服务商类型
    public func storeAuthToken(_ token: String, for provider: ProviderType) {
        authTokens[provider.rawValue] = token
        print("认证令牌已安全存储: \(provider.displayName)")
    }
    
    /// 获取认证令牌
    /// - Parameter provider: 服务商类型
    /// - Returns: 认证令牌，如果不存在则返回 nil
    public func getAuthToken(for provider: ProviderType) -> String? {
        return authTokens[provider.rawValue]
    }
    
    /// 清除指定服务商的认证令牌
    /// - Parameter provider: 服务商类型
    public func clearAuthToken(for provider: ProviderType) {
        authTokens.removeValue(forKey: provider.rawValue)
        print("认证令牌已清除: \(provider.displayName)")
    }
    
    /// 清除所有认证令牌
    public func clearAllAuthTokens() {
        authTokens.removeAll()
        print("所有认证令牌已清除")
    }
    
    /// 获取或生成RTM Token
    /// - Parameter userId: 用户ID
    /// - Returns: RTM Token字符串
    private func getOrGenerateRTMToken(for userId: String) async throws -> String {
        // 首先尝试从存储中获取现有的RTM Token
        let tokenKey = "\(currentProvider.rawValue)_rtm_\(userId)"
        if let existingToken = authTokens[tokenKey] {
            print("使用现有RTM Token: \(userId)")
            return existingToken
        }
        
        // 如果没有现有Token，尝试生成新的Token
        // 这里可以调用Token生成服务或使用默认Token
        let newToken = try await generateRTMToken(for: userId)
        
        // 存储新生成的Token
        authTokens[tokenKey] = newToken
        print("生成并存储新RTM Token: \(userId)")
        
        return newToken
    }
    
    /// 生成RTM Token
    /// - Parameter userId: 用户ID
    /// - Returns: 生成的RTM Token
    private func generateRTMToken(for userId: String) async throws -> String {
        // 在实际应用中，这里应该调用您的Token生成服务
        // 目前返回一个模拟Token用于开发和测试
        
        guard currentConfig != nil else {
            throw RealtimeError.configurationError("RealtimeConfig not available")
        }
        
        // 对于Mock Provider，返回一个简单的测试Token
        if currentProvider == .mock {
            return "mock_rtm_token_\(userId)_\(Date().timeIntervalSince1970)"
        }
        
        // 对于真实的服务商，这里应该实现实际的Token生成逻辑
        // 例如调用您的后端服务来生成Token
        throw RealtimeError.configurationError("RTM Token generation not implemented for provider: \(currentProvider.displayName)")
    }
    
    /// 获取应用状态恢复信息
    /// - Returns: 应用状态恢复信息
    public func getAppStateRecoveryInfo() -> AppStateRecoveryInfo {
        return appStateRecovery
    }
    
    /// 手动触发状态恢复
    /// - Returns: 恢复是否成功
    @discardableResult
    public func triggerStateRecovery() async -> Bool {
        await performStartupStateRecovery()
        return true
    }
    
    /// 重置所有持久化状态
    public func resetAllPersistentState() async {
        // 重置音频设置
        await updateAudioSettings { _ in .default }
        
        // 重置连接历史
        connectionHistory.removeAll()
        
        // 重置用户偏好
        userPreferences = RealtimeManagerPreferences()
        
        // 重置应用状态恢复信息
        appStateRecovery = AppStateRecoveryInfo()
        
        // 清除认证令牌
        authTokens.removeAll()
        
        // 清除会话存储
        sessionStorage.clearUserSession()
        
        print("所有持久化状态已重置")
    }
    
    /// 启用或禁用自动重连
    /// - Parameter enabled: 是否启用自动重连
    public func setAutoReconnectEnabled(_ enabled: Bool) {
        var preferences = userPreferences
        preferences.enableAutoReconnect = enabled
        updateUserPreferences(preferences)
    }
    
    /// 设置最大重连尝试次数
    /// - Parameter maxAttempts: 最大尝试次数
    public func setMaxReconnectAttempts(_ maxAttempts: Int) {
        var preferences = userPreferences
        preferences.maxReconnectAttempts = max(1, maxAttempts)
        updateUserPreferences(preferences)
    }
    
    /// 设置重连间隔
    /// - Parameter interval: 重连间隔（秒）
    public func setReconnectInterval(_ interval: TimeInterval) {
        var preferences = userPreferences
        preferences.reconnectInterval = max(1.0, interval)
        updateUserPreferences(preferences)
    }
    
    /// 启用或禁用连接历史记录
    /// - Parameter enabled: 是否启用连接历史记录
    public func setConnectionHistoryEnabled(_ enabled: Bool) {
        var preferences = userPreferences
        preferences.enableConnectionHistory = enabled
        updateUserPreferences(preferences)
    }
    
    /// 设置连接历史记录最大条数
    /// - Parameter maxEntries: 最大条数
    public func setMaxConnectionHistoryEntries(_ maxEntries: Int) {
        var preferences = userPreferences
        preferences.maxConnectionHistoryEntries = max(1, maxEntries)
        updateUserPreferences(preferences)
        
        // 立即应用限制
        if connectionHistory.count > maxEntries {
            connectionHistory = Array(connectionHistory.suffix(maxEntries))
        }
    }
    
    /// 应用完整的持久化设置
    private func applyFullPersistedSettings() async throws {
        guard let rtcProvider = rtcProvider else { return }
        
        do {
            try await rtcProvider.muteMicrophone(audioSettings.microphoneMuted)
            try await rtcProvider.setAudioMixingVolume(audioSettings.audioMixingVolume)
            try await rtcProvider.setPlaybackSignalVolume(audioSettings.playbackSignalVolume)
            try await rtcProvider.setRecordingSignalVolume(audioSettings.recordingSignalVolume)
            
            if audioSettings.localAudioStreamActive {
                try await rtcProvider.resumeLocalAudioStream()
            } else {
                try await rtcProvider.stopLocalAudioStream()
            }
        } catch {
            print("应用持久化设置失败: \(error)")
            throw error
        }
    }
    
    /// 为重新配置清除会话（内部使用）
    internal func clearSessionForReconfiguration() async {
        currentSession = nil
        // 不清除持久化存储，因为这只是临时清除
    }
    
    // MARK: - Configuration Support
    
    /// Apply storage configuration
    private func applyStorageConfiguration(_ config: StorageConfiguration) async {
        // Configure storage manager with the provided settings
        // This would typically involve setting up the default backend and namespace
        // For now, we'll just store the configuration for future use
    }
    
    /// Apply localization configuration
    private func applyLocalizationConfiguration(_ config: LocalizationConfiguration) async {
        // Set the default language
        await LocalizationManager.shared.setLanguage(config.defaultLanguage)
        
        // Configure auto-detection
        if config.autoDetectSystemLanguage {
            _ = LocalizationManager.shared.detectSystemLanguage()
        }
        
        // Add custom strings if provided
        for (key, translations) in config.customStrings {
            for (language, translation) in translations {
                LocalizationManager.shared.addCustomString(key: key, value: translation, for: language)
            }
        }
    }
}

// MARK: - Storage Classes

/// 音频设置存储管理器
/// 需求: 5.4, 5.5 - 音频设置的持久化存储和恢复
public class AudioSettingsStorage {
    
    // MARK: - Constants
    
    private static let audioSettingsKey = "RealtimeKit.AudioSettings"
    private static let audioSettingsBackupKey = "RealtimeKit.AudioSettings.Backup"
    private static let migrationVersionKey = "RealtimeKit.AudioSettings.MigrationVersion"
    private static let currentMigrationVersion = 1
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // 配置编码器
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // 执行数据迁移检查
        performMigrationIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// 保存音频设置 (需求 5.4)
    public func saveAudioSettings(_ settings: AudioSettings) {
        do {
            // 验证设置有效性
            guard settings.isValid else {
                throw AudioSettingsStorageError.invalidSettings("音频设置包含无效的音量值")
            }
            
            // 创建备份
            createBackup()
            
            // 编码并保存
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: Self.audioSettingsKey)
            
            // 强制同步到磁盘
            userDefaults.synchronize()
            
        } catch {
            handleSaveError(error, settings: settings)
        }
    }
    
    /// 加载音频设置 (需求 5.5)
    public func loadAudioSettings() -> AudioSettings {
        do {
            guard let data = userDefaults.data(forKey: Self.audioSettingsKey) else {
                // 没有保存的设置，返回默认值
                return .default
            }
            
            let settings = try decoder.decode(AudioSettings.self, from: data)
            
            // 验证加载的设置
            guard settings.isValid else {
                throw AudioSettingsStorageError.corruptedData("加载的音频设置数据已损坏")
            }
            
            return settings
            
        } catch {
            return handleLoadError(error)
        }
    }
    
    /// 清除音频设置
    public func clearAudioSettings() {
        userDefaults.removeObject(forKey: Self.audioSettingsKey)
        userDefaults.removeObject(forKey: Self.audioSettingsBackupKey)
        userDefaults.synchronize()
    }
    
    /// 检查是否存在保存的设置
    public func hasStoredSettings() -> Bool {
        return userDefaults.data(forKey: Self.audioSettingsKey) != nil
    }
    
    /// 获取设置的最后修改时间
    public func getLastModifiedTime() -> Date? {
        let settings = loadAudioSettings()
        return settings.lastModified
    }
    
    /// 恢复备份设置
    public func restoreFromBackup() -> AudioSettings? {
        guard let backupData = userDefaults.data(forKey: Self.audioSettingsBackupKey) else {
            return nil
        }
        
        do {
            let backupSettings = try decoder.decode(AudioSettings.self, from: backupData)
            
            // 验证备份设置
            guard backupSettings.isValid else {
                return nil
            }
            
            // 恢复备份设置
            saveAudioSettings(backupSettings)
            return backupSettings
            
        } catch {
            print("Failed to restore backup settings: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// 创建设置备份
    private func createBackup() {
        guard let currentData = userDefaults.data(forKey: Self.audioSettingsKey) else {
            return
        }
        
        userDefaults.set(currentData, forKey: Self.audioSettingsBackupKey)
    }
    
    /// 处理保存错误
    private func handleSaveError(_ error: Error, settings: AudioSettings) {
        print("Failed to save audio settings: \(error)")
        
        // 尝试保存到备份位置
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: Self.audioSettingsBackupKey)
            print("Audio settings saved to backup location")
        } catch {
            print("Failed to save audio settings to backup: \(error)")
        }
    }
    
    /// 处理加载错误
    private func handleLoadError(_ error: Error) -> AudioSettings {
        print("Failed to load audio settings: \(error)")
        
        // 尝试从备份恢复
        if let backupSettings = restoreFromBackup() {
            print("Audio settings restored from backup")
            return backupSettings
        }
        
        // 返回默认设置
        print("Using default audio settings")
        return .default
    }
    
    /// 执行数据迁移
    private func performMigrationIfNeeded() {
        let currentVersion = userDefaults.integer(forKey: Self.migrationVersionKey)
        
        if currentVersion < Self.currentMigrationVersion {
            performMigration(from: currentVersion, to: Self.currentMigrationVersion)
            userDefaults.set(Self.currentMigrationVersion, forKey: Self.migrationVersionKey)
        }
    }
    
    /// 执行具体的数据迁移
    private func performMigration(from oldVersion: Int, to newVersion: Int) {
        print("Migrating audio settings from version \(oldVersion) to \(newVersion)")
        
        switch oldVersion {
        case 0:
            // 从版本0迁移到版本1
            migrateFromVersion0()
        default:
            break
        }
    }
    
    /// 从版本0迁移（添加settingsVersion字段）
    private func migrateFromVersion0() {
        guard let data = userDefaults.data(forKey: Self.audioSettingsKey) else {
            return
        }
        
        do {
            // 尝试解码旧格式的设置
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var mutableJson = json
                
                // 添加缺失的字段
                if mutableJson["settingsVersion"] == nil {
                    mutableJson["settingsVersion"] = 1
                }
                
                // 重新编码并保存
                let migratedData = try JSONSerialization.data(withJSONObject: mutableJson)
                userDefaults.set(migratedData, forKey: Self.audioSettingsKey)
                
                print("Successfully migrated audio settings from version 0")
            }
        } catch {
            print("Failed to migrate audio settings: \(error)")
            // 迁移失败，清除旧数据
            clearAudioSettings()
        }
    }
}

// MARK: - Storage Errors

/// 音频设置存储错误
public enum AudioSettingsStorageError: Error, LocalizedError {
    case invalidSettings(String)
    case corruptedData(String)
    case migrationFailed(String)
    case backupFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSettings(let message):
            return "无效的音频设置: \(message)"
        case .corruptedData(let message):
            return "数据损坏: \(message)"
        case .migrationFailed(let message):
            return "数据迁移失败: \(message)"
        case .backupFailed(let message):
            return "备份失败: \(message)"
        }
    }
}

/// 用户会话存储管理器
/// 需求: 4.4, 4.5 - 用户会话的安全存储和恢复机制
public class UserSessionStorage {
    
    // MARK: - Constants
    
    private static let userSessionKey = "RealtimeKit.UserSession"
    private static let userSessionBackupKey = "RealtimeKit.UserSession.Backup"
    private static let sessionIntegrityKey = "RealtimeKit.UserSession.Integrity"
    private static let maxSessionAge: TimeInterval = 7 * 24 * 3600 // 7天
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // 配置编码器
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    /// 保存用户会话 (需求 4.4)
    public func saveUserSession(_ session: UserSession) {
        do {
            // 验证会话数据完整性
            try validateSessionData(session)
            
            // 创建备份
            createSessionBackup()
            
            // 编码会话数据
            let sessionData = try encoder.encode(session)
            
            // 计算数据完整性校验值
            let integrityHash = calculateIntegrityHash(for: sessionData)
            
            // 保存会话数据和完整性校验值
            userDefaults.set(sessionData, forKey: Self.userSessionKey)
            userDefaults.set(integrityHash, forKey: Self.sessionIntegrityKey)
            
            // 强制同步到磁盘
            userDefaults.synchronize()
            
        } catch {
            handleSaveSessionError(error, session: session)
        }
    }
    
    /// 加载用户会话 (需求 4.5)
    public func loadUserSession() -> UserSession? {
        do {
            guard let sessionData = userDefaults.data(forKey: Self.userSessionKey) else {
                return nil
            }
            
            // 验证数据完整性
            try validateDataIntegrity(sessionData)
            
            // 解码会话数据
            let session = try decoder.decode(UserSession.self, from: sessionData)
            
            // 验证会话有效性
            try validateSessionValidity(session)
            
            return session
            
        } catch {
            return handleLoadSessionError(error)
        }
    }
    
    /// 清除用户会话
    public func clearUserSession() {
        userDefaults.removeObject(forKey: Self.userSessionKey)
        userDefaults.removeObject(forKey: Self.userSessionBackupKey)
        userDefaults.removeObject(forKey: Self.sessionIntegrityKey)
        userDefaults.synchronize()
    }
    
    /// 检查是否存在有效的会话
    public func hasValidSession() -> Bool {
        guard let session = loadUserSession() else {
            return false
        }
        
        return session.isValid(maxInactiveTime: Self.maxSessionAge)
    }
    
    /// 更新会话的最后活跃时间
    public func updateLastActiveTime(for session: UserSession) {
        // 创建更新了活跃时间的新会话
        let updatedSession = UserSession(
            userId: session.userId,
            userName: session.userName,
            userRole: session.userRole,
            roomId: session.roomId,
            deviceInfo: session.deviceInfo
        )
        
        saveUserSession(updatedSession)
    }
    
    /// 恢复备份会话
    public func restoreFromBackup() -> UserSession? {
        guard let backupData = userDefaults.data(forKey: Self.userSessionBackupKey) else {
            return nil
        }
        
        do {
            let backupSession = try decoder.decode(UserSession.self, from: backupData)
            
            // 验证备份会话
            try validateSessionValidity(backupSession)
            
            // 恢复备份会话
            saveUserSession(backupSession)
            return backupSession
            
        } catch {
            print("Failed to restore backup session: \(error)")
            return nil
        }
    }
    
    /// 获取会话统计信息
    public func getSessionStats() -> UserSessionStats? {
        guard let session = loadUserSession() else {
            return nil
        }
        
        let sessionDuration = Date().timeIntervalSince(session.joinTime)
        let inactiveDuration = Date().timeIntervalSince(session.lastActiveTime)
        
        return UserSessionStats(
            sessionId: session.sessionId,
            userId: session.userId,
            sessionDuration: sessionDuration,
            inactiveDuration: inactiveDuration,
            isValid: session.isValid(maxInactiveTime: Self.maxSessionAge)
        )
    }
    
    // MARK: - Private Methods
    
    /// 验证会话数据完整性
    private func validateSessionData(_ session: UserSession) throws {
        // 验证必要字段
        guard !session.userId.isEmpty else {
            throw UserSessionStorageError.invalidSessionData("用户ID不能为空")
        }
        
        guard !session.userName.isEmpty else {
            throw UserSessionStorageError.invalidSessionData("用户名不能为空")
        }
        
        guard !session.sessionId.isEmpty else {
            throw UserSessionStorageError.invalidSessionData("会话ID不能为空")
        }
        
        // 验证时间戳
        let now = Date()
        guard session.joinTime <= now else {
            throw UserSessionStorageError.invalidSessionData("加入时间不能是未来时间")
        }
        
        guard session.lastActiveTime <= now else {
            throw UserSessionStorageError.invalidSessionData("最后活跃时间不能是未来时间")
        }
    }
    
    /// 验证数据完整性
    private func validateDataIntegrity(_ data: Data) throws {
        guard let storedHash = userDefaults.string(forKey: Self.sessionIntegrityKey) else {
            throw UserSessionStorageError.integrityCheckFailed("缺少完整性校验值")
        }
        
        let calculatedHash = calculateIntegrityHash(for: data)
        
        guard storedHash == calculatedHash else {
            throw UserSessionStorageError.integrityCheckFailed("数据完整性校验失败")
        }
    }
    
    /// 验证会话有效性
    private func validateSessionValidity(_ session: UserSession) throws {
        // 检查会话是否过期
        guard session.isValid(maxInactiveTime: Self.maxSessionAge) else {
            throw UserSessionStorageError.sessionExpired("会话已过期")
        }
        
        // 验证会话数据
        try validateSessionData(session)
    }
    
    /// 计算数据完整性校验值
    private func calculateIntegrityHash(for data: Data) -> String {
        // 使用简单的哈希算法（在实际应用中可能需要更强的加密）
        let hash = data.hashValue
        return String(hash)
    }
    
    /// 创建会话备份
    private func createSessionBackup() {
        guard let currentData = userDefaults.data(forKey: Self.userSessionKey) else {
            return
        }
        
        userDefaults.set(currentData, forKey: Self.userSessionBackupKey)
    }
    
    /// 处理保存会话错误
    private func handleSaveSessionError(_ error: Error, session: UserSession) {
        print("Failed to save user session: \(error)")
        
        // 尝试保存到备份位置
        do {
            let data = try encoder.encode(session)
            userDefaults.set(data, forKey: Self.userSessionBackupKey)
            print("User session saved to backup location")
        } catch {
            print("Failed to save user session to backup: \(error)")
        }
    }
    
    /// 处理加载会话错误
    private func handleLoadSessionError(_ error: Error) -> UserSession? {
        print("Failed to load user session: \(error)")
        
        // 尝试从备份恢复
        if let backupSession = restoreFromBackup() {
            print("User session restored from backup")
            return backupSession
        }
        
        // 清除损坏的数据
        clearUserSession()
        print("Cleared corrupted session data")
        return nil
    }
}

// MARK: - User Session Storage Errors and Models

/// 用户会话存储错误
public enum UserSessionStorageError: Error, LocalizedError {
    case invalidSessionData(String)
    case integrityCheckFailed(String)
    case sessionExpired(String)
    case corruptedData(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSessionData(let message):
            return "无效的会话数据: \(message)"
        case .integrityCheckFailed(let message):
            return "完整性检查失败: \(message)"
        case .sessionExpired(let message):
            return "会话已过期: \(message)"
        case .corruptedData(let message):
            return "数据损坏: \(message)"
        }
    }
}

// Note: UserSessionStats is defined in ConnectionModels.swift to avoid duplicates
// Note: Notification names are defined in ConnectionModels.swift to avoid duplicates
