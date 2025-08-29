# RealtimeKit Project Structure

## Package Organization

The project follows a modular Swift Package structure with clear separation of concerns:

```
RealtimeKit/
├── Package.swift                    # Swift Package manifest
├── Sources/                         # Source code modules
├── Tests/                          # Test modules  
├── SwiftUIDemo/                    # SwiftUI example app
├── UIKitDemo/                      # UIKit example app
├── Examples.xcworkspace/           # Workspace for demos
└── docs/                          # Documentation
```

## Source Modules

### RealtimeKit (Main Module)
- **Purpose**: Umbrella module that re-exports all functionality
- **Location**: `Sources/RealtimeKit/`
- **Dependencies**: All other modules
- **Usage**: Single import for complete functionality

### RealtimeCore (Core Module)
- **Purpose**: Core protocols, models, and managers
- **Location**: `Sources/RealtimeCore/`
- **Structure**:
  - `Protocols/` - RTCProvider, RTMProvider, MessageProcessor
  - `Models/` - Data models and enums
  - `Managers/` - RealtimeManager and sub-managers
  - `Storage/` - Persistence and caching
  - `Resources/` - Localization files (.lproj)

### UI Framework Modules
- **RealtimeUIKit**: `Sources/RealtimeUIKit/` - UIKit integration
- **RealtimeSwiftUI**: `Sources/RealtimeSwiftUI/` - SwiftUI components

### Provider Modules
- **RealtimeAgora**: `Sources/RealtimeAgora/` - Agora SDK integration
- **RealtimeMocking**: `Sources/RealtimeMocking/` - Mock provider for testing

## Core Module Structure

### Protocols Directory
- `RTCProvider.swift` - Real-time communication interface
- `RTMProvider.swift` - Real-time messaging interface  
- `MessageProcessor.swift` - Message processing pipeline

### Models Directory
- `CoreModels.swift` - Basic enums and types
- `ConnectionModels.swift` - Connection state models
- `AudioStatusModels.swift` - Audio-related models
- `VolumeModels.swift` - Volume detection models
- `StreamModels.swift` - Stream push models
- `UserRole.swift` - User role definitions
- `LocalizedErrors.swift` - Error localization

### Managers Directory
- `RealtimeManager.swift` - Main coordinator (3000+ lines)
- `ConnectionStateManager.swift` - Connection lifecycle
- `TokenManager.swift` - Authentication tokens
- `VolumeIndicatorManager.swift` - Volume detection
- `MediaRelayManager.swift` - Cross-channel relay
- `StreamPushManager.swift` - Live streaming
- `LocalizationManager.swift` - i18n support

### Storage Directory
- `RealtimeStorage.swift` - Persistence framework
- `AudioSettingsManager.swift` - Audio settings storage
- `UserSessionManager.swift` - Session persistence
- `MessageProcessingManager.swift` - Message handling

## Test Structure

### Test Organization
- `Tests/RealtimeCoreTests/` - Core functionality tests
- `Tests/RealtimeMockingTests/` - Mock provider tests
- Each test file corresponds to a source file (e.g., `RealtimeManagerTests.swift`)

### Test Naming Convention
- Unit tests: `[ClassName]Tests.swift`
- Integration tests: `[Feature]IntegrationTests.swift`
- UI tests: `[Framework][Component]Tests.swift`

## Demo Applications

### SwiftUIDemo
- **Purpose**: Modern declarative UI example
- **Structure**: Standard SwiftUI app structure
- **Key Files**: `ContentView.swift`, `SwiftUIDemoApp.swift`

### UIKitDemo  
- **Purpose**: Traditional imperative UI example
- **Structure**: Standard UIKit app structure
- **Key Files**: `ViewController.swift`, `AppDelegate.swift`

## Documentation Structure

### Core Documentation
- `API-Reference.md` - Complete API documentation
- `Quick-Start-Guide.md` - Getting started tutorial
- `Best-Practices.md` - Architecture and coding guidelines

### Specialized Guides
- `Localization-Guide.md` - i18n implementation
- `Storage-Guide.md` - Persistence patterns
- `Migration-Guide.md` - Version upgrade guide

## File Naming Conventions

### Swift Files
- **Classes**: PascalCase (e.g., `RealtimeManager.swift`)
- **Protocols**: PascalCase with descriptive suffix (e.g., `RTCProvider.swift`)
- **Models**: Descriptive + "Models" suffix (e.g., `AudioStatusModels.swift`)
- **Extensions**: ClassName + "Extensions" (e.g., `LocalizedExtensions.swift`)

### Resource Files
- **Localization**: Standard .lproj structure (`en.lproj/Localizable.strings`)
- **Assets**: Organized in .xcassets bundles
- **Configuration**: Descriptive names (e.g., `RTCConfig.swift`)

## Import Organization

### Module Imports
```swift
// System frameworks first
import Foundation
import Combine
import SwiftUI

// Third-party dependencies
// (Currently none, but would go here)

// Internal modules
import RealtimeCore
```

### Conditional Imports
```swift
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
```

## Code Organization Patterns

### File Structure Template
```swift
// MARK: - Imports
import Foundation

// MARK: - Protocol/Class Definition
public protocol/class Name {
    
    // MARK: - Public Properties
    
    // MARK: - Private Properties
    
    // MARK: - Initialization
    
    // MARK: - Public Methods
    
    // MARK: - Private Methods
}

// MARK: - Extensions
extension Name {
    // Grouped functionality
}
```

### Manager Class Pattern
- Singleton access via `.shared`
- `@MainActor` for UI-related managers
- Combine publishers for reactive updates
- Private sub-managers for specialized functionality
- Clear separation of public/internal/private APIs