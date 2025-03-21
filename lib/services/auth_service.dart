import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:retry/retry.dart';
import '../models/user_model.dart' as models;
import 'dart:math';
import 'dart:async'; 

/// A service class that handles all authentication operations including:
/// - Sign in with various providers (Google, Apple, Phone)
/// - User data management in Firestore
/// - FCM token management
/// - Auth state tracking
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
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
            verificationFailed: verificationFailed,
            codeSent: codeSent,
            codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
            timeout: timeout,
          );
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => debugPrint('Retrying phone verification due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error starting phone verification after retries: $e');
      rethrow;
    }
  }

  /// Get the current user model
  /// Will return cached version if available, or fetch from Firestore
  Future<models.UserModel?> getCurrentUserModel() async {
    if (_auth.currentUser == null) return null;
    
    if (_cachedUserModel != null && 
        _cachedUserModel!.uid == _auth.currentUser!.uid) {
      return _cachedUserModel;
    }
    
    return await getUserModel(_auth.currentUser!.uid);
  }

  /// Get a user model by UID
  Future<models.UserModel?> getUserModel(String uid) async {
    print('AuthService: Getting user model for UID: $uid');
    try {
      print('AuthService: Fetching user document from Firestore');
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      
      print('AuthService: Document exists: ${docSnapshot.exists}');
      if (!docSnapshot.exists) {
        print('AuthService: No user document found');
        return null;
      }
      
      final userData = docSnapshot.data() as Map<String, dynamic>;
      print('AuthService: User data found: ${userData['displayName']}');
      final userModel = models.UserModel.fromJson(userData);
      
      // Cache the user model if it's the current user
      if (_auth.currentUser != null && uid == _auth.currentUser!.uid) {
        print('AuthService: Caching user model for current user');
        _cachedUserModel = userModel;
        _setupCacheRefresh();
      }
      
      return userModel;
    } catch (e) {
      print('AuthService: Error getting user model for $uid: $e');
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
    return await getUserModel(_auth.currentUser!.uid);
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
        onRetry: (e) => debugPrint('Retrying profile update due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error updating user profile: $e');
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
        onRetry: (e) => debugPrint('Retrying Google sign-in due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error signing in with Google after retries: $e');
      rethrow;
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
          
          // Update user data in Firestore
          await _updateUserData(userCredential.user, models.AuthProvider.apple);
          
          return userCredential;
        },
        retryIf: (e) => _shouldRetry(e),
        onRetry: (e) => debugPrint('Retrying Apple sign-in due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error signing in with Apple after retries: $e');
      rethrow;
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
        onRetry: (e) => debugPrint('Retrying phone sign-in due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error signing in with phone number after retries: $e');
      rethrow;
    }
  }

  /// Generate and save FCM token for push notifications
  Future<void> _generateAndSaveFcmToken(String? uid) async {
    if (uid == null) return;
    
    try {
      await _retryOptions.retry(
        () async {
          // Get the FCM token
          final messaging = FirebaseMessaging.instance;
          final token = await messaging.getToken();
          
          if (token != null) {
            // Save the token to Firestore
            await _firestore.collection('users').doc(uid).update({
              'fcmToken': token,
              'lastLoginAt': Timestamp.now(),
            });
            
            debugPrint('FCM Token generated and saved: $token');
          }
        },
        retryIf: (e) => e is FirebaseException && _shouldRetryFirestore(e),
        onRetry: (e) => debugPrint('Retrying FCM token save due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error generating FCM token after retries: $e');
      // Don't rethrow - we don't want to fail sign-in if FCM fails
    }
  }

  /// Check if user exists in Firestore
  /// Returns true if user exists, false otherwise
  Future<bool> userExists(String uid) async {
    try {
      return await _retryOptions.retry(
        () async {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          return userDoc.exists;
        },
        retryIf: (e) => e is FirebaseException && _shouldRetryFirestore(e),
        onRetry: (e) => debugPrint('Retrying user exists check due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error checking if user exists after retries: $e');
      return false;
    }
  }

  /// Check if user exists and create if not
  Future<void> _checkAndCreateUser(User? user, models.AuthProvider provider) async {
    if (user == null) return;

    try {
      await _retryOptions.retry(
        () async {
          final exists = await userExists(user.uid);
          
          if (!exists) {
            // Generate a new room ID for the user
            final roomId = _generateRoomId();
            
            // Create metadata with all user information
            final metadata = <String, dynamic>{
              'email': user.email ?? '',
              'phoneNumber': user.phoneNumber,
            };
            
            // Create a new user document with consistent field placement
            final newUser = models.UserModel(
              uid: user.uid,
              displayName: user.displayName ?? 'User',
              photoURL: user.photoURL,
              providers: [provider],
              createdAt: Timestamp.now(),
              lastLoginAt: Timestamp.now(),
              metadata: metadata,
              roomId: roomId,
            );
            
            await _firestore.collection('users').doc(user.uid).set(newUser.toJson());
          } else {
            // Only update login time and FCM token for existing users
            await _firestore.collection('users').doc(user.uid).update({
              'lastLoginAt': Timestamp.now(),
              'fcmToken': null, // Will be updated later
            });
          }
        },
        retryIf: (e) => e is FirebaseException && _shouldRetryFirestore(e),
        onRetry: (e) => debugPrint('Retrying user creation due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error checking/creating user after retries: $e');
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
        onRetry: (e) => debugPrint('Retrying sign out due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error signing out after retries: $e');
      rethrow;
    }
  }

  /// Update user data in Firestore
  Future<void> _updateUserData(User? user, models.AuthProvider provider) async {
    if (user == null) return;

    try {
      await _retryOptions.retry(
        () async {
          final userDoc = _firestore.collection('users').doc(user.uid);
          final userSnapshot = await userDoc.get();
          
          if (userSnapshot.exists) {
            // User exists, update the data
            final existingUserData = userSnapshot.data() as Map<String, dynamic>;
            final existingUser = models.UserModel.fromJson(existingUserData);
            
            // Add the new provider if it doesn't exist
            if (!existingUser.hasProvider(provider)) {
              final updatedUser = existingUser.addProvider(provider);
              await userDoc.update(updatedUser.toJson());
            } else {
              // Just update the last login time
              await userDoc.update({
                'lastLoginAt': Timestamp.now(),
                'fcmToken': null, // Clear FCM token on login, will be updated later
              });
            }
          } else {
            // New user, create a document with consistent field placement
            final roomId = _generateRoomId();
            
            // Create metadata with all user information
            final metadata = <String, dynamic>{
              'email': user.email ?? '',
              'phoneNumber': user.phoneNumber,
            };
            
            final newUser = models.UserModel(
              uid: user.uid,
              displayName: user.displayName ?? 'User',
              photoURL: user.photoURL,
              providers: [provider],
              createdAt: Timestamp.now(),
              lastLoginAt: Timestamp.now(),
              metadata: metadata,
              roomId: roomId,
            );
            
            await userDoc.set(newUser.toJson());
          }
        },
        retryIf: (e) => e is FirebaseException && _shouldRetryFirestore(e),
        onRetry: (e) => debugPrint('Retrying user data update due to error: $e'),
      );
    } catch (e) {
      debugPrint('Error updating user data after retries: $e');
      // We might want to rethrow here depending on how critical this is
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
}


