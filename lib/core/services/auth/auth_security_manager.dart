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
  late SessionManager _sessionManager;
  static const String _tag = 'AUTH_SECURITY';
  
  // Get logger service from service locator
  LoggerService get _logger => serviceLocator<LoggerService>();
  
  // Singleton implementation
  static final AuthSecurityManager _instance = AuthSecurityManager._internal();
  factory AuthSecurityManager() => _instance;
  
  AuthSecurityManager._internal() 
    : _authService = serviceLocator<AuthServiceInterface>(),
      _userRepository = serviceLocator<UserRepository>();
  
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
  
  /// Check if session is active
  bool get isSessionActive => _sessionManager.isSessionActive;
}
