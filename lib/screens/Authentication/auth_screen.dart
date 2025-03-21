import 'dart:io'; 
import 'package:duckbuck/screens/onboarding/name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../widgets/phone_auth_popup.dart';
import '../../providers/auth_provider.dart' as auth_provider;
import '../Home/home_screen.dart';
import '../onboarding/dob_screen.dart';
import '../onboarding/gender_screen.dart';
import '../onboarding/profile_photo_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override 
  // ignore: library_private_types_in_public_api
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();
  double _currentPage = 0;
  bool _showBottomSheet = false;
  
  // Auth state variables
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isPhoneLoading = false;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Connect Instantly',
      'subtitle': 'Talk with friends and family in real-time with just one tap',
      'features': ['No phone numbers needed', 'Instant voice connection', 'Crystal clear audio'],
      'color': Color(0xFFD4A76A),
    },
    {
      'title': 'Global Reach',
      'subtitle': 'Stay connected with your friends no matter where they are',
      'features': ['Connect worldwide', 'Private voice channels', 'Group conversations'],
      'color': Color(0xFF6AD4A7),
    },
    {
      'title': 'Ready to Talk?',
      'subtitle': 'Join millions of people already connecting on DuckBuck',
      'features': ['End-to-end encryption', 'Zero lag communication', 'Free forever'],
      'color': Color(0xFF6A7AD4),
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
  }

  @override
  Widget build(BuildContext context) {
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
          _showErrorSnackBar(authProvider.errorMessage!);
          // Clear the error
          authProvider.clearError();
        });
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _onboardingData[_currentPage.floor()]['color'],
                  _onboardingData[_currentPage.floor()]['color'].withOpacity(0.7),
                ],
              ),
            ),
          ),
          
          // Main Content
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page.toDouble();
                      _showBottomSheet = page >= 2;
                    });
                  },
                  itemCount: _onboardingData.length,
                  itemBuilder: (context, index) {
                    return _buildFeatureScreen(
                      _onboardingData[index],
                      index,
                    );
                  },
                ),
              ),
              
              // Dots Indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: DotsIndicator(
                  dotsCount: _onboardingData.length,
                  position: _currentPage,
                  decorator: DotsDecorator(
                    activeColor: Colors.white,
                    size: const Size(8.0, 8.0),
                    activeSize: const Size(24.0, 8.0),
                    activeShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Get Started Button
          if (_showBottomSheet)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
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
                  children: [
                    ElevatedButton(
                      onPressed: () => _handleGoogleSignIn(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset('assets/animations/google.json', height: 24),
                          const SizedBox(width: 12),
                          Text(_isGoogleLoading ? 'Please wait...' : 'Continue with Google'),
                        ],
                      ),
                    ).animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.5, end: 0),
                      
                    if (Platform.isIOS)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton(
                          onPressed: () => _handleAppleSignIn(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.apple, size: 24),
                              const SizedBox(width: 12),
                              Text(_isAppleLoading ? 'Please wait...' : 'Continue with Apple'),
                            ],
                          ),
                        ).animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.5, end: 0),
                      ),
                      
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ElevatedButton(
                        onPressed: () => _showPhoneAuthBottomSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone_android, size: 24),
                            const SizedBox(width: 12),
                            Text(_isPhoneLoading ? 'Please wait...' : 'Continue with Phone'),
                          ],
                        ),
                      ).animate()
                        .fadeIn(delay: 500.ms)
                        .slideY(begin: 0.5, end: 0),
                    ),
                  ],
                ),
              ).animate()
                .fadeIn()
                .slideY(begin: 1, end: 0, curve: Curves.easeOutQuart),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureScreen(Map<String, dynamic> data, int index) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Text(
            data['title'],
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ).animate()
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.3, end: 0),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              data['subtitle'],
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ).animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          ),

          // Features List
          ...List.generate(
            data['features'].length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    data['features'][i],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ).animate()
                .fadeIn(delay: Duration(milliseconds: 600 + (i * 200)))
                .slideX(begin: 0.3, end: 0),
            ),
          ),
        ],
      ),
    );
  }

  void _handleGoogleSignIn(BuildContext context) async {
    if (_isGoogleLoading) return;
    
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      HapticFeedback.mediumImpact();
      // Use auth provider instead of the service directly
      await Provider.of<auth_provider.AuthProvider>(context, listen: false).signInWithGoogle();
    } catch (e) {
      // Error handling is now managed by the provider
      // But we still set the local loading state back to false
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _handleAppleSignIn(BuildContext context) async {
    if (_isAppleLoading) return;
    
    setState(() {
      _isAppleLoading = true;
    });

    try {
      HapticFeedback.mediumImpact();
      // Use auth provider instead of the service directly
      await Provider.of<auth_provider.AuthProvider>(context, listen: false).signInWithApple();
    } catch (e) {
      // Error handling is now managed by the provider
      // But we still set the local loading state back to false
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  void _showPhoneAuthBottomSheet(BuildContext context) {
    if (_isPhoneLoading) return;
    
    setState(() {
      _isPhoneLoading = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: !_isPhoneLoading,
      builder: (dialogContext) => PhoneAuthPopup(
        onSubmit: (countryCode, phoneNumber) async {
          // Authentication is handled inside the popup
          // Popup is now responsible for communicating with the provider
          if (mounted) {
            setState(() {
              _isPhoneLoading = false;
            });
          }
        },
      ),
    ).then((_) {
      // Dialog closed, reset loading state if needed
      if (mounted && _isPhoneLoading) {
        setState(() {
          _isPhoneLoading = false;
        });
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}