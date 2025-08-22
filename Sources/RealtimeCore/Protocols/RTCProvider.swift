import Foundation

/// 核心RTC（实时通信）提供者协议，用于抽象不同的服务提供商
/// 需求: 1.1, 1.2, 1.3
public protocol RTCProvider: AnyObject {
    // MARK: - 基础生命周期
    
    /// 使用配置初始化RTC提供者
    /// - Parameter config: 包含应用凭证和设置的RTC配置
    func initialize(config: RTCConfig) async throws
    
    /// 使用指定房间ID创建新房间
    /// - Parameter roomId: 房间的唯一标识符
    /// - Returns: 表示创建房间的RTCRoom实例
    func createRoom(roomId: String) async throws -> RTCRoom
    
    /// 使用用户凭证和角色加入现有房间
    /// - Parameters:
    ///   - roomId: 要加入的房间标识符
    ///   - userId: 用户标识符
    ///   - userRole: 用户在房间中的角色（主播、观众等）
    func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws
    
    /// 离开当前房间
    func leaveRoom() async throws
    
    /// 在活动会话期间切换用户角色
    /// - Parameter role: 要切换到的新用户角色
    func switchUserRole(_ role: UserRole) async throws
    
    // MARK: - 音频流控制
    
    /// 静音或取消静音麦克风
    /// - Parameter muted: true表示静音，false表示取消静音
    func muteMicrophone(_ muted: Bool) async throws
    
    /// 检查麦克风当前是否静音
    /// - Returns: 如果静音返回true，否则返回false
    func isMicrophoneMuted() -> Bool
    
    /// 停止本地音频流传输
    func stopLocalAudioStream() async throws
    
    /// 恢复本地音频流传输
    func resumeLocalAudioStream() async throws
    
    /// 检查本地音频流是否活跃
    /// - Returns: 如果活跃返回true，否则返回false
    func isLocalAudioStreamActive() -> Bool
    
    // MARK: - 音量控制
    
    /// 设置音频混音音量（0-100）
    /// - Parameter volume: 音量级别，范围0到100
    func setAudioMixingVolume(_ volume: Int) async throws
    
    /// 获取当前音频混音音量
    /// - Returns: 当前音量级别（0-100）
    func getAudioMixingVolume() -> Int
    
    /// 设置播放信号音量（0-100）
    /// - Parameter volume: 音量级别，范围0到100
    func setPlaybackSignalVolume(_ volume: Int) async throws
    
    /// 获取当前播放信号音量
    /// - Returns: 当前音量级别（0-100）
    func getPlaybackSignalVolume() -> Int
    
    /// 设置录音信号音量（0-100）
    /// - Parameter volume: 音量级别，范围0到100
    func setRecordingSignalVolume(_ volume: Int) async throws
    
    /// 获取当前录音信号音量
    /// - Returns: 当前音量级别（0-100）
    func getRecordingSignalVolume() -> Int
    
    // MARK: - 推流功能
    
    /// 开始向外部平台推流
    /// - Parameter config: 推流配置
    func startStreamPush(config: StreamPushConfig) async throws
    
    /// 停止推流
    func stopStreamPush() async throws
    
    /// 更新推流布局
    /// - Parameter layout: 新的流布局配置
    func updateStreamPushLayout(layout: StreamLayout) async throws
    
    // MARK: - 媒体中继功能
    
    /// 开始跨媒体流中继
    /// - Parameter config: 媒体中继配置
    func startMediaRelay(config: MediaRelayConfig) async throws
    
    /// 停止媒体中继
    func stopMediaRelay() async throws
    
    /// 更新媒体中继频道
    /// - Parameter config: 更新的媒体中继配置
    func updateMediaRelayChannels(config: MediaRelayConfig) async throws
    
    /// 暂停到指定频道的媒体中继
    /// - Parameter toChannel: 要暂停的目标频道
    func pauseMediaRelay(toChannel: String) async throws
    
    /// 恢复到指定频道的媒体中继
    /// - Parameter toChannel: 要恢复的目标频道
    func resumeMediaRelay(toChannel: String) async throws
    
    // MARK: - 音量指示器功能
    
    /// 启用音量指示器配置
    /// - Parameter config: 音量检测配置
    func enableVolumeIndicator(config: VolumeDetectionConfig) async throws
    
    /// 禁用音量指示器
    func disableVolumeIndicator() async throws
    
    /// 设置音量指示器更新处理器
    /// - Parameter handler: 音量更新的回调
    func setVolumeIndicatorHandler(_ handler: @escaping ([UserVolumeInfo]) -> Void)
    
    /// 设置音量事件处理器，用于说话状态变化
    /// - Parameter handler: 音量事件的回调
    func setVolumeEventHandler(_ handler: @escaping (VolumeEvent) -> Void)
    
    /// 获取所有用户的当前音量信息
    /// - Returns: 用户音量信息数组
    func getCurrentVolumeInfos() -> [UserVolumeInfo]
    
    /// 获取指定用户的音量信息
    /// - Parameter userId: 用户标识符
    /// - Returns: 用户的音量信息，如果未找到则返回nil
    func getVolumeInfo(for userId: String) -> UserVolumeInfo?
    
    // MARK: - Token管理
    
    /// 更新认证令牌
    /// - Parameter newToken: 新的认证令牌
    func renewToken(_ newToken: String) async throws
    
    /// 设置令牌过期处理器
    /// - Parameter handler: 令牌即将过期时的回调（剩余秒数）
    func onTokenWillExpire(_ handler: @escaping (Int) -> Void)
}