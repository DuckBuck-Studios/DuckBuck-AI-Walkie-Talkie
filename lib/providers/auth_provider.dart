import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart' as models;

/// Authentication state enum
enum AuthStatus {
  /// Initial state
  initial,

  /// User is authenticated
  authenticated,

  /// User is not authenticated
  unauthenticated,

  /// Authentication is in progress
  loading,

  /// Authentication has failed
  error,
}

/// Onboarding stage enum to track user's progress
enum OnboardingStage {
  /// Not started
  notStarted,
  
  /// Name screen
  name,
  
  /// Date of birth screen
  dateOfBirth,
  
  /// Gender screen
  gender,
  
  /// Profile photo screen
  profilePhoto,
  
  /// Completed
  completed
}

/// Provider that manages authentication state
class AuthProvider with ChangeNotifier {
  /// Instance of the auth service
  final AuthService _authService;
  
  /// Secure storage instance for local data
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Current authentication status
  AuthStatus _status = AuthStatus.initial;

  /// Current user
  User? _user;

  /// Current user model with additional data
  models.UserModel? _userModel;
  
  /// Current onboarding stage (cached)
  OnboardingStage? _cachedOnboardingStage;

  /// Error message if authentication fails
  String? _errorMessage;

  /// Create a new auth provider
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    // Initialize by checking current auth state
    _init();
  }

  /// Get the current authentication status
  AuthStatus get status => _status;

  /// Get the current user
  User? get user => _user;

  /// Get the current user model
  models.UserModel? get userModel => _userModel;

  /// Get the error message
  String? get errorMessage => _errorMessage;

  /// Check if the user is authenticated
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Check if the user has completed onboarding
  bool get hasCompletedOnboarding => _cachedOnboardingStage == OnboardingStage.completed;

  /// Check if authentication is in progress
  bool get isLoading => _status == AuthStatus.loading;

  /// Get the current onboarding stage
  Future<OnboardingStage> getOnboardingStage() async {
    // If cached value exists, return it
    if (_cachedOnboardingStage != null) {
      return _cachedOnboardingStage!;
    }
    
    try {
      // If no cached value, get from secure storage
      final userId = _user?.uid;
      if (userId == null) return OnboardingStage.notStarted;
      
      final stageString = await _secureStorage.read(key: 'onboarding_stage_$userId');
      if (stageString == null) return OnboardingStage.notStarted;
      
      // Parse stage from storage
      OnboardingStage stage;
      switch (stageString) {
        case 'name':
          stage = OnboardingStage.name;
          break;
        case 'dateOfBirth':
          stage = OnboardingStage.dateOfBirth;
          break;
        case 'gender':
          stage = OnboardingStage.gender;
          break;
        case 'profilePhoto':
          stage = OnboardingStage.profilePhoto;
          break;
        case 'completed':
          stage = OnboardingStage.completed;
          break;
        default:
          stage = OnboardingStage.notStarted;
      }
      
      // Cache the result
      _cachedOnboardingStage = stage;
      return stage;
    } catch (e) {
      debugPrint('Error getting onboarding stage: $e');
      return OnboardingStage.notStarted;
    }
  }

  /// Initialize the provider by checking current auth state
  void _init() {
    // Set initial loading state
    _status = AuthStatus.loading;
    notifyListeners();

    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) {
        _status = AuthStatus.authenticated;
        // Fetch user data from Firestore
        _fetchUserModel(user.uid);
        // Reset cached onboarding stage on new sign-in
        _cachedOnboardingStage = null;
      } else {
        _status = AuthStatus.unauthenticated;
        _userModel = null;
        _cachedOnboardingStage = null;
      }
      notifyListeners();
    });
  }

  /// Fetch the user model from Firestore
  Future<void> _fetchUserModel(String uid) async {
    try {
      _userModel = await _authService.getUserModel(uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user model: $e');
      // We don't change the auth status here since the user is still authenticated
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _authService.signInWithGoogle();
      
      // Auth state listener will update the status
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _authService.signInWithApple();
      
      // Auth state listener will update the status
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Initiate phone number verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Handle auto-verification
          await _handleCredential(credential);
          verificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _status = AuthStatus.error;
          _errorMessage = e.message;
          notifyListeners();
          verificationFailed(e);
        },
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Sign in with phone verification code
  Future<void> signInWithPhoneNumber(String verificationId, String smsCode) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _authService.signInWithPhoneNumber(verificationId, smsCode);
      
      // Auth state listener will update the status
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    Map<String, dynamic>? metadata,
    DateTime? dateOfBirth,
    models.Gender? gender,
  }) async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      await _authService.updateUserProfile(
        displayName: displayName,
        photoURL: photoURL,
        metadata: metadata,
        dateOfBirth: dateOfBirth,
        gender: gender,
      );

      // Refresh user model
      if (_user != null) {
        await _fetchUserModel(_user!.uid);
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update the onboarding stage
  Future<void> updateOnboardingStage(OnboardingStage stage) async {
    try {
      final userId = _user?.uid;
      if (userId == null) return;
      
      String stageValue;
      
      switch (stage) {
        case OnboardingStage.name:
          stageValue = 'name';
          break;
        case OnboardingStage.dateOfBirth:
          stageValue = 'dateOfBirth';
          break;
        case OnboardingStage.gender:
          stageValue = 'gender';
          break;
        case OnboardingStage.profilePhoto:
          stageValue = 'profilePhoto';
          break;
        case OnboardingStage.completed:
          stageValue = 'completed';
          break;
        default:
          stageValue = '';
      }
      
      // Store in secure storage
      await _secureStorage.write(key: 'onboarding_stage_$userId', value: stageValue);
      
      // Update cache
      _cachedOnboardingStage = stage;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating onboarding stage: $e');
    }
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    try {
      await updateOnboardingStage(OnboardingStage.completed);
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
    }
  }

  /// Handle a phone auth credential
  Future<void> _handleCredential(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      // Auth state listener will handle the rest
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh the user model
  Future<void> refreshUserModel() async {
    if (_user != null) {
      await _fetchUserModel(_user!.uid);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      await _authService.signOut();
      
      // Auth state listener will update the status
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Clear any error message
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = _user != null 
          ? AuthStatus.authenticated 
          : AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
}

/// Extension method to access auth provider from build context
extension AuthProviderExtension on BuildContext {
  /// Get the auth provider
  AuthProvider get authProvider => Provider.of<AuthProvider>(this, listen: false);
  
  /// Get the current user
  User? get currentUser => Provider.of<AuthProvider>(this, listen: false).user;
  
  /// Check if the user is authenticated
  bool get isAuthenticated => Provider.of<AuthProvider>(this, listen: false).isAuthenticated;
} 