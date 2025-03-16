import 'dart:io'; 
import 'package:duckbuck/screens/onboarding/name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/widgets/animated_background.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:dots_indicator/dots_indicator.dart'; // Add this import for the dots indicator
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../widgets/phone_auth_popup.dart';
import '../../providers/auth_provider.dart';
import '../Home/home_screen.dart';
import '../onboarding/dob_screen.dart';
import '../onboarding/gender_screen.dart';
import '../onboarding/profile_photo_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override 
  // ignore: library_private_types_in_public_api
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();
  double _currentPage = 0;
  bool _showBottomSheet = false;
  
  // Auth state variables - no longer need to create AuthService directly
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isPhoneLoading = false;
  
  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!;
        // Show bottom sheet only when on last page
        if (_currentPage >= 2) {
          _showBottomSheet = true;
        } else {
          _showBottomSheet = false;
        }
      });
    });
  }

  @override
  // Modify the build method to listen for auth changes
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    
    // Add this to handle successful authentication
    if (authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Check if the user has completed onboarding
        final onboardingStage = await authProvider.getOnboardingStage();
        
        if (onboardingStage == OnboardingStage.completed) {
          // If onboarding is completed, go to home screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        } else {
          // Otherwise start/resume onboarding flow
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const NameScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        }
      });
    }

    // Update loading states based on the auth provider
    if (authProvider.status == AuthStatus.loading) {
      // Keep existing loading state to know which button is loading
    } else {
      // Reset loading states when auth is no longer loading
      if (_isGoogleLoading || _isAppleLoading || _isPhoneLoading) {
        setState(() {
          _isGoogleLoading = false;
          _isAppleLoading = false;
          _isPhoneLoading = false;
        });
      }
      
      // Show error if there is one
      if (authProvider.status == AuthStatus.error && authProvider.errorMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorSnackBar(authProvider.errorMessage!);
          // Clear the error
          authProvider.clearError();
        });
      }
    }

    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: Stack(
          children: [
            // Main content
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: _showBottomSheet
                          ? const NeverScrollableScrollPhysics() // Disable swiping when bottom sheet is visible
                          : const PageScrollPhysics(),
                      children: [
                        _buildPageContent("Welcome to DuckBuck", "This is the first page about the app."),
                        _buildPageContent("Features", "This page describes the features of the app."),
                        _buildPageContent("Get Started", "Instructions on how to get started with the app."),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // DotsIndicator above the bottom sheet
            Positioned(
              bottom: _showBottomSheet ? 200 : 20, // Adjust position based on bottom sheet visibility
              left: 0,
              right: 0,
              child: Center(
                child: DotsIndicator(
                  dotsCount: 3,
                  position: _currentPage,
                  decorator: DotsDecorator(
                    activeColor: Colors.black,
                    size: const Size.square(9.0),
                    activeSize: const Size(18.0, 9.0),
                    activeShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                ),
              ),
            ),
            
            // Bottom sheet with animation
            if (_showBottomSheet)
              Positioned(
                bottom: 0,
                child: Container(
                  height: 200,
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Auth buttons
                          if (Platform.isIOS) ...[
                            _buildAuthButton(
                              context: context,
                              text: "Continue with Google",
                              icon: Icons.g_mobiledata,
                              onTap: _signInWithGoogle,
                              color: const Color(0xFF4285F4),
                              borderColor: const Color(0xFF4285F4).withAlpha(204),
                              isLoading: _isGoogleLoading,
                            ),
                            const SizedBox(height: 16),
                            _buildAuthButton(
                              context: context,
                              text: "Continue with Apple",
                              icon: Icons.apple,
                              onTap: _signInWithApple,
                              color: Colors.black,
                              borderColor: Colors.black87,
                              isLoading: _isAppleLoading,
                            ),
                          ] else ...[
                            _buildAuthButton(
                              context: context,
                              text: "Continue with Google",
                              icon: Icons.g_mobiledata,
                              onTap: _signInWithGoogle,
                              color: const Color(0xFF4285F4),
                              borderColor: const Color(0xFF4285F4).withAlpha(204),
                              isLoading: _isGoogleLoading,
                            ),
                            const SizedBox(height: 16),
                            _buildAuthButton(
                              context: context,
                              text: "Continue with Phone",
                              icon: Icons.phone_android,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _showPhoneAuthPopup();
                              },
                              color: const Color(0xFF34A853),
                              borderColor: const Color(0xFF34A853).withAlpha(204),
                              isLoading: _isPhoneLoading,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
                .animate(
                  target: _showBottomSheet ? 1 : 0,
                  onPlay: (controller) => controller.forward(),
                )
                .slideY(
                  begin: 1,
                  end: 0,
                  duration: 500.ms,
                  curve: Curves.easeOutQuart,
                )
                .fadeIn(
                  duration: 300.ms,
                  curve: Curves.easeOut,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPageContent(String title, String description) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    Color color = const Color(0xFFD4A76A),
    Color borderColor = const Color(0xFFB38B4D),
    bool isLoading = false,
  }) {
    return DuckBuckButton(
      text: isLoading ? '' : text,
      onTap: isLoading ? () {} : onTap,
      color: color,
      borderColor: borderColor,
      textColor: Colors.white,
      alignment: MainAxisAlignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      icon: isLoading
          ? Lottie.asset(
              'assets/animations/loading.json',
              width: 24,
              height: 24,
            )
          : Icon(icon, color: Colors.white),
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      height: 50,
      width: double.infinity,
    );
  }

  // Sign in with Google
  Future<void> _signInWithGoogle() async {
    if (_isGoogleLoading) return;
    
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      HapticFeedback.mediumImpact();
      // Use auth provider instead of the service directly
      await Provider.of<AuthProvider>(context, listen: false).signInWithGoogle();
    } catch (e) {
      // Error handling is now managed by the provider
      // But we still set the local loading state back to false
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // Sign in with Apple
  Future<void> _signInWithApple() async {
    if (_isAppleLoading) return;
    
    setState(() {
      _isAppleLoading = true;
    });

    try {
      HapticFeedback.mediumImpact();
      // Use auth provider instead of the service directly
      await Provider.of<AuthProvider>(context, listen: false).signInWithApple();
    } catch (e) {
      // Error handling is now managed by the provider
      // But we still set the local loading state back to false
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  // Show phone auth popup
  void _showPhoneAuthPopup() {
    if (_isPhoneLoading) return;
    
    setState(() {
      _isPhoneLoading = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: !_isPhoneLoading,
      builder: (dialogContext) => PhoneAuthPopup(
        onSubmit: (countryCode, phoneNumber) async {
          // Authentication is handled inside the popup
          // Popup is now responsible for communicating with the provider
          if (mounted) {
            setState(() {
              _isPhoneLoading = false;
            });
          }
        },
      ),
    ).then((_) {
      // Dialog closed, reset loading state if needed
      if (mounted && _isPhoneLoading) {
        setState(() {
          _isPhoneLoading = false;
        });
      }
    });
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}