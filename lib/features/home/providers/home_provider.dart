import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/relationship_model.dart';
import '../../../core/repositories/relationship_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/auth/auth_service_interface.dart';

/// Provider for managing home screen state
/// 
/// Extends FriendsProvider functionality to show only friends list
/// with real-time updates via streams
class HomeProvider extends ChangeNotifier {
  final RelationshipRepository _relationshipRepository;
  final AuthServiceInterface _authService;
  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'HOME_PROVIDER';

  // Stream Subscription for friends only
  StreamSubscription<List<RelationshipModel>>? _friendsSubscription;

  // Friends data
  List<RelationshipModel> _friends = [];

  // Loading states
  bool _isLoadingFriends = false;

  // Error states
  String? _error;

  /// Creates a new HomeProvider
  HomeProvider({
    RelationshipRepository? relationshipRepository,
    AuthServiceInterface? authService,
  }) : _relationshipRepository = relationshipRepository ?? serviceLocator<RelationshipRepository>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>();

  // Getters
  List<RelationshipModel> get friends => List.unmodifiable(_friends);
  bool get isLoadingFriends => _isLoadingFriends;
  String? get error => _error;
  int get friendsCount => _friends.length;

  /// Initialize the provider - loads friends and sets up stream
  Future<void> initialize() async {
    _logger.d(_tag, 'Initializing HomeProvider');
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _logger.w(_tag, 'Cannot initialize HomeProvider: user not authenticated');
      return;
    }

    _setupFriendsStream(currentUser.uid);
    _logger.i(_tag, 'HomeProvider initialized with friends stream');
  }

  void _setupFriendsStream(String userId) {
    _friendsSubscription?.cancel();
    _isLoadingFriends = true;
    notifyListeners();

    _friendsSubscription = _relationshipRepository.getFriendsStream().listen(
      (friendsList) {
        _logger.d(_tag, 'Friends list updated from stream: ${friendsList.length} friends');
        _friends = friendsList;
        _isLoadingFriends = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _logger.e(_tag, 'Error in friends stream: ${e.toString()}');
        _error = _getErrorMessage(e);
        _isLoadingFriends = false;
        notifyListeners();
      },
      onDone: () {
        _logger.d(_tag, 'Friends stream completed');
        _isLoadingFriends = false;
        notifyListeners();
      }
    );
  }

  /// Get cached profile for a relationship
  CachedProfile? getCachedProfile(RelationshipModel relationship, String currentUserId) {
    final friendId = relationship.getFriendId(currentUserId);
    return relationship.getCachedProfile(friendId);
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    return 'Failed to load friends';
  }

  @override
  void dispose() {
    _logger.d(_tag, 'Disposing HomeProvider and cancelling streams');
    _friendsSubscription?.cancel();
    super.dispose();
  }
}
