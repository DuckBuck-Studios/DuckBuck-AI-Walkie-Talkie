import 'dart:io';
import '../../models/user_model.dart';

/// Interface for user data service operations
abstract class UserServiceInterface {
  /// Get user data from database
  Future<UserModel?> getUserData(String uid);
  
  /// Get user data with selective fields only
  Future<UserModel?> getUserWithSelectiveData(String uid, List<String> fields);
  
  /// Create a new user in the database
  Future<void> createUserData(UserModel user);
  
  /// Update user data in the database
  Future<void> updateUserData(UserModel user);
  
  /// Check if a user exists and create if not
  /// Returns true if this was a new user
  Future<bool> createOrUpdateUserData(UserModel user);
  
  /// Check if a user is marked as new
  Future<bool> checkIfUserIsNew(String uid);
  
  /// Mark user's onboarding as complete
  Future<void> markUserOnboardingComplete(String uid);
  
  /// Get a stream of user document changes
  Stream<UserModel?> getUserDataStream(String uid);
  
  /// Mark user account as deleted
  Future<void> deleteUserAccount(String uid);
  
  /// Restore a deleted user account
  Future<void> restoreDeletedAccount(String uid);
  
  /// Remove FCM token for user (used during sign out)
  Future<void> removeFcmToken(String uid);
  
  /// Generate and save FCM token for user during sign-in
  Future<void> generateAndSaveFcmToken(String uid);
  
  /// Upload user profile photo and return the download URL
  Future<String> uploadProfilePhoto(String uid, File imageFile);
  
  // AI Agent Time Management Methods (Premium Feature)
  /// Get user's current remaining AI agent time from Firebase
  /// This is a protected premium feature - only available for paying users
  Future<int> getUserAgentRemainingTime(String uid);
  
  /// Update user's remaining AI agent time in Firebase
  /// This is a protected premium feature - only available for paying users
  Future<void> updateUserAgentTime({
    required String uid,
    required int newRemainingTimeSeconds,
  });
  
  /// Decrease user's remaining AI agent time by specified amount
  /// This is a protected premium feature - only available for paying users
  Future<int> decreaseUserAgentTime({
    required String uid,
    required int timeUsedSeconds,
  });
  
  /// Increase user's remaining AI agent time by specified amount
  /// This is a protected premium feature - only available for paying users
  Future<int> increaseUserAgentTime({
    required String uid,
    required int additionalTimeSeconds,
  });
  
  /// Reset user's AI agent time to default (1 hour free for new users)
  /// This is a protected premium feature - only available for paying users
  Future<void> resetUserAgentTime(String uid);
  
  /// Check if user has remaining AI agent time
  /// This is a protected premium feature - only available for paying users
  Future<bool> hasUserAgentTime(String uid);
}
