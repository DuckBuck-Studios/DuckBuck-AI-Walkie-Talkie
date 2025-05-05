import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth/auth_service_interface.dart';
import '../models/user_model.dart';
import '../services/firebase/firebase_database_service.dart';
import '../services/service_locator.dart';

/// Repository to handle user data operations
class UserRepository {
  final AuthServiceInterface authService;
  final FirebaseFirestore _firestore;
  final String _userCollection = 'users';

  /// Creates a new UserRepository
  UserRepository({required this.authService, FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          serviceLocator<FirebaseDatabaseService>().firestoreInstance;

  /// Get the current authenticated user
  UserModel? get currentUser {
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) return null;
    return UserModel.fromFirebaseUser(firebaseUser);
  }

  /// Stream of auth state changes converted to UserModel
  Stream<UserModel?> get userStream {
    return authService.authStateChanges.map((firebaseUser) {
      if (firebaseUser == null) return null;
      return UserModel.fromFirebaseUser(firebaseUser);
    });
  }

  /// Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
    bool requireEmailVerification = false,
  }) async {
    final credential = await authService.signInWithEmailPassword(
      email,
      password,
      requireEmailVerification: requireEmailVerification,
    );
    final user = UserModel.fromFirebaseUser(credential.user!);

    // Update user record in Firestore to track last sign in
    await _updateUserData(user);

    return user;
  }

  /// Create a new account with email and password
  Future<UserModel> createAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await authService.createAccountWithEmailPassword(
      email,
      password,
    );

    // Update display name if provided
    if (displayName != null) {
      await authService.updateProfile(displayName: displayName);
    }

    final user = UserModel.fromFirebaseUser(credential.user!);

    // Create user record in Firestore
    await _createUserData(user);

    return user;
  }

  /// Sign in with Google
  Future<(UserModel, bool)> signInWithGoogle() async {
    final credential = await authService.signInWithGoogle();
    final user = UserModel.fromFirebaseUser(credential.user!);

    // Check if user exists in Firestore and create if needed
    // Returns true if this is a new user
    final isNewUser = await _createOrUpdateUserData(user);

    return (user, isNewUser);
  }

  /// Sign in with Apple
  Future<(UserModel, bool)> signInWithApple() async {
    final credential = await authService.signInWithApple();
    final user = UserModel.fromFirebaseUser(credential.user!);

    // Check if user exists in Firestore and create if needed
    // Returns true if this is a new user
    final isNewUser = await _createOrUpdateUserData(user);

    return (user, isNewUser);
  }

  /// Initiate phone auth verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) {
    return authService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  /// Verify phone OTP code and sign in
  Future<(UserModel, bool)> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = await authService.verifyOtpAndSignIn(
      verificationId,
      smsCode,
    );
    final user = UserModel.fromFirebaseUser(credential.user!);

    // Check if user exists in Firestore and create if needed
    final isNewUser = await _createOrUpdateUserData(user);

    return (user, isNewUser);
  }

  /// Sign in with phone auth credential
  Future<(UserModel, bool)> signInWithPhoneAuthCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await authService.signInWithPhoneAuthCredential(
        credential,
      );
      final user = UserModel.fromFirebaseUser(userCredential.user!);

      // Check if user exists in Firestore and create if needed
      final isNewUser = await _createOrUpdateUserData(user);

      return (user, isNewUser);
    } catch (e) {
      throw Exception(
        'Failed to sign in with phone credential: ${e.toString()}',
      );
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    // Clear FCM token before signing out (already handled in AuthStateProvider)

    // Sign out from Firebase Auth
    await authService.signOut();

    // Clear login state and reset all auth-related preferences
    await PreferencesService.instance.setLoggedIn(false);
    await PreferencesService.instance.clearAll();
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    await authService.updateProfile(
      displayName: displayName,
      photoURL: photoURL,
    );

    final user = currentUser;
    if (user != null) {
      final updatedUser = user.copyWith(
        displayName: displayName ?? user.displayName,
        photoURL: photoURL ?? user.photoURL,
      );

      await _updateUserData(updatedUser);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) {
    return authService.sendPasswordResetEmail(email);
  }

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection(_userCollection).doc(uid).get();
      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get user data: ${e.toString()}');
    }
  }

  /// Create user record in Firestore
  Future<void> _createUserData(UserModel user) async {
    try {
      await _firestore.collection(_userCollection).doc(user.uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create user data: ${e.toString()}');
    }
  }

  /// Update existing user record in Firestore
  Future<void> _updateUserData(UserModel user) async {
    try {
      await _firestore.collection(_userCollection).doc(user.uid).update({
        ...user.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoggedIn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user data: ${e.toString()}');
    }
  }

  /// Create or update user data in Firestore
  /// Returns true if this is a new user (first time in Firestore)
  Future<bool> _createOrUpdateUserData(UserModel user) async {
    try {
      print(
        '🔍 CHECKING USER EXISTENCE: Checking if user ${user.uid} exists in Firestore',
      );
      final doc =
          await _firestore.collection(_userCollection).doc(user.uid).get();

      if (doc.exists) {
        print(
          '🔍 CHECKING USER EXISTENCE: User ${user.uid} EXISTS in Firestore, updating data',
        );
        await _updateUserData(user);
        return false; // Existing user
      } else {
        print(
          '🔍 CHECKING USER EXISTENCE: User ${user.uid} DOES NOT EXIST in Firestore, creating new user',
        );
        await _createUserData(user);
        return true; // New user
      }
    } catch (e) {
      print('❌ CHECKING USER EXISTENCE ERROR: ${e.toString()}');
      throw Exception('Failed to create or update user data: ${e.toString()}');
    }
  }

  /// Delete the current user
  Future<void> deleteAccount() async {
    try {
      final uid = authService.currentUser?.uid;
      if (uid == null) {
        throw Exception('No user is currently signed in');
      }

      // Delete user data from Firestore
      await _firestore.collection(_userCollection).doc(uid).delete();

      // Delete the Firebase Auth account
      await authService.deleteAccount();
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  /// Check if a user is new (doesn't exist in Firestore)
  Future<bool> checkIfUserIsNew(String uid) async {
    try {
      print('🔍 USER REPO: Checking if user $uid exists in Firestore');
      final doc = await _firestore.collection(_userCollection).doc(uid).get();

      final exists = doc.exists;
      print('🔍 USER REPO: User document exists in Firestore? $exists');

      // If document doesn't exist, user is new
      return !exists;
    } catch (e) {
      print('❌ USER REPO ERROR: ${e.toString()}');
      // In case of error, default to treating the user as new to ensure profile completion
      return true;
    }
  }
}
