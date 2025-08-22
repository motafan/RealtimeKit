import Foundation

// MARK: - Realtime Message Processing Models (需求 10.1, 10.2)

/// 实时消息模型，支持消息处理管道
public struct RealtimeMessage: Codable, Identifiable, Equatable, Sendable {
    /// 消息唯一标识符
    public let id: String
    
    /// 消息类型
    public let type: RealtimeMessageType
    
    /// 消息内容
    public let content: MessageContent
    
    /// 发送者用户ID
    public let senderId: String
    
    /// 接收者用户ID（点对点消息）
    public let receiverId: String?
    
    /// 频道ID（频道消息）
    public let channelId: String?
    
    /// 消息时间戳
    public let timestamp: Date
    
    /// 消息元数据
    public let metadata: [String: MessageMetadataValue]
    
    /// 消息状态
    public let status: RealtimeMessageStatus
    
    /// 消息优先级
    public let priority: MessagePriority
    
    /// 消息过期时间
    public let expirationTime: Date?
    
    /// 消息处理标记
    public let processingFlags: MessageProcessingFlags
    
    public init(
        id: String = UUID().uuidString,
        type: RealtimeMessageType,
        content: MessageContent,
        senderId: String,
        receiverId: String? = nil,
        channelId: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: MessageMetadataValue] = [:],
        status: RealtimeMessageStatus = .pending,
        priority: MessagePriority = .normal,
        expirationTime: Date? = nil,
        processingFlags: MessageProcessingFlags = MessageProcessingFlags()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.senderId = senderId
        self.receiverId = receiverId
        self.channelId = channelId
        self.timestamp = timestamp
        self.metadata = metadata
        self.status = status
        self.priority = priority
        self.expirationTime = expirationTime
        self.processingFlags = processingFlags
    }
    
    /// 检查消息是否过期
    public var isExpired: Bool {
        guard let expirationTime = expirationTime else { return false }
        return Date() > expirationTime
    }
    
    /// 检查消息是否为点对点消息
    public var isDirectMessage: Bool {
        return receiverId != nil && channelId == nil
    }
    
    /// 检查消息是否为频道消息
    public var isChannelMessage: Bool {
        return channelId != nil && receiverId == nil
    }
    
    /// 创建带有新状态的消息副本
    public func withStatus(_ newStatus: RealtimeMessageStatus) -> RealtimeMessage {
        return RealtimeMessage(
            id: self.id,
            type: self.type,
            content: self.content,
            senderId: self.senderId,
            receiverId: self.receiverId,
            channelId: self.channelId,
            timestamp: self.timestamp,
            metadata: self.metadata,
            status: newStatus,
            priority: self.priority,
            expirationTime: self.expirationTime,
            processingFlags: self.processingFlags
        )
    }
    
    /// 创建带有新元数据的消息副本
    public func withMetadata(_ newMetadata: [String: MessageMetadataValue]) -> RealtimeMessage {
        return RealtimeMessage(
            id: self.id,
            type: self.type,
            content: self.content,
            senderId: self.senderId,
            receiverId: self.receiverId,
            channelId: self.channelId,
            timestamp: self.timestamp,
            metadata: newMetadata,
            status: self.status,
            priority: self.priority,
            expirationTime: self.expirationTime,
            processingFlags: self.processingFlags
        )
    }
}

/// 实时消息类型 (需求 10.1)
public enum RealtimeMessageType: String, CaseIterable, Codable, Sendable {
    case text = "text"
    case image = "image"
    case audio = "audio"
    case video = "video"
    case file = "file"
    case system = "system"
    case custom = "custom"
    case notification = "notification"
    case command = "command"
    
    public var displayName: String {
        switch self {
        case .text: return "文本消息"
        case .image: return "图片消息"
        case .audio: return "音频消息"
        case .video: return "视频消息"
        case .file: return "文件消息"
        case .system: return "系统消息"
        case .custom: return "自定义消息"
        case .notification: return "通知消息"
        case .command: return "命令消息"
        }
    }
    
    /// 检查消息类型是否需要特殊处理
    public var requiresSpecialProcessing: Bool {
        switch self {
        case .system, .command, .notification:
            return true
        case .text, .image, .audio, .video, .file, .custom:
            return false
        }
    }
}

/// 消息内容 (需求 10.1)
public enum MessageContent: Codable, Equatable, Sendable {
    case text(String)
    case image(ImageContent)
    case audio(AudioContent)
    case video(VideoContent)
    case file(FileContent)
    case system(SystemContent)
    case custom(CustomContent)
    
    public var textValue: String? {
        switch self {
        case .text(let text):
            return text
        case .system(let content):
            return content.message
        default:
            return nil
        }
    }
    
    public var isEmpty: Bool {
        switch self {
        case .text(let text):
            return text.isEmpty
        case .system(let content):
            return content.message.isEmpty
        default:
            return false
        }
    }
}

/// 图片内容
public struct ImageContent: Codable, Equatable, Sendable {
    public let url: String
    public let thumbnailUrl: String?
    public let width: Int?
    public let height: Int?
    public let fileSize: Int?
    public let mimeType: String?
    
    public init(url: String, thumbnailUrl: String? = nil, width: Int? = nil, height: Int? = nil, fileSize: Int? = nil, mimeType: String? = nil) {
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

/// 音频内容
public struct AudioContent: Codable, Equatable, Sendable {
    public let url: String
    public let duration: TimeInterval?
    public let fileSize: Int?
    public let mimeType: String?
    
    public init(url: String, duration: TimeInterval? = nil, fileSize: Int? = nil, mimeType: String? = nil) {
        self.url = url
        self.duration = duration
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

/// 视频内容
public struct VideoContent: Codable, Equatable, Sendable {
    public let url: String
    public let thumbnailUrl: String?
    public let duration: TimeInterval?
    public let width: Int?
    public let height: Int?
    public let fileSize: Int?
    public let mimeType: String?
    
    public init(url: String, thumbnailUrl: String? = nil, duration: TimeInterval? = nil, width: Int? = nil, height: Int? = nil, fileSize: Int? = nil, mimeType: String? = nil) {
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

/// 文件内容
public struct FileContent: Codable, Equatable, Sendable {
    public let url: String
    public let fileName: String
    public let fileSize: Int?
    public let mimeType: String?
    
    public init(url: String, fileName: String, fileSize: Int? = nil, mimeType: String? = nil) {
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

/// 系统内容
public struct SystemContent: Codable, Equatable, Sendable {
    public let message: String
    public let systemType: SystemMessageType
    public let parameters: [String: String]
    
    public init(message: String, systemType: SystemMessageType, parameters: [String: String] = [:]) {
        self.message = message
        self.systemType = systemType
        self.parameters = parameters
    }
}

/// 自定义内容
public struct CustomContent: Codable, Equatable, Sendable {
    public let data: [String: MessageMetadataValue]
    public let customType: String
    
    public init(data: [String: MessageMetadataValue], customType: String) {
        self.data = data
        self.customType = customType
    }
}

/// 系统消息类型
public enum SystemMessageType: String, CaseIterable, Codable, Sendable {
    case userJoined = "user_joined"
    case userLeft = "user_left"
    case userRoleChanged = "user_role_changed"
    case roomCreated = "room_created"
    case roomDestroyed = "room_destroyed"
    case connectionLost = "connection_lost"
    case connectionRestored = "connection_restored"
    
    public var displayName: String {
        switch self {
        case .userJoined: return "用户加入"
        case .userLeft: return "用户离开"
        case .userRoleChanged: return "用户角色变更"
        case .roomCreated: return "房间创建"
        case .roomDestroyed: return "房间销毁"
        case .connectionLost: return "连接丢失"
        case .connectionRestored: return "连接恢复"
        }
    }
}

/// 消息元数据值
public enum MessageMetadataValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([MessageMetadataValue])
    case dictionary([String: MessageMetadataValue])
    
    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        default: return nil
        }
    }
    
    public var intValue: Int? {
        switch self {
        case .int(let value): return value
        default: return nil
        }
    }
    
    public var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        default: return nil
        }
    }
}

/// 实时消息状态 (需求 10.2)
public enum RealtimeMessageStatus: String, CaseIterable, Codable, Sendable {
    case pending = "pending"
    case processing = "processing"
    case processed = "processed"
    case sent = "sent"
    case delivered = "delivered"
    case failed = "failed"
    case expired = "expired"
    
    public var displayName: String {
        switch self {
        case .pending: return "待处理"
        case .processing: return "处理中"
        case .processed: return "已处理"
        case .sent: return "已发送"
        case .delivered: return "已送达"
        case .failed: return "发送失败"
        case .expired: return "已过期"
        }
    }
}

/// 消息优先级
public enum MessagePriority: String, CaseIterable, Codable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    public var displayName: String {
        switch self {
        case .low: return "低优先级"
        case .normal: return "普通优先级"
        case .high: return "高优先级"
        case .urgent: return "紧急优先级"
        }
    }
    
    public var numericValue: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
}

/// 消息处理标记 (需求 10.2)
public struct MessageProcessingFlags: Codable, Equatable, Sendable {
    public let requiresEncryption: Bool
    public let requiresValidation: Bool
    public let requiresFiltering: Bool
    public let requiresTransformation: Bool
    public let skipOfflineStorage: Bool
    public let skipNotification: Bool
    
    public init(
        requiresEncryption: Bool = false,
        requiresValidation: Bool = true,
        requiresFiltering: Bool = true,
        requiresTransformation: Bool = false,
        skipOfflineStorage: Bool = false,
        skipNotification: Bool = false
    ) {
        self.requiresEncryption = requiresEncryption
        self.requiresValidation = requiresValidation
        self.requiresFiltering = requiresFiltering
        self.requiresTransformation = requiresTransformation
        self.skipOfflineStorage = skipOfflineStorage
        self.skipNotification = skipNotification
    }
}

// MARK: - Message Validation (需求 10.2)

/// 消息验证器
public struct MessageValidator {
    /// 验证消息内容
    public static func validate(_ message: RealtimeMessage) -> MessageValidationResult {
        var errors: [MessageValidationError] = []
        
        // 验证基本字段
        if message.senderId.isEmpty {
            errors.append(.emptySenderId)
        }
        
        if message.content.isEmpty {
            errors.append(.emptyContent)
        }
        
        // 验证消息类型和内容匹配
        if !isContentMatchingType(message.content, type: message.type) {
            errors.append(.contentTypeMismatch)
        }
        
        // 验证过期时间
        if message.isExpired {
            errors.append(.messageExpired)
        }
        
        // 验证点对点消息和频道消息的互斥性
        if message.receiverId != nil && message.channelId != nil {
            errors.append(.invalidRecipient)
        }
        
        if message.receiverId == nil && message.channelId == nil {
            errors.append(.missingRecipient)
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
    
    private static func isContentMatchingType(_ content: MessageContent, type: RealtimeMessageType) -> Bool {
        switch (content, type) {
        case (.text, .text), (.image, .image), (.audio, .audio), (.video, .video), (.file, .file), (.system, .system), (.custom, .custom):
            return true
        default:
            return false
        }
    }
}

/// 消息验证结果
public enum MessageValidationResult: Equatable {
    case valid
    case invalid([MessageValidationError])
    
    public var isValid: Bool {
        switch self {
        case .valid: return true
        case .invalid: return false
        }
    }
    
    public var errors: [MessageValidationError] {
        switch self {
        case .valid: return []
        case .invalid(let errors): return errors
        }
    }
}

/// 消息验证错误
public enum MessageValidationError: String, CaseIterable, Error, Sendable {
    case emptySenderId = "empty_sender_id"
    case emptyContent = "empty_content"
    case contentTypeMismatch = "content_type_mismatch"
    case messageExpired = "message_expired"
    case invalidRecipient = "invalid_recipient"
    case missingRecipient = "missing_recipient"
    
    public var localizedDescription: String {
        switch self {
        case .emptySenderId: return "发送者ID不能为空"
        case .emptyContent: return "消息内容不能为空"
        case .contentTypeMismatch: return "消息内容与类型不匹配"
        case .messageExpired: return "消息已过期"
        case .invalidRecipient: return "不能同时指定接收者和频道"
        case .missingRecipient: return "必须指定接收者或频道"
        }
    }
}

// MARK: - Legacy RTM Models (向后兼容)

/// RTM消息模型
/// 需求: 1.2, 1.3
public struct RTMMessage: Codable, Identifiable {
    /// 消息唯一标识符
    public let id: String
    
    /// 消息内容
    public let text: String
    
    /// 消息类型
    public let type: RTMMessageType
    
    /// 发送者用户ID
    public let senderId: String
    
    /// 消息时间戳
    public let timestamp: Date
    
    /// 消息元数据（可选）
    public let metadata: [String: String]?
    
    /// 消息状态
    public let status: RTMMessageStatus
    
    /// 是否为离线消息
    public let isOfflineMessage: Bool
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        type: RTMMessageType = .text,
        senderId: String,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil,
        status: RTMMessageStatus = .sent,
        isOfflineMessage: Bool = false
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.senderId = senderId
        self.timestamp = timestamp
        self.metadata = metadata
        self.status = status
        self.isOfflineMessage = isOfflineMessage
    }
}

/// RTM消息类型
public enum RTMMessageType: String, CaseIterable, Codable {
    /// 文本消息
    case text = "text"
    /// 图片消息
    case image = "image"
    /// 文件消息
    case file = "file"
    /// 自定义消息
    case custom = "custom"
    /// 系统消息
    case system = "system"
    
    /// 获取消息类型的中文显示名称
    public var displayName: String {
        switch self {
        case .text:
            return "文本"
        case .image:
            return "图片"
        case .file:
            return "文件"
        case .custom:
            return "自定义"
        case .system:
            return "系统"
        }
    }
}

/// RTM消息状态
public enum RTMMessageStatus: String, CaseIterable, Codable {
    /// 发送中
    case sending = "sending"
    /// 已发送
    case sent = "sent"
    /// 已送达
    case delivered = "delivered"
    /// 发送失败
    case failed = "failed"
    
    /// 获取消息状态的中文显示名称
    public var displayName: String {
        switch self {
        case .sending:
            return "发送中"
        case .sent:
            return "已发送"
        case .delivered:
            return "已送达"
        case .failed:
            return "发送失败"
        }
    }
}

/// RTM频道模型
public struct RTMChannel: Codable, Identifiable {
    /// 频道唯一标识符
    public let id: String
    
    /// 频道名称
    public let name: String
    
    /// 频道描述
    public let description: String?
    
    /// 频道类型
    public let type: RTMChannelType
    
    /// 频道创建时间
    public let createdAt: Date
    
    /// 频道创建者ID
    public let creatorId: String
    
    /// 频道成员数量
    public let memberCount: Int
    
    /// 频道最大成员数
    public let maxMembers: Int
    
    /// 频道状态
    public let status: RTMChannelStatus
    
    /// 频道属性
    public let attributes: [String: String]
    
    public init(
        id: String,
        name: String,
        description: String? = nil,
        type: RTMChannelType = .public,
        createdAt: Date = Date(),
        creatorId: String,
        memberCount: Int = 0,
        maxMembers: Int = 1000,
        status: RTMChannelStatus = .active,
        attributes: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.createdAt = createdAt
        self.creatorId = creatorId
        self.memberCount = memberCount
        self.maxMembers = maxMembers
        self.status = status
        self.attributes = attributes
    }
}

/// RTM频道类型
public enum RTMChannelType: String, CaseIterable, Codable {
    /// 公开频道
    case `public` = "public"
    /// 私有频道
    case `private` = "private"
    /// 临时频道
    case temporary = "temporary"
    
    /// 获取频道类型的中文显示名称
    public var displayName: String {
        switch self {
        case .public:
            return "公开频道"
        case .private:
            return "私有频道"
        case .temporary:
            return "临时频道"
        }
    }
}

/// RTM频道状态
public enum RTMChannelStatus: String, CaseIterable, Codable {
    /// 活跃状态
    case active = "active"
    /// 暂停状态
    case paused = "paused"
    /// 已关闭
    case closed = "closed"
    
    /// 获取频道状态的中文显示名称
    public var displayName: String {
        switch self {
        case .active:
            return "活跃"
        case .paused:
            return "暂停"
        case .closed:
            return "已关闭"
        }
    }
}

/// RTM频道成员模型
public struct RTMChannelMember: Codable, Identifiable {
    /// 成员用户ID
    public let id: String
    
    /// 成员用户ID（为了兼容性保留）
    public let userId: String
    
    /// 成员昵称
    public let nickname: String?
    
    /// 成员角色
    public let role: RTMChannelMemberRole
    
    /// 加入时间
    public let joinedAt: Date
    
    /// 最后活跃时间
    public let lastActiveAt: Date
    
    /// 在线状态
    public let isOnline: Bool
    
    /// 成员属性
    public let attributes: [String: String]
    
    public init(
        userId: String,
        nickname: String? = nil,
        role: RTMChannelMemberRole = .member,
        joinedAt: Date = Date(),
        lastActiveAt: Date = Date(),
        isOnline: Bool = true,
        attributes: [String: String] = [:]
    ) {
        self.id = userId
        self.userId = userId
        self.nickname = nickname
        self.role = role
        self.joinedAt = joinedAt
        self.lastActiveAt = lastActiveAt
        self.isOnline = isOnline
        self.attributes = attributes
    }
}

/// RTM频道成员角色
public enum RTMChannelMemberRole: String, CaseIterable, Codable {
    /// 普通成员
    case member = "member"
    /// 管理员
    case admin = "admin"
    /// 频道所有者
    case owner = "owner"
    
    /// 获取成员角色的中文显示名称
    public var displayName: String {
        switch self {
        case .member:
            return "普通成员"
        case .admin:
            return "管理员"
        case .owner:
            return "频道所有者"
        }
    }
}

/// RTM消息发送选项
public struct RTMSendMessageOptions: Codable {
    /// 是否启用离线消息
    public let enableOfflineMessaging: Bool
    
    /// 是否启用历史消息
    public let enableHistoricalMessaging: Bool
    
    /// 消息优先级
    public let priority: RTMMessagePriority
    
    /// 消息过期时间（秒）
    public let expirationTime: TimeInterval?
    
    public init(
        enableOfflineMessaging: Bool = true,
        enableHistoricalMessaging: Bool = true,
        priority: RTMMessagePriority = .normal,
        expirationTime: TimeInterval? = nil
    ) {
        self.enableOfflineMessaging = enableOfflineMessaging
        self.enableHistoricalMessaging = enableHistoricalMessaging
        self.priority = priority
        self.expirationTime = expirationTime
    }
}

/// RTM消息优先级
public enum RTMMessagePriority: String, CaseIterable, Codable {
    /// 低优先级
    case low = "low"
    /// 普通优先级
    case normal = "normal"
    /// 高优先级
    case high = "high"
    
    /// 获取优先级的中文显示名称
    public var displayName: String {
        switch self {
        case .low:
            return "低优先级"
        case .normal:
            return "普通优先级"
        case .high:
            return "高优先级"
        }
    }
}

/// RTM频道属性操作选项
public struct RTMChannelAttributeOptions: Codable {
    /// 是否启用通知
    public let enableNotificationToChannelMembers: Bool
    
    /// 操作者用户ID
    public let operatorId: String?
    
    public init(
        enableNotificationToChannelMembers: Bool = true,
        operatorId: String? = nil
    ) {
        self.enableNotificationToChannelMembers = enableNotificationToChannelMembers
        self.operatorId = operatorId
    }
}