import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:retry/retry.dart';
import '../models/user_model.dart' as models;
import 'dart:math';
import 'dart:async'; 
import '../config/app_config.dart';

/// A service class that handles all authentication operations including:
/// - Sign in with various providers (Google, Apple, Phone)
/// - User data management in Firestore
/// - FCM token management
/// - Auth state tracking
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AppConfig _appConfig = AppConfig();
  
  // Retry configuration
  final RetryOptions _retryOptions = const RetryOptions(
    maxAttempts: 3,
    delayFactor: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 5),
  );

  // Internal cache for current user model
  models.UserModel? _cachedUserModel;
  Timer? _cacheRefreshTimer;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Gets a user-friendly error message, hiding implementation details
  String getFriendlyErrorMessage(dynamic error) {
    // Don't expose raw Firebase error messages to users
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Account not found. Please check your credentials.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'Invalid login credentials. Please try again.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'weak-password':
          return 'Password is too weak. Please use a stronger password.';
        case 'operation-not-allowed':
          return 'This login method is not enabled.';
        case 'invalid-verification-code':
          return 'The verification code is invalid. Please try again.';
        case 'invalid-verification-id':
          return 'Your verification session has expired. Please try again.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'popup-closed-by-user':
          return 'Login canceled. Please try again.';
        case 'ERROR_ABORTED_BY_USER':
          return 'Sign in process was canceled.';
        default:
          return 'Authentication error. Please try again later.';
      }
    } else if (error is FirebaseException) {
      if (error.code == 'unavailable' || 
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed') {
        return 'Network error. Please check your connection and try again.';
      }
      return 'Service error. Please try again later.';
    } else if (error is PlatformException) {
      if (error.code == 'network_error') {
        return 'Network error. Please check your connection and try again.';
      }
      return 'Service error. Please try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  /// Initiate phone number verification
  /// 
  /// This method starts the phone verification process by sending an SMS code
  /// to the provided phone number. It returns a Future that completes with the
  /// verification ID needed for the second step.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      await _retryOptions.retry(
        () async {
          await _auth.verifyPhoneNumber(
            phoneNumber: phoneNumber,
            verificationCompleted: verificationCompleted,
            verificationFailed: (FirebaseAuthException e) {
              _appConfig.log('Phone verification failed: ${e.code} - ${e.message}');
              // Transform the error before passing it on
              final friendlyMessage = getFriendlyErrorMessage(e);
              verificationFailed(
                FirebaseAuthException(
                  code: e.code,
                  message: friendlyMessage,
                )
              );
            },
            codeSent: codeSent,
            codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
            timeout: timeout,
          );
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => _appConfig.log('Retrying phone verification due to error: $e'),
      );
    } catch (e) {
      _appConfig.log('Error starting phone verification after retries: $e');
      throw Exception(getFriendlyErrorMessage(e));
    }
  }

  /// Get the current user model
  /// Will return cached version if available, or fetch from Firestore
  Future<models.UserModel?> getCurrentUserModel() async {
    if (_auth.currentUser == null) return null;
    
    if (_cachedUserModel != null) {
      return _cachedUserModel;
    }
    
    // Get the user document using Firebase UID
    final docSnapshot = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    
    if (!docSnapshot.exists) {
      _appConfig.log('No user document found');
      return null;
    }
    
    final userData = docSnapshot.data() as Map<String, dynamic>;
    final userModel = models.UserModel.fromJson(userData);
    
    // Cache the user model
    _cachedUserModel = userModel;
    _setupCacheRefresh();
    
    return userModel;
  }

  /// Find or generate an 8-digit UID
  Future<String> _getOrGenerate8DigitUid() async {
    final random = Random();
    return List.generate(8, (_) => random.nextInt(10)).join();
  }

  /// Get a user model by UID
  Future<models.UserModel?> getUserModel(String uid) async {
    _appConfig.log('Getting user model for UID: $uid');
    try {
      // First try with the exact ID (if it's the Firebase Auth ID)
      if (uid == _auth.currentUser?.uid) {
        final docSnapshot = await _firestore.collection('users').doc(uid).get();
        if (docSnapshot.exists) {
          final userData = docSnapshot.data() as Map<String, dynamic>;
          _appConfig.log('User data found: ${userData['displayName']}');
          final userModel = models.UserModel.fromJson(userData);
          
          // Cache the user model
          _cachedUserModel = userModel;
          _setupCacheRefresh();
          
          return userModel;
        }
      }
      
      // If not found and it could be an 8-digit ID, try to find it
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        _appConfig.log('User data found by 8-digit UID: ${userData['displayName']}');
        final userModel = models.UserModel.fromJson(userData);
        
        // Only cache if this is the current user
        if (querySnapshot.docs.first.id == _auth.currentUser?.uid) {
          _cachedUserModel = userModel;
          _setupCacheRefresh();
        }
        
        return userModel;
      }
      
      _appConfig.log('No user document found');
      return null;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error getting user model for $uid');
      return null;
    }
  }

  /// Set up a timer to refresh the cached user model
  void _setupCacheRefresh() {
    // Cancel any existing timer
    _cacheRefreshTimer?.cancel();
    
    // Set up a new timer to refresh the cache every 5 minutes
    _cacheRefreshTimer = Timer.periodic(
      const Duration(minutes: 5), 
      (_) => refreshCurrentUserModel(),
    );
  }

  /// Force refresh the current user model from Firestore
  Future<models.UserModel?> refreshCurrentUserModel() async {
    if (_auth.currentUser == null) return null;
    
    _cachedUserModel = null; // Clear cache to force refresh
    return await getCurrentUserModel();
  }

  /// Update the current user's profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    Map<String, dynamic>? metadata,
    DateTime? dateOfBirth,
    models.Gender? gender,
  }) async {
    if (_auth.currentUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user is currently signed in',
      );
    }

    try {
      await _retryOptions.retry(
        () async {
          final updates = <String, dynamic>{
            'lastLoginAt': Timestamp.now(),
          };

          // Update display name in Firebase Auth if provided
          if (displayName != null) {
            await _auth.currentUser!.updateDisplayName(displayName);
            updates['displayName'] = displayName;
          }

          // Update photo URL in Firebase Auth if provided
          if (photoURL != null) {
            await _auth.currentUser!.updatePhotoURL(photoURL);
            updates['photoURL'] = photoURL;
          }

          // Get current metadata
          final userModel = await getCurrentUserModel();
          final existingMetadata = Map<String, dynamic>.from(userModel?.metadata ?? {});
          
          // Update date of birth in metadata if provided
          if (dateOfBirth != null) {
            existingMetadata['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
          }

          // Update gender in metadata if provided
          if (gender != null) {
            existingMetadata['gender'] = gender.toString().split('.').last;
          }

          // Merge with additional metadata if provided
          if (metadata != null && metadata.isNotEmpty) {
            existingMetadata.addAll(metadata);
          }
          
          // Add metadata to updates
          updates['metadata'] = existingMetadata;

          // Update in Firestore
          if (updates.length > 1) { // More than just lastLoginAt
            await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .update(updates);
            
            // Clear cache to force refresh on next get
            _cachedUserModel = null;
          }
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => _appConfig.log('Retrying profile update due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error updating user profile');
      rethrow;
    }
  }

  /// Sign in with Google
  /// Returns UserCredential on success
  /// Throws FirebaseAuthException on error
  Future<UserCredential> signInWithGoogle() async {
    try {
      return await _retryOptions.retry(
        () async {
          // Trigger the authentication flow
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          
          if (googleUser == null) {
            throw FirebaseAuthException(
              code: 'ERROR_ABORTED_BY_USER',
              message: 'Sign in aborted by user',
            );
          }

          // Obtain the auth details from the request
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

          // Create a new credential
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // Sign in with credential
          final userCredential = await _auth.signInWithCredential(credential);
          
          // Check if user exists, create if not
          await _checkAndCreateUser(userCredential.user, models.AuthProvider.google);
          
          // Generate and save FCM token
          await _generateAndSaveFcmToken(userCredential.user?.uid);
          
          return userCredential;
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => _appConfig.log('Retrying Google sign-in due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error signing in with Google');
      throw Exception(getFriendlyErrorMessage(e));
    }
  }

  /// Sign in with Apple
  /// Returns UserCredential on success
  /// Throws Exception on error
  Future<UserCredential> signInWithApple() async {
    try {
      return await _retryOptions.retry(
        () async {
          // Perform the authentication request
          final appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

          // Create an OAuthCredential
          final oauthCredential = OAuthProvider('apple.com').credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          );

          // Sign in with credential
          final userCredential = await _auth.signInWithCredential(oauthCredential);
          
          // Apple may not return name info on subsequent logins
          if (appleCredential.givenName != null && 
              appleCredential.familyName != null &&
              (userCredential.user?.displayName == null || 
               userCredential.user!.displayName!.isEmpty)) {
            await userCredential.user?.updateDisplayName(
              '${appleCredential.givenName} ${appleCredential.familyName}'
            );
          }
          
          // Check if user exists, create if not
          await _checkAndCreateUser(userCredential.user, models.AuthProvider.apple);
          
          return userCredential;
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => _appConfig.log('Retrying Apple sign-in due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error signing in with Apple');
      throw Exception(getFriendlyErrorMessage(e));
    }
  }

  /// Sign in with phone number - verify code
  /// Returns UserCredential on success
  /// Throws FirebaseAuthException on error
  Future<UserCredential> signInWithPhoneNumber(
    String verificationId, 
    String smsCode,
  ) async {
    try {
      return await _retryOptions.retry(
        () async {
          // Create a PhoneAuthCredential with the verification ID and SMS code
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: smsCode,
          );

          // Sign in with credential
          final userCredential = await _auth.signInWithCredential(credential);
          
          // Check if user exists, create if not
          await _checkAndCreateUser(userCredential.user, models.AuthProvider.phone);
          
          // Generate and save FCM token
          await _generateAndSaveFcmToken(userCredential.user?.uid);
          
          return userCredential;
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => _appConfig.log('Retrying phone sign-in due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error signing in with phone number');
      throw Exception(getFriendlyErrorMessage(e));
    }
  }

  /// Generate and save FCM token for push notifications
  Future<void> _generateAndSaveFcmToken(String? firebaseUid) async {
    if (firebaseUid == null) return;
    
    try {
      await _retryOptions.retry(
        () async {
          // Get the FCM token
          final messaging = FirebaseMessaging.instance;
          final token = await messaging.getToken();
          
          if (token != null) {
            // Save the token to Firestore
            await _firestore.collection('users').doc(firebaseUid).update({
              'fcmToken': token,
              'lastLoginAt': Timestamp.now(),
            });
            
            _appConfig.log('FCM Token generated and saved');
          }
        },
        retryIf: (e) => e is FirebaseException && _shouldRetryFirestore(e),
        onRetry: (e) => _appConfig.log('Retrying FCM token save due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error generating FCM token');
      // Don't rethrow - we don't want to fail sign-in if FCM fails
    }
  }

  /// Check if user exists in Firestore by Firebase UID
  /// Returns true if user exists, false otherwise
  Future<bool> userExists(String firebaseUid) async {
    try {
      return await _retryOptions.retry(
        () async {
          final docSnapshot = await _firestore.collection('users').doc(firebaseUid).get();
          return docSnapshot.exists;
        },
        retryIf: (e) => e is FirebaseException && _shouldRetryFirestore(e),
        onRetry: (e) => _appConfig.log('Retrying user exists check due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error checking if user exists');
      return false;
    }
  }

  /// Check if user exists and create if not
  Future<void> _checkAndCreateUser(User? user, models.AuthProvider provider) async {
    if (user == null) return;

    try {
      await _retryOptions.retry(
        () async {
          // Check if user already exists by Firebase UID
          final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
          
          if (!docSnapshot.exists) {
            // Generate a new 8-digit number for uid
            final customUid = await _getOrGenerate8DigitUid();
            
            // Generate a new room ID for the user
            final roomId = _generateRoomId();
            
            // Create metadata with all user information
            final metadata = <String, dynamic>{
              'email': user.email ?? '',
              'phoneNumber': user.phoneNumber,
            };
            
            // Create a new user document using Firebase UID as doc ID
            // but include the 8-digit ID as the 'uid' field
            final newUser = models.UserModel(
              uid: customUid,  // Use 8-digit ID as the uid field
              displayName: user.displayName ?? 'User',
              photoURL: user.photoURL,
              providers: [provider],
              createdAt: Timestamp.now(),
              lastLoginAt: Timestamp.now(),
              metadata: metadata,
              roomId: roomId,
            );
            
            // Store user data in Firestore
            await _firestore.collection('users').doc(user.uid).set(newUser.toJson());
            _appConfig.log('Created new user with 8-digit UID: $customUid');
          } else {
            // User exists, update last login time
            await _firestore.collection('users').doc(user.uid).update({
              'lastLoginAt': Timestamp.now(),
              'fcmToken': null, // Will be updated later
            });
            _appConfig.log('Updated existing user login timestamp');
          }
        },
        retryIf: (e) => e is FirebaseException && _shouldRetryFirestore(e),
        onRetry: (e) => _appConfig.log('Retrying user creation due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error checking/creating user');
      // We might want to rethrow here depending on how critical this is
    }
  }

  /// Sign out from all providers
  Future<void> signOut() async {
    try {
      await _retryOptions.retry(
        () async {
          await _googleSignIn.signOut();
          await _auth.signOut();
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => _appConfig.log('Retrying sign out due to error: $e'),
      );
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error signing out');
      rethrow;
    }
  }
  
  /// Helper method to determine if we should retry an operation
  bool _shouldRetry(dynamic error) {
    if (error is FirebaseAuthException) {
      // Retry for network errors or server errors
      final code = error.code;
      return code == 'network-request-failed' || 
             code == 'timeout' || 
             code == 'app-not-authorized';
    } else if (error is FirebaseException) {
      return _shouldRetryFirestore(error);
    } else if (error is PlatformException) {
      // Retry for network-related platform exceptions
      return error.code == 'network_error' || 
             error.code == 'sign_in_failed' && 
             error.message?.contains('network') == true;
    } else if (error is Exception) {
      // Retry for general network exceptions
      final message = error.toString().toLowerCase();
      return message.contains('network') || 
             message.contains('connection') || 
             message.contains('timeout');
    }
    return false;
  }
  
  /// Helper method specifically for Firestore errors
  bool _shouldRetryFirestore(FirebaseException error) {
    final code = error.code;
    return code == 'unavailable' || 
           code == 'deadline-exceeded' || 
           code == 'cancelled' ||
           code == 'network-request-failed';
  }

  /// Generate a random room ID for the user
  String _generateRoomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      List.generate(8, (index) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  /// Dispose resources used by the service
  void dispose() {
    _cacheRefreshTimer?.cancel();
    _cacheRefreshTimer = null;
    _cachedUserModel = null;
  }

  /// Get Firebase Auth UID from 8-digit UID
  Future<String?> getFirebaseUidFrom8DigitUid(String eightDigitUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: eightDigitUid)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      
      // The document ID is the Firebase Auth UID
      return querySnapshot.docs.first.id;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error getting Firebase UID from 8-digit UID');
      return null;
    }
  }
  
  /// Get 8-digit UID from Firebase Auth UID
  Future<String?> get8DigitUidFromFirebaseUid(String firebaseUid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(firebaseUid).get();
      
      if (!docSnapshot.exists) return null;
      
      final userData = docSnapshot.data() as Map<String, dynamic>;
      return userData['uid'] as String?;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: 'Error getting 8-digit UID from Firebase UID');
      return null;
    }
  }
}


