# DuckBuck Authentication Testing Guide

This document provides a comprehensive guide for testing the authentication system of the DuckBuck application. It covers manual testing strategies for testing with real Firebase services using physical and virtual devices.

## Table of Contents

1. [Testing Prerequisites](#testing-prerequisites)
2. [Manual Testing Process](#manual-testing-process)
3. [Testing Different Auth Methods](#testing-different-auth-methods)
4. [Security Testing](#security-testing)
5. [Performance Testing](#performance-testing)
6. [Test Account Management](#test-account-management)
7. [Troubleshooting Common Issues](#troubleshooting-common-issues)

## Testing Prerequisites

Before conducting authentication testing, ensure the following prerequisites are in place:

### 1. Testing Environment Setup

- **Firebase Project Setup**: Use a dedicated Firebase test project separate from production
- **Testing Device Set**: Multiple physical devices or emulators covering iOS and Android platforms
- **Test Firebase Console Access**: Ensure you have access to the Firebase console for test project
- **Test User Accounts**: Create various accounts for different authentication scenarios

### 2. Firebase Console Preparation

- Ensure all authentication methods are enabled in the Firebase Console:
  - Google Sign-In
  - Apple Sign-In
  - Phone Authentication
- Configure proper SHA-1 and SHA-256 keys for Android test builds
- Set up Apple Sign-In in the Apple Developer portal for iOS testing

### 3. Device/Emulator Preparation

- Ensure Google Play Services are updated on Android emulators and devices
- For iOS simulators, note that certain authentication methods may have limitations
- Install the latest version of the app build for testing

## Manual Testing Process

Follow this process to thoroughly test the authentication system:

### 1. Onboarding Flow Testing

1. **Install fresh app** and verify first-time experience
2. **Navigate through welcome screens**:
   - Verify slide action functionality on welcome screen
   - Check all onboarding screen transitions
   - Test "Get Started" button on final onboarding screen
3. **Verify auth bottom sheet appears** with all auth options

### 2. Testing Auth Methods

For each authentication method (Google, Apple, Phone), verify:

1. **Button UI states**:
   - Normal state
   - Pressed state
   - Loading state (individual loaders)
   - Disabled state when another auth is in progress
2. **Authentication flow**:
   - Proper API calls to Firebase Auth
   - Handling of successful auth
   - Proper error handling and user feedback
3. **Post-authentication**:
   - User data creation in Firestore
   - Proper navigation to next screen
   - Session persistence between app restarts

### 3. Testing Edge Cases

1. **Network interruptions**:
   - Simulate poor connectivity during sign-in
   - Test auth flow with airplane mode toggled mid-flow
2. **Cancellations**:
   - Cancel authentication dialog (e.g., Google Sign-In popup)
   - Cancel phone verification process
3. **Invalid inputs**:
   - Test invalid phone numbers
   - Test invalid OTP codes

## Testing Different Auth Methods

### 1. Google Sign-In Testing

1. **Test with various Google accounts**:
   - Brand new Google account (never used with app)
   - Previously authenticated Google account
   - Account with different domains (@gmail.com vs G Suite)
2. **Check Firebase console** after sign-in to verify user creation
3. **Verify data in Firestore**:
   - New user document created
   - User data properly saved with Google auth provider information

### 2. Apple Sign-In Testing (iOS Only)

1. **Test with various Apple IDs**:
   - Account with hiding email option
   - Account with real email sharing
2. **Verify sign-in on different iOS versions**
3. **Check user creation** in Firebase console and Firestore

### 3. Phone Authentication Testing

1. **Test with various phone numbers**:
   - Domestic numbers
   - International numbers with different country codes
   - Numbers with and without formatting characters
2. **Test OTP verification**:
   - Auto-fill functionality where supported
   - Manual code entry
   - Invalid code scenarios
   - Resend code functionality
3. **Verify timeout handling** for OTP code

## Security Testing

Manual tests to verify security aspects:

### 1. Token Management

1. **Session persistence**:
   - Authenticate, then close and reopen app
   - Verify user remains authenticated
   - Check if token refresh occurs properly
2. **Force logout scenarios**:
   - Change password in Firebase Console
   - Delete user in Firebase Console
   - Verify app handles these scenarios properly

### 2. Device Security

1. **Biometric authentication** (if implemented):
   - Test finger/face authentication flows
   - Test fallback mechanisms
2. **App background/foreground transition**:
   - Test authentication state after app is in background for extended periods
   - Verify auth state after system-initiated app termination

## Performance Testing

Manual performance evaluation:

### 1. Authentication Speed

1. **Measure login times** with a stopwatch:
   - Google Sign-In response time
   - Apple Sign-In response time
   - Phone verification code sending time
   - OTP verification time
2. **Compare performance** across different network conditions:
   - WiFi
   - Cellular data (4G/5G)
   - Poor network conditions

### 2. UI Responsiveness

1. **Evaluate UI feedback** during authentication:
   - Loading indicators appear promptly
   - No UI freezes during authentication processes
   - Smooth transitions between auth stages
2. **Test on low-end devices** to ensure acceptable performance

## Test Account Management

### 1. Creating Test Accounts

1. **Google Test Accounts**:
   - Create dedicated testing Google accounts
   - Document account credentials in a secure location
2. **Phone Test Numbers**:
   - Document phone numbers used for testing
   - Use consistent phone numbers across test cycles

### 2. Managing Test Data

1. **Regular cleanup** in Firebase Console:
   - Remove test users periodically to keep the database clean
   - Document the cleanup process and schedule
2. **Test user identification**:
   - Add metadata to test users to identify them
   - Consider adding a "test" flag in user documents

## Troubleshooting Common Issues

### 1. Authentication Failures

**Symptom**: User authentication fails with error messages

**Solution**:
- Verify Firebase project settings are correct
- Check SHA-1 and SHA-256 keys are properly configured for Android
- Ensure App ID and Team ID are correct for Apple Sign-In
- Verify phone authentication is enabled and not restricted by region

### 2. Session Management Issues

**Symptom**: Users are unexpectedly logged out

**Solution**:
- Check token refresh logic
- Verify token expiration handling
- Review any security rules that might invalidate sessions

### 3. Database Permission Errors

**Symptom**: Authentication succeeds but database operations fail

**Solution**:
- Check Firestore security rules for authenticated users
- Verify user documents are created with proper structure
- Ensure user has necessary permissions in Firebase Console

## Device Support Testing

### 1. Platform-Specific Testing

1. **Android Device Testing**:
   - Test on various Android versions (10, 11, 12, 13)
   - Test on different screen sizes and resolutions
   - Verify compatibility with major manufacturers' UI overlays (Samsung, Xiaomi, etc.)

2. **iOS Device Testing**:
   - Test on latest iOS version and one version back
   - Test on different iPhone models (standard, Pro, Max)
   - Verify proper keyboard handling with auth inputs

### 2. Features Behavior by Platform

1. **Google Sign-In**:
   - Available on both Android and iOS
   - Verify Google account selection UI on both platforms
   - Test handling of multiple Google accounts on device

2. **Apple Sign-In**:
   - iOS only - verify graceful failure or hiding on Android
   - Test on iOS 13+ (where Sign In with Apple is required)

3. **Phone Authentication**:
   - Test SMS auto-verification on Android
   - Test manual input on iOS (auto-fill often less reliable)

## Accessibility Testing

### 1. Screen Reader Support

1. **Test with VoiceOver (iOS) and TalkBack (Android)**:
   - Ensure all authentication UI components are properly labeled
   - Verify focus order during authentication flows
   - Check that error messages are announced appropriately

2. **Test Dynamic Text Sizes**:
   - Verify UI handles larger font sizes set in system settings
   - Check that buttons remain usable with largest accessibility text

### 2. Input Methods

1. **Alternative Input Testing**:
   - Test keyboard-only navigation for authentication forms
   - Verify voice input functions correctly for phone numbers and codes
   - Check compatibility with external keyboards and input devices

### 3. Color and Contrast

1. **Test with Color Blindness Simulation**:
   - Verify that error states are perceivable without color perception
   - Check that success indicators don't rely solely on color
   - Validate sufficient contrast ratios (WCAG AA compliant)
