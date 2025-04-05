import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart' as auth;
import 'gender_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';

class DOBScreen extends StatefulWidget {
  const DOBScreen({super.key});

  @override
  State<DOBScreen> createState() => _DOBScreenState();
}

class _DOBScreenState extends State<DOBScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
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
      duration: const Duration(milliseconds: 1200),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = DateTime(now.year - 18, now.month, now.day);
    final DateTime firstDate = DateTime(now.year - 100);
    final DateTime lastDate = DateTime(now.year - 13, now.month, now.day);

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // iOS-style date picker with custom styling
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          return Container(
            height: 350,
            padding: const EdgeInsets.only(top: 6.0),
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'Select Date of Birth',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Color(0xFFD4A76A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Provide haptic feedback on selection
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 0),
                  Expanded(
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            fontSize: 22,
                            color: Color(0xFF333333),
                          ),
                        ),
                        primaryColor: Color(0xFFD4A76A),
                      ),
                      child: CupertinoDatePicker(
                        initialDateTime: _selectedDate ?? initialDate,
                        mode: CupertinoDatePickerMode.date,
                        minimumDate: firstDate,
                        maximumDate: lastDate,
                        onDateTimeChanged: (DateTime dateTime) {
                          setState(() {
                            _selectedDate = dateTime;
                          });
                        },
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Material design date picker with custom styling
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
                onSurface: Color(0xFF333333),
                surface: Colors.white,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD4A76A),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );

      if (picked != null && picked != _selectedDate) {
        setState(() {
          _selectedDate = picked;
        });
        
        // Provide haptic feedback on selection
        HapticFeedback.selectionClick();
      }
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
      
      // Debug logging
      debugPrint('DOBScreen: Saved DOB: ${_selectedDate!.toIso8601String()}, Age: $age');
      
      // Navigate to Gender screen if mounted
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const GenderScreen(),
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
      _showErrorSnackBar('Unable to save your date of birth. Please try again.');
      debugPrint('DOBScreen: Error saving DOB: $e');
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
                      
                      // Calendar icon with enhanced animation
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
                          Icons.calendar_month_rounded,
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
                        "When were you born?",
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
                        "We'll customize your experience based on your age",
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
                      
                      // Date picker form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Enhanced date display/button
                            InkWell(
                              onTap: () => _selectDate(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: _selectedDate != null 
                                        ? const Color(0xFFD4A76A) 
                                        : Colors.transparent,
                                    width: _selectedDate != null ? 1.5 : 0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4A76A).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.calendar_month,
                                        color: _selectedDate != null 
                                            ? const Color(0xFFD4A76A) 
                                            : Colors.grey.shade600,
                                        size: 24,
                                      ),
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
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .animate(controller: _animationController)
                            .fadeIn(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 600),
                            )
                            .slideY(
                              begin: 0.3, 
                              end: 0, 
                              delay: const Duration(milliseconds: 600), 
                              duration: const Duration(milliseconds: 600), 
                              curve: Curves.easeOutQuint
                            ),
                            
                            if (_selectedDate != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4A76A).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.cake_rounded,
                                        color: Color(0xFFD4A76A),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'You are ${DateTime.now().year - _selectedDate!.year} years old',
                                            style: const TextStyle(
                                              color: Color(0xFF333333),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Born on ${DateFormat('MMMM d, yyyy').format(_selectedDate!)}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate(controller: _animationController)
                              .fadeIn(
                                duration: const Duration(milliseconds: 400),
                              )
                              .scale(
                                begin: const Offset(0.95, 0.95),
                                end: const Offset(1.0, 1.0),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const Spacer(flex: 4),
                      
                      // Continue button
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
      
      // Calendar decorative elements
      Positioned(
        top: screenSize.height * 0.25,
        left: screenSize.width * 0.1,
        child: Transform.rotate(
          angle: 0.3,
          child: Container(
            width: 15,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(5),
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