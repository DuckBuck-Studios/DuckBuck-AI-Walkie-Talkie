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
  bool _actualIsOnline = false;  
  String? _statusAnimation;
  int _lastStatusTimestamp = 0;
  
  bool get isOnline => _isOnline;
  bool get actualIsOnline => _actualIsOnline; // Actual status for the current user's own view
  String? get statusAnimation => _statusAnimation;
  int get lastStatusTimestamp => _lastStatusTimestamp;
  
  // Privacy settings
  bool get showOnlineStatus => _currentUser?.getMetadata('showOnlineStatus') ?? true;
  bool get showLastSeen => _currentUser?.getMetadata('showLastSeen') ?? true;
  
  // Initialize provider
  Future<void> initialize() async {
    print("UserProvider: Initializing");
    final currentUid = _userService.currentUserId;
    if (currentUid != null) {
      print("UserProvider: Current user ID found: $currentUid");
      await _setupUserListeners(currentUid);
      
      // Wait for initial user data to be fetched
      if (_currentUser == null) {
        print("UserProvider: Waiting for initial user data");
        // Create a completer to wait for the first user data
        final completer = Completer<void>();
        late StreamSubscription subscription;
        
        subscription = _userService.getUserStreamById(currentUid).listen((userData) {
          if (userData != null && !completer.isCompleted) {
            print("UserProvider: Initial user data received");
            _currentUser = userData;
            completer.complete();
            subscription.cancel();
          }
        });
        
        // Set a timeout just in case
        Future.delayed(const Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            print("UserProvider: Timeout waiting for user data");
            completer.complete();
          }
        });
        
        await completer.future;
      }
      
      print("UserProvider: Initialization completed with user: ${_currentUser?.displayName ?? 'Unknown'}");
    } else {
      print("UserProvider: No current user ID found");
    }
    
    // Listen for auth state changes
    auth.FirebaseAuth.instance.authStateChanges().listen((auth.User? user) {
      if (user != null && (currentUid == null || currentUid != user.uid)) {
        print("UserProvider: Auth state changed, user logged in: ${user.uid}");
        _setupUserListeners(user.uid);
      } else if (user == null) {
        print("UserProvider: Auth state changed, user logged out");
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
      _actualIsOnline = statusData['actualIsOnline'] ?? _isOnline; // Use actual status if available
      _statusAnimation = statusData['animation'];
      _lastStatusTimestamp = statusData['timestamp'] ?? 0;
      notifyListeners();
    });
  }
  
  // Set user status animation
  void setStatusAnimation(String? animation, {bool explicitChange = true}) {
    if (_currentUser == null) return;
    
    // For explicit changes (from popup), directly use the animation value
    // For non-explicit changes (initialization), only update if animation is not null
    if (explicitChange || animation != null) {
      _userService.setUserStatusAnimation(_currentUser!.uid, animation, explicitAnimationChange: explicitChange);
      _statusAnimation = animation;
      notifyListeners();
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
    _actualIsOnline = false;
    _statusAnimation = null;
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
      print("UserProvider: Error refreshing user data: $e");
      return false;
    }
  }
  
  // Set user online status (without changing animation)
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_currentUser == null) return;
    await _userService.setUserOnlineStatus(_currentUser!.uid, isOnline);
    _actualIsOnline = isOnline;
    _isOnline = showOnlineStatus ? isOnline : false; // Visible status depends on privacy settings
    notifyListeners();
  }
  
  // Update privacy settings
  Future<void> updatePrivacySettings(String key, bool value) async {
    if (_currentUser == null) return;
    await _userService.updateUserPrivacySetting(_currentUser!.uid, key, value);
    
    // Update local state immediately based on the new privacy setting
    if (key == 'showOnlineStatus') {
      _isOnline = value ? _actualIsOnline : false;
    }
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _clearSubscriptions();
    super.dispose();
  }
} 