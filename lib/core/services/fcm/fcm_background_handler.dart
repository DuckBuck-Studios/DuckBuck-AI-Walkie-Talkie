import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../logger/logger_service.dart';
import 'fcm_message_handler.dart';

/// Background message handler for Firebase Cloud Messaging
/// 
/// This function handles FCM messages when the app is in background or killed state.
/// It must be a top-level function and cannot be inside a class.
/// 
/// For background/killed state messages:
/// - Shows local notifications with custom styling based on notification type
/// - Handles notification taps to navigate to friends screen
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  try {
    final logger = LoggerService();
    logger.i('FCM_BACKGROUND', 'Received background message: ${message.messageId}');
    
    // Log message details
    if (message.notification != null) {
      logger.d('FCM_BACKGROUND', 'Title: ${message.notification!.title}');
      logger.d('FCM_BACKGROUND', 'Body: ${message.notification!.body}');
    }
    
    if (message.data.isNotEmpty) {
      logger.d('FCM_BACKGROUND', 'Data payload: ${message.data}');
      
      // Log critical fields for debugging
      final notificationType = message.data['type'];
      if (notificationType == 'friend_request') {
        final senderId = message.data['sender_id'];
        final senderName = message.data['sender_name'];
        final senderPhotoUrl = message.data['sender_photo_url'];
        
        logger.d('FCM_BACKGROUND', 'Friend request - from: $senderName ($senderId), photo URL: $senderPhotoUrl');
      } else if (notificationType == 'friend_request_accepted') {
        final accepterId = message.data['accepter_id'];
        final accepterName = message.data['accepter_name'];
        final accepterPhotoUrl = message.data['accepter_photo_url'];
        
        logger.d('FCM_BACKGROUND', 'Friend request accepted - by: $accepterName ($accepterId), photo URL: $accepterPhotoUrl');
      }
    }
    
    // Initialize FCM handler for showing local notification
    final fcmHandler = FCMMessageHandler();
    await fcmHandler.initialize();
    
    // Show local notification for background messages with proper styling
    await fcmHandler.showLocalNotification(message);
    
    logger.i('FCM_BACKGROUND', 'Background message handled successfully');
  } catch (e) {
    if (kDebugMode) {
      print('Error in background message handler: $e');
    }
  }
}
