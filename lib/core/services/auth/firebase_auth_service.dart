import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' show Platform;
import 'auth_service_interface.dart';
import 'auth_exception_handler.dart';
import 'package:flutter/material.dart';

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

  @override
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password, {
    bool requireEmailVerification = false,
  }) async {
    try {
      // Sign in with Firebase Authentication
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Check if email verification is required and the email is not verified
      if (requireEmailVerification &&
          userCredential.user != null &&
          !userCredential.user!.emailVerified) {
        // Send verification email
        await userCredential.user!.sendEmailVerification();
        // Sign out the user since verification is required
        await _firebaseAuth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message:
              'Please verify your email address. A verification link has been sent.',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    }
  }

  @override
  Future<UserCredential> createAccountWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    debugPrint('📱 GOOGLE AUTH: Starting Google sign-in process...');

    try {
      // Check if a user is already signed in with Google
      final currentGoogleUser = await _googleSignIn.isSignedIn();
      debugPrint('📱 GOOGLE AUTH: User already signed in? $currentGoogleUser');

      if (currentGoogleUser) {
        debugPrint('📱 GOOGLE AUTH: Signing out previous Google session...');
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      }

      // Begin interactive sign in process
      debugPrint('📱 GOOGLE AUTH: Launching Google sign-in UI...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If the user canceled the sign-in flow
      if (googleUser == null) {
        debugPrint('📱 GOOGLE AUTH: Sign-in process was canceled by user');
        throw Exception('Google sign in was canceled by the user');
      }

      debugPrint('📱 GOOGLE AUTH: Sign-in successful for: ${googleUser.email}');

      // Obtain the auth details from the request
      debugPrint('📱 GOOGLE AUTH: Getting authentication details...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      debugPrint('📱 GOOGLE AUTH: Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      debugPrint('📱 GOOGLE AUTH: Signing in to Firebase...');
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      debugPrint(
        '📱 GOOGLE AUTH: Firebase sign-in complete for: ${userCredential.user?.email}',
      );

      return userCredential;
    } catch (e) {
      // Properly handle and log the error
      debugPrint('❌ GOOGLE AUTH ERROR: ${e.toString()}');

      if (e is Exception && e.toString().contains('canceled by the user')) {
        // This is a user cancellation, not an error
        debugPrint(
          '📱 GOOGLE AUTH: User deliberately canceled the sign-in process',
        );
        throw Exception('Google sign in was canceled');
      }

      // Attempt to recover by clearing any cached state
      try {
        debugPrint('📱 GOOGLE AUTH: Attempting recovery by clearing state...');
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      } catch (recoveryError) {
        debugPrint('📱 GOOGLE AUTH: Recovery attempt failed: $recoveryError');
      }

      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  @override
  Future<UserCredential> signInWithApple() async {
    debugPrint('🍎 APPLE AUTH: Starting Apple sign-in process...');

    try {
      if (kIsWeb) {
        // Sign in with Apple on Web
        debugPrint('🍎 APPLE AUTH: Using web sign-in flow');
        final provider = AppleAuthProvider();
        return await _firebaseAuth.signInWithPopup(provider);
      } else if (Platform.isIOS || Platform.isMacOS) {
        debugPrint('🍎 APPLE AUTH: Using native iOS/macOS sign-in flow');

        try {
          // Check Apple Sign In availability
          debugPrint('🍎 APPLE AUTH: Checking Apple Sign In availability...');
          final isAvailable = await SignInWithApple.isAvailable();

          if (!isAvailable) {
            debugPrint(
              '❌ APPLE AUTH ERROR: Apple Sign In is not available on this device',
            );
            throw Exception('Apple Sign In is not available on this device');
          }

          debugPrint('🍎 APPLE AUTH: Apple Sign In available, proceeding...');

          // Request credential for the currently signed in Apple account
          debugPrint('🍎 APPLE AUTH: Requesting Apple ID credential...');
          final appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

          debugPrint('🍎 APPLE AUTH: Successfully got Apple ID credential');
          debugPrint(
            '🍎 APPLE AUTH: Email provided by Apple: ${appleCredential.email ?? "Not provided"}',
          );
          debugPrint(
            '🍎 APPLE AUTH: Name provided: ${appleCredential.givenName ?? ""} ${appleCredential.familyName ?? ""}',
          );

          // Check if we got the token
          if (appleCredential.identityToken == null) {
            debugPrint('❌ APPLE AUTH ERROR: No identity token returned');
            throw Exception('Apple Sign In failed: No identity token returned');
          }

          // Create an OAuthCredential from the credential returned by Apple
          debugPrint(
            '🍎 APPLE AUTH: Creating Firebase credential from Apple response',
          );
          final oauthCredential = OAuthProvider('apple.com').credential(
            idToken: appleCredential.identityToken!,
            accessToken: appleCredential.authorizationCode,
          );

          // Sign in to Firebase with the Apple OAuthCredential
          debugPrint('🍎 APPLE AUTH: Signing in to Firebase...');
          final userCredential = await _firebaseAuth.signInWithCredential(
            oauthCredential,
          );

          // Update user display name if this is a new user and name was provided
          if (userCredential.additionalUserInfo?.isNewUser == true &&
              (appleCredential.givenName != null ||
                  appleCredential.familyName != null)) {
            String? displayName;
            if (appleCredential.givenName != null ||
                appleCredential.familyName != null) {
              displayName = [
                appleCredential.givenName,
                appleCredential.familyName,
              ].where((name) => name != null && name.isNotEmpty).join(' ');
            }

            if (displayName != null && displayName.isNotEmpty) {
              debugPrint(
                '🍎 APPLE AUTH: Updating user profile with name: $displayName',
              );
              await userCredential.user?.updateDisplayName(displayName);
            }
          }

          debugPrint(
            '🍎 APPLE AUTH: Firebase sign-in complete for user: ${userCredential.user?.email ?? "unknown"}',
          );

          return userCredential;
        } catch (e) {
          debugPrint('❌ APPLE AUTH ERROR: ${e.toString()}');

          if (e.toString().contains('canceled') ||
              e.toString().contains('cancelled')) {
            debugPrint(
              '🍎 APPLE AUTH: User deliberately canceled the sign-in process',
            );
            throw Exception('Apple sign in was canceled by the user');
          }

          rethrow;
        }
      } else {
        debugPrint(
          '❌ APPLE AUTH ERROR: Platform not supported (${Platform.operatingSystem})',
        );
        throw Exception(
          'Apple Sign In is not supported on ${Platform.operatingSystem}',
        );
      }
    } catch (e) {
      debugPrint('❌ APPLE AUTH ERROR: ${e.toString()}');
      throw Exception('Failed to sign in with Apple: ${e.toString()}');
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      debugPrint('📱 PHONE AUTH: Starting phone verification for $phoneNumber');

      // Configure phone verification settings based on environment
      if (kDebugMode) {
        // In debug/development mode, use settings optimized for testing
        await _firebaseAuth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (credential) {
            debugPrint('📱 PHONE AUTH: Auto-verification completed');
            verificationCompleted(credential);
          },
          verificationFailed: (e) {
            debugPrint('📱 PHONE AUTH: Verification failed: ${e.message}');
            verificationFailed(AuthExceptionHandler.handleException(e));
          },
          codeSent: (verificationId, resendToken) {
            debugPrint('📱 PHONE AUTH: Verification code sent to user');
            codeSent(verificationId, resendToken);
          },
          codeAutoRetrievalTimeout: (verificationId) {
            debugPrint('📱 PHONE AUTH: Auto-retrieval timeout');
            codeAutoRetrievalTimeout(verificationId);
          },
          timeout: const Duration(seconds: 120), // Longer timeout for testing
          forceResendingToken: null,
        );
      } else {
        // In production mode, use standard settings
        await _firebaseAuth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (credential) {
            debugPrint('📱 PHONE AUTH: Auto-verification completed');
            verificationCompleted(credential);
          },
          verificationFailed: (e) {
            debugPrint('📱 PHONE AUTH: Verification failed: ${e.message}');
            verificationFailed(AuthExceptionHandler.handleException(e));
          },
          codeSent: (verificationId, resendToken) {
            debugPrint('📱 PHONE AUTH: Verification code sent to user');
            codeSent(verificationId, resendToken);
          },
          codeAutoRetrievalTimeout: (verificationId) {
            debugPrint('📱 PHONE AUTH: Auto-retrieval timeout');
            codeAutoRetrievalTimeout(verificationId);
          },
          timeout: const Duration(seconds: 60),
        );
      }
    } catch (e) {
      debugPrint('❌ PHONE AUTH ERROR: ${e.toString()}');
      throw Exception('Failed to verify phone number: ${e.toString()}');
    }
  }

  @override
  Future<UserCredential> signInWithPhoneAuthCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    }
  }

  @override
  Future<UserCredential> verifyOtpAndSignIn(
    String verificationId,
    String smsCode,
  ) async {
    try {
      // Create a PhoneAuthCredential with the verification ID and OTP code
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await signInWithPhoneAuthCredential(credential);
    } catch (e) {
      throw Exception('Failed to verify OTP: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _firebaseAuth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    }
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await _firebaseAuth.currentUser?.updateDisplayName(displayName);
      await _firebaseAuth.currentUser?.updatePhotoURL(photoURL);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    try {
      await _firebaseAuth.currentUser?.updateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    }
  }
}
