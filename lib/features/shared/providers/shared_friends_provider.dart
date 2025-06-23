import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/repositories/relationship_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/database/local_database_service.dart';
import '../../../core/repositories/user_repository.dart';

/// Shared provider for all friends-related functionality
/// Combines HomeProvider and RelationshipProvider into single source of truth
/// Implements smart caching with offline-first loading and photo caching
/// Following the same pattern as UserRepository for consistency
class SharedFriendsProvider extends ChangeNotifier {
  final RelationshipRepository _relationshipRepository;
  final UserRepository _userRepository;
  final LocalDatabaseService _localDb;
  final LoggerService _logger;
  
  static const String _tag = 'SHARED_FRIENDS_PROVIDER';
  
  // Cache configuration - following UserRepository pattern
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  DateTime? _lastFriendsRefresh;
  DateTime? _lastRequestsRefresh;
  
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
  
  // Stream subscriptions for real-time updates
  StreamSubscription<List<Map<String, dynamic>>>? _friendsStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _requestsStreamSubscription;
  
  /// Creates SharedFriendsProvider with dependency injection
  SharedFriendsProvider({
    RelationshipRepository? relationshipRepository,
    UserRepository? userRepository,
    LocalDatabaseService? localDb,
    LoggerService? logger,
  }) : _relationshipRepository = relationshipRepository ?? serviceLocator<RelationshipRepository>(),
       _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _localDb = localDb ?? LocalDatabaseService.instance,
       _logger = logger ?? serviceLocator<LoggerService>();

  // Getters - Public API
  List<Map<String, dynamic>> get friends => _friends;
  bool get isLoadingFriends => _isLoadingFriends;
  String? get friendsError => _friendsError;
  
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;
  bool get isLoadingRequests => _isLoadingRequests;
  bool get isLoadingPendingRequests => _isLoadingRequests;  // Alias for compatibility
  String? get requestsError => _requestsError;
  
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
      
      // Start real-time streams for updates
      await _startRealtimeStreams();
      
      _isInitialized = true;
      _logger.i(_tag, 'SharedFriendsProvider initialized successfully');
      notifyListeners();
      
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize SharedFriendsProvider: $e');
      _friendsError = 'Failed to initialize friends data';
      _requestsError = 'Failed to initialize requests data';
      notifyListeners();
    }
  }

  /// Load friends with smart caching - offline first
  /// Follows UserRepository caching pattern
  Future<void> _loadFriendsWithCaching({bool forceRefresh = false}) async {
    if (_currentUserUid == null) return;
    
    try {
      _logger.d(_tag, 'Loading friends with caching for user: $_currentUserUid');
      
      // Check if we should use cache
      final shouldUseCache = !forceRefresh && _isFriendsCacheValid();
      
      if (shouldUseCache) {
        // Load from cache first (offline-first approach)
        final cachedFriends = await _localDb.getCachedFriends(_currentUserUid!);
        if (cachedFriends.isNotEmpty) {
          _friends = cachedFriends;
          _logger.d(_tag, 'Loaded ${_friends.length} friends from cache');
          notifyListeners();
          
          // Download photos for cached friends in background
          _downloadFriendsPhotosInBackground(_friends);
          return;
        }
      }
      
      // Cache miss or force refresh - load from Firebase
      _isLoadingFriends = true;
      _friendsError = null;
      notifyListeners();
      
      _logger.i(_tag, 'Loading friends from Firebase...');
      final relationships = await _relationshipRepository.getFriendsStream().first;
      
      // Get full user data for each friend relationship
      final friendsWithData = <Map<String, dynamic>>[];
      for (final relationship in relationships) {
        final friendUid = relationship['uid'] as String;
        final relationshipId = relationship['relationshipId'] as String;
        final userData = await _userRepository.getUserData(friendUid);
        if (userData != null) {
          friendsWithData.add({
            'uid': friendUid,
            'relationshipId': relationshipId,
            'userData': userData.toMap(),
          });
        }
      }
      
      _friends = friendsWithData;
      _lastFriendsRefresh = DateTime.now();
      _isLoadingFriends = false;
      
      // Cache the enriched data with user profiles
      await _localDb.cacheFriends(_currentUserUid!, friendsWithData);
      
      _logger.i(_tag, 'Loaded and cached ${friendsWithData.length} friends from Firebase');
      notifyListeners();
      
      // Download photos for new friends in background
      _downloadFriendsPhotosInBackground(friendsWithData);
      
    } catch (e) {
      _logger.e(_tag, 'Error loading friends: $e');
      _isLoadingFriends = false;
      _friendsError = 'Failed to load friends';
      notifyListeners();
      
      // Fallback to cache on error
      try {
        final cachedFriends = await _localDb.getCachedFriends(_currentUserUid!);
        if (cachedFriends.isNotEmpty) {
          _friends = cachedFriends;
          _logger.w(_tag, 'Using cached friends due to load error');
          notifyListeners();
        }
      } catch (cacheError) {
        _logger.e(_tag, 'Failed to load cached friends: $cacheError');
      }
    }
  }

  /// Load pending requests with smart caching
  Future<void> _loadRequestsWithCaching({bool forceRefresh = false}) async {
    if (_currentUserUid == null) return;
    
    try {
      _logger.d(_tag, 'Loading requests with caching for user: $_currentUserUid');
      
      // Check if we should use cache
      final shouldUseCache = !forceRefresh && _isRequestsCacheValid();
      
      if (shouldUseCache) {
        // Load from cache first
        final cachedRequests = await _localDb.getCachedPendingRequests(_currentUserUid!);
        if (cachedRequests.isNotEmpty) {
          _pendingRequests = cachedRequests;
          _logger.d(_tag, 'Loaded ${_pendingRequests.length} requests from cache');
          notifyListeners();
          return;
        }
      }
      
      // Cache miss or force refresh - load from Firebase
      _isLoadingRequests = true;
      _requestsError = null;
      notifyListeners();
      
      _logger.i(_tag, 'Loading requests from Firebase...');
      final requests = await _relationshipRepository.getPendingRequestsStream().first;
      
      _pendingRequests = requests;
      _lastRequestsRefresh = DateTime.now();
      _isLoadingRequests = false;
      
      // Cache the data
      await _localDb.cachePendingRequests(_currentUserUid!, requests);
      
      _logger.i(_tag, 'Loaded and cached ${requests.length} requests from Firebase');
      notifyListeners();
      
    } catch (e) {
      _logger.e(_tag, 'Error loading requests: $e');
      _isLoadingRequests = false;
      _requestsError = 'Failed to load requests';
      notifyListeners();
      
      // Fallback to cache on error
      try {
        final cachedRequests = await _localDb.getCachedPendingRequests(_currentUserUid!);
        if (cachedRequests.isNotEmpty) {
          _pendingRequests = cachedRequests;
          _logger.w(_tag, 'Using cached requests due to load error');
          notifyListeners();
        }
      } catch (cacheError) {
        _logger.e(_tag, 'Failed to load cached requests: $cacheError');
      }
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
          _lastFriendsRefresh = DateTime.now();
          
          // Update cache
          await _localDb.cacheFriends(_currentUserUid!, friends);
          
          // Download new photos
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
          _lastRequestsRefresh = DateTime.now();
          
          // Update cache
          await _localDb.cachePendingRequests(_currentUserUid!, requests);
          
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Requests stream error: $error');
          _requestsError = 'Real-time sync error';
          notifyListeners();
        },
      );
      
    } catch (e) {
      _logger.e(_tag, 'Failed to start real-time streams: $e');
    }
  }

  /// Download friend profile photos in background
  /// Following LocalDatabaseService photo caching pattern
  void _downloadFriendsPhotosInBackground(List<Map<String, dynamic>> friends) {
    for (final friend in friends) {
      final uid = friend['uid'] as String?;
      final photoURL = friend['photoURL'] as String?;
      
      if (uid != null && photoURL != null && photoURL.isNotEmpty) {
        // Download in background without blocking UI
        _localDb.downloadAndCachePhoto(uid, photoURL).then((cachedPath) {
          if (cachedPath != null) {
            _logger.d(_tag, 'Cached photo for friend: $uid');
            // Update friend data with cached photo path
            final friendIndex = _friends.indexWhere((f) => f['uid'] == uid);
            if (friendIndex != -1) {
              _friends[friendIndex]['cachedPhotoPath'] = cachedPath;
              notifyListeners();
            }
          }
        }).catchError((error) {
          _logger.w(_tag, 'Failed to cache photo for friend $uid: $error');
        });
      }
    }
  }

  /// Check if friends cache is still valid
  bool _isFriendsCacheValid() {
    if (_lastFriendsRefresh == null) return false;
    return DateTime.now().difference(_lastFriendsRefresh!) < _cacheValidDuration;
  }

  /// Check if requests cache is still valid
  bool _isRequestsCacheValid() {
    if (_lastRequestsRefresh == null) return false;
    return DateTime.now().difference(_lastRequestsRefresh!) < _cacheValidDuration;
  }

  /// Public method to refresh data (pull-to-refresh)
  Future<void> refreshData() async {
    _logger.i(_tag, 'Manual refresh requested');
    await _loadFriendsWithCaching(forceRefresh: true);
    await _loadRequestsWithCaching(forceRefresh: true);
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
      
      // Find the relationship ID for this request
      final request = _pendingRequests.firstWhere(
        (req) => req['fromUserId'] == fromUid,
        orElse: () => {},
      );
      
      if (request.isEmpty) {
        _logger.e(_tag, 'Friend request not found for user: $fromUid');
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
      
      // Find the relationship ID for this request
      final request = _pendingRequests.firstWhere(
        (req) => req['fromUserId'] == fromUid,
        orElse: () => {},
      );
      
      if (request.isEmpty) {
        _logger.e(_tag, 'Friend request not found for user: $fromUid');
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

  /// Check if a request is being processed (simplified for now)
  /// TODO: Add proper processing state tracking if needed
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
      
      // Refresh friends list to remove blocked user
      await _loadFriendsWithCaching(forceRefresh: true);
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to block user: $e');
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
    notifyListeners();
  }

  /// Force refresh all data - useful for pull-to-refresh
  Future<void> refresh() async {
    _logger.d(_tag, 'Force refreshing all data...');
    await Future.wait([
      _loadFriendsWithCaching(forceRefresh: true),
      _loadRequestsWithCaching(forceRefresh: true),
    ]);
  }

  /// Dispose resources and clean up
  @override
  void dispose() {
    _logger.d(_tag, 'Disposing SharedFriendsProvider...');
    
    // Cancel stream subscriptions
    _friendsStreamSubscription?.cancel();
    _requestsStreamSubscription?.cancel();
    
    super.dispose();
    _logger.d(_tag, 'SharedFriendsProvider disposed');
  }
}
