import 'package:flutter/services.dart';
import 'dart:async';

class AgoraService {
  static const String _appId = '3983e52a08424b7da5e79be4c9dfae0f';
  static const MethodChannel _channel = MethodChannel('com.example.duckbuck/agora');

  // Event streams
  final StreamController<Map<String, dynamic>> _userJoinedController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _userLeftController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _joinChannelSuccessController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _connectionStateChangedController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _leaveChannelController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _errorController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _tokenExpiredController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get onUserJoined => _userJoinedController.stream;
  Stream<Map<String, dynamic>> get onUserLeft => _userLeftController.stream;
  Stream<Map<String, dynamic>> get onJoinChannelSuccess => _joinChannelSuccessController.stream;
  Stream<Map<String, dynamic>> get onConnectionStateChanged => _connectionStateChangedController.stream;
  Stream<Map<String, dynamic>> get onLeaveChannel => _leaveChannelController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  Stream<Map<String, dynamic>> get onTokenExpired => _tokenExpiredController.stream;

  // Singleton pattern
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;

  AgoraService._internal() {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      final Map<String, dynamic> args = call.arguments ?? {};
      
      switch (call.method) {
        case 'userJoined':
          _userJoinedController.add(args);
          break;
        case 'userLeft':
          _userLeftController.add(args);
          break;
        case 'joinChannelSuccess':
          _joinChannelSuccessController.add(args);
          break;
        case 'connectionStateChanged':
          _connectionStateChangedController.add(args);
          break;
        case 'leaveChannel':
          _leaveChannelController.add(args);
          break;
        case 'error':
          _errorController.add(args);
          break;
        case 'tokenExpired':
          _tokenExpiredController.add(args);
          break;
      }
      
      return null;
    });
  }

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
    bool muteOnJoin = true,
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

  // Dispose all resources
  void dispose() {
    _userJoinedController.close();
    _userLeftController.close();
    _joinChannelSuccessController.close();
    _connectionStateChangedController.close();
    _leaveChannelController.close();
    _errorController.close();
    _tokenExpiredController.close();
  }
}