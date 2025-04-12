import 'dart:async'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; 
import 'agora_service.dart';

/// FCMReceiverService handles incoming Firebase Cloud Messaging (FCM) notifications,
/// particularly for room invitations that require auto-joining Agora channels.
class FCMReceiverService {
  static final FCMReceiverService _instance = FCMReceiverService._internal();
  factory FCMReceiverService() => _instance;
  FCMReceiverService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AgoraService _agoraService = AgoraService();
  
  // Stream controllers for broadcasting room invitations
  final StreamController<Map<String, dynamic>> _roomInvitationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Stream of room invitation notifications
  Stream<Map<String, dynamic>> get onRoomInvitation => _roomInvitationController.stream;
  
  /// Initialize the FCM service and set up message handlers
  Future<void> initialize() async {
    try {
      debugPrint("FCMReceiverService: Initializing");
      
      // Request permission for iOS (Android doesn't need this)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      debugPrint('FCMReceiverService: User granted permission: ${settings.authorizationStatus}');
      
      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle when user taps on notification and opens app from background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
      
      // Handle background messages through the handler registered in main.dart
      // FirebaseMessaging.onBackgroundMessage() is registered separately
      
      // Get any messages that caused the app to open from a terminated state
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("FCMReceiverService: App opened from terminated state with message");
        _handleInitialMessage(initialMessage);
      }
      
      debugPrint("FCMReceiverService: Initialized successfully");
    } catch (e) {
      debugPrint("FCMReceiverService: Error initializing - $e");
    }
  }
  
  /// Handle messages when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint("FCMReceiverService: Received foreground message");
    
    if (_isRoomInvitation(message)) {
      debugPrint("FCMReceiverService: Raw message data: ${message.data}");
      
      final data = _extractInvitationData(message.data);
      debugPrint("FCMReceiverService: Room invitation received in foreground: $data");
      
      // Print token details for debugging
      final token = data['agora_token'] as String? ?? '';
      debugPrint("FCMReceiverService: Token value: $token");
      debugPrint("FCMReceiverService: Token length: ${token.length}");
      
      // Check if the invitation is still valid
      if (_isInvitationValid(data['timestamp'])) {
        // Add to stream for UI to handle
        _roomInvitationController.add(data);
        
        // Auto-join the channel
        _autoJoinChannel(data);
      }
    }
  }
  
  /// Handle taps on notifications when app is in background
  Future<void> _handleBackgroundMessageTap(RemoteMessage message) async {
    debugPrint("FCMReceiverService: Notification tapped from background state");
    
    if (_isRoomInvitation(message)) {
      final data = _extractInvitationData(message.data);
      debugPrint("FCMReceiverService: Room invitation tapped from background: $data");
      
      // Check if the invitation is still valid
      if (_isInvitationValid(data['timestamp'])) {
        // Add to stream for UI to handle
        _roomInvitationController.add(data);
        
        // Auto-join the channel
        _autoJoinChannel(data);
      }
    }
  }
  
  /// Handle initial message when app is opened from terminated state
  Future<void> _handleInitialMessage(RemoteMessage message) async {
    if (_isRoomInvitation(message)) {
      final data = _extractInvitationData(message.data);
      debugPrint("FCMReceiverService: Initial message contains room invitation: $data");
      
      // Check if the invitation is still valid
      if (_isInvitationValid(data['timestamp'])) {
        // Add to stream for UI to handle
        _roomInvitationController.add(data);
        
        // Auto-join the channel
        _autoJoinChannel(data);
      }
    }
  }
  
  /// Check if the message is a room invitation
  bool _isRoomInvitation(RemoteMessage message) {
    // Check for direct properties
    if (message.data.containsKey('type') && message.data['type'] == 'roomInvitation') {
      return true;
    }
    
    // Check if metadata exists and contains the room invitation type
    if (message.data.containsKey('metadata')) {
      final metadata = message.data['metadata'];
      // Handle both string and map formats
      if (metadata is String) {
        try {
          // If it's a JSON string, try to parse it
          return metadata.contains('roomInvitation') || metadata.contains('type":"roomInvitation');
        } catch (_) {
          return false;
        }
      } else if (metadata is Map) {
        // If it's already a Map, check for the type field
        return metadata.containsKey('type') && metadata['type'] == 'roomInvitation';
      }
    }
    
    return false;
  }
  
  /// Extract and format the room invitation data from the message
  Map<String, dynamic> _extractInvitationData(Map<String, dynamic> data) {
    Map<String, dynamic> metadata = {};
    
    // Process metadata field if it exists
    if (data.containsKey('metadata')) {
      final rawMetadata = data['metadata'];
      
      // Handle metadata as string (JSON)
      if (rawMetadata is String) {
        try {
          // Try to parse as JSON
          Map<String, dynamic> parsedMetadata = {};
          // Simple parsing approach - look for key-value patterns
          final matches = RegExp(r'"(\w+)"\s*:\s*"([^"]*)"').allMatches(rawMetadata);
          for (final match in matches) {
            if (match.groupCount >= 2) {
              final key = match.group(1);
              final value = match.group(2);
              if (key != null && value != null) {
                parsedMetadata[key] = value;
              }
            }
          }
          metadata = parsedMetadata;
          debugPrint("FCMReceiverService: Extracted metadata from string: $metadata");
        } catch (e) {
          debugPrint("FCMReceiverService: Error parsing metadata string: $e");
        }
      } 
      // Handle metadata as Map
      else if (rawMetadata is Map) {
        metadata = Map<String, dynamic>.from(rawMetadata);
        debugPrint("FCMReceiverService: Using metadata map directly: $metadata");
      }
    }
    
    // Build the standardized invitation data
    final result = {
      'sender_uid': metadata['senderUid'] ?? data['sender_uid'] ?? '',
      'sender_name': metadata['sender'] ?? data['sender_name'] ?? 'Unknown Caller',
      'sender_photo': metadata['senderPhoto'] ?? data['sender_photo'] ?? '',
      'timestamp': data['timestamp'] ?? metadata['timestamp'] ?? '0',
      'agora_token': metadata['agoraToken'] ?? data['agora_token'] ?? '',
      'agora_uid': metadata['agoraUid'] ?? data['agora_uid'] ?? '',
      'agora_channel': metadata['agoraChannel'] ?? data['agora_channel'] ?? '',
    };
    
    debugPrint("FCMReceiverService: Extracted invitation data: $result");
    return result;
  }
  
  /// Check if the invitation is still valid (within 15 seconds)
  bool _isInvitationValid(String timestampStr) {
    final int invitationTimestamp = int.tryParse(timestampStr) ?? 0;
    final int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    final int timeDifference = currentTimestamp - invitationTimestamp;
    
    final bool isValid = timeDifference <= 15000; // 15 seconds in milliseconds
    
    debugPrint("FCMReceiverService: Invitation ${isValid ? 'is valid' : 'expired'}. "
        "Time difference: ${timeDifference/1000} seconds");
    
    return isValid;
  }
  
  /// Auto-join a channel with the provided credentials
  Future<void> _autoJoinChannel(Map<String, dynamic> data) async {
    try {
      // Validate required fields
      final token = data['agora_token'];
      final channelId = data['agora_channel'];
      final uidString = data['agora_uid'];
      
      if (token == null || token.isEmpty) {
        debugPrint("FCMReceiverService: Missing Agora token");
        return;
      }
      
      if (channelId == null || channelId.isEmpty) {
        debugPrint("FCMReceiverService: Missing channel ID");
        return;
      }
      
      if (uidString == null || uidString.isEmpty) {
        debugPrint("FCMReceiverService: Missing UID string");
        return;
      }
      
      // Log values for debugging
      debugPrint("FCMReceiverService: Joining with token: $token");
      debugPrint("FCMReceiverService: Channel ID: $channelId");
      debugPrint("FCMReceiverService: UID string: $uidString");
      
      // Use the UID directly as provided by the server
      // Trust that the backend sends proper integer values
      final int uid = int.parse(uidString);
      debugPrint("FCMReceiverService: Parsed UID: $uid");
      
      // Initialize Agora if needed
      if (!await _agoraService.initialize()) {
        debugPrint("FCMReceiverService: Failed to initialize Agora engine");
        return;
      }
      
      // Join the channel using the values exactly as provided
      final success = await _agoraService.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid, 
        enableAudio: true,   // Audio enabled but will be muted
      );
      
      if (success) {
        // Mute local audio initially
        await _agoraService.muteLocalAudio(true);
        debugPrint("FCMReceiverService: Successfully joined channel $channelId");
      } else {
        debugPrint("FCMReceiverService: Failed to join channel");
        
        // Simple retry with re-initialization if the first attempt fails
        debugPrint("FCMReceiverService: Retrying after re-initialization...");
        await _agoraService.destroy(); // Fully reset the engine
        
        if (!await _agoraService.initialize()) {
          debugPrint("FCMReceiverService: Failed to re-initialize Agora engine");
          return;
        }
        
        final retrySuccess = await _agoraService.joinChannel(
          token: token,
          channelId: channelId,
          uid: uid,
          enableAudio: true,
        );
        
        if (retrySuccess) {
          await _agoraService.muteLocalAudio(true);
          debugPrint("FCMReceiverService: Successfully joined channel on retry");
        } else {
          debugPrint("FCMReceiverService: All join attempts failed");
        }
      }
    } catch (e) {
      debugPrint("FCMReceiverService: Error auto-joining channel - $e");
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _roomInvitationController.close();
  }
}

/// This handler must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handling needs to be minimal and can't interact with UI
  debugPrint("FCMReceiverService: Received background message");
  
  try {
    // Don't do any heavy processing here, just parse and store the notification
    // for processing when the app comes to foreground
    if (message.data.containsKey('type') && 
        message.data['type'] == 'roomInvitation' &&
        message.data.containsKey('timestamp')) {
      
      // Check if invitation is still valid (within 15 seconds)
      final int invitationTimestamp = int.tryParse(message.data['timestamp'].toString()) ?? 0;
      final int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      final int timeDifference = currentTimestamp - invitationTimestamp;
      
      if (timeDifference <= 15000) { // 15 seconds in milliseconds
        debugPrint("FCMReceiverService: Valid room invitation received in background");
        // Store the invitation data to be processed when app opens
        // This would typically be done in a persistent storage for retrieval
      } else {
        debugPrint("FCMReceiverService: Expired room invitation received in background");
      }
    }
  } catch (e) {
    debugPrint("FCMReceiverService: Error in background handler - $e");
  }
} 