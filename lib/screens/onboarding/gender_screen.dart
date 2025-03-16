import 'package:duckbuck/screens/onboarding/profile_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart' as auth;
import '../../widgets/animated_background.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  final TextEditingController _customGenderController = TextEditingController();
  bool _isLoading = false;
  bool _isCustomGender = false;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    
    // Set the onboarding stage to 'gender' when this screen loads,
    // but only if it's not already set to avoid unnecessary updates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      final currentStage = await authProvider.getOnboardingStage();
      
      // Only update if needed
      if (currentStage != auth.OnboardingStage.gender) {
        await authProvider.updateOnboardingStage(auth.OnboardingStage.gender);
      }
    });
  }

  @override
  void dispose() {
    _customGenderController.dispose();
    super.dispose();
  }

  Future<void> _saveGender() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGender == null) {
      _showErrorSnackBar('Please select your gender');
      return;
    }

    String gender = _selectedGender!;
    if (_isCustomGender) {
      gender = _customGenderController.text.trim();
      if (gender.isEmpty) {
        _showErrorSnackBar('Please enter your gender');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the auth provider
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Save gender to user profile metadata
      await authProvider.updateUserProfile(
        metadata: {
          'gender': gender,
        },
      );
      
      // Update onboarding stage to profile photo
      await authProvider.updateOnboardingStage(auth.OnboardingStage.profilePhoto);
      
      // Navigate to home screen if mounted
      if (mounted) {
        // Navigate to Profile Photo screen with a smooth transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ProfilePhotoScreen(),
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
      _showErrorSnackBar('Failed to save gender: ${e.toString()}');
    } finally {
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: DuckBuckAnimatedBackground(
          child: SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // User icon
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.width * 0.3,
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
                  
                  const SizedBox(height: 24),
                  
                  // Title and subtitle
                  Text(
                    "What's your gender?",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(begin: 0.3, end: 0),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    "This helps us personalize your experience",
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
                  
                  const SizedBox(height: 24),
                  
                  // Scrollable form with gender options
                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.9),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGender,
                          hint: Text(
                            'Select your gender',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                          items: _genderOptions
                              .where((gender) => gender != 'Custom') // Remove Custom option
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(
                                  color: _selectedGender == value
                                      ? const Color(0xFFD4A76A)
                                      : Colors.black87,
                                  fontWeight: _selectedGender == value
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedGender = newValue;
                              _isCustomGender = false;
                            });
                          },
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                  ),
                  
                  const Spacer(flex: 4),
                  
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
                        onTap: _isLoading ? () {} : _saveGender,
                        color: const Color(0xFFD4A76A),
                        borderColor: const Color(0xFFB38B4D),
                        textColor: Colors.white,
                        alignment: MainAxisAlignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        icon: _isLoading ? null : const Icon(Icons.arrow_forward, color: Colors.white),
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
      ),
    );
  }

  List<Widget> _buildGenderOptions() {
    return _genderOptions.map((gender) {
      final bool isSelected = _selectedGender == gender;
      final bool isCustom = gender == 'Custom';
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedGender = gender;
              _isCustomGender = isCustom;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFFD4A76A) 
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isSelected 
                  ? const Color(0xFFD4A76A).withOpacity(0.1) 
                  : Colors.white.withOpacity(0.9),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected 
                      ? Icons.check_circle 
                      : Icons.circle_outlined,
                  color: isSelected 
                      ? const Color(0xFFD4A76A) 
                      : Colors.grey.shade500,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    gender,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                      color: isSelected 
                          ? const Color(0xFFD4A76A) 
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}