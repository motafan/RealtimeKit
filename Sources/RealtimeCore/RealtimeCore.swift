// RealtimeCore.swift
// Main RealtimeCore module file

// MARK: - Protocols
@_exported import struct Foundation.Date
@_exported import struct Foundation.UUID
@_exported import class Foundation.UserDefaults

// Re-export all protocols
public protocol RTCProviderProtocol: RTCProvider {}
public protocol RTMProviderProtocol: RTMProvider {}
public protocol MessageProcessorProtocol: MessageProcessor {}
public protocol MessageProcessorManagerProtocol: MessageProcessorManager {}

// MARK: - Core Types
// All models and enums are automatically available through their individual files

/// RealtimeCore version information
public struct RealtimeCoreVersion {
    public static let current = "1.0.0"
    public static let build = "1"
}