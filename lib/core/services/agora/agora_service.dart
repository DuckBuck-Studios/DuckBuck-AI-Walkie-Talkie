import 'package:flutter/services.dart';

class AgoraService {
  static const MethodChannel _channel = MethodChannel('com.duckbuck.app/agora_channel');

  /// Initialize Agora Engine
  static Future<bool> initializeEngine() async {
    try {
      final bool result = await _channel.invokeMethod('initializeAgoraEngine');
      return result;
    } catch (e) {
      return false;
    }
  }
 

  /// Join a channel and wait for other users to join within the specified timeout
  /// Returns true if users joined within timeout, false otherwise
  static Future<bool> joinChannelAndWaitForUsers(
    String channelName, {
    String? token,
    int uid = 0,
    int timeoutSeconds = 15,
  }) async {
    try {
      // Log the exact parameters being sent through method channel
      print('🔧 AgoraService: Invoking joinChannelAndWaitForUsers method channel with:');
      print('   - channelName: $channelName');
      print('   - token: $token');
      print('   - uid: $uid');
      print('   - timeoutSeconds: $timeoutSeconds');
      
      final methodChannelParams = {
        'channelName': channelName,
        'token': token,
        'uid': uid,
        'timeoutSeconds': timeoutSeconds,
      };
      
      print('   - Full method channel params: $methodChannelParams');
      
      final bool result = await _channel.invokeMethod('joinChannelAndWaitForUsers', methodChannelParams);
      
      print('🔧 AgoraService: Method channel returned result: $result');
      
      if (result) {
        // Default to mic on (unmuted) after joining
        await turnMicrophoneOn();
      }
      
      return result;
    } catch (e) {
      print('❌ AgoraService: Exception in joinChannelAndWaitForUsers: $e');
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
      final bool result = await _channel.invokeMethod('turnSpeakerOn');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Turn speaker off
  static Future<bool> turnSpeakerOff() async {
    try {
      final bool result = await _channel.invokeMethod('turnSpeakerOff');
      return result;
    } catch (e) {
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
}
