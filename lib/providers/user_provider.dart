import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  UserModel? _currentUser;
  StreamSubscription? _userSubscription;
  StreamSubscription? _userStatusSubscription;
  
  // Get current user data
  UserModel? get currentUser => _currentUser;
  String? get uid => _currentUser?.uid;
  String? get displayName => _currentUser?.displayName;
  String? get photoURL => _currentUser?.photoURL;
  String? get email => _currentUser?.email;
  Map<String, dynamic>? get metadata => _currentUser?.metadata;
  String? get roomId => _currentUser?.roomId;
  
  // Get user status
  bool _isOnline = false;
  String _statusAnimation = 'default';
  int _lastStatusTimestamp = 0;
  
  bool get isOnline => _isOnline;
  String get statusAnimation => _statusAnimation;
  int get lastStatusTimestamp => _lastStatusTimestamp;
  
  // Initialize provider
  Future<void> initialize() async {
    final currentUid = _userService.currentUserId;
    if (currentUid != null) {
      await _setupUserListeners(currentUid);
    }
    
    // Listen for auth state changes
    auth.FirebaseAuth.instance.authStateChanges().listen((auth.User? user) {
      if (user != null && (currentUid == null || currentUid != user.uid)) {
        _setupUserListeners(user.uid);
      } else if (user == null) {
        _clearUser();
      }
    });
  }
  
  // Setup listeners for user data and status
  Future<void> _setupUserListeners(String uid) async {
    // Cancel existing subscriptions
    await _clearSubscriptions();
    
    // Setup user data listener
    _userSubscription = _userService.getUserStreamById(uid).listen((userData) {
      _currentUser = userData;
      notifyListeners();
    });
    
    // Setup user status listener
    _userStatusSubscription = _userService.getUserStatusStream(uid).listen((statusData) {
      _isOnline = statusData['isOnline'] ?? false;
      _statusAnimation = statusData['animation'] ?? 'default';
      _lastStatusTimestamp = statusData['timestamp'] ?? 0;
      notifyListeners();
    });
  }
  
  // Set user status animation
  Future<void> setStatusAnimation(String animation) async {
    if (_currentUser != null) {
      await _userService.setUserStatusAnimation(_currentUser!.uid, animation);
    }
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
  
  // Clear user data on logout
  Future<void> _clearUser() async {
    final uid = _currentUser?.uid;
    if (uid != null) {
      await _userService.clearUserStatus(uid);
    }
    
    await _clearSubscriptions();
    _currentUser = null;
    _isOnline = false;
    _statusAnimation = 'default';
    _lastStatusTimestamp = 0;
    notifyListeners();
  }
  
  // Clear all subscriptions
  Future<void> _clearSubscriptions() async {
    await _userSubscription?.cancel();
    _userSubscription = null;
    
    await _userStatusSubscription?.cancel();
    _userStatusSubscription = null;
  }
  
  @override
  void dispose() {
    _clearSubscriptions();
    super.dispose();
  }
} 