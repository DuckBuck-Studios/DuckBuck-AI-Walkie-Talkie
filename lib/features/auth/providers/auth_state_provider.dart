import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/models/user_model.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/exceptions/auth_exceptions.dart';
import '../../../core/services/auth/auth_security_manager.dart';
import '../../../core/services/database/local_database_service.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../friends/providers/relationship_provider.dart';

/// Provider that manages authentication state throughout the app
///
/// This class uses the ChangeNotifier pattern to broadcast authentication state
/// changes to all listening widgets. It serves as a bridge between the UI and
/// the UserRepository that handles the actual authentication logic.
class AuthStateProvider extends ChangeNotifier {
  final UserRepository _userRepository;
  final AuthSecurityManager _securityManager;
  final LoggerService _logger;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _authSubscription;
  
  static const String _tag = 'AUTH_PROVIDER';

  /// Creates a new AuthStateProvider
  AuthStateProvider({
    UserRepository? userRepository,
    AuthSecurityManager? securityManager,
    LoggerService? logger,
  }) : _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _securityManager = securityManager ?? serviceLocator<AuthSecurityManager>(),
       _logger = logger ?? serviceLocator<LoggerService>() {
    _init();
  }

  /// Initialize the provider and listen for auth state changes
  void _init() {
    // Note: Notification service initialization is now handled by Kotlin/Android side
    // _notificationsService.initialize(); - No longer needed

    // Listen for auth changes - properly store subscription for disposal
    _authSubscription = _userRepository.userStream.listen((user) {
      // Only notify if user actually changed to avoid excessive rebuilds
      final userChanged = _currentUser?.uid != user?.uid;
      _currentUser = user;

      // When user logs in, update login state and start monitoring
      if (user != null) {
        // Note: FCM token registration is now handled by Kotlin/Android side
        
        // Update login status in local database (async but don't await to avoid blocking UI)
        Future(() async {
          try {
            final localDb = LocalDatabaseService.instance;
            await localDb.setUserLoggedIn(user.uid, true);
            
            // Start Firebase document monitoring for reactive updates
            await _userRepository.startUserDocumentMonitoring();
            _logger.i(_tag, 'Started Firebase document monitoring for user: ${user.uid}');
          } catch (e) {
            _logger.e(_tag, 'Failed to update login status or start monitoring: $e');
          }
        });
      } else {
        // User logged out, stop monitoring
        Future(() async {
          try {
            await _userRepository.stopUserDocumentMonitoring();
            _logger.i(_tag, 'Stopped Firebase document monitoring');
          } catch (e) {
            _logger.e(_tag, 'Failed to stop user document monitoring: $e');
          }
        });
      }

      // Only notify listeners if something meaningful changed
      if (userChanged) {
        notifyListeners();
      }
    });

    // Load current user immediately if available (but load complete data in background)
    _currentUser = _userRepository.currentUser; // This might have agentRemainingTime: 0
    if (_currentUser != null) {
      // Note: FCM token registration is now handled by Kotlin/Android side
      
      // Load complete user data in background and update _currentUser
      Future(() async {
        try {
          final completeUser = await _userRepository.getCurrentUser();
          if (completeUser != null && completeUser.uid == _currentUser?.uid) {
            _currentUser = completeUser;
            _logger.i(_tag, 'Updated current user with complete data (agentRemainingTime: ${completeUser.agentRemainingTime}s)');
            notifyListeners(); // Notify UI of the complete data update
          }
        } catch (e) {
          _logger.e(_tag, 'Failed to load complete user data: $e');
        }
      });
      
      // Update login status in local database and start monitoring (async but don't await to avoid blocking initialization)
      Future(() async {
        try {
          final localDb = LocalDatabaseService.instance;
          await localDb.setUserLoggedIn(_currentUser!.uid, true);
          
          // Start Firebase document monitoring for reactive updates
          await _userRepository.startUserDocumentMonitoring();
          _logger.i(_tag, 'Started Firebase document monitoring for existing user: ${_currentUser!.uid}');
        } catch (e) {
          _logger.e(_tag, 'Failed to update login status or start monitoring during init: $e');
        }
      });
      
      // Start session tracking for already authenticated users
      _securityManager.startUserSession();
    }
  }

  /// Current authenticated user, if any
  UserModel? get currentUser => _currentUser;
  
  /// Get current user with enhanced performance using caching
  Future<UserModel?> getCurrentUserWithCache() async {
    try {
      final user = await _securityManager.getCurrentUserWithCache();
      return user as UserModel?;
    } catch (e) {
      _logger.e(_tag, 'Error getting cached user: $e');
      return _currentUser;
    }
  }

  /// Whether authentication operations are in progress
  bool get isLoading => _isLoading;

  /// Last error message from authentication operations
  String? get errorMessage => _errorMessage;

  /// Whether the user is authenticated
  bool get isAuthenticated => _currentUser != null;

  /// Sign in with Google
  Future<(UserModel, bool)> signInWithGoogle() async {
    _logger.i(_tag, 'Starting Google sign-in flow...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Delegating to user repository...');
      final (user, isNewUser) = await _userRepository.signInWithGoogle();

      _logger.i(_tag, 'Google sign-in successful for user: ${user.displayName ?? 'Unknown'}, isNewUser: $isNewUser');
      
      // Start tracking user session
      _securityManager.startUserSession();
      
      // Ensure we have a valid token
      await _securityManager.ensureValidToken();
      
      _errorMessage = null;
      return (user, isNewUser);
    } catch (e) {
      _logger.e(_tag, 'Google sign-in failed: ${e.toString()}');
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _logger.d(_tag, 'Google sign-in flow completed, isLoading set to false');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Apple
  Future<(UserModel, bool)> signInWithApple() async {
    _logger.i(_tag, 'Starting Apple sign-in flow...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Delegating to user repository...');
      final (user, isNewUser) = await _userRepository.signInWithApple();

      _logger.i(_tag, 'Apple sign-in successful for user: ${user.displayName ?? 'Unknown'}, isNewUser: $isNewUser');
      
      // Start tracking user session
      _securityManager.startUserSession();
      
      // Ensure we have a valid token
      await _securityManager.ensureValidToken();
      
      _errorMessage = null;
      return (user, isNewUser);
    } catch (e) {
      _logger.e(_tag, 'Apple sign-in failed: ${e.toString()}');
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _logger.d(_tag, 'Apple sign-in flow completed, isLoading set to false');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initialize phone number verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(String) onError,
    required Function() onVerified,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (_) {
          _isLoading = false;
          notifyListeners();
          onVerified();
        },
        verificationFailed: (AuthException e) {
          _errorMessage = e.message;
          _isLoading = false;
          notifyListeners();
          onError(e.message);
        },
        codeSent: (verificationId, resendToken) {
          _isLoading = false;
          notifyListeners();
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (_) {
          // Auto-retrieval timeout, handle if needed
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      onError(e.toString());
    }
  }

  /// Verify OTP code and sign in
  Future<(UserModel, bool)> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final (user, isNewUser) = await _userRepository.verifyOtpAndSignIn(
        verificationId: verificationId,
        smsCode: smsCode,
        phoneNumber: phoneNumber,
      );

      _logger.i(_tag, 'Phone OTP verification successful, isNewUser: $isNewUser');
      
      // Start tracking user session
      _securityManager.startUserSession();
      
      // Ensure we have a valid token
      await _securityManager.ensureValidToken();
      
      _errorMessage = null;
      return (user, isNewUser);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with PhoneAuthCredential
  Future<(UserModel, bool)> signInWithPhoneAuthCredential(
    dynamic credential,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _logger.d(_tag, 'Processing phone auth credential');
      final (user, isNewUser) = await _userRepository
          .signInWithPhoneAuthCredential(credential);

      _logger.i(_tag, 'Phone auth successful for user: ${user.phoneNumber ?? 'Unknown'}, isNewUser: $isNewUser');
      
      // Start tracking user session
      _securityManager.startUserSession();
      
      // Ensure we have a valid token
      await _securityManager.ensureValidToken();
      
      _errorMessage = null;
      return (user, isNewUser);
    } catch (e) {
      _logger.e(_tag, 'Phone auth failed: ${e.toString()}');
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _logger.d(_tag, 'Phone auth flow completed, isLoading set to false');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // End the user session first
      _securityManager.endUserSession();
      _logger.i(_tag, 'Ending user session...');
      
      // Stop Firebase document monitoring before signing out
      await _userRepository.stopUserDocumentMonitoring();
      _logger.i(_tag, 'Stopped Firebase document monitoring');
      
      // CRITICAL: Close RelationshipProvider streams before signout to prevent memory leaks
      // This ensures all relationship streams are properly closed and no background operations continue
      _logger.i(_tag, 'Closing RelationshipProvider streams...');
      try {
        final relationshipProvider = serviceLocator<RelationshipProvider>();
        relationshipProvider.closeStreams(); // Use closeStreams() instead of dispose()
        _logger.i(_tag, 'RelationshipProvider streams closed successfully');
      } catch (e) {
        _logger.w(_tag, 'Warning - Error closing RelationshipProvider streams: $e');
        // Continue with signout even if relationship provider stream closure fails
      }
      
      // Use UserRepository.signOut() for proper architecture flow: UI → Provider → Repository → Service
      // This handles Firebase auth logout and FCM token removal
      _logger.i(_tag, 'Using UserRepository.signOut() for proper layering');
      await _userRepository.signOut();
      
      // Note: Local database cleanup is handled by UserRepository.signOut()
      _logger.i(_tag, 'Local database cleared by UserRepository');
      
      _logger.i(_tag, 'User signed out successfully');
    } catch (e) {
      _errorMessage = e.toString();
      _logger.e(_tag, 'Error during sign-out process: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userRepository.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      // Force refresh the current user with complete data
      _currentUser = await _userRepository.getCurrentUser();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear any error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Validate a user credential for security-sensitive operations
  Future<bool> validateCredential(dynamic credential) async {
    try {
      // Use repository layer for proper architecture: UI → Provider → Repository → Service
      return await _userRepository.validateCredential(credential);
    } catch (e) {
      _errorMessage = e.toString();
      _logger.e(_tag, 'Credential validation failed: ${e.toString()}');
      return false;
    }
  }

  /// Check if a user is new (doesn't exist in Firestore)
  Future<bool> checkIfUserIsNew(String uid) {
    return _userRepository.checkIfUserIsNew(uid);
  }

  /// Mark user's onboarding as complete (removes isNewUser flag)
  Future<void> markUserOnboardingComplete() async {
    if (_currentUser == null) {
      throw AuthException(
        AuthErrorCodes.notLoggedIn,
        'No user is currently signed in',
      );
    }
    
    try {
      await _userRepository.markUserOnboardingComplete(_currentUser!.uid);
      _logger.i(_tag, 'User onboarding marked as complete');
    } catch (e) {
      _logger.e(_tag, 'Error marking onboarding complete: ${e.toString()}');
      rethrow;
    }
  }

  /// Delete the current user account and all associated data
  /// 
  /// This method follows proper architecture by using the UI → Provider → Repository pattern
  /// It handles all cleanup including FCM tokens, Firestore data, and Firebase Auth deletion
  Future<void> deleteUserAccount() async {
    _logger.i(_tag, 'Starting user account deletion process...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser == null) {
        throw AuthException(
          AuthErrorCodes.notLoggedIn,
          'No user is currently signed in',
        );
      }

      final userIdToDelete = _currentUser!.uid;
      _logger.i(_tag, 'Deleting account for user: $userIdToDelete');
      
      // End the user session before deletion
      _securityManager.endUserSession();
      
      // Stop Firebase document monitoring before deletion
      await _userRepository.stopUserDocumentMonitoring();
      _logger.i(_tag, 'Stopped Firebase document monitoring');
      
      // Cancel auth subscription FIRST to prevent any auth state change notifications during deletion
      await _authSubscription?.cancel();
      _authSubscription = null;
      _logger.i(_tag, 'Auth subscription canceled to prevent state conflicts');
      
      // Clear the current user state immediately to prevent any further operations
      _currentUser = null;
      
      // Note: Local database cleanup will be handled by UserRepository.deleteUserAccount()
      _logger.i(_tag, 'Local database will be cleared by UserRepository');
      
      // Delegate the actual deletion to the repository
      // This handles: FCM token removal, Firestore deletion, backend cleanup, Firebase Auth deletion
      await _userRepository.deleteUserAccount();
      
      _logger.i(_tag, 'User account deletion completed successfully');
      _errorMessage = null;
      
    } catch (e) {
      _logger.e(_tag, 'Account deletion failed: ${e.toString()}');
      _errorMessage = e.toString();
      
      // If deletion failed, we need to restore the auth state
      // Re-initialize the auth subscription
      _init();
      
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() { 
    // Clean up resources
    Future(() async {
      try {
        await _userRepository.dispose();
        _logger.i(_tag, 'UserRepository disposed successfully');
      } catch (e) {
        _logger.e(_tag, 'Error disposing UserRepository: $e');
      }
    });
    
    _authSubscription?.cancel();
    super.dispose();
  }
}
