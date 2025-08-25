import Testing
@testable import RealtimeCore

/// 简化的转推流管理器测试
/// 需求: 7.2, 7.3, 7.4 - 转推流控制逻辑和状态转换测试
@Suite("Stream Push Manager Simple Tests")
struct StreamPushManagerSimpleTests {
    
    @Test("StreamPushState should have correct transition capabilities")
    func testStreamPushStateTransitions() async throws {
        // Test canStart
        #expect(StreamPushState.stopped.canStart == true)
        #expect(StreamPushState.failed.canStart == true)
        #expect(StreamPushState.running.canStart == false)
        #expect(StreamPushState.starting.canStart == false)
        #expect(StreamPushState.stopping.canStart == false)
        
        // Test canStop
        #expect(StreamPushState.running.canStop == true)
        #expect(StreamPushState.starting.canStop == true)
        #expect(StreamPushState.stopped.canStop == false)
        #expect(StreamPushState.failed.canStop == false)
        #expect(StreamPushState.stopping.canStop == false)
        
        // Test canUpdateLayout
        #expect(StreamPushState.running.canUpdateLayout == true)
        #expect(StreamPushState.stopped.canUpdateLayout == false)
        #expect(StreamPushState.starting.canUpdateLayout == false)
        #expect(StreamPushState.stopping.canUpdateLayout == false)
        #expect(StreamPushState.failed.canUpdateLayout == false)
    }
    
    @Test("StreamPushStatistics should initialize correctly")
    func testStatisticsInitialization() async throws {
        let stats = StreamPushStatistics()
        
        #expect(stats.totalDuration == 0)
        #expect(stats.layoutUpdateCount == 0)
        #expect(stats.errorCount == 0)
        #expect(stats.retryCount == 0)
        #expect(stats.averageBitrate == 0)
        #expect(stats.frameDropRate == 0)
        #expect(stats.networkLatency == 0)
    }
    
    @Test("StreamPushStatistics should reset correctly")
    func testStatisticsReset() async throws {
        var stats = StreamPushStatistics()
        
        // Set some values
        stats.totalDuration = 100
        stats.layoutUpdateCount = 5
        stats.errorCount = 2
        stats.averageBitrate = 1000
        
        // Reset
        stats.reset()
        
        #expect(stats.totalDuration == 0)
        #expect(stats.layoutUpdateCount == 0)
        #expect(stats.errorCount == 0)
        #expect(stats.averageBitrate == 0)
    }
    
    @Test("StreamPushStatistics should update correctly")
    func testStatisticsUpdate() async throws {
        var stats = StreamPushStatistics()
        
        stats.update(
            duration: 120,
            bitrate: 2000,
            frameDropRate: 0.5,
            latency: 50
        )
        
        #expect(stats.totalDuration == 120)
        #expect(stats.averageBitrate == 2000)
        #expect(stats.frameDropRate == 0.5)
        #expect(stats.networkLatency == 50)
    }
    
    @Test("StreamPushError should provide correct descriptions")
    func testStreamPushErrorDescriptions() async throws {
        let configError = StreamPushError.invalidConfiguration("test reason")
        #expect(configError.errorDescription?.contains("Invalid stream push configuration") == true)
        
        let startError = StreamPushError.startFailed("test reason")
        #expect(startError.errorDescription?.contains("Failed to start stream push") == true)
        
        let stopError = StreamPushError.stopFailed("test reason")
        #expect(stopError.errorDescription?.contains("Failed to stop stream push") == true)
        
        let layoutError = StreamPushError.layoutUpdateFailed("test reason")
        #expect(layoutError.errorDescription?.contains("Failed to update stream layout") == true)
        
        let stateError = StreamPushError.invalidState(current: .stopped, expected: .running)
        #expect(stateError.errorDescription?.contains("Invalid state transition") == true)
        
        let providerError = StreamPushError.providerNotAvailable
        #expect(providerError.errorDescription?.contains("provider is not available") == true)
    }
}