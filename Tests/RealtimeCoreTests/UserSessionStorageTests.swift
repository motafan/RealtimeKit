// UserSessionStorageTests.swift
// Tests for UserSessionStorage

import Testing
import Combine
import Foundation
@testable import RealtimeCore

@Suite("UserSessionStorage Tests")
struct UserSessionStorageTests {
    
    // MARK: - Mock Storage Provider
    
    final class MockStorageProvider: StorageProvider {
        private var storage: [String: Data] = [:]
        
        func setValue<T: Codable>(_ value: T, forKey key: String) throws {
            let data = try JSONEncoder().encode(value)
            storage[key] = data
        }
        
        func getValue<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
            guard let data = storage[key] else { return nil }
            return try JSONDecoder().decode(type, from: data)
        }
        
        func removeValue(forKey key: String) throws {
            storage.removeValue(forKey: key)
        }
        
        func hasValue(forKey key: String) -> Bool {
            return storage[key] != nil
        }
        
        func clearAll() throws {
            storage.removeAll()
        }
        
        func reset() {
            storage.removeAll()
        }
    }
    
    // MARK: - Tests
    
    @Test("UserSessionStorage initialization test")
    func testUserSessionStorageInitialization() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Should initialize with no current session
        #expect(sessionStorage.currentSession == nil)
        #expect(sessionStorage.sessionHistory.isEmpty)
        #expect(sessionStorage.hasActiveSession == false)
    }
    
    @Test("UserSessionStorage create session test")
    func testCreateSession() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        let session = try sessionStorage.createSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster,
            roomId: "room456"
        )
        
        #expect(session.userId == "user123")
        #expect(session.userName == "Test User")
        #expect(session.userRole == .broadcaster)
        #expect(session.roomId == "room456")
        #expect(sessionStorage.currentSession?.userId == "user123")
        #expect(sessionStorage.hasActiveSession == true)
    }
    
    @Test("UserSessionStorage update session test")
    func testUpdateSession() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Create initial session
        let initialSession = try sessionStorage.createSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Update session room
        try sessionStorage.updateSessionRoom("room456")
        #expect(sessionStorage.currentSession?.roomId == "room456")
        #expect(sessionStorage.isInRoom == true)
        
        // Update session role
        try sessionStorage.updateSessionRole(.moderator)
        #expect(sessionStorage.currentSession?.userRole == .moderator)
        
        // Session should have updated timestamp
        if let currentLastActive = sessionStorage.currentSession?.lastActiveAt {
            #expect(currentLastActive > initialSession.lastActiveAt)
        }
    }
    
    @Test("UserSessionStorage end session test")
    func testEndSession() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Create session
        _ = try sessionStorage.createSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(sessionStorage.hasActiveSession == true)
        
        // End session
        try sessionStorage.endCurrentSession()
        
        #expect(sessionStorage.currentSession == nil)
        #expect(sessionStorage.hasActiveSession == false)
        #expect(sessionStorage.sessionHistory.count == 1)
        #expect(sessionStorage.sessionHistory.first?.userId == "user123")
    }
    
    @Test("UserSessionStorage session history test")
    func testSessionHistory() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Create multiple sessions
        _ = try sessionStorage.createSession(
            userId: "user1",
            userName: "User One",
            userRole: .broadcaster
        )
        
        try sessionStorage.endCurrentSession()
        
        _ = try sessionStorage.createSession(
            userId: "user2",
            userName: "User Two",
            userRole: .audience
        )
        
        try sessionStorage.endCurrentSession()
        
        // Check history
        #expect(sessionStorage.sessionHistory.count == 2)
        
        // History should be sorted by most recent first
        #expect(sessionStorage.sessionHistory[0].userId == "user2")
        #expect(sessionStorage.sessionHistory[1].userId == "user1")
        
        // Test getting session from history
        let foundSession = sessionStorage.getSessionFromHistory(for: "user1")
        #expect(foundSession?.userId == "user1")
        
        let notFoundSession = sessionStorage.getSessionFromHistory(for: "user3")
        #expect(notFoundSession == nil)
    }
    
    @Test("UserSessionStorage validation test")
    func testSessionValidation() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Test invalid session parameters
        #expect(throws: RealtimeError.self) {
            try sessionStorage.createSession(
                userId: "",
                userName: "Test User",
                userRole: .broadcaster
            )
        }
        
        #expect(throws: RealtimeError.self) {
            try sessionStorage.createSession(
                userId: "user123",
                userName: "",
                userRole: .broadcaster
            )
        }
        
        // Test updating session without active session
        #expect(throws: RealtimeError.self) {
            try sessionStorage.updateSessionRoom("room123")
        }
        
        #expect(throws: RealtimeError.self) {
            try sessionStorage.updateSessionRole(.moderator)
        }
        
        #expect(throws: RealtimeError.self) {
            try sessionStorage.endCurrentSession()
        }
    }
    
    @Test("UserSessionStorage persistence test")
    func testSessionPersistence() async throws {
        let mockStorage = MockStorageProvider()
        
        // Create first instance and create session
        let sessionStorage1 = UserSessionStorage(storage: mockStorage)
        _ = try sessionStorage1.createSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster,
            roomId: "room456"
        )
        
        // Create second instance with same storage - should load persisted session
        let sessionStorage2 = UserSessionStorage(storage: mockStorage)
        
        #expect(sessionStorage2.currentSession?.userId == "user123")
        #expect(sessionStorage2.currentSession?.userName == "Test User")
        #expect(sessionStorage2.currentSession?.userRole == .broadcaster)
        #expect(sessionStorage2.currentSession?.roomId == "room456")
        #expect(sessionStorage2.hasActiveSession == true)
    }
    
    @Test("UserSessionStorage clear operations test")
    func testClearOperations() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Create session and add to history
        _ = try sessionStorage.createSession(
            userId: "user1",
            userName: "User One",
            userRole: .broadcaster
        )
        try sessionStorage.endCurrentSession()
        
        _ = try sessionStorage.createSession(
            userId: "user2",
            userName: "User Two",
            userRole: .audience
        )
        
        #expect(sessionStorage.hasActiveSession == true)
        #expect(sessionStorage.sessionHistory.count == 1)
        
        // Clear history only
        try sessionStorage.clearHistory()
        #expect(sessionStorage.sessionHistory.isEmpty)
        #expect(sessionStorage.hasActiveSession == true) // Current session should remain
        
        // Clear all
        try sessionStorage.clearAll()
        #expect(sessionStorage.currentSession == nil)
        #expect(sessionStorage.sessionHistory.isEmpty)
        #expect(sessionStorage.hasActiveSession == false)
    }
    
    @Test("UserSessionStorage convenience properties test")
    func testConvenienceProperties() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Test with no session
        #expect(sessionStorage.currentUserId == nil)
        #expect(sessionStorage.currentUserName == nil)
        #expect(sessionStorage.currentUserRole == nil)
        #expect(sessionStorage.isInRoom == false)
        #expect(sessionStorage.currentRoomId == nil)
        
        // Create session
        _ = try sessionStorage.createSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster,
            roomId: "room456"
        )
        
        // Test with active session
        #expect(sessionStorage.currentUserId == "user123")
        #expect(sessionStorage.currentUserName == "Test User")
        #expect(sessionStorage.currentUserRole == .broadcaster)
        #expect(sessionStorage.isInRoom == true)
        #expect(sessionStorage.currentRoomId == "room456")
    }
    
    @Test("UserSessionStorage session validation logic test")
    func testSessionValidationLogic() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Valid session
        let validSession = UserSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster
        )
        #expect(sessionStorage.validateSession(validSession) == true)
        
        // Invalid session - empty userId
        let invalidSession1 = UserSession(
            userId: "",
            userName: "Test User",
            userRole: .broadcaster
        )
        #expect(sessionStorage.validateSession(invalidSession1) == false)
        
        // Invalid session - empty userName
        let invalidSession2 = UserSession(
            userId: "user123",
            userName: "",
            userRole: .broadcaster
        )
        #expect(sessionStorage.validateSession(invalidSession2) == false)
        
        // Invalid session - future created date
        let futureDate = Date().addingTimeInterval(3600) // 1 hour in future
        let invalidSession3 = UserSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster,
            createdAt: futureDate,
            lastActiveAt: Date()
        )
        #expect(sessionStorage.validateSession(invalidSession3) == false)
        
        // Invalid session - too old
        let oldDate = Date().addingTimeInterval(-31 * 24 * 60 * 60) // 31 days ago
        let invalidSession4 = UserSession(
            userId: "user123",
            userName: "Test User",
            userRole: .broadcaster,
            lastActiveAt: oldDate
        )
        #expect(sessionStorage.validateSession(invalidSession4) == false)
    }
}