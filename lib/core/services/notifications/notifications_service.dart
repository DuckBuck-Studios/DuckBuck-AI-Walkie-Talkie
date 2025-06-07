import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_database_service.dart';
import '../logger/logger_service.dart';
import '../api/api_service.dart';
import '../../repositories/user_repository.dart';
import '../service_locator.dart';

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
  final ApiService _apiService;
  
  static const String _tag = 'NOTIFICATIONS'; // Tag for logs

  /// Creates a new NotificationsService
  NotificationsService({
    FirebaseMessaging? firebaseMessaging,
    required FirebaseDatabaseService databaseService,
    required ApiService apiService,
  }) : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
       _databaseService = databaseService,
       _apiService = apiService;

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

    // 1. Delete the token from Firebase Messaging on the device
    _logger.d(_tag, 'Deleting token from device');
    await _firebaseMessaging.deleteToken();
    _logger.d(_tag, 'Device token deletion completed');

    // 2. Update Firestore: set token inside fcmTokenData to null and remove rogue fields
    _logger.d(_tag, 'Clearing FCM token data and rogue fields in Firestore for user: $userId');

    await _databaseService.setDocument(
      collection: 'users',
      documentId: userId,
      data: {
        'fcmTokenData': {
          'token': null,
        },
        'fcmTokenData.token': FieldValue.delete(), // remove incorrect dot-named field
        'fcmTokenData.lastUpdated': FieldValue.delete(),
      },
      merge: true,
    );

    // 3. Optional: Verify cleanup
    final userData = await _databaseService.getDocument(
      collection: 'users',
      documentId: userId,
    );

    final fcmTokenData = userData?['fcmTokenData'];
    final bool nestedTokenNull = fcmTokenData is Map && fcmTokenData['token'] == null;
    final bool rogueTokenRemoved = userData?['fcmTokenData.token'] == null;
    final bool rogueLastUpdatedRemoved = userData?['fcmTokenData.lastUpdated'] == null;

    if (nestedTokenNull && rogueTokenRemoved && rogueLastUpdatedRemoved) {
      _logger.i(_tag, '✅ Verified FCM token data and rogue fields are cleared.');
    } else {
      String warning = '⚠️ Token data cleanup incomplete:';
      if (!nestedTokenNull) {
        warning += ' fcmTokenData.token is not null or missing.';
      }
      if (!rogueTokenRemoved) {
        warning += ' Rogue field "fcmTokenData.token" still exists.';
      }
      if (!rogueLastUpdatedRemoved) {
        warning += ' Rogue field "fcmTokenData.lastUpdated" still exists.';
      }
      _logger.w(_tag, warning);
    }

    _logger.i(_tag, 'FCM token removal process completed for user: $userId');
  } catch (e) {
    _logger.e(_tag, 'Error in removeToken: ${e.toString()}');
    throw Exception('Failed to remove FCM token: ${e.toString()}');
  }
}

  
  /// Send push notification to a user
  /// Fire-and-forget method - doesn't throw exceptions, just logs results
  Future<bool> sendNotification({
    required String recipientUid,
    String? title,  // Make title optional
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      _logger.i(_tag, 'Sending notification to user: $recipientUid');
      final success = await _apiService.sendNotification(
        recipientUid: recipientUid,
        title: title,  // Pass title as optional
        body: body,
        data: data,
      );
      
      if (success) {
        _logger.i(_tag, 'Notification sent successfully to user: $recipientUid');
      } else {
        _logger.w(_tag, 'Failed to send notification to user: $recipientUid');
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, 'Error sending notification: $e');
      return false;
    }
  }

  /// Send data-only push notification to a user (for call invitations)
  /// Fire-and-forget method - doesn't throw exceptions, just logs results
  /// Automatically fetches current user's displayName and photoURL from cached auth data
  Future<bool> sendDataOnlyNotification({
    required String uid,
    required String type,
    required String agoraUid,
    required String agoraChannelId,
  }) async {
    try {
      _logger.i(_tag, 'Sending data-only notification to user: $uid');
      
      // Get current user's name and photo from cached auth data
      final userRepository = serviceLocator<UserRepository>();
      final currentUser = await userRepository.getCurrentUser();
      
      if (currentUser == null) {
        _logger.e(_tag, 'Cannot send data-only notification: No current user found');
        return false;
      }
      
      final callName = currentUser.displayName ?? 'Unknown User';
      final callerPhoto = currentUser.photoURL ?? '';
      
      _logger.d(_tag, 'Using caller data - Name: $callName, Photo: ${callerPhoto.isNotEmpty ? "present" : "not present"}');
      
      final success = await _apiService.sendDataOnlyNotification(
        uid: uid,
        type: type,
        agoraUid: agoraUid,
        agoraChannelId: agoraChannelId,
        callName: callName,
        callerPhoto: callerPhoto,
      );
      
      if (success) {
        _logger.i(_tag, 'Data-only notification sent successfully to user: $uid');
      } else {
        _logger.w(_tag, 'Failed to send data-only notification to user: $uid');
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, 'Error sending data-only notification: $e');
      return false;
    }
  }

  /// Helper to get the current platform name
  String _getPlatformName() { 
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios'; 
    return 'unknown';
  }
}
