import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../styles/onboarding_styles.dart';

class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2> {
  bool _isReady = false;
  
  @override
  void initState() {
    super.initState();
    
    // Add haptic feedback when screen appears with platform-specific intensity
    if (Platform.isIOS) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    
    // Trigger animations after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isIOS = Platform.isIOS;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: size.height * 0.15,
              left: -size.width * 0.2,
              child: Container(
                height: size.width * 0.6,
                width: size.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            Positioned(
              bottom: -size.height * 0.1,
              right: -size.width * 0.1,
              child: Container(
                height: size.width * 0.8,
                width: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),

            // Small decorative circles
            ...List.generate(10, (index) {
              return Positioned(
                top: size.height * (index / 20) + (index * 10),
                left: index % 2 == 0 ? size.width * 0.8 : size.width * 0.2,
                child: Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              );
            }),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Content - Expanded to take available space
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Container with optimized Lottie animation - made consistent with screen 1
                          RepaintBoundary(
                            child: Container(
                              height:
                                  OnboardingStyles.illustrationSize(size).height,
                              width: OnboardingStyles.illustrationSize(size).width,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isIOS ? 18 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Lottie.asset(
                                  'assets/animations/push-to-talk.json',
                                  height:
                                      OnboardingStyles.illustrationSize(
                                        size,
                                      ).height *
                                      0.7,
                                  width:
                                      OnboardingStyles.illustrationSize(
                                        size,
                                      ).width *
                                      0.7,
                                  fit: BoxFit.contain,
                                  // Optimize memory usage when rendering Lottie
                                  frameRate: FrameRate(30),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: size.height * 0.05),

                          // Title
                          const Text(
                            'Talk Instantly',
                            style: OnboardingStyles.titleStyle,
                          ),

                          SizedBox(height: size.height * 0.03),

                          // Description with improved visibility
                          const Text(
                            'Communicate like a walkie-talkie with just one tap. Fast, reliable, and secure voice messaging when you need it most.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom section with page indicator dots
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Column(
                      children: [
                        // Page indicator - now with 4 dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPageIndicator(isActive: false),
                            _buildPageIndicator(isActive: true),
                            _buildPageIndicator(isActive: false),
                            _buildPageIndicator(isActive: false),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Swipe indicator
                        _buildSwipeIndicator(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator({required bool isActive}) {
    final bool isIOS = Platform.isIOS;
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: isIOS ? 8 : 10,
        width: isActive ? (isIOS ? 20 : 24) : (isIOS ? 8 : 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(isIOS ? 4 : 5),
        ),
      ),
    );
  }

  Widget _buildSwipeIndicator() {
    final bool isIOS = Platform.isIOS;
    
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isIOS)
            const Text(
              'Swipe to continue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            )
          else
            const Text(
              'SWIPE TO CONTINUE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          SizedBox(width: isIOS ? 6 : 8),
          Icon(
            isIOS ? CupertinoIcons.arrow_right : Icons.arrow_forward_rounded,
            color: Colors.white,
            size: isIOS ? 16 : 18,
          ),
        ],
      )
      .animate(target: _isReady ? 1 : 0)
      .fadeIn(delay: 1000.ms, duration: 600.ms)
      .then()
      .animate(
        onPlay: (controller) => controller.repeat(),
        effects: [
          FadeEffect(
            begin: 1.0,
            end: 0.6,
            duration: 800.ms,
            curve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}
