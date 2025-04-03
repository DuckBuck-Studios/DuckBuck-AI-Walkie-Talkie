import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path; 
import '../models/user_model.dart'; 
import 'package:firebase_database/firebase_database.dart' as database;
import 'package:firebase_database/firebase_database.dart';
import '../config/app_config.dart';

class UserService {
  final _realtimeDb = database.FirebaseDatabase.instance;
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

  // Set user status animation in the real-time database
  Future<void> setUserStatusAnimation(String userId, String? animation, {bool explicitAnimationChange = true}) async {
    try {
      // Use the same userStatus path as other methods
      final statusRef = _realtimeDb.ref().child('userStatus').child(userId);
      
      // Get current status data to preserve other values
      final snapshot = await statusRef.get();
      Map<String, dynamic> existingData = {};
      
      if (snapshot.exists) {
        existingData = Map<String, dynamic>.from(snapshot.value as Map? ?? {});
      }
      
      // Update animation while preserving other values
      final Map<String, dynamic> updates = {
        ...existingData,
        'animation': animation,
        'timestamp': ServerValue.timestamp,
      };
      
      if (explicitAnimationChange) {
        updates['lastAnimationUpdate'] = ServerValue.timestamp;
      }
      
      // Make sure we don't accidentally mark user as offline
      // If no online status exists yet, set to true
      if (!existingData.containsKey('isOnline') && !existingData.containsKey('_actualIsOnline')) {
        updates['isOnline'] = true;
        updates['_actualIsOnline'] = true;
      }
      
      await statusRef.update(updates);
    } catch (e, stackTrace) {
      _reportError(e, 'setUserStatusAnimation', stackTrace: stackTrace);
    }
  }

  // Add these new methods for status management
  Future<void> updateUserStatus(String userId, String? statusAnimation, {bool explicitAnimationChange = false}) async {
    try {
      final statusRef = _realtimeDb.ref().child('userStatus').child(userId);
      
      // Only preserve animation if this is not an explicit animation change (like during initialization)
      // and the incoming statusAnimation is null
      if (statusAnimation == null && !explicitAnimationChange) {
        final snapshot = await statusRef.get();
        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map? ?? {});
          statusAnimation = data['animation'] as String?;
        }
      }
      
      // Update the status with preserved or new animation
      await statusRef.set({
        'animation': statusAnimation,
        'timestamp': ServerValue.timestamp,
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      // Set user as offline on disconnect instead of removing
      statusRef.onDisconnect().update({
        'isOnline': false,
        'timestamp': ServerValue.timestamp,
        'lastSeen': ServerValue.timestamp,
        // Keep the animation as is
      });
    } catch (e, stackTrace) {
      _reportError(e, 'updateUserStatus', stackTrace: stackTrace);
    }
  }

  Stream<Map<String, dynamic>> getUserStatusStream(String userId) {
    // First get the user document to check privacy settings
    return _firestore.collection('users').doc(userId)
      .snapshots()
      .asyncMap((userDoc) async {
        // Extract privacy settings
        bool showOnlineStatus = true;
        bool showLastSeen = true;
        
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          final metadata = userData['metadata'] as Map<String, dynamic>? ?? {};
          showOnlineStatus = metadata['showOnlineStatus'] ?? true;
          showLastSeen = metadata['showLastSeen'] ?? true;
        }
        
        // Now get the real-time status
        final snapshot = await _realtimeDb
            .ref()
            .child('userStatus')
            .child(userId)
            .get();
        
        if (snapshot.exists && snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          
          // Get the actual status values
          final bool actualIsOnline = data['_actualIsOnline'] ?? data['isOnline'] ?? false;
          final int? actualLastSeen = data['lastSeen'];
          
          // Apply privacy filters
          final bool visibleIsOnline = showOnlineStatus ? actualIsOnline : false;
          final int? visibleLastSeen = showLastSeen ? actualLastSeen : null;
                
          return {
            'animation': data['animation'],
            'timestamp': data['timestamp'] ?? 0,
            'isOnline': visibleIsOnline,
            'lastSeen': visibleLastSeen ?? 0,
            'actualIsOnline': actualIsOnline, // Only visible to the user themselves
          };
        }
        
        return {
          'animation': null,
          'timestamp': 0,
          'isOnline': false,
          'lastSeen': 0,
          'actualIsOnline': false,
        };
      });
  }

  // Method to clear user status when logging out
  Future<void> clearUserStatus(String userId) async {
    try {
      await _realtimeDb.ref().child('userStatus').child(userId).remove();
    } catch (e, stackTrace) {
      _reportError(e, 'clearUserStatus', stackTrace: stackTrace);
    }
  }

  // Method to set user's online status without changing animation
  Future<void> setUserOnlineStatus(String userId, bool isOnline) async {
    try {
      final statusRef = _realtimeDb.ref().child('userStatus').child(userId);
      
      // Get current animation status and privacy settings if they exist
      String? currentAnimation;
      bool showOnlineStatus = true; // Default to showing online status
      bool showLastSeen = true; // Default to showing last seen
      
      // First, check the user's privacy settings from Firestore
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          final metadata = userData['metadata'] as Map<String, dynamic>? ?? {};
          showOnlineStatus = metadata['showOnlineStatus'] ?? true;
          showLastSeen = metadata['showLastSeen'] ?? true;
        }
      } catch (e) {
        // Continue with defaults if there's an error
      }
      
      // Get current animation status if it exists
      final snapshot = await statusRef.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map? ?? {});
        currentAnimation = data['animation'] as String?;
      }
      
      // Create a map with internal actual status
      final Map<String, dynamic> statusUpdates = {
        '_actualIsOnline': isOnline, // Store actual status internally
        'timestamp': ServerValue.timestamp,
        'lastSeen': showLastSeen ? ServerValue.timestamp : null,
        'animation': currentAnimation, // Preserve current animation
      };
      
      // Set the public online status based on privacy settings
      if (showOnlineStatus) {
        statusUpdates['isOnline'] = isOnline;
      } else {
        // If the user doesn't want to show online status, always appear offline to others
        statusUpdates['isOnline'] = false;
      }
      
      // Update the status
      await statusRef.update(statusUpdates);

      // If setting to online, also setup the onDisconnect handler
      if (isOnline) {
        final Map<String, dynamic> disconnectUpdates = {
          '_actualIsOnline': false,
          'timestamp': ServerValue.timestamp,
        };
        
        // Only update public values based on privacy settings
        if (showOnlineStatus) {
          disconnectUpdates['isOnline'] = false;
        }
        
        if (showLastSeen) {
          disconnectUpdates['lastSeen'] = ServerValue.timestamp;
        }
        
        statusRef.onDisconnect().update(disconnectUpdates);
      }
    } catch (e, stackTrace) {
      _reportError(e, 'setUserOnlineStatus', stackTrace: stackTrace);
    }
  }

  // Update user privacy setting
  Future<void> updateUserPrivacySetting(String userId, String settingKey, bool value) async {
    try {
      // First update the metadata in Firestore
      final docRef = _firestore.collection('users').doc(userId);
      final userDoc = await docRef.get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        final metadata = Map<String, dynamic>.from(userData?['metadata'] ?? {});
        
        // Update the specific setting
        metadata[settingKey] = value;
        
        // Save back to Firestore
        await docRef.update({'metadata': metadata});
        
        // For specific privacy settings that affect real-time presence, immediately apply the change
        if (settingKey == 'showOnlineStatus' || settingKey == 'showLastSeen') {
          // Get current user status from real-time DB
          final statusRef = _realtimeDb.ref().child('userStatus').child(userId);
          final snapshot = await statusRef.get();
          
          if (snapshot.exists) {
            final data = Map<String, dynamic>.from(snapshot.value as Map? ?? {});
            
            // Determine the current actual online status
            final bool actualIsOnline = data['_actualIsOnline'] ?? data['isOnline'] ?? false;
            
            // Prepare updates based on new privacy settings
            final Map<String, dynamic> updates = {};
            
            if (settingKey == 'showOnlineStatus') {
              // Update the public online status based on the new setting
              if (value) {
                // If showing online status now, use the actual status
                updates['isOnline'] = actualIsOnline;
              } else {
                // If hiding online status now, always show as offline
                updates['isOnline'] = false;
              }
            }
            
            if (settingKey == 'showLastSeen') {
              if (value) {
                // If showing last seen now, update it to current time
                updates['lastSeen'] = ServerValue.timestamp;
              } else {
                // If hiding last seen now, remove or set to null
                updates['lastSeen'] = null;
              }
            }
            
            // Apply the updates if any
            if (updates.isNotEmpty) {
              await statusRef.update(updates);
            }
          }
        }
      }
    } catch (e, stackTrace) {
      _reportError(e, 'updateUserPrivacySetting', stackTrace: stackTrace);
    }
  }
}