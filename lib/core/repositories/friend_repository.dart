import 'package:duckbuck/core/models/user_model.dart';
import 'package:flutter/foundation.dart';

import '../models/friend_request_model.dart';
import '../services/friend/friend_service.dart';
import 'user_repository.dart';

/// Repository for handling friend request operations
class FriendRepository {
  final FriendService _friendService;
  final UserRepository _userRepository;

  /// Creates a new FriendRepository instance
  FriendRepository({
    required FriendService friendService,
    required UserRepository userRepository,
  })  : _friendService = friendService,
        _userRepository = userRepository;

  /// Sends a friend request to another user
  ///
  /// [receiverId] is the ID of the user to send the request to
  /// Returns the ID of the created friend request
  Future<String> sendFriendRequest(String receiverId) async {
    try {
      // Get current user ID
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to send a friend request');
      }
      
      // Check if the user is trying to send a request to someone who blocked them
      final blockedByReceiver = await _friendService.isUserBlocked(receiverId, currentUser.uid);
      if (blockedByReceiver) {
        throw Exception('Cannot send friend request to this user');
      }
      
      // Check if the user has blocked the receiver
      final blockedByMe = await _friendService.isUserBlocked(currentUser.uid, receiverId);
      if (blockedByMe) {
        throw Exception('You have blocked this user. Unblock them first to send a friend request.');
      }
      
      // Check if they're already friends
      final alreadyFriends = await isFriendWith(receiverId);
      if (alreadyFriends) {
        throw Exception('You are already friends with this user');
      }

      // Send the friend request
      final requestId = await _friendService.sendFriendRequest(
        senderId: currentUser.uid,
        receiverId: receiverId,
      );

      return requestId;
    } catch (e) {
      debugPrint('Error in FriendRepository.sendFriendRequest: ${e.toString()}');
      throw Exception('Failed to send friend request: ${e.toString()}');
    }
  }

  /// Get all pending friend requests for the current user
  ///
  /// Returns a list of FriendRequestModel objects
  Future<List<FriendRequestModel>> getPendingRequests() async {
    try {
      // Get current user ID
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to get friend requests');
      }

      // Get pending requests for the user
      return await _friendService.getPendingRequestsForUser(currentUser.uid);
    } catch (e) {
      debugPrint('Error in FriendRepository.getPendingRequests: ${e.toString()}');
      throw Exception('Failed to get pending friend requests: ${e.toString()}');
    }
  }

  /// Accept a friend request
  ///
  /// [requestId] is the ID of the friend request to accept
  /// Returns true if the request was accepted successfully
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      // Get current user ID
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to accept a friend request');
      }

      // Verify that the request is to the current user
      final request = await _friendService.getFriendRequest(requestId);
      if (request == null) {
        throw Exception('Friend request not found');
      }

      if (request.receiverId != currentUser.uid) {
        throw Exception('Cannot accept a friend request that was not sent to you');
      }

      // Accept the friend request
      return await _friendService.acceptFriendRequest(requestId);
    } catch (e) {
      debugPrint('Error in FriendRepository.acceptFriendRequest: ${e.toString()}');
      throw Exception('Failed to accept friend request: ${e.toString()}');
    }
  }

  /// Reject a friend request
  ///
  /// [requestId] is the ID of the friend request to reject
  /// Returns true if the request was rejected successfully
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      // Get current user ID
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to reject a friend request');
      }

      // Verify that the request is to the current user
      final request = await _friendService.getFriendRequest(requestId);
      if (request == null) {
        throw Exception('Friend request not found');
      }

      if (request.receiverId != currentUser.uid) {
        throw Exception('Cannot reject a friend request that was not sent to you');
      }

      // Reject the friend request
      return await _friendService.rejectFriendRequest(requestId);
    } catch (e) {
      debugPrint('Error in FriendRepository.rejectFriendRequest: ${e.toString()}');
      throw Exception('Failed to reject friend request: ${e.toString()}');
    }
  }

  /// Get a list of the current user's friends
  ///
  /// Returns a list of friend user IDs
  Future<List<String>> getFriends() async {
    try {
      // Get current user ID
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to get friends');
      }

      // Get the user's friends
      return await _friendService.getUserFriends(currentUser.uid);
    } catch (e) {
      debugPrint('Error in FriendRepository.getFriends: ${e.toString()}');
      throw Exception('Failed to get friends: ${e.toString()}');
    }
  }

  /// Get a list of friends for a specific user
  ///
  /// [userId] is the ID of the user whose friends to get
  /// Returns a list of friend user IDs
  Future<List<String>> getFriendsFor(String userId) async {
    try {
      // Get the user's friends
      return await _friendService.getUserFriends(userId);
    } catch (e) {
      debugPrint('Error in FriendRepository.getFriendsFor: ${e.toString()}');
      throw Exception('Failed to get friends: ${e.toString()}');
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
      throw Exception('Failed to check friendship status: ${e.toString()}');
    }
  }
  
  /// Check if two users are friends with each other
  ///
  /// [user1Id] is the ID of the first user
  /// [user2Id] is the ID of the second user
  /// Returns true if the users are friends
  Future<bool> checkIfFriends(String user1Id, String user2Id) async {
    try {
      // Get friends list for user 1
      final user1Friends = await _friendService.getUserFriends(user1Id);
      
      // Check if user2 is in user1's friend list
      return user1Friends.contains(user2Id);
    } catch (e) {
      debugPrint('Error in FriendRepository.checkIfFriends: ${e.toString()}');
      throw Exception('Failed to check friendship status: ${e.toString()}');
    }
  }
  
  /// Get user details for a list of user IDs
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
      throw Exception('Failed to get user details: ${e.toString()}');
    }
  }

  /// Remove a friendship/unfriend a user
  ///
  /// [friendId] is the ID of the friend to remove
  /// Returns true if the friendship was removed successfully
  Future<bool> unfriend(String friendId) async {
    try {
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to unfriend someone');
      }

      // Verify that the users are actually friends
      final isFriend = await isFriendWith(friendId);
      if (!isFriend) {
        throw Exception('Cannot unfriend someone who is not a friend');
      }

      // Remove the friendship
      return await _friendService.removeFriendship(currentUser.uid, friendId);
    } catch (e) {
      debugPrint('Error in FriendRepository.unfriend: ${e.toString()}');
      throw Exception('Failed to unfriend user: ${e.toString()}');
    }
  }

  /// Block a user
  ///
  /// [userId] is the ID of the user to block
  /// Returns true if the user was blocked successfully
  Future<bool> blockUser(String userId) async {
    try {
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to block someone');
      }

      // Block the user
      return await _friendService.blockUser(currentUser.uid, userId);
    } catch (e) {
      debugPrint('Error in FriendRepository.blockUser: ${e.toString()}');
      throw Exception('Failed to block user: ${e.toString()}');
    }
  }

  /// Unblock a user
  ///
  /// [userId] is the ID of the user to unblock
  /// Returns true if the user was unblocked successfully
  Future<bool> unblockUser(String userId) async {
    try {
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to unblock someone');
      }

      // Unblock the user
      return await _friendService.unblockUser(currentUser.uid, userId);
    } catch (e) {
      debugPrint('Error in FriendRepository.unblockUser: ${e.toString()}');
      throw Exception('Failed to unblock user: ${e.toString()}');
    }
  }

  /// Get list of users blocked by the current user
  ///
  /// Returns a list of blocked user IDs
  Future<List<String>> getBlockedUsers() async {
    try {
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to get blocked users');
      }

      // Get blocked users
      return await _friendService.getBlockedUsers(currentUser.uid);
    } catch (e) {
      debugPrint('Error in FriendRepository.getBlockedUsers: ${e.toString()}');
      throw Exception('Failed to get blocked users: ${e.toString()}');
    }
  }

  /// Check if a user is blocked by the current user
  ///
  /// [userId] is the ID of the user to check
  /// Returns true if the user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to check if a user is blocked');
      }

      // Check if user is blocked
      return await _friendService.isUserBlocked(currentUser.uid, userId);
    } catch (e) {
      debugPrint('Error in FriendRepository.isUserBlocked: ${e.toString()}');
      throw Exception('Failed to check if user is blocked: ${e.toString()}');
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
      throw Exception('Failed to check if user is blocked: ${e.toString()}');
    }
  }

  /// Get users who have blocked the current user
  ///
  /// This is useful to prevent showing users who have blocked the current user
  /// Returns a list of user IDs who have blocked the current user
  Future<List<String>> getUsersWhoBlockedMe() async {
    try {
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to get users who blocked them');
      }

      return await _friendService.getUsersWhoBlocked(currentUser.uid);
    } catch (e) {
      debugPrint('Error in FriendRepository.getUsersWhoBlockedMe: ${e.toString()}');
      throw Exception('Failed to get users who blocked me: ${e.toString()}');
    }
  }

  /// Filter a list of user IDs to remove blocked users and users who have blocked the current user
  ///
  /// This is useful when displaying search results or user lists
  /// [userIds] is the list of user IDs to filter
  /// Returns a filtered list of user IDs
  Future<List<String>> filterBlockedUsers(List<String> userIds) async {
    try {
      final currentUser = _userRepository.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to filter users');
      }
      
      // Get users that the current user has blocked
      final blockedByMe = await _friendService.getBlockedUsers(currentUser.uid);
      
      // Get users that have blocked the current user
      final blockedMe = await _friendService.getUsersWhoBlocked(currentUser.uid);
      
      // Filter out both types of blocked users
      final filteredIds = userIds.where((userId) {
        return !blockedByMe.contains(userId) && !blockedMe.contains(userId);
      }).toList();
      
      return filteredIds;
    } catch (e) {
      debugPrint('Error in FriendRepository.filterBlockedUsers: ${e.toString()}');
      throw Exception('Failed to filter blocked users: ${e.toString()}');
    }
  }
}
