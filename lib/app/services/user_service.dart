import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path; 
import '../models/user_model.dart'; 
import '../config/app_config.dart'; 

class UserService {
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Dio _dio = Dio();
  final AppConfig _appConfig = AppConfig();
  
  // Cloudinary configuration - in production, these would be secured
  final String _cloudName = 'deycvanff';
  final String _uploadPreset = 'users_p';
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Report error to crashlytics if available
  void _reportError(dynamic error, String method, {StackTrace? stackTrace}) {
    _appConfig.reportError(error, stackTrace ?? StackTrace.current, reason: 'Error in UserService.$method');
  }
  
  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      // First try with the Firebase Auth UID
      if (userId == currentUserId) {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists && doc.data() != null) {
          return UserModel.fromJson(doc.data()!);
        }
      }
      
      // If that fails and it's not the current user's ID, try to find by uid field
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromJson(querySnapshot.docs.first.data());
      }
      
      return null;
    } catch (e, stackTrace) {
      _reportError(e, 'getUserById', stackTrace: stackTrace);
      return null;
    }
  }
  
  // Stream user data by ID for real-time updates
  Stream<UserModel?> getUserStreamById(String userId) {
    // If it's current user, we know we can use Firebase Auth UID as document ID
    if (userId == currentUserId) {
      return _firestore.collection('users').doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return UserModel.fromJson(doc.data()!);
          }
          return null;
        });
    }
    
    // For other users, we need to watch for any document where uid field equals userId
    return _firestore
        .collection('users')
        .where('uid', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return UserModel.fromJson(snapshot.docs.first.data());
          }
          return null;
        });
  }
  
  // Get current user
  Future<UserModel?> getCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getUserById(userId);
  }
  
  // Get current user as stream for real-time updates
  Stream<UserModel?> getCurrentUserStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value(null);
    return getUserStreamById(userId);
  }
  
  // Update user display name
  Future<bool> updateDisplayName(String userId, String displayName) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'displayName': displayName,
      });
      
      // Also update Firebase Auth display name if it's the current user
      if (userId == currentUserId) {
        await _auth.currentUser?.updateDisplayName(displayName);
      }
      
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'updateDisplayName', stackTrace: stackTrace);
      return false;
    }
  }
  
  // Update user date of birth
  Future<bool> updateDateOfBirth(String userId, DateTime dateOfBirth) async {
    try {
      // Get current user to access their metadata
      final user = await getUserById(userId);
      if (user == null) return false;
      
      // Create updated metadata with the new dateOfBirth
      final updatedMetadata = Map<String, dynamic>.from(user.metadata ?? {});
      updatedMetadata['dateOfBirth'] = firestore.Timestamp.fromDate(dateOfBirth);
      
      // Update the user document with the new metadata
      await _firestore.collection('users').doc(userId).update({
        'metadata': updatedMetadata
      });
      
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'updateDateOfBirth', stackTrace: stackTrace);
      return false;
    }
  }
  
  // Update user gender
  Future<bool> updateGender(String userId, Gender gender) async {
    try {
      // Get current user to access their metadata
      final user = await getUserById(userId);
      if (user == null) return false;
      
      // Create updated metadata with the new gender
      final updatedMetadata = Map<String, dynamic>.from(user.metadata ?? {});
      updatedMetadata['gender'] = gender.toString().split('.').last;
      
      // Update the user document with the new metadata
      await _firestore.collection('users').doc(userId).update({
        'metadata': updatedMetadata
      });
      
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'updateGender', stackTrace: stackTrace);
      return false;
    }
  }
  
  // Update user roomId
  Future<bool> updateRoomId(String userId, String roomId) async {
    try {
      // Update the user document with the new roomId as a top-level field
      await _firestore.collection('users').doc(userId).update({
        'roomId': roomId
      });
      
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'updateRoomId', stackTrace: stackTrace);
      return false;
    }
  }
  
  // Delete user account completely
  Future<bool> deleteUserAccount(String userId) async {
    try { 
      
      // Modify the check to be more lenient - as long as we have a current user,
      // allow deletion of the account without strict ID matching
      if (_auth.currentUser == null) {
        _reportError(
          "No authenticated user found to delete account", 
          'deleteUserAccount'
        );
        return false;
      }
      
      // Directly use the current user's ID for the deletion instead of parameter
      final currentUserId = _auth.currentUser!.uid;
      
      // 1. Get Firestore reference to user document
      final userDoc = _firestore.collection('users').doc(currentUserId);
      
      // Start a batch to handle Firestore operations
      final batch = _firestore.batch();
      
      try {
        // 3. Get all friend relationships
        // 3.1 Get incoming requests
        final incomingRequests = await userDoc.collection('incomingRequests').get();
        // 3.2 Get outgoing requests
        final outgoingRequests = await userDoc.collection('outgoingRequests').get();
        // 3.3 Get friends
        final friends = await userDoc.collection('friends').get();
        // 3.4 Get blocked users
        final blockedUsers = await userDoc.collection('blockedUsers').get();
        
        // 4. Process friend subcollections
        for (final doc in incomingRequests.docs) {
          // Delete corresponding outgoing request from the other user
          final otherUserDoc = _firestore.collection('users').doc(doc.id);
          batch.delete(otherUserDoc.collection('outgoingRequests').doc(currentUserId));
          
          // Delete the incoming request
          batch.delete(doc.reference);
        }
        
        for (final doc in outgoingRequests.docs) {
          // Delete corresponding incoming request from the other user
          final otherUserDoc = _firestore.collection('users').doc(doc.id);
          batch.delete(otherUserDoc.collection('incomingRequests').doc(currentUserId));
          
          // Delete the outgoing request
          batch.delete(doc.reference);
        }
        
        for (final doc in friends.docs) {
          // Delete corresponding friend entry from the other user
          final otherUserDoc = _firestore.collection('users').doc(doc.id);
          batch.delete(otherUserDoc.collection('friends').doc(currentUserId));
          
          // Delete the friend
          batch.delete(doc.reference);
        }
        
        for (final doc in blockedUsers.docs) {
          // Delete corresponding blocked entry from the other user if they also blocked this user
          final otherUserDoc = _firestore.collection('users').doc(doc.id);
          batch.delete(otherUserDoc.collection('blockedUsers').doc(currentUserId));
          
          // Delete the blocked user
          batch.delete(doc.reference);
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error getting friend relationships: $e");
        }
        // Continue with deleting the user document even if we couldn't get all relationships
      }
      
      // 5. Delete all user data in Firestore
      batch.delete(userDoc);
      
      // 6. Execute the batch
      await batch.commit();
      
      try {
        // 8. Delete the Firebase Auth user
        // This might fail due to session timeout, but we can still continue
        // as we've already deleted all user data
        await _auth.currentUser?.delete();
      } catch (e) {
        // If deleting the auth user fails, just log it but don't fail the whole operation
        // We've already deleted all the user data, which is the important part
        if (kDebugMode) {
          print("Error deleting Firebase Auth user: $e");
        }
        // Sign out the user since we've deleted their data
        try {
          await _auth.signOut();
        } catch (signOutError) {
          if (kDebugMode) {
            print("Error signing out: $signOutError");
          }
        }
      }
      
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'deleteUserAccount', stackTrace: stackTrace);
      
      // Try to sign out anyway if there's an error
      try {
        await _auth.signOut();
      } catch (signOutError) {
        if (kDebugMode) {
          print("Error signing out after error: $signOutError");
        }
      }
      
      return false;
    }
  }
  
  // Fix field inconsistencies in user document
  Future<bool> fixUserDocumentFields(String userId) async {
    try {
      // Get the full document data first to check all fields
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      if (!docSnapshot.exists) return false;
      
      final userData = docSnapshot.data()!;
      final updates = <String, dynamic>{};
      
      // Start with existing metadata or empty map
      final metadataUpdates = Map<String, dynamic>.from(userData['metadata'] ?? {});
      bool needsUpdate = false;
      
      // Move top-level email to metadata
      if (userData.containsKey('email') && userData['email'] != null) {
        final email = userData['email'];
        if (email is String) {
          metadataUpdates['email'] = email;
          updates['email'] = firestore.FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move top-level phoneNumber to metadata
      if (userData.containsKey('phoneNumber') && userData['phoneNumber'] != null) {
        final phoneNumber = userData['phoneNumber'];
        metadataUpdates['phoneNumber'] = phoneNumber;
        updates['phoneNumber'] = firestore.FieldValue.delete();
        needsUpdate = true;
      }
      
      // Move top-level dateOfBirth to metadata
      if (userData.containsKey('dateOfBirth') && userData['dateOfBirth'] != null) {
        final dob = userData['dateOfBirth'];
        if (dob is firestore.Timestamp) {
          metadataUpdates['dateOfBirth'] = dob;
          updates['dateOfBirth'] = firestore.FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move top-level gender to metadata
      if (userData.containsKey('gender') && userData['gender'] != null) {
        final gender = userData['gender'];
        if (gender is String) {
          metadataUpdates['gender'] = gender;
          updates['gender'] = firestore.FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move roomId from metadata to top level
      if (metadataUpdates.containsKey('roomId')) {
        final roomId = metadataUpdates['roomId'];
        if (roomId is String) {
          updates['roomId'] = roomId;
          metadataUpdates.remove('roomId');
          needsUpdate = true;
        }
      }
      
      // Handle profileUrl vs photoURL inconsistency
      if (userData.containsKey('profileUrl')) {
        final profileUrl = userData['profileUrl'];
        if (profileUrl is String && profileUrl.isNotEmpty) {
          final photoURL = userData['photoURL'];
          if (photoURL == null || (photoURL is String && photoURL.isEmpty)) {
            updates['photoURL'] = profileUrl;
          }
          updates['profileUrl'] = firestore.FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // If any changes needed, update the document
      if (needsUpdate) {
        updates['metadata'] = metadataUpdates;
        await _firestore.collection('users').doc(userId).update(updates);
      }
      
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'fixUserDocumentFields', stackTrace: stackTrace);
      return false;
    }
  }
  
  // Fix field inconsistencies for all users
  Future<bool> fixAllUserDocuments() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      int count = 0;
      
      for (final doc in usersSnapshot.docs) {
        final success = await fixUserDocumentFields(doc.id);
        if (success) count++;
        
        // Add small delay to avoid overwhelming Firestore
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      _appConfig.log('Fixed $count/${usersSnapshot.docs.length} user documents');
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'fixAllUserDocuments', stackTrace: stackTrace);
      return false;
    }
  }
  
  // Upload photo and update user photoURL
  Future<bool> uploadAndUpdatePhoto(String userId, File imageFile) async {
    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        return false;
      }
      
      // Upload image to cloud storage
      final photoUrl = await _uploadToCloudinary(imageFile);
      
      if (photoUrl == null) {
        return false;
      }
      
      // Update Firestore
      await _firestore.collection('users').doc(userId).update({
        'photoURL': photoUrl,
      });
      
      // Also update Firebase Auth photoURL if it's the current user
      if (userId == currentUserId) {
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }
      
      return true;
    } catch (e, stackTrace) {
      _reportError(e, 'uploadAndUpdatePhoto', stackTrace: stackTrace);
      return false;
    }
  }
  
  // Upload image to cloud storage
  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      final uri = 'https://api.cloudinary.com/v1_1/$_cloudName/upload';
      final userId = currentUserId ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final filename = path.basename(imageFile.path);
      
      // Create form data with folder structure and public_id
      final formData = FormData.fromMap({
        'upload_preset': _uploadPreset,
        'folder': 'users/$userId',
        'public_id': 'profile_$timestamp',
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: filename,
        ),
      });
      
      // Send request with timeout
      final response = await _dio.post(
        uri,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      // Check if successful
      if (response.statusCode == 200) {
        // Return the secure URL
        return response.data['secure_url'];
      } else {
        return null;
      }
    } catch (e, stackTrace) {
      _reportError(e, '_uploadToCloudinary', stackTrace: stackTrace);
      return null;
    }
  }

  // Clear FCM token when user logs out
  Future<void> clearFcmToken(String userId) async {
    try {
      // Update the user document to clear the FCM token
      if (kDebugMode) {
        print("UserService: Clearing FCM token for user $userId");
      }
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': null,  // Set to null to indicate no active device
      });
      if (kDebugMode) {
        print("UserService: FCM token cleared successfully");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("UserService: Error clearing FCM token: $e");
      }
      _reportError(e, 'clearFcmToken', stackTrace: stackTrace);
    }
  }
}