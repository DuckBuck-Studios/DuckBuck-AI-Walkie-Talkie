import 'package:firebase_auth/firebase_auth.dart';

/// Interface defining the authentication service capabilities.
abstract class AuthServiceInterface {
  /// Get the currently signed-in user
  User? get currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password, {
    bool requireEmailVerification = false,
  });

  /// Create a new account with email and password
  Future<UserCredential> createAccountWithEmailPassword(
    String email,
    String password,
  );

  /// Sign in with Google account
  Future<UserCredential> signInWithGoogle();

  /// Sign in with Apple account
  Future<UserCredential> signInWithApple();

  /// Start phone number verification process
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
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

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Delete the current user account
  Future<void> deleteAccount();

  /// Update user profile information
  Future<void> updateProfile({String? displayName, String? photoURL});

  /// Update user email address
  Future<void> updateEmail(String newEmail);
}
