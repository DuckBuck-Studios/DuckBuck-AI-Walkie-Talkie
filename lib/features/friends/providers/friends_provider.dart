import 'package:flutter/foundation.dart';
import '../../../core/models/relationship_model.dart';
import '../../../core/repositories/relationship_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/exceptions/relationship_exceptions.dart';
import '../../../core/services/auth/auth_service_interface.dart';

/// Provider for managing friends state throughout the app
///
/// Handles:
/// - Friends summary (counts of different relationship types)
/// - Friends list (accepted relationships)
/// - Incoming friend requests (pending received)
/// - Outgoing friend requests (pending sent)
/// - UI state for expandable sections
class FriendsProvider extends ChangeNotifier {
  final RelationshipRepository _relationshipRepository;
  final AuthServiceInterface _authService;
  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'FRIENDS_PROVIDER';

  // Summary data
  Map<String, int> _summary = {
    'friends': 0,
    'pending_received': 0,
    'pending_sent': 0,
    'blocked': 0,
  };

  // Friends data
  List<RelationshipModel> _friends = [];
  List<RelationshipModel> _incomingRequests = [];
  List<RelationshipModel> _outgoingRequests = [];

  // Pagination state
  bool _friendsHasMore = false;
  bool _incomingHasMore = false;
  bool _outgoingHasMore = false;
  String? _friendsLastDoc;
  String? _incomingLastDoc;
  String? _outgoingLastDoc;

  // Loading states
  bool _isLoadingSummary = false;
  bool _isLoadingFriends = false;
  bool _isLoadingIncoming = false;
  bool _isLoadingOutgoing = false;
  bool _isLoadingMoreFriends = false;
  bool _isLoadingMoreIncoming = false;
  bool _isLoadingMoreOutgoing = false;
  bool _isSearching = false;

  // UI state for dropdown sections
  bool _isIncomingExpanded = false;
  bool _isOutgoingExpanded = false;

  // Error states
  String? _error;

  /// Creates a new FriendsProvider
  FriendsProvider({
    RelationshipRepository? relationshipRepository,
    AuthServiceInterface? authService,
  }) : _relationshipRepository = relationshipRepository ?? serviceLocator<RelationshipRepository>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>();

  // Getters
  Map<String, int> get summary => Map.unmodifiable(_summary);
  List<RelationshipModel> get friends => List.unmodifiable(_friends);
  List<RelationshipModel> get incomingRequests => List.unmodifiable(_incomingRequests);
  List<RelationshipModel> get outgoingRequests => List.unmodifiable(_outgoingRequests);

  bool get isLoadingSummary => _isLoadingSummary;
  bool get isLoadingFriends => _isLoadingFriends;
  bool get isLoadingIncoming => _isLoadingIncoming;
  bool get isLoadingOutgoing => _isLoadingOutgoing;
  bool get isLoadingMoreFriends => _isLoadingMoreFriends;
  bool get isLoadingMoreIncoming => _isLoadingMoreIncoming;
  bool get isLoadingMoreOutgoing => _isLoadingMoreOutgoing;
  bool get isSearching => _isSearching;

  bool get friendsHasMore => _friendsHasMore;
  bool get incomingHasMore => _incomingHasMore;
  bool get outgoingHasMore => _outgoingHasMore;

  bool get isIncomingExpanded => _isIncomingExpanded;
  bool get isOutgoingExpanded => _isOutgoingExpanded;

  String? get error => _error;

  int get friendsCount => _summary['friends'] ?? 0;
  int get incomingCount => _summary['pending_received'] ?? 0;
  int get outgoingCount => _summary['pending_sent'] ?? 0;

  /// Initialize the provider - loads summary and friends list
  Future<void> initialize() async {
    _logger.d(_tag, 'Initializing FriendsProvider');
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _logger.w(_tag, 'Cannot initialize FriendsProvider: user not authenticated');
      return;
    }

    await Future.wait([
      loadSummary(),
      loadFriends(),
    ]);

    _logger.i(_tag, 'FriendsProvider initialized successfully');
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
      
      final summary = await _relationshipRepository.getUserRelationshipsSummary(currentUser.uid);
      _summary = summary;
      
      _logger.i(_tag, 'Summary loaded: $_summary');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load summary: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingSummary = false;
      notifyListeners();
    }
  }

  /// Load friends list (accepted relationships)
  Future<void> loadFriends({bool refresh = false}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    if (refresh) {
      _friends.clear();
      _friendsLastDoc = null;
      _friendsHasMore = false;
    }

    _isLoadingFriends = true;
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading friends list');
      
      final result = await _relationshipRepository.getFriends(
        currentUser.uid,
        limit: 20,
        startAfter: refresh ? null : _friendsLastDoc,
      );

      if (refresh) {
        _friends = result.relationships;
      } else {
        _friends.addAll(result.relationships);
      }
      
      _friendsHasMore = result.hasMore;
      _friendsLastDoc = result.lastDocumentId;
      
      _logger.i(_tag, 'Friends loaded: ${_friends.length} total');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load friends: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingFriends = false;
      notifyListeners();
    }
  }

  /// Load more friends (pagination)
  Future<void> loadMoreFriends() async {
    if (!_friendsHasMore || _isLoadingMoreFriends) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _isLoadingMoreFriends = true;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading more friends');
      
      final result = await _relationshipRepository.getFriends(
        currentUser.uid,
        limit: 20,
        startAfter: _friendsLastDoc,
      );

      _friends.addAll(result.relationships);
      _friendsHasMore = result.hasMore;
      _friendsLastDoc = result.lastDocumentId;
      
      _logger.i(_tag, 'More friends loaded: ${_friends.length} total');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load more friends: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingMoreFriends = false;
      notifyListeners();
    }
  }

  /// Load incoming friend requests
  Future<void> loadIncomingRequests({bool refresh = false}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    if (refresh) {
      _incomingRequests.clear();
      _incomingLastDoc = null;
      _incomingHasMore = false;
    }

    _isLoadingIncoming = true;
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading incoming requests');
      
      final result = await _relationshipRepository.getPendingRequests(
        currentUser.uid,
        limit: 20,
        startAfter: refresh ? null : _incomingLastDoc,
      );

      if (refresh) {
        _incomingRequests = result.relationships;
      } else {
        _incomingRequests.addAll(result.relationships);
      }
      
      _incomingHasMore = result.hasMore;
      _incomingLastDoc = result.lastDocumentId;
      
      _logger.i(_tag, 'Incoming requests loaded: ${_incomingRequests.length} total');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load incoming requests: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingIncoming = false;
      notifyListeners();
    }
  }

  /// Load more incoming requests (pagination)
  Future<void> loadMoreIncomingRequests() async {
    if (!_incomingHasMore || _isLoadingMoreIncoming) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _isLoadingMoreIncoming = true;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading more incoming requests');
      
      final result = await _relationshipRepository.getPendingRequests(
        currentUser.uid,
        limit: 20,
        startAfter: _incomingLastDoc,
      );

      _incomingRequests.addAll(result.relationships);
      _incomingHasMore = result.hasMore;
      _incomingLastDoc = result.lastDocumentId;
      
      _logger.i(_tag, 'More incoming requests loaded: ${_incomingRequests.length} total');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load more incoming requests: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingMoreIncoming = false;
      notifyListeners();
    }
  }

  /// Load outgoing friend requests
  Future<void> loadOutgoingRequests({bool refresh = false}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    if (refresh) {
      _outgoingRequests.clear();
      _outgoingLastDoc = null;
      _outgoingHasMore = false;
    }

    _isLoadingOutgoing = true;
    _error = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading outgoing requests');
      
      final result = await _relationshipRepository.getSentRequests(
        currentUser.uid,
        limit: 20,
        startAfter: refresh ? null : _outgoingLastDoc,
      );

      if (refresh) {
        _outgoingRequests = result.relationships;
      } else {
        _outgoingRequests.addAll(result.relationships);
      }
      
      _outgoingHasMore = result.hasMore;
      _outgoingLastDoc = result.lastDocumentId;
      
      _logger.i(_tag, 'Outgoing requests loaded: ${_outgoingRequests.length} total');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load outgoing requests: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingOutgoing = false;
      notifyListeners();
    }
  }

  /// Load more outgoing requests (pagination)
  Future<void> loadMoreOutgoingRequests() async {
    if (!_outgoingHasMore || _isLoadingMoreOutgoing) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _isLoadingMoreOutgoing = true;
    notifyListeners();

    try {
      _logger.d(_tag, 'Loading more outgoing requests');
      
      final result = await _relationshipRepository.getSentRequests(
        currentUser.uid,
        limit: 20,
        startAfter: _outgoingLastDoc,
      );

      _outgoingRequests.addAll(result.relationships);
      _outgoingHasMore = result.hasMore;
      _outgoingLastDoc = result.lastDocumentId;
      
      _logger.i(_tag, 'More outgoing requests loaded: ${_outgoingRequests.length} total');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to load more outgoing requests: ${e.toString()}');
      _error = _getErrorMessage(e);
    } finally {
      _isLoadingMoreOutgoing = false;
      notifyListeners();
    }
  }

  /// Toggle incoming requests section expanded state
  void toggleIncomingExpanded() {
    _isIncomingExpanded = !_isIncomingExpanded;
    
    // Load incoming requests when expanding for the first time
    if (_isIncomingExpanded && _incomingRequests.isEmpty && !_isLoadingIncoming) {
      loadIncomingRequests();
    }
    
    notifyListeners();
  }

  /// Toggle outgoing requests section expanded state
  void toggleOutgoingExpanded() {
    _isOutgoingExpanded = !_isOutgoingExpanded;
    
    // Load outgoing requests when expanding for the first time
    if (_isOutgoingExpanded && _outgoingRequests.isEmpty && !_isLoadingOutgoing) {
      loadOutgoingRequests();
    }
    
    notifyListeners();
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Accepting friend request: $relationshipId');
      
      await _relationshipRepository.acceptFriendRequest(relationshipId);
      
      // Remove from incoming requests
      _incomingRequests.removeWhere((req) => req.id == relationshipId);
      
      // Refresh summary and friends list
      await Future.wait([
        loadSummary(),
        loadFriends(refresh: true),
      ]);
      
      _logger.i(_tag, 'Friend request accepted successfully');
      return true;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to accept friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Decline a friend request
  Future<bool> declineFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Declining friend request: $relationshipId');
      
      await _relationshipRepository.declineFriendRequest(relationshipId);
      
      // Remove from incoming requests
      _incomingRequests.removeWhere((req) => req.id == relationshipId);
      
      // Refresh summary
      await loadSummary();
      
      notifyListeners();
      _logger.i(_tag, 'Friend request declined successfully');
      return true;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to decline friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Cancel an outgoing friend request
  Future<bool> cancelFriendRequest(String relationshipId) async {
    try {
      _logger.d(_tag, 'Cancelling friend request: $relationshipId');
      
      await _relationshipRepository.cancelFriendRequest(relationshipId);
      
      // Remove from outgoing requests
      _outgoingRequests.removeWhere((req) => req.id == relationshipId);
      
      // Refresh summary
      await loadSummary();
      
      notifyListeners();
      _logger.i(_tag, 'Friend request cancelled successfully');
      return true;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to cancel friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(String relationshipId) async {
    try {
      _logger.d(_tag, 'Removing friend: $relationshipId');
      
      await _relationshipRepository.removeFriend(relationshipId);
      
      // Remove from friends list
      _friends.removeWhere((friend) => friend.id == relationshipId);
      
      // Refresh summary
      await loadSummary();
      
      notifyListeners();
      _logger.i(_tag, 'Friend removed successfully');
      return true;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
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
      
      // Refresh summary and outgoing requests if expanded
      await loadSummary();
      if (_isOutgoingExpanded) {
        await loadOutgoingRequests(refresh: true);
      }
      
      _logger.i(_tag, 'Friend request sent successfully');
      return true;
      
    } catch (e) {
      _logger.e(_tag, 'Failed to send friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    _logger.d(_tag, 'Refreshing all friends data');
    
    await Future.wait([
      loadSummary(),
      loadFriends(refresh: true),
      if (_isIncomingExpanded) loadIncomingRequests(refresh: true),
      if (_isOutgoingExpanded) loadOutgoingRequests(refresh: true),
    ]);
    
    _logger.i(_tag, 'All friends data refreshed');
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

  /// Get cached profile for a relationship
  CachedProfile? getCachedProfile(RelationshipModel relationship, String currentUserId) {
    final friendId = relationship.getFriendId(currentUserId);
    return relationship.getCachedProfile(friendId);
  }

  @override
  void dispose() {
    _logger.d(_tag, 'Disposing FriendsProvider');
    super.dispose();
  }
}
