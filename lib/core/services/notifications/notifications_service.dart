import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_database_service.dart';

/// Service for handling push notifications and FCM tokens
///
/// This service encapsulates all notification-related functionality:
/// - FCM token registration and storage
/// - Notification permission handling
/// - Notification configuration
class NotificationsService {
  final FirebaseMessaging _firebaseMessaging;
  final FirebaseDatabaseService _databaseService;

  /// Creates a new NotificationsService
  NotificationsService({
    FirebaseMessaging? firebaseMessaging,
    required FirebaseDatabaseService databaseService,
  }) : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
       _databaseService = databaseService;

  /// Initialize FCM token generation
  Future<void> initialize() async {
    try {
      debugPrint('🔔 NOTIFICATION SERVICE: Initializing token generation only...');
      
      // Request minimal permissions needed for token generation
      final settings = await _firebaseMessaging.requestPermission(
        alert: false,
        badge: false,
        sound: false,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint(
        '🔔 NOTIFICATION SERVICE: Permission status: ${settings.authorizationStatus}',
      );
      
      // Test if we can get a token (don't save it yet, just check availability)
      try {
        final testToken = await _firebaseMessaging.getToken();
        if (testToken != null) {
          debugPrint('✅ NOTIFICATION SERVICE: FCM token is available');
        } else {
          debugPrint('⚠️ NOTIFICATION SERVICE WARNING: FCM token is null during initialization');
        }
      } catch (tokenError) {
        debugPrint('⚠️ NOTIFICATION SERVICE WARNING: Failed to get test FCM token: $tokenError');
      }
      
      debugPrint('✅ NOTIFICATION SERVICE: Initialization complete');
    } catch (e) {
      debugPrint('❌ NOTIFICATION SERVICE ERROR: Failed to initialize notifications: $e');
      debugPrint('❌ NOTIFICATION SERVICE ERROR: Stack trace: ${StackTrace.current}');
    }
  }

  /// Register FCM token for the current user - token generation only
  ///
  /// This should be called after successful user authentication
  Future<void> registerToken(String userId) async {
    try {
      debugPrint('🔔 NOTIFICATION SERVICE: Generating FCM token for user: $userId');
      
      // Force token refresh to ensure we get the latest
      await _firebaseMessaging.deleteToken();
      final token = await _firebaseMessaging.getToken();
      
      if (token == null) {
        debugPrint('⚠️ NOTIFICATION SERVICE: Failed to generate FCM token - token is null');
        return;
      }
      
      // Only log a substring of the token for security
      String tokenPreview = token.length > 15 ? '${token.substring(0, 15)}...' : token;
      debugPrint('🔔 NOTIFICATION SERVICE: FCM token generated: $tokenPreview');
      
      // Store the token in the user's document with minimal data
      final Map<String, dynamic> tokenData = {
        'fcmTokens': {
          token: {
            'createdAt': DateTime.now().toIso8601String(),
            'platform': _getPlatformName(),
          },
        },
      };
      
      debugPrint('🔔 NOTIFICATION SERVICE: Saving token to Firestore...');
      
      // Retry mechanism for saving token
      bool saved = false;
      int attempts = 0;
      const maxAttempts = 3;
      
      while (!saved && attempts < maxAttempts) {
        attempts++;
        try {
          await _databaseService.setDocument(
            collection: 'users',
            documentId: userId,
            data: tokenData,
            merge: true,
          );
          saved = true;
          debugPrint('✅ NOTIFICATION SERVICE: FCM token saved for user: $userId (attempt $attempts)');
        } catch (e) {
          if (attempts < maxAttempts) {
            debugPrint('⚠️ NOTIFICATION SERVICE: Retrying token save after error (attempt $attempts): $e');
            await Future.delayed(Duration(seconds: 1 * attempts));
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ NOTIFICATION SERVICE ERROR: Failed to save FCM token: $e');
      debugPrint('❌ NOTIFICATION SERVICE ERROR: Stack trace: ${StackTrace.current}');
    }
    
    // No listeners for token refresh are needed
  }

  // Token refresh handling removed as requested

  /// Delete FCM token when user logs out 
  Future<void> removeToken(String userId) async {
    try {
      debugPrint('🔔 NOTIFICATION SERVICE: Deleting FCM token for user: $userId');
      
      // Simply delete the token from Firebase Messaging
      await _firebaseMessaging.deleteToken();
      
      debugPrint('✅ NOTIFICATION SERVICE: FCM token deleted locally for user: $userId');
    } catch (e) {
      debugPrint('❌ NOTIFICATION SERVICE ERROR: Failed to delete FCM token: $e');
    }
  }

  /// Helper to get the current platform name
  String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }
}
