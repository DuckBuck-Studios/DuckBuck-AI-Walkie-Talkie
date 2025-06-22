import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../exceptions/auth_exceptions.dart';
import '../services/auth/auth_service_interface.dart';
import '../services/user/user_service_interface.dart';
import '../services/logger/logger_service.dart';
import '../services/service_locator.dart';

/// Repository that handles all authentication business logic and coordinates
/// between auth service and user service.
/// 
/// This is the main entry point for authentication operations in the app.
/// It delegates Firebase operations to auth service and user data management to user service.
class AuthRepository {
  final AuthServiceInterface _authService;
  final UserServiceInterface _userService;
  final LoggerService _logger;
  
  static const String _tag = 'AUTH_REPO';

  /// Create a new AuthRepository instance
  AuthRepository({
    AuthServiceInterface? authService,
    UserServiceInterface? userService,
    LoggerService? logger,
  }) : _authService = authService ?? serviceLocator<AuthServiceInterface>(),
       _userService = userService ?? serviceLocator<UserServiceInterface>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Get the currently signed-in user
  User? get currentUser => _authService.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _authService.authStateChanges;
  
  /// Refresh the authentication token for the current user
  Future<String?> refreshIdToken({bool forceRefresh = false}) async {
    try {
      _logger.d(_tag, 'Refreshing authentication token');
      return await _authService.refreshIdToken(forceRefresh: forceRefresh);
    } catch (e) {
      _logger.e(_tag, 'Failed to refresh authentication token', e);
      rethrow;
    }
  }

  /// Sign in with Google account and handle post-authentication setup
  Future<UserModel> signInWithGoogle() async {
    try {
      _logger.i(_tag, 'Starting Google sign-in flow');
      
      // Authenticate with Google through auth service
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential.user == null) {
        throw AuthException(
          AuthErrorCodes.googleSignInFailed,
          'Google sign-in returned null user',
        );
      }
      
      // Check if account is marked as deleted before proceeding
      await _validateAccountNotDeleted(userCredential.user!.uid);
      
      // Create user model from Firebase user
      final userModel = UserModel.fromFirebaseUser(userCredential.user!);
      
      // Handle user data persistence and FCM token generation
      await _handlePostAuthenticationSetup(userModel, userCredential);
      
      _logger.i(_tag, 'Google sign-in completed successfully');
      return userModel;
    } catch (e) {
      _logger.e(_tag, 'Google sign-in failed', e);
      rethrow;
    }
  }

  /// Sign in with Apple account and handle post-authentication setup
  Future<UserModel> signInWithApple() async {
    try {
      _logger.i(_tag, 'Starting Apple sign-in flow');
      
      // Authenticate with Apple through auth service
      final userCredential = await _authService.signInWithApple();
      
      if (userCredential.user == null) {
        throw AuthException(
          AuthErrorCodes.appleSignInFailed,
          'Apple sign-in returned null user',
        );
      }
      
      // Check if account is marked as deleted before proceeding
      await _validateAccountNotDeleted(userCredential.user!.uid);
      
      // Create user model from Firebase user
      final userModel = UserModel.fromFirebaseUser(userCredential.user!);
      
      // Handle user data persistence and FCM token generation
      await _handlePostAuthenticationSetup(userModel, userCredential);
      
      _logger.i(_tag, 'Apple sign-in completed successfully');
      return userModel;
    } catch (e) {
      _logger.e(_tag, 'Apple sign-in failed', e);
      rethrow;
    }
  }

  /// Start phone number verification process
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(AuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      _logger.i(_tag, 'Starting phone number verification');
      
      // Create wrapper functions to handle post-auth setup for auto-completed verification
      void wrappedVerificationCompleted(PhoneAuthCredential credential) async {
        try {
          _logger.d(_tag, 'Phone verification auto-completed, performing sign-in');
          final userCredential = await _authService.signInWithPhoneAuthCredential(credential);
          
          if (userCredential.user != null) {
            // Check if account is marked as deleted
            await _validateAccountNotDeleted(userCredential.user!.uid);
            
            // Create user model and handle post-auth setup
            final userModel = UserModel.fromFirebaseUser(userCredential.user!);
            await _handlePostAuthenticationSetup(userModel, userCredential);
          }
          
          verificationCompleted(credential);
        } catch (e) {
          _logger.e(_tag, 'Failed to handle auto-completed phone verification', e);
          if (e is AuthException) {
            verificationFailed(e);
          } else {
            verificationFailed(AuthException(
              AuthErrorCodes.phoneAuthFailed,
              'Failed to complete phone authentication',
              e,
              AuthMethod.phone,
            ));
          }
        }
      }
      
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: wrappedVerificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      _logger.e(_tag, 'Phone number verification setup failed', e);
      rethrow;
    }
  }

  /// Sign in with phone verification code and handle post-authentication setup
  Future<UserModel> signInWithPhoneAuthCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      _logger.i(_tag, 'Starting phone authentication with credential');
      
      // Authenticate with phone credential through auth service
      final userCredential = await _authService.signInWithPhoneAuthCredential(credential);
      
      if (userCredential.user == null) {
        throw AuthException(
          AuthErrorCodes.phoneAuthFailed,
          'Phone authentication returned null user',
        );
      }
      
      // Check if account is marked as deleted before proceeding
      await _validateAccountNotDeleted(userCredential.user!.uid);
      
      // Create user model from Firebase user
      final userModel = UserModel.fromFirebaseUser(userCredential.user!);
      
      // Handle user data persistence and FCM token generation
      await _handlePostAuthenticationSetup(userModel, userCredential);
      
      _logger.i(_tag, 'Phone authentication completed successfully');
      return userModel;
    } catch (e) {
      _logger.e(_tag, 'Phone authentication failed', e);
      rethrow;
    }
  }

  /// Complete phone auth with verification code and verification ID
  Future<UserModel> verifyOtpAndSignIn(
    String verificationId,
    String smsCode,
  ) async {
    try {
      _logger.i(_tag, 'Starting OTP verification and sign-in');
      
      // Authenticate with OTP through auth service
      final userCredential = await _authService.verifyOtpAndSignIn(verificationId, smsCode);
      
      if (userCredential.user == null) {
        throw AuthException(
          AuthErrorCodes.phoneAuthFailed,
          'OTP verification returned null user',
        );
      }
      
      // Check if account is marked as deleted before proceeding
      await _validateAccountNotDeleted(userCredential.user!.uid);
      
      // Create user model from Firebase user
      final userModel = UserModel.fromFirebaseUser(userCredential.user!);
      
      // Handle user data persistence and FCM token generation
      await _handlePostAuthenticationSetup(userModel, userCredential);
      
      _logger.i(_tag, 'OTP verification and sign-in completed successfully');
      return userModel;
    } catch (e) {
      _logger.e(_tag, 'OTP verification failed', e);
      rethrow;
    }
  }

  /// Sign out the current user and clean up user data
  Future<void> signOut() async {
    try {
      _logger.i(_tag, 'Starting sign-out process');
      
      // Get current user ID before signing out
      final user = currentUser;
      final uid = user?.uid;
      
      if (uid != null) {
        _logger.i(_tag, 'Removing FCM token before sign out for user: $uid');
        
        // Remove FCM token from user document via user service
        try {
          await _userService.removeFcmToken(uid);
          _logger.i(_tag, 'FCM token successfully removed from user document');
        } catch (e) {
          // Log error but continue with sign out process
          _logger.e(_tag, 'Failed to remove FCM token from user document: ${e.toString()}');
        }
      }
      
      // Delegate to auth service for Firebase sign-out
      await _authService.signOut();
      
      _logger.i(_tag, 'Sign-out completed successfully');
    } catch (e) {
      _logger.e(_tag, 'Sign-out failed', e);
      rethrow;
    }
  }
  
  /// Validate a credential to ensure it's still valid
  Future<bool> validateCredential(AuthCredential credential) async {
    try {
      _logger.d(_tag, 'Validating credential');
      return await _authService.validateCredential(credential);
    } catch (e) {
      _logger.e(_tag, 'Credential validation failed', e);
      rethrow;
    }
  }

  /// Get user data for the current authenticated user
  Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) {
      _logger.w(_tag, 'No authenticated user found');
      return null;
    }
    
    try {
      return await _userService.getUserData(user.uid);
    } catch (e) {
      _logger.e(_tag, 'Failed to get current user data', e);
      rethrow;
    }
  }

  /// Get a stream of the current user's data
  Stream<UserModel?> getCurrentUserDataStream() {
    final user = currentUser;
    if (user == null) {
      _logger.w(_tag, 'No authenticated user found for stream');
      return Stream.value(null);
    }
    
    return _userService.getUserDataStream(user.uid);
  }

  /// Check if the current user is new (hasn't completed onboarding)
  Future<bool> isCurrentUserNew() async {
    final user = currentUser;
    if (user == null) {
      _logger.w(_tag, 'No authenticated user found');
      return false;
    }
    
    try {
      return await _userService.checkIfUserIsNew(user.uid);
    } catch (e) {
      _logger.e(_tag, 'Failed to check if user is new', e);
      rethrow;
    }
  }

  /// Mark the current user's onboarding as complete
  Future<void> markCurrentUserOnboardingComplete() async {
    final user = currentUser;
    if (user == null) {
      _logger.w(_tag, 'No authenticated user found');
      throw AuthException(
        AuthErrorCodes.notLoggedIn,
        'No user is currently signed in',
      );
    }
    
    try {
      await _userService.markUserOnboardingComplete(user.uid);
      _logger.i(_tag, 'Marked user onboarding as complete');
    } catch (e) {
      _logger.e(_tag, 'Failed to mark onboarding as complete', e);
      rethrow;
    }
  }

  /// Delete the current user's account
  Future<void> deleteCurrentUserAccount() async {
    final user = currentUser;
    if (user == null) {
      _logger.w(_tag, 'No authenticated user found');
      throw AuthException(
        AuthErrorCodes.notLoggedIn,
        'No user is currently signed in',
      );
    }
    
    try {
      await _userService.deleteUserAccount(user.uid);
      _logger.i(_tag, 'User account marked as deleted');
    } catch (e) {
      _logger.e(_tag, 'Failed to delete user account', e);
      rethrow;
    }
  }

  /// Restore the current user's deleted account
  Future<void> restoreCurrentUserAccount() async {
    final user = currentUser;
    if (user == null) {
      _logger.w(_tag, 'No authenticated user found');
      throw AuthException(
        AuthErrorCodes.notLoggedIn,
        'No user is currently signed in',
      );
    }
    
    try {
      await _userService.restoreDeletedAccount(user.uid);
      _logger.i(_tag, 'User account restored from deleted state');
    } catch (e) {
      _logger.e(_tag, 'Failed to restore user account', e);
      rethrow;
    }
  }

  /// Handles post-authentication setup including user data persistence
  /// and FCM token generation for new and existing users
  Future<void> _handlePostAuthenticationSetup(
    UserModel userModel,
    UserCredential userCredential,
  ) async {
    try {
      final uid = userModel.uid;
      
      // Create or update user data using the user service
      _logger.i(_tag, 'Creating or updating user data for: $uid');
      final isNewUser = await _userService.createOrUpdateUserData(userModel);
      
      if (isNewUser) {
        _logger.i(_tag, 'New user created: $uid');
      } else {
        _logger.i(_tag, 'Existing user updated: $uid');
      }
      
      // Generate and save FCM token for push notifications
      try {
        await _userService.generateAndSaveFcmToken(uid);
        _logger.d(_tag, 'FCM token generated and saved successfully');
      } catch (e) {
        // Log error but don't fail the authentication process
        _logger.e(_tag, 'Failed to generate/save FCM token (non-critical)', e);
      }
      
    } catch (e) {
      _logger.e(_tag, 'Post-authentication setup failed', e);
      // Don't rethrow - authentication was successful, this is just setup
    }
  }

  /// Check if the user account is marked as deleted in the database
  /// Throws AuthException with accountMarkedDeleted code if account is deleted
  Future<void> _validateAccountNotDeleted(String uid) async {
    try {
      _logger.d(_tag, 'Checking if account is marked as deleted for user: $uid');
      final userData = await _userService.getUserData(uid);
      
      if (userData != null && userData.deleted) {
        _logger.w(_tag, 'Account is marked as deleted for user: $uid');
        
        // Don't sign out here - keep user authenticated temporarily so they can restore account
        // The UI will handle signing out only if they choose "Keep Deleted"
        throw AuthException(
          AuthErrorCodes.accountMarkedDeleted,
          'This account has been marked as deleted.',
          null,
          null,
        );
      }
      
      _logger.d(_tag, 'Account validation passed for user: $uid');
    } catch (e) {
      if (e is AuthException && e.code == AuthErrorCodes.accountMarkedDeleted) {
        rethrow;
      }
      
      _logger.e(_tag, 'Error checking account deletion status', e);
      // Don't throw here - allow login to continue if we can't check deletion status
    }
  }
}
