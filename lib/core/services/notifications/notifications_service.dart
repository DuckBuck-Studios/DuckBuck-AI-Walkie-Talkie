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
      
      // 🔧 FIX: Get the network URL instead of local cached path
      String callerPhoto = '';
      final photoURL = currentUser.photoURL ?? '';
      
      if (photoURL.isNotEmpty) {
        if (photoURL.startsWith('file://') || photoURL.startsWith('/')) {
          // This is a local cached file path - we need the network URL instead
          // Try to get the network URL from user service or fallback to empty
          _logger.w(_tag, 'Detected local file path in photoURL: $photoURL');
          
          try {
            // Get fresh user data from Firestore to get the network URL
            final freshUserData = await _userService.getUserData(currentUser.uid);
            if (freshUserData?.photoURL != null && 
                !freshUserData!.photoURL!.startsWith('file://') && 
                !freshUserData.photoURL!.startsWith('/')) {
              callerPhoto = freshUserData.photoURL!;
              _logger.i(_tag, 'Using network URL from fresh user data: ${callerPhoto.substring(0, 50)}...');
            } else {
              _logger.w(_tag, 'Fresh user data also contains local path, using empty photo URL');
              callerPhoto = '';
            }
          } catch (e) {
            _logger.e(_tag, 'Error fetching fresh user data for network URL: $e');
            callerPhoto = '';
          }
        } else {
          // This is already a network URL
          callerPhoto = photoURL;
          _logger.d(_tag, 'Using network URL: ${callerPhoto.substring(0, 50)}...');
        }
      }
      
      _logger.d(_tag, 'Using caller data - Name: $callName, Photo: ${callerPhoto.isNotEmpty ? "network URL present" : "not present"}');
      _logger.d(_tag, 'Final photo URL for FCM: ${callerPhoto.isNotEmpty ? callerPhoto : "EMPTY"}');
      
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

}
