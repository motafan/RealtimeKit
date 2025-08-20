// RealtimeKit.swift
// Main module that re-exports all RealtimeKit functionality

@_exported import RealtimeCore
@_exported import RealtimeUIKit
@_exported import RealtimeSwiftUI
@_exported import RealtimeAgora

/// RealtimeKit version information
public struct RealtimeKitVersion {
    public static let current = "1.0.0"
    public static let build = "1"
}