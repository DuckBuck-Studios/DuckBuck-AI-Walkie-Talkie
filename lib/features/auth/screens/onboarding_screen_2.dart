import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../styles/onboarding_styles.dart';

class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2> {
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
                        // Container with Lottie animation - made consistent with screen 1
                        Container(
                          height:
                              OnboardingStyles.illustrationSize(size).height,
                          width: OnboardingStyles.illustrationSize(size).width,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
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
    );
  }

  Widget _buildPageIndicator({required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 10,
      width: isActive ? 24 : 10,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
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
