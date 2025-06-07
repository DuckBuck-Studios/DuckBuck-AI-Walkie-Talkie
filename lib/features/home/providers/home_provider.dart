import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../friends/providers/relationship_provider.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';

/// Provider for managing home screen state
/// 
/// This provider extends RelationshipProvider functionality to show only friends list
/// with real-time updates. Instead of setting up its own streams, it listens to
/// the RelationshipProvider for changes to avoid duplicate stream listeners.
/// 
/// Features:
/// - Real-time friends list updates via RelationshipProvider
/// - No duplicate stream setup - reuses existing relationship streams
/// - Automatic UI updates when friends are added/removed
/// - Automatic UI updates when friend profiles change
/// - Loading states and error handling
class HomeProvider extends ChangeNotifier {
  final RelationshipProvider _relationshipProvider;
  final LoggerService _logger;
  
  static const String _tag = 'HOME_PROVIDER';

  // Local state for home-specific functionality
  bool _isInitialized = false;

  /// Creates a new HomeProvider
  HomeProvider({
    RelationshipProvider? relationshipProvider,
    LoggerService? logger,
  }) : _relationshipProvider = relationshipProvider ?? serviceLocator<RelationshipProvider>(),
       _logger = logger ?? serviceLocator<LoggerService>() {
    
    // Listen to changes in the relationship provider
    _relationshipProvider.addListener(_onRelationshipProviderChanged);
  }

  // ==========================================================================
  // GETTERS - Delegate to RelationshipProvider
  // ==========================================================================

  /// List of friends (accepted relationships) - delegates to RelationshipProvider
  List<Map<String, dynamic>> get friends => _relationshipProvider.friends;

  /// Loading state for friends list - delegates to RelationshipProvider
  bool get isLoadingFriends => _relationshipProvider.isLoadingFriends;

  /// Error state - delegates to RelationshipProvider
  String? get error => _relationshipProvider.error;

  /// Count of friends
  int get friendsCount => friends.length;

  /// Whether the provider has been initialized
  bool get isInitialized => _isInitialized;

  /// Current user UID from RelationshipProvider
  String? get currentUserUid => _relationshipProvider.currentUserUid;

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initialize the provider - ensures RelationshipProvider is initialized
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.d(_tag, 'HomeProvider already initialized');
      return;
    }

    _logger.d(_tag, 'Initializing HomeProvider');
    
    // Ensure RelationshipProvider is initialized
    // This will set up the streams if not already done
    await _relationshipProvider.initialize();
    
    _isInitialized = true;
    _logger.i(_tag, 'HomeProvider initialized successfully');
    
    // Notify listeners since we might have new data
    notifyListeners();
  }

  // ==========================================================================
  // EVENT HANDLERS
  // ==========================================================================

  /// Called when RelationshipProvider changes
  void _onRelationshipProviderChanged() {
    _logger.d(_tag, 'RelationshipProvider changed - updating Home UI');
    // Propagate the change to home screen listeners
    notifyListeners();
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  /// Get cached profile for a friend by user ID
  Map<String, dynamic>? getFriendProfile(String userId) {
    try {
      return friends.firstWhere(
        (friend) => friend['uid'] == userId,
        orElse: () => {},
      );
    } catch (e) {
      _logger.w(_tag, 'Friend profile not found for userId: $userId');
      return null;
    }
  }

  /// Check if a user is a friend
  bool isFriend(String userId) {
    return friends.any((friend) => friend['uid'] == userId);
  }

  /// Get friends count for display
  String get friendsCountDisplay {
    final count = friendsCount;
    if (count == 0) return 'No friends yet';
    if (count == 1) return '1 friend';
    return '$count friends';
  }

  /// Clear error state - delegates to RelationshipProvider
  void clearError() {
    _relationshipProvider.clearError();
  }

  /// Refresh friends data - delegates to RelationshipProvider
  Future<void> refresh() async {
    _logger.d(_tag, 'Refreshing friends data');
    await _relationshipProvider.refresh();
  }

  /// Get summary for display
  Map<String, dynamic> getHomeSummary() {
    return {
      'friendsCount': friendsCount,
      'isLoading': isLoadingFriends,
      'hasError': error != null,
      'isInitialized': _isInitialized,
    };
  }

  // ==========================================================================
  // DISPOSAL
  // ==========================================================================

  @override
  void dispose() {
    _logger.d(_tag, 'Disposing HomeProvider');
    
    // Remove listener from RelationshipProvider
    _relationshipProvider.removeListener(_onRelationshipProviderChanged);
    
    super.dispose();
  }
}
