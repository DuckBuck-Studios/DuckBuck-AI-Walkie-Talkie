import 'dart:async';
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
/// Handles relationship operations using the Firebase database service
/// 
/// All stream methods (getFriendsStream, getPendingRequestsStream, getBlockedUsersStream) 
/// implement pagination with a default limit of 15 items per page for optimal performance.
class RelationshipService implements RelationshipServiceInterface {
  final FirebaseDatabaseService _databaseService;
  final UserServiceInterface _userService;
  final AuthServiceInterface _authService;
  final NotificationsService _notificationsService;
  final LoggerService _logger;
  
  static const String _tag = 'RELATIONSHIP_SERVICE';
  static const String _relationshipCollection = 'relationships';
  static const int _defaultPageSize = 15;

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

      // Use transaction to check existing relationship and create new one
      return await _databaseService.runTransaction<String>((transaction) async {
        // Check if relationship already exists
        final existingRelationship = await _getRelationshipBetweenUsers(currentUserId, targetUserId);
        
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
              // Update existing declined relationship to pending
              await _updateRelationshipInTransaction(
                transaction,
                existingRelationship.id,
                {
                  'status': RelationshipStatus.pending.name,
                  'initiatorId': currentUserId,
                  'updatedAt': DateTime.now().toIso8601String(),
                  'acceptedAt': null,
                },
              );
              
              // Send notification
              await _sendFriendRequestNotification(currentUserId, targetUserId);
              return existingRelationship.id;
          }
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
        );

        // Add document using Firebase database service
        final docRef = await _databaseService.addDocument(
          collection: _relationshipCollection,
          data: newRelationship.toMap(),
        );

        _logger.i(_tag, 'Friend request sent: $docRef');
        
        // Send notification
        await _sendFriendRequestNotification(currentUserId, targetUserId);
        return docRef;
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

  @override
  Future<String> acceptFriendRequest(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      return await _databaseService.runTransaction<String>((transaction) async {
        // Get the relationship
        final relationship = await _getRelationshipById(relationshipId);
        if (relationship == null) {
          throw RelationshipException(
            RelationshipErrorCodes.notFound,
            'Friend request not found',
            null,
            RelationshipOperation.acceptRequest,
          );
        }

        // Validate user is participant
        if (!relationship.participants.contains(currentUserId)) {
          throw RelationshipException(
            RelationshipErrorCodes.notParticipant,
            'You are not a participant in this relationship',
            null,
            RelationshipOperation.acceptRequest,
          );
        }

        // Validate request is pending
        if (relationship.status != RelationshipStatus.pending) {
          throw RelationshipException(
            RelationshipErrorCodes.notPending,
            'Friend request is not pending',
            null,
            RelationshipOperation.acceptRequest,
          );
        }

        // Validate user is not the initiator
        if (relationship.initiatorId == currentUserId) {
          throw RelationshipException(
            RelationshipErrorCodes.cannotAcceptOwnRequest,
            'Cannot accept your own friend request',
            null,
            RelationshipOperation.acceptRequest,
          );
        }

        // Update relationship to accepted
        await _updateRelationshipInTransaction(
          transaction,
          relationshipId,
          {
            'status': RelationshipStatus.accepted.name,
            'acceptedAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        _logger.i(_tag, 'Friend request accepted: $relationshipId');
        
        // Send notification to the initiator
        if (relationship.initiatorId != null) {
          await _sendFriendAcceptedNotification(currentUserId, relationship.initiatorId!);
        }
        
        return relationshipId;
      });
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
  Future<bool> rejectFriendRequest(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      return await _databaseService.runTransaction<bool>((transaction) async {
        // Get the relationship
        final relationship = await _getRelationshipById(relationshipId);
        if (relationship == null) {
          throw RelationshipException(
            RelationshipErrorCodes.notFound,
            'Friend request not found',
            null,
            RelationshipOperation.declineRequest,
          );
        }

        // Validate user is participant
        if (!relationship.participants.contains(currentUserId)) {
          throw RelationshipException(
            RelationshipErrorCodes.notParticipant,
            'You are not a participant in this relationship',
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

        // Validate user is not the initiator
        if (relationship.initiatorId == currentUserId) {
          throw RelationshipException(
            RelationshipErrorCodes.cannotDeclineOwnRequest,
            'Cannot decline your own friend request',
            null,
            RelationshipOperation.declineRequest,
          );
        }

        // Update relationship to declined
        await _updateRelationshipInTransaction(
          transaction,
          relationshipId,
          {
            'status': RelationshipStatus.declined.name,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        _logger.i(_tag, 'Friend request rejected: $relationshipId');
        return true;
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to reject friend request: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to reject friend request',
        e,
        RelationshipOperation.declineRequest,
      );
    }
  }

  @override
  Future<bool> cancelFriendRequest(String relationshipId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      return await _databaseService.runTransaction<bool>((transaction) async {
        // Get the relationship
        final relationship = await _getRelationshipById(relationshipId);
        if (relationship == null) {
          throw RelationshipException(
            RelationshipErrorCodes.notFound,
            'Friend request not found',
            null,
            RelationshipOperation.cancelRequest,
          );
        }

        // Validate user is participant
        if (!relationship.participants.contains(currentUserId)) {
          throw RelationshipException(
            RelationshipErrorCodes.notParticipant,
            'You are not a participant in this relationship',
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

        // Validate user is the initiator (can only cancel own requests)
        if (relationship.initiatorId != currentUserId) {
          throw RelationshipException(
            RelationshipErrorCodes.cannotCancelOthersRequest,
            'You can only cancel your own friend requests',
            null,
            RelationshipOperation.cancelRequest,
          );
        }

        // Delete the relationship document
        _logger.d(_tag, 'Deleting relationship document: ${relationship.id}');
        await _deleteRelationshipInTransaction(transaction, relationship.id);

        _logger.i(_tag, 'Friend request cancelled: $relationshipId');
        return true;
      });
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
  Future<bool> removeFriend(String targetUserId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      // Prevent self-removal
      if (currentUserId == targetUserId) {
        throw RelationshipException(
          RelationshipErrorCodes.selfRequest,
          'Cannot remove yourself as friend',
          null,
          RelationshipOperation.removeFriend,
        );
      }

      return await _databaseService.runTransaction<bool>((transaction) async {
        // Get the relationship
        final relationship = await _getRelationshipBetweenUsers(currentUserId, targetUserId);
        if (relationship == null) {
          throw RelationshipException(
            RelationshipErrorCodes.notFound,
            'Friendship not found',
            null,
            RelationshipOperation.removeFriend,
          );
        }

        // Validate relationship is accepted
        if (relationship.status != RelationshipStatus.accepted) {
          throw RelationshipException(
            RelationshipErrorCodes.notAccepted,
            'Users are not friends',
            null,
            RelationshipOperation.removeFriend,
          );
        }

        // Delete the relationship
        _logger.d(_tag, 'Deleting relationship document: ${relationship.id}');
        await _deleteRelationshipInTransaction(transaction, relationship.id);

        _logger.i(_tag, 'Friend removed: ${relationship.id}');
        _logger.d(_tag, 'Document deleted successfully, transaction should now commit and trigger stream update');
        return true;
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: ${e.toString()}');
      if (e is RelationshipException) rethrow;
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to remove friend',
        e,
        RelationshipOperation.removeFriend,
      );
    }
  }

  @override
  Future<String> blockUser(String targetUserId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      // Validate target user exists
      final targetUser = await _userService.getUserData(targetUserId);
      if (targetUser == null) {
        throw RelationshipException(
          RelationshipErrorCodes.userNotFound,
          'Target user not found',
          null,
          RelationshipOperation.blockUser,
        );
      }

      // Prevent self-blocking
      if (currentUserId == targetUserId) {
        throw RelationshipException(
          RelationshipErrorCodes.selfRequest,
          'Cannot block yourself',
          null,
          RelationshipOperation.blockUser,
        );
      }

      return await _databaseService.runTransaction<String>((transaction) async {
        // Check if relationship already exists
        final existingRelationship = await _getRelationshipBetweenUsers(currentUserId, targetUserId);
        
        if (existingRelationship != null) {
          // Update existing relationship to blocked
          await _updateRelationshipInTransaction(
            transaction,
            existingRelationship.id,
            {
              'status': RelationshipStatus.blocked.name,
              'initiatorId': currentUserId,
              'updatedAt': DateTime.now().toIso8601String(),
              'acceptedAt': null,
            },
          );
          
          _logger.i(_tag, 'User blocked (updated existing): ${existingRelationship.id}');
          return existingRelationship.id;
        } else {
          // Create new blocked relationship
          final participants = RelationshipModel.sortParticipants([currentUserId, targetUserId]);
          final now = DateTime.now();
          
          final newRelationship = RelationshipModel(
            id: '', // Will be set by Firestore
            participants: participants,
            type: RelationshipType.friendship,
            status: RelationshipStatus.blocked,
            createdAt: now,
            updatedAt: now,
            initiatorId: currentUserId,
          );

          final docRef = await _databaseService.addDocument(
            collection: _relationshipCollection,
            data: newRelationship.toMap(),
          );

          _logger.i(_tag, 'User blocked (new relationship): $docRef');
          return docRef;
        }
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
  Future<bool> unblockUser(String targetUserId) async {
    try {
      final currentUserId = _getCurrentUserId();
      
      // Prevent self-unblocking
      if (currentUserId == targetUserId) {
        throw RelationshipException(
          RelationshipErrorCodes.selfRequest,
          'Cannot unblock yourself',
          null,
          RelationshipOperation.unblockUser,
        );
      }

      return await _databaseService.runTransaction<bool>((transaction) async {
        // Get the relationship
        final relationship = await _getRelationshipBetweenUsers(currentUserId, targetUserId);
        if (relationship == null) {
          throw RelationshipException(
            RelationshipErrorCodes.notFound,
            'Block relationship not found',
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

        // Validate current user is the one who blocked
        if (relationship.initiatorId != currentUserId) {
          throw RelationshipException(
            RelationshipErrorCodes.unauthorized,
            'You can only unblock users you have blocked',
            null,
            RelationshipOperation.unblockUser,
          );
        }

        // Delete the blocked relationship
        await _deleteRelationshipInTransaction(transaction, relationship.id);

        _logger.i(_tag, 'User unblocked: ${relationship.id}');
        return true;
      });
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
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    try {
      final currentUserId = _getCurrentUserId();
      
      return _databaseService.collectionStream(
        collection: _relationshipCollection,
        queryBuilder: (query) => query
            .where('participants', arrayContains: currentUserId)
            .where('status', isEqualTo: RelationshipStatus.accepted.name)
            .where('type', isEqualTo: RelationshipType.friendship.name)
            .orderBy('createdAt', descending: true)  // This will require a composite index!
            .limit(_defaultPageSize), // Limit to 15 friends
      ).map((querySnapshot) {
        _logger.d(_tag, 'Friends stream: Received ${querySnapshot.docs.length} relationship documents');
        
        final friendsData = <Map<String, dynamic>>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
            
            if (otherUserId.isNotEmpty) {
              friendsData.add({
                'uid': otherUserId,
                'relationshipId': doc.id,
              });
              _logger.d(_tag, 'Friends stream: Found friend relationship - userId: $otherUserId, relationshipId: ${doc.id}');
            }
          } catch (e) {
            _logger.w(_tag, 'Failed to process friend relationship for doc ${doc.id}: ${e.toString()}');
          }
        }
        
        _logger.i(_tag, 'Friends stream updated: ${friendsData.length} friends');
        return friendsData;
      }).handleError((error) {
        _logger.e(_tag, 'Friends stream error: ${error.toString()}');
        throw RelationshipException(
          RelationshipErrorCodes.databaseError,
          'Failed to stream friends list',
          error,
          RelationshipOperation.getFriends,
        );
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to create friends stream: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to create friends stream',
        e,
        RelationshipOperation.getFriends,
      );
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> getPendingRequestsStream() {
    try {
      final currentUserId = _getCurrentUserId();
      
      return _databaseService.collectionStream(
        collection: _relationshipCollection,
        queryBuilder: (query) => query
            .where('participants', arrayContains: currentUserId)
            .where('status', isEqualTo: RelationshipStatus.pending.name)
            .where('type', isEqualTo: RelationshipType.friendship.name)
            .orderBy('createdAt', descending: true)  // This will require a composite index!
            .limit(_defaultPageSize), // Limit to 15 pending requests
      ).map((querySnapshot) {
        _logger.d(_tag, 'Pending requests stream: Received ${querySnapshot.docs.length} relationship documents');
        
        final pendingRequestsData = <Map<String, dynamic>>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final initiatorId = data['initiatorId'] as String? ?? '';
            final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
            
            if (otherUserId.isNotEmpty && initiatorId.isNotEmpty) {
              final isIncoming = initiatorId != currentUserId;
              
              pendingRequestsData.add({
                'uid': otherUserId,
                'relationshipId': doc.id,
                'isIncoming': isIncoming,
                'initiatorId': initiatorId,
              });
              _logger.d(_tag, 'Pending requests stream: Found pending request - userId: $otherUserId, relationshipId: ${doc.id}, isIncoming: $isIncoming');
            }
          } catch (e) {
            _logger.w(_tag, 'Failed to process pending request for doc ${doc.id}: ${e.toString()}');
          }
        }
        
        _logger.i(_tag, 'Pending requests stream updated: ${pendingRequestsData.length} requests');
        return pendingRequestsData;
      }).handleError((error) {
        _logger.e(_tag, 'Pending requests stream error: ${error.toString()}');
        throw RelationshipException(
          RelationshipErrorCodes.databaseError,
          'Failed to stream pending requests list',
          error,
          RelationshipOperation.getPendingRequestsStream,
        );
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to create pending requests stream: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to create pending requests stream',
        e,
        RelationshipOperation.getPendingRequestsStream,
      );
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream() {
    try {
      final currentUserId = _getCurrentUserId();
      
      return _databaseService.collectionStream(
        collection: _relationshipCollection,
        queryBuilder: (query) => query
            .where('participants', arrayContains: currentUserId)
            .where('status', isEqualTo: RelationshipStatus.blocked.name)
            .where('type', isEqualTo: RelationshipType.friendship.name)
            .where('initiatorId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)  // This will require a composite index!
            .limit(_defaultPageSize), // Limit to 15 blocked users
      ).map((querySnapshot) {
        _logger.d(_tag, 'Blocked users stream: Received ${querySnapshot.docs.length} relationship documents');
        
        final blockedUsersData = <Map<String, dynamic>>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
            
            if (otherUserId.isNotEmpty) {
              blockedUsersData.add({
                'uid': otherUserId,
                'relationshipId': doc.id,
              });
              _logger.d(_tag, 'Blocked users stream: Found blocked user - userId: $otherUserId, relationshipId: ${doc.id}');
            }
          } catch (e) {
            _logger.w(_tag, 'Failed to process blocked user for doc ${doc.id}: ${e.toString()}');
          }
        }
        
        _logger.i(_tag, 'Blocked users stream updated: ${blockedUsersData.length} blocked users');
        return blockedUsersData;
      }).handleError((error) {
        _logger.e(_tag, 'Blocked users stream error: ${error.toString()}');
        throw RelationshipException(
          RelationshipErrorCodes.databaseError,
          'Failed to stream blocked users list',
          error,
          RelationshipOperation.getBlockedUsersStream,
        );
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to create blocked users stream: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to create blocked users stream',
        e,
        RelationshipOperation.getBlockedUsersStream,
      );
    }
  }

  /// Setup user stream subscription for a list of user IDs
  /// This method can be used to get user data streams for UIDs returned from relationship streams
  @override
  Stream<Map<String, Map<String, dynamic>>> setupUserStreamSubscription(List<String> userIds) {
    try {
      if (userIds.isEmpty) {
        return Stream.value(<String, Map<String, dynamic>>{});
      }

      _logger.d(_tag, 'Setting up user stream subscription for ${userIds.length} users');

      // Create a StreamController to manage the combined stream
      late StreamController<Map<String, Map<String, dynamic>>> controller;
      late List<StreamSubscription> subscriptions;
      Map<String, Map<String, dynamic>> currentUserData = {};

      void updateAndEmit() {
        if (!controller.isClosed) {
          controller.add(Map.from(currentUserData));
        }
      }

      controller = StreamController<Map<String, Map<String, dynamic>>>(
        onListen: () {
          subscriptions = userIds.map((userId) {
            return _userService.getUserDataStream(userId).listen(
              (userData) {
                currentUserData[userId] = userData?.toMap() ?? <String, dynamic>{};
                updateAndEmit();
              },
              onError: (error) {
                _logger.w(_tag, 'Error in user stream for $userId: $error');
                // Keep existing data for this user and continue
                if (!currentUserData.containsKey(userId)) {
                  currentUserData[userId] = <String, dynamic>{};
                }
                updateAndEmit();
              },
            );
          }).toList();
        },
        onCancel: () {
          for (final subscription in subscriptions) {
            subscription.cancel();
          }
        },
      );

      return controller.stream.handleError((error) {
        _logger.e(_tag, 'User stream subscription error: ${error.toString()}');
        throw RelationshipException(
          RelationshipErrorCodes.databaseError,
          'Failed to stream user data',
          error,
          RelationshipOperation.searchUser,
        );
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to setup user stream subscription: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to setup user stream subscription',
        e,
        RelationshipOperation.searchUser,
      );
    }
  }

  // Helper methods

  /// Get relationship between two users
  Future<RelationshipModel?> _getRelationshipBetweenUsers(String userId1, String userId2) async {
    try {
      final participants = RelationshipModel.sortParticipants([userId1, userId2]);
      
      final results = await _databaseService.queryDocuments(
        collection: _relationshipCollection,
        conditions: [
          {'field': 'participants', 'operator': '==', 'value': participants},
          {'field': 'type', 'operator': '==', 'value': RelationshipType.friendship.name},
        ],
      );

      if (results.isEmpty) return null;

      final relationshipData = results.first;
      return RelationshipModel.fromMap(relationshipData, relationshipData['id']);
    } catch (e) {
      _logger.e(_tag, 'Failed to get relationship between users: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to check relationship status',
        e,
      );
    }
  }

  /// Get relationship by ID
  Future<RelationshipModel?> _getRelationshipById(String relationshipId) async {
    try {
      final relationshipData = await _databaseService.getDocument(
        collection: _relationshipCollection,
        documentId: relationshipId,
      );

      if (relationshipData == null) return null;

      return RelationshipModel.fromMap(relationshipData, relationshipId);
    } catch (e) {
      _logger.e(_tag, 'Failed to get relationship by ID: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to get relationship data',
        e,
      );
    }
  }

  /// Update relationship within transaction
  Future<void> _updateRelationshipInTransaction(
    Transaction transaction,
    String relationshipId,
    Map<String, dynamic> updates,
  ) async {
    final docRef = _databaseService.firestoreInstance
        .collection(_relationshipCollection)
        .doc(relationshipId);
    
    transaction.update(docRef, {
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete relationship within transaction
  Future<void> _deleteRelationshipInTransaction(
    Transaction transaction,
    String relationshipId,
  ) async {
    _logger.d(_tag, 'Creating delete transaction for relationship: $relationshipId');
    final docRef = _databaseService.firestoreInstance
        .collection(_relationshipCollection)
        .doc(relationshipId);
    
    _logger.d(_tag, 'Executing delete operation on document: ${docRef.path}');
    transaction.delete(docRef);
    _logger.d(_tag, 'Delete operation added to transaction');
  }

  /// Send friend request notification
  Future<void> _sendFriendRequestNotification(String fromUserId, String toUserId) async {
    try {
      final currentUserProfile = await _userService.getUserData(fromUserId);
      if (currentUserProfile != null) {
        _notificationsService.sendNotification(
          recipientUid: toUserId,
          title: 'Friend Request',
          body: '${currentUserProfile.displayName ?? 'Someone'} wants to be your friend',
          data: {
            'type': 'friend_request',
            'sender_name': currentUserProfile.displayName ?? 'Someone',
            'sender_id': fromUserId,
          },
        );
      }
    } catch (e) {
      _logger.w(_tag, 'Failed to send friend request notification: ${e.toString()}');
    }
  }

  /// Send friend accepted notification
  Future<void> _sendFriendAcceptedNotification(String fromUserId, String toUserId) async {
    try {
      final currentUserProfile = await _userService.getUserData(fromUserId);
      if (currentUserProfile != null) {
        _notificationsService.sendNotification(
          recipientUid: toUserId,
          title: 'Friend Request Accepted',
          body: '${currentUserProfile.displayName ?? 'Someone'} accepted your friend request',
          data: {
            'type': 'friend_accepted',
            'sender_name': currentUserProfile.displayName ?? 'Someone',
            'sender_id': fromUserId,
          },
        );
      }
    } catch (e) {
      _logger.w(_tag, 'Failed to send friend accepted notification: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    try {
      _logger.d(_tag, 'Searching for user by UID: $uid');
      
      // Prevent users from searching themselves
      final currentUserId = _getCurrentUserId();
      if (uid == currentUserId) {
        _logger.d(_tag, 'User cannot search for themselves: $uid');
        return null;
      }
      
      // Query the users collection directly for this UID
      final userData = await _databaseService.getDocument(
        collection: 'users',
        documentId: uid,
      );
      
      if (userData == null) {
        _logger.d(_tag, 'User not found for UID: $uid');
        return null;
      }
      
      // Return only displayName, photoURL, and uid (no email or isOnline)
      final result = {
        'uid': uid,
        'displayName': userData['displayName'] as String?,
        'photoURL': userData['photoURL'] as String?,
      };
      
      _logger.i(_tag, 'User found for UID: $uid, displayName: ${result['displayName']}');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to search user by UID: ${e.toString()}');
      throw RelationshipException(
        RelationshipErrorCodes.databaseError,
        'Failed to search for user',
        e,
        RelationshipOperation.searchUser,
      );
    }
  }
}
