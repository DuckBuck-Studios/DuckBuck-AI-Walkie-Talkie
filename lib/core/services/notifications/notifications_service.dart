import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_database_service.dart';
import '../logger/logger_service.dart';

/// Service for handling push notifications and FCM tokens
///
/// This service encapsulates all notification-related functionality:
/// - FCM token registration and storage
/// - Notification permission handling
/// - Notification configuration
class NotificationsService {
  final FirebaseMessaging _firebaseMessaging;
  final FirebaseDatabaseService _databaseService;
  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'NOTIFICATIONS'; // Tag for logs

  /// Creates a new NotificationsService
  NotificationsService({
    FirebaseMessaging? firebaseMessaging,
    required FirebaseDatabaseService databaseService,
  }) : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
       _databaseService = databaseService;

  /// Initialize FCM token generation
  Future<void> initialize() async {
    try {
      _logger.i(_tag, 'Initializing notifications service');
      // Request minimal permissions needed for token generation
      await _firebaseMessaging.requestPermission(
        alert: false,
        badge: false,
        sound: false,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      _logger.d(_tag, 'Permission request for FCM token completed');
      
      // Test if we can get a token (don't save it yet, just check availability)
      try {
        await _firebaseMessaging.getToken();
        _logger.d(_tag, 'FCM token availability check passed');
      } catch (e) {
        // Handle error silently but log it for debugging
        _logger.w(_tag, 'FCM token availability check failed: ${e.toString()}');
      }
    } catch (e) {
      // Handle error silently but log it for debugging
      _logger.e(_tag, 'Notification service initialization error: ${e.toString()}');
    }
  }

  /// Register FCM token for the current user
  /// This has been simplified to always register a fresh token
  Future<void> restoreOrRegisterToken(String userId) async {
    try {
      _logger.i(_tag, 'Registering FCM token for user: $userId');
      await registerToken(userId);
    } catch (e) {
      _logger.e(_tag, 'Error in restoreOrRegisterToken: ${e.toString()}');
      // Retry registration
      await registerToken(userId);
    }
  }

  /// Register FCM token for the current user - token generation only
  ///
  /// This should be called after successful user authentication
  Future<void> registerToken(String userId) async {
    try {
      // Force token refresh to ensure we get the latest
      _logger.d(_tag, 'Refreshing FCM token for user: $userId');
      await _firebaseMessaging.deleteToken();
      final token = await _firebaseMessaging.getToken();
      
      if (token == null) {
        _logger.w(_tag, 'Failed to get FCM token - token is null');
        return;
      }
      
      _logger.d(_tag, 'Successfully retrieved new FCM token');
      // Store FCM token and related data under fcmTokenData object
      final Map<String, dynamic> tokenData = {
        'fcmTokenData': {
          'token': token,
          'platform': _getPlatformName(), 
        }
      };
      
      // Retry mechanism for saving token
      bool saved = false;
      int attempts = 0;
      const maxAttempts = 3;
      
      _logger.d(_tag, 'Saving FCM token to Firestore for user: $userId');
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
          _logger.i(_tag, 'FCM token saved successfully for user: $userId');
        } catch (e) {
          _logger.w(_tag, 'Attempt $attempts failed to save token: ${e.toString()}');
          if (attempts < maxAttempts) {
            _logger.d(_tag, 'Retrying in $attempts seconds...');
            await Future.delayed(Duration(seconds: 1 * attempts));
          } else {
            _logger.e(_tag, 'All attempts to save token failed');
            rethrow;
          }
        }
      }
    } catch (e) {
      // Handle error silently but log it for debugging
      _logger.e(_tag, 'Error in registerToken: ${e.toString()}');
    }
  }

  /// Delete FCM token when user logs out - removes from both local device and Firestore
  Future<void> removeToken(String userId) async {
    try {
      _logger.i(_tag, 'Removing FCM token for user: $userId');
      
      // 1. Delete the token from Firebase Messaging on device first
      _logger.d(_tag, 'Deleting token from device');
      await _firebaseMessaging.setAutoInitEnabled(false);
      await _firebaseMessaging.deleteToken();
      _logger.d(_tag, 'Device token deletion completed');
      
      // 2. Update Firestore to set token to null but preserve the structure
      _logger.d(_tag, 'Updating token in Firestore');
      
      await _databaseService.setDocument(
        collection: 'users',
        documentId: userId,
        data: {
          'fcmTokenData.token': null,
          'fcmTokenData.lastUpdated': FieldValue.serverTimestamp(),
        },
        merge: true
      );

      // 3. Verify the token was properly cleared
      final userData = await _databaseService.getDocument(
        collection: 'users',
        documentId: userId,
      );

      if (userData != null && userData['fcmTokenData'] != null) {
        final fcmData = userData['fcmTokenData'] as Map<String, dynamic>;
        if (fcmData['token'] == null) {
          _logger.i(_tag, '✅ Verified fcmTokenData.token is now null');
        } else {
          _logger.w(_tag, '⚠️ Token may not be properly cleared');
        }
      }

      _logger.i(_tag, 'FCM token successfully removed for user: $userId');
    } catch (e) {
      _logger.e(_tag, 'Error in removeToken: ${e.toString()}');
      // If the primary update fails, try a simpler approach
      try {
        await _databaseService.setDocument(
          collection: 'users',
          documentId: userId,
          data: {'fcmTokenData': null},
          merge: true
        );
      } catch (fallbackError) {
        _logger.e(_tag, 'Fallback token removal also failed: ${fallbackError.toString()}');
        throw Exception('Failed to remove FCM token: ${e.toString()}');
      }
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
