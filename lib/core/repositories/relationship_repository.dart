import '../services/relationship/relationship_service_interface.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/logger/logger_service.dart';
import '../services/service_locator.dart';
import '../services/database/local_database_service.dart';
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
  final LocalDatabaseService _localDb;

  static const String _tag = 'RELATIONSHIP_REPO';
  
  // Cache configuration - following UserRepository pattern
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  DateTime? _lastFriendsRefresh;
  DateTime? _lastRequestsRefresh;
  DateTime? _lastBlockedUsersRefresh;

  /// Creates a new RelationshipRepository
  RelationshipRepository({
    RelationshipServiceInterface? relationshipService,
    FirebaseAnalyticsService? analytics,
    FirebaseCrashlyticsService? crashlytics,
    LoggerService? logger,
    LocalDatabaseService? localDb,
  }) : _relationshipService = relationshipService ?? serviceLocator<RelationshipServiceInterface>(),
       _analytics = analytics ?? serviceLocator<FirebaseAnalyticsService>(),
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>(),
       _logger = logger ?? serviceLocator<LoggerService>(),
       _localDb = localDb ?? LocalDatabaseService.instance;

  // ========== FRIEND REQUEST OPERATIONS ==========

  /// Send a friend request to another user
  /// Returns the relationship ID if successful
  Future<String> sendFriendRequest(String targetUserId) async {
    try {
      _logger.d(_tag, 'Sending friend request to user: $targetUserId');
      
      final relationshipId = await _relationshipService.sendFriendRequest(targetUserId);
      
      // Invalidate requests cache after successful send
      _lastRequestsRefresh = null;
      
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
      
      // Invalidate friends and requests cache after successful accept
      _lastFriendsRefresh = null;
      _lastRequestsRefresh = null;
      
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
      
      // Invalidate requests cache after successful reject
      _lastRequestsRefresh = null;
      
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
      
      // Invalidate requests cache after successful cancel
      _lastRequestsRefresh = null;
      
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
      
      // Invalidate friends cache after successful removal
      _lastFriendsRefresh = null;
      
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
      
      // Invalidate blocked users and friends cache after successful block
      _lastBlockedUsersRefresh = null;
      _lastFriendsRefresh = null; // Block removes from friends if they were friends
      
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
      
      // Invalidate blocked users cache after successful unblock
      _lastBlockedUsersRefresh = null;
      
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
  /// Now with proper stream ordering to prevent race conditions
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    try {
      _logger.d(_tag, 'Getting friends stream for current user');
      
      // Use a stream controller to ensure proper ordering
      late StreamController<List<Map<String, dynamic>>> controller;
      StreamSubscription? subscription;
      
      controller = StreamController<List<Map<String, dynamic>>>(
        onCancel: () {
          subscription?.cancel();
        },
      );
      
      // Track the latest stream emission timestamp to prevent race conditions
      int latestEmissionTime = 0;
      
      subscription = _relationshipService.getFriendsStream().listen(
        (friends) async {
          final currentEmissionTime = DateTime.now().millisecondsSinceEpoch;
          latestEmissionTime = currentEmissionTime;
          
          try {
            // Ensure each friend has complete user data
            final enrichedFriends = <Map<String, dynamic>>[];
            
            for (final friend in friends) {
              // Check if this emission is still the latest (prevent race conditions)
              if (currentEmissionTime != latestEmissionTime) {
                _logger.d(_tag, 'Skipping stale stream emission');
                return;
              }
              
              final userId = friend['uid'] as String?;
              if (userId != null) {
                // Verify that essential user data is present
                if (friend['displayName'] == null || friend['displayName'] == '') {
                  _logger.w(_tag, 'Friend missing displayName for user: $userId, attempting to fetch');
                  
                  // Try to get user data from the service
                  try {
                    final userData = await _relationshipService.searchUserByUid(userId);
                    
                    // Double-check that this emission is still the latest
                    if (currentEmissionTime != latestEmissionTime) {
                      _logger.d(_tag, 'Skipping stale user data fetch');
                      return;
                    }
                    
                    if (userData != null) {
                      // Merge the complete user data
                      final enrichedFriend = Map<String, dynamic>.from(friend);
                      enrichedFriend.addAll(userData);
                      enrichedFriends.add(enrichedFriend);
                      _logger.i(_tag, 'Enriched friend with user data for: ${userData['displayName']}');
                    } else {
                      // Use original data even if incomplete
                      enrichedFriends.add(friend);
                      _logger.w(_tag, 'Could not fetch user data for: $userId');
                    }
                  } catch (e) {
                    // Use original data if fetch fails
                    enrichedFriends.add(friend);
                    _logger.e(_tag, 'Failed to fetch user data for $userId: $e');
                  }
                } else {
                  // User data is complete
                  enrichedFriends.add(friend);
                }
              } else {
                // No user ID, add as-is
                enrichedFriends.add(friend);
              }
            }
            
            // Final check that this emission is still the latest
            if (currentEmissionTime == latestEmissionTime) {
              // Track stream updates for analytics
              await _analytics.logEvent(
                name: 'friends_stream_updated',
                parameters: {
                  'count': enrichedFriends.length,
                  'success': true,
                },
              );
              
              _logger.d(_tag, 'Friends stream updated: ${enrichedFriends.length} friends');
              
              // Enhanced debugging - log friend UIDs
              for (int i = 0; i < enrichedFriends.length; i++) {
                final friend = enrichedFriends[i];
                _logger.d(_tag, 'Repository Friend $i: uid=${friend['uid']}, name=${friend['displayName']}');
              }
              
              controller.add(enrichedFriends);
            } else {
              _logger.d(_tag, 'Discarding stale stream result');
            }
          } catch (e) {
            _logger.e(_tag, 'Error processing friends stream: $e');
            controller.addError(e);
          }
        },
        onError: (error) async {
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
          
          controller.addError(error);
        },
      );
      
      return controller.stream;
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
  /// Now with proper stream ordering to prevent race conditions
  Stream<List<Map<String, dynamic>>> getPendingRequestsStream() {
    try {
      _logger.d(_tag, 'Getting pending requests stream for current user');
      
      // Use a stream controller to ensure proper ordering
      late StreamController<List<Map<String, dynamic>>> controller;
      StreamSubscription? subscription;
      
      controller = StreamController<List<Map<String, dynamic>>>(
        onCancel: () {
          subscription?.cancel();
        },
      );
      
      // Track the latest stream emission timestamp to prevent race conditions
      int latestEmissionTime = 0;
      
      subscription = _relationshipService.getPendingRequestsStream().listen(
        (requests) async {
          final currentEmissionTime = DateTime.now().millisecondsSinceEpoch;
          latestEmissionTime = currentEmissionTime;
          
          try {
            // Ensure each request has complete user data
            final enrichedRequests = <Map<String, dynamic>>[];
            
            for (final request in requests) {
              // Check if this emission is still the latest (prevent race conditions)
              if (currentEmissionTime != latestEmissionTime) {
                _logger.d(_tag, 'Skipping stale requests stream emission');
                return;
              }
              
              final userId = request['uid'] as String?;
              if (userId != null) {
                // Verify that essential user data is present
                if (request['displayName'] == null || request['displayName'] == '') {
                  _logger.w(_tag, 'Request missing displayName for user: $userId, attempting to fetch');
                  
                  // Try to get user data from the service
                  try {
                    final userData = await _relationshipService.searchUserByUid(userId);
                    
                    // Double-check that this emission is still the latest
                    if (currentEmissionTime != latestEmissionTime) {
                      _logger.d(_tag, 'Skipping stale user data fetch for requests');
                      return;
                    }
                    
                    if (userData != null) {
                      // Merge the complete user data
                      final enrichedRequest = Map<String, dynamic>.from(request);
                      enrichedRequest.addAll(userData);
                      enrichedRequests.add(enrichedRequest);
                      _logger.i(_tag, 'Enriched request with user data for: ${userData['displayName']}');
                    } else {
                      // Use original data even if incomplete
                      enrichedRequests.add(request);
                      _logger.w(_tag, 'Could not fetch user data for: $userId');
                    }
                  } catch (e) {
                    // Use original data if fetch fails
                    enrichedRequests.add(request);
                    _logger.e(_tag, 'Failed to fetch user data for $userId: $e');
                  }
                } else {
                  // User data is complete
                  enrichedRequests.add(request);
                }
              } else {
                // No user ID, add as-is
                enrichedRequests.add(request);
              }
            }
            
            // Final check that this emission is still the latest
            if (currentEmissionTime == latestEmissionTime) {
              // Track stream updates for analytics
              await _analytics.logEvent(
                name: 'pending_requests_stream_updated',
                parameters: {
                  'count': enrichedRequests.length,
                  'success': true,
                },
              );
              
              _logger.d(_tag, 'Pending requests stream updated: ${enrichedRequests.length} requests');
              
              // Enhanced debugging - log request details
              for (int i = 0; i < enrichedRequests.length; i++) {
                final request = enrichedRequests[i];
                _logger.d(_tag, 'Repository Request $i: uid=${request['uid']}, name=${request['displayName']}');
              }
              
              controller.add(enrichedRequests);
            } else {
              _logger.d(_tag, 'Discarding stale requests stream result');
            }
          } catch (e) {
            _logger.e(_tag, 'Error processing pending requests stream: $e');
            controller.addError(e);
          }
        },
        onError: (error) async {
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
          
          controller.addError(error);
        },
      );
      
      return controller.stream;
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
          // Ensure each blocked user has complete user data
          final enrichedBlockedUsers = <Map<String, dynamic>>[];
          
          for (final blockedUser in blockedUsers) {
            final userId = blockedUser['uid'] as String?;
            if (userId != null) {
              // Verify that essential user data is present
              if (blockedUser['displayName'] == null || blockedUser['displayName'] == '') {
                _logger.w(_tag, 'Blocked user missing displayName for user: $userId, attempting to fetch');
                
                // Try to get user data from the service
                try {
                  final userData = await _relationshipService.searchUserByUid(userId);
                  if (userData != null) {
                    // Merge the complete user data
                    final enrichedBlockedUser = Map<String, dynamic>.from(blockedUser);
                    enrichedBlockedUser.addAll(userData);
                    enrichedBlockedUsers.add(enrichedBlockedUser);
                    _logger.i(_tag, 'Enriched blocked user with user data for: ${userData['displayName']}');
                  } else {
                    // Use original data even if incomplete
                    enrichedBlockedUsers.add(blockedUser);
                    _logger.w(_tag, 'Could not fetch user data for: $userId');
                  }
                } catch (e) {
                  // Use original data if fetch fails
                  enrichedBlockedUsers.add(blockedUser);
                  _logger.e(_tag, 'Failed to fetch user data for $userId: $e');
                }
              } else {
                // User data is complete
                enrichedBlockedUsers.add(blockedUser);
              }
            } else {
              // No user ID, add as-is
              enrichedBlockedUsers.add(blockedUser);
            }
          }
          
          // Track stream updates for analytics
          await _analytics.logEvent(
            name: 'blocked_users_stream_updated',
            parameters: {
              'count': enrichedBlockedUsers.length,
              'success': true,
            },
          );
          
          _logger.d(_tag, 'Blocked users stream updated: ${enrichedBlockedUsers.length} blocked users');
          return enrichedBlockedUsers;
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

  // ========== CACHED DATA OPERATIONS ==========

  /// Get friends with smart caching - offline first approach
  /// Follows UserRepository caching pattern
  Future<List<Map<String, dynamic>>> getFriendsWithCaching({
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      _logger.d(_tag, 'Getting friends with caching for user: $userId');
      
      // Check if we should use cache
      final shouldUseCache = !forceRefresh && _isFriendsCacheValid();
      
      if (shouldUseCache) {
        // Load from cache first (offline-first approach)
        final cachedFriends = await _localDb.getCachedFriends(userId);
        if (cachedFriends.isNotEmpty) {
          _logger.d(_tag, 'Loaded ${cachedFriends.length} friends from cache');
          return cachedFriends;
        }
      }
      
      // Cache miss or force refresh - load from Firebase
      _logger.i(_tag, 'Loading friends from Firebase...');
      final friends = await getFriendsStream().first;
      
      // Update cache timestamp and cache the data
      _lastFriendsRefresh = DateTime.now();
      await _localDb.cacheFriends(userId, friends);
      
      _logger.i(_tag, 'Loaded and cached ${friends.length} friends from Firebase');
      return friends;
      
    } catch (e) {
      _logger.e(_tag, 'Error loading friends: $e');
      
      // Fallback to cache on error
      try {
        final cachedFriends = await _localDb.getCachedFriends(userId);
        if (cachedFriends.isNotEmpty) {
          _logger.w(_tag, 'Using cached friends due to load error');
          return cachedFriends;
        }
      } catch (cacheError) {
        _logger.e(_tag, 'Failed to load cached friends: $cacheError');
      }
      
      rethrow;
    }
  }

  /// Get pending requests with smart caching
  Future<List<Map<String, dynamic>>> getPendingRequestsWithCaching({
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      _logger.d(_tag, 'Getting requests with caching for user: $userId');
      
      // Check if we should use cache
      final shouldUseCache = !forceRefresh && _isRequestsCacheValid();
      
      if (shouldUseCache) {
        // Load from cache first
        final cachedRequests = await _localDb.getCachedPendingRequests(userId);
        if (cachedRequests.isNotEmpty) {
          _logger.d(_tag, 'Loaded ${cachedRequests.length} requests from cache');
          return cachedRequests;
        }
      }
      
      // Cache miss or force refresh - load from Firebase
      _logger.i(_tag, 'Loading requests from Firebase...');
      final requests = await getPendingRequestsStream().first;
      
      // Update cache timestamp and cache the data
      _lastRequestsRefresh = DateTime.now();
      await _localDb.cachePendingRequests(userId, requests);
      
      _logger.i(_tag, 'Loaded and cached ${requests.length} requests from Firebase');
      return requests;
      
    } catch (e) {
      _logger.e(_tag, 'Error loading requests: $e');
      
      // Fallback to cache on error
      try {
        final cachedRequests = await _localDb.getCachedPendingRequests(userId);
        if (cachedRequests.isNotEmpty) {
          _logger.w(_tag, 'Using cached requests due to load error');
          return cachedRequests;
        }
      } catch (cacheError) {
        _logger.e(_tag, 'Failed to load cached requests: $cacheError');
      }
      
      rethrow;
    }
  }

  /// Get blocked users with smart caching
  Future<List<Map<String, dynamic>>> getBlockedUsersWithCaching({
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      _logger.d(_tag, 'Getting blocked users with caching for user: $userId');
      
      // Check if we should use cache
      final shouldUseCache = !forceRefresh && _isBlockedUsersCacheValid();
      
      if (shouldUseCache) {
        // Load from cache first
        final cachedBlockedUsers = await _localDb.getCachedBlockedUsers(userId);
        if (cachedBlockedUsers.isNotEmpty) {
          _logger.d(_tag, 'Loaded ${cachedBlockedUsers.length} blocked users from cache');
          return cachedBlockedUsers;
        }
      }
      
      // Cache miss or force refresh - load from Firebase
      _logger.i(_tag, 'Loading blocked users from Firebase...');
      final blockedUsers = await getBlockedUsersStream().first;
      
      // Update cache timestamp and cache the data
      _lastBlockedUsersRefresh = DateTime.now();
      await _localDb.cacheBlockedUsers(userId, blockedUsers);
      
      _logger.i(_tag, 'Loaded and cached ${blockedUsers.length} blocked users from Firebase');
      return blockedUsers;
      
    } catch (e) {
      _logger.e(_tag, 'Error loading blocked users: $e');
      
      // Fallback to cache on error
      try {
        final cachedBlockedUsers = await _localDb.getCachedBlockedUsers(userId);
        if (cachedBlockedUsers.isNotEmpty) {
          _logger.w(_tag, 'Using cached blocked users due to load error');
          return cachedBlockedUsers;
        }
      } catch (cacheError) {
        _logger.e(_tag, 'Failed to load cached blocked users: $cacheError');
      }
      
      rethrow;
    }
  }

  /// Check if friends cache is still valid
  bool _isFriendsCacheValid() {
    if (_lastFriendsRefresh == null) return false;
    return DateTime.now().difference(_lastFriendsRefresh!) < _cacheValidDuration;
  }

  /// Check if requests cache is still valid
  bool _isRequestsCacheValid() {
    if (_lastRequestsRefresh == null) return false;
    return DateTime.now().difference(_lastRequestsRefresh!) < _cacheValidDuration;
  }

  /// Check if blocked users cache is still valid
  bool _isBlockedUsersCacheValid() {
    if (_lastBlockedUsersRefresh == null) return false;
    return DateTime.now().difference(_lastBlockedUsersRefresh!) < _cacheValidDuration;
  }

  /// Force refresh all cached data
  Future<void> refreshAllCachedData(String userId) async {
    _logger.d(_tag, 'Force refreshing all cached data...');
    await Future.wait([
      getFriendsWithCaching(userId: userId, forceRefresh: true),
      getPendingRequestsWithCaching(userId: userId, forceRefresh: true),
      getBlockedUsersWithCaching(userId: userId, forceRefresh: true),
    ]);
  }

  /// Clear all relationship cache for a user
  Future<void> clearUserCache(String userId) async {
    _logger.d(_tag, 'Clearing relationship cache for user: $userId');
    await _localDb.clearRelationshipCache(userId);
    // Reset cache timestamps
    _lastFriendsRefresh = null;
    _lastRequestsRefresh = null;
    _lastBlockedUsersRefresh = null;
  }

  /// Clear all relationship cache
  Future<void> clearAllCache() async {
    _logger.d(_tag, 'Clearing all relationship cache');
    await _localDb.clearAllRelationshipCache();
    // Reset cache timestamps
    _lastFriendsRefresh = null;
    _lastRequestsRefresh = null;
    _lastBlockedUsersRefresh = null;
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
