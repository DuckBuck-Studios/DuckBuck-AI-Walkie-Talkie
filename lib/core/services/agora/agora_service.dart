import 'package:flutter/services.dart';

import '../logger/logger_service.dart';
import '../service_locator.dart';

class AgoraService {
  static const MethodChannel _channel = MethodChannel('com.duckbuck.app/agora_channel');
  
  // Get logger service from service locator
  static final LoggerService _logger = serviceLocator<LoggerService>();
  
  // Event listener for call state changes
  static Function()? _onCallEnded;
  static Function()? _onUserJoined;
  
  /// Set callback for when call ends (for providers to listen)
  static void setCallEndedCallback(Function()? callback) {
    _onCallEnded = callback;
  }

  /// Set callback for when a remote user joins
  static void setUserJoinedCallback(Function()? callback) {
    _onUserJoined = callback;
  }

  /// Initialize Agora Engine
  static Future<bool> initializeEngine() async {
    try {
      final bool result = await _channel.invokeMethod('initializeAgoraEngine');
      return result;
    } catch (e) {
      return false;
    }
  }
 

  /// Leave current channel
  static Future<bool> leaveChannel() async {
    try {
      final bool result = await _channel.invokeMethod('leaveChannel');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Turn microphone on
  static Future<bool> turnMicrophoneOn() async {
    try {
      final bool result = await _channel.invokeMethod('turnMicrophoneOn');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Turn microphone off
  static Future<bool> turnMicrophoneOff() async {
    try {
      final bool result = await _channel.invokeMethod('turnMicrophoneOff');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Turn speaker on
  static Future<bool> turnSpeakerOn() async {
    try {
      print('AgoraService: Calling turnSpeakerOn');
      final bool result = await _channel.invokeMethod('turnSpeakerOn');
      print('AgoraService: turnSpeakerOn result: $result');
      return result;
    } catch (e) {
      print('AgoraService: Error in turnSpeakerOn: $e');
      return false;
    }
  }

  /// Turn speaker off
  static Future<bool> turnSpeakerOff() async {
    try {
      print('AgoraService: Calling turnSpeakerOff');
      final bool result = await _channel.invokeMethod('turnSpeakerOff');
      print('AgoraService: turnSpeakerOff result: $result');
      return result;
    } catch (e) {
      print('AgoraService: Error in turnSpeakerOff: $e');
      return false;
    }
  }

  /// Toggle microphone (mute/unmute)
  static Future<bool> toggleMicrophone() async {
    try {
      final bool currentlyMuted = await isMicrophoneMuted();
      if (currentlyMuted) {
        return await turnMicrophoneOn();
      } else {
        return await turnMicrophoneOff();
      }
    } catch (e) {
      return false;
    }
  }

  /// Toggle speaker (on/off)
  static Future<bool> toggleSpeaker() async {
    try {
      final bool currentlyEnabled = await isSpeakerEnabled();
      print('AgoraService: Current speaker state: $currentlyEnabled');
      
      bool result;
      if (currentlyEnabled) {
        print('AgoraService: Turning speaker OFF (to earpiece)');
        result = await turnSpeakerOff();
      } else {
        print('AgoraService: Turning speaker ON (to speaker)');
        result = await turnSpeakerOn();
      }
      
      print('AgoraService: Toggle result: $result');
      
      // Verify the new state after toggle
      final newState = await isSpeakerEnabled();
      print('AgoraService: New speaker state after toggle: $newState');
      
      return result;
    } catch (e) {
      print('AgoraService: Error in toggleSpeaker: $e');
      return false;
    }
  }

  /// Check if Agora engine is active
  static Future<bool> isEngineActive() async {
    try {
      final bool result = await _channel.invokeMethod('isEngineActive');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Get number of remote users in channel
  static Future<int> getRemoteUserCount() async {
    try {
      final int result = await _channel.invokeMethod('getRemoteUserCount');
      return result;
    } catch (e) {
      return 0;
    }
  }

  /// Check if microphone is currently muted
  static Future<bool> isMicrophoneMuted() async {
    try {
      final bool result = await _channel.invokeMethod('isMicrophoneMuted');
      return result;
    } catch (e) {
      return true; // Default to muted on error
    }
  }

  /// Check if speaker is currently enabled
  static Future<bool> isSpeakerEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isSpeakerEnabled');
      print('AgoraService: isSpeakerEnabled result: $result');
      return result;
    } catch (e) {
      print('AgoraService: Error in isSpeakerEnabled: $e');
      return false; // Default to disabled on error
    }
  }

  /// Check if currently in a channel
  static Future<bool> isInChannel() async {
    try {
      final bool result = await _channel.invokeMethod('isInChannel');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Get current channel name
  static Future<String?> getCurrentChannelName() async {
    try {
      final String? result = await _channel.invokeMethod('getCurrentChannelName');
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Get my UID in the current channel
  static Future<int> getMyUid() async {
    try {
      final int result = await _channel.invokeMethod('getMyUid');
      return result;
    } catch (e) {
      return 0;
    }
  }

  /// Check if channel has other users besides me
  static Future<bool> hasOtherUsers() async {
    try {
      final int userCount = await getRemoteUserCount();
      return userCount > 0;
    } catch (e) {
      return false;
    }
  }

  /// Destroy Agora engine (cleanup)
  static Future<bool> destroyEngine() async {
    try {
      final bool result = await _channel.invokeMethod('destroyEngine');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Force leave channel (for emergency cleanup)
  static Future<bool> forceLeaveChannel() async {
    try {
      final bool result = await _channel.invokeMethod('forceLeaveChannel');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Get Agora connection state
  static Future<int> getConnectionState() async {
    try {
      final int result = await _channel.invokeMethod('getConnectionState');
      return result;
    } catch (e) {
      return -1; // Unknown state
    }
  }

  /// Join channel with basic parameters (without waiting)
  static Future<bool> joinChannel({
    required String channelName,
    String? token,
    int uid = 0,
    bool isAiAgent = false,
  }) async {
    try {
      final methodChannelParams = {
        'channelName': channelName,
        'token': token,
        'uid': uid,
        'isAiAgent': isAiAgent,
      };
      
      final bool result = await _channel.invokeMethod('joinChannel', methodChannelParams);
      return result;
    } catch (e) {
      _logger.e('AgoraService', 'Exception in joinChannel: $e');
      return false;
    }
  }

  /// Set up method channel to listen for events from Android
  static void _setupMethodChannelHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCallEnded':
          _onCallEnded?.call();
          break;
        case 'onUserLeft':
          _onCallEnded?.call();
          break;
        case 'onChannelEmpty':
          _onCallEnded?.call();
          break;
        case 'onUserJoined':
          _onUserJoined?.call();
          break;
      }
    });
  }

  /// Initialize the method channel handler (call this once during app startup)
  static void initialize() {
    _setupMethodChannelHandler();
  }
}
