import 'package:duckbuck/screens/onboarding/profile_photo_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';
import '../../app/providers/auth_provider.dart' as auth; 

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  bool _isLoading = false;
  late AnimationController _animationController;
  
  // Enhanced gradient for background
  final LinearGradient _backgroundGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9C78E), Color(0xFFD4A76A)],
  );

  final List<Map<String, dynamic>> _genderOptions = [
    {
      'value': 'Male',
      'icon': Icons.male_rounded,
      'description': 'He/Him',
    },
    {
      'value': 'Female',
      'icon': Icons.female_rounded,
      'description': 'She/Her',
    },
    {
      'value': 'Prefer not to say',
      'icon': Icons.visibility_off_rounded,
      'description': 'Not specified',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveGender() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGender == null) {
      _showErrorSnackBar('Please select your gender');
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    String gender = _selectedGender!;

    try {
      // Get the auth provider
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Save gender to user profile metadata
      await authProvider.updateUserProfile(
        metadata: {
          'gender': gender,
          'current_onboarding_stage': 'profilePhoto', // Explicitly set the stage
        },
      );
      
      // Update onboarding stage to profilePhoto
      await authProvider.updateOnboardingStage(auth.OnboardingStage.profilePhoto);
      
      // Log for debugging
      if (kDebugMode) {
        print('GenderScreen: Saved gender: $gender');
      }
      
      // Navigate to Profile Photo screen if mounted
      if (mounted) {
        // Navigate to Profile Photo screen with a smooth transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ProfilePhotoScreen(),
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
      // Handle error
      if (kDebugMode) {
        print('GenderScreen: Error saving gender: $e');
      }
      _showErrorSnackBar('Unable to save your gender. Please try again.');
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
  
  void _selectGender(String gender) {
    setState(() {
      _selectedGender = gender;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return WillPopScope(
      onWillPop: () async => !_isLoading,
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
                      
                      // User icon with enhanced animation
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
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .scale(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.0, 1.0),
                      ),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Title with enhanced animation
                      Text(
                        "What's your gender?",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 200))
                      .slideY(
                        begin: 0.3, 
                        end: 0, 
                        duration: const Duration(milliseconds: 800), 
                        curve: Curves.easeOutQuint
                      )
                      .shimmer(
                        duration: const Duration(milliseconds: 1200),
                        delay: const Duration(milliseconds: 900),
                        color: Colors.white.withOpacity(0.8),
                      ),
                      
                      SizedBox(height: screenHeight * 0.01),
                      
                      // Subtitle with staggered animation
                      Text(
                        "This helps us personalize your experience",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 400),
                      )
                      .slideY(
                        begin: 0.3, 
                        end: 0, 
                        delay: const Duration(milliseconds: 400), 
                        duration: const Duration(milliseconds: 800)
                      ),
                      
                      const Spacer(flex: 1),
                      
                      // Enhanced gender selection
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Gender selection cards
                            ..._genderOptions.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final option = entry.value;
                              final bool isSelected = _selectedGender == option['value'];
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () => _selectGender(option['value']),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFD4A76A) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isSelected ? 0.15 : 0.08),
                                          blurRadius: isSelected ? 12 : 8,
                                          spreadRadius: isSelected ? 2 : 0,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Icon container
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? Colors.white.withOpacity(0.3) 
                                                : const Color(0xFFD4A76A).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            option['icon'],
                                            color: isSelected ? Colors.white : const Color(0xFFD4A76A),
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Text content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                option['value'],
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                option['description'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isSelected 
                                                      ? Colors.white.withOpacity(0.9) 
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Selection indicator
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Color(0xFFD4A76A),
                                              size: 16,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ).animate(controller: _animationController)
                                .fadeIn(
                                  duration: const Duration(milliseconds: 600),
                                  delay: Duration(milliseconds: 600 + (index * 100)),
                                )
                                .slideY(
                                  begin: 0.3, 
                                  end: 0, 
                                  delay: Duration(milliseconds: 600 + (index * 100)),
                                  duration: const Duration(milliseconds: 600),
                                );
                            }),
                          ],
                        ),
                      ),
                      
                      const Spacer(flex: 4),
                      
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
                            onTapUp: _saveGender,
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
                                children: const [
                                  Text(
                                    'Continue',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(Icons.arrow_forward, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        )
                      .animate(controller: _animationController)
                      .fadeIn(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 800),
                      )
                      .slideY(begin: 0.3, end: 0, delay: const Duration(milliseconds: 800), duration: const Duration(milliseconds: 800)),
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
        .fadeIn(duration: const Duration(milliseconds: 1000))
        .slideX(begin: 0.3, end: 0, duration: const Duration(milliseconds: 1200), curve: Curves.easeOutQuint),
        
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
        .fadeIn(duration: const Duration(milliseconds: 1000), delay: const Duration(milliseconds: 200))
        .slideY(begin: 0.2, end: 0, duration: const Duration(milliseconds: 1200), curve: Curves.easeOutQuint),
      
      // Small shape elements
      Positioned(
        top: screenSize.height * 0.25,
        left: screenSize.width * 0.2,
        child: Transform.rotate(
          angle: 0.3,
          child: Container(
            width: 20,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 300))
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 600), 
          delay: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
        ),
        
      Positioned(
        bottom: screenSize.height * 0.3,
        right: screenSize.width * 0.15,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 400))
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 600), 
          delay: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
        ),
    ];
  }
}