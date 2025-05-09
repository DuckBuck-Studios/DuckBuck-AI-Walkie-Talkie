import 'package:duckbuck/core/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../components/auth_bottom_sheet.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/firebase/firebase_analytics_service.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Services
  late final FirebaseAnalyticsService _analyticsService;

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    // Add haptic feedback when screen appears with stronger impact for final screen
    HapticFeedback.heavyImpact();

    // Initialize services
    _analyticsService = serviceLocator<FirebaseAnalyticsService>();

    // Check if the user is already authenticated and route accordingly
    _checkAndRouteAuthenticatedUser();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Handle email/password login
  Future<void> _handleEmailLogin(String email, String password) async {
    // Don't require email verification - allow users to sign in regardless of verification status
    await _handleAuthentication(
      AuthMethod.email,
      email: email,
      password: password,
      requireEmailVerification:
          false, // Set to false to allow login without email verification
    );
  }

  /// Handle phone authentication
  Future<void> _handlePhoneAuth(String phoneNumber) async {
    await _handleAuthentication(AuthMethod.phone, phoneNumber: phoneNumber);
  }

  /// Handle Google authentication
  Future<void> _handleGoogleAuth() async {
    debugPrint('🔍 SIGNUP SCREEN: Google auth button pressed');
    // Don't force profile completion - properly check if user is new
    await _handleAuthentication(AuthMethod.google);
  }

  /// Handle Apple authentication
  Future<void> _handleAppleAuth() async {
    debugPrint('🔍 SIGNUP SCREEN: Apple auth button pressed');
    await _handleAuthentication(AuthMethod.apple);
  }

  /// Handle phone auth credential verification
  Future<void> _handlePhoneAuthCredential(dynamic credential) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthStateProvider>(
        context,
        listen: false,
      );
      final (user, isNewUser) = await authProvider
          .signInWithPhoneAuthCredential(credential);

      // Track signup/login event with analytics
      _analyticsService.logLogin(loginMethod: 'phone');

      // Reset verification state
      setState(() {
        _verificationId = null;
        _phoneNumber = null;
        _isLoading = false;
      });

      // Check if user needs profile completion with explicit isNewUser flag
      _showProfileCompletionIfNeeded(user, isNewUser);
    } catch (e) {
      debugPrint('🔍 SIGNUP SCREEN: Phone auth verification error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Handle authentication process with different providers
  Future<void> _handleAuthentication(
    AuthMethod method, {
    String? email,
    String? password,
    String? phoneNumber,
    bool requireEmailVerification = false,
    bool forceProfileCompletion = false, // New parameter to force profile completion
  }) async {
    debugPrint(
      '🔍 SIGNUP SCREEN: Starting authentication process for method: $method, forceProfileCompletion: $forceProfileCompletion',
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
        case AuthMethod.email:
          debugPrint('🔍 SIGNUP SCREEN: Processing email auth');
          if (email != null && password != null) {
            // Email auth logic
          }
          break;

        case AuthMethod.google:
          debugPrint('🔍 SIGNUP SCREEN: Starting Google auth flow...');
          try {
            final (user, isNewUser) = await authProvider.signInWithGoogle();
            debugPrint(
              '🔍 SIGNUP SCREEN: Google sign-in successful, user: ${user.email}, isNewUser: $isNewUser',
            );

            // Track signup/login event with analytics
            _analyticsService.logLogin(loginMethod: 'google');

            // For Google authentication, we can force the profile completion if requested
            // This is useful for testing or when we want to ensure a user completes their profile
            if (forceProfileCompletion) {
              debugPrint('🔍 SIGNUP SCREEN: Forcing profile completion for Google user');
              _showProfileCompletionIfNeeded(user, true); // Force isNewUser to true
            } else {
              // Proceed to profile completion if needed
              _showProfileCompletionIfNeeded(user, isNewUser);
            }
          } catch (e) {
            debugPrint(
              '🔍 SIGNUP SCREEN: Google sign-in failed with error: $e',
            );
            setState(() {
              _isLoading = false;
              _errorMessage = e.toString();
            });
          }
          break;

        case AuthMethod.apple:
          debugPrint('🔍 SIGNUP SCREEN: Processing Apple auth');
          try {
            final (user, isNewUser) = await authProvider.signInWithApple();
            debugPrint(
              '🔍 SIGNUP SCREEN: Apple sign-in successful, user: ${user.email ?? "unknown email"}, isNewUser: $isNewUser',
            );

            // Track signup/login event with analytics
            _analyticsService.logLogin(loginMethod: 'apple');

            // Proceed to profile completion if needed
            _showProfileCompletionIfNeeded(user, isNewUser);
          } catch (e) {
            debugPrint('🔍 SIGNUP SCREEN: Apple sign-in failed with error: $e');
            setState(() {
              _isLoading = false;
              _errorMessage = e.toString();
            });
          }
          break;

        case AuthMethod.phone:
          debugPrint('🔍 SIGNUP SCREEN: Processing Phone auth');
          if (phoneNumber != null) {
            try {
              // Start phone verification with callbacks
              await authProvider.verifyPhoneNumber(
                phoneNumber: phoneNumber,
                onCodeSent: (String verificationId, int? resendToken) {
                  debugPrint('🔍 SIGNUP SCREEN: SMS code sent to $phoneNumber');

                  // Store verification ID and phone number
                  setState(() {
                    _verificationId = verificationId;
                    _phoneNumber = phoneNumber;
                    _isLoading = false;
                  });
                },
                onError: (String errorMessage) {
                  debugPrint(
                    '🔍 SIGNUP SCREEN: Phone auth error - $errorMessage',
                  );
                  setState(() {
                    _isLoading = false;
                    _errorMessage = errorMessage;
                  });
                },
                onVerified: () async {
                  // This is called when the phone is auto-verified
                  debugPrint('🔍 SIGNUP SCREEN: Phone automatically verified');
                  setState(() {
                    _isLoading = false;
                  });

                  // When auto-verification happens, we need to explicitly check if the user is new in Firestore
                  final user = authProvider.currentUser;
                  if (user != null) {
                    _analyticsService.logLogin(loginMethod: 'phone');

                    // Use AuthStateProvider's public method to check if user is new
                    print(
                      '🔍 AUTO VERIFY: Explicitly checking if user ${user.uid} exists in Firestore',
                    );
                    final isNewUser = await authProvider.checkIfUserIsNew(
                      user.uid,
                    );
                    print('🔍 AUTO VERIFY: User is new? $isNewUser');

                    _showProfileCompletionIfNeeded(user, isNewUser);
                  }
                },
              );
            } catch (e) {
              debugPrint('🔍 SIGNUP SCREEN: Phone verification error: $e');
              setState(() {
                _isLoading = false;
                _errorMessage = e.toString();
              });
            }
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Phone number is required';
            });
          }
          break;

        case AuthMethod.signup:
          debugPrint('🔍 SIGNUP SCREEN: Processing signup');
          // Signup logic
          break;
      }
    } catch (e) {
      debugPrint('🔍 SIGNUP SCREEN: Authentication error: $e');
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
      debugPrint(
        '🔍 SIGNUP SCREEN: User already authenticated, checking profile status',
      );

      // Explicitly check if this user exists in Firestore
      print(
        '🔍 STARTUP CHECK: Checking if user ${user.uid} exists in Firestore',
      );
      final isNewUser = await authProvider.checkIfUserIsNew(user.uid);
      print('🔍 STARTUP CHECK: Is user new? $isNewUser');

      // Use the accurate isNewUser flag when determining profile completion needs
      _showProfileCompletionIfNeeded(user, isNewUser);
    }
  }

  /// Check if profile completion is needed and navigate accordingly
  void _showProfileCompletionIfNeeded(
    UserModel user, [
    bool isNewUser = false,
  ]) {
    print(
      '🔍 PROFILE CHECK: Starting profile completion check for user ${user.uid}',
    );
    print(
      '🔍 PROFILE CHECK: User data - displayName: ${user.displayName}, photoURL: ${user.photoURL}, isNewUser parameter: $isNewUser',
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
    print('🔍 PROFILE CHECK: Auth provider: $authProvider');

    // Only use metadata to determine if new user when explicit isNewUser flag wasn't provided
    // THIS IS THE FIX: Don't override the explicit isNewUser flag from Firestore
    if (!isNewUser && user.metadata != null) {
      final creationTime = user.metadata?['creationTime'] as int?;
      final lastSignInTime = user.metadata?['lastSignInTime'] as int?;

      print(
        '🔍 PROFILE CHECK: Metadata - creationTime: $creationTime, lastSignInTime: $lastSignInTime',
      );

      if (creationTime != null && lastSignInTime != null) {
        final timeDifference = (lastSignInTime - creationTime).abs();
        print(
          '🔍 PROFILE CHECK: Time difference between creation and sign-in: ${timeDifference}ms',
        );

        // Only consider metadata if we don't have an explicit isNewUser flag
        if (timeDifference < 10000) {
          print(
            '🔍 PROFILE CHECK: Metadata indicates possible new user, but using Firestore check result: $isNewUser',
          );
        }
      }
    }

    // ROBUST LOGIC: Different handling for new vs returning users
    bool needsProfileCompletion;
    String reason = "";

    if (isNewUser) {
      // For new users: ALWAYS show profile completion regardless of whether they have info from providers
      // This ensures all new users go through the profile setup flow
      needsProfileCompletion = true;
      reason = "New user registration - mandatory profile setup";
    } else {
      // For existing users:
      // Only show profile completion if essential information is missing
      bool hasMissingInfo =
          displayName == null || displayName.isEmpty || photoURL == null;
      needsProfileCompletion = hasMissingInfo;

      if (hasMissingInfo) {
        if (displayName == null || displayName.isEmpty) {
          reason = "Missing display name";
        } else if (photoURL == null)
          reason = "Missing profile photo";
      } else {
        reason = "Returning user with complete profile";
      }
    }

    print(
      '🔍 PROFILE CHECK: Final decision - needsProfileCompletion: $needsProfileCompletion',
    );
    print('🔍 PROFILE CHECK: Reason: $reason');

    if (needsProfileCompletion) {
      print('🔍 PROFILE CHECK: Navigating to profile completion screen');

      // Navigate to the dedicated profile completion screen
      if (mounted) {
        AppRoutes.navigatorKey.currentState?.pushReplacementNamed(
          AppRoutes.profileCompletion,
        );
      }
    } else {
      print('🔍 PROFILE CHECK: Profile complete, proceeding to dashboard');
      _completeOnboarding();
    }
  }

  /// Complete onboarding
  void _completeOnboarding() {
    debugPrint(
      '🔍 SIGNUP SCREEN: Completing onboarding, calling onComplete callback',
    );
    widget.onComplete();
  }

  /// Dismiss the error notification
  void _dismissError() {
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content (Logo, Title, Spacers)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3), // Adjust flex for spacing
                  // Logo with animation
                  SizedBox(
                    width: size.width * 0.4, // Adjust size as needed
                    height: size.width * 0.4,
                    child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: ClipOval(
                            child: Container(
                              padding: const EdgeInsets.all(
                                8,
                              ), // Padding inside oval
                              color: Colors.black, // Background for the oval
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.currency_exchange_rounded,
                                    size: size.width * 0.15,
                                    color: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 2500.ms,
                          color: Colors.white.withOpacity(0.8),
                          size: 3,
                        ),
                  ),

                  const SizedBox(height: 40),

                  // Centered Join DuckBuck text - ALWAYS VISIBLE
                  const Center(
                    child: Text(
                      'Join DuckBuck',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // REMOVED the error message Text widget from here

                  // Equal spacer to center the content vertically
                  const Spacer(flex: 2),

                  // Space for the bottom sheet height plus safe area
                  SizedBox(height: size.height * 0.33 + bottomPadding + 20),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),

          // Bottom sheet positioned directly in place
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AuthBottomSheet(
              key: const ValueKey('auth_bottom_sheet'),
              isLoading: _isLoading,
              loadingMethod: _loadingMethod,
              onLogin: _handleEmailLogin,
              onPhoneAuth: _handlePhoneAuth,
              onGoogleAuth: _handleGoogleAuth,
              onAppleAuth: _handleAppleAuth,
              onPhoneAuthCredential: _handlePhoneAuthCredential,
              verificationId: _verificationId,
              phoneNumber: _phoneNumber,
              onError: (String errorMessage) {
                setState(() {
                  _errorMessage = errorMessage;
                });
              },
              onVerified: (UserModel user) async {
                _analyticsService.logLogin(loginMethod: 'phone');

                // Explicitly check if this user exists in Firestore
                final authProvider = Provider.of<AuthStateProvider>(
                  context,
                  listen: false,
                );
                print(
                  '🔍 BOTTOM SHEET VERIFY: Checking if user ${user.uid} exists in Firestore',
                );
                final isNewUser = await authProvider.checkIfUserIsNew(user.uid);
                print('🔍 BOTTOM SHEET VERIFY: User is new? $isNewUser');

                _showProfileCompletionIfNeeded(user, isNewUser);
              },
            ),
          ),

          // Notification Bar at the bottom (conditionally shown)
          if (_errorMessage != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: NotificationBar(
                message: _errorMessage!,
                onDismiss: _dismissError,
              ),
            ),
        ],
      ),
    );
  }
}
