import Testing
@testable import RealtimeCore

/// 转推流配置验证测试
/// 需求: 7.1, 7.5 - 转推流配置验证逻辑和错误处理
@Suite("Stream Push Configuration Tests")
struct StreamPushConfigTests {
    
    // MARK: - StreamPushConfig Tests
    
    @Test("Valid stream push config should initialize successfully")
    func testValidStreamPushConfig() async throws {
        let config = try StreamPushConfig(
            url: "rtmp://live.example.com/live/stream123"
        )
        
        #expect(config.url == "rtmp://live.example.com/live/stream123")
        #expect(config.enableTranscoding == true)
        #expect(config.backgroundColor == "#000000")
        #expect(config.quality == .standard)
    }
    
    @Test("Invalid URL should throw validation error", arguments: [
        "",
        "invalid-url",
        "ftp://example.com/stream",
        "rtmp://",
        "http://example.com"
    ])
    func testInvalidURL(url: String) async throws {
        #expect(throws: StreamPushValidationError.self) {
            try StreamPushConfig(url: url)
        }
    }
    
    @Test("Valid URLs should pass validation", arguments: [
        "rtmp://live.example.com/live/stream123",
        "rtmps://secure.example.com/live/stream456",
        "http://example.com/hls/stream.m3u8",
        "https://secure.example.com/dash/stream.mpd"
    ])
    func testValidURLs(url: String) async throws {
        let config = try StreamPushConfig(url: url)
        #expect(config.url == url)
    }
    
    @Test("Invalid background color should throw validation error", arguments: [
        "invalid",
        "#GGG",
        "#12345",
        "#1234567",
        "123456"
    ])
    func testInvalidBackgroundColor(color: String) async throws {
        #expect(throws: StreamPushValidationError.self) {
            try StreamPushConfig(
                url: "rtmp://example.com/stream",
                backgroundColor: color
            )
        }
    }
    
    @Test("Valid background colors should pass validation", arguments: [
        "#000000",
        "#FFFFFF",
        "#123456",
        "#abcdef",
        "#ABCDEF"
    ])
    func testValidBackgroundColors(color: String) async throws {
        let config = try StreamPushConfig(
            url: "rtmp://example.com/stream",
            backgroundColor: color
        )
        #expect(config.backgroundColor == color)
    }
    
    // MARK: - StreamVideoConfig Tests
    
    @Test("Valid video config should initialize successfully")
    func testValidVideoConfig() async throws {
        let config = StreamVideoConfig(
            width: 1280,
            height: 720,
            bitrate: 2000,
            frameRate: 30
        )
        
        try config.validate()
        #expect(config.width == 1280)
        #expect(config.height == 720)
        #expect(config.bitrate == 2000)
        #expect(config.frameRate == 30)
    }
    
    @Test("Invalid video resolution should throw validation error", arguments: [
        (width: 0, height: 480),
        (width: 640, height: 0),
        (width: 15, height: 480),
        (width: 640, height: 15),
        (width: 2000, height: 480),
        (width: 640, height: 1200)
    ])
    func testInvalidVideoResolution(width: Int, height: Int) async throws {
        let config = StreamVideoConfig(width: width, height: height)
        #expect(throws: StreamPushValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Invalid video bitrate should throw validation error", arguments: [0, -1, 10001, 50000])
    func testInvalidVideoBitrate(bitrate: Int) async throws {
        let config = StreamVideoConfig(bitrate: bitrate)
        #expect(throws: StreamPushValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Invalid video frame rate should throw validation error", arguments: [0, -1, 61, 120])
    func testInvalidVideoFrameRate(frameRate: Int) async throws {
        let config = StreamVideoConfig(frameRate: frameRate)
        #expect(throws: StreamPushValidationError.self) {
            try config.validate()
        }
    }
    
    // MARK: - StreamLayout Tests
    
    @Test("Valid stream layout should initialize successfully")
    func testValidStreamLayout() async throws {
        let layout = StreamLayout(
            type: .floating,
            canvasWidth: 1280,
            canvasHeight: 720
        )
        
        #expect(layout.type == .floating)
        #expect(layout.canvasWidth == 1280)
        #expect(layout.canvasHeight == 720)
        #expect(layout.userRegions.isEmpty)
    }
    
    @Test("Invalid canvas size should throw validation error", arguments: [
        (width: 0, height: 480),
        (width: 640, height: 0),
        (width: 15, height: 480),
        (width: 640, height: 15),
        (width: 2000, height: 480),
        (width: 640, height: 1200)
    ])
    func testInvalidCanvasSize(width: Int, height: Int) async throws {
        let layout = StreamLayout(canvasWidth: width, canvasHeight: height)
        #expect(throws: StreamPushValidationError.self) {
            try layout.validate()
        }
    }
    
    @Test("Custom layout with empty user regions should throw validation error")
    func testCustomLayoutWithEmptyUserRegions() async throws {
        let layout = StreamLayout(type: .custom, userRegions: [])
        #expect(throws: StreamPushValidationError.self) {
            try layout.validate()
        }
    }
    
    @Test("Duplicate user regions should throw validation error")
    func testDuplicateUserRegions() async throws {
        let region1 = StreamUserRegion(userId: "user1", x: 0, y: 0, width: 320, height: 240)
        let region2 = StreamUserRegion(userId: "user1", x: 320, y: 0, width: 320, height: 240)
        
        let layout = StreamLayout(
            type: .custom,
            canvasWidth: 640,
            canvasHeight: 480,
            userRegions: [region1, region2]
        )
        
        #expect(throws: StreamPushValidationError.self) {
            try layout.validate()
        }
    }
    
    // MARK: - StreamUserRegion Tests
    
    @Test("Valid user region should initialize successfully")
    func testValidUserRegion() async throws {
        let region = StreamUserRegion(
            userId: "user123",
            x: 100,
            y: 50,
            width: 320,
            height: 240,
            alpha: 0.8
        )
        
        #expect(region.userId == "user123")
        #expect(region.x == 100)
        #expect(region.y == 50)
        #expect(region.width == 320)
        #expect(region.height == 240)
        #expect(region.alpha == 0.8)
    }
    
    @Test("Empty user ID should throw validation error")
    func testEmptyUserId() async throws {
        let region = StreamUserRegion(userId: "", x: 0, y: 0, width: 100, height: 100)
        #expect(throws: StreamPushValidationError.self) {
            try region.validate(canvasWidth: 640, canvasHeight: 480)
        }
    }
    
    @Test("Invalid dimensions should throw validation error", arguments: [
        (width: 0, height: 100),
        (width: 100, height: 0),
        (width: -10, height: 100),
        (width: 100, height: -10)
    ])
    func testInvalidUserRegionDimensions(width: Int, height: Int) async throws {
        let region = StreamUserRegion(userId: "user1", x: 0, y: 0, width: width, height: height)
        #expect(throws: StreamPushValidationError.self) {
            try region.validate(canvasWidth: 640, canvasHeight: 480)
        }
    }
    
    @Test("Invalid alpha should throw validation error", arguments: [-0.1, 1.1, 2.0, -1.0])
    func testInvalidUserRegionAlpha(alpha: Double) async throws {
        let region = StreamUserRegion(userId: "user1", x: 0, y: 0, width: 100, height: 100, alpha: alpha)
        #expect(throws: StreamPushValidationError.self) {
            try region.validate(canvasWidth: 640, canvasHeight: 480)
        }
    }
    
    @Test("User region out of bounds should throw validation error")
    func testUserRegionOutOfBounds() async throws {
        let region = StreamUserRegion(userId: "user1", x: 500, y: 400, width: 200, height: 200)
        
        #expect(throws: StreamPushValidationError.self) {
            try region.validate(canvasWidth: 640, canvasHeight: 480)
        }
    }
    
    // MARK: - StreamAudioConfig Tests
    
    @Test("Valid audio config should pass validation")
    func testValidAudioConfig() async throws {
        let config = StreamAudioConfig(
            sampleRate: 48000,
            bitrate: 128,
            channels: 2,
            codec: .aac
        )
        
        try config.validate()
        #expect(config.sampleRate == 48000)
        #expect(config.bitrate == 128)
        #expect(config.channels == 2)
        #expect(config.codec == .aac)
    }
    
    @Test("Invalid sample rate should throw validation error", arguments: [11025, 32000, 96000])
    func testInvalidSampleRate(sampleRate: Int) async throws {
        let config = StreamAudioConfig(sampleRate: sampleRate)
        #expect(throws: StreamPushValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Invalid audio bitrate should throw validation error", arguments: [16, 31, 321, 500])
    func testInvalidAudioBitrate(bitrate: Int) async throws {
        let config = StreamAudioConfig(bitrate: bitrate)
        #expect(throws: StreamPushValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Invalid audio channels should throw validation error", arguments: [0, 3, 5, -1])
    func testInvalidAudioChannels(channels: Int) async throws {
        let config = StreamAudioConfig(channels: channels)
        #expect(throws: StreamPushValidationError.self) {
            try config.validate()
        }
    }
    
    // MARK: - StreamWatermark Tests
    
    @Test("Valid watermark should initialize successfully")
    func testValidWatermark() async throws {
        let watermark = StreamWatermark(
            imageUrl: "https://example.com/watermark.png",
            x: 10,
            y: 10,
            width: 100,
            height: 50,
            alpha: 0.7
        )
        
        #expect(watermark.imageUrl == "https://example.com/watermark.png")
        #expect(watermark.x == 10)
        #expect(watermark.y == 10)
        #expect(watermark.width == 100)
        #expect(watermark.height == 50)
        #expect(watermark.alpha == 0.7)
    }
    
    @Test("Invalid watermark URL should throw validation error", arguments: [
        "",
        "invalid-url",
        "ftp://example.com/image.png"
    ])
    func testInvalidWatermarkURL(url: String) async throws {
        let watermark = StreamWatermark(imageUrl: url, x: 0, y: 0, width: 100, height: 100)
        #expect(throws: StreamPushValidationError.self) {
            try watermark.validate()
        }
    }
    
    @Test("Invalid watermark dimensions should throw validation error", arguments: [
        (width: 0, height: 100),
        (width: 100, height: 0),
        (width: -10, height: 100),
        (width: 2000, height: 100),
        (width: 100, height: 1200)
    ])
    func testInvalidWatermarkDimensions(width: Int, height: Int) async throws {
        let watermark = StreamWatermark(
            imageUrl: "https://example.com/watermark.png",
            x: 0,
            y: 0,
            width: width,
            height: height
        )
        #expect(throws: StreamPushValidationError.self) {
            try watermark.validate()
        }
    }
    
    @Test("Invalid watermark alpha should throw validation error", arguments: [-0.1, 1.1, 2.0, -1.0])
    func testInvalidWatermarkAlpha(alpha: Double) async throws {
        let watermark = StreamWatermark(
            imageUrl: "https://example.com/watermark.png",
            x: 0,
            y: 0,
            width: 100,
            height: 100,
            alpha: alpha
        )
        #expect(throws: StreamPushValidationError.self) {
            try watermark.validate()
        }
    }
}