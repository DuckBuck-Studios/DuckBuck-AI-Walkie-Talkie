import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../components/auth_bottom_sheet.dart';
import '../../main_navigation.dart';

class OnboardingSignupScreen extends StatefulWidget {
  const OnboardingSignupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingSignupScreen> createState() => _OnboardingSignupScreenState();
}

class _OnboardingSignupScreenState extends State<OnboardingSignupScreen> 
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _moveUpAnimation;
  bool _isDisposed = false; // Track disposal state

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller with premium timing
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800), // Increased for smoother feel
      vsync: this,
    );
    
    // Create sophisticated move up animation with better easing
    _moveUpAnimation = Tween<double>(
      begin: 0.0,
      end: -140.0, // Slightly more movement for dramatic effect
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo, // Premium easing curve
    ));
    
    // Add sophisticated haptic feedback when screen appears
    HapticFeedback.mediumImpact();
    
    // Add a subtle delay before showing content for premium feel
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    // Safely dispose animation controller
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
    _animationController.dispose();
    _isDisposed = true;
    super.dispose();
  }

  void _handleContinuePressed() {
    // Don't process if already loading
    if (_isLoading) return;
    
    // Premium haptic feedback
    HapticFeedback.mediumImpact();
    
    // Start animation to move content up with premium timing
    _animationController.forward();
    
    // Show auth bottom sheet component with enhanced presentation
    AuthBottomSheet.show(
      context: context,
      onAuthComplete: _completeWithDemo,
    ).then((_) {
      // Reset animation when bottom sheet is dismissed with smooth timing
      _animationController.reverse();
    });
  }
  
  void _completeWithDemo() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate a short processing time (can be removed in production)
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Navigate to home screen with premium celebration transition
    if (mounted) {
      _navigateToHome();
    }
  }

  /// Navigate to home screen with premium celebration transition
  void _navigateToHome() {
    // Safely dispose animation controller to free memory before navigation
    if (!_isDisposed) {
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      _animationController.dispose();
      _isDisposed = true;
    }
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          const MainNavigation(),
        transitionDuration: const Duration(milliseconds: 600), // Reduced for better performance
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Simplified but still cool celebration transition
          return Stack(
            children: [
              // Simplified celebration gradient background
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5 * animation.value,
                        colors: [
                          Colors.green.shade400.withValues(alpha: animation.value * 0.2),
                          Colors.blue.shade600.withValues(alpha: animation.value * 0.15),
                          Colors.black,
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
              
              // Reduced floating particles - only 6 instead of 12
              ...List.generate(6, (index) {
                final delay = (index * 0.08);
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final animationWithDelay = Curves.easeOut.transform(
                      (animation.value - delay).clamp(0.0, 1.0),
                    );
                    return Positioned(
                      left: 50.0 + (index * 40) * animationWithDelay,
                      top: 100.0 + (index % 2 * 200) * animationWithDelay,
                      child: Opacity(
                        opacity: animationWithDelay * (1 - animationWithDelay),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: [
                              Colors.blue.shade300,
                              Colors.green.shade300,
                            ][index % 2],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Main content with simplified celebration scale and slide
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(
                    0.8 + (animation.value * 0.2), // Scale from 80% to 100%
                  )
                  ..translate(
                    0.0,
                    (1 - animation.value) * 100, // Slide up from bottom
                    0.0,
                  ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          // Simplified background - only 2 static elements for better performance
          Positioned(
            top: -size.height * 0.1,
            right: -size.width * 0.1,
            child: Container(
              height: size.width * 0.7,
              width: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.whiteOpacity10,
              ),
            ),
          ),

          Positioned(
            bottom: -size.height * 0.05,
            left: -size.width * 0.1,
            child: Container(
              height: size.width * 0.6,
              width: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.whiteOpacity15,
              ),
            ),
          ),

          // Content container with modern entrance animations
          Padding(
            padding: EdgeInsets.only(
              top: size.height * 0.08,
              left: 24,
              right: 24,
              bottom: bottomPadding + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated container for logo and title with premium effects
                      AnimatedBuilder(
                        animation: _moveUpAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _moveUpAnimation.value),
                            child: Column(
                              children: [
                                // Logo container with simplified entrance animation
                                Container(
                                  width: size.width * 0.4,
                                  height: size.width * 0.4,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.whiteOpacity10,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AppColors.whiteOpacity20,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.blackOpacity20,
                                        blurRadius: 15,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: size.width * 0.25,
                                    fit: BoxFit.contain,
                                  ),
                                )
                                .animate()
                                .fadeIn(
                                  delay: 100.ms,
                                  duration: 400.ms,
                                  curve: Curves.easeOut,
                                ),

                                SizedBox(height: size.height * 0.05),

                                // Title text with simplified animation
                                Text(
                                  'Welcome to DuckBuck',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 1,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                                .animate()
                                .fadeIn(
                                  delay: 200.ms,
                                  duration: 400.ms,
                                  curve: Curves.easeOut,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Continue button with premium interaction animations
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleContinuePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pureWhite,
                      foregroundColor: AppColors.pureBlack,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      elevation: 0,
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return AppColors.whiteOpacity50;
                        }
                        return AppColors.pureWhite;
                      }),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.blackOpacity70,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: Platform.isIOS ? FontWeight.w600 : FontWeight.bold,
                                  color: AppColors.pureBlack,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Platform.isIOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
                                size: 16,
                                color: AppColors.pureBlack,
                              ),
                            ],
                          ),
                  )
                  .animate()
                  .fadeIn(
                    delay: 300.ms,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
