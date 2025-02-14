import 'package:duckbuck/Home/service/friend_service.dart';
import 'package:flutter/foundation.dart';
import 'package:duckbuck/Authentication/service/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FriendService _friendService = FriendService();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  bool _isLoading = false;
  final Map<String, StreamSubscription<DocumentSnapshot>> _friendListeners = {};

  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get friendRequests => _friendRequests;
  bool get isLoading => _isLoading;

  Future<void> initFriendsListener() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await _authService.getCurrentUserData();
        if (userData == null || userData['uid'] == null) return;

        _friendService
            .getFriendsStream(userData['uid'])
            .listen((friendsList) async {
          final List<Map<String, dynamic>> acceptedFriends = [];
          final List<Map<String, dynamic>> requests = [];

          for (var friend in friendsList) {
            _listenToFriendProfile(
                friend['uid']); // Start listening to friend's profile

            final details = await _friendService.fetchDetails(friend['uid']);
            final enrichedFriend = {
              ...friend,
              'name': details['name'],
              'photoURL': details['photoURL'],
            };

            if (friend['status'] == 'accepted') {
              acceptedFriends.add(enrichedFriend);
            } else if (friend['status'] == 'pending') {
              requests.add(enrichedFriend);
            }
          }

          _friends = acceptedFriends;
          _friendRequests = requests;
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('Error setting up friends listener: $e');
    }
  }

  void _listenToFriendProfile(String friendUid) {
    if (_friendListeners.containsKey(friendUid))
      return; // Avoid duplicate listeners

    final StreamSubscription<DocumentSnapshot> subscription = FirebaseFirestore
        .instance
        .collection('users')
        .doc(friendUid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        _removeFriendFromList(friendUid); // Friend deleted their account
        return;
      }

      final updatedName = doc.data()?['name'];
      final updatedPhotoURL = doc.data()?['photoURL'];
      _updateFriendDetails(friendUid, updatedName, updatedPhotoURL);
    });

    _friendListeners[friendUid] = subscription;
  }

  void _updateFriendDetails(
      String friendUid, String? newName, String? newPhotoURL) {
    bool updated = false;

    // Update accepted friends
    for (var friend in _friends) {
      if (friend['uid'] == friendUid) {
        if (friend['name'] != newName || friend['photoURL'] != newPhotoURL) {
          friend['name'] = newName ?? friend['name'];
          friend['photoURL'] = newPhotoURL ?? friend['photoURL'];
          updated = true;
        }
      }
    }

    // Update friend requests
    for (var request in _friendRequests) {
      if (request['uid'] == friendUid) {
        if (request['name'] != newName || request['photoURL'] != newPhotoURL) {
          request['name'] = newName ?? request['name'];
          request['photoURL'] = newPhotoURL ?? request['photoURL'];
          updated = true;
        }
      }
    }

    if (updated) notifyListeners(); // Ensure UI updates when data changes
  }

  void _removeFriendFromList(String friendUid) {
    _friends.removeWhere((friend) => friend['uid'] == friendUid);
    _friendListeners[friendUid]?.cancel();
    _friendListeners.remove(friendUid);
    notifyListeners();
  }

  @override
  void dispose() {
    for (var sub in _friendListeners.values) {
      sub.cancel();
    }
    _friendListeners.clear();
    super.dispose();
  }

  Future<String> sendFriendRequest(String friendUid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await _authService.getCurrentUserData();
      if (userData == null || userData['uid'] == null) {
        return 'User not authenticated';
      }

      final result = await _friendService.sendFriendRequest(
        userData['uid'],
        friendUid,
      );

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Failed to send friend request';
    }
  }

  Future<void> acceptFriendRequest(String senderUid) async {
    final userData = await _authService.getCurrentUserData();
    if (userData == null || userData['uid'] == null) return;

    await _friendService.acceptFriendRequest(senderUid, userData['uid']);
  }

  Future<void> removeFriend(String friendUid) async {
    final userData = await _authService.getCurrentUserData();
    if (userData == null || userData['uid'] == null) return;

    await _friendService.removeFriend(userData['uid'], friendUid);
    _removeFriendFromList(friendUid);
  }
}
