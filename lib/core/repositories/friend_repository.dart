import 'dart:async';

import 'package:flutter/foundation.dart';
import '../exceptions/friend_exceptions.dart';
import '../models/friend_relationship_model.dart';
import '../models/user_model.dart';
import '../services/friend/friend_service.dart';
import 'user_repository.dart';

/// Repository for handling friend operations with improved performance and error handling
class FriendRepository {
  final FriendService _friendService;
  final UserRepository _userRepository;
  
  /// Cache of friends for current user to improve performance
  Map<String, List<String>> _friendsCache = {};
  
  /// Cache expiration time for friends lists
  final Duration _cacheDuration = const Duration(minutes: 5);
  
  /// Cache of relationship objects for faster access to relationship data
  Map<String, FriendRelationshipModel> _relationshipCache = {};
  
  /// Timer for cache cleanup
  Timer? _cacheCleanupTimer;
  
  /// Map of cache timestamps
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Creates a new FriendRepository instance
  FriendRepository({
    required FriendService friendService,
    required UserRepository userRepository,
  }) : _friendService = friendService,
       _userRepository = userRepository {
    // Setup periodic cache cleanup
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _cleanupExpiredCache(),
    );
  }

  /// Clean up expired cache entries
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheDuration)
        .map((entry) => entry.key)
        .toList();
        
    for (final key in expiredKeys) {
      _friendsCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    // Also clean up relationship cache periodically
    if (_relationshipCache.length > 100) {
      _relationshipCache.clear();
    }
  }
  
  /// Invalidate cache for a specific user
  void invalidateCache(String userId) {
    _friendsCache.remove(userId);
    _cacheTimestamps.remove(userId);
    
    // Also invalidate current user's cache since relationships are bidirectional
    final currentUser = _userRepository.currentUser;
    if (currentUser != null) {
      _friendsCache.remove(currentUser.uid);
      _cacheTimestamps.remove(currentUser.uid);
    }
  }
  
  /// Get current user or throw appropriate exception
  Future<UserModel> _getCurrentUser() async {
    final currentUser = _userRepository.currentUser;
    if (currentUser == null) {
      throw FriendException(
        FriendErrorCodes.notLoggedIn, 
        'User must be logged in to perform this operation'
      );
    }
    return currentUser;
  }

  /// Sends a friend request to another user
  ///
  /// [receiverId] is the ID of the user to send the request to
  /// Returns the ID of the created friend request
  Future<String> sendFriendRequest(String receiverId) async {
    try {
      final currentUser = await _getCurrentUser();
      
      // Validate input
      if (receiverId.isEmpty) {
        throw FriendException(
          FriendErrorCodes.invalidReceiverId, 
          'Receiver ID cannot be empty'
        );
      }
      
      // Check if the user is trying to send a request to themselves
      if (currentUser.uid == receiverId) {
        throw FriendException(
          FriendErrorCodes.selfRequest, 
          'Cannot send a friend request to yourself'
        );
      }
      
      // Check if the user is trying to send a request to someone who blocked them
      final blockedByReceiver = await _friendService.isUserBlocked(receiverId, currentUser.uid);
      if (blockedByReceiver) {
        throw FriendException(
          FriendErrorCodes.blockedByReceiver, 
          'Cannot send friend request to this user'
        );
      }
      
      // Check if the user has blocked the receiver
      final blockedByMe = await _friendService.isUserBlocked(currentUser.uid, receiverId);
      if (blockedByMe) {
        throw FriendException(
          FriendErrorCodes.blockedBySender, 
          'You have blocked this user. Unblock them first to send a friend request.'
        );
      }
      
      // Check if they're already friends
      final alreadyFriends = await isFriendWith(receiverId);
      if (alreadyFriends) {
        throw FriendException(
          FriendErrorCodes.alreadyFriends, 
          'You are already friends with this user'
        );
      }

      // Send the friend request
      final requestId = await _friendService.sendFriendRequest(
        senderId: currentUser.uid,
        receiverId: receiverId,
      );
      
      // Invalidate cache since relationship has changed
      invalidateCache(currentUser.uid);
      invalidateCache(receiverId);

      return requestId;
    } catch (e) {
      debugPrint('Error in FriendRepository.sendFriendRequest: ${e.toString()}');
      
      // Rethrow FriendException if it's already our custom exception
      if (e is FriendException) {
        rethrow;
      }
      
      // Otherwise wrap the error in our custom exception
      throw FriendException(
        FriendErrorCodes.requestFailed, 
        'Failed to send friend request', 
        e
      );
    }
  }

  /// Get all pending friend relationships for the current user
  ///
  /// Returns a list of FriendRelationshipModel objects with pending status
  Future<List<FriendRelationshipModel>> getPendingRequests() async {
    try {
      // Get current user first
      final currentUser = await _getCurrentUser();
      final String uid = currentUser.uid;
      
      // Get pending relationships for the current user with the explicit userId
      final pendingRelationships = await _friendService.getPendingRelationships(uid);
      
      // Cache the relationships for faster access
      for (final relationship in pendingRelationships) {
        _relationshipCache[relationship.id] = relationship;
      }
      
      return pendingRelationships;
      
    } catch (e) {
      debugPrint('Error in FriendRepository.getPendingRequests: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get pending friend requests',
        e
      );
    }
  }
  
  /// Get pending friend requests specifically sent TO the current user (requests they can accept)
  ///
  /// Returns a list of FriendRelationshipModel objects where the current user is the receiver
  Future<List<FriendRelationshipModel>> getIncomingFriendRequests() async {
    try {
      final currentUser = await _getCurrentUser();
      
      // First get all pending relationships
      final allPending = await getPendingRequests();
      
      // Filter to only include relationships where the current user is the receiver
      final incomingRequests = allPending.where(
        (relationship) => _friendService.isRelationshipIncoming(relationship, currentUser.uid)
      ).toList();
      
      return incomingRequests;
    } catch (e) {
      debugPrint('Error in FriendRepository.getIncomingFriendRequests: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get incoming friend requests',
        e
      );
    }
  }
  
  /// Get pending friend requests sent BY the current user (requests they've sent)
  ///
  /// Returns a list of FriendRelationshipModel objects where the current user is the sender
  Future<List<FriendRelationshipModel>> getOutgoingFriendRequests() async {
    try {
      final currentUser = await _getCurrentUser();
      
      // First get all pending relationships
      final allPending = await getPendingRequests();
      
      // Filter to only include relationships where the current user is the sender
      final outgoingRequests = allPending.where(
        (relationship) => !_friendService.isRelationshipIncoming(relationship, currentUser.uid)
      ).toList();
      
      return outgoingRequests;
    } catch (e) {
      debugPrint('Error in FriendRepository.getOutgoingFriendRequests: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get outgoing friend requests',
        e
      );
    }
  }

  /// Get a specific relationship by ID
  ///
  /// [relationshipId] is the ID of the relationship to retrieve
  /// Returns the relationship if found, null otherwise
  Future<FriendRelationshipModel?> getRelationship(String relationshipId) async {
    try {
      // Check cache first
      if (_relationshipCache.containsKey(relationshipId)) {
        return _relationshipCache[relationshipId];
      }
      
      // Otherwise get from service
      final relationship = await _friendService.getRelationship(relationshipId);
      
      // Update cache if found
      if (relationship != null) {
        _relationshipCache[relationship.id] = relationship;
      }
      
      return relationship;
    } catch (e) {
      debugPrint('Error in FriendRepository.getRelationship: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get relationship',
        e
      );
    }
  }

  /// Accept a friend request
  ///
  /// [relationshipId] is the ID of the friend relationship to accept
  /// Returns true if the request was accepted successfully
  Future<bool> acceptFriendRequest(String relationshipId) async {
    try {
      final currentUser = await _getCurrentUser();

      // Verify that the request is to the current user
      final relationship = await getRelationship(relationshipId);
      if (relationship == null) {
        throw FriendException(
          FriendErrorCodes.requestNotFound,
          'Friend relationship not found'
        );
      }

      // Verify the current user is involved in the relationship
      if (relationship.user1Id != currentUser.uid && relationship.user2Id != currentUser.uid) {
        throw FriendException(
          FriendErrorCodes.invalidRequest,
          'Cannot accept a friend request that does not involve you'
        );
      }

      // Determine other user ID
      final otherUserId = relationship.user1Id == currentUser.uid
          ? relationship.user2Id
          : relationship.user1Id;

      // Accept the friend request
      final result = await _friendService.acceptFriendRequest(relationshipId);
      
      // Remove from cache and invalidate friends caches
      _relationshipCache.remove(relationshipId);
      invalidateCache(currentUser.uid);
      invalidateCache(otherUserId);
      
      return result;
    } catch (e) {
      debugPrint('Error in FriendRepository.acceptFriendRequest: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.acceptFailed,
        'Failed to accept friend request',
        e
      );
    }
  }

  /// Reject a friend request
  ///
  /// [relationshipId] is the ID of the friend relationship to reject
  /// Returns true if the request was rejected successfully
  Future<bool> rejectFriendRequest(String relationshipId) async {
    try {
      final currentUser = await _getCurrentUser();

      // Verify that the request is to the current user
      final relationship = await getRelationship(relationshipId);
      if (relationship == null) {
        throw FriendException(
          FriendErrorCodes.requestNotFound,
          'Friend relationship not found'
        );
      }

      // Verify the current user is involved in the relationship
      if (relationship.user1Id != currentUser.uid && relationship.user2Id != currentUser.uid) {
        throw FriendException(
          FriendErrorCodes.invalidRequest,
          'Cannot reject a friend request that does not involve you'
        );
      }

      // Reject the friend request
      final result = await _friendService.rejectFriendRequest(relationshipId);
      
      // Remove from cache
      _relationshipCache.remove(relationshipId);
      
      return result;
    } catch (e) {
      debugPrint('Error in FriendRepository.rejectFriendRequest: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.rejectFailed,
        'Failed to reject friend request',
        e
      );
    }
  }

  /// Get a list of the current user's friends with caching
  ///
  /// [forceRefresh] if true, will bypass cache and get fresh data
  /// Returns a list of friend user IDs
  Future<List<String>> getFriends({bool forceRefresh = false}) async {
    try {
      final currentUser = await _getCurrentUser();
      final userId = currentUser.uid;
      
      // If we have a valid cache and don't need to force refresh, use it
      if (!forceRefresh && 
          _friendsCache.containsKey(userId) && 
          _cacheTimestamps.containsKey(userId)) {
        final timestamp = _cacheTimestamps[userId]!;
        final now = DateTime.now();
        if (now.difference(timestamp) <= _cacheDuration) {
          return List<String>.from(_friendsCache[userId]!);
        }
      }

      // Otherwise get fresh data
      final friends = await _friendService.getUserFriends(userId);
      
      // Update cache
      _friendsCache[userId] = friends;
      _cacheTimestamps[userId] = DateTime.now();
      
      return friends;
    } catch (e) {
      debugPrint('Error in FriendRepository.getFriends: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.getFriendsFailed,
        'Failed to get friends',
        e
      );
    }
  }

  /// Get a list of friends for a specific user with caching
  ///
  /// [userId] is the ID of the user whose friends to get
  /// [forceRefresh] if true, will bypass cache and get fresh data
  /// Returns a list of friend user IDs
  Future<List<String>> getFriendsFor(String userId, {bool forceRefresh = false}) async {
    try {
      // If we have a valid cache and don't need to force refresh, use it
      if (!forceRefresh && 
          _friendsCache.containsKey(userId) && 
          _cacheTimestamps.containsKey(userId)) {
        final timestamp = _cacheTimestamps[userId]!;
        final now = DateTime.now();
        if (now.difference(timestamp) <= _cacheDuration) {
          return List<String>.from(_friendsCache[userId]!);
        }
      }
      
      // Otherwise get fresh data
      final friends = await _friendService.getUserFriends(userId);
      
      // Update cache
      _friendsCache[userId] = friends;
      _cacheTimestamps[userId] = DateTime.now();
      
      return friends;
    } catch (e) {
      debugPrint('Error in FriendRepository.getFriendsFor: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.getFriendsFailed,
        'Failed to get friends for specified user',
        e
      );
    }
  }

  /// Check if a user is friends with the current user
  ///
  /// [userId] is the ID of the user to check
  /// Returns true if the users are friends
  Future<bool> isFriendWith(String userId) async {
    try {
      final friends = await getFriends();
      return friends.contains(userId);
    } catch (e) {
      debugPrint('Error in FriendRepository.isFriendWith: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.notFriends,
        'Failed to check friendship status',
        e
      );
    }
  }
  
  /// Check if two users are friends with each other
  ///
  /// [user1Id] is the ID of the first user
  /// [user2Id] is the ID of the second user
  /// Returns true if the users are friends
  Future<bool> checkIfFriends(String user1Id, String user2Id) async {
    try {
      // Get friends list for user1, using cache if available
      final user1Friends = await getFriendsFor(user1Id);
      
      // Check if user2 is in user1's friend list
      return user1Friends.contains(user2Id);
    } catch (e) {
      debugPrint('Error in FriendRepository.checkIfFriends: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.notFriends,
        'Failed to check friendship status between users',
        e
      );
    }
  }
  
  /// Get user details for a list of user IDs with efficient batching
  ///
  /// [userIds] is the list of user IDs to get details for
  /// Returns a list of UserModel objects
  Future<List<UserModel>> getUsersDetails(List<String> userIds) async {
    try {
      if (userIds.isEmpty) {
        return [];
      }
      
      // Limit to batches of 10 for processing
      const batchSize = 10;
      List<UserModel> allUsers = [];
      
      // Process users in batches
      for (int i = 0; i < userIds.length; i += batchSize) {
        final end = (i + batchSize < userIds.length) ? i + batchSize : userIds.length;
        final batch = userIds.sublist(i, end);
        
        // Use Future.wait to fetch user data in parallel for this batch
        final userModels = await Future.wait(
          batch.map((uid) async {
            final userData = await _userRepository.getUserData(uid);
            return userData;
          }),
        );
        
        // Add valid user models to the result list
        for (final userModel in userModels) {
          if (userModel != null) {
            allUsers.add(userModel);
          }
        }
      }
      
      return allUsers;
    } catch (e) {
      debugPrint('Error in FriendRepository.getUsersDetails: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.userDetailsFailed,
        'Failed to get user details',
        e
      );
    }
  }

  /// Remove a friendship/unfriend a user
  ///
  /// [friendId] is the ID of the friend to remove
  /// Returns true if the friendship was removed successfully
  Future<bool> unfriend(String friendId) async {
    try {
      final currentUser = await _getCurrentUser();

      // Verify that the users are actually friends
      final isFriend = await isFriendWith(friendId);
      if (!isFriend) {
        throw FriendException(
          FriendErrorCodes.notFriends,
          'Cannot unfriend someone who is not a friend'
        );
      }

      // Remove the friendship
      final result = await _friendService.removeFriendship(currentUser.uid, friendId);
      
      // Invalidate cache for both users
      invalidateCache(currentUser.uid);
      invalidateCache(friendId);
      
      return result;
    } catch (e) {
      debugPrint('Error in FriendRepository.unfriend: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.unfriendFailed,
        'Failed to unfriend user',
        e
      );
    }
  }

  /// Block a user
  ///
  /// [userId] is the ID of the user to block
  /// Returns true if the user was blocked successfully
  Future<bool> blockUser(String userId) async {
    try {
      final currentUser = await _getCurrentUser();
      
      // Block the user
      final result = await _friendService.blockUser(currentUser.uid, userId);
      
      // Invalidate cache for both users since blocking affects friendship status
      invalidateCache(currentUser.uid);
      invalidateCache(userId);
      
      return result;
    } catch (e) {
      debugPrint('Error in FriendRepository.blockUser: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.blockFailed,
        'Failed to block user',
        e
      );
    }
  }

  /// Unblock a user
  ///
  /// [userId] is the ID of the user to unblock
  /// Returns true if the user was unblocked successfully
  Future<bool> unblockUser(String userId) async {
    try {
      final currentUser = await _getCurrentUser();

      // Unblock the user
      final result = await _friendService.unblockUser(currentUser.uid, userId);
      
      // Invalidate cache for current user
      invalidateCache(currentUser.uid);
      
      return result;
    } catch (e) {
      debugPrint('Error in FriendRepository.unblockUser: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.unblockFailed,
        'Failed to unblock user',
        e
      );
    }
  }

  /// Get list of users blocked by the current user with caching
  ///
  /// [forceRefresh] if true, will bypass cache and get fresh data
  /// Returns a list of blocked user IDs
  Future<List<String>> getBlockedUsers({bool forceRefresh = false}) async {
    try {
      final currentUser = await _getCurrentUser();
      final cacheKey = '${currentUser.uid}_blocked';
      
      // If we have a valid cache and don't need to force refresh, use it
      if (!forceRefresh && 
          _friendsCache.containsKey(cacheKey) && 
          _cacheTimestamps.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey]!;
        final now = DateTime.now();
        if (now.difference(timestamp) <= _cacheDuration) {
          return List<String>.from(_friendsCache[cacheKey]!);
        }
      }

      // Get blocked users
      final blockedUsers = await _friendService.getBlockedUsers(currentUser.uid);
      
      // Update cache
      _friendsCache[cacheKey] = blockedUsers;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      return blockedUsers;
    } catch (e) {
      debugPrint('Error in FriendRepository.getBlockedUsers: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get blocked users',
        e
      );
    }
  }

  /// Check if a user is blocked by the current user
  ///
  /// [userId] is the ID of the user to check
  /// Returns true if the user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUser = await _getCurrentUser();

      // Check if user is blocked
      return await _friendService.isUserBlocked(currentUser.uid, userId);
    } catch (e) {
      debugPrint('Error in FriendRepository.isUserBlocked: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to check if user is blocked',
        e
      );
    }
  }

  /// Check if a specific user is blocked by another user
  ///
  /// [blockerId] is the ID of the user who might have blocked
  /// [blockedId] is the ID of the user who might be blocked
  /// Returns true if blockedId is blocked by blockerId
  Future<bool> isUserBlockedBy(String blockerId, String blockedId) async {
    try {
      return await _friendService.isUserBlocked(blockerId, blockedId);
    } catch (e) {
      debugPrint('Error in FriendRepository.isUserBlockedBy: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to check if user is blocked',
        e
      );
    }
  }

  /// Get users who have blocked the current user
  ///
  /// This is useful to prevent showing users who have blocked the current user
  /// Returns a list of user IDs who have blocked the current user
  Future<List<String>> getUsersWhoBlockedMe() async {
    try {
      final currentUser = await _getCurrentUser();
      final cacheKey = '${currentUser.uid}_blockers';
      
      // If we have a recent cache, use it
      if (_friendsCache.containsKey(cacheKey) && 
          _cacheTimestamps.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey]!;
        final now = DateTime.now();
        if (now.difference(timestamp) <= _cacheDuration) {
          return List<String>.from(_friendsCache[cacheKey]!);
        }
      }
      
      // Get blockers
      final blockers = await _friendService.getUsersWhoBlocked(currentUser.uid);
      
      // Update cache
      _friendsCache[cacheKey] = blockers;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      return blockers;
    } catch (e) {
      debugPrint('Error in FriendRepository.getUsersWhoBlockedMe: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get users who blocked me',
        e
      );
    }
  }

  /// Filter a list of user IDs to remove blocked users and users who have blocked the current user
  ///
  /// This is useful when displaying search results or user lists
  /// [userIds] is the list of user IDs to filter
  /// Returns a filtered list of user IDs
  Future<List<String>> filterBlockedUsers(List<String> userIds) async {
    try {
      if (userIds.isEmpty) {
        return [];
      }
      
      // Get both blocked lists without needing current user directly
      final blockedByMe = await getBlockedUsers();
      final blockedMe = await getUsersWhoBlockedMe();
      
      // Filter out both types of blocked users
      final filteredIds = userIds.where((userId) {
        return !blockedByMe.contains(userId) && !blockedMe.contains(userId);
      }).toList();
      
      return filteredIds;
    } catch (e) {
      debugPrint('Error in FriendRepository.filterBlockedUsers: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to filter blocked users',
        e
      );
    }
  }
  
  /// Get relationship status between current user and another user
  ///
  /// [userId] is the ID of the other user
  /// Returns the [RelationshipStatus] between the users
  Future<RelationshipStatus> getRelationshipWith(String userId) async {
    try {
      final currentUser = await _getCurrentUser();
      
      // Directly get the relationship document, which is more efficient than multiple queries
      final relationship = await _friendService.getRelationshipBetweenUsers(currentUser.uid, userId);
      
      // If we found a relationship, return its status
      if (relationship != null) {
        return relationship.status;
      }
      
      // If no relationship document exists, return none
      return RelationshipStatus.none;
    } catch (e) {
      debugPrint('Error in FriendRepository.getRelationshipWith: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get relationship status',
        e
      );
    }
  }
  
  /// Get the full relationship model between the current user and another user
  ///
  /// [userId] is the ID of the other user
  /// Returns the complete [FriendRelationshipModel] or null if no relationship exists
  Future<FriendRelationshipModel?> getRelationshipModelWith(String userId) async {
    try {
      final currentUser = await _getCurrentUser();
      return await _friendService.getRelationshipBetweenUsers(currentUser.uid, userId);
    } catch (e) {
      debugPrint('Error in FriendRepository.getRelationshipModelWith: ${e.toString()}');
      
      if (e is FriendException) {
        rethrow;
      }
      
      throw FriendException(
        FriendErrorCodes.fetchFailed,
        'Failed to get relationship model',
        e
      );
    }
  }
  

  
  /// Dispose any resources used by the repository
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = null;
    _friendsCache.clear();
    _cacheTimestamps.clear();
    _relationshipCache.clear();
  }
}
