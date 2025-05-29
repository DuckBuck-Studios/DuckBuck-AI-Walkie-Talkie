import 'dart:async'; // Import for StreamSubscription

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

  // Stream Subscriptions
  StreamSubscription<List<RelationshipModel>>? _friendsSubscription;
  StreamSubscription<List<RelationshipModel>>? _incomingRequestsSubscription;
  StreamSubscription<List<RelationshipModel>>? _outgoingRequestsSubscription;
  // StreamSubscription<Map<String, int>>? _summarySubscription; // Optional: if summary can be streamed

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

  // Pagination state - May become less relevant with streams providing full lists, or adapt if streams support pagination
  bool _friendsHasMore = false;
  bool _incomingHasMore = false;
  bool _outgoingHasMore = false;
  // String? _friendsLastDoc; // Likely remove if streams don't use cursors this way
  // String? _incomingLastDoc; // Likely remove
  // String? _outgoingLastDoc; // Likely remove

  // Loading states
  bool _isLoadingSummary = false;
  bool _isLoadingFriends = false;
  bool _isLoadingIncoming = false;
  bool _isLoadingOutgoing = false;
  bool _isLoadingMoreFriends = false;
  bool _isLoadingMoreIncoming = false;
  bool _isLoadingMoreOutgoing = false;
  bool _isSearching = false;

  // Sets to track processing state for individual requests
  final Set<String> _processingAcceptRequestIds = {};
  final Set<String> _processingDeclineRequestIds = {};
  final Set<String> _processingCancelRequestIds = {}; // Added for cancelling outgoing requests

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

  // Getters for processing states
  bool isAcceptingRequest(String id) => _processingAcceptRequestIds.contains(id);
  bool isDecliningRequest(String id) => _processingDeclineRequestIds.contains(id);
  bool isCancellingRequest(String id) => _processingCancelRequestIds.contains(id); // Added getter

  bool get friendsHasMore => _friendsHasMore;
  bool get incomingHasMore => _incomingHasMore;
  bool get outgoingHasMore => _outgoingHasMore;

  String? get error => _error;

  int get friendsCount => _friends.length;
  int get incomingCount => _incomingRequests.length;
  int get outgoingCount => _outgoingRequests.length;

  /// Initialize the provider - loads summary and sets up streams
  Future<void> initialize() async {
    _logger.d(_tag, 'Initializing FriendsProvider');
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _logger.w(_tag, 'Cannot initialize FriendsProvider: user not authenticated');
      return;
    }

    // Load initial summary (can also be converted to a stream if backend supports)
    await loadSummary(); 
    
    _setupStreams(currentUser.uid);

    _logger.i(_tag, 'FriendsProvider initialized with streams');
  }

  void _setupStreams(String userId) {
    _friendsSubscription?.cancel();
    _friendsSubscription = _relationshipRepository.getFriendsStream().listen(
      (friendsList) {
        _friends = friendsList;
        _summary['friends'] = _friends.length; // Update summary count
        _isLoadingFriends = false;
        _friendsHasMore = false; // Assuming stream provides the whole list
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
    _isLoadingFriends = true; // Indicate initial loading via stream
    notifyListeners();

    _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription = _relationshipRepository.getPendingRequestsStream().listen(
      (incomingList) {
        _incomingRequests = incomingList;
        _summary['pending_received'] = _incomingRequests.length; // Update summary count
        _isLoadingIncoming = false;
        _incomingHasMore = false; // Assuming stream provides the whole list
        _error = null;
        notifyListeners();
        _logger.d(_tag, 'Incoming requests updated from stream: ${_incomingRequests.length} requests');
      },
      onError: (e) {
        _logger.e(_tag, 'Error in incoming requests stream: ${e.toString()}');
        _error = _getErrorMessage(e);
        _isLoadingIncoming = false;
        notifyListeners();
      },
      onDone: () {
        _isLoadingIncoming = false;
        notifyListeners();
      }
    );
    _isLoadingIncoming = true; // Indicate initial loading via stream
    notifyListeners();

    _outgoingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription = _relationshipRepository.getSentRequestsStream().listen(
      (outgoingList) {
        _outgoingRequests = outgoingList;
        _summary['pending_sent'] = _outgoingRequests.length; // Update summary count
        _isLoadingOutgoing = false;
        _outgoingHasMore = false; // Assuming stream provides the whole list
        _error = null;
        notifyListeners();
        _logger.d(_tag, 'Outgoing requests updated from stream: ${_outgoingRequests.length} requests');
      },
      onError: (e) {
        _logger.e(_tag, 'Error in outgoing requests stream: ${e.toString()}');
        _error = _getErrorMessage(e);
        _isLoadingOutgoing = false;
        notifyListeners();
      },
      onDone: () {
        _isLoadingOutgoing = false;
        notifyListeners();
      }
    );
    _isLoadingOutgoing = true; // Indicate initial loading via stream
    notifyListeners();
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

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String relationshipId) async {
    _processingAcceptRequestIds.add(relationshipId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Accepting friend request: $relationshipId');
      await _relationshipRepository.acceptFriendRequest(relationshipId);
      // Lists will update via streams automatically
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

  /// Decline a friend request
  Future<bool> declineFriendRequest(String relationshipId) async {
    _processingDeclineRequestIds.add(relationshipId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Declining friend request: $relationshipId');
      await _relationshipRepository.declineFriendRequest(relationshipId);
      // Lists will update via streams automatically
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
  Future<bool> cancelFriendRequest(String relationshipId) async {
    _processingCancelRequestIds.add(relationshipId);
    notifyListeners();
    try {
      _logger.d(_tag, 'Cancelling friend request: $relationshipId');
      await _relationshipRepository.cancelFriendRequest(relationshipId);
      // Lists will update via streams automatically
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

  /// Remove a friend
  Future<bool> removeFriend(String relationshipId) async {
    // Add processing state if needed: _processingRemoveFriendIds.add(relationshipId); notifyListeners();
    try {
      _logger.d(_tag, 'Removing friend: $relationshipId');
      await _relationshipRepository.removeFriend(relationshipId);
      // Lists will update via streams automatically
      _logger.i(_tag, 'Friend removed successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to remove friend: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      // _processingRemoveFriendIds.remove(relationshipId); notifyListeners();
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
    // Add processing state if needed
    try {
      _logger.d(_tag, 'Sending friend request to: $targetUserId');
      await _relationshipRepository.sendFriendRequest(targetUserId);
      // Lists will update via streams automatically
      _logger.i(_tag, 'Friend request sent successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to send friend request: ${e.toString()}');
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      // Clear processing state
    }
  }

  /// Refresh all data - streams handle automatic updates, this method can be kept for manual refresh if needed
  Future<void> refreshAll() async {
    _logger.d(_tag, 'Refreshing data - streams handle automatic updates');
    // Streams are already active and handle real-time updates automatically
    // If you need to force a re-fetch for streams, you might need to re-initialize them
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      // Optionally reload summary for any other fields not covered by streams
      await loadSummary(); 
    }
    _logger.i(_tag, 'Data refresh completed');
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
    _logger.d(_tag, 'Disposing FriendsProvider and cancelling streams');
    _friendsSubscription?.cancel();
    _incomingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription?.cancel();
    // _summarySubscription?.cancel();
    super.dispose();
  }
}
