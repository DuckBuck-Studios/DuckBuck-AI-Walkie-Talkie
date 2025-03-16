import 'dart:async';
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:lottie/lottie.dart'; 
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart' as auth;

class PhoneAuthPopup extends StatefulWidget {
  final Function(String, String) onSubmit;

  const PhoneAuthPopup({
    Key? key,
    required this.onSubmit,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _PhoneAuthPopupState createState() => _PhoneAuthPopupState();
}

class _PhoneAuthPopupState extends State<PhoneAuthPopup> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _verificationController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  bool _isLoading = false;
  bool _codeSent = false;
  String _verificationId = '';
  int? _resendToken;
  String _countryCode = '+1'; // Default to US
  Timer? _timer;
  int _timerSeconds = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _verificationController.dispose();
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the auth provider with listen: false to avoid rebuilds during the operation
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      await authProvider.verifyPhoneNumber(
        phoneNumber: '$_countryCode${_phoneController.text}',
        verificationCompleted: _handleVerificationCompleted,
        verificationFailed: _handleVerificationFailed,
        codeSent: _handleCodeSent,
        codeAutoRetrievalTimeout: _handleCodeAutoRetrievalTimeout,
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send verification code: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the auth provider with listen: false to avoid rebuilds during the operation
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Use the correct method name
      await authProvider.signInWithPhoneNumber(_verificationId, _verificationController.text);

      // Successful verification
      if (mounted) {
        // Close the dialog
        Navigator.of(context).pop();
        // Notify parent widget
        widget.onSubmit(_countryCode, _phoneController.text);
      }
    } catch (e) {
      _showErrorSnackBar('Verification failed: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleVerificationCompleted(PhoneAuthCredential credential) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // If SMS code is available from credential, update the text field
      if (credential.smsCode != null) {
        _verificationController.text = credential.smsCode!;
        
        // Show that auto-detection worked
        _showSuccessSnackBar('Code auto-detected!');
      }
      
      // Get the auth provider with listen: false
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Sign in with the credential via phone number
      if (credential.smsCode != null) {
        await authProvider.signInWithPhoneNumber(_verificationId, credential.smsCode!);
      } else {
        // This is an edge case where verification completed without an SMS code
        // We can't directly use signInWithCredential as it's private in the provider
        // So we'll try to sign in with the verification ID we have
        // For on-device verification without SMS, this is a fallback
        _showErrorSnackBar('Automatic verification not supported. Please enter code manually.');
        
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Notify parent and close dialog on success
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmit(_countryCode, _phoneController.text);
      }
    } catch (e) {
      _showErrorSnackBar('Auto-verification failed: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleVerificationFailed(FirebaseAuthException exception) {
    _showErrorSnackBar('Verification failed: ${exception.message}');
    setState(() {
      _isLoading = false;
    });
  }

  void _handleCodeSent(String verificationId, int? resendToken) {
    _startTimer();
    setState(() {
      _verificationId = verificationId;
      _resendToken = resendToken;
      _codeSent = true;
      _isLoading = false;
    });
    _showSuccessSnackBar('Verification code sent');
  }

  void _handleCodeAutoRetrievalTimeout(String verificationId) {
    setState(() {
      _verificationId = verificationId;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create two separate widgets for phone input and verification code
    // that will be animated between
    final phoneInputWidget = _buildPhoneInput();
    final verificationWidget = _buildVerificationInput();
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFD4A76A).withOpacity(0.1),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and animation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _codeSent ? Icons.sms : Icons.phone_android,
                    size: 36,
                    color: const Color(0xFFD4A76A),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _codeSent ? 'Verification Code' : 'Phone Verification',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD4A76A),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Animated content switcher
              Stack(
                children: [
                  // Phone input form - visible when !_codeSent
                  if (!_codeSent) phoneInputWidget,
                  
                  // Verification code form - slides in from right
                  if (_codeSent) 
                    verificationWidget
                      .animate()
                      .slideX(
                        begin: 1, 
                        end: 0, 
                        duration: 300.ms,
                        curve: Curves.easeOutQuad,
                      )
                      .fadeIn(duration: 200.ms),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build the phone input section
  Widget _buildPhoneInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phone number input section
        Row(
          children: [
            // Use CountryCodePicker with customization
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CountryCodePicker(
                onChanged: (code) {
                  setState(() {
                    _countryCode = code.dialCode ?? '+1';
                  });
                },
                initialSelection: 'US',
                favorite: const ['+1', 'US', '+91', 'IN'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                padding: const EdgeInsets.all(0),
                dialogBackgroundColor: Colors.white,
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
            ),
            const SizedBox(width: 10),
            // Phone number field
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD4A76A)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Instruction text
        Text(
          'We\'ll send a verification code to this number to confirm your identity.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 24),
        
        // Action buttons
        DuckBuckButton(
          text: 'Send Code',
          onTap: _isLoading ? () {} : _sendVerificationCode,
          color: const Color(0xFFD4A76A),
          borderColor: const Color(0xFFB38B4D),
          textColor: Colors.white,
          height: 50,
          isLoading: _isLoading,
          icon: _isLoading ? null : const Icon(Icons.send, color: Colors.white),
        ),
        
        const SizedBox(height: 12),
        
        // Cancel button
        TextButton(
          onPressed: _isLoading 
              ? null 
              : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  
  // Build the verification code input section
  Widget _buildVerificationInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phone icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFD4A76A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            Icons.phone_android,
            size: 32,
            color: const Color(0xFFD4A76A),
          ),
        ),
        const SizedBox(height: 20),
        
        // Code input with better styling
        TextFormField(
          controller: _verificationController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLength: 6,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '• • • • • •',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD4A76A), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            counterText: "",
            helperText: "Firebase will auto-detect the SMS code",
            helperStyle: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontStyle: FontStyle.italic,
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
          onChanged: (value) {
            // Auto-submit when 6 digits are entered
            if (value.length == 6 && !_isLoading) {
              _verifyCode();
            }
          },
        ),
        
        const SizedBox(height: 12),
        
        // Timer or resend option
        if (_timerSeconds > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined, 
                  size: 16, 
                  color: Colors.grey.shade600
                ),
                const SizedBox(width: 8),
                Text(
                  'Resend code in $_timerSeconds seconds',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        if (_timerSeconds == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _sendVerificationCode,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Resend Code'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD4A76A),
              ),
            ),
          ),
          
        const SizedBox(height: 24),
        
        // Action buttons
        Row(
          children: [
            // Back button with improved styling
            Expanded(
              child: DuckBuckButton(
                text: 'Back',
                onTap: () {
                  if (!_isLoading) {
                    setState(() {
                      _codeSent = false;
                    });
                  }
                },
                color: Colors.grey.shade200,
                borderColor: Colors.grey.shade300,
                textColor: Colors.black87,
                height: 50,
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.black87,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Verify button
            Expanded(
              child: DuckBuckButton(
                text: 'Verify',
                onTap: _isLoading ? () {} : _verifyCode,
                color: const Color(0xFFD4A76A),
                borderColor: const Color(0xFFB38B4D),
                textColor: Colors.white,
                height: 50,
                isLoading: _isLoading,
                icon: _isLoading ? null : const Icon(Icons.check, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}