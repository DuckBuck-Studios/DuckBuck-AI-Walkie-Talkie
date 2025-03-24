# DuckBuck - Internet Walkie Talkie

![DuckBuck Logo](assets/app_icon.png)

## 🧠 Project Attribution

> **Core Logic & Concept:** Rudra Sahoo  
> **Design & Development:** Claude 3.5 Sonnet & Claude 3.7  
> **Debugging & Optimization:** ChatGPT 4.0 & DeepSeek Models

*This project showcases the power of AI-assisted development while maintaining human-directed innovation.*

## Overview

DuckBuck is an innovative internet walkie-talkie application that enables real-time voice communication over the internet. Unlike traditional messaging apps, DuckBuck focuses on a simple, push-to-talk experience that feels like using a walkie-talkie but works globally through an internet connection. With stunning animations and a modern interface, DuckBuck delivers a delightful user experience while maintaining reliable communication anywhere with internet access.

Connect with friends and family anytime, anywhere—just press, talk, and release. No complicated setups, no phone numbers needed, just instant communication with beautiful, fluid animations that make every interaction satisfying.

### Key Features

- **Instant Push-to-Talk Communication**: Long-press on a friend's card to establish immediate audio connection
- **Dynamic Locking Mechanism**: Intuitive swipe-to-lock feature for hands-free conversations with fluid animations
- **Call Controls**: Easily toggle mic, video, and speaker during conversations with animated feedback
- **Status Animation System**: Express yourself with eye-catching Lottie animations as status indicators
- **Advanced UI Animations**: Smooth transitions, gesture-based interactions, and visual feedback throughout the app
- **Cross-Platform Support**: Available for both Android and iOS with consistent experience
- **Background Audio Processing**: Receive and join audio channels even when the app is in a killed state
- **Minimal Battery Usage**: Optimized for extended use without draining your device's battery
- **Modern UI Design**: Beautiful and intuitive interface with responsive animations using NeopPop and Flutter Animate

## Technical Details

DuckBuck leverages the following technologies:

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| **flutter** | SDK | Cross-platform UI toolkit |
| **cupertino_icons** | ^1.0.8 | iOS-style icons |
| **agora_rtc_engine** | ^6.5.1 | Real-time voice communication |
| **flutter_animate** | ^4.5.2 | Advanced UI animations and transitions |
| **lottie** | ^3.3.1 | High-quality interactive animations |

### Firebase Services

| Package | Version | Purpose |
|---------|---------|---------|
| **firebase_core** | ^3.12.1 | Core Firebase functionality |
| **firebase_auth** | ^5.5.1 | User authentication |
| **cloud_firestore** | ^5.6.5 | NoSQL database for user data and settings |
| **firebase_messaging** | ^15.2.4 | Push notifications for calls |
| **firebase_analytics** | ^11.4.4 | App usage analytics |
| **firebase_crashlytics** | ^4.3.4 | Crash reporting |
| **firebase_app_check** | ^0.3.2+4 | Security verification |
| **firebase_storage** | ^12.4.4 | Storage for user profile images |
| **firebase_database** | ^11.3.4 | Realtime database for online status |

### Authentication

| Package | Version | Purpose |
|---------|---------|---------|
| **sign_in_with_apple** | ^6.1.4 | Apple authentication |
| **google_sign_in** | ^6.3.0 | Google authentication |
| **flutter_secure_storage** | ^9.2.4 | Secure credential storage |

### UI Components

| Package | Version | Purpose |
|---------|---------|---------|
| **shimmer** | ^3.0.0 | Loading animation effects |
| **neopop** | ^1.0.2 | Modern UI elements with depth |
| **dots_indicator** | ^4.0.1 | Animated page indicators |
| **flutter_slidable** | ^4.0.0 | Swipeable list items |
| **cached_network_image** | ^3.3.1 | Efficient image loading with caching |
| **country_code_picker** | ^3.2.0 | Country selection UI |

### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| **provider** | ^6.1.2 | State management |
| **dio** | ^5.8.0+1 | HTTP client for API requests |
| **flutter_dotenv** | ^5.2.1 | Environment variable management |
| **url_launcher** | ^6.3.1 | Opening external links |
| **intl** | ^0.20.2 | Internationalization and formatting |
| **retry** | ^3.1.2 | Auto-retry for network operations |
| **mobile_scanner** | ^6.0.7 | QR code scanning |
| **qr_flutter** | ^4.1.0 | QR code generation |
| **image_picker** | ^1.1.2 | Select images from gallery or camera |
| **image_cropper** | ^9.0.0 | Image editing capabilities |
| **share_plus** | ^10.1.4 | Content sharing functionality |

### Animation System

DuckBuck features a sophisticated animation system powered by Flutter Animate and Lottie:

- **Gesture Animations**: Fluid responses to swipes, taps, and long presses
- **Transition Animations**: Smooth navigation between screens with custom page transitions
- **Micro-interactions**: Subtle animations for buttons, toggles, and user feedback
- **Status Animations**: Custom Lottie animations for user status expression
- **Onboarding Animations**: Engaging walkthroughs with sequenced animations
- **Call Interface Animations**: Dynamic visual feedback during audio calls

### Connectivity Features

DuckBuck ensures reliable communication with:

- **Seamless Reconnection**: Automatically reconnects when internet access is restored
- **Background Processing**: FCM-powered notifications that work even when the app is closed
- **Adaptive Quality**: Adjusts audio quality based on connection strength
- **Minimal Data Usage**: Optimized data transmission for lower bandwidth consumption
- **Foreground Service**: Android implementation ensures call continuity in background
- **Native Integration**: Leverages Kotlin for better performance and OS integration

## Installation

### Prerequisites

- Flutter SDK v3.19 or higher
- Dart SDK v3.2 or higher
- Android Studio / Xcode
- Firebase project with Firestore and Authentication enabled
- Agora developer account with an App ID

### Setup

1. Clone the repository:
   ```
   git clone https://github.com/your-username/duckbuck.git
   ```

2. Navigate to the project directory:
   ```
   cd duckbuck
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Configure Firebase:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective app directories
   - Enable Authentication, Firestore, and FCM in your Firebase Console

5. Configure Agora:
   - Add your Agora App ID to the `android/app/src/main/kotlin/com/example/duckbuck/AgoraService.kt` file
   - Update the Agora App ID in the Flutter side configuration

6. Run the application:
   ```
   flutter run
   ```

## Usage

1. **Sign up/Login**: Create an account or log in using Google or Apple authentication
2. **Add Friends**: Scan QR codes or search for friends by username
3. **Talk**: Long-press on a friend's card to start a conversation
4. **Hands-free Mode**: Swipe in the indicated direction to lock the conversation
5. **Call Controls**: Use the on-screen controls to manage microphone, video, and speaker settings

## Platform Support

- Android 8.0+ (API level 26+)
- iOS 12.0+

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Team & Credits

| Role | Attribution |
|------|-------------|
| **Concept & Project Lead** | Rudra Sahoo |
| **Design & Development** | Claude 3.5 Sonnet & Claude 3.7 |
| **Debugging & Optimization** | ChatGPT 4.0 & DeepSeek Models |
| **UI/UX Design Assistant** | Claude 3.7 |
| **Code Refactoring** | Claude 3.5 Sonnet |
| **Performance Optimization** | DeepSeek Models |

*This collaborative project demonstrates how human creativity and AI capabilities can work together to create innovative applications.*

## Acknowledgements

- The Agora team for their excellent RTC engine
- The Flutter community for their support and resources
- Firebase for providing a robust backend infrastructure

## Using the Friend Card for Calls

The Friend Card component has been modularized to better handle both initiating and receiving calls.

### Initiating a Call

To initiate a call to a friend, use the static method:

```dart
// friend is a Map containing 'id', 'displayName' or 'name', and 'photoURL'
FriendCard.initiateCall(context, friend);
```

This will show a friend card that can be long-pressed to start a call. The call will send an FCM notification to the friend and show the connecting animation.

### Receiving a Call

When an FCM notification is received for an incoming call, pass the call data to the static method:

```dart
// In your FCM message handler
void handleFCMMessage(Map<String, dynamic> message) {
  final callData = message['data'];
  if (callData != null && callData['type'] == 'call') {
    FriendCard.handleIncomingCall(context, callData);
  }
}
```

This will find the appropriate friend card and show the incoming call UI.

### How It Works

The Friend Card uses three modular components:

1. `FriendCardInitiator` - Handles the initiator side of calls
2. `FriendCardReceiver` - Handles the receiver side of calls
3. `FriendCardUI` - Shared UI components for both sides

When a user long-presses a friend card, it triggers the call animation and sends an FCM notification. When the other user receives the notification, they see the incoming call screen which directly goes to full screen mode.

Both sides have controls for microphone, video, speaker, and ending the call, with permission checks for sensitive functionality.
