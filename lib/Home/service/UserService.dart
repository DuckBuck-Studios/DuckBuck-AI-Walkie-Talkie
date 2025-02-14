import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duckbuck/Authentication/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _userCollection = 'users';
  static const List<String> _allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'heic'
  ];
  // Method to listen to user document changes
  Stream<DocumentSnapshot> listenToUserChanges(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Method to get the current user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    DocumentSnapshot doc =
        await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  Future<void> updateName(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }

      if (name.trim().isEmpty) {
        throw AuthException('Name cannot be empty');
      }

      await _firestore.collection(_userCollection).doc(user.uid).update({
        'name': name.trim(),
      });
    } catch (e) {
      debugPrint('Error updating name: $e');
      throw AuthException('Failed to update name', e.toString());
    }
  }

  Future<String> uploadProfilePicture(File image) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }

      final fileExtension = image.path.split('.').last.toLowerCase();
      if (!_allowedImageExtensions.contains(fileExtension)) {
        throw AuthException(
            'Invalid file format. Only ${_allowedImageExtensions.join(", ")} are allowed.',
            'INVALID_FILE_TYPE');
      }

      final fileName = 'profile_pics/${user.uid}.$fileExtension';
      final storageRef = _storage.ref().child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
        customMetadata: {'uploadedBy': user.uid},
      );

      // Upload with progress tracking
      final uploadTask = storageRef.putFile(image, metadata);

      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred /
            (snapshot.totalBytes == 0 ? 1 : snapshot.totalBytes);
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Atomic update of user document
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection(_userCollection).doc(user.uid);
        final docSnapshot = await transaction.get(docRef);

        if (!docSnapshot.exists) {
          throw AuthException('User document not found');
        }

        transaction.update(docRef, {
          'photoURL': downloadUrl,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('Profile picture uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      throw AuthException('Failed to upload profile picture',
          e is AuthException ? e.code : e.toString());
    }
  }

  Future<void> submitFeedback(String feedback) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }

      if (feedback.trim().isEmpty) {
        throw AuthException('Feedback cannot be empty');
      }

      // Get reference to the user's document in feedback collection
      final userFeedbackDoc = _firestore.collection('feedback').doc(user.uid);

      // Create a new feedback document with auto-generated ID in subcollection
      await userFeedbackDoc.collection('user_feedback').add({
        'feedback': feedback.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'platform': Platform.operatingSystem,
      });

      // Create or update the user's feedback document with metadata
      await userFeedbackDoc.set({
        'userName': user.displayName ?? 'Anonymous',
        'userEmail': user.email ?? 'No email',
        'lastFeedbackAt': FieldValue.serverTimestamp(),
        'feedbackCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      debugPrint('Feedback submitted successfully');
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      throw AuthException('Failed to submit feedback',
          e is AuthException ? e.code : e.toString());
    }
  }
}
