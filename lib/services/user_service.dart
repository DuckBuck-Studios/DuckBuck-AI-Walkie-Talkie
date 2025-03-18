import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../models/user_model.dart'; 
import 'package:firebase_database/firebase_database.dart' as database;

class UserService {
  final _realtimeDb = database.FirebaseDatabase.instance;
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
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
  
  // Stream user data by ID for real-time updates
  Stream<UserModel?> getUserStreamById(String userId) {
    return _firestore.collection('users').doc(userId)
      .snapshots()
      .map((doc) {
        if (doc.exists && doc.data() != null) {
          return UserModel.fromJson(doc.data()!);
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
      updatedMetadata['dateOfBirth'] = firestore.Timestamp.fromDate(dateOfBirth);
      
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
          updates['email'] = firestore.FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move top-level phoneNumber to metadata
      if (userData.containsKey('phoneNumber') && userData['phoneNumber'] != null) {
        print('Moving top-level phoneNumber to metadata for user $userId');
        
        final phoneNumber = userData['phoneNumber'];
        metadataUpdates['phoneNumber'] = phoneNumber;
        updates['phoneNumber'] = firestore.FieldValue.delete();
        needsUpdate = true;
      }
      
      // Move top-level dateOfBirth to metadata
      if (userData.containsKey('dateOfBirth') && userData['dateOfBirth'] != null) {
        print('Moving top-level dateOfBirth to metadata for user $userId');
        
        final dob = userData['dateOfBirth'];
        if (dob is firestore.Timestamp) {
          metadataUpdates['dateOfBirth'] = dob;
          updates['dateOfBirth'] = firestore.FieldValue.delete();
          needsUpdate = true;
        }
      }
      
      // Move top-level gender to metadata
      if (userData.containsKey('gender') && userData['gender'] != null) {
        print('Moving top-level gender to metadata for user $userId');
        
        final gender = userData['gender'];
        if (gender is String) {
          metadataUpdates['gender'] = gender;
          updates['gender'] = firestore.FieldValue.delete();
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
          updates['profileUrl'] = firestore.FieldValue.delete();
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

  // Method to set predefined status animations
  Future<void> setUserStatusAnimation(String userId, String? animation, {bool explicitAnimationChange = true}) async {
    print("UserService: Setting status animation for user: $userId");
    
    if (animation == null) {
      if (explicitAnimationChange) {
        print("UserService: Explicitly setting null animation (no animation)");
      } else {
        print("UserService: Null animation passed during initialization, will preserve existing");
      }
    } else {
      print("UserService: Setting animation: $animation");
    }

    await updateUserStatus(userId, animation, explicitAnimationChange: explicitAnimationChange);
  }

  // Add these new methods for status management
  Future<void> updateUserStatus(String userId, String? statusAnimation, {bool explicitAnimationChange = false}) async {
    try {
      print("UserService: Updating user status in Realtime DB for user: $userId");
      print("UserService: Setting animation: ${statusAnimation ?? 'null'}, isOnline: true");
      
      final statusRef = _realtimeDb.ref().child('userStatus').child(userId);
      
      // Only preserve animation if this is not an explicit animation change (like during initialization)
      // and the incoming statusAnimation is null
      if (statusAnimation == null && !explicitAnimationChange) {
        final snapshot = await statusRef.get();
        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map? ?? {});
          statusAnimation = data['animation'] as String?;
          print("UserService: Retrieved existing animation: ${statusAnimation ?? 'null'}");
        }
      }
      
      // Update the status with preserved or new animation
      await statusRef.set({
        'animation': statusAnimation,
        'timestamp': database.ServerValue.timestamp,
        'isOnline': true,
        'lastSeen': database.ServerValue.timestamp,
      });
      
      print("UserService: Status updated successfully in Realtime DB");

      // Set user as offline on disconnect instead of removing
      statusRef.onDisconnect().update({
        'isOnline': false,
        'timestamp': database.ServerValue.timestamp,
        'lastSeen': database.ServerValue.timestamp,
        // Keep the animation as is
      });
      print("UserService: Set onDisconnect handler to mark user as offline");
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  Stream<Map<String, dynamic>> getUserStatusStream(String userId) {
    print("UserService: Setting up status stream for user: $userId");
    return _realtimeDb
        .ref()
        .child('userStatus')
        .child(userId)
        .onValue
        .map((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        print("UserService: Status update received: animation=${data['animation']}, isOnline=${data['isOnline']}");
        return {
          'animation': data['animation'],
          'timestamp': data['timestamp'] ?? 0,
          'isOnline': data['isOnline'] ?? false,
          'lastSeen': data['lastSeen'] ?? 0,
        };
      }
      print("UserService: Status update received: null (user offline)");
      return {
        'animation': null,
        'timestamp': 0,
        'isOnline': false,
        'lastSeen': 0,
      };
    });
  }

  // Method to clear user status when logging out
  Future<void> clearUserStatus(String userId) async {
    try {
      print("UserService: Clearing user status for user: $userId");
      await _realtimeDb.ref().child('userStatus').child(userId).remove();
      print("UserService: User status cleared successfully");
    } catch (e) {
      print('Error clearing user status: $e');
    }
  }
}