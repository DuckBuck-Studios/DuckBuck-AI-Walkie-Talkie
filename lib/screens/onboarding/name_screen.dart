import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart' as auth;
import 'dob_screen.dart';
import '../../widgets/animated_background.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Get the auth provider
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Save name to user profile
      await authProvider.updateUserProfile(
        displayName: _nameController.text.trim(),
      );
      
      // Update onboarding stage to dateOfBirth
      await authProvider.updateOnboardingStage(auth.OnboardingStage.dateOfBirth);
      
      print('NameScreen: Saved name: ${_nameController.text.trim()}');
      
      // Navigate to DOB screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const DOBScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save name: ${e.toString()}');
      print('NameScreen: Error saving name: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: SafeArea(
          child: Container(
            height: screenHeight,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Welcome image/icon
                Container(
                  width: screenWidth * 0.3,
                  height: screenWidth * 0.3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A76A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 60,
                    color: Color(0xFFD4A76A),
                  ),
                )
                .animate()
                .scale(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                ),
                
                SizedBox(height: screenHeight * 0.03),
                
                // Title and subtitle
                Text(
                  "What's your name?",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 500))
                .slideY(begin: 0.3, end: 0),
                
                SizedBox(height: screenHeight * 0.01),
                
                Text(
                  "We'll use this to personalize your experience",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                ),
                
                const Spacer(flex: 1),
                
                // Name field in the middle
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFD4A76A),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveName(),
                  ),
                )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 300),
                )
                .slideY(begin: 0.2, end: 0),
                
                const Spacer(flex: 2),
                
                // Continue button - move to bottom of screen
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 30.0, 
                      right: 30.0, 
                      bottom: 30.0
                    ),
                    child: DuckBuckButton(
                      text: 'Continue',
                      onTap: _saveName,
                      color: const Color(0xFFD4A76A),
                      borderColor: const Color(0xFFB38B4D),
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
                      height: 55,
                      width: double.infinity,
                    ),
                  ),
                )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}