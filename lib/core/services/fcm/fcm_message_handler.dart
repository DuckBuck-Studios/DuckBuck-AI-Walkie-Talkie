import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logger/logger_service.dart';
import '../../navigation/app_routes.dart';

/// FCM Message Handler for handling Firebase Cloud Messaging notifications
///
/// This service handles all FCM notification scenarios:
/// - Foreground: No notifications shown (as per requirement)
/// - Background/Killed: Shows local notifications that navigate to friends screen
/// - Message handling with authentication checks
class FCMMessageHandler {
  static final FCMMessageHandler _instance = FCMMessageHandler._internal();
  factory FCMMessageHandler() => _instance;
  FCMMessageHandler._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'FCM_HANDLER';
  
  // Notification configuration
  static const String _channelId = 'duckbuck_notifications';
  static const String _channelName = 'DuckBuck Notifications';
  static const String _channelDescription = 'Notifications for friend requests and app updates';

  /// Initialize FCM message handling
  Future<void> initialize() async {
    try {
      _logger.i(_tag, 'Initializing FCM message handler');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Set up FCM message handlers
      await _setupMessageHandlers();
      
      _logger.i(_tag, 'FCM message handler initialized successfully');
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize FCM message handler: $e');
      rethrow;
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings  
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Initialize with callback for notification taps
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();
      
      _logger.d(_tag, 'Local notifications initialized');
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize local notifications: $e');
      rethrow;
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
          
      _logger.d(_tag, 'Notification channel created');
    } catch (e) {
      _logger.e(_tag, 'Failed to create notification channel: $e');
    }
  }

  /// Set up FCM message handlers
  Future<void> _setupMessageHandlers() async {
    try {
      // Handle foreground messages (don't show notifications as per requirement)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background messages (when app is backgrounded but not killed)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // Handle messages when app is opened from terminated state
      _handleInitialMessage();
      
      _logger.d(_tag, 'FCM message handlers set up');
    } catch (e) {
      _logger.e(_tag, 'Failed to set up FCM message handlers: $e');
      rethrow;
    }
  }

  /// Handle foreground messages (when app is in foreground)
  /// As per requirement: Don't show anything in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      _logger.i(_tag, 'Received foreground message: ${message.messageId}');
      _logger.d(_tag, 'Foreground message data: ${message.data}');
      
      // Log the message but don't show any notification (as per requirement)
      if (message.notification != null) {
        _logger.d(_tag, 'Foreground notification title: ${message.notification!.title}');
        _logger.d(_tag, 'Foreground notification body: ${message.notification!.body}');
      }
      
      // Don't show any notifications in foreground as per requirement
      _logger.i(_tag, 'Foreground message handled (no notification shown)');
    } catch (e) {
      _logger.e(_tag, 'Error handling foreground message: $e');
    }
  }

  /// Handle notification tap when app is in background
  void _handleNotificationTap(RemoteMessage message) {
    try {
      _logger.i(_tag, 'Notification tapped from background: ${message.messageId}');
      _navigateToFriendsScreen(message);
    } catch (e) {
      _logger.e(_tag, 'Error handling notification tap: $e');
    }
  }

  /// Handle initial message when app is opened from terminated state
  Future<void> _handleInitialMessage() async {
    try {
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      
      if (initialMessage != null) {
        _logger.i(_tag, 'App opened from notification: ${initialMessage.messageId}');
        // Reduced delay to ensure app is fully initialized - from 500ms to 300ms
        Future.delayed(const Duration(milliseconds: 300), () {
          _navigateToFriendsScreen(initialMessage);
        });
      }
    } catch (e) {
      _logger.e(_tag, 'Error handling initial message: $e');
    }
  }

  /// Navigate to friends screen with authentication check
  Future<void> _navigateToFriendsScreen(RemoteMessage message) async {
    try {
      _logger.i(_tag, 'Attempting to navigate to friends screen');
      
      // Check if user is authenticated
      if (!_isUserAuthenticated()) {
        _logger.w(_tag, 'User not authenticated, cannot navigate to friends screen');
        return;
      }
      
      _logger.i(_tag, 'User authenticated, navigating to friends screen');
      
      // Navigate to home route (which contains friends screen in bottom navigation)
      final navigatorKey = AppRoutes.navigatorKey;
      if (navigatorKey.currentState != null) {
        // Navigate to home which contains the friends tab
        await navigatorKey.currentState!.pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
        
        _logger.i(_tag, 'Successfully navigated to home screen');
        
        // Log analytics for notification interaction
        _logNotificationInteraction(message);
      } else {
        _logger.w(_tag, 'Navigator not available for navigation');
      }
    } catch (e) {
      _logger.e(_tag, 'Error navigating to friends screen: $e');
    }
  }

  /// Check if user is properly authenticated
  bool _isUserAuthenticated() {
    try {
      // Check Firebase Auth state (primary source of truth)
      final firebaseUser = FirebaseAuth.instance.currentUser;
      
      // Firebase Auth is the authoritative source for authentication state
      bool isAuthenticated = firebaseUser != null;
      
      _logger.d(_tag, 'Authentication check - Firebase: ${firebaseUser != null}, Result: $isAuthenticated');
      
      return isAuthenticated;
    } catch (e) {
      _logger.e(_tag, 'Error checking authentication: $e');
      return false;
    }
  }

  /// Handle notification response when user taps on local notification
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    try {
      _logger.i(_tag, 'Local notification tapped: ${notificationResponse.id}');
      
      // Parse the payload if it contains message data
      final payload = notificationResponse.payload;
      if (payload != null) {
        _logger.d(_tag, 'Notification payload: $payload');
      }
      
      // Create a mock RemoteMessage for navigation (since we're coming from local notification)
      final mockMessage = _createMockRemoteMessage(notificationResponse);
      _navigateToFriendsScreen(mockMessage);
    } catch (e) {
      _logger.e(_tag, 'Error handling notification tap: $e');
    }
  }

  /// Create a mock RemoteMessage from notification response for consistent handling
  RemoteMessage _createMockRemoteMessage(NotificationResponse notificationResponse) {
    return RemoteMessage(
      messageId: 'local_${notificationResponse.id}',
      data: {
        'source': 'local_notification',
        'original_payload': notificationResponse.payload ?? '',
      },
    );
  }

  /// Log notification interaction for analytics
  void _logNotificationInteraction(RemoteMessage message) {
    try {
      _logger.d(_tag, 'Logging notification interaction for message: ${message.messageId}');
      
      // Log basic interaction data
      final data = {
        'message_id': message.messageId ?? 'unknown',
        'source': message.data['source'] ?? 'fcm',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _logger.i(_tag, 'Notification interaction logged: $data');
    } catch (e) {
      _logger.e(_tag, 'Error logging notification interaction: $e');
    }
  }

  /// Show local notification for background/killed state messages
  Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      _logger.i(_tag, 'Showing local notification for message: ${message.messageId}');
      
      // Body only (no title) based on message type
      String body = '';
      
      // Extract data fields based on notification type
      final Map<String, dynamic> data = message.data;
      final notificationType = data['type'];
      _logger.d(_tag, 'Processing notification type: $notificationType');
      
      // Format notification based on type
      if (notificationType == 'friend_request') {
        // Extract sender name only
        final senderName = data['sender_name'] ?? 'Someone';
        _logger.d(_tag, 'Friend request from: $senderName');
        
        // Only show the name and action in body, no title
        body = '$senderName wants to be your friend';
      } else if (notificationType == 'friend_request_accepted') {
        // Extract accepter name only
        final accepterName = data['accepter_name'] ?? 'Someone';
        _logger.d(_tag, 'Friend request accepted by: $accepterName');
        
        // Only show the name and action in body, no title
        body = '$accepterName accepted your friend request';
      } else {
        // Default to using the message's notification if available
        final notification = message.notification;
        if (notification == null) {
          _logger.w(_tag, 'No notification data in message');
          return;
        }
        
        body = notification.body ?? 'You have a new notification';
      }
      
      // Create Android notification details with standard style - no title or image
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.social,
        channelShowBadge: true,
        // No large icon (profile photo)
        // Simple text style with no title
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: true,
          summaryText: 'DuckBuck',
          htmlFormatSummaryText: true,
        ),
        // Add group tag for social notification
        groupKey: 'duckbuck_social',
      );

      // Create iOS notification details
      final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
        categoryIdentifier: 'social',
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Store all notification data for when user taps
      final String payload = message.data.toString();

      // Show the notification with no title, only body
      await _localNotifications.show(
        message.hashCode,
        "", // Empty title
        body,
        notificationDetails,
        payload: payload,
      );
      
      _logger.i(_tag, 'Local notification shown successfully');
    } catch (e) {
      _logger.e(_tag, 'Error showing local notification: $e');
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      _logger.i(_tag, 'Requesting notification permissions');
      
      // Request FCM permissions
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      
      final bool granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                          settings.authorizationStatus == AuthorizationStatus.provisional;
      
      _logger.i(_tag, 'Notification permission status: ${settings.authorizationStatus}, granted: $granted');
      
      return granted;
    } catch (e) {
      _logger.e(_tag, 'Error requesting permissions: $e');
      return false;
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      _logger.d(_tag, 'FCM token retrieved');
      return token;
    } catch (e) {
      _logger.e(_tag, 'Error getting FCM token: $e');
      return null;
    }
  }
}
