import '../services/relationship/relationship_service_interface.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/logger/logger_service.dart';
import '../services/service_locator.dart';
import '../services/database/local_database_service.dart';
import '../exceptions/relationship_exceptions.dart';
import '../services/auth/auth_service_interface.dart';
import 'dart:async';

/// Repository to handle relationship data operations
/// 
/// Provides a clean abstraction layer between the UI/business logic and the relationship service.
/// Follows the repository pattern to coordinate between services, handle error logging,
/// and provide analytics tracking for all relationship operations.
/// 
/// Features:
/// - Real-time streams for friends, pending requests, and blocked users (15 items paginated)
/// - Comprehensive analytics tracking for all operations
/// - Error handling with Crashlytics integration
/// - Transaction-safe relationship operations
class RelationshipRepository {
  final RelationshipServiceInterface _relationshipService;
  final FirebaseAnalyticsService _analytics;
  final FirebaseCrashlyticsService _crashlytics;
  final LoggerService _logger;
  final LocalDatabaseService _localDb;
  final AuthServiceInterface _authService;

  static const String _tag = 'RELATIONSHIP_REPO';

  /// Creates a new RelationshipRepository
  RelationshipRepository({
    RelationshipServiceInterface? relationshipService,
    FirebaseAnalyticsService? analytics,
    FirebaseCrashlyticsService? crashlytics,
    LoggerService? logger,
    AuthServiceInterface? authService,
    LocalDatabaseService? localDb,
  }) : _relationshipService = relationshipService ?? serviceLocator<RelationshipServiceInterface>(),
       _analytics = analytics ?? serviceLocator<FirebaseAnalyticsService>(),
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>(),
       _logger = logger ?? serviceLocator<LoggerService>(),
       _localDb = localDb ?? LocalDatabaseService.instance,
       _authService = authService ?? serviceLocator<AuthServiceInterface>();

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
      
      // Note: No need to force refresh caches here - the real-time streams will
      // automatically update when the Firestore document status changes from 'pending' to 'accepted'
      _logger.d(_tag, 'Friend request accepted - real-time streams will handle UI updates');
      
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
      
      // Note: No need to force refresh caches here - the real-time streams will
      // automatically update when the Firestore document status changes from 'pending' to 'declined'
      _logger.d(_tag, 'Friend request rejected - real-time streams will handle UI updates');
      
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

  // ========== FRIENDSHIP MANAGEMENT ==========

  /// Remove an existing friend
  /// Returns true if successful
  Future<bool> removeFriend(String targetUserId) async {
    try {
      _logger.d(_tag, 'Removing friend: $targetUserId');
      
      final result = await _relationshipService.removeFriend(targetUserId);
      
      // Note: No need to force refresh caches here - the real-time streams will
      // automatically update when the Firestore relationship document is deleted
      _logger.d(_tag, 'Friend removed - real-time streams will handle UI updates');
      
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
  /// Implements local caching for better performance
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    try {
      final currentUserId = _getCurrentUserId();
      _logger.d(_tag, 'Getting friends stream with caching for current user');
      
      return _relationshipService.getFriendsStream()
        .asyncMap((friends) async {
          try {
            // Cache the friends data to local database
            await _localDb.cacheFriends(currentUserId, friends);
            
            // Track stream updates for analytics
            await _analytics.logEvent(
              name: 'friends_stream_updated',
              parameters: {
                'count': friends.length,
                'success': true,
                'cached': true,
              },
            );
            
            _logger.d(_tag, 'Friends stream updated and cached: ${friends.length} friends');
            return friends;
          } catch (cacheError) {
            _logger.w(_tag, 'Failed to cache friends data: $cacheError');
            // Continue with original data even if caching fails
            await _analytics.logEvent(
              name: 'friends_stream_updated',
              parameters: {
                'count': friends.length,
                'success': true,
                'cached': false,
              },
            );
            return friends;
          }
        })
        .handleError((error) async {
          _logger.e(_tag, 'Error in friends stream: $error');
          
          try {
            // Fallback to cached data if stream fails
            final cachedFriends = await _localDb.getCachedFriends(currentUserId);
            if (cachedFriends.isNotEmpty) {
              _logger.i(_tag, 'Falling back to cached friends data: ${cachedFriends.length} friends');
              return cachedFriends;
            }
          } catch (cacheError) {
            _logger.w(_tag, 'Failed to get cached friends: $cacheError');
          }
          
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
            reason: 'Failed to stream friends list',
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
  /// Implements local caching for better performance
  Stream<List<Map<String, dynamic>>> getPendingRequestsStream() {
    try {
      final currentUserId = _getCurrentUserId();
      _logger.d(_tag, 'Getting pending requests stream with caching for current user');
      
      return _relationshipService.getPendingRequestsStream()
        .asyncMap((requests) async {
          try {
            // Cache the pending requests data to local database
            await _localDb.cachePendingRequests(currentUserId, requests);
            
            // Track stream updates for analytics
            await _analytics.logEvent(
              name: 'pending_requests_stream_updated',
              parameters: {
                'count': requests.length,
                'success': true,
                'cached': true,
              },
            );
            
            _logger.d(_tag, 'Pending requests stream updated and cached: ${requests.length} requests');
            return requests;
          } catch (cacheError) {
            _logger.w(_tag, 'Failed to cache pending requests data: $cacheError');
            // Continue with original data even if caching fails
            await _analytics.logEvent(
              name: 'pending_requests_stream_updated',
              parameters: {
                'count': requests.length,
                'success': true,
                'cached': false,
              },
            );
            return requests;
          }
        })
        .handleError((error) async {
          _logger.e(_tag, 'Error in pending requests stream: $error');
          
          try {
            // Fallback to cached data if stream fails
            final cachedRequests = await _localDb.getCachedPendingRequests(currentUserId);
            if (cachedRequests.isNotEmpty) {
              _logger.i(_tag, 'Falling back to cached pending requests data: ${cachedRequests.length} requests');
              return cachedRequests;
            }
          } catch (cacheError) {
            _logger.w(_tag, 'Failed to get cached pending requests: $cacheError');
          }
          
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
  /// Implements local caching for better performance
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream() {
    try {
      final currentUserId = _getCurrentUserId();
      _logger.d(_tag, 'Getting blocked users stream with caching for current user');
      
      return _relationshipService.getBlockedUsersStream()
        .asyncMap((blockedUsers) async {
          try {
            // Cache the blocked users data to local database
            await _localDb.cacheBlockedUsers(currentUserId, blockedUsers);
            
            // Track stream updates for analytics
            await _analytics.logEvent(
              name: 'blocked_users_stream_updated',
              parameters: {
                'count': blockedUsers.length,
                'success': true,
                'cached': true,
              },
            );
            
            _logger.d(_tag, 'Blocked users stream updated and cached: ${blockedUsers.length} blocked');
            return blockedUsers;
          } catch (cacheError) {
            _logger.w(_tag, 'Failed to cache blocked users data: $cacheError');
            // Continue with original data even if caching fails
            await _analytics.logEvent(
              name: 'blocked_users_stream_updated',
              parameters: {
                'count': blockedUsers.length,
                'success': true,
                'cached': false,
              },
            );
            return blockedUsers;
          }
        })
        .handleError((error) async {
          _logger.e(_tag, 'Error in blocked users stream: $error');
          
          try {
            // Fallback to cached data if stream fails
            final cachedBlockedUsers = await _localDb.getCachedBlockedUsers(currentUserId);
            if (cachedBlockedUsers.isNotEmpty) {
              _logger.i(_tag, 'Falling back to cached blocked users data: ${cachedBlockedUsers.length} blocked');
              return cachedBlockedUsers;
            }
          } catch (cacheError) {
            _logger.w(_tag, 'Failed to get cached blocked users: $cacheError');
          }
          
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
  }

  // ========== UTILITY METHODS ==========



  /// Get the current user ID
  /// Throws RelationshipException if not authenticated
  String _getCurrentUserId() {
    final user = _authService.currentUser;
    if (user == null) {
      throw RelationshipException(
        RelationshipErrorCodes.notLoggedIn,
        'User must be authenticated to perform relationship operations',
      );
    }
    return user.uid;
  }

  /// Clear relationship cache for current user
  /// Useful when user signs out or wants to refresh data
  Future<void> clearCurrentUserRelationshipCache() async {
    try {
      final currentUserId = _getCurrentUserId();
      await _localDb.clearRelationshipCache(currentUserId);
      _logger.i(_tag, 'Cleared relationship cache for current user: $currentUserId');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear relationship cache: ${e.toString()}');
      rethrow;
    }
  }

  /// Get cached friends without stream (for offline access)
  Future<List<Map<String, dynamic>>> getCachedFriends() async {
    try {
      final currentUserId = _getCurrentUserId();
      final cachedFriends = await _localDb.getCachedFriends(currentUserId);
      _logger.d(_tag, 'Retrieved ${cachedFriends.length} cached friends');
      return cachedFriends;
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached friends: ${e.toString()}');
      return [];
    }
  }

  /// Get cached pending requests without stream (for offline access)
  Future<List<Map<String, dynamic>>> getCachedPendingRequests() async {
    try {
      final currentUserId = _getCurrentUserId();
      final cachedRequests = await _localDb.getCachedPendingRequests(currentUserId);
      _logger.d(_tag, 'Retrieved ${cachedRequests.length} cached pending requests');
      return cachedRequests;
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached pending requests: ${e.toString()}');
      return [];
    }
  }

  /// Get cached blocked users without stream (for offline access)
  Future<List<Map<String, dynamic>>> getCachedBlockedUsers() async {
    try {
      final currentUserId = _getCurrentUserId();
      final cachedBlockedUsers = await _localDb.getCachedBlockedUsers(currentUserId);
      _logger.d(_tag, 'Retrieved ${cachedBlockedUsers.length} cached blocked users');
      return cachedBlockedUsers;
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached blocked users: ${e.toString()}');
      return [];
    }
  }

  /// Force refresh all relationship caches by fetching fresh data from Firebase
  /// This is useful when app resumes or user manually refreshes
  /// Returns true if refresh was successful
  Future<bool> forceRefreshAllCaches() async {
    try {
      final currentUserId = _getCurrentUserId();
      _logger.i(_tag, 'Force refreshing all relationship caches for user: $currentUserId');

      // Get fresh data from each stream (this will automatically update caches)
      final futures = <Future>[];

      // Refresh friends cache
      futures.add(
        _relationshipService.getFriendsStream().first.then((friends) {
          _localDb.cacheFriends(currentUserId, friends);
          _logger.d(_tag, 'Force refreshed friends cache: ${friends.length} friends');
        }).catchError((e) {
          _logger.w(_tag, 'Failed to force refresh friends cache: $e');
        })
      );

      // Refresh pending requests cache
      futures.add(
        _relationshipService.getPendingRequestsStream().first.then((requests) {
          _localDb.cachePendingRequests(currentUserId, requests);
          _logger.d(_tag, 'Force refreshed pending requests cache: ${requests.length} requests');
        }).catchError((e) {
          _logger.w(_tag, 'Failed to force refresh pending requests cache: $e');
        })
      );

      // Refresh blocked users cache
      futures.add(
        _relationshipService.getBlockedUsersStream().first.then((blockedUsers) {
          _localDb.cacheBlockedUsers(currentUserId, blockedUsers);
          _logger.d(_tag, 'Force refreshed blocked users cache: ${blockedUsers.length} blocked');
        }).catchError((e) {
          _logger.w(_tag, 'Failed to force refresh blocked users cache: $e');
        })
      );

      // Wait for all refreshes to complete (with timeout)
      await Future.wait(futures).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          _logger.w(_tag, 'Cache refresh timed out after 10 seconds');
          throw TimeoutException('Cache refresh timeout', Duration(seconds: 10));
        },
      );

      // Update cache refresh timestamp
      await _updateCacheRefreshTimestamp();

      // Track successful refresh
      await _analytics.logEvent(
        name: 'relationship_cache_force_refresh',
        parameters: {
          'success': true,
          'user_id_hash': currentUserId.hashCode.toString(),
        },
      );

      _logger.i(_tag, 'Successfully force refreshed all relationship caches');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to force refresh relationship caches: ${e.toString()}');

      // Track failed refresh
      await _analytics.logEvent(
        name: 'relationship_cache_force_refresh',
        parameters: {
          'success': false,
          'error': e.toString(),
        },
      );

      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to force refresh relationship caches',
        fatal: false,
      );

      return false;
    }
  }

  /// Check if relationship cache is stale and needs refresh
  /// Returns true if cache is older than the specified duration
  Future<bool> isCacheStale({Duration maxAge = const Duration(minutes: 5)}) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      // Check if we have any cached data
      final cachedFriends = await _localDb.getCachedFriends(currentUserId);
      final cachedRequests = await _localDb.getCachedPendingRequests(currentUserId);
      final cachedBlocked = await _localDb.getCachedBlockedUsers(currentUserId);

      // If no cached data exists, consider it stale
      if (cachedFriends.isEmpty && cachedRequests.isEmpty && cachedBlocked.isEmpty) {
        _logger.d(_tag, 'No cached relationship data found - cache is stale');
        return true;
      }

      // For simplicity, we'll use a timestamp stored in app settings
      // This could be enhanced to check individual cache timestamps
      final lastRefreshKey = 'relationship_cache_last_refresh_$currentUserId';
      final lastRefreshString = await _localDb.getSetting(lastRefreshKey);
      
      if (lastRefreshString == null) {
        _logger.d(_tag, 'No cache timestamp found - cache is stale');
        return true;
      }

      final lastRefresh = DateTime.fromMillisecondsSinceEpoch(int.parse(lastRefreshString));
      final age = DateTime.now().difference(lastRefresh);
      final isStale = age > maxAge;

      _logger.d(_tag, 'Cache age: ${age.inMinutes} minutes, max age: ${maxAge.inMinutes} minutes, is stale: $isStale');
      return isStale;

    } catch (e) {
      _logger.e(_tag, 'Error checking cache staleness: ${e.toString()}');
      return true; // Consider stale on error to be safe
    }
  }

  /// Update the cache refresh timestamp
  Future<void> _updateCacheRefreshTimestamp() async {
    try {
      final currentUserId = _getCurrentUserId();
      final timestampKey = 'relationship_cache_last_refresh_$currentUserId';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      await _localDb.setSetting(timestampKey, timestamp);
      _logger.d(_tag, 'Updated cache refresh timestamp');
    } catch (e) {
      _logger.w(_tag, 'Failed to update cache refresh timestamp: ${e.toString()}');
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
