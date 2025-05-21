import '../../models/user_model.dart';
import '../firebase/firebase_database_service.dart';
import 'user_service_interface.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';
import '../../exceptions/auth_exceptions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase implementation of the UserService interface
class FirebaseUserService implements UserServiceInterface {
  final FirebaseDatabaseService _databaseService;
  final LoggerService _logger;
  
  static const String _tag = 'USER_SERVICE';
  static const String _userCollection = 'users';

  /// Creates a new FirebaseUserService
  FirebaseUserService({
    FirebaseDatabaseService? databaseService,
    LoggerService? logger,
  }) : _databaseService = databaseService ?? serviceLocator<FirebaseDatabaseService>(),
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
      
      // Log which auth method is being used
      _logger.i(_tag, 'Creating new user with auth method: $authMethod');
      
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
      
      // Then exclude fcmTokenData to prevent overwriting it
      userMap.remove('fcmTokenData'); // Don't overwrite FCM token data
      
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
      _logger.i(_tag, 'Updated user data with auth method: $authMethod');
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
}
