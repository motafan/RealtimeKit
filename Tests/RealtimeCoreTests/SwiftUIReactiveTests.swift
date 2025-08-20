// SwiftUIReactiveTests.swift
// Unit tests for SwiftUI reactive support and Combine integration

import Testing
import Combine
@testable import RealtimeCore

@Suite("SwiftUI Reactive Support Tests")
struct SwiftUIReactiveTests {
    
    @MainActor
    func setupManager() async throws -> RealtimeManager {
        let manager = RealtimeManager.shared
        let config = RealtimeConfig(appId: "test-app-id")
        try await manager.configure(provider: .mock, config: config)
        
        // Login user first
        try await manager.loginUser(
            userId: "test-user",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        return manager
    }
    
    @Test("Published properties are properly exposed")
    @MainActor
    func testPublishedProperties() async throws {
        let manager = try await setupManager()
        
        // Test that all @Published properties are accessible
        #expect(manager.currentSession != nil)
        #expect(manager.audioSettings != AudioSettings())
        #expect(manager.connectionState == .connected)
        #expect(manager.isInitialized == true)
        #expect(manager.currentProvider == .mock)
        #expect(manager.availableProviders.contains(.mock))
        #expect(manager.providerSwitchInProgress == false)
    }
    
    @Test("Connection state publisher works correctly")
    @MainActor
    func testConnectionStatePublisher() async throws {
        let manager = try await setupManager()
        var receivedStates: [ConnectionState] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to connection state changes
        manager.connectionStatePublisher
            .sink { state in
                receivedStates.append(state)
            }
            .store(in: &cancellables)
        
        // Initial state should be received
        #expect(receivedStates.contains(.connected))
        
        // Simulate state change
        manager.connectionState = .reconnecting
        
        // Wait for publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        #expect(receivedStates.contains(.reconnecting))
    }
    
    @Test("Audio settings publisher works correctly")
    @MainActor
    func testAudioSettingsPublisher() async throws {
        let manager = try await setupManager()
        var receivedSettings: [AudioSettings] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to audio settings changes
        manager.audioSettingsPublisher
            .sink { settings in
                receivedSettings.append(settings)
            }
            .store(in: &cancellables)
        
        // Change audio settings
        try await manager.setAudioMixingVolume(75)
        
        // Wait for publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should have received updated settings
        let latestSettings = receivedSettings.last
        #expect(latestSettings?.audioMixingVolume == 75)
    }
    
    @Test("Volume infos publisher works correctly")
    @MainActor
    func testVolumeInfosPublisher() async throws {
        let manager = try await setupManager()
        var receivedVolumeInfos: [[UserVolumeInfo]] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to volume info changes
        manager.volumeInfosPublisher
            .sink { volumeInfos in
                receivedVolumeInfos.append(volumeInfos)
            }
            .store(in: &cancellables)
        
        // Simulate volume update
        let volumeInfo = UserVolumeInfo(userId: "test-user", volume: 0.8, isSpeaking: true)
        manager.volumeInfos = [volumeInfo]
        
        // Wait for publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should have received volume info
        let latestVolumeInfos = receivedVolumeInfos.last
        #expect(latestVolumeInfos?.first?.userId == "test-user")
        #expect(latestVolumeInfos?.first?.volume == 0.8)
    }
    
    @Test("Speaking users publisher works correctly")
    @MainActor
    func testSpeakingUsersPublisher() async throws {
        let manager = try await setupManager()
        var receivedSpeakingUsers: [Set<String>] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to speaking users changes
        manager.speakingUsersPublisher
            .sink { speakingUsers in
                receivedSpeakingUsers.append(speakingUsers)
            }
            .store(in: &cancellables)
        
        // Simulate speaking users update
        manager.speakingUsers = ["user1", "user2"]
        
        // Wait for publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should have received speaking users
        let latestSpeakingUsers = receivedSpeakingUsers.last
        #expect(latestSpeakingUsers?.contains("user1") == true)
        #expect(latestSpeakingUsers?.contains("user2") == true)
    }
    
    @Test("System readiness publisher works correctly")
    @MainActor
    func testSystemReadinessPublisher() async throws {
        let manager = try await setupManager()
        var receivedReadiness: [Bool] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to system readiness changes
        manager.systemReadinessPublisher
            .sink { isReady in
                receivedReadiness.append(isReady)
            }
            .store(in: &cancellables)
        
        // Wait for initial state
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should be ready initially
        #expect(receivedReadiness.contains(true))
        
        // Simulate provider switch in progress
        manager.providerSwitchInProgress = true
        
        // Wait for publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should not be ready during provider switch
        #expect(receivedReadiness.contains(false))
    }
    
    @Test("Audio state summary publisher works correctly")
    @MainActor
    func testAudioStateSummaryPublisher() async throws {
        let manager = try await setupManager()
        var receivedSummaries: [AudioStateSummary] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to audio state summary changes
        manager.audioStateSummaryPublisher
            .sink { summary in
                receivedSummaries.append(summary)
            }
            .store(in: &cancellables)
        
        // Change audio settings
        try await manager.updateAudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 80,
            localAudioStreamActive: false
        )
        
        // Wait for publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should have received updated summary
        let latestSummary = receivedSummaries.last
        #expect(latestSummary?.isMuted == true)
        #expect(latestSummary?.mixingVolume == 80)
        #expect(latestSummary?.isStreamActive == false)
        #expect(latestSummary?.isAudioEnabled == false)
    }
    
    @Test("Observation methods work correctly")
    @MainActor
    func testObservationMethods() async throws {
        let manager = try await setupManager()
        var connectionStateReceived: ConnectionState?
        var audioSettingsReceived: AudioSettings?
        var speakingUsersReceived: Set<String>?
        var systemReadinessReceived: Bool?
        
        var cancellables = Set<AnyCancellable>()
        
        // Set up observations
        manager.observeConnectionState { state in
            connectionStateReceived = state
        }.store(in: &cancellables)
        
        manager.observeAudioSettings { settings in
            audioSettingsReceived = settings
        }.store(in: &cancellables)
        
        manager.observeSpeakingUsers { users in
            speakingUsersReceived = users
        }.store(in: &cancellables)
        
        manager.observeSystemReadiness { isReady in
            systemReadinessReceived = isReady
        }.store(in: &cancellables)
        
        // Wait for initial values
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Verify initial values were received
        #expect(connectionStateReceived == .connected)
        #expect(audioSettingsReceived != nil)
        #expect(speakingUsersReceived != nil)
        #expect(systemReadinessReceived == true)
    }
    
    @Test("Debounced volume publisher works correctly")
    @MainActor
    func testDebouncedVolumePublisher() async throws {
        let manager = try await setupManager()
        var receivedUpdates: [[UserVolumeInfo]] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to debounced volume updates
        manager.debouncedVolumePublisher(interval: 0.05)
            .sink { volumeInfos in
                receivedUpdates.append(volumeInfos)
            }
            .store(in: &cancellables)
        
        // Send multiple rapid updates
        let volumeInfo1 = UserVolumeInfo(userId: "user1", volume: 0.5, isSpeaking: true)
        let volumeInfo2 = UserVolumeInfo(userId: "user1", volume: 0.7, isSpeaking: true)
        let volumeInfo3 = UserVolumeInfo(userId: "user1", volume: 0.9, isSpeaking: true)
        
        manager.volumeInfos = [volumeInfo1]
        manager.volumeInfos = [volumeInfo2]
        manager.volumeInfos = [volumeInfo3]
        
        // Wait for debounce period
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should have received fewer updates due to debouncing
        #expect(receivedUpdates.count < 3)
        
        // Last update should be the final value
        let lastUpdate = receivedUpdates.last?.first
        #expect(lastUpdate?.volume == 0.9)
    }
    
    @Test("Throttled audio state publisher works correctly")
    @MainActor
    func testThrottledAudioStatePublisher() async throws {
        let manager = try await setupManager()
        var receivedSummaries: [AudioStateSummary] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to throttled audio state updates
        manager.throttledAudioStatePublisher(interval: 0.05)
            .sink { summary in
                receivedSummaries.append(summary)
            }
            .store(in: &cancellables)
        
        // Send multiple rapid updates
        try await manager.setAudioMixingVolume(50)
        try await manager.setPlaybackSignalVolume(60)
        try await manager.setRecordingSignalVolume(70)
        
        // Wait for throttle period
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should have received throttled updates
        #expect(receivedSummaries.count >= 1)
        
        // Last update should reflect final state
        let lastSummary = receivedSummaries.last
        #expect(lastSummary?.recordingVolume == 70)
    }
    
    @Test("Combined state publisher works correctly")
    @MainActor
    func testCombinedStatePublisher() async throws {
        let manager = try await setupManager()
        var receivedStatuses: [RealtimeSystemStatus] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to combined state updates
        manager.combinedStatePublisher()
            .sink { status in
                receivedStatuses.append(status)
            }
            .store(in: &cancellables)
        
        // Wait for initial state
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should have received initial status
        let initialStatus = receivedStatuses.first
        #expect(initialStatus?.isInitialized == true)
        #expect(initialStatus?.hasActiveSession == true)
        #expect(initialStatus?.isReady == true)
        
        // Change connection state
        manager.connectionState = .failed
        
        // Wait for update
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Should have received updated status
        let updatedStatus = receivedStatuses.last
        #expect(updatedStatus?.connectionState == .failed)
        #expect(updatedStatus?.isReady == false)
        #expect(updatedStatus?.hasIssues == true)
    }
    
    @Test("Audio state summary calculations work correctly")
    func testAudioStateSummaryCalculations() {
        let summary = AudioStateSummary(
            isMuted: false,
            isStreamActive: true,
            mixingVolume: 80,
            playbackVolume: 60,
            recordingVolume: 40
        )
        
        #expect(summary.isAudioEnabled == true)
        #expect(summary.averageVolume == 60) // (80 + 60 + 40) / 3 = 60
        
        let mutedSummary = AudioStateSummary(
            isMuted: true,
            isStreamActive: true,
            mixingVolume: 100,
            playbackVolume: 100,
            recordingVolume: 100
        )
        
        #expect(mutedSummary.isAudioEnabled == false)
        #expect(mutedSummary.averageVolume == 100)
    }
}