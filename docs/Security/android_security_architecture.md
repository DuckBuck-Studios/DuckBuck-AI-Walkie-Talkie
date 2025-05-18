# DuckBuck Android Security Architecture

## Overview

The DuckBuck app implements a comprehensive security architecture that centralizes all security operations through a `SecurityManager` class. This document explains the components of this architecture and how they work together.

## Components

### SecurityManager

This is the central hub for all security features and provides a unified interface for the app to interact with security features. It handles:

- SSL Certificate Pinning
- App tamper detection
- Root detection
- Secure data storage and encryption
- Screen capture protection
- Integrity validation via Google Play Integrity API

### RootDetector

Detects if a device is rooted/jailbroken using multiple detection methods:
- Checking for root-related files and packages
- Testing for su binary and busybox
- Examining build tags for test keys

### TamperDetector

Verifies the app's signature to detect if it has been tampered with or modified by:
- Retrieving and validating the signing certificate
- Comparing against expected certificate hash
- Providing signature verification results

### IntegrityChecker

Integrates with Google Play Integrity API to:
- Request integrity tokens for server validation
- Configure Firebase App Check for additional security
- Generate nonces for integrity checking

### SSLPinningManager

Implements certificate pinning to prevent man-in-the-middle attacks by:
- Pinning certificates for different domains
- Providing production and development OkHttpClient builders
- Logging certificate information in debug mode

## Integration in MainActivity

The MainActivity has been simplified to use only the SecurityManager for all security operations:
- Initializes SecurityManager with appropriate development/production mode
- Sets up a method channel for Flutter to interact with security features
- No longer contains individual security component imports or methods

## Security Flow

1. On app start, MainActivity initializes SecurityManager
2. SecurityManager initializes all security components and runs initial checks
3. Flutter code interacts with security features through the method channel
4. SecurityManager handles all security operations and returns results

## Security Operations

The SecurityManager provides these core operations:
- `initialize()`: Sets up all security components
- `performSecurityChecks()`: Runs all security validations
- `isDeviceRooted()`: Checks for root access
- `verifyAppSignature()`: Verifies app hasn't been tampered with
- `requestIntegrityToken()`: Gets token from Google Play Integrity
- Secure data storage with encrypted shared preferences
- String encryption/decryption using AES-GCM
- Screen capture protection controls

## Development vs Production

The security implementation distinguishes between development and production environments:
- In development (BuildConfig.DEBUG = true): 
  - Less stringent security checks
  - Development SSL certificates
  - More verbose logging
- In production:
  - Strict security checks
  - Production certificate pinning
  - Limited logging

## Best Practices

1. Never access security components directly; always go through SecurityManager
2. Always initialize SecurityManager at app startup
3. Use the security method channel for Flutter-side security operations
4. Test security features in both development and production modes
5. Regular certificate rotation for production environments
