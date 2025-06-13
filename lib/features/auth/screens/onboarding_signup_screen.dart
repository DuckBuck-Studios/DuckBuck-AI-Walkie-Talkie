import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    _animationController.dispose();
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
    
    // Complete onboarding process
    widget.onComplete();
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
          // Enhanced decorative background elements with animations
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
            )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              duration: 4000.ms,
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.2, 1.2),
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              duration: 4000.ms,
              begin: const Offset(1.2, 1.2),
              end: const Offset(0.8, 0.8),
              curve: Curves.easeInOut,
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
            )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              duration: 3500.ms,
              begin: const Offset(1.1, 1.1),
              end: const Offset(0.9, 0.9),
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              duration: 3500.ms,
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              curve: Curves.easeInOut,
            ),
          ),

          // Floating particle animations
          ...List.generate(8, (index) {
            final random = index * 37 % 100;
            final delay = (index * 200 + random * 10).ms;
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
              )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(delay: delay, duration: 1000.ms)
              .then()
              .moveY(
                duration: (3000 + random * 20).ms,
                begin: 0,
                end: -50,
                curve: Curves.easeInOut,
              )
              .fadeOut(duration: 500.ms)
              .then(delay: (500 + random * 100).ms),
            );
          }),

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
                                // Logo container with sophisticated entrance animation
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
                                .scale(
                                  delay: 200.ms,
                                  duration: 800.ms,
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1.0, 1.0),
                                  curve: Curves.elasticOut,
                                )
                                .fadeIn(
                                  delay: 100.ms,
                                  duration: 600.ms,
                                  curve: Curves.easeOutExpo,
                                )
                                .shimmer(
                                  delay: 1000.ms,
                                  duration: 1500.ms,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),

                                SizedBox(height: size.height * 0.05),

                                // Title text with staggered character animation
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
                                  delay: 400.ms,
                                  duration: 800.ms,
                                  curve: Curves.easeOutExpo,
                                )
                                .slideY(
                                  delay: 400.ms,
                                  duration: 800.ms,
                                  begin: 0.3,
                                  end: 0.0,
                                  curve: Curves.easeOutExpo,
                                )
                                .then()
                                .shimmer(
                                  delay: 500.ms,
                                  duration: 2000.ms,
                                  color: AppColors.accentBlue.withValues(alpha: 0.2),
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
                    delay: 800.ms,
                    duration: 600.ms,
                    curve: Curves.easeOutExpo,
                  )
                  .slideY(
                    delay: 800.ms,
                    duration: 600.ms,
                    begin: 0.5,
                    end: 0.0,
                    curve: Curves.easeOutExpo,
                  )
                  .scale(
                    delay: 800.ms,
                    duration: 600.ms,
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    curve: Curves.easeOutBack,
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
