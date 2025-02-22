import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../service/agora_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class FCMNotificationHandler {
  static const platform = MethodChannel('com.example.duckbuck/call');
  static final AgoraService _agoraService = AgoraService();
  static bool _isInitialized = false;

  /// Initialize FCM notification handlers
  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('Initializing FCM Notification Handler');
    await _agoraService.initializeAgora();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessage(message);
      }
    });

    // Handle when app is in background but opened
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message);
    });

    platform.setMethodCallHandler((call) async {
      if (call.method == 'incomingCall') {
        final channelName = call.arguments['channelName'];
        final callerName = call.arguments['callerName'];

        // Join the call directly since we're in the main activity
        await _agoraService.initializeAgora();
        final userUid = _generateUID();
        await _agoraService.joinChannel(channelName, userUid);
      }
    });

    _isInitialized = true;
    debugPrint('FCM Notification Handler initialized');
  }

  /// Generate a random 6-digit UID
  static int _generateUID() {
    final random = Random();
    return 100000 +
        random.nextInt(900000); // Generates number between 100000 and 999999
  }

  /// Handle incoming message
  static Future<void> _handleMessage(RemoteMessage message) async {
    debugPrint('Handling FCM message: ${message.data}');

    if (message.data['type'] == 'call') {
      final channelName = message.data['channelName'];
      final callerName = message.data['callerName'];
      final callerId = message.data['callerId'];

      if (channelName == null) {
        debugPrint('Error: No channel name provided in call notification');
        return;
      }

      debugPrint('Received call notification:');
      debugPrint('Channel Name: $channelName');
      debugPrint('Caller Name: $callerName');
      debugPrint('Caller ID: $callerId');

      try {
        // Initialize Agora first
        await _agoraService.initializeAgora();

        // Request permissions before joining
        final status = await Permission.microphone.request();
        if (status.isGranted) {
          final userUid = _generateUID();
          await _agoraService.joinChannel(channelName, userUid);
          debugPrint(
              'Successfully joined channel: $channelName with UID: $userUid');
        } else {
          debugPrint('Microphone permission denied');
        }
      } catch (e) {
        debugPrint('Error joining channel: $e');
      }
    }
  }

  /// Handle background message
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Handling background FCM message: ${message.data}');
    await _handleMessage(message);
  }

  /// Handle foreground message
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Handling foreground FCM message: ${message.data}');
    await _handleMessage(message);
  }

  /// Clean up resources
  static Future<void> dispose() async {
    try {
      await _agoraService.leaveChannel();
    } catch (e) {
      debugPrint('Error disposing FCM Notification Handler: $e');
    }
  }
}
