import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../styles/onboarding_styles.dart';

class OnboardingScreen1 extends StatefulWidget {
  const OnboardingScreen1({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<OnboardingScreen1> createState() => _OnboardingScreen1State();
}

class _OnboardingScreen1State extends State<OnboardingScreen1> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();

    // Add haptic feedback when screen appears
    HapticFeedback.mediumImpact();

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

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          // Add decorative background elements similar to screens 2 and 3
          Positioned(
                top: size.height * 0.1,
                right: -size.width * 0.2,
                child: Container(
                  height: size.width * 0.6,
                  width: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              )
              .animate(target: _isReady ? 1 : 0)
              .fadeIn(duration: 800.ms)
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1.0, 1.0),
                duration: 1000.ms,
                curve: Curves.easeOutCubic,
              ),

          Positioned(
                bottom: -size.height * 0.1,
                left: -size.width * 0.15,
                child: Container(
                  height: size.width * 0.7,
                  width: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              )
              .animate(target: _isReady ? 1 : 0)
              .fadeIn(duration: 800.ms, delay: 200.ms)
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1.0, 1.0),
                duration: 1000.ms,
              ),

          // Small decorative circles
          ...List.generate(8, (index) {
            return Positioned(
                  top: size.height * 0.2 + (index * 50),
                  left: index % 2 == 0 ? size.width * 0.85 : size.width * 0.15,
                  child: Container(
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                )
                .animate(target: _isReady ? 1 : 0)
                .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                .scale(begin: const Offset(0, 0), end: const Offset(1.0, 1.0));
          }),

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
                        // Lottie animation instead of icon
                        Container(
                              height:
                                  OnboardingStyles.illustrationSize(
                                    size,
                                  ).height,
                              width:
                                  OnboardingStyles.illustrationSize(size).width,
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
                                  'assets/animations/world-wide.json',
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
                            )
                            .animate(target: _isReady ? 1 : 0)
                            .fadeIn(duration: 800.ms, delay: 300.ms)
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              duration: 700.ms,
                              curve: Curves.easeOutQuad,
                            ),

                        SizedBox(height: size.height * 0.05),

                        // Regular title with animation
                        const Text(
                              'Connect Anywhere',
                              style: OnboardingStyles.titleStyle,
                            )
                            .animate(target: _isReady ? 1 : 0)
                            .fadeIn(duration: 600.ms, delay: 500.ms)
                            .slideY(begin: 0.3, end: 0, duration: 500.ms),

                        SizedBox(height: size.height * 0.03),

                        // Description with improved visibility and animation
                        Text(
                              'Connect with friends and family from anywhere in the world. Just one tap away from global communication.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            )
                            .animate(target: _isReady ? 1 : 0)
                            .fadeIn(duration: 600.ms, delay: 700.ms)
                            .slideY(begin: 0.3, end: 0, duration: 500.ms),
                      ],
                    ),
                  ),
                ),

                // Swipe indicator instead of next button
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: Column(
                    children: [
                      // Page indicator
                      Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPageIndicator(isActive: true, index: 0),
                              _buildPageIndicator(isActive: false, index: 1),
                              _buildPageIndicator(isActive: false, index: 2),
                              _buildPageIndicator(isActive: false, index: 3),
                            ],
                          )
                          .animate(target: _isReady ? 1 : 0)
                          .fadeIn(duration: 600.ms, delay: 900.ms),

                      const SizedBox(height: 20),

                      // Swipe indicator with pulsing animation
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

  Widget _buildPageIndicator({required bool isActive, required int index}) {
    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 10,
          width: isActive ? 24 : 10,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(5),
          ),
        )
        .animate(target: _isReady ? 1 : 0)
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          delay: (100 * index).ms,
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildSwipeIndicator() {
    return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Swipe to continue',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        )
        .animate(target: _isReady ? 1 : 0)
        .fadeIn(delay: 1000.ms, duration: 600.ms)
        .then()
        .animate(onPlay: (controller) => controller.repeat());
  }
}
