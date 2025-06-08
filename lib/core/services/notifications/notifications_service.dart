import '../logger/logger_service.dart';
import '../api/api_service.dart';
import '../../repositories/user_repository.dart';
import '../service_locator.dart';

/// Service for handling push notifications
///
/// Note: FCM token management is now handled entirely on the Kotlin/Android side.
/// This service only handles notification sending through the API service.
class NotificationsService {
  final LoggerService _logger = LoggerService();
  final ApiService _apiService;
  
  static const String _tag = 'NOTIFICATIONS'; // Tag for logs

  /// Creates a new NotificationsService
  NotificationsService({
    required ApiService apiService,
  }) : _apiService = apiService;

  /// Initialize the notifications service
  /// Since FCM is handled on Kotlin side, this is now a no-op
  Future<void> initialize() async {
    _logger.i(_tag, 'Initializing notifications service (FCM handled by Kotlin)');
  }

  /// Register FCM token for the current user
  /// Since FCM is handled on Kotlin side, this is now a no-op
  Future<void> restoreOrRegisterToken(String userId) async {
    _logger.d(_tag, 'FCM token registration handled by Kotlin for user: $userId');
  }

  /// Register FCM token for the current user
  /// Since FCM is handled on Kotlin side, this is now a no-op
  Future<void> registerToken(String userId) async {
    _logger.d(_tag, 'FCM token registration handled by Kotlin for user: $userId');
  }

  /// Remove FCM token when user logs out
  /// Since FCM is handled on Kotlin side, this is now a no-op
  Future<void> removeToken(String userId) async {
    _logger.d(_tag, 'FCM token removal handled by Kotlin for user: $userId');
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
}
