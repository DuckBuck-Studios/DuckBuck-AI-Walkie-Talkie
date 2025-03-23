import 'package:duckbuck/screens/Authentication/auth_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:duckbuck/widgets/terms_agreement_widget.dart';
import 'package:duckbuck/widgets/animated_background.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen size information for responsive adjustments
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    final safePadding = MediaQuery.of(context).padding;
    
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate appropriate font and element sizes based on screen width
              final titleFontSize = constraints.maxWidth * 0.09;
              final subtitleFontSize = constraints.maxWidth * 0.045;
              final lottieSize = constraints.maxWidth * 0.5;
              
              return Column(
                children: [
                  // Top shimmer title with 3D effect
                  Padding(
                    padding: EdgeInsets.only(
                      top: isSmallScreen ? 20.0 : 40.0,
                      left: 16.0,
                      right: 16.0,
                    ),
                    child: Column(
                      children: [
                        // 3D DuckBuck title
                        Stack(
                          children: [
                            // Shadow layers for 3D effect
                            Positioned(
                              left: 3,
                              top: 3,
                              child: Text(
                                "DuckBuck",
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.brown.shade900.withOpacity(0.3),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 2,
                              top: 2,
                              child: Text(
                                "DuckBuck",
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.brown.shade800.withOpacity(0.5),
                                ),
                              ),
                            ),
                            // Main text with shimmer
                            Shimmer.fromColors(
                              baseColor: Colors.brown.shade700,
                              highlightColor: Colors.amber.shade300,
                              child: Text(
                                "DuckBuck",
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Enhanced subtitle: Your Internet Walkie Talkie
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade200.withOpacity(0.7),
                                  Colors.amber.shade300.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.brown.shade200.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.brown.shade400.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              "Your Internet Walkie Talkie",
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: Colors.brown.shade800,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Expanded space for mic animation
                  Expanded(
                    child: Center(
                      child: Lottie.asset(
                        'assets/animations/mic.json',
                        width: lottieSize,
                        height: lottieSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  // Terms and Privacy Policy agreement
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.08, 
                      vertical: isSmallScreen ? 5.0 : 10.0
                    ),
                    child: const TermsAgreementWidget(),
                  ),
                  
                  // Bottom button
                  Padding(
                    padding: EdgeInsets.only(
                      left: constraints.maxWidth * 0.08, 
                      right: constraints.maxWidth * 0.08, 
                      bottom: safePadding.bottom + (isSmallScreen ? 20.0 : 50.0),
                      top: 10.0,
                    ),
                    child: DuckBuckButton(
                      text: "Let's Go",
                      onTap: () {
                        // Add haptic feedback
                        HapticFeedback.mediumImpact();
                        
                        // Navigate to the next screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const AuthScreen()),
                        );
                      },
                      color: const Color(0xFFD4A76A),
                      borderColor: const Color(0xFFB38B4D),
                      textColor: Colors.white,
                      alignment: MainAxisAlignment.center,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24, 
                        vertical: isSmallScreen ? 12 : 15
                      ),
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: constraints.maxWidth * 0.045,
                        letterSpacing: 0.5,
                      ),
                      height: isSmallScreen ? 48 : 55,
                      width: double.infinity,
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}