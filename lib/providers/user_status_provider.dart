import 'package:flutter/foundation.dart';
import '../services/user_service.dart';
import 'package:firebase_database/firebase_database.dart';

class UserStatusProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final Map<String, Map<String, dynamic>> _userStatuses = {};
  String _currentStatus = 'idle';
  String _currentAnimationPath = 'assets/animations/idle.json';
  bool _isInitialized = false;

  Map<String, Map<String, dynamic>> get userStatuses => _userStatuses;

  // Getters
  String get currentStatus => _currentStatus;
  String get currentAnimationPath => _currentAnimationPath;
  bool get isInitialized => _isInitialized;

  void listenToUserStatus(String userId) {
    _userService.getUserStatusStream(userId).listen((status) {
      _userStatuses[userId] = status;
      notifyListeners();
    });
  }

  Future<void> updateStatus(String userId, String animation) async {
    await _userService.setUserStatusAnimation(userId, animation);
  }

  Future<void> clearStatus(String userId) async {
    await _userService.clearUserStatus(userId);
    _userStatuses.remove(userId);
    notifyListeners();
  }

  String getCurrentStatus(String userId) {
    return _userStatuses[userId]?['animation'] ?? 'default';
  }

  bool isUserOnline(String userId) {
    return _userStatuses[userId]?['isOnline'] ?? false;
  }

  // Initialize status from database
  Future<void> initializeStatus(String userId) async {
    if (_isInitialized) return;
    
    try {
      // Reference to the user's status in the real-time database
      final statusRef = FirebaseDatabase.instance.ref('userStatus/$userId');
      
      // Get the current snapshot
      final snapshot = await statusRef.get();
      
      if (snapshot.exists) {
        // Data exists, update with the stored status
        final data = snapshot.value as Map<dynamic, dynamic>;
        _currentStatus = data['status'] as String? ?? 'idle';
        _currentAnimationPath = data['animationPath'] as String? ?? 'assets/animations/idle.json';
      } else {
        // No data exists yet, set the default and save it
        await updateUserStatus(userId, _currentStatus, _currentAnimationPath);
      }
      
      // Set up a listener for real-time updates
      statusRef.onValue.listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          _currentStatus = data['status'] as String? ?? 'idle';
          _currentAnimationPath = data['animationPath'] as String? ?? 'assets/animations/idle.json';
          notifyListeners();
        }
      });
      
      _isInitialized = true;
      notifyListeners();
      
    } catch (e) {
      print('Error initializing user status: $e');
      // Keep defaults if there's an error
    }
  }
  
  // Update status in database and locally
  Future<void> updateUserStatus(String userId, String status, String animationPath) async {
    try {
      // Reference to the user's status in the real-time database
      final statusRef = FirebaseDatabase.instance.ref('userStatus/$userId');
      
      // Update the status
      await statusRef.set({
        'status': status,
        'animationPath': animationPath,
        'lastUpdated': ServerValue.timestamp,
      });
      
      // Update local state
      _currentStatus = status;
      _currentAnimationPath = animationPath;
      notifyListeners();
      
    } catch (e) {
      print('Error updating user status: $e');
      // Error handling will be done in the UI
      rethrow;
    }
  }
}