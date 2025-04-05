import 'package:duckbuck/screens/Authentication/auth_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:duckbuck/widgets/terms_agreement_widget.dart';
import 'package:duckbuck/widgets/animated_background.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math' as math;

class WelcomeScreen extends StatefulWidget {
  final bool accountDeleted;
  final bool loggedOut;
  
  const WelcomeScreen({
    super.key, 
    this.accountDeleted = false,
    this.loggedOut = false,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    
    // Show appropriate dialog after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.accountDeleted) {
        _showAccountDeletedDialog();
      } else if (widget.loggedOut) {
        _showLoggedOutDialog();
      }
    });
  }

  // Show account deleted success dialog with animation
  void _showAccountDeletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: const Color(0xFFF5E8C7),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animation from assets
                Lottie.asset(
                  'assets/animations/delete.json',
                  width: 120,
                  height: 120,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Account Deleted Successfully',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your account and all related data have been successfully deleted.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B4513),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A76A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show logged out success dialog without animation
  void _showLoggedOutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: const Color(0xFFF5E8C7),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon instead of animation
                const Icon(
                  Icons.logout_rounded,
                  size: 70,
                  color: Color(0xFFD4A76A),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Logged Out Successfully',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'You have been successfully logged out of your account.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B4513),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A76A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
                  Container(
                    margin: EdgeInsets.only(
                      left: constraints.maxWidth * 0.06, 
                      right: constraints.maxWidth * 0.06, 
                      bottom: math.max(safePadding.bottom + 16.0, 24.0),
                      top: 10.0,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: 500, // Prevent button from becoming too wide on large screens
                      minHeight: 48, // Minimum touch target size
                    ),
                    child: LayoutBuilder(
                      builder: (context, btnConstraints) {
                        // Calculate appropriate button height based on screen size
                        final buttonHeight = math.min(
                          math.max(48.0, constraints.maxHeight * 0.07),
                          65.0 // Maximum button height
                        );
                        
                        // Calculate appropriate font size
                        final fontSize = math.min(
                          math.max(16.0, constraints.maxWidth * 0.04),
                          22.0 // Maximum font size
                        );

                        return DuckBuckButton(
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
                            horizontal: math.max(16.0, btnConstraints.maxWidth * 0.05),
                            vertical: 0, // Height is controlled by container
                          ),
                          icon: const Icon(Icons.arrow_forward, color: Colors.white),
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: fontSize,
                            letterSpacing: 0.5,
                          ),
                          height: buttonHeight,
                          width: double.infinity,
                        );
                      }
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