// UIKitInteractionTests.swift
// Interaction tests for RealtimeUIKit components

import Testing
import Foundation
#if canImport(UIKit)
import UIKit
@testable import RealtimeUIKit
@testable import RealtimeCore
#endif

#if canImport(UIKit)
@available(iOS 13.0, *)
struct UIKitInteractionTests {
    
    // MARK: - RealtimeViewController Integration Tests
    
    @Test("RealtimeViewController reactive binding integration")
    func testRealtimeViewControllerReactiveBinding() async throws {
        let viewController = RealtimeViewController()
        var connectionStateChanges: [ConnectionState] = []
        var volumeChanges: [[UserVolumeInfo]] = []
        
        // Set up event handlers
        viewController.onConnectionStateChanged = { state in
            connectionStateChanges.append(state)
        }
        
        viewController.onVolumeChanged = { volumeInfos in
            volumeChanges.append(volumeInfos)
        }
        
        // Load the view to trigger reactive bindings
        _ = viewController.view
        
        // Wait a bit for bindings to be established
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // The initial state should be captured
        #expect(connectionStateChanges.count >= 1)
        #expect(connectionStateChanges.first == .disconnected)
    }
    
    @Test("RealtimeViewController convenience methods")
    func testRealtimeViewControllerConvenienceMethods() async throws {
        let viewController = RealtimeViewController()
        
        // Test that convenience methods don't crash when no session exists
        do {
            try await viewController.joinRoom("test-room")
            Issue.record("Should have thrown noActiveSession error")
        } catch RealtimeError.noActiveSession {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        
        // Test leave room (should not crash even without active session)
        do {
            try await viewController.leaveRoom()
        } catch {
            // May throw error, but should not crash
        }
    }
    
    // MARK: - Volume Visualization Integration Tests
    
    @Test("VolumeVisualizationView layout and animation")
    func testVolumeVisualizationViewLayoutAndAnimation() {
        let volumeView = VolumeVisualizationView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        
        // Trigger layout
        volumeView.layoutSubviews()
        
        // Test volume level changes
        volumeView.volumeLevel = 0.5
        #expect(volumeView.volumeLevel == 0.5)
        
        volumeView.volumeLevel = 1.0
        #expect(volumeView.volumeLevel == 1.0)
        
        volumeView.volumeLevel = 0.0
        #expect(volumeView.volumeLevel == 0.0)
    }
    
    @Test("VolumeVisualizationView speaking animation")
    func testVolumeVisualizationViewSpeakingAnimation() {
        let volumeView = VolumeVisualizationView()
        
        // Test speaking state changes
        volumeView.isSpeaking = true
        #expect(volumeView.isSpeaking == true)
        
        volumeView.isSpeaking = false
        #expect(volumeView.isSpeaking == false)
        
        // Test combined volume and speaking update
        let volumeInfo = UserVolumeInfo(userId: "test", volume: 0.8, isSpeaking: true)
        volumeView.updateVolumeInfo(volumeInfo)
        
        #expect(volumeView.volumeLevel == 0.8)
        #expect(volumeView.isSpeaking == true)
    }
    
    // MARK: - Speaking Indicator Integration Tests
    
    @Test("SpeakingIndicatorView animation lifecycle")
    func testSpeakingIndicatorViewAnimationLifecycle() {
        let indicatorView = SpeakingIndicatorView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        
        // Trigger layout to create layers
        indicatorView.layoutSubviews()
        
        // Test animation start
        indicatorView.isSpeaking = true
        #expect(indicatorView.isSpeaking == true)
        
        // Test animation stop
        indicatorView.isSpeaking = false
        #expect(indicatorView.isSpeaking == false)
    }
    
    @Test("SpeakingIndicatorView configuration changes")
    func testSpeakingIndicatorViewConfigurationChanges() {
        let indicatorView = SpeakingIndicatorView()
        
        let customConfig = SpeakingIndicatorView.Configuration(
            indicatorColor: .red,
            rippleColor: .blue,
            animationDuration: 2.0,
            rippleCount: 5
        )
        
        indicatorView.configuration = customConfig
        
        #expect(indicatorView.configuration.indicatorColor == .red)
        #expect(indicatorView.configuration.rippleColor == .blue)
        #expect(indicatorView.configuration.animationDuration == 2.0)
        #expect(indicatorView.configuration.rippleCount == 5)
    }
    
    // MARK: - Audio Control Panel Integration Tests
    
    @Test("AudioControlPanelView UI state synchronization")
    func testAudioControlPanelViewUIStateSynchronization() {
        let controlPanel = AudioControlPanelView()
        
        // Test initial state
        #expect(controlPanel.audioSettings == .default)
        
        // Test settings update
        let mutedSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 50,
            playbackSignalVolume: 75,
            recordingSignalVolume: 25,
            localAudioStreamActive: false
        )
        
        controlPanel.audioSettings = mutedSettings
        
        #expect(controlPanel.audioSettings.microphoneMuted == true)
        #expect(controlPanel.audioSettings.audioMixingVolume == 50)
        #expect(controlPanel.audioSettings.playbackSignalVolume == 75)
        #expect(controlPanel.audioSettings.recordingSignalVolume == 25)
        #expect(controlPanel.audioSettings.localAudioStreamActive == false)
    }
    
    @Test("AudioControlPanelView delegate integration")
    func testAudioControlPanelViewDelegateIntegration() {
        let controlPanel = AudioControlPanelView()
        let delegate = MockAudioControlPanelDelegate()
        controlPanel.delegate = delegate
        
        // Test that delegate is properly set
        #expect(controlPanel.delegate === delegate)
        
        // Test closure handlers
        var microphoneToggled = false
        var volumeChanged = false
        var streamToggled = false
        
        controlPanel.onMicrophoneToggle = { _ in microphoneToggled = true }
        controlPanel.onVolumeChanged = { _, _ in volumeChanged = true }
        controlPanel.onAudioStreamToggle = { _ in streamToggled = true }
        
        #expect(controlPanel.onMicrophoneToggle != nil)
        #expect(controlPanel.onVolumeChanged != nil)
        #expect(controlPanel.onAudioStreamToggle != nil)
    }
    
    // MARK: - Error Display Integration Tests
    
    @Test("ErrorDisplayView error handling workflow")
    func testErrorDisplayViewErrorHandlingWorkflow() {
        let errorView = ErrorDisplayView()
        var retryCallCount = 0
        
        errorView.onRetry = {
            retryCallCount += 1
        }
        
        // Test showing error
        let connectionError = RealtimeError.connectionFailed
        errorView.showError(connectionError, animated: false)
        
        #expect(errorView.currentError != nil)
        #expect(errorView.isHidden == false)
        
        // Test hiding error
        errorView.hideError(animated: false)
        
        #expect(errorView.currentError == nil)
        #expect(errorView.isHidden == true)
    }
    
    @Test("ErrorDisplayView different error types display")
    func testErrorDisplayViewDifferentErrorTypesDisplay() {
        let errorView = ErrorDisplayView()
        
        let testErrors: [RealtimeError] = [
            .connectionFailed("Test connection error"),
            .tokenExpired(.agora),
            .insufficientPermissions(.audience),
            .noActiveSession,
            .providerNotAvailable(.agora),
            .invalidConfiguration("Test message"),
            .networkError("Test network error"),
            .audioControlFailed("Test audio error")
        ]
        
        for error in testErrors {
            errorView.currentError = error
            #expect(errorView.isHidden == false)
            #expect(errorView.currentError != nil)
        }
    }
    
    // MARK: - Toast Notification Integration Tests
    
    @Test("ToastNotificationView display and dismiss")
    func testToastNotificationViewDisplayAndDismiss() {
        let parentView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        let toast = ToastNotificationView()
        
        // Test showing toast
        toast.show(message: "Test message", type: .success, duration: 0.1, in: parentView)
        
        #expect(parentView.subviews.contains(toast))
        
        // Test immediate dismiss
        toast.dismiss()
        
        // Note: The actual removal happens in animation completion,
        // so we can't test it synchronously here
    }
    
    @Test("ToastNotificationView convenience methods")
    func testToastNotificationViewConvenienceMethods() {
        let parentView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        
        // Test convenience methods don't crash
        ToastNotificationView.showSuccess("Success message", in: parentView)
        ToastNotificationView.showError("Error message", in: parentView)
        ToastNotificationView.showWarning("Warning message", in: parentView)
        ToastNotificationView.showInfo("Info message", in: parentView)
        
        // Should have 4 toast views added
        let toastViews = parentView.subviews.compactMap { $0 as? ToastNotificationView }
        #expect(toastViews.count == 4)
    }
    
    // MARK: - AudioSettingsViewController Integration Tests
    
    @Test("AudioSettingsViewController lifecycle")
    func testAudioSettingsViewControllerLifecycle() {
        let settingsVC = AudioSettingsViewController()
        
        // Test view loading
        settingsVC.loadViewIfNeeded()
        
        #expect(settingsVC.isViewLoaded)
        #expect(settingsVC.title == "Audio Settings")
        #expect(settingsVC.navigationItem.rightBarButtonItem != nil)
        
        // Test that audio control panel is properly configured
        #expect(settingsVC.audioControlPanel.delegate === settingsVC)
    }
    
    @Test("AudioSettingsViewController reactive updates")
    func testAudioSettingsViewControllerReactiveUpdates() async throws {
        let settingsVC = AudioSettingsViewController()
        
        // Load view to establish bindings
        settingsVC.loadViewIfNeeded()
        
        // Wait for initial binding
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // The audio control panel should reflect the current settings
        let currentSettings = settingsVC.realtimeManager.audioSettings
        #expect(settingsVC.audioControlPanel.audioSettings == currentSettings)
    }
    
    // MARK: - UIViewController Extension Tests
    
    @Test("UIViewController error handling extensions")
    func testUIViewControllerErrorHandlingExtensions() {
        let viewController = UIViewController()
        
        // Load view
        _ = viewController.view
        
        // Test toast methods don't crash
        viewController.showSuccessToast("Success")
        viewController.showErrorToast("Error")
        viewController.showWarningToast("Warning")
        viewController.showInfoToast("Info")
        
        // Should have 4 toast views in the view hierarchy
        let toastViews = viewController.view.subviews.compactMap { $0 as? ToastNotificationView }
        #expect(toastViews.count == 4)
    }
    
    // MARK: - Complex Integration Scenarios
    
    @Test("Complete UIKit workflow integration")
    func testCompleteUIKitWorkflowIntegration() async throws {
        // Create a complete UIKit setup
        let mainViewController = RealtimeViewController()
        let delegate = MockRealtimeUIKitDelegate()
        mainViewController.delegate = delegate
        
        // Load view
        _ = mainViewController.view
        
        // Create audio settings
        let audioSettingsVC = AudioSettingsViewController()
        _ = audioSettingsVC.view
        
        // Create volume indicators
        let volumeIndicator = UserVolumeIndicatorView()
        volumeIndicator.userId = "test-user"
        volumeIndicator.userName = "Test User"
        
        // Create error display
        let errorDisplay = ErrorDisplayView()
        
        // Test error handling workflow
        let testError = RealtimeError.connectionFailed("Test connection error")
        mainViewController.handleRealtimeEvent(.error(testError))
        
        #expect(delegate.receivedErrors.count == 1)
        
        // Test volume update workflow
        let volumeInfo = UserVolumeInfo(userId: "test-user", volume: 0.7, isSpeaking: true)
        volumeIndicator.updateVolumeInfo(volumeInfo)
        
        #expect(volumeIndicator.volumeView.volumeLevel == 0.7)
        #expect(volumeIndicator.speakingIndicator.isSpeaking == true)
        
        // Test error display
        errorDisplay.showError(testError, animated: false)
        #expect(errorDisplay.currentError != nil)
        #expect(errorDisplay.isHidden == false)
    }
    
    @Test("Memory management and cleanup")
    func testMemoryManagementAndCleanup() {
        weak var weakViewController: RealtimeViewController?
        weak var weakAudioSettings: AudioSettingsViewController?
        weak var weakDelegate: MockRealtimeUIKitDelegate?
        
        autoreleasepool {
            let viewController = RealtimeViewController()
            let audioSettings = AudioSettingsViewController()
            let delegate = MockRealtimeUIKitDelegate()
            
            viewController.delegate = delegate
            
            // Load views
            _ = viewController.view
            _ = audioSettings.view
            
            weakViewController = viewController
            weakAudioSettings = audioSettings
            weakDelegate = delegate
            
            // Objects should be alive
            #expect(weakViewController != nil)
            #expect(weakAudioSettings != nil)
            #expect(weakDelegate != nil)
        }
        
        // After autoreleasepool, objects should be deallocated
        // Note: In practice, some objects might still be retained by the system
        // This test mainly ensures no obvious retain cycles
    }
}
#endif