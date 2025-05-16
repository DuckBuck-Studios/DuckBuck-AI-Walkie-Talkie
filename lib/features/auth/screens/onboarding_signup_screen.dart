import 'dart:io';
import 'dart:math' as Math;

import 'package:duckbuck/core/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../components/auth_bottom_sheet.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/firebase/firebase_analytics_service.dart';
import '../../../core/services/logger/logger_service.dart';
import '../providers/auth_state_provider.dart';
import '../../../core/widgets/notification_bar.dart';
import '../../../core/navigation/app_routes.dart';

/// Screen that handles user signup/login and additional profile information
class OnboardingSignupScreen extends StatefulWidget {
  const OnboardingSignupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingSignupScreen> createState() => _OnboardingSignupScreenState();
}

class _OnboardingSignupScreenState extends State<OnboardingSignupScreen>
    with TickerProviderStateMixin {
  // No more animation controller needed

  // Services
  late final FirebaseAnalyticsService _analyticsService;
  late final LoggerService _logger;
  final String _tag = 'OnboardingSignupScreen';

  // UI state management
  bool _isLoading = false;
  String? _errorMessage;
  AuthMethod? _loadingMethod;

  // For handling verification ID in phone auth
  String? _verificationId;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();

    // Remove animation controller setup

    // Add haptic feedback when screen appears with stronger impact for final screen
    HapticFeedback.heavyImpact();

    // Initialize services
    _analyticsService = serviceLocator<FirebaseAnalyticsService>();
    _logger = serviceLocator<LoggerService>();

    _logger.i(_tag, 'Initializing OnboardingSignupScreen');

    // Check if the user is already authenticated and route accordingly
    _checkAndRouteAuthenticatedUser();
  }

  @override
  void dispose() {
    // Remove animation controller disposal
    super.dispose();
  }

  /// Handle phone authentication
  Future<void> _handlePhoneAuth(String phoneNumber) async {
    // Set loading state immediately to show the loading indicator
    setState(() {
      _isLoading = true;
      _loadingMethod = AuthMethod.phone;
      _errorMessage = null;
    });

    // Log the phone number verification attempt
    _logger.i(_tag, 'Starting phone number verification: $phoneNumber');

    // Reset any previous verification state before starting new verification
    _verificationId = null;
    _phoneNumber = null;

    await _handleAuthentication(AuthMethod.phone, phoneNumber: phoneNumber);
  }

  /// Handle Google authentication
  Future<void> _handleGoogleAuth() async {
    _logger.i(_tag, 'Google auth button pressed');
    await _handleAuthentication(AuthMethod.google);
  }

  /// Handle Apple authentication
  Future<void> _handleAppleAuth() async {
    _logger.i(_tag, 'Apple auth button pressed');
    await _handleAuthentication(AuthMethod.apple);
  }

  /// Handle phone auth credential verification
  Future<void> _handlePhoneAuthCredential(dynamic credential) async {
    setState(() {
      _isLoading = true;
      _loadingMethod = AuthMethod.phone; // Make sure to set the loading method
      _errorMessage = null;
    });

    // Log OTP verification attempt
    _logger.i(_tag, 'Verifying OTP for phone number: $_phoneNumber');

    try {
      // Logging attempt with analytics
      await _analyticsService.logOtpEntered(
        isSuccessful: false, // Will update to true if successful
        isAutoFilled: false, // Manual entry
      );

      final authProvider = Provider.of<AuthStateProvider>(
        context,
        listen: false,
      );

      _logger.d(_tag, 'Submitting phone auth credential for verification');

      // Fix: Use the credential directly as a positional parameter
      final (user, isNewUser) = await authProvider
          .signInWithPhoneAuthCredential(credential);

      // Log successful OTP verification
      await _analyticsService.logOtpEntered(
        isSuccessful: true,
        isAutoFilled: false,
      );

      // Track appropriate event based on new/existing user
      if (isNewUser) {
        _analyticsService.logSignUp(signUpMethod: 'phone');
        _analyticsService.logEvent(
          name: 'new_user_signup',
          parameters: {
            'auth_method': 'phone',
            'user_id': user.uid.toString().substring(0, Math.min(user.uid.length, 36)),
            'verification_type': 'manual_code_entry',
          }
        );
      } else {
        _analyticsService.logLogin(loginMethod: 'phone');
        _analyticsService.logEvent(
          name: 'returning_user_login',
          parameters: {
            'auth_method': 'phone',
            'user_id': user.uid,
            'verification_type': 'manual_code_entry',
          }
        );
      }

      // Track auth success
      _analyticsService.logAuthSuccess(
        authMethod: 'phone',
        userId: user.uid,
        isNewUser: isNewUser,
      );

      // Reset verification state
      setState(() {
        _verificationId = null;
        _phoneNumber = null;
        _isLoading = false;
      });

      // Check if user needs profile completion with explicit isNewUser flag
      _showProfileCompletionIfNeeded(user, isNewUser);
    } catch (e) {
      // Log the detailed error with full stack trace
      _logger.e(_tag, 'OTP verification error: ${e.toString()}', e);

      // Log OTP verification failure in analytics
      await _analyticsService.logAuthFailure(
        authMethod: 'phone_otp_verification',
        reason: e.toString(),
        errorCode: e is FirebaseAuthException ? e.code : null,
      );

      // Format user-friendly error message
      String errorMsg = 'Verification failed';

      if (e.toString().contains('invalid-verification-code')) {
        errorMsg = 'Invalid verification code. Please try again.';
      } else if (e.toString().contains('session-expired')) {
        errorMsg = 'Verification session expired. Please resend the code.';
      } else if (e.toString().contains('network-request-failed')) {
        errorMsg = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('auth/invalid-credential')) {
        errorMsg = 'Invalid verification code. Please check and try again.';
      } else if (e.toString().contains('auth/code-expired')) {
        errorMsg = 'Verification code has expired. Please request a new code.';
      } else if (e.toString().contains('auth/invalid-verification-id')) {
        // If verification ID is invalid, we need to restart the verification process
        errorMsg = 'Verification session is invalid. Please restart the verification process.';
        // Reset verification state to force starting over
        _verificationId = null;
      } else {
        errorMsg = 'Verification failed: ${e.toString()}';
      }

      // Update UI state
      setState(() {
        _isLoading = false;
        _loadingMethod = null;
        _errorMessage = errorMsg;
      });
    }
  }

  /// Handle authentication process with different providers
  Future<void> _handleAuthentication(
    AuthMethod method, {
    String? phoneNumber,
    bool forceProfileCompletion = false,
  }) async {
    _logger.i(
      _tag,
      'Starting authentication process for method: $method, forceProfileCompletion: $forceProfileCompletion',
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingMethod = method;
    });

    try {
      // Get AuthProvider from context
      final authProvider = Provider.of<AuthStateProvider>(
        context,
        listen: false,
      );

      // Perform authentication based on the method
      switch (method) {
        case AuthMethod.google:
          // Log authentication attempt with analytics
          _analyticsService.logAuthAttempt(authMethod: 'google');

          try {
            // FIX: Correctly destructure the tuple
            final (userModel, isNewUser) = await authProvider.signInWithGoogle();

            // Track successful login/signup with analytics
            // FIX: Use userModel instead of user
            if (isNewUser) {
              _analyticsService.logSignUp(signUpMethod: 'google');
              _analyticsService.logEvent(
                name: 'new_user_signup',
                parameters: {
                  'auth_method': 'google',
                  'user_id': userModel.uid,
                  'has_email': userModel.email != null,
                },
              );
            } else {
              _analyticsService.logLogin(loginMethod: 'google');
              _analyticsService.logEvent(
                name: 'returning_user_login',
                parameters: {
                  'auth_method': 'google',
                  'user_id': userModel.uid,
                },
              );
            }

            // Track auth success
            // FIX: Use userModel instead of user
            _analyticsService.logAuthSuccess(
              authMethod: 'google',
              userId: userModel.uid,
              isNewUser: isNewUser,
            );

            // For Google authentication, we can force the profile completion if requested
            // This is useful for testing or when we want to ensure a user completes their profile
            if (forceProfileCompletion) {
              // FIX: Use userModel instead of user
              _showProfileCompletionIfNeeded(userModel, true); // Force isNewUser to true
            } else {
              // Proceed to profile completion if needed
              // FIX: Use userModel instead of user
              _showProfileCompletionIfNeeded(userModel, isNewUser);
            }
          } catch (e) {
            // Track auth failure with analytics
            _analyticsService.logAuthFailure(
              authMethod: 'google',
              reason: e.toString(),
            );

            setState(() {
              _isLoading = false;
              _errorMessage = e.toString();
            });
          }
          break;

        case AuthMethod.apple:
          // Log authentication attempt with analytics
          _analyticsService.logAuthAttempt(authMethod: 'apple');

          try {
            // FIX: Correctly destructure the tuple
            final (userModel, isNewUser) = await authProvider.signInWithApple();

            // Track signup or login event based on user status
            // FIX: Use userModel instead of user
            if (isNewUser) {
              _analyticsService.logSignUp(signUpMethod: 'apple');
              _analyticsService.logEvent(
                name: 'new_user_signup',
                parameters: {
                  'auth_method': 'apple',
                  'user_id': userModel.uid,
                  'has_email': userModel.email != null,
                },
              );
            } else {
              _analyticsService.logLogin(loginMethod: 'apple');
              _analyticsService.logEvent(
                name: 'returning_user_login',
                parameters: {
                  'auth_method': 'apple',
                  'user_id': userModel.uid,
                },
              );
            }

            // Track auth success
            // FIX: Use userModel instead of user
            _analyticsService.logAuthSuccess(
              authMethod: 'apple',
              userId: userModel.uid,
              isNewUser: isNewUser,
            );

            // Proceed to profile completion if needed
            // FIX: Use userModel instead of user
            _showProfileCompletionIfNeeded(userModel, isNewUser);
          } catch (e) {
            // Track auth failure with analytics
            _analyticsService.logAuthFailure(
              authMethod: 'apple',
              reason: e.toString(),
            );

            setState(() {
              _isLoading = false;
              _errorMessage = e.toString();
            });
          }
          break;

        case AuthMethod.phone:
          // For phone, initiate verification
          await authProvider.verifyPhoneNumber(
            phoneNumber: phoneNumber!,
            onCodeSent: (String verificationId, int? resendToken) {
              // Log analytics for code sent
              _analyticsService.logEvent(
                name: 'phone_verification_code_sent',
                parameters: {
                  'timestamp': DateTime.now().toIso8601String(),
                },
              );

              // Log debug information
              _logger.i(_tag, 'Verification code sent to $phoneNumber');

              // Update state with verification ID first
              setState(() {
                _verificationId = verificationId;
                _phoneNumber = phoneNumber;
                _isLoading = false;
                _loadingMethod = null;
              });

              // Need to force a rebuild of the bottom sheet
              // Close the current bottom sheet and show a new one with verification UI
              Navigator.of(context).pop();

              // Show new bottom sheet with verification UI after a small delay to ensure state is updated
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  _showAuthOptionsWithVerification();
                }
              });
            },
            onError: (e) {
              // Log analytics for verification failure
              _analyticsService.logEvent(
                name: 'phone_verification_failed',
                parameters: {
                  'error': e.toString(),
                  'timestamp': DateTime.now().toIso8601String(),
                },
              );

              setState(() {
                _isLoading = false;
                _loadingMethod = null;
                _errorMessage = 'Verification failed: ${e.toString()}';
              });
            },
            onVerified: () async {
              setState(() {
                _isLoading = false;
              });

              // When auto-verification happens, we need to explicitly check if the user is new in Firestore
              final user = authProvider.currentUser;
              if (user != null) {
                // Check if new user
                final isNewUser = await authProvider.checkIfUserIsNew(user.uid);
                _showProfileCompletionIfNeeded(user, isNewUser);
              }
            },
          );
          break;
      }
    } catch (e) {
      _logger.e(_tag, 'Authentication error', e);
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Check if the user is already authenticated and route accordingly
  Future<void> _checkAndRouteAuthenticatedUser() async {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      _logger.i(_tag, 'User already authenticated, checking profile status');

      // Explicitly check if this user exists in Firestore
      _logger.d(
        _tag,
        'Checking if user ${user.uid} exists in Firestore',
      );
      final isNewUser = await authProvider.checkIfUserIsNew(user.uid);
      _logger.d(_tag, 'Is user new? $isNewUser');

      // Use the accurate isNewUser flag when determining profile completion needs
      _showProfileCompletionIfNeeded(user, isNewUser);
    }
  }

  /// Check if profile completion is needed and navigate accordingly
  void _showProfileCompletionIfNeeded(
    UserModel user, [
    bool isNewUser = false,
  ]) {
    _logger.i(
      _tag,
      'Starting profile completion check for user ${user.uid}',
    );
    _logger.d(
      _tag,
      'User data - displayName: ${user.displayName}, photoURL: ${user.photoURL}, isNewUser parameter: $isNewUser',
    );

    // Reset loading state first
    setState(() {
      _isLoading = false;
    });

    // Get user information
    final displayName = user.displayName;
    final photoURL = user.photoURL;

    // Log authentication method if available
    final authProvider = user.metadata?['providerId'] as String? ?? 'unknown';
    _logger.d(_tag, 'Auth provider: $authProvider');

    // Only use metadata to determine if new user when explicit isNewUser flag wasn't provided
    // THIS IS THE FIX: Don't override the explicit isNewUser flag from Firestore
    if (!isNewUser && user.metadata != null) {
      final creationTime = user.metadata?['creationTime'] as int?;
      final lastSignInTime = user.metadata?['lastSignInTime'] as int?;

      _logger.d(
        _tag,
        'Metadata - creationTime: $creationTime, lastSignInTime: $lastSignInTime',
      );

      if (creationTime != null && lastSignInTime != null) {
        final timeDifference = (lastSignInTime - creationTime).abs();
        _logger.d(
          _tag,
          'Time difference between creation and sign-in: ${timeDifference}ms',
        );

        // Only consider metadata if we don't have an explicit isNewUser flag
        if (timeDifference < 10000) {
          _logger.d(
            _tag,
            'Metadata indicates possible new user, but using Firestore check result: $isNewUser',
          );
        }
      }
    }

    // Check if user needs profile completion - only required for new users or if profile is incomplete
    bool needsProfileCompletion = isNewUser || !_isProfileComplete(displayName, photoURL);
    String reason = isNewUser
        ? "New user registration - mandatory profile setup"
        : (!_isProfileComplete(displayName, photoURL) ? "Incomplete profile information" : "Profile already complete");

    // Log information about the user's current profile state
    _logger.i(_tag, "Profile completion needed: $needsProfileCompletion. User has display name: ${displayName != null && displayName.isNotEmpty}, has photo: ${photoURL != null}");

    // Log profile completion check
    _analyticsService.logEvent(
      name: 'profile_completion_check',
      parameters: {
        'user_id': user.uid,
        'is_new_user': isNewUser ? 'true' : 'false', // Convert boolean to string
        'needs_completion': needsProfileCompletion ? 'true' : 'false', // Convert boolean to string
        'reason': reason,
        'has_display_name': (displayName != null && displayName.isNotEmpty) ? 'true' : 'false', // Convert boolean to string
        'has_photo': photoURL != null ? 'true' : 'false', // Convert boolean to string
        'auth_provider': user.metadata?['providerId'] as String? ?? 'unknown',
      },
    );

    // Only proceed with profile completion if needed
    if (needsProfileCompletion) {
      // Log navigation to profile completion
      _analyticsService.logEvent(
        name: 'navigate_to_profile_completion',
        parameters: {
          'user_id': user.uid,
          'is_new_user': isNewUser,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Set a user property to track onboarding status
      _analyticsService.setUserProperty(
        name: 'onboarding_status',
        value: 'profile_completion'
      );

      // Navigate to the dedicated profile completion screen
      if (mounted) {
        // Log screen view for analytics
        _analyticsService.logScreenView(
          screenName: 'profile_completion_screen',
          screenClass: 'ProfileCompletionScreen',
        );

        _logger.i(_tag, "Navigating to profile completion screen for user ${user.uid}");

        AppRoutes.navigatorKey.currentState?.pushReplacementNamed(
          AppRoutes.profileCompletion,
        );
      }
    } else {
      // User already has a complete profile, skip profile completion
      _logger.i(_tag, "User ${user.uid} already has a complete profile. Skipping profile completion.");

      // Go directly to home
      AppRoutes.navigatorKey.currentState?.pushReplacementNamed(
        AppRoutes.home,
      );
    }
  }

  /// Complete onboarding
  /// This is a public method that should ONLY be called from the profile completion screen
  /// after a user has successfully completed their profile with required information.
  /// Do not call this method directly from the signup flow - users must complete profile first.
  void completeOnboarding() {
    final currentUserID = Provider.of<AuthStateProvider>(context, listen: false).currentUser?.uid ?? 'unknown';

    _logger.i(_tag, 'Completing onboarding for user: $currentUserID');

    // Log onboarding completion
    _analyticsService.logEvent(
      name: 'onboarding_complete',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'profile_completion', // Changed source to profile_completion
        'user_id': currentUserID,
      },
    );

    // Set user property for completed onboarding
    _analyticsService.setUserProperty(
      name: 'onboarding_status',
      value: 'completed',
    );

    widget.onComplete();
  }

  /// Check if a user's profile is considered complete
  bool _isProfileComplete(String? displayName, String? photoURL) {
    return displayName != null && displayName.isNotEmpty && photoURL != null;
  }

  @override
  Widget build(BuildContext context) {
    // Check platform for platform-specific UI
    final bool isIOS = Platform.isIOS;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          // Use Box decoration instead of gradient for better performance
          color: Colors.black,
        ),
        child: Stack(
          children: [
            // Background
            _buildBackgroundElements(),

            // Main content without animation
            Center(
              child: RepaintBoundary( // Add RepaintBoundary for better performance
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // App logo - Cached for better performance
                    _buildLogo(),

                    const SizedBox(height: 24),

                    // App name text
                    const Text(
                      'DuckBuck',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // App tagline with platform-specific styling
                    Text(
                      'Connect with friends across the globe',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isIOS ? 16 : 17,
                        fontWeight: isIOS ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Get started button with platform-specific styling
                    _buildGetStartedButton(isIOS),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),

            // Notification for errors - positioned at the top
            if (_errorMessage != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NotificationBar(
                  message: _errorMessage!,
                  onDismiss: () {
                    setState(() {
                      _errorMessage = null;
                    });
                  },
                  autoDismiss: true, // Auto-dismiss after 1.5 seconds
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build platform-specific get started button
  Widget _buildGetStartedButton(bool isIOS) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: isIOS
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showAuthOptions,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: _showAuthOptions,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'GET STARTED',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
    );
  }

  // Build logo without animation
  Widget _buildLogo() {
    return RepaintBoundary( // Use RepaintBoundary for better performance
      child: Image.asset(
        'assets/logo.png',
        width: 120,
        height: 120,
        cacheWidth: 240, // Use cacheWidth for better memory management
        cacheHeight: 240,
      ),
    );
  }

  // Optimized background elements
  Widget _buildBackgroundElements() {
    // Use a stateless decoration to avoid rebuilds
    return RepaintBoundary( // Optimize background rendering
      child: Stack(
        children: [
          // Positioned elements for background
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }  // Show auth bottom sheet
  void _showAuthOptions() {
    HapticFeedback.mediumImpact();
    
    // Log analytics event
    _analyticsService.logEvent(
      name: 'signup_flow_started',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Show bottom sheet with platform-specific UI
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      elevation: 0,
      enableDrag: true,
      useSafeArea: true, // Ensures proper insets with notches and rounded screens
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets, // Handle keyboard appearance
        child: AuthBottomSheet(
          onPhoneAuth: _handlePhoneAuth,
          onGoogleAuth: _handleGoogleAuth,
          onAppleAuth: _handleAppleAuth,
          onPhoneAuthCredential: _handlePhoneAuthCredential,
          onError: (message) {
            setState(() {
              _errorMessage = message;
              _isLoading = false; // Ensure loading is stopped on error from bottom sheet
            });
          },
          isLoading: _isLoading,
          loadingMethod: _loadingMethod,
          verificationId: _verificationId,
          phoneNumber: _phoneNumber,
        ),
      ),
    );
  }  // Show auth bottom sheet specifically for OTP verification
  void _showAuthOptionsWithVerification() {
    HapticFeedback.mediumImpact();
    
    // Log that we're showing the verification sheet
    _logger.i(_tag, 'Showing verification sheet for phone: $_phoneNumber, id: $_verificationId');

    // Show bottom sheet with verification UI
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      elevation: 0,
      isDismissible: false, // Prevent dismissal during verification
      enableDrag: false, // Prevent dragging during verification
      useSafeArea: true,
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: AuthBottomSheet(
          // Force phone method to be initially selected for verification screens
          initialAuthMethod: AuthMethod.phone,
          onPhoneAuth: _handlePhoneAuth,
          onGoogleAuth: _handleGoogleAuth,
          onAppleAuth: _handleAppleAuth,
          onPhoneAuthCredential: _handlePhoneAuthCredential,
          onError: (message) {
            setState(() {
              _errorMessage = message;
              _isLoading = false;
            });
          },
          isLoading: _isLoading,
          loadingMethod: _loadingMethod,
          // Pass verification data explicitly
          verificationId: _verificationId,
          phoneNumber: _phoneNumber,
        ),
      ),
    );
  }
}
