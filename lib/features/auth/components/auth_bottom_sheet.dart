import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../providers/auth_state_provider.dart';
import '../screens/profile_completion_screen.dart';
import '../../main_navigation.dart';
import 'bottom_sheet_components/index.dart';

// Authentication flow states
enum AuthStage {
  options,
  phoneEntry,
  otpVerification
}

/// A bottom sheet that presents authentication options to the user
/// with animated transitions between auth stages
class AuthBottomSheet extends StatefulWidget {
  /// Function to be called when the user completes the auth process
  final Function() onAuthComplete;
  
  /// Flag to control loading state
  final bool isLoading;

  const AuthBottomSheet({
    super.key,
    required this.onAuthComplete,
    this.isLoading = false,
  });

  /// Show the bottom sheet with authentication options
  static Future<void> show({required BuildContext context, required Function() onAuthComplete}) {
    // Add haptic feedback when sheet appears
    HapticFeedback.mediumImpact();
    
    if (Platform.isIOS) {
      return showCupertinoModalPopup(
        context: context,
        barrierDismissible: false, // Prevent dismissing during verification
        builder: (context) => AuthBottomSheet(
          onAuthComplete: onAuthComplete,
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        isDismissible: false, // Prevent dismissing during verification
        enableDrag: false, // Prevent dragging down during verification
        builder: (context) => AuthBottomSheet(
          onAuthComplete: onAuthComplete,
        ),
      );
    }
  }
  
  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> with SingleTickerProviderStateMixin {
  // Track the current stage of authentication
  AuthStage _currentStage = AuthStage.options;
  
  // Controller for phone number input
  final TextEditingController _phoneController = TextEditingController();
  
  // Controller for OTP input
  final TextEditingController _otpController = TextEditingController();
  
  // Selected country code
  String _countryCode = '+1';
  
  // Verification ID for OTP verification
  String? _verificationId;
  
  // Animation controller for stage transitions
  late final AnimationController _animationController;
  
  // Loading states for different authentication methods
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isPhoneVerificationLoading = false;
  bool _isOtpVerificationLoading = false;
  
  // Resend code cooldown timer
  Timer? _resendTimer;
  int _resendCountdown = 0;
  
  // Helper property to determine if any authentication is in progress
  bool get _isAnyAuthInProgress => 
      _isGoogleLoading || _isAppleLoading || 
      _isPhoneVerificationLoading || _isOtpVerificationLoading;
  
  // Track resend code count
  int _codeResendCount = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }
  
  @override
  void dispose() {
    // Dispose controllers
    _animationController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    // Cancel any active timers to prevent memory leaks
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Handles the Google sign-in process with proper auth service
  void _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    HapticFeedback.mediumImpact();
    
    try {
      // Get auth provider and attempt sign in
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      final (user, isNewUser) = await authProvider.signInWithGoogle();
      
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        Navigator.pop(context);
        
        // Navigate based on whether user is new or returning
        if (isNewUser) {
          // New user goes to profile completion with premium transition
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                const ProfileCompletionScreen(),
              transitionDuration: const Duration(milliseconds: 1000),
              reverseTransitionDuration: const Duration(milliseconds: 800),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Premium morph transition from onboarding to profile completion
                return Stack(
                  children: [
                    // Background gradient transition
                    AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.8 + (animation.value * 0.2)),
                                Colors.blue.shade900.withValues(alpha: animation.value * 0.3),
                                Colors.purple.shade900.withValues(alpha: animation.value * 0.2),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Main content with sophisticated 3D transform
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002) // Enhanced perspective
                        ..rotateX((1 - animation.value) * 0.15) // 3D rotation around X-axis
                        ..rotateY((1 - animation.value) * 0.1) // Slight Y-axis rotation
                        ..scale(
                          0.8 + (animation.value * 0.2), // Scale from 80% to 100%
                        )
                        ..translate(
                          (1 - animation.value) * 50, // Horizontal slide
                          (1 - animation.value) * 100, // Vertical movement
                          (1 - animation.value) * 200, // Z-depth movement
                        ),
                      child: Opacity(
                        opacity: animation.value,
                        child: child,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        } else {
          // Returning user goes to home with different premium transition
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                const MainNavigation(),
              transitionDuration: const Duration(milliseconds: 800),
              reverseTransitionDuration: const Duration(milliseconds: 600),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Fast premium transition for returning users
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..scale(0.9 + (animation.value * 0.1))
                    ..translate(0.0, (1 - animation.value) * 30, 0.0),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
            ),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Handles the transition to phone input UI
  void _handlePhoneSignIn() {
    // Don't proceed if any authentication is already in progress
    if (_isAnyAuthInProgress) return;
    
    HapticFeedback.mediumImpact();
    
    setState(() {
      _currentStage = AuthStage.phoneEntry;
    });
    
    // Play forward transition animation
    _animationController.forward(from: 0.0);
  }

  /// Handles the Apple sign-in process with proper auth service
  void _handleAppleSignIn() async {
    setState(() => _isAppleLoading = true);
    HapticFeedback.mediumImpact();
    
    try {
      // Get auth provider and attempt sign in
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      final (user, isNewUser) = await authProvider.signInWithApple();
      
      if (mounted) {
        setState(() => _isAppleLoading = false);
        Navigator.pop(context);
        
        // Navigate based on whether user is new or returning
        if (isNewUser) {
          // New user goes to profile completion with premium transition
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                const ProfileCompletionScreen(),
              transitionDuration: const Duration(milliseconds: 1000),
              reverseTransitionDuration: const Duration(milliseconds: 800),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Premium morph transition from onboarding to profile completion
                return Stack(
                  children: [
                    // Background gradient transition
                    AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.8 + (animation.value * 0.2)),
                                Colors.blue.shade900.withValues(alpha: animation.value * 0.3),
                                Colors.purple.shade900.withValues(alpha: animation.value * 0.2),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Main content with sophisticated 3D transform
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002) // Enhanced perspective
                        ..rotateX((1 - animation.value) * 0.15) // 3D rotation around X-axis
                        ..rotateY((1 - animation.value) * 0.1) // Slight Y-axis rotation
                        ..scale(
                          0.8 + (animation.value * 0.2), // Scale from 80% to 100%
                        )
                        ..translate(
                          (1 - animation.value) * 50, // Horizontal slide
                          (1 - animation.value) * 100, // Vertical movement
                          (1 - animation.value) * 200, // Z-depth movement
                        ),
                      child: Opacity(
                        opacity: animation.value,
                        child: child,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        } else {
          // Returning user goes to home with different premium transition
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                const MainNavigation(),
              transitionDuration: const Duration(milliseconds: 800),
              reverseTransitionDuration: const Duration(milliseconds: 600),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Fast premium transition for returning users
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..scale(0.9 + (animation.value * 0.1))
                    ..translate(0.0, (1 - animation.value) * 30, 0.0),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
            ),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        setState(() => _isAppleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
  
  /// Handles submission of phone number
  void _handlePhoneSubmit() async {
    // Validate phone number with country code
    final fullPhoneNumber = "$_countryCode${_phoneController.text}";
    

    
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {

      
      // Show validation error
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    
    setState(() => _isPhoneVerificationLoading = true);
    HapticFeedback.mediumImpact();
    
    // Get auth provider
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    
    try {
      // Initiate actual phone verification
      await authProvider.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        onCodeSent: (String verificationId, int? resendToken) {

          
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isPhoneVerificationLoading = false;
              _currentStage = AuthStage.otpVerification;
              _codeResendCount = 0; // Reset resend count
            });
            
            // Start the cooldown timer for the first code
            _startResendCooldown();
            
            // Reset animation and play forward for next transition
            _animationController.reset();
            _animationController.forward();
          }
        },
        onError: (String error) {
          if (mounted) {
            setState(() => _isPhoneVerificationLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification failed: $error'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
        onVerified: () {
          // Auto-verification succeeded, close bottom sheet
          if (mounted) {
            setState(() => _isPhoneVerificationLoading = false);
            Navigator.pop(context);
            widget.onAuthComplete();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPhoneVerificationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
  
  /// Handles verification of OTP
  void _handleOtpSubmit() async {
    // Validate OTP code - enforcing exactly 6 digits
    if (_otpController.text.isEmpty || _otpController.text.length != 6 || !RegExp(r'^\d{6}$').hasMatch(_otpController.text)) {
      // Show error feedback with haptic
      HapticFeedback.heavyImpact();
      
      // Show more specific error message
      String errorMessage = 'Please enter a valid 6-digit code';
      if (_otpController.text.isEmpty) {
        errorMessage = 'Please enter the verification code';
      } else if (_otpController.text.length != 6) {
        errorMessage = 'The verification code must be 6 digits';
      } else if (!RegExp(r'^\d{6}$').hasMatch(_otpController.text)) {
        errorMessage = 'The code should only contain numbers';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    
    setState(() => _isOtpVerificationLoading = true);
    HapticFeedback.mediumImpact();
    
    try {
      // Get full phone number with country code for rate limiting check
      final fullPhoneNumber = "$_countryCode${_phoneController.text}";
      
      // Get auth provider and verify OTP
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      final (user, isNewUser) = await authProvider.verifyOtpAndSignIn(
        verificationId: _verificationId!, 
        smsCode: _otpController.text,
        phoneNumber: fullPhoneNumber,
      );
      
      if (mounted) {
        setState(() => _isOtpVerificationLoading = false);
        Navigator.pop(context);
        
        // Navigate based on whether user is new or returning
        if (isNewUser) {
          Navigator.pushReplacementNamed(context, AppRoutes.profileCompletion);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      // Extract meaningful error message
      String errorMessage = 'Verification failed';
      String errorCode = 'unknown';
      
      // Extract error code from error message if possible
      if (e.toString().contains('invalid-verification-code')) {
        errorMessage = 'Invalid verification code';
        errorCode = 'invalid-verification-code';
      } else if (e.toString().contains('session-expired') || e.toString().contains('code-expired')) {
        errorMessage = 'Verification code expired';
        errorCode = 'code-expired';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error, please check your connection';
        errorCode = 'network-error';
      }
      
      if (mounted) {
        setState(() => _isOtpVerificationLoading = false);
        
        // Show user-friendly error message with option to resend if code expired
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
            action: errorCode == 'code-expired' ? SnackBarAction(
              label: 'Resend',
              textColor: Colors.white,
              onPressed: _handleResendCode,
            ) : null,
          ),
        );
      }
    }
  }
  
  /// Start countdown timer for resend cooldown
  void _startResendCooldown() {
    // Cancel any existing timer
    _resendTimer?.cancel();
    
    // Set initial countdown time (30 seconds)
    setState(() => _resendCountdown = 30);
    
    // Create a new timer that ticks every second
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        // When countdown reaches 0, cancel the timer
        timer.cancel();
      }
    });
  }
  
  /// Handle resend code functionality
  void _handleResendCode() {
    // Don't allow resend if already loading, in cooldown, or too many attempts
    if (_isOtpVerificationLoading || _resendCountdown > 0 || _codeResendCount > 2) return;
    
    HapticFeedback.mediumImpact();
    
    // Reset OTP field to avoid confusion with old code
    _otpController.clear();
    
    // Resend the verification code
    final fullPhoneNumber = "$_countryCode${_phoneController.text}";
    
    // Set loading state
    setState(() => _isOtpVerificationLoading = true);
    
    // Get auth provider
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    
    // Add a safety timeout to ensure loading state doesn't get stuck
    Timer safetyTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _isOtpVerificationLoading) {
        setState(() => _isOtpVerificationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    
    // Request new code
    authProvider.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      onCodeSent: (String verificationId, int? resendToken) {
        // Cancel safety timer since we got a response
        safetyTimer.cancel();
        

        
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isOtpVerificationLoading = false;
            _codeResendCount += 1;
          });
          
          // Start cooldown timer after successful resend
          _startResendCooldown();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code resent'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onError: (String error) {
        // Cancel safety timer since we got a response
        safetyTimer.cancel();
        

        
        if (mounted) {
          setState(() => _isOtpVerificationLoading = false);
          
          // Show user-friendly error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resend code: $error'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      onVerified: () {
        // Cancel safety timer since we got a response
        safetyTimer.cancel();
        
        // Auto-verification succeeded
        if (mounted) {
          setState(() => _isOtpVerificationLoading = false);
          Navigator.pop(context);
          widget.onAuthComplete();
        }
      },
    );
  }
  
  /// Handles back navigation between stages
  void _handleBackPress() {
    HapticFeedback.lightImpact();
    

    
    if (_currentStage == AuthStage.otpVerification) {
      setState(() => _currentStage = AuthStage.phoneEntry);
      _animationController.reverse();
    } else if (_currentStage == AuthStage.phoneEntry) {
      setState(() => _currentStage = AuthStage.options);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Shared content
    Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _currentStage == AuthStage.options
        ? _buildAuthOptions(isIOS)
        : _currentStage == AuthStage.phoneEntry
          ? _buildPhoneEntryUI(isIOS)
          : _buildOtpVerificationUI(isIOS),
    );
    
    // Shared header - with empty title for auth options, only showing title for phone/OTP screens
    Widget header = BottomSheetHeader(
      title: _currentStage == AuthStage.options ? '' : 
             _currentStage == AuthStage.phoneEntry ? 'Verify Phone' :
             'Enter OTP',
      subtitle: null,
      showCloseButton: false,
    );
    
    // Calculate responsive padding based on screen size
    final double horizontalPadding = screenHeight * 0.03;
    final double topPadding = screenHeight * 0.02;
    final double bottomPaddingValue = bottomPadding + screenHeight * 0.03;
    
    if (isIOS) {
      // iOS-specific container styling with CupertinoTheme
      return CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.accentBlue,
        ),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding,
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: bottomPaddingValue,
          ),
          decoration: BoxDecoration(
            color: AppColors.pureBlack,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.whiteOpacity20,
              width: 0.5,
            ),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center, // Center content
              children: [
                header,
                content,
              ],
            ),
          ),
        ),
      );
    } else {
      // Android-specific container styling with Material theming
      return Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.dark(
            primary: AppColors.accentBlue,
            secondary: AppColors.accentBlue,
            surface: Colors.black,
          ),
        ),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding,
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: bottomPaddingValue,
          ),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.whiteOpacity20,
                blurRadius: 10,
                spreadRadius: -5,
              ),
            ],
            border: Border.all(
              color: AppColors.whiteOpacity20,
              width: 0.5,
            ),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center, // Center content
              children: [
                header,
                content,
              ],
            ),
          ),
        ),
      );
    }
  }

  // UI for initial auth options
  Widget _buildAuthOptions(bool isIOS) {
    return AuthOptionsView(
      onGoogleSelected: _handleGoogleSignIn,
      onAppleSelected: _handleAppleSignIn,
      onPhoneSelected: _handlePhoneSignIn,
      isGoogleLoading: _isGoogleLoading,
      isAppleLoading: _isAppleLoading,
    ).animate().fadeIn(duration: 400.ms);
  }

  // UI for phone number entry with improved UX
  Widget _buildPhoneEntryUI(bool isIOS) {
    return PhoneVerificationView(
      phoneController: _phoneController,
      countryCode: _countryCode,
      onCountryCodeChanged: (code) {
        setState(() {
          _countryCode = code;
        });
      },
      onVerifyPressed: _handlePhoneSubmit,
      onBackPressed: _handleBackPress,
      isLoading: _isPhoneVerificationLoading,
    ).animate().fadeIn(duration: 400.ms);
  }

  // UI for OTP verification
  Widget _buildOtpVerificationUI(bool isIOS) {
    final fullPhoneNumber = "$_countryCode ${_phoneController.text}";
    
    // Use a separate state variable for the resend button to avoid the infinite loading issue
    final bool isResendButtonDisabled = _isOtpVerificationLoading || _resendCountdown > 0 || _codeResendCount > 2;
    
    // Prepare countdown text if timer is active
    String? resendText;
    if (_codeResendCount > 2) {
      resendText = 'Try again later';
    } else if (_resendCountdown > 0) {
      resendText = 'Resend in ${_resendCountdown}s';
    }
    
    return OtpVerificationView(
      otpController: _otpController,
      phoneNumber: fullPhoneNumber,
      onVerifyPressed: _handleOtpSubmit,
      onResendPressed: _handleResendCode,
      onBackPressed: _handleBackPress,
      isLoading: _isOtpVerificationLoading,
      isResendDisabled: isResendButtonDisabled,
      resendCountdownText: resendText,
    ).animate().fadeIn(duration: 400.ms);
  }
 
}
