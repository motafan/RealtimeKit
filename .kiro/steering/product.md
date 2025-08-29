# RealtimeKit Product Overview

RealtimeKit is a unified Swift Package for integrating multiple third-party RTM (Real-Time Messaging) and RTC (Real-Time Communication) service providers, providing a unified real-time communication solution for iOS/macOS applications.

## Core Features

- **Unified API Interface**: Protocol abstraction that shields differences between service providers
- **Plugin Architecture**: Support for dynamic switching and extension of multiple service providers  
- **Dual Framework Support**: Complete support for both UIKit and SwiftUI
- **Multi-language Support**: Built-in localization for Chinese (Simplified/Traditional), English, Japanese, Korean
- **Automatic State Persistence**: @AppStorage-like automatic state management
- **Modern Concurrency**: Full adoption of Swift Concurrency (async/await, actors)
- **Volume Indicators**: Real-time volume detection and visualization
- **Stream Push Support**: Support for live streaming to third-party platforms
- **Media Relay**: Cross-channel audio/video stream forwarding
- **Token Auto-renewal**: Intelligent token management and renewal

## Target Platforms

- iOS 13.0+
- macOS 10.15+
- Swift 6.2+
- Xcode 15.0+

## Supported Providers

- ✅ Agora: Full support
- 🚧 Tencent Cloud TRTC: In development
- 🚧 ZEGO: In development
- ✅ Mock Provider: Testing support

## Architecture Philosophy

The project follows a modular, protocol-oriented design with provider abstraction, allowing seamless switching between different real-time communication service providers while maintaining a consistent API surface.