import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/friend_service.dart'; 

class FriendProvider with ChangeNotifier {
  final FriendService _friendService = FriendService();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _incomingRequestsSubscription;
  StreamSubscription? _outgoingRequestsSubscription;
  Map<String, StreamSubscription> _friendStreamSubscriptions = {};

  // Getters
  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get incomingRequests => _incomingRequests;
  List<Map<String, dynamic>> get outgoingRequests => _outgoingRequests;

  // Initialize provider
  Future<void> initialize() async {
    await _setupSubscriptions();
  }

  // Setup all subscriptions
  Future<void> _setupSubscriptions() async {
    await _clearSubscriptions();

    // Setup friends stream
    _friendsSubscription = _friendService.getFriendsStream().listen((friends) {
      _friends = friends;
      _setupFriendStreams(friends);
      notifyListeners();
    });

    // Setup incoming requests stream
    _incomingRequestsSubscription = _friendService.getIncomingRequestsStream().listen((requests) {
      _incomingRequests = requests;
      notifyListeners();
    });

    // Setup outgoing requests stream
    _outgoingRequestsSubscription = _friendService.getOutgoingRequestsStream().listen((requests) {
      _outgoingRequests = requests;
      notifyListeners();
    });
  }

  // Setup individual friend streams
  void _setupFriendStreams(List<Map<String, dynamic>> friends) {
    print("FriendProvider: Setting up friend streams for ${friends.length} friends");
    
    // Cancel old subscriptions
    for (var subscription in _friendStreamSubscriptions.values) {
      subscription.cancel();
    }
    _friendStreamSubscriptions.clear();

    // Setup new subscriptions
    for (var friend in friends) {
      final friendId = friend['id'];
      if (friendId != null) {
        print("FriendProvider: Setting up stream for friend: $friendId");
        
        // Setup friend data stream
        _friendStreamSubscriptions[friendId] = _friendService.getFriendStream(friendId).listen(
          (updatedFriend) {
            if (updatedFriend != null) {
              print("FriendProvider: Received update for friend $friendId");
              final index = _friends.indexWhere((f) => f['id'] == friendId);
              if (index != -1) {
                _friends[index] = {
                  ..._friends[index],
                  ...updatedFriend,
                };
                notifyListeners();
              }
            }
          },
          onError: (error) {
            print("FriendProvider: Error in friend stream for $friendId: $error");
          },
        );
        
        // Setup status monitoring
        _monitorFriendStatus(friendId);
      }
    }
  }

  // Monitor friend status with enhanced error handling and retry logic
  Future<void> _monitorFriendStatus(String friendId) async {
    print("FriendProvider: Starting status monitoring for friend: $friendId");
    try {
      final isStarted = await _friendService.monitorFriendStatus(friendId);
      if (isStarted) {
        print("FriendProvider: Successfully started status monitoring for $friendId");
      } else {
        print("FriendProvider: Failed to start status monitoring for $friendId");
        // Retry after a delay
        Future.delayed(const Duration(seconds: 5), () {
          _monitorFriendStatus(friendId);
        });
      }
    } catch (e) {
      print("FriendProvider: Error monitoring status for $friendId: $e");
      // Retry after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _monitorFriendStatus(friendId);
      });
    }
  }

  // Start monitoring friend statuses in real-time
  void startStatusMonitoring() {
    print("FriendProvider: Starting status monitoring for all friends");
    
    // Cancel existing status monitoring
    for (var friend in _friends) {
      final friendId = friend['id'];
      if (friendId != null) {
        _monitorFriendStatus(friendId);
      }
    }
  }

  // Send a friend request
  Future<bool> sendFriendRequest(String targetUserId) async {
    return await _friendService.sendFriendRequest(targetUserId);
  }

  // Accept a friend request
  Future<bool> acceptFriendRequest(String senderId) async {
    return await _friendService.acceptFriendRequest(senderId);
  }

  // Decline a friend request
  Future<bool> declineFriendRequest(String senderId) async {
    return await _friendService.declineFriendRequest(senderId);
  }

  // Remove a friend
  Future<bool> removeFriend(String friendId) async {
    return await _friendService.removeFriend(friendId);
  }

  // Block a user
  Future<bool> blockUser(String targetUserId) async {
    return await _friendService.blockUser(targetUserId);
  }

  // Report a user
  Future<bool> reportUser(String targetUserId, String reason) async {
    return await _friendService.reportUser(targetUserId, reason);
  }

  // Cancel a friend request
  Future<bool> cancelFriendRequest(String targetUserId) async {
    return await _friendService.cancelFriendRequest(targetUserId);
  }

  // Check if a user is blocked
  Future<bool> isUserBlocked(String targetUserId) async {
    return await _friendService.isUserBlocked(targetUserId);
  }

  // Check if a user is a friend
  Future<bool> isFriend(String targetUserId) async {
    return await _friendService.isFriend(targetUserId);
  }

  // Get friend request status
  Future<FriendRequestStatus?> getFriendRequestStatus(String targetUserId) async {
    return await _friendService.getFriendRequestStatus(targetUserId);
  }

  // Clear all subscriptions
  Future<void> _clearSubscriptions() async {
    await _friendsSubscription?.cancel();
    _friendsSubscription = null;

    await _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription = null;

    await _outgoingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription = null;

    for (var subscription in _friendStreamSubscriptions.values) {
      await subscription.cancel();
    }
    _friendStreamSubscriptions.clear();
  }

  // Dispose provider
  @override
  void dispose() {
    _clearSubscriptions();
    super.dispose();
  }
} 