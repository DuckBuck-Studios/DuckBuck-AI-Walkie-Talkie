import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'agora_service.dart';
import '../providers/call_provider.dart';
import '../screens/Home/widgets/friend_card.dart';
import 'package:provider/provider.dart';

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
  
  // Static instance for singleton access
  static final FCMReceiverService _instance = FCMReceiverService._internal();
  factory FCMReceiverService() => _instance;
  
  // Context and providers stored for use in background handlers
  static BuildContext? _staticContext;
  static CallProvider? _staticCallProvider;
  BuildContext? _context;
  CallProvider? _callProvider;
  
  // Navigator key for accessing navigator from service
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  FCMReceiverService._internal();
  
  // Initialize the service with context
  Future<void> initialize(BuildContext context) async {
    _context = context;
    _staticContext = context;
    _callProvider = Provider.of<CallProvider>(context, listen: false);
    _staticCallProvider = _callProvider;
    
    print('FCM: Initializing FCM Service');
    
    // Initialize Firebase Messaging
    await Firebase.initializeApp();
    
    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen((message) => _handleForegroundMessage(message));
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification clicks when app is terminated/background
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleMessageOpenedApp(message));
    
    // Request notification permissions
    await _requestNotificationPermissions();
    
    // Get FCM token and print it for testing
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM: Token: $token');
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
    print('FCM: Received foreground message: ${message.messageId}');
    print('FCM: Raw message data: ${message.data}');
    
    // Check message type
    final type = message.data['type'];
    if (type == 'roomInvitation') {
      // Extract call data
      final senderName = message.data['sender_name'] ?? 'Unknown';
      final senderUid = message.data['sender_uid'] ?? '';
      final channelId = message.data['channel_id'] ?? message.data['agora_channel'] ?? '';
      
      print('FCM: Extracted call data - sender_name: $senderName, sender_uid: $senderUid, channel: $channelId');
      
      if (senderUid.isNotEmpty) {
        // Create call data map
        final callData = {
          'token': message.data['agora_token'] ?? '',
          'channelName': channelId,
          'channelId': channelId, // Add both formats to be safe
          'channel_id': channelId, // Add both formats to be safe
          'uid': int.tryParse(message.data['agora_uid'] ?? '0') ?? 0,
          'callerName': senderName,
          'callerPhoto': '',
          'callerUid': senderUid,
          'sender_uid': senderUid, // Add both formats to be safe
          'timestamp': int.tryParse(message.data['timestamp'] ?? '0') ?? DateTime.now().millisecondsSinceEpoch,
        };
        
        print('FCM: Triggering call animation for caller ID: $senderUid');
        
        // Add a short delay to make sure the app is fully initialized
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Use a navigatorKey to access the navigator from anywhere
        // The key should be defined in main.dart and passed here during initialization
        if (navigatorKey.currentContext != null) {
          final buildContext = navigatorKey.currentContext!;
          // Show incoming call UI using the proper context with Navigator access
          FriendCard.handleIncomingCall(buildContext, callData);
        } else {
          print('FCM: Cannot show incoming call - navigator context is not available');
          
          // Fallback to direct call provider usage if we can't show UI
          if (_staticContext != null) {
            final callProvider = Provider.of<CallProvider>(_staticContext!, listen: false);
            callProvider.handleIncomingCall(callData);
          } else {
            print('FCM: Cannot handle call - context is not available');
          }
        }
      }
    }
  }
  
  // Handle when a notification is clicked from background/terminated state
  void _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('FCM: Notification clicked: ${message.messageId}');
    
    if (_isAgoraRoomMessage(message)) {
      // Process the message and update CallProvider state
      final Map<String, dynamic> callData = await _extractAgoraCallData(message);
      if (callData.isNotEmpty) {
        // When opening from notification, trigger call animation
        Future.delayed(Duration.zero, () {
          // Update call provider state
          if (_staticCallProvider != null) {
            _staticCallProvider!.handleIncomingCall(callData);
          }
          
          // Use FriendCard static method to trigger animation
          if (_staticContext != null) {
            FriendCard.handleIncomingCall(_staticContext!, callData);
          }
        });
      }
    }
  }
  
  // Check if message is related to Agora rooms - only roomInvitation type
  bool _isAgoraRoomMessage(RemoteMessage message) {
    final data = message.data;
    return data.containsKey('type') && data['type'] == 'roomInvitation';
  }
  
  // Extract call data from the message
  Future<Map<String, dynamic>> _extractAgoraCallData(RemoteMessage message) async {
    try {
      final data = message.data;
      debugPrint('FCM: Raw message data: $data');
      
      // Extract required Agora credentials based on the exact backend format
      final String? token = data['agora_token'];
      final String? channelName = data['agora_channel'];
      final String? uidString = data['agora_uid'];
      final String? channelId = data['channel_id'];
      
      // Extract caller information based on the exact backend format
      final String? senderUid = data['sender_uid'];
      final String? senderName = data['sender_name'];
      final String? timestamp = data['timestamp'];
      
      if (token == null || channelName == null || uidString == null) {
        debugPrint('FCM: Missing Agora credentials in message');
        return {};
      }
      
      // Parse user ID
      final int uid = int.tryParse(uidString) ?? 0;
      
      // Log the extracted data to help debug
      debugPrint('FCM: Extracted call data - sender_name: $senderName, sender_uid: $senderUid, channel: $channelName');
      
      return {
        'token': token,
        'channelName': channelName,
        'uid': uid,
        'callerName': senderName ?? 'Unknown Caller',
        'callerPhoto': '',  // Backend doesn't provide photo
        'callerUid': senderUid ?? channelId ?? '',  // Use sender_uid primarily, fallback to channel_id
        'timestamp': int.tryParse(timestamp ?? '') ?? DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('FCM: Error extracting call data: $e');
      return {};
    }
  }
  
  // Process Agora channel joining from the message
  static Future<void> _processAgoraChannelJoining(RemoteMessage message) async {
    try {
      final data = message.data;
      debugPrint('FCM: Processing Agora channel joining from message data: $data');
      
      // Only process roomInvitation type
      if (data['type'] != 'roomInvitation') {
        debugPrint('FCM: Ignoring non-roomInvitation message');
        return;
      }
      
      // Extract call data
      final Map<String, dynamic> callData = await _instance._extractAgoraCallData(message);
      
      // If we have a stored call provider and context, update its state
      if (_staticCallProvider != null && _staticContext != null && callData.isNotEmpty) {
        // Trigger card-to-fullscreen animation via FriendCard
        if (_staticContext!.mounted) {
          FriendCard.handleIncomingCall(_staticContext!, callData);
        }
        return;
      }
      
      // Legacy fallback - direct channel joining without UI
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
      
      // Join the channel (muted by default)
      debugPrint('FCM: Joining Agora channel: $channelName with UID: $uid');
      final success = await agoraService.joinChannel(
        token: token,
        channelName: channelName,
        userId: uid,
        muteOnJoin: true,
      );
      
      if (success) {
        debugPrint('FCM: Successfully joined Agora channel');
      } else {
        debugPrint('FCM: Failed to join Agora channel');
      }
    } catch (e) {
      debugPrint('FCM: Error processing Agora channel joining: $e');
    }
  }
}