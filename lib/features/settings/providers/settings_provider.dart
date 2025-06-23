import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/models/user_model.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';

/// Provider specifically for the Settings screen
/// 
/// This provider listens to real-time user changes and ensures the settings UI
/// is always up-to-date with the latest user data, including cached photos.
class SettingsProvider extends ChangeNotifier {
  final UserRepository _userRepository;
  final LoggerService _logger;
  static const String _tag = 'SETTINGS_PROVIDER';
  
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _userStreamSubscription;

  /// Creates a new SettingsProvider
  SettingsProvider({
    UserRepository? userRepository,
    LoggerService? logger,
  }) : _userRepository = userRepository ?? serviceLocator<UserRepository>(),
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

  // Note: Blocked users functionality has been moved to SharedFriendsProvider
  // If blocked users management is needed in settings, use SharedFriendsProvider instead

  @override
  void dispose() {
    _logger.i(_tag, '🧹 Disposing SettingsProvider');
    _userStreamSubscription?.cancel();
    super.dispose();
  }
}
