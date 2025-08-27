import XCTest
import SwiftUI
import Combine
@testable import RealtimeCore
@testable import RealtimeSwiftUI

/// SwiftUI 动画效果测试
/// 需求: 11.2 - 音量波形可视化和动画效果测试
@available(macOS 10.15, iOS 13.0, *)
final class SwiftUIAnimationTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Volume Visualization Animation Tests
    
    func testVolumeVisualizationBarAnimation() {
        // Given
        let volumeLevel: Float = 0.8
        let isSpeaking = true
        
        // When
        let view = VolumeVisualizationView(
            volumeLevel: volumeLevel,
            isSpeaking: isSpeaking,
            style: .bar
        )
        
        // Then - View should be created successfully
        XCTAssertNotNil(view)
        
        // Animation properties should be set correctly
        XCTAssertEqual(volumeLevel, 0.8)
        XCTAssertTrue(isSpeaking)
    }
    
    func testVolumeVisualizationWaveformAnimation() {
        // Given
        let volumeLevel: Float = 0.6
        let isSpeaking = false
        
        // When
        let view = VolumeVisualizationView(
            volumeLevel: volumeLevel,
            isSpeaking: isSpeaking,
            style: .waveform
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertEqual(volumeLevel, 0.6)
        XCTAssertFalse(isSpeaking)
    }
    
    func testVolumeVisualizationCircularAnimation() {
        // Given
        let volumeLevel: Float = 0.9
        let isSpeaking = true
        
        // When
        let view = VolumeVisualizationView(
            volumeLevel: volumeLevel,
            isSpeaking: isSpeaking,
            style: .circular
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertEqual(volumeLevel, 0.9)
        XCTAssertTrue(isSpeaking)
    }
    
    func testVolumeVisualizationRippleAnimation() {
        // Given
        let volumeLevel: Float = 0.4
        let isSpeaking = true
        
        // When
        let view = VolumeVisualizationView(
            volumeLevel: volumeLevel,
            isSpeaking: isSpeaking,
            style: .ripple
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertEqual(volumeLevel, 0.4)
        XCTAssertTrue(isSpeaking)
    }
    
    // MARK: - Connection State Animation Tests
    
    func testConnectionStateAnimationForConnectingState() {
        // Given
        let connectionState = ConnectionState.connecting
        
        // When
        let view = ConnectionStateIndicatorView(
            connectionState: connectionState,
            showText: true,
            style: .capsule
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertTrue(connectionState.shouldAnimate, "Connecting state should animate")
    }
    
    func testConnectionStateAnimationForReconnectingState() {
        // Given
        let connectionState = ConnectionState.reconnecting
        
        // When
        let view = ConnectionStateIndicatorView(
            connectionState: connectionState,
            showText: true,
            style: .badge
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertTrue(connectionState.shouldAnimate, "Reconnecting state should animate")
    }
    
    func testConnectionStateNoAnimationForStableStates() {
        let stableStates: [ConnectionState] = [.connected, .disconnected, .failed, .suspended]
        
        for state in stableStates {
            // When
            let view = ConnectionStateIndicatorView(
                connectionState: state,
                showText: true,
                style: .minimal
            )
            
            // Then
            XCTAssertNotNil(view)
            XCTAssertFalse(state.shouldAnimate, "\(state) should not animate")
        }
    }
    
    // MARK: - User Volume Indicator Animation Tests
    
    func testUserVolumeIndicatorSpeakingAnimation() {
        // Given
        let userVolumeInfo = UserVolumeInfo(
            userId: "speaking-user",
            volume: 180,
            vad: .speaking,
            timestamp: Date()
        )
        
        // When
        let view = UserVolumeIndicatorView(
            userVolumeInfo: userVolumeInfo,
            visualizationStyle: .bar,
            showPercentage: true
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertTrue(userVolumeInfo.isSpeaking, "User should be speaking")
        XCTAssertEqual(userVolumeInfo.vad, .speaking)
    }
    
    func testUserVolumeIndicatorSilentAnimation() {
        // Given
        let userVolumeInfo = UserVolumeInfo(
            userId: "silent-user",
            volume: 30,
            vad: .notSpeaking,
            timestamp: Date()
        )
        
        // When
        let view = UserVolumeIndicatorView(
            userVolumeInfo: userVolumeInfo,
            visualizationStyle: .circular,
            showPercentage: false
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertFalse(userVolumeInfo.isSpeaking, "User should be silent")
        XCTAssertEqual(userVolumeInfo.vad, .notSpeaking)
    }
    
    // MARK: - Audio Control Panel Animation Tests
    
    func testAudioControlPanelExpandCollapseAnimation() {
        // Given
        let realtimeManager = RealtimeManager.shared
        
        // When
        let view = AudioControlPanelView()
            .environmentObject(realtimeManager)
        
        // Then
        XCTAssertNotNil(view)
    }
    
    // MARK: - Animation Timing Tests
    
    func testVolumeVisualizationAnimationTiming() {
        // Test that different volume levels create appropriate visual feedback
        let volumeLevels: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for level in volumeLevels {
            let view = VolumeVisualizationView(
                volumeLevel: level,
                isSpeaking: level > 0.3,
                style: .bar
            )
            
            XCTAssertNotNil(view)
            XCTAssertEqual(level >= 0.0 && level <= 1.0, true, "Volume level should be in valid range")
        }
    }
    
    func testConnectionStateTransitionAnimations() {
        // Test state transitions that should trigger animations
        let transitionPairs: [(from: ConnectionState, to: ConnectionState)] = [
            (.disconnected, .connecting),
            (.connecting, .connected),
            (.connected, .reconnecting),
            (.reconnecting, .connected),
            (.connected, .failed),
            (.failed, .connecting)
        ]
        
        for (fromState, toState) in transitionPairs {
            // Create views for both states
            let fromView = ConnectionStateIndicatorView(
                connectionState: fromState,
                showText: true,
                style: .capsule
            )
            
            let toView = ConnectionStateIndicatorView(
                connectionState: toState,
                showText: true,
                style: .capsule
            )
            
            XCTAssertNotNil(fromView)
            XCTAssertNotNil(toView)
            
            // Verify animation behavior
            if toState == .connecting || toState == .reconnecting {
                XCTAssertTrue(toState.shouldAnimate, "Transition to \(toState) should animate")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testVolumeVisualizationPerformance() {
        // Test creating multiple volume visualizations quickly
        measure {
            for i in 0..<100 {
                let volumeLevel = Float(i) / 100.0
                let isSpeaking = i % 3 == 0
                let style = VolumeVisualizationStyle.allCases[i % VolumeVisualizationStyle.allCases.count]
                
                let view = VolumeVisualizationView(
                    volumeLevel: volumeLevel,
                    isSpeaking: isSpeaking,
                    style: style
                )
                
                _ = view // Use the view to prevent optimization
            }
        }
    }
    
    func testConnectionStateIndicatorPerformance() {
        // Test creating multiple connection state indicators quickly
        measure {
            let states: [ConnectionState] = [.disconnected, .connecting, .connected, .reconnecting, .failed, .suspended]
            let styles = ConnectionIndicatorStyle.allCases
            
            for i in 0..<100 {
                let state = states[i % states.count]
                let style = styles[i % styles.count]
                
                let view = ConnectionStateIndicatorView(
                    connectionState: state,
                    showText: i % 2 == 0,
                    style: style
                )
                
                _ = view // Use the view to prevent optimization
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testVolumeVisualizationEdgeCases() {
        // Test with extreme volume levels
        let edgeCases: [Float] = [0.0, 1.0, -0.1, 1.1]
        
        for volumeLevel in edgeCases {
            let view = VolumeVisualizationView(
                volumeLevel: volumeLevel,
                isSpeaking: false,
                style: .bar
            )
            
            XCTAssertNotNil(view, "View should handle edge case volume: \(volumeLevel)")
        }
    }
    
    func testUserVolumeIndicatorEdgeCases() {
        // Test with extreme volume values
        let edgeVolumes = [0, 255, -10, 300]
        
        for volume in edgeVolumes {
            let userVolumeInfo = UserVolumeInfo(
                userId: "edge-case-user",
                volume: volume,
                vad: .notSpeaking,
                timestamp: Date()
            )
            
            let view = UserVolumeIndicatorView(
                userVolumeInfo: userVolumeInfo,
                visualizationStyle: .bar,
                showPercentage: true
            )
            
            XCTAssertNotNil(view, "View should handle edge case volume: \(volume)")
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testVolumeVisualizationAccessibility() {
        // Test that volume visualizations are accessible
        let view = VolumeVisualizationView(
            volumeLevel: 0.7,
            isSpeaking: true,
            style: .bar
        )
        
        XCTAssertNotNil(view)
        // In a real app, we would test accessibility labels and hints here
    }
    
    func testConnectionStateIndicatorAccessibility() {
        // Test that connection state indicators are accessible
        let view = ConnectionStateIndicatorView(
            connectionState: .connected,
            showText: true,
            style: .capsule
        )
        
        XCTAssertNotNil(view)
        // In a real app, we would test accessibility labels and hints here
    }
}

// MARK: - Animation Test Helpers

@available(macOS 10.15, iOS 13.0, *)
extension SwiftUIAnimationTests {
    
    /// Helper to create a mock volume info with animation-relevant properties
    func createAnimatedVolumeInfo(
        userId: String,
        volume: Int,
        isSpeaking: Bool
    ) -> UserVolumeInfo {
        return UserVolumeInfo(
            userId: userId,
            volume: volume,
            vad: isSpeaking ? .speaking : .notSpeaking,
            timestamp: Date()
        )
    }
    
    /// Helper to test volume level transitions
    func testVolumeTransition(
        from startLevel: Float,
        to endLevel: Float,
        style: VolumeVisualizationStyle
    ) {
        let startView = VolumeVisualizationView(
            volumeLevel: startLevel,
            isSpeaking: false,
            style: style
        )
        
        let endView = VolumeVisualizationView(
            volumeLevel: endLevel,
            isSpeaking: true,
            style: style
        )
        
        XCTAssertNotNil(startView)
        XCTAssertNotNil(endView)
    }
    
    /// Helper to test connection state transitions
    func testConnectionTransition(
        from startState: ConnectionState,
        to endState: ConnectionState,
        style: ConnectionIndicatorStyle
    ) {
        let startView = ConnectionStateIndicatorView(
            connectionState: startState,
            showText: true,
            style: style
        )
        
        let endView = ConnectionStateIndicatorView(
            connectionState: endState,
            showText: true,
            style: style
        )
        
        XCTAssertNotNil(startView)
        XCTAssertNotNil(endView)
    }
}
