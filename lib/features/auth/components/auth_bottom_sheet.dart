import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/models/user_model.dart';

/// Authentication method options
enum AuthMethod { phone, google, apple }

/// Bottom sheet component containing authentication options
class AuthBottomSheet extends StatefulWidget {
  final Function(String phoneNumber) onPhoneAuth;
  final VoidCallback onGoogleAuth;
  final VoidCallback onAppleAuth;
  final Function(PhoneAuthCredential)? onPhoneAuthCredential;
  final Function(String errorMessage)? onError;
  final Function(UserModel user)? onVerified;
  final bool isLoading;
  final AuthMethod? loadingMethod; // Track which method is loading
  final String? verificationId; // For phone verification
  final String? phoneNumber; // Phone number being verified
  final bool requireEmailVerification; // Whether to require email verification
  final AuthMethod? initialAuthMethod; // Initial auth method to display

  const AuthBottomSheet({
    super.key,
    required this.onPhoneAuth,
    required this.onGoogleAuth,
    required this.onAppleAuth,
    this.onPhoneAuthCredential,
    this.onError,
    this.onVerified,
    this.isLoading = false,
    this.loadingMethod,
    this.verificationId,
    this.phoneNumber,
    this.requireEmailVerification = false, // Default to not requiring verification
    this.initialAuthMethod, // For pre-selecting a method (especially for verification)
  });

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> {
  AuthMethod? _selectedAuthMethod;

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _countryCode = '+1'; // Default country code
  String _otpValue = ''; // To store OTP value

  // Stream controller for OTP timer
  StreamController<ErrorAnimationType>? _otpErrorController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _otpErrorController = StreamController<ErrorAnimationType>();
    
    // Set initial auth method if provided
    if (widget.initialAuthMethod != null) {
      _selectedAuthMethod = widget.initialAuthMethod;
    }
    
    // If we have verification ID and phone number, we should show the verification UI
    if (widget.verificationId != null && widget.phoneNumber != null) {
      _selectedAuthMethod = AuthMethod.phone;
      debugPrint("AUTH SHEET: Showing verification UI for ${widget.phoneNumber}");
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpErrorController?.close();
    super.dispose();
  }

  // Validation methods
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    
    // More simplified regex that just checks for mostly numbers
    final phoneRegex = RegExp(r'^[0-9\s-]{7,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  // Handle method selection (only for Phone now)
  void _selectAuthMethod(AuthMethod method) {
    HapticFeedback.mediumImpact();
    
    // Use a microtask to ensure smooth transition animation
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _selectedAuthMethod = method;
          _phoneController.clear();
        });
      }
    });
  }

  void _goBack() {
    HapticFeedback.lightImpact();
    
    // Use a microtask to ensure smooth transition animation
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _selectedAuthMethod = null;
          _phoneController.clear();
        });
      }
    });
  }

  // Handle Google auth with loading state
  void _handleGoogleAuth() {
    if (!widget.isLoading) {
      HapticFeedback.mediumImpact();
      widget.onGoogleAuth();
    }
  }

  // Handle Apple auth with loading state
  void _handleAppleAuth() {
    if (!widget.isLoading) {
      HapticFeedback.mediumImpact();
      widget.onAppleAuth();
    }
  }

  void _submitForm() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }

    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedAuthMethod == AuthMethod.phone) {
        final phoneNumberText = _phoneController.text.trim();
        // Combine country code with phone number
        final fullPhoneNumber = _countryCode + phoneNumberText;
        widget.onPhoneAuth(fullPhoneNumber);
      }
    }
  }

  void _onCountryCodeChanged(CountryCode code) {
    setState(() {
      _countryCode = code.dialCode ?? '+1';
    });
  }

  @override
  void didUpdateWidget(AuthBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Debug log for verification state changes
    debugPrint("Auth bottom sheet didUpdateWidget: oldVerificationId=${oldWidget.verificationId}, newVerificationId=${widget.verificationId}, phoneNumber=${widget.phoneNumber}");

    // Reset error state when props change
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }

    // Handle verification ID and phone number changes
    final bool hadVerificationId = oldWidget.verificationId != null;
    final bool hasVerificationId = widget.verificationId != null;
    final bool verificationIdChanged = oldWidget.verificationId != widget.verificationId;

    // Always check if we should show verification based on current props,
    // not just changes since this might be a new instance of the sheet
    if (widget.verificationId != null && widget.phoneNumber != null) {
      debugPrint("VERIFICATION SHOULD BE SHOWING! Setting selectedAuthMethod to phone");
      
      // Force phone auth mode to show verification UI
      setState(() {
        _selectedAuthMethod = AuthMethod.phone;
        _otpValue = ''; // Reset OTP value when showing verification UI
        
        // Clear the text controller - we don't need it when showing verification
        if (_phoneController.text.isNotEmpty) {
          _phoneController.clear();
        }
      });
    } else if ((hadVerificationId && !hasVerificationId) || 
               (verificationIdChanged && widget.verificationId == null)) {
      // If we previously had a verification ID but now don't, go back to phone input
      debugPrint("Verification ID removed, going back to phone input");
      
      setState(() {
        _selectedAuthMethod = AuthMethod.phone;
        _otpValue = ''; // Reset OTP value
      });
    } else {
      debugPrint("No verification ID or phone number, normal auth sheet");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isIOS = Platform.isIOS;

    // Debug print for verification and phone state
    debugPrint("AUTH BOTTOM SHEET BUILD: verificationId=${widget.verificationId}, phoneNumber=${widget.phoneNumber}, selectedAuthMethod=$_selectedAuthMethod");

    // Content for the bottom sheet
    Widget content;
    if (_selectedAuthMethod == null) {
      content = _buildInitialOptions(isIOS);
    } else if (_selectedAuthMethod == AuthMethod.phone) {
      content = _buildPhoneForm(isIOS);
    } else {
      content = const SizedBox.shrink();
    }

    // Dark background color
    final darkBackgroundColor = const Color(0xFF1A1A1A);

    // Use a more compact fixed height for the sheet that fits just the content
    // This ensures height consistency across all auth states
    final double sheetHeight = _selectedAuthMethod == null 
        ? 230.0  // Height for initial auth options (3 buttons)
        : _selectedAuthMethod == AuthMethod.phone && widget.verificationId != null
            ? 260.0  // Height for verification UI
            : 240.0;  // Height for phone input

    return Material(
      borderRadius: BorderRadius.vertical(top: Radius.circular(isIOS ? 28 : 24)),
      color: darkBackgroundColor,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, isIOS ? 24 : 20, 24, 16 + bottomPadding),
          child: SizedBox(
            height: sheetHeight,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sheet handle at the top
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                
                  // Title with back button if needed
                  Row(
                    children: [
                      if (_selectedAuthMethod != null)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: _goBack,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (_selectedAuthMethod != null) 
                        const SizedBox(width: 8),
                      Text(
                        _getTitle(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content based on selection with improved animation
                  AnimatedSwitcher(
                    layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                      // Custom layout builder to maintain consistent size
                      return Stack(
                        alignment: Alignment.topCenter,
                        fit: StackFit.loose,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      // Use only fade transition to avoid layout shifts
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                        child: child,
                      );
                    },
                    child: SizedBox(
                      key: ValueKey<AuthMethod?>(_selectedAuthMethod),
                      width: double.infinity,
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_selectedAuthMethod) {
      case AuthMethod.phone:
        return widget.verificationId != null ? 'Verify Phone' : 'Sign in with Phone';
      default:
        return ''; // Removing "Sign in" text from the header
    }
  }

  Widget _buildInitialOptions(bool isIOS) {
    // Get screen size
    final size = MediaQuery.of(context).size;
    // Adjust button spacing based on screen size
    final buttonSpacing = size.height < 700 ? 8.0 : 12.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phone button
        _buildAuthOptionButton(
          icon: isIOS ? CupertinoIcons.phone : Icons.phone_outlined,
          label: 'Continue with Phone',
          onPressed: widget.isLoading ? null : () => _selectAuthMethod(AuthMethod.phone),
          isBlack: false,
          showLoadingIndicator: widget.isLoading && widget.loadingMethod == AuthMethod.phone,
          isIOS: isIOS,
        ),
        SizedBox(height: buttonSpacing),

        // Google button
        _buildAuthOptionButton(
          icon: FontAwesomeIcons.google,
          label: 'Continue with Google',
          onPressed: widget.isLoading ? null : _handleGoogleAuth,
          isBlack: true,
          showLoadingIndicator: widget.isLoading && widget.loadingMethod == AuthMethod.google,
          isIOS: isIOS,
        ),
        SizedBox(height: buttonSpacing),

        // Apple button - show on all platforms
        _buildAuthOptionButton(
          icon: FontAwesomeIcons.apple,
          label: 'Continue with Apple',
          onPressed: widget.isLoading ? null : _handleAppleAuth,
          isBlack: true,
          showLoadingIndicator: widget.isLoading && widget.loadingMethod == AuthMethod.apple,
          isIOS: isIOS,
        ),
      ],
    );
  }

  Widget _buildAuthOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isBlack,
    bool showLoadingIndicator = false,
    required bool isIOS,
  }) {
    // Colors based on theme
    final Color backgroundColor = isBlack ? Colors.black : Colors.white;
    final Color contentColor = isBlack ? Colors.white : Colors.black;
    
    // Get screen size to adjust button height
    final size = MediaQuery.of(context).size;
    final buttonHeight = size.height < 700 ? 45.0 : 50.0;
    
    // Loading indicator with platform-specific styling
    final Widget loadingIndicator = SizedBox(
      height: 20,
      width: 20,
      child: isIOS 
        ? CupertinoActivityIndicator(color: contentColor)
        : CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(contentColor),
            strokeWidth: 2,
          ),
    );

    // Content to display (either loading indicator or normal content)
    final Widget content = showLoadingIndicator 
        ? loadingIndicator
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: contentColor, size: isIOS ? 16 : 18),
              SizedBox(width: isIOS ? 8 : 10),
              Text(
                label,
                style: TextStyle(
                  color: contentColor,
                  fontSize: isIOS ? 16 : 14,
                  fontWeight: isIOS ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          );
            
    // Platform-specific button with proper styling
    return RepaintBoundary(
      child: isIOS
        ? CupertinoButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            child: Container(
              height: buttonHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: isBlack ? null : Border.all(color: Colors.black, width: 1),
              ),
              alignment: Alignment.center,
              child: content,
            ),
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: contentColor,
              minimumSize: Size(double.infinity, buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: isBlack ? BorderSide.none : const BorderSide(color: Colors.black),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              splashFactory: NoSplash.splashFactory,
            ),
            child: content,
          ),
    );
  }

  Widget _buildPhoneForm(bool isIOS) {
    // Loading state tracking
    final bool isPhoneLoading = widget.isLoading && widget.loadingMethod == AuthMethod.phone;
    
    // Verification mode if we have a verification ID
    final bool showVerification = widget.verificationId != null && widget.phoneNumber != null;
    
    if (isIOS) {
      return _buildIOSPhoneForm(isPhoneLoading, showVerification);
    } else {
      return _buildAndroidPhoneForm(isPhoneLoading, showVerification);
    }
  }

  Widget _buildIOSPhoneForm(bool isPhoneLoading, bool showVerification) {
    // Debug print current verification state
    debugPrint("IOS PHONE FORM: showVerification=$showVerification, verificationId=${widget.verificationId}, phoneNumber=${widget.phoneNumber}");
    
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showVerification) ... [
            // Phone Input with Country Code
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A), // Use same dark color as background
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              height: 56,
              child: Row(
                children: [
                  // Country Code Picker
                  Container(
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: CountryCodePicker(
                      onChanged: _onCountryCodeChanged,
                      initialSelection: 'US',
                      favorite: const ['US', 'IN', 'CA', 'GB'],
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      textStyle: const TextStyle(color: Colors.white),
                      padding: EdgeInsets.zero,
                      barrierColor: Colors.black.withOpacity(0.7),
                      backgroundColor: const Color(0xFF1A1A1A),
                      dialogBackgroundColor: const Color(0xFF1A1A1A),
                      searchDecoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.search, color: Colors.white70),
                      ),
                      dialogTextStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                  
                  // Phone number field
                  Expanded(
                    child: CupertinoTextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      placeholder: '123 456 7890',
                      placeholderStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      decoration: null,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      enabled: !isPhoneLoading,
                      onSubmitted: (_) => _submitForm(),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Continue Button with Loading State
            CupertinoButton(
              onPressed: isPhoneLoading ? null : _submitForm,
              padding: EdgeInsets.zero,
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: isPhoneLoading
                  ? const CupertinoActivityIndicator(color: Colors.black)
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              'We\'ll send a verification code to this number',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          // OTP Verification UI
          if (showVerification) ... [
            // Show the phone number we're verifying
            const Text(
              'Enter verification code sent to',
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.phoneNumber!,
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold, 
                fontSize: 16
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // iOS OTP Input as individual boxes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PinCodeTextField(
                appContext: context,
                length: 6,
                obscureText: false,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 50,
                  fieldWidth: 40,
                  activeFillColor: Colors.white.withOpacity(0.15),
                  selectedFillColor: Colors.white.withOpacity(0.25),
                  inactiveFillColor: Colors.white.withOpacity(0.1),
                  activeColor: Colors.white,
                  selectedColor: Colors.blue,
                  inactiveColor: Colors.white.withOpacity(0.3),
                ),
                cursorColor: Colors.white,
                animationDuration: const Duration(milliseconds: 300),
                enableActiveFill: true,
                errorAnimationController: _otpErrorController,
                controller: TextEditingController(),
                keyboardType: TextInputType.number,
                boxShadows: const [
                  BoxShadow(
                    offset: Offset(0, 0),
                    color: Colors.blue,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    offset: Offset(0, 1),
                    color: Colors.black26,
                    blurRadius: 10,
                  )
                ],
                onCompleted: (value) {
                  _otpValue = value;
                  _verifyOtp(value);
                },
                onChanged: (value) {
                  setState(() {
                    _otpValue = value;
                  });
                },
                beforeTextPaste: (text) {
                  // Allow only numbers
                  return text != null && RegExp(r'^[0-9]+$').hasMatch(text);
                },
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Verify Button - auto-enabled when OTP is complete
            CupertinoButton(
              onPressed: isPhoneLoading ? null : (_otpValue.length == 6 ? () => _verifyOtp(_otpValue) : null),
              padding: EdgeInsets.zero,
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _otpValue.length == 6 ? Colors.blue : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _otpValue.length == 6 ? 
                    [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ] : null,
                ),
                alignment: Alignment.center,
                child: isPhoneLoading
                  ? const CupertinoActivityIndicator(color: Colors.black)
                  : Text(
                      'Verify',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w600,
                        color: _otpValue.length == 6 ? Colors.white : Colors.black,
                      ),
                    ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Row with options to change phone number or resend code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: isPhoneLoading ? null : _goBack,
                  child: Text(
                    'Change Number',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
                
                Container(
                  height: 16,
                  width: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: isPhoneLoading ? null : () {
                    // Resend code using the existing phone number
                    if (widget.phoneNumber != null) {
                      widget.onPhoneAuth(widget.phoneNumber!);
                    }
                  },
                  child: Text(
                    'Resend Code',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAndroidPhoneForm(bool isPhoneLoading, bool showVerification) {
    // Debug print current verification state
    debugPrint("ANDROID PHONE FORM: showVerification=$showVerification, verificationId=${widget.verificationId}, phoneNumber=${widget.phoneNumber}");
    
    return Form(
      key: _formKey,
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!showVerification) ... [
              // Phone Input with Material design and Country Code
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A), // Use same dark color as background
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    // Country Code Picker
                    Container(
                      padding: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: CountryCodePicker(
                        onChanged: _onCountryCodeChanged,
                        initialSelection: 'US',
                        favorite: const ['US', 'IN', 'CA', 'GB'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        textStyle: const TextStyle(color: Colors.white),
                        padding: EdgeInsets.zero,
                        barrierColor: Colors.black.withOpacity(0.7),
                        backgroundColor: const Color(0xFF1A1A1A),
                        dialogBackgroundColor: const Color(0xFF1A1A1A),
                        searchDecoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.search, color: Colors.white70),
                        ),
                        dialogTextStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                    
                    // Phone number field
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '123 456 7890',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        enabled: !isPhoneLoading,
                        onFieldSubmitted: (_) => _submitForm(),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Continue Button with Loading State
              ElevatedButton(
                onPressed: isPhoneLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isPhoneLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              ),
              
              const SizedBox(height: 12),
              Text(
                'We\'ll send a verification code to this number',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],

            // OTP VERIFICATION UI
            if (showVerification) ... [
              // Show the phone number we're verifying
              const Text(
                'Enter verification code sent to',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.phoneNumber!,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Material Design OTP Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(10),
                    fieldHeight: 50,
                    fieldWidth: 40,
                    activeFillColor: Colors.white.withOpacity(0.15),
                    selectedFillColor: Colors.white.withOpacity(0.25),
                    inactiveFillColor: Colors.white.withOpacity(0.1),
                    activeColor: Colors.white,
                    selectedColor: Colors.blue,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                  cursorColor: Colors.white,
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  errorAnimationController: _otpErrorController,
                  controller: TextEditingController(),
                  keyboardType: TextInputType.number,
                  boxShadows: const [
                    BoxShadow(
                      offset: Offset(0, 0),
                      color: Colors.blue,
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      offset: Offset(0, 1),
                      color: Colors.black26,
                      blurRadius: 10,
                    )
                  ],
                  onCompleted: (value) {
                    _otpValue = value;
                    _verifyOtp(value);
                  },
                  onChanged: (value) {
                    setState(() {
                      _otpValue = value;
                    });
                  },
                  beforeTextPaste: (text) {
                    return text != null && RegExp(r'^[0-9]+$').hasMatch(text);
                  },
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Verify Button - auto-enabled when OTP is complete
              ElevatedButton(
                onPressed: isPhoneLoading ? null : (_otpValue.length == 6 ? () => _verifyOtp(_otpValue) : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _otpValue.length == 6 ? Colors.blue : Colors.white,
                  foregroundColor: _otpValue.length == 6 ? Colors.white : Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: _otpValue.length == 6 ? 4 : 0,
                  shadowColor: _otpValue.length == 6 ? Colors.blue.withOpacity(0.5) : Colors.transparent,
                ),
                child: isPhoneLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Verify',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _otpValue.length == 6 ? Colors.white : Colors.black,
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              
              // Row with options to change phone number or resend code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: isPhoneLoading ? null : _goBack,
                    child: Text(
                      'Change Phone Number',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  Container(
                    height: 16,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  
                  TextButton(
                    onPressed: isPhoneLoading ? null : () {
                      // Resend code using the existing phone number
                      if (widget.phoneNumber != null) {
                        widget.onPhoneAuth(widget.phoneNumber!);
                      }
                    },
                    child: Text(
                      'Resend Code',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Verify OTP code and pass credential to parent
  void _verifyOtp(String otp) {
    // Debug log for verification attempt
    debugPrint("Verifying OTP: ${otp.length} digits, verificationId: ${widget.verificationId != null}");
    
    // Validate OTP
    if (otp.length != 6) {
      // Show animation for error
      _otpErrorController?.add(ErrorAnimationType.shake);
      setState(() {
        _hasError = true;
      });
      if (widget.onError != null) {
        widget.onError!('Please enter a valid 6-digit verification code.');
      }
      return;
    }
    
    // Validate verification ID
    if (widget.verificationId == null || widget.verificationId!.isEmpty) {
      // Show animation for error
      _otpErrorController?.add(ErrorAnimationType.shake);
      setState(() {
        _hasError = true;
      });
      if (widget.onError != null) {
        widget.onError!('Verification session has expired. Please restart the verification process.');
      }
      return;
    }

    try {
      // Provide haptic feedback for verification attempt
      HapticFeedback.mediumImpact();
      
      // Create phone credential from verification ID and code
      // Ensure both are properly trimmed of any whitespace
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId!.trim(),
        smsCode: otp.trim(),
      );

      // Send back to parent
      if (widget.onPhoneAuthCredential != null) {
        debugPrint("Sending credential to parent: verificationId=${widget.verificationId!.trim()}, smsCode=${otp.trim()}");
        widget.onPhoneAuthCredential!(credential);
      } else {
        debugPrint("ERROR: No onPhoneAuthCredential handler available");
        if (widget.onError != null) {
          widget.onError!('Unable to process verification code. Please try again.');
        }
      }
    } catch (e) {
      debugPrint("Error creating phone credential: $e");
      // Show animation for error
      _otpErrorController?.add(ErrorAnimationType.shake);
      setState(() {
        _hasError = true;
      });
      if (widget.onError != null) {
        widget.onError!('Error verifying code: ${e.toString()}');
      }
    }
  }
}
