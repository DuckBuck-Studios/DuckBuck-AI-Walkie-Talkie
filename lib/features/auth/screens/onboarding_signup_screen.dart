import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../styles/onboarding_styles.dart';
import '../components/auth_bottom_sheet.dart';

class OnboardingSignupScreen extends StatefulWidget {
  const OnboardingSignupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingSignupScreen> createState() => _OnboardingSignupScreenState();
}

class _OnboardingSignupScreenState extends State<OnboardingSignupScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Add haptic feedback when screen appears with platform-specific intensity
    HapticFeedback.mediumImpact();
  }

  void _handleContinuePressed() {
    // Don't process if already loading
    if (_isLoading) return;
    
    // Show auth bottom sheet component
    AuthBottomSheet.show(
      context: context,
      onAuthComplete: _completeWithDemo,
    );
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
                color: Colors.white.withOpacity(0.1),
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
                color: Colors.white.withOpacity(0.15),
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
                  color: Colors.white.withOpacity(0.3),
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
                      // Logo container with animation
                      Container(
                        width: size.width * 0.4,
                        height: size.width * 0.4,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
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
                        style: OnboardingStyles.titleStyle,
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: size.height * 0.03),

                      // Description text with animation
                      Text(
                        'Secure messaging and voice chat at your fingertips',
                        style: OnboardingStyles.subtitleStyle,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Continue button with animation
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleContinuePressed,
                    style: OnboardingStyles.primaryButtonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.disabled)) {
                          return Colors.white.withOpacity(0.5);
                        }
                        return Colors.white;
                      }),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black.withOpacity(0.7),
                              ),
                            ),
                          )
                        : Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold,
                              color: Colors.black,
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
