import 'dart:io';
import '../../models/user_model.dart';
import '../firebase/firebase_database_service.dart';
import '../firebase/firebase_storage_service.dart';
import 'user_service_interface.dart';
import '../logger/logger_service.dart';
import '../firebase/firebase_analytics_service.dart';
import '../service_locator.dart';
import '../../exceptions/auth_exceptions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Firebase implementation of the UserService interface
class UserService implements UserServiceInterface {
  final FirebaseDatabaseService _databaseService;
  final LoggerService _logger;
  final FirebaseAnalyticsService _analytics;
  
  static const String _tag = 'USER_SERVICE';
  static const String _userCollection = 'users';

  /// Creates a new UserService
  UserService({
    FirebaseDatabaseService? databaseService,
    LoggerService? logger,
    FirebaseAnalyticsService? analytics,
  }) : _databaseService = databaseService ?? serviceLocator<FirebaseDatabaseService>(),
       _analytics = analytics ?? serviceLocator<FirebaseAnalyticsService>(),
       _logger = logger ?? LoggerService();
  
  @override
  Future<UserModel?> getUserData(String uid) async {
    try {
      final userData = await _databaseService.getDocument(
        collection: _userCollection,
        documentId: uid,
      );
      
      if (userData == null) return null;
      
      return UserModel.fromMap(userData);
    } catch (e) {
      _logger.e(_tag, 'Failed to get user data: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to get user data',
        e
      );
    }
  }
  
  @override
  Future<UserModel?> getUserWithSelectiveData(String uid, List<String> fields) async {
    try {
      // For selective data, we're still using regular getDocument
      // In a more optimized setup, we'd have a method in Firebase Database Service
      // that supports field selection
      final userData = await _databaseService.getDocument(
        collection: _userCollection,
        documentId: uid,
      );
      
      if (userData == null) return null;
      
      return UserModel.fromMap(userData);
    } catch (e) {
      _logger.e(_tag, 'Failed to get selective user data', e);
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to get user data',
        e
      );
    }
  }
  
  @override
  Future<void> createUserData(UserModel user) async {
    try {
      // Extract the provider ID from user metadata if available
      final providerId = user.metadata?['providerId'] as String? ?? 'unknown';
      final authMethod = user.metadata?['authMethod'] as String? ?? 'unknown';
      
      // Convert user to map with only relevant fields based on auth method
      final userMap = user.toMap();
      
      // For new users, ensure they get the default 1 hour of AI agent time
      // Override the agentRemainingTime from fromFirebaseUser() which is 0
      userMap['agentRemainingTime'] = 3600; // 1 hour default for new users
      
      // Log which auth method is being used
      _logger.i(_tag, 'Creating new user with auth method: $authMethod (agentRemainingTime: 1 hour)');
      
      await _databaseService.setDocument(
        collection: _userCollection,
        documentId: user.uid,
        data: {
          ...userMap,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isNewUser': true, // Explicitly mark as a new user 
        }
      );
      
      _logger.i(_tag, 'Created new user with auth provider: $providerId');
    } catch (e) {
      _logger.e(_tag, 'Failed to create user data: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to create user data',
        e
      );
    }
  }
  
  @override
  Future<void> updateUserData(UserModel user) async {
    try {
      // Get user map with only relevant fields based on auth method in metadata
      final userMap = user.toMap();
      
      // CRITICAL: Remove agentRemainingTime to prevent overwriting existing premium time
      // This preserves the user's actual remaining AI agent time during login updates
      userMap.remove('agentRemainingTime');
      
      // Keep FCM token data - no longer exclude it
      // userMap.remove('fcmTokenData'); // REMOVED: Now we want to save FCM token data
      
      await _databaseService.setDocument(
        collection: _userCollection,
        documentId: user.uid,
        data: {
          ...userMap,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoggedIn': FieldValue.serverTimestamp(),
        },
        merge: true
      );
      
      final authMethod = user.metadata?['authMethod'] as String? ?? 'unknown';
      _logger.i(_tag, 'Updated user data with auth method: $authMethod (agentRemainingTime preserved)');
    } catch (e) {
      _logger.e(_tag, 'Failed to update user data: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to update user data',
        e
      );
    }
  }
  
  @override
  Future<bool> createOrUpdateUserData(UserModel user) async {
    try {
      _logger.d(
        _tag, 'Checking if user ${user.uid} exists in Firestore',
      );
      
      // Check if user exists
      final userData = await _databaseService.getDocument(
        collection: _userCollection,
        documentId: user.uid,
      );
      
      if (userData != null) {
        _logger.d(
          _tag, 'User ${user.uid} EXISTS in Firestore, updating data',
        );
        // User exists, update data
        await updateUserData(user);
        return false; // Existing user
      } else {
        _logger.d(
          _tag, 'User ${user.uid} DOES NOT EXIST in Firestore, creating new user',
        );
        // User doesn't exist, create new
        await createUserData(user);
        return true; // New user
      }
    } catch (e) {
      _logger.e(_tag, 'CHECKING USER EXISTENCE ERROR: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to create or update user data',
        e
      );
    }
  }
  
  @override
  Future<bool> checkIfUserIsNew(String uid) async {
    try {
      _logger.d(_tag, 'Checking if user $uid exists in Firestore');
      
      // Get user document
      final userData = await _databaseService.getDocument(
        collection: _userCollection,
        documentId: uid,
      );
      
      // If document doesn't exist, user is definitely new
      if (userData == null) {
        _logger.i(_tag, 'User document does NOT exist in Firestore - user is new');
        return true;
      }
      
      // If document exists but has isNewUser flag set to true, also consider as new
      final isMarkedAsNew = userData['isNewUser'] == true;
      
      _logger.d(_tag, 'User document exists, isNewUser flag: $isMarkedAsNew');
      return isMarkedAsNew;
    } catch (e) {
      _logger.e(_tag, 'USER SERVICE ERROR: ${e.toString()}');
      // In case of error, default to treating the user as new to ensure profile completion
      return true;
    }
  }
  
  @override
  Future<void> markUserOnboardingComplete(String uid) async {
    try {
      _logger.i(_tag, 'Marking user $uid onboarding as complete');
      
      await _databaseService.setDocument(
        collection: _userCollection,
        documentId: uid,
        data: {
          'isNewUser': FieldValue.delete(), // Remove the isNewUser field entirely
          'onboardingCompletedAt': FieldValue.serverTimestamp(),
        },
        merge: true
      );
      
      _logger.i(_tag, 'User onboarding marked as complete for $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to mark user onboarding as complete: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to mark user onboarding as complete',
        e
      );
    }
  }
  
  @override
  Stream<UserModel?> getUserDataStream(String uid) {
    try {
      _logger.d(_tag, 'Creating user data stream for uid: $uid');
      
      return _databaseService.documentStream(
        collection: _userCollection,
        documentId: uid,
      ).map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          _logger.d(_tag, 'User document does not exist in stream for uid: $uid');
          return null;
        }
        
        try {
          final userData = snapshot.data()!;
          _logger.d(_tag, 'User data received in stream for uid: $uid');
          return UserModel.fromMap(userData);
        } catch (e) {
          _logger.e(_tag, 'Failed to parse user data in stream: ${e.toString()}');
          return null;
        }
      }).handleError((error) {
        _logger.e(_tag, 'Error in user data stream: ${error.toString()}');
        throw AuthException(
          AuthErrorCodes.databaseError,
          'Failed to get user data stream',
          error
        );
      });
    } catch (e) {
      _logger.e(_tag, 'Failed to create user data stream: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to create user data stream',
        e
      );
    }
  }
  
  @override
  Future<void> deleteUserAccount(String uid) async {
    try {
      _logger.i(_tag, 'Marking user $uid as deleted in Firestore');
      
      await _databaseService.setDocument(
        collection: _userCollection,
        documentId: uid,
        data: {
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        merge: true
      );
      
      _logger.i(_tag, 'User $uid successfully marked as deleted');
    } catch (e) {
      _logger.e(_tag, 'Failed to mark user as deleted: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to mark user as deleted',
        e
      );
    }
  }

  @override
  Future<void> restoreDeletedAccount(String uid) async {
    try {
      _logger.i(_tag, 'Restoring deleted account for user: $uid');
      
      // Completely restore the account by setting deleted to false 
      // and removing all deletion-related timestamps
      await _databaseService.setDocument(
        collection: _userCollection,
        documentId: uid,
        data: {
          'deleted': false,
          'deletedAt': FieldValue.delete(), // Remove deletion timestamp completely
          'restoredAt': FieldValue.delete(), // Remove any previous restoration timestamp
          'updatedAt': FieldValue.serverTimestamp(), // Update the last modified time
        },
        merge: true
      );
      
      _logger.i(_tag, 'User $uid successfully restored from deleted state with timestamps removed');
    } catch (e) {
      _logger.e(_tag, 'Failed to restore deleted account: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to restore deleted account',
        e
      );
    }
  }

  @override
  Future<void> removeFcmToken(String uid) async {
    try {
      _logger.i(_tag, 'Removing FCM token for user: $uid');
      
      // Completely remove the FCM token data field from the user document
      await _databaseService.setDocument(
        collection: _userCollection,
        documentId: uid,
        data: {
          'fcmTokenData': FieldValue.delete(), // Completely remove the field
          'updatedAt': FieldValue.serverTimestamp(),
        },
        merge: true
      );
      
      _logger.i(_tag, 'FCM token successfully removed for user: $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to remove FCM token: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to remove FCM token',
        e
      );
    }
  }

  @override
  Future<void> generateAndSaveFcmToken(String uid) async {
    try {
      _logger.i(_tag, 'Generating and saving FCM token for user: $uid');
      
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      
      if (token != null) {
        _logger.i(_tag, 'FCM token generated successfully: ${token.substring(0, 20)}...');
        
        // Create FCM token data structure without platform field
        final fcmTokenData = {
          'token': token,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Update user document with FCM token data
        await _databaseService.setDocument(
          collection: _userCollection,
          documentId: uid,
          data: {
            'fcmTokenData': fcmTokenData,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          merge: true
        );
        
        _logger.i(_tag, 'FCM token saved to Firestore for user: $uid');
      } else {
        _logger.w(_tag, 'Failed to generate FCM token for user: $uid');
      }
    } catch (e) {
      _logger.e(_tag, 'Error generating and saving FCM token: ${e.toString()}');
      throw AuthException(
        AuthErrorCodes.databaseError,
        'Failed to generate and save FCM token',
        e
      );
    }
  }

  @override
  Future<String> uploadProfilePhoto(String uid, File imageFile) async {
    _logger.i(_tag, 'Uploading profile photo for user: $uid');
    
    try {
      // Get Firebase storage service to upload the image
      final storageService = serviceLocator<FirebaseStorageService>();
      final photoURL = await storageService.uploadProfileImage(
        userId: uid,
        imageFile: imageFile,
      );
      
      _logger.i(_tag, 'Profile photo uploaded successfully: $photoURL');
      
      // Log successful photo upload
      await _analytics.logEvent(
        name: 'profile_photo_upload_success',
        parameters: {
          'user_id': uid,
          'photo_url_length': photoURL.length,
        },
      );
      
      return photoURL;
    } catch (e) {
      _logger.e(_tag, 'Failed to upload profile photo for user $uid: $e');
      
      // Log photo upload failure
      await _analytics.logEvent(
        name: 'profile_photo_upload_failed',
        parameters: {
          'user_id': uid,
          'error': e.toString(),
        },
      );
      
      rethrow;
    }
  }
}