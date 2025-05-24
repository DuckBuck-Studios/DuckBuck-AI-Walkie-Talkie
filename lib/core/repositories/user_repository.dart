import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth/auth_service_interface.dart';
import '../models/user_model.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/notifications/notifications_service.dart';
import '../services/service_locator.dart';
import '../exceptions/auth_exceptions.dart';
import '../services/logger/logger_service.dart';
import '../services/api/api_service.dart';
import '../services/user/user_service_interface.dart';

/// Repository to handle user data operations
class UserRepository {
  final AuthServiceInterface authService;
  final UserServiceInterface _userService;
  final LoggerService _logger = LoggerService();
  final FirebaseAnalyticsService _analytics;
  final FirebaseCrashlyticsService _crashlytics;
  final ApiService _apiService;
  
  static const String _tag = 'USER_REPO'; // Tag for logs

  /// Creates a new UserRepository
  UserRepository({
    required this.authService, 
    UserServiceInterface? userService,
    FirebaseAnalyticsService? analytics,
    FirebaseCrashlyticsService? crashlytics,
    ApiService? apiService,
  }) : _userService = userService ?? serviceLocator<UserServiceInterface>(),
       _analytics = analytics ?? serviceLocator<FirebaseAnalyticsService>(),
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>(),
       _apiService = apiService ?? serviceLocator<ApiService>();

  /// Get the current authenticated user
  UserModel? get currentUser {
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) return null;
    return UserModel.fromFirebaseUser(firebaseUser);
  }
  
  /// Get the current user with enhanced caching for better performance
  Future<UserModel?> getCurrentUserWithCache() async {
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) return null;
    
    // Track cache hit/miss for analytics
    bool cacheHit = false;
    
    // Check if we have valid cached user data
    final prefService = PreferencesService.instance;
    if (prefService.isCachedUserDataValid()) {
      final cachedData = prefService.getCachedUserData();
      if (cachedData != null && cachedData['uid'] == firebaseUser.uid) {
        // Check if cache is too old (more than 1 hour)
        final lastUpdated = cachedData['_last_updated'] as int?;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (lastUpdated != null && now - lastUpdated < 3600000) { // 1 hour in ms
          _logger.d(_tag, 'Using cached user data from preferences');
          cacheHit = true;
          return UserModel.fromMap(cachedData);
        }
      }
    }
    
    // If no valid cached data, create from Firebase user
    final user = UserModel.fromFirebaseUser(firebaseUser);
    
    // Cache the user data with timestamp
    try {
      final userMap = user.toMap();
      userMap['_last_updated'] = DateTime.now().millisecondsSinceEpoch;
      await prefService.cacheUserData(userMap);
      _logger.d(_tag, 'User data refreshed and cached');
      
      // Log cache performance for analytics
      _analytics.logEvent(
        name: 'user_cache_performance',
        parameters: {'cache_hit': cacheHit},
      );
    } catch (e) {
      _logger.w(_tag, 'Failed to cache user data: ${e.toString()}');
    }
    
    return user;
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
        // Capture user data for background email sending
        final userEmail = user.email ?? '';
        final userName = user.displayName ?? 'User';
        final userMetadata = user.metadata;
        final loginTime = DateTime.now().toString();
        
        // Fire and forget email sending in the background (non-blocking)
        Future(() {
          _apiService.sendLoginNotificationEmail(
            email: userEmail,
            username: userName,
            loginTime: loginTime,
            metadata: userMetadata,
          ).then((success) {
            _logger.i(_tag, success ? 'Login notification sent successfully' : 'Failed to send login notification');
          });
        });
      } else {
        _logger.i(_tag, 'Skipping welcome email for new Google user - will send after profile completion');
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
        // Capture user data for background email sending
        final userEmail = user.email ?? '';
        final userName = user.displayName ?? 'User';
        final userMetadata = user.metadata;
        final loginTime = DateTime.now().toString();
        
        // Fire and forget email sending in the background (non-blocking)
        Future(() {
          _apiService.sendLoginNotificationEmail(
            email: userEmail,
            username: userName,
            loginTime: loginTime,
            metadata: userMetadata,
          ).then((success) {
            _logger.i(_tag, success ? 'Login notification sent successfully' : 'Failed to send login notification');
          });
        });
      } else {
        _logger.i(_tag, 'Skipping welcome email for new Apple user - will send after profile completion');
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

  /// Verify phone OTP code and sign in
  Future<(UserModel, bool)> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
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
    PhoneAuthCredential credential,
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

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      // Get current user ID before signing out
      final userId = currentUser?.uid;
      
      if (userId != null) {
        try {
          // Remove FCM token through notifications service
          _logger.i(_tag, 'Removing FCM token for user: $userId');
          final notificationsService = serviceLocator<NotificationsService>();
          await notificationsService.removeToken(userId);
          
          // Token verification now happens in the notifications service
        } catch (e) {
          // Log but continue with sign out
          _logger.w(_tag, 'Error removing FCM token during sign out: ${e.toString()}');
        }
      }

      // Clear analytics user ID
      await _analytics.clearUserId();
      
      // Clear crashlytics data
      await _crashlytics.clearKeys();
      await _crashlytics.setUserIdentifier('');
      await _crashlytics.log('User signed out');
      
      // Sign out from Firebase Auth
      await authService.signOut();

      // Clear login state and reset all auth-related preferences
      await PreferencesService.instance.setLoggedIn(false);
      await PreferencesService.instance.clearAll();
      
      _logger.i(_tag, 'User signed out successfully');
    } catch (e) {
      _logger.e(_tag, 'Error during sign out: ${e.toString()}');
      rethrow;
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

  // Password reset functionality has been removed

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      return await _userService.getUserData(uid);
    } catch (e) {
      _logger.e(_tag, 'Failed to get user data: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Get user data with selective field loading for better performance
  /// This fetches only the specified fields from Firestore
  Future<UserModel?> getUserWithSelectiveData(String uid, List<String> fields) async {
    try {
      // Check if we have valid cached data first
      final prefService = PreferencesService.instance;
      if (prefService.isCachedUserDataValid()) {
        final cachedData = prefService.getCachedUserData();
        if (cachedData != null && cachedData['uid'] == uid) {
          _logger.d(_tag, 'Using cached user data');
          return UserModel.fromMap(cachedData);
        }
      }
      
      // If no valid cached data, fetch from service
      final user = await _userService.getUserWithSelectiveData(uid, fields);
      
      if (user != null) {
        // Cache this data for future use
        prefService.cacheUserData(user.toMap());
      }
      
      return user;
    } catch (e) {
      _logger.e(_tag, 'Failed to get selective user data', e);
      rethrow;
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
      // First retrieve the current user data to get the fcmTokenData
      final currentData = await _userService.getUserData(user.uid);
      
      // Create an updated user with preserved FCM data
      final updatedUser = user.copyWith(
        fcmTokenData: currentData?.fcmTokenData,
      );
      
      await _userService.updateUserData(updatedUser);
      
      final authMethod = user.metadata?['authMethod'] as String? ?? 'unknown';
      _logger.i(_tag, 'Updated user data with auth method: $authMethod');
    } catch (e) {
      _logger.e(_tag, 'Failed to update user data: ${e.toString()}');
      rethrow;
    }
  }
  
  // Removed _updateUserDataWithoutOverridingFCM method as its logic is now in _updateUserData

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
}
