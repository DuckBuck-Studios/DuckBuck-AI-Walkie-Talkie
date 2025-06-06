import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../components/auth_bottom_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Create move up animation
    _moveUpAnimation = Tween<double>(
      begin: 0.0,
      end: -120.0, // Move up by 120 pixels when bottom sheet opens
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Add haptic feedback when screen appears with platform-specific intensity
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleContinuePressed() {
    // Don't process if already loading
    if (_isLoading) return;
    
    // Start animation to move content up
    _animationController.forward();
    
    // Show auth bottom sheet component
    AuthBottomSheet.show(
      context: context,
      onAuthComplete: _completeWithDemo,
    ).then((_) {
      // Reset animation when bottom sheet is dismissed
      _animationController.reverse();
    });
  }
  
  void _completeWithDemo() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate a short processing time (can be removed in production)
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Complete onboarding process
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isIOS = Platform.isIOS;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          // Decorative background elements
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

          // Small decorative circles
          ...List.generate(8, (index) {
            final random = index * 37 % 100;
            return Positioned(
              top: size.height * (random % 80) / 100,
              left: size.width * ((random * 3) % 90) / 100,
              child: Container(
                height: 6 + (random % 10),
                width: 6 + (random % 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.whiteOpacity30,
                ),
              ),
            );
          }),

          // Content container
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
                      // Animated container for logo and title
                      AnimatedBuilder(
                        animation: _moveUpAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _moveUpAnimation.value),
                            child: Column(
                              children: [
                                // Logo container with animation
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
                                ),

                                SizedBox(height: size.height * 0.05),

                                // Title text with animation
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
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Continue button with animation
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
                        : Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold,
                              color: AppColors.pureBlack,
                            ),
                          ),
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
