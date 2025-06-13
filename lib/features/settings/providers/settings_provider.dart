import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/models/user_model.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../friends/providers/relationship_provider.dart';

/// Provider specifically for the Settings screen
/// 
/// This provider listens to real-time user changes and ensures the settings UI
/// is always up-to-date with the latest user data, including cached photos.
/// Also provides blocked users functionality from RelationshipProvider.
class SettingsProvider extends ChangeNotifier {
  final UserRepository _userRepository;
  final RelationshipProvider _relationshipProvider;
  final LoggerService _logger;
  static const String _tag = 'SETTINGS_PROVIDER';
  
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _userStreamSubscription;

  /// Creates a new SettingsProvider
  SettingsProvider({
    UserRepository? userRepository,
    RelationshipProvider? relationshipProvider,
    LoggerService? logger,
  }) : _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _relationshipProvider = relationshipProvider ?? serviceLocator<RelationshipProvider>(),
       _logger = logger ?? serviceLocator<LoggerService>() {
    _init();
  }

  /// Initialize the provider and start listening to user changes
  void _init() {
    _logger.i(_tag, '🔧 Initializing SettingsProvider with reactive user stream');
    
    // Start listening to the reactive user stream that combines Firebase and local DB
    _userStreamSubscription = _userRepository.getUserReactiveStream().listen(
      (user) {
        _logger.i(_tag, '👤 User data updated from stream');
        if (user != null) {
          _logger.i(_tag, '📸 Updated user photoURL: ${user.photoURL}');
        }
        
        final userChanged = _currentUser?.uid != user?.uid || 
                           _currentUser?.photoURL != user?.photoURL ||
                           _currentUser?.displayName != user?.displayName ||
                           _currentUser?.email != user?.email;
        
        if (userChanged) {
          _currentUser = user;
          _isLoading = false;
          _errorMessage = null;
          _logger.i(_tag, '🔄 Notifying UI of user data changes');
          notifyListeners();
        }
      },
      onError: (error) {
        _logger.e(_tag, 'Error in user stream: ${error.toString()}');
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
    
    // Also load initial cached user data immediately
    _loadInitialUserData();
  }

  /// Load initial user data from cache for immediate display
  Future<void> _loadInitialUserData() async {
    try {
      _logger.i(_tag, '⚡ Loading initial cached user data');
      final cachedUser = await _userRepository.getCurrentUser();
      
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _isLoading = false;
        _logger.i(_tag, '✅ Initial cached user loaded');
        _logger.i(_tag, '📸 Initial user photoURL: ${cachedUser.photoURL}');
        notifyListeners();
      } else {
        _logger.w(_tag, '⚠️ No initial cached user found');
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _logger.e(_tag, 'Failed to load initial user data: ${e.toString()}');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Current user with real-time updates
  UserModel? get currentUser => _currentUser;

  /// Whether data is loading
  bool get isLoading => _isLoading;

  /// Last error message, if any
  String? get errorMessage => _errorMessage;

  /// Whether user is authenticated
  bool get isAuthenticated => _currentUser != null;

  /// Refresh user data manually
  Future<void> refreshUserData() async {
    try {
      _logger.i(_tag, '🔄 Manual refresh requested');
      _isLoading = true;
      notifyListeners();
      
      final refreshedUser = await _userRepository.getCurrentUser();
      if (refreshedUser != null) {
        _currentUser = refreshedUser;
        _logger.i(_tag, '✅ Manual refresh completed');
        _logger.i(_tag, '📸 Refreshed user photoURL: ${refreshedUser.photoURL}');
      }
      
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _logger.e(_tag, 'Manual refresh failed: ${e.toString()}');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear any error messages
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ==========================================================================
  // BLOCKED USERS FUNCTIONALITY (from RelationshipProvider)
  // ==========================================================================

  /// List of blocked users from RelationshipProvider
  List<Map<String, dynamic>> get blockedUsers => _relationshipProvider.blockedUsers;

  /// Loading state for blocked users
  bool get isLoadingBlockedUsers => _relationshipProvider.isLoadingBlockedUsers;

  /// Whether an unblock user operation is processing for a specific user
  bool isProcessingUnblockUser(String userId) => _relationshipProvider.isProcessingUnblockUser(userId);

  /// RelationshipProvider error state
  String? get relationshipError => _relationshipProvider.error;

  /// Unblock a user using RelationshipProvider
  /// Returns true if successful, false otherwise
  Future<bool> unblockUser(String targetUserId) async {
    _logger.d(_tag, 'Unblocking user via RelationshipProvider: $targetUserId');
    
    final result = await _relationshipProvider.unblockUser(targetUserId);
    
    if (result) {
      _logger.i(_tag, 'User unblocked successfully: $targetUserId');
    } else {
      _logger.e(_tag, 'Failed to unblock user: $targetUserId');
    }
    
    return result;
  }

  /// Initialize RelationshipProvider to ensure blocked users streams are active
  /// This ensures blocked users streams are active when the settings screen is opened
  Future<void> initializeRelationshipProvider() async {
    _logger.d(_tag, 'Ensuring RelationshipProvider is initialized for blocked users');
    
    try {
      await _relationshipProvider.initialize();
      _logger.i(_tag, 'RelationshipProvider initialized for settings');
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize RelationshipProvider: $e');
      // Don't rethrow as this is a best-effort initialization
    }
  }

  /// Clear relationship error messages
  void clearRelationshipError() {
    _relationshipProvider.clearError();
  }

  @override
  void dispose() {
    _logger.i(_tag, '🧹 Disposing SettingsProvider');
    _userStreamSubscription?.cancel();
    super.dispose();
  }
}
