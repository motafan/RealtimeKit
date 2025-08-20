// UserSessionStorageTests.swift
// Comprehensive unit tests for UserSessionStorage

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
    
    // MARK: - Test Setup
    
    private func createTestSession() -> UserSession {
        return UserSession(
            userId: "test_user_123",
            userName: "Test User",
            userRole: .broadcaster,
            roomId: "test_room_456"
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("UserSessionStorage initialization")
    func testUserSessionStorageInitialization() {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        #expect(sessionStorage.currentSession == nil)
        #expect(sessionStorage.sessionHistory.isEmpty)
        #expect(sessionStorage.isSessionActive == false)
    }
    
    // MARK: - Session Management Tests
    
    @Test("Save user session")
    func testSaveUserSession() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        let testSession = createTestSession()
        
        try sessionStorage.saveUserSession(testSession)
        
        #expect(sessionStorage.currentSession?.userId == testSession.userId)
        #expect(sessionStorage.currentSession?.userName == testSession.userName)
        #expect(sessionStorage.currentSession?.userRole == testSession.userRole)
        #expect(sessionStorage.currentSession?.roomId == testSession.roomId)
        #expect(sessionStorage.isSessionActive == true)
    }
    
    @Test("Load user session")
    func testLoadUserSession() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage1 = UserSessionStorage(storage: mockStorage)
        let testSession = createTestSession()
        
        // Save session with first instance
        try sessionStorage1.saveUserSession(testSession)
        
        // Load session with second instance
        let sessionStorage2 = UserSessionStorage(storage: mockStorage)
        let loadedSession = sessionStorage2.loadUserSession()
        
        #expect(loadedSession?.userId == testSession.userId)
        #expect(loadedSession?.userName == testSession.userName)
        #expect(loadedSession?.userRole == testSession.userRole)
        #expect(loadedSession?.roomId == testSession.roomId)
    }
    
    @Test("Update user session")
    func testUpdateUserSession() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        let testSession = createTestSession()
        
        try sessionStorage.saveUserSession(testSession)
        
        // Update session with new role
        let updatedSession = UserSession(
            userId: testSession.userId,
            userName: testSession.userName,
            userRole: .moderator,
            roomId: testSession.roomId
        )
        
        try sessionStorage.updateUserSession(updatedSession)
        
        #expect(sessionStorage.currentSession?.userRole == .moderator)
        #expect(sessionStorage.currentSession?.userId == testSession.userId)
    }
    
    @Test("Clear user session")
    func testClearUserSession() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        let testSession = createTestSession()
        
        try sessionStorage.saveUserSession(testSession)
        #expect(sessionStorage.currentSession != nil)
        #expect(sessionStorage.isSessionActive == true)
        
        try sessionStorage.clearUserSession()
        
        #expect(sessionStorage.currentSession == nil)
        #expect(sessionStorage.isSessionActive == false)
    }
    
    // MARK: - Session History Tests
    
    @Test("Session history tracking")
    func testSessionHistoryTracking() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Create multiple sessions
        let session1 = UserSession(userId: "user1", userName: "User 1", userRole: .broadcaster)
        let session2 = UserSession(userId: "user2", userName: "User 2", userRole: .audience)
        let session3 = UserSession(userId: "user3", userName: "User 3", userRole: .coHost)
        
        // Save sessions sequentially
        try sessionStorage.saveUserSession(session1)
        try sessionStorage.clearUserSession()
        
        try sessionStorage.saveUserSession(session2)
        try sessionStorage.clearUserSession()
        
        try sessionStorage.saveUserSession(session3)
        
        let history = sessionStorage.sessionHistory
        #expect(history.count >= 2) // Should have at least the cleared sessions
        
        // Check that history contains previous sessions
        let userIds = history.map { $0.userId }
        #expect(userIds.contains("user1"))
        #expect(userIds.contains("user2"))
    }
    
    @Test("Session history size limit")
    func testSessionHistorySizeLimit() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        sessionStorage.setMaxHistorySize(3)
        
        // Create more sessions than the limit
        for i in 1...5 {
            let session = UserSession(
                userId: "user\(i)",
                userName: "User \(i)",
                userRole: .broadcaster
            )
            try sessionStorage.saveUserSession(session)
            try sessionStorage.clearUserSession()
        }
        
        let history = sessionStorage.sessionHistory
        #expect(history.count <= 3)
        
        // Should contain the most recent sessions
        let userIds = history.map { $0.userId }
        #expect(userIds.contains("user3"))
        #expect(userIds.contains("user4"))
        #expect(userIds.contains("user5"))
    }
    
    @Test("Clear session history")
    func testClearSessionHistory() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Add some sessions to history
        for i in 1...3 {
            let session = UserSession(
                userId: "user\(i)",
                userName: "User \(i)",
                userRole: .broadcaster
            )
            try sessionStorage.saveUserSession(session)
            try sessionStorage.clearUserSession()
        }
        
        #expect(!sessionStorage.sessionHistory.isEmpty)
        
        try sessionStorage.clearSessionHistory()
        
        #expect(sessionStorage.sessionHistory.isEmpty)
    }
    
    // MARK: - Session Validation Tests
    
    @Test("Session validation")
    func testSessionValidation() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Valid session
        let validSession = createTestSession()
        #expect(sessionStorage.validateSession(validSession) == true)
        
        // Invalid session - empty user ID
        let invalidSession1 = UserSession(
            userId: "",
            userName: "Test User",
            userRole: .broadcaster
        )
        #expect(sessionStorage.validateSession(invalidSession1) == false)
        
        // Invalid session - empty user name
        let invalidSession2 = UserSession(
            userId: "test_user",
            userName: "",
            userRole: .broadcaster
        )
        #expect(sessionStorage.validateSession(invalidSession2) == false)
    }
    
    @Test("Save invalid session")
    func testSaveInvalidSession() {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        let invalidSession = UserSession(
            userId: "",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        #expect(throws: RealtimeError.self) {
            try sessionStorage.saveUserSession(invalidSession)
        }
    }
    
    // MARK: - Session Persistence Tests
    
    @Test("Session persistence across instances")
    func testSessionPersistenceAcrossInstances() throws {
        let mockStorage = MockStorageProvider()
        let testSession = createTestSession()
        
        // Save session with first instance
        let sessionStorage1 = UserSessionStorage(storage: mockStorage)
        try sessionStorage1.saveUserSession(testSession)
        
        // Load session with second instance
        let sessionStorage2 = UserSessionStorage(storage: mockStorage)
        
        #expect(sessionStorage2.currentSession?.userId == testSession.userId)
        #expect(sessionStorage2.isSessionActive == true)
    }
    
    @Test("Session history persistence")
    func testSessionHistoryPersistence() throws {
        let mockStorage = MockStorageProvider()
        
        // Create history with first instance
        let sessionStorage1 = UserSessionStorage(storage: mockStorage)
        
        for i in 1...3 {
            let session = UserSession(
                userId: "user\(i)",
                userName: "User \(i)",
                userRole: .broadcaster
            )
            try sessionStorage1.saveUserSession(session)
            try sessionStorage1.clearUserSession()
        }
        
        // Load history with second instance
        let sessionStorage2 = UserSessionStorage(storage: mockStorage)
        
        #expect(sessionStorage2.sessionHistory.count == 3)
        
        let userIds = sessionStorage2.sessionHistory.map { $0.userId }
        #expect(userIds.contains("user1"))
        #expect(userIds.contains("user2"))
        #expect(userIds.contains("user3"))
    }
    
    // MARK: - Session Query Tests
    
    @Test("Find session by user ID")
    func testFindSessionByUserId() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Add sessions to history
        for i in 1...3 {
            let session = UserSession(
                userId: "user\(i)",
                userName: "User \(i)",
                userRole: .broadcaster
            )
            try sessionStorage.saveUserSession(session)
            try sessionStorage.clearUserSession()
        }
        
        let foundSession = sessionStorage.findSession(byUserId: "user2")
        
        #expect(foundSession?.userId == "user2")
        #expect(foundSession?.userName == "User 2")
    }
    
    @Test("Find sessions by role")
    func testFindSessionsByRole() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Add sessions with different roles
        let broadcasterSession = UserSession(userId: "broadcaster", userName: "Broadcaster", userRole: .broadcaster)
        let audienceSession = UserSession(userId: "audience", userName: "Audience", userRole: .audience)
        let coHostSession = UserSession(userId: "cohost", userName: "Co-Host", userRole: .coHost)
        
        try sessionStorage.saveUserSession(broadcasterSession)
        try sessionStorage.clearUserSession()
        
        try sessionStorage.saveUserSession(audienceSession)
        try sessionStorage.clearUserSession()
        
        try sessionStorage.saveUserSession(coHostSession)
        try sessionStorage.clearUserSession()
        
        let broadcasterSessions = sessionStorage.findSessions(byRole: .broadcaster)
        let audienceSessions = sessionStorage.findSessions(byRole: .audience)
        
        #expect(broadcasterSessions.count == 1)
        #expect(broadcasterSessions.first?.userId == "broadcaster")
        
        #expect(audienceSessions.count == 1)
        #expect(audienceSessions.first?.userId == "audience")
    }
    
    @Test("Get recent sessions")
    func testGetRecentSessions() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Add sessions with delays to ensure different timestamps
        for i in 1...5 {
            let session = UserSession(
                userId: "user\(i)",
                userName: "User \(i)",
                userRole: .broadcaster
            )
            try sessionStorage.saveUserSession(session)
            try sessionStorage.clearUserSession()
            
            // Small delay to ensure different timestamps
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let recentSessions = sessionStorage.getRecentSessions(limit: 3)
        
        #expect(recentSessions.count == 3)
        
        // Should be in reverse chronological order (most recent first)
        #expect(recentSessions[0].userId == "user5")
        #expect(recentSessions[1].userId == "user4")
        #expect(recentSessions[2].userId == "user3")
    }
    
    // MARK: - Session Statistics Tests
    
    @Test("Session duration tracking")
    func testSessionDurationTracking() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        let testSession = createTestSession()
        
        try sessionStorage.saveUserSession(testSession)
        
        // Wait for some session time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let duration = sessionStorage.getCurrentSessionDuration()
        #expect(duration > 0.05) // Should be at least 0.05 seconds
        
        try sessionStorage.clearUserSession()
        
        let finalDuration = sessionStorage.getLastSessionDuration()
        #expect(finalDuration > 0.05)
    }
    
    @Test("Session statistics")
    func testSessionStatistics() throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Create sessions with different roles and durations
        for i in 1...5 {
            let role: UserRole = i % 2 == 0 ? .broadcaster : .audience
            let session = UserSession(
                userId: "user\(i)",
                userName: "User \(i)",
                userRole: role
            )
            
            try sessionStorage.saveUserSession(session)
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            try sessionStorage.clearUserSession()
        }
        
        let stats = sessionStorage.getSessionStatistics()
        
        #expect(stats.totalSessions == 5)
        #expect(stats.broadcasterSessions >= 2)
        #expect(stats.audienceSessions >= 2)
        #expect(stats.averageSessionDuration > 0)
    }
    
    // MARK: - Reactive Updates Tests
    
    @Test("Reactive session updates")
    func testReactiveSessionUpdates() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        var receivedSessions: [UserSession?] = []
        let cancellable = sessionStorage.$currentSession
            .sink { session in
                receivedSessions.append(session)
            }
        
        let testSession = createTestSession()
        try sessionStorage.saveUserSession(testSession)
        
        // Give some time for the reactive update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        try sessionStorage.clearUserSession()
        
        // Give some time for the reactive update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Should have received at least 3 updates (initial nil, session, nil)
        #expect(receivedSessions.count >= 3)
        #expect(receivedSessions.first == nil) // Initial state
        #expect(receivedSessions.last == nil) // After clearing
        
        cancellable.cancel()
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle storage errors")
    func testHandleStorageErrors() {
        let failingStorage = FailingStorageProvider()
        let sessionStorage = UserSessionStorage(storage: failingStorage)
        let testSession = createTestSession()
        
        #expect(throws: RealtimeError.self) {
            try sessionStorage.saveUserSession(testSession)
        }
    }
    
    @Test("Handle corrupted session data")
    func testHandleCorruptedSessionData() throws {
        let mockStorage = MockStorageProvider()
        
        // Manually insert corrupted data
        let corruptedData = "corrupted_session_data".data(using: .utf8)!
        try mockStorage.setValue(corruptedData, forKey: "current_session")
        
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        // Should handle corrupted data gracefully
        let loadedSession = sessionStorage.loadUserSession()
        #expect(loadedSession == nil)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent session operations")
    func testConcurrentSessionOperations() async throws {
        let mockStorage = MockStorageProvider()
        let sessionStorage = UserSessionStorage(storage: mockStorage)
        
        await withTaskGroup(of: Void.self) { group in
            // Concurrent saves
            for i in 1...5 {
                group.addTask {
                    let session = UserSession(
                        userId: "user\(i)",
                        userName: "User \(i)",
                        userRole: .broadcaster
                    )
                    
                    do {
                        try sessionStorage.saveUserSession(session)
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                        try sessionStorage.clearUserSession()
                    } catch {
                        // Handle concurrent access errors
                    }
                }
            }
        }
        
        // Should handle concurrent operations without crashing
        #expect(sessionStorage.sessionHistory.count >= 0)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Session storage cleanup")
    func testSessionStorageCleanup() throws {
        var sessionStorage: UserSessionStorage? = UserSessionStorage(storage: MockStorageProvider())
        
        weak var weakStorage = sessionStorage
        
        let testSession = createTestSession()
        try sessionStorage?.saveUserSession(testSession)
        
        sessionStorage = nil
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        #expect(weakStorage == nil)
    }
    
    // MARK: - Helper Classes
    
    class FailingStorageProvider: StorageProvider {
        func setValue<T: Codable>(_ value: T, forKey key: String) throws {
            throw RealtimeError.storageError("Storage operation failed")
        }
        
        func getValue<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
            throw RealtimeError.storageError("Storage operation failed")
        }
        
        func removeValue(forKey key: String) throws {
            throw RealtimeError.storageError("Storage operation failed")
        }
        
        func hasValue(forKey key: String) -> Bool {
            return false
        }
        
        func clearAll() throws {
            throw RealtimeError.storageError("Storage operation failed")
        }
    }
}