import 'package:firebase_auth/firebase_auth.dart';
import '../service_locator.dart';
import 'auth_service_interface.dart';
import '../../repositories/user_repository.dart';
import '../logger/logger_service.dart';

/// Manages security aspects of authentication including:
/// - Token refresh management
/// - Session timeout handling
/// - Credential validation
/// - Auth state caching
class AuthSecurityManager {
  final AuthServiceInterface _authService;
  final UserRepository _userRepository;
  final LoggerService _logger;
  final String _tag = 'AuthSecurityManager';

  // Singleton implementation with improved dependency injection for testability
  static final AuthSecurityManager _instance = AuthSecurityManager._internal(
    authService: serviceLocator<AuthServiceInterface>(),
    userRepository: serviceLocator<UserRepository>(),
    logger: serviceLocator<LoggerService>(),
  );

  factory AuthSecurityManager({
    AuthServiceInterface? authService,
    UserRepository? userRepository,
    LoggerService? logger,
  }) {
    if (authService != null || userRepository != null || logger != null) {
      // If dependencies are provided, create a new instance for testing/custom use
      return AuthSecurityManager._internal(
        authService: authService ?? serviceLocator<AuthServiceInterface>(),
        userRepository: userRepository ?? serviceLocator<UserRepository>(),
        logger: logger ?? serviceLocator<LoggerService>(),
      );
    }
    // Otherwise return the singleton instance
    return _instance;
  }

  AuthSecurityManager._internal({
    required AuthServiceInterface authService,
    required UserRepository userRepository,
    required LoggerService logger,
  })  : _authService = authService,
        _userRepository = userRepository,
        _logger = logger;

  /// Initialize the security manager
  Future<void> initialize() async {
    _logger.d(_tag, 'Auth security manager initialized');
  }

  /// Start tracking user session (placeholder if SessionManager is removed)
  void startUserSession() {
    _logger.d(_tag, 'User session started (tracking logic removed)');
  }

  /// Update user activity (placeholder if SessionManager is removed)
  void updateUserActivity() {
    _logger.d(_tag, 'User activity updated (tracking logic removed)');
  }

  /// End the user session (placeholder if SessionManager is removed)
  void endUserSession() {
    _logger.d(_tag, 'User session ended (tracking logic removed)');
  }

  /// Check if the current session is active (placeholder if SessionManager is removed)
  bool isSessionActive() {
    _logger.d(_tag, 'Session active check (logic removed, returning false)');
    return false; // Defaulting to false as session management is removed
  }

  /// Get the last activity time (placeholder if SessionManager is removed)
  DateTime? getLastActivityTime() {
    _logger.d(_tag, 'Get last activity time (logic removed, returning null)');
    return null; // Defaulting to null
  }

  /// Get the session timeout duration (placeholder if SessionManager is removed)
  Duration? getSessionTimeoutDuration() {
    _logger.d(_tag, 'Get session timeout (logic removed, returning null)');
    return null; // Defaulting to null
  }

  /// Set a new session timeout duration (placeholder if SessionManager is removed)
  Future<void> setSessionTimeout(Duration timeout) async {
    _logger.d(_tag,
        'Set session timeout (logic removed): ${timeout.inSeconds} seconds');
  }

  /// Check if the current auth token is valid and refresh if needed
  Future<String?> ensureValidToken() async {
    try {
      return await _authService.refreshIdToken(forceRefresh: false);
    } catch (e) {
      _logger.e(_tag, 'Token validation failed', e);
      rethrow;
    }
  }

  /// Force refresh the authentication token
  Future<String?> forceTokenRefresh() async {
    try {
      return await _authService.refreshIdToken(forceRefresh: true);
    } catch (e) {
      _logger.e(_tag, 'Token refresh failed', e);
      rethrow;
    }
  }

  /// Validate a credential (useful before sensitive operations)
  Future<bool> validateCredential(AuthCredential credential) async {
    try {
      return await _authService.validateCredential(credential);
    } catch (e) {
      _logger.e(_tag, 'Credential validation failed', e);
      return false;
    }
  }

  /// Get user with cached data for better performance
  Future<dynamic> getCurrentUserWithCache() async {
    try {
      return await _userRepository.getCurrentUserWithCache();
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached user data', e);

      // Fallback to standard method
      return _userRepository.currentUser;
    }
  }
}
