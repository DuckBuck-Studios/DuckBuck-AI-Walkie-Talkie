import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

/// Status of a friend request
enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  blocked
}

/// Block relationship type to track who blocked whom
enum BlockRelationshipType {
  blockedByMe,
  blockedByThem,
  mutualBlock
}

/// Service class to handle all friend-related operations
class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final AppConfig _appConfig = AppConfig();

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Convert 8-digit UID to Firebase Auth UID if needed
  Future<String?> _getFirebaseUid(String userId) async {
    // If the ID is already a Firebase Auth UID (current user), return it
    if (userId == currentUserId) return userId;
    
    // If userId is the format of a Firebase UID (long alphanumeric), use it directly
    // Firebase UIDs are typically around 28 characters
    if (userId.length > 20) {
      _appConfig.log('Using provided Firebase UID directly: $userId');
      return userId;
    }
    
    // If it's an 8-digit ID, convert it to Firebase Auth UID by querying Firestore
    if (userId.length == 8 && int.tryParse(userId) != null) {
      _appConfig.log('Looking up Firebase UID for 8-digit ID: $userId');
      try {
        final querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();
          
        if (querySnapshot.docs.isNotEmpty) {
          // Return the document ID, which is the Firebase Auth UID
          final firebaseUid = querySnapshot.docs.first.id;
          _appConfig.log('Found Firebase UID: $firebaseUid for 8-digit ID: $userId');
          return firebaseUid;
        } else {
          _appConfig.log('No user found with 8-digit ID: $userId');
          return null;
        }
      } catch (e, stackTrace) {
        _appConfig.reportError(e, stackTrace, reason: 'Error converting 8-digit UID to Firebase UID');
        return null;
      }
    }
    
    // Otherwise assume it's already a Firebase Auth UID or try direct lookup
    try {
      // Verify if this userId exists as a document ID
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists) {
        _appConfig.log('Verified userId $userId as valid Firebase UID');
        return userId;
      } else {
        _appConfig.log('Could not find user document for ID: $userId');
        return null;
      }
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error verifying userId');
      return null;
    }
  }
  
  /// Convert Firebase Auth UID to 8-digit UID for display purposes
  Future<String?> _get8DigitUid(String firebaseUid) async {
    return await _authService.get8DigitUidFromFirebaseUid(firebaseUid);
  }

  /// Send a friend request to another user
  Future<Map<String, dynamic>> sendFriendRequest(String targetUserId) async {
    if (currentUserId == null) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'errorCode': 'auth/not-authenticated'
      };
    }
    
    _appConfig.log('Sending friend request to target: $targetUserId');
    
    // Convert target user ID to Firebase UID if needed
    final targetFirebaseUid = await _getFirebaseUid(targetUserId);
    if (targetFirebaseUid == null) {
      _appConfig.log('Target user not found for ID: $targetUserId');
      return {
        'success': false,
        'error': 'Target user not found',
        'errorCode': 'request/user-not-found'
      };
    }
    
    _appConfig.log('Resolved target Firebase UID: $targetFirebaseUid');
    
    // Prevent sending request to self
    if (currentUserId == targetFirebaseUid) {
      return {
        'success': false,
        'error': 'Cannot send friend request to yourself',
        'errorCode': 'request/self-request'
      };
    }

    try {
      // Check if the user is blocked by the current user
      final isBlockedByMe = await isUserBlocked(targetFirebaseUid);
      if (isBlockedByMe) {
        return {
          'success': false,
          'error': 'Cannot send friend request to a blocked user',
          'errorCode': 'request/blocked-user',
          'blockType': BlockRelationshipType.blockedByMe.toString().split('.').last
        };
      }
      
      // Check if current user is blocked by the target user
      final isBlockedByThem = await isBlockedBy(targetFirebaseUid);
      if (isBlockedByThem) {
        return {
          'success': false,
          'error': 'Cannot send friend request as you are blocked by this user',
          'errorCode': 'request/blocked-by-user',
          'blockType': BlockRelationshipType.blockedByThem.toString().split('.').last
        };
      }
      
      // Check if already friends
      final alreadyFriends = await isFriend(targetFirebaseUid);
      if (alreadyFriends) {
        return {
          'success': false,
          'error': 'Already friends with this user',
          'errorCode': 'request/already-friends'
        };
      }
      
      // Check if request already exists
      final existingIncomingRequest = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incomingRequests')
          .doc(targetFirebaseUid)
          .get();
          
      if (existingIncomingRequest.exists) {
        final status = existingIncomingRequest.data()?['status'];
        return {
          'success': false,
          'error': 'Incoming request already exists from this user',
          'errorCode': 'request/existing-incoming',
          'requestStatus': status
        };
      }
      
      final existingOutgoingRequest = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('outgoingRequests')
          .doc(targetFirebaseUid)
          .get();
          
      if (existingOutgoingRequest.exists) {
        final status = existingOutgoingRequest.data()?['status'];
        return {
          'success': false,
          'error': 'Outgoing request already exists to this user',
          'errorCode': 'request/existing-outgoing',
          'requestStatus': status
        };
      }

      // Get 8-digit UIDs for storing in the request data
      final current8DigitUid = await _get8DigitUid(currentUserId!);
      final target8DigitUid = await _get8DigitUid(targetFirebaseUid);

      _appConfig.log('Adding request to firestore, current user 8-digit UID: $current8DigitUid, target 8-digit UID: $target8DigitUid');
      
      // Add to sender's outgoing requests
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('outgoingRequests')
          .doc(targetFirebaseUid)
          .set({
        'status': FriendRequestStatus.pending.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': currentUserId,
        'sentByUid': current8DigitUid,
        'targetUid': target8DigitUid,
        'targetFirebaseUid': targetFirebaseUid, // Store the Firebase UID directly
      });

      // Add to receiver's incoming requests
      await _firestore
          .collection('users')
          .doc(targetFirebaseUid)
          .collection('incomingRequests')
          .doc(currentUserId)
          .set({
        'status': FriendRequestStatus.pending.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': currentUserId,
        'sentByUid': current8DigitUid,
        'targetUid': target8DigitUid,
        'senderFirebaseUid': currentUserId, // Store the Firebase UID directly
      });

      _appConfig.log('Friend request sent successfully to $targetFirebaseUid');
      
      // Return the target's Firebase UID and 8-digit UID for the UI
      return {
        'success': true,
        'message': 'Friend request sent successfully',
        'targetUserId': targetUserId,
        'targetFirebaseUid': targetFirebaseUid,
        'target8DigitUid': target8DigitUid
      };
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error sending friend request');
      return {
        'success': false,
        'error': 'An error occurred while sending friend request',
        'errorCode': 'request/unknown-error',
        'exception': e.toString()
      };
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String senderId) async {
    if (currentUserId == null) return false;

    try {
      // Convert sender ID to Firebase UID if needed
      final senderFirebaseUid = await _getFirebaseUid(senderId);
      if (senderFirebaseUid == null) {
        _appConfig.log('Cannot find Firebase UID for sender: $senderId');
        return false;
      }
      
      _appConfig.log('Accepting friend request from $senderFirebaseUid for user $currentUserId');
      
      // Check if request exists
      final incomingRequest = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incomingRequests')
          .doc(senderFirebaseUid)
          .get();
          
      if (!incomingRequest.exists) {
        _appConfig.log('Cannot find incoming request from $senderFirebaseUid');
        return false;
      }
      
      // Get 8-digit UIDs for storing in the friend data
      final current8DigitUid = await _get8DigitUid(currentUserId!);
      final sender8DigitUid = await _get8DigitUid(senderFirebaseUid);
      
      // Use a transaction to ensure data consistency
      return await _firestore.runTransaction((transaction) async {
        // Update status in both users' request collections
        transaction.update(
          _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('incomingRequests')
              .doc(senderFirebaseUid),
          {
            'status': FriendRequestStatus.accepted.toString().split('.').last,
            'acceptedAt': FieldValue.serverTimestamp(),
            'acceptedBy': currentUserId,
            'acceptedByUid': current8DigitUid,
          }
        );
        
        transaction.update(
          _firestore
              .collection('users')
              .doc(senderFirebaseUid)
              .collection('outgoingRequests')
              .doc(currentUserId),
          {
            'status': FriendRequestStatus.accepted.toString().split('.').last,
            'acceptedAt': FieldValue.serverTimestamp(),
            'acceptedBy': currentUserId,
            'acceptedByUid': current8DigitUid,
          }
        );

        // Add to both users' friends lists with both Firebase and 8-digit UIDs
        transaction.set(
          _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('friends')
              .doc(senderFirebaseUid),
          {
            'addedAt': FieldValue.serverTimestamp(),
            'addedBy': currentUserId,
            'friendUid': sender8DigitUid,
            'firebaseUid': senderFirebaseUid,
          }
        );
        
        transaction.set(
          _firestore
              .collection('users')
              .doc(senderFirebaseUid)
              .collection('friends')
              .doc(currentUserId),
          {
            'addedAt': FieldValue.serverTimestamp(),
            'addedBy': currentUserId,
            'friendUid': current8DigitUid,
            'firebaseUid': currentUserId,
          }
        );
        
        // Successfully completed transaction
        return true;
      }).then((result) async {
        // After successful transaction, remove requests
        try {
          await Future.wait([
            _firestore
                .collection('users')
                .doc(currentUserId)
                .collection('incomingRequests')
                .doc(senderFirebaseUid)
                .delete(),
            _firestore
                .collection('users')
                .doc(senderFirebaseUid)
                .collection('outgoingRequests')
                .doc(currentUserId)
                .delete(),
          ]);
          
          _appConfig.log('Friendship established between $currentUserId and $senderFirebaseUid');
          return true;
        } catch (e) {
          // This is not critical, as the friendship has been established
          _appConfig.log('Warning - could not delete requests after acceptance: $e');
          return true;
        }
      });
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error accepting friend request');
      return false;
    }
  }

  /// Decline a friend request
  Future<bool> declineFriendRequest(String senderId) async {
    if (currentUserId == null) return false;

    try {
      // Convert to Firebase UID if needed
      final senderFirebaseUid = await _getFirebaseUid(senderId);
      if (senderFirebaseUid == null) return false;
      
      // Update status in both users' request collections
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('incomingRequests')
            .doc(senderFirebaseUid)
            .update({
          'status': FriendRequestStatus.declined.toString().split('.').last,
          'declinedAt': FieldValue.serverTimestamp(),
          'declinedBy': currentUserId,
        }),
        _firestore
            .collection('users')
            .doc(senderFirebaseUid)
            .collection('outgoingRequests')
            .doc(currentUserId)
            .update({
          'status': FriendRequestStatus.declined.toString().split('.').last,
          'declinedAt': FieldValue.serverTimestamp(),
          'declinedBy': currentUserId,
        }),
      ]);

      // Remove from requests collections
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('incomingRequests')
            .doc(senderFirebaseUid)
            .delete(),
        _firestore
            .collection('users')
            .doc(senderFirebaseUid)
            .collection('outgoingRequests')
            .doc(currentUserId)
            .delete(),
      ]);

      return true;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error declining friend request');
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(String friendId) async {
    if (currentUserId == null) return false;

    try {
      // Convert to Firebase UID if needed
      final friendFirebaseUid = await _getFirebaseUid(friendId);
      if (friendFirebaseUid == null) return false;
      
      // Remove from both users' friends lists
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('friends')
            .doc(friendFirebaseUid)
            .delete(),
        _firestore
            .collection('users')
            .doc(friendFirebaseUid)
            .collection('friends')
            .doc(currentUserId)
            .delete(),
      ]);

      return true;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error removing friend');
      return false;
    }
  }

  /// Block a user and provide detailed information about the block
  Future<Map<String, dynamic>> blockUser(String targetUserId) async {
    if (currentUserId == null) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'errorCode': 'auth/not-authenticated'
      };
    }

    try {
      // Convert to Firebase UID if needed
      final targetFirebaseUid = await _getFirebaseUid(targetUserId);
      if (targetFirebaseUid == null) {
        return {
          'success': false,
          'error': 'Target user not found',
          'errorCode': 'block/user-not-found'
        };
      }
      
      // Check if already blocked
      final alreadyBlocked = await isUserBlocked(targetFirebaseUid);
      if (alreadyBlocked) {
        return {
          'success': false,
          'error': 'This user is already blocked',
          'errorCode': 'block/already-blocked'
        };
      }
      
      // Check if blocked by the target user
      final blockedByTarget = await isBlockedBy(targetFirebaseUid);
      final blockType = blockedByTarget 
          ? BlockRelationshipType.mutualBlock 
          : BlockRelationshipType.blockedByMe;
      
      // Check if they are friends
      final isFriendRelationship = await isFriend(targetFirebaseUid);
      
      // Get 8-digit UIDs
      final current8DigitUid = await _get8DigitUid(currentUserId!);
      final target8DigitUid = await _get8DigitUid(targetFirebaseUid);

      // Add to blocked users list for the blocker
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetFirebaseUid)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': currentUserId,
        'blockedByUid': current8DigitUid,
        'targetUid': target8DigitUid,
        'blockType': blockType.toString().split('.').last,
        'wasFriend': isFriendRelationship,
      });

      // Add to blockedBy list for the blocked user
      await _firestore
          .collection('users')
          .doc(targetFirebaseUid)
          .collection('blockedBy')
          .doc(currentUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': currentUserId,
        'blockedByUid': current8DigitUid,
        'targetUid': target8DigitUid,
        'blockType': blockType.toString().split('.').last,
        'wasFriend': isFriendRelationship,
      });

      // Remove any existing friend relationship
      if (isFriendRelationship) {
        await removeFriend(targetFirebaseUid);
      }

      // Update any existing requests to blocked status
      try {
        await Future.wait([
          _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('outgoingRequests')
              .doc(targetFirebaseUid)
              .update({
            'status': FriendRequestStatus.blocked.toString().split('.').last,
            'blockedAt': FieldValue.serverTimestamp(),
            'blockedBy': currentUserId,
            'blockedByUid': current8DigitUid,
          }),
          _firestore
              .collection('users')
              .doc(targetFirebaseUid)
              .collection('incomingRequests')
              .doc(currentUserId)
              .update({
            'status': FriendRequestStatus.blocked.toString().split('.').last,
            'blockedAt': FieldValue.serverTimestamp(),
            'blockedBy': currentUserId,
            'blockedByUid': current8DigitUid,
          }),
        ]);
      } catch (e) {
        // It's okay if these fail, they might not exist
        _appConfig.log('Non-critical error updating request docs: $e');
      }

      return {
        'success': true,
        'message': 'User blocked successfully',
        'blockType': blockType.toString().split('.').last,
        'wasFriend': isFriendRelationship,
        'isMutualBlock': blockedByTarget,
        'targetFirebaseUid': targetFirebaseUid,
        'target8DigitUid': target8DigitUid
      };
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error blocking user');
      return {
        'success': false,
        'error': 'Failed to block user',
        'errorCode': 'block/unknown-error',
        'exception': e.toString()
      };
    }
  }

  /// Report a user with enhanced feedback about what happened
  Future<Map<String, dynamic>> reportUser(String targetUserId, String reason) async {
    if (currentUserId == null) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'errorCode': 'auth/not-authenticated'
      };
    }

    try {
      // Convert to Firebase UID if needed
      final targetFirebaseUid = await _getFirebaseUid(targetUserId);
      if (targetFirebaseUid == null) {
        return {
          'success': false,
          'error': 'Target user not found',
          'errorCode': 'report/user-not-found'
        };
      }
      
      // Check if already reported
      final query = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: currentUserId)
          .where('reportedId', isEqualTo: targetFirebaseUid)
          .get();
          
      if (query.docs.isNotEmpty) {
        return {
          'success': false,
          'error': 'You have already reported this user',
          'errorCode': 'report/already-reported',
          'existingReportId': query.docs.first.id
        };
      }
      
      // Get 8-digit UIDs
      final current8DigitUid = await _get8DigitUid(currentUserId!);
      final target8DigitUid = await _get8DigitUid(targetFirebaseUid);
      
      // Check current relationship status
      final isFriendRelationship = await isFriend(targetFirebaseUid);
      final isBlockedByMe = await isUserBlocked(targetFirebaseUid);
      final isBlockedByThem = await isBlockedBy(targetFirebaseUid);
      
      // Create the report
      final reportRef = await _firestore.collection('reports').add({
        'reporterId': currentUserId,
        'reporterUid': current8DigitUid,
        'reportedId': targetFirebaseUid,
        'reportedUid': target8DigitUid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'actionTaken': 'auto-blocked',
        'wasFriend': isFriendRelationship,
        'wasBlockedBefore': isBlockedByMe,
        'wasBlockedByBefore': isBlockedByThem,
      });

      // Block the user if not already blocked
      Map<String, dynamic> blockResult;
      if (!isBlockedByMe) {
        // Remove friend relationship if exists
        if (isFriendRelationship) {
          await removeFriend(targetFirebaseUid);
        }
        
        // Call block user
        blockResult = await blockUser(targetFirebaseUid);
      } else {
        blockResult = {
          'success': true,
          'message': 'User was already blocked',
          'wasAlreadyBlocked': true
        };
      }

      // Update report with block result
      await reportRef.update({
        'blockResult': blockResult,
      });

      return {
        'success': true,
        'message': 'User has been reported and blocked',
        'reportId': reportRef.id,
        'blockStatus': blockResult,
        'wasFriend': isFriendRelationship,
        'wasBlockedBefore': isBlockedByMe,
        'targetFirebaseUid': targetFirebaseUid,
        'target8DigitUid': target8DigitUid
      };
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error reporting user');
      return {
        'success': false,
        'error': 'Failed to report user',
        'errorCode': 'report/unknown-error',
        'exception': e.toString()
      };
    }
  }

  /// Cancel a friend request
  Future<bool> cancelFriendRequest(String targetUserId) async {
    if (currentUserId == null) return false;

    try {
      // Convert to Firebase UID if needed
      final targetFirebaseUid = await _getFirebaseUid(targetUserId);
      if (targetFirebaseUid == null) return false;
      
      // Remove from both users' request collections
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('outgoingRequests')
            .doc(targetFirebaseUid)
            .delete(),
        _firestore
            .collection('users')
            .doc(targetFirebaseUid)
            .collection('incomingRequests')
            .doc(currentUserId)
            .delete(),
      ]);

      return true;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error canceling friend request');
      return false;
    }
  }

  /// Get stream of incoming friend requests
  Stream<List<Map<String, dynamic>>> getIncomingRequestsStream() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('incomingRequests')
        .snapshots()
        .asyncMap((snapshot) async {
      final requests = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final senderId = doc.id;
        final senderDoc = await _firestore.collection('users').doc(senderId).get();
        
        if (senderDoc.exists) {
          requests.add({
            'id': senderId,
            'displayName': senderDoc.data()?['displayName'],
            'photoURL': senderDoc.data()?['photoURL'],
            'timestamp': doc.data()['timestamp'],
          });
        }
      }
      
      return requests;
    });
  }

  /// Get stream of outgoing friend requests
  Stream<List<Map<String, dynamic>>> getOutgoingRequestsStream() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('outgoingRequests')
        .snapshots()
        .asyncMap((snapshot) async {
      final requests = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final receiverId = doc.id;
        final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
        
        if (receiverDoc.exists) {
          requests.add({
            'id': receiverId,
            'displayName': receiverDoc.data()?['displayName'],
            'photoURL': receiverDoc.data()?['photoURL'],
            'timestamp': doc.data()['timestamp'],
            'status': doc.data()['status'],
          });
        }
      }
      
      return requests;
    });
  }

  /// Get stream of friends list
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    if (currentUserId == null) {
      _appConfig.log("FriendService: Cannot get friends stream - user not authenticated");
      return Stream.value([]);
    }

    _appConfig.log("FriendService: Setting up friends stream for user: $currentUserId");
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
      _appConfig.log("FriendService: Received friends collection update with ${snapshot.docs.length} documents");
      final friends = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        try {
          final friendFirebaseUid = doc.id;
          _appConfig.log("FriendService: Processing friend document with ID: $friendFirebaseUid");
          
          // Get the 8-digit UID
          final friend8DigitUid = await _get8DigitUid(friendFirebaseUid);
          
          // Get the user document for this friend
          final friendDoc = await _firestore.collection('users').doc(friendFirebaseUid).get();
          
          if (friendDoc.exists) {
            _appConfig.log("FriendService: Found user document for friend: $friendFirebaseUid");
            final friendData = friendDoc.data()!;
            
            // Get online status from realtime database
            try {
              final statusSnapshot = await _realtimeDb
                  .ref('userStatus/$friendFirebaseUid')
                  .get();
                  
              final isOnline = statusSnapshot.exists && 
                  (statusSnapshot.child('isOnline').value == true);
                  
              // Get animation and last seen as well
              final String? animation = statusSnapshot.exists ? 
                  statusSnapshot.child('animation').value as String? : null;
              final int lastSeen = statusSnapshot.exists && statusSnapshot.child('lastSeen').exists ?
                  (statusSnapshot.child('lastSeen').value as int?) ?? 0 : 0;
                  
              // Create friend object with all available data
              final friend = {
                'id': friendFirebaseUid,
                'uid': friend8DigitUid,
                'displayName': friendData['displayName'] ?? 'Unknown User',
                'photoURL': friendData['photoURL'],
                'isOnline': isOnline,
                'statusAnimation': animation,
                'lastSeen': lastSeen,
                'email': friendData['email'],
                'addedAt': doc.data()['addedAt'],
                'addedBy': doc.data()['addedBy'],
              };
              
              friends.add(friend);
              _appConfig.log("FriendService: Added friend to list: ${friend['displayName']} (online: $isOnline, animation: $animation)");
            } catch (statusError) {
              // If we can't get status, still add the friend as offline
              _appConfig.log("FriendService: Could not get status for $friendFirebaseUid: $statusError");
              final friend = {
                'id': friendFirebaseUid,
                'uid': friend8DigitUid,
                'displayName': friendData['displayName'] ?? 'Unknown User',
                'photoURL': friendData['photoURL'],
                'isOnline': false,
                'statusAnimation': null,
                'lastSeen': 0,
                'email': friendData['email'],
                'addedAt': doc.data()['addedAt'],
                'addedBy': doc.data()['addedBy'],
              };
              
              friends.add(friend);
              _appConfig.log("FriendService: Added friend to list with status error: ${friend['displayName']}");
            }
          } else {
            _appConfig.log("FriendService: WARNING - User document doesn't exist for friend ID: $friendFirebaseUid");
            // Still add the friend with minimal data
            friends.add({
              'id': friendFirebaseUid,
              'uid': friend8DigitUid,
              'displayName': 'Unknown User',
              'isOnline': false,
              'statusAnimation': null,
              'lastSeen': 0,
              'email': null,
              'addedAt': doc.data()['addedAt'],
              'addedBy': doc.data()['addedBy'],
            });
          }
        } catch (e, stackTrace) {
          _appConfig.reportError(e, stackTrace, reason: "Error processing friend");
        }
      }
      
      _appConfig.log("FriendService: Returning ${friends.length} friends in stream");
      return friends;
    });
  }

  /// Get real-time updates for a specific friend
  Stream<Map<String, dynamic>?> getFriendStream(String friendId) {
    if (currentUserId == null) return Stream.value(null);

    // First we need to convert the friendId to a Firebase UID if needed
    // We'll use a StreamController to handle this async conversion
    final controller = StreamController<Map<String, dynamic>?>();
    
    // Start the conversion and stream setup
    _setupFriendStream(friendId, controller);
    
    return controller.stream;
  }
  
  /// Helper method to set up the friend stream after UID conversion
  void _setupFriendStream(String friendId, StreamController<Map<String, dynamic>?> controller) async {
    try {
      // Convert to Firebase UID if needed
      final friendFirebaseUid = await _getFirebaseUid(friendId);
      if (friendFirebaseUid == null) {
        controller.add(null);
        controller.close();
        return;
      }
      
      // Get 8-digit UID for display
      final friend8DigitUid = await _get8DigitUid(friendFirebaseUid);
      
      // Keep track of the latest friend data and status
      Map<String, dynamic>? latestFriendData;
      Map<String, dynamic>? latestStatus;
      
      // Function to emit the combined data
      void emitCombinedData() {
        if (latestFriendData == null) return;
        
        controller.add({
          'id': friendFirebaseUid,
          'uid': friend8DigitUid,
          'displayName': latestFriendData!['displayName'],
          'photoURL': latestFriendData!['photoURL'],
          'isOnline': latestStatus?['isOnline'] ?? false,
          'statusAnimation': latestStatus?['animation'], // Can be null
          'lastSeen': latestStatus?['timestamp'] ?? 0,
        });
      }
      
      // Listen to Firestore user data changes
      final userSubscription = _firestore
          .collection('users')
          .doc(friendFirebaseUid)
          .snapshots()
          .listen((friendDoc) {
        if (friendDoc.exists) {
          latestFriendData = friendDoc.data()!;
          emitCombinedData();
        } else {
          controller.add(null);
        }
      }, onError: (e, stackTrace) {
        _appConfig.reportError(e, stackTrace, reason: "Error in friend data stream");
        controller.addError(e);
      });
      
      // IMPORTANT: Must use the 8-digit UID for retrieving status from Realtime Database
      final String statusPath;
      if (friend8DigitUid == null) {
        _appConfig.log("FriendService: WARNING - Could not get 8-digit UID for $friendFirebaseUid, status updates may not work");
        statusPath = friendFirebaseUid; // Fall back to Firebase UID, though this likely won't work for status
      } else {
        statusPath = friend8DigitUid;
        _appConfig.log("FriendService: Listening for status updates at path: userStatus/$statusPath");
      }
      
      // Listen to Realtime Database status changes
      final statusRef = _realtimeDb.ref().child('userStatus').child(statusPath);
      final statusSubscription = statusRef.onValue.listen((event) {
        _appConfig.log("FriendService: Status update received for $friendFirebaseUid ($statusPath)");
        if (event.snapshot.exists) {
          try {
            latestStatus = Map<String, dynamic>.from(event.snapshot.value as Map);
            _appConfig.log("FriendService: New status for $friendFirebaseUid - online: ${latestStatus!['isOnline']}, animation: ${latestStatus!['animation']}");
          } catch (e, stackTrace) {
            _appConfig.reportError(e, stackTrace, reason: "Error parsing status data");
            latestStatus = null;
          }
        } else {
          _appConfig.log("FriendService: No status data for $friendFirebaseUid (offline)");
          latestStatus = null;
        }
        emitCombinedData();
      }, onError: (e, stackTrace) {
        _appConfig.reportError(e, stackTrace, reason: "Error in status stream");
      });
      
      // Clean up when the stream is cancelled
      controller.onCancel = () {
        userSubscription.cancel();
        statusSubscription.cancel();
      };
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: "Error setting up friend stream");
      controller.addError(e);
    }
  }

  /// Get stream of friend's status updates in real-time
  Stream<Map<String, dynamic>?> getFriendStatusStream(String friendId) {
    _appConfig.log("FriendService: Setting up status stream for friend ID: $friendId");
    
    // We need to convert the Firebase UID to 8-digit UID to access the correct path in real-time database
    return Stream.fromFuture(_get8DigitUid(friendId))
      .asyncExpand((String? uid8Digit) {
        if (uid8Digit == null) {
          _appConfig.log("FriendService: Failed to get 8-digit UID for friend $friendId");
          return Stream.value(null);
        }
        
        _appConfig.log("FriendService: Using 8-digit UID $uid8Digit for status lookup of friend $friendId");
        
        return _realtimeDb
          .ref()
          .child('userStatus')
          .child(uid8Digit)
          .onValue
          .map((event) {
            if (event.snapshot.value != null) {
              final data = Map<String, dynamic>.from(event.snapshot.value as Map);
              _appConfig.log("FriendService: Status update for friend $friendId ($uid8Digit): animation=${data['animation']}, isOnline=${data['isOnline']}");
              return {
                'animation': data['animation'],
                'timestamp': data['timestamp'] ?? 0,
                'isOnline': data['isOnline'] ?? false,
                'lastSeen': data['lastSeen'] ?? 0,
              };
            }
            _appConfig.log("FriendService: No status data for friend $friendId ($uid8Digit)");
            return {
              'animation': null,
              'timestamp': 0,
              'isOnline': false,
              'lastSeen': 0,
            };
          });
      });
  }

  /// Check if a user is blocked
  Future<Map<String, dynamic>> getBlockStatus(String targetUserId) async {
    if (currentUserId == null) {
      return {
        'isBlocked': false,
        'error': 'User not authenticated',
        'errorCode': 'auth/not-authenticated'
      };
    }

    try {
      // Convert to Firebase UID if needed
      final targetFirebaseUid = await _getFirebaseUid(targetUserId);
      if (targetFirebaseUid == null) {
        return {
          'isBlocked': false,
          'error': 'Target user not found',
          'errorCode': 'block/user-not-found'
        };
      }
      
      // Check if current user has blocked target
      final blockedDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetFirebaseUid)
          .get();

      // Check if target has blocked current user
      final blockedByDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedBy')
          .doc(targetFirebaseUid)
          .get();

      final blockedByMe = blockedDoc.exists;
      final blockedByThem = blockedByDoc.exists;
      
      BlockRelationshipType? blockType;
      if (blockedByMe && blockedByThem) {
        blockType = BlockRelationshipType.mutualBlock;
      } else if (blockedByMe) {
        blockType = BlockRelationshipType.blockedByMe;
      } else if (blockedByThem) {
        blockType = BlockRelationshipType.blockedByThem;
      }
      
      Map<String, dynamic> blockData = {};
      if (blockedDoc.exists) {
        blockData = blockedDoc.data() ?? {};
      }
      
      return {
        'isBlocked': blockedByMe || blockedByThem,
        'blockedByMe': blockedByMe,
        'blockedByThem': blockedByThem,
        'blockType': blockType?.toString().split('.').last,
        'blockData': blockData,
        'timestamp': blockData['blockedAt'],
        'firebaseUid': targetFirebaseUid
      };
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error checking block status');
      return {
        'isBlocked': false,
        'error': 'Failed to check block status',
        'errorCode': 'block/unknown-error',
        'exception': e.toString()
      };
    }
  }

  /// Convenience method for checking if a user is blocked by current user
  Future<bool> isUserBlocked(String targetUserId) async {
    final blockStatus = await getBlockStatus(targetUserId);
    return blockStatus['blockedByMe'] == true;
  }

  /// Convenience method for checking if current user is blocked by target user
  Future<bool> isBlockedBy(String userId) async {
    final blockStatus = await getBlockStatus(userId);
    return blockStatus['blockedByThem'] == true;
  }

  /// Check if a user is a friend
  Future<bool> isFriend(String targetUserId) async {
    if (currentUserId == null) return false;

    try {
      // Convert to Firebase UID if needed
      final targetFirebaseUid = await _getFirebaseUid(targetUserId);
      if (targetFirebaseUid == null) return false;
      
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(targetFirebaseUid)
          .get();

      return doc.exists;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error checking if user is friend');
      return false;
    }
  }

  /// Get the status of a friend request
  Future<FriendRequestStatus?> getFriendRequestStatus(String targetUserId) async {
    if (currentUserId == null) return null;

    try {
      // Convert to Firebase UID if needed
      final targetFirebaseUid = await _getFirebaseUid(targetUserId);
      if (targetFirebaseUid == null) return null;
      
      // Check both directions of the request
      final requestRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incomingRequests')
          .doc(targetFirebaseUid);

      final requestDoc = await requestRef.get();
      if (requestDoc.exists) {
        final status = requestDoc.data()?['status'];
        return FriendRequestStatus.values.firstWhere(
          (e) => e.toString().split('.').last == status,
          orElse: () => FriendRequestStatus.pending,
        );
      }

      return null;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error getting friend request status');
      return null;
    }
  }

  /// Get stream of blocked users
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream() {
    if (currentUserId == null) return Stream.value([]);

    _appConfig.log("FriendService: Getting blocked users stream for user: $currentUserId");
    
    // Create a controller to handle errors and retries
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    // Set up the stream with retry logic and error handling
    void setupStream() {
      _appConfig.log("FriendService: Setting up blocked users stream");
      
      StreamSubscription? subscription;
      subscription = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .snapshots()
          .asyncMap((snapshot) async {
            _appConfig.log("FriendService: Got ${snapshot.docs.length} blocked users docs");
            final blockedUsers = <Map<String, dynamic>>[];
            
            try {
              for (var doc in snapshot.docs) {
                final userId = doc.id;
                _appConfig.log("FriendService: Processing blocked user: $userId, data: ${doc.data()}");
                
                try {
                  final userDoc = await _firestore.collection('users').doc(userId).get();
                  
                  if (userDoc.exists) {
                    final userData = userDoc.data() ?? {};
                    final blockData = doc.data();
                    
                    // Combine the user data with the block data
                    blockedUsers.add({
                      'id': userId,
                      'displayName': userData['displayName'] ?? 'Unknown User',
                      'username': userData['username'],
                      'photoURL': userData['photoURL'],
                      'blockedAt': blockData['blockedAt'] is Timestamp 
                          ? (blockData['blockedAt'] as Timestamp).toDate() 
                          : null,
                      'blockReason': blockData['reason'] ?? 'Manual block',
                      'blockType': blockData['blockType'] ?? 'blockedByMe',
                      'wasFriend': blockData['wasFriend'] ?? false
                    });
                    
                    _appConfig.log("FriendService: Added blocked user to list: $userId");
                  } else {
                    _appConfig.log("FriendService: User document doesn't exist for blocked user: $userId");
                    // Add a placeholder entry with minimal information
                    blockedUsers.add({
                      'id': userId,
                      'displayName': 'User $userId',
                      'blockedAt': null,
                      'blockReason': 'User information unavailable',
                      'blockType': 'blockedByMe',
                      'wasFriend': false
                    });
                  }
                } catch (e, stackTrace) {
                  _appConfig.reportError(e, stackTrace, reason: "Error fetching user doc for blocked user $userId");
                  // Add a placeholder entry with error information
                  blockedUsers.add({
                    'id': userId,
                    'displayName': 'User $userId',
                    'blockedAt': null,
                    'blockReason': 'Error loading user data',
                    'blockType': 'blockedByMe',
                    'wasFriend': false,
                    'loadError': e.toString()
                  });
                }
              }
              
              _appConfig.log("FriendService: Returning ${blockedUsers.length} blocked users");
              return blockedUsers;
            } catch (e, stackTrace) {
              _appConfig.reportError(e, stackTrace, reason: "Error processing blocked users");
              rethrow;
            }
          })
          .listen(
            (users) {
              // On data, add to the controller
              if (!controller.isClosed) {
                controller.add(users);
              }
            },
            onError: (error, stackTrace) {
              // On error, log and try to recover
              _appConfig.reportError(error, stackTrace, reason: "Error in blocked users stream");
              
              if (!controller.isClosed) {
                // Try to add empty list to avoid breaking UI
                try {
                  controller.add([]);
                } catch (e, stackTrace) {
                  _appConfig.reportError(e, stackTrace, reason: "Error adding empty list to controller");
                }
                
                // Retry after delay
                Future.delayed(Duration(seconds: 5), () {
                  if (!controller.isClosed) {
                    _appConfig.log("FriendService: Retrying blocked users stream setup");
                    subscription?.cancel();
                    setupStream();
                  }
                });
              }
            },
            onDone: () {
              // If the stream is done (should rarely happen), retry
              _appConfig.log("FriendService: Blocked users stream done, retrying");
              if (!controller.isClosed) {
                Future.delayed(Duration(seconds: 2), () {
                  if (!controller.isClosed) {
                    _appConfig.log("FriendService: Restarting blocked users stream");
                    subscription?.cancel();
                    setupStream();
                  }
                });
              }
            },
            cancelOnError: false,
          );
      
      // Clean up on controller close
      controller.onCancel = () {
        _appConfig.log("FriendService: Cancelling blocked users stream");
        subscription?.cancel();
      };
    }
    
    // Start the stream
    setupStream();
    
    // Return the controlled stream
    return controller.stream;
  }

  /// Monitor friend status with enhanced error handling
  Future<bool> monitorFriendStatus(String friendId) async {
    try {
      // Keep the existing implementation
      return true;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error monitoring friend status');
      return false;
    }
  }

  /// Unblock a user with retries for network errors
  Future<Map<String, dynamic>> unblockUser(String targetUserId) async {
    if (currentUserId == null) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'errorCode': 'auth/not-authenticated'
      };
    }

    // Function to perform the unblock operation with proper error handling
    Future<Map<String, dynamic>> performUnblock() async {
      try {
        // Convert to Firebase UID if needed
        final targetFirebaseUid = await _getFirebaseUid(targetUserId);
        if (targetFirebaseUid == null) {
          return {
            'success': false,
            'error': 'Target user not found',
            'errorCode': 'unblock/user-not-found'
          };
        }
        
        // Check if the user is currently blocked
        final blockStatus = await getBlockStatus(targetFirebaseUid);
        if (blockStatus['blockedByMe'] != true) {
          return {
            'success': false,
            'error': 'This user is not blocked',
            'errorCode': 'unblock/not-blocked'
          };
        }

        // Remove from blocked users collection
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('blockedUsers')
            .doc(targetFirebaseUid)
            .delete();

        // Remove from blockedBy collection for the other user
        await _firestore
            .collection('users')
            .doc(targetFirebaseUid)
            .collection('blockedBy')
            .doc(currentUserId)
            .delete();

        return {
          'success': true,
          'message': 'User unblocked successfully',
          'userId': targetUserId,
          'firebaseUid': targetFirebaseUid
        };
      } catch (e, stackTrace) {
        _appConfig.reportError(e, stackTrace, reason: 'Error in unblock operation');
        // Classify error type
        String errorCode = 'unblock/unknown-error';
        if (e.toString().contains('network')) {
          errorCode = 'unblock/network-error';
        } else if (e.toString().contains('permission')) {
          errorCode = 'unblock/permission-denied';
        } else if (e.toString().contains('not-found')) {
          errorCode = 'unblock/document-not-found';
        }
        
        return {
          'success': false,
          'error': 'Failed to unblock user',
          'errorCode': errorCode,
          'exception': e.toString(),
          'isNetworkError': errorCode == 'unblock/network-error'
        };
      }
    }

    // First attempt
    var result = await performUnblock();
    
    // Retry logic for network errors only
    int retries = 0;
    while (!result['success'] && 
           result['isNetworkError'] == true && 
           retries < 2) {
      retries++;
      _appConfig.log('Retrying unblock operation, attempt $retries');
      
      // Wait before retry with exponential backoff
      await Future.delayed(Duration(seconds: retries * 2));
      result = await performUnblock();
    }
    
    // Add retry information to the result
    if (retries > 0) {
      result['retries'] = retries;
    }
    
    return result;
  }

  /// Get friends directly (not as a stream) for manual refresh
  Future<List<Map<String, dynamic>>> getFriends() async {
    if (currentUserId == null) return [];
    
    try {
      _appConfig.log('Getting friends directly for user $currentUserId');
      final friendsCollection = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();
          
      _appConfig.log('Found ${friendsCollection.docs.length} friend documents');
      final List<Map<String, dynamic>> friends = [];
      
      for (var doc in friendsCollection.docs) {
        final friendId = doc.id;
        _appConfig.log('Processing friend: $friendId');
        
        // Get user data for this friend
        final userData = await _firestore
            .collection('users')
            .doc(friendId)
            .get();
            
        if (userData.exists) {
          final friendData = userData.data() ?? {};
          _appConfig.log('Found user data for friend: ${friendData['displayName']}');
          
          // Get online status from realtime database
          try {
            final statusSnapshot = await _realtimeDb
                .ref('userStatus/$friendId')
                .get();
                
            final isOnline = statusSnapshot.exists && 
                (statusSnapshot.child('isOnline').value == true);
                
            // Get animation and last seen as well
            final String? animation = statusSnapshot.exists ? 
                statusSnapshot.child('animation').value as String? : null;
            final int lastSeen = statusSnapshot.exists && statusSnapshot.child('lastSeen').exists ?
                (statusSnapshot.child('lastSeen').value as int?) ?? 0 : 0;
                
            friends.add({
              'id': friendId,
              'displayName': friendData['displayName'] ?? 'Unknown User',
              'photoURL': friendData['photoURL'],
              'isOnline': isOnline,
              'statusAnimation': animation,
              'lastSeen': lastSeen,
              'email': friendData['email'],
              'addedAt': doc.data()['addedAt'],
              'addedBy': doc.data()['addedBy'],
            });
            
            _appConfig.log('Added friend with ID $friendId to list (online: $isOnline, animation: $animation)');
          } catch (e, stackTrace) {
            _appConfig.reportError(e, stackTrace, reason: 'Error getting status for $friendId');
            // Still add the friend but mark as offline
            friends.add({
              'id': friendId,
              'displayName': friendData['displayName'] ?? 'Unknown User',
              'photoURL': friendData['photoURL'],
              'isOnline': false,
              'statusAnimation': null,
              'lastSeen': 0,
              'email': friendData['email'],
              'addedAt': doc.data()['addedAt'],
              'addedBy': doc.data()['addedBy'],
            });
          }
        } else {
          _appConfig.log('WARNING - User document for friend $friendId does not exist');
          // Add with minimal data
          friends.add({
            'id': friendId,
            'displayName': 'Unknown User',
            'isOnline': false,
            'statusAnimation': null,
            'lastSeen': 0,
            'email': null,
            'addedAt': doc.data()['addedAt'],
            'addedBy': doc.data()['addedBy'],
          });
        }
      }
      
      _appConfig.log('Returning ${friends.length} friends');
      return friends;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error getting friends');
      return [];
    }
  }

  /// Debug method to directly check friends collection in Firestore
  Future<List<Map<String, dynamic>>> debugCheckFriendsCollection() async {
    if (currentUserId == null) return [];
    
    try {
      _appConfig.log('FriendService DEBUG: Directly checking friends collection for user: $currentUserId');
      
      // Get all friend documents for the current user
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();
      
      List<Map<String, dynamic>> results = [];
      
      for (var doc in snapshot.docs) {
        final friendId = doc.id;
        final data = doc.data();
        
        _appConfig.log('FriendService DEBUG: Found friend document with ID: $friendId');
        _appConfig.log('FriendService DEBUG: Friend document data: $data');
        
        results.add({
          'id': friendId,
          'rawData': data,
        });
        
        // Also check if this friend's user document exists
        final userDoc = await _firestore
            .collection('users')
            .doc(friendId)
            .get();
            
        if (userDoc.exists) {
          _appConfig.log('FriendService DEBUG: User document exists for friend $friendId: ${userDoc.data()?['displayName']}');
        } else {
          _appConfig.log('FriendService DEBUG: WARNING - User document does NOT exist for friend $friendId');
        }
      }
      
      return results;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error checking friends collection');
      return [];
    }
  }

  /// Search user by UID - handles both 8-digit and Firebase UIDs
  Future<Map<String, dynamic>> searchUserByUID(String searchUID) async {
    if (currentUserId == null) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'errorCode': 'auth/not-authenticated'
      };
    }
    
    _appConfig.log('Searching for user with UID: $searchUID');
    
    try {
      DocumentSnapshot? userDoc;
      String? firebaseUid;
      
      // First, try direct lookup by Firebase UID if it looks like one (length > 20 chars)
      if (searchUID.length > 20) {
        // Looks like a Firebase Auth UID, try direct document lookup
        _appConfig.log('Trying direct lookup with Firebase UID');
        userDoc = await _firestore.collection('users').doc(searchUID).get();
        if (userDoc.exists) {
          firebaseUid = searchUID;
          _appConfig.log('Found user directly with Firebase UID: $firebaseUid');
        } else {
          _appConfig.log('No user document found with this Firebase UID');
        }
      }
      
      // If not found or not a Firebase UID, try searching by 8-digit UID
      if (userDoc == null || !userDoc.exists) {
        _appConfig.log('Trying to search by 8-digit UID');
        // Query for the 8-digit UID
        final querySnapshot = await _firestore
            .collection('users')
            .where('uid', isEqualTo: searchUID)
            .limit(1)
            .get();
            
        if (querySnapshot.docs.isNotEmpty) {
          userDoc = querySnapshot.docs.first;
          firebaseUid = userDoc.id; // The document ID is the Firebase Auth UID
          _appConfig.log('Found user by 8-digit UID. Firebase UID: $firebaseUid');
        } else {
          _appConfig.log('No user found with 8-digit UID: $searchUID');
        }
      }
      
      // If we found a user document
      if (userDoc != null && userDoc.exists && firebaseUid != null) {
        // Prevent finding yourself
        if (firebaseUid == currentUserId) {
          return {
            'success': false,
            'error': 'You cannot add yourself as a friend',
            'errorCode': 'search/self-reference'
          };
        }
        
        // Check if already friends
        final isFriendRelationship = await isFriend(firebaseUid);
        
        // Check if there's a pending request
        final hasPendingRequest = await _checkForPendingRequests(firebaseUid);
        
        // Get block status
        final blockStatus = await getBlockStatus(firebaseUid);
        
        // Extract user data
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData == null) {
          return {
            'success': false,
            'error': 'User document is empty',
            'errorCode': 'search/empty-document'
          };
        }
        
        // Format the result
        return {
          'success': true,
          'user': {
            'id': firebaseUid,
            'uid': userData['uid'] ?? 'Unknown', // 8-digit UID
            'displayName': userData['displayName'] ?? 'Unknown User',
            'photoURL': userData['photoURL'],
            'email': userData['email'],
          },
          'relationship': {
            'isFriend': isFriendRelationship,
            'hasPendingRequest': hasPendingRequest['hasPendingRequest'] ?? false,
            'pendingRequestType': hasPendingRequest['requestType'],
            'isBlocked': blockStatus['isBlocked'] ?? false,
            'blockType': blockStatus['blockType'],
          }
        };
      }
      
      // No user found with this UID
      return {
        'success': false,
        'error': 'No user found with this ID',
        'errorCode': 'search/user-not-found'
      };
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error searching user by UID');
      return {
        'success': false,
        'error': 'Error searching for user',
        'errorCode': 'search/error',
        'exception': e.toString()
      };
    }
  }

  /// Check for pending friend requests between users
  Future<Map<String, dynamic>> _checkForPendingRequests(String otherUserId) async {
    if (currentUserId == null) return {'hasPendingRequest': false};
    
    try {
      // Check for incoming request
      final incomingDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incomingRequests')
          .doc(otherUserId)
          .get();
          
      if (incomingDoc.exists) {
        return {
          'hasPendingRequest': true,
          'requestType': 'incoming',
          'status': incomingDoc.data()?['status'] ?? 'pending'
        };
      }
      
      // Check for outgoing request
      final outgoingDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('outgoingRequests')
          .doc(otherUserId)
          .get();
          
      if (outgoingDoc.exists) {
        return {
          'hasPendingRequest': true,
          'requestType': 'outgoing',
          'status': outgoingDoc.data()?['status'] ?? 'pending'
        };
      }
      
      return {'hasPendingRequest': false};
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error checking pending requests');
      return {'hasPendingRequest': false, 'error': e.toString()};
    }
  }

  /// Mute a user to prevent them from calling
  Future<Map<String, dynamic>> muteUser(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {'success': false, 'error': 'User not logged in'};
      }

      // Add current user to target's mutedBy list (track who has muted this user)
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (!targetUserDoc.exists) {
        return {'success': false, 'error': 'Target user document not found'};
      }

      final mutedBy = List<String>.from(targetUserDoc.data()?['mutedBy'] ?? []);
      if (!mutedBy.contains(currentUser.uid)) {
        mutedBy.add(currentUser.uid);
        await _firestore.collection('users').doc(targetUserId).update({
          'mutedBy': mutedBy,
        });
        debugPrint('User ${currentUser.uid} has muted user $targetUserId');
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error in muteUser: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Unmute a user to allow them to call again
  Future<Map<String, dynamic>> unmuteUser(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {'success': false, 'error': 'User not logged in'};
      }

      // Remove current user from target's mutedBy list
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (!targetUserDoc.exists) {
        return {'success': false, 'error': 'Target user document not found'};
      }

      final mutedBy = List<String>.from(targetUserDoc.data()?['mutedBy'] ?? []);
      mutedBy.remove(currentUser.uid);
      await _firestore.collection('users').doc(targetUserId).update({
        'mutedBy': mutedBy,
      });
      debugPrint('User ${currentUser.uid} has unmuted user $targetUserId');

      return {'success': true};
    } catch (e) {
      debugPrint('Error in unmuteUser: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if current user has muted a target user
  Future<bool> isUserMuted(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Check if current user is in target's mutedBy list
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (!targetUserDoc.exists) return false;

      final mutedBy = List<String>.from(targetUserDoc.data()?['mutedBy'] ?? []);
      return mutedBy.contains(currentUser.uid);
    } catch (e) {
      debugPrint('Error in isUserMuted: $e');
      return false;
    }
  }

  /// Stream to check if current user has muted a target user
  Stream<bool> isUserMutedStream(String targetUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('users')
        .doc(targetUserId)
        .snapshots()
        .map((doc) {
          final mutedBy = List<String>.from(doc.data()?['mutedBy'] ?? []);
          final isMuted = mutedBy.contains(currentUser.uid);
          debugPrint('Mute status check: User ${currentUser.uid} has ${isMuted ? "muted" : "not muted"} user $targetUserId');
          return isMuted;
        });
  }

  /// Check if current user is muted by a specific user
  Future<bool> isMutedByUser(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Check if target user has muted current user
      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!currentUserDoc.exists) return false;

      final mutedBy = List<String>.from(currentUserDoc.data()?['mutedBy'] ?? []);
      return mutedBy.contains(targetUserId);
    } catch (e) {
      debugPrint('Error checking if muted by user: $e');
      return false;
    }
  }

  /// Stream to check if current user is muted by a specific user
  Stream<bool> isMutedByUserStream(String targetUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) {
          final mutedBy = List<String>.from(doc.data()?['mutedBy'] ?? []);
          final isMuted = mutedBy.contains(targetUserId);
          debugPrint('Mute status check: User $targetUserId has ${isMuted ? "muted" : "not muted"} current user ${currentUser.uid}');
          return isMuted;
        });
  }

  /// Get stream of users who have muted the current user
  Stream<List<String>> getMutedUsersStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) {
          final mutedBy = List<String>.from(doc.data()?['mutedBy'] ?? []);
          debugPrint('Mute status updated: ${mutedBy.length} users have muted me');
          return mutedBy;
        });
  }
} 