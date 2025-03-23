import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

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

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Send a friend request to another user
  Future<Map<String, dynamic>> sendFriendRequest(String targetUserId) async {
    if (currentUserId == null) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'errorCode': 'auth/not-authenticated'
      };
    }
    
    // Prevent sending request to self
    if (currentUserId == targetUserId) {
      return {
        'success': false,
        'error': 'Cannot send friend request to yourself',
        'errorCode': 'request/self-request'
      };
    }

    try {
      // Check if the user is blocked by the current user
      final isBlockedByMe = await isUserBlocked(targetUserId);
      if (isBlockedByMe) {
        return {
          'success': false,
          'error': 'Cannot send friend request to a blocked user',
          'errorCode': 'request/blocked-user',
          'blockType': BlockRelationshipType.blockedByMe.toString().split('.').last
        };
      }
      
      // Check if current user is blocked by the target user
      final isBlockedByThem = await isBlockedBy(targetUserId);
      if (isBlockedByThem) {
        return {
          'success': false,
          'error': 'Cannot send friend request as you are blocked by this user',
          'errorCode': 'request/blocked-by-user',
          'blockType': BlockRelationshipType.blockedByThem.toString().split('.').last
        };
      }
      
      // Check if already friends
      final alreadyFriends = await isFriend(targetUserId);
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
          .doc(targetUserId)
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
          .doc(targetUserId)
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

      // Add to sender's outgoing requests
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('outgoingRequests')
          .doc(targetUserId)
          .set({
        'status': FriendRequestStatus.pending.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': currentUserId,
      });

      // Add to receiver's incoming requests
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('incomingRequests')
          .doc(currentUserId)
          .set({
        'status': FriendRequestStatus.pending.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': currentUserId,
      });

      return {
        'success': true,
        'message': 'Friend request sent successfully',
        'targetUserId': targetUserId
      };
    } catch (e) {
      print('Error sending friend request: $e');
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
      // Update status in both users' request collections
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('incomingRequests')
            .doc(senderId)
            .update({
          'status': FriendRequestStatus.accepted.toString().split('.').last,
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedBy': currentUserId,
        }),
        _firestore
            .collection('users')
            .doc(senderId)
            .collection('outgoingRequests')
            .doc(currentUserId)
            .update({
          'status': FriendRequestStatus.accepted.toString().split('.').last,
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedBy': currentUserId,
        }),
      ]);

      // Add to both users' friends lists
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('friends')
            .doc(senderId)
            .set({
          'addedAt': FieldValue.serverTimestamp(),
          'addedBy': currentUserId,
        }),
        _firestore
            .collection('users')
            .doc(senderId)
            .collection('friends')
            .doc(currentUserId)
            .set({
          'addedAt': FieldValue.serverTimestamp(),
          'addedBy': currentUserId,
        }),
      ]);

      // Remove from requests collections
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('incomingRequests')
            .doc(senderId)
            .delete(),
        _firestore
            .collection('users')
            .doc(senderId)
            .collection('outgoingRequests')
            .doc(currentUserId)
            .delete(),
      ]);

      return true;
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  /// Decline a friend request
  Future<bool> declineFriendRequest(String senderId) async {
    if (currentUserId == null) return false;

    try {
      // Update status in both users' request collections
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('incomingRequests')
            .doc(senderId)
            .update({
          'status': FriendRequestStatus.declined.toString().split('.').last,
          'declinedAt': FieldValue.serverTimestamp(),
          'declinedBy': currentUserId,
        }),
        _firestore
            .collection('users')
            .doc(senderId)
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
            .doc(senderId)
            .delete(),
        _firestore
            .collection('users')
            .doc(senderId)
            .collection('outgoingRequests')
            .doc(currentUserId)
            .delete(),
      ]);

      return true;
    } catch (e) {
      print('Error declining friend request: $e');
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(String friendId) async {
    if (currentUserId == null) return false;

    try {
      // Remove from both users' friends lists
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('friends')
            .doc(friendId)
            .delete(),
        _firestore
            .collection('users')
            .doc(friendId)
            .collection('friends')
            .doc(currentUserId)
            .delete(),
      ]);

      return true;
    } catch (e) {
      print('Error removing friend: $e');
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
      // Check if already blocked
      final alreadyBlocked = await isUserBlocked(targetUserId);
      if (alreadyBlocked) {
        return {
          'success': false,
          'error': 'This user is already blocked',
          'errorCode': 'block/already-blocked'
        };
      }
      
      // Check if blocked by the target user
      final blockedByTarget = await isBlockedBy(targetUserId);
      final blockType = blockedByTarget 
          ? BlockRelationshipType.mutualBlock 
          : BlockRelationshipType.blockedByMe;
      
      // Check if they are friends
      final isFriendRelationship = await isFriend(targetUserId);

      // Add to blocked users list for the blocker
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': currentUserId,
        'blockType': blockType.toString().split('.').last,
        'wasFriend': isFriendRelationship,
      });

      // Add to blockedBy list for the blocked user
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('blockedBy')
          .doc(currentUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': currentUserId,
        'blockType': blockType.toString().split('.').last,
        'wasFriend': isFriendRelationship,
      });

      // Remove any existing friend relationship
      if (isFriendRelationship) {
        await removeFriend(targetUserId);
      }

      // Update any existing requests to blocked status
      try {
        await Future.wait([
          _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('outgoingRequests')
              .doc(targetUserId)
              .update({
            'status': FriendRequestStatus.blocked.toString().split('.').last,
            'blockedAt': FieldValue.serverTimestamp(),
            'blockedBy': currentUserId,
          }),
          _firestore
              .collection('users')
              .doc(targetUserId)
              .collection('incomingRequests')
              .doc(currentUserId)
              .update({
            'status': FriendRequestStatus.blocked.toString().split('.').last,
            'blockedAt': FieldValue.serverTimestamp(),
            'blockedBy': currentUserId,
          }),
        ]);
      } catch (e) {
        // It's okay if these fail, they might not exist
        print('Non-critical error updating request docs: $e');
      }

      return {
        'success': true,
        'message': 'User blocked successfully',
        'blockType': blockType.toString().split('.').last,
        'wasFriend': isFriendRelationship,
        'isMutualBlock': blockedByTarget
      };
    } catch (e) {
      print('Error blocking user: $e');
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
      // Check if already reported
      final query = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: currentUserId)
          .where('reportedId', isEqualTo: targetUserId)
          .get();
          
      if (query.docs.isNotEmpty) {
        return {
          'success': false,
          'error': 'You have already reported this user',
          'errorCode': 'report/already-reported',
          'existingReportId': query.docs.first.id
        };
      }
      
      // Check current relationship status
      final isFriendRelationship = await isFriend(targetUserId);
      final isBlockedByMe = await isUserBlocked(targetUserId);
      final isBlockedByThem = await isBlockedBy(targetUserId);
      
      // Create the report
      final reportRef = await _firestore.collection('reports').add({
        'reporterId': currentUserId,
        'reportedId': targetUserId,
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
          await removeFriend(targetUserId);
        }
        
        // Call block user
        blockResult = await blockUser(targetUserId);
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
      };
    } catch (e) {
      print('Error reporting user: $e');
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
      // Remove from both users' request collections
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('outgoingRequests')
            .doc(targetUserId)
            .delete(),
        _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('incomingRequests')
            .doc(currentUserId)
            .delete(),
      ]);

      return true;
    } catch (e) {
      print('Error canceling friend request: $e');
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
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
      final friends = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final friendId = doc.id;
        // Get real-time updates for friend's user document
        final friendDoc = await _firestore.collection('users').doc(friendId).get();
        
        if (friendDoc.exists) {
          final friendData = friendDoc.data()!;
          final statusRef = _realtimeDb.ref().child('userStatus').child(friendId);
          final statusSnapshot = await statusRef.get();
          
          final status = statusSnapshot.value as Map?;
          friends.add({
            'id': friendId,
            'displayName': friendData['displayName'],
            'photoURL': friendData['photoURL'],
            'isOnline': status?['isOnline'] ?? false,
            'statusAnimation': status?['animation'] ?? 'default',
            'lastSeen': status?['timestamp'] ?? 0,
            'addedAt': doc.data()['addedAt'],
          });
        }
      }
      
      return friends;
    });
  }

  /// Get real-time updates for a specific friend
  Stream<Map<String, dynamic>?> getFriendStream(String friendId) {
    if (currentUserId == null) return Stream.value(null);

    // Create a controller to merge the two streams
    final controller = StreamController<Map<String, dynamic>?>();
    
    // Keep track of the latest friend data and status
    Map<String, dynamic>? latestFriendData;
    Map<String, dynamic>? latestStatus;
    
    // Function to emit the combined data
    void emitCombinedData() {
      if (latestFriendData == null) return;
      
      controller.add({
        'id': friendId,
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
        .doc(friendId)
        .snapshots()
        .listen((friendDoc) {
      if (friendDoc.exists) {
        latestFriendData = friendDoc.data()!;
        emitCombinedData();
      } else {
        controller.add(null);
      }
    }, onError: (e) {
      print("Error in friend data stream: $e");
      controller.addError(e);
    });
    
    // Listen to Realtime Database status changes
    final statusRef = _realtimeDb.ref().child('userStatus').child(friendId);
    final statusSubscription = statusRef.onValue.listen((event) {
      print("FriendService: Status update received for $friendId");
      if (event.snapshot.exists) {
        try {
          latestStatus = Map<String, dynamic>.from(event.snapshot.value as Map);
          print("FriendService: New status for $friendId - online: ${latestStatus!['isOnline']}, animation: ${latestStatus!['animation']}");
        } catch (e) {
          print("Error parsing status data: $e");
          latestStatus = null;
        }
      } else {
        print("FriendService: No status data for $friendId (offline)");
        latestStatus = null;
      }
      emitCombinedData();
    }, onError: (e) {
      print("Error in status stream: $e");
    });
    
    // Clean up when the stream is cancelled
    controller.onCancel = () {
      userSubscription.cancel();
      statusSubscription.cancel();
    };
    
    return controller.stream;
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
      // Check if current user has blocked target
      final blockedDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .get();

      // Check if target has blocked current user
      final blockedByDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedBy')
          .doc(targetUserId)
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
      };
    } catch (e) {
      print('Error checking block status: $e');
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
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking if user is friend: $e');
      return false;
    }
  }

  /// Get the status of a friend request
  Future<FriendRequestStatus?> getFriendRequestStatus(String targetUserId) async {
    if (currentUserId == null) return null;

    try {
      // Check both directions of the request
      final requestRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incomingRequests')
          .doc(targetUserId);

      final requestDoc = await requestRef.get();
      if (requestDoc.exists) {
        final status = requestDoc.data()?['status'];
        return FriendRequestStatus.values.firstWhere(
          (e) => e.toString().split('.').last == status,
          orElse: () => FriendRequestStatus.pending,
        );
      }

      return null;
    } catch (e) {
      print('Error getting friend request status: $e');
      return null;
    }
  }

  /// Get stream of blocked users
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream() {
    if (currentUserId == null) return Stream.value([]);

    print("FriendService: Getting blocked users stream for user: $currentUserId");
    
    // Create a controller to handle errors and retries
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    // Set up the stream with retry logic and error handling
    void setupStream() {
      print("FriendService: Setting up blocked users stream");
      
      StreamSubscription? subscription;
      subscription = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .snapshots()
          .asyncMap((snapshot) async {
            print("FriendService: Got ${snapshot.docs.length} blocked users docs");
            final blockedUsers = <Map<String, dynamic>>[];
            
            try {
              for (var doc in snapshot.docs) {
                final userId = doc.id;
                print("FriendService: Processing blocked user: $userId, data: ${doc.data()}");
                
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
                    
                    print("FriendService: Added blocked user to list: $userId");
                  } else {
                    print("FriendService: User document doesn't exist for blocked user: $userId");
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
                } catch (e) {
                  print("FriendService: Error fetching user doc for blocked user $userId: $e");
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
              
              print("FriendService: Returning ${blockedUsers.length} blocked users");
              return blockedUsers;
            } catch (e) {
              print("FriendService: Error processing blocked users: $e");
              throw e;
            }
          })
          .listen(
            (users) {
              // On data, add to the controller
              if (!controller.isClosed) {
                controller.add(users);
              }
            },
            onError: (error) {
              // On error, log and try to recover
              print("FriendService: Error in blocked users stream: $error");
              
              if (!controller.isClosed) {
                // Try to add empty list to avoid breaking UI
                try {
                  controller.add([]);
                } catch (e) {
                  print("FriendService: Error adding empty list to controller: $e");
                }
                
                // Retry after delay
                Future.delayed(Duration(seconds: 5), () {
                  if (!controller.isClosed) {
                    print("FriendService: Retrying blocked users stream setup");
                    subscription?.cancel();
                    setupStream();
                  }
                });
              }
            },
            onDone: () {
              // If the stream is done (should rarely happen), retry
              print("FriendService: Blocked users stream done, retrying");
              if (!controller.isClosed) {
                Future.delayed(Duration(seconds: 2), () {
                  if (!controller.isClosed) {
                    print("FriendService: Restarting blocked users stream");
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
        print("FriendService: Cancelling blocked users stream");
        subscription?.cancel();
      };
    }
    
    // Start the stream
    setupStream();
    
    // Return the controlled stream
    return controller.stream;
  }

  /// Monitor a friend's status in real-time
  Future<bool> monitorFriendStatus(String friendId) async {
    try {
      print("FriendService: Setting up status monitoring for friend: $friendId");
      // This would typically connect to the realtime database to monitor status changes
      // The implementation depends on your existing Firebase setup
      return true;
    } catch (e) {
      print("Error monitoring friend status: $e");
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
        // Check if the user is currently blocked
        final blockStatus = await getBlockStatus(targetUserId);
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
            .doc(targetUserId)
            .delete();

        // Remove from blockedBy collection for the other user
        await _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('blockedBy')
            .doc(currentUserId)
            .delete();

        return {
          'success': true,
          'message': 'User unblocked successfully',
          'userId': targetUserId,
        };
      } catch (e) {
        print('Error in unblock operation: $e');
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
      print('Retrying unblock operation, attempt $retries');
      
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
} 