import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/friend_service.dart';

class FriendProvider with ChangeNotifier {
  final FriendService _friendService = FriendService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize streams for current user
  void initializeFriendStreams(String currentUserId) {
    // Listen to friends stream
    _friendService.getFriendsStream(currentUserId).listen((friendsList) async {
      _friends = [];
      _pendingRequests = [];

      for (var friend in friendsList) {
        // Listen to each friend's user document for real-time updates
        _firestore
            .collection('users')
            .doc(friend['uid'])
            .snapshots()
            .listen((friendDoc) {
          if (friendDoc.exists) {
            final friendData = friendDoc.data() ?? {};
            final updatedFriend = {
              ...friend,
              'name': friendData['name'] ?? 'Unknown',
              'photoURL': friendData['photoURL'] ?? '',
              'lastSeen': friendData['lastSeen'],
              'isOnline': friendData['isOnline'] ?? false,
            };

            // Update friends or pending requests list based on status
            if (friend['status'] == 'accepted') {
              _updateFriendInList(updatedFriend);
            } else if (friend['status'] == 'pending') {
              _updatePendingRequest(updatedFriend);
            }
          }
        });
      }
    });
  }

  // Helper method to update a friend in the friends list
  void _updateFriendInList(Map<String, dynamic> updatedFriend) {
    final index = _friends.indexWhere((f) => f['uid'] == updatedFriend['uid']);
    if (index != -1) {
      _friends[index] = updatedFriend;
    } else {
      _friends.add(updatedFriend);
    }
    notifyListeners();
  }

  // Helper method to update a pending request
  void _updatePendingRequest(Map<String, dynamic> updatedRequest) {
    final index = _pendingRequests.indexWhere((r) => r['uid'] == updatedRequest['uid']);
    if (index != -1) {
      _pendingRequests[index] = updatedRequest;
    } else {
      _pendingRequests.add(updatedRequest);
    }
    notifyListeners();
  }

  // Send friend request
  Future<String> sendFriendRequest(String currentUserId, String friendId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _friendService.sendFriendRequest(currentUserId, friendId);
      return result;
    } catch (e) {
      _error = e.toString();
      return 'Failed to send friend request';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String currentUserId, String friendId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _friendService.acceptFriendRequest(friendId, currentUserId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove friend
  Future<void> removeFriend(String currentUserId, String friendId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _friendService.removeFriend(currentUserId, friendId);
      
      // Remove from local lists
      _friends.removeWhere((friend) => friend['uid'] == friendId);
      _pendingRequests.removeWhere((request) => request['uid'] == friendId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check friend status
  Future<String> checkFriendStatus(String currentUserId, String friendId) async {
    try {
      return await _friendService.checkFriendStatus(currentUserId, friendId);
    } catch (e) {
      _error = e.toString();
      return 'Error checking friend status';
    }
  }

  // Clear provider data (useful when logging out)
  void clear() {
    _friends = [];
    _pendingRequests = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}