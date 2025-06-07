import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/models/relationship_model.dart';
import '../../../core/repositories/relationship_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/exceptions/relationship_exceptions.dart';
import '../../../core/services/auth/auth_service_interface.dart';

/// Provider for managing relationship state throughout the app
///
/// Replaces FriendsProvider with updated architecture that works with
/// the new RelationshipRepository while maintaining UI compatibility.
///
/// Handles:
/// - Friends list (accepted relationships) 
/// - Incoming friend requests (pending received)
/// - Outgoing friend requests (pending sent)
/// - Blocked users list
/// - Loading states and error handling
/// - Data transformation from Map to RelationshipModel
class RelationshipProvider extends ChangeNotifier {
  final RelationshipRepository _relationshipRepository;
  final AuthServiceInterface _authService;
  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'RELATIONSHIP_PROVIDER';

  // Stream Subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _friendsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingRequestsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _blockedUsersSubscription;

  // Summary data
  Map<String, int> _summary = {
    'friends': 0,
    'pending_received': 0,
    'pending_sent': 0,
    'blocked': 0,
  };

  // Relationship data (as RelationshipModel for UI compatibility)
  List<RelationshipModel> _friends = [];
  List<RelationshipModel> _incomingRequests = [];
  List<RelationshipModel> _outgoingRequests = [];
  List<RelationshipModel> _blockedUsers = [];

  // User profile data cache (for UI display)
  Map<String, Map<String, dynamic>> _userProfiles = {};

  // Loading states
  bool _isLoadingSummary = false;
  bool _isLoadingFriends = false;
  bool _isLoadingIncoming = false;
  bool _isLoadingOutgoing = false;
  bool _isLoadingBlocked = false;
  bool _isSearching = false;

  // Sets to track processing state for individual requests
  final Set<String> _processingAcceptRequestIds = {};
  final Set<String> _processingDeclineRequestIds = {};
  final Set<String> _processingCancelRequestIds = {};
  final Set<String> _processingBlockUserIds = {};

  // Error states
  String? _error;

  /// Creates a new RelationshipProvider
  RelationshipProvider({
    RelationshipRepository? relationshipRepository,
    AuthServiceInterface? authService,
  }) : _relationshipRepository = relationshipRepository ?? serviceLocator<RelationshipRepository>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>();

  // Getters (maintaining FriendsProvider compatibility)
  Map<String, int> get summary => Map.unmodifiable(_summary);
  List<RelationshipModel> get friends => List.unmodifiable(_friends);
  List<RelationshipModel> get incomingRequests => List.unmodifiable(_incomingRequests);
  List<RelationshipModel> get outgoingRequests => List.unmodifiable(_outgoingRequests);
  List<RelationshipModel> get blockedUsers => List.unmodifiable(_blockedUsers);

  bool get isLoadingSummary => _isLoadingSummary;
  bool get isLoadingFriends => _isLoadingFriends;
  bool get isLoadingIncoming => _isLoadingIncoming;
  bool get isLoadingOutgoing => _isLoadingOutgoing;
  bool get isLoadingBlocked => _isLoadingBlocked;
  bool get isSearching => _isSearching;

  // Getters for processing states
  bool isAcceptingRequest(String id) => _processingAcceptRequestIds.contains(id);
  bool isDecliningRequest(String id) => _processingDeclineRequestIds.contains(id);
  bool isCancellingRequest(String id) => _processingCancelRequestIds.contains(id);
  bool isBlockingUser(String id) => _processingBlockUserIds.contains(id);

  String? get error => _error;

  int get friendsCount => _friends.length;
  int get incomingCount => _incomingRequests.length;
  int get outgoingCount => _outgoingRequests.length;

  /// Initialize the provider - loads summary and sets up streams
  Future<void> initialize() async {
    _logger.d(_tag, 'Initializing RelationshipProvider');
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _logger.w(_tag, 'Cannot initialize RelationshipProvider: user not authenticated');
      return;
    }

    // Load initial summary
    await loadSummary(); 
    
    _setupStreams(currentUser.uid);

    _logger.i(_tag, 'RelationshipProvider initialized with streams');
  }

  void _setupStreams(String userId) {
    // Setup friends stream
    _friendsSubscription?.cancel();
    _friendsSubscription = _relationshipRepository.getFriendsStream().listen(
      (friendsData) {
        _friends = _convertToRelationshipModels(friendsData);
        _summary['friends'] = _friends.length;
        _isLoadingFriends = false;
        _error = null;
        notifyListeners();
        _logger.d(_tag, 'Friends list updated from stream: ${_friends.length} friends');
      },
      onError: (e) {
        _logger.e(_tag, 'Error in friends stream: ${e.toString()}');
        _error = _getErrorMessage(e);
        _isLoadingFriends = false;
        notifyListeners();
      },
      onDone: () {
        _isLoadingFriends = false;
        notifyListeners();
      }
    );
    _isLoadingFriends = true;
    notifyListeners();

    // Setup combined pending requests stream (includes both incoming and outgoing)
    _pendingRequestsSubscription?.cancel();
    _pendingRequestsSubscription = _relationshipRepository.getPendingRequestsStream().listen(
      (pendingData) {
        // Filter into incoming and outgoing based on isIncoming field
        final incoming = <Map<String, dynamic>>[];
        final outgoing = <Map<String, dynamic>>[];
        
        for (final data in pendingData) {
          final isIncoming = data['isIncoming'] as bool? ?? false;
          if (isIncoming) {
            incoming.add(data);
          } else {
            outgoing.add(data);
          }
        }
        
        _incomingRequests = _convertToRelationshipModels(incoming);
        _outgoingRequests = _convertToRelationshipModels(outgoing);
        
        _summary['pending_received'] = _incomingRequests.length;
        _summary['pending_sent'] = _outgoingRequests.length;
        
        _isLoadingIncoming = false;
        _isLoadingOutgoing = false;
        _error = null;
        notifyListeners();
        
        _logger.d(_tag, 'Pending requests updated: ${_incomingRequests.length} incoming, ${_outgoingRequests.length} outgoing');
      },
      onError: (e) {
        _logger.e(_tag, 'Error in pending requests stream: ${e.toString()}');
        _error = _getErrorMessage(e);
        _isLoadingIncoming = false;
        _isLoadingOutgoing = false;
        notifyListeners();
      },
      onDone: () {
        _isLoadingIncoming = false;
        _isLoadingOutgoing = false;
        notifyListeners();
      }
    );
    _isLoadingIncoming = true;
    _isLoadingOutgoing = true;
    notifyListeners();
    
    // Setup blocked users stream
    _blockedUsersSubscription?.cancel();
    _blockedUsersSubscription = _relationshipRepository.getBlockedUsersStream().listen(
      (blockedData) {
        _blockedUsers = _convertToRelationshipModels(blockedData);
        _summary['blocked'] = _blockedUsers.length;
        _isLoadingBlocked = false;
        _error = null;
        notifyListeners();
        _logger.d(_tag, 'Blocked users updated from stream: ${_blockedUsers.length} users');
      },
      onError: (e) {
        _logger.e(_tag, 'Error in blocked users stream: ${e.toString()}');
        _error = _getErrorMessage(e);
        _isLoadingBlocked = false;
        notifyListeners();
      },
      onDone: () {
        _isLoadingBlocked = false;
        notifyListeners();
      }
    );
    _isLoadingBlocked = true;
    notifyListeners();
  }

  /// Convert List<Map<String, dynamic>> to List<RelationshipModel>
  List<RelationshipModel> _convertToRelationshipModels(List<Map<String, dynamic>> data) {
    final models = <RelationshipModel>[];
    
    for (final item in data) {
      try {
        // Create a basic RelationshipModel from the user data
        // Note: The repository returns user data, not relationship data
        // We need to create synthetic relationship models for UI compatibility
        final uid = item['uid'] as String?;
        final relationshipId = item['relationshipId'] as String?;
        
        if (uid != null && relationshipId != null) {
          // Create a synthetic RelationshipModel
          final currentUserId = _authService.currentUser?.uid ?? '';
          final participants = RelationshipModel.sortParticipants([currentUserId, uid]);
          
          // Determine status based on context (friends are accepted, others are pending/blocked)
          RelationshipStatus status = RelationshipStatus.pending;
          if (_isLoadingFriends || (!_isLoadingFriends && _friends.isNotEmpty)) {
            status = RelationshipStatus.accepted; // Friends stream
          } else if (_isLoadingBlocked || (!_isLoadingBlocked && _blockedUsers.isNotEmpty)) {
            status = RelationshipStatus.blocked; // Blocked stream
          }
          
          final model = RelationshipModel(
            id: relationshipId,
            participants: participants,
            type: RelationshipType.friendship,
            status: status,
            createdAt: DateTime.now(), // We don't have this data from user streams
            updatedAt: DateTime.now(),
            initiatorId: item['initiatorId'] as String?,
          );
          
          models.add(model);
          
          // Cache user profile data for UI display
          _userProfiles[uid] = {
            'uid': uid,
            'displayName': item['displayName'],
            'photoURL': item['photoURL'],
            'email': item['email'], // if available
          };
        }
      } catch (e) {
        _logger.w(_tag, 'Failed to convert item to RelationshipModel: ${e.toString()}');
      }
    }
    
    return models;
  }

  /// Get user profile data for a specific user
  /// This method provides the user profile information needed by UI components
  Map<String, dynamic>? getUserProfile(String userId) {
    return _userProfiles[userId];
  }

  /// Get user profile data based on a relationship and current user ID
  /// This provides compatibility with the old getCachedProfile method
  Map<String, dynamic>? getProfileForRelationship(RelationshipModel relationship, String currentUserId) {
    final friendId = relationship.getFriendId(currentUserId);
    return getUserProfile(friendId);
  }

  /// Load summary of relationship counts
  Future<void> loadSummary() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _isLoadingSummary = true;
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading relationships summary');
      
      // Since repository doesn't have getUserRelationshipsSummary, 
      // we'll build summary from current data
      _summary = {
        'friends': _friends.length,
        'pending_received': _incomingRequests.length,
        'pending_sent': _outgoingRequests.length,
        'blocked': _blockedUsers.length,
      };
      
      _logger.i(_tag, 'Summary loaded: $_summary');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load summary: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingSummary = false;
      notifyListeners();
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String relationshipId) async {
    _processingAcceptRequestIds.add(relationshipId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Accepting friend request: $relationshipId');
      await _relationshipRepository.acceptFriendRequest(relationshipId);
      _logger.i(_tag, 'Friend request accepted successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to accept friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingAcceptRequestIds.remove(relationshipId);
      notifyListeners();
    }
  }

  /// Decline a friend request (maps to rejectFriendRequest in repository)
  Future<bool> declineFriendRequest(String relationshipId) async {
    _processingDeclineRequestIds.add(relationshipId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Declining friend request: $relationshipId');
      await _relationshipRepository.rejectFriendRequest(relationshipId);
      _logger.i(_tag, 'Friend request declined successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to decline friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingDeclineRequestIds.remove(relationshipId);
      notifyListeners();
    }
  }

  /// Cancel an outgoing friend request 
  /// Note: RelationshipRepository doesn't have cancelFriendRequest, using rejectFriendRequest
  Future<bool> cancelFriendRequest(String relationshipId) async {
    _processingCancelRequestIds.add(relationshipId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Cancelling friend request: $relationshipId');
      // For now, use rejectFriendRequest as cancel functionality
      await _relationshipRepository.rejectFriendRequest(relationshipId);
      _logger.i(_tag, 'Friend request cancelled successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to cancel friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingCancelRequestIds.remove(relationshipId);
      notifyListeners();
    }
  }

  /// Remove a friend (using targetUserId instead of relationshipId)
  Future<bool> removeFriend(String targetUserId) async {
    try {
      _logger.d(_tag, 'Removing friend: $targetUserId');
      await _relationshipRepository.removeFriend(targetUserId);
      _logger.i(_tag, 'Friend removed successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Block a user (using targetUserId instead of relationshipId)
  Future<bool> blockUser(String targetUserId) async {
    _processingBlockUserIds.add(targetUserId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Blocking user: $targetUserId');
      await _relationshipRepository.blockUser(targetUserId);
      _logger.i(_tag, 'User blocked successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to block user: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingBlockUserIds.remove(targetUserId);
      notifyListeners();
    }
  }

  /// Unblock a user (using targetUserId instead of relationshipId)
  Future<bool> unblockUser(String targetUserId) async {
    _processingBlockUserIds.add(targetUserId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Unblocking user: $targetUserId');
      await _relationshipRepository.unblockUser(targetUserId);
      _logger.i(_tag, 'User unblocked successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to unblock user: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _processingBlockUserIds.remove(targetUserId);
      notifyListeners();
    }
  }

  /// Search for user by UID
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    _isSearching = true;
    notifyListeners();
    
    try {
      _logger.d(_tag, 'Searching user by UID: $uid');
      
      final result = await _relationshipRepository.searchUserByUid(uid);
      
      _logger.i(_tag, 'User search completed: ${result != null ? 'found' : 'not found'}');
      return result;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to search user: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return null;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Send friend request to user
  Future<bool> sendFriendRequest(String targetUserId) async {
    try {
      _logger.d(_tag, 'Sending friend request to: $targetUserId');
      await _relationshipRepository.sendFriendRequest(targetUserId);
      _logger.i(_tag, 'Friend request sent successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to send friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    if (error is RelationshipException) {
      return error.message;
    }
    return 'An unexpected error occurred';
  }

  /// Load blocked users manually (compatibility method)
  Future<void> loadBlockedUsers() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _isLoadingBlocked = true;
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading blocked users');
      
      final result = await _relationshipRepository.getCachedBlockedUsers();
      _blockedUsers = _convertToRelationshipModels(result);
      
      _logger.i(_tag, 'Blocked users loaded: ${_blockedUsers.length} users');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load blocked users: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingBlocked = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _logger.d(_tag, 'Disposing RelationshipProvider and cancelling streams');
    _friendsSubscription?.cancel();
    _pendingRequestsSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    super.dispose();
  }
}
