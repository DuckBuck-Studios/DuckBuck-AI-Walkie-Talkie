import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/friend_relationship_model.dart';
import '../firebase/firebase_database_service.dart';

/// Service for managing friend relationships
class FriendService {
  final FirebaseDatabaseService _databaseService;
  
  /// Collection reference for friend relationships
  static const String _relationshipsCollection = 'relationships';
  
  /// For backward compatibility
  static const String _friendshipsCollection = 'friendships';
  static const String _blockedUsersCollection = 'blockedUsers';

  /// Creates a new FriendService instance
  FriendService({required FirebaseDatabaseService databaseService}) 
    : _databaseService = databaseService;

  /// Generate a unique, deterministic document ID for a relationship between two users
  /// This ensures that the same two users always get the same relationship document
  String _generateRelationshipId(String userId1, String userId2) {
    // Consistently order the user IDs to ensure a unique relationship ID
    final List<String> orderedIds = [userId1, userId2]..sort();
    return '${orderedIds[0]}_${orderedIds[1]}';
  }
  
  /// Get or create a relationship document between two users
  Future<FriendRelationshipModel> _getOrCreateRelationship(
    String userId1, 
    String userId2
  ) async {
    // Order user IDs consistently
    final List<String> orderedIds = [userId1, userId2]..sort();
    final String relationshipId = _generateRelationshipId(userId1, userId2);
    
    // Try to get existing relationship
    final relationshipData = await _databaseService.getDocument(
      collection: _relationshipsCollection,
      documentId: relationshipId,
    );
    
    // If relationship exists, return it
    if (relationshipData != null) {
      return FriendRelationshipModel.fromMap(relationshipData, relationshipId);
    }
    
    // Otherwise create a new relationship
    final now = DateTime.now();
    final relationshipModel = FriendRelationshipModel(
      id: relationshipId,
      user1Id: orderedIds[0],
      user2Id: orderedIds[1],
      status: RelationshipStatus.none,
      direction: RelationshipDirection.mutual,
      createdAt: now,
      updatedAt: now,
      history: [],
    );
    
    // Save new relationship to database
    await _databaseService.setDocument(
      collection: _relationshipsCollection,
      documentId: relationshipId,
      data: {
        'user1Id': orderedIds[0],
        'user2Id': orderedIds[1],
        'status': RelationshipStatus.none.name,
        'direction': RelationshipDirection.mutual.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'history': [],
      },
    );
    
    return relationshipModel;
  }

  /// Send a friend request from one user to another
  /// 
  /// [senderId] is the ID of the user sending the request
  /// [receiverId] is the ID of the user receiving the request
  /// Returns the ID of the relationship document
  Future<String> sendFriendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      // Don't allow sending friend request to yourself
      if (senderId == receiverId) {
        throw Exception('Cannot send friend request to yourself');
      }
      
      // Get or create relationship document
      final relationship = await _getOrCreateRelationship(senderId, receiverId);
      
      // Check current relationship status
      if (relationship.status == RelationshipStatus.blocked) {
        // Check who is blocked
        if (relationship.blockedUserId == senderId) {
          throw Exception('You have been blocked by this user');
        } else if (relationship.blockedUserId == receiverId) {
          throw Exception('You cannot send a request to a user you have blocked');
        }
      } else if (relationship.status == RelationshipStatus.friends) {
        throw Exception('You are already friends with this user');
      } else if (relationship.status == RelationshipStatus.pending) {
        // Check if there's already a pending request in the other direction
        if ((relationship.direction == RelationshipDirection.fromFirst && relationship.user1Id == receiverId) ||
            (relationship.direction == RelationshipDirection.fromSecond && relationship.user2Id == receiverId)) {
          // The receiver has already sent a request to the sender
          // Let's accept it instead of sending a new request
          await acceptFriendRequestInternal(relationship.id, senderId);
          return relationship.id;
        } else {
          throw Exception('A friend request already exists between these users');
        }
      }

      // Determine which user is user1 and which is user2
      final direction = relationship.user1Id == senderId 
          ? RelationshipDirection.fromFirst 
          : RelationshipDirection.fromSecond;
      
      // Update relationship to pending
      await _databaseService.updateDocument(
        collection: _relationshipsCollection,
        documentId: relationship.id,
        data: {
          'status': RelationshipStatus.pending.name,
          'direction': direction.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([{
            'previousStatus': relationship.status.name,
            'newStatus': RelationshipStatus.pending.name,
            'timestamp': FieldValue.serverTimestamp(),
            'actionByUserId': senderId,
            'note': 'Friend request sent'
          }])
        },
      );

      debugPrint('Friend request sent successfully: ${relationship.id}');
      return relationship.id;
    } catch (e) {
      debugPrint('Error sending friend request: ${e.toString()}');
      throw Exception('Failed to send friend request: ${e.toString()}');
    }
  }
  
  /// Internal method to accept a friend request
  /// Used by sendFriendRequest when there's a pending request in the opposite direction
  Future<void> acceptFriendRequestInternal(String relationshipId, String acceptorId) async {
    try {
      // Get the relationship
      final relationshipData = await _databaseService.getDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
      );
      
      if (relationshipData == null) {
        throw Exception('Relationship not found');
      }
      
      final relationship = FriendRelationshipModel.fromMap(relationshipData, relationshipId);
      
      // Ensure we're in the pending state
      if (relationship.status != RelationshipStatus.pending) {
        throw Exception('No pending friend request to accept');
      }
      
      // Update the relationship to friends
      await _databaseService.updateDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
        data: {
          'status': RelationshipStatus.friends.name,
          'direction': RelationshipDirection.mutual.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([{
            'previousStatus': RelationshipStatus.pending.name,
            'newStatus': RelationshipStatus.friends.name,
            'timestamp': FieldValue.serverTimestamp(),
            'actionByUserId': acceptorId,
            'note': 'Friend request accepted'
          }])
        },
      );
      
      debugPrint('Friend request accepted successfully: $relationshipId');
    } catch (e) {
      debugPrint('Error accepting friend request: ${e.toString()}');
      throw Exception('Failed to accept friend request: ${e.toString()}');
    }
  }

  /// Get a specific relationship by its ID
  ///
  /// [relationshipId] is the ID of the relationship document
  /// Returns the relationship model if found, null otherwise
  Future<FriendRelationshipModel?> getRelationship(String relationshipId) async {
    try {
      final docData = await _databaseService.getDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
      );

      if (docData == null) {
        return null;
      }

      return FriendRelationshipModel.fromMap(docData, relationshipId);
    } catch (e) {
      debugPrint('Error getting relationship: ${e.toString()}');
      throw Exception('Failed to get relationship: ${e.toString()}');
    }
  }
  
  /// Get the relationship between two users
  ///
  /// [user1Id] is the ID of the first user
  /// [user2Id] is the ID of the second user
  /// Returns the relationship model if found, null if no relationship exists
  Future<FriendRelationshipModel?> getRelationshipBetweenUsers(
    String user1Id,
    String user2Id
  ) async {
    try {
      final relationshipId = _generateRelationshipId(user1Id, user2Id);
      return await getRelationship(relationshipId);
    } catch (e) {
      debugPrint('Error getting relationship between users: ${e.toString()}');
      throw Exception('Failed to get relationship between users: ${e.toString()}');
    }
  }
  
  // Using the existing getRelationship method instead

  /// Get pending friend relationships for a user
  ///
  /// [userId] is the ID of the user 
  /// Returns a list of relationship models with pending status involving the user
  Future<List<FriendRelationshipModel>> getPendingRelationships(String userId) async {
    try {
      final List<FriendRelationshipModel> pendingRelationshipModels = [];
      
      // Query relationships where this user is involved and status is pending
      final pendingRelationships = await _databaseService.queryDocuments(
        collection: _relationshipsCollection,
        conditions: [
          {
            'field': 'status', 
            'operator': '==', 
            'value': RelationshipStatus.pending.name
          },
          {
            'field': 'user1Id',
            'operator': '==',
            'value': userId,
            'orConditions': [
              {
                'field': 'user2Id',
                'operator': '==',
                'value': userId
              }
            ]
          }
        ],
      );
      
      // Convert to relationship models
      for (final doc in pendingRelationships) {
        final relationship = FriendRelationshipModel.fromMap(doc, doc['id']);
        pendingRelationshipModels.add(relationship);
      }
      
      // Sort by updated time, most recent first
      pendingRelationshipModels.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return pendingRelationshipModels;
    } catch (e) {
      debugPrint('Error getting pending relationships: ${e.toString()}');
      throw Exception('Failed to get pending relationships: ${e.toString()}');
    }
  }
  
  /// Check if a relationship is incoming (sent to) the specified user
  bool isRelationshipIncoming(FriendRelationshipModel relationship, String userId) {
    return (relationship.user1Id == userId && 
            relationship.direction == RelationshipDirection.fromSecond) ||
           (relationship.user2Id == userId && 
            relationship.direction == RelationshipDirection.fromFirst);
  }
  
  /// Get the sender ID from a relationship based on its direction
  String getSenderId(FriendRelationshipModel relationship) {
    return relationship.direction == RelationshipDirection.fromFirst
        ? relationship.user1Id
        : relationship.user2Id;
  }
  
  /// Get the receiver ID from a relationship based on its direction
  String getReceiverId(FriendRelationshipModel relationship) {
    return relationship.direction == RelationshipDirection.fromFirst
        ? relationship.user2Id
        : relationship.user1Id;
  }

  /// Accept a friend request
  ///
  /// [relationshipId] is the ID of the relationship document with the pending request
  /// Returns true if the request was accepted successfully
  Future<bool> acceptFriendRequest(String relationshipId) async {
    try {
      // Get the relationship
      final relationship = await getRelationship(relationshipId);
      if (relationship == null) {
        throw Exception('Relationship not found');
      }

      // Check if the relationship has a pending request
      if (relationship.status != RelationshipStatus.pending) {
        throw Exception('No pending friend request to accept');
      }
      
      // Determine who's the receiver based on the direction
      String receiverId, senderId;
      if (relationship.direction == RelationshipDirection.fromFirst) {
        senderId = relationship.user1Id;
        receiverId = relationship.user2Id;
      } else {
        senderId = relationship.user2Id;
        receiverId = relationship.user1Id;
      }
      
      // Check if either user has blocked the other since the request was sent
      final isUserBlocked = await checkIfUsersBlocked(senderId, receiverId);
      if (isUserBlocked) {
        // Auto-reject the request
        await _databaseService.updateDocument(
          collection: _relationshipsCollection,
          documentId: relationshipId,
          data: {
            'status': RelationshipStatus.none.name,
            'updatedAt': FieldValue.serverTimestamp(),
            'history': FieldValue.arrayUnion([{
              'previousStatus': RelationshipStatus.pending.name,
              'newStatus': RelationshipStatus.none.name,
              'timestamp': FieldValue.serverTimestamp(),
              'actionByUserId': receiverId,
              'note': 'Friend request auto-rejected due to blocking'
            }])
          },
        );
        debugPrint('Friend request auto-rejected due to blocking: $relationshipId');
        throw Exception('Cannot accept a request due to blocking between users');
      }

      // Update the relationship status to friends
      await _databaseService.updateDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
        data: {
          'status': RelationshipStatus.friends.name,
          'direction': RelationshipDirection.mutual.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([{
            'previousStatus': RelationshipStatus.pending.name,
            'newStatus': RelationshipStatus.friends.name,
            'timestamp': FieldValue.serverTimestamp(),
            'actionByUserId': receiverId,
            'note': 'Friend request accepted'
          }])
        },
      );

      debugPrint('Friend request accepted successfully: $relationshipId');
      return true;
    } catch (e) {
      debugPrint('Error accepting friend request: ${e.toString()}');
      throw Exception('Failed to accept friend request: ${e.toString()}');
    }
  }

  /// Reject a friend request
  ///
  /// [relationshipId] is the ID of the relationship document with the pending request
  /// Returns true if the request was rejected successfully
  Future<bool> rejectFriendRequest(String relationshipId) async {
    try {
      // Get the relationship
      final relationship = await getRelationship(relationshipId);
      if (relationship == null) {
        throw Exception('Relationship not found');
      }

      // Check if the relationship has a pending request
      if (relationship.status != RelationshipStatus.pending) {
        throw Exception('No pending friend request to reject');
      }
      
      // Determine who's the receiver based on the direction
      String receiverId;
      if (relationship.direction == RelationshipDirection.fromFirst) {
        receiverId = relationship.user2Id;
      } else {
        receiverId = relationship.user1Id;
      }

      // Update the relationship status back to none
      await _databaseService.updateDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
        data: {
          'status': RelationshipStatus.none.name,
          'direction': RelationshipDirection.mutual.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([{
            'previousStatus': RelationshipStatus.pending.name,
            'newStatus': RelationshipStatus.none.name,
            'timestamp': FieldValue.serverTimestamp(),
            'actionByUserId': receiverId,
            'note': 'Friend request rejected'
          }])
        },
      );

      debugPrint('Friend request rejected successfully: $relationshipId');
      return true;
    } catch (e) {
      debugPrint('Error rejecting friend request: ${e.toString()}');
      throw Exception('Failed to reject friend request: ${e.toString()}');
    }
  }
  
  /// Helper method to check if either user has blocked the other
  Future<bool> checkIfUsersBlocked(String user1Id, String user2Id) async {
    try {
      // Get the relationship between these users
      final relationship = await getRelationshipBetweenUsers(user1Id, user2Id);
      
      // If no relationship or not in blocked state, they're not blocked
      if (relationship == null || relationship.status != RelationshipStatus.blocked) {
        return false;
      }
      
      // They have a blocking relationship
      return true;
    } catch (e) {
      debugPrint('Error checking if users blocked: ${e.toString()}');
      // Default to false if there's an error
      return false;
    }
  }

  /// Get a list of a user's friends
  ///
  /// [userId] is the ID of the user whose friends to retrieve
  /// Returns a list of friend user IDs
  Future<List<String>> getUserFriends(String userId) async {
    try {
      final List<String> friendsList = [];
      
      // Query all relationships where this user is involved and they're friends
      final friendsQuery = await _databaseService.queryDocuments(
        collection: _relationshipsCollection,
        conditions: [
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.friends.name},
        ],
      );
      
      // Filter to find relationships involving this user
      for (final doc in friendsQuery) {
        final relationship = FriendRelationshipModel.fromMap(doc, doc['id']);
        
        // If user is part of this relationship, add the other user to friends list
        if (relationship.user1Id == userId) {
          friendsList.add(relationship.user2Id);
        } else if (relationship.user2Id == userId) {
          friendsList.add(relationship.user1Id);
        }
      }
      
      // For backward compatibility, also check the old friendships collection
      final oldFriendships = await _databaseService.getDocument(
        collection: _friendshipsCollection,
        documentId: userId,
      );
      
      if (oldFriendships != null && oldFriendships.containsKey('friends')) {
        final oldFriends = List<String>.from(oldFriendships['friends']);
        
        // Add old friends to the list if they're not already there
        for (final friendId in oldFriends) {
          if (!friendsList.contains(friendId)) {
            friendsList.add(friendId);
            
            // Create new relationship document for this friendship for future use
            final relationshipId = _generateRelationshipId(userId, friendId);
            await _databaseService.setDocument(
              collection: _relationshipsCollection,
              documentId: relationshipId,
              data: {
                'user1Id': relationshipId.split('_')[0],
                'user2Id': relationshipId.split('_')[1],
                'status': RelationshipStatus.friends.name,
                'direction': RelationshipDirection.mutual.name,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'history': [{
                  'previousStatus': RelationshipStatus.none.name,
                  'newStatus': RelationshipStatus.friends.name,
                  'timestamp': FieldValue.serverTimestamp(),
                  'note': 'Migrated from legacy friendships'
                }],
              },
              merge: true,
            );
          }
        }
      }
      
      return friendsList;
    } catch (e) {
      debugPrint('Error getting user friends: ${e.toString()}');
      throw Exception('Failed to get user friends: ${e.toString()}');
    }
  }

  /// Remove a friendship between two users
  ///
  /// [user1Id] is the ID of the first user
  /// [user2Id] is the ID of the second user
  /// Returns true if the friendship was removed successfully
  Future<bool> removeFriendship(String user1Id, String user2Id) async {
    try {
      final relationshipId = _generateRelationshipId(user1Id, user2Id);
      
      // Get the current relationship
      final relationship = await getRelationship(relationshipId);
      
      if (relationship == null) {
        // If no relationship exists in the new system, check the legacy system
        await _removeLegacyFriendship(user1Id, user2Id);
        return true;
      }
      
      // If they are not friends, just return
      if (relationship.status != RelationshipStatus.friends) {
        return true;
      }
      
      // Update the relationship back to 'none' status
      await _databaseService.updateDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
        data: {
          'status': RelationshipStatus.none.name,
          'direction': RelationshipDirection.mutual.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([{
            'previousStatus': RelationshipStatus.friends.name,
            'newStatus': RelationshipStatus.none.name,
            'timestamp': FieldValue.serverTimestamp(),
            'actionByUserId': user1Id,
            'note': 'Friendship removed'
          }])
        },
      );
      
      // Also remove from legacy system if needed
      await _removeLegacyFriendship(user1Id, user2Id);

      debugPrint('Friendship removed successfully between $user1Id and $user2Id');
      return true;
    } catch (e) {
      debugPrint('Error removing friendship: ${e.toString()}');
      throw Exception('Failed to remove friendship: ${e.toString()}');
    }
  }
  
  /// Helper method to remove friendship in legacy system
  Future<void> _removeLegacyFriendship(String user1Id, String user2Id) async {
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
        if (user1Doc.exists && user1Doc.data() != null && user1Doc.data()!.containsKey('friends')) {
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
        if (user2Doc.exists && user2Doc.data() != null && user2Doc.data()!.containsKey('friends')) {
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
    } catch (e) {
      debugPrint('Error removing legacy friendship: ${e.toString()}');
      // Don't throw - this is a secondary operation
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

      final relationshipId = _generateRelationshipId(blockerId, blockedId);
      
      // Get existing relationship if any
      final relationship = await getRelationship(relationshipId);
      RelationshipStatus previousStatus = RelationshipStatus.none;
      
      // If they are friends, we need to remove that relationship first
      if (relationship != null) {
        previousStatus = relationship.status;
        
        // If already blocked, check who blocked whom
        if (relationship.status == RelationshipStatus.blocked) {
          if (relationship.blockedUserId == blockedId && relationship.blockedByUserId == blockerId) {
            // Already blocked by this user
            return true;
          }
        }
      }
      
      // Determine which user is user1 and which is user2 (for consistent IDs)
      final List<String> orderedIds = [blockerId, blockedId]..sort();
      
      // Update the relationship to blocked
      await _databaseService.setDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
        data: {
          'user1Id': orderedIds[0],
          'user2Id': orderedIds[1],
          'status': RelationshipStatus.blocked.name,
          'direction': blockerId == orderedIds[0] 
              ? RelationshipDirection.fromFirst.name 
              : RelationshipDirection.fromSecond.name,
          'blockedUserId': blockedId,
          'blockedByUserId': blockerId,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([{
            'previousStatus': previousStatus.name,
            'newStatus': RelationshipStatus.blocked.name,
            'timestamp': FieldValue.serverTimestamp(),
            'actionByUserId': blockerId,
            'note': 'User blocked'
          }])
        },
        // Use merge in case this is a new document
        merge: true,
      );
      
      // For backward compatibility, update the old blocked users collection as well
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
      final relationshipId = _generateRelationshipId(blockerId, blockedId);
      
      // Get existing relationship
      final relationship = await getRelationship(relationshipId);
      
      // If no relationship or not blocked, just return
      if (relationship == null || relationship.status != RelationshipStatus.blocked) {
        // Still update the legacy system
        await _databaseService.setDocument(
          collection: _blockedUsersCollection,
          documentId: blockerId,
          data: {
            'blockedUsers': FieldValue.arrayRemove([blockedId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          merge: true,
        );
        return true;
      }
      
      // Check if this user is the one who blocked
      if (relationship.blockedByUserId != blockerId) {
        throw Exception('Cannot unblock a user you did not block');
      }
      
      // Update the relationship back to 'none'
      await _databaseService.updateDocument(
        collection: _relationshipsCollection,
        documentId: relationshipId,
        data: {
          'status': RelationshipStatus.none.name,
          'direction': RelationshipDirection.mutual.name,
          'blockedUserId': null,
          'blockedByUserId': null,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([{
            'previousStatus': RelationshipStatus.blocked.name,
            'newStatus': RelationshipStatus.none.name,
            'timestamp': FieldValue.serverTimestamp(),
            'actionByUserId': blockerId,
            'note': 'User unblocked'
          }])
        },
      );
      
      // For backward compatibility, update the old blocked users collection as well
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
      final List<String> blockedUsers = [];
      
      // Query all relationships where this user blocked someone
      final blockedRelationships = await _databaseService.queryDocuments(
        collection: _relationshipsCollection,
        conditions: [
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.blocked.name},
          {'field': 'blockedByUserId', 'operator': '==', 'value': userId},
        ],
      );
      
      // Extract the blocked user IDs
      for (final doc in blockedRelationships) {
        final relationship = FriendRelationshipModel.fromMap(doc, doc['id']);
        if (relationship.blockedUserId != null) {
          blockedUsers.add(relationship.blockedUserId!);
        }
      }
      
      // For backward compatibility, check the old blocked users collection as well
      final blockedData = await _databaseService.getDocument(
        collection: _blockedUsersCollection,
        documentId: userId,
      );

      if (blockedData != null && blockedData.containsKey('blockedUsers')) {
        final oldBlockedUsers = List<String>.from(blockedData['blockedUsers']);
        
        // Add old blocked users if they're not already there
        for (final blockedId in oldBlockedUsers) {
          if (!blockedUsers.contains(blockedId)) {
            blockedUsers.add(blockedId);
            
            // Also update the relationship in the new system for future use
            await blockUser(userId, blockedId);
          }
        }
      }

      return blockedUsers;
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
      // First check the relationship in the new system
      final relationshipId = _generateRelationshipId(blockerId, potentiallyBlockedId);
      final relationship = await getRelationship(relationshipId);
      
      if (relationship != null && 
          relationship.status == RelationshipStatus.blocked &&
          relationship.blockedByUserId == blockerId &&
          relationship.blockedUserId == potentiallyBlockedId) {
        return true;
      }
      
      // For backward compatibility, check the old blocked users collection as well
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
      final List<String> usersThatBlockedMe = [];
      
      // Query relationships where userId is blocked
      final blockedRelationships = await _databaseService.queryDocuments(
        collection: _relationshipsCollection,
        conditions: [
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.blocked.name},
          {'field': 'blockedUserId', 'operator': '==', 'value': userId},
        ],
      );
      
      // Extract the blocker user IDs
      for (final doc in blockedRelationships) {
        final relationship = FriendRelationshipModel.fromMap(doc, doc['id']);
        if (relationship.blockedByUserId != null) {
          usersThatBlockedMe.add(relationship.blockedByUserId!);
        }
      }
      
      // For backward compatibility, also check the old blocked users collection
      final blockedByDocs = await _databaseService.queryDocuments(
        collection: _blockedUsersCollection,
        field: 'blockedUsers',
        arrayContains: userId,
      );

      // Add any users from the old system who aren't already in the list
      for (final doc in blockedByDocs) {
        final blockerId = doc['id'] as String;
        if (!usersThatBlockedMe.contains(blockerId)) {
          usersThatBlockedMe.add(blockerId);
        }
      }

      return usersThatBlockedMe;
    } catch (e) {
      debugPrint('Error getting users who blocked user: ${e.toString()}');
      throw Exception('Failed to get users who blocked user: ${e.toString()}');
    }
  }
  
  /// Check the current relationship state between two users
  ///
  /// [user1Id] is the ID of the first user
  /// [user2Id] is the ID of the second user
  /// Returns the relationship status
  Future<RelationshipStatus> getRelationshipStatus(String user1Id, String user2Id) async {
    try {
      final relationship = await getRelationshipBetweenUsers(user1Id, user2Id);
      return relationship?.status ?? RelationshipStatus.none;
    } catch (e) {
      debugPrint('Error getting relationship status: ${e.toString()}');
      throw Exception('Failed to get relationship status: ${e.toString()}');
    }
  }
}
