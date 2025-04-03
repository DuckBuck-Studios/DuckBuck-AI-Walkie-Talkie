import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../widgets/phone_auth_popup.dart';
import '../../providers/auth_provider.dart' as auth_provider;
import '../../screens/onboarding/name_screen.dart';
import '../../screens/onboarding/dob_screen.dart';
import '../../screens/onboarding/gender_screen.dart';
import '../../screens/onboarding/profile_photo_screen.dart';
import '../../screens/Home/home_screen.dart';
import '../../widgets/animated_background.dart';
import 'dart:math' as math;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override 
  // ignore: library_private_types_in_public_api
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  double _currentPage = 0;
  bool _showBottomSheet = false;
  
  // Auth state variables
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isPhoneLoading = false;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Instant Voice Chat',
      'subtitle': 'Connect with friends instantly',
      'features': [
        'No call setup required',
        'Push-to-talk simplicity',
        'Crystal clear audio'
      ],
      'color': const Color(0xFF3C1F1F),
      'animation': 'assets/animations/walkie-talkie1.json',
    },
    {
      'title': 'Global Reach',
      'subtitle': 'Talk to friends anywhere',
      'features': [
        'Works across countries',
        'Low data usage',
        'End-to-end encryption'
      ],
      'color': const Color(0xFF2C1810),
      'animation': 'assets/animations/walkie-talkie2.json',
    },
    {
      'title': '', // Empty title for the last screen
      'subtitle': '', // Empty subtitle for the last screen
      'features': [
        '', // Empty features to keep structure but not display text
        '',
        ''
      ],
      'color': const Color(0xFF3C1F1F),
      'animation': 'assets/animations/loading.json',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!;
        // Show bottom sheet only when on last page
        if (_currentPage >= 2) {
          _showBottomSheet = true;
        } else {
          _showBottomSheet = false;
        }
      });
    });
    
    // Remove preloading from initState
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

    // Update loading states based on the auth provider
    if (authProvider.status == auth_provider.AuthStatus.authenticated) {
      // Keep existing loading state to know which button is loading
    } else {
      // Reset loading states when auth is no longer loading
      if (_isGoogleLoading || _isAppleLoading || _isPhoneLoading) {
        setState(() {
          _isGoogleLoading = false;
          _isAppleLoading = false;
          _isPhoneLoading = false;
        });
      }
      
      // Show error if there is one
      if (authProvider.status == auth_provider.AuthStatus.error && authProvider.errorMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Display a user-friendly error message
          String friendlyMessage = 'An error occurred during authentication. Please try again.';
          
          // Check if the error message contains any service names to hide
          // This is a backup in case the auth provider didn't already sanitize the message
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
    }

    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive sizes
            final double titleFontSize = constraints.maxWidth * 0.085;
            final double subtitleFontSize = constraints.maxWidth * 0.045;
            final double featureFontSize = constraints.maxWidth * 0.035;
            final double bottomSheetHeight = isLandscape 
                ? constraints.maxHeight * 0.65
                : (isSmallScreen ? constraints.maxHeight * 0.48 : constraints.maxHeight * 0.42);
            
            return Stack(
            children: [
                // Onboarding Content PageView
                PageView.builder(
                  controller: _pageController,
                  itemCount: _onboardingData.length,
                  onPageChanged: (index) {
                    setState(() {
                      // Show bottom sheet only when on last page
                      _showBottomSheet = index >= 2;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        20, 
                        safePadding.top + 20, 
                        20, 
                        _showBottomSheet ? bottomSheetHeight + 20 : 20
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Large Animation at top (walkie-talkie) - BIGGER SIZE
                          Expanded(
                            flex: 6, // Increased from 5 to 6
                            child: Center(
                              child: index == 2 
                                ? _buildDBLogo() // For the last page, show DB logo
                                : Lottie.asset(
                                    _onboardingData[index]['animation']!,
                                    width: constraints.maxWidth * 1.0, 
                                    height: constraints.maxHeight * 0.5, 
                                    fit: BoxFit.contain,
                                  ),
                            ),
                          ),
                          
                          // Flexible spacer to prevent overflow
                          const Spacer(flex: 1),
                                                  
                          // Title with improved styling and enhanced animations
                          index == 2 ? Container() : Text(
                            _onboardingData[index]['title'],
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
                              letterSpacing: 0.5,
                            ),
                          ).animate(
                            autoPlay: true,
                            onComplete: (controller) => controller.repeat(), // Subtle repeat effect
                          )
                            .fadeIn(duration: 600.ms, delay: 200.ms, curve: Curves.easeOut)
                            .slideX(begin: -0.2, end: 0, duration: 600.ms, delay: 200.ms, curve: Curves.easeOutQuart)
                            .then(delay: 3000.ms) // Add subtle shine effect
                            .shimmer(
                              duration: 2000.ms,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            
                          const SizedBox(height: 12),
                          
                          // Subtitle with improved styling and animations
                          index == 2 ? Container() : Text(
                            _onboardingData[index]['subtitle'],
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              shadows: [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              ],
                            ),
                          ).animate()
                            .fadeIn(duration: 600.ms, delay: 400.ms, curve: Curves.easeOut)
                            .slideX(begin: -0.2, end: 0, duration: 600.ms, delay: 400.ms, curve: Curves.easeOutQuart),
                            
                          const SizedBox(height: 24),
                          
                          // Features with improved styling and staggered animations
                          if (index != 2)
                            ...(_onboardingData[index]['features'] as List<String>).asMap().entries.map((entry) {
                              final int featureIndex = entry.key;
                              final String feature = entry.value;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32, // Increased from 24 to 32
                                      height: 32, // Increased from 24 to 32
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFD4A76A),
                                        boxShadow: [
                                          BoxShadow(
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                            color: Colors.black.withOpacity(0.3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18, // Adjusted from 16 to 18
                                      ),
                                    ).animate()
                                      .fadeIn(duration: 300.ms, delay: 600.ms + (featureIndex * 200).ms)
                                      .scale(
                                        begin: const Offset(0.0, 0.0),
                                        end: const Offset(1.0, 1.0), 
                                        duration: 400.ms, 
                                        delay: 600.ms + (featureIndex * 200).ms,
                                        curve: Curves.elasticOut
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        feature,
                                        style: TextStyle(
                                          fontSize: featureFontSize * 1.1, // Increased size slightly
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                          shadows: [
                                            Shadow(
                                              offset: const Offset(1, 1),
                                              blurRadius: 2,
                                              color: Colors.black.withOpacity(0.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).animate()
                                      .fadeIn(duration: 600.ms, delay: 700.ms + (featureIndex * 200).ms)
                                      .slideX(begin: 0.2, end: 0, duration: 600.ms, delay: 700.ms + (featureIndex * 200).ms, curve: Curves.easeOutQuart),
                                  ],
                                ),
                              );
                            }).toList(),
                          
                          const Spacer(),
                        ],
                      ),
                    );
                  },
                ),
                
                // Dots Indicator with enhanced styling
                if (!_showBottomSheet || isLandscape)
                  Positioned(
                    bottom: _showBottomSheet 
                        ? (isLandscape ? 12.0 : 24.0) 
                        : (isSmallScreen ? 32.0 : 48.0),
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Animated page indicator
                        AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            // Current page for smoother animation
                            final page = _pageController.hasClients 
                                ? _pageController.page ?? 0 
                                : _currentPage;
                                
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _onboardingData.length,
                                (i) {
                                  // Determine if this dot is active
                                  final isActive = i == page.round();
                                  // Calculate color and size based on distance from current page
                                  final distance = (page - i).abs();
                                  final distanceFactor = 1.0 - (distance > 1.0 ? 1.0 : distance);
                                  
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    height: 8,
                                    width: isActive ? 24 : 8,
                                    decoration: BoxDecoration(
                                      color: isActive 
                                          ? Colors.white 
                                          : Colors.white.withOpacity(0.5 - (distance * 0.2).clamp(0.0, 0.5)),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: isActive ? [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ] : null,
                                    ),
                                  ).animate(target: distanceFactor).custom(
                                    duration: 300.ms,
                                    builder: (context, value, child) => Transform.scale(
                                      scale: 0.8 + (0.2 * value),
                                      child: child,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        
                        // Screen title indicator
                        SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _onboardingData[_currentPage.round()]['title'],
                            key: ValueKey<int>(_currentPage.round()),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
                  ).animate()
                    .fadeIn(duration: 600.ms, delay: 800.ms),
          
          // Get Started Button
          if (_showBottomSheet)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                      height: bottomSheetHeight,
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: isSmallScreen ? 16 : 24,
                        bottom: safePadding.bottom + (isSmallScreen ? 16 : 24),
                      ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isLandscape) // Don't show in landscape to save space
                            Text(
                              "Join DuckBuck",
                              style: TextStyle(
                                fontSize: titleFontSize * 0.8,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade800,
                              ),
                              textAlign: TextAlign.center,
                    ).animate()
                              .fadeIn(duration: 400.ms)
                              .scale(
                                begin: const Offset(0.9, 0.9),
                                end: const Offset(1.0, 1.0),
                                duration: 600.ms,
                                curve: Curves.easeOutBack,
                              ),
                          
                          SizedBox(height: isSmallScreen ? 8 : 16),
                          
                          // Auth Buttons with staggered animations
                          _buildAuthButton(
                            "Continue with Google",
                            null,
                            _isGoogleLoading,
                            () => _onGoogleSignIn(authProvider),
                            isSmallScreen,
                            lottieAsset: 'assets/animations/google.json',
                            animationDelay: 200,
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 16),
                      
                    if (Platform.isIOS)
                            _buildAuthButton(
                              "Continue with Apple",
                              null,
                              _isAppleLoading,
                              () => _onAppleSignIn(authProvider),
                              isSmallScreen,
                              lottieAsset: 'assets/animations/apple.json',
                              animationDelay: 300,
                            ),
                          if (Platform.isIOS)
                            SizedBox(height: isSmallScreen ? 8 : 16),
                          
                          // Only show phone option for Android
                          if (!Platform.isIOS)
                            _buildAuthButton(
                              "Continue with Phone",
                              null,
                              _isPhoneLoading,
                              () => _onPhoneSignIn(context),
                              isSmallScreen,
                              lottieAsset: 'assets/animations/phone.json',
                              animationDelay: Platform.isIOS ? 400 : 300,
                            ),
                          
                          // More space for showing disclaimer
                          SizedBox(height: isSmallScreen ? 12 : 20),
                          
                          // Terms and conditions text with fade in animation
                          if (!isSmallScreen || !isLandscape) // Don't show in small landscape screens
                            Text(
                              "By continuing, you agree to our Terms of Service & Privacy Policy.",
                              style: TextStyle(
                                fontSize: subtitleFontSize * 0.75,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                        ).animate()
                              .fadeIn(duration: 600.ms, delay: 700.ms),
                        ],
                      ),
                    ),
                  ).animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildAuthButton(
    String text, 
    String? iconPath, 
    bool isLoading, 
    VoidCallback onPressed,
    bool isSmallScreen,
    {String? lottieAsset, int? animationDelay}
  ) {
    Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown.shade800,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 12 : 16,
          horizontal: 20,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.brown.shade800),
              ),
            )
          else if (lottieAsset != null)
            SizedBox(
              width: 28,
              height: 28,
              child: Lottie.asset(
                lottieAsset,
                fit: BoxFit.contain,
              ),
            )
          else if (iconPath != null)
            Image.asset(
              iconPath,
              width: 28,
              height: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
    
    if (animationDelay != null) {
      return button.animate()
        .fadeIn(duration: 600.ms, delay: animationDelay.ms)
        .slideY(begin: 0.3, end: 0, duration: 800.ms, delay: animationDelay.ms, curve: Curves.easeOutQuart)
        .then(delay: 200.ms)
        .custom(
          duration: 1500.ms,
          builder: (context, value, child) => Transform.scale(
            scale: 1.0 + 0.01 * math.sin(value * math.pi),
            child: child,
          ),
        );
    }
    
    return button;
  }

  // Auth methods
  
  void _onGoogleSignIn(auth_provider.AuthProvider authProvider) async {
    setState(() => _isGoogleLoading = true);
    HapticFeedback.selectionClick();
    await authProvider.signInWithGoogle();
  }

  void _onAppleSignIn(auth_provider.AuthProvider authProvider) async {
    setState(() => _isAppleLoading = true);
    HapticFeedback.selectionClick();
    await authProvider.signInWithApple();
  }

  void _onPhoneSignIn(BuildContext context) async {
    setState(() => _isPhoneLoading = true);
    HapticFeedback.selectionClick();
    
    // Reset loading state
    setState(() => _isPhoneLoading = false);
    
    // Show phone auth popup
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PhoneAuthPopup(
        onSubmit: (countryCode, phoneNumber) async {
          // Handle by the popup internally
          print('Phone auth initiated with $countryCode $phoneNumber');
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

Widget _buildDBLogo() {
  return SizedBox(
    width: 280,
    height: 280,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Generate shadow layers for 3D effect
        ...List.generate(5, (index) {
          final double offset = (index + 1) * 2.0;
          final double opacity = 0.8 - (index * 0.15);
          
          return Positioned(
            left: offset,
            top: offset,
            child: Text(
              "db", // Changed to lowercase "db"
              style: TextStyle(
                fontSize: 180, // Increased size
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.black.withOpacity(opacity.clamp(0.0, 1.0)),
                letterSpacing: -2,
              ),
            ),
          );
        }).reversed,
        
        // Main DB text with shimmer effect
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              const Color(0xFFD4A76A),
              Colors.white,
              const Color(0xFFD4A76A),
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            transform: GradientRotation(math.pi / 4),
          ).createShader(bounds),
          child: Text(
            "db", // Changed to lowercase "db"
            style: TextStyle(
              fontSize: 180, // Increased size
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
        ),
      ],
    ).animate()
      .fadeIn(duration: 1000.ms)
      .scale(
        begin: const Offset(0.5, 0.5),
        end: const Offset(1.0, 1.0),
        duration: 1000.ms,
        curve: Curves.elasticOut,
      )
      .custom(
        duration: 3000.ms,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(0, 4 * math.sin(value * math.pi * 2)),
          child: child,
        ),
      )
      .shimmer(
        duration: 2000.ms,
        color: Colors.white.withOpacity(0.8),
        angle: math.pi / 4,
        size: 8,
      ),
  );
}