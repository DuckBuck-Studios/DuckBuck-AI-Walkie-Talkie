import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import '../services/auth/auth_service_interface.dart';
import '../models/user_model.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/firebase/firebase_storage_service.dart';
import '../services/service_locator.dart';
import '../exceptions/auth_exceptions.dart';
import '../services/logger/logger_service.dart';
import '../services/notifications/notifications_service.dart';
import '../services/user/user_service_interface.dart';
import '../services/database/local_database_service.dart';

/// Repository to handle user data operations
class UserRepository {
  final AuthServiceInterface authService;
  final UserServiceInterface _userService;
  final LoggerService _logger;
  final FirebaseAnalyticsService _analytics;
  final FirebaseCrashlyticsService _crashlytics;
  
  // Stream subscriptions for cleanup
  StreamSubscription<UserModel?>? _userDocumentSubscription;
  
  static const String _tag = 'USER_REPO'; // Tag for logs

  /// Creates a new UserRepository
  UserRepository({
    required this.authService, 
    UserServiceInterface? userService,
    FirebaseAnalyticsService? analytics,
    FirebaseCrashlyticsService? crashlytics,
    LoggerService? logger,
  }) : _userService = userService ?? serviceLocator<UserServiceInterface>(),
       _analytics = analytics ?? serviceLocator<FirebaseAnalyticsService>(),
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Get the current authenticated user
  /// First tries to get from local database, then falls back to Firebase
  /// WARNING: This is a synchronous getter that may not have complete Firestore data
  /// Use getCurrentUser() async method instead for complete user data with agentRemainingTime
  UserModel? get currentUser {
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) return null;
    // This only creates a basic model - agentRemainingTime will be 0 
    // Real data should be loaded from Firestore via getCurrentUser()
    return UserModel.fromFirebaseUser(firebaseUser);
  }
  
  /// Get the current user with caching (async version)
  /// This method tries local DB first, then refreshes from Firebase on app open
  Future<UserModel?> getCurrentUser() async {
    try {
      final localDb = LocalDatabaseService.instance;
      
      _logger.i(_tag, 'Getting current user with cache priority');
      
      // First try to get current user from local database
      final cachedUser = await localDb.getCurrentUser();
      if (cachedUser != null) {
        _logger.i(_tag, 'Retrieved current user from local database cache');
        return cachedUser;
      }
      
      // Fallback to Firebase if no local data
      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) {
        _logger.d(_tag, 'No user found in local DB or Firebase');
        return null;
      }
      
      // First, try to get complete user data from Firestore (with real agentRemainingTime)
      try {
        final firestoreUser = await _userService.getUserData(firebaseUser.uid);
        if (firestoreUser != null) {
          // Save complete data to local database and return it
          await localDb.saveUser(firestoreUser);
          await localDb.setUserLoggedIn(firestoreUser.uid, true);
          _logger.i(_tag, 'User data loaded from Firestore with agentRemainingTime: ${firestoreUser.agentRemainingTime}s');
          return firestoreUser;
        }
      } catch (e) {
        _logger.w(_tag, 'Failed to load complete user data from Firestore: $e');
      }
      
      // Final fallback: create user from Firebase Auth (WARNING: agentRemainingTime will be 0)
      final user = UserModel.fromFirebaseUser(firebaseUser);
      _logger.w(_tag, 'Created basic user from Firebase Auth - agentRemainingTime will be 0 until Firestore data loads');
      
      // Save to local database and return cached version
      await localDb.saveUser(user);
      await localDb.setUserLoggedIn(user.uid, true);
      final updatedUser = await localDb.getCurrentUser();
      _logger.i(_tag, 'User data refreshed from Firebase and cached in local database');
      
      return updatedUser ?? user;
    } catch (e) {
      _logger.w(_tag, 'Failed to get current user: ${e.toString()}');
      // Ultimate fallback to Firebase sync method
      final firebaseUser = authService.currentUser;
      return firebaseUser != null ? UserModel.fromFirebaseUser(firebaseUser) : null;
    }
  }

  /// Stream of auth state changes converted to UserModel
  /// WARNING: This stream provides basic Firebase Auth data only
  /// For complete user data with agentRemainingTime, use getUserReactiveStream() instead
  Stream<UserModel?> get userStream {
    return authService.authStateChanges.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      
      // Try to get complete user data from Firestore first
      try {
        final firestoreUser = await _userService.getUserData(firebaseUser.uid);
        if (firestoreUser != null) {
          _logger.d(_tag, 'User stream: Loaded complete data from Firestore');
          return firestoreUser;
        }
      } catch (e) {
        _logger.w(_tag, 'User stream: Failed to load Firestore data: $e');
      }
      
      // Fallback to basic Firebase Auth data (agentRemainingTime will be 0)
      _logger.w(_tag, 'User stream: Using basic Firebase Auth data - agentRemainingTime will be 0');
      return UserModel.fromFirebaseUser(firebaseUser);
    });
  }

  // Email and password authentication has been removed in favor of social auth and phone auth

  /// Sign in with Google
  Future<(UserModel, bool)> signInWithGoogle() async {
    try {
      // Log authentication attempt
      await _analytics.logAuthAttempt(authMethod: 'google');
      
      final credential = await authService.signInWithGoogle();
      
      // Create user model
      var user = UserModel.fromFirebaseUser(credential.user!);
      
      // Ensure authMethod is in metadata
      if (user.metadata == null || user.metadata!['authMethod'] == null) {
        // Update metadata with auth method
        Map<String, dynamic> updatedMetadata = {...(user.metadata ?? {}), 'authMethod': 'google'};
        user = user.copyWith(metadata: updatedMetadata);
      }
      
      _logger.i(_tag, 'Google auth sign-in with auth method: ${user.metadata?['authMethod'] ?? "unknown"}');
      
      // Check if this is actually a new sign-in to Firebase Auth
      final isNewToFirebase = credential.additionalUserInfo?.isNewUser ?? false;
      _logger.d(_tag, 'Firebase reports isNewUser: $isNewToFirebase for Google sign-in');
      
      // If Firebase says this is a new user, definitely treat as new
      if (isNewToFirebase) {
        _logger.i(_tag, 'Creating new user document for Google user as reported by Firebase');
        await _createUserData(user);
        
        // Save user to local database
        final localDb = LocalDatabaseService.instance;
        await localDb.saveUser(user);
        await localDb.setUserLoggedIn(user.uid, true);
        await localDb.startUserSession(user.uid, 'google');
        
        // Log successful sign up
        await _analytics.logSignUp(signUpMethod: 'google');
        await _analytics.logAuthSuccess(
          authMethod: 'google',
          userId: user.uid,
          isNewUser: true,
        );
        
        // Set user ID in Crashlytics
        await _crashlytics.setUserIdentifier(user.uid);
        // Log user identifying info (non-PII)
        await _crashlytics.log('User signed up with Google');
        
        return (user, true);
      }
      
      // Otherwise, check if user exists in Firestore and create if needed
      final isNewToFirestore = await _createOrUpdateUserData(user);
      
      // Generate and save FCM token after user data is saved
      await _generateAndSaveFCMToken(user.uid);
      
      // Save user to local database for all sign-ins
      final localDb = LocalDatabaseService.instance;
      await localDb.saveUser(user);
      await localDb.setUserLoggedIn(user.uid, true);
      await localDb.startUserSession(user.uid, 'google');
      
      // Log successful login
      await _analytics.logLogin(loginMethod: 'google');
      await _analytics.logAuthSuccess(
        authMethod: 'google',
        userId: user.uid,
        isNewUser: isNewToFirestore,
      );
      
      // Only send login notification for returning users, not for new users
      // New users will get welcome email after profile completion
      if (!isNewToFirestore) {
        _logger.i(_tag, 'Returning Google user - login completed');
      } else {
        _logger.i(_tag, 'New Google user - profile completion required');
      }
      
      // Set user ID in Crashlytics
      await _crashlytics.setUserIdentifier(user.uid);
      // Log user identifying info (non-PII)
      await _crashlytics.log('User logged in with Google');
      
      return (user, isNewToFirestore);
    } catch (e) {
      // Log authentication failure
      await _analytics.logAuthFailure(
        authMethod: 'google',
        reason: e.toString(),
        errorCode: e is FirebaseAuthException ? e.code : null,
      );
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<(UserModel, bool)> signInWithApple() async {
    try {
      // Log authentication attempt with Apple
      await _analytics.logAuthAttempt(authMethod: 'apple');
      
      final credential = await authService.signInWithApple();
      
      // Create user model
      var user = UserModel.fromFirebaseUser(credential.user!);
      
      // Ensure authMethod is in metadata
      if (user.metadata == null || user.metadata!['authMethod'] == null) {
        // Update metadata with auth method
        Map<String, dynamic> updatedMetadata = {...(user.metadata ?? {}), 'authMethod': 'apple'};
        user = user.copyWith(metadata: updatedMetadata);
      }
      
      _logger.i(_tag, 'Apple auth sign-in with auth method: ${user.metadata?['authMethod'] ?? "unknown"}');
      
      // Check if this is actually a new sign-in to Firebase Auth
      final isNewToFirebase = credential.additionalUserInfo?.isNewUser ?? false;
      _logger.d(_tag, 'Firebase reports isNewUser: $isNewToFirebase for Apple sign-in');
      
      // If Firebase says this is a new user, definitely treat as new
      if (isNewToFirebase) {
        _logger.i(_tag, 'Creating new user document for Apple user as reported by Firebase');
        await _createUserData(user);
        
        // Save user to local database
        final localDb = LocalDatabaseService.instance;
        await localDb.saveUser(user);
        await localDb.setUserLoggedIn(user.uid, true);
        await localDb.startUserSession(user.uid, 'apple');
        
        // Log successful sign up with Apple
        await _analytics.logSignUp(signUpMethod: 'apple');
        await _analytics.logAuthSuccess(
          authMethod: 'apple',
          userId: user.uid,
          isNewUser: true,
        );
        
        // Set user ID in Crashlytics
        await _crashlytics.setUserIdentifier(user.uid);
        await _crashlytics.log('User signed up with Apple');
        
        return (user, true);
      }
      
      // Otherwise, check if user exists in Firestore and create if needed
      final isNewToFirestore = await _createOrUpdateUserData(user);
      
      // Generate and save FCM token after user data is saved
      await _generateAndSaveFCMToken(user.uid);
      
      // Save user to local database for all sign-ins
      final localDb = LocalDatabaseService.instance;
      await localDb.saveUser(user);
      await localDb.setUserLoggedIn(user.uid, true);
      await localDb.startUserSession(user.uid, 'apple');
      
      // Log successful login with Apple
      await _analytics.logLogin(loginMethod: 'apple');
      await _analytics.logAuthSuccess(
        authMethod: 'apple',
        userId: user.uid,
        isNewUser: isNewToFirestore,
      );
      
      // Only send login notification for returning users, not for new users
      // New users will get welcome email after profile completion
      if (!isNewToFirestore) {
        _logger.i(_tag, 'Returning Apple user - login completed');
      } else {
        _logger.i(_tag, 'New Apple user - profile completion required');
      }
      
      // Set user ID in Crashlytics
      await _crashlytics.setUserIdentifier(user.uid);
      await _crashlytics.log('User logged in with Apple');
      
      return (user, isNewToFirestore);
    } catch (e) {
      // Log authentication failure with Apple
      await _analytics.logAuthFailure(
        authMethod: 'apple',
        reason: e.toString(),
        errorCode: e is FirebaseAuthException ? e.code : null,
      );
      rethrow;
    }
  }

  /// Initiate phone auth verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(AuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      _logger.i(_tag, 'Starting phone verification for number: $phoneNumber');
      
      // Check if the phone number is rate limited
      final (isLimited, timeoutRemaining) = isPhoneNumberRateLimited(phoneNumber);
      if (isLimited) {
        _logger.w(_tag, 'Phone verification rate limited: must wait $timeoutRemaining more seconds');
        
        // Log rate limiting in analytics
        await _analytics.logAuthFailure(
          authMethod: 'phone',
          reason: 'Rate limited',
          errorCode: 'too_many_attempts',
        );
        
        verificationFailed(
          AuthException(
            AuthErrorCodes.tooManyRequests,
            'Too many verification attempts. Please wait ${_formatTimeRemaining(timeoutRemaining)} before trying again.',
            null,
            AuthMethod.phone,
          ),
        );
        return;
      }
      
      // Log phone verification started
      await _analytics.logPhoneVerificationStarted(
        phoneNumber: phoneNumber,
        countryCode: phoneNumber.startsWith('+') ? phoneNumber.split(' ').first : null,
      );
      
      return await authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Log auto-verification success
          _analytics.logOtpEntered(isSuccessful: true, isAutoFilled: true);
          verificationCompleted(credential);
        },
        verificationFailed: (AuthException exception) {
          // Log verification failure
          _analytics.logAuthFailure(
            authMethod: 'phone',
            reason: exception.message,
            errorCode: exception.code,
          );
          verificationFailed(exception);
        },
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      // Log general error during verification
      await _analytics.logAuthFailure(
        authMethod: 'phone_verification',
        reason: e.toString(),
      );
      rethrow;
    }
  }
  
  /// Format a time duration in seconds into a user-friendly string
  String _formatTimeRemaining(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      final hours = (seconds / 3600).floor();
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
  }

  /// Verify phone OTP code and sign in
  Future<(UserModel, bool)> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    try {
      // Check if OTP verification attempts are rate limited for this number
      final (isLimited, timeoutRemaining) = isOtpVerificationRateLimited(phoneNumber);
      if (isLimited) {
        _logger.w(_tag, 'OTP verification rate limited for $phoneNumber: must wait $timeoutRemaining more seconds');
        
        // Log rate limiting event
        await _analytics.logAuthFailure(
          authMethod: 'phone_otp',
          reason: 'Rate limited',
          errorCode: 'too_many_attempts',
        );
        
        throw AuthException(
          AuthErrorCodes.tooManyRequests,
          'Too many verification attempts. Please wait ${_formatTimeRemaining(timeoutRemaining)} before trying again.',
          null,
          AuthMethod.phone,
        );
      }
      
      // Log OTP verification attempt
      await _analytics.logAuthAttempt(
        authMethod: 'phone_otp',
        additionalParams: {'otp_length': smsCode.length},
      );
      
      final credential = await authService.verifyOtpAndSignIn(
        verificationId,
        smsCode,
      );
      
      // Log OTP entry success
      await _analytics.logOtpEntered(isSuccessful: true);
      
      // Create user model
      var user = UserModel.fromFirebaseUser(credential.user!);
      
      // Ensure authMethod is in metadata
      if (user.metadata == null || user.metadata!['authMethod'] == null) {
        // Update metadata with auth method
        Map<String, dynamic> updatedMetadata = {...(user.metadata ?? {}), 'authMethod': 'phone'};
        user = user.copyWith(metadata: updatedMetadata);
      }
      
      _logger.i(_tag, 'Phone auth OTP verification with auth method: ${user.metadata?['authMethod'] ?? "unknown"}');

      // Check if user exists in Firestore and create if needed
      final isNewUser = await _createOrUpdateUserData(user);
      
      // Generate and save FCM token after user data is saved
      await _generateAndSaveFCMToken(user.uid);
      
      // Log authentication success
      if (isNewUser) {
        await _analytics.logSignUp(signUpMethod: 'phone');
      } else {
        await _analytics.logLogin(loginMethod: 'phone');
      }
      
      await _analytics.logAuthSuccess(
        authMethod: 'phone',
        userId: user.uid,
        isNewUser: isNewUser,
      );
      
      // Set user ID in Crashlytics
      await _crashlytics.setUserIdentifier(user.uid);
      await _crashlytics.log('User authenticated with phone');

      return (user, isNewUser);
    } catch (e) {
      // Log OTP entry failure
      await _analytics.logOtpEntered(isSuccessful: false);
      
      // Log authentication failure
      await _analytics.logAuthFailure(
        authMethod: 'phone_otp',
        reason: e.toString(),
        errorCode: e is FirebaseAuthException ? e.code : null,
      );
      rethrow;
    }
  }

  /// Sign in with phone auth credential
  Future<(UserModel, bool)> signInWithPhoneAuthCredential(
    dynamic credential,
  ) async {
    try {
      // Additional logging to debug verification issues
      _logger.i(_tag, 'Starting phone auth credential verification');
      if (credential.verificationId != null) {
        _logger.d(_tag, 'Verification ID length: ${credential.verificationId!.length}');
      } else {
        _logger.w(_tag, 'No verification ID in the credential');
      }
      
      // Log manual verification attempt
      await _analytics.logAuthAttempt(
        authMethod: 'phone_manual',
        additionalParams: {'verification_method': 'manual_code_entry'},
      );
      
      // Attempt to sign in with the credential
      final userCredential = await authService.signInWithPhoneAuthCredential(
        credential,
      );
      
      if (userCredential.user == null) {
        _logger.e(_tag, 'Authentication succeeded but no user was returned');
        throw AuthException(
          AuthErrorCodes.phoneAuthFailed,
          'Authentication succeeded but no user was returned',
        );
      }
      
      // Create user model
      var user = UserModel.fromFirebaseUser(userCredential.user!);
      
      // Ensure authMethod is in metadata
      if (user.metadata == null || user.metadata!['authMethod'] == null) {
        // Update metadata with auth method
        Map<String, dynamic> updatedMetadata = {...(user.metadata ?? {}), 'authMethod': 'phone'};
        user = user.copyWith(metadata: updatedMetadata);
      }
      
      _logger.i(_tag, 'Phone auth sign-in with auth method: ${user.metadata?['authMethod'] ?? "unknown"}');

      // Check if user exists in Firestore and create if needed
      final isNewUser = await _createOrUpdateUserData(user);
      
      // Generate and save FCM token after user data is saved
      await _generateAndSaveFCMToken(user.uid);
      
      // Save user to local database
      final localDb = LocalDatabaseService.instance;
      await localDb.saveUser(user);
      await localDb.setUserLoggedIn(user.uid, true);
      await localDb.startUserSession(user.uid, 'phone');
      
      // Log authentication success
      if (isNewUser) {
        await _analytics.logSignUp(signUpMethod: 'phone');
      } else {
        await _analytics.logLogin(loginMethod: 'phone');
      }
      
      await _analytics.logAuthSuccess(
        authMethod: 'phone_manual',
        userId: user.uid,
        isNewUser: isNewUser,
      );

      return (user, isNewUser);
    } on FirebaseAuthException catch (e) {
      // Log authentication failure with specific error code
      _logger.e(_tag, 'Firebase Auth Exception in phone sign-in: ${e.code} - ${e.message}');
      
      await _analytics.logAuthFailure(
        authMethod: 'phone_manual',
        reason: e.message ?? e.toString(),
        errorCode: e.code,
      );
      
      // Map Firebase error code to our own error codes
      String errorCode;
      switch (e.code) {
        case 'invalid-verification-code':
          errorCode = AuthErrorCodes.invalidVerificationCode;
          break;
        case 'invalid-verification-id':
          errorCode = AuthErrorCodes.invalidVerificationId;
          break;
        case 'session-expired':
          errorCode = AuthErrorCodes.sessionExpired;
          break;
        case 'code-expired':
          errorCode = AuthErrorCodes.smsCodeExpired;
          break;
        default:
          errorCode = AuthErrorCodes.phoneAuthFailed;
      }
      
      throw AuthException(
        errorCode,
        e.message ?? 'Failed to verify phone number',
        e,
        AuthMethod.phone,
      );
    } catch (e) {
      // Log generic authentication failure
      _logger.e(_tag, 'Unexpected error during phone auth: ${e.toString()}');
      
      await _analytics.logAuthFailure(
        authMethod: 'phone_manual',
        reason: e.toString(),
      );
      
      if (e is AuthException) {
        rethrow;  
      }
      throw AuthException(
        AuthErrorCodes.phoneAuthFailed,
        'Failed to sign in with phone credential',
        e,
        AuthMethod.phone,
      );
    }
  }



  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = currentUser;
      if (user == null) {
        _logger.w(_tag, 'Cannot update profile: No logged-in user');
        return;
      }
      
      // Track which fields are being updated
      final Map<String, Object> updatedFields = {};
      if (displayName != null) updatedFields['display_name'] = true;
      if (photoURL != null) updatedFields['photo_url'] = true;
      
      // Log profile update attempt
      await _analytics.logEvent(
        name: 'profile_update_start',
        parameters: {
          'user_id': user.uid,
          'fields_updated': updatedFields.keys.join(','),
        },
      );
      
      // Update auth profile
      await authService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      // First retrieve the current Firestore user data to get the fcmTokenData and metadata
      final currentFirestoreData = await getUserData(user.uid);
      
      final updatedUser = user.copyWith(
        displayName: displayName ?? user.displayName,
        photoURL: photoURL ?? user.photoURL,
        // Preserve existing FCM token data if available
        fcmTokenData: currentFirestoreData?.fcmTokenData,
        // Preserve the metadata
        metadata: currentFirestoreData?.metadata ?? user.metadata,
      );

      await _updateUserData(updatedUser);
      
      // Log successful profile update
      await _analytics.logEvent(
        name: 'profile_update_success',
        parameters: {
          'user_id': user.uid,
          'fields_updated': updatedFields.keys.join(','),
        },
      );
    } catch (e) {
      _logger.e(_tag, 'Error updating profile: ${e.toString()}');
      
      // Log profile update failure
      await _analytics.logEvent(
        name: 'profile_update_failure',
        parameters: {
          'reason': e.toString(),
          'error_code': e is FirebaseAuthException ? e.code : 'unknown',
        },
      );
      
      rethrow;
    }
  }

  /// Upload user profile photo and update profile
  /// Returns the download URL of the uploaded photo
  Future<String> uploadProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    try {
      _logger.i(_tag, 'Uploading profile photo for user: $userId');
      
      // Log photo upload attempt
      await _analytics.logEvent(
        name: 'profile_photo_upload_start',
        parameters: {
          'user_id': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Get Firebase storage service to upload the image
      final storageService = serviceLocator<FirebaseStorageService>();
      final photoURL = await storageService.uploadProfileImage(
        userId: userId,
        imageFile: imageFile,
      );
      
      _logger.i(_tag, 'Profile photo uploaded successfully: $photoURL');
      
      // Log successful photo upload
      await _analytics.logEvent(
        name: 'profile_photo_upload_success',
        parameters: {
          'user_id': userId,
          'photo_url_length': photoURL.length,
        },
      );
      
      return photoURL;
    } catch (e) {
      _logger.e(_tag, 'Failed to upload profile photo: ${e.toString()}');
      
      // Log photo upload failure
      await _analytics.logEvent(
        name: 'profile_photo_upload_failure',
        parameters: {
          'user_id': userId,
          'error': e.toString(),
        },
      );
      
      rethrow;
    }
  }

  // Password reset functionality has been removed

  /// Get user data with caching
  /// First tries local database, then falls back to Firebase/Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final localDb = LocalDatabaseService.instance;
      
      // First try to get user from local database
      final cachedUser = await localDb.getUser(uid);
      if (cachedUser != null) {
        _logger.d(_tag, 'Retrieved user data from local database cache: $uid');
        return cachedUser;
      }
      
      // Fallback to Firebase/Firestore
      final user = await _userService.getUserData(uid);
      
      if (user != null) {
        // Cache the fresh data in local database
        await localDb.saveUser(user);
        _logger.d(_tag, 'User data fetched from Firebase and cached: $uid');
      }
      
      return user;
    } catch (e) {
      _logger.e(_tag, 'Failed to get user data: ${e.toString()}');
      rethrow;
    }
  }

  /// Helper method to generate and save FCM token after successful authentication
  Future<void> _generateAndSaveFCMToken(String userId) async {
    try {
      _logger.i(_tag, 'Generating FCM token for authenticated user: $userId');
      
      // Get notifications service to generate and save FCM token
      final notificationsService = serviceLocator<NotificationsService>();
      await notificationsService.generateAndSaveToken(userId);
      
      _logger.i(_tag, 'FCM token generation completed for user: $userId');
    } catch (e) {
      // Log error but don't fail the authentication process
      _logger.e(_tag, 'Failed to generate FCM token for user $userId: ${e.toString()}');
    }
  }

  /// Create user record in Firestore
  Future<void> _createUserData(UserModel user) async {
    try {
      await _userService.createUserData(user);
      
      final providerId = user.metadata?['providerId'] as String? ?? 'unknown';
      _logger.i(_tag, 'Created new user with auth provider: $providerId');
    } catch (e) {
      _logger.e(_tag, 'Failed to create user data: ${e.toString()}');
      rethrow;
    }
  }

  /// Update existing user record in Firestore
  Future<void> _updateUserData(UserModel user) async {
    try {
      // First retrieve the current user data to preserve important fields
      final currentData = await _userService.getUserData(user.uid);
      
      // Create an updated user with preserved FCM data AND agentRemainingTime
      final updatedUser = user.copyWith(
        fcmTokenData: currentData?.fcmTokenData,
        agentRemainingTime: currentData?.agentRemainingTime, // Preserve AI agent time
      );
      
      await _userService.updateUserData(updatedUser);
      
      final authMethod = user.metadata?['authMethod'] as String? ?? 'unknown';
      _logger.i(_tag, 'Updated user data with auth method: $authMethod (preserved agentRemainingTime: ${currentData?.agentRemainingTime ?? 0}s)');
    } catch (e) {
      _logger.e(_tag, 'Failed to update user data: ${e.toString()}');
      rethrow;
    }
  }
   

  /// Create or update user data in Firestore
  /// Returns true if this is a new user (first time in Firestore)
  Future<bool> _createOrUpdateUserData(UserModel user) async {
    try {
      _logger.d(
        _tag, 'Checking if user ${user.uid} exists in Firestore',
      );
      
      return await _userService.createOrUpdateUserData(user);
    } catch (e) {
      _logger.e(_tag, 'CHECKING USER EXISTENCE ERROR: ${e.toString()}');
      rethrow;
    }
  }

  // Account deletion functionality has been removed

  /// Check if a user is new (doesn't exist in Firestore or has isNewUser flag)
  Future<bool> checkIfUserIsNew(String uid) async {
    try {
      _logger.d(_tag, 'Checking if user $uid is new');
      
      return await _userService.checkIfUserIsNew(uid);
    } catch (e) {
      _logger.e(_tag, 'USER REPO ERROR: ${e.toString()}');
      // In case of error, default to treating the user as new to ensure profile completion
      return true;
    }
  }

  /// Mark user as no longer new (completes onboarding)
  Future<void> markUserOnboardingComplete(String uid) async {
    try {
      _logger.i(_tag, 'Marking user $uid onboarding as complete');
      
      // Track onboarding completion start
      await _analytics.logEvent(
        name: 'onboarding_complete',
        parameters: {
          'user_id': uid,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      await _userService.markUserOnboardingComplete(uid);
      
      // Set analytics user property to indicate completed onboarding
      await _analytics.setUserProperty(
        name: 'onboarding_status', 
        value: 'completed'
      );
      
    } catch (e) {
      _logger.e(_tag, 'USER REPO ERROR: ${e.toString()}');
      
      // Track onboarding completion failure
      await _analytics.logEvent(
        name: 'onboarding_complete_error',
        parameters: {
          'user_id': uid,
          'error': e.toString(),
        },
      );
      
      rethrow;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      // Get current user ID before signing out
      final userId = currentUser?.uid;
      
      // Log sign out event in analytics
      await _analytics.logEvent(
        name: 'sign_out',
        parameters: {'user_id': userId ?? 'unknown'},
      );
      
      // Clear crashlytics data
      await _crashlytics.clearKeys();
      await _crashlytics.setUserIdentifier('');
      await _crashlytics.log('User signed out');
      
      // Call auth service signOut (this handles FCM token removal and Firebase signOut)
      await authService.signOut();

      // End user session and clear login state from local database
      final localDb = LocalDatabaseService.instance;
      if (userId != null) {
        await localDb.endUserSession(userId);
      }
      await localDb.clearAllUserData();
      
      _logger.i(_tag, 'User signed out successfully');
    } catch (e) {
      _logger.e(_tag, 'Error during sign out: ${e.toString()}');
      rethrow;
    }
  }

  /// Delete the current user account and all associated data
  Future<void> deleteUserAccount() async {
    String? uid;
    UserModel? user;
    
    try {
      user = currentUser;
      if (user == null) {
        throw AuthException(
          AuthErrorCodes.notLoggedIn,
          'No user is currently signed in.',
        );
      }
      
      _logger.i(_tag, 'Starting user account deletion process');
      
      // Get user ID before deleting
      uid = user.uid;
      _logger.d(_tag, 'User ID to delete: $uid');
      
      // Call auth service deleteUserAccount (this handles API call and Firebase user deletion)
      await authService.deleteUserAccount();
      
      // Clean up local database data for this user
      final localDb = LocalDatabaseService.instance;
      await localDb.deleteUser(uid);
      
      _logger.i(_tag, 'User account deletion completed successfully');
    } catch (e) {
      _logger.e(_tag, 'Failed to delete user account: ${e.toString()}');
      
      // Log deletion failure for analytics
      await _analytics.logEvent(
        name: 'account_deletion_failed',
        parameters: {
          'user_id': uid ?? 'unknown',
          'error': e.toString(),
        },
      );
      
      rethrow;
    }
  }

  // Track phone verification attempts to implement rate limiting
  final Map<String, List<DateTime>> _phoneVerificationAttempts = {};
  final Map<String, List<DateTime>> _otpVerificationAttempts = {};
  
  /// Check if a phone number is rate limited for verification attempts
  /// Returns true if rate limited, false if allowed to proceed
  /// Also returns the remaining timeout in seconds
  (bool isLimited, int timeoutRemaining) isPhoneNumberRateLimited(String phoneNumber) {
    // Normalize phone number by removing spaces and non-digits except +
    final normalizedNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    
    // Check if phone verification attempts are rate limited
    final attempts = _phoneVerificationAttempts[normalizedNumber] ?? [];
    final now = DateTime.now();
    
    // Initialize attempts list if it doesn't exist
    if (!_phoneVerificationAttempts.containsKey(normalizedNumber)) {
      _phoneVerificationAttempts[normalizedNumber] = [];
      return (false, 0); // First attempt, not rate limited
    }
    
    // Remove attempts older than 1 hour
    _phoneVerificationAttempts[normalizedNumber] = attempts.where((attempt) {
      return now.difference(attempt).inHours < 1;
    }).toList();
    
    final recentAttempts = _phoneVerificationAttempts[normalizedNumber]!.length;
    if (recentAttempts == 0) return (false, 0); // No attempts in last hour
    
    int timeoutSeconds;
    
    // Determine timeout based on frequency of attempts
    if (recentAttempts <= 2) {
      timeoutSeconds = 0;  // No timeout for first 2 attempts
    } else if (recentAttempts <= 5) {
      timeoutSeconds = 30; // 30 seconds timeout after 5 attempts
    } else if (recentAttempts <= 10) {
      timeoutSeconds = 60; // 1 minute timeout after 10 attempts
    } else if (recentAttempts <= 15) { 
      timeoutSeconds = 300; // 5 minutes timeout after 15 attempts
    } else {
      timeoutSeconds = 3600; // 1 hour timeout after more attempts (potential attack)
    }
    
    // Check if most recent attempt is within timeout period
    if (_phoneVerificationAttempts[normalizedNumber]!.isNotEmpty) {
      final lastAttempt = _phoneVerificationAttempts[normalizedNumber]!.last;
      final secondsSinceLastAttempt = now.difference(lastAttempt).inSeconds;
      
      if (secondsSinceLastAttempt < timeoutSeconds) {
        final timeoutRemaining = timeoutSeconds - secondsSinceLastAttempt;
        _logger.w(_tag, 'Phone verification rate limited: $recentAttempts attempts for $normalizedNumber, must wait $timeoutRemaining more seconds');
        return (true, timeoutRemaining);
      }
    }
    
    // Record this attempt
    _phoneVerificationAttempts[normalizedNumber]!.add(now);
    return (false, 0); // Not rate limited
  }
  
  /// Check if OTP verification for a phone number is rate limited
  /// Returns true if rate limited, false if allowed to proceed
  /// Also returns the remaining timeout in seconds  
  (bool isLimited, int timeoutRemaining) isOtpVerificationRateLimited(String phoneNumber) {
    // Normalize phone number by removing spaces and non-digits except +
    final normalizedNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    
    // Check if OTP verification attempts are rate limited
    final attempts = _otpVerificationAttempts[normalizedNumber] ?? [];
    final now = DateTime.now();
    
    // Initialize attempts list if it doesn't exist
    if (!_otpVerificationAttempts.containsKey(normalizedNumber)) {
      _otpVerificationAttempts[normalizedNumber] = [];
      return (false, 0); // First attempt, not rate limited
    }
    
    // Remove attempts older than 1 hour
    _otpVerificationAttempts[normalizedNumber] = attempts.where((attempt) {
      return now.difference(attempt).inHours < 1;
    }).toList();
    
    final recentAttempts = _otpVerificationAttempts[normalizedNumber]!.length;
    if (recentAttempts == 0) return (false, 0); // No attempts in last hour
    
    int timeoutSeconds;
    
    // OTP verification should have stricter rate limiting since it's more security-sensitive
    if (recentAttempts <= 2) {
      timeoutSeconds = 0;  // No timeout for first 2 attempts
    } else if (recentAttempts <= 5) {
      timeoutSeconds = 60; // 1 minute timeout after 5 attempts
    } else if (recentAttempts <= 8) {
      timeoutSeconds = 300; // 5 minutes timeout after 8 attempts
    } else {
      timeoutSeconds = 3600; // 1 hour timeout after more attempts (potential attack)
    }
    
    // Check if most recent attempt is within timeout period
    if (_otpVerificationAttempts[normalizedNumber]!.isNotEmpty) {
      final lastAttempt = _otpVerificationAttempts[normalizedNumber]!.last;
      final secondsSinceLastAttempt = now.difference(lastAttempt).inSeconds;
      
      if (secondsSinceLastAttempt < timeoutSeconds) {
        final timeoutRemaining = timeoutSeconds - secondsSinceLastAttempt;
        _logger.w(_tag, 'OTP verification rate limited: $recentAttempts attempts for $normalizedNumber, must wait $timeoutRemaining more seconds');
        return (true, timeoutRemaining);
      }
    }
    
    // Record this attempt
    _otpVerificationAttempts[normalizedNumber]!.add(now);
    return (false, 0); // Not rate limited
  }

  /// Validate a user credential for security-sensitive operations
  /// This method delegates to the auth service to perform credential validation
  Future<bool> validateCredential(dynamic credential) async {
    try {
      _logger.d(_tag, 'Validating user credential for security operation');
      
      // Delegate credential validation to the auth service
      final isValid = await authService.validateCredential(credential);
      
      _logger.i(_tag, 'Credential validation result: ${isValid ? 'valid' : 'invalid'}');
      
      // Log validation attempt in analytics
      await _analytics.logEvent(
        name: 'credential_validation_attempt',
        parameters: {
          'validation_result': isValid ? 'success' : 'failure',
        },
      );
      
      return isValid;
    } catch (e) {
      _logger.e(_tag, 'Credential validation failed: ${e.toString()}');
      
      // Log validation failure in analytics
      await _analytics.logEvent(
        name: 'credential_validation_error',
        parameters: {
          'error_type': e.runtimeType.toString(),
          'error_message': e.toString(),
        },
      );
      
      // Report to crashlytics for monitoring
      await _crashlytics.recordError(
        e,
        StackTrace.current,
        reason: 'Credential validation failed',
      );
      
      return false;
    }
  }



  /// Start monitoring Firebase user document changes for the current user
  /// This creates a real-time stream that updates local database when Firebase changes occur
  Future<void> startUserDocumentMonitoring() async {
    try {
      final user = currentUser;
      if (user == null) {
        _logger.w(_tag, 'Cannot start user document monitoring: No current user');
        return;
      }

      // Cancel any existing subscription
      await stopUserDocumentMonitoring();

      _logger.i(_tag, 'Starting Firebase user document monitoring for user: ${user.uid}');

      // Set up the stream subscription using UserService interface
      _userDocumentSubscription = _userService.getUserDataStream(user.uid).listen(
        (updatedUser) async {
          if (updatedUser != null) {
            _logger.d(_tag, 'Firebase user document changed, updating local database');
            
            // Update local database with the fresh data from Firebase
            final localDb = LocalDatabaseService.instance;
            await localDb.saveUser(updatedUser);
            
            _logger.i(_tag, 'Local database updated with Firebase changes for user: ${user.uid}');
          } else {
            _logger.w(_tag, 'Received null user data from Firebase stream - user may have been deleted');
          }
        },
        onError: (error) {
          _logger.e(_tag, 'Error in Firebase user document stream: ${error.toString()}');
          
          // Log the error for analytics
          _analytics.logEvent(
            name: 'user_stream_error',
            parameters: {
              'user_id': user.uid,
              'error': error.toString(),
            },
          );
        },
      );

      _logger.i(_tag, 'Firebase user document monitoring started successfully');
    } catch (e) {
      _logger.e(_tag, 'Failed to start user document monitoring: ${e.toString()}');
      rethrow;
    }
  }

  /// Stop monitoring Firebase user document changes
  Future<void> stopUserDocumentMonitoring() async {
    try {
      if (_userDocumentSubscription != null) {
        _logger.i(_tag, 'Stopping Firebase user document monitoring');
        await _userDocumentSubscription!.cancel();
        _userDocumentSubscription = null;
        _logger.i(_tag, 'Firebase user document monitoring stopped');
      }
    } catch (e) {
      _logger.e(_tag, 'Error stopping user document monitoring: ${e.toString()}');
    }
  }

  /// Get a reactive stream of user changes that combines Firebase and local database
  /// This stream automatically updates local database when Firebase changes occur
  Stream<UserModel?> getUserReactiveStream() {
    try {
      final user = currentUser;
      if (user == null) {
        _logger.w(_tag, 'Cannot create reactive stream: No current user');
        return Stream.value(null);
      }

      _logger.d(_tag, 'Creating reactive user stream for user: ${user.uid}');

      // Create a stream that monitors Firebase changes and updates local DB
      return _userService.getUserDataStream(user.uid).asyncMap((firebaseUser) async {
        if (firebaseUser != null) {
          // Update local database with fresh Firebase data
          final localDb = LocalDatabaseService.instance;
          await localDb.saveUser(firebaseUser);
          
          _logger.d(_tag, 'Reactive stream: Updated local database with Firebase data');
          
          // Retrieve the locally cached user data (with file:// URLs) instead of returning Firebase data
          final cachedUser = await localDb.getCurrentUser();
          if (cachedUser != null) {
            _logger.d(_tag, 'Reactive stream: Returning cached user with local photo paths');
            return cachedUser;
          } else {
            _logger.w(_tag, 'Reactive stream: Failed to get cached user, falling back to Firebase data');
            return firebaseUser;
          }
        } else {
          _logger.w(_tag, 'Reactive stream: Received null user from Firebase');
          return null;
        }
      }).handleError((error) {
        _logger.e(_tag, 'Error in reactive user stream: ${error.toString()}');
        
        // Log the error for analytics
        _analytics.logEvent(
          name: 'reactive_stream_error',
          parameters: {
            'user_id': user.uid,
            'error': error.toString(),
          },
        );
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to create reactive user stream: ${e.toString()}');
      return Stream.error(e);
    }
  }

  /// Dispose of resources and clean up subscriptions
  Future<void> dispose() async {
    try {
      _logger.d(_tag, 'Disposing UserRepository resources');
      await stopUserDocumentMonitoring();
      _logger.d(_tag, 'UserRepository disposed successfully');
    } catch (e) {
      _logger.e(_tag, 'Error disposing UserRepository: ${e.toString()}');
    }
  }

  /// Force refresh user data from Firebase and update local cache
  /// This is useful when app resumes or user manually refreshes
  /// Returns true if refresh was successful
  Future<bool> forceRefreshUserData() async {
    try {
      final currentUserAuth = authService.currentUser;
      if (currentUserAuth == null) {
        _logger.d(_tag, 'No current user, no refresh needed');
        return false;
      }

      _logger.i(_tag, 'Force refreshing user data for user: ${currentUserAuth.uid}');

      // Get fresh user data from Firebase/Firestore
      final freshUserData = await _userService.getUserData(currentUserAuth.uid);
      if (freshUserData == null) {
        _logger.w(_tag, 'No user data found in Firebase for refresh');
        return false;
      }

      // Update local database with fresh data
      final localDb = LocalDatabaseService.instance;
      await localDb.saveUser(freshUserData);
      
      // Update user cache refresh timestamp
      await _updateUserCacheRefreshTimestamp();

      // Track successful refresh
      await _analytics.logEvent(
        name: 'user_cache_force_refresh',
        parameters: {
          'success': true,
          'user_id_hash': currentUserAuth.uid.hashCode.toString(),
        },
      );

      _logger.i(_tag, 'Successfully force refreshed user data');
      return true;

    } catch (e) {
      _logger.e(_tag, 'Failed to force refresh user data: ${e.toString()}');

      // Track failed refresh
      await _analytics.logEvent(
        name: 'user_cache_force_refresh',
        parameters: {
          'success': false,
          'error': e.toString(),
        },
      );

      // Log to crashlytics for debugging
      await _crashlytics.recordError(
        e,
        null,
        reason: 'Failed to force refresh user cache',
        fatal: false,
      );

      return false;
    }
  }

  /// Check if user cache is stale and needs refresh
  /// Returns true if cache is older than the specified duration
  Future<bool> isUserCacheStale({Duration maxAge = const Duration(minutes: 5)}) async {
    try {
      final currentUserAuth = authService.currentUser;
      if (currentUserAuth == null) {
        _logger.d(_tag, 'No current user, cache is not stale');
        return false;
      }

      // Check if we have any cached user data
      final localDb = LocalDatabaseService.instance;
      final cachedUser = await localDb.getCurrentUser();

      // If no cached data exists, consider it stale
      if (cachedUser == null) {
        _logger.d(_tag, 'No cached user data found - cache is stale');
        return true;
      }

      // Check cache timestamp
      final lastRefreshKey = 'user_cache_last_refresh_${currentUserAuth.uid}';
      final lastRefreshString = await localDb.getSetting(lastRefreshKey);
      
      if (lastRefreshString == null) {
        _logger.d(_tag, 'No user cache timestamp found - cache is stale');
        return true;
      }

      final lastRefresh = DateTime.fromMillisecondsSinceEpoch(int.parse(lastRefreshString));
      final age = DateTime.now().difference(lastRefresh);
      final isStale = age > maxAge;

      _logger.d(_tag, 'User cache age: ${age.inMinutes} minutes, max age: ${maxAge.inMinutes} minutes, is stale: $isStale');
      return isStale;

    } catch (e) {
      _logger.e(_tag, 'Error checking user cache staleness: ${e.toString()}');
      return true; // Consider stale on error to be safe
    }
  }

  /// Update the user cache refresh timestamp
  Future<void> _updateUserCacheRefreshTimestamp() async {
    try {
      final currentUserAuth = authService.currentUser;
      if (currentUserAuth == null) return;
      
      final timestampKey = 'user_cache_last_refresh_${currentUserAuth.uid}';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      final localDb = LocalDatabaseService.instance;
      await localDb.setSetting(timestampKey, timestamp);
      _logger.d(_tag, 'Updated user cache refresh timestamp');
    } catch (e) {
      _logger.w(_tag, 'Failed to update user cache refresh timestamp: ${e.toString()}');
    }
  }

  /// Clear user cache for current user
  /// Useful when user signs out or wants to refresh data
  Future<void> clearCurrentUserCache() async {
    try {
      final currentUserAuth = authService.currentUser;
      if (currentUserAuth == null) return;

      final localDb = LocalDatabaseService.instance;
      
      // Clear user data from local database
      await localDb.deleteUser(currentUserAuth.uid);
      
      // Clear cache timestamp
      final timestampKey = 'user_cache_last_refresh_${currentUserAuth.uid}';
      await localDb.removeSetting(timestampKey);
      
      _logger.i(_tag, 'Cleared user cache for current user: ${currentUserAuth.uid}');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear user cache: ${e.toString()}');
      rethrow;
    }
  }
}