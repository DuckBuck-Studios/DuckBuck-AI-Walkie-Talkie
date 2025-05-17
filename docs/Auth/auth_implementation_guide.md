# DuckBuck Authentication Implementation Guide

This technical guide provides detailed implementation instructions for developers working on the authentication system in the DuckBuck app.

## Table of Contents

1. [Authentication Components Overview](#authentication-components-overview)
2. [Directory Structure](#directory-structure)
3. [Authentication Service Implementation](#authentication-service-implementation)
4. [Phone Authentication Flow](#phone-authentication-flow)
5. [Social Authentication Flow](#social-authentication-flow)
6. [User Data Management](#user-data-management)
7. [Authentication UI Implementation](#authentication-ui-implementation)
8. [Security Best Practices](#security-best-practices)
9. [Troubleshooting Common Issues](#troubleshooting-common-issues)
10. [Testing Authentication](#testing-authentication)

## Authentication Components Overview

The DuckBuck authentication system is built using Firebase Authentication with three authentication methods:

1. **Google Sign-In** - OAuth-based authentication using Google credentials
2. **Apple Sign-In** - Secure authentication using Apple ID
3. **Phone Authentication** - Two-step verification using phone number and OTP

The authentication system consists of these primary components:

- **Authentication Interface** - Defines the contract for auth operations
- **Firebase Authentication Service** - Implements the auth interface using Firebase
- **User Repository** - Manages user data and authentication state
- **Authentication State Provider** - Provides auth state to the UI
- **Authentication UI Components** - Welcome screen, onboarding, and auth bottom sheet

## Directory Structure

```
lib/
├── core/
│   ├── exceptions/
│   │   └── auth_exceptions.dart       # Custom auth error handling
│   ├── models/
│   │   └── user_model.dart            # User data model
│   ├── repositories/
│   │   └── user_repository.dart       # User data and auth operations
│   ├── services/
│   │   ├── auth/
│   │   │   ├── auth_security_manager.dart     # Security utilities
│   │   │   ├── auth_service_interface.dart    # Auth service contract
│   │   │   ├── firebase_auth_service.dart     # Firebase implementation
│   │   │   └── session_manager.dart           # Token management
│   │   ├── firebase/                 # Firebase service wrappers
│   │   └── preferences_service.dart  # Local storage for auth state
├── features/
│   └── auth/
│       ├── components/
│       │   └── auth_bottom_sheet.dart # Auth UI component
│       ├── providers/
│       │   └── auth_state_provider.dart # Auth state management
│       ├── screens/
│       │   ├── welcome_screen.dart       # Initial welcome screen
│       │   ├── onboarding_container.dart # Onboarding flow manager
│       │   ├── onboarding_screen_1.dart  # First onboarding screen
│       │   ├── onboarding_screen_2.dart  # Second onboarding screen
│       │   ├── onboarding_screen_3.dart  # Third onboarding screen
│       │   └── onboarding_signup_screen.dart # Final auth entry point
│       └── styles/
│           └── onboarding_styles.dart    # Shared styles for auth UI
```

## Authentication Service Implementation

### AuthServiceInterface

The `AuthServiceInterface` defines the contract for all authentication operations:

```dart
abstract class AuthServiceInterface {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  Future<String?> refreshIdToken({bool forceRefresh = false});
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> signInWithApple();
  Future<void> verifyPhoneNumber({...});
  Future<UserCredential> signInWithPhoneAuthCredential(PhoneAuthCredential credential);
  Future<UserCredential> verifyOtpAndSignIn(String verificationId, String smsCode);
  Future<void> signOut();
  Future<void> updateProfile({String? displayName, String? photoURL});
  Future<bool> validateCredential(AuthCredential credential);
}
```

### FirebaseAuthService

The `FirebaseAuthService` implements this interface using Firebase Authentication:

```dart
class FirebaseAuthService implements AuthServiceInterface {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  
  // Implementation of all methods defined in the interface
  // with proper error handling and analytics logging
}
```

**Key Implementation Points:**

1. **Error Handling** - The service converts Firebase errors into app-specific `AuthException` objects:

```dart
AuthException _handleException(FirebaseAuthException e) {
  String code;
  String message = e.message ?? 'An unknown error occurred';

  switch (e.code) {
    case 'invalid-email':
      code = AuthErrorCodes.invalidCredential;
      message = 'The email address is not valid.';
      break;
    // ... other error cases
    default:
      code = AuthErrorCodes.unknown;
  }
  
  return AuthException(code, message, e);
}
```

2. **Google Authentication** - Implemented using GoogleSignIn package:

```dart
@override
Future<UserCredential> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      throw AuthException(
        AuthErrorCodes.userCancelled,
        'Sign in was cancelled by user',
      );
    }
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    return await _firebaseAuth.signInWithCredential(credential);
  } on FirebaseAuthException catch (e) {
    throw _handleException(e);
  } catch (e) {
    // Handle other exceptions
  }
}
```

3. **Apple Authentication** - Implemented with secure nonce generation:

```dart
@override
Future<UserCredential> signInWithApple() async {
  try {
    // Generate a secure nonce
    final rawNonce = _getNonce();
    final nonce = _sha256ofString(rawNonce);
    
    // Request Apple Sign In credential
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    
    // Convert to OAuthCredential
    final oauthCredential = _getAppleCredential(appleCredential, rawNonce);
    
    // Sign in with Firebase
    return await _firebaseAuth.signInWithCredential(oauthCredential);
  } on FirebaseAuthException catch (e) {
    throw _handleException(e);
  } catch (e) {
    // Handle other exceptions
  }
}
```

## Phone Authentication Flow

The phone authentication flow is a two-step process:

### 1. Phone Number Verification

```dart
@override
Future<void> verifyPhoneNumber({
  required String phoneNumber,
  required void Function(PhoneAuthCredential) verificationCompleted,
  required void Function(AuthException) verificationFailed,
  required void Function(String, int?) codeSent,
  required void Function(String) codeAutoRetrievalTimeout,
}) async {
  try {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: (FirebaseAuthException e) {
        verificationFailed(_handleException(e));
      },
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  } catch (e) {
    // Handle unexpected errors
  }
}
```

### 2. OTP Verification

```dart
@override
Future<UserCredential> verifyOtpAndSignIn(
  String verificationId, 
  String smsCode
) async {
  try {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    
    return await _firebaseAuth.signInWithCredential(credential);
  } on FirebaseAuthException catch (e) {
    throw _handleException(e);
  } catch (e) {
    // Handle other exceptions
  }
}
```

## Social Authentication Flow

Both Google and Apple authentication follow a similar pattern:

1. Request authentication from the provider
2. Receive OAuth credentials
3. Sign in to Firebase with the credentials
4. Process user information in the repository

**Implementation Example from UserRepository:**

```dart
Future<(UserModel, bool)> signInWithGoogle() async {
  try {
    // Log authentication attempt
    await _analytics.logAuthAttempt(authMethod: 'google');
    
    final credential = await authService.signInWithGoogle();
    
    // Create user model
    var user = UserModel.fromFirebaseUser(credential.user!);
    
    // Check if this is a new user
    final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
    
    // Update user profile if needed
    if (isNewUser) {
      await _storeNewUserData(user);
      _logger.i(_tag, 'New user created with Google auth');
    } else {
      await _updateExistingUser(user);
      _logger.i(_tag, 'Existing user signed in with Google');
    }
    
    return (user, isNewUser);
  } on AuthException catch (e) {
    // Handle auth exceptions
    _logger.e(_tag, 'Google sign-in failed: ${e.message}', e);
    rethrow;
  } catch (e) {
    // Handle unexpected errors
    _logger.e(_tag, 'Unexpected error during Google sign-in', e);
    throw AuthException(AuthErrorCodes.unknown, 'Sign-in failed unexpectedly', e);
  }
}
```

## User Data Management

The `UserRepository` handles user data storage and retrieval:

### Creating/Updating User Data

```dart
Future<void> storeOrUpdateUserData(UserModel user) async {
  try {
    final docRef = _firestore.collection(_userCollection).doc(user.uid);
    
    // Get existing data first to merge properly
    final docSnap = await docRef.get();
    Map<String, dynamic> data = user.toMap();
    
    if (docSnap.exists) {
      // Update existing user data, preserving fields not included in the update
      await docRef.update(data);
      _logger.i(_tag, 'Updated user data for ${user.uid}');
    } else {
      // Create new user document with server timestamp
      data['createdAt'] = FieldValue.serverTimestamp();
      await docRef.set(data);
      _logger.i(_tag, 'Created new user document for ${user.uid}');
    }
    
    // Update user cache
    await PreferencesService.instance.cacheUserData(data);
  } catch (e) {
    _crashlytics.recordError(e, StackTrace.current, reason: 'Failed to store user data');
    _logger.e(_tag, 'Error storing user data: $e');
    throw Exception('Failed to store user data: $e');
  }
}
```

### User Caching for Performance

```dart
Future<UserModel?> getCurrentUserWithCache() async {
  final firebaseUser = authService.currentUser;
  if (firebaseUser == null) return null;
  
  // Check if we have valid cached user data
  final prefService = PreferencesService.instance;
  if (prefService.isCachedUserDataValid()) {
    final cachedData = prefService.getCachedUserData();
    if (cachedData != null && cachedData['uid'] == firebaseUser.uid) {
      _logger.d(_tag, 'Using cached user data from preferences');
      return UserModel.fromMap(cachedData);
    }
  }
  
  // If no valid cached data, create from Firebase user
  final user = UserModel.fromFirebaseUser(firebaseUser);
  
  // Cache the user data
  try {
    await prefService.cacheUserData(user.toMap());
  } catch (e) {
    _logger.w(_tag, 'Failed to cache user data: ${e.toString()}');
  }
  
  return user;
}
```

## Authentication UI Implementation

### Auth Bottom Sheet

The `AuthBottomSheet` is the main UI component for authentication:

```dart
class AuthBottomSheet extends StatefulWidget {
  // Implementation of the bottom sheet with different auth methods
  // and stages for phone authentication flow
}
```

**Key Features:**

1. **Authentication Stage Management** - Tracks the current stage of authentication:

```dart
enum AuthStage {
  options,      // Initial options (Google, Apple, Phone)
  phoneEntry,   // Phone number input
  otpVerification // OTP verification
}
```

2. **Individual Loading States** - Each authentication method has its own loading state:

```dart
// Loading states for different auth methods
bool _isGoogleLoading = false;
bool _isAppleLoading = false;
bool _isPhoneVerificationLoading = false;
bool _isOtpVerificationLoading = false;

// Helper property
bool get _isAnyAuthInProgress => 
    _isGoogleLoading || _isAppleLoading || 
    _isPhoneVerificationLoading || _isOtpVerificationLoading;
```

3. **Google Sign-In Button:**

```dart
Widget _buildGoogleSignInButton() {
  return _buildAuthButton(
    onPressed: _handleGoogleSignIn,
    isLoading: _isGoogleLoading,
    icon: FontAwesomeIcons.google,
    text: 'Continue with Google',
  );
}

Future<void> _handleGoogleSignIn() async {
  if (_isAnyAuthInProgress) return;
  
  setState(() {
    _isGoogleLoading = true;
  });
  
  try {
    await _authProvider.signInWithGoogle();
    _completeAuthentication();
  } catch (e) {
    _handleAuthError('Google sign-in failed', e);
  } finally {
    if (mounted) {
      setState(() {
        _isGoogleLoading = false;
      });
    }
  }
}
```

4. **Phone Authentication:**

```dart
Widget _buildPhoneEntryStage() {
  return Column(
    children: [
      // Phone number input with country code
      Row(
        children: [
          CountryCodePicker(
            onChanged: _onCountryCodeChanged,
            initialSelection: _selectedCountryCode,
            showCountryOnly: false,
            showOnlyCountryWhenClosed: false,
            alignLeft: false,
          ),
          
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Phone number',
              ),
              onChanged: (value) {
                // Validation logic
              },
            ),
          ),
        ],
      ),
      
      // Send code button
      _buildActionButton(
        onPressed: _isPhoneValid ? _sendVerificationCode : null,
        isLoading: _isPhoneVerificationLoading,
        text: 'Send Verification Code',
      ),
    ],
  );
}
```

5. **OTP Verification:**

```dart
Widget _buildOtpVerificationStage() {
  return Column(
    children: [
      // OTP input
      PinCodeTextField(
        appContext: context,
        length: 6,
        onChanged: (value) {
          setState(() {
            _otp = value;
          });
        },
        onCompleted: (value) {
          _verifyOtp();
        },
      ),
      
      // Verify button
      _buildActionButton(
        onPressed: _otp.length >= 6 ? _verifyOtp : null,
        isLoading: _isOtpVerificationLoading,
        text: 'Verify',
      ),
    ],
  );
}
```

### Onboarding Flow UI

The onboarding flow consists of multiple screens managed by the `OnboardingContainer`:

```dart
class OnboardingContainer extends StatefulWidget {
  // Implementation of the onboarding container with LiquidSwipe
}
```

**Key Features:**

1. **LiquidSwipe Controller** - Manages transitions between screens:

```dart
LiquidController _liquidController = LiquidController();

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: LiquidSwipe(
      pages: [
        OnboardingScreen1(),
        OnboardingScreen2(),
        OnboardingScreen3(),
        OnboardingSignupScreen(onComplete: widget.onComplete),
      ],
      liquidController: _liquidController,
      onPageChangeCallback: (page) {
        setState(() {
          _currentPage = page;
        });
        
        // Save progress
        PreferencesService.instance.setCurrentOnboardingStep(page);
        
        // Log analytics
        _logOnboardingPageView(page);
      },
      enableLoop: false,
      fullTransitionValue: 800,
    ),
  );
}
```

2. **Progress Restoration** - Remembers user's progress in the onboarding flow:

```dart
void _restoreOnboardingProgress() async {
  final step = await PreferencesService.instance.getCurrentOnboardingStep();
  
  if (step > 0 && step < 4) {
    // Use a brief delay to ensure animation works properly
    await Future.delayed(const Duration(milliseconds: 100));
    _liquidController.animateToPage(page: step, duration: 300);
  }
}
```

## Security Best Practices

### 1. Secure Token Management

The `SessionManager` class handles secure token management:

```dart
class SessionManager {
  final AuthServiceInterface _auth;
  Timer? _refreshTimer;
  
  Future<String?> getAuthToken() async {
    return _auth.refreshIdToken();
  }
  
  void startTokenRefreshCycle() {
    // Set up periodic token refresh before expiration
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 55), // Firebase tokens expire after 60 minutes
      (_) async {
        try {
          await _auth.refreshIdToken(forceRefresh: true);
        } catch (e) {
          // Handle refresh errors, potentially logging out the user
        }
      },
    );
  }
  
  void stopTokenRefreshCycle() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
```

### 2. Secure Credential Storage

The `AuthSecurityManager` class handles secure credential storage:

```dart
class AuthSecurityManager {
  final FlutterSecureStorage _secureStorage;
  
  Future<void> storeCredentialSecurely(String credentialType, String data) async {
    await _secureStorage.write(
      key: 'auth_credential_$credentialType',
      value: data,
    );
  }
  
  Future<String?> retrieveSecureCredential(String credentialType) async {
    return _secureStorage.read(key: 'auth_credential_$credentialType');
  }
  
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: 'auth_credential_google');
    await _secureStorage.delete(key: 'auth_credential_apple');
    await _secureStorage.delete(key: 'auth_credential_phone');
  }
  
  Future<bool> checkDeviceIntegrity() async {
    // Check for rooted/jailbroken device
    // Return false if device security is compromised
    return true;
  }
}
```

### 3. Apple Sign-In Security

Apple Sign-In requires a secure nonce to prevent replay attacks:

```dart
String _getNonce() {
  final random = Random.secure();
  final values = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(values);
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
```

## Troubleshooting Common Issues

### 1. Firebase Authentication Issues

**Issue**: `ERROR_USER_NOT_FOUND` or `user-not-found` error

**Solution**:
- Check if the user's account has been deleted from Firebase Console
- Verify that the user is signing in with the correct provider (Google vs Phone)
- Clear local cache and try again

**Implementation**:
```dart
if (e.code == 'user-not-found') {
  // Clear local cached credentials
  await _securityManager.clearCredentials();
  // Clear preferences
  await PreferencesService.instance.clearUserCache();
  // Show user-friendly message
  throw AuthException(
    AuthErrorCodes.userNotFound,
    'Your account was not found. Please sign in again.',
    e
  );
}
```

### 2. Phone Authentication Issues

**Issue**: Invalid phone number format

**Solution**:
- Validate phone number format before submission
- Use the CountryCodePicker to ensure proper country code

**Implementation**:
```dart
bool _validatePhoneNumber(String phoneNumber, String countryCode) {
  // Basic validation to ensure number has minimum length
  if (phoneNumber.length < 6) return false;
  
  // Format with country code
  final formattedNumber = '$countryCode$phoneNumber';
  
  try {
    // Use regex to validate
    final validPhonePattern = RegExp(r'^\+[0-9]{10,15}$');
    return validPhonePattern.hasMatch(formattedNumber);
  } catch (e) {
    return false;
  }
}
```

### 3. Social Authentication Issues

**Issue**: Google Sign-In fails silently

**Solution**:
- Check internet connectivity
- Verify Google services configuration in build files
- Validate SHA-1 fingerprint in Firebase console

**Implementation**:
```dart
Future<void> _handleGoogleSignIn() async {
  if (_isAnyAuthInProgress) return;
  
  if (!await _connectivity.checkConnectivity()) {
    _showError('No internet connection. Please try again when you're online.');
    return;
  }
  
  setState(() {
    _isGoogleLoading = true;
  });
  
  try {
    await _authProvider.signInWithGoogle();
    _completeAuthentication();
  } catch (e) {
    if (e is AuthException && e.code == AuthErrorCodes.invalidCredential) {
      _showError('Google sign-in configuration issue. Please contact support.');
      _logger.e(_tag, 'Google sign-in configuration error', e);
    } else {
      _handleAuthError('Google sign-in failed', e);
    }
  } finally {
    if (mounted) {
      setState(() {
        _isGoogleLoading = false;
      });
    }
  }
}
```

## Testing Authentication

### 1. Unit Testing Auth Services

```dart
void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late FirebaseAuthService authService;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    authService = FirebaseAuthService(
      firebaseAuth: mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
    );
  });

  test('signInWithGoogle should complete successfully', () async {
    // Mock Google sign-in response
    final mockGoogleUser = MockGoogleSignInAccount();
    final mockGoogleAuth = MockGoogleSignInAuthentication();
    when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
    when(mockGoogleUser.authentication).thenAnswer((_) async => mockGoogleAuth);
    when(mockGoogleAuth.accessToken).thenReturn('test-access-token');
    when(mockGoogleAuth.idToken).thenReturn('test-id-token');

    // Mock Firebase response
    final mockUserCredential = MockUserCredential();
    when(mockFirebaseAuth.signInWithCredential(any))
        .thenAnswer((_) async => mockUserCredential);

    // Execute the method under test
    final result = await authService.signInWithGoogle();

    // Verify the result
    expect(result, mockUserCredential);
    verify(mockGoogleSignIn.signIn()).called(1);
    verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
  });
}
```

### 2. Testing Auth State Provider

```dart
void main() {
  late AuthStateProvider authStateProvider;
  late MockUserRepository mockUserRepository;
  late MockNotificationsService mockNotificationsService;
  late StreamController<UserModel?> userStreamController;

  setUp(() {
    mockUserRepository = MockUserRepository();
    mockNotificationsService = MockNotificationsService();
    
    userStreamController = StreamController<UserModel?>();
    when(mockUserRepository.userStream).thenAnswer(
      (_) => userStreamController.stream,
    );

    authStateProvider = AuthStateProvider(
      userRepository: mockUserRepository,
      notificationsService: mockNotificationsService,
    );
  });

  tearDown(() {
    userStreamController.close();
  });

  test('should update currentUser when user stream emits new value', () async {
    // Create a test user
    final testUser = UserModel(uid: 'test-user-123');
    
    // Emit the user on the stream
    userStreamController.add(testUser);
    
    // Wait for the provider to process the update
    await Future.delayed(Duration.zero);
    
    // Verify the current user is updated
    expect(authStateProvider.currentUser, testUser);
    expect(authStateProvider.isLoggedIn, true);
  });
}
```

### 3. Widget Testing Auth UI

```dart
void main() {
  testWidgets('AuthBottomSheet shows auth options and handles Google sign in',
      (WidgetTester tester) async {
    // Create mocks
    final mockAuthProvider = MockAuthStateProvider();
    
    // Build our widget with Provider
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthStateProvider>.value(
          value: mockAuthProvider,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AuthBottomSheet.show(
                    context: context,
                    onAuthComplete: () {},
                  );
                },
                child: Text('Show Auth'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap the button to show the bottom sheet
    await tester.tap(find.text('Show Auth'));
    await tester.pumpAndSettle();

    // Verify the bottom sheet is displayed with auth options
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    
    // Mock successful Google sign-in
    when(mockAuthProvider.signInWithGoogle()).thenAnswer((_) async {});
    
    // Tap the Google sign-in button
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    
    // Verify loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Simulate completion
    await tester.pumpAndSettle();
    
    // Verify the provider method was called
    verify(mockAuthProvider.signInWithGoogle()).called(1);
  });
}
```

---

This implementation guide provides detailed instructions and code examples for working with the DuckBuck authentication system. By following these patterns and best practices, developers can maintain and extend the authentication system with confidence while ensuring security and a positive user experience.
