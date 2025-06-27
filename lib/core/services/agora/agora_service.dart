import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// AgoraService - Flutter service for communicating with native Agora functionality
/// Provides a clean Dart interface to all native AgoraService methods
class AgoraService {
  static const MethodChannel _channel = MethodChannel('com.duckbuck.app/agora');
  
  static AgoraService? _instance;
  
  /// Singleton instance
  static AgoraService get instance {
    _instance ??= AgoraService._();
    return _instance!;
  }
  
  AgoraService._();

  // ================================
  // ENGINE LIFECYCLE METHODS
  // ================================

  /// Initialize the Agora RTC Engine
  Future<bool> initializeEngine() async {
    try {
      final result = await _channel.invokeMethod<bool>('initializeEngine');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error initializing engine: $e');
      return false;
    }
  }

  /// Destroy the Agora RTC Engine and cleanup resources
  Future<bool> destroyEngine() async {
    try {
      final result = await _channel.invokeMethod<bool>('destroyEngine');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error destroying engine: $e');
      return false;
    }
  }

  // ================================
  // CHANNEL MANAGEMENT METHODS
  // ================================

  /// Join a channel with the specified parameters
  Future<bool> joinChannel({
    String? token,
    required String channelName,
    int uid = 0,
    bool joinMuted = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('joinChannel', {
        'token': token,
        'channelName': channelName,
        'uid': uid,
        'joinMuted': joinMuted,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error joining channel: $e');
      return false;
    }
  }

  /// Leave the current channel
  Future<bool> leaveChannel() async {
    try {
      final result = await _channel.invokeMethod<bool>('leaveChannel');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error leaving channel: $e');
      return false;
    }
  }

  /// Check if currently connected to a channel
  Future<bool> isChannelConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isChannelConnected');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error checking channel connection: $e');
      return false;
    }
  }

  /// Get the current channel name
  Future<String?> getCurrentChannelName() async {
    try {
      final result = await _channel.invokeMethod<String>('getCurrentChannelName');
      return result;
    } catch (e) {
      debugPrint('❌ Error getting current channel name: $e');
      return null;
    }
  }

  /// Get the current user ID
  Future<int> getCurrentUid() async {
    try {
      final result = await _channel.invokeMethod<int>('getCurrentUid');
      return result ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting current UID: $e');
      return 0;
    }
  }

  // ================================
  // AUDIO CONTROL METHODS
  // ================================

  /// Mute or unmute the local microphone
  Future<bool> muteLocalAudio(bool muted) async {
    try {
      final result = await _channel.invokeMethod<bool>('muteLocalAudio', {
        'muted': muted,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error muting local audio: $e');
      return false;
    }
  }

  /// Mute or unmute a remote user's audio
  Future<bool> muteRemoteAudio(int uid, bool muted) async {
    try {
      final result = await _channel.invokeMethod<bool>('muteRemoteAudio', {
        'uid': uid,
        'muted': muted,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error muting remote audio: $e');
      return false;
    }
  }

  /// Mute or unmute all remote users' audio
  Future<bool> muteAllRemoteAudio(bool muted) async {
    try {
      final result = await _channel.invokeMethod<bool>('muteAllRemoteAudio', {
        'muted': muted,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error muting all remote audio: $e');
      return false;
    }
  }

  /// Enable or disable the local audio (microphone)
  Future<bool> enableLocalAudio(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('enableLocalAudio', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error enabling local audio: $e');
      return false;
    }
  }

  // ================================
  // AUDIO ROUTING METHODS
  // ================================

  /// Enable or disable speakerphone
  Future<bool> setSpeakerphoneEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setSpeakerphoneEnabled', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error setting speakerphone: $e');
      return false;
    }
  }

  /// Check if speakerphone is currently enabled
  Future<bool> isSpeakerphoneEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSpeakerphoneEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error checking speakerphone: $e');
      return false;
    }
  }

  /// Set the default audio output route to speakerphone or earpiece
  Future<bool> setDefaultAudioRoute(bool useSpeakerphone) async {
    try {
      final result = await _channel.invokeMethod<bool>('setDefaultAudioRoute', {
        'useSpeakerphone': useSpeakerphone,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error setting default audio route: $e');
      return false;
    }
  }

  // ================================
  // VOLUME CONTROL METHODS
  // ================================

  /// Adjust the recording signal volume (microphone gain)
  Future<bool> adjustRecordingVolume(int volume) async {
    try {
      final result = await _channel.invokeMethod<bool>('adjustRecordingVolume', {
        'volume': volume,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error adjusting recording volume: $e');
      return false;
    }
  }

  /// Adjust the playback signal volume (speaker volume)
  Future<bool> adjustPlaybackVolume(int volume) async {
    try {
      final result = await _channel.invokeMethod<bool>('adjustPlaybackVolume', {
        'volume': volume,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error adjusting playback volume: $e');
      return false;
    }
  }

  /// Adjust the playback volume for a specific remote user
  Future<bool> adjustUserPlaybackVolume(int uid, int volume) async {
    try {
      final result = await _channel.invokeMethod<bool>('adjustUserPlaybackVolume', {
        'uid': uid,
        'volume': volume,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error adjusting user playback volume: $e');
      return false;
    }
  }

  // ================================
  // AUDIO CONFIGURATION METHODS
  // ================================

  /// Set audio scenario for optimal walkie-talkie experience
  Future<bool> setAudioScenario(int scenario) async {
    try {
      final result = await _channel.invokeMethod<bool>('setAudioScenario', {
        'scenario': scenario,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error setting audio scenario: $e');
      return false;
    }
  }

  // ================================
  // AI AUDIO ENHANCEMENT METHODS
  // ================================

  /// Load Agora AI denoising plugin (dynamic library)
  Future<bool> loadAiDenoisePlugin() async {
    try {
      final result = await _channel.invokeMethod<bool>('loadAiDenoisePlugin');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error loading AI denoise plugin: $e');
      return false;
    }
  }

  /// Load Agora AI echo cancellation plugin (dynamic library)
  Future<bool> loadAiEchoCancellationPlugin() async {
    try {
      final result = await _channel.invokeMethod<bool>('loadAiEchoCancellationPlugin');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error loading AI echo cancellation plugin: $e');
      return false;
    }
  }

  /// Enable or disable AI denoising extension
  Future<bool> enableAiDenoising({bool enabled = true}) async {
    try {
      final result = await _channel.invokeMethod<bool>('enableAiDenoising', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error enabling AI denoising: $e');
      return false;
    }
  }

  /// Enable or disable AI echo cancellation extension
  Future<bool> enableAiEchoCancellation({bool enabled = true}) async {
    try {
      final result = await _channel.invokeMethod<bool>('enableAiEchoCancellation', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error enabling AI echo cancellation: $e');
      return false;
    }
  }

  /// Set audio scenario to AI client for optimal AI conversational experience
  Future<bool> setAiAudioScenario() async {
    try {
      final result = await _channel.invokeMethod<bool>('setAiAudioScenario');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error setting AI audio scenario: $e');
      return false;
    }
  }

  /// Configure recommended audio parameters for AI conversational experience
  Future<bool> setAudioConfigParameters() async {
    try {
      final result = await _channel.invokeMethod<bool>('setAudioConfigParameters');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error setting audio config parameters: $e');
      return false;
    }
  }

  /// Initialize complete AI audio enhancement stack
  Future<bool> initializeAiAudioEnhancements() async {
    try {
      final result = await _channel.invokeMethod<bool>('initializeAiAudioEnhancements');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error initializing AI audio enhancements: $e');
      return false;
    }
  }

  /// Reconfigure AI audio parameters (call on audio route changes)
  Future<bool> reconfigureAiAudioForRoute() async {
    try {
      final result = await _channel.invokeMethod<bool>('reconfigureAiAudioForRoute');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error reconfiguring AI audio for route: $e');
      return false;
    }
  }

  // ================================
  // WALKIE-TALKIE UTILITY METHODS
  // ================================

  /// Get active call data from SharedPreferences
  Future<Map<String, dynamic>> getActiveCallData() async {
    try {
      final result = await _channel.invokeMethod<Map>('getActiveCallData');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('❌ Error getting active call data: $e');
      return {};
    }
  }

  /// Clear active call data from SharedPreferences
  Future<bool> clearActiveCallData() async {
    try {
      final result = await _channel.invokeMethod<bool>('clearActiveCallData');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error clearing active call data: $e');
      return false;
    }
  }

  // ================================
  // CONVENIENCE METHODS
  // ================================

  /// Check if there's an ongoing call (convenience method)
  Future<bool> hasActiveCall() async {
    final callData = await getActiveCallData();
    return callData['is_call_active'] == true;
  }

  /// Get active call channel ID (convenience method)
  Future<String?> getActiveCallChannelId() async {
    final callData = await getActiveCallData();
    final channelId = callData['channel_id'] as String?;
    return (channelId?.isNotEmpty == true) ? channelId : null;
  }

  /// Get active call caller name (convenience method)
  Future<String?> getActiveCallCallerName() async {
    final callData = await getActiveCallData();
    final callerName = callData['caller_name'] as String?;
    return (callerName?.isNotEmpty == true) ? callerName : null;
  }

  /// Get active call caller photo (convenience method)
  Future<String?> getActiveCallCallerPhoto() async {
    final callData = await getActiveCallData();
    final callerPhoto = callData['caller_photo'] as String?;
    return (callerPhoto?.isNotEmpty == true) ? callerPhoto : null;
  }
}
