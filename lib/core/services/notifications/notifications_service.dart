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

  /// Initialize notification settings and request permissions
  Future<void> initialize() async {
    try {
      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        'Notification authorization status: ${settings.authorizationStatus}',
      );

      // Configure FCM in foreground
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  /// Register FCM token for the current user
  ///
  /// This should be called after successful user authentication
  Future<void> registerToken(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();

      if (token != null) {
        // Store the token in the user's document
        await _databaseService.setDocument(
          collection: 'users',
          documentId: userId,
          data: {
            'fcmTokens': {
              token: {
                'createdAt': DateTime.now().toIso8601String(),
                'platform': _getPlatformName(),
                'lastActiveAt': DateTime.now().toIso8601String(),
              },
            },
          },
          merge: true,
        );

        debugPrint('FCM Token registered for user: $userId');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }

    // Listen for token refreshes
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _updateToken(userId, newToken);
    });
  }

  /// Update FCM token when refreshed
  Future<void> _updateToken(String userId, String newToken) async {
    try {
      await _databaseService.setDocument(
        collection: 'users',
        documentId: userId,
        data: {
          'fcmTokens': {
            newToken: {
              'updatedAt': DateTime.now().toIso8601String(),
              'platform': _getPlatformName(),
              'lastActiveAt': DateTime.now().toIso8601String(),
            },
          },
        },
        merge: true,
      );

      debugPrint('FCM Token updated for user: $userId');
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
    }
  }

  /// Remove FCM token when user logs out
  Future<void> removeToken(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();

      if (token != null) {
        // Get current tokens
        final userDoc = await _databaseService.getDocument(
          collection: 'users',
          documentId: userId,
        );

        if (userDoc != null && userDoc.containsKey('fcmTokens')) {
          final Map<String, dynamic> tokens = Map.from(userDoc['fcmTokens']);

          // Remove this token
          tokens.remove(token);

          // Update the document
          await _databaseService.updateDocument(
            collection: 'users',
            documentId: userId,
            data: {'fcmTokens': tokens},
          );

          debugPrint('FCM Token removed for user: $userId');
        }
      }
    } catch (e) {
      debugPrint('Failed to remove FCM token: $e');
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
