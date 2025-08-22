import Foundation
@testable import RealtimeCore

// Simple test to verify basic imports work
let version = RealtimeKitVersion.current
print("RealtimeKit version: \(version)")

let userRole = UserRole.broadcaster
print("User role: \(userRole.displayName)")

let config = RTCConfig(appId: "test")
print("Config created: \(config.appId)")