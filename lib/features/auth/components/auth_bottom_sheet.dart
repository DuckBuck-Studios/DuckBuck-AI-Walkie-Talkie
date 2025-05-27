import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/firebase/firebase_analytics_service.dart';
import '../providers/auth_state_provider.dart';
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
  
  // Track when the code was first sent
  DateTime _codeFirstSentTime = DateTime.now();
  
  // Track resend code count
  int _codeResendCount = 0;
  
  // Analytics service
  late final FirebaseAnalyticsService _analytics;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize services
    _analytics = serviceLocator<FirebaseAnalyticsService>();
    
    // Initialize animation controller for transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Log sheet opened event
    _logBottomSheetOpened();
  }
  
  void _logBottomSheetOpened() {
    _analytics.logEvent(
      name: 'auth_sheet_opened',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
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
    
    // Log Google sign-in attempt from UI
    _analytics.logEvent(
      name: 'auth_google_button_clicked',
      parameters: {
        'source': 'auth_bottom_sheet',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    try {
      // Get auth provider and attempt sign in
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      final (user, isNewUser) = await authProvider.signInWithGoogle();
      
      // Log successful Google sign-in UI flow completion
      _analytics.logEvent(
        name: 'auth_google_success_ui',
        parameters: {
          'is_new_user': isNewUser ? '1' : '0',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        Navigator.pop(context);
        
        // Navigate based on whether user is new or returning
        if (isNewUser) {
          // Log new user flow start
          _analytics.logEvent(
            name: 'profile_completion_navigation',
            parameters: {
              'auth_method': 'google',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          // New user goes to profile completion
          Navigator.pushReplacementNamed(context, AppRoutes.profileCompletion);
        } else {
          // Log returning user flow
          _analytics.logEvent(
            name: 'home_screen_navigation',
            parameters: {
              'auth_method': 'google',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          // Returning user goes to home
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      // Log failed Google sign-in UI flow
      _analytics.logEvent(
        name: 'auth_google_failure_ui',
        parameters: {
          'error': e.toString().substring(0, math.min(e.toString().length, 100)),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
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
    
    // Log phone auth method selection
    _analytics.logEvent(
      name: 'auth_phone_button_clicked',
      parameters: {
        'source': 'auth_bottom_sheet',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
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
    
    // Log Apple sign-in attempt from UI
    _analytics.logEvent(
      name: 'auth_apple_button_clicked',
      parameters: {
        'source': 'auth_bottom_sheet',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    try {
      // Get auth provider and attempt sign in
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      final (user, isNewUser) = await authProvider.signInWithApple();
      
      // Log successful Apple sign-in UI flow completion
      _analytics.logEvent(
        name: 'auth_apple_success_ui',
        parameters: {
          'is_new_user': isNewUser ? '1' : '0',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        setState(() => _isAppleLoading = false);
        Navigator.pop(context);
        
        // Navigate based on whether user is new or returning
        if (isNewUser) {
          // Log new user flow start
          _analytics.logEvent(
            name: 'profile_completion_navigation',
            parameters: {
              'auth_method': 'apple',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          // New user goes to profile completion
          Navigator.pushReplacementNamed(context, AppRoutes.profileCompletion);
        } else {
          // Log returning user flow
          _analytics.logEvent(
            name: 'home_screen_navigation',
            parameters: {
              'auth_method': 'apple',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          // Returning user goes to home
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      // Log failed Apple sign-in UI flow
      _analytics.logEvent(
        name: 'auth_apple_failure_ui',
        parameters: {
          'error': e.toString().substring(0, math.min(e.toString().length, 100)),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
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
    
    // Log phone submission attempt
    _analytics.logEvent(
      name: 'phone_number_submit',
      parameters: {
        'country_code': _countryCode,
        'phone_length': _phoneController.text.length.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
      // Log validation error
      _analytics.logEvent(
        name: 'phone_validation_failed',
        parameters: {
          'reason': 'too_short',
          'length': _phoneController.text.length.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
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
          // Log code sent success
          _analytics.logEvent(
            name: 'verification_code_sent',
            parameters: {
              'has_resend_token': resendToken != null ? '1' : '0',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isPhoneVerificationLoading = false;
              _currentStage = AuthStage.otpVerification;
              _codeFirstSentTime = DateTime.now(); // Set first sent time
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
          // Log verification error
          _analytics.logEvent(
            name: 'phone_verification_error',
            parameters: {
              'error': error.substring(0, math.min(error.length, 100)),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          
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
          // Log auto-verification success
          _analytics.logEvent(
            name: 'auto_verification_success',
            parameters: {
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          
          // Auto-verification succeeded, close bottom sheet
          if (mounted) {
            setState(() => _isPhoneVerificationLoading = false);
            Navigator.pop(context);
            widget.onAuthComplete();
          }
        },
      );
    } catch (e) {
      // Log verification exception
      _analytics.logEvent(
        name: 'phone_verification_exception',
        parameters: {
          'error': e.toString().substring(0, math.min(e.toString().length, 100)),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
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
    // Log OTP submission attempt
    _analytics.logEvent(
      name: 'otp_submission_attempt',
      parameters: {
        'otp_length': _otpController.text.length.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    // Validate OTP code - enforcing exactly 6 digits
    if (_otpController.text.isEmpty || _otpController.text.length != 6 || !RegExp(r'^\d{6}$').hasMatch(_otpController.text)) {
      // Log validation failure with specific reason
      _analytics.logEvent(
        name: 'otp_validation_failed',
        parameters: {
          'reason': _otpController.text.isEmpty ? 'empty_code' : 
                    _otpController.text.length != 6 ? 'invalid_length' : 'non_numeric',
          'entered_length': _otpController.text.length.toString(),
          'required_length': '6',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
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
      
      // Log successful OTP verification at UI level
      _analytics.logEvent(
        name: 'otp_verification_success_ui',
        parameters: {
          'is_new_user': isNewUser ? '1' : '0',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        setState(() => _isOtpVerificationLoading = false);
        Navigator.pop(context);
        
        // Navigate based on whether user is new or returning
        if (isNewUser) {
          // Log new user flow
          _analytics.logEvent(
            name: 'profile_completion_navigation',
            parameters: {
              'auth_method': 'phone',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          Navigator.pushReplacementNamed(context, AppRoutes.profileCompletion);
        } else {
          // Log returning user flow
          _analytics.logEvent(
            name: 'home_screen_navigation',
            parameters: {
              'auth_method': 'phone',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
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
      
      // Log OTP verification failure with detailed parameters
      _analytics.logEvent(
        name: 'otp_verification_failure_ui',
        parameters: {
          'error_message': e.toString().substring(0, math.min(e.toString().length, 100)),
          'error_code': errorCode,
          'otp_length': _otpController.text.length.toString(),
          'resend_count': _codeResendCount,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
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
    
    // Log resend code action with proper source
    _analytics.logEvent(
      name: 'resend_code_clicked',
      parameters: {
        'source': 'resend_button',
        'phone_number_length': _phoneController.text.length,
        'time_since_first_send': DateTime.now().difference(_codeFirstSentTime).inSeconds,
        'resend_count': _codeResendCount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
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
        
        // Log successful code resend
        _analytics.logEvent(
          name: 'resend_code_success',
          parameters: {
            'source': 'resend_button',
            'has_resend_token': resendToken != null ? '1' : '0',
            'phone_country_code': _countryCode,
            'resend_count': _codeResendCount + 1,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
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
        
        // Log resend error
        _analytics.logEvent(
          name: 'resend_code_error',
          parameters: {
            'source': 'resend_button',
            'error': error.substring(0, math.min(error.length, 100)),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
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
    
    // Log back button press with current stage info
    _analytics.logEvent(
      name: 'auth_back_pressed',
      parameters: {
        'from_stage': _currentStage.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
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
          primaryColor: CupertinoColors.activeBlue,
        ),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding,
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: bottomPaddingValue,
          ),
          decoration: BoxDecoration(
            color: CupertinoColors.black,
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

  // Legacy auth button implementation removed as it's now handled by AuthOptionsView
}
