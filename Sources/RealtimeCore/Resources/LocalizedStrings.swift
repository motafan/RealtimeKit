import Foundation

/// Built-in localized strings for RealtimeKit
internal struct LocalizedStrings {
    
    /// All built-in localized strings organized by language
    static let builtInStrings: [SupportedLanguage: [String: String]] = [
        .english: englishStrings,
        .chineseSimplified: chineseSimplifiedStrings,
        .chineseTraditional: chineseTraditionalStrings,
        .japanese: japaneseStrings,
        .korean: koreanStrings
    ]
    
    // MARK: - English Strings
    
    private static let englishStrings: [String: String] = [
        // Connection States
        "connection.state.disconnected": "Disconnected",
        "connection.state.connecting": "Connecting",
        "connection.state.connected": "Connected",
        "connection.state.reconnecting": "Reconnecting",
        "connection.state.failed": "Connection Failed",
        
        // Network Status
        "network.status.unknown": "Unknown Network",
        "network.status.unavailable": "Network Unavailable",
        "network.status.wifi": "WiFi",
        "network.status.cellular": "Cellular",
        "network.status.limited": "Limited Network",
        
        // User Roles
        "user.role.broadcaster": "Broadcaster",
        "user.role.audience": "Audience",
        "user.role.cohost": "Co-host",
        "user.role.moderator": "Moderator",
        
        // Audio Controls
        "audio.microphone.muted": "Microphone Muted",
        "audio.microphone.unmuted": "Microphone Unmuted",
        "audio.stream.stopped": "Audio Stream Stopped",
        "audio.stream.active": "Audio Stream Active",
        "audio.volume.mixing": "Mixing Volume: %d%%",
        "audio.volume.playback": "Playback Volume: %d%%",
        "audio.volume.recording": "Recording Volume: %d%%",
        
        // Volume Indicator
        "volume.speaking.started": "%@ started speaking",
        "volume.speaking.stopped": "%@ stopped speaking",
        "volume.dominant.speaker": "Main speaker: %@",
        "volume.no.speaker": "No one is speaking",
        
        // Stream Push
        "stream.push.starting": "Starting stream push...",
        "stream.push.active": "Stream push active",
        "stream.push.stopped": "Stream push stopped",
        "stream.push.failed": "Stream push failed",
        
        // Media Relay
        "media.relay.starting": "Starting media relay...",
        "media.relay.active": "Media relay active to %d channels",
        "media.relay.stopped": "Media relay stopped",
        "media.relay.failed": "Media relay failed",
        
        // Token Management
        "token.expiring.soon": "Token expires in %d seconds",
        "token.expired": "Token has expired",
        "token.renewed": "Token renewed successfully",
        "token.renewal.failed": "Token renewal failed",
        
        // Error Messages - Network
        "error.network.unavailable": "Network unavailable",
        "error.connection.timeout": "Connection timeout",
        "error.connection.failed": "Connection failed",
        
        // Error Messages - Permission
        "error.permission.denied": "Permission denied",
        "error.insufficient.permissions": "Insufficient permissions for role: %@",
        "error.invalid.role.transition": "Cannot switch from %@ to %@",
        "error.microphone.permission.denied": "Microphone permission denied",
        
        // Error Messages - Configuration
        "error.invalid.configuration": "Invalid configuration",
        "error.provider.unavailable": "Service provider unavailable: %@",
        "error.invalid.token": "Invalid token",
        "error.token.expired": "Token has expired",
        "error.token.renewal.failed": "Token renewal failed",
        
        // Error Messages - Session
        "error.no.active.session": "No active session",
        "error.session.already.active": "Session already active",
        "error.user.already.in.room": "User already in room",
        "error.room.not.found": "Room not found: %@",
        "error.user.not.found": "User not found: %@",
        
        // Error Messages - Audio
        "error.audio.device.unavailable": "Audio device unavailable",
        "error.audio.stream.failed": "Audio stream failed",
        "error.volume.detection.failed": "Volume detection failed",
        
        // Error Messages - Stream Push
        "error.stream.push.not.supported": "Stream push not supported",
        "error.stream.push.configuration.invalid": "Stream push configuration invalid",
        "error.stream.push.failed": "Stream push failed",
        "error.stream.push.already.active": "Stream push already active",
        
        // Error Messages - Media Relay
        "error.media.relay.not.supported": "Media relay not supported",
        "error.media.relay.configuration.invalid": "Media relay configuration invalid",
        "error.media.relay.failed": "Media relay failed",
        "error.media.relay.channel.limit.exceeded": "Media relay channel limit exceeded",
        
        // Error Messages - Message Processing
        "error.processor.already.registered": "Message processor already registered for type: %@",
        "error.processor.not.found": "Message processor not found for type: %@",
        "error.message.processing.failed": "Message processing failed",
        "error.invalid.message.format": "Invalid message format",
        
        // Error Messages - Localization
        "error.localization.key.not.found": "Localization key not found: %@",
        "error.language.pack.load.failed": "Language pack load failed",
        "error.unsupported.language": "Unsupported language: %@",
        
        // Error Messages - Generic
        "error.unknown": "Unknown error",
        "error.operation.cancelled": "Operation cancelled",
        "error.operation.timeout": "Operation timeout",
        "error.internal": "Internal error (code: %d)",
        
        // General UI
        "button.ok": "OK",
        "button.cancel": "Cancel",
        "button.retry": "Retry",
        "button.close": "Close",
        "button.settings": "Settings",
        "button.join": "Join",
        "button.leave": "Leave",
        
        // Settings
        "settings.language": "Language",
        "settings.audio": "Audio Settings",
        "settings.video": "Video Settings",
        "settings.advanced": "Advanced Settings",
        
        // Room and User Management
        "room.user.count": "Users: %d",
        "connection.duration": "Connected for %d seconds",
        
        // Accessibility
        "accessibility.button.ok": "OK Button",
        "accessibility.hint.tap.to.confirm": "Tap to confirm your selection",
        
        // Test keys (English only for fallback testing)
        "test.english.only": "English Only Text"
    ]
    
    // MARK: - Chinese Simplified Strings
    
    private static let chineseSimplifiedStrings: [String: String] = [
        // Connection States
        "connection.state.disconnected": "已断开连接",
        "connection.state.connecting": "连接中",
        "connection.state.connected": "已连接",
        "connection.state.reconnecting": "重新连接中",
        "connection.state.failed": "连接失败",
        
        // Network Status
        "network.status.unknown": "未知网络",
        "network.status.unavailable": "网络不可用",
        "network.status.wifi": "WiFi",
        "network.status.cellular": "蜂窝网络",
        "network.status.limited": "受限网络",
        
        // User Roles
        "user.role.broadcaster": "主播",
        "user.role.audience": "观众",
        "user.role.cohost": "连麦嘉宾",
        "user.role.moderator": "主持人",
        
        // Audio Controls
        "audio.microphone.muted": "麦克风已静音",
        "audio.microphone.unmuted": "麦克风已开启",
        "audio.stream.stopped": "音频流已停止",
        "audio.stream.active": "音频流已激活",
        "audio.volume.mixing": "混音音量：%d%%",
        "audio.volume.playback": "播放音量：%d%%",
        "audio.volume.recording": "录制音量：%d%%",
        
        // Volume Indicator
        "volume.speaking.started": "%@ 开始说话",
        "volume.speaking.stopped": "%@ 停止说话",
        "volume.dominant.speaker": "主讲人：%@",
        "volume.no.speaker": "没有人在说话",
        
        // Stream Push
        "stream.push.starting": "正在启动转推流...",
        "stream.push.active": "转推流已激活",
        "stream.push.stopped": "转推流已停止",
        "stream.push.failed": "转推流失败",
        
        // Media Relay
        "media.relay.starting": "正在启动媒体中继...",
        "media.relay.active": "媒体中继已激活到 %d 个频道",
        "media.relay.stopped": "媒体中继已停止",
        "media.relay.failed": "媒体中继失败",
        
        // Token Management
        "token.expiring.soon": "令牌将在 %d 秒后过期",
        "token.expired": "令牌已过期",
        "token.renewed": "令牌续期成功",
        "token.renewal.failed": "令牌续期失败",
        
        // Error Messages - Network
        "error.network.unavailable": "网络不可用",
        "error.connection.timeout": "连接超时",
        "error.connection.failed": "连接失败",
        
        // Error Messages - Permission
        "error.permission.denied": "权限被拒绝",
        "error.insufficient.permissions": "角色权限不足：%@",
        "error.invalid.role.transition": "无法从 %@ 切换到 %@",
        "error.microphone.permission.denied": "麦克风权限被拒绝",
        
        // Error Messages - Configuration
        "error.invalid.configuration": "配置无效",
        "error.provider.unavailable": "服务提供商不可用：%@",
        "error.invalid.token": "令牌无效",
        "error.token.expired": "令牌已过期",
        "error.token.renewal.failed": "令牌续期失败",
        
        // Error Messages - Session
        "error.no.active.session": "没有活动会话",
        "error.session.already.active": "会话已激活",
        "error.user.already.in.room": "用户已在房间中",
        "error.room.not.found": "未找到房间：%@",
        "error.user.not.found": "未找到用户：%@",
        
        // Error Messages - Audio
        "error.audio.device.unavailable": "音频设备不可用",
        "error.audio.stream.failed": "音频流失败",
        "error.volume.detection.failed": "音量检测失败",
        
        // Error Messages - Stream Push
        "error.stream.push.not.supported": "不支持转推流",
        "error.stream.push.configuration.invalid": "转推流配置无效",
        "error.stream.push.failed": "转推流失败",
        "error.stream.push.already.active": "转推流已激活",
        
        // Error Messages - Media Relay
        "error.media.relay.not.supported": "不支持媒体中继",
        "error.media.relay.configuration.invalid": "媒体中继配置无效",
        "error.media.relay.failed": "媒体中继失败",
        "error.media.relay.channel.limit.exceeded": "媒体中继频道限制已超出",
        
        // Error Messages - Message Processing
        "error.processor.already.registered": "消息处理器已注册类型：%@",
        "error.processor.not.found": "未找到消息处理器类型：%@",
        "error.message.processing.failed": "消息处理失败",
        "error.invalid.message.format": "消息格式无效",
        
        // Error Messages - Localization
        "error.localization.key.not.found": "未找到本地化键：%@",
        "error.language.pack.load.failed": "语言包加载失败",
        "error.unsupported.language": "不支持的语言：%@",
        
        // Error Messages - Generic
        "error.unknown": "未知错误",
        "error.operation.cancelled": "操作已取消",
        "error.operation.timeout": "操作超时",
        "error.internal": "内部错误（代码：%d）",
        
        // General UI
        "button.ok": "确定",
        "button.cancel": "取消",
        "button.retry": "重试",
        "button.close": "关闭",
        "button.settings": "设置",
        "button.join": "加入",
        "button.leave": "离开",
        
        // Settings
        "settings.language": "语言",
        "settings.audio": "音频设置",
        "settings.video": "视频设置",
        "settings.advanced": "高级设置",
        
        // Room and User Management
        "room.user.count": "用户数：%d",
        "connection.duration": "已连接 %d 秒",
        
        // Accessibility
        "accessibility.button.ok": "确定按钮",
        "accessibility.hint.tap.to.confirm": "点击确认您的选择"
    ]
    
    // MARK: - Chinese Traditional Strings
    
    private static let chineseTraditionalStrings: [String: String] = [
        // Connection States
        "connection.state.disconnected": "已斷開連接",
        "connection.state.connecting": "連接中",
        "connection.state.connected": "已連接",
        "connection.state.reconnecting": "重新連接中",
        "connection.state.failed": "連接失敗",
        
        // Network Status
        "network.status.unknown": "未知網絡",
        "network.status.unavailable": "網絡不可用",
        "network.status.wifi": "WiFi",
        "network.status.cellular": "蜂窩網絡",
        "network.status.limited": "受限網絡",
        
        // User Roles
        "user.role.broadcaster": "主播",
        "user.role.audience": "觀眾",
        "user.role.cohost": "連麥嘉賓",
        "user.role.moderator": "主持人",
        
        // Audio Controls
        "audio.microphone.muted": "麥克風已靜音",
        "audio.microphone.unmuted": "麥克風已開啟",
        "audio.stream.stopped": "音頻流已停止",
        "audio.stream.active": "音頻流已激活",
        "audio.volume.mixing": "混音音量：%d%%",
        "audio.volume.playback": "播放音量：%d%%",
        "audio.volume.recording": "錄製音量：%d%%",
        
        // Volume Indicator
        "volume.speaking.started": "%@ 開始說話",
        "volume.speaking.stopped": "%@ 停止說話",
        "volume.dominant.speaker": "主講人：%@",
        "volume.no.speaker": "沒有人在說話",
        
        // Stream Push
        "stream.push.starting": "正在啟動轉推流...",
        "stream.push.active": "轉推流已激活",
        "stream.push.stopped": "轉推流已停止",
        "stream.push.failed": "轉推流失敗",
        
        // Media Relay
        "media.relay.starting": "正在啟動媒體中繼...",
        "media.relay.active": "媒體中繼已激活到 %d 個頻道",
        "media.relay.stopped": "媒體中繼已停止",
        "media.relay.failed": "媒體中繼失敗",
        
        // Token Management
        "token.expiring.soon": "令牌將在 %d 秒後過期",
        "token.expired": "令牌已過期",
        "token.renewed": "令牌續期成功",
        "token.renewal.failed": "令牌續期失敗",
        
        // Error Messages - Network
        "error.network.unavailable": "網絡不可用",
        "error.connection.timeout": "連接超時",
        "error.connection.failed": "連接失敗",
        
        // Error Messages - Permission
        "error.permission.denied": "權限被拒絕",
        "error.insufficient.permissions": "角色權限不足：%@",
        "error.invalid.role.transition": "無法從 %@ 切換到 %@",
        "error.microphone.permission.denied": "麥克風權限被拒絕",
        
        // Error Messages - Configuration
        "error.invalid.configuration": "配置無效",
        "error.provider.unavailable": "服務提供商不可用：%@",
        "error.invalid.token": "令牌無效",
        "error.token.expired": "令牌已過期",
        "error.token.renewal.failed": "令牌續期失敗",
        
        // Error Messages - Session
        "error.no.active.session": "沒有活動會話",
        "error.session.already.active": "會話已激活",
        "error.user.already.in.room": "用戶已在房間中",
        "error.room.not.found": "未找到房間：%@",
        "error.user.not.found": "未找到用戶：%@",
        
        // Error Messages - Audio
        "error.audio.device.unavailable": "音頻設備不可用",
        "error.audio.stream.failed": "音頻流失敗",
        "error.volume.detection.failed": "音量檢測失敗",
        
        // Error Messages - Stream Push
        "error.stream.push.not.supported": "不支持轉推流",
        "error.stream.push.configuration.invalid": "轉推流配置無效",
        "error.stream.push.failed": "轉推流失敗",
        "error.stream.push.already.active": "轉推流已激活",
        
        // Error Messages - Media Relay
        "error.media.relay.not.supported": "不支持媒體中繼",
        "error.media.relay.configuration.invalid": "媒體中繼配置無效",
        "error.media.relay.failed": "媒體中繼失敗",
        "error.media.relay.channel.limit.exceeded": "媒體中繼頻道限制已超出",
        
        // Error Messages - Message Processing
        "error.processor.already.registered": "消息處理器已註冊類型：%@",
        "error.processor.not.found": "未找到消息處理器類型：%@",
        "error.message.processing.failed": "消息處理失敗",
        "error.invalid.message.format": "消息格式無效",
        
        // Error Messages - Localization
        "error.localization.key.not.found": "未找到本地化鍵：%@",
        "error.language.pack.load.failed": "語言包加載失敗",
        "error.unsupported.language": "不支持的語言：%@",
        
        // Error Messages - Generic
        "error.unknown": "未知錯誤",
        "error.operation.cancelled": "操作已取消",
        "error.operation.timeout": "操作超時",
        "error.internal": "內部錯誤（代碼：%d）",
        
        // General UI
        "button.ok": "確定",
        "button.cancel": "取消",
        "button.retry": "重試",
        "button.close": "關閉",
        "button.settings": "設置",
        "button.join": "加入",
        "button.leave": "離開",
        
        // Settings
        "settings.language": "語言",
        "settings.audio": "音頻設置",
        "settings.video": "視頻設置",
        "settings.advanced": "高級設置"
    ]
    
    // MARK: - Japanese Strings
    
    private static let japaneseStrings: [String: String] = [
        // Connection States
        "connection.state.disconnected": "切断されました",
        "connection.state.connecting": "接続中",
        "connection.state.connected": "接続済み",
        "connection.state.reconnecting": "再接続中",
        "connection.state.failed": "接続に失敗しました",
        
        // Network Status
        "network.status.unknown": "不明なネットワーク",
        "network.status.unavailable": "ネットワーク利用不可",
        "network.status.wifi": "WiFi",
        "network.status.cellular": "セルラー",
        "network.status.limited": "制限されたネットワーク",
        
        // User Roles
        "user.role.broadcaster": "配信者",
        "user.role.audience": "視聴者",
        "user.role.cohost": "共同ホスト",
        "user.role.moderator": "モデレーター",
        
        // Audio Controls
        "audio.microphone.muted": "マイクがミュートされました",
        "audio.microphone.unmuted": "マイクがオンになりました",
        "audio.stream.stopped": "オーディオストリームが停止しました",
        "audio.stream.active": "オーディオストリームがアクティブです",
        "audio.volume.mixing": "ミキシング音量：%d%%",
        "audio.volume.playback": "再生音量：%d%%",
        "audio.volume.recording": "録音音量：%d%%",
        
        // Volume Indicator
        "volume.speaking.started": "%@ が話し始めました",
        "volume.speaking.stopped": "%@ が話すのをやめました",
        "volume.dominant.speaker": "メインスピーカー：%@",
        "volume.no.speaker": "誰も話していません",
        
        // Stream Push
        "stream.push.starting": "ストリームプッシュを開始しています...",
        "stream.push.active": "ストリームプッシュがアクティブです",
        "stream.push.stopped": "ストリームプッシュが停止しました",
        "stream.push.failed": "ストリームプッシュに失敗しました",
        
        // Media Relay
        "media.relay.starting": "メディアリレーを開始しています...",
        "media.relay.active": "メディアリレーが %d チャンネルでアクティブです",
        "media.relay.stopped": "メディアリレーが停止しました",
        "media.relay.failed": "メディアリレーに失敗しました",
        
        // Token Management
        "token.expiring.soon": "トークンは %d 秒後に期限切れになります",
        "token.expired": "トークンの有効期限が切れました",
        "token.renewed": "トークンの更新に成功しました",
        "token.renewal.failed": "トークンの更新に失敗しました",
        
        // Error Messages - Network
        "error.network.unavailable": "ネットワークが利用できません",
        "error.connection.timeout": "接続がタイムアウトしました",
        "error.connection.failed": "接続に失敗しました",
        
        // Error Messages - Permission
        "error.permission.denied": "権限が拒否されました",
        "error.insufficient.permissions": "ロールの権限が不足しています：%@",
        "error.invalid.role.transition": "%@ から %@ に切り替えることはできません",
        "error.microphone.permission.denied": "マイクの権限が拒否されました",
        
        // Error Messages - Configuration
        "error.invalid.configuration": "無効な設定です",
        "error.provider.unavailable": "サービスプロバイダーが利用できません：%@",
        "error.invalid.token": "無効なトークンです",
        "error.token.expired": "トークンの有効期限が切れました",
        "error.token.renewal.failed": "トークンの更新に失敗しました",
        
        // Error Messages - Session
        "error.no.active.session": "アクティブなセッションがありません",
        "error.session.already.active": "セッションは既にアクティブです",
        "error.user.already.in.room": "ユーザーは既にルームにいます",
        "error.room.not.found": "ルームが見つかりません：%@",
        "error.user.not.found": "ユーザーが見つかりません：%@",
        
        // Error Messages - Audio
        "error.audio.device.unavailable": "オーディオデバイスが利用できません",
        "error.audio.stream.failed": "オーディオストリームに失敗しました",
        "error.volume.detection.failed": "音量検出に失敗しました",
        
        // Error Messages - Stream Push
        "error.stream.push.not.supported": "ストリームプッシュはサポートされていません",
        "error.stream.push.configuration.invalid": "ストリームプッシュの設定が無効です",
        "error.stream.push.failed": "ストリームプッシュに失敗しました",
        "error.stream.push.already.active": "ストリームプッシュは既にアクティブです",
        
        // Error Messages - Media Relay
        "error.media.relay.not.supported": "メディアリレーはサポートされていません",
        "error.media.relay.configuration.invalid": "メディアリレーの設定が無効です",
        "error.media.relay.failed": "メディアリレーに失敗しました",
        "error.media.relay.channel.limit.exceeded": "メディアリレーのチャンネル制限を超えました",
        
        // Error Messages - Message Processing
        "error.processor.already.registered": "メッセージプロセッサーは既に登録されています：%@",
        "error.processor.not.found": "メッセージプロセッサーが見つかりません：%@",
        "error.message.processing.failed": "メッセージ処理に失敗しました",
        "error.invalid.message.format": "無効なメッセージ形式です",
        
        // Error Messages - Localization
        "error.localization.key.not.found": "ローカライゼーションキーが見つかりません：%@",
        "error.language.pack.load.failed": "言語パックの読み込みに失敗しました",
        "error.unsupported.language": "サポートされていない言語です：%@",
        
        // Error Messages - Generic
        "error.unknown": "不明なエラー",
        "error.operation.cancelled": "操作がキャンセルされました",
        "error.operation.timeout": "操作がタイムアウトしました",
        "error.internal": "内部エラー（コード：%d）",
        
        // General UI
        "button.ok": "OK",
        "button.cancel": "キャンセル",
        "button.retry": "再試行",
        "button.close": "閉じる",
        "button.settings": "設定",
        "button.join": "参加",
        "button.leave": "退出",
        
        // Settings
        "settings.language": "言語",
        "settings.audio": "オーディオ設定",
        "settings.video": "ビデオ設定",
        "settings.advanced": "詳細設定"
    ]
    
    // MARK: - Korean Strings
    
    private static let koreanStrings: [String: String] = [
        // Connection States
        "connection.state.disconnected": "연결 해제됨",
        "connection.state.connecting": "연결 중",
        "connection.state.connected": "연결됨",
        "connection.state.reconnecting": "재연결 중",
        "connection.state.failed": "연결 실패",
        
        // Network Status
        "network.status.unknown": "알 수 없는 네트워크",
        "network.status.unavailable": "네트워크 사용 불가",
        "network.status.wifi": "WiFi",
        "network.status.cellular": "셀룰러",
        "network.status.limited": "제한된 네트워크",
        
        // User Roles
        "user.role.broadcaster": "방송자",
        "user.role.audience": "시청자",
        "user.role.cohost": "공동 호스트",
        "user.role.moderator": "진행자",
        
        // Audio Controls
        "audio.microphone.muted": "마이크가 음소거되었습니다",
        "audio.microphone.unmuted": "마이크가 켜졌습니다",
        "audio.stream.stopped": "오디오 스트림이 중지되었습니다",
        "audio.stream.active": "오디오 스트림이 활성화되었습니다",
        "audio.volume.mixing": "믹싱 볼륨: %d%%",
        "audio.volume.playback": "재생 볼륨: %d%%",
        "audio.volume.recording": "녹음 볼륨: %d%%",
        
        // Volume Indicator
        "volume.speaking.started": "%@ 님이 말하기 시작했습니다",
        "volume.speaking.stopped": "%@ 님이 말하기를 중단했습니다",
        "volume.dominant.speaker": "주 발표자: %@",
        "volume.no.speaker": "아무도 말하고 있지 않습니다",
        
        // Stream Push
        "stream.push.starting": "스트림 푸시를 시작하고 있습니다...",
        "stream.push.active": "스트림 푸시가 활성화되었습니다",
        "stream.push.stopped": "스트림 푸시가 중지되었습니다",
        "stream.push.failed": "스트림 푸시에 실패했습니다",
        
        // Media Relay
        "media.relay.starting": "미디어 릴레이를 시작하고 있습니다...",
        "media.relay.active": "미디어 릴레이가 %d개 채널에서 활성화되었습니다",
        "media.relay.stopped": "미디어 릴레이가 중지되었습니다",
        "media.relay.failed": "미디어 릴레이에 실패했습니다",
        
        // Token Management
        "token.expiring.soon": "토큰이 %d초 후에 만료됩니다",
        "token.expired": "토큰이 만료되었습니다",
        "token.renewed": "토큰 갱신에 성공했습니다",
        "token.renewal.failed": "토큰 갱신에 실패했습니다",
        
        // Error Messages - Network
        "error.network.unavailable": "네트워크를 사용할 수 없습니다",
        "error.connection.timeout": "연결 시간이 초과되었습니다",
        "error.connection.failed": "연결에 실패했습니다",
        
        // Error Messages - Permission
        "error.permission.denied": "권한이 거부되었습니다",
        "error.insufficient.permissions": "역할에 대한 권한이 부족합니다: %@",
        "error.invalid.role.transition": "%@에서 %@로 전환할 수 없습니다",
        "error.microphone.permission.denied": "마이크 권한이 거부되었습니다",
        
        // Error Messages - Configuration
        "error.invalid.configuration": "잘못된 구성입니다",
        "error.provider.unavailable": "서비스 제공자를 사용할 수 없습니다: %@",
        "error.invalid.token": "잘못된 토큰입니다",
        "error.token.expired": "토큰이 만료되었습니다",
        "error.token.renewal.failed": "토큰 갱신에 실패했습니다",
        
        // Error Messages - Session
        "error.no.active.session": "활성 세션이 없습니다",
        "error.session.already.active": "세션이 이미 활성화되어 있습니다",
        "error.user.already.in.room": "사용자가 이미 방에 있습니다",
        "error.room.not.found": "방을 찾을 수 없습니다: %@",
        "error.user.not.found": "사용자를 찾을 수 없습니다: %@",
        
        // Error Messages - Audio
        "error.audio.device.unavailable": "오디오 장치를 사용할 수 없습니다",
        "error.audio.stream.failed": "오디오 스트림에 실패했습니다",
        "error.volume.detection.failed": "볼륨 감지에 실패했습니다",
        
        // Error Messages - Stream Push
        "error.stream.push.not.supported": "스트림 푸시가 지원되지 않습니다",
        "error.stream.push.configuration.invalid": "스트림 푸시 구성이 잘못되었습니다",
        "error.stream.push.failed": "스트림 푸시에 실패했습니다",
        "error.stream.push.already.active": "스트림 푸시가 이미 활성화되어 있습니다",
        
        // Error Messages - Media Relay
        "error.media.relay.not.supported": "미디어 릴레이가 지원되지 않습니다",
        "error.media.relay.configuration.invalid": "미디어 릴레이 구성이 잘못되었습니다",
        "error.media.relay.failed": "미디어 릴레이에 실패했습니다",
        "error.media.relay.channel.limit.exceeded": "미디어 릴레이 채널 제한을 초과했습니다",
        
        // Error Messages - Message Processing
        "error.processor.already.registered": "메시지 프로세서가 이미 등록되었습니다: %@",
        "error.processor.not.found": "메시지 프로세서를 찾을 수 없습니다: %@",
        "error.message.processing.failed": "메시지 처리에 실패했습니다",
        "error.invalid.message.format": "잘못된 메시지 형식입니다",
        
        // Error Messages - Localization
        "error.localization.key.not.found": "로컬라이제이션 키를 찾을 수 없습니다: %@",
        "error.language.pack.load.failed": "언어 팩 로드에 실패했습니다",
        "error.unsupported.language": "지원되지 않는 언어입니다: %@",
        
        // Error Messages - Generic
        "error.unknown": "알 수 없는 오류",
        "error.operation.cancelled": "작업이 취소되었습니다",
        "error.operation.timeout": "작업 시간이 초과되었습니다",
        "error.internal": "내부 오류 (코드: %d)",
        
        // General UI
        "button.ok": "확인",
        "button.cancel": "취소",
        "button.retry": "다시 시도",
        "button.close": "닫기",
        "button.settings": "설정",
        "button.join": "참가",
        "button.leave": "나가기",
        
        // Settings
        "settings.language": "언어",
        "settings.audio": "오디오 설정",
        "settings.video": "비디오 설정",
        "settings.advanced": "고급 설정",
        
        // Room and User Management
        "room.user.count": "사용자: %d명",
        "connection.duration": "%d초 동안 연결됨",
        
        // Accessibility
        "accessibility.button.ok": "확인 버튼",
        "accessibility.hint.tap.to.confirm": "선택을 확인하려면 탭하세요"
    ]
}