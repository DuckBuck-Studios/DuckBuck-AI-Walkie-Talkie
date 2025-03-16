import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../models/user_model.dart'; 
import 'package:firebase_database/firebase_database.dart';

class UserService {
  final _realtimeDb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Dio _dio = Dio();
  
  // Cloudinary configuration - in production, these would be secured
  final String _cloudName = 'deycvanff';
  final String _uploadPreset = 'users_p';
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }
  
  // Get current user
  Future<UserModel?> getCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getUserById(userId);
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
    } catch (e) {
      print('Error updating display name: $e');
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
      updatedMetadata['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      
      // Update the user document with the new metadata
      await _firestore.collection('users').doc(userId).update({
        'metadata': updatedMetadata
      });
      
      return true;
    } catch (e) {
      print('Error updating date of birth: $e');
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
    } catch (e) {
      print('Error updating gender: $e');
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
      
      print('Updated roomId to $roomId for user $userId');
      return true;
    } catch (e) {
      print('Error updating roomId: $e');
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
        print('Moving top-level email to metadata for user $userId');
        
        final email = userData['email'];
        if (email is String) {
          metadataUpdates['email'] = email;
          updates['email'] = FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move top-level phoneNumber to metadata
      if (userData.containsKey('phoneNumber') && userData['phoneNumber'] != null) {
        print('Moving top-level phoneNumber to metadata for user $userId');
        
        final phoneNumber = userData['phoneNumber'];
        metadataUpdates['phoneNumber'] = phoneNumber;
        updates['phoneNumber'] = FieldValue.delete();
        needsUpdate = true;
      }
      
      // Move top-level dateOfBirth to metadata
      if (userData.containsKey('dateOfBirth') && userData['dateOfBirth'] != null) {
        print('Moving top-level dateOfBirth to metadata for user $userId');
        
        final dob = userData['dateOfBirth'];
        if (dob is Timestamp) {
          metadataUpdates['dateOfBirth'] = dob;
          updates['dateOfBirth'] = FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move top-level gender to metadata
      if (userData.containsKey('gender') && userData['gender'] != null) {
        print('Moving top-level gender to metadata for user $userId');
        
        final gender = userData['gender'];
        if (gender is String) {
          metadataUpdates['gender'] = gender;
          updates['gender'] = FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move roomId from metadata to top level
      if (metadataUpdates.containsKey('roomId')) {
        print('Moving roomId from metadata to top level for user $userId');
        
        final roomId = metadataUpdates['roomId'];
        if (roomId is String) {
          updates['roomId'] = roomId;
          metadataUpdates.remove('roomId');
          needsUpdate = true;
        }
      }
      
      // Handle profileUrl vs photoURL inconsistency
      if (userData.containsKey('profileUrl')) {
        print('Found profileUrl for user $userId, moving to photoURL');
        
        final profileUrl = userData['profileUrl'];
        if (profileUrl is String && profileUrl.isNotEmpty) {
          final photoURL = userData['photoURL'];
          if (photoURL == null || (photoURL is String && photoURL.isEmpty)) {
            updates['photoURL'] = profileUrl;
          }
          updates['profileUrl'] = FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // If any changes needed, update the document
      if (needsUpdate) {
        updates['metadata'] = metadataUpdates;
        
        await _firestore.collection('users').doc(userId).update(updates);
        print('Fixed field inconsistencies for user $userId');
      } else {
        print('No inconsistencies found for user $userId');
      }
      
      return true;
    } catch (e) {
      print('Error fixing user document fields: $e');
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
      
      print('Fixed field inconsistencies for $count/${usersSnapshot.docs.length} users');
      return true;
    } catch (e) {
      print('Error fixing all user documents: $e');
      return false;
    }
  }
  
  // Upload photo and update user photoURL
  Future<bool> uploadAndUpdatePhoto(String userId, File imageFile) async {
    try {
      print('Starting photo upload process for user: $userId');
      
      // Check if file exists
      if (!await imageFile.exists()) {
        print('ERROR: Image file does not exist at path: ${imageFile.path}');
        return false;
      }
      
      // Upload image to cloud storage
      print('Uploading image to cloud storage...');
      final photoUrl = await _uploadToCloudinary(imageFile);
      
      if (photoUrl == null) {
        print('ERROR: Failed to get photo URL from cloud storage');
        return false;
      }
      
      print('Successfully uploaded image. URL received.');
      
      // Update Firestore
      print('Updating user profile with new photo URL...');
      await _firestore.collection('users').doc(userId).update({
        'photoURL': photoUrl,
      });
      
      // Also update Firebase Auth photoURL if it's the current user
      if (userId == currentUserId) {
        print('Updating Firebase Auth user profile...');
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }
      
      print('Photo upload and update process completed successfully');
      return true;
    } catch (e) {
      print('ERROR in uploadAndUpdatePhoto: $e');
      if (e is DioException) {
        print('Network error details: ${e.message}');
      }
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
      
      print('Preparing image upload...');
      
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
      
      print('Sending upload request...');
      
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
      print('Upload response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        // Return the secure URL
        return response.data['secure_url'];
      } else {
        print('Failed to upload image. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ERROR in image upload: $e');
      if (e is DioException) {
        print('Network error type: ${e.type}');
        
        // Check for common issues
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.sendTimeout) {
          print('Connection timeout - please check your internet connection');
        } else if (e.type == DioExceptionType.receiveTimeout) {
          print('Response timeout - the image might be too large');
        }
      }
      return null;
    }
  }

  // Add these new methods for status management
  Future<void> updateUserStatus(String userId, String statusAnimation) async {
    try {
      final statusRef = _realtimeDb.ref().child('userStatus').child(userId);
      await statusRef.set({
        'animation': statusAnimation,
        'timestamp': ServerValue.timestamp,
        'isOnline': true,
      });

      // Remove the status when user goes offline
      statusRef.onDisconnect().remove();
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  Stream<Map<String, dynamic>> getUserStatusStream(String userId) {
    return _realtimeDb
        .ref()
        .child('userStatus')
        .child(userId)
        .onValue
        .map((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return {
          'animation': data['animation'] ?? 'default',
          'timestamp': data['timestamp'] ?? 0,
          'isOnline': data['isOnline'] ?? false,
        };
      }
      return {
        'animation': 'default',
        'timestamp': 0,
        'isOnline': false,
      };
    });
  }

  // Method to clear user status when logging out
  Future<void> clearUserStatus(String userId) async {
    try {
      await _realtimeDb.ref().child('userStatus').child(userId).remove();
    } catch (e) {
      print('Error clearing user status: $e');
    }
  }

  // Method to set predefined status animations
  Future<void> setUserStatusAnimation(String userId, String animation) async {
    // animation parameter should be the name of the JSON file without extension
    // Example: 'happy', 'busy', 'away', 'gaming', etc.
    if (!_isValidStatusAnimation(animation)) {
      print('Invalid status animation: $animation');
      return;
    }

    await updateUserStatus(userId, animation);
  }

  // Validate status animation names
  bool _isValidStatusAnimation(String animation) {
    // Add all valid status animation names here
    final validAnimations = [
      'default',
      'happy',
      'busy',
      'away',
      'gaming',
      'working',
      'sleeping',
      'eating',
      // Add more status animations as needed
    ];
    return validAnimations.contains(animation);
  }
}