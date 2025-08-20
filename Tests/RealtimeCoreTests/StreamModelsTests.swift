// StreamModelsTests.swift
// Unit tests for stream push configuration and validation

import Testing
@testable import RealtimeCore

@Suite("Stream Models Tests")
struct StreamModelsTests {
    
    // MARK: - StreamPushConfig Tests
    
    @Suite("StreamPushConfig Validation Tests")
    struct StreamPushConfigTests {
        
        @Test("Valid configuration should initialize successfully")
        func testValidConfiguration() throws {
            let layout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
            let config = try StreamPushConfig(
                pushUrl: "rtmp://example.com/live/stream",
                width: 1280,
                height: 720,
                bitrate: 2000,
                frameRate: 30,
                layout: layout
            )
            
            #expect(config.pushUrl == "rtmp://example.com/live/stream")
            #expect(config.width == 1280)
            #expect(config.height == 720)
            #expect(config.bitrate == 2000)
            #expect(config.frameRate == 30)
            #expect(config.resolution == "1280x720")
            #expect(config.isValid == true)
        }
        
        @Test("Empty push URL should throw error")
        func testEmptyPushUrl() throws {
            let layout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
            
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "",
                    width: 1280,
                    height: 720,
                    bitrate: 2000,
                    frameRate: 30,
                    layout: layout
                )
            }
        }
        
        @Test("Invalid push URL protocol should throw error")
        func testInvalidPushUrlProtocol() throws {
            let layout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
            
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "http://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    bitrate: 2000,
                    frameRate: 30,
                    layout: layout
                )
            }
        }
        
        @Test("Invalid dimensions should throw error")
        func testInvalidDimensions() throws {
            let layout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
            
            // Test zero width
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 0,
                    height: 720,
                    bitrate: 2000,
                    frameRate: 30,
                    layout: layout
                )
            }
            
            // Test dimensions too small
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 100,
                    height: 100,
                    bitrate: 2000,
                    frameRate: 30,
                    layout: layout
                )
            }
            
            // Test dimensions too large
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 2000,
                    height: 1200,
                    bitrate: 2000,
                    frameRate: 30,
                    layout: layout
                )
            }
        }
        
        @Test("Invalid bitrate should throw error")
        func testInvalidBitrate() throws {
            let layout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
            
            // Test zero bitrate
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    bitrate: 0,
                    frameRate: 30,
                    layout: layout
                )
            }
            
            // Test bitrate too low
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    bitrate: 50,
                    frameRate: 30,
                    layout: layout
                )
            }
            
            // Test bitrate too high
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    bitrate: 15000,
                    frameRate: 30,
                    layout: layout
                )
            }
        }
        
        @Test("Invalid frame rate should throw error")
        func testInvalidFrameRate() throws {
            let layout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
            
            // Test zero frame rate
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    bitrate: 2000,
                    frameRate: 0,
                    layout: layout
                )
            }
            
            // Test unsupported frame rate
            #expect(throws: RealtimeError.self) {
                try StreamPushConfig(
                    pushUrl: "rtmp://example.com/live/stream",
                    width: 1280,
                    height: 720,
                    bitrate: 2000,
                    frameRate: 45,
                    layout: layout
                )
            }
        }
        
        @Test("Predefined configurations should work")
        func testPredefinedConfigurations() throws {
            let config720p = try StreamPushConfig.standard720p(pushUrl: "rtmp://example.com/live/stream")
            #expect(config720p.width == 1280)
            #expect(config720p.height == 720)
            #expect(config720p.bitrate == 2000)
            #expect(config720p.frameRate == 30)
            
            let config1080p = try StreamPushConfig.standard1080p(pushUrl: "rtmp://example.com/live/stream")
            #expect(config1080p.width == 1920)
            #expect(config1080p.height == 1080)
            #expect(config1080p.bitrate == 4000)
            #expect(config1080p.frameRate == 30)
        }
    }
    
    // MARK: - StreamLayout Tests
    
    @Suite("StreamLayout Validation Tests")
    struct StreamLayoutTests {
        
        @Test("Valid layout should initialize successfully")
        func testValidLayout() throws {
            let region = try UserRegion(
                userId: "user1",
                x: 0.0, y: 0.0,
                width: 1.0, height: 1.0,
                zOrder: 1,
                alpha: 1.0
            )
            
            let layout = try StreamLayout(
                backgroundColor: "#FF0000",
                userRegions: [region]
            )
            
            #expect(layout.backgroundColor == "#FF0000")
            #expect(layout.userRegions.count == 1)
            #expect(layout.isValid == true)
        }
        
        @Test("Invalid background color should throw error")
        func testInvalidBackgroundColor() throws {
            // Test empty color
            #expect(throws: RealtimeError.self) {
                try StreamLayout(backgroundColor: "", userRegions: [])
            }
            
            // Test color without #
            #expect(throws: RealtimeError.self) {
                try StreamLayout(backgroundColor: "FF0000", userRegions: [])
            }
            
            // Test invalid hex length
            #expect(throws: RealtimeError.self) {
                try StreamLayout(backgroundColor: "#FF00", userRegions: [])
            }
            
            // Test invalid hex characters
            #expect(throws: RealtimeError.self) {
                try StreamLayout(backgroundColor: "#GGHHII", userRegions: [])
            }
        }
        
        @Test("Duplicate user IDs should throw error")
        func testDuplicateUserIds() throws {
            let region1 = try UserRegion(
                userId: "user1",
                x: 0.0, y: 0.0,
                width: 0.5, height: 1.0,
                zOrder: 1,
                alpha: 1.0
            )
            
            let region2 = try UserRegion(
                userId: "user1", // Same user ID
                x: 0.5, y: 0.0,
                width: 0.5, height: 1.0,
                zOrder: 1,
                alpha: 1.0
            )
            
            #expect(throws: RealtimeError.self) {
                try StreamLayout(
                    backgroundColor: "#000000",
                    userRegions: [region1, region2]
                )
            }
        }
        
        @Test("Too many regions should throw error")
        func testTooManyRegions() throws {
            var regions: [UserRegion] = []
            
            // Create 17 regions (exceeds limit of 16)
            for i in 0..<17 {
                let region = try UserRegion(
                    userId: "user\(i)",
                    x: 0.0, y: 0.0,
                    width: 0.1, height: 0.1,
                    zOrder: 1,
                    alpha: 1.0
                )
                regions.append(region)
            }
            
            #expect(throws: RealtimeError.self) {
                try StreamLayout(
                    backgroundColor: "#000000",
                    userRegions: regions
                )
            }
        }
        
        @Test("Layout manipulation should work")
        func testLayoutManipulation() throws {
            let initialLayout = try StreamLayout(backgroundColor: "#000000", userRegions: [])
            
            let region = try UserRegion(
                userId: "user1",
                x: 0.0, y: 0.0,
                width: 1.0, height: 1.0,
                zOrder: 1,
                alpha: 1.0
            )
            
            // Test adding region
            let layoutWithRegion = try initialLayout.addingRegion(region)
            #expect(layoutWithRegion.userRegions.count == 1)
            
            // Test removing region
            let layoutWithoutRegion = try layoutWithRegion.removingRegion(for: "user1")
            #expect(layoutWithoutRegion.userRegions.count == 0)
            
            // Test changing background color
            let layoutWithNewColor = try initialLayout.withBackgroundColor("#FF0000")
            #expect(layoutWithNewColor.backgroundColor == "#FF0000")
        }
        
        @Test("Predefined layouts should work")
        func testPredefinedLayouts() throws {
            // Test single user layout
            let singleUser = StreamLayout.singleUser
            #expect(singleUser.userRegions.count == 1)
            #expect(singleUser.isValid == true)
            
            // Test picture-in-picture layout
            let pip = try StreamLayout.pictureInPicture(mainUserId: "main", overlayUserId: "overlay")
            #expect(pip.userRegions.count == 2)
            #expect(pip.isValid == true)
            
            // Test side-by-side layout
            let sideBySide = try StreamLayout.sideBySide(leftUserId: "left", rightUserId: "right")
            #expect(sideBySide.userRegions.count == 2)
            #expect(sideBySide.isValid == true)
            
            // Test grid layout
            let grid = try StreamLayout.grid(userIds: ["user1", "user2", "user3", "user4"])
            #expect(grid.userRegions.count == 4)
            #expect(grid.isValid == true)
        }
    }
    
    // MARK: - UserRegion Tests
    
    @Suite("UserRegion Validation Tests")
    struct UserRegionTests {
        
        @Test("Valid region should initialize successfully")
        func testValidRegion() throws {
            let region = try UserRegion(
                userId: "user1",
                x: 0.1, y: 0.1,
                width: 0.8, height: 0.8,
                zOrder: 5,
                alpha: 0.9
            )
            
            #expect(region.userId == "user1")
            #expect(region.x == 0.1)
            #expect(region.y == 0.1)
            #expect(region.width == 0.8)
            #expect(region.height == 0.8)
            #expect(region.zOrder == 5)
            #expect(region.alpha == 0.9)
            #expect(region.isValid == true)
        }
        
        @Test("Invalid user ID should throw error")
        func testInvalidUserId() throws {
            // Test empty user ID
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "",
                    x: 0.0, y: 0.0,
                    width: 1.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
            
            // Test whitespace-only user ID
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "   ",
                    x: 0.0, y: 0.0,
                    width: 1.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
            
            // Test user ID too long
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: String(repeating: "a", count: 65),
                    x: 0.0, y: 0.0,
                    width: 1.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
            
            // Test invalid characters
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "user@domain.com",
                    x: 0.0, y: 0.0,
                    width: 1.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
        }
        
        @Test("Invalid position should throw error")
        func testInvalidPosition() throws {
            // Test negative x
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "user1",
                    x: -0.1, y: 0.0,
                    width: 1.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
            
            // Test x > 1.0
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "user1",
                    x: 1.1, y: 0.0,
                    width: 1.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
        }
        
        @Test("Invalid size should throw error")
        func testInvalidSize() throws {
            // Test zero width
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "user1",
                    x: 0.0, y: 0.0,
                    width: 0.0, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
            
            // Test size too small
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "user1",
                    x: 0.0, y: 0.0,
                    width: 0.01, height: 0.01,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
        }
        
        @Test("Region extending beyond bounds should throw error")
        func testRegionBounds() throws {
            // Test region extending beyond right edge
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "user1",
                    x: 0.8, y: 0.0,
                    width: 0.5, height: 1.0,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
            
            // Test region extending beyond bottom edge
            #expect(throws: RealtimeError.self) {
                try UserRegion(
                    userId: "user1",
                    x: 0.0, y: 0.8,
                    width: 1.0, height: 0.5,
                    zOrder: 1,
                    alpha: 1.0
                )
            }
        }
        
        @Test("Region properties should be calculated correctly")
        func testRegionProperties() throws {
            let region = try UserRegion(
                userId: "user1",
                x: 0.2, y: 0.3,
                width: 0.4, height: 0.5,
                zOrder: 1,
                alpha: 1.0
            )
            
            #expect(region.right == 0.6)
            #expect(region.bottom == 0.8)
            #expect(region.area == 0.2)
        }
        
        @Test("Region overlap detection should work")
        func testRegionOverlap() throws {
            let region1 = try UserRegion(
                userId: "user1",
                x: 0.0, y: 0.0,
                width: 0.5, height: 0.5,
                zOrder: 1,
                alpha: 1.0
            )
            
            let region2 = try UserRegion(
                userId: "user2",
                x: 0.3, y: 0.3,
                width: 0.4, height: 0.4,
                zOrder: 1,
                alpha: 1.0
            )
            
            let region3 = try UserRegion(
                userId: "user3",
                x: 0.6, y: 0.6,
                width: 0.3, height: 0.3,
                zOrder: 1,
                alpha: 1.0
            )
            
            // region1: (0.0, 0.0) to (0.5, 0.5)
            // region2: (0.3, 0.3) to (0.7, 0.7) - overlaps with region1
            // region3: (0.6, 0.6) to (0.9, 0.9) - overlaps with region2 but not region1
            
            #expect(region1.overlaps(with: region2) == true)
            #expect(region1.overlaps(with: region3) == false)
            #expect(region2.overlaps(with: region3) == true)
        }
        
        @Test("Point containment should work")
        func testPointContainment() throws {
            let region = try UserRegion(
                userId: "user1",
                x: 0.2, y: 0.3,
                width: 0.4, height: 0.5,
                zOrder: 1,
                alpha: 1.0
            )
            
            #expect(region.contains(pointX: 0.4, pointY: 0.5) == true)
            #expect(region.contains(pointX: 0.1, pointY: 0.5) == false)
            #expect(region.contains(pointX: 0.4, pointY: 0.1) == false)
        }
        
        @Test("Region manipulation should work")
        func testRegionManipulation() throws {
            let originalRegion = try UserRegion(
                userId: "user1",
                x: 0.1, y: 0.1,
                width: 0.3, height: 0.3,
                zOrder: 1,
                alpha: 1.0
            )
            
            // Test moving
            let movedRegion = try originalRegion.moveTo(x: 0.2, y: 0.2)
            #expect(movedRegion.x == 0.2)
            #expect(movedRegion.y == 0.2)
            #expect(movedRegion.width == 0.3)
            #expect(movedRegion.height == 0.3)
            
            // Test resizing
            let resizedRegion = try originalRegion.resizeTo(width: 0.4, height: 0.4)
            #expect(resizedRegion.x == 0.1)
            #expect(resizedRegion.y == 0.1)
            #expect(resizedRegion.width == 0.4)
            #expect(resizedRegion.height == 0.4)
            
            // Test z-order change
            let reorderedRegion = try originalRegion.withZOrder(5)
            #expect(reorderedRegion.zOrder == 5)
            
            // Test alpha change
            let transparentRegion = try originalRegion.withAlpha(0.5)
            #expect(transparentRegion.alpha == 0.5)
        }
    }
}