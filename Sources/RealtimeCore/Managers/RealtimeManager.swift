import Foundation
import Combine

/// RealtimeManager 核心管理器
/// 统一管理所有实时通信功能
/// 需求: 3.1, 3.2, 3.3, 3.5

@MainActor
public class RealtimeManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = RealtimeManager()
    
    // MARK: - Published Properties for SwiftUI
    
    @Published public private(set) var currentSession: UserSession?
    @Published public private(set) var audioSettings: AudioSettings = .default
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var streamPushState: StreamPushState = .stopped
    @Published public private(set) var mediaRelayState: MediaRelayState?
    @Published public private(set) var volumeInfos: [UserVolumeInfo] = []
    @Published public private(set) var speakingUsers: Set<String> = []
    @Published public private(set) var dominantSpeaker: String? = nil
    
    // MARK: - Private Properties
    
    private let settingsStorage = AudioSettingsStorage()
    private let sessionStorage = UserSessionStorage()
    private let tokenManager = TokenManager()
    
    private var rtcProvider: RTCProvider?
    private var rtmProvider: RTMProvider?
    internal var currentConfig: RealtimeConfig?
    private var currentProvider: ProviderType?
    
    // MARK: - Initialization
    
    private init() {
        // 恢复持久化设置
        restorePersistedSettings()
    }
    
    deinit {
        // 清理通知观察者
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration
    
    public func configure(provider: ProviderType, config: RealtimeConfig) async throws {
        currentConfig = config
        currentProvider = provider
        
        // 创建服务商实例
        let factory = createProviderFactory(for: provider)
        rtcProvider = factory.createRTCProvider()
        rtmProvider = factory.createRTMProvider()
        
        // 初始化服务商
        try await rtcProvider?.initialize(config: RTCConfig(from: config))
        try await rtmProvider?.initialize(config: RTMConfig(from: config))
        
        // 设置事件处理
        setupEventHandlers()
        
        // 设置 Token 管理
        setupTokenManagement()
        
        // 应用持久化设置
        try await applyPersistedSettings()
        
        connectionState = .connected
        print("RealtimeManager 配置完成，使用服务商: \(provider.displayName)")
    }
    
    // MARK: - Session Management
    
    public func loginUser(userId: String, userName: String, userRole: UserRole) async throws {
        guard rtcProvider != nil, rtmProvider != nil else {
            throw RealtimeError.configurationError("RealtimeManager 未配置")
        }
        
        let session = UserSession(userId: userId, userName: userName, userRole: userRole)
        currentSession = session
        sessionStorage.saveUserSession(session)
        
        print("用户登录: \(userName) (\(userRole.displayName))")
    }
    
    public func logoutUser() async throws {
        if currentSession?.roomId != nil {
            try await leaveRoom()
        }
        
        currentSession = nil
        sessionStorage.clearUserSession()
        connectionState = .disconnected
        
        print("用户登出")
    }
    
    public func switchUserRole(_ newRole: UserRole) async throws {
        guard let currentSession = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        try await rtcProvider?.switchUserRole(newRole)
        
        let updatedSession = UserSession(
            userId: currentSession.userId,
            userName: currentSession.userName,
            userRole: newRole,
            roomId: currentSession.roomId
        )
        
        self.currentSession = updatedSession
        sessionStorage.saveUserSession(updatedSession)
        
        print("用户角色切换到: \(newRole.displayName)")
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
        
        try await rtcProvider.joinRoom(
            roomId: roomId,
            userId: currentSession.userId,
            userRole: currentSession.userRole
        )
        
        // 更新会话信息
        let updatedSession = UserSession(
            userId: currentSession.userId,
            userName: currentSession.userName,
            userRole: currentSession.userRole,
            roomId: roomId
        )
        
        self.currentSession = updatedSession
        sessionStorage.saveUserSession(updatedSession)
        
        print("加入房间: \(roomId)")
    }
    
    public func leaveRoom() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        try await rtcProvider.leaveRoom()
        
        // 清除房间信息
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
        
        print("离开房间")
    }
    
    // MARK: - Audio Control
    
    public func muteMicrophone(_ muted: Bool) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        try await rtcProvider.muteMicrophone(muted)
        
        audioSettings = AudioSettings(
            microphoneMuted: muted,
            audioMixingVolume: audioSettings.audioMixingVolume,
            playbackSignalVolume: audioSettings.playbackSignalVolume,
            recordingSignalVolume: audioSettings.recordingSignalVolume,
            localAudioStreamActive: audioSettings.localAudioStreamActive
        )
        
        settingsStorage.saveAudioSettings(audioSettings)
        print("麦克风 \(muted ? "静音" : "取消静音")")
    }
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setAudioMixingVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(audioMixing: clampedVolume)
        settingsStorage.saveAudioSettings(audioSettings)
        
        print("设置混音音量: \(clampedVolume)")
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setPlaybackSignalVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(playbackSignal: clampedVolume)
        settingsStorage.saveAudioSettings(audioSettings)
        
        print("设置播放音量: \(clampedVolume)")
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        let clampedVolume = max(0, min(100, volume))
        try await rtcProvider.setRecordingSignalVolume(clampedVolume)
        
        audioSettings = audioSettings.withUpdatedVolume(recordingSignal: clampedVolume)
        settingsStorage.saveAudioSettings(audioSettings)
        
        print("设置录音音量: \(clampedVolume)")
    }
    
    // MARK: - Volume Indicator
    
    public func enableVolumeIndicator(config: VolumeDetectionConfig = .default) async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        try await rtcProvider.enableVolumeIndicator(config: config)
        print("启用音量指示器")
    }
    
    public func disableVolumeIndicator() async throws {
        guard let rtcProvider = rtcProvider else {
            throw RealtimeError.configurationError("RTC Provider 未配置")
        }
        
        try await rtcProvider.disableVolumeIndicator()
        volumeInfos = []
        speakingUsers = []
        dominantSpeaker = nil
        
        print("禁用音量指示器")
    }
    
    // MARK: - Token Management
    
    /// 设置 Token 续期处理器 (需求 9.2)
    /// - Parameter handler: Token 续期处理器，返回新的 Token
    public func setupTokenRenewal(handler: @escaping @Sendable () async throws -> String) {
        guard let provider = currentProvider else {
            print("TokenManager: 未配置服务商，无法设置 Token 续期处理器")
            return
        }
        
        tokenManager.setupTokenRenewal(provider: provider, handler: handler)
    }
    
    /// 立即执行 Token 续期
    public func renewTokenImmediately() async {
        guard let provider = currentProvider else {
            print("TokenManager: 未配置服务商，无法执行 Token 续期")
            return
        }
        
        await tokenManager.renewTokenImmediately(provider: provider)
    }
    
    /// 获取当前服务商的 Token 状态
    /// - Returns: Token 状态，如果未配置则返回 nil
    public func getCurrentTokenState() -> TokenState? {
        guard let provider = currentProvider else { return nil }
        return tokenManager.getTokenState(for: provider)
    }
    
    /// 配置 Token 续期重试策略
    /// - Parameter configuration: 重试配置
    public func configureTokenRetryStrategy(configuration: RetryConfiguration) {
        guard let provider = currentProvider else {
            print("TokenManager: 未配置服务商，无法设置重试策略")
            return
        }
        
        tokenManager.configureRetryStrategy(for: provider, configuration: configuration)
    }
    
    /// 获取 Token 续期统计信息
    /// - Returns: 续期统计信息
    public func getTokenRenewalStats() -> TokenRenewalStats {
        return tokenManager.renewalStats
    }
    
    // MARK: - Private Methods
    
    private func createProviderFactory(for type: ProviderType) -> ProviderFactory {
        switch type {
        case .agora:
            // 这里需要导入 RealtimeAgora 模块
            fatalError("Agora provider factory not implemented yet")
        case .mock:
            // 这里需要导入 RealtimeMocking 模块
            fatalError("Mock provider factory not implemented yet")
        default:
            fatalError("Unsupported provider type: \(type)")
        }
    }
    
    private func setupEventHandlers() {
        // 设置音量指示器处理器
        rtcProvider?.setVolumeIndicatorHandler { [weak self] volumeInfos in
            Task { @MainActor in
                self?.handleVolumeUpdate(volumeInfos)
            }
        }
        
        // 设置音量事件处理器
        rtcProvider?.setVolumeEventHandler { [weak self] (event: VolumeEvent) in
            Task { @MainActor in
                self?.handleVolumeEvent(event)
            }
        }
    }
    
    /// 设置 Token 管理 (需求 9.1, 9.2, 9.5)
    private func setupTokenManagement() {
        guard let provider = currentProvider else { return }
        
        // 设置 RTC Provider 的 Token 过期处理器
        rtcProvider?.onTokenWillExpire { [weak self] expiresIn in
            Task { @MainActor in
                await self?.tokenManager.handleTokenExpiration(
                    provider: provider,
                    expiresIn: expiresIn
                )
            }
        }
        
        // 设置 RTM Provider 的 Token 过期处理器
        rtmProvider?.onTokenWillExpire { [weak self] in
            Task { @MainActor in
                // RTM Provider 没有提供剩余时间，使用默认值
                await self?.tokenManager.handleTokenExpiration(
                    provider: provider,
                    expiresIn: 60 // 默认 60 秒
                )
            }
        }
        
        // 监听 Token 续期通知
        NotificationCenter.default.addObserver(
            forName: .tokenRenewed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // 提取通知数据以避免并发问题
            if let userInfo = notification.userInfo,
               let provider = userInfo["provider"] as? ProviderType,
               let newToken = userInfo["token"] as? String {
                Task { @MainActor in
                    await self?.handleTokenRenewalNotification(provider: provider, newToken: newToken)
                }
            }
        }
        
        print("TokenManager: 已设置 \(provider.displayName) 的 Token 管理")
    }
    
    /// 处理 Token 续期通知
    /// - Parameters:
    ///   - provider: 服务商类型
    ///   - newToken: 新的 Token
    private func handleTokenRenewalNotification(provider: ProviderType, newToken: String) async {
        
        do {
            // 更新 RTC Provider Token
            try await rtcProvider?.renewToken(newToken)
            
            // 更新 RTM Provider Token
            try await rtmProvider?.renewToken(newToken)
            
            print("TokenManager: \(provider.displayName) Token 更新成功")
            
        } catch {
            print("TokenManager: \(provider.displayName) Token 更新失败: \(error)")
            
            // 发送失败通知
            NotificationCenter.default.post(
                name: .tokenRenewalFailed,
                object: self,
                userInfo: [
                    "provider": provider,
                    "error": error
                ]
            )
        }
    }
    
    private func handleVolumeUpdate(_ volumeInfos: [UserVolumeInfo]) {
        self.volumeInfos = volumeInfos
        
        let newSpeakingUsers = Set(volumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        speakingUsers = newSpeakingUsers
        
        let newDominantSpeaker = volumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        dominantSpeaker = newDominantSpeaker
        
        // 发送通知给 UIKit 组件
        NotificationCenter.default.post(
            name: .realtimeVolumeInfoUpdated,
            object: nil,
            userInfo: ["volumeInfos": volumeInfos]
        )
    }
    
    private func handleVolumeEvent(_ event: VolumeEvent) {
        // 处理音量事件
        switch event {
        case .userStartedSpeaking(let userId, _):
            print("用户 \(userId) 开始说话")
        case .userStoppedSpeaking(let userId, _):
            print("用户 \(userId) 停止说话")
        case .dominantSpeakerChanged(let userId):
            print("主讲人变更: \(userId ?? "无")")
        case .volumeUpdate:
            break // 已在 handleVolumeUpdate 中处理
        }
    }
    
    private func restorePersistedSettings() {
        audioSettings = settingsStorage.loadAudioSettings()
        
        if let session = sessionStorage.loadUserSession() {
            currentSession = session
        }
    }
    
    private func applyPersistedSettings() async throws {
        guard let rtcProvider = rtcProvider else { return }
        
        try await rtcProvider.muteMicrophone(audioSettings.microphoneMuted)
        try await rtcProvider.setAudioMixingVolume(audioSettings.audioMixingVolume)
        try await rtcProvider.setPlaybackSignalVolume(audioSettings.playbackSignalVolume)
        try await rtcProvider.setRecordingSignalVolume(audioSettings.recordingSignalVolume)
        
        if audioSettings.localAudioStreamActive {
            try await rtcProvider.resumeLocalAudioStream()
        } else {
            try await rtcProvider.stopLocalAudioStream()
        }
    }
    
    // MARK: - Internal Methods (for testing and provider switching)
    
    internal func applyAudioSettings(_ settings: AudioSettings) async throws {
        guard let rtcProvider = rtcProvider else { return }
        
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
    
    internal func restoreSession(_ session: UserSession) async throws {
        currentSession = session
        sessionStorage.saveUserSession(session)
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

/// 用户会话统计信息
public struct UserSessionStats {
    public let sessionId: String
    public let userId: String
    public let sessionDuration: TimeInterval
    public let inactiveDuration: TimeInterval
    public let isValid: Bool
    
    public init(
        sessionId: String,
        userId: String,
        sessionDuration: TimeInterval,
        inactiveDuration: TimeInterval,
        isValid: Bool
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.sessionDuration = sessionDuration
        self.inactiveDuration = inactiveDuration
        self.isValid = isValid
    }
    
    /// 格式化的会话持续时间
    public var formattedSessionDuration: String {
        let hours = Int(sessionDuration) / 3600
        let minutes = Int(sessionDuration) % 3600 / 60
        let seconds = Int(sessionDuration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// 格式化的非活跃时间
    public var formattedInactiveDuration: String {
        let minutes = Int(inactiveDuration) / 60
        let seconds = Int(inactiveDuration) % 60
        
        if minutes > 0 {
            return String(format: "%d分%d秒", minutes, seconds)
        } else {
            return String(format: "%d秒", seconds)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let realtimeConnectionStateChanged = Notification.Name("RealtimeKit.connectionStateChanged")
    static let realtimeVolumeInfoUpdated = Notification.Name("RealtimeKit.volumeInfoUpdated")
}