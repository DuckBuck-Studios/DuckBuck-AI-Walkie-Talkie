import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/friend_request_model.dart';
import '../firebase/firebase_database_service.dart';

/// Service for managing friend requests and friendships
class FriendService {
  final FirebaseDatabaseService _databaseService;
  
  /// Collection reference for friend requests
  static const String _friendRequestsCollection = 'friendRequests';
  
  /// Collection reference for user friendships
  static const String _friendshipsCollection = 'friendships';

  /// Collection reference for blocked users
  static const String _blockedUsersCollection = 'blockedUsers';

  /// Creates a new FriendService instance
  FriendService({required FirebaseDatabaseService databaseService}) 
    : _databaseService = databaseService;

  /// Send a friend request from one user to another
  /// 
  /// [senderId] is the ID of the user sending the request
  /// [receiverId] is the ID of the user receiving the request
  /// Returns the ID of the created friend request
  Future<String> sendFriendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      // Don't allow sending friend request to yourself
      if (senderId == receiverId) {
        throw Exception('Cannot send friend request to yourself');
      }
      
      // Check if either user has blocked the other
      final isReceiverBlockedBySender = await isUserBlocked(senderId, receiverId);
      if (isReceiverBlockedBySender) {
        throw Exception('Cannot send friend request to a user you have blocked');
      }
      
      final isSenderBlockedByReceiver = await isUserBlocked(receiverId, senderId);
      if (isSenderBlockedByReceiver) {
        throw Exception('This user has blocked you');
      }
      
      // Check if a pending or accepted request already exists between these users
      final existingRequests = await _databaseService.queryDocuments(
        collection: _friendRequestsCollection,
        conditions: [
          {'field': 'senderId', 'operator': '==', 'value': senderId},
          {'field': 'receiverId', 'operator': '==', 'value': receiverId},
          {'field': 'status', 'operator': 'in', 'value': ['pending', 'accepted']},
        ],
      );

      // Also check the reverse direction (if receiver has already sent a request to sender)
      final reverseRequests = await _databaseService.queryDocuments(
        collection: _friendRequestsCollection,
        conditions: [
          {'field': 'senderId', 'operator': '==', 'value': receiverId},
          {'field': 'receiverId', 'operator': '==', 'value': senderId},
          {'field': 'status', 'operator': 'in', 'value': ['pending', 'accepted']},
        ],
      );

      // If a request already exists, throw an exception
      if (existingRequests.isNotEmpty || reverseRequests.isNotEmpty) {
        throw Exception('A friend request already exists between these users');
      }

      // Create the friend request data
      final requestData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'status': FriendRequestStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add the document and return its ID
      final requestId = await _databaseService.addDocument(
        collection: _friendRequestsCollection,
        data: requestData,
      );

      debugPrint('Friend request sent successfully: $requestId');
      return requestId;
      
    } catch (e) {
      debugPrint('Error sending friend request: ${e.toString()}');
      throw Exception('Failed to send friend request: ${e.toString()}');
    }
  }

  /// Get a specific friend request by its ID
  ///
  /// [requestId] is the ID of the friend request
  /// Returns the friend request model if found, null otherwise
  Future<FriendRequestModel?> getFriendRequest(String requestId) async {
    try {
      final docData = await _databaseService.getDocument(
        collection: _friendRequestsCollection,
        documentId: requestId,
      );

      if (docData == null) {
        return null;
      }

      return FriendRequestModel.fromMap(docData, requestId);
    } catch (e) {
      debugPrint('Error getting friend request: ${e.toString()}');
      throw Exception('Failed to get friend request: ${e.toString()}');
    }
  }

  /// Get pending friend requests sent to a user
  ///
  /// [userId] is the ID of the user receiving the requests
  /// Returns a list of friend request models
  Future<List<FriendRequestModel>> getPendingRequestsForUser(String userId) async {
    try {
      final pendingRequests = await _databaseService.queryDocuments(
        collection: _friendRequestsCollection,
        conditions: [
          {'field': 'receiverId', 'operator': '==', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': FriendRequestStatus.pending.name},
        ],
        orderBy: 'createdAt',
        descending: true,
      );

      return pendingRequests
          .map((doc) => FriendRequestModel.fromMap(doc, doc['id']))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending friend requests: ${e.toString()}');
      throw Exception('Failed to get pending friend requests: ${e.toString()}');
    }
  }

  /// Accept a friend request
  ///
  /// [requestId] is the ID of the friend request to accept
  /// Returns true if the request was accepted successfully
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      // Get the friend request
      final request = await getFriendRequest(requestId);
      if (request == null) {
        throw Exception('Friend request not found');
      }

      // Check if the request is pending
      if (request.status != FriendRequestStatus.pending) {
        throw Exception('Friend request is not pending');
      }
      
      // Check if either user has blocked the other since the request was sent
      final isSenderBlockedByReceiver = await isUserBlocked(request.receiverId, request.senderId);
      if (isSenderBlockedByReceiver) {
        // Auto-reject the request instead of accepting it
        await _databaseService.updateDocument(
          collection: _friendRequestsCollection,
          documentId: requestId,
          data: {
            'status': FriendRequestStatus.rejected.name,
            'updatedAt': FieldValue.serverTimestamp(),
            'rejectionReason': 'blocked',
          },
        );
        debugPrint('Friend request auto-rejected due to blocking: $requestId');
        throw Exception('Cannot accept a request from a blocked user');
      }
      
      final isReceiverBlockedBySender = await isUserBlocked(request.senderId, request.receiverId);
      if (isReceiverBlockedBySender) {
        // Auto-reject the request
        await _databaseService.updateDocument(
          collection: _friendRequestsCollection,
          documentId: requestId,
          data: {
            'status': FriendRequestStatus.rejected.name,
            'updatedAt': FieldValue.serverTimestamp(),
            'rejectionReason': 'blocked',
          },
        );
        debugPrint('Friend request auto-rejected due to being blocked by sender: $requestId');
        throw Exception('This user has blocked you');
      }

      // Update the request status to accepted
      await _databaseService.updateDocument(
        collection: _friendRequestsCollection,
        documentId: requestId,
        data: {
          'status': FriendRequestStatus.accepted.name,
        },
      );

      // Create friendship entries for both users
      await _createFriendshipEntry(request.senderId, request.receiverId);

      debugPrint('Friend request accepted successfully: $requestId');
      return true;
    } catch (e) {
      debugPrint('Error accepting friend request: ${e.toString()}');
      throw Exception('Failed to accept friend request: ${e.toString()}');
    }
  }

  /// Reject a friend request
  ///
  /// [requestId] is the ID of the friend request to reject
  /// Returns true if the request was rejected successfully
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      // Get the friend request
      final request = await getFriendRequest(requestId);
      if (request == null) {
        throw Exception('Friend request not found');
      }

      // Check if the request is pending
      if (request.status != FriendRequestStatus.pending) {
        throw Exception('Friend request is not pending');
      }

      // Update the request status to rejected
      await _databaseService.updateDocument(
        collection: _friendRequestsCollection,
        documentId: requestId,
        data: {
          'status': FriendRequestStatus.rejected.name,
        },
      );

      debugPrint('Friend request rejected successfully: $requestId');
      return true;
    } catch (e) {
      debugPrint('Error rejecting friend request: ${e.toString()}');
      throw Exception('Failed to reject friend request: ${e.toString()}');
    }
  }

  /// Get a list of a user's friends
  ///
  /// [userId] is the ID of the user whose friends to retrieve
  /// Returns a list of friend user IDs
  Future<List<String>> getUserFriends(String userId) async {
    try {
      final friendships = await _databaseService.getDocument(
        collection: _friendshipsCollection,
        documentId: userId,
      );

      if (friendships == null || !friendships.containsKey('friends')) {
        return [];
      }

      return List<String>.from(friendships['friends']);
    } catch (e) {
      debugPrint('Error getting user friends: ${e.toString()}');
      throw Exception('Failed to get user friends: ${e.toString()}');
    }
  }

  /// Create friendship entries for both users
  ///
  /// This creates or updates documents in the friendships collection to establish
  /// a bidirectional friendship connection between two users
  ///
  /// [user1Id] is the ID of the first user
  /// [user2Id] is the ID of the second user
  Future<void> _createFriendshipEntry(String user1Id, String user2Id) async {
    try {
      // Use a transaction to ensure both friendship entries are created atomically
      await _databaseService.runTransaction<void>((transaction) async {
        // Get the current friends list for user1
        final user1Doc = await transaction.get(
          _databaseService.firestoreInstance
              .collection(_friendshipsCollection)
              .doc(user1Id),
        );

        // Get the current friends list for user2
        final user2Doc = await transaction.get(
          _databaseService.firestoreInstance
              .collection(_friendshipsCollection)
              .doc(user2Id),
        );

        // Update user1's friends list
        final List<String> user1Friends = user1Doc.exists && user1Doc.data()!.containsKey('friends')
            ? List<String>.from(user1Doc.data()!['friends'])
            : [];

        if (!user1Friends.contains(user2Id)) {
          user1Friends.add(user2Id);
          transaction.set(
            _databaseService.firestoreInstance
                .collection(_friendshipsCollection)
                .doc(user1Id),
            {'friends': user1Friends},
            SetOptions(merge: true),
          );
        }

        // Update user2's friends list
        final List<String> user2Friends = user2Doc.exists && user2Doc.data()!.containsKey('friends')
            ? List<String>.from(user2Doc.data()!['friends'])
            : [];

        if (!user2Friends.contains(user1Id)) {
          user2Friends.add(user1Id);
          transaction.set(
            _databaseService.firestoreInstance
                .collection(_friendshipsCollection)
                .doc(user2Id),
            {'friends': user2Friends},
            SetOptions(merge: true),
          );
        }

        return;
      });

      debugPrint('Friendship created successfully between $user1Id and $user2Id');
    } catch (e) {
      debugPrint('Error creating friendship: ${e.toString()}');
      throw Exception('Failed to create friendship: ${e.toString()}');
    }
  }

  /// Remove a friendship between two users
  ///
  /// [user1Id] is the ID of the first user
  /// [user2Id] is the ID of the second user
  /// Returns true if the friendship was removed successfully
  Future<bool> removeFriendship(String user1Id, String user2Id) async {
    try {
      // Use a transaction to ensure both friendship entries are removed atomically
      await _databaseService.runTransaction<void>((transaction) async {
        // Get the current friends list for user1
        final user1Doc = await transaction.get(
          _databaseService.firestoreInstance
              .collection(_friendshipsCollection)
              .doc(user1Id),
        );

        // Get the current friends list for user2
        final user2Doc = await transaction.get(
          _databaseService.firestoreInstance
              .collection(_friendshipsCollection)
              .doc(user2Id),
        );

        // Update user1's friends list
        if (user1Doc.exists && user1Doc.data()!.containsKey('friends')) {
          final List<String> user1Friends = List<String>.from(user1Doc.data()!['friends']);
          user1Friends.remove(user2Id);
          transaction.set(
            _databaseService.firestoreInstance
                .collection(_friendshipsCollection)
                .doc(user1Id),
            {'friends': user1Friends},
            SetOptions(merge: true),
          );
        }

        // Update user2's friends list
        if (user2Doc.exists && user2Doc.data()!.containsKey('friends')) {
          final List<String> user2Friends = List<String>.from(user2Doc.data()!['friends']);
          user2Friends.remove(user1Id);
          transaction.set(
            _databaseService.firestoreInstance
                .collection(_friendshipsCollection)
                .doc(user2Id),
            {'friends': user2Friends},
            SetOptions(merge: true),
          );
        }

        return;
      });

      debugPrint('Friendship removed successfully between $user1Id and $user2Id');
      return true;
    } catch (e) {
      debugPrint('Error removing friendship: ${e.toString()}');
      throw Exception('Failed to remove friendship: ${e.toString()}');
    }
  }

  /// Block a user
  ///
  /// [blockerId] is the ID of the user doing the blocking
  /// [blockedId] is the ID of the user being blocked
  /// Returns true if the user was blocked successfully
  Future<bool> blockUser(String blockerId, String blockedId) async {
    try {
      // Don't allow blocking yourself
      if (blockerId == blockedId) {
        throw Exception('Cannot block yourself');
      }

      // Remove any existing friendship
      final areFriends = await _checkIfFriends(blockerId, blockedId);
      if (areFriends) {
        await removeFriendship(blockerId, blockedId);
      }

      // Cancel any pending friend requests between the users
      await _cancelPendingFriendRequests(blockerId, blockedId);

      // Add to blocked users collection
      await _databaseService.setDocument(
        collection: _blockedUsersCollection,
        documentId: blockerId,
        data: {
          'blockedUsers': FieldValue.arrayUnion([blockedId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );

      debugPrint('User $blockedId blocked successfully by $blockerId');
      return true;
    } catch (e) {
      debugPrint('Error blocking user: ${e.toString()}');
      throw Exception('Failed to block user: ${e.toString()}');
    }
  }

  /// Unblock a user
  ///
  /// [blockerId] is the ID of the user who did the blocking
  /// [blockedId] is the ID of the user who was blocked
  /// Returns true if the user was unblocked successfully
  Future<bool> unblockUser(String blockerId, String blockedId) async {
    try {
      await _databaseService.setDocument(
        collection: _blockedUsersCollection,
        documentId: blockerId,
        data: {
          'blockedUsers': FieldValue.arrayRemove([blockedId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );

      debugPrint('User $blockedId unblocked successfully by $blockerId');
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: ${e.toString()}');
      throw Exception('Failed to unblock user: ${e.toString()}');
    }
  }

  /// Get list of users blocked by a user
  ///
  /// [userId] is the ID of the user whose blocked list to retrieve
  /// Returns a list of blocked user IDs
  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final blockedData = await _databaseService.getDocument(
        collection: _blockedUsersCollection,
        documentId: userId,
      );

      if (blockedData == null || !blockedData.containsKey('blockedUsers')) {
        return [];
      }

      return List<String>.from(blockedData['blockedUsers']);
    } catch (e) {
      debugPrint('Error getting blocked users: ${e.toString()}');
      throw Exception('Failed to get blocked users: ${e.toString()}');
    }
  }

  /// Check if a user is blocked
  ///
  /// [blockerId] is the ID of the user who might have blocked
  /// [potentiallyBlockedId] is the ID of the user who might be blocked
  /// Returns true if the user is blocked
  Future<bool> isUserBlocked(String blockerId, String potentiallyBlockedId) async {
    try {
      final blockedUsers = await getBlockedUsers(blockerId);
      return blockedUsers.contains(potentiallyBlockedId);
    } catch (e) {
      debugPrint('Error checking if user is blocked: ${e.toString()}');
      throw Exception('Failed to check if user is blocked: ${e.toString()}');
    }
  }

  /// Get users who have blocked a specific user
  ///
  /// [userId] is the ID of the user to find blockers for
  /// Returns a list of user IDs who have blocked the specified user
  Future<List<String>> getUsersWhoBlocked(String userId) async {
    try {
      // Query the blockedUsers collection to find documents where the userId is in the blockedUsers array
      final blockedByDocs = await _databaseService.queryDocuments(
        collection: _blockedUsersCollection,
        field: 'blockedUsers',
        arrayContains: userId,
      );

      // Extract the user IDs from the documents
      return blockedByDocs.map((doc) => doc['id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting users who blocked user: ${e.toString()}');
      throw Exception('Failed to get users who blocked user: ${e.toString()}');
    }
  }

  /// Helper method to check if two users are friends
  Future<bool> _checkIfFriends(String user1Id, String user2Id) async {
    final user1Friends = await getUserFriends(user1Id);
    return user1Friends.contains(user2Id);
  }

  /// Helper method to cancel any pending friend requests between two users
  Future<void> _cancelPendingFriendRequests(String user1Id, String user2Id) async {
    try {
      // Find requests from user1 to user2
      final requestsFromUser1 = await _databaseService.queryDocuments(
        collection: _friendRequestsCollection,
        conditions: [
          {'field': 'status', 'operator': '==', 'value': FriendRequestStatus.pending.name},
          {'field': 'senderId', 'operator': '==', 'value': user1Id},
          {'field': 'receiverId', 'operator': '==', 'value': user2Id},
        ],
      );

      // Find requests from user2 to user1
      final requestsFromUser2 = await _databaseService.queryDocuments(
        collection: _friendRequestsCollection,
        conditions: [
          {'field': 'status', 'operator': '==', 'value': FriendRequestStatus.pending.name},
          {'field': 'senderId', 'operator': '==', 'value': user2Id},
          {'field': 'receiverId', 'operator': '==', 'value': user1Id},
        ],
      );
      
      // Combine the lists
      final pendingRequests = [...requestsFromUser1, ...requestsFromUser2];

      // Cancel all pending requests
      for (final doc in pendingRequests) {
        await _databaseService.updateDocument(
          collection: _friendRequestsCollection,
          documentId: doc['id'],
          data: {
            'status': 'canceled',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    } catch (e) {
      debugPrint('Error canceling pending friend requests: ${e.toString()}');
      // Don't throw - this is a secondary operation
    }
  }
}
