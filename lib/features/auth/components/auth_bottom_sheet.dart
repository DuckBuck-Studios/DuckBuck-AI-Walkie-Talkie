import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_model.dart';

/// Authentication method options
enum AuthMethod { email, phone, google, apple, signup }

/// Bottom sheet component containing authentication options
class AuthBottomSheet extends StatefulWidget {
  final Function(String email, String password) onLogin;
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

  const AuthBottomSheet({
    super.key,
    required this.onLogin,
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
    this.requireEmailVerification =
        false, // Default to not requiring verification
  });

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> {
  AuthMethod? _selectedAuthMethod;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;

  // Validation methods (keep existing validation methods)
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[0-9\s-()]{7,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  // Handle method selection (only for Email/Phone now)
  void _selectAuthMethod(AuthMethod method) {
    HapticFeedback.mediumImpact();
    // Removed Google/Apple direct calls from here
    debugPrint('Selected auth method: $method');
    setState(() {
      _selectedAuthMethod = method;
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _obscurePassword = true;
    });
  }

  void _goBack() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedAuthMethod = null;
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
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

    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedAuthMethod == AuthMethod.email) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        widget.onLogin(email, password);
      } else if (_selectedAuthMethod == AuthMethod.phone) {
        final phone = _phoneController.text.trim();
        widget.onPhoneAuth(phone);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AuthBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if we need to show the OTP verification dialog
    // This happens when verificationId is received from the parent
    if (widget.verificationId != null &&
        widget.phoneNumber != null &&
        (oldWidget.verificationId != widget.verificationId)) {
      // Use a microtask to show the dialog after the build cycle completes
      Future.microtask(() {
        _showOtpVerificationDialog(widget.verificationId!, widget.phoneNumber!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    Widget content;
    if (_selectedAuthMethod == null) {
      content = _buildInitialOptions();
    } else if (_selectedAuthMethod == AuthMethod.email) {
      content = _buildEmailForm();
    } else if (_selectedAuthMethod == AuthMethod.phone) {
      content = _buildPhoneForm();
    } else {
      content = const SizedBox.shrink();
    }

    // Using a light black background color (a dark gray)
    final lightBlackColor = Color(0xFF1E1E1E);

    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      color: lightBlackColor,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottomPadding),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title with back button if needed
                _selectedAuthMethod == null
                    ? const Center(
                      child: Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                    : Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: _goBack,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
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
                const SizedBox(height: 24),

                // Content based on selection
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_selectedAuthMethod) {
      case AuthMethod.email:
        return 'Sign in with Email';
      case AuthMethod.phone:
        return 'Sign in with Phone';
      default:
        return 'Sign in';
    }
  }

  Widget _buildInitialOptions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Email button
        _buildAuthOptionButton(
          icon: Icons.email_outlined,
          label: 'Continue with Email',
          // Disable if any loading is happening
          onPressed:
              widget.isLoading
                  ? null
                  : () => _selectAuthMethod(AuthMethod.email),
          isBlack: false,
          showLoadingIndicator:
              widget.isLoading &&
              widget.loadingMethod ==
                  AuthMethod.email, // Show loading if this method is loading
        ),
        const SizedBox(height: 8),

        // Phone button
        _buildAuthOptionButton(
          icon: Icons.phone_outlined,
          label: 'Continue with Phone',
          // Disable if any loading is happening
          onPressed:
              widget.isLoading
                  ? null
                  : () => _selectAuthMethod(AuthMethod.phone),
          isBlack: false,
          showLoadingIndicator:
              widget.isLoading &&
              widget.loadingMethod ==
                  AuthMethod.phone, // Show loading if this method is loading
        ),
        const SizedBox(height: 8),

        // Google button
        _buildAuthOptionButton(
          icon: FontAwesomeIcons.google,
          label: 'Continue with Google',
          // Disable if any loading is happening
          onPressed: widget.isLoading ? null : _handleGoogleAuth,
          isBlack: true,
          showLoadingIndicator:
              widget.isLoading &&
              widget.loadingMethod ==
                  AuthMethod.google, // Show loading if this method is loading
        ),
        const SizedBox(height: 8),

        // Apple button
        _buildAuthOptionButton(
          icon: FontAwesomeIcons.apple,
          label: 'Continue with Apple',
          // Disable if any loading is happening
          onPressed: widget.isLoading ? null : _handleAppleAuth,
          isBlack: true,
          showLoadingIndicator:
              widget.isLoading &&
              widget.loadingMethod ==
                  AuthMethod.apple, // Show loading if this method is loading
        ),
      ],
    );
  }

  /// Build a consistent styled authentication option button
  Widget _buildAuthOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isBlack,
    bool showLoadingIndicator = false, // Added parameter
  }) {
    final Color contentColor = isBlack ? Colors.white : Colors.black;
    final Widget buttonContent =
        showLoadingIndicator // Check if loading indicator should be shown
            ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                // Use contentColor for the loader
                valueColor: AlwaysStoppedAnimation<Color>(contentColor),
                strokeWidth: 2,
              ),
            )
            : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: contentColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: contentColor,
                  ),
                ),
              ],
            );

    if (isBlack) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          // Disable splash effect when loading
          splashFactory: showLoadingIndicator ? NoSplash.splashFactory : null,
        ),
        child: buttonContent,
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          side: const BorderSide(color: Colors.black, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // Disable splash effect when loading
          splashFactory: showLoadingIndicator ? NoSplash.splashFactory : null,
        ),
        child: buttonContent,
      );
    }
  }

  Widget _buildEmailForm() {
    // Use widget.isLoading to show loading state on the submit button
    final bool isEmailLoading =
        widget.isLoading && widget.loadingMethod == AuthMethod.email;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email field (disable based on global loading)
          TextFormField(
            controller: _emailController,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Colors.white70,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              errorStyle: TextStyle(color: Colors.redAccent),
            ),
            textInputAction: TextInputAction.next,
            enabled: !widget.isLoading, // Use global loading state
          ),
          const SizedBox(height: 16),

          // Password field (disable based on global loading)
          TextFormField(
            controller: _passwordController,
            validator: _validatePassword,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              prefixIcon: const Icon(
                Icons.lock_outlined,
                color: Colors.white70,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              errorStyle: TextStyle(color: Colors.redAccent),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white70,
                ),
                onPressed:
                    () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            textInputAction: TextInputAction.done,
            enabled: !widget.isLoading, // Use global loading state
            onFieldSubmitted: (_) => _submitForm(),
          ),

          const SizedBox(height: 24),

          // Sign in button (show loading based on email method)
          ElevatedButton(
            onPressed:
                widget.isLoading
                    ? null
                    : _submitForm, // Disable if global loading
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              splashFactory: isEmailLoading ? NoSplash.splashFactory : null,
            ),
            child:
                isEmailLoading // Show loading indicator if email is loading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    // Use widget.isLoading to show loading state on the submit button
    final bool isPhoneLoading =
        widget.isLoading && widget.loadingMethod == AuthMethod.phone;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phone field (disable based on global loading)
          TextFormField(
            controller: _phoneController,
            validator: _validatePhone,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: '+1 234 567 8900',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              prefixIcon: const Icon(
                Icons.phone_outlined,
                color: Colors.white70,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              errorStyle: TextStyle(color: Colors.redAccent),
            ),
            textInputAction: TextInputAction.done,
            enabled: !widget.isLoading, // Use global loading state
            onFieldSubmitted: (_) => _submitForm(),
          ),
          const SizedBox(height: 16),

          // Submit button (show loading based on phone method)
          ElevatedButton(
            onPressed:
                widget.isLoading
                    ? null
                    : _submitForm, // Disable if global loading
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              splashFactory: isPhoneLoading ? NoSplash.splashFactory : null,
            ),
            child:
                isPhoneLoading // Show loading indicator if phone is loading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        strokeWidth: 2,
                      ),
                    )
                    : const Text('Continue'),
          ),

          const SizedBox(height: 12),
          Text(
            'We\'ll send a verification code to this number',
            style: TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Show dialog to enter OTP verification code
  void _showOtpVerificationDialog(String verificationId, String phoneNumber) {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: const Color(
                    0xFF1E1E1E,
                  ), // Match the bottom sheet dark color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'Verification Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Enter the 6-digit code sent to $phoneNumber',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Verification Code',
                            labelStyle: TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            counterStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(
                              Icons.lock_outlined,
                              color: Colors.white70,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the verification code';
                            }
                            if (value.length != 6) {
                              return 'Code must be 6 digits';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Phone verification canceled'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          isVerifying
                              ? null
                              : () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  // Set verifying state
                                  setState(() {
                                    isVerifying = true;
                                  });

                                  try {
                                    final PhoneAuthCredential credential =
                                        PhoneAuthProvider.credential(
                                          verificationId: verificationId,
                                          smsCode: otpController.text.trim(),
                                        );

                                    // Close dialog and let parent know verification is complete
                                    Navigator.of(context).pop(credential);
                                  } catch (e) {
                                    // Show error and allow retry
                                    setState(() {
                                      isVerifying = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Verification error: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      child:
                          isVerifying
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                              : Text('Verify'),
                    ),
                  ],
                ),
          ),
    ).then((credential) {
      // If dialog was dismissed without a credential, do nothing
      if (credential == null) return;

      // Otherwise pass the credential to the parent
      if (widget.onPhoneAuthCredential != null) {
        widget.onPhoneAuthCredential!(credential);
      }
    });
  }
}
