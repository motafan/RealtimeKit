// StorageExampleTests.swift
// Tests for storage example usage

import Testing
import Foundation
@testable import RealtimeCore

@Suite("Storage Example Tests")
struct StorageExampleTests {
    
    @Test("Storage example usage test")
    func testStorageExampleUsage() async throws {
        let example = StorageExample()
        
        // Should not throw any errors
        try example.exampleUsage()
        try example.exampleCustomStorage()
        
        // Test RealtimeStorage example (no throws)
        example.exampleRealtimeStorage()
        
        // Give some time for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
    }
}