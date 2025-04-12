import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart' as auth;

// Status types for user feedback
enum StatusType {
  none,
  success,
  error,
  info,
}

class PhoneAuthPopup extends StatefulWidget {
  final Function(String phoneNumber)? onSubmit;
  final Color? primaryColor;
  final Color? secondaryColor;

  const PhoneAuthPopup({
    super.key,
    this.onSubmit,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<PhoneAuthPopup> createState() => _PhoneAuthPopupState();
}

class _PhoneAuthPopupState extends State<PhoneAuthPopup> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  final _smsFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isCodeSent = false;
  String _countryCode = '+1';
  String? _verificationId;
  int _timer = 60;
  bool _resendEnabled = false;
  Timer? _resendTimer;
  
  String? _statusMessage;
  StatusType _statusType = StatusType.none;
  late AnimationController _animationController;
  
  // Maps for status icons and colors
  final Map<StatusType, IconData> _statusIconMap = {
    StatusType.none: Icons.info_outline,
    StatusType.success: Icons.check_circle_outline,
    StatusType.error: Icons.error_outline,
    StatusType.info: Icons.info_outline,
  };
  
  final Map<StatusType, Color> _statusColorMap = {
    StatusType.none: Colors.grey,
    StatusType.success: Colors.green,
    StatusType.error: Colors.red,
    StatusType.info: Colors.blue,
  };
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Set up SMS auto-detection
    _smsFocusNode.addListener(() {
      if (_smsFocusNode.hasFocus) {
        // This helps trigger the SMS retriever API on Android
        _smsController.selection = TextSelection.fromPosition(
          TextPosition(offset: _smsController.text.length),
        );
      }
    });
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    _smsFocusNode.dispose();
    _resendTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  
  // Start the cooldown timer for resending the code
  void _startTimer() {
    setState(() {
      _timer = 60;
      _resendEnabled = false;
    });
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timer > 0) {
          _timer--;
        } else {
          _resendEnabled = true;
          timer.cancel();
        }
      });
    });
  }

  // Helper method to set status messages
  void _setStatus(String? message, StatusType type) {
    setState(() {
      _statusMessage = message;
      _statusType = message == null ? StatusType.none : type;
    });
  }

  // Validate phone number format
  bool _isValidPhoneNumber(String number) {
    // Basic validation: allow digits, spaces, dashes, and parentheses
    final validChars = RegExp(r'^[0-9\s\-\(\)]+$');
    return validChars.hasMatch(number) && number.replaceAll(RegExp(r'[\s\-\(\)]'), '').length >= 7;
  }

  // Send verification code to the phone
  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Trim to handle any unwanted spaces
    final phoneNumber = _phoneController.text.trim();
    
    // Check valid formatting
    if (!_isValidPhoneNumber(phoneNumber)) {
      _setStatus('Please enter a valid phone number', StatusType.error);
      return;
    }

    // Provide user feedback through haptics and status
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _statusType = StatusType.none;
    });

    try {
      // Get the auth provider with listen: false to avoid rebuilds during the operation
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Format full phone number with country code
      final fullPhoneNumber = '$_countryCode${phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '')}';
      
      // Request verification code
      await authProvider.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: _handleVerificationCompleted,
        verificationFailed: _handleVerificationFailed,
        codeSent: _handleCodeSent,
        codeAutoRetrievalTimeout: _handleCodeAutoRetrievalTimeout,
      );
      
    } catch (e) {
      _setStatus('Unable to send verification code. Please try again.', StatusType.error);
      debugPrint('Verification code error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Verify SMS code entered by user
  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate code format
    final verificationCode = _smsController.text.trim();
    if (verificationCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(verificationCode)) {
      _setStatus('Please enter a valid 6-digit verification code', StatusType.error);
      return;
    }

    // Provide user feedback
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _statusType = StatusType.none;
    });

    try {
      // Get the auth provider with listen: false to avoid rebuilds
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Attempt to sign in with the provided code
      await authProvider.signInWithPhoneNumber(_verificationId!, verificationCode);

      // Successful verification - provide feedback with haptics
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        // Close the dialog with successful animation
        _animationController.forward().then((_) {
          Navigator.of(context).pop();
          // Notify parent widget with phone number if callback provided
          if (widget.onSubmit != null) {
            widget.onSubmit!('$_countryCode${_phoneController.text.trim()}');
          }
        });
      }
    } catch (e) {
      // Convert backend errors to user-friendly messages
      String errorMessage = 'Invalid verification code. Please try again.';
      
      if (e is FirebaseException) {
        if (e.code == 'session-expired') {
          errorMessage = 'Your verification session has expired. Please request a new code.';
        } else if (e.code == 'invalid-verification-code') {
          errorMessage = 'The code you entered is incorrect. Please try again.';
        }
      }
      
      _setStatus(errorMessage, StatusType.error);
      debugPrint('Verification failed: $e');
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle automatic verification (when device auto-detects SMS)
  void _handleVerificationCompleted(PhoneAuthCredential credential) async {
    setState(() {
      _isCodeSent = true;
    });

    // Only proceed if we're still mounted and waiting for verification
    if (!mounted || !_isCodeSent) return;

    try {
      // If SMS code is available from credential, update the text field
      if (credential.smsCode != null) {
        setState(() {
          _smsController.text = credential.smsCode!;
          _setStatus('Code auto-detected!', StatusType.success);
        });
        
        // Brief pause to show the detected code before proceeding
        await Future.delayed(const Duration(milliseconds: 800));
      }
      
      // Only proceed with auto-verification if we have an SMS code
      if (credential.smsCode != null && mounted) {
        setState(() {
          _isLoading = true;
        });
        
        // Get the auth provider
        final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
        
        try {
          // Try to sign in with the auto-detected code
          await authProvider.signInWithPhoneNumber(_verificationId!, credential.smsCode!);
          
          // Success - provide feedback
          HapticFeedback.heavyImpact();
          
          if (mounted) {
            // Success animation and close dialog
            _animationController.forward().then((_) {
              Navigator.of(context).pop();
              if (widget.onSubmit != null && credential.smsCode != null) {
                widget.onSubmit!('$_countryCode${_phoneController.text.trim()}');
              }
            });
          }
        } catch (e) {
          _setStatus('Auto-verification failed. Please enter the code manually.', StatusType.error);
          debugPrint('Auto-verification error: $e');
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      _setStatus('Auto-detection failed. Please enter the code manually.', StatusType.info);
      debugPrint('Auto-detection error: $e');
      
      if (mounted) {
        setState(() {
          _isCodeSent = false;
          _isLoading = false;
        });
      }
    }
  }

  // Handle verification failure with user-friendly error messages
  void _handleVerificationFailed(FirebaseException exception) {
    setState(() {
      _isCodeSent = false;
    });
    
    // Map backend error codes to user-friendly messages
    String friendlyMessage;
    
    switch (exception.code) {
      case 'invalid-phone-number':
        friendlyMessage = 'Please enter a valid phone number.';
        break;
      case 'too-many-requests':
        friendlyMessage = 'Too many attempts. Please try again later.';
        break;
      case 'quota-exceeded':
        friendlyMessage = 'Service temporarily unavailable. Please try again later.';
        break;
      case 'network-request-failed':
        friendlyMessage = 'Network error. Please check your connection and try again.';
        break;
      case 'captcha-check-failed':
        friendlyMessage = 'Security verification failed. Please try again.';
        break;
      default:
        friendlyMessage = 'Verification failed. Please try again.';
    }
    
    _setStatus(friendlyMessage, StatusType.error);
    debugPrint('Verification error: ${exception.code} - ${exception.message}');
    
    setState(() {
      _isLoading = false;
    });
  }

  // Handle successful code sent to device
  void _handleCodeSent(String verificationId, int? resendToken) {
    _startTimer();
    _setStatus('Verification code sent', StatusType.success);
    
    // Provide haptic feedback for success
    HapticFeedback.mediumImpact();
    
    setState(() {
      _verificationId = verificationId;
      _isCodeSent = true;
      _isLoading = false;
    });
    
    // Auto-focus the verification code field
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _smsFocusNode.requestFocus();
      }
    });
  }

  // Handle code auto-retrieval timeout
  void _handleCodeAutoRetrievalTimeout(String verificationId) {
    setState(() {
      _verificationId = verificationId;
      _isCodeSent = false;
    });
    
    if (mounted && _statusType != StatusType.error) {
      _setStatus('Enter code manually to continue', StatusType.info);
    }
  }

  // Animation helper for transitions between screens
  Widget _animateTransition(Widget child, bool isActive) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: isActive ? child : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final secondaryColor = widget.secondaryColor ?? primaryColor.withOpacity(0.7);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header with animation
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Phone Verification',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: -0.1, end: 0, duration: 300.ms),
                    
                    const SizedBox(height: 16),
                    
                    // Status banner
                    _buildStatusBanner(),
                    
                    // Conditional UI based on verification step
                    _animateTransition(
                      _buildPhoneInput(primaryColor, secondaryColor),
                      !_isCodeSent,
                    ),
                    
                    _animateTransition(
                      _buildVerificationInput(primaryColor, secondaryColor),
                      _isCodeSent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Build the phone input section
  Widget _buildPhoneInput(Color primaryColor, Color secondaryColor) {
    return Column(
      key: const ValueKey('phone_input'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phone number input section with improved styling
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Country code picker with improved styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.public,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Country code',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Country code picker
              CountryCodePicker(
                onChanged: (code) {
                  setState(() {
                    _countryCode = code.dialCode ?? '+1';
                  });
                  // Clear any previous error when changing country
                  if (_statusType == StatusType.error) {
                    _setStatus(null, StatusType.none);
                  }
                },
                initialSelection: 'US',
                favorite: const ['+1', 'US', '+91', 'IN', '+44', 'GB', '+61', 'AU', '+86', 'CN'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                searchDecoration: InputDecoration(
                  hintText: 'Search country',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                dialogSize: const Size(340, 500),
                dialogBackgroundColor: Colors.white,
                barrierColor: Colors.black54,
                boxDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              
              // Divider
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade200,
              ),
              
              // Phone number field with improved styling
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 16,
                    ),
                    prefixText: '$_countryCode ',
                    prefixStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!_isValidPhoneNumber(value)) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!_isLoading) {
                      _sendVerificationCode();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Instruction text with animation
        Text(
          'We\'ll send a verification code to this number to confirm your identity.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(
          begin: 0.2, 
          end: 0, 
          delay: 200.ms, 
          duration: 400.ms
        ),
        
        const SizedBox(height: 24),
        
        // Action buttons
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: secondaryColor, width: 1.5),
              ),
              elevation: 4,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shadowColor: primaryColor.withOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Send Verification Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.send, size: 18)
                    ],
                  ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(
          begin: 0.2, 
          end: 0, 
          delay: 300.ms, 
          duration: 400.ms
        ),
        
        const SizedBox(height: 16),
        
        // Cancel button with styled animation
        TextButton.icon(
          onPressed: _isLoading 
              ? null 
              : () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.cancel_outlined,
            color: Colors.grey.shade700,
            size: 18,
          ),
          label: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 400.ms),
      ],
    );
  }
  
  // Build the verification code input section
  Widget _buildVerificationInput(Color primaryColor, Color secondaryColor) {
    return Column(
      key: const ValueKey('verification_input'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Verification code input with improved styling
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header text
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Description text
              Text(
                'A 6-digit code has been sent to\n$_countryCode ${_phoneController.text}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Code input field with improved styling
              TextFormField(
                controller: _smsController,
                focusNode: _smsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '······',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 24,
                    letterSpacing: 12,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    // Auto-verify when 6 digits are entered
                    _verifyCode();
                  }
                },
                onFieldSubmitted: (_) {
                  if (!_isLoading && _smsController.text.length == 6) {
                    _verifyCode();
                  }
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Resend code timer with improved styling
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              _resendEnabled
                  ? 'Didn\'t receive the code?'
                  : 'Resend code in $_timer seconds',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Resend button
        TextButton.icon(
          onPressed: _resendEnabled && !_isLoading
              ? _sendVerificationCode
              : null,
          icon: Icon(
            Icons.refresh,
            size: 16,
            color: _resendEnabled && !_isLoading
                ? primaryColor
                : Colors.grey.shade400,
          ),
          label: Text(
            'Resend Code',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: _resendEnabled && !_isLoading
                  ? primaryColor
                  : Colors.grey.shade400,
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Action buttons
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading || _smsController.text.length != 6
                ? null
                : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: secondaryColor, width: 1.5),
              ),
              elevation: 4,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shadowColor: primaryColor.withOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Verify Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.check_circle, size: 18)
                    ],
                  ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(
          begin: 0.2, 
          end: 0, 
          delay: 300.ms, 
          duration: 400.ms
        ),
        
        const SizedBox(height: 16),
        
        // Change number button with animation
        TextButton.icon(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _isCodeSent = false;
                    _setStatus(null, StatusType.none);
                  });
                },
          icon: Icon(
            Icons.phone_android,
            color: Colors.grey.shade700,
            size: 18,
          ),
          label: Text(
            'Change Phone Number',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 400.ms),
      ],
    );
  }

  // Build the status banner
  Widget _buildStatusBanner() {
    if (_statusType == StatusType.none || _statusMessage == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: _statusColorMap[_statusType]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusColorMap[_statusType]!.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _statusIconMap[_statusType],
            color: _statusColorMap[_statusType],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 14,
                color: _statusColorMap[_statusType],
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.close,
              color: _statusColorMap[_statusType],
              size: 18,
            ),
            onPressed: () {
              setState(() {
                _setStatus(null, StatusType.none);
              });
            },
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .slideY(begin: -0.1, end: 0);
  }
}