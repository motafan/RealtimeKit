// UserSessionStorage.swift
// User session storage manager with security and validation

import Foundation
import Combine

/// Storage manager for user sessions with security and validation support
public final class UserSessionStorage: ObservableObject {
    
    // MARK: - Storage Keys
    private enum StorageKeys {
        static let currentSession = "user.session.current"
        static let sessionHistory = "user.session.history"
        static let sessionVersion = "user.session.version"
    }
    
    // MARK: - Properties
    private let storage: StorageProvider
    private let currentVersion = 1
    private let maxHistoryCount = 10 // Maximum number of sessions to keep in history
    
    /// Current user session as a published property
    @Published public private(set) var currentSession: UserSession?
    
    /// Session history (recent sessions)
    @Published public private(set) var sessionHistory: [UserSession] = []
    
    // MARK: - Initialization
    
    /// Initialize user session storage
    /// - Parameter storage: Storage provider to use
    public init(storage: StorageProvider = UserDefaultsStorageProvider()) {
        self.storage = storage
        
        // Load current session from storage
        loadCurrentSession()
        
        // Load session history
        loadSessionHistory()
        
        // Perform migration if needed
        performMigrationIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Create and store a new user session
    /// - Parameters:
    ///   - userId: User identifier
    ///   - userName: User display name
    ///   - userRole: User role
    ///   - roomId: Optional room identifier
    /// - Returns: Created user session
    /// - Throws: RealtimeError if creation fails
    public func createSession(
        userId: String,
        userName: String,
        userRole: UserRole,
        roomId: String? = nil
    ) throws -> UserSession {
        // Validate input parameters
        guard !userId.isEmpty else {
            throw RealtimeError.requiredParameterMissing("userId")
        }
        
        guard !userName.isEmpty else {
            throw RealtimeError.requiredParameterMissing("userName")
        }
        
        // Create new session
        let newSession = UserSession(
            userId: userId,
            userName: userName,
            userRole: userRole,
            roomId: roomId
        )
        
        // Archive current session to history if exists
        if let existingSession = currentSession {
            addToHistory(existingSession)
        }
        
        // Set as current session
        currentSession = newSession
        
        // Save to storage
        try saveCurrentSession()
        
        return newSession
    }
    
    /// Update the current session
    /// - Parameter session: Updated session
    /// - Throws: RealtimeError if update fails
    public func updateCurrentSession(_ session: UserSession) throws {
        guard currentSession != nil else {
            throw RealtimeError.noActiveSession
        }
        
        currentSession = session.updateLastActive()
        try saveCurrentSession()
    }
    
    /// Update current session with new room
    /// - Parameter roomId: New room identifier
    /// - Throws: RealtimeError if update fails
    public func updateSessionRoom(_ roomId: String?) throws {
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        let updatedSession = session.withRoom(roomId)
        try updateCurrentSession(updatedSession)
    }
    
    /// Update current session with new role
    /// - Parameter role: New user role
    /// - Throws: RealtimeError if update fails
    public func updateSessionRole(_ role: UserRole) throws {
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        let updatedSession = session.withRole(role)
        try updateCurrentSession(updatedSession)
    }
    
    /// End the current session and move it to history
    /// - Throws: RealtimeError if ending fails
    public func endCurrentSession() throws {
        guard let session = currentSession else {
            throw RealtimeError.noActiveSession
        }
        
        // Add to history
        addToHistory(session)
        
        // Clear current session
        currentSession = nil
        
        // Save changes
        try saveCurrentSession()
        try saveSessionHistory()
    }
    
    /// Get session by user ID from history
    /// - Parameter userId: User identifier to search for
    /// - Returns: Most recent session for the user, if found
    public func getSessionFromHistory(for userId: String) -> UserSession? {
        return sessionHistory.first { $0.userId == userId }
    }
    
    /// Get all sessions for a specific user from history
    /// - Parameter userId: User identifier to search for
    /// - Returns: Array of sessions for the user, sorted by most recent first
    public func getAllSessionsFromHistory(for userId: String) -> [UserSession] {
        return sessionHistory
            .filter { $0.userId == userId }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }
    
    /// Clear session history
    /// - Throws: RealtimeError if clearing fails
    public func clearHistory() throws {
        sessionHistory.removeAll()
        try saveSessionHistory()
    }
    
    /// Clear all stored data (current session and history)
    /// - Throws: RealtimeError if clearing fails
    public func clearAll() throws {
        currentSession = nil
        sessionHistory.removeAll()
        
        try storage.removeValue(forKey: StorageKeys.currentSession)
        try storage.removeValue(forKey: StorageKeys.sessionHistory)
        try storage.removeValue(forKey: StorageKeys.sessionVersion)
    }
    
    /// Validate session integrity
    /// - Parameter session: Session to validate
    /// - Returns: True if session is valid
    public func validateSession(_ session: UserSession) -> Bool {
        // Check required fields
        guard !session.userId.isEmpty,
              !session.userName.isEmpty,
              !session.sessionId.isEmpty else {
            return false
        }
        
        // Check timestamps
        guard session.createdAt <= session.lastActiveAt else {
            return false
        }
        
        // Check session age (sessions older than 30 days are considered invalid)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        guard session.lastActiveAt > thirtyDaysAgo else {
            return false
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentSession() {
        do {
            if let session = try storage.getValue(UserSession.self, forKey: StorageKeys.currentSession) {
                // Validate session before loading
                if validateSession(session) {
                    currentSession = session
                } else {
                    print("UserSessionStorage: Current session is invalid, clearing")
                    try? storage.removeValue(forKey: StorageKeys.currentSession)
                }
            }
        } catch {
            print("UserSessionStorage: Failed to load current session: \(error)")
        }
    }
    
    private func loadSessionHistory() {
        do {
            if let history = try storage.getValue([UserSession].self, forKey: StorageKeys.sessionHistory) {
                // Filter out invalid sessions and limit count
                sessionHistory = history
                    .filter { validateSession($0) }
                    .sorted { $0.lastActiveAt > $1.lastActiveAt }
                    .prefix(maxHistoryCount)
                    .map { $0 }
            }
        } catch {
            print("UserSessionStorage: Failed to load session history: \(error)")
        }
    }
    
    private func saveCurrentSession() throws {
        do {
            if let session = currentSession {
                try storage.setValue(session, forKey: StorageKeys.currentSession)
            } else {
                try storage.removeValue(forKey: StorageKeys.currentSession)
            }
        } catch {
            throw RealtimeError.storageError("Failed to save current session: \(error.localizedDescription)")
        }
    }
    
    private func saveSessionHistory() throws {
        do {
            try storage.setValue(sessionHistory, forKey: StorageKeys.sessionHistory)
        } catch {
            throw RealtimeError.storageError("Failed to save session history: \(error.localizedDescription)")
        }
    }
    
    private func addToHistory(_ session: UserSession) {
        // Remove any existing session for the same user
        sessionHistory.removeAll { $0.userId == session.userId }
        
        // Add to beginning of history
        sessionHistory.insert(session, at: 0)
        
        // Limit history size
        if sessionHistory.count > maxHistoryCount {
            sessionHistory = Array(sessionHistory.prefix(maxHistoryCount))
        }
        
        // Save to storage
        try? saveSessionHistory()
    }
    
    private func performMigrationIfNeeded() {
        do {
            let storedVersion = try storage.getValue(Int.self, forKey: StorageKeys.sessionVersion) ?? 0
            if storedVersion < currentVersion {
                performMigration(from: storedVersion, to: currentVersion)
                try storage.setValue(currentVersion, forKey: StorageKeys.sessionVersion)
            }
        } catch {
            print("UserSessionStorage: Migration check failed: \(error)")
        }
    }
    
    private func performMigration(from oldVersion: Int, to newVersion: Int) {
        print("UserSessionStorage: Migrating from version \(oldVersion) to \(newVersion)")
        
        switch oldVersion {
        case 0:
            // Initial migration - clean up any invalid sessions
            if let session = currentSession, !validateSession(session) {
                currentSession = nil
                try? storage.removeValue(forKey: StorageKeys.currentSession)
            }
            
            // Clean up invalid sessions from history
            sessionHistory = sessionHistory.filter { validateSession($0) }
            try? saveSessionHistory()
            
        default:
            break
        }
    }
}

// MARK: - Convenience Extensions

public extension UserSessionStorage {
    
    /// Check if there is an active session
    var hasActiveSession: Bool {
        return currentSession != nil
    }
    
    /// Get current user ID if session exists
    var currentUserId: String? {
        return currentSession?.userId
    }
    
    /// Get current user name if session exists
    var currentUserName: String? {
        return currentSession?.userName
    }
    
    /// Get current user role if session exists
    var currentUserRole: UserRole? {
        return currentSession?.userRole
    }
    
    /// Check if current user is in a room
    var isInRoom: Bool {
        return currentSession?.isInRoom ?? false
    }
    
    /// Get current room ID if user is in a room
    var currentRoomId: String? {
        return currentSession?.roomId
    }
}

// MARK: - SwiftUI Binding Support

#if canImport(SwiftUI)
import SwiftUI

public extension UserSessionStorage {
    
    /// Binding for current session (read-only)
    var currentSessionBinding: Binding<UserSession?> {
        Binding(
            get: { self.currentSession },
            set: { _ in } // Read-only binding
        )
    }
}
#endif

// MARK: - Legacy Method Support for RealtimeManager

public extension UserSessionStorage {
    
    /// Save user session (legacy method for RealtimeManager compatibility)
    /// - Parameter session: User session to save
    func saveUserSession(_ session: UserSession) {
        try? updateCurrentSession(session)
    }
    
    /// Load user session (legacy method for RealtimeManager compatibility)
    /// - Returns: Current user session
    func loadUserSession() -> UserSession? {
        return currentSession
    }
    
    /// Clear user session (legacy method for RealtimeManager compatibility)
    func clearUserSession() {
        try? endCurrentSession()
    }
}