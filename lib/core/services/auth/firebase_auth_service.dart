import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'auth_service_interface.dart';
import 'package:flutter/material.dart';
import '../../exceptions/auth_exceptions.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Firebase implementation of the auth service interface
class FirebaseAuthService implements AuthServiceInterface {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

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

  /// Convert FirebaseAuthException to our AuthException
  AuthException _handleException(FirebaseAuthException e) {
    String code;
    String message = e.message ?? 'An unknown error occurred';

    switch (e.code) {
      case 'invalid-email':
        code = AuthErrorCodes.invalidCredential;
        message = 'The email address is not valid.';
        break;
      case 'wrong-password':
        code = AuthErrorCodes.wrongPassword;
        message = 'Your password is incorrect.';
        break;
      case 'user-not-found':
        code = AuthErrorCodes.userNotFound;
        message = 'No user found with this email address.';
        break;
      case 'user-disabled':
        code = AuthErrorCodes.userDisabled;
        message = 'This user account has been disabled.';
        break;
      case 'too-many-requests':
        code = AuthErrorCodes.tooManyRequests;
        message = 'Too many requests. Try again later.';
        break;
      case 'operation-not-allowed':
        code = AuthErrorCodes.operationNotAllowed;
        message = 'This sign in method is not allowed.';
        break;
      case 'invalid-verification-code':
        code = AuthErrorCodes.invalidVerificationCode;
        message = 'The verification code is invalid.';
        break;
      case 'invalid-verification-id':
        code = AuthErrorCodes.invalidVerificationId;
        message = 'The verification ID is invalid.';
        break;
      case 'account-exists-with-different-credential':
        code = AuthErrorCodes.accountExistsWithDifferentCredential;
        message = 'An account already exists with the same email but different sign-in credentials.';
        break;
      case 'network-request-failed':
        code = AuthErrorCodes.networkError;
        message = 'Network error. Please check your connection and try again.';
        break;
      default:
        code = AuthErrorCodes.unknown;
        break;
    }

    return AuthException(code, message, e);
  }

  // Email/password authentication removed as per new requirements

  // Create account with email/password removed as per new requirements

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web platform sign-in
        final authProvider = GoogleAuthProvider();
        return await _firebaseAuth.signInWithPopup(authProvider);
      } else {
        // Mobile platform sign-in
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw AuthException(
            AuthErrorCodes.socialAuthCancelled,
            'Google sign-in was cancelled by the user',
          );
        }

        try {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          return await _firebaseAuth.signInWithCredential(credential);
        } catch (e) {
          debugPrint('Error during Google sign-in: ${e.toString()}');
          
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
      debugPrint('Google sign-in error: ${e.toString()}');
      
      if (e is FirebaseAuthException) {
        throw _handleException(e);
      } else if (e is AuthException) {
        throw e;
      }
      
      throw AuthException(
        AuthErrorCodes.googleSignInFailed,
        'Google sign-in failed',
        e,
      );
    }
  }

  @override
  Future<UserCredential> signInWithApple() async {
    try {
      if (Platform.isIOS) {
        // Check if Apple Sign-In is available on the device
        final appleSignInAvailable = await SignInWithApple.isAvailable();
        if (!appleSignInAvailable) {
          throw AuthException(
            AuthErrorCodes.operationNotAllowed,
            'Apple Sign-In is not available on this device.',
          );
        }
      }

      // Generate a random string to prevent CSRF attacks
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      // Request credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create Firebase credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with the Apple credentials
      return await _firebaseAuth.signInWithCredential(oauthCredential);
    } catch (e) {
      debugPrint('Apple sign-in error: ${e.toString()}');
      
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          throw AuthException(
            AuthErrorCodes.socialAuthCancelled,
            'Apple sign-in was cancelled by the user',
            e,
          );
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
        throw e;
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
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: (FirebaseAuthException e) {
          verificationFailed(_handleException(e));
        },
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('Phone number verification error: ${e.toString()}');
      
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
      // Sign out from Google
      await _googleSignIn.signOut();
      
      // Sign out from Firebase
      await _firebaseAuth.signOut();
    } catch (e) {
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
        throw e;
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
}
