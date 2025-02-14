import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:duckbuck/Home/service/UserService.dart'; 

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  String _photoURL = '';
  String _name = '';
  bool _isLoading = true; // Add loading state

  String get photoURL => _photoURL;
  String get name => _name;
  bool get isLoading => _isLoading; // Add getter

  // This method initializes the user by fetching the current user's UID
  Future<void> initializeUser() async {
    _isLoading = true; // Set loading to true when starting
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        _name = userData['name'] ?? '';
        _photoURL = userData['photoURL'] ?? '';
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
    } finally {
      _isLoading = false; // Set loading to false when done
      notifyListeners();
    }
  }
}
