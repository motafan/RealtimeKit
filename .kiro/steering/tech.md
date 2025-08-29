# RealtimeKit Technical Stack

## Build System & Package Management

- **Swift Package Manager (SPM)**: Primary build system and dependency management
- **Package.swift**: Swift 6.0 tools version with strict concurrency enabled
- **Xcode Workspaces**: Examples.xcworkspace for demo applications

## Core Technologies

- **Swift 6.2+**: Modern Swift with strict concurrency features
- **Swift Concurrency**: async/await, actors, structured concurrency throughout
- **Combine Framework**: Reactive programming for data streams and UI updates
- **SwiftUI**: Declarative UI framework support
- **UIKit**: Traditional imperative UI framework support

## Architecture Patterns

- **Protocol-Oriented Programming**: Core abstractions via RTCProvider, RTMProvider protocols
- **Factory Pattern**: Provider creation and management
- **Observer Pattern**: Event handling and state notifications
- **Repository Pattern**: Data persistence and storage management
- **MVVM**: Recommended pattern for UI layers

## Concurrency & Threading

- **@MainActor**: UI updates and main thread operations
- **Sendable Protocol**: Thread-safe data types
- **Actor Isolation**: Thread-safe state management
- **Structured Concurrency**: Task groups and async sequences

## Storage & Persistence

- **@RealtimeStorage**: Custom property wrapper for automatic persistence
- **@SecureRealtimeStorage**: Secure storage for sensitive data (tokens)
- **UserDefaults**: Underlying storage mechanism
- **Keychain**: Secure storage backend

## Localization

- **Built-in i18n**: Support for 5 languages (en, zh-Hans, zh-Hant, ja, ko)
- **NSLocalizedString**: Standard localization mechanism
- **Resource Bundles**: Organized .lproj directories

## Testing Framework

- **Swift Testing**: Modern testing framework (not XCTest)
- **Mock Providers**: RealtimeMocking module for testing
- **Test Targets**: Separate test modules per package

## Common Commands

### Building
```bash
# Build all targets
swift build

# Build specific target
swift build --target RealtimeCore

# Build for release
swift build -c release
```

### Testing
```bash
# Run all tests
swift test

# Run specific test target
swift test --filter RealtimeCoreTests

# Run with code coverage
swift test --enable-code-coverage
```

### Demo Applications
```bash
# Open in Xcode
open Examples.xcworkspace

# Build SwiftUI demo
xcodebuild -workspace Examples.xcworkspace -scheme SwiftUIDemo

# Build UIKit demo  
xcodebuild -workspace Examples.xcworkspace -scheme UIKitDemo
```

### Package Management
```bash
# Resolve dependencies
swift package resolve

# Update dependencies
swift package update

# Generate Xcode project
swift package generate-xcodeproj
```

## Development Tools

- **SwiftLint**: Code style enforcement (recommended)
- **SwiftFormat**: Code formatting (recommended)
- **Periphery**: Dead code detection
- **Sourcery**: Code generation

## Platform-Specific Features

### iOS
- Background app state handling
- Audio session management
- Microphone/camera permissions

### macOS
- App lifecycle notifications
- Audio device management
- Window state preservation