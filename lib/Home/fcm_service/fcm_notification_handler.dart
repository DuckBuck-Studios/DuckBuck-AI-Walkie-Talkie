import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../service/agora_service.dart';
import 'package:uuid/uuid.dart';

class FCMNotificationHandler {
  static final AgoraService _agoraService = AgoraService();
  static bool _isInitialized = false;
  static final _uuid = Uuid();
  static bool _isJoiningChannel = false;

  // Store pending call information
  static Map<String, dynamic>? _pendingCall;
  static int? _pendingCallUid;

  /// Check if we have the necessary permissions
  static Future<bool> _checkPermissions() async {
    try {
      // In background mode on Android, avoid permission checks
      if (Platform.isAndroid && WidgetsBinding.instance.lifecycleState == AppLifecycleState.detached) {
        debugPrint('🔄 Skipping permission check in Android background mode');
        return true;
      }

      final micStatus = await Permission.microphone.status;
      debugPrint('🎤 Microphone permission status: $micStatus');
      return micStatus.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      // In background, if we can't check permissions, we'll try to proceed anyway
      return true;
    }
  }

  /// Request permissions (only call this in foreground)
  static Future<bool> _requestPermissions() async {
    try {
      final micStatus = await Permission.microphone.request();
      debugPrint('🎤 Microphone permission status after request: $micStatus');
      return micStatus.isGranted;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Initialize FCM notification handlers
  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🚀 Initializing FCM Notification Handler');

    try {
      await _agoraService.initializeAgora();
      debugPrint('✅ Agora initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Non-fatal error initializing Agora: $e');
      // Continue initialization even if Agora fails
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    debugPrint('✅ Background message handler registered');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    debugPrint('✅ Foreground message handler registered');

    // Handle when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) async {
      if (message != null) {
        debugPrint('📬 Found initial message: ${message.data}');
        await _handleMessage(message, isBackground: false);
        // Try to join any pending call
        await _joinPendingCallIfExists();
      }
    });

    // Handle when app is in background but opened
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      debugPrint('📱 App opened from background state via notification');
      await _handleMessage(message, isBackground: false);
      // Try to join any pending call
      await _joinPendingCallIfExists();
    });

    _isInitialized = true;
    debugPrint('✅ FCM Notification Handler initialized successfully');
  }

  /// Join pending call if exists
  static Future<void> _joinPendingCallIfExists() async {
    if (_pendingCall != null && _pendingCallUid != null) {
      debugPrint('🔄 Attempting to join pending call');
      final channelName = _pendingCall!['channelName'];
      final userUid = _pendingCallUid!;

      // Clear pending call data
      _pendingCall = null;
      _pendingCallUid = null;

      // Attempt to join the channel
      await _attemptChannelJoin(channelName, userUid, false);
    }
  }

  /// Store pending call information
  static void _storePendingCall(Map<String, dynamic> callData, int userUid) {
    _pendingCall = callData;
    _pendingCallUid = userUid;
    debugPrint('📝 Stored pending call information for later');
  }

  /// Generate a random 6-digit UID
  static int _generateUID() {
    final random = Random();
    return 100000 + random.nextInt(900000);
  }

  /// Attempt to join channel with retry logic
  static Future<void> _attemptChannelJoin(String channelName, int userUid, bool isBackground) async {
    if (_isJoiningChannel) {
      debugPrint('⚠️ Already attempting to join channel, skipping duplicate attempt');
      return;
    }

    _isJoiningChannel = true;
    try {
      // Ensure we leave any existing channel first
      try {
        await _agoraService.leaveChannel();
        debugPrint('✅ Successfully left previous channel');
      } catch (e) {
        debugPrint('⚠️ Non-fatal error leaving previous channel: $e');
      }

      // Add a small delay to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Check permissions first
      if (!isBackground && !await _checkPermissions()) {
        if (!await _requestPermissions()) {
          throw Exception('Microphone permission denied');
        }
      }

      // Initialize Agora if needed
      try {
        await _agoraService.initializeAgora();
        debugPrint('✅ Agora initialized for channel join');
      } catch (e) {
        debugPrint('⚠️ Non-fatal error initializing Agora: $e');
      }

      // Configure audio session
      await _agoraService.configureAudioSession();

      // Join the channel
      await _agoraService.joinChannel(channelName, userUid);
      debugPrint('✅ Successfully joined Agora channel');

      // Enable speaker if not in background
      if (!isBackground) {
        try {
          await _agoraService.setSpeakerphoneOn(true);
          debugPrint('🔊 Speaker enabled');
        } catch (e) {
          debugPrint('⚠️ Non-fatal error enabling speaker: $e');
        }
      }
    } catch (e) {
      if (e is PlatformException &&
          e.message?.contains('Unable to detect current Android Activity') == true) {
        debugPrint('⚠️ Cannot join channel in background due to missing Activity context');
        // Store call information for later
        _storePendingCall({'channelName': channelName}, userUid);
      } else {
        debugPrint('❌ Error joining channel: $e');
      }
    } finally {
      _isJoiningChannel = false;
    }
  }

  /// Handle incoming message
  static Future<void> _handleMessage(RemoteMessage message,
      {bool isBackground = false}) async {
    debugPrint('📬 Handling FCM message (isBackground: $isBackground)');
    debugPrint('📝 Message data: ${message.data}');

    if (message.data['type'] == 'call') {
      debugPrint('📞 Call type message detected');
      final channelName = message.data['channelName'];
      final callerName = message.data['callerName'];
      final callerId = message.data['callerId'];

      if (channelName == null) {
        debugPrint('❌ Error: No channel name provided in call notification');
        return;
      }

      debugPrint('📞 Processing call notification:');
      debugPrint('🎯 Channel Name: $channelName');
      debugPrint('👤 Caller Name: $callerName');
      debugPrint('🆔 Caller ID: $callerId');

      // Generate UID for the call
      final userUid = _generateUID();
      debugPrint('👤 Generated UID for call: $userUid');

      // Attempt to join the channel
      await _attemptChannelJoin(channelName, userUid, isBackground);
    } else {
      debugPrint('ℹ️ Not a call message, type: ${message.data['type']}');
    }
  }

  /// Handle background message
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('🌟 Handling background FCM message');
    await _handleMessage(message, isBackground: true);
    debugPrint('✅ Background message handled successfully');
  }

  /// Handle foreground message
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🎯 Handling foreground FCM message');
    await _handleMessage(message, isBackground: false);
    debugPrint('✅ Foreground message handled successfully');
  }

  /// Clean up resources
  static Future<void> dispose() async {
    try {
      await _agoraService.leaveChannel();
      _pendingCall = null;
      _pendingCallUid = null;
    } catch (e) {
      debugPrint('⚠️ Error disposing FCM Notification Handler: $e');
    }
  }
}
