// UserIdentityManagementTests.swift
// Unit tests for user identity and session management

import Testing
@testable import RealtimeCore

@Suite("User Identity Management Tests")
struct UserIdentityManagementTests {
    
    @Test("User login creates valid session")
    func testUserLogin() async throws {
        let manager = RealtimeManager.shared
        
        // Configure with mock provider
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Test user login
        try await manager.loginUser(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Verify session was created
        let session = manager.currentSession
        #expect(session != nil)
        #expect(session?.userId == "user123")
        #expect(session?.userName == "Test User")
        #expect(session?.userRole == .broadcaster)
        #expect(session?.isInRoom == false)
    }
    
    @Test("User login with invalid parameters throws error")
    func testUserLoginValidation() async throws {
        let manager = RealtimeManager.shared
        
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Test empty user ID
        await #expect(throws: RealtimeError.self) {
            try await manager.loginUser(
                userId: "",
                userName: "Test User",
                userRole: .broadcaster
            )
        }
        
        // Test empty user name
        await #expect(throws: RealtimeError.self) {
            try await manager.loginUser(
                userId: "user123",
                userName: "",
                userRole: .broadcaster
            )
        }
    }
    
    @Test("User logout clears session")
    func testUserLogout() async throws {
        let manager = RealtimeManager.shared
        
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Login user
        try await manager.loginUser(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.currentSession != nil)
        
        // Logout user
        try await manager.logoutUser()
        
        // Verify session was cleared
        #expect(manager.currentSession == nil)
    }
    
    @Test("User permissions are correctly assigned")
    func testUserPermissions() async throws {
        let manager = RealtimeManager.shared
        
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Test broadcaster permissions
        try await manager.loginUser(
            userId: "broadcaster",
            userName: "Broadcaster",
            userRole: .broadcaster
        )
        
        #expect(manager.hasPermission(.audio) == true)
        #expect(manager.hasPermission(.video) == true)
        #expect(manager.hasPermission(.manageRoom) == true)
        #expect(manager.hasPermission(.streamPush) == true)
        
        // Test audience permissions
        try await manager.loginUser(
            userId: "audience",
            userName: "Audience",
            userRole: .audience
        )
        
        #expect(manager.hasPermission(.audio) == false)
        #expect(manager.hasPermission(.video) == false)
        #expect(manager.hasPermission(.manageRoom) == false)
        #expect(manager.hasPermission(.sendMessage) == true)
        #expect(manager.hasPermission(.receiveMessage) == true)
    }
    
    @Test("Role switching validates transitions")
    func testRoleSwitching() async throws {
        let manager = RealtimeManager.shared
        
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Login as audience
        try await manager.loginUser(
            userId: "user123",
            userName: "Test User",
            userRole: .audience
        )
        
        // Join room first
        try await manager.joinRoom(roomId: "room123")
        
        // Valid transition: audience -> coHost
        try await manager.switchUserRole(.coHost)
        #expect(manager.currentSession?.userRole == .coHost)
        
        // Invalid transition: coHost -> moderator (not allowed)
        await #expect(throws: RealtimeError.self) {
            try await manager.switchUserRole(.moderator)
        }
        
        // Valid transition: coHost -> broadcaster
        try await manager.switchUserRole(.broadcaster)
        #expect(manager.currentSession?.userRole == .broadcaster)
    }
    
    @Test("Available role transitions are correct")
    func testAvailableRoleTransitions() async throws {
        let manager = RealtimeManager.shared
        
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Test audience transitions
        try await manager.loginUser(
            userId: "user123",
            userName: "Test User",
            userRole: .audience
        )
        
        let audienceTransitions = manager.getAvailableRoleTransitions()
        #expect(audienceTransitions == [.coHost])
        
        // Test broadcaster transitions
        try await manager.loginUser(
            userId: "user456",
            userName: "Broadcaster",
            userRole: .broadcaster
        )
        
        let broadcasterTransitions = manager.getAvailableRoleTransitions()
        #expect(broadcasterTransitions == [.moderator])
    }
    
    @Test("Session activity updates correctly")
    func testSessionActivityUpdate() async throws {
        let manager = RealtimeManager.shared
        
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        try await manager.loginUser(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        let initialSession = manager.currentSession
        let initialLastActive = initialSession?.lastActiveAt
        
        // Wait a bit and update activity
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        manager.updateSessionActivity()
        
        let updatedSession = manager.currentSession
        let updatedLastActive = updatedSession?.lastActiveAt
        
        #expect(updatedLastActive != nil)
        #expect(updatedLastActive! > initialLastActive!)
    }
    
    @Test("Room joining updates session correctly")
    func testRoomJoiningUpdatesSession() async throws {
        let manager = RealtimeManager.shared
        
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        try await manager.loginUser(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(manager.currentSession?.isInRoom == false)
        
        // Join room
        try await manager.joinRoom(roomId: "room123")
        
        #expect(manager.currentSession?.isInRoom == true)
        #expect(manager.currentSession?.roomId == "room123")
        
        // Leave room
        try await manager.leaveRoom()
        
        #expect(manager.currentSession?.isInRoom == false)
        #expect(manager.currentSession?.roomId == nil)
    }
    
    @Test("User permissions struct works correctly")
    func testUserPermissionsStruct() {
        let broadcasterPermissions = UserPermissions(role: .broadcaster)
        let audiencePermissions = UserPermissions(role: .audience)
        
        // Test broadcaster permissions
        #expect(broadcasterPermissions.hasPermission(.audio) == true)
        #expect(broadcasterPermissions.hasPermission(.video) == true)
        #expect(broadcasterPermissions.hasPermission(.manageRoom) == true)
        
        // Test audience permissions
        #expect(audiencePermissions.hasPermission(.audio) == false)
        #expect(audiencePermissions.hasPermission(.video) == false)
        #expect(audiencePermissions.hasPermission(.manageRoom) == false)
        #expect(audiencePermissions.hasPermission(.sendMessage) == true)
        
        // Test all permissions
        let broadcasterAllPermissions = broadcasterPermissions.allPermissions
        #expect(broadcasterAllPermissions.contains(.audio))
        #expect(broadcasterAllPermissions.contains(.video))
        #expect(broadcasterAllPermissions.contains(.manageRoom))
        
        let audienceAllPermissions = audiencePermissions.allPermissions
        #expect(!audienceAllPermissions.contains(.audio))
        #expect(!audienceAllPermissions.contains(.video))
        #expect(audienceAllPermissions.contains(.sendMessage))
    }
}