import Foundation

/// 核心RTM（实时消息）提供者协议，用于抽象不同的消息服务提供商
/// 需求: 1.1, 1.2, 1.3
public protocol RTMProvider: AnyObject {
    // MARK: - 基础生命周期
    
    /// 使用配置初始化RTM提供者
    /// - Parameter config: 包含应用凭证和设置的RTM配置
    func initialize(config: RTMConfig) async throws
    
    /// 登录RTM系统
    /// - Parameters:
    ///   - userId: 用户标识符
    ///   - token: 认证令牌
    func login(userId: String, token: String) async throws
    
    /// 登出RTM系统
    func logout() async throws
    
    /// 获取当前登录状态
    /// - Returns: 如果已登录返回true，否则返回false
    func isLoggedIn() -> Bool
    
    // MARK: - 频道管理
    
    /// 创建频道实例
    /// - Parameter channelId: 频道标识符
    /// - Returns: RTMChannel实例
    func createChannel(channelId: String) -> RTMChannel
    
    /// 加入频道
    /// - Parameter channelId: 要加入的频道标识符
    func joinChannel(channelId: String) async throws
    
    /// 离开频道
    /// - Parameter channelId: 要离开的频道标识符
    func leaveChannel(channelId: String) async throws
    
    /// 获取频道成员列表
    /// - Parameter channelId: 频道标识符
    /// - Returns: 频道成员数组
    func getChannelMembers(channelId: String) async throws -> [RTMChannelMember]
    
    /// 获取频道成员数量
    /// - Parameter channelId: 频道标识符
    /// - Returns: 成员数量
    func getChannelMemberCount(channelId: String) async throws -> Int
    
    // MARK: - 消息发送
    
    /// 发送点对点消息
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - peerId: 接收者用户ID
    ///   - options: 消息选项（可选）
    func sendPeerMessage(_ message: RTMMessage, toPeer peerId: String, options: RTMSendMessageOptions?) async throws
    
    /// 发送频道消息
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - channelId: 目标频道ID
    ///   - options: 消息选项（可选）
    func sendChannelMessage(_ message: RTMMessage, toChannel channelId: String, options: RTMSendMessageOptions?) async throws
    
    // MARK: - 用户属性管理
    
    /// 设置本地用户属性
    /// - Parameter attributes: 用户属性字典
    func setLocalUserAttributes(_ attributes: [String: String]) async throws
    
    /// 添加或更新本地用户属性
    /// - Parameter attributes: 要添加或更新的属性字典
    func addOrUpdateLocalUserAttributes(_ attributes: [String: String]) async throws
    
    /// 删除本地用户属性
    /// - Parameter attributeKeys: 要删除的属性键数组
    func deleteLocalUserAttributesByKeys(_ attributeKeys: [String]) async throws
    
    /// 清除本地用户所有属性
    func clearLocalUserAttributes() async throws
    
    /// 获取指定用户的属性
    /// - Parameter userId: 用户标识符
    /// - Returns: 用户属性字典
    func getUserAttributes(userId: String) async throws -> [String: String]
    
    /// 批量获取用户属性
    /// - Parameter userIds: 用户ID数组
    /// - Returns: 用户ID到属性字典的映射
    func getUsersAttributes(userIds: [String]) async throws -> [String: [String: String]]
    
    // MARK: - 频道属性管理
    
    /// 设置频道属性
    /// - Parameters:
    ///   - channelId: 频道标识符
    ///   - attributes: 频道属性字典
    ///   - options: 属性操作选项（可选）
    func setChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws
    
    /// 添加或更新频道属性
    /// - Parameters:
    ///   - channelId: 频道标识符
    ///   - attributes: 要添加或更新的属性字典
    ///   - options: 属性操作选项（可选）
    func addOrUpdateChannelAttributes(channelId: String, attributes: [String: String], options: RTMChannelAttributeOptions?) async throws
    
    /// 删除频道属性
    /// - Parameters:
    ///   - channelId: 频道标识符
    ///   - attributeKeys: 要删除的属性键数组
    ///   - options: 属性操作选项（可选）
    func deleteChannelAttributesByKeys(channelId: String, attributeKeys: [String], options: RTMChannelAttributeOptions?) async throws
    
    /// 清除频道所有属性
    /// - Parameters:
    ///   - channelId: 频道标识符
    ///   - options: 属性操作选项（可选）
    func clearChannelAttributes(channelId: String, options: RTMChannelAttributeOptions?) async throws
    
    /// 获取频道属性
    /// - Parameter channelId: 频道标识符
    /// - Returns: 频道属性字典
    func getChannelAttributes(channelId: String) async throws -> [String: String]
    
    /// 根据键获取频道属性
    /// - Parameters:
    ///   - channelId: 频道标识符
    ///   - attributeKeys: 属性键数组
    /// - Returns: 频道属性字典
    func getChannelAttributesByKeys(channelId: String, attributeKeys: [String]) async throws -> [String: String]
    
    // MARK: - 在线状态查询
    
    /// 查询用户在线状态
    /// - Parameter userIds: 要查询的用户ID数组
    /// - Returns: 用户ID到在线状态的映射
    func queryPeersOnlineStatus(userIds: [String]) async throws -> [String: Bool]
    
    /// 订阅用户在线状态
    /// - Parameter userIds: 要订阅的用户ID数组
    func subscribePeersOnlineStatus(userIds: [String]) async throws
    
    /// 取消订阅用户在线状态
    /// - Parameter userIds: 要取消订阅的用户ID数组
    func unsubscribePeersOnlineStatus(userIds: [String]) async throws
    
    /// 查询已订阅用户列表
    /// - Returns: 已订阅的用户ID数组
    func querySubscribedPeersList() async throws -> [String]
    
    // MARK: - Token管理
    
    /// 更新认证令牌
    /// - Parameter newToken: 新的认证令牌
    func renewToken(_ newToken: String) async throws
    
    /// 设置令牌过期处理器
    /// - Parameter handler: 令牌即将过期时的回调
    func onTokenWillExpire(_ handler: @escaping () -> Void)
    
    // MARK: - 事件处理器
    
    /// 设置连接状态变化处理器
    /// - Parameter handler: 连接状态变化的回调
    func onConnectionStateChanged(_ handler: @escaping (RTMConnectionState, RTMConnectionChangeReason) -> Void)
    
    /// 设置点对点消息接收处理器
    /// - Parameter handler: 接收点对点消息的回调
    func onPeerMessageReceived(_ handler: @escaping (RTMMessage, String) -> Void)
    
    /// 设置频道消息接收处理器
    /// - Parameter handler: 接收频道消息的回调
    func onChannelMessageReceived(_ handler: @escaping (RTMMessage, RTMChannelMember, String) -> Void)
    
    /// 设置用户在线状态变化处理器
    /// - Parameter handler: 用户在线状态变化的回调
    func onPeersOnlineStatusChanged(_ handler: @escaping ([String: Bool]) -> Void)
}