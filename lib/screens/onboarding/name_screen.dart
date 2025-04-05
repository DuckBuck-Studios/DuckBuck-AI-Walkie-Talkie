import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart'; 
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';
import '../../providers/auth_provider.dart' as auth;
import 'dob_screen.dart'; 

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _animationController;
  
  // Enhanced gradient for background
  final LinearGradient _backgroundGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9C78E), Color(0xFFD4A76A)],
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

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
      
      // Navigate to DOB screen with enhanced transition
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const DOBScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Use curve animation for smoother transition
              var curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuint,
              );
              
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Unable to save your name. Please try again.');
      print('NameScreen: Error saving name: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return WillPopScope(
      onWillPop: () async => !_isLoading, // Prevent going back during loading
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: _backgroundGradient,
          ),
          child: Stack(
            children: [
              // Background decorative elements
              ..._buildBackgroundElements(),
              
              // Main content
              SafeArea(
                child: Container(
                  height: screenHeight,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      
                      // Welcome image/icon with enhanced animation
                      Container(
                        width: screenWidth * 0.3,
                        height: screenWidth * 0.3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB38B4D).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 60,
                          color: Color(0xFFB38B4D),
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(duration: 600.ms)
                      .scale(
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.0, 1.0),
                      ),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Title with enhanced animation
                      Text(
                        "What's your name?",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(duration: 600.ms, delay: 100.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOutQuint)
                      .shimmer(
                        duration: 600.ms,
                        delay: 300.ms,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      
                      SizedBox(height: screenHeight * 0.01),
                      
                      // Subtitle with staggered animation
                      Text(
                        "We'll use this to personalize your experience",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(
                        duration: 600.ms,
                        delay: 200.ms,
                      )
                      .slideY(begin: 0.3, end: 0, delay: 200.ms, duration: 600.ms),
                      
                      const Spacer(flex: 1),
                      
                      // Enhanced name input field
                      Form(
                        key: _formKey,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                spreadRadius: 0,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
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
                              color: Color(0xFFB38B4D),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _saveName(),
                          ),
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(
                        duration: 600.ms,
                        delay: 300.ms,
                      )
                      .slideY(begin: 0.3, end: 0, delay: 300.ms, duration: 600.ms, curve: Curves.easeOutQuint),
                      
                      const Spacer(flex: 2),
                      
                      // Enhanced continue button
                      _isLoading 
                      ? Container(
                          height: 100,
                          width: 100,
                          alignment: Alignment.center,
                          child: Lottie.asset(
                            'assets/animations/loading1.json',
                            width: 80,
                            height: 80,
                            repeat: true,
                            animate: true,
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 65,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB38B4D).withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: NeoPopButton(
                            color: const Color(0xFFD4A76A),
                            onTapUp: _saveName,
                            onTapDown: () {},
                            border: Border.all(
                              color: const Color(0xFFB38B4D),
                              width: 1.5,
                            ),
                            depth: 10,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Continue',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        )
                      .animate(controller: _animationController)
                      .fadeIn(
                        duration: 600.ms,
                        delay: 400.ms,
                      )
                      .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 600.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Add decorative background elements
  List<Widget> _buildBackgroundElements() {
    final screenSize = MediaQuery.of(context).size;
    
    return [
      // Top right decorative circle
      Positioned(
        top: screenSize.height * 0.1,
        right: -screenSize.width * 0.1,
        child: Container(
          width: screenSize.width * 0.4,
          height: screenSize.width * 0.4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: 800.ms)
        .slideX(begin: 0.3, end: 0, duration: 800.ms, curve: Curves.easeOutQuint),
        
      // Bottom left decorative shape
      Positioned(
        bottom: -screenSize.width * 0.2,
        left: -screenSize.width * 0.1,
        child: Container(
          width: screenSize.width * 0.7,
          height: screenSize.width * 0.7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(screenSize.width * 0.3),
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: 800.ms, delay: 100.ms)
        .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutQuint),
        
      // Small circles pattern
      ..._buildSmallCircles(),
    ];
  }
  
  // Create a pattern of small circles
  List<Widget> _buildSmallCircles() {
    final screenSize = MediaQuery.of(context).size;
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(6, (index) {
      // Use a seeded random to create consistent but random-looking positioning
      final posX = (((random + index * 100) % 83) / 100) * screenSize.width;
      final posY = (((random + index * 200) % 91) / 100) * screenSize.height;
      final size = (((random + index * 50) % 30) + 10.0);
      
      return Positioned(
        top: posY,
        left: posX,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: 800.ms, delay: (100 + index * 50).ms)
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 800.ms,
          delay: (100 + index * 50).ms,
        );
    });
  }
}