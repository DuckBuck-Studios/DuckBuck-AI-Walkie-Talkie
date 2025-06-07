import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../service_locator.dart';
import 'auth_service_interface.dart';
import '../../repositories/user_repository.dart';
import '../logger/logger_service.dart';
import '../../exceptions/auth_exceptions.dart';

/// Manages security aspects of authentication including:
/// - Token refresh management and rotation
/// - Credential validation for sensitive operations
/// - Auth state caching
/// - Security verification for auth operations
class AuthSecurityManager {
  final AuthServiceInterface _authService;
  final UserRepository _userRepository;
  final LoggerService _logger;
  final String _tag = 'AuthSecurityManager';
  
  // Token management constants
  static const int _tokenRefreshThresholdMinutes = 45; // Refresh tokens before they expire
  
  // Cache for last token refresh time
  DateTime? _lastTokenRefresh;
  Timer? _tokenRefreshTimer;

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

  /// Initialize the security manager and set up token refresh monitoring
  Future<void> initialize() async {
    _logger.d(_tag, 'Auth security manager initialized with enhanced token management');
    // Schedule first token refresh check
    _scheduleTokenRefresh();
  }

  /// Start auth monitoring for a new user login 
  void startUserSession() {
    _logger.d(_tag, 'Starting auth monitoring for user session');
    // Setup proactive token refresh
    _scheduleTokenRefresh();
  }

  /// End auth monitoring when user logs out
  void endUserSession() {
    _logger.d(_tag, 'Ending auth monitoring for user session');
    // Cancel any pending token refresh
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Schedule periodic token refresh to prevent expiration
  void _scheduleTokenRefresh() {
    // Cancel any existing timer
    _tokenRefreshTimer?.cancel();
    
    // Create a new timer for regular refresh checks
    _tokenRefreshTimer = Timer.periodic(
      Duration(minutes: _tokenRefreshThresholdMinutes ~/ 3), 
      (_) => _checkAndRefreshTokenIfNeeded()
    );
  }
  
  /// Check and refresh the token if it's getting close to expiry
  Future<void> _checkAndRefreshTokenIfNeeded() async {
    try {
      // Only refresh if we're logged in
      if (_authService.currentUser == null) {
        _logger.d(_tag, 'No user logged in, skipping token refresh');
        return;
      }
      
      // Check if we need to refresh based on last refresh time
      final now = DateTime.now();
      if (_lastTokenRefresh != null) {
        final refreshIntervalMinutes = _getRefreshInterval();
        final minutesSinceLastRefresh = now.difference(_lastTokenRefresh!).inMinutes;
        
        if (minutesSinceLastRefresh < refreshIntervalMinutes) {
          _logger.d(_tag, 'Token still fresh (refreshed $minutesSinceLastRefresh min ago, refresh interval $refreshIntervalMinutes min)');
          return;
        }
        
        _logger.i(_tag, 'Token refresh needed ($minutesSinceLastRefresh min since last refresh)');
      } else {
        _logger.i(_tag, 'Initial token refresh after login');
      }
      
      // Refresh token and update timestamp
      await refreshIdToken(forceRefresh: false);
    } catch (e) {
      _logger.w(_tag, 'Automatic token refresh failed: ${e.toString()}');
      // Don't throw - this is a background operation
      
      // Schedule another refresh attempt sooner than normal if this one failed
      _scheduleRetryAfterFailure();
    }
  }
  
  /// Schedule a retry after a token refresh failure
  void _scheduleRetryAfterFailure() {
    // Cancel any existing timer
    _tokenRefreshTimer?.cancel();
    
    // Schedule a retry in a shorter time period
    _tokenRefreshTimer = Timer(
      Duration(minutes: 5), // Try again in 5 minutes
      () {
        _checkAndRefreshTokenIfNeeded();
        // After retry, resume normal schedule
        _scheduleTokenRefresh();
      }
    );
  }
  
  /// Get dynamic refresh interval based on usage patterns
  int _getRefreshInterval() {
    // Standard refresh interval is 45 minutes, but we refresh at 30 minutes to be safe
    return (_tokenRefreshThresholdMinutes * 2) ~/ 3;
  }

  /// Refresh auth token with error handling and logging
  Future<String?> refreshIdToken({bool forceRefresh = false}) async {
    try {
      final token = await _authService.refreshIdToken(forceRefresh: forceRefresh);
      _lastTokenRefresh = DateTime.now();
      _logger.d(_tag, 'Auth token refreshed successfully');
      return token;
    } catch (e) {
      _logger.e(_tag, 'Token refresh failed', e);
      // Re-throw with standardized exception
      throw AuthException(
        AuthErrorCodes.tokenRefreshFailed,
        'Failed to refresh authentication token. Please re-authenticate.',
        e,
      );
    }
  }

  /// Check if the current auth token is valid and refresh if needed
  /// This is the public method used by app components
  Future<String?> ensureValidToken() async {
    try {
      _logger.d(_tag, 'Ensuring valid auth token for user');
      
      // Force-refresh token if we haven't refreshed before or it's been over 30 minutes
      bool forceRefresh = _lastTokenRefresh == null || 
          DateTime.now().difference(_lastTokenRefresh!).inMinutes > 30;
      
      final token = await refreshIdToken(forceRefresh: forceRefresh);
      return token;
    } catch (e) {
      _logger.e(_tag, 'Token validation failed', e);
      
      // Try once more with force refresh if the first attempt failed
      if (!e.toString().contains('force-refreshed')) {
        try {
          _logger.w(_tag, 'Retrying token refresh with force=true');
          final token = await refreshIdToken(forceRefresh: true);
          return token;
        } catch (retryError) {
          _logger.e(_tag, 'Force-refreshed token validation failed', retryError);
          throw AuthException(
            AuthErrorCodes.tokenRefreshFailed,
            'Failed to refresh authentication token even after forced refresh. Please re-authenticate.',
            retryError,
          );
        }
      }
      
      rethrow;
    }
  }

  /// Validate a credential for sensitive operations and throw exceptions rather than silent failure
  /// This is used for re-authentication before sensitive operations like account deletion
  Future<bool> validateCredential(AuthCredential credential) async {
    try {
      _logger.i(_tag, 'Validating user credential for sensitive operation');
      
      // Check if user is logged in first
      if (_authService.currentUser == null) {
        _logger.e(_tag, 'Cannot validate credential: No user is logged in');
        throw AuthException(
          AuthErrorCodes.notLoggedIn,
          'No user is currently logged in. Please log in first.',
        );
      }
      
      // Use the auth service to validate the credential
      final isValid = await _authService.validateCredential(credential);
      
      if (!isValid) {
        _logger.w(_tag, 'Credential validation failed: Invalid credential provided');
        throw AuthException(
          AuthErrorCodes.credentialValidationFailed,
          'The credential provided is invalid. Please try again with correct credentials.',
          null,
          _determineAuthMethodFromCredential(credential)
        );
      }
      
      _logger.i(_tag, 'Credential validation successful');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Credential validation failed', e);
      
      if (e is AuthException) {
        rethrow;
      }
      
      throw AuthException(
        AuthErrorCodes.credentialValidationFailed,
        'Failed to validate your credentials. Please log out and log in again.',
        e,
      );
    }
  }
  
  /// Determine the authentication method from a credential
  AuthMethod? _determineAuthMethodFromCredential(AuthCredential credential) {
    if (credential is PhoneAuthCredential) {
      return AuthMethod.phone;
    } else if (credential.providerId == 'google.com') {
      return AuthMethod.google;
    } else if (credential.providerId == 'apple.com') {
      return AuthMethod.apple;
    }
    return null;
  }

  /// Get user with cached data for better performance
  /// This method optimizes user data retrieval by using cached data when possible
  Future<dynamic> getCurrentUserWithCache() async {
    try {
      _logger.i(_tag, 'Getting current user with cache optimization');
      
      // Check if user is logged in first
      if (_authService.currentUser == null) {
        _logger.d(_tag, 'No user is logged in, returning null');
        return null;
      }
      
      // Use UserRepository's getCurrentUser method which handles local database caching
      final cachedUser = await _userRepository.getCurrentUser();
      if (cachedUser != null) {
        _logger.i(_tag, 'Retrieved user with cached data including local photo');
        return cachedUser;
      }
      
      // Fallback to current user
      _logger.d(_tag, 'No cached user found, using current user');
      return _userRepository.currentUser;
       
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached user data', e);
      
      // Log to track cache failures (no analytics to avoid dependencies)
      _logger.w(_tag, 'Falling back to non-cached user data method');
      
      // Fallback to standard non-cached method as a recovery mechanism
      return _userRepository.currentUser;
    }
  }
}
