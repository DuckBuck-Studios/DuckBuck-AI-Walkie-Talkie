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

/// Service class to handle all friend-related operations
class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Send a friend request to another user
  Future<bool> sendFriendRequest(String targetUserId) async {
    if (currentUserId == null) return false;

    try {
      // Check if user is blocked
      final isBlocked = await isUserBlocked(targetUserId);
      if (isBlocked) return false;

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

      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
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

  /// Block a user
  Future<bool> blockUser(String targetUserId) async {
    if (currentUserId == null) return false;

    try {
      // Add to blocked users list for the blocker
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': currentUserId,
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
      });

      // Remove any existing friend relationship
      await removeFriend(targetUserId);

      // Update any existing requests to blocked status
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

      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  /// Report a user
  Future<bool> reportUser(String targetUserId, String reason) async {
    if (currentUserId == null) return false;

    try {
      // Create the report
      await _firestore.collection('reports').add({
        'reporterId': currentUserId,
        'reportedId': targetUserId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Remove friend relationship if exists
      await removeFriend(targetUserId);

      // Update any existing requests to declined status
      await Future.wait([
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('outgoingRequests')
            .doc(targetUserId)
            .update({
          'status': FriendRequestStatus.declined.toString().split('.').last,
          'declinedAt': FieldValue.serverTimestamp(),
          'declinedBy': currentUserId,
          'reported': true,
        }),
        _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('incomingRequests')
            .doc(currentUserId)
            .update({
          'status': FriendRequestStatus.declined.toString().split('.').last,
          'declinedAt': FieldValue.serverTimestamp(),
          'declinedBy': currentUserId,
          'reported': true,
        }),
      ]);

      return true;
    } catch (e) {
      print('Error reporting user: $e');
      return false;
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
  Future<bool> isUserBlocked(String targetUserId) async {
    if (currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
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
} 