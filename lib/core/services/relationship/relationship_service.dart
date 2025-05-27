import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/relationship_model.dart';
import '../firebase/firebase_database_service.dart';
import '../user/user_service_interface.dart';
import '../auth/auth_service_interface.dart';
import '../service_locator.dart';
import '../logger/logger_service.dart';
import '../../exceptions/relationship_exceptions.dart';
import 'relationship_service_interface.dart';

/// Firebase implementation of the relationship service
/// Handles single document per relationship with proper state transitions
class RelationshipService implements RelationshipServiceInterface {
  final FirebaseDatabaseService _databaseService;
  final UserServiceInterface _userService;
  final AuthServiceInterface _authService;
  final LoggerService _logger;
  
  static const String _tag = 'RELATIONSHIP_SERVICE';
  static const String _relationshipCollection = 'relationships';

  /// Creates a new RelationshipService
  RelationshipService({
    FirebaseDatabaseService? databaseService,
    UserServiceInterface? userService,
    AuthServiceInterface? authService,
    LoggerService? logger,
  }) : _databaseService = databaseService ?? serviceLocator<FirebaseDatabaseService>(),
       _userService = userService ?? serviceLocator<UserServiceInterface>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Get current user ID with validation
  String _getCurrentUserId() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw RelationshipException(
        RelationshipErrorCodes.notLoggedIn,
        'User must be logged in to perform relationship operations',
      );
    }
    return currentUser.uid;
  }

  @override
  Future<String> sendFriendRequest(String targetUserId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      // Validate target user exists
      final targetUser = await _userService.getUserData(targetUserId);
      if (targetUser == null) {
        throw RelationshipException(
          RelationshipErrorCodes.userNotFound,
          'Target user not found',
          null,
          RelationshipOperation.sendRequest,
        );
      }

      // Prevent self-friending
      if (currentUserId == targetUserId) {
        throw RelationshipException(
          RelationshipErrorCodes.selfRequest,
          'Cannot send friend request to yourself',
          null,
          RelationshipOperation.sendRequest,
        );
      }

      // Check if relationship already exists
      final existingRelationship = await getFriendshipStatus(currentUserId, targetUserId);
      
      if (existingRelationship != null) {
        switch (existingRelationship.status) {
          case RelationshipStatus.pending:
            if (existingRelationship.initiatorId == currentUserId) {
              throw RelationshipException(
                RelationshipErrorCodes.requestAlreadySent,
                'Friend request already sent',
                null,
                RelationshipOperation.sendRequest,
              );
            } else {
              throw RelationshipException(
                RelationshipErrorCodes.requestAlreadyReceived,
                'You have a pending friend request from this user',
                null,
                RelationshipOperation.sendRequest,
              );
            }
          case RelationshipStatus.accepted:
            throw RelationshipException(
              RelationshipErrorCodes.alreadyFriends,
              'Users are already friends',
              null,
              RelationshipOperation.sendRequest,
            );
          case RelationshipStatus.blocked:
            throw RelationshipException(
              RelationshipErrorCodes.blocked,
              'Cannot send request to blocked user',
              null,
              RelationshipOperation.sendRequest,
            );
          case RelationshipStatus.declined:
            // Update existing declined relationship to pending with new initiator
            return await _updateExistingRelationshipToPending(
              existingRelationship.id,
              currentUserId,
              targetUserId,
            );
        }
      }

      // Get current user profile for caching
      final currentUser = await _userService.getUserData(currentUserId);
      if (currentUser == null) {
        throw RelationshipException(
          RelationshipErrorCodes.userNotFound,
          'Current user data not found',
          null,
          RelationshipOperation.sendRequest,
        );
      }

      // Create new relationship document
      final participants = RelationshipModel.sortParticipants([currentUserId, targetUserId]);
      final now = DateTime.now();
      
      final newRelationship = RelationshipModel(
        id: '', // Will be set by Firestore
        participants: participants,
        type: RelationshipType.friendship,
        status: RelationshipStatus.pending,
        createdAt: now,
        updatedAt: now,
        initiatorId: currentUserId,
        cachedProfiles: {
          currentUserId: CachedProfile(
            displayName: currentUser.displayName ?? 'Unknown',
            photoURL: currentUser.photoURL,
            lastUpdated: now,
          ),
          targetUserId: CachedProfile(
            displayName: targetUser.displayName ?? 'Unknown',
            photoURL: targetUser.photoURL,
            lastUpdated: now,
          ),
        },
      );

      // Save to Firestore
      final docId = await _databaseService.addDocument(
        collection: _relationshipCollection,
        data: newRelationship.toMap(),
      );

      _logger.i(_tag, 'Friend request sent from $currentUserId to $targetUserId');
      return docId;
    } catch (e) {
      _logger.e(_tag, 'Failed to send friend request: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to send friend request',
        e,
        RelationshipOperation.sendRequest,
      );
    }
  }

  /// Update existing declined relationship to pending with new initiator
  Future<String> _updateExistingRelationshipToPending(
    String relationshipId,
    String newInitiatorId,
    String targetUserId,
  ) async {
    final now = DateTime.now();
    
    // Get fresh user data for cache update
    final newInitiator = await _userService.getUserData(newInitiatorId);
    final targetUser = await _userService.getUserData(targetUserId);
    
    if (newInitiator == null || targetUser == null) {
      throw RelationshipException(
        RelationshipErrorCodes.userNotFound,
        'User data not found',
        null,
        RelationshipOperation.sendRequest,
      );
    }

    final updatedRelationship = {
      'status': RelationshipStatus.pending.name,
      'initiatorId': newInitiatorId,
      'updatedAt': Timestamp.fromDate(now),
      'acceptedAt': null, // Clear previous acceptance
      'cachedProfiles': {
        newInitiatorId: CachedProfile(
          displayName: newInitiator.displayName ?? 'Unknown',
          photoURL: newInitiator.photoURL,
          lastUpdated: now,
        ).toMap(),
        targetUserId: CachedProfile(
          displayName: targetUser.displayName ?? 'Unknown',
          photoURL: targetUser.photoURL,
          lastUpdated: now,
        ).toMap(),
      },
    };

    await _databaseService.setDocument(
      collection: _relationshipCollection,
      documentId: relationshipId,
      data: updatedRelationship,
      merge: true,
    );

    _logger.i(_tag, 'Updated declined relationship to pending: $relationshipId');
    return relationshipId;
  }

  @override
  Future<void> acceptFriendRequest(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      final relationship = await getRelationshipById(relationshipId);
      if (relationship == null) {
        throw RelationshipException(
          RelationshipErrorCodes.notFound,
          'Friend request not found',
          null,
          RelationshipOperation.acceptRequest,
        );
      }

      // Validate user is part of this relationship
      if (!relationship.participants.contains(currentUserId)) {
        throw RelationshipException(
          RelationshipErrorCodes.notParticipant,
          'Not authorized to accept this friend request',
          null,
          RelationshipOperation.acceptRequest,
        );
      }

      // Validate request is pending and user is not the initiator
      if (relationship.status != RelationshipStatus.pending) {
        throw RelationshipException(
          RelationshipErrorCodes.notPending,
          'Friend request is not pending',
          null,
          RelationshipOperation.acceptRequest,
        );
      }

      if (relationship.initiatorId == currentUserId) {
        throw RelationshipException(
          RelationshipErrorCodes.cannotAcceptOwnRequest,
          'Cannot accept your own friend request',
          null,
          RelationshipOperation.acceptRequest,
        );
      }

      // Update relationship to accepted
      final updatedData = {
        'status': RelationshipStatus.accepted.name,
        'acceptedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await _databaseService.setDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
        data: updatedData,
        merge: true,
      );

      _logger.i(_tag, 'Friend request accepted: $relationshipId');
    } catch (e) {
      _logger.e(_tag, 'Failed to accept friend request: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to accept friend request',
        e,
        RelationshipOperation.acceptRequest,
      );
    }
  }

  @override
  Future<void> declineFriendRequest(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      final relationship = await getRelationshipById(relationshipId);
      if (relationship == null) {
        throw RelationshipException(
          RelationshipErrorCodes.notFound,
          'Friend request not found',
          null,
          RelationshipOperation.declineRequest,
        );
      }

      // Validate user is part of this relationship and not the initiator
      if (!relationship.participants.contains(currentUserId) || 
          relationship.initiatorId == currentUserId) {
        throw RelationshipException(
          RelationshipErrorCodes.cannotDeclineOwnRequest,
          'Not authorized to decline this friend request',
          null,
          RelationshipOperation.declineRequest,
        );
      }

      // Validate request is pending
      if (relationship.status != RelationshipStatus.pending) {
        throw RelationshipException(
          RelationshipErrorCodes.notPending,
          'Friend request is not pending',
          null,
          RelationshipOperation.declineRequest,
        );
      }

      // Update relationship to declined
      final updatedData = {
        'status': RelationshipStatus.declined.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await _databaseService.setDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
        data: updatedData,
        merge: true,
      );

      _logger.i(_tag, 'Friend request declined: $relationshipId');
    } catch (e) {
      _logger.e(_tag, 'Failed to decline friend request: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to decline friend request',
        e,
        RelationshipOperation.declineRequest,
      );
    }
  }

  @override
  Future<void> cancelFriendRequest(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      final relationship = await getRelationshipById(relationshipId);
      if (relationship == null) {
        throw RelationshipException(
          RelationshipErrorCodes.notFound,
          'Friend request not found',
          null,
          RelationshipOperation.cancelRequest,
        );
      }

      // Validate user is the initiator
      if (relationship.initiatorId != currentUserId) {
        throw RelationshipException(
          RelationshipErrorCodes.cannotCancelOthersRequest,
          'Can only cancel your own friend requests',
          null,
          RelationshipOperation.cancelRequest,
        );
      }

      // Validate request is pending
      if (relationship.status != RelationshipStatus.pending) {
        throw RelationshipException(
          RelationshipErrorCodes.notPending,
          'Friend request is not pending',
          null,
          RelationshipOperation.cancelRequest,
        );
      }

      // Delete the relationship document
      await _databaseService.deleteDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
      );

      _logger.i(_tag, 'Friend request cancelled: $relationshipId');
    } catch (e) {
      _logger.e(_tag, 'Failed to cancel friend request: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to cancel friend request',
        e,
        RelationshipOperation.cancelRequest,
      );
    }
  }

  @override
  Future<void> removeFriend(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      final relationship = await getRelationshipById(relationshipId);
      if (relationship == null) {
        throw RelationshipException(
          RelationshipErrorCodes.notFound,
          'Friendship not found',
          null,
          RelationshipOperation.removeFriend,
        );
      }

      // Validate user is part of this relationship
      if (!relationship.participants.contains(currentUserId)) {
        throw RelationshipException(
          RelationshipErrorCodes.notParticipant,
          'Not authorized to remove this friendship',
          null,
          RelationshipOperation.removeFriend,
        );
      }

      // Validate relationship is accepted
      if (relationship.status != RelationshipStatus.accepted) {
        throw RelationshipException(
          RelationshipErrorCodes.notAccepted,
          'Can only remove accepted friendships',
          null,
          RelationshipOperation.removeFriend,
        );
      }

      // Delete the relationship document
      await _databaseService.deleteDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
      );

      _logger.i(_tag, 'Friendship removed: $relationshipId');
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friendship: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to remove friendship',
        e,
        RelationshipOperation.removeFriend,
      );
    }
  }

  @override
  Future<void> blockUser(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      final relationship = await getRelationshipById(relationshipId);
      if (relationship == null) {
        throw RelationshipException(
          RelationshipErrorCodes.notFound,
          'Relationship not found',
          null,
          RelationshipOperation.blockUser,
        );
      }

      // Validate user is part of this relationship
      if (!relationship.participants.contains(currentUserId)) {
        throw RelationshipException(
          RelationshipErrorCodes.notParticipant,
          'Not authorized to block this user',
          null,
          RelationshipOperation.blockUser,
        );
      }

      // Update relationship to blocked
      final updatedData = {
        'status': RelationshipStatus.blocked.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await _databaseService.setDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
        data: updatedData,
        merge: true,
      );

      _logger.i(_tag, 'User blocked: $relationshipId');
    } catch (e) {
      _logger.e(_tag, 'Failed to block user: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to block user',
        e,
        RelationshipOperation.blockUser,
      );
    }
  }

  @override
  Future<void> unblockUser(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      final relationship = await getRelationshipById(relationshipId);
      if (relationship == null) {
        throw RelationshipException(
          RelationshipErrorCodes.notFound,
          'Relationship not found',
          null,
          RelationshipOperation.unblockUser,
        );
      }

      // Validate user is part of this relationship
      if (!relationship.participants.contains(currentUserId)) {
        throw RelationshipException(
          RelationshipErrorCodes.notParticipant,
          'Not authorized to unblock this user',
          null,
          RelationshipOperation.unblockUser,
        );
      }

      // Validate relationship is blocked
      if (relationship.status != RelationshipStatus.blocked) {
        throw RelationshipException(
          RelationshipErrorCodes.notBlocked,
          'User is not blocked',
          null,
          RelationshipOperation.unblockUser,
        );
      }

      // Delete the relationship (unblocking removes the relationship entirely)
      await _databaseService.deleteDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
      );

      _logger.i(_tag, 'User unblocked: $relationshipId');
    } catch (e) {
      _logger.e(_tag, 'Failed to unblock user: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to unblock user',
        e,
        RelationshipOperation.unblockUser,
      );
    }
  }

  @override
  Future<List<RelationshipModel>> getFriends(String userId) async {
    try {
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.accepted.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
      );

      return results
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get friends: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get friends list',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<List<RelationshipModel>> getPendingRequests(String userId) async {
    try {
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.pending.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
      );

      // Filter to only show requests received by this user (not sent by them)
      return results
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .where((relationship) => relationship.initiatorId != userId)
          .toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get pending requests: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get pending friend requests',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<List<RelationshipModel>> getSentRequests(String userId) async {
    try {
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'initiatorId', 'operator': '==', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.pending.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
      );

      return results
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get sent requests: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get sent friend requests',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<List<RelationshipModel>> getBlockedUsers(String userId) async {
    try {
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.blocked.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
      );

      return results
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get blocked users: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get blocked users list',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<RelationshipModel?> getFriendshipStatus(String userId, String otherUserId) async {
    try {
      final participants = RelationshipModel.sortParticipants([userId, otherUserId]);
      
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': '==', 'value': participants},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
      );

      if (results.isEmpty) {
        return null;
      }

      return RelationshipModel.fromMap(results.first, results.first['id']);
    } catch (e) {
      _logger.e(_tag, 'Failed to get friendship status: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to check friendship status',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<List<RelationshipModel>> searchFriends(String userId, String query) async {
    try {
      final friends = await getFriends(userId);
      
      if (query.isEmpty) {
        return friends;
      }

      // Search in cached profiles
      return friends.where((friendship) {
        final otherUserId = friendship.getFriendId(userId);
        final cachedProfile = friendship.getCachedProfile(otherUserId);
        
        if (cachedProfile != null) {
          return cachedProfile.displayName
              .toLowerCase()
              .contains(query.toLowerCase());
        }
        
        return false;
      }).toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to search friends: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to search friends',
        e,
        RelationshipOperation.searchFriends,
      );
    }
  }

  @override
  Future<RelationshipModel?> getRelationshipById(String relationshipId) async {
    try {
      final doc = await _databaseService.getDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
      );

      if (doc == null) {
        return null;
      }

      return RelationshipModel.fromMap(doc, relationshipId);
    } catch (e) {
      _logger.e(_tag, 'Failed to get relationship: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get relationship',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<bool> checkIfUsersAreFriends(String userId1, String userId2) async {
    try {
      final relationship = await getFriendshipStatus(userId1, userId2);
      return relationship?.status == RelationshipStatus.accepted;
    } catch (e) {
      _logger.e(_tag, 'Failed to check friendship: ${e.toString()}');
      return false;
    }
  }

  @override
  Future<List<RelationshipModel>> getMutualFriends(String userId1, String userId2) async {
    try {
      final user1Friends = await getFriends(userId1);
      final user2Friends = await getFriends(userId2);

      final user1FriendIds = user1Friends.map((f) => f.getFriendId(userId1)).toSet();
      final user2FriendIds = user2Friends.map((f) => f.getFriendId(userId2)).toSet();

      final mutualFriendIds = user1FriendIds.intersection(user2FriendIds);

      return user1Friends
          .where((f) => mutualFriendIds.contains(f.getFriendId(userId1)))
          .toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get mutual friends: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get mutual friends',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<int> getFriendCount(String userId) async {
    try {
      final friends = await getFriends(userId);
      return friends.length;
    } catch (e) {
      _logger.e(_tag, 'Failed to get friend count: ${e.toString()}');
      return 0;
    }
  }

  @override
  Future<List<RelationshipModel>> getMultipleRelationships(List<String> relationshipIds) async {
    try {
      if (relationshipIds.isEmpty) {
        return [];
      }

      final relationships = <RelationshipModel>[];
      
      // Firestore 'in' queries are limited to 10 items, so we need to batch
      const batchSize = 10;
      for (int i = 0; i < relationshipIds.length; i += batchSize) {
        final batch = relationshipIds.skip(i).take(batchSize).toList();
        
        final results = await _databaseService.queryDocuments(
          collection: _relationshipCollection,
          conditions: [
            {'field': FieldPath.documentId, 'operator': 'in', 'value': batch},
          ],
        );

        relationships.addAll(
          results.map((doc) => RelationshipModel.fromMap(doc, doc['id'])),
        );
      }

      return relationships;
    } catch (e) {
      _logger.e(_tag, 'Failed to get multiple relationships: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get relationships',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<Map<String, int>> getUserRelationshipsSummary(String userId) async {
    try {
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
      );

      final relationships = results
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .toList();

      final summary = <String, int>{
        'friends': 0,
        'pending_received': 0,
        'pending_sent': 0,
        'blocked': 0,
      };

      for (final relationship in relationships) {
        switch (relationship.status) {
          case RelationshipStatus.accepted:
            summary['friends'] = summary['friends']! + 1;
            break;
          case RelationshipStatus.pending:
            if (relationship.initiatorId == userId) {
              summary['pending_sent'] = summary['pending_sent']! + 1;
            } else {
              summary['pending_received'] = summary['pending_received']! + 1;
            }
            break;
          case RelationshipStatus.blocked:
            summary['blocked'] = summary['blocked']! + 1;
            break;
          case RelationshipStatus.declined:
            // Don't count declined requests
            break;
        }
      }

      return summary;
    } catch (e) {
      _logger.e(_tag, 'Failed to get relationships summary: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get relationships summary',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<void> updateCachedProfile(String userId, String displayName, String? photoURL) async {
    try {
      // Get all relationships involving this user
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
        ],
      );

      final batch = FirebaseFirestore.instance.batch();
      final updatedAt = DateTime.now();

      for (final doc in results) {
        final relationship = RelationshipModel.fromMap(doc, doc['id']);
        final updatedCachedProfiles = Map<String, CachedProfile>.from(relationship.cachedProfiles);
        
        // Update the cached profile for this user
        updatedCachedProfiles[userId] = CachedProfile(
          displayName: displayName,
          photoURL: photoURL,
          lastUpdated: updatedAt,
        );

        final updatedRelationship = relationship.copyWith(
          cachedProfiles: updatedCachedProfiles,
          updatedAt: updatedAt,
        );

        batch.update(
          FirebaseFirestore.instance.collection(_relationshipCollection).doc(doc['id']),
          updatedRelationship.toMap(),
        );
      }

      await batch.commit();
      _logger.i(_tag, 'Updated cached profile for user: $userId in ${results.length} relationships');
    } catch (e) {
      _logger.e(_tag, 'Failed to update cached profile: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.cacheUpdateFailed,
        'Failed to update profile cache',
        e,
        RelationshipOperation.updateProfile,
      );
    }
  }

  @override
  Future<void> refreshCachedProfiles(String relationshipId) async {
    try {
      final relationship = await getRelationshipById(relationshipId);
      if (relationship == null) {
        throw RelationshipException(
          RelationshipErrorCodes.notFound,
          'Relationship not found',
          null,
          RelationshipOperation.updateProfile,
        );
      }

      final updatedCachedProfiles = <String, CachedProfile>{};
      final updatedAt = DateTime.now();

      // Refresh cached profiles for all participants
      for (final userId in relationship.participants) {
        final userProfile = await _userService.getUserData(userId);
        if (userProfile != null) {
          updatedCachedProfiles[userId] = CachedProfile(
            displayName: userProfile.displayName ?? 'Unknown',
            photoURL: userProfile.photoURL,
            lastUpdated: updatedAt,
          );
        }
      }

      final updatedRelationship = relationship.copyWith(
        cachedProfiles: updatedCachedProfiles,
        updatedAt: updatedAt,
      );

      await _databaseService.setDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
        data: updatedRelationship.toMap(),
        merge: true,
      );

      _logger.i(_tag, 'Refreshed cached profiles for relationship: $relationshipId');
    } catch (e) {
      _logger.e(_tag, 'Failed to refresh cached profiles: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.profileRefreshFailed,
        'Failed to refresh cached profiles',
        e,
        RelationshipOperation.updateProfile,
      );
    }
  }
}
