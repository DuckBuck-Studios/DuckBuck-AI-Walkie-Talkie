import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import 'package:liquid_swipe/liquid_swipe.dart';
import '../../widgets/phone_auth_popup.dart';
import '../../providers/auth_provider.dart' as auth_provider;
import '../../screens/onboarding/name_screen.dart';
import '../../screens/onboarding/dob_screen.dart';
import '../../screens/onboarding/gender_screen.dart';
import '../../screens/onboarding/profile_photo_screen.dart';
import '../../screens/Home/home_screen.dart'; 
import 'dart:math' as math;

// Custom painter for creating dot patterns
class DotPatternPainter extends CustomPainter {
  final Color dotColor;
  final double dotSize;
  final double spacing;

  DotPatternPainter({
    required this.dotColor,
    this.dotSize = 5.0,
    this.spacing = 15.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    // Calculate number of dots based on size and spacing
    final horizontalCount = (size.width / spacing).floor();
    final verticalCount = (size.height / spacing).floor();

    // Draw dots in a grid pattern
    for (int x = 0; x < horizontalCount; x++) {
      for (int y = 0; y < verticalCount; y++) {
        final xPos = x * spacing + spacing / 2;
        final yPos = y * spacing + spacing / 2;
        canvas.drawCircle(Offset(xPos, yPos), dotSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for creating wave patterns
class WavePainter extends CustomPainter {
  final Color color;

  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.25);
    
    // Create a wavy pattern
    for (int i = 0; i < 6; i++) {
      final x1 = size.width * (i / 6);
      final y1 = size.height * (0.25 + (i % 2 == 0 ? 0.1 : -0.1));
      final x2 = size.width * ((i + 1) / 6);
      final y2 = size.height * (0.25 + (i % 2 == 0 ? -0.1 : 0.1));
      
      path.quadraticBezierTo(
        (x1 + x2) / 2, 
        i % 2 == 0 ? size.height * 0.4 : size.height * 0.1, 
        x2, 
        y2
      );
    }
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for creating grid patterns
class GridPatternPainter extends CustomPainter {
  final Color lineColor;
  final double spacing;

  GridPatternPainter({
    required this.lineColor,
    this.spacing = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Calculate number of lines based on size and spacing
    final horizontalCount = (size.height / spacing).floor();
    final verticalCount = (size.width / spacing).floor();

    // Draw horizontal lines
    for (int i = 0; i < horizontalCount; i++) {
      final y = i * spacing;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw vertical lines
    for (int i = 0; i < verticalCount; i++) {
      final x = i * spacing;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override 
  // ignore: library_private_types_in_public_api
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  int _currentPage = 0;
  bool _showBottomSheet = false;
  
  // Auth state variables
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isPhoneLoading = false;
  
  // Content for each onboarding screen with eye-catching colors
  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Instant Push-to-Talk',
      'subtitle': 'Modern walkie-talkie on your phone',
      'features': [
        'Voice transmission in milliseconds',
        'No calls to answer or decline',
        'Talk with a simple button press',
        'Create your profile in seconds'
      ],
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF0080), Color(0xFF7928CA)], // Hot pink to vibrant purple
      ),
      'iconColor': const Color(0xFFFF0080),
    },
    {
      'title': 'Connect Globally',
      'subtitle': 'Talk to anyone, anywhere, instantly',
      'features': [
        'Global coverage over internet',
        'Minimal data usage',
        'Works on slow connections',
        'Connect with friends instantly',
        'Start talking right away'
      ],
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0070F3), Color(0xFF00DFD8)], // Electric blue to aqua
      ),
      'iconColor': const Color(0xFF0070F3),
    },
    {
      'title': 'Join DuckBuck',
      'subtitle': 'Become part of the community',
      // No features needed for the last screen
      'features': [],
      'gradient': const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFF4D4D), Color(0xFFF9CB28)], // Bright red to yellow
      ),
      'iconColor': const Color(0xFFFF4D4D),
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // No need to preload images as we're using Lottie animations instead
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions and safe area information for responsive layout
    final Size screenSize = MediaQuery.of(context).size;
    final EdgeInsets safePadding = MediaQuery.of(context).padding;
    final bool isSmallScreen = screenSize.height < 600;
    final bool isLandscape = screenSize.width > screenSize.height;
    
    final authProvider = Provider.of<auth_provider.AuthProvider>(context, listen: true);
    
    // Reset loading states when auth is no longer loading
    if (authProvider.status != auth_provider.AuthStatus.loading && 
        (_isGoogleLoading || _isAppleLoading || _isPhoneLoading)) {
      setState(() {
        _isGoogleLoading = false;
        _isAppleLoading = false;
        _isPhoneLoading = false;
      });
      
      // Trigger haptic feedback on successful authentication
      if (authProvider.status == auth_provider.AuthStatus.authenticated) {
        HapticFeedback.mediumImpact();
      }
    }
    
    if (authProvider.isAuthenticated) {
      print('AuthScreen: User is authenticated, checking user existence');
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // First check if user exists in Firestore
        final exists = await authProvider.authService.userExists(authProvider.currentUser!.uid);
        print('AuthScreen: User exists in Firestore: $exists');
        
        if (!exists) {
          print('AuthScreen: New user, going to name screen');
          // If user doesn't exist, go to name screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const NameScreen(),
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
        } else {
          print('AuthScreen: Existing user, checking onboarding status');
          // For existing users, check onboarding status
          final currentStage = await authProvider.getOnboardingStage();
          print('AuthScreen: Current onboarding stage: $currentStage');
          
          Widget targetScreen;
          
          if (currentStage == auth_provider.OnboardingStage.notStarted || currentStage == auth_provider.OnboardingStage.completed) {
            // If onboarding is not started or completed, go to home screen
            print('AuthScreen: Onboarding not started or completed, going to home screen');
            targetScreen = const HomeScreen();
          } else {
            // Otherwise, navigate to the appropriate onboarding screen
            print('AuthScreen: Navigating to onboarding screen: $currentStage');
            switch (currentStage) {
              case auth_provider.OnboardingStage.name:
                targetScreen = const NameScreen();
                break;
              case auth_provider.OnboardingStage.dateOfBirth:
                targetScreen = const DOBScreen();
                break;
              case auth_provider.OnboardingStage.gender:
                targetScreen = const GenderScreen();
                break;
              case auth_provider.OnboardingStage.profilePhoto:
                targetScreen = const ProfilePhotoScreen();
                break;
              default:
                targetScreen = const HomeScreen();
            }
          }
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
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
        }
      });
    }

    // Show error if there is one
    if (authProvider.status == auth_provider.AuthStatus.error && authProvider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Display a user-friendly error message
        String friendlyMessage = 'An error occurred during authentication. Please try again.';
        
        // Check if the error message contains any service names to hide
        if (authProvider.errorMessage!.contains('firebase') || 
            authProvider.errorMessage!.contains('Firebase') ||
            authProvider.errorMessage!.contains('Google') ||
            authProvider.errorMessage!.contains('Apple')) {
          // Log the original error for debugging but don't show to user
          print('Auth error: ${authProvider.errorMessage}');
        } else {
          // If the message is already sanitized, use it
          friendlyMessage = authProvider.errorMessage!;
        }
        
        _showErrorSnackBar(friendlyMessage);
        // Clear the error
        authProvider.clearError();
      });
    }

    return Scaffold(
      // Remove any background color that might be causing white bar
      backgroundColor: Colors.transparent,
      // Hide system overlays to prevent white bars
      extendBodyBehindAppBar: true,
      extendBody: true,
      // Make appbar transparent and set system overlay style
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          // Fix for black screen on right side - ensure status bar is transparent
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      body: Container(
        // Ensure container fills entire screen width
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            // Enhanced Liquid Swipe with magnetic effect
            _buildMagneticSwiper(screenSize),
            
            // Page Indicator
            if (_currentPage < 2) // Only show dots on first two screens
              Positioned(
                bottom: isSmallScreen ? 20 : 30,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Animated page indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingData.length,
                        (i) {
                          // Determine if this dot is active
                          final isActive = i == _currentPage;
                          final LinearGradient currentGradient = _onboardingData[i]['gradient'] as LinearGradient;
                          final Color dotColor = currentGradient.colors.last;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            height: 10,
                            width: isActive ? 30 : 10,
                            decoration: BoxDecoration(
                              color: isActive ? dotColor : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: isActive ? [
                                BoxShadow(
                                  color: dotColor.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ] : null,
                            ),
                          ).animate(target: isActive ? 1.0 : 0.0)
                            .custom(
                              duration: 300.ms,
                              builder: (context, value, child) => Transform.scale(
                                scale: 0.8 + (0.2 * value),
                                child: child,
                              ),
                            );
                        },
                      ),
                    ),
                  ],
                ),
              ).animate()
                .fadeIn(duration: 600.ms, delay: 600.ms),
            
            // Auth UI Bottom Section - Only on last page
            if (_showBottomSheet)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildAuthUI(
                  safePadding, 
                  isSmallScreen, 
                  isLandscape, 
                  authProvider
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build the magnetic liquid swiper with enhanced gestures
  Widget _buildMagneticSwiper(Size screenSize) {
    final LiquidController liquidController = LiquidController();
    
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Get the drag distance and screen width
        final dragDistance = details.delta.dx;
        final screenWidth = screenSize.width;
        
        // Calculate how much we've moved as a percentage of screen width
        final dragPercentage = dragDistance / screenWidth;
        
        // Get current page
        final currentPage = liquidController.currentPage;
        
        // If dragging right and not on first page, or dragging left and not on last page
        if ((dragDistance > 0 && currentPage > 0) || 
            (dragDistance < 0 && currentPage < _onboardingData.length - 1)) {
          // Apply the magnetic effect through animation
          if (dragDistance < 0) {
            // Moving to next page
            liquidController.animateToPage(
              page: currentPage + 1,
              duration: 300,
            );
          } else {
            // Moving to previous page
            liquidController.animateToPage(
              page: currentPage - 1,
              duration: 300,
            );
          }
        }
      },
      onHorizontalDragEnd: (details) {
        // Get velocity and screen width
        final velocity = details.primaryVelocity ?? 0;
        final screenWidth = screenSize.width;
        
        // Get the current page
        final currentPage = liquidController.currentPage;
        
        // Determine the threshold for swipe - lower value means more sensitive
        final velocityThreshold = screenWidth * 0.05; // 5% of screen width per second
        
        // If velocity is significant enough, change page
        if (velocity.abs() > velocityThreshold) {
          // If swiping right and not on first page
          if (velocity > 0 && currentPage > 0) {
            liquidController.jumpToPage(page: currentPage - 1);
            HapticFeedback.lightImpact();
          } 
          // If swiping left and not on last page
          else if (velocity < 0 && currentPage < _onboardingData.length - 1) {
            liquidController.jumpToPage(page: currentPage + 1);
            HapticFeedback.lightImpact();
          }
        } else {
          // Animate back to current page with a spring effect
          liquidController.animateToPage(
            page: currentPage,
            duration: 300,
          );
        }
      },
      child: LiquidSwipe(
        pages: _buildPages(),
        enableLoop: false,
        fullTransitionValue: 500, // Lower value for smoother transitions
        enableSideReveal: true,
        slideIconWidget: null,
        positionSlideIcon: 0.8,
        waveType: WaveType.circularReveal,
        onPageChangeCallback: (index) {
          setState(() {
            _currentPage = index;
            _showBottomSheet = index >= 2;
          });
          // Add haptic feedback on page change
          HapticFeedback.lightImpact();
        },
        liquidController: liquidController,
        ignoreUserGestureWhileAnimating: false, // Let gestures work during animation
      ),
    );
  }

  List<Widget> _buildPages() {
    return _onboardingData.asMap().entries.map((entry) {
      final int index = entry.key;
      final Map<String, dynamic> data = entry.value;
      
      // Common gradient container for all screens
      return Container(
        decoration: BoxDecoration(
          gradient: data['gradient'] as LinearGradient,
        ),
        width: MediaQuery.of(context).size.width,
        // Use consistent layout for all pages
        child: SafeArea(
          bottom: false, // Don't add safe area at bottom to avoid spacing issues
          child: Stack(
            children: [
              // Decorative background elements - unique to each screen
              ..._buildBackgroundElements(index),

              // Main content column - with special handling for the last screen
              Column(
                children: [
                  // Top spacer - increased on last screen
                  SizedBox(height: MediaQuery.of(context).size.height * (index == 2 ? 0.1 : 0.08)),
                  
                  // App logo - same position on all screens
                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(25.0),
                        child: Image.asset(
                          'assets/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ).animate(autoPlay: true)
                    .fadeIn(delay: 300.ms, duration: 700.ms)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1.0, 1.0),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    ),
                  
                  // Different layout for the last screen
                  if (index == 2) ...[
                    // Title and subtitle stacked in center with more advanced animations
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            data['title'],
                            style: const TextStyle(
                              fontSize: 42, // Larger text for better impact
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ).animate(autoPlay: true)
                            .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.3, end: 0, duration: 800.ms, curve: Curves.easeOutQuart)
                            .then(delay: 200.ms)
                            .shimmer(
                              duration: 2200.ms,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          Text(
                            data['subtitle'],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0, 
                            ),
                            textAlign: TextAlign.center,
                          ).animate(autoPlay: true)
                            .fadeIn(delay: 400.ms, duration: 600.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.3, end: 0, delay: 300.ms, duration: 600.ms),
                        ],
                      ),
                    ),
                    
                    // More space at bottom for auth UI
                    SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  ] else ...[
                    // Standard layout for first two screens
                    const Spacer(),
                    
                    // Content area for title, subtitle, and features
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            data['title'],
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.start,
                          ).animate(autoPlay: true)
                            .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                            .slideX(begin: -0.3, end: 0, duration: 600.ms, curve: Curves.easeOutQuart)
                            .shimmer(
                              duration: 2200.ms,
                              delay: 1500.ms,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Subtitle
                          Text(
                            data['subtitle'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.start,
                          ).animate(autoPlay: true)
                            .fadeIn(delay: 200.ms, duration: 600.ms, curve: Curves.easeOut)
                            .slideX(begin: -0.3, end: 0, delay: 200.ms, duration: 600.ms, curve: Curves.easeOutQuart),
                          
                          const SizedBox(height: 40),
                          
                          // Features list with staggered animations and improved icons
                          ...data['features'].asMap().entries.map((feature) {
                            final int featureIndex = feature.key;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      featureIndex == 3 ? Icons.person_add_alt_1_rounded :
                                      featureIndex == 4 ? Icons.chat_rounded :
                                      featureIndex == 5 ? Icons.touch_app_rounded :
                                      _getFeatureIcon(featureIndex),
                                      color: (data['gradient'] as LinearGradient).colors.first,
                                      size: 22,
                                    ),
                                  ).animate(autoPlay: true)
                                    .fadeIn(
                                      delay: Duration(milliseconds: 400 + (featureIndex * 150)), 
                                      duration: 600.ms
                                    )
                                    .scale(
                                      begin: const Offset(0.0, 0.0),
                                      end: const Offset(1.0, 1.0), 
                                      delay: Duration(milliseconds: 400 + (featureIndex * 150)),
                                      duration: 600.ms, 
                                      curve: Curves.elasticOut
                                    ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      feature.value,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ).animate(autoPlay: true)
                                    .fadeIn(
                                      delay: Duration(milliseconds: 500 + (featureIndex * 150)), 
                                      duration: 600.ms
                                    )
                                    .slideX(
                                      begin: 0.2, 
                                      end: 0, 
                                      delay: Duration(milliseconds: 500 + (featureIndex * 150)), 
                                      duration: 600.ms, 
                                      curve: Curves.easeOutQuart
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    
                    // Bottom spacing
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Generate decorative background elements for each screen
  List<Widget> _buildBackgroundElements(int index) {
    final screenSize = MediaQuery.of(context).size;
    final random = math.Random(index); // Use screen index as seed for consistent randomness
    
    // Different decoration styles based on screen index
    switch (index) {
      case 0: // First screen - diagonal stripes and circles
        return [
          // Diagonal stripes
          Positioned(
            top: screenSize.height * 0.15,
            left: -30,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Container(
                width: 150,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, curve: Curves.easeOut),
          
          // Striped pattern
          Positioned(
            top: screenSize.height * 0.2,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                backgroundBlendMode: BlendMode.screen,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: List.generate(12, (i) => 
                    Container(
                      height: 10,
                      color: i % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.2),
                    )
                  ),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 200.ms, curve: Curves.easeOut)
            .slide(begin: const Offset(0.2, 0), end: Offset.zero, duration: 800.ms),
          
          // Small circle
          Positioned(
            bottom: screenSize.height * 0.35,
            right: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 400.ms),
          
          // Larger rounded rectangle
          Positioned(
            bottom: screenSize.height * 0.25,
            left: 30,
            child: Transform.rotate(
              angle: math.pi / 12,
              child: Container(
                width: 100,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 300.ms)
            .slideY(begin: 0.2, end: 0, duration: 800.ms),
        ];
        
      case 1: // Second screen - dots and waves
        return [
          // Dotted pattern container 
          Positioned(
            top: screenSize.height * 0.18,
            right: -20,
            child: Transform.rotate(
              angle: -math.pi / 8,
              child: Container(
                width: 150,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: CustomPaint(
                  painter: DotPatternPainter(
                    dotColor: Colors.white.withOpacity(0.3),
                    dotSize: 4,
                    spacing: 12,
                  ),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, curve: Curves.easeOut)
            .slideX(begin: 0.2, end: 0, duration: 800.ms),
          
          // Wave-like shape
          Positioned(
            top: screenSize.height * 0.23,
            left: 20,
            child: CustomPaint(
              size: Size(100, 150),
              painter: WavePainter(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 200.ms),
          
          // Small circles
          ...List.generate(5, (i) {
            return Positioned(
              top: screenSize.height * (0.3 + random.nextDouble() * 0.4),
              left: screenSize.width * random.nextDouble(),
              child: Container(
                width: 10 + random.nextInt(20).toDouble(),
                height: 10 + random.nextInt(20).toDouble(),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1 + random.nextDouble() * 0.2),
                ),
              ),
            ).animate(autoPlay: true)
              .fadeIn(duration: 800.ms, delay: (200 + i * 100).ms);
          }),
          
          // Diagonal bar
          Positioned(
            bottom: screenSize.height * 0.3,
            right: 20,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 120,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 300.ms)
            .slideY(begin: 0.3, end: 0, duration: 800.ms),
        ];
        
      case 2: // Third screen - geometric shapes
        return [
          // Large diagonal shape
          Positioned(
            top: screenSize.height * 0.12,
            left: -40,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Container(
                width: 200,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms)
            .slideX(begin: -0.2, end: 0, duration: 800.ms),
          
          // Pattern container on right
          Positioned(
            top: screenSize.height * 0.14,
            right: -30,
            child: Transform.rotate(
              angle: math.pi / 8,
              child: Container(
                width: 180,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: CustomPaint(
                  painter: GridPatternPainter(
                    lineColor: Colors.white.withOpacity(0.2),
                    spacing: 8,
                  ),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 200.ms)
            .slideX(begin: 0.2, end: 0, duration: 800.ms),
          
          // Small circle near bottom
          Positioned(
            bottom: screenSize.height * 0.35,
            left: 40,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 300.ms),
          
          // Diagonal small bar
          Positioned(
            bottom: screenSize.height * 0.3,
            right: 30,
            child: Transform.rotate(
              angle: math.pi / 6,
              child: Container(
                width: 80,
                height: 25,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.5),
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 800.ms, delay: 400.ms)
            .slideY(begin: 0.2, end: 0, duration: 800.ms),
        ];
        
      default:
        return [];
    }
  }

  IconData _getFeatureIcon(int index) {
    final List<IconData> icons = [
      Icons.flash_on_rounded,         // Speed/transmission
      Icons.chat_bubble_rounded,      // Modern messaging
      Icons.touch_app_rounded,        // Simple button press
      Icons.person_add_rounded,       // Create profile
      Icons.public_rounded,           // Global coverage
      Icons.data_usage_rounded,       // Minimal data
      Icons.signal_cellular_alt_rounded, // Slow connections
      Icons.group_rounded,            // Connect with friends
      Icons.play_circle_rounded,      // Start talking
    ];
    
    return icons[index % icons.length];
  }

  Widget _buildAuthUI(
    EdgeInsets safePadding,
    bool isSmallScreen,
    bool isLandscape,
    auth_provider.AuthProvider authProvider
  ) {
    // Enhanced bottom sheet with more vibrant design
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: safePadding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Auth Button - Modern style
          _buildModernAuthButton(
            "Continue with Google",
            _isGoogleLoading,
            () => _onGoogleSignIn(authProvider),
            Colors.black87,
            Colors.black87,
            "G",
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            animationDelay: 100.ms,
          ),
          
          const SizedBox(height: 16),
      
          // Apple Auth Button (iOS only)
          if (Platform.isIOS)
            _buildModernAuthButton(
              "Continue with Apple",
              _isAppleLoading,
              () => _onAppleSignIn(authProvider),
              Colors.white,
              Colors.black,
              "",
              icon: Icons.apple,
              gradient: LinearGradient(
                colors: [Colors.black, Color(0xFF222222)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              animationDelay: 200.ms,
            ),
          
          if (Platform.isIOS)
            const SizedBox(height: 16),
          
          // Phone Auth Button - Vibrant gradient - Only show on Android
          if (!Platform.isIOS)
            _buildModernAuthButton(
              "Continue with Phone",
              _isPhoneLoading,
              () => _onPhoneSignIn(context),
              Colors.white,
              Colors.white,
              "",
              icon: Icons.phone,
              gradient: LinearGradient(
                colors: [_onboardingData[2]['gradient'].colors.first, _onboardingData[2]['gradient'].colors.last],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              animationDelay: 200.ms,
            ),
          
          // Terms and conditions text
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 4),
            child: Text(
              "By continuing, you agree to our Terms of Service & Privacy Policy.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate()
            .fadeIn(delay: 500.ms, duration: 600.ms),
        ],
      ),
    ).animate()
      .fadeIn(duration: 500.ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuint);
  }

  // Modern auth button with gradient background and enhanced animations
  Widget _buildModernAuthButton(
    String text, 
    bool isLoading, 
    VoidCallback onPressed,
    Color textColor,
    Color iconColor,
    String letter, {
    IconData? icon,
    Gradient? gradient,
    Duration animationDelay = Duration.zero,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            alignment: Alignment.center,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradient != null ? Colors.white.withOpacity(0.2) : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : icon != null
                      ? Icon(icon, color: iconColor, size: 22)
                      : Text(
                          letter,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 50),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: animationDelay)
      .fadeIn(duration: 600.ms, curve: Curves.easeOut)
      .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutQuint)
      .then(delay: 400.ms)
      .shimmer(
        duration: 3000.ms, 
        delay: 1000.ms,
        color: Colors.white.withOpacity(0.1),
      );
  }
  
  // Authentication methods
  void _onGoogleSignIn(auth_provider.AuthProvider authProvider) async {
    setState(() => _isGoogleLoading = true);
    HapticFeedback.selectionClick(); // Add haptic feedback
    await authProvider.signInWithGoogle();
  }

  void _onAppleSignIn(auth_provider.AuthProvider authProvider) async {
    setState(() => _isAppleLoading = true);
    HapticFeedback.selectionClick(); // Add haptic feedback
    await authProvider.signInWithApple();
  }

  void _onPhoneSignIn(BuildContext context) {
    setState(() => _isPhoneLoading = true);
    HapticFeedback.selectionClick(); // Add haptic feedback
    
    // Reset loading state before showing dialog
    setState(() => _isPhoneLoading = false);
    
    // Show phone auth popup
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PhoneAuthPopup(
        onSubmit: (phoneNumber) async {
          // Handle by the popup internally
          print('Phone auth initiated with $phoneNumber');
          // Add haptic feedback when phone auth is successfully completed
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}