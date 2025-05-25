import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/models/user_model.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/notifications/notifications_service.dart';
import '../../../core/exceptions/auth_exceptions.dart';
import '../../../core/services/auth/auth_security_manager.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/firebase/firebase_analytics_service.dart';
import '../../../core/services/firebase/firebase_crashlytics_service.dart';

/// Provider that manages authentication state throughout the app
///
/// This class uses the ChangeNotifier pattern to broadcast authentication state
/// changes to all listening widgets. It serves as a bridge between the UI and
/// the UserRepository that handles the actual authentication logic.
class AuthStateProvider extends ChangeNotifier {
  final UserRepository _userRepository;
  final NotificationsService _notificationsService;
  final AuthSecurityManager _securityManager;
  final AuthServiceInterface _authService;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _authSubscription;

  /// Creates a new AuthStateProvider
  AuthStateProvider({
    UserRepository? userRepository,
    NotificationsService? notificationsService,
    AuthSecurityManager? securityManager,
    AuthServiceInterface? authService,
  }) : _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _notificationsService = notificationsService ?? serviceLocator<NotificationsService>(),
       _securityManager = securityManager ?? serviceLocator<AuthSecurityManager>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>() {
    _init();
  }

  /// Initialize the provider and listen for auth state changes
  void _init() {
    // Initialize notification service
    _notificationsService.initialize();

    // Listen for auth changes - properly store subscription for disposal
    _authSubscription = _userRepository.userStream.listen((user) {
      // Only notify if user actually changed to avoid excessive rebuilds
      final userChanged = _currentUser?.uid != user?.uid;
      _currentUser = user;

      // When user logs in, register FCM token and update login state in preferences
      if (user != null) {
        // Register a new token on login
        _notificationsService.registerToken(user.uid);
        PreferencesService.instance.setLoggedIn(true);
      }

      // Only notify listeners if something meaningful changed
      if (userChanged) {
        notifyListeners();
      }
    });

    // Load current user immediately if available
    _currentUser = _userRepository.currentUser;
    if (_currentUser != null) {
      // Register token for immediate loading too
      _notificationsService.registerToken(_currentUser!.uid);
      PreferencesService.instance.setLoggedIn(true);
      
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
      debugPrint('Error getting cached user: $e');
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
    debugPrint('🔐 AUTH PROVIDER: Starting Google sign-in flow...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔐 AUTH PROVIDER: Delegating to user repository...');
      final (user, isNewUser) = await _userRepository.signInWithGoogle();

      debugPrint(
        '🔐 AUTH PROVIDER: Google sign-in successful for user: ${user.displayName ?? 'Unknown'}, isNewUser: $isNewUser',
      );
      
      // Start tracking user session
      _securityManager.startUserSession();
      
      // Ensure we have a valid token
      await _securityManager.ensureValidToken();
      
      _errorMessage = null;
      return (user, isNewUser);
    } catch (e) {
      debugPrint('🔐 AUTH PROVIDER: Google sign-in failed: ${e.toString()}');
      _errorMessage = e.toString();
      rethrow;
    } finally {
      debugPrint(
        '🔐 AUTH PROVIDER: Google sign-in flow completed, isLoading set to false',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Apple
  Future<(UserModel, bool)> signInWithApple() async {
    debugPrint('🔐 AUTH PROVIDER: Starting Apple sign-in flow...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔐 AUTH PROVIDER: Delegating to user repository...');
      final (user, isNewUser) = await _userRepository.signInWithApple();

      debugPrint(
        '🔐 AUTH PROVIDER: Apple sign-in successful for user: ${user.displayName ?? 'Unknown'}, isNewUser: $isNewUser',
      );
      
      // Start tracking user session
      _securityManager.startUserSession();
      
      // Ensure we have a valid token
      await _securityManager.ensureValidToken();
      
      _errorMessage = null;
      return (user, isNewUser);
    } catch (e) {
      debugPrint('🔐 AUTH PROVIDER: Apple sign-in failed: ${e.toString()}');
      _errorMessage = e.toString();
      rethrow;
    } finally {
      debugPrint(
        '🔐 AUTH PROVIDER: Apple sign-in flow completed, isLoading set to false',
      );
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
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final (user, isNewUser) = await _userRepository.verifyOtpAndSignIn(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      debugPrint(
        '🔐 AUTH PROVIDER: Phone OTP verification successful, isNewUser: $isNewUser',
      );
      
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
    PhoneAuthCredential credential,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔐 AUTH PROVIDER: Processing phone auth credential');
      final (user, isNewUser) = await _userRepository
          .signInWithPhoneAuthCredential(credential);

      debugPrint(
        '🔐 AUTH PROVIDER: Phone auth successful for user: ${user.phoneNumber ?? 'Unknown'}, isNewUser: $isNewUser',
      );
      
      // Start tracking user session
      _securityManager.startUserSession();
      
      // Ensure we have a valid token
      await _securityManager.ensureValidToken();
      
      _errorMessage = null;
      return (user, isNewUser);
    } catch (e) {
      debugPrint('🔐 AUTH PROVIDER: Phone auth failed: ${e.toString()}');
      _errorMessage = e.toString();
      rethrow;
    } finally {
      debugPrint(
        '🔐 AUTH PROVIDER: Phone auth flow completed, isLoading set to false',
      );
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
      debugPrint('🔐 AUTH PROVIDER: Ending user session...');
      
      // Get current user ID before signing out for cleanup purposes
      final userId = _currentUser?.uid;
      
      // Use AuthServiceInterface.signOut() for proper architecture flow: UI → Provider → Interface → Service
      // This handles Firebase auth logout and FCM token removal
      debugPrint('🔐 AUTH PROVIDER: Using AuthServiceInterface.signOut() for proper layering');
      await _authService.signOut();
      
      // Handle app-level cleanup that the provider is responsible for
      if (userId != null) {
        try {
          // Get analytics and crashlytics services for cleanup
          final analytics = serviceLocator.get<FirebaseAnalyticsService>();
          final crashlytics = serviceLocator.get<FirebaseCrashlyticsService>();
          
          // Log sign out event in analytics
          await analytics.logEvent(
            name: 'sign_out',
            parameters: {'user_id': userId},
          );
          
          // Clear crashlytics data
          await crashlytics.clearKeys();
          await crashlytics.setUserIdentifier('');
          await crashlytics.log('User signed out');
        } catch (e) {
          // Log but continue with sign out
          debugPrint('🔐 AUTH PROVIDER: Error during app-level cleanup: ${e.toString()}');
        }
      }
      
      // Clear login state and reset all auth-related preferences
      await PreferencesService.instance.setLoggedIn(false);
      await PreferencesService.instance.clearAll();
      
      debugPrint('🔐 AUTH PROVIDER: User signed out successfully');
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('🔐 AUTH PROVIDER: Error during sign-out process: ${e.toString()}');
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

      // Force refresh the current user
      _currentUser = _userRepository.currentUser;
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
  Future<bool> validateCredential(AuthCredential credential) async {
    try {
      return await _securityManager.validateCredential(credential);
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('🔐 AUTH PROVIDER: Credential validation failed: ${e.toString()}');
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
      throw Exception('No user is currently signed in');
    }
    
    try {
      await _userRepository.markUserOnboardingComplete(_currentUser!.uid);
      debugPrint('🔐 AUTH PROVIDER: User onboarding marked as complete');
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }
  
  @override
  void dispose() {
    // Cancel auth subscription to prevent memory leaks
    _authSubscription?.cancel();
    super.dispose();
  }
}
