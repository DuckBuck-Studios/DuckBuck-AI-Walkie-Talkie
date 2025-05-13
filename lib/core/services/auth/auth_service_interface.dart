import 'package:firebase_auth/firebase_auth.dart';
import '../../exceptions/auth_exceptions.dart';

/// Interface defining the authentication service capabilities.
abstract class AuthServiceInterface {
  /// Get the currently signed-in user
  User? get currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges;

  /// Sign in with Google account
  Future<UserCredential> signInWithGoogle();

  /// Sign in with Apple account
  Future<UserCredential> signInWithApple();

  /// Start phone number verification process
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(AuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  });

  /// Sign in with phone verification code
  Future<UserCredential> signInWithPhoneAuthCredential(
    PhoneAuthCredential credential,
  );

  /// Complete phone auth with verification code and verification ID
  Future<UserCredential> verifyOtpAndSignIn(
    String verificationId,
    String smsCode,
  );

  /// Sign out the current user
  Future<void> signOut();

  /// Update user profile information
  Future<void> updateProfile({String? displayName, String? photoURL});
}
