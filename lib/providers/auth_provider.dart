import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
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
  
  /// Current authentication status
  AuthStatus _status = AuthStatus.initial;

  /// Current user
  User? _user;

  /// Current user model with additional data
  models.UserModel? _userModel;
  
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

  /// Get the auth service instance
  AuthService get authService => _authService;

  /// Get the current user
  User? get currentUser => _user;

  /// Check if the user is authenticated
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Check if the user has completed onboarding
  bool get hasCompletedOnboarding {
    return _userModel?.metadata != null &&
           _userModel!.metadata!['current_onboarding_stage'] == 'completed';
  }

  /// Check if authentication is in progress
  bool get isLoading => _status == AuthStatus.loading;

  /// Get the current onboarding stage
  Future<OnboardingStage> getOnboardingStage() async {
    try {
      final userId = _user?.uid;
      if (userId == null) {
        return OnboardingStage.notStarted;
      }
      
      // Always check Firestore first to see if the user exists
      final userModel = await _authService.getUserModel(userId);
      
      // If user doesn't exist in database, don't use cache and don't recreate the user
      if (userModel == null) {
        // Clear any cached user model to prevent recreating deleted users
        _userModel = null;
        
        // Return notStarted to force the user through onboarding again
        return OnboardingStage.notStarted;
      }
      
      // Update the cached user model
      _userModel = userModel;
      
      // Check the current_onboarding_stage field in metadata if it exists
      if (userModel.metadata != null && 
          userModel.metadata!['current_onboarding_stage'] != null) {
        
        final stageString = userModel.metadata!['current_onboarding_stage'];
        switch (stageString) {
          case 'name':
            return OnboardingStage.name;
          case 'dateOfBirth':
            return OnboardingStage.dateOfBirth;
          case 'gender':
            return OnboardingStage.gender;
          case 'profilePhoto':
            return OnboardingStage.profilePhoto;
          case 'completed':
            return OnboardingStage.completed;
          default:
            // Continue to check individual fields
        }
      }
      
      // For new users or if stage is not set, start with name
      return OnboardingStage.name;
      
    } catch (e) {
      debugPrint('Error getting onboarding stage: $e');
      return OnboardingStage.name; // Default to name
    }
  }

  /// Update the onboarding stage in Firestore
  Future<void> updateOnboardingStage(OnboardingStage stage) async {
    try {
      final userId = _user?.uid;
      if (userId == null) {
        return;
      }
      
      String stageString;
      switch (stage) {
        case OnboardingStage.name:
          stageString = 'name';
          break;
        case OnboardingStage.dateOfBirth:
          stageString = 'dateOfBirth';
          break;
        case OnboardingStage.gender:
          stageString = 'gender';
          break;
        case OnboardingStage.profilePhoto:
          stageString = 'profilePhoto';
          break;
        case OnboardingStage.completed:
          stageString = 'completed';
          break;
        default:
          stageString = 'name';
      }
      
      // Update the current onboarding stage in Firestore
      await updateUserProfile(
        metadata: {'current_onboarding_stage': stageString},
      );
      
      // Refresh the user model to ensure we have the latest data
      await refreshUserModel();
    } catch (e) {
      debugPrint('Error updating onboarding stage: $e');
    }
  }

  /// Initialize the provider by checking current auth state
  void _init() {
    // Set initial loading state
    _status = AuthStatus.loading;
    notifyListeners();

    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) async {
      _user = user;
      if (user != null) {
        _status = AuthStatus.loading;
        notifyListeners();

        try {
          // First check if user exists in Firestore
          final exists = await _authService.userExists(user.uid);
          
          if (!exists) {
            // New user - set initial onboarding stage
            await updateOnboardingStage(OnboardingStage.name);
            _status = AuthStatus.authenticated;
          } else {
            // Existing user - fetch user model 
            await _fetchUserModel(user.uid);
            
            _status = AuthStatus.authenticated;
          }
        } catch (e) {
          debugPrint('Error initializing auth state: $e');
          _status = AuthStatus.error;
          _errorMessage = e.toString();
        }
      } else {
        _status = AuthStatus.unauthenticated;
        _userModel = null;
        _errorMessage = null;
      }
      notifyListeners();
    });
  }

  /// Fetch the user model from Firestore
  Future<void> _fetchUserModel(String uid) async {
    try {
      // Get user model from Firestore
      final userModel = await _authService.getUserModel(uid);
      
      // Only update the user model if it exists in Firestore
      // This prevents recreating deleted users from cache
      if (userModel != null) {
        _userModel = userModel;
        notifyListeners();
      } else {
        // If the user doesn't exist in Firestore but is authenticated,
        // clear the cached model to prevent recreating it
        _userModel = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user model: $e');
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

  /// Get the user model from the auth service
  Future<models.UserModel?> getUserModel() async {
    return await _authService.getCurrentUserModel();
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      // Clear any cached data
      _userModel = null;
      _errorMessage = null;

      // Sign out from Firebase Auth
      await _authService.signOut();
      
      // Explicitly set status to unauthenticated
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Clear any error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
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