import Foundation
import RealtimeCore

/// User preferences model demonstrating @RealtimeStorage usage
struct UserPreferences: Codable, Equatable {
    var lastUserId: String = ""
    var lastUserName: String = ""
    var lastVolume: Int = 50
    var preferredLanguage: SupportedLanguage? = nil
    var enableVolumeIndicator: Bool = true
    var enableNotifications: Bool = true
    var lastLoginTime: Date? = nil
    
    init() {
        // Default initialization
    }
    
    init(
        lastUserId: String = "",
        lastUserName: String = "",
        lastVolume: Int = 50,
        preferredLanguage: SupportedLanguage? = nil,
        enableVolumeIndicator: Bool = true,
        enableNotifications: Bool = true,
        lastLoginTime: Date? = nil
    ) {
        self.lastUserId = lastUserId
        self.lastUserName = lastUserName
        self.lastVolume = max(0, min(100, lastVolume))
        self.preferredLanguage = preferredLanguage
        self.enableVolumeIndicator = enableVolumeIndicator
        self.enableNotifications = enableNotifications
        self.lastLoginTime = lastLoginTime
    }
    
    // Helper methods for updating preferences
    mutating func updateLastLogin() {
        lastLoginTime = Date()
    }
    
    mutating func updateUserInfo(userId: String, userName: String) {
        lastUserId = userId
        lastUserName = userName
        updateLastLogin()
    }
    
    mutating func updateVolume(_ volume: Int) {
        lastVolume = max(0, min(100, volume))
    }
}