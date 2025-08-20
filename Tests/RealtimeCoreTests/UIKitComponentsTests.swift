// UIKitComponentsTests.swift
// Tests for RealtimeUIKit components

import Testing
import Foundation
#if canImport(UIKit)
import UIKit
@testable import RealtimeUIKit
@testable import RealtimeCore
#endif

#if canImport(UIKit)
@available(iOS 13.0, *)
struct UIKitComponentsTests {
    
    // MARK: - RealtimeViewController Tests
    
    @Test("RealtimeViewController initialization")
    func testRealtimeViewControllerInitialization() {
        let viewController = RealtimeViewController()
        
        #expect(viewController.realtimeManager === RealtimeManager.shared)
        #expect(viewController.delegate == nil)
        #expect(viewController.currentSession == nil)
        #expect(viewController.connectionState == .disconnected)
    }
    
    @Test("RealtimeViewController event handling")
    func testRealtimeViewControllerEventHandling() async {
        let viewController = RealtimeViewController()
        var receivedEvents: [RealtimeEvent] = []
        
        // Set up event handler
        viewController.onConnectionStateChanged = { state in
            receivedEvents.append(.connectionStateChanged(state))
        }
        
        viewController.onVolumeChanged = { volumeInfos in
            receivedEvents.append(.volumeChanged(volumeInfos))
        }
        
        // Trigger events
        viewController.handleRealtimeEvent(.connectionStateChanged(.connecting))
        viewController.handleRealtimeEvent(.volumeChanged([]))
        
        #expect(receivedEvents.count == 2)
        
        if case .connectionStateChanged(let state) = receivedEvents[0] {
            #expect(state == .connecting)
        } else {
            Issue.record("Expected connectionStateChanged event")
        }
    }
    
    @Test("RealtimeViewController delegate pattern")
    func testRealtimeViewControllerDelegate() {
        let viewController = RealtimeViewController()
        let delegate = MockRealtimeUIKitDelegate()
        viewController.delegate = delegate
        
        let testError = RealtimeError.connectionFailed("Test connection error")
        viewController.handleRealtimeEvent(.error(testError))
        
        #expect(delegate.receivedEvents.count == 1)
        #expect(delegate.receivedErrors.count == 1)
        
        if case .error(let error) = delegate.receivedEvents[0] {
            #expect(error.localizedDescription == testError.localizedDescription)
        } else {
            Issue.record("Expected error event")
        }
    }
    
    // MARK: - VolumeVisualizationView Tests
    
    @Test("VolumeVisualizationView initialization")
    func testVolumeVisualizationViewInitialization() {
        let volumeView = VolumeVisualizationView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        
        #expect(volumeView.volumeLevel == 0.0)
        #expect(volumeView.isSpeaking == false)
        #expect(volumeView.configuration.barCount == 5)
    }
    
    @Test("VolumeVisualizationView volume update")
    func testVolumeVisualizationViewVolumeUpdate() {
        let volumeView = VolumeVisualizationView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        
        let volumeInfo = UserVolumeInfo(userId: "test-user", volume: 0.8, isSpeaking: true)
        volumeView.updateVolumeInfo(volumeInfo)
        
        #expect(volumeView.volumeLevel == 0.8)
        #expect(volumeView.isSpeaking == true)
    }
    
    @Test("VolumeVisualizationView configuration")
    func testVolumeVisualizationViewConfiguration() {
        let volumeView = VolumeVisualizationView()
        
        let customConfig = VolumeVisualizationView.Configuration(
            barCount: 8,
            barSpacing: 3.0,
            barCornerRadius: 2.0,
            activeColor: .red,
            inactiveColor: .gray,
            animationDuration: 0.2
        )
        
        volumeView.configuration = customConfig
        
        #expect(volumeView.configuration.barCount == 8)
        #expect(volumeView.configuration.barSpacing == 3.0)
        #expect(volumeView.configuration.animationDuration == 0.2)
    }
    
    // MARK: - SpeakingIndicatorView Tests
    
    @Test("SpeakingIndicatorView initialization")
    func testSpeakingIndicatorViewInitialization() {
        let indicatorView = SpeakingIndicatorView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        
        #expect(indicatorView.isSpeaking == false)
        #expect(indicatorView.configuration.rippleCount == 3)
    }
    
    @Test("SpeakingIndicatorView speaking state")
    func testSpeakingIndicatorViewSpeakingState() {
        let indicatorView = SpeakingIndicatorView()
        
        indicatorView.isSpeaking = true
        #expect(indicatorView.isSpeaking == true)
        
        indicatorView.isSpeaking = false
        #expect(indicatorView.isSpeaking == false)
    }
    
    // MARK: - UserVolumeIndicatorView Tests
    
    @Test("UserVolumeIndicatorView initialization")
    func testUserVolumeIndicatorViewInitialization() {
        let userVolumeView = UserVolumeIndicatorView()
        
        #expect(userVolumeView.userId.isEmpty)
        #expect(userVolumeView.userName.isEmpty)
        #expect(userVolumeView.userLabel.text?.isEmpty ?? true)
    }
    
    @Test("UserVolumeIndicatorView user info update")
    func testUserVolumeIndicatorViewUserInfoUpdate() {
        let userVolumeView = UserVolumeIndicatorView()
        
        userVolumeView.userId = "test-user"
        userVolumeView.userName = "Test User"
        
        #expect(userVolumeView.userId == "test-user")
        #expect(userVolumeView.userName == "Test User")
        #expect(userVolumeView.userLabel.text == "Test User")
    }
    
    @Test("UserVolumeIndicatorView volume info update")
    func testUserVolumeIndicatorViewVolumeInfoUpdate() {
        let userVolumeView = UserVolumeIndicatorView()
        
        let volumeInfo = UserVolumeInfo(userId: "test-user", volume: 0.6, isSpeaking: true)
        userVolumeView.updateVolumeInfo(volumeInfo)
        
        #expect(userVolumeView.userId == "test-user")
        #expect(userVolumeView.volumeView.volumeLevel == 0.6)
        #expect(userVolumeView.speakingIndicator.isSpeaking == true)
    }
    
    // MARK: - AudioControlPanelView Tests
    
    @Test("AudioControlPanelView initialization")
    func testAudioControlPanelViewInitialization() {
        let controlPanel = AudioControlPanelView()
        
        #expect(controlPanel.audioSettings.microphoneMuted == false)
        #expect(controlPanel.audioSettings.audioMixingVolume == 100)
        #expect(controlPanel.delegate == nil)
    }
    
    @Test("AudioControlPanelView settings update")
    func testAudioControlPanelViewSettingsUpdate() {
        let controlPanel = AudioControlPanelView()
        
        let customSettings = AudioSettings(
            microphoneMuted: true,
            audioMixingVolume: 75,
            playbackSignalVolume: 80,
            recordingSignalVolume: 90,
            localAudioStreamActive: false
        )
        
        controlPanel.audioSettings = customSettings
        
        #expect(controlPanel.audioSettings.microphoneMuted == true)
        #expect(controlPanel.audioSettings.audioMixingVolume == 75)
        #expect(controlPanel.audioSettings.playbackSignalVolume == 80)
        #expect(controlPanel.audioSettings.recordingSignalVolume == 90)
        #expect(controlPanel.audioSettings.localAudioStreamActive == false)
    }
    
    @Test("AudioControlPanelView delegate callbacks")
    func testAudioControlPanelViewDelegateCallbacks() {
        let controlPanel = AudioControlPanelView()
        let delegate = MockAudioControlPanelDelegate()
        controlPanel.delegate = delegate
        
        // Test microphone toggle
        var microphoneToggled = false
        controlPanel.onMicrophoneToggle = { muted in
            microphoneToggled = true
        }
        
        // Test volume change
        var volumeChanged = false
        controlPanel.onVolumeChanged = { type, value in
            volumeChanged = true
        }
        
        // Simulate button taps and slider changes would require UI interaction
        // For now, we test that the closures are properly set
        #expect(controlPanel.onMicrophoneToggle != nil)
        #expect(controlPanel.onVolumeChanged != nil)
    }
    
    // MARK: - ErrorDisplayView Tests
    
    @Test("ErrorDisplayView initialization")
    func testErrorDisplayViewInitialization() {
        let errorView = ErrorDisplayView()
        
        #expect(errorView.currentError == nil)
        #expect(errorView.isHidden == true)
    }
    
    @Test("ErrorDisplayView error display")
    func testErrorDisplayViewErrorDisplay() {
        let errorView = ErrorDisplayView()
        
        let testError = RealtimeError.connectionFailed("Test connection error")
        errorView.showError(testError, animated: false)
        
        #expect(errorView.currentError != nil)
        #expect(errorView.isHidden == false)
    }
    
    @Test("ErrorDisplayView error types")
    func testErrorDisplayViewErrorTypes() {
        let errorView = ErrorDisplayView()
        
        // Test different error types
        let errors: [RealtimeError] = [
            .connectionFailed("Test connection error"),
            .tokenExpired(.agora),
            .insufficientPermissions(.audience),
            .noActiveSession,
            .providerNotAvailable(.agora),
            .invalidConfiguration("Test config error"),
            .networkError("Test network error"),
            .audioControlFailed("Test audio error")
        ]
        
        for error in errors {
            errorView.currentError = error
            #expect(errorView.isHidden == false)
        }
    }
    
    @Test("ErrorDisplayView retry functionality")
    func testErrorDisplayViewRetryFunctionality() {
        let errorView = ErrorDisplayView()
        var retryCallbackCalled = false
        
        errorView.onRetry = {
            retryCallbackCalled = true
        }
        
        #expect(errorView.onRetry != nil)
        // Actual retry button tap would require UI interaction
    }
    
    // MARK: - ToastNotificationView Tests
    
    @Test("ToastNotificationView types")
    func testToastNotificationViewTypes() {
        let successColor = ToastNotificationView.ToastType.success.backgroundColor
        let errorColor = ToastNotificationView.ToastType.error.backgroundColor
        let warningColor = ToastNotificationView.ToastType.warning.backgroundColor
        let infoColor = ToastNotificationView.ToastType.info.backgroundColor
        
        #expect(successColor == .systemGreen)
        #expect(errorColor == .systemRed)
        #expect(warningColor == .systemOrange)
        #expect(infoColor == .systemBlue)
    }
    
    @Test("ToastNotificationView icons")
    func testToastNotificationViewIcons() {
        let successIcon = ToastNotificationView.ToastType.success.icon
        let errorIcon = ToastNotificationView.ToastType.error.icon
        let warningIcon = ToastNotificationView.ToastType.warning.icon
        let infoIcon = ToastNotificationView.ToastType.info.icon
        
        #expect(successIcon == "checkmark.circle.fill")
        #expect(errorIcon == "xmark.circle.fill")
        #expect(warningIcon == "exclamationmark.triangle.fill")
        #expect(infoIcon == "info.circle.fill")
    }
    
    // MARK: - AudioSettingsViewController Tests
    
    @Test("AudioSettingsViewController initialization")
    func testAudioSettingsViewControllerInitialization() {
        let settingsVC = AudioSettingsViewController()
        
        #expect(settingsVC.realtimeManager === RealtimeManager.shared)
        #expect(settingsVC.title == nil) // Title is set in viewDidLoad
    }
    
    @Test("AudioSettingsViewController view loading")
    func testAudioSettingsViewControllerViewLoading() {
        let settingsVC = AudioSettingsViewController()
        
        // Trigger viewDidLoad
        _ = settingsVC.view
        
        #expect(settingsVC.title == "Audio Settings")
        #expect(settingsVC.navigationItem.rightBarButtonItem != nil)
        #expect(settingsVC.view.backgroundColor == .systemGroupedBackground)
    }
}

// MARK: - Mock Classes for Testing

@available(iOS 13.0, *)
class MockRealtimeUIKitDelegate: RealtimeUIKitDelegate {
    var receivedEvents: [RealtimeEvent] = []
    var receivedErrors: [RealtimeError] = []
    
    func realtimeKit(_ manager: RealtimeManager, didReceiveEvent event: RealtimeEvent) {
        receivedEvents.append(event)
    }
    
    func realtimeKit(_ manager: RealtimeManager, didEncounterError error: RealtimeError) {
        receivedErrors.append(error)
    }
}

@available(iOS 13.0, *)
class MockAudioControlPanelDelegate: AudioControlPanelDelegate {
    var microphoneToggleCalls: [(Bool)] = []
    var audioStreamToggleCalls: [(Bool)] = []
    var volumeChangeCalls: [(AudioVolumeType, Int)] = []
    
    func audioControlPanel(_ panel: AudioControlPanelView, didToggleMicrophone muted: Bool) {
        microphoneToggleCalls.append(muted)
    }
    
    func audioControlPanel(_ panel: AudioControlPanelView, didToggleAudioStream active: Bool) {
        audioStreamToggleCalls.append(active)
    }
    
    func audioControlPanel(_ panel: AudioControlPanelView, didChangeVolume type: AudioVolumeType, value: Int) {
        volumeChangeCalls.append((type, value))
    }
}
#endif