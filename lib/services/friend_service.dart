import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
   Stream<List<Map<String, dynamic>>> getFriendsStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return [];
      }

      List<dynamic> friends = snapshot.data()?['friends'] ?? [];
      return friends.map<Map<String, dynamic>>((friend) {
        return {
          'uid': friend['uid'],
          'status': friend['status'],
          'type': friend['type'],
        };
      }).toList();
    });
  }
  /// Checks if a user exists in the `users` collection
  Future<bool> userExists(String uid) async {
    try {
      final userSnapshot = await _firestore.collection('users').doc(uid).get();
      return userSnapshot.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  /// Sends a friend request if the receiver UID exists
  Future<String> sendFriendRequest(String senderUid, String receiverUid) async {
  try {
    print('FRIEND SERVICE: Sending friend request from $senderUid to $receiverUid');
    
    // Check if the sender is trying to send a request to themselves
    if (senderUid == receiverUid) {
      print('FRIEND SERVICE: Cannot send friend request to self');
      return 'You cannot send a friend request to yourself.';
    }

    final receiverExists = await userExists(receiverUid);

    if (!receiverExists) {
      print('FRIEND SERVICE: Receiver user does not exist: $receiverUid');
      return 'User does not exist.';
    }

    final senderRef = _firestore.collection('users').doc(senderUid);
    final receiverRef = _firestore.collection('users').doc(receiverUid);

    // First check if request already exists to avoid transaction if unnecessary
    final senderDoc = await senderRef.get();
    if (senderDoc.exists) {
      final List<dynamic> senderFriends = senderDoc.data()?['friends'] ?? [];
      
      // Print all sender's friends for debugging
      print('FRIEND SERVICE: Current sender friends: $senderFriends');
      
      if (senderFriends.any((friend) => 
          friend is Map && 
          friend['uid'] == receiverUid)) {
        print('FRIEND SERVICE: Friend request already exists');
        return 'Friend request already sent or you are already friends.';
      }
    }

    String result = await _firestore.runTransaction<String>((transaction) async {
      print('FRIEND SERVICE: Starting transaction for friend request');
      final senderSnapshot = await transaction.get(senderRef);
      final receiverSnapshot = await transaction.get(receiverRef);

      if (!senderSnapshot.exists) {
        print('FRIEND SERVICE: Sender document not found');
        throw Exception('Your user profile was not found.');
      }
      
      if (!receiverSnapshot.exists) {
        print('FRIEND SERVICE: Receiver document not found');
        throw Exception('Recipient user profile was not found.');
      }

      List<dynamic> senderFriends = senderSnapshot.data()?['friends'] ?? [];
      List<dynamic> receiverFriends = receiverSnapshot.data()?['friends'] ?? [];

      // Check if a request already exists (double check in transaction)
      if (senderFriends.any((friend) => 
          friend is Map && 
          friend['uid'] == receiverUid)) {
        print('FRIEND SERVICE: Friend request already exists (inside transaction)');
        return 'Friend request already sent.';
      }

      // Add to sender's friends list with status 'pending' and type 'sent'
      final senderEntry = {
        'uid': receiverUid,
        'status': 'pending',
        'type': 'sent',
      };
      
      // Add to receiver's friends list with status 'pending' and type 'received'
      final receiverEntry = {
        'uid': senderUid,
        'status': 'pending',
        'type': 'received',
      };
      
      senderFriends.add(senderEntry);
      receiverFriends.add(receiverEntry);

      print('FRIEND SERVICE: Updating sender document with new friends list: $senderFriends');
      print('FRIEND SERVICE: Updating receiver document with new friends list: $receiverFriends');
      
      transaction.update(senderRef, {'friends': senderFriends});
      transaction.update(receiverRef, {'friends': receiverFriends});
      
      print('FRIEND SERVICE: Transaction completed successfully');
      return 'Friend request sent successfully.';
    });

    print('FRIEND SERVICE: Friend request result: $result');
    return result;
  } catch (e) {
    print('FRIEND SERVICE: Error sending friend request: $e');
    return 'Failed to send friend request: ${e.toString()}';
  }
}


  /// Fetches all friend requests for a user, including user details
  Future<List<Map<String, dynamic>>> fetchFriendRequests(String uid, {String? type}) async {
    try {
      final userSnapshot = await _firestore.collection('users').doc(uid).get();

      if (!userSnapshot.exists) {
        return [];
      }

      List<dynamic> friends = userSnapshot.data()?['friends'] ?? [];

      if (type != null) {
        friends = friends.where((friend) => friend['type'] == type).toList();
      }

      // Fetch additional user details for each friend
      List<Map<String, dynamic>> detailedFriends = [];
      for (var friend in friends) {
        final friendUid = friend['uid'];
        final friendSnapshot = await _firestore.collection('users').doc(friendUid).get();

        if (friendSnapshot.exists) {
          final friendData = friendSnapshot.data();
          detailedFriends.add({
            'uid': friendUid,
            'status': friend['status'],
            'type': friend['type'],
            'name': friendData?['name'] ?? 'Unknown',
            'profileUrl': friendData?['photoURL'] ?? '',
          });
        }
      }

      return detailedFriends;
    } catch (e) {
      print('Error fetching friend requests: $e');
      return [];
    }
  }

  /// Accepts a friend request
  Future<void> acceptFriendRequest(String senderUid, String receiverUid) async {
  try {
    final senderRef = _firestore.collection('users').doc(senderUid);
    final receiverRef = _firestore.collection('users').doc(receiverUid);

    await _firestore.runTransaction((transaction) async {
      // First, perform all reads (get operations)
      final receiverSnapshot = await transaction.get(receiverRef);
      final senderSnapshot = await transaction.get(senderRef);

      if (!receiverSnapshot.exists || !senderSnapshot.exists) {
        print('Error: One or both user documents not found.');
        return;
      }

      List<dynamic> receiverFriends = receiverSnapshot.data()?['friends'] ?? [];
      List<dynamic> senderFriends = senderSnapshot.data()?['friends'] ?? [];

      print('Receiver\'s friends before update: $receiverFriends');
      print('Sender\'s friends before update: $senderFriends');

      // Now perform the update logic on receiver's friends list
      bool receiverUpdated = false;
      for (var friend in receiverFriends) {
        if (friend['uid'] == senderUid && friend['status'] == 'pending') {
          friend['status'] = 'accepted';
          friend.remove('type');
          receiverUpdated = true;
          print('Receiver friend updated: $friend');
          break;
        }
      }

      if (!receiverUpdated) {
        print('No matching friend found for $senderUid in receiver\'s friends.');
      }

      // Perform the update on receiver's friends
      transaction.update(receiverRef, {'friends': receiverFriends});

      // Now perform the update logic on sender's friends list
      bool senderUpdated = false;
      for (var friend in senderFriends) {
        if (friend['uid'] == receiverUid && friend['status'] == 'pending') {
          friend['status'] = 'accepted';
          friend.remove('type');
          senderUpdated = true;
          print('Sender friend updated: $friend');
          break;
        }
      }

      if (!senderUpdated) {
        print('No matching friend found for $receiverUid in sender\'s friends.');
      }

      // Perform the update on sender's friends
      transaction.update(senderRef, {'friends': senderFriends});
    });
  } catch (e) {
    print('Error accepting friend request: $e');
  }
}



  /// Checks the friend status
  Future<String> checkFriendStatus(String userUid, String friendUid) async {
    try {
      final userSnapshot = await _firestore.collection('users').doc(userUid).get();

      if (!userSnapshot.exists) {
        return 'User does not exist.';
      }

      List<dynamic> friends = userSnapshot.data()?['friends'] ?? [];

      for (var friend in friends) {
        if (friend['uid'] == friendUid) {
          switch (friend['status']) {
            case 'pending':
              return 'Friend request is pending.';
            case 'rejected':
              return 'Friend request was rejected.';
            case 'accepted':
              return 'You are already friends.';
            default:
              return 'Unknown friend status.';
          }
        }
      }

      return 'No friend request found.';
    } catch (e) {
      print('Error checking friend status: $e');
      return 'Failed to check friend status.';
    }
  }

  /// Removes a friend request or friendship
  Future<void> removeFriend(String uid, String targetUid) async {
  try {
    final userRef = _firestore.collection('users').doc(uid);
    final targetRef = _firestore.collection('users').doc(targetUid);

    await _firestore.runTransaction((transaction) async {
      // Step 1: Read both user and target data first
      final userSnapshot = await transaction.get(userRef);
      final targetSnapshot = await transaction.get(targetRef);

      // Step 2: Perform the updates after both reads are completed
      if (userSnapshot.exists) {
        List<dynamic> userFriends = userSnapshot.data()?['friends'] ?? [];
        userFriends.removeWhere((friend) => friend['uid'] == targetUid);
        transaction.update(userRef, {'friends': userFriends});
      }

      if (targetSnapshot.exists) {
        List<dynamic> targetFriends = targetSnapshot.data()?['friends'] ?? [];
        targetFriends.removeWhere((friend) => friend['uid'] == uid);
        transaction.update(targetRef, {'friends': targetFriends});
      }
    });
  } catch (e) {
    print('Error removing friend: $e');
  }
}
Future<Map<String, dynamic>> fetchDetails(String uid) async {
  try {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return {
      'name': userDoc['name'],
      'photoURL': userDoc['photoURL'],
    };
  } catch (e) {
    print('Error fetching user details: $e');
    return {
      'name': 'Unknown',
      'photoURL': '',
    };
  }
}
}