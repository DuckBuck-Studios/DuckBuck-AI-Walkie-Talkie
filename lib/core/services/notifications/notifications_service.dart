import 'package:firebase_messaging/firebase_messaging.dart';
import '../logger/logger_service.dart';
import '../api/api_service.dart';
import '../../repositories/user_repository.dart';
import '../service_locator.dart';
import '../user/user_service_interface.dart';

/// Service for handling push notifications and FCM token management
class NotificationsService {
  final LoggerService _logger;
  final ApiService _apiService;
  final UserServiceInterface _userService;
  
  static const String _tag = 'NOTIFICATIONS'; // Tag for logs

  /// Creates a new NotificationsService
  NotificationsService({
    required ApiService apiService,
    UserServiceInterface? userService,
    LoggerService? logger,
  }) : _apiService = apiService,
       _userService = userService ?? serviceLocator<UserServiceInterface>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Initialize the notifications service
  Future<void> initialize() async {
    try {
      _logger.i(_tag, 'Initializing notifications service with FCM token management');
      
      // Request notification permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      _logger.i(_tag, 'Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize notifications service: $e');
    }
  }

  /// Generate and save FCM token for user during sign-in
  Future<void> generateAndSaveToken(String userId) async {
    try {
      _logger.i(_tag, 'Generating FCM token for user: $userId');
      
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      
      if (token != null) {
        _logger.i(_tag, 'FCM token generated successfully: ${token.substring(0, 20)}...');
        
        // Create FCM token data structure
        final fcmTokenData = {
          'token': token,
          'platform': 'flutter',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Get current user data to preserve other fields
        final currentUser = await _userService.getUserData(userId);
        if (currentUser != null) {
          // Create updated user with FCM token data
          final updatedUser = currentUser.copyWith(fcmTokenData: fcmTokenData);
          
          // Save to Firestore
          await _userService.updateUserData(updatedUser);
          _logger.i(_tag, 'FCM token saved to Firestore for user: $userId');
        } else {
          _logger.w(_tag, 'Could not find user data to update FCM token for: $userId');
        }
      } else {
        _logger.w(_tag, 'Failed to generate FCM token for user: $userId');
      }
    } catch (e) {
      _logger.e(_tag, 'Error generating and saving FCM token: $e');
    }
  }

  /// Register FCM token for the current user
  Future<void> restoreOrRegisterToken(String userId) async {
    await generateAndSaveToken(userId);
  }

  /// Register FCM token for the current user
  Future<void> registerToken(String userId) async {
    await generateAndSaveToken(userId);
  }

  /// Remove FCM token when user logs out
  Future<void> removeToken(String userId) async {
    try {
      _logger.i(_tag, 'Removing FCM token for user: $userId');
      
      // Get current user data
      final currentUser = await _userService.getUserData(userId);
      if (currentUser != null) {
        // Remove FCM token data
        final updatedUser = currentUser.copyWith(fcmTokenData: null);
        
        // Update in Firestore
        await _userService.updateUserData(updatedUser);
        _logger.i(_tag, 'FCM token removed from Firestore for user: $userId');
      } else {
        _logger.w(_tag, 'Could not find user data to remove FCM token for: $userId');
      }
    } catch (e) {
      _logger.e(_tag, 'Error removing FCM token: $e');
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
  
  /// Send welcome email to a new user after profile completion
  /// This is a fire-and-forget operation that won't block the UI
  /// No exceptions are thrown and no return value is provided
  void sendWelcomeEmail({
    required String email,
    required String username,
    required Map<String, dynamic>? metadata,
  }) {
    // Fire and forget - schedule async operation without awaiting
    _apiService.sendWelcomeEmail(
      email: email,
      username: username,
      metadata: metadata,
    ).then((success) {
      if (success) {
        _logger.i(_tag, 'Welcome email sent successfully to $email');
      } else {
        _logger.w(_tag, 'Welcome email failed to send to $email');
      }
    }).catchError((error) {
      _logger.e(_tag, 'Error sending welcome email to $email: $error');
    });
  }
  
  /// Send login notification email to returning users
  /// This is a fire-and-forget operation that won't block the UI
  /// No exceptions are thrown and no return value is provided
  void sendLoginNotificationEmail({
    required String email,
    required String username,
    required String loginTime,
    required Map<String, dynamic>? metadata,
  }) {
    // Fire and forget - schedule async operation without awaiting
    _apiService.sendLoginNotificationEmail(
      email: email,
      username: username,
      loginTime: loginTime,
      metadata: metadata,
    ).then((success) {
      if (success) {
        _logger.i(_tag, 'Login notification sent successfully to $email');
      } else {
        _logger.w(_tag, 'Login notification failed to send to $email');
      }
    }).catchError((error) {
      _logger.e(_tag, 'Error sending login notification to $email: $error');
    });
  }
}
