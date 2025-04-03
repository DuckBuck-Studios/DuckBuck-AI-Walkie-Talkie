import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';
import '../../providers/auth_provider.dart' as auth;
import 'gender_screen.dart';
import 'package:intl/intl.dart';
import '../../widgets/animated_background.dart';

class DOBScreen extends StatefulWidget {
  const DOBScreen({super.key});

  @override
  State<DOBScreen> createState() => _DOBScreenState();
}

class _DOBScreenState extends State<DOBScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = DateTime(now.year - 18, now.month, now.day);
    final DateTime firstDate = DateTime(now.year - 100);
    final DateTime lastDate = DateTime(now.year - 13, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4A76A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD4A76A),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveDOB() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      _showErrorSnackBar('Please select your date of birth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the auth provider
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Calculate age
      final DateTime now = DateTime.now();
      final int age = now.year - _selectedDate!.year - 
          (now.month > _selectedDate!.month || 
          (now.month == _selectedDate!.month && now.day >= _selectedDate!.day) ? 0 : 1);
      
      // Save DOB to user profile metadata
      await authProvider.updateUserProfile(
        metadata: {
          'dateOfBirth': _selectedDate!.toIso8601String(),
          'age': age.toString(),
        },
      );
      
      // Update onboarding stage to gender
      await authProvider.updateOnboardingStage(auth.OnboardingStage.gender);
      
      // Log for debugging
      print('DOBScreen: Saved DOB: ${_selectedDate!.toIso8601String()}, Age: $age');
      
      // Navigate to Gender screen if mounted
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const GenderScreen(),
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
      _showErrorSnackBar('Unable to save your date of birth. Please try again.');
      print('DOBScreen: Error saving DOB: $e');
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isLoading,
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
                  
                  // Calendar icon
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A76A).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today,
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
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  
                  // Title and subtitle
                  Text(
                    "When were you born?",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(begin: 0.3, end: 0),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  
                  Text(
                    "We'll use this to customize your experience",
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
                  
                  // Date picker form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Date picker button remains the same
                        InkWell(
                          onTap: () => _selectDate(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedDate != null 
                                    ? const Color(0xFFD4A76A) 
                                    : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withOpacity(0.9),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: _selectedDate != null 
                                      ? const Color(0xFFD4A76A) 
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? DateFormat('MMMM d, yyyy').format(_selectedDate!)
                                        : 'Select your birth date',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _selectedDate != null 
                                          ? Colors.black87 
                                          : Colors.grey.shade600,
                                      fontWeight: _selectedDate != null 
                                          ? FontWeight.w500 
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 300),
                        ),
                        
                        if (_selectedDate != null) ...[
                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4A76A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFFD4A76A),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You are ${DateTime.now().year - _selectedDate!.year} years old',
                                    style: const TextStyle(
                                      color: Color(0xFFD4A76A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ],
                    ),
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
                      child: _isLoading 
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
                          child: NeoPopButton(
                            color: const Color(0xFFD4A76A),
                            onTapUp: _saveDOB,
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
                                  Text(
                                    'Continue',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.arrow_forward, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}