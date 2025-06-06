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

  /// Join a channel with mic unmuted
  static Future<bool> joinChannel(String channelName, {String? token, int uid = 0}) async {
    try {
      final bool result = await _channel.invokeMethod('joinChannel', {
        'channelName': channelName,
        'token': token,
        'uid': uid,
      });
      
      if (result) {
        // Default to mic on (unmuted) after joining
        await turnMicrophoneOn();
      }
      
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
