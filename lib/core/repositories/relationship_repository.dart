import '../services/relationship/relationship_service_interface.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/logger/logger_service.dart';
import '../services/service_locator.dart';
import '../exceptions/relationship_exceptions.dart';

/// Repository to handle relationship data operations
/// 
/// Provides a clean abstraction layer between the UI/business logic and the relationship service.
/// Follows the repository pattern to coordinate between services, handle error logging,
/// and provide analytics tracking for all relationship operations.
class RelationshipRepository {
  final RelationshipServiceInterface _relationshipService;
  final FirebaseAnalyticsService _analytics;
  final FirebaseCrashlyticsService _crashlytics;
  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'RELATIONSHIP_REPO';

  /// Creates a new RelationshipRepository
  RelationshipRepository({
    RelationshipServiceInterface? relationshipService,
    FirebaseAnalyticsService? analytics,
    FirebaseCrashlyticsService? crashlytics,
  }) : _relationshipService = relationshipService ?? serviceLocator<RelationshipServiceInterface>(),
       _analytics = analytics ?? serviceLocator<FirebaseAnalyticsService>(),
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>();

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
  Future<void> acceptFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Accepting friend request: $relationshipId');
      
      await _relationshipService.acceptFriendRequest(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_request_accepted',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend request accepted successfully: $relationshipId');
      
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

  /// Decline a pending friend request
  Future<void> declineFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Declining friend request: $relationshipId');
      
      await _relationshipService.declineFriendRequest(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_request_declined',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend request declined successfully: $relationshipId');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to decline friend request: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friend_request_declined',
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
        reason: 'Failed to decline friend request',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Cancel a sent friend request
  Future<void> cancelFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Cancelling friend request: $relationshipId');
      
      await _relationshipService.cancelFriendRequest(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_request_cancelled',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend request cancelled successfully: $relationshipId');
      
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
  Future<void> removeFriend(String relationshipId) async {
    try {
      _logger.d(_tag, 'Removing friend: $relationshipId');
      
      await _relationshipService.removeFriend(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friend_removed',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'Friend removed successfully: $relationshipId');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friend_removed',
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
        reason: 'Failed to remove friend',
        fatal: false,
      );
      
      rethrow;
    }
  }

  // ========== BLOCKING OPERATIONS ==========

  /// Block a user
  Future<void> blockUser(String relationshipId) async {
    try {
      _logger.d(_tag, 'Blocking user: $relationshipId');
      
      await _relationshipService.blockUser(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'user_blocked',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'User blocked successfully: $relationshipId');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to block user: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'user_blocked',
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
        reason: 'Failed to block user',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String relationshipId) async {
    try {
      _logger.d(_tag, 'Unblocking user: $relationshipId');
      
      await _relationshipService.unblockUser(relationshipId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'user_unblocked',
        parameters: {
          'relationship_id_hash': relationshipId.hashCode.toString(),
          'success': true,
        },
      );
      
      _logger.i(_tag, 'User unblocked successfully: $relationshipId');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to unblock user: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'user_unblocked',
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
        reason: 'Failed to unblock user',
        fatal: false,
      );
      
      rethrow;
    }
  }

  // ========== DATA RETRIEVAL OPERATIONS ==========

  /// Get all friends for a user with pagination
  Future<PaginatedRelationshipResult> getFriends(
    String userId, {
    int limit = 20,
    String? startAfter,
  }) async {
    try {
      _logger.d(_tag, 'Getting friends for user: $userId (limit: $limit)');
      
      final result = await _relationshipService.getFriends(
        userId,
        limit: limit,
        startAfter: startAfter,
      );
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'friends_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'count': result.relationships.length,
          'has_more': result.hasMore,
          'success': true,
        },
      );
      
      _logger.d(_tag, 'Friends loaded successfully: ${result.relationships.length} items');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to get friends: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'friends_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get friends',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Get pending friend requests (received by user) with pagination
  Future<PaginatedRelationshipResult> getPendingRequests(
    String userId, {
    int limit = 20,
    String? startAfter,
  }) async {
    try {
      _logger.d(_tag, 'Getting pending requests for user: $userId (limit: $limit)');
      
      final result = await _relationshipService.getPendingRequests(
        userId,
        limit: limit,
        startAfter: startAfter,
      );
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'pending_requests_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'count': result.relationships.length,
          'has_more': result.hasMore,
          'success': true,
        },
      );
      
      _logger.d(_tag, 'Pending requests loaded successfully: ${result.relationships.length} items');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to get pending requests: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'pending_requests_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get pending requests',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Get sent friend requests (sent by user) with pagination
  Future<PaginatedRelationshipResult> getSentRequests(
    String userId, {
    int limit = 20,
    String? startAfter,
  }) async {
    try {
      _logger.d(_tag, 'Getting sent requests for user: $userId (limit: $limit)');
      
      final result = await _relationshipService.getSentRequests(
        userId,
        limit: limit,
        startAfter: startAfter,
      );
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'sent_requests_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'count': result.relationships.length,
          'has_more': result.hasMore,
          'success': true,
        },
      );
      
      _logger.d(_tag, 'Sent requests loaded successfully: ${result.relationships.length} items');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to get sent requests: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'sent_requests_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get sent requests',
        fatal: false,
      );
      
      rethrow;
    }
  }

  /// Get blocked users with pagination
  Future<PaginatedRelationshipResult> getBlockedUsers(
    String userId, {
    int limit = 20,
    String? startAfter,
  }) async {
    try {
      _logger.d(_tag, 'Getting blocked users for user: $userId (limit: $limit)');
      
      final result = await _relationshipService.getBlockedUsers(
        userId,
        limit: limit,
        startAfter: startAfter,
      );
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'blocked_users_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'count': result.relationships.length,
          'has_more': result.hasMore,
          'success': true,
        },
      );
      
      _logger.d(_tag, 'Blocked users loaded successfully: ${result.relationships.length} items');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to get blocked users: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'blocked_users_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get blocked users',
        fatal: false,
      );
      
      rethrow;
    }
  }

  // ========== UTILITY OPERATIONS ==========

  /// Search for a user by UID to send friend request
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    try {
      _logger.d(_tag, 'Searching for user by UID: $uid');
      
      final result = await _relationshipService.searchUserByUid(uid);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'user_search_by_uid',
        parameters: {
          'search_uid_hash': uid.hashCode.toString(),
          'found': result != null,
          'success': true,
        },
      );
      
      _logger.d(_tag, 'User search completed: ${result != null ? 'found' : 'not found'}');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to search user by UID: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'user_search_by_uid',
        parameters: {
          'search_uid_hash': uid.hashCode.toString(),
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

  /// Get relationship summary (counts of different types)
  Future<Map<String, int>> getUserRelationshipsSummary(String userId) async {
    try {
      _logger.d(_tag, 'Getting relationships summary for user: $userId');
      
      final result = await _relationshipService.getUserRelationshipsSummary(userId);
      
      // Track success analytics
      await _analytics.logEvent(
        name: 'relationships_summary_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'friends_count': result['friends'] ?? 0,
          'pending_received_count': result['pending_received'] ?? 0,
          'pending_sent_count': result['pending_sent'] ?? 0,
          'blocked_count': result['blocked'] ?? 0,
          'success': true,
        },
      );
      
      _logger.d(_tag, 'Relationships summary loaded successfully');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to get relationships summary: ${e.toString()}');
      
      // Track failure analytics
      await _analytics.logEvent(
        name: 'relationships_summary_loaded',
        parameters: {
          'user_id_hash': userId.hashCode.toString(),
          'success': false,
          'error_code': e is RelationshipException ? e.code : 'unknown',
        },
      );
      
      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to get relationships summary',
        fatal: false,
      );
      
      rethrow;
    }
  }

  // ========== HELPER METHODS ==========

  /// Get user-friendly error message from RelationshipException
  String getErrorMessage(RelationshipException exception) {
    return RelationshipErrorMessages.getOperationSpecificMessage(exception);
  }

  /// Check if an error is a specific relationship error code
  bool isErrorOfType(dynamic error, String errorCode) {
    return error is RelationshipException && error.code == errorCode;
  }

  /// Check if user is not logged in error
  bool isNotLoggedInError(dynamic error) {
    return isErrorOfType(error, RelationshipErrorCodes.notLoggedIn);
  }

  /// Check if user not found error
  bool isUserNotFoundError(dynamic error) {
    return isErrorOfType(error, RelationshipErrorCodes.userNotFound);
  }

  /// Check if network error
  bool isNetworkError(dynamic error) {
    return isErrorOfType(error, RelationshipErrorCodes.networkError);
  }

  /// Check if already friends error
  bool isAlreadyFriendsError(dynamic error) {
    return isErrorOfType(error, RelationshipErrorCodes.alreadyFriends);
  }

  /// Check if request already sent error
  bool isRequestAlreadySentError(dynamic error) {
    return isErrorOfType(error, RelationshipErrorCodes.requestAlreadySent);
  }

  /// Check if blocked error
  bool isBlockedError(dynamic error) {
    return isErrorOfType(error, RelationshipErrorCodes.blocked) ||
           isErrorOfType(error, RelationshipErrorCodes.blockedByUser) ||
           isErrorOfType(error, RelationshipErrorCodes.blockedUser);
  }
}
