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

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
