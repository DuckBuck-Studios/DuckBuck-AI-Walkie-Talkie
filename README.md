# DuckBuck

<div align="center">
  <img src="assets/logo.png" alt="DuckBuck Logo" width="250" />
</div>

DuckBuck is a feature-rich mobile application built with Flutter that provides a secure and intuitive platform for social connections and messaging.

## Authentication System

DuckBuck implements a robust authentication system with multiple sign-in options to enhance user experience and security:

### Authentication Methods

- **Google Sign-In**: Fast authentication using Google accounts
- **Apple Sign-In**: Secure authentication for iOS users with privacy options
- **Phone Authentication**: OTP-based verification using phone numbers

### Architecture

The authentication system follows a layered architecture:
- **UI Layer**: Welcome screen, onboarding flow, and authentication bottom sheet
- **Provider Layer**: Manages auth state and propagates changes to UI
- **Repository Layer**: Coordinates auth operations and user data persistence
- **Service Layer**: Implements Firebase authentication services
- **Model Layer**: Defines user data structures

For detailed documentation:
- [Authentication Architecture](docs/auth_architecture.md)
- [Authentication Testing Guide](docs/auth_testing_guide.md)

### Security Features

- Secure token management and refresh cycles
- Session persistence with proper invalidation
- Protection against common authentication vulnerabilities
- Device-specific security features integration

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK  
- iOS development: Xcode and iOS Simulator
- Android development: Android Studio and Android SDK

### Quick Setup

1. **Set up environment:**
   ```bash
   cp .env.example .env
   # Edit .env and add your DUCKBUCK_API_KEY
   ```

2. **Run in development:**
   ```bash
   ./scripts/run-dev.sh
   ```

3. **Build for production:**
   ```bash
   ./scripts/build.sh release
   ```

### Development Workflow

The project includes production-ready scripts for streamlined development:

#### Development Script
```bash
# Run on default device
./scripts/run-dev.sh

# Run on specific device
./scripts/run-dev.sh "iPhone 15 Pro"
./scripts/run-dev.sh "Pixel 7 API 34"
```

Features:
- Automatic environment loading from `.env`
- Device detection and selection
- Hot reload enabled
- Security verification (shows truncated API key)

#### Build Script
```bash
./scripts/build.sh [debug|release|ios-debug|ios-release]
```

Features:
- Environment validation
- Secure environment variable passing
- Multi-platform support
- Optimized production builds

For detailed configuration, see [Environment Setup Guide](docs/ENVIRONMENT_SETUP.md).

### Development Resources

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
