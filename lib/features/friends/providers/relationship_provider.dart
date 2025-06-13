import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/repositories/relationship_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/exceptions/relationship_exceptions.dart';

/// Provider for managing relationship state throughout the app
///
/// This provider wraps the RelationshipRepository and provides reactive state management
/// for all relationship-related operations following the app's architecture pattern:
/// UI → Provider → Repository → Service → Database
///
/// Features:
/// - Real-time streams for friends, pending requests, and blocked users
/// - Loading states for all operations
/// - Error handling with user-friendly messages
/// - Analytics tracking through repository layer
/// - Optimistic UI updates where appropriate
class RelationshipProvider extends ChangeNotifier {
  final RelationshipRepository _relationshipRepository;
  final AuthServiceInterface _authService;
  final UserRepository _userRepository;
  final LoggerService _logger;

  static const String _tag = 'RELATIONSHIP_PROVIDER';

  // Stream subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _friendsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingRequestsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _blockedUsersSubscription;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _userDataSubscription;

  // Raw relationship data (UIDs and relationship IDs only)
  List<Map<String, dynamic>> _friendsRelationshipData = [];
  List<Map<String, dynamic>> _pendingRequestsRelationshipData = [];
  List<Map<String, dynamic>> _blockedUsersRelationshipData = [];

  // User data cache (UID -> user data)
  Map<String, Map<String, dynamic>> _userDataCache = {};

  // Combined data for UI (relationship data + user data)
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _blockedUsers = [];

  // Loading states
  bool _isLoadingFriends = false;
  bool _isLoadingPendingRequests = false;
  bool _isLoadingBlockedUsers = false;
  bool _isLoadingOperation = false;

  // Error state
  String? _error;

  // Operation tracking to prevent duplicate requests
  final Set<String> _processingSendRequests = {};
  final Set<String> _processingAcceptRequests = {};
  final Set<String> _processingRejectRequests = {};
  final Set<String> _processingCancelRequests = {}; // Add cancel tracking
  final Set<String> _processingBlockUsers = {};
  final Set<String> _processingUnblockUsers = {};
  final Set<String> _processingRemoveFriends = {};

  /// Creates a new RelationshipProvider
  RelationshipProvider({
    RelationshipRepository? relationshipRepository,
    AuthServiceInterface? authService,
    UserRepository? userRepository,
    LoggerService? logger,
  }) : _relationshipRepository = relationshipRepository ?? serviceLocator<RelationshipRepository>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>(),
       _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  /// List of friends (accepted relationships)
  List<Map<String, dynamic>> get friends => List.unmodifiable(_friends);

  /// List of pending friend requests (received by current user)
  List<Map<String, dynamic>> get pendingRequests => List.unmodifiable(_pendingRequests);

  /// List of blocked users
  List<Map<String, dynamic>> get blockedUsers => List.unmodifiable(_blockedUsers);

  /// Loading state for friends list
  bool get isLoadingFriends => _isLoadingFriends;

  /// Loading state for pending requests
  bool get isLoadingPendingRequests => _isLoadingPendingRequests;

  /// Loading state for blocked users
  bool get isLoadingBlockedUsers => _isLoadingBlockedUsers;

  /// Loading state for operations (send request, accept, etc.)
  bool get isLoadingOperation => _isLoadingOperation;

  /// Current error message, null if no error
  String? get error => _error;

  /// Current user UID from UserRepository
  String? get currentUserUid => _userRepository.currentUser?.uid;

  /// Whether a send request operation is processing for a specific user
  bool isProcessingSendRequest(String userId) => _processingSendRequests.contains(userId);

  /// Whether an accept request operation is processing for a specific relationship
  bool isProcessingAcceptRequest(String relationshipId) => _processingAcceptRequests.contains(relationshipId);

  /// Whether a reject request operation is processing for a specific relationship
  bool isProcessingRejectRequest(String relationshipId) => _processingRejectRequests.contains(relationshipId);

  /// Whether a cancel request operation is processing for a specific relationship
  bool isProcessingCancelRequest(String relationshipId) => _processingCancelRequests.contains(relationshipId);

  /// Whether a block user operation is processing for a specific user
  bool isProcessingBlockUser(String userId) => _processingBlockUsers.contains(userId);

  /// Whether an unblock user operation is processing for a specific user
  bool isProcessingUnblockUser(String userId) => _processingUnblockUsers.contains(userId);

  /// Whether a remove friend operation is processing for a specific user
  bool isProcessingRemoveFriend(String userId) => _processingRemoveFriends.contains(userId);

  // ==========================================================================
  // INITIALIZATION & CLEANUP
  // ==========================================================================

  /// Initialize the provider and set up real-time streams
  Future<void> initialize() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _logger.w(_tag, 'Cannot initialize RelationshipProvider: user not authenticated');
      return;
    }

    _logger.i(_tag, 'Initializing RelationshipProvider for user: ${currentUser.uid}');
    
    await _setupStreams();
    
    _logger.i(_tag, 'RelationshipProvider initialized successfully');
  }

  /// Set up real-time streams for relationship data
  Future<void> _setupStreams() async {
    try {
      // Setup friends stream
      _isLoadingFriends = true;
      notifyListeners();

      _friendsSubscription?.cancel();
      _friendsSubscription = _relationshipRepository.getFriendsStream().listen(
        (friendsRelationshipData) {
          _logger.d(_tag, 'Friends relationship stream updated: ${friendsRelationshipData.length} friends');
          _friendsRelationshipData = friendsRelationshipData;
          _updateUserSubscription();
          _combineFriendsData();
          _isLoadingFriends = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Error in friends stream: ${error.toString()}');
          _error = _getErrorMessage(error);
          _isLoadingFriends = false;
          notifyListeners();
        },
      );

      // Setup pending requests stream
      _isLoadingPendingRequests = true;
      notifyListeners();

      _pendingRequestsSubscription?.cancel();
      _pendingRequestsSubscription = _relationshipRepository.getPendingRequestsStream().listen(
        (pendingRelationshipData) {
          _logger.d(_tag, 'Pending requests relationship stream updated: ${pendingRelationshipData.length} requests');
          _pendingRequestsRelationshipData = pendingRelationshipData;
          _updateUserSubscription();
          _combinePendingRequestsData();
          _isLoadingPendingRequests = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Error in pending requests stream: ${error.toString()}');
          _error = _getErrorMessage(error);
          _isLoadingPendingRequests = false;
          notifyListeners();
        },
      );

      // Setup blocked users stream
      _isLoadingBlockedUsers = true;
      notifyListeners();

      _blockedUsersSubscription?.cancel();
      _blockedUsersSubscription = _relationshipRepository.getBlockedUsersStream().listen(
        (blockedRelationshipData) {
          _logger.d(_tag, 'Blocked users relationship stream updated: ${blockedRelationshipData.length} blocked users');
          _blockedUsersRelationshipData = blockedRelationshipData;
          _updateUserSubscription();
          _combineBlockedUsersData();
          _isLoadingBlockedUsers = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Error in blocked users stream: ${error.toString()}');
          _error = _getErrorMessage(error);
          _isLoadingBlockedUsers = false;
          notifyListeners();
        },
      );

    } catch (e) {
      _logger.e(_tag, 'Failed to setup streams: ${e.toString()}');
      _error = _getErrorMessage(e);
      _isLoadingFriends = false;
      _isLoadingPendingRequests = false;
      _isLoadingBlockedUsers = false;
      notifyListeners();
    }
  }

  /// Close all active streams (used during signout)
  /// This is different from dispose() - it closes streams but keeps the provider usable
  void closeStreams() {
    _logger.d(_tag, 'Closing all RelationshipProvider streams (signout cleanup)');
    
    // Cancel all stream subscriptions
    _friendsSubscription?.cancel();
    _friendsSubscription = null;
    
    _pendingRequestsSubscription?.cancel();
    _pendingRequestsSubscription = null;
    
    _blockedUsersSubscription?.cancel();
    _blockedUsersSubscription = null;
    
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    
    // Clear data but keep the provider functional for potential re-initialization
    _friendsRelationshipData.clear();
    _pendingRequestsRelationshipData.clear();
    _blockedUsersRelationshipData.clear();
    _userDataCache.clear();
    _friends.clear();
    _pendingRequests.clear();
    _blockedUsers.clear();
    
    // Reset loading states
    _isLoadingFriends = false;
    _isLoadingPendingRequests = false;
    _isLoadingBlockedUsers = false;
    _error = null;
    
    _logger.i(_tag, 'All RelationshipProvider streams closed and data cleared');
    
    // Notify listeners of the cleared state
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.d(_tag, 'Disposing RelationshipProvider');
    closeStreams();
    super.dispose();
  }

  /// Update user data subscription based on all current UIDs
  void _updateUserSubscription() {
    // Collect all unique UIDs from all relationship streams
    final Set<String> allUids = {};
    
    // Add UIDs from friends
    for (final friend in _friendsRelationshipData) {
      final uid = friend['uid'] as String?;
      if (uid != null) allUids.add(uid);
    }
    
    // Add UIDs from pending requests
    for (final request in _pendingRequestsRelationshipData) {
      final uid = request['uid'] as String?;
      if (uid != null) allUids.add(uid);
    }
    
    // Add UIDs from blocked users
    for (final blocked in _blockedUsersRelationshipData) {
      final uid = blocked['uid'] as String?;
      if (uid != null) allUids.add(uid);
    }
    
    // Only update subscription if we have UIDs to subscribe to
    if (allUids.isNotEmpty) {
      _logger.d(_tag, 'Updating user subscription for ${allUids.length} unique UIDs');
      
      _userDataSubscription?.cancel();
      _userDataSubscription = _relationshipRepository.setupUserStreamSubscription(allUids.toList()).listen(
        (userData) {
          _logger.d(_tag, 'User data stream updated: ${userData.length} users');
          _logger.d(_tag, 'Received user data: $userData');
          _userDataCache = userData;
          
          // Recombine all data whenever user data updates
          _combineFriendsData();
          _combinePendingRequestsData();
          _combineBlockedUsersData();
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Error in user data stream: ${error.toString()}');
          // Don't set _error here as this is a secondary stream
          // Relationship streams will continue to work without user data
        },
      );
    } else {
      _logger.d(_tag, 'No UIDs to subscribe to, clearing user data subscription');
      _userDataSubscription?.cancel();
      _userDataCache.clear();
    }
  }

  /// Combine friends relationship data with user data
  void _combineFriendsData() {
    _friends = _friendsRelationshipData.map((relationshipData) {
      final uid = relationshipData['uid'] as String;
      final userData = _userDataCache[uid] ?? {};
      
      _logger.d(_tag, 'Combining friend data for UID: $uid');
      _logger.d(_tag, 'Relationship data: $relationshipData');
      _logger.d(_tag, 'User data from cache: $userData');
      
      final combinedData = {
        ...relationshipData, // uid, relationshipId
        ...userData, // displayName, photoURL, etc.
      };
      
      _logger.d(_tag, 'Combined data result: $combinedData');
      
      return combinedData;
    }).toList();
    
    _logger.d(_tag, 'Combined friends data: ${_friends.length} friends with user data');
    _logger.d(_tag, 'User data cache contains ${_userDataCache.length} users: ${_userDataCache.keys}');
  }

  /// Combine pending requests relationship data with user data
  void _combinePendingRequestsData() {
    _pendingRequests = _pendingRequestsRelationshipData.map((relationshipData) {
      final uid = relationshipData['uid'] as String;
      final userData = _userDataCache[uid] ?? {};
      
      return {
        ...relationshipData, // uid, relationshipId, isIncoming, initiatorId
        ...userData, // displayName, photoURL, etc.
      };
    }).toList();
    
    _logger.d(_tag, 'Combined pending requests data: ${_pendingRequests.length} requests with user data');
  }

  /// Combine blocked users relationship data with user data
  void _combineBlockedUsersData() {
    _blockedUsers = _blockedUsersRelationshipData.map((relationshipData) {
      final uid = relationshipData['uid'] as String;
      final userData = _userDataCache[uid] ?? {};
      
      return {
        ...relationshipData, // uid, relationshipId
        ...userData, // displayName, photoURL, etc.
      };
    }).toList();
    
    _logger.d(_tag, 'Combined blocked users data: ${_blockedUsers.length} blocked users with user data');
  }

  // ==========================================================================
  // FRIEND REQUEST OPERATIONS
  // ==========================================================================

  /// Send a friend request to another user
  Future<bool> sendFriendRequest(String targetUserId) async {
    if (_processingSendRequests.contains(targetUserId)) {
      _logger.w(_tag, 'Send friend request already in progress for user: $targetUserId');
      return false;
    }

    _processingSendRequests.add(targetUserId);
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Sending friend request to user: $targetUserId');
      
      final relationshipId = await _relationshipRepository.sendFriendRequest(targetUserId);
      
      _logger.i(_tag, 'Friend request sent successfully: $relationshipId');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to send friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingSendRequests.remove(targetUserId);
      notifyListeners();
    }
  }

  /// Accept a pending friend request
  Future<bool> acceptFriendRequest(String relationshipId) async {
    if (_processingAcceptRequests.contains(relationshipId)) {
      _logger.w(_tag, 'Accept friend request already in progress: $relationshipId');
      return false;
    }

    _processingAcceptRequests.add(relationshipId);
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Accepting friend request: $relationshipId');
      
      await _relationshipRepository.acceptFriendRequest(relationshipId);
      
      _logger.i(_tag, 'Friend request accepted successfully: $relationshipId');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to accept friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingAcceptRequests.remove(relationshipId);
      notifyListeners();
    }
  }

  /// Reject/decline a pending friend request
  Future<bool> rejectFriendRequest(String relationshipId) async {
    if (_processingRejectRequests.contains(relationshipId)) {
      _logger.w(_tag, 'Reject friend request already in progress: $relationshipId');
      return false;
    }

    _processingRejectRequests.add(relationshipId);
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Rejecting friend request: $relationshipId');
      
      await _relationshipRepository.rejectFriendRequest(relationshipId);
      
      _logger.i(_tag, 'Friend request rejected successfully: $relationshipId');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to reject friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingRejectRequests.remove(relationshipId);
      notifyListeners();
    }
  }

  /// Cancel a sent friend request
  Future<bool> cancelFriendRequest(String relationshipId) async {
    if (_processingCancelRequests.contains(relationshipId)) {
      _logger.w(_tag, 'Cancel friend request already in progress: $relationshipId');
      return false;
    }

    _processingCancelRequests.add(relationshipId);
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Cancelling friend request: $relationshipId');
      
      await _relationshipRepository.cancelFriendRequest(relationshipId);
      
      _logger.i(_tag, 'Friend request cancelled successfully: $relationshipId');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to cancel friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingCancelRequests.remove(relationshipId);
      notifyListeners();
    }
  }

  // ==========================================================================
  // FRIENDSHIP MANAGEMENT
  // ==========================================================================

  /// Remove an existing friend
  Future<bool> removeFriend(String targetUserId) async {
    if (_processingRemoveFriends.contains(targetUserId)) {
      _logger.w(_tag, 'Remove friend already in progress for user: $targetUserId');
      return false;
    }

    _processingRemoveFriends.add(targetUserId);
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Removing friend: $targetUserId');
      _logger.d(_tag, 'Current friends count BEFORE removal: ${_friends.length}');
      
      await _relationshipRepository.removeFriend(targetUserId);
      
      _logger.i(_tag, 'Friend removed successfully: $targetUserId');
      _logger.d(_tag, 'Current friends count AFTER removal call: ${_friends.length}');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingRemoveFriends.remove(targetUserId);
      notifyListeners();
    }
  }

  // ==========================================================================
  // BLOCKING OPERATIONS
  // ==========================================================================

  /// Block a user
  Future<bool> blockUser(String targetUserId) async {
    if (_processingBlockUsers.contains(targetUserId)) {
      _logger.w(_tag, 'Block user already in progress for user: $targetUserId');
      return false;
    }

    _processingBlockUsers.add(targetUserId);
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Blocking user: $targetUserId');
      
      await _relationshipRepository.blockUser(targetUserId);
      
      _logger.i(_tag, 'User blocked successfully: $targetUserId');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to block user: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingBlockUsers.remove(targetUserId);
      notifyListeners();
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String targetUserId) async {
    if (_processingUnblockUsers.contains(targetUserId)) {
      _logger.w(_tag, 'Unblock user already in progress for user: $targetUserId');
      return false;
    }

    _processingUnblockUsers.add(targetUserId);
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Unblocking user: $targetUserId');
      
      await _relationshipRepository.unblockUser(targetUserId);
      
      _logger.i(_tag, 'User unblocked successfully: $targetUserId');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to unblock user: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingUnblockUsers.remove(targetUserId);
      notifyListeners();
    }
  }

  // ==========================================================================
  // USER SEARCH OPERATIONS
  // ==========================================================================

  /// Search for a user by their UID
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    _isLoadingOperation = true;
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Searching for user by UID: $uid');
      
      final result = await _relationshipRepository.searchUserByUid(uid);
      
      if (result != null) {
        _logger.i(_tag, 'User found: ${result['displayName']}');
      } else {
        _logger.i(_tag, 'User not found for UID: $uid');
      }
      
      return result;

    } catch (e) {
      _logger.e(_tag, 'Failed to search user by UID: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return null;
    } finally {
      _isLoadingOperation = false;
      notifyListeners();
    }
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  /// Clear the current error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get user-friendly error message from exception
  String _getErrorMessage(dynamic error) {
    if (error is RelationshipException) {
      switch (error.code) {
        case RelationshipErrorCodes.userNotFound:
          return 'User not found. Please check the user ID.';
        case RelationshipErrorCodes.alreadyFriends:
          return 'You are already friends with this user.';
        case RelationshipErrorCodes.requestAlreadySent:
          return 'Friend request already sent to this user.';
        case RelationshipErrorCodes.requestAlreadyReceived:
          return 'You already have a pending request from this user.';
        case RelationshipErrorCodes.blocked:
          return 'Cannot send friend request. User may be blocked.';
        case RelationshipErrorCodes.selfRequest:
          return 'You cannot send a friend request to yourself.';
        case RelationshipErrorCodes.notLoggedIn:
          return 'Please sign in to manage friends.';
        case RelationshipErrorCodes.databaseError:
          return 'Database error. Please try again later.';
        case RelationshipErrorCodes.networkError:
          return 'Network error. Please check your connection.';
        case RelationshipErrorCodes.unauthorized:
          return 'You are not authorized to perform this action.';
        default:
          return 'An unexpected error occurred. Please try again.';
      }
    }
    
    return 'An unexpected error occurred. Please try again.';
  }

  /// Get summary counts for UI display
  Map<String, int> getSummary() {
    return {
      'friends': _friends.length,
      'pendingRequests': _pendingRequests.length,
      'blockedUsers': _blockedUsers.length,
    };
  }

  /// Refresh all data streams (useful for pull-to-refresh)
  Future<void> refresh() async {
    _logger.d(_tag, 'Refreshing relationship data');
    clearError();
    await _setupStreams();
  }
}
