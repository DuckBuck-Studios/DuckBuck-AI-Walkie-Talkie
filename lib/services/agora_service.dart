import 'package:flutter/services.dart';

class AgoraService {
  static const String _appId = '3983e52a08424b7da5e79be4c9dfae0f';
  static const MethodChannel _channel = MethodChannel('com.example.duckbuck/agora');

  // Initialize the Agora engine
  Future<bool> initializeEngine() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'initializeEngine',
        {'appId': _appId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error initializing Agora engine: ${e.message}');
      return false;
    }
  }

  // Join a channel
  Future<bool> joinChannel({
    required String token,
    required String channelName,
    int userId = 0,
    bool muteOnJoin = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'joinChannel',
        {
          'token': token,
          'channelName': channelName,
          'userId': userId,
          'muteOnJoin': muteOnJoin,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error joining channel: ${e.message}');
      return false;
    }
  }

  // Leave the channel
  Future<bool> leaveChannel() async {
    try {
      final result = await _channel.invokeMethod<bool>('leaveChannel');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error leaving channel: ${e.message}');
      return false;
    }
  }

  // Cleanup resources
  Future<bool> cleanup() async {
    try {
      final result = await _channel.invokeMethod<bool>('cleanup');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error cleaning up: ${e.message}');
      return false;
    }
  }

  // Mute local audio
  Future<bool> muteLocalAudio(bool mute) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'muteLocalAudio',
        {'mute': mute},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error muting audio: ${e.message}');
      return false;
    }
  }

  // Toggle local video
  Future<bool> enableLocalVideo(bool enable) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'enableLocalVideo',
        {'enable': enable},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error toggling video: ${e.message}');
      return false;
    }
  }
}