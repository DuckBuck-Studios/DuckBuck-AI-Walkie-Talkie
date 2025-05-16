import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../styles/onboarding_styles.dart';

class OnboardingScreen3 extends StatefulWidget {
  const OnboardingScreen3({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<OnboardingScreen3> createState() => _OnboardingScreen3State();
}

class _OnboardingScreen3State extends State<OnboardingScreen3> {
  @override
  void initState() {
    super.initState();
    // Keep haptic feedback when screen appears
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          // Decorative background elements
          Positioned(
            top: -size.height * 0.1,
            left: -size.width * 0.1,
            child: Container(
              height: size.width * 0.7,
              width: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),

          Positioned(
            bottom: -size.height * 0.05,
            right: -size.width * 0.1,
            child: Container(
              height: size.width * 0.6,
              width: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),

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
                        // Container with Lottie animation - made consistent with other screens
                        Container(
                          height:
                              OnboardingStyles.illustrationSize(size).height,
                          width: OnboardingStyles.illustrationSize(size).width,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Lottie.asset(
                              'assets/animations/end-to-end.json',
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
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.05),

                        // Title
                        const Text(
                          'Stay Secure',
                          style: OnboardingStyles.titleStyle,
                        ),

                        SizedBox(height: size.height * 0.03),

                        // Description with improved visibility
                        const Text(
                          'Your security is our priority. All your communications are encrypted and protected. No one can access your data but you.',
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

                // Bottom section with page indicators
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: Column(
                    children: [
                      // Page indicator - now with 4 dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPageIndicator(isActive: false),
                          _buildPageIndicator(isActive: false),
                          _buildPageIndicator(isActive: true),
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
    );
  }

  Widget _buildPageIndicator({required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 10,
      width: isActive ? 24 : 10,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildSwipeIndicator() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Swipe to continue',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        SizedBox(width: 8),
        Icon(Icons.arrow_forward, color: Colors.white, size: 20),
      ],
    );
  }
}
