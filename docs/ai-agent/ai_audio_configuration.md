# AI Audio Configuration Integration

This document outlines the integration of Agora Conversational AI Engine audio enhancements into the DuckBuck walkie-talkie system.

## Overview

The AI audio configuration provides enhanced audio quality through:
- **AI Denoising**: Removes background noise intelligently
- **AI Echo Cancellation**: Eliminates echo for clearer conversations
- **AI Audio Scenario**: Optimized audio parameters for conversational AI
- **Dynamic Configuration**: Auto-reconfigures on audio route changes

## Architecture

### Native Android (Kotlin)

#### AgoraService.kt (`com.duckbuck.app.services.agora`)
- **`loadAiDenoisePlugin()`**: Loads AI denoising dynamic library
- **`loadAiEchoCancellationPlugin()`**: Loads AI echo cancellation dynamic library
- **`enableAiDenoising(enabled)`**: Enables/disables AI denoising extension
- **`enableAiEchoCancellation(enabled)`**: Enables/disables AI echo cancellation extension
- **`setAiAudioScenario()`**: Sets audio scenario to `AUDIO_SCENARIO_AI_CLIENT`
- **`setAudioConfigParameters()`**: Configures optimal audio parameters for AI
- **`initializeAiAudioEnhancements()`**: Complete AI stack initialization
- **`reconfigureAiAudioForRoute()`**: Reconfigures AI audio on route changes

#### AgoraBridge.kt (`com.duckbuck.app.bridges`)
- Exposes all AI configuration methods to Flutter via MethodChannel
- Maps Flutter method calls to native AgoraService methods
- Provides error handling and logging for bridge communication

### Flutter (Dart)

#### agora_service.dart
- **`loadAiDenoisePlugin()`**: Flutter wrapper for loading AI denoising plugin
- **`loadAiEchoCancellationPlugin()`**: Flutter wrapper for loading AI echo cancellation plugin
- **`enableAiDenoising({enabled})`**: Flutter wrapper for enabling AI denoising
- **`enableAiEchoCancellation({enabled})`**: Flutter wrapper for enabling AI echo cancellation
- **`setAiAudioScenario()`**: Flutter wrapper for setting AI audio scenario
- **`setAudioConfigParameters()`**: Flutter wrapper for configuring AI audio parameters
- **`initializeAiAudioEnhancements()`**: Flutter wrapper for complete AI initialization
- **`reconfigureAiAudioForRoute()`**: Flutter wrapper for AI audio reconfiguration

## Automatic Initialization

The AI audio enhancements are automatically initialized when the Agora RTC Engine is created:

```kotlin
fun initializeEngine(): Boolean {
    // ... create RTC engine ...
    
    // Initialize AI audio enhancements automatically
    initializeAiAudioEnhancements()
    
    // ... rest of initialization ...
}
```

## Audio Parameter Configuration

The AI audio system configures the following parameters:

```json
{
    "che.audio.specify.codec": "OPUS",
    "che.audio.codec.opus.complexity": 9,
    "che.audio.codec.opus.dtx": true,
    "che.audio.codec.opus.fec": true,
    "che.audio.codec.opus.application": "voip",
    "che.audio.aec.enable": true,
    "che.audio.agc.enable": true,
    "che.audio.ns.enable": true,
    "che.audio.ai.enhance": true,
    "che.audio.ai.denoise.level": "aggressive",
    "che.audio.ai.agc.target_level": -18,
    "che.audio.ai.ns.level": "high"
}
```

## Dynamic Reconfiguration

The system automatically reconfigures AI audio parameters when audio devices change:

```kotlin
override fun onAudioDeviceStateChanged(deviceId: String?, deviceType: Int, deviceState: Int) {
    // ... existing logic ...
    
    // Reconfigure AI audio parameters when audio route changes
    if (deviceState == Constants.MEDIA_DEVICE_STATE_ACTIVE) {
        reconfigureAiAudioForRoute()
    }
}
```

## Usage Examples

### Flutter Usage

```dart
// Initialize AI enhancements (done automatically in initializeEngine)
await AgoraService.instance.initializeAiAudioEnhancements();

// Enable specific AI features
await AgoraService.instance.enableAiDenoising(enabled: true);
await AgoraService.instance.enableAiEchoCancellation(enabled: true);

// Set AI audio scenario
await AgoraService.instance.setAiAudioScenario();

// Reconfigure on audio route change (done automatically)
await AgoraService.instance.reconfigureAiAudioForRoute();
```

### Manual Plugin Loading (if needed)

```dart
// Load plugins manually (optional - done automatically)
await AgoraService.instance.loadAiDenoisePlugin();
await AgoraService.instance.loadAiEchoCancellationPlugin();
```

## Error Handling

The system includes comprehensive error handling:
- Plugin loading failures are logged but don't block initialization
- AI feature enabling continues even if plugins aren't available
- Audio configuration falls back to standard settings if AI config fails
- All methods return boolean success indicators

## Logging

All AI configuration operations are logged with appropriate tags:
- `🤖` prefix for AI-related operations
- Success/failure status for each operation
- Detailed parameter configurations
- Error messages for troubleshooting

## Requirements

### Dynamic Libraries
The following dynamic libraries should be available at runtime:
- `libagora_ai_denoise_extension`
- `libagora_ai_echo_cancellation_extension`

### Agora SDK
- Requires Agora RTC SDK with AI extension support
- `Constants.AUDIO_SCENARIO_AI_CLIENT` must be available
- Extension loading and enabling APIs must be available

## Fallback Behavior

If AI features are not available:
- System falls back to standard audio configuration
- Basic noise suppression and echo cancellation still work
- Audio scenario defaults to `AUDIO_SCENARIO_CHATROOM_GAMING`
- Walkie-talkie functionality remains fully operational

## Testing

To test AI audio configuration:

1. **Plugin Loading**: Check logs for successful plugin loading
2. **Feature Enabling**: Verify AI features are enabled without errors
3. **Audio Quality**: Test voice quality with/without AI enhancements
4. **Route Changes**: Test reconfiguration when switching audio devices
5. **Fallback**: Test behavior when AI features are unavailable
