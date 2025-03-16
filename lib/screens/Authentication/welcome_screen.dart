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
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top shimmer title with 3D effect
              Padding(
                padding: const EdgeInsets.only(top: 40.0),
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
                              fontSize: 36,
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
                              fontSize: 36,
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
                          child: const Text(
                            "DuckBuck",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Enhanced subtitle: Your Internet Walkie Talkie
                    const SizedBox(height: 12),
                    Container(
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
                          fontSize: 18,
                          color: Colors.brown.shade800,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
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
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              // Terms and Privacy Policy agreement
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
                child: TermsAgreementWidget(),
              ),
              
              // Bottom button
              Padding(
                padding: const EdgeInsets.only(
                  left: 30.0, 
                  right: 30.0, 
                  bottom: 50.0
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
                  color: const Color(0xFFD4A76A), // Warm caramel color that complements ghee
                  borderColor: const Color(0xFFB38B4D), // Slightly darker border
                  textColor: Colors.white,
                  alignment: MainAxisAlignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                  height: 55, // Slightly taller button
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}