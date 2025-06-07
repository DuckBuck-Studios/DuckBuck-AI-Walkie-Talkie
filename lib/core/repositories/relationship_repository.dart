import '../services/relationship/relationship_service_interface.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/logger/logger_service.dart';
import '../services/service_locator.dart';
import '../exceptions/relationship_exceptions.dart';
import 'dart:async';

/// Repository to handle relationship data operations
/// 
/// Provides a clean abstraction layer between the UI/business logic and the relationship service.
/// Follows the repository pattern to coordinate between services, handle error logging,
/// and provide analytics tracking for all relationship operations.
/// 
/// Features:
/// - Real-time streams for friends, pending requests, and blocked users
/// - Comprehensive analytics tracking for all operations
/// - Error handling with Crashlytics integration
/// - Transaction-safe relationship operations
class RelationshipRepository {
  final RelationshipServiceInterface _relationshipService;
  final FirebaseAnalyticsService _analytics;
  final FirebaseCrashlyticsService _crashlytics;
  final LoggerService _logger;

  static const String _tag = 'RELATIONSHIP_REPO';

  /// Creates a new RelationshipRepository
  RelationshipRepository({
    RelationshipServiceInterface? relationshipService,
    FirebaseAnalyticsService? analytics,
    FirebaseCrashlyticsService? crashlytics,
    LoggerService? logger,
  }) : _relationshipService = relationshipService ?? serviceLocator<RelationshipServiceInterface>(),
       _analytics = analytics ?? serviceLocator<FirebaseAnalyticsService>(),
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  // ========== FRIEND REQUEST OPERATIONS ==========

  /// Send a friend request to another user
  /// Returns the relationship ID if successful
  Future<String> sendFriendRequest(String targetUserId) async {
    try {
      _logger.d(_tag, 'Sending friend request to user: $targetUserId');
      
      final relationshipId = await _relationshipService.sendFriendRequest(targetUserId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_request_sent',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend request sent successfully: $relationshipId');
      return relationshipId;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to send friend request: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friend_request_sent',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to send friend request',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Accept a pending friend request
  /// Returns the relationship ID if successful
  Future<String> acceptFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Accepting friend request: $relationshipId');
      
      final resultId = await _relationshipService.acceptFriendRequest(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_request_accepted',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend request accepted successfully: $relationshipId');
      return resultId;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to accept friend request: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friend_request_accepted',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to accept friend request',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Reject/decline a pending friend request
  /// Returns true if successful
  Future<bool> rejectFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Rejecting friend request: $relationshipId');
      
      final result = await _relationshipService.rejectFriendRequest(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_request_rejected',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend request rejected successfully: $relationshipId');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to reject friend request: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friend_request_rejected',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to reject friend request',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Cancel a sent friend request
  /// Returns true if successful
  Future<bool> cancelFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Cancelling friend request: $relationshipId');
      
      final result = await _relationshipService.cancelFriendRequest(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_request_cancelled',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend request cancelled successfully: $relationshipId');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to cancel friend request: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friend_request_cancelled',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to cancel friend request',
        fatal: false,
      );
      
      rethrow;
    }
  }

  // ========== FRIENDSHIP MANAGEMENT ==========

  /// Remove an existing friend
  /// Returns true if successful
  Future<bool> removeFriend(String targetUserId) async {
    try {
      _logger.d(_tag, 'Removing friend: $targetUserId');
      
      final result = await _relationshipService.removeFriend(targetUserId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_removed',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend removed successfully: $targetUserId');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friend_removed',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to remove friend',
        fatal: false,
      );
      
      rethrow;
    }
  }

  // ========== BLOCKING OPERATIONS ==========

  /// Block a user
  /// Returns the relationship ID if successful
  Future<String> blockUser(String targetUserId) async {
    try {
      _logger.d(_tag, 'Blocking user: $targetUserId');
      
      final relationshipId = await _relationshipService.blockUser(targetUserId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'user_blocked',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'User blocked successfully: $targetUserId');
      return relationshipId;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to block user: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'user_blocked',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to block user',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Unblock a user
  /// Returns true if successful
  Future<bool> unblockUser(String targetUserId) async {
    try {
      _logger.d(_tag, 'Unblocking user: $targetUserId');
      
      final result = await _relationshipService.unblockUser(targetUserId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'user_unblocked',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'User unblocked successfully: $targetUserId');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to unblock user: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'user_unblocked',
        parameters: {
          'target_user_id_hash': targetUserId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to unblock user',
        fatal: false,
      );
      
      rethrow;
    }
  }

  // ========== REAL-TIME STREAM OPERATIONS ==========

  /// Get real-time stream of friends list (accepted relationships)
  /// Returns stream of user data for friends with real-time updates
  /// Limited to 15 items per page for optimal performance
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    try {
      _logger.d(_tag, 'Getting friends stream for current user');
      
      return _relationshipService.getFriendsStream()
        .asyncMap((friends) async {
          // Track stream updates for analytics
          await _analytics.logEvent(
            name: 'friends_stream_updated',
            parameters: {
              'count': friends.length,
              'success': true,
            },
          );
          
          _logger.d(_tag, 'Friends stream updated: ${friends.length} friends');
          // Enhanced debugging - log friend UIDs
          for (int i = 0; i < friends.length; i++) {
            final friend = friends[i];
            _logger.d(_tag, 'Repository Friend $i: uid=${friend['uid']}, name=${friend['displayName']}');
          }
          return friends;
        })
        .handleError((error) async {
          _logger.e(_tag, 'Error in friends stream: $error');
          
          // Track stream errors
          await _analytics.logEvent(
            name: 'friends_stream_error',
            parameters: {
              'success': false,
              'error_code': error is RelationshipException ? error.code : 'unknown',
            },
          );
          
          // Log to crashlytics for debugging
          await _crashlytics.recordError(
            error,
            null,
            reason: 'Failed to stream friends',
            fatal: false,
          );
          
          throw error;
        });
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize friends stream: ${e.toString()}');
      
      // Log initialization errors
      _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to initialize friends stream',
        fatal: false,
      );
      
      return Stream.error(e);
    }
  }

  /// Get real-time stream of pending friend requests (received by current user)
  /// Returns stream of user data for users who sent requests with real-time updates
  /// Limited to 15 items per page for optimal performance
  Stream<List<Map<String, dynamic>>> getPendingRequestsStream() {
    try {
      _logger.d(_tag, 'Getting pending requests stream for current user');
      
      return _relationshipService.getPendingRequestsStream()
        .asyncMap((requests) async {
          // Track stream updates for analytics
          await _analytics.logEvent(
            name: 'pending_requests_stream_updated',
            parameters: {
              'count': requests.length,
              'success': true,
            },
          );
          
          _logger.d(_tag, 'Pending requests stream updated: ${requests.length} requests');
          return requests;
        })
        .handleError((error) async {
          _logger.e(_tag, 'Error in pending requests stream: $error');
          
          // Track stream errors
          await _analytics.logEvent(
            name: 'pending_requests_stream_error',
            parameters: {
              'success': false,
              'error_code': error is RelationshipException ? error.code : 'unknown',
            },
          );
          
          // Log to crashlytics for debugging
          await _crashlytics.recordError(
            error,
            null,
            reason: 'Failed to stream pending requests',
            fatal: false,
          );
          
          throw error;
        });
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize pending requests stream: ${e.toString()}');
      
      // Log initialization errors
      _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to initialize pending requests stream',
        fatal: false,
      );
      
      return Stream.error(e);
    }
  }

  /// Get real-time stream of blocked users
  /// Returns stream of user data for blocked users with real-time updates
  /// Limited to 15 items per page for optimal performance
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream() {
    try {
      _logger.d(_tag, 'Getting blocked users stream for current user');
      
      return _relationshipService.getBlockedUsersStream()
        .asyncMap((blockedUsers) async {
          // Track stream updates for analytics
          await _analytics.logEvent(
            name: 'blocked_users_stream_updated',
            parameters: {
              'count': blockedUsers.length,
              'success': true,
            },
          );
          
          _logger.d(_tag, 'Blocked users stream updated: ${blockedUsers.length} blocked');
          return blockedUsers;
        })
        .handleError((error) async {
          _logger.e(_tag, 'Error in blocked users stream: $error');
          
          // Track stream errors
          await _analytics.logEvent(
            name: 'blocked_users_stream_error',
            parameters: {
              'success': false,
              'error_code': error is RelationshipException ? error.code : 'unknown',
            },
          );
          
          // Log to crashlytics for debugging
          await _crashlytics.recordError(
            error,
            null,
            reason: 'Failed to stream blocked users',
            fatal: false,
          );
          
          throw error;
        });
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize blocked users stream: ${e.toString()}');
      
      // Log initialization errors
      _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to initialize blocked users stream',
        fatal: false,
      );
      
      return Stream.error(e);
    }
  }  /// Setup real-time stream subscription for user data based on provided UIDs
  /// Returns a stream of user data maps that updates when user information changes
  /// This method allows separate management of user data streams from relationship streams
  Stream<Map<String, Map<String, dynamic>>> setupUserStreamSubscription(List<String> userIds) {
    try {
      _logger.d(_tag, 'Setting up user stream subscription for ${userIds.length} users');
      
      return _relationshipService.setupUserStreamSubscription(userIds)
        .asyncMap((usersMap) async {
          // Track stream updates for analytics
          await _analytics.logEvent(
            name: 'user_stream_subscription_updated',
            parameters: {
              'user_count': userIds.length,
              'returned_count': usersMap.length,
              'success': true,
            },
          );
          
          _logger.d(_tag, 'User stream subscription updated: ${usersMap.length} users');
          return usersMap;
        })
        .handleError((error) async {
          _logger.e(_tag, 'Error in user stream subscription: $error');
          
          // Track stream errors
          await _analytics.logEvent(
        name: 'user_stream_subscription_error',
        parameters: {
          'user_count': userIds.length,
          'success': false,
          'error_code': error is RelationshipException ? error.code : 'unknown',
        },
          );
          
          // Log to crashlytics for debugging
          await _crashlytics.recordError(
        error,
        null,
        reason: 'Failed to setup user stream subscription',
        fatal: false,
          );
          
          throw error;
        });
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize user stream subscription: ${e.toString()}');
      
      // Log initialization errors
      _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to initialize user stream subscription',
        fatal: false,
      );
      
      return Stream.error(e);
    }
  }

  // ========== USER SEARCH OPERATIONS ==========

  /// Search for a user by their UID directly from the users collection
  /// Returns user data if found, null if not found
  /// Excludes email and isOnline fields, prevents self-search
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    try {
      _logger.d(_tag, 'Searching for user by UID: $uid');
      
      final result = await _relationshipService.searchUserByUid(uid);
      
      // Track analytics
      await _analytics.logEvent(
        name: 'user_search_by_uid',
        parameters: {
          'target_uid_hash': uid.hashCode.toString(),
          'success': result != null,
        },
      );
      
      if (result != null) {
        _logger.i(_tag, 'User found by UID: $uid, displayName: ${result['displayName']}');
      } else {
        _logger.d(_tag, 'User not found by UID: $uid');
      }
      
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to search user by UID: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'user_search_by_uid',
        parameters: {
          'target_uid_hash': uid.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to search user by UID',
        fatal: false,
      );
      
      rethrow;
    }
  }
}
