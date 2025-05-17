import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/firebase/firebase_analytics_service.dart';
import '../providers/auth_state_provider.dart';

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
      // Get the auth provider and verify OTP
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      final (user, isNewUser) = await authProvider.verifyOtpAndSignIn(
        verificationId: _verificationId!, 
        smsCode: _otpController.text,
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
  
  /// Handle resend code functionality
  void _handleResendCode() {
    HapticFeedback.mediumImpact();
    
    // Log resend code action
    _analytics.logEvent(
      name: 'resend_code_clicked',
      parameters: {
        'source': 'error_snackbar',
        'phone_number_length': _phoneController.text.length,
        'time_since_first_send': DateTime.now().difference(_codeFirstSentTime).inSeconds,
        'resend_count': _codeResendCount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    // Reset OTP field
    _otpController.clear();
    
    // Resend the verification code
    final fullPhoneNumber = "$_countryCode${_phoneController.text}";
    
    setState(() => _isOtpVerificationLoading = true);
    
    // Get auth provider
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    
    // Request new code
    authProvider.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      onCodeSent: (String verificationId, int? resendToken) {
        // Log successful code resend
        _analytics.logEvent(
          name: 'resend_code_success',
          parameters: {
            'source': 'error_snackbar',
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
        // Log resend error
        _analytics.logEvent(
          name: 'resend_code_error',
          parameters: {
            'source': 'error_snackbar',
            'error': error.substring(0, math.min(error.length, 100)),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
        if (mounted) {
          setState(() => _isOtpVerificationLoading = false);
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resend code: $error'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      onVerified: () {
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
    return Container(
      padding: EdgeInsets.only(
        top: screenHeight * 0.02,
        left: 24,
        right: 24,
        bottom: bottomPadding + screenHeight * 0.02,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.whiteOpacity20,
            blurRadius: 10,
            spreadRadius: -5,
          ),
        ],
        border: Border.all(
          color: AppColors.whiteOpacity20,
          width: 1,
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.whiteOpacity20,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Content based on current stage
            if (_currentStage == AuthStage.options) _buildAuthOptions(isIOS),
            if (_currentStage == AuthStage.phoneEntry) _buildPhoneEntryUI(isIOS),
            if (_currentStage == AuthStage.otpVerification) _buildOtpVerificationUI(isIOS),
          ],
        ),
      ),
    );
  }

  // UI for initial auth options
  Widget _buildAuthOptions(bool isIOS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Removed "Continue with" text for more compact UI
        
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        
        // Google sign in
        _buildAuthButton(
          icon: FontAwesomeIcons.google,
          text: 'Continue with Google',
          onPressed: _handleGoogleSignIn,
          isIOS: isIOS,
          iconSize: 20,
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),
        
        SizedBox(height: MediaQuery.of(context).size.height * 0.012),
        
        // Phone sign in
        _buildAuthButton(
          icon: isIOS ? CupertinoIcons.phone : FontAwesomeIcons.phone,
          text: 'Continue with Phone',
          onPressed: _handlePhoneSignIn,
          isIOS: isIOS,
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
        
        SizedBox(height: MediaQuery.of(context).size.height * 0.012),
        
        // Apple sign in
        _buildAuthButton(
          icon: FontAwesomeIcons.apple,
          text: 'Continue with Apple',
          onPressed: _handleAppleSignIn,
          isIOS: isIOS,
          iconSize: 24,
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
        
        SizedBox(height: MediaQuery.of(context).size.height * 0.012),
        
        // Legal information text
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.005),
          child: Text(
            'By continuing, you agree to our Terms of Service and Privacy Policy',
            style: TextStyle(
              color: AppColors.whiteOpacity50,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
      ],
    );
  }

  // UI for phone number entry with improved UX
  Widget _buildPhoneEntryUI(bool isIOS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(
              isIOS ? CupertinoIcons.back : Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: _handleBackPress,
            padding: EdgeInsets.zero,
          ),
        ).animate().fadeIn(duration: 300.ms),
        
        const SizedBox(height: 8),
        
        Text(
          'Enter your phone number',
          style: TextStyle(
            color: Colors.white,
            fontSize: isIOS ? 19 : 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms),
        
        const SizedBox(height: 8),
        
        Text(
          'We\'ll send you a 6-digit verification code',
          style: TextStyle(
            color: AppColors.whiteOpacity50,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        
        const SizedBox(height: 24),
        
        // Phone number input with country code picker
        Container(
          decoration: BoxDecoration(
            color: AppColors.whiteOpacity10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Country code picker
              Container(
                padding: const EdgeInsets.only(left: 8),
                constraints: const BoxConstraints(
                  minWidth: 100, 
                  maxWidth: 110,
                ),
                child: Theme(
                  data: ThemeData.dark().copyWith(
                    primaryColor: Colors.white,
                    scaffoldBackgroundColor: Colors.black,
                    textTheme: const TextTheme(
                      bodyMedium: TextStyle(color: Colors.white),
                    ),
                    dialogTheme: const DialogTheme(
                      backgroundColor: Colors.black,
                      titleTextStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                  child: CountryCodePicker(
                    onChanged: (CountryCode code) {
                      _countryCode = code.dialCode ?? '+1';
                    },
                    initialSelection: 'US',
                    favorite: const ['US', 'IN', 'CA', 'UK'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    flagWidth: 24,
                    textStyle: const TextStyle(color: Colors.white),
                    dialogTextStyle: const TextStyle(color: Colors.white),
                    searchStyle: const TextStyle(color: Colors.white),
                    dialogBackgroundColor: Colors.black,
                    boxDecoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: AppColors.whiteOpacity20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              // Vertical divider
              Container(
                height: 30,
                width: 1,
                color: AppColors.whiteOpacity20,
              ),
              
              // Phone input field
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '(555) 123-4567',
                    hintStyle: TextStyle(color: AppColors.whiteOpacity50),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  autofocus: true,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 24),
        
        // Continue button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isPhoneVerificationLoading ? null : _handlePhoneSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: AppColors.whiteOpacity50,
            ),
            child: _isPhoneVerificationLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black.withOpacity(0.7)),
                    ),
                  )
                : Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
      ],
    );
  }

  // UI for OTP verification
  Widget _buildOtpVerificationUI(bool isIOS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(
              isIOS ? CupertinoIcons.back : Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: _handleBackPress,
            padding: EdgeInsets.zero,
          ),
        ).animate().fadeIn(duration: 300.ms),
        
        const SizedBox(height: 8),
        
        Text(
          'Enter verification code',
          style: TextStyle(
            color: Colors.white,
            fontSize: isIOS ? 19 : 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms),
        
        const SizedBox(height: 8),
        
        Text(
          'We\'ve sent it to $_countryCode ${_phoneController.text}',
          style: TextStyle(
            color: AppColors.whiteOpacity50,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        
        const SizedBox(height: 24),
        
        // OTP input field - updated for 6-digit verification code
        Container(
          decoration: BoxDecoration(
            color: AppColors.whiteOpacity10,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20, // Slightly smaller for better fit with 6 digits
              letterSpacing: 5, // Adjusted letter spacing for 6 digits
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '• • • • • •', // 6 dots for 6 digits
              hintStyle: TextStyle(
                color: AppColors.whiteOpacity50,
                fontSize: 20,
              ),
              border: InputBorder.none,
              counterText: '', // Hide the counter
            ),
            maxLength: 6, // 6-digit verification code
            autofocus: true,
            onChanged: (value) {
              // Auto-submit when all 6 digits are entered
              if (value.length == 6) {
                FocusScope.of(context).unfocus(); // Hide keyboard
              }
            },
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 24),
        
        // Verify button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isOtpVerificationLoading ? null : _handleOtpSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: AppColors.whiteOpacity50,
            ),
            child: _isOtpVerificationLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black.withOpacity(0.7)),
                    ),
                  )
                : Text(
                    'Verify',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
        
        const SizedBox(height: 16),
        
        // Resend code button with improved implementation
        TextButton(
          onPressed: _isOtpVerificationLoading ? null : _handleResendCode,
          child: Text(
            'Resend Code',
            style: TextStyle(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.w600,
              fontSize: isIOS ? 15 : 16,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
      ],
    );
  }

  /// Builds a styled authentication button with clean, minimalist design
  Widget _buildAuthButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    required bool isIOS,
    double iconSize = 22,
  }) {
    // Determine if this specific button is loading
    bool isLoading = false;
    if (text.contains('Google')) {
      isLoading = _isGoogleLoading;
    } else if (text.contains('Apple')) {
      isLoading = _isAppleLoading;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isAnyAuthInProgress ? null : onPressed,
          splashColor: AppColors.whiteOpacity10,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.018),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                ),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isIOS ? FontWeight.w600 : FontWeight.w500,
                    fontSize: isIOS ? 15 : 16,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isLoading)
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
