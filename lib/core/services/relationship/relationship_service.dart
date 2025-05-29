import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/relationship_model.dart';
import '../firebase/firebase_database_service.dart';
import '../user/user_service_interface.dart';
import '../auth/auth_service_interface.dart';
import '../notifications/notifications_service.dart';
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
  final NotificationsService _notificationsService;
  final LoggerService _logger;
  
  static const String _tag = 'RELATIONSHIP_SERVICE';
  static const String _relationshipCollection = 'relationships';

  /// Creates a new RelationshipService
  RelationshipService({
    FirebaseDatabaseService? databaseService,
    UserServiceInterface? userService,
    AuthServiceInterface? authService,
    NotificationsService? notificationsService,
    LoggerService? logger,
  }) : _databaseService = databaseService ?? serviceLocator<FirebaseDatabaseService>(),
       _userService = userService ?? serviceLocator<UserServiceInterface>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>(),
       _notificationsService = notificationsService ?? serviceLocator<NotificationsService>(),
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

      // Use transaction to ensure consistency
      return await _databaseService.runTransaction<String>((transaction) async {
        // Check if relationship already exists within transaction
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

        // Create new relationship document within transaction
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

        // Create document within transaction
        final docRef = _databaseService.firestoreInstance.collection(_relationshipCollection).doc();
        transaction.set(docRef, {
          ...newRelationship.toMap(),
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        _logger.i(_tag, 'Friend request sent from $currentUserId to $targetUserId');
        
        // Send notification to target user (fire-and-forget)
        final currentUserProfile = await _userService.getUserData(currentUserId);
        if (currentUserProfile != null) {
          _notificationsService.sendNotification(
            recipientUid: targetUserId,
            // Don't include title field at all to avoid showing title in notification
            body: '${currentUserProfile.displayName ?? 'Someone'} wants to be your friend',
            data: {
              'type': 'friend_request',
              'sender_name': currentUserProfile.displayName ?? 'Someone',
              // Remove photo URL and other unnecessary data
            },
          );
        }
        
        return docRef.id;
      });
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
      
      // Use transaction to ensure consistency
      await _databaseService.runTransaction<void>((transaction) async {
        final relationshipRef = _databaseService.firestoreInstance
            .collection(_relationshipCollection)
            .doc(relationshipId);
            
        final relationshipDoc = await transaction.get(relationshipRef);
        
        if (!relationshipDoc.exists) {
          throw RelationshipException(
            RelationshipErrorCodes.notFound,
            'Friend request not found',
            null,
            RelationshipOperation.acceptRequest,
          );
        }

        final relationship = RelationshipModel.fromMap(relationshipDoc.data()!, relationshipId);

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

        // Update relationship to accepted within transaction
        final now = DateTime.now();
        transaction.update(relationshipRef, {
          'status': RelationshipStatus.accepted.name,
          'acceptedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        _logger.i(_tag, 'Friend request accepted: $relationshipId');
      });
      
      // Send notification to the request sender (fire-and-forget)
      final relationship = await _getRelationshipById(relationshipId);
      if (relationship != null && relationship.initiatorId != null) {
        final accepterProfile = await _userService.getUserData(currentUserId);
        if (accepterProfile != null) {
          _notificationsService.sendNotification(
            recipientUid: relationship.initiatorId!,
            // Leave title empty as per requirement to only show the name
            title: '',
            body: '${accepterProfile.displayName ?? 'Someone'} accepted your friend request',
            data: {
              'type': 'friend_request_accepted',
              'accepter_name': accepterProfile.displayName ?? 'Someone',
              // Remove photo URL and other unnecessary data
            },
          );
        }
      }
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
      
      final relationship = await _getRelationshipById(relationshipId);
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
      
      final relationship = await _getRelationshipById(relationshipId);
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
      
      final relationship = await _getRelationshipById(relationshipId);
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
      
      // Use transaction to ensure consistency
      await _databaseService.runTransaction<void>((transaction) async {
        final relationshipRef = _databaseService.firestoreInstance
            .collection(_relationshipCollection)
            .doc(relationshipId);
            
        final relationshipDoc = await transaction.get(relationshipRef);
        
        if (!relationshipDoc.exists) {
          throw RelationshipException(
            RelationshipErrorCodes.notFound,
            'Relationship not found',
            null,
            RelationshipOperation.blockUser,
          );
        }

        final relationship = RelationshipModel.fromMap(relationshipDoc.data()!, relationshipId);

        // Validate user is part of this relationship
        if (!relationship.participants.contains(currentUserId)) {
          throw RelationshipException(
            RelationshipErrorCodes.notParticipant,
            'Not authorized to block this user',
            null,
            RelationshipOperation.blockUser,
          );
        }

        // Update relationship to blocked within transaction
        transaction.update(relationshipRef, {
          'status': RelationshipStatus.blocked.name,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        _logger.i(_tag, 'User blocked: $relationshipId');
      });
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
      
      final relationship = await _getRelationshipById(relationshipId);
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
  Future<PaginatedRelationshipResult> getFriends(String userId, {int limit = 20, String? startAfter}) async {
    try {
      // Simplified query - removed ordering to avoid index requirement
      // TODO: Add proper composite index in Firebase Console for better performance
      final results = await _databaseService.queryDocumentsWithPagination(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.accepted.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
        // Temporarily removed orderBy to avoid index requirement
        // orderBy: 'updatedAt',
        // descending: true,
        limit: limit + 1, // Fetch one extra to check if there are more
        startAfterDocument: startAfter,
      );

      final relationships = results
          .take(limit) // Take only the requested amount
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .toList();

      final hasMore = results.length > limit;
      final lastDocumentId = relationships.isNotEmpty ? relationships.last.id : null;

      return PaginatedRelationshipResult(
        relationships: relationships,
        hasMore: hasMore,
        lastDocumentId: lastDocumentId,
      );
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



  Future<RelationshipModel?> _getRelationshipById(String relationshipId) async {
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
  Future<PaginatedRelationshipResult> getPendingRequests(String userId, {int limit = 20, String? startAfter}) async {
    try {
      // Simplified query - removed ordering to avoid index requirement
      final results = await _databaseService.queryDocumentsWithPagination(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.pending.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
        // Temporarily removed orderBy to avoid index requirement
        // orderBy: 'createdAt',
        // descending: true,
        limit: limit * 2, // Fetch more since we need to filter
        startAfterDocument: startAfter,
      );

      // Filter to only show requests received by this user (not sent by them)
      final relationships = results
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .where((relationship) => relationship.initiatorId != userId)
          .take(limit)
          .toList();

      // For pending requests, we need to check if there are more by running another query
      final hasMore = relationships.length == limit;
      final lastDocId = relationships.isNotEmpty ? relationships.last.id : null;

      return PaginatedRelationshipResult(
        relationships: relationships,
        hasMore: hasMore,
        lastDocumentId: lastDocId,
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to get pending requests paginated: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get pending friend requests',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<PaginatedRelationshipResult> getSentRequests(String userId, {int limit = 20, String? startAfter}) async {
    try {
      // Simplified query - removed ordering to avoid index requirement
      final results = await _databaseService.queryDocumentsWithPagination(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'initiatorId', 'operator': '==', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.pending.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
        // Temporarily removed orderBy to avoid index requirement
        // orderBy: 'createdAt',
        // descending: true,
        limit: limit + 1, // Fetch one extra to check if there are more
        startAfterDocument: startAfter,
      );

      final relationships = results
          .take(limit) // Take only the requested amount
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .toList();

      final hasMore = results.length > limit;
      final lastDocId = relationships.isNotEmpty ? relationships.last.id : null;

      return PaginatedRelationshipResult(
        relationships: relationships,
        hasMore: hasMore,
        lastDocumentId: lastDocId,
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to get sent requests paginated: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get sent friend requests',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<PaginatedRelationshipResult> getBlockedUsers(String userId, {int limit = 20, String? startAfter}) async {
    try {
      // Simplified query - removed ordering to avoid index requirement
      final results = await _databaseService.queryDocumentsWithPagination(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': 'array-contains', 'value': userId},
          {'field': 'status', 'operator': '==', 'value': RelationshipStatus.blocked.name},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
        // Temporarily removed orderBy to avoid index requirement
        // orderBy: 'updatedAt',
        // descending: true,
        limit: limit + 1, // Fetch one extra to check if there are more
        startAfterDocument: startAfter,
      );

      final relationships = results
          .take(limit) // Take only the requested amount
          .map((doc) => RelationshipModel.fromMap(doc, doc['id']))
          .toList();

      final hasMore = results.length > limit;
      final lastDocId = relationships.isNotEmpty ? relationships.last.id : null;

      return PaginatedRelationshipResult(
        relationships: relationships,
        hasMore: hasMore,
        lastDocumentId: lastDocId,
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to get blocked users paginated: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get blocked users list',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      // Prevent searching for self
      if (currentUserId == uid) {
        throw RelationshipException(
          RelationshipErrorCodes.selfRequest,
          'Cannot search for yourself',
          null,
          RelationshipOperation.searchUser,
        );
      }

      // Get user data from user service
      final userData = await _userService.getUserData(uid);
      if (userData == null) {
        return null;
      }

      // Check existing relationship status
      final existingRelationship = await getFriendshipStatus(currentUserId, uid);
      
      String relationshipStatus = 'none';
      String? relationshipId;
      
      if (existingRelationship != null) {
        relationshipId = existingRelationship.id;
        switch (existingRelationship.status) {
          case RelationshipStatus.accepted:
            relationshipStatus = 'friends';
            break;
          case RelationshipStatus.pending:
            if (existingRelationship.initiatorId == currentUserId) {
              relationshipStatus = 'request_sent';
            } else {
              relationshipStatus = 'request_received';
            }
            break;
          case RelationshipStatus.blocked:
            relationshipStatus = 'blocked';
            break;
          case RelationshipStatus.declined:
            relationshipStatus = 'declined';
            break;
        }
      }

      return {
        'uid': userData.uid,
        'displayName': userData.displayName,
        'photoURL': userData.photoURL,
        'email': userData.email,
        'relationshipStatus': relationshipStatus,
        'relationshipId': relationshipId,
        'canSendRequest': relationshipStatus == 'none' || relationshipStatus == 'declined',
      };
    } catch (e) {
      _logger.e(_tag, 'Failed to search user by UID: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to search user',
        e,
        RelationshipOperation.searchUser,
      );
    }
  }

  // ========== STREAM-BASED METHODS ==========

  @override
  Stream<List<RelationshipModel>> getFriendsStream(String userId) {
    _logger.d(_tag, 'Getting friends stream for user: $userId');
    return _databaseService
        .collectionStream(
          collection: _relationshipCollection,
          queryBuilder: (query) => query
              .where('participants', arrayContains: userId)
              .where('status', isEqualTo: RelationshipStatus.accepted.name),
        )
        .map((snapshot) {
          final relationships = snapshot.docs
              .map((doc) => RelationshipModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by display name of the other participant
          relationships.sort((a, b) => 
            (a.cachedProfiles[a.participants.firstWhere((id) => id != userId, orElse: () => '')]?.displayName ?? '')
            .compareTo(b.cachedProfiles[b.participants.firstWhere((id) => id != userId, orElse: () => '')]?.displayName ?? '')
          );
          return relationships;
        })
        .handleError((error) {
          _logger.e(_tag, 'Error in getFriendsStream: $error');
          _handleStreamError(error, RelationshipOperation.getFriendsStream);
          return Stream.value([]); // Return empty list on error to keep stream alive
        });
  }

  @override
  Stream<List<RelationshipModel>> getPendingRequestsStream(String userId) {
    _logger.d(_tag, 'Getting pending requests stream for user: $userId');
    return _databaseService
        .collectionStream(
          collection: _relationshipCollection,
          queryBuilder: (query) => query
              .where('participants', arrayContains: userId)
              .where('status', isEqualTo: RelationshipStatus.pending.name)
              .where('initiatorId', isNotEqualTo: userId), // User is the receiver
        )
        .map((snapshot) {
          final relationships = snapshot.docs
              .map((doc) => RelationshipModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by display name of the initiator
          relationships.sort((a, b) => 
            (a.cachedProfiles[a.initiatorId]?.displayName ?? '')
            .compareTo(b.cachedProfiles[b.initiatorId]?.displayName ?? '')
          );
          return relationships;
        })
        .handleError((error) {
          _logger.e(_tag, 'Error in getPendingRequestsStream: $error');
          _handleStreamError(error, RelationshipOperation.getPendingRequestsStream);
          return Stream.value([]);
        });
  }

  @override
  Stream<List<RelationshipModel>> getSentRequestsStream(String userId) {
    _logger.d(_tag, 'Getting sent requests stream for user: $userId');
    return _databaseService
        .collectionStream(
          collection: _relationshipCollection,
          queryBuilder: (query) => query
              .where('participants', arrayContains: userId)
              .where('status', isEqualTo: RelationshipStatus.pending.name)
              .where('initiatorId', isEqualTo: userId), // User is the initiator
        )
        .map((snapshot) {
          final relationships = snapshot.docs
              .map((doc) => RelationshipModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by display name of the other participant (receiver)
          relationships.sort((a, b) {
            final otherParticipantA = a.participants.firstWhere((pId) => pId != userId, orElse: () => '');
            final otherParticipantB = b.participants.firstWhere((pId) => pId != userId, orElse: () => '');
            return (a.cachedProfiles[otherParticipantA]?.displayName ?? '')
                .compareTo(b.cachedProfiles[otherParticipantB]?.displayName ?? '');
          });
          return relationships;
        })
        .handleError((error) {
          _logger.e(_tag, 'Error in getSentRequestsStream: $error');
          _handleStreamError(error, RelationshipOperation.getSentRequestsStream);
          return Stream.value([]);
        });
  }

  /// Helper to handle stream errors consistently
  void _handleStreamError(Object error, RelationshipOperation operation) {
    if (error is RelationshipException) {
      // Log already handled by the exception constructor or specific catch block
    } else {
      // Log unexpected errors
      _logger.e(
        _tag,
        'Unexpected error in stream operation $operation: ${error.toString()}',
      );
      // Optionally, rethrow as a RelationshipException if needed for higher-level handling
      // throw RelationshipException(
      //   RelationshipErrorCodes.databaseError,
      //   'Stream failed for $operation',
      //   error,
      //   operation,
      // );
    }
    // Consider if Crashlytics should record these errors,
    // but be mindful of potential noise if streams frequently encounter transient issues.
  }
}
