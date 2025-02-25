import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, [this.code]);

  @override
  String toString() =>
      'AuthException: $message ${code != null ? '(Code: $code)' : ''}';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _userCollection = 'users';
  static const List<String> _allowedImageExtensions = ['jpg', 'jpeg', 'png'];

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Centralized user existence check
  Future<bool> _checkUserExists(String uid) async {
    try {
      debugPrint('Checking existence for user with UID: $uid');

      final userDoc =
          await _firestore.collection(_userCollection).doc(uid).get();

      if (userDoc.exists) {
        debugPrint('User exists in Firestore: $uid');
      } else {
        debugPrint('User does NOT exist in Firestore: $uid');
      }

      return userDoc.exists;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null; // No user is signed in
    }

    return await getUserData(user.uid); // Fetch Firestore user data
  }

  // Enhanced user data retrieval with robust error handling
  Future<Map<String, dynamic>?> getUserData(String? uid) async {
    if (uid == null) {
      throw AuthException('User ID cannot be null');
    }

    try {
      final docSnapshot =
          await _firestore.collection(_userCollection).doc(uid).get();

      return docSnapshot.exists ? docSnapshot.data() : null;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      throw AuthException('Failed to retrieve user data', e.toString());
    }
  }

  // Improved Google Sign In with comprehensive error handling
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return {'user': null, 'isNewUser': false};

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) return {'user': null, 'isNewUser': false};

      final userDoc =
          await _firestore.collection(_userCollection).doc(user.uid).get();
      final isNewUser = !userDoc.exists;

      // Get FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (isNewUser) {
        await _firestore.collection(_userCollection).doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? 'User',
          'photoURL': user.photoURL ?? '',
          'channelName': _generateRandomChannelName(),
          'fcmToken': fcmToken, // Save FCM token
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update FCM token for existing users
        await _firestore.collection(_userCollection).doc(user.uid).update({
          'fcmToken': fcmToken,
        });
      }

      return {
        'user': user,
        'isNewUser': isNewUser,
        'userData': isNewUser ? null : userDoc.data(),
      };
    } catch (e) {
      debugPrint('Error in Google Sign In: $e');
      await _auth.signOut();
      return {'user': null, 'isNewUser': false, 'userData': null};
    }
  }

  // Enhanced Apple Sign In with comprehensive error handling
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user!;

      final userExists = await _checkUserExists(user.uid);

      if (!userExists) {
        await _saveUserData(user);
      }

      return {
        'userCredential': userCredential,
        'isNewUser': !userExists,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Apple sign in error: ${e.message}');
      throw AuthException(e.message ?? 'Apple sign in failed', e.code);
    } catch (e) {
      debugPrint('Unexpected error: $e');
      throw AuthException('Unexpected error during Apple sign in');
    }
  }

  // Robust name update method
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

  // Save user data with more comprehensive initial data
  Future<void> _saveUserData(User user, {String? channelName}) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();

    await _firestore.collection(_userCollection).doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? 'User',
      'photoURL': user.photoURL ?? '',
      'channelName': channelName ?? _generateRandomChannelName(),
      'fcmToken': fcmToken, // Save FCM token
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Enhanced sign out with comprehensive logout
  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Remove FCM token from Firestore
        await _firestore.collection(_userCollection).doc(user.uid).update({
          'fcmToken': null,
        });
      }

      // Delete FCM token
      await FirebaseMessaging.instance.deleteToken();

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Error during sign out: $e');
      throw AuthException('Failed to sign out', e.toString());
    }
  }

  // Secure random channel name generation
  String _generateRandomChannelName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // Comprehensive profile picture upload with advanced error handling
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

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("No authenticated user found");
      }

      // Delete FCM token
      await FirebaseMessaging.instance.deleteToken();

      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        final photoURL = userDoc.data()?['photoURL'];

        // 🗑 Delete profile picture from Firebase Storage if it exists
        if (photoURL != null && photoURL.isNotEmpty) {
          try {
            final storageRef = _storage.refFromURL(photoURL);
            await storageRef.delete();
            debugPrint("Profile picture deleted successfully");
          } catch (e) {
            debugPrint("Failed to delete profile picture: $e");
          }
        }

        await userDocRef.delete(); // ❌ Delete user data from Firestore
      }

      // 🔄 **Re-authenticate if the user signed in via Google**
      for (final provider in user.providerData) {
        if (provider.providerId == "google.com") {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
          final GoogleSignInAuthentication? googleAuth =
              await googleUser?.authentication;

          if (googleAuth?.idToken == null) {
            throw Exception("Google re-authentication failed.");
          }

          final AuthCredential credential = GoogleAuthProvider.credential(
            idToken: googleAuth?.idToken,
            accessToken: googleAuth?.accessToken,
          );

          await user.reauthenticateWithCredential(credential);
          debugPrint("User re-authenticated successfully.");
        }
      }

      // 🔗 Unlink authentication providers (Google, Facebook, etc.)
      for (final provider in user.providerData) {
        await user.unlink(provider.providerId);
      }

      await user.delete(); // ❌ Delete user from Firebase Authentication
      debugPrint("User account deleted successfully from authentication.");
    } catch (e) {
      debugPrint("Error deleting user account: $e");
      throw Exception("Failed to delete account");
    }
  }
}
