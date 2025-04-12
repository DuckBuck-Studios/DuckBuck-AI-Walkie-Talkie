import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  UserModel? _currentUser;
  StreamSubscription? _userSubscription;
  
  // Get current user data
  UserModel? get currentUser => _currentUser;
  String? get uid => _currentUser?.uid;
  String? get displayName => _currentUser?.displayName;
  String? get photoURL => _currentUser?.photoURL;
  String? get email => _currentUser?.email;
  Map<String, dynamic>? get metadata => _currentUser?.metadata;
  String? get roomId => _currentUser?.roomId;
  
  // Initialize provider
  Future<void> initialize() async {
    if (kDebugMode) {
      print("UserProvider: Initializing");
    }
    final currentUid = _userService.currentUserId;
    if (currentUid != null) {
      if (kDebugMode) {
        print("UserProvider: Current user ID found: $currentUid");
      }
      await _setupUserListeners(currentUid);
      
      // Wait for initial user data to be fetched
      if (_currentUser == null) {
        if (kDebugMode) {
          print("UserProvider: Waiting for initial user data");
        }
        // Create a completer to wait for the first user data
        final completer = Completer<void>();
        late StreamSubscription subscription;
        
        subscription = _userService.getUserStreamById(currentUid).listen((userData) {
          if (userData != null && !completer.isCompleted) {
            if (kDebugMode) {
              print("UserProvider: Initial user data received");
            }
            _currentUser = userData;
            completer.complete();
            subscription.cancel();
          }
        });
        
        // Set a timeout just in case
        Future.delayed(const Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            if (kDebugMode) {
              print("UserProvider: Timeout waiting for user data");
            }
            completer.complete();
          }
        });
        
        await completer.future;
      }
      
      if (kDebugMode) {
        print("UserProvider: Initialization completed with user: ${_currentUser?.displayName ?? 'Unknown'}");
      }
    } else {
      if (kDebugMode) {
        print("UserProvider: No current user ID found");
      }
    }
    
    // Listen for auth state changes
    auth.FirebaseAuth.instance.authStateChanges().listen((auth.User? user) {
      if (user != null && (currentUid == null || currentUid != user.uid)) {
        if (kDebugMode) {
          print("UserProvider: Auth state changed, user logged in: ${user.uid}");
        }
        _setupUserListeners(user.uid);
      } else if (user == null) {
        if (kDebugMode) {
          print("UserProvider: Auth state changed, user logged out");
        }
        logout();
      }
    });
  }
  
  // Setup listeners for user data
  Future<void> _setupUserListeners(String uid) async {
    // Cancel existing subscriptions
    await _clearSubscriptions();
    
    // Setup user data listener
    _userSubscription = _userService.getUserStreamById(uid).listen((userData) {
      _currentUser = userData;
      notifyListeners();
    });
  }
  
  // Update user display name
  Future<bool> updateDisplayName(String displayName) async {
    if (_currentUser == null) return false;
    final result = await _userService.updateDisplayName(_currentUser!.uid, displayName);
    return result;
  }
  
  // Update user photo URL
  Future<bool> updatePhoto(dynamic photoFile) async {
    if (_currentUser == null) return false;
    final result = await _userService.uploadAndUpdatePhoto(_currentUser!.uid, photoFile);
    return result;
  }
  
  // Logout user and clear data 
  Future<void> logout() async {
    final uid = _currentUser?.uid;
    if (uid != null) {
      // Clear FCM token first
      await _userService.clearFcmToken(uid);
    }
    
    await _clearSubscriptions();
    
    _currentUser = null;
    notifyListeners();
  }
  
  // Clear all subscriptions
  Future<void> _clearSubscriptions() async {
    await _userSubscription?.cancel();
    _userSubscription = null;
  }
  
  // Force refresh user data from Firestore
  Future<bool> refreshUserData() async {
    if (_currentUser == null) return false;
    
    try {
      final userData = await _userService.getUserById(_currentUser!.uid);
      if (userData != null) {
        _currentUser = userData;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("UserProvider: Error refreshing user data: $e");
      }
      return false;
    }
  }

  // Delete user account
  Future<bool> deleteAccount() async {
    try {
      // Get current user ID for logging purposes
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      final String currentUserId = currentUser?.uid ?? 'unknown';
      if (kDebugMode) {
        print('UserProvider: Attempting to delete account for user: $currentUserId');
      }
      
      // Delete the user account via UserService
      await _userService.deleteUserAccount(currentUserId);
      if (kDebugMode) {
        print('UserProvider: User data deleted successfully for user: $currentUserId');
      }
      
      // Sign out regardless of the result to ensure session is terminated
      await auth.FirebaseAuth.instance.signOut();
      
      // Clear FCM token if available
      await _clearFCMToken();
      
      if (kDebugMode) {
        print('UserProvider: User signed out successfully after account deletion');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('UserProvider: Error during account deletion: $e');
      }
      
      // Try to sign out even if the deletion failed
      try {
        await auth.FirebaseAuth.instance.signOut();
        await _clearFCMToken();
        if (kDebugMode) {
          print('UserProvider: User signed out after deletion failure');
        }
      } catch (signOutError) {
        if (kDebugMode) {
          print('UserProvider: Error signing out after deletion failure: $signOutError');
        }
      }
      
      return false;
    }
  }
  
  // Clear FCM token for account deletion
  Future<void> _clearFCMToken() async {
    if (_currentUser == null) return;
    await _userService.clearFcmToken(_currentUser!.uid);
  }
  
  @override
  void dispose() {
    _clearSubscriptions();
    super.dispose();
  }
} 