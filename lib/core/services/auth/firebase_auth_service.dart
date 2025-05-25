import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'auth_service_interface.dart';
import '../../exceptions/auth_exceptions.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../logger/logger_service.dart';
import '../../constants/auth_constants.dart';
import '../service_locator.dart';
import '../api/api_service.dart';
import '../notifications/notifications_service.dart';

/// Firebase implementation of the auth service interface
class FirebaseAuthService implements AuthServiceInterface {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'AUTH';  

  /// Create a new FirebaseAuthService instance
  FirebaseAuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            // Explicitly configure Google Sign-In
            scopes: ['email', 'profile'],
          );

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  
  @override
  Future<String?> refreshIdToken({bool forceRefresh = false}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException(
          AuthErrorCodes.notLoggedIn,
          'No user is currently signed in',
        );
      }
      
      final token = await user.getIdToken(forceRefresh);
      _logger.i(_tag, 'Auth token refreshed successfully');
      return token;
    } on FirebaseAuthException catch (e) {
      _logger.e(_tag, 'Failed to refresh auth token', e);
      throw _handleException(e);
    } catch (e) {
      _logger.e(_tag, 'Failed to refresh auth token', e);
      throw AuthException(
        AuthErrorCodes.tokenRefreshFailed,
        'Failed to refresh authentication token',
        e,
      );
    }
  }

  /// Convert FirebaseAuthException to our AuthException using standardized error handler
  AuthException _handleException(FirebaseAuthException e, {AuthMethod? method}) {
    // Using our centralized error handler for consistency
    return AuthErrorMessages.handleError(e, authMethod: method);
  }

  // Email/password authentication removed as per new requirements

  // Create account with email/password removed as per new requirements

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      _logger.i(_tag, 'Starting Google sign-in process');
      
      if (kIsWeb) {
        // Web platform sign-in
        _logger.d(_tag, 'Using web platform Google sign-in flow');
        final authProvider = GoogleAuthProvider();
        return await _firebaseAuth.signInWithPopup(authProvider);
      } else {
        // Mobile platform sign-in
        _logger.d(_tag, 'Using mobile platform Google sign-in flow');
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          _logger.w(_tag, 'Google sign-in canceled by user');
          throw AuthException(
            AuthErrorCodes.socialAuthCancelled,
            'Google sign-in was cancelled by the user',
          );
        }

        try {
          _logger.d(_tag, 'Getting Google authentication tokens');
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          _logger.d(_tag, 'Signing in with Google credential');
          return await _firebaseAuth.signInWithCredential(credential);
        } catch (e) {
          _logger.e(_tag, 'Error during Google sign-in authentication: ${e.toString()}');
          
          if (e is FirebaseAuthException) {
            throw _handleException(e);
          }
          
          throw AuthException(
            AuthErrorCodes.googleSignInFailed,
            'Failed to sign in with Google',
            e,
          );
        }
      }
    } catch (e) {
      _logger.e(_tag, 'Google sign-in process failed: ${e.toString()}');
      
      if (e is FirebaseAuthException) {
        throw _handleException(e, method: AuthMethod.google);
      } else if (e is AuthException) {
        rethrow;
      }
      
      // Use standardized error handling
      throw AuthErrorMessages.handleError(e, authMethod: AuthMethod.google);
    }
  }

  @override
  Future<UserCredential> signInWithApple() async {
    try {
      _logger.i(_tag, 'Starting Apple sign-in process');
      
      // Check if Apple Sign-In is available on the device (for any platform)
      _logger.d(_tag, 'Checking Apple Sign-In availability');
      final appleSignInAvailable = await SignInWithApple.isAvailable();
      if (!appleSignInAvailable) {
        _logger.w(_tag, 'Apple Sign-In is not available on this device');
        throw AuthException(
          AuthErrorCodes.operationNotAllowed,
          'Apple Sign-In is not available on this device.',
        );
      }
      
      // Generate a random string to prevent CSRF attacks
      _logger.d(_tag, 'Generating nonce for Apple Sign-In');
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      // Request credentials - platform-specific implementation
      _logger.d(_tag, 'Requesting Apple ID credentials with platform-specific flow');
      
      late AuthorizationCredentialAppleID appleCredential;
      
      if (Platform.isIOS || Platform.isMacOS) {
        // Use native flow for iOS and macOS
        _logger.d(_tag, 'Using native Apple Sign-In flow for iOS/macOS');
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );
      } else {
        // Use web authentication flow for Android
        _logger.d(_tag, 'Using web authentication flow for Android with service ID: ${AuthConstants.appleServicesId}');
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
          webAuthenticationOptions: WebAuthenticationOptions(
            clientId: AuthConstants.appleServicesId,
            redirectUri: Uri.parse(AuthConstants.appleRedirectUrl),
          ),
        );
      }

      // Create Firebase credential
      _logger.d(_tag, 'Creating Firebase credential from Apple ID');
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with the Apple credentials
      _logger.d(_tag, 'Signing in with Apple credential');
      return await _firebaseAuth.signInWithCredential(oauthCredential);
    } catch (e) {
      _logger.e(_tag, 'Apple sign-in error: ${e.toString()}');
      
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          throw AuthException(
            AuthErrorCodes.socialAuthCancelled,
            'Apple sign-in was cancelled by the user',
            e,
          );
        } else if (e.code == AuthorizationErrorCode.invalidResponse) {
          // This often happens when web authentication is misconfigured
          if (Platform.isAndroid) {
            throw AuthException(
              AuthErrorCodes.appleSignInFailed,
              'Apple Sign-In failed: Make sure you have set up a Services ID in Apple Developer Portal',
              e,
            );
          } else {
            throw AuthException(
              AuthErrorCodes.appleSignInFailed,
              'Apple Sign-In received an invalid response',
              e,
            );
          }
        } else {
          throw AuthException(
            AuthErrorCodes.appleSignInFailed,
            'Apple sign-in failed: ${e.message}',
            e,
          );
        }
      } else if (e is FirebaseAuthException) {
        throw _handleException(e);
      } else if (e is AuthException) {
        rethrow;
      } else if (Platform.isAndroid && e.toString().contains('webAuthenticationOptions')) {
        // Specific error for missing web authentication options on Android
        throw AuthException(
          AuthErrorCodes.appleSignInFailed,
          'Apple Sign-In failed on Android: webAuthenticationOptions missing or invalid',
          e,
        );
      }
      
      throw AuthException(
        AuthErrorCodes.appleSignInFailed,
        'Apple sign-in failed',
        e,
      );
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(AuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      _logger.i(_tag, 'Starting phone number verification: $phoneNumber');
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          _logger.i(_tag, 'Phone auth automatically completed');
          verificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _logger.w(_tag, 'Phone verification failed: ${e.code} - ${e.message}');
          verificationFailed(_handleException(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          _logger.i(_tag, 'Verification code sent to $phoneNumber');
          codeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _logger.d(_tag, 'Auto-retrieval timeout for verification code');
          codeAutoRetrievalTimeout(verificationId);
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      _logger.e(_tag, 'Phone number verification error: ${e.toString()}');
      
      if (e is FirebaseAuthException) {
        verificationFailed(_handleException(e));
      } else {
        verificationFailed(
          AuthException(
            AuthErrorCodes.phoneAuthFailed,
            'Failed to verify phone number',
            e,
          ),
        );
      }
    }
  }

  @override
  Future<UserCredential> signInWithPhoneAuthCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleException(e);
    } catch (e) {
      throw AuthException(
        AuthErrorCodes.phoneAuthFailed,
        'Failed to sign in with phone credential',
        e,
      );
    }
  }

  @override
  Future<UserCredential> verifyOtpAndSignIn(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleException(e);
    } catch (e) {
      throw AuthException(
        AuthErrorCodes.phoneAuthFailed,
        'Failed to verify OTP code',
        e,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Get current user ID before signing out
      final user = _firebaseAuth.currentUser;
      final uid = user?.uid;
      
      if (uid != null) {
        _logger.i(_tag, 'Removing FCM token before sign out for user: $uid');
        
        // Get notifications service to remove FCM token
        try {
          // Use the service locator to get the notifications service
          final notificationsService = serviceLocator<NotificationsService>();
          await notificationsService.removeToken(uid);
          _logger.i(_tag, 'FCM token successfully removed');
        } catch (e) {
          // Log error but continue with sign out process
          _logger.e(_tag, 'Failed to remove FCM token: ${e.toString()}');
        }
      }
      
      // Sign out from Google
      await _googleSignIn.signOut();
      
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      _logger.i(_tag, 'User successfully signed out');
    } catch (e) {
      _logger.e(_tag, 'Failed to sign out: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.unknown,
        'Failed to sign out',
        e,
      );
    }
  }

  // Password reset and account deletion methods removed

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException(
          AuthErrorCodes.notLoggedIn,
          'No user is currently logged in',
        );
      }
      
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
    } on FirebaseAuthException catch (e) {
      throw _handleException(e);
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException(
        AuthErrorCodes.unknown,
        'Failed to update profile',
        e,
      );
    }
  }

  // Email update functionality removed

  /// Generates a cryptographically secure random nonce for Apple Sign In
  String generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation
  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  @override
  Future<bool> validateCredential(AuthCredential credential) async {
    try {
      if (_firebaseAuth.currentUser == null) {
        _logger.w(_tag, 'Cannot validate credentials: No user is logged in');
        return false;
      }
      
      // Reauthenticate to check if credential is valid
      final authResult = await _firebaseAuth.currentUser!.reauthenticateWithCredential(credential);
      _logger.i(_tag, 'Credential validation successful');
      
      return authResult.user != null;
    } on FirebaseAuthException catch (e) {
      _logger.e(_tag, 'Credential validation failed: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_tag, 'Unexpected error during credential validation', e);
      return false;
    }
  }

  @override
  Future<void> deleteUserAccount() async {
    // This is a blocking operation that will not return until the backend confirms deletion
    String? uid;
    User? user;
    
    try {
      user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException(
          AuthErrorCodes.notLoggedIn,
          'No user is currently signed in',
        );
      }
      
      _logger.i(_tag, 'Starting user account deletion process');
      debugPrint('💥 DELETE: Starting user account deletion process');
      
      // Get user ID before deleting
      uid = user.uid;
      debugPrint('💥 DELETE: User ID to delete: $uid');
      
      // Get API service from service locator for backend deletion request
      final apiService = serviceLocator<ApiService>();
      
      _logger.i(_tag, 'Making API call to delete user data from backend');
      debugPrint('💥 DELETE: Making API call to delete user data from backend');
      
      // Get Firebase ID token for authorization
      final idToken = await refreshIdToken(forceRefresh: true);
      if (idToken == null) {
        throw AuthException(
          AuthErrorCodes.tokenRefreshFailed,
          'Failed to get authentication token for account deletion',
        );
      }
      
      // Call the backend API to delete user data and wait for confirmation
      // This is a blocking call that ensures the backend has completed deletion
      final backendDeletionSuccess = await apiService.deleteUser(
        uid: uid,
        idToken: idToken,
      );
      
      // Verify the backend deletion was successful before proceeding
      if (!backendDeletionSuccess) {
        _logger.e(_tag, 'Backend user deletion failed, stopping the deletion process');
        throw AuthException(
          AuthErrorCodes.unknown,
          'Failed to delete user data from backend services',
        );
      }
      
      _logger.i(_tag, 'Backend confirmed successful user deletion');
      debugPrint('💥 DELETE: Backend deletion confirmed successful');
      
      // Delete the Firebase user directly without token removal or signOut
      // No need to remove FCM token as the backend should have cleaned up all user data
      
      // Try to delete the user from Firebase Auth, but handle the case where
      // the backend may have already deleted the Firebase Auth user
      try {
        await user.delete();
        _logger.i(_tag, 'Firebase user deleted successfully');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // This is expected - the backend already deleted the Firebase Auth user
          _logger.i(_tag, 'Firebase user was already deleted by backend - this is expected');
          debugPrint('💥 DELETE: Firebase user was already deleted by backend - this is expected');
        } else {
          // Some other Firebase Auth error occurred
          _logger.e(_tag, 'Unexpected Firebase Auth error during user deletion: ${e.code} - ${e.message}');
          throw AuthErrorMessages.handleError(e);
        }
      }
      
      _logger.i(_tag, 'Account deletion completed successfully');
      debugPrint('💥 DELETE: Account deletion completed successfully');
      
    } catch (e) {
      _logger.e(_tag, 'Error during account deletion: ${e.toString()}');
      
      if (e is FirebaseAuthException) {
        throw AuthErrorMessages.handleError(e);
      } else if (e is AuthException) {
        rethrow;
      } else {
        throw AuthException(
          AuthErrorCodes.unknown, 
          'Failed to delete account: ${e.toString()}',
          e,
        );
      }
    }
  }
}
