import 'package:firebase_auth/firebase_auth.dart';
import '../service_locator.dart';
import 'auth_service_interface.dart';
import 'session_manager.dart';
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
  late SessionManager _sessionManager;
  static const String _tag = 'AUTH_SECURITY';
  
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
  }) : _authService = authService,
       _userRepository = userRepository,
       _logger = logger;
  
  /// Initialize the security manager
  Future<void> initialize({required Function() onSessionExpired}) async {
    // Create session manager with timeout handling
    _sessionManager = await SessionManager.create(
      onSessionExpired: onSessionExpired,
    );
    
    _logger.d(_tag, 'Auth security manager initialized');
  }
  
  /// Start tracking user session
  void startUserSession() {
    _sessionManager.startSessionTimer();
    _logger.d(_tag, 'User session tracking started');
  }
  
  /// Update user activity to prevent timeout
  void updateUserActivity() {
    _sessionManager.updateActivity();
  }
  
  /// End the user session
  void endUserSession() {
    _sessionManager.clearSession();
    _logger.d(_tag, 'User session ended');
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
  
  /// Get remaining session time
  Duration get remainingSessionTime => _sessionManager.remainingTime;
  
  /// Dispose resources to prevent memory leaks
  void dispose() {
    _sessionManager.dispose();
    _logger.d(_tag, 'Auth security manager resources released');
  }
  
  /// Validate and update session timeout duration
  /// Returns true if timeout was updated successfully
  Future<bool> updateSessionTimeout(int seconds) async {
    // Ensure timeout value is within reasonable bounds (5 min to 4 hours)
    if (seconds < 300 || seconds > 14400) {
      _logger.w(_tag, 'Invalid session timeout value: $seconds seconds');
      return false;
    }
    
    try {
      await _sessionManager.updateSessionTimeout(seconds);
      _logger.d(_tag, 'Session timeout updated to $seconds seconds');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Failed to update session timeout', e);
      return false;
    }
  }
}
