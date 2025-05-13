import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth/auth_service_interface.dart';
import '../models/user_model.dart';  // Account deletion functionality has been removed
import '../services/firebase/firebase_database_service.dart';
import '../services/service_locator.dart';
import '../exceptions/auth_exceptions.dart';

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

  // Email and password authentication has been removed in favor of social auth and phone auth

  /// Sign in with Google
  Future<(UserModel, bool)> signInWithGoogle() async {
    final credential = await authService.signInWithGoogle();
    final user = UserModel.fromFirebaseUser(credential.user!);
    
    // Check if this is actually a new sign-in to Firebase Auth
    final isNewToFirebase = credential.additionalUserInfo?.isNewUser ?? false;
    print('🔍 USER REPO: Firebase reports isNewUser: $isNewToFirebase for Google sign-in');
    
    // If Firebase says this is a new user, definitely treat as new
    if (isNewToFirebase) {
      print('🔍 USER REPO: Creating new user document for Google user as reported by Firebase');
      await _createUserData(user);
      return (user, true);
    }
    
    // Otherwise, check if user exists in Firestore and create if needed
    final isNewToFirestore = await _createOrUpdateUserData(user);
    
    return (user, isNewToFirestore);
  }

  /// Sign in with Apple
  Future<(UserModel, bool)> signInWithApple() async {
    final credential = await authService.signInWithApple();
    final user = UserModel.fromFirebaseUser(credential.user!);
    
    // Check if this is actually a new sign-in to Firebase Auth
    final isNewToFirebase = credential.additionalUserInfo?.isNewUser ?? false;
    print('🔍 USER REPO: Firebase reports isNewUser: $isNewToFirebase for Apple sign-in');
    
    // If Firebase says this is a new user, definitely treat as new
    if (isNewToFirebase) {
      print('🔍 USER REPO: Creating new user document for Apple user as reported by Firebase');
      await _createUserData(user);
      return (user, true);
    }
    
    // Otherwise, check if user exists in Firestore and create if needed
    final isNewToFirestore = await _createOrUpdateUserData(user);
    
    return (user, isNewToFirestore);
  }

  /// Initiate phone auth verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(AuthException) verificationFailed,
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
      if (e is AuthException) {
        throw e; // Re-throw our custom exception if already processed
      }
      throw AuthException(
        AuthErrorCodes.phoneAuthFailed,
        'Failed to sign in with phone credential',
        e,
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

  // Password reset functionality has been removed

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection(_userCollection).doc(uid).get();
      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      throw AuthException(
        AuthErrorCodes.unknown,
        'Failed to get user data',
        e
      );
    }
  }

  /// Create user record in Firestore
  Future<void> _createUserData(UserModel user) async {
    try {
      // Extract the provider ID from user metadata if available
      final providerId = user.metadata?['providerId'] as String? ?? 'unknown';
      
      await _firestore.collection(_userCollection).doc(user.uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isNewUser': true, // Explicitly mark as a new user
        'authProvider': providerId, // Store the auth provider used for signup
      });
      
      print('🔍 USER REPO: Created new user with auth provider: $providerId');
    } catch (e) {
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to create user data',
        e
      );
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
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to update user data',
        e
      );
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
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to create or update user data',
        e
      );
    }
  }

  // Account deletion functionality has been removed

  /// Check if a user is new (doesn't exist in Firestore or has isNewUser flag)
  Future<bool> checkIfUserIsNew(String uid) async {
    try {
      print('🔍 USER REPO: Checking if user $uid exists in Firestore');
      final doc = await _firestore.collection(_userCollection).doc(uid).get();

      // If document doesn't exist, user is definitely new
      if (!doc.exists) {
        print('🔍 USER REPO: User document does NOT exist in Firestore - user is new');
        return true;
      }

      // If document exists but has isNewUser flag set to true, also consider as new
      final data = doc.data();
      final isMarkedAsNew = data != null && data['isNewUser'] == true;
      
      print('🔍 USER REPO: User document exists, isNewUser flag: $isMarkedAsNew');
      return isMarkedAsNew;
    } catch (e) {
      print('❌ USER REPO ERROR: ${e.toString()}');
      // In case of error, default to treating the user as new to ensure profile completion
      return true;
    }
  }

  /// Mark user as no longer new (completes onboarding)
  Future<void> markUserOnboardingComplete(String uid) async {
    try {
      print('🔍 USER REPO: Marking user $uid onboarding as complete');
      await _firestore.collection(_userCollection).doc(uid).update({
        'isNewUser': FieldValue.delete(), // Remove the isNewUser field entirely
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ USER REPO ERROR: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to mark user onboarding as complete',
        e
      );
    }
  }
}
