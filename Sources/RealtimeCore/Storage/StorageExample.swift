// StorageExample.swift
// Example usage of RealtimeKit storage system

import Foundation
import Combine

/// Example demonstrating RealtimeKit storage system usage
public class StorageExample {
    
    private let audioStorage: AudioSettingsStorage
    private let sessionStorage: UserSessionStorage
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // Initialize storage managers
        self.audioStorage = AudioSettingsStorage()
        self.sessionStorage = UserSessionStorage()
        
        // Setup reactive observations
        setupObservations()
    }
    
    /// Example: Create a user session and configure audio settings
    public func exampleUsage() throws {
        print("=== RealtimeKit Storage Example ===")
        
        // 1. Create a user session
        let session = try sessionStorage.createSession(
            userId: "user123",
            userName: "张三",
            userRole: .broadcaster,
            roomId: "room456"
        )
        
        print("✅ Created session for user: \(session.userName)")
        print("   - User ID: \(session.userId)")
        print("   - Role: \(session.userRole.displayName)")
        print("   - Room: \(session.roomId ?? "None")")
        
        // 2. Configure audio settings
        try audioStorage.updateAudioMixingVolume(75)
        try audioStorage.updatePlaybackSignalVolume(80)
        audioStorage.updateMicrophoneMuted(true)
        
        print("✅ Updated audio settings:")
        print("   - Audio mixing volume: \(audioStorage.currentSettings.audioMixingVolume)")
        print("   - Playback volume: \(audioStorage.currentSettings.playbackSignalVolume)")
        print("   - Microphone muted: \(audioStorage.currentSettings.microphoneMuted)")
        
        // 3. Update session (join room)
        try sessionStorage.updateSessionRoom("newRoom789")
        print("✅ Updated session room to: \(sessionStorage.currentRoomId ?? "None")")
        
        // 4. Change user role
        try sessionStorage.updateSessionRole(.moderator)
        print("✅ Updated user role to: \(sessionStorage.currentUserRole?.displayName ?? "None")")
        
        // 5. End session
        try sessionStorage.endCurrentSession()
        print("✅ Session ended and moved to history")
        print("   - History count: \(sessionStorage.sessionHistory.count)")
    }
    
    /// Example: Using RealtimeStorage property wrapper
    public func exampleRealtimeStorage() {
        print("\n=== RealtimeStorage Property Wrapper Example ===")
        
        // Using RealtimeStorage for custom settings
        @RealtimeStorage("example.customSetting", defaultValue: "default")
        var customSetting: String
        
        @RealtimeStorage("example.counter", defaultValue: 0)
        var counter: Int
        
        print("Initial custom setting: \(customSetting)")
        print("Initial counter: \(counter)")
        
        // Update values (automatically persisted)
        customSetting = "updated value"
        counter = 42
        
        print("Updated custom setting: \(customSetting)")
        print("Updated counter: \(counter)")
        
        // Observe changes
        $customSetting
            .sink { newValue in
                print("Custom setting changed to: \(newValue)")
            }
            .store(in: &cancellables)
        
        $counter
            .sink { newValue in
                print("Counter changed to: \(newValue)")
            }
            .store(in: &cancellables)
    }
    
    /// Example: Storage with custom provider
    public func exampleCustomStorage() throws {
        print("\n=== Custom Storage Provider Example ===")
        
        // Create custom storage provider (in-memory for this example)
        class InMemoryStorageProvider: StorageProvider {
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
        }
        
        let customProvider = InMemoryStorageProvider()
        let customAudioStorage = AudioSettingsStorage(storage: customProvider)
        
        // Use custom storage
        try customAudioStorage.updateAudioMixingVolume(90)
        print("✅ Custom storage audio volume: \(customAudioStorage.currentSettings.audioMixingVolume)")
        
        // Verify it's using in-memory storage
        let anotherInstance = AudioSettingsStorage(storage: customProvider)
        print("✅ Another instance volume: \(anotherInstance.currentSettings.audioMixingVolume)")
    }
    
    private func setupObservations() {
        // Observe audio settings changes
        audioStorage.$currentSettings
            .sink { settings in
                print("🔊 Audio settings updated: muted=\(settings.microphoneMuted), volume=\(settings.audioMixingVolume)")
            }
            .store(in: &cancellables)
        
        // Observe session changes
        sessionStorage.$currentSession
            .sink { session in
                if let session = session {
                    print("👤 Session updated: \(session.userName) in room \(session.roomId ?? "none")")
                } else {
                    print("👤 No active session")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI Integration Example

#if canImport(SwiftUI)
import SwiftUI

/// Example SwiftUI view using RealtimeKit storage
@available(iOS 13.0, macOS 10.15, *)
public struct AudioSettingsView: View {
    @ObservedObject private var audioStorage = AudioSettingsStorage()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("音频设置")
                .font(.title)
            
            // Microphone mute toggle
            Toggle("静音麦克风", isOn: audioStorage.microphoneMutedBinding)
            
            // Volume sliders
            VStack {
                Text("混音音量: \(audioStorage.currentSettings.audioMixingVolume)")
                Slider(
                    value: Binding(
                        get: { Double(audioStorage.currentSettings.audioMixingVolume) },
                        set: { try? audioStorage.updateAudioMixingVolume(Int($0)) }
                    ),
                    in: 0...100,
                    step: 1
                )
            }
            
            VStack {
                Text("播放音量: \(audioStorage.currentSettings.playbackSignalVolume)")
                Slider(
                    value: Binding(
                        get: { Double(audioStorage.currentSettings.playbackSignalVolume) },
                        set: { try? audioStorage.updatePlaybackSignalVolume(Int($0)) }
                    ),
                    in: 0...100,
                    step: 1
                )
            }
            
            // Reset button
            Button("重置为默认设置") {
                audioStorage.resetToDefaults()
            }
        }
        .padding()
    }
}
#endif