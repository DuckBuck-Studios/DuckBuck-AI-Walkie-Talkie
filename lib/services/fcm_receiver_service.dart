import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'agora_service.dart';

// Initialize the FCM background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  await Firebase.initializeApp();
  
  debugPrint("FCM: Handling background message: ${message.messageId}");
  
  // Process Agora channel joining
  await FCMReceiverService._processAgoraChannelJoining(message);
}

class FCMReceiverService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AgoraService _agoraService = AgoraService();
  
  // Private constructor
  FCMReceiverService._();
  
  // Singleton instance
  static final FCMReceiverService _instance = FCMReceiverService._();
  
  // Factory constructor to return the singleton instance
  factory FCMReceiverService() => _instance;
  
  // Initialize the FCM service
  Future<void> initialize() async {
    debugPrint("FCM: Initializing FCM receiver service");
    
    // Initialize Agora engine
    await _agoraService.initializeEngine();
    
    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification clicks when app is terminated/background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Request notification permissions
    await _requestNotificationPermissions();
    
    debugPrint("FCM: Receiver service initialized successfully");
  }
  
  // Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('FCM: User granted permission: ${settings.authorizationStatus}');
  }
  
  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('FCM: Received foreground message: ${message.messageId}');
    
    // Extract message data
    if (_isAgoraRoomMessage(message)) {
      await _processAgoraChannelJoining(message);
    }
  }
  
  // Handle when a notification is clicked from background/terminated state
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM: Notification clicked: ${message.messageId}');
    // We don't need to do anything special here since we're auto-joining
  }
  
  // Check if message is related to Agora rooms
  bool _isAgoraRoomMessage(RemoteMessage message) {
    final data = message.data;
    return data.containsKey('type') && 
           (data['type'] == 'roomInvitation' || data['type'] == 'roomAcknowledgement');
  }
  
  // Process Agora channel joining from the message
  static Future<void> _processAgoraChannelJoining(RemoteMessage message) async {
    try {
      final data = message.data;
      debugPrint('FCM: Processing Agora channel joining from message data: $data');
      
      // Extract required Agora credentials
      final String? token = data['agora_token'];
      final String? channelName = data['agora_channel'];
      final String? uidString = data['agora_uid'];
      
      if (token == null || channelName == null || uidString == null) {
        debugPrint('FCM: Missing Agora credentials in message');
        return;
      }
      
      // Parse user ID
      final int uid = int.tryParse(uidString) ?? 0;
      
      // Initialize Agora service
      final agoraService = AgoraService();
      await agoraService.initializeEngine();
      
      // Join the channel (muted)
      debugPrint('FCM: Joining Agora channel: $channelName with UID: $uid');
      final success = await agoraService.joinChannel(
        token: token,
        channelName: channelName,
        userId: uid,
        muteOnJoin: true,
      );
      
      if (success) {
        debugPrint('FCM: Successfully joined Agora channel');
        // Ensure audio is muted
        await agoraService.muteLocalAudio(true);
      } else {
        debugPrint('FCM: Failed to join Agora channel');
      }
    } catch (e) {
      debugPrint('FCM: Error processing Agora channel joining: $e');
    }
  }
}