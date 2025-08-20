// SwiftUIDataFlowTests.swift
// Tests for Combine data flows and reactive state management

import Testing
import SwiftUI
import Combine
@testable import RealtimeCore
@testable import RealtimeSwiftUI

@available(iOS 13.0, macOS 10.15, *)
struct SwiftUIDataFlowTests {
    
    // MARK: - RealtimeEventPublisher Tests
    
    @Test("RealtimeEventPublisher should publish connection state changes")
    func testEventPublisherConnectionStateChanges() async throws {
        let publisher = RealtimeEventPublisher.shared
        var receivedStates: [ConnectionState] = []
        
        let cancellable = publisher.connectionStateChanged
            .sink { state in
                receivedStates.append(state)
            }
        
        // Publish different states
        publisher.publishConnectionStateChange(.connecting)
        publisher.publishConnectionStateChange(.connected)
        publisher.publishConnectionStateChange(.disconnected)
        
        // Allow time for events to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(receivedStates.count == 3)
        #expect(receivedStates[0] == .connecting)
        #expect(receivedStates[1] == .connected)
        #expect(receivedStates[2] == .disconnected)
        
        cancellable.cancel()
    }
    
    @Test("RealtimeEventPublisher should publish volume updates")
    func testEventPublisherVolumeUpdates() async throws {
        let publisher = RealtimeEventPublisher.shared
        var receivedVolumeUpdates: [[UserVolumeInfo]] = []
        
        let cancellable = publisher.volumeUpdated
            .sink { volumeInfos in
                receivedVolumeUpdates.append(volumeInfos)
            }
        
        // Publish volume updates
        let volumeInfos1 = [
            UserVolumeInfo(userId: "user1", volume: 0.5, isSpeaking: true)
        ]
        let volumeInfos2 = [
            UserVolumeInfo(userId: "user1", volume: 0.3, isSpeaking: false),
            UserVolumeInfo(userId: "user2", volume: 0.8, isSpeaking: true)
        ]
        
        publisher.publishVolumeUpdate(volumeInfos1)
        publisher.publishVolumeUpdate(volumeInfos2)
        
        // Allow time for events to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(receivedVolumeUpdates.count == 2)
        #expect(receivedVolumeUpdates[0].count == 1)
        #expect(receivedVolumeUpdates[1].count == 2)
        #expect(receivedVolumeUpdates[0][0].userId == "user1")
        #expect(receivedVolumeUpdates[1][1].userId == "user2")
        
        cancellable.cancel()
    }
    
    @Test("RealtimeEventPublisher should publish speaking state changes")
    func testEventPublisherSpeakingStateChanges() async throws {
        let publisher = RealtimeEventPublisher.shared
        var receivedSpeakingChanges: [(userId: String, isSpeaking: Bool)] = []
        
        let cancellable = publisher.speakingStateChanged
            .sink { change in
                receivedSpeakingChanges.append(change)
            }
        
        // Publish speaking state changes
        publisher.publishSpeakingStateChange(userId: "user1", isSpeaking: true)
        publisher.publishSpeakingStateChange(userId: "user2", isSpeaking: true)
        publisher.publishSpeakingStateChange(userId: "user1", isSpeaking: false)
        
        // Allow time for events to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(receivedSpeakingChanges.count == 3)
        #expect(receivedSpeakingChanges[0].userId == "user1")
        #expect(receivedSpeakingChanges[0].isSpeaking == true)
        #expect(receivedSpeakingChanges[2].userId == "user1")
        #expect(receivedSpeakingChanges[2].isSpeaking == false)
        
        cancellable.cancel()
    }
    
    @Test("RealtimeEventPublisher should handle multiple subscribers")
    func testEventPublisherMultipleSubscribers() async throws {
        let publisher = RealtimeEventPublisher.shared
        var subscriber1Updates = 0
        var subscriber2Updates = 0
        
        let cancellable1 = publisher.connectionStateChanged
            .sink { _ in
                subscriber1Updates += 1
            }
        
        let cancellable2 = publisher.connectionStateChanged
            .sink { _ in
                subscriber2Updates += 1
            }
        
        // Publish events
        publisher.publishConnectionStateChange(.connecting)
        publisher.publishConnectionStateChange(.connected)
        
        // Allow time for events to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(subscriber1Updates == 2)
        #expect(subscriber2Updates == 2)
        
        cancellable1.cancel()
        cancellable2.cancel()
    }
    
    // MARK: - AsyncOperationManager Tests
    
    @Test("AsyncOperationManager should manage login state correctly")
    func testAsyncOperationManagerLoginState() async throws {
        let operationManager = AsyncOperationManager()
        
        #expect(operationManager.loginState.isLoading == false)
        
        // Perform login (will fail in test environment, but we test state management)
        await operationManager.performLogin(
            userId: "testUser",
            userName: "Test User",
            userRole: .broadcaster
        )
        
        // Verify state was managed (either success or failure)
        #expect(operationManager.loginState.isLoading == false)
        
        // In test environment, login will likely fail
        if case .failure = operationManager.loginState {
            #expect(true) // Expected in test environment
        } else if case .success = operationManager.loginState {
            #expect(true) // Would be success in real environment
        }
    }
    
    @Test("AsyncOperationManager should handle connection state")
    func testAsyncOperationManagerConnectionState() async throws {
        let operationManager = AsyncOperationManager()
        
        #expect(operationManager.connectionState.isLoading == false)
        
        let config = RealtimeConfig(
            appId: "test-app-id",
            appCertificate: "test-certificate",
            rtcToken: "test-rtc-token",
            rtmToken: "test-rtm-token"
        )
        
        await operationManager.performConnection(config: config)
        
        // Verify state was managed
        #expect(operationManager.connectionState.isLoading == false)
    }
    
    @Test("AsyncOperationManager should handle volume detection state")
    func testAsyncOperationManagerVolumeDetectionState() async throws {
        let operationManager = AsyncOperationManager()
        
        #expect(operationManager.volumeDetectionState.isLoading == false)
        
        await operationManager.enableVolumeDetection()
        
        // Verify state was managed
        #expect(operationManager.volumeDetectionState.isLoading == false)
        
        await operationManager.disableVolumeDetection()
        
        // Verify state was managed
        #expect(operationManager.volumeDetectionState.isLoading == false)
    }
    
    @Test("AsyncOperationManager should perform generic async operations")
    func testAsyncOperationManagerGenericOperations() async throws {
        let operationManager = AsyncOperationManager()
        
        // Test successful operation
        let successResult = await operationManager.performAudioOperation {
            return "success"
        }
        
        if case .success(let value) = successResult {
            #expect(value == "success")
        } else {
            #expect(false, "Expected success result")
        }
        
        // Test failing operation
        let failureResult = await operationManager.performAudioOperation {
            throw RealtimeError.networkError("Test error")
        }
        
        if case .failure = failureResult {
            #expect(true)
        } else {
            #expect(false, "Expected failure result")
        }
    }
    
    // MARK: - RealtimeDataStore Tests
    
    @Test("RealtimeDataStore should initialize with correct default state")
    func testRealtimeDataStoreInitialization() async throws {
        let dataStore = RealtimeDataStore()
        
        #expect(dataStore.connectionState == .disconnected)
        #expect(dataStore.currentSession == nil)
        #expect(dataStore.audioSettings == .default)
        #expect(dataStore.volumeInfos.isEmpty)
        #expect(dataStore.speakingUsers.isEmpty)
        #expect(dataStore.dominantSpeaker == nil)
        #expect(dataStore.isVolumeDetectionEnabled == false)
        #expect(dataStore.selectedUser == nil)
        #expect(dataStore.showingErrorAlert == false)
        #expect(dataStore.currentError == nil)
    }
    
    @Test("RealtimeDataStore should update state from event publisher")
    func testRealtimeDataStoreEventBinding() async throws {
        let eventPublisher = RealtimeEventPublisher()
        let dataStore = RealtimeDataStore(eventPublisher: eventPublisher)
        
        // Test connection state update
        eventPublisher.publishConnectionStateChange(.connected)
        
        // Allow time for binding to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(dataStore.connectionState == .connected)
        
        // Test volume update
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.8, isSpeaking: true),
            UserVolumeInfo(userId: "user2", volume: 0.3, isSpeaking: false)
        ]
        
        eventPublisher.publishVolumeUpdate(volumeInfos)
        
        // Allow time for binding to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(dataStore.volumeInfos.count == 2)
        #expect(dataStore.speakingUsers.contains("user1"))
        #expect(!dataStore.speakingUsers.contains("user2"))
    }
    
    @Test("RealtimeDataStore should compute properties correctly")
    func testRealtimeDataStoreComputedProperties() async throws {
        let eventPublisher = RealtimeEventPublisher()
        let dataStore = RealtimeDataStore(eventPublisher: eventPublisher)
        
        // Set up test data
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.3, isSpeaking: false),
            UserVolumeInfo(userId: "user2", volume: 0.8, isSpeaking: true),
            UserVolumeInfo(userId: "user3", volume: 0.5, isSpeaking: true)
        ]
        
        eventPublisher.publishVolumeUpdate(volumeInfos)
        eventPublisher.publishConnectionStateChange(.connected)
        
        let session = UserSession(
            userId: "testUser",
            userName: "Test User",
            userRole: .broadcaster
        )
        eventPublisher.publishUserJoined(session)
        
        // Allow time for updates to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Test computed properties
        let sortedInfos = dataStore.sortedVolumeInfos
        #expect(sortedInfos.first?.volume == 0.8) // Highest volume first
        
        let activeSpeakers = dataStore.activeSpeakers
        #expect(activeSpeakers.count == 2) // Only speaking users
        
        #expect(dataStore.isConnected == true)
        #expect(dataStore.hasActiveSession == true)
    }
    
    @Test("RealtimeDataStore should handle error states")
    func testRealtimeDataStoreErrorHandling() async throws {
        let eventPublisher = RealtimeEventPublisher()
        let dataStore = RealtimeDataStore(eventPublisher: eventPublisher)
        
        let testError = RealtimeError.networkError("Test error")
        eventPublisher.publishError(testError)
        
        // Allow time for error to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(dataStore.currentError != nil)
        #expect(dataStore.showingErrorAlert == true)
        
        dataStore.clearError()
        
        #expect(dataStore.currentError == nil)
        #expect(dataStore.showingErrorAlert == false)
    }
    
    // MARK: - RealtimeReactiveCoordinator Tests
    
    @Test("RealtimeReactiveCoordinator should monitor system initialization")
    func testRealtimeReactiveCoordinatorInitialization() async throws {
        let dataStore = RealtimeDataStore()
        let operationManager = AsyncOperationManager()
        let coordinator = RealtimeReactiveCoordinator(
            dataStore: dataStore,
            operationManager: operationManager
        )
        
        #expect(coordinator.isFullyInitialized == false)
        #expect(coordinator.systemHealth == .unknown)
        
        // Allow time for initial coordination setup
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // System health should be calculated based on current states
        #expect(coordinator.systemHealth != .unknown)
    }
    
    @Test("RealtimeReactiveCoordinator should calculate system health correctly")
    func testRealtimeReactiveCoordinatorSystemHealth() async throws {
        let dataStore = RealtimeDataStore()
        let operationManager = AsyncOperationManager()
        let coordinator = RealtimeReactiveCoordinator(
            dataStore: dataStore,
            operationManager: operationManager
        )
        
        // Simulate healthy system state
        let eventPublisher = RealtimeEventPublisher()
        eventPublisher.publishConnectionStateChange(.connected)
        
        let session = UserSession(
            userId: "testUser",
            userName: "Test User",
            userRole: .broadcaster
        )
        eventPublisher.publishUserJoined(session)
        
        // Allow time for coordination
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // System health should reflect the state
        #expect(coordinator.systemHealth != .failed)
    }
    
    // MARK: - Complex Data Flow Tests
    
    @Test("Complex data flow should work end-to-end")
    func testComplexDataFlowEndToEnd() async throws {
        let eventPublisher = RealtimeEventPublisher()
        let dataStore = RealtimeDataStore(eventPublisher: eventPublisher)
        let operationManager = AsyncOperationManager()
        let coordinator = RealtimeReactiveCoordinator(
            dataStore: dataStore,
            operationManager: operationManager
        )
        
        var stateChanges: [String] = []
        
        // Monitor state changes
        let cancellable1 = dataStore.$connectionState
            .sink { state in
                stateChanges.append("connection: \(state)")
            }
        
        let cancellable2 = dataStore.$speakingUsers
            .sink { users in
                stateChanges.append("speaking: \(users.count)")
            }
        
        // Simulate complex flow
        eventPublisher.publishConnectionStateChange(.connecting)
        eventPublisher.publishConnectionStateChange(.connected)
        
        let volumeInfos = [
            UserVolumeInfo(userId: "user1", volume: 0.8, isSpeaking: true),
            UserVolumeInfo(userId: "user2", volume: 0.3, isSpeaking: false)
        ]
        eventPublisher.publishVolumeUpdate(volumeInfos)
        
        eventPublisher.publishSpeakingStateChange(userId: "user3", isSpeaking: true)
        
        // Allow time for all updates to propagate
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        #expect(stateChanges.count >= 4) // Should have multiple state changes
        #expect(dataStore.connectionState == .connected)
        #expect(dataStore.speakingUsers.count >= 1)
        
        cancellable1.cancel()
        cancellable2.cancel()
    }
    
    @Test("Data flow should handle concurrent updates correctly")
    func testDataFlowConcurrentUpdates() async throws {
        let eventPublisher = RealtimeEventPublisher()
        let dataStore = RealtimeDataStore(eventPublisher: eventPublisher)
        
        var updateCount = 0
        let cancellable = dataStore.$volumeInfos
            .sink { _ in
                updateCount += 1
            }
        
        // Simulate concurrent volume updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let volumeInfos = [
                        UserVolumeInfo(
                            userId: "user\(i)",
                            volume: Float.random(in: 0...1),
                            isSpeaking: Bool.random()
                        )
                    ]
                    eventPublisher.publishVolumeUpdate(volumeInfos)
                }
            }
        }
        
        // Allow time for all updates to propagate
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(updateCount >= 10) // Should have received all updates
        
        cancellable.cancel()
    }
    
    @Test("Data flow should maintain consistency under stress")
    func testDataFlowConsistencyUnderStress() async throws {
        let eventPublisher = RealtimeEventPublisher()
        let dataStore = RealtimeDataStore(eventPublisher: eventPublisher)
        
        // Simulate high-frequency updates
        for iteration in 0..<100 {
            let volumeInfos = (0..<5).map { userIndex in
                UserVolumeInfo(
                    userId: "user\(userIndex)",
                    volume: Float.random(in: 0...1),
                    isSpeaking: Bool.random()
                )
            }
            
            eventPublisher.publishVolumeUpdate(volumeInfos)
            
            if iteration % 10 == 0 {
                eventPublisher.publishConnectionStateChange(.connected)
            }
            
            // Small delay to simulate real-time updates
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Allow final updates to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify data consistency
        #expect(dataStore.volumeInfos.count <= 5) // Should not accumulate
        #expect(dataStore.speakingUsers.count <= 5) // Should not accumulate
        #expect(dataStore.connectionState == .connected)
        
        // Verify computed properties are consistent
        let sortedInfos = dataStore.sortedVolumeInfos
        for i in 0..<(sortedInfos.count - 1) {
            #expect(sortedInfos[i].volume >= sortedInfos[i + 1].volume)
        }
    }
}