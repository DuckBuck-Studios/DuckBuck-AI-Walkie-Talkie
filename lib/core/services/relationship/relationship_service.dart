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
        await _deleteRelationshipInTransaction(transaction, relationship.id);

        _logger.i(_tag, 'Friend removed: ${relationship.id}');
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
      
      // Create stream for accepted relationships where current user is a participant
      return _databaseService.collectionStream(
        collection: _relationshipCollection,
        queryBuilder: (query) => query
            .where('participants', arrayContains: currentUserId)
            .where('status', isEqualTo: RelationshipStatus.accepted.name)
            .where('type', isEqualTo: RelationshipType.friendship.name)
            .orderBy('acceptedAt', descending: true) // Order by acceptance date (most recent first)
            .limit(_defaultPageSize), // Limit to 15 friends
      ).asyncExpand((querySnapshot) {
        // Extract friend relationships data
        final friendRelationships = <Map<String, String>>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
            
            if (otherUserId.isNotEmpty) {
              friendRelationships.add({
                'userId': otherUserId,
                'relationshipId': doc.id,
              });
            }
          } catch (e) {
            _logger.w(_tag, 'Failed to process friend relationship for doc ${doc.id}: ${e.toString()}');
          }
        }
        
        // If no friends, return empty stream
        if (friendRelationships.isEmpty) {
          _logger.i(_tag, 'Friends stream updated: 0 friends');
          return Stream.value(<Map<String, dynamic>>[]);
        }
        
        // Create combined user streams for all friends
        return _combineUserStreams(friendRelationships);
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
      
      // Create stream for ALL pending relationships where current user is a participant
      return _databaseService.collectionStream(
        collection: _relationshipCollection,
        queryBuilder: (query) => query
            .where('participants', arrayContains: currentUserId)
            .where('status', isEqualTo: RelationshipStatus.pending.name)
            .where('type', isEqualTo: RelationshipType.friendship.name)
            .orderBy('createdAt', descending: true) // Order by creation date (most recent first)
            .limit(_defaultPageSize), // Limit to 15 pending requests
      ).asyncExpand((querySnapshot) {
        // Extract ALL pending request relationships data (both incoming and outgoing)
        final pendingRelationships = <Map<String, String>>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final initiatorId = data['initiatorId'] as String?;
            final participants = data['participants'] as List<dynamic>?;
            
            if (initiatorId != null && participants != null) {
              // Find the other user (not current user)
              final otherUserId = participants.firstWhere(
                (id) => id != currentUserId,
                orElse: () => null,
              );
              
              if (otherUserId != null) {
                pendingRelationships.add({
                  'userId': otherUserId,
                  'relationshipId': doc.id,
                  'isIncoming': (initiatorId != currentUserId).toString(), // Add direction flag
                  'initiatorId': initiatorId, // Add initiator info for client-side filtering
                });
              }
            }
          } catch (e) {
            _logger.w(_tag, 'Failed to process pending request for doc ${doc.id}: ${e.toString()}');
          }
        }
        
        // If no pending requests, return empty stream
        if (pendingRelationships.isEmpty) {
          _logger.i(_tag, 'Pending requests stream updated: 0 requests');
          return Stream.value(<Map<String, dynamic>>[]);
        }
        
        // Create combined user streams for all pending request users
        return _combineUserStreams(pendingRelationships);
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
      
      // Create stream for blocked relationships where current user is the initiator (blocker)
      return _databaseService.collectionStream(
        collection: _relationshipCollection,
        queryBuilder: (query) => query
            .where('participants', arrayContains: currentUserId)
            .where('status', isEqualTo: RelationshipStatus.blocked.name)
            .where('type', isEqualTo: RelationshipType.friendship.name)
            .where('initiatorId', isEqualTo: currentUserId)
            .orderBy('updatedAt', descending: true) // Order by block date (most recent first)
            .limit(_defaultPageSize), // Limit to 15 blocked users
      ).asyncExpand((querySnapshot) {
        // Extract blocked user relationships data
        final blockedRelationships = <Map<String, String>>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
            
            if (otherUserId.isNotEmpty) {
              blockedRelationships.add({
                'userId': otherUserId,
                'relationshipId': doc.id,
              });
            }
          } catch (e) {
            _logger.w(_tag, 'Failed to process blocked user for doc ${doc.id}: ${e.toString()}');
          }
        }
        
        // If no blocked users, return empty stream
        if (blockedRelationships.isEmpty) {
          _logger.i(_tag, 'Blocked users stream updated: 0 blocked');
          return Stream.value(<Map<String, dynamic>>[]);
        }
        
        // Create combined user streams for all blocked users
        return _combineUserStreams(blockedRelationships);
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
    dynamic transaction,
    String relationshipId,
    Map<String, dynamic> updates,
  ) async {
    await _databaseService.setDocument(
      collection: _relationshipCollection,
      documentId: relationshipId,
      data: updates,
      merge: true,
    );
  }

  /// Delete relationship within transaction
  Future<void> _deleteRelationshipInTransaction(
    dynamic transaction,
    String relationshipId,
  ) async {
    await _databaseService.deleteDocument(
      collection: _relationshipCollection,
      documentId: relationshipId,
    );
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

  /// Combines multiple user streams to provide real-time updates when user profiles change
  Stream<List<Map<String, dynamic>>> _combineUserStreams(List<Map<String, String>> userRelationships) {
    if (userRelationships.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    // Create individual user document streams
    final userStreams = userRelationships.map((userRel) {
      final userId = userRel['userId']!;
      final relationshipId = userRel['relationshipId']!;
      final isIncoming = userRel['isIncoming'];
      final initiatorId = userRel['initiatorId'];
      
      return _databaseService.documentStream(
        collection: 'users',
        documentId: userId,
      ).map((docSnapshot) {
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final userData = docSnapshot.data()!;
          final result = <String, dynamic>{
            'uid': userId,
            'displayName': userData['displayName'] as String?,
            'photoURL': userData['photoURL'] as String?,
            'relationshipId': relationshipId,
          };
          
          // Add metadata fields if they exist (for pending requests)
          if (isIncoming != null) {
            result['isIncoming'] = isIncoming == 'true';
          }
          if (initiatorId != null) {
            result['initiatorId'] = initiatorId;
          }
          
          return result;
        }
        return null;
      });
    }).toList();

    // If only one user, return that stream as a list
    if (userStreams.length == 1) {
      return userStreams.first.map((userData) {
        return userData != null ? [userData] : <Map<String, dynamic>>[];
      });
    }

    // For multiple users, use Stream.combineLatest to combine all streams
    return _combineMultipleStreams(userStreams);
  }

  /// Combines multiple user streams using Stream.combineLatest for real-time updates
  Stream<List<Map<String, dynamic>>> _combineMultipleStreams(List<Stream<Map<String, dynamic>?>> streams) {
    // Use a stream controller to manually manage the combination
    late StreamController<List<Map<String, dynamic>>> controller;
    final List<Map<String, dynamic>?> currentValues = List.filled(streams.length, null);
    final List<StreamSubscription> subscriptions = [];
    
    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        // Subscribe to each stream
        for (int i = 0; i < streams.length; i++) {
          subscriptions.add(
            streams[i].listen(
              (value) {
                currentValues[i] = value;
                // Emit combined result when any stream updates
                final validResults = currentValues.where((v) => v != null).cast<Map<String, dynamic>>().toList();
                if (!controller.isClosed) {
                  controller.add(validResults);
                  _logger.i(_tag, 'Combined user streams updated: ${validResults.length} users');
                }
              },
              onError: (error) {
                if (!controller.isClosed) {
                  controller.addError(error);
                }
              },
            ),
          );
        }
      },
      onCancel: () {
        for (final subscription in subscriptions) {
          subscription.cancel();
        }
      },
    );
    
    return controller.stream;
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
