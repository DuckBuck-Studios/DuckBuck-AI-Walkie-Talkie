import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/friend_service.dart';  
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendProvider with ChangeNotifier {
  final FriendService _friendService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  FriendProvider(this._friendService);
  
  // Friends lists
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
  List<Map<String, dynamic>> _blockedUsers = [];
  
  // For controlling subscriptions
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _incomingRequestsSubscription;
  StreamSubscription? _outgoingRequestsSubscription;
  StreamSubscription? _blockedUsersSubscription;
  final Map<String, StreamSubscription<Map<String, dynamic>?>> _friendStreamSubscriptions = {};
  final Map<String, StreamSubscription<Map<String, dynamic>?>> _friendStatusSubscriptions = {};
  final bool _isLoading = false;
  
  // Loading states for better UI feedback
  bool _isInitializing = false;
  bool _isInitialized = false;
  String? _lastError;
  
  // Getters
  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get incomingRequests => _incomingRequests;
  List<Map<String, dynamic>> get outgoingRequests => _outgoingRequests;
  List<Map<String, dynamic>> get blockedUsers => _blockedUsers;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  // Initialize provider
  Future<bool> initialize() async {
    try {
      _isInitializing = true;
      _lastError = null;
      _safeNotifyListeners();
      
      final success = await _setupSubscriptions();
      _isInitializing = false;
      _isInitialized = success;
      _safeNotifyListeners();
      return success;
    } catch (e) {
      _isInitializing = false;
      _isInitialized = false;
      _lastError = "Failed to initialize: $e";
      _safeNotifyListeners();
      return false;
    }
  }

  // Setup all subscriptions
  Future<bool> _setupSubscriptions() async {
    try {
      await _clearSubscriptions();

      // Setup friends stream
      _friendsSubscription = _friendService.getFriendsStream().listen((friends) {
        _friends = friends;
        _setupFriendStreams(friends);
        _setupFriendStatusStreams(friends);
        _safeNotifyListeners();
      }, onError: (error) {
        print("Error in friends stream: $error");
        _lastError = "Error loading friends: $error";
        _safeNotifyListeners();
      });

      // Setup incoming requests stream
      _incomingRequestsSubscription = _friendService.getIncomingRequestsStream().listen((requests) {
        _incomingRequests = requests;
        _safeNotifyListeners();
      }, onError: (error) {
        print("Error in incoming requests stream: $error");
        _lastError = "Error loading friend requests: $error";
        _safeNotifyListeners();
      });

      // Setup outgoing requests stream
      _outgoingRequestsSubscription = _friendService.getOutgoingRequestsStream().listen((requests) {
        _outgoingRequests = requests;
        _safeNotifyListeners();
      }, onError: (error) {
        print("Error in outgoing requests stream: $error");
        _lastError = "Error loading outgoing requests: $error";
        _safeNotifyListeners();
      });
      
      // Setup blocked users stream
      _blockedUsersSubscription = _friendService.getBlockedUsersStream().listen((users) {
        _blockedUsers = users;
        _safeNotifyListeners();
      }, onError: (error) {
        print("Error in blocked users stream: $error");
        _lastError = "Error loading blocked users: $error";
        _safeNotifyListeners();
      });
      
      return true;
    } catch (e) {
      _lastError = "Failed to set up subscriptions: $e";
      _safeNotifyListeners();
      return false;
    }
  }

  // Setup individual friend status streams
  void _setupFriendStatusStreams(List<Map<String, dynamic>> friends) {
    print("FriendProvider: Setting up status streams for ${friends.length} friends");
    
    // Cancel old status subscriptions
    for (var subscription in _friendStatusSubscriptions.values) {
      subscription.cancel();
    }
    _friendStatusSubscriptions.clear();

    // Setup new status subscriptions
    for (var friend in friends) {
      final friendId = friend['id'];
      if (friendId != null) {
        print("FriendProvider: Setting up status stream for friend: $friendId");
        
        // Get user status stream
        _friendStatusSubscriptions[friendId] = _friendService.getFriendStatusStream(friendId).listen(
          (statusData) async {
            if (statusData != null) {
              print("FriendProvider: Received status update for friend $friendId: ${statusData['animation']}");
              
              // Also get the friend's privacy settings
              final privacySettings = await _getUserPrivacySettings(friendId);
              
              final index = _friends.indexWhere((f) => f['id'] == friendId);
              if (index != -1) {
                _friends[index] = {
                  ..._friends[index],
                  'isOnline': statusData['isOnline'] ?? false,
                  'statusAnimation': statusData['animation'],
                  'lastSeen': statusData['lastSeen'],
                  'privacySettings': privacySettings,
                };
                _safeNotifyListeners();
              }
            }
          },
          onError: (error) {
            print("FriendProvider: Error in friend status stream for $friendId: $error");
          },
        );
      }
    }
  }

  // Helper method to get user privacy settings
  Future<Map<String, dynamic>> _getUserPrivacySettings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (snapshot.exists && snapshot.data() != null) {
        final userData = snapshot.data()!;
        final metadata = userData['metadata'] as Map<String, dynamic>? ?? {};
        
        return {
          'showOnlineStatus': metadata['showOnlineStatus'] ?? true,
          'showLastSeen': metadata['showLastSeen'] ?? true,
          'showSocialLinks': metadata['showSocialLinks'] ?? true,
        };
      }
      
      // Default settings if we can't retrieve them
      return {
        'showOnlineStatus': true,
        'showLastSeen': true,
        'showSocialLinks': true,
      };
    } catch (e) {
      print("FriendProvider: Error getting privacy settings for $userId: $e");
      // Default settings on error
      return {
        'showOnlineStatus': true,
        'showLastSeen': true,
        'showSocialLinks': true,
      };
    }
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
        
        // Get friend's privacy settings
        _getUserPrivacySettings(friendId).then((privacySettings) {
          // Update the friend with privacy settings
          final index = _friends.indexWhere((f) => f['id'] == friendId);
          if (index != -1) {
            _friends[index] = {
              ..._friends[index],
              'privacySettings': privacySettings,
            };
            _safeNotifyListeners();
          }
        });
        
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
                _safeNotifyListeners();
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

  // Send a friend request with enhanced validation
  Future<Map<String, dynamic>> sendFriendRequestWithValidation(String targetUserId) async {
    try {
      // Prevent sending request to self
      if (targetUserId == _friendService.currentUserId) {
        return {
          'success': false,
          'error': 'You cannot add yourself as a friend'
        };
      }
      
      // Check if already friends
      final isAlreadyFriend = await isFriend(targetUserId);
      if (isAlreadyFriend) {
        return {
          'success': false,
          'error': 'This user is already in your friends list'
        };
      }
      
      // Get detailed block status
      final blockStatus = await _friendService.getBlockStatus(targetUserId);
      final isBlocked = blockStatus['blockedByMe'] == true;
      final isBlockedByTarget = blockStatus['blockedByThem'] == true;
      
      if (isBlocked) {
        return {
          'success': false,
          'error': 'You have blocked this user. Unblock them first to send a request.',
          'blockStatus': blockStatus
        };
      }
      
      if (isBlockedByTarget) {
        return {
          'success': false,
          'error': 'Unable to send request to this user',
          'blockStatus': blockStatus,
          'reason': 'You are blocked by this user'
        };
      }
      
      // Check for existing requests
      final hasPendingIncoming = _incomingRequests.any((req) => req['id'] == targetUserId);
      if (hasPendingIncoming) {
        return {
          'success': false,
          'error': 'This user already sent you a request. Check your incoming requests.'
        };
      }
      
      final hasPendingOutgoing = _outgoingRequests.any((req) => req['id'] == targetUserId);
      if (hasPendingOutgoing) {
        return {
          'success': false,
          'error': 'You already sent a request to this user'
        };
      }
      
      // Try to send the request
      final result = await _friendService.sendFriendRequest(targetUserId);
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred while sending the request',
        'exception': e.toString()
      };
    }
  }

  // Accept a friend request with enhanced feedback
  Future<Map<String, dynamic>> acceptFriendRequest(String senderId) async {
    try {
      // First check if we already have this friend to prevent duplicates
      if (_friends.any((friend) => friend['id'] == senderId)) {
        return {
          'success': true,
          'message': 'Already friends with this user'
        };
      }
      
      final result = await _friendService.acceptFriendRequest(senderId);
      
      if (result) {
        // Force immediate refresh of friends lists to ensure UI updates
        await _refreshFriends();
        
        return {
          'success': true,
          'message': 'Friend request accepted successfully'
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to accept friend request'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error accepting friend request: $e'
      };
    }
  }

  // Decline a friend request with enhanced feedback
  Future<Map<String, dynamic>> declineFriendRequest(String senderId) async {
    try {
      final result = await _friendService.declineFriendRequest(senderId);
      if (result) {
        return {
          'success': true,
          'message': 'Friend request declined',
          'friendId': senderId
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to decline friend request'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred while declining the request',
        'exception': e.toString()
      };
    }
  }

  // Remove a friend with enhanced feedback
  Future<Map<String, dynamic>> removeFriend(String friendId) async {
    try {
      final result = await _friendService.removeFriend(friendId);
      if (result) {
        return {
          'success': true,
          'message': 'Friend removed successfully',
          'friendId': friendId
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to remove friend'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred while removing the friend',
        'exception': e.toString()
      };
    }
  }

  // Block a user with enhanced feedback
  Future<Map<String, dynamic>> blockUser(String targetUserId) async {
    try {
      // Check first if they are a friend
      final isFriendRelationship = await isFriend(targetUserId);
      
      // Perform the block operation
      final result = await _friendService.blockUser(targetUserId);
      
      // Add specific messaging for the UI
      if (result['success'] == true) {
        if (isFriendRelationship) {
          result['message'] = 'User blocked and removed from friends';
          result['wasFriend'] = true;
        }
      }
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred while blocking the user',
        'exception': e.toString()
      };
    }
  }

  // Report a user with enhanced feedback
  Future<Map<String, dynamic>> reportUser(String targetUserId, String reason) async {
    try {
      // Check first if they are a friend
      final isFriendRelationship = await isFriend(targetUserId);
      final blockStatus = await _friendService.getBlockStatus(targetUserId);
      
      // Perform the report operation
      final result = await _friendService.reportUser(targetUserId, reason);
      
      // Add additional context to the result
      if (result['success'] == true) {
        result['wasFriend'] = isFriendRelationship;
        result['blockStatus'] = blockStatus;
      }
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred while reporting the user',
        'exception': e.toString()
      };
    }
  }

  // Cancel a friend request with enhanced feedback
  Future<Map<String, dynamic>> cancelFriendRequest(String targetUserId) async {
    try {
      final result = await _friendService.cancelFriendRequest(targetUserId);
      if (result) {
        return {
          'success': true,
          'message': 'Friend request canceled',
          'userId': targetUserId
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to cancel friend request'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred while canceling the request',
        'exception': e.toString()
      };
    }
  }

  // Get detailed block status information
  Future<Map<String, dynamic>> getBlockStatus(String targetUserId) async {
    try {
      return await _friendService.getBlockStatus(targetUserId);
    } catch (e) {
      return {
        'isBlocked': false,
        'error': 'Failed to check block status',
        'exception': e.toString()
      };
    }
  }

  // Check if a user is blocked by the current user
  Future<bool> isUserBlocked(String targetUserId) async {
    try {
      return await _friendService.isUserBlocked(targetUserId);
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  // Check if a user is a friend
  Future<bool> isFriend(String targetUserId) async {
    try {
      return await _friendService.isFriend(targetUserId);
    } catch (e) {
      print('Error checking if user is friend: $e');
      return false;
    }
  }

  // Send a friend request with just boolean feedback
  Future<bool> sendFriendRequest(String targetUserId) async {
    try {
      final result = await sendFriendRequestWithValidation(targetUserId);
      return result['success'] == true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  // Get friend request status
  Future<FriendRequestStatus?> getFriendRequestStatus(String targetUserId) async {
    try {
      return await _friendService.getFriendRequestStatus(targetUserId);
    } catch (e) {
      print('Error getting friend request status: $e');
      return null;
    }
  }

  // Unblock a user
  Future<Map<String, dynamic>> unblockUser(String targetUserId) async {
    try {
      final result = await _friendService.unblockUser(targetUserId);
      
      if (result['success'] == true) {
        // Notify listeners to refresh the UI
        _safeNotifyListeners();
      }
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred while unblocking the user',
        'exception': e.toString()
      };
    }
  }

  // Clear all subscriptions
  Future<void> _clearSubscriptions() async {
    await _friendsSubscription?.cancel();
    _friendsSubscription = null;

    await _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription = null;

    await _outgoingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription = null;

    await _blockedUsersSubscription?.cancel();
    _blockedUsersSubscription = null;

    for (var subscription in _friendStreamSubscriptions.values) {
      await subscription.cancel();
    }
    _friendStreamSubscriptions.clear();

    for (var subscription in _friendStatusSubscriptions.values) {
      await subscription.cancel();
    }
    _friendStatusSubscriptions.clear();
  }

  // Add a method to force refresh friends data
  Future<void> _refreshFriends() async {
    try {
      print("FriendProvider: Manually refreshing friends data");
      // Get updated friends list directly from the service
      final updatedFriends = await _friendService.getFriends();
      
      // Update the internal list
      _friends = updatedFriends;
      
      // Refresh friend streams for the updated list
      _setupFriendStreams(updatedFriends);
      _setupFriendStatusStreams(updatedFriends);
      
      // Notify listeners to update UI
      _safeNotifyListeners();
      
      print("FriendProvider: Friends data refreshed, found ${updatedFriends.length} friends");
    } catch (e) {
      print("FriendProvider: Error refreshing friends data: $e");
    }
  }

  // Safe method to call notifyListeners that won't throw if being disposed
  void _safeNotifyListeners() {
    try {
      notifyListeners();
    } catch (e) {
      print("FriendProvider: Error in notifyListeners: $e");
      // This usually happens when the widget is being disposed
    }
  }

  // Dispose provider
  @override
  void dispose() {
    _clearSubscriptions();
    super.dispose();
  }

  // Force refresh all friends data - including direct database check
  Future<void> forceRefreshFriends() async {
    try {
      print("FriendProvider: FORCE REFRESHING friends data from database");
      
      // First, manually check the friends collection directly
      final friendDocs = await _friendService.debugCheckFriendsCollection();
      print("FriendProvider: Raw friends in database: ${friendDocs.length}");
      
      // Get updated friends through the regular method
      final updatedFriends = await _friendService.getFriends();
      print("FriendProvider: Updated friends count: ${updatedFriends.length}");
      
      // Update the internal list with basic data
      _friends = updatedFriends;
      
      // For each friend, get their privacy settings
      for (int i = 0; i < _friends.length; i++) {
        final friendId = _friends[i]['id'];
        if (friendId != null) {
          try {
            final privacySettings = await _getUserPrivacySettings(friendId);
            _friends[i] = {
              ..._friends[i],
              'privacySettings': privacySettings,
            };
          } catch (e) {
            print("FriendProvider: Error getting privacy settings for $friendId during refresh: $e");
          }
        }
      }
      
      // Refresh friend streams for the updated list
      _setupFriendStreams(updatedFriends);
      _setupFriendStatusStreams(updatedFriends);
      
      // Notify listeners to update UI
      _safeNotifyListeners();
      
      print("FriendProvider: Force refresh completed, found ${updatedFriends.length} friends");
    } catch (e) {
      print("FriendProvider: Error during force refresh: $e");
    }
  }

  Future<Map<String, dynamic>> muteUser(String targetUserId) async {
    try {
      final result = await _friendService.muteUser(targetUserId);
      return result;
    } catch (e) {
      debugPrint('Error muting user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> unmuteUser(String targetUserId) async {
    try {
      final result = await _friendService.unmuteUser(targetUserId);
      return result;
    } catch (e) {
      debugPrint('Error unmuting user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> isUserMuted(String targetUserId) async {
    try {
      return await _friendService.isUserMuted(targetUserId);
    } catch (e) {
      debugPrint('Error checking mute status: $e');
      return false;
    }
  }

  Stream<List<String>> getMutedUsersStream() {
    return _friendService.getMutedUsersStream();
  }

  Future<bool> isMutedByUser(String targetUserId) async {
    try {
      return await _friendService.isMutedByUser(targetUserId);
    } catch (e) {
      debugPrint('Error checking if muted by user: $e');
      return false;
    }
  }

  Stream<bool> isMutedByUserStream(String targetUserId) {
    return _friendService.isMutedByUserStream(targetUserId);
  }

  Stream<bool> isUserMutedStream(String targetUserId) {
    return _friendService.isUserMutedStream(targetUserId);
  }
} 