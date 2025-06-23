import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/repositories/relationship_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/repositories/user_repository.dart';

/// Shared provider for all friends-related functionality
/// Combines HomeProvider and RelationshipProvider into single source of truth
/// All caching and offline functionality is handled by RelationshipRepository
/// Following the same pattern as UserRepository for consistency
class SharedFriendsProvider extends ChangeNotifier {
  final RelationshipRepository _relationshipRepository;
  final UserRepository _userRepository;
  final LoggerService _logger;
  
  static const String _tag = 'SHARED_FRIENDS_PROVIDER';

  // Current state
  String? _currentUserUid;
  bool _isInitialized = false;
  
  // Friends data
  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = false;
  String? _friendsError;
  
  // Pending requests data
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoadingRequests = false;
  String? _requestsError;
  
  // Blocked users data
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoadingBlockedUsers = false;
  String? _blockedUsersError; 
  
  // Stream subscriptions for real-time updates
  StreamSubscription<List<Map<String, dynamic>>>? _friendsStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _requestsStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _blockedUsersStreamSubscription;
  
  /// Creates SharedFriendsProvider with dependency injection
  SharedFriendsProvider({
    RelationshipRepository? relationshipRepository,
    UserRepository? userRepository,
    LoggerService? logger,
  }) : _relationshipRepository = relationshipRepository ?? serviceLocator<RelationshipRepository>(),
       _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  // Getters - Public API
  List<Map<String, dynamic>> get friends => _friends;
  bool get isLoadingFriends => _isLoadingFriends;
  String? get friendsError => _friendsError;
  
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;
  bool get isLoadingRequests => _isLoadingRequests;
  bool get isLoadingPendingRequests => _isLoadingRequests;  // Alias for compatibility
  String? get requestsError => _requestsError;
  
  List<Map<String, dynamic>> get blockedUsers => _blockedUsers;
  bool get isLoadingBlockedUsers => _isLoadingBlockedUsers;
  String? get blockedUsersError => _blockedUsersError;
  
  String? get currentUserUid => _currentUserUid;
  bool get isInitialized => _isInitialized;
  
  // General error getter for UI compatibility
  String? get error => _friendsError ?? _requestsError;

  /// Initialize provider with user ID - lazy loading approach
  /// Only initializes once per app session unless forced
  Future<void> initialize({bool forceRefresh = false}) async {
    if (_isInitialized && !forceRefresh) {
      _logger.d(_tag, 'Already initialized, skipping (use forceRefresh to override)');
      return;
    }

    try {
      _logger.i(_tag, 'Initializing SharedFriendsProvider...');
      
      // Get current user
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      _currentUserUid = currentUser.uid;
      
      // Load data with cache-first approach
      await _loadFriendsWithCaching(forceRefresh: forceRefresh);
      await _loadRequestsWithCaching(forceRefresh: forceRefresh);
      await _loadBlockedUsersWithCaching(forceRefresh: forceRefresh);
      
      // Start real-time streams for updates
      await _startRealtimeStreams();
      
      _isInitialized = true;
      _logger.i(_tag, 'SharedFriendsProvider initialized successfully');
      notifyListeners();
      
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize SharedFriendsProvider: $e');
      _friendsError = 'Failed to initialize friends data';
      _requestsError = 'Failed to initialize requests data';
      _blockedUsersError = 'Failed to initialize blocked users data';
      notifyListeners();
    }
  }

  /// Load friends with smart caching - offline first
  /// Now delegates to RelationshipRepository for caching
  Future<void> _loadFriendsWithCaching({bool forceRefresh = false}) async {
    if (_currentUserUid == null) return;
    
    try {
      _logger.d(_tag, 'Loading friends with caching for user: $_currentUserUid');
      
      _isLoadingFriends = true;
      _friendsError = null;
      notifyListeners();
      
      // Use RelationshipRepository's cached method
      final friendsWithData = await _relationshipRepository.getFriendsWithCaching(
        userId: _currentUserUid!,
        forceRefresh: forceRefresh,
      );
      
      _friends = friendsWithData;
      _isLoadingFriends = false;
      
      _logger.i(_tag, 'Loaded ${friendsWithData.length} friends via repository caching');
      notifyListeners();
      
      // Download photos for friends in background
      _downloadFriendsPhotosInBackground(friendsWithData);
      
    } catch (e) {
      _logger.e(_tag, 'Error loading friends: $e');
      _isLoadingFriends = false;
      _friendsError = 'Failed to load friends';
      notifyListeners();
    }
  }

  /// Load pending requests with smart caching
  /// Now delegates to RelationshipRepository for caching
  Future<void> _loadRequestsWithCaching({bool forceRefresh = false}) async {
    if (_currentUserUid == null) return;
    
    try {
      _logger.d(_tag, 'Loading requests with caching for user: $_currentUserUid');
      
      _isLoadingRequests = true;
      _requestsError = null;
      notifyListeners();
      
      // Use RelationshipRepository's cached method
      final requests = await _relationshipRepository.getPendingRequestsWithCaching(
        userId: _currentUserUid!,
        forceRefresh: forceRefresh,
      );
      
      _pendingRequests = requests;
      _isLoadingRequests = false;
      
      _logger.i(_tag, 'Loaded ${requests.length} requests via repository caching');
      notifyListeners();
      
    } catch (e) {
      _logger.e(_tag, 'Error loading requests: $e');
      _isLoadingRequests = false;
      _requestsError = 'Failed to load requests';
      notifyListeners();
    }
  }

  /// Load blocked users with smart caching
  /// Now delegates to RelationshipRepository for caching
  Future<void> _loadBlockedUsersWithCaching({bool forceRefresh = false}) async {
    if (_currentUserUid == null) return;
    
    try {
      _logger.d(_tag, 'Loading blocked users with caching for user: $_currentUserUid');
      
      _isLoadingBlockedUsers = true;
      _blockedUsersError = null;
      notifyListeners();
      
      // Use RelationshipRepository's cached method
      final blockedUsers = await _relationshipRepository.getBlockedUsersWithCaching(
        userId: _currentUserUid!,
        forceRefresh: forceRefresh,
      );
      
      _blockedUsers = blockedUsers;
      _isLoadingBlockedUsers = false;
      
      _logger.i(_tag, 'Loaded ${blockedUsers.length} blocked users via repository caching');
      notifyListeners();
      
    } catch (e) {
      _logger.e(_tag, 'Error loading blocked users: $e');
      _isLoadingBlockedUsers = false;
      _blockedUsersError = 'Failed to load blocked users';
      notifyListeners();
    }
  }

  /// Start real-time Firebase streams for updates
  /// Similar to UserRepository's stream approach
  Future<void> _startRealtimeStreams() async {
    if (_currentUserUid == null) return;
    
    try {
      _logger.i(_tag, 'Starting real-time streams...');
      
      // Friends stream
      _friendsStreamSubscription?.cancel();
      _friendsStreamSubscription = _relationshipRepository
          .getFriendsStream()
          .listen(
        (friends) async {
          _logger.d(_tag, 'Friends stream update: ${friends.length} friends');
          _friends = friends;
          
          // Download new photos in background
          _downloadFriendsPhotosInBackground(friends);
          
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Friends stream error: $error');
          _friendsError = 'Real-time sync error';
          notifyListeners();
        },
      );
      
      // Requests stream
      _requestsStreamSubscription?.cancel();
      _requestsStreamSubscription = _relationshipRepository
          .getPendingRequestsStream()
          .listen(
        (requests) async {
          _logger.d(_tag, 'Requests stream update: ${requests.length} requests');
          _pendingRequests = requests;
          
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Requests stream error: $error');
          _requestsError = 'Real-time sync error';
          notifyListeners();
        },
      );
      
      // Blocked users stream
      _blockedUsersStreamSubscription?.cancel();
      _blockedUsersStreamSubscription = _relationshipRepository
          .getBlockedUsersStream()
          .listen(
        (blockedUsers) async {
          _logger.d(_tag, 'Blocked users stream update: ${blockedUsers.length} blocked users');
          _blockedUsers = blockedUsers;
          
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Blocked users stream error: $error');
          _blockedUsersError = 'Real-time sync error';
          notifyListeners();
        },
      );
      
    } catch (e) {
      _logger.e(_tag, 'Failed to start real-time streams: $e');
    }
  }

  /// Download friend profile photos in background
  /// Photo caching is now handled by RelationshipRepository
  void _downloadFriendsPhotosInBackground(List<Map<String, dynamic>> friends) {
    // Photo caching is now handled by RelationshipRepository
    // This method is kept for future photo-related logic if needed
    _logger.d(_tag, 'Photo caching is handled by RelationshipRepository for ${friends.length} friends');
  }

   

  /// Public method to refresh data (pull-to-refresh)
  /// Now delegates to RelationshipRepository for caching
  Future<void> refreshData() async {
    if (_currentUserUid == null) return;
    
    _logger.i(_tag, 'Manual refresh requested');
    await _relationshipRepository.refreshAllCachedData(_currentUserUid!);
    
    // Reload data after cache refresh
    await Future.wait([
      _loadFriendsWithCaching(forceRefresh: true),
      _loadRequestsWithCaching(forceRefresh: true), 
      _loadBlockedUsersWithCaching(forceRefresh: true),
    ]);
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String targetUid) async {
    if (_currentUserUid == null) return false;
    
    try {
      _logger.i(_tag, 'Sending friend request to: $targetUid');
      await _relationshipRepository.sendFriendRequest(targetUid);
      
      // Refresh requests to show outgoing request
      await _loadRequestsWithCaching(forceRefresh: true);
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to send friend request: $e');
      return false;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String fromUid) async {
    if (_currentUserUid == null) return false;
    
    try {
      _logger.i(_tag, 'Accepting friend request from: $fromUid');
      _logger.d(_tag, 'Looking for request in ${_pendingRequests.length} pending requests');
      
      // Debug: Log all pending requests
      for (int i = 0; i < _pendingRequests.length; i++) {
        final req = _pendingRequests[i];
        _logger.d(_tag, 'Request $i: uid=${req['uid']}, initiatorId=${req['initiatorId']}, isIncoming=${req['isIncoming']}');
      }
      
      // Find the relationship ID for this request
      // For incoming requests, match by initiatorId (who sent the request)
      // For outgoing requests, match by uid (the other user)
      final request = _pendingRequests.firstWhere(
        (req) {
          final isIncoming = req['isIncoming'] as bool? ?? false;
          if (isIncoming) {
            // For incoming requests, match by initiatorId
            return req['initiatorId'] == fromUid;
          } else {
            // For outgoing requests, match by uid
            return req['uid'] == fromUid;
          }
        },
        orElse: () => {},
      );
      
      if (request.isEmpty) {
        _logger.e(_tag, 'Friend request not found for user: $fromUid');
        _logger.e(_tag, 'Available requests: ${_pendingRequests.map((r) => 'uid=${r['uid']}, initiatorId=${r['initiatorId']}, isIncoming=${r['isIncoming']}').join(', ')}');
        return false;
      }
      
      final relationshipId = request['relationshipId'] as String;
      
      // Accept the request - returns the relationship ID
      final resultId = await _relationshipRepository.acceptFriendRequest(relationshipId);
      
      if (resultId.isNotEmpty) {
        _logger.i(_tag, 'Friend request accepted successfully');
        // Refresh both friends and requests
        await _loadFriendsWithCaching(forceRefresh: true);
        await _loadRequestsWithCaching(forceRefresh: true);
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.e(_tag, 'Failed to accept friend request: $e');
      return false;
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String fromUid) async {
    if (_currentUserUid == null) return false;
    
    try {
      _logger.i(_tag, 'Rejecting friend request from: $fromUid');
      _logger.d(_tag, 'Looking for request in ${_pendingRequests.length} pending requests');
      
      // Find the relationship ID for this request
      // For incoming requests, match by initiatorId (who sent the request)
      // For outgoing requests, match by uid (the other user)
      final request = _pendingRequests.firstWhere(
        (req) {
          final isIncoming = req['isIncoming'] as bool? ?? false;
          if (isIncoming) {
            // For incoming requests, match by initiatorId
            return req['initiatorId'] == fromUid;
          } else {
            // For outgoing requests, match by uid
            return req['uid'] == fromUid;
          }
        },
        orElse: () => {},
      );
      
      if (request.isEmpty) {
        _logger.e(_tag, 'Friend request not found for user: $fromUid');
        _logger.e(_tag, 'Available requests: ${_pendingRequests.map((r) => 'uid=${r['uid']}, initiatorId=${r['initiatorId']}, isIncoming=${r['isIncoming']}').join(', ')}');
        return false;
      }
      
      final relationshipId = request['relationshipId'] as String;
      final success = await _relationshipRepository.rejectFriendRequest(relationshipId);
      
      if (success) {
        // Refresh requests to remove rejected request
        await _loadRequestsWithCaching(forceRefresh: true);
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, 'Failed to reject friend request: $e');
      return false;
    }
  }

  /// Remove friend
  Future<bool> removeFriend(String friendUid) async {
    if (_currentUserUid == null) return false;
    
    try {
      _logger.i(_tag, 'Removing friend: $friendUid');
      final success = await _relationshipRepository.removeFriend(friendUid);
      
      if (success) {
        // Refresh friends list
        await _loadFriendsWithCaching(forceRefresh: true);
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: $e');
      return false;
    }
  }

  /// Cancel an outgoing friend request
  Future<bool> cancelFriendRequest(String relationshipId) async {
    try {
      _logger.i(_tag, 'Cancelling friend request: $relationshipId');
      final success = await _relationshipRepository.cancelFriendRequest(relationshipId);
      
      if (success) {
        // Refresh requests to remove cancelled request
        await _loadRequestsWithCaching(forceRefresh: true);
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, 'Failed to cancel friend request: $e');
      return false;
    }
  }
 
  bool isProcessingAcceptRequest(String relationshipId) {
    return false;  // Simplified for now
  }

  bool isProcessingRejectRequest(String relationshipId) {
    return false;  // Simplified for now
  }

  bool isProcessingCancelRequest(String relationshipId) {
    return false;  // Simplified for now
  }

  /// Block a user
  Future<bool> blockUser(String targetUid) async {
    if (_currentUserUid == null) return false;
    
    try {
      _logger.i(_tag, 'Blocking user: $targetUid');
      await _relationshipRepository.blockUser(targetUid);
      
      // Refresh blocked users and friends data after block
      await _loadBlockedUsersWithCaching(forceRefresh: true);
      await _loadFriendsWithCaching(forceRefresh: true);
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to block user: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String targetUid) async {
    if (_currentUserUid == null) return false;
    
    try {
      _logger.i(_tag, 'Unblocking user: $targetUid');
      final success = await _relationshipRepository.unblockUser(targetUid);
      
      if (success) {
        // Refresh blocked users list
        await _loadBlockedUsersWithCaching(forceRefresh: true);
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, 'Failed to unblock user: $e');
      return false;
    }
  }

  /// Search users by UID
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    try {
      _logger.d(_tag, 'Searching user by UID: $uid');
      return await _relationshipRepository.searchUserByUid(uid);
    } catch (e) {
      _logger.e(_tag, 'Failed to search user: $e');
      return null;
    }
  }

  /// Clear error messages
  void clearErrors() {
    _friendsError = null;
    _requestsError = null;
    _blockedUsersError = null;
    notifyListeners();
  }

  /// Force refresh all data - useful for pull-to-refresh
  Future<void> refresh() async {
    _logger.d(_tag, 'Force refreshing all data...');
    await Future.wait([
      _loadFriendsWithCaching(forceRefresh: true),
      _loadRequestsWithCaching(forceRefresh: true),
      _loadBlockedUsersWithCaching(forceRefresh: true),
    ]);
  }

  /// Optimize memory usage by clearing cached data when not needed
  /// Call this when the app goes to background or user navigates away from friends-related screens
  void optimizeMemory() {
    _logger.d(_tag, 'Optimizing memory usage...');
    
    // Clear error messages
    _friendsError = null;
    _requestsError = null;
    _blockedUsersError = null;
    
    notifyListeners();
  }

  /// Dispose resources and clean up
  @override
  void dispose() {
    _logger.d(_tag, 'Disposing SharedFriendsProvider...');
    
    // Cancel stream subscriptions
    _friendsStreamSubscription?.cancel();
    _requestsStreamSubscription?.cancel();
    _blockedUsersStreamSubscription?.cancel();
    
    // Clear memory-heavy data
    _friends.clear();
    _pendingRequests.clear();
    _blockedUsers.clear();
    
    // Reset state
    _isInitialized = false;
    _currentUserUid = null;
    
    super.dispose();
    _logger.d(_tag, 'SharedFriendsProvider disposed');
  }
}
