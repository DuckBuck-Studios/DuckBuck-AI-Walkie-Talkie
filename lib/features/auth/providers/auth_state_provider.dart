import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/user_model.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/notifications/notifications_service.dart';

/// Provider that manages authentication state throughout the app
///
/// This class uses the ChangeNotifier pattern to broadcast authentication state
/// changes to all listening widgets. It serves as a bridge between the UI and
/// the UserRepository that handles the actual authentication logic.
class AuthStateProvider extends ChangeNotifier {
  final UserRepository _userRepository;
  final NotificationsService _notificationsService;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  /// Creates a new AuthStateProvider
  AuthStateProvider({
    UserRepository? userRepository,
    NotificationsService? notificationsService,
  }) : _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _notificationsService =
           notificationsService ?? serviceLocator<NotificationsService>() {
    _init();
  }

  /// Initialize the provider and listen for auth state changes
  void _init() {
    // Initialize notification service
    _notificationsService.initialize();

    // Listen for auth changes
    _userRepository.userStream.listen((user) {
      _currentUser = user;

      // When user logs in, register FCM token and update login state in preferences
      if (user != null) {
        _notificationsService.registerToken(user.uid);
        PreferencesService.instance.setLoggedIn(true);
      }

      notifyListeners();
    });

    // Load current user immediately if available
    _currentUser = _userRepository.currentUser;
    if (_currentUser != null) {
      _notificationsService.registerToken(_currentUser!.uid);
      PreferencesService.instance.setLoggedIn(true);
    }
  }

  /// Current authenticated user, if any
  UserModel? get currentUser => _currentUser;

  /// Whether authentication operations are in progress
  bool get isLoading => _isLoading;

  /// Last error message from authentication operations
  String? get errorMessage => _errorMessage;

  /// Whether the user is authenticated
  bool get isAuthenticated => _currentUser != null;

  /// Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
    bool requireEmailVerification = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _userRepository.signInWithEmail(
        email: email,
        password: password,
        requireEmailVerification: requireEmailVerification,
      );

      _errorMessage = null;
      return user;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new account with email and password
  Future<UserModel> createAccount({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _userRepository.createAccountWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      _errorMessage = null;
      return user;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
        verificationFailed: (e) {
          _errorMessage = e.message;
          _isLoading = false;
          notifyListeners();
          onError(e.message ?? 'Verification failed');
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
      // Remove FCM token if there's a current user
      if (_currentUser != null) {
        await _notificationsService.removeToken(_currentUser!.uid);
      }

      // Sign out
      await _userRepository.signOut();
    } catch (e) {
      _errorMessage = e.toString();
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

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userRepository.sendPasswordResetEmail(email);
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

  /// Check if a user is new (doesn't exist in Firestore)
  Future<bool> checkIfUserIsNew(String uid) {
    return _userRepository.checkIfUserIsNew(uid);
  }
}
