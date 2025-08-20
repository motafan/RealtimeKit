// RealtimeAgora.swift
// Agora provider implementation for RealtimeKit

import Foundation
import RealtimeCore

/// RealtimeAgora version information
public struct RealtimeAgoraVersion {
    public static let current = "1.0.0"
    public static let build = "1"
}

// MARK: - Agora SDK Integration Types
// These would normally come from the Agora SDK, but we define them here for compilation

/// Agora RTC Engine delegate protocol (simulated)
internal protocol AgoraRtcEngineDelegate: AnyObject {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int)
    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats)
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int)
    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String)
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode)
}

/// Agora RTM delegate protocol (simulated)
internal protocol AgoraRtmDelegate: AnyObject {
    func rtmKit(_ kit: AgoraRtmKit, connectionStateChanged state: AgoraRtmConnectionState, reason: AgoraRtmConnectionChangeReason)
    func rtmKit(_ kit: AgoraRtmKit, messageReceived message: AgoraRtmMessage, fromPeer peerId: String)
    func rtmKit(_ kit: AgoraRtmKit, channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember)
    func rtmKit(_ kit: AgoraRtmKit, tokenPrivilegeWillExpire token: String)
}

// MARK: - Simulated Agora SDK Classes
// In real implementation, these would be imported from AgoraRtcKit and AgoraRtmKit

internal class AgoraRtcEngineKit: @unchecked Sendable {
    weak var delegate: AgoraRtcEngineDelegate?
    private var isInitialized = false
    private var currentChannel: String?
    private var currentUid: UInt = 0
    private var volumeIndicatorEnabled = false
    private var volumeTimer: Timer?
    
    static func sharedEngine(withAppId appId: String, delegate: AgoraRtcEngineDelegate?) -> AgoraRtcEngineKit {
        let engine = AgoraRtcEngineKit()
        engine.delegate = delegate
        engine.isInitialized = true
        return engine
    }
    
    func joinChannel(byToken token: String?, channelId: String, info: String?, uid: UInt) -> Int32 {
        currentChannel = channelId
        currentUid = uid
        
        // Simulate async join
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            self.delegate?.rtcEngine(self, didJoinChannel: channelId, withUid: uid, elapsed: 100)
        }
        return 0
    }
    
    func leaveChannel() -> Int32 {
        let stats = AgoraChannelStats()
        delegate?.rtcEngine(self, didLeaveChannelWith: stats)
        currentChannel = nil
        currentUid = 0
        return 0
    }
    
    func muteLocalAudioStream(_ mute: Bool) -> Int32 { return 0 }
    func adjustRecordingSignalVolume(_ volume: Int32) -> Int32 { return 0 }
    func adjustPlaybackSignalVolume(_ volume: Int32) -> Int32 { return 0 }
    func adjustAudioMixingVolume(_ volume: Int32) -> Int32 { return 0 }
    func setClientRole(_ role: AgoraClientRole) -> Int32 { return 0 }
    func renewToken(_ token: String) -> Int32 { return 0 }
    
    func enableAudioVolumeIndication(_ interval: Int, smooth: Int, reportVad: Bool) -> Int32 {
        volumeIndicatorEnabled = interval > 0
        
        if volumeIndicatorEnabled {
            startVolumeIndicatorTimer(interval: interval)
        } else {
            stopVolumeIndicatorTimer()
        }
        return 0
    }
    
    private func startVolumeIndicatorTimer(interval: Int) {
        stopVolumeIndicatorTimer()
        
        volumeTimer = Timer.scheduledTimer(withTimeInterval: Double(interval) / 1000.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Simulate volume data
            let speakers = [
                AgoraRtcAudioVolumeInfo(uid: self.currentUid, volume: UInt(Int.random(in: 0...255))),
                AgoraRtcAudioVolumeInfo(uid: 12345, volume: UInt(Int.random(in: 0...255)))
            ]
            self.delegate?.rtcEngine(self, reportAudioVolumeIndicationOfSpeakers: speakers, totalVolume: 150)
        }
    }
    
    private func stopVolumeIndicatorTimer() {
        volumeTimer?.invalidate()
        volumeTimer = nil
    }
    
    func startRtmpStream(withTranscoding url: String, transcoding: AgoraLiveTranscoding?) -> Int32 { return 0 }
    func stopRtmpStream(_ url: String) -> Int32 { return 0 }
    func updateRtmpTranscoding(_ transcoding: AgoraLiveTranscoding) -> Int32 { return 0 }
    
    func startChannelMediaRelay(_ config: AgoraChannelMediaRelayConfiguration) -> Int32 { return 0 }
    func stopChannelMediaRelay() -> Int32 { return 0 }
    func updateChannelMediaRelay(_ config: AgoraChannelMediaRelayConfiguration) -> Int32 { return 0 }
    func pauseAllChannelMediaRelay() -> Int32 { return 0 }
    func resumeAllChannelMediaRelay() -> Int32 { return 0 }
}

internal class AgoraRtmKit: @unchecked Sendable {
    weak var agoraRtmDelegate: AgoraRtmDelegate?
    private var isLoggedIn = false
    private var subscribedChannels: Set<String> = []
    
    init(appId: String, delegate: AgoraRtmDelegate?) {
        self.agoraRtmDelegate = delegate
    }
    
    func login(byToken token: String?, user userId: String, completion: ((AgoraRtmLoginErrorCode) -> Void)?) {
        isLoggedIn = true
        completion?(.ok)
    }
    
    func logout(completion: ((AgoraRtmLogoutErrorCode) -> Void)?) {
        isLoggedIn = false
        completion?(.ok)
    }
    
    func send(_ message: AgoraRtmMessage, toPeer peerId: String, completion: ((AgoraRtmSendPeerMessageErrorCode) -> Void)?) {
        completion?(.ok)
    }
    
    func createChannel(withId channelId: String, delegate: AgoraRtmChannelDelegate?) -> AgoraRtmChannel? {
        return AgoraRtmChannel(channelId: channelId, delegate: delegate)
    }
    
    func renewToken(_ token: String, completion: ((AgoraRtmRenewTokenErrorCode) -> Void)?) {
        completion?(.ok)
    }
}

internal class AgoraRtmChannel: @unchecked Sendable {
    let channelId: String
    weak var channelDelegate: AgoraRtmChannelDelegate?
    private var isJoined = false
    
    init(channelId: String, delegate: AgoraRtmChannelDelegate?) {
        self.channelId = channelId
        self.channelDelegate = delegate
    }
    
    func join(completion: ((AgoraRtmJoinChannelErrorCode) -> Void)?) {
        isJoined = true
        completion?(.channelErrorOk)
    }
    
    func leave(completion: ((AgoraRtmLeaveChannelErrorCode) -> Void)?) {
        isJoined = false
        completion?(.channelErrorOk)
    }
    
    func send(_ message: AgoraRtmMessage, completion: ((AgoraRtmSendChannelMessageErrorCode) -> Void)?) {
        completion?(.channelMessageErrorOk)
    }
}

// MARK: - Agora SDK Supporting Types

internal protocol AgoraRtmChannelDelegate: AnyObject {
    func channel(_ channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember)
}

internal class AgoraRtmMessage {
    let text: String
    let type: AgoraRtmMessageType
    
    init(text: String, type: AgoraRtmMessageType = .text) {
        self.text = text
        self.type = type
    }
}

internal class AgoraRtmMember {
    let userId: String
    let channelId: String
    
    init(userId: String, channelId: String) {
        self.userId = userId
        self.channelId = channelId
    }
}

internal struct AgoraChannelStats {
    let duration: Int = 0
    let txBytes: Int = 0
    let rxBytes: Int = 0
}

internal struct AgoraRtcAudioVolumeInfo {
    let uid: UInt
    let volume: UInt
    
    init(uid: UInt, volume: UInt) {
        self.uid = uid
        self.volume = volume
    }
}

internal class AgoraLiveTranscoding {
    var width: Int = 640
    var height: Int = 480
    var videoBitrate: Int = 400
    var videoFramerate: Int = 15
    var transcodingUsers: [AgoraLiveTranscodingUser] = []
}

internal class AgoraLiveTranscodingUser {
    var uid: UInt = 0
    var x: Int = 0
    var y: Int = 0
    var width: Int = 160
    var height: Int = 120
}

internal class AgoraChannelMediaRelayConfiguration {
    var sourceInfo: AgoraChannelMediaRelayInfo?
    var destinationInfos: [String: AgoraChannelMediaRelayInfo] = [:]
    
    func setSourceInfo(_ sourceInfo: AgoraChannelMediaRelayInfo) {
        self.sourceInfo = sourceInfo
    }
    
    func setDestinationInfo(_ destinationInfo: AgoraChannelMediaRelayInfo, forChannelName channelName: String) {
        destinationInfos[channelName] = destinationInfo
    }
}

internal class AgoraChannelMediaRelayInfo {
    var channelName: String?
    var token: String?
    var uid: UInt = 0
    
    init(token: String?) {
        self.token = token
    }
}

// MARK: - Agora SDK Enums

internal enum AgoraClientRole: Int {
    case broadcaster = 1
    case audience = 2
}

internal enum AgoraErrorCode: Int {
    case noError = 0
    case failed = 1
    case invalidArgument = 2
    case notReady = 3
    case notSupported = 4
    case refused = 5
    case bufferTooSmall = 6
    case notInitialized = 7
    case invalidState = 8
    case noPermission = 9
    case timedOut = 10
    case canceled = 11
    case tooOften = 12
    case bindSocketFailed = 13
    case netDown = 14
    case joinChannelRejected = 17
    case leaveChannelRejected = 18
    case alreadyInUse = 19
    case aborted = 20
    case initNetEngine = 21
    case resourceLimited = 22
    case invalidAppId = 101
    case invalidChannelName = 102
    case noServerResources = 103
    case tokenExpired = 109
    case invalidToken = 110
    case connectionInterrupted = 111
    case connectionLost = 112
}

internal enum AgoraRtmConnectionState: Int {
    case disconnected = 1
    case connecting = 2
    case connected = 3
    case reconnecting = 4
    case aborted = 5
}

internal enum AgoraRtmConnectionChangeReason: Int {
    case login = 1
    case loginSuccess = 2
    case loginFailure = 3
    case loginTimeout = 4
    case interrupted = 5
    case logout = 6
    case bannedByServer = 7
    case remoteLogin = 8
    case tokenExpired = 9
}

internal enum AgoraRtmMessageType: Int {
    case undefined = 0
    case text = 1
    case raw = 2
}

internal enum AgoraRtmLoginErrorCode: Int {
    case ok = 0
    case unknown = 1
    case rejected = 2
    case invalidArgument = 3
    case invalidAppId = 4
    case invalidToken = 5
    case tokenExpired = 6
    case notAuthorized = 7
    case alreadyLogin = 8
    case timeout = 9
    case tooOften = 10
}

internal enum AgoraRtmLogoutErrorCode: Int {
    case ok = 0
    case rejected = 1
    case notInitialized = 2
    case notLoggedIn = 3
}

internal enum AgoraRtmSendPeerMessageErrorCode: Int {
    case ok = 0
    case failure = 1
    case timeout = 2
    case peerUnreachable = 3
    case cached = 4
    case tooOften = 5
    case invalidUserId = 6
    case invalidMessage = 7
    case notInitialized = 101
    case notLoggedIn = 102
}

internal enum AgoraRtmJoinChannelErrorCode: Int {
    case channelErrorOk = 0
    case channelErrorFailure = 1
    case channelErrorRejected = 2
    case channelErrorInvalidArgument = 3
    case channelErrorTimeout = 4
    case channelErrorExceedLimit = 5
    case channelErrorAlreadyJoined = 6
    case channelErrorNotInitialized = 101
    case channelErrorNotLoggedIn = 102
}

internal enum AgoraRtmLeaveChannelErrorCode: Int {
    case channelErrorOk = 0
    case channelErrorFailure = 1
    case channelErrorRejected = 2
    case channelErrorNotInChannel = 3
    case channelErrorNotInitialized = 101
    case channelErrorNotLoggedIn = 102
}

internal enum AgoraRtmSendChannelMessageErrorCode: Int {
    case channelMessageErrorOk = 0
    case channelMessageErrorFailure = 1
    case channelMessageErrorTimeout = 2
    case channelMessageErrorTooOften = 3
    case channelMessageErrorInvalidMessage = 4
    case channelMessageErrorNotInChannel = 5
    case channelMessageErrorNotInitialized = 101
    case channelMessageErrorNotLoggedIn = 102
}

internal enum AgoraRtmRenewTokenErrorCode: Int {
    case ok = 0
    case failure = 1
    case invalidArgument = 2
    case rejected = 3
    case tooOften = 4
    case tokenExpired = 5
    case invalidToken = 6
    case notInitialized = 101
    case notLoggedIn = 102
}

/// Agora RTC provider implementation
public final class AgoraRTCProvider: RTCProvider, @unchecked Sendable {
    
    // MARK: - Private Properties
    private var rtcEngine: AgoraRtcEngineKit?
    private var isInitialized = false
    private var currentConfig: RTCConfig?
    private var currentRoom: RTCRoom?
    private var currentUserId: String?
    private var currentUserRole: UserRole = .audience
    
    // Audio state tracking
    private var microphoneMuted = false
    private var localAudioStreamActive = true
    private var audioMixingVolume = 100
    private var playbackSignalVolume = 100
    private var recordingSignalVolume = 100
    
    // Volume indicator
    private var volumeIndicatorHandler: (([UserVolumeInfo]) -> Void)?
    private var volumeEventHandler: ((VolumeEvent) -> Void)?
    private var currentVolumeInfos: [UserVolumeInfo] = []
    private var volumeDetectionConfig: VolumeDetectionConfig?
    
    // Token management
    private var tokenExpirationHandler: ((Int) -> Void)?
    
    // Stream push state
    private var streamPushConfig: StreamPushConfig?
    private var isStreamPushActive = false
    
    // Media relay state
    private var mediaRelayConfig: MediaRelayConfig?
    private var isMediaRelayActive = false
    
    // MARK: - RTCProvider Implementation
    
    public init() {}
    
    public func initialize(config: RTCConfig) async throws {
        guard !isInitialized else {
            throw RealtimeError.providerAlreadyInitialized(.agora)
        }
        
        currentConfig = config
        
        // Initialize Agora RTC Engine
        rtcEngine = AgoraRtcEngineKit.sharedEngine(withAppId: config.appId, delegate: self)
        
        guard let engine = rtcEngine else {
            throw RealtimeError.providerInitializationFailed(.agora, "Failed to create RTC engine")
        }
        
        // Configure engine based on config
        configureEngine(engine, with: config)
        
        isInitialized = true
        print("AgoraRTCProvider initialized with appId: \(config.appId)")
    }
    
    private func configureEngine(_ engine: AgoraRtcEngineKit, with config: RTCConfig) {
        // Configure audio profile based on config
        // In real implementation, this would call actual Agora SDK methods
        print("Configuring Agora engine with audio profile: \(config.audioProfile)")
        print("Configuring Agora engine with video profile: \(config.videoProfile)")
        
        if config.enableEncryption, let key = config.encryptionKey {
            print("Enabling encryption with key: \(key.prefix(4))...")
        }
    }
    
    public func createRoom(roomId: String) async throws -> RTCRoom {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let room = RTCRoom(roomId: roomId, roomName: "Agora Room \(roomId)")
        currentRoom = room
        return room
    }
    
    public func joinRoom(roomId: String, userId: String, userRole: UserRole) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        currentUserId = userId
        currentUserRole = userRole
        
        // Set client role based on user role
        let clientRole: AgoraClientRole = userRole.hasAudioPermission ? .broadcaster : .audience
        let result = engine.setClientRole(clientRole)
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to set client role")
        }
        
        // Join channel
        let token = currentConfig?.token
        let joinResult = engine.joinChannel(byToken: token, channelId: roomId, info: nil, uid: UInt(userId.hash))
        
        guard joinResult == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to join channel")
        }
        
        print("Joining Agora room: \(roomId) as user: \(userId) with role: \(userRole)")
    }
    
    public func leaveRoom() async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let result = engine.leaveChannel()
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to leave channel")
        }
        
        currentRoom = nil
        currentUserId = nil
        currentUserRole = .audience
        
        print("Left Agora room")
    }
    
    public func switchUserRole(_ role: UserRole) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard currentUserRole.canSwitchToRole.contains(role) else {
            throw RealtimeError.invalidRoleTransition(from: currentUserRole, to: role)
        }
        
        let clientRole: AgoraClientRole = role.hasAudioPermission ? .broadcaster : .audience
        let result = engine.setClientRole(clientRole)
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to switch user role")
        }
        
        currentUserRole = role
        print("Switched to role: \(role)")
    }
    
    // MARK: - Audio Stream Control
    
    public func muteMicrophone(_ muted: Bool) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let result = engine.muteLocalAudioStream(muted)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to mute microphone")
        }
        
        microphoneMuted = muted
        print("Agora: Microphone muted: \(muted)")
    }
    
    public func isMicrophoneMuted() -> Bool {
        return microphoneMuted
    }
    
    public func stopLocalAudioStream() async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let result = engine.muteLocalAudioStream(true)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to stop local audio stream")
        }
        
        localAudioStreamActive = false
        print("Agora: Stopped local audio stream")
    }
    
    public func resumeLocalAudioStream() async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let result = engine.muteLocalAudioStream(false)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to resume local audio stream")
        }
        
        localAudioStreamActive = true
        print("Agora: Resumed local audio stream")
    }
    
    public func isLocalAudioStreamActive() -> Bool {
        return localAudioStreamActive
    }
    
    // MARK: - Volume Control
    
    public func setAudioMixingVolume(_ volume: Int) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let clampedVolume = max(0, min(100, volume))
        let result = engine.adjustAudioMixingVolume(Int32(clampedVolume))
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to set audio mixing volume")
        }
        
        audioMixingVolume = clampedVolume
        print("Agora: Set audio mixing volume: \(clampedVolume)")
    }
    
    public func getAudioMixingVolume() -> Int {
        return audioMixingVolume
    }
    
    public func setPlaybackSignalVolume(_ volume: Int) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let clampedVolume = max(0, min(100, volume))
        let result = engine.adjustPlaybackSignalVolume(Int32(clampedVolume))
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to set playback signal volume")
        }
        
        playbackSignalVolume = clampedVolume
        print("Agora: Set playback signal volume: \(clampedVolume)")
    }
    
    public func getPlaybackSignalVolume() -> Int {
        return playbackSignalVolume
    }
    
    public func setRecordingSignalVolume(_ volume: Int) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let clampedVolume = max(0, min(100, volume))
        let result = engine.adjustRecordingSignalVolume(Int32(clampedVolume))
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to set recording signal volume")
        }
        
        recordingSignalVolume = clampedVolume
        print("Agora: Set recording signal volume: \(clampedVolume)")
    }
    
    public func getRecordingSignalVolume() -> Int {
        return recordingSignalVolume
    }
    
    // MARK: - Stream Push
    
    public func startStreamPush(config: StreamPushConfig) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard !isStreamPushActive else {
            throw RealtimeError.operationFailed(.agora, "Stream push already active")
        }
        
        // Create Agora live transcoding configuration
        let transcoding = createAgoraTranscoding(from: config)
        
        let result = engine.startRtmpStream(withTranscoding: config.pushUrl, transcoding: transcoding)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to start stream push")
        }
        
        streamPushConfig = config
        isStreamPushActive = true
        print("Agora: Started stream push to: \(config.pushUrl)")
    }
    
    public func stopStreamPush() async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isStreamPushActive, let config = streamPushConfig else {
            throw RealtimeError.operationFailed(.agora, "No active stream push")
        }
        
        let result = engine.stopRtmpStream(config.pushUrl)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to stop stream push")
        }
        
        streamPushConfig = nil
        isStreamPushActive = false
        print("Agora: Stopped stream push")
    }
    
    public func updateStreamPushLayout(layout: StreamLayout) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isStreamPushActive, let config = streamPushConfig else {
            throw RealtimeError.operationFailed(.agora, "No active stream push")
        }
        
        let updatedConfig = try StreamPushConfig(
            pushUrl: config.pushUrl,
            width: config.width,
            height: config.height,
            bitrate: config.bitrate,
            frameRate: config.frameRate,
            layout: layout
        )
        let transcoding = createAgoraTranscoding(from: updatedConfig)
        
        let result = engine.updateRtmpTranscoding(transcoding)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to update stream push layout")
        }
        
        streamPushConfig = updatedConfig
        print("Agora: Updated stream push layout")
    }
    
    private func createAgoraTranscoding(from config: StreamPushConfig) -> AgoraLiveTranscoding {
        let transcoding = AgoraLiveTranscoding()
        transcoding.width = config.width
        transcoding.height = config.height
        transcoding.videoBitrate = config.bitrate
        transcoding.videoFramerate = config.frameRate
        
        // Convert layout users to Agora transcoding users
        transcoding.transcodingUsers = config.layout.userRegions.map { region in
            let agoraUser = AgoraLiveTranscodingUser()
            agoraUser.uid = UInt(region.userId.hash)
            agoraUser.x = Int(region.x * Float(config.width))
            agoraUser.y = Int(region.y * Float(config.height))
            agoraUser.width = Int(region.width * Float(config.width))
            agoraUser.height = Int(region.height * Float(config.height))
            return agoraUser
        }
        
        return transcoding
    }
    
    // MARK: - Media Relay
    
    public func startMediaRelay(config: MediaRelayConfig) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard !isMediaRelayActive else {
            throw RealtimeError.operationFailed(.agora, "Media relay already active")
        }
        
        let relayConfig = createAgoraMediaRelayConfig(from: config)
        let result = engine.startChannelMediaRelay(relayConfig)
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to start media relay")
        }
        
        mediaRelayConfig = config
        isMediaRelayActive = true
        print("Agora: Started media relay")
    }
    
    public func stopMediaRelay() async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isMediaRelayActive else {
            throw RealtimeError.operationFailed(.agora, "No active media relay")
        }
        
        let result = engine.stopChannelMediaRelay()
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to stop media relay")
        }
        
        mediaRelayConfig = nil
        isMediaRelayActive = false
        print("Agora: Stopped media relay")
    }
    
    public func updateMediaRelayChannels(config: MediaRelayConfig) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isMediaRelayActive else {
            throw RealtimeError.operationFailed(.agora, "No active media relay")
        }
        
        let relayConfig = createAgoraMediaRelayConfig(from: config)
        let result = engine.updateChannelMediaRelay(relayConfig)
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to update media relay channels")
        }
        
        mediaRelayConfig = config
        print("Agora: Updated media relay channels")
    }
    
    public func pauseMediaRelay(toChannel: String) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isMediaRelayActive else {
            throw RealtimeError.operationFailed(.agora, "No active media relay")
        }
        
        // In real implementation, this would pause specific channel
        let result = engine.pauseAllChannelMediaRelay()
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to pause media relay")
        }
        
        print("Agora: Paused media relay to channel: \(toChannel)")
    }
    
    public func resumeMediaRelay(toChannel: String) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isMediaRelayActive else {
            throw RealtimeError.operationFailed(.agora, "No active media relay")
        }
        
        // In real implementation, this would resume specific channel
        let result = engine.resumeAllChannelMediaRelay()
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to resume media relay")
        }
        
        print("Agora: Resumed media relay to channel: \(toChannel)")
    }
    
    private func createAgoraMediaRelayConfig(from config: MediaRelayConfig) -> AgoraChannelMediaRelayConfiguration {
        let relayConfig = AgoraChannelMediaRelayConfiguration()
        
        // Set source channel
        let sourceInfo = AgoraChannelMediaRelayInfo(token: config.sourceChannel.token)
        sourceInfo.channelName = config.sourceChannel.channelName
        sourceInfo.uid = config.sourceChannel.uid ?? UInt(config.sourceChannel.userId.hashValue)
        relayConfig.setSourceInfo(sourceInfo)
        
        // Set destination channels
        for destChannel in config.destinationChannels {
            let destInfo = AgoraChannelMediaRelayInfo(token: destChannel.token)
            destInfo.channelName = destChannel.channelName
            destInfo.uid = destChannel.uid ?? UInt(destChannel.userId.hashValue)
            relayConfig.setDestinationInfo(destInfo, forChannelName: destChannel.channelName)
        }
        
        return relayConfig
    }
    
    // MARK: - Volume Indicator
    
    public func enableVolumeIndicator(config: VolumeDetectionConfig) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        volumeDetectionConfig = config
        
        let result = engine.enableAudioVolumeIndication(
            config.detectionInterval,
            smooth: Int(config.smoothFactor * 10),
            reportVad: true
        )
        
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to enable volume indicator")
        }
        
        print("Agora: Enabled volume indicator with interval: \(config.detectionInterval)ms")
    }
    
    public func disableVolumeIndicator() async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let result = engine.enableAudioVolumeIndication(0, smooth: 0, reportVad: false)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to disable volume indicator")
        }
        
        volumeDetectionConfig = nil
        currentVolumeInfos = []
        print("Agora: Disabled volume indicator")
    }
    
    public func setVolumeIndicatorHandler(_ handler: @escaping @Sendable ([UserVolumeInfo]) -> Void) {
        volumeIndicatorHandler = handler
        print("Agora: Set volume indicator handler")
    }
    
    public func setVolumeEventHandler(_ handler: @escaping @Sendable (VolumeEvent) -> Void) {
        volumeEventHandler = handler
        print("Agora: Set volume event handler")
    }
    
    public func getCurrentVolumeInfos() -> [UserVolumeInfo] {
        return currentVolumeInfos
    }
    
    public func getVolumeInfo(for userId: String) -> UserVolumeInfo? {
        return currentVolumeInfos.first { $0.userId == userId }
    }
    
    // MARK: - Token Management
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized, let engine = rtcEngine else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        let result = engine.renewToken(newToken)
        guard result == 0 else {
            throw RealtimeError.operationFailed(.agora, "Failed to renew token")
        }
        
        print("Agora: Renewed token")
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {
        tokenExpirationHandler = handler
        print("Agora: Set token expiration handler")
    }
}

/// Agora RTM provider implementation
public final class AgoraRTMProvider: RTMProvider, @unchecked Sendable {
    
    // MARK: - Private Properties
    private var rtmKit: AgoraRtmKit?
    private var isInitialized = false
    private var isLoggedIn = false
    private var currentConfig: RTMConfig?
    private var currentUserId: String?
    private var connectionState: ConnectionState = .disconnected
    
    // Channel management
    private var subscribedChannels: [String: AgoraRtmChannel] = [:]
    
    // Handlers
    private var messageHandler: ((RealtimeMessage) -> Void)?
    private var connectionStateHandler: ((ConnectionState) -> Void)?
    private var tokenExpirationHandler: ((Int) -> Void)?
    
    // MARK: - RTMProvider Implementation
    
    public init() {}
    
    public func initialize(config: RTMConfig) async throws {
        guard !isInitialized else {
            throw RealtimeError.providerAlreadyInitialized(.agora)
        }
        
        currentConfig = config
        
        // Initialize Agora RTM Kit
        rtmKit = AgoraRtmKit(appId: config.appId, delegate: self)
        
        guard rtmKit != nil else {
            throw RealtimeError.providerInitializationFailed(.agora, "Failed to create RTM kit")
        }
        
        isInitialized = true
        connectionState = .disconnected
        
        print("AgoraRTMProvider initialized with appId: \(config.appId)")
    }
    
    public func sendMessage(_ message: RealtimeMessage) async throws {
        guard isInitialized, let kit = rtmKit else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isLoggedIn else {
            throw RealtimeError.notLoggedIn(.agora)
        }
        
        let agoraMessage = AgoraRtmMessage(text: message.content, type: .text)
        
        return try await withCheckedThrowingContinuation { continuation in
            if let channelId = message.channelId {
                // Send channel message
                guard let channel = subscribedChannels[channelId] else {
                    continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Not subscribed to channel: \(channelId)"))
                    return
                }
                
                channel.send(agoraMessage) { errorCode in
                    if errorCode == .channelMessageErrorOk {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Failed to send channel message: \(errorCode)"))
                    }
                }
            } else {
                // Send peer message (assume senderId is the target user)
                kit.send(agoraMessage, toPeer: message.senderId) { errorCode in
                    if errorCode == .ok {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Failed to send peer message: \(errorCode)"))
                    }
                }
            }
        }
    }
    
    public func subscribe(to channel: String) async throws {
        guard isInitialized, let kit = rtmKit else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isLoggedIn else {
            throw RealtimeError.notLoggedIn(.agora)
        }
        
        guard subscribedChannels[channel] == nil else {
            throw RealtimeError.operationFailed(.agora, "Already subscribed to channel: \(channel)")
        }
        
        // Create and join channel
        guard let rtmChannel = kit.createChannel(withId: channel, delegate: self) else {
            throw RealtimeError.operationFailed(.agora, "Failed to create channel: \(channel)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            rtmChannel.join { errorCode in
                if errorCode == .channelErrorOk {
                    self.subscribedChannels[channel] = rtmChannel
                    continuation.resume()
                    print("Agora RTM: Subscribed to channel: \(channel)")
                } else {
                    continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Failed to join channel: \(errorCode)"))
                }
            }
        }
    }
    
    public func unsubscribe(from channel: String) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard let rtmChannel = subscribedChannels[channel] else {
            throw RealtimeError.operationFailed(.agora, "Not subscribed to channel: \(channel)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            rtmChannel.leave { errorCode in
                if errorCode == .channelErrorOk {
                    self.subscribedChannels.removeValue(forKey: channel)
                    continuation.resume()
                    print("Agora RTM: Unsubscribed from channel: \(channel)")
                } else {
                    continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Failed to leave channel: \(errorCode)"))
                }
            }
        }
    }
    
    public func setMessageHandler(_ handler: @escaping @Sendable (RealtimeMessage) -> Void) {
        messageHandler = handler
        print("Agora RTM: Set message handler")
    }
    
    public func setConnectionStateHandler(_ handler: @escaping @Sendable (ConnectionState) -> Void) {
        connectionStateHandler = handler
        print("Agora RTM: Set connection state handler")
    }
    
    public func processIncomingMessage(_ rawMessage: Any) async throws -> RealtimeMessage {
        guard let agoraMessage = rawMessage as? AgoraRtmMessage else {
            throw RealtimeError.invalidMessageFormat(.agora, "Expected AgoraRtmMessage")
        }
        
        // Convert Agora message to RealtimeMessage
        let messageType: MessageType = agoraMessage.type == .text ? .text : .custom
        
        return RealtimeMessage(
            messageId: UUID().uuidString,
            messageType: messageType,
            content: agoraMessage.text,
            senderId: "unknown", // Would be provided by delegate context
            channelId: "unknown", // Would be provided by delegate context
            timestamp: Date(),
            metadata: [:]
        )
    }
    
    public func renewToken(_ newToken: String) async throws {
        guard isInitialized, let kit = rtmKit else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            kit.renewToken(newToken) { errorCode in
                if errorCode == .ok {
                    continuation.resume()
                    print("Agora RTM: Token renewed successfully")
                } else {
                    continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Failed to renew token: \(errorCode)"))
                }
            }
        }
    }
    
    public func onTokenWillExpire(_ handler: @escaping @Sendable (Int) -> Void) {
        tokenExpirationHandler = handler
        print("Agora RTM: Set token expiration handler")
    }
    
    public func getConnectionState() -> ConnectionState {
        return connectionState
    }
    
    public func reconnect() async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard let config = currentConfig else {
            throw RealtimeError.operationFailed(.agora, "No configuration available for reconnection")
        }
        
        // Disconnect first if connected
        if isLoggedIn {
            try await disconnect()
        }
        
        // Attempt to login again
        try await login(with: config)
        
        print("Agora RTM: Reconnected successfully")
    }
    
    public func disconnect() async throws {
        guard isInitialized, let kit = rtmKit else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        guard isLoggedIn else {
            return // Already disconnected
        }
        
        // Leave all subscribed channels first
        for (channelId, _) in subscribedChannels {
            try? await unsubscribe(from: channelId)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            kit.logout { errorCode in
                self.isLoggedIn = false
                self.connectionState = .disconnected
                self.connectionStateHandler?(.disconnected)
                
                if errorCode == .ok {
                    continuation.resume()
                    print("Agora RTM: Disconnected successfully")
                } else {
                    continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Failed to logout: \(errorCode)"))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func login(with config: RTMConfig) async throws {
        guard let kit = rtmKit else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        // Generate a user ID if not provided
        let userId = currentUserId ?? "user_\(Int.random(in: 1000...9999))"
        currentUserId = userId
        
        connectionState = .connecting
        connectionStateHandler?(.connecting)
        
        return try await withCheckedThrowingContinuation { continuation in
            kit.login(byToken: config.token, user: userId) { errorCode in
                if errorCode == .ok {
                    self.isLoggedIn = true
                    self.connectionState = .connected
                    self.connectionStateHandler?(.connected)
                    continuation.resume()
                    print("Agora RTM: Logged in successfully as user: \(userId)")
                } else {
                    self.connectionState = .failed
                    self.connectionStateHandler?(.failed)
                    continuation.resume(throwing: RealtimeError.operationFailed(.agora, "Failed to login: \(errorCode)"))
                }
            }
        }
    }
    
    /// Login with user ID (public method for external use)
    public func login(userId: String, token: String? = nil) async throws {
        guard isInitialized else {
            throw RealtimeError.providerNotInitialized(.agora)
        }
        
        currentUserId = userId
        
        // Update config with new token if provided
        if let token = token, var config = currentConfig {
            config = RTMConfig(
                appId: config.appId,
                token: token,
                serverUrl: config.serverUrl,
                logLevel: config.logLevel,
                enableEncryption: config.enableEncryption,
                encryptionKey: config.encryptionKey,
                heartbeatInterval: config.heartbeatInterval,
                connectionTimeout: config.connectionTimeout
            )
            currentConfig = config
        }
        
        guard let config = currentConfig else {
            throw RealtimeError.operationFailed(.agora, "No configuration available")
        }
        
        try await login(with: config)
    }
}

// MARK: - AgoraRtcEngineDelegate Implementation

extension AgoraRTCProvider: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("Agora: Successfully joined channel: \(channel) with uid: \(uid)")
        
        // Update current room if needed
        if currentRoom?.roomId != channel {
            currentRoom = RTCRoom(roomId: channel, roomName: "Agora Room \(channel)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        print("Agora: Left channel with stats - duration: \(stats.duration)s, tx: \(stats.txBytes), rx: \(stats.rxBytes)")
        currentRoom = nil
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        guard let config = volumeDetectionConfig else { return }
        
        let previousVolumeInfos = currentVolumeInfos
        let previousSpeakingUsers = Set(previousVolumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        
        // Convert Agora volume info to RealtimeKit format
        currentVolumeInfos = speakers.compactMap { speaker in
            let userId = String(speaker.uid)
            let normalizedVolume = Float(speaker.volume) / 255.0
            let isSpeaking = normalizedVolume > config.speakingThreshold
            
            return UserVolumeInfo(
                userId: userId,
                volume: normalizedVolume,
                isSpeaking: isSpeaking,
                timestamp: Date()
            )
        }
        
        // Filter out local user if not included in config
        if !config.includeLocalUser, let localUserId = currentUserId {
            currentVolumeInfos = currentVolumeInfos.filter { $0.userId != localUserId }
        }
        
        // Detect speaking state changes
        let currentSpeakingUsers = Set(currentVolumeInfos.filter { $0.isSpeaking }.map { $0.userId })
        
        // Users who started speaking
        let startedSpeaking = currentSpeakingUsers.subtracting(previousSpeakingUsers)
        for userId in startedSpeaking {
            if let volumeInfo = currentVolumeInfos.first(where: { $0.userId == userId }) {
                volumeEventHandler?(.userStartedSpeaking(userId: userId, volume: volumeInfo.volume))
            }
        }
        
        // Users who stopped speaking
        let stoppedSpeaking = previousSpeakingUsers.subtracting(currentSpeakingUsers)
        for userId in stoppedSpeaking {
            if let volumeInfo = previousVolumeInfos.first(where: { $0.userId == userId }) {
                volumeEventHandler?(.userStoppedSpeaking(userId: userId, volume: volumeInfo.volume))
            }
        }
        
        // Check for dominant speaker change
        let currentDominantSpeaker = currentVolumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        
        let previousDominantSpeaker = previousVolumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        
        if currentDominantSpeaker != previousDominantSpeaker {
            volumeEventHandler?(.dominantSpeakerChanged(userId: currentDominantSpeaker))
        }
        
        // Call volume indicator handler
        volumeIndicatorHandler?(currentVolumeInfos)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        print("Agora: Token will expire soon")
        
        // Calculate remaining time (simulate 30 seconds)
        let remainingSeconds = 30
        tokenExpirationHandler?(remainingSeconds)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("Agora: RTC Engine error occurred: \(errorCode.rawValue)")
        
        // Handle specific error cases
        switch errorCode {
        case .tokenExpired:
            tokenExpirationHandler?(0)
        case .invalidToken:
            print("Agora: Invalid token provided")
        case .connectionLost:
            print("Agora: Connection lost, attempting to reconnect")
        case .joinChannelRejected:
            print("Agora: Join channel rejected")
        default:
            print("Agora: Unhandled error: \(errorCode)")
        }
    }
}

// MARK: - AgoraRtmDelegate Implementation

extension AgoraRTMProvider: AgoraRtmDelegate {
    
    func rtmKit(_ kit: AgoraRtmKit, connectionStateChanged state: AgoraRtmConnectionState, reason: AgoraRtmConnectionChangeReason) {
        print("Agora RTM: Connection state changed to \(state.rawValue), reason: \(reason.rawValue)")
        
        let newState: ConnectionState
        switch state {
        case .disconnected:
            newState = .disconnected
            isLoggedIn = false
        case .connecting:
            newState = .connecting
        case .connected:
            newState = .connected
            isLoggedIn = true
        case .reconnecting:
            newState = .reconnecting
        case .aborted:
            newState = .failed
            isLoggedIn = false
        }
        
        connectionState = newState
        connectionStateHandler?(newState)
        
        // Handle specific reasons
        switch reason {
        case .tokenExpired:
            print("Agora RTM: Token expired")
            tokenExpirationHandler?(0)
        case .remoteLogin:
            print("Agora RTM: Remote login detected")
        case .bannedByServer:
            print("Agora RTM: Banned by server")
        default:
            break
        }
    }
    
    func rtmKit(_ kit: AgoraRtmKit, messageReceived message: AgoraRtmMessage, fromPeer peerId: String) {
        print("Agora RTM: Received peer message from \(peerId): \(message.text)")
        
        // Convert to RealtimeMessage and forward to handler
        let realtimeMessage = RealtimeMessage(
            messageId: UUID().uuidString,
            messageType: message.type == .text ? .text : .custom,
            content: message.text,
            senderId: peerId,
            channelId: nil, // Peer message, no channel
            timestamp: Date(),
            metadata: [:]
        )
        
        messageHandler?(realtimeMessage)
    }
    
    func rtmKit(_ kit: AgoraRtmKit, channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember) {
        print("Agora RTM: Received channel message in \(channel.channelId) from \(member.userId): \(message.text)")
        
        // Convert to RealtimeMessage and forward to handler
        let realtimeMessage = RealtimeMessage(
            messageId: UUID().uuidString,
            messageType: message.type == .text ? .text : .custom,
            content: message.text,
            senderId: member.userId,
            channelId: channel.channelId,
            timestamp: Date(),
            metadata: [:]
        )
        
        messageHandler?(realtimeMessage)
    }
    
    func rtmKit(_ kit: AgoraRtmKit, tokenPrivilegeWillExpire token: String) {
        print("Agora RTM: Token will expire soon")
        
        // Calculate remaining time (simulate 30 seconds)
        let remainingSeconds = 30
        tokenExpirationHandler?(remainingSeconds)
    }
}

// MARK: - AgoraRtmChannelDelegate Implementation

extension AgoraRTMProvider: AgoraRtmChannelDelegate {
    
    func channel(_ channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember) {
        // This is handled by the main RTM delegate method above
        rtmKit(rtmKit!, channel: channel, messageReceived: message, from: member)
    }
}

// MARK: - Agora Provider Factory

/// Factory for creating Agora providers
public final class AgoraProviderFactory: ProviderFactory, @unchecked Sendable {
    public let providerType: ProviderType = .agora
    
    public init() {}
    
    public func createRTCProvider() -> RTCProvider {
        return AgoraRTCProvider()
    }
    
    public func createRTMProvider() -> RTMProvider {
        return AgoraRTMProvider()
    }
    
    public func supportedFeatures() -> Set<ProviderFeature> {
        return [
            .audioStreaming,
            .videoStreaming,
            .streamPush,
            .mediaRelay,
            .volumeIndicator,
            .messageProcessing,
            .tokenManagement,
            .encryption
        ]
    }
}