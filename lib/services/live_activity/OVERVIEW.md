# DuckBuck Live Activities Implementation

This document provides an overview of how Live Activities are implemented in the DuckBuck app.

## Overview

Live Activities allow showing real-time call information in the Dynamic Island and Lock Screen on iOS 16.1+ devices. The implementation consists of two main parts:

1. **Flutter side** - `CallActivityService` in the app that manages the lifecycle of Live Activities
2. **iOS side** - `CallActivity` widget extension that displays the call information

## Setup

The implementation uses:
- App Group ID: `group.duckbuck.callactivity`
- URL Scheme: `duckbuck`

## How It Works

### Data Flow

1. When a call starts in the app, the `CallActivityService` creates a Live Activity with caller name and duration
2. The Flutter app updates the activity every second to show the current call duration
3. The iOS widget extension reads the data using `UserDefaults` with the app group ID
4. When the call ends, the Live Activity is dismissed

### Key Files

- `call_activity_service.dart` - Manages the Live Activity lifecycle from Flutter
- `call_activity_model.dart` - Data model for call activities
- `CallActivityLiveActivity.swift` - iOS widget for displaying the Live Activity

## LiveActivitiesAppAttributes

The widget extension uses a structure named `LiveActivitiesAppAttributes` which **must not be renamed** (as per documentation) to properly show activities. This structure contains:

```swift
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var callerName: String
    var callDuration: String
  }

  var id = UUID()
}
```

## Deep Linking

The Live Activity includes an "End" button that deep links back to the app using the `duckbuck://call/end` URL scheme. This allows users to end the call directly from the Lock Screen or Dynamic Island.

## Testing

To test Live Activities:
1. Run the app on an iOS 16.1+ device
2. Start a call in the app
3. Put the app in the background (home button or swipe up)
4. The Live Activity should appear in the Dynamic Island or Lock Screen

## Troubleshooting

- Ensure the app group ID is correctly set up in both targets
- Check that the widget extension displays the activity properly
- Verify that the URL scheme works for deep linking back to the app 