import 'package:duckbuck/Authentication/screens/name_screen.dart';
import 'package:duckbuck/home/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:neopop/neopop.dart';
import 'dart:ui';
import 'package:duckbuck/Authentication/service/auth_service.dart';
import 'package:shimmer/shimmer.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  
  // Colors
  final Color textColor = const Color(0xFF8D6E63);
  final Color gheeAccentDark = const Color(0xFFD2B48C);
  
  // Fixed positions for background icons
  final List<_BackgroundIconData> _backgroundIcons = [];

  @override
  void initState() {
    super.initState();
    _initializeUI();
    _initializeAnimations();
    _generateFixedBackgroundIcons();
  }

  void _initializeUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFEEDCB5), // Warm ghee color
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }
  
  void _generateFixedBackgroundIcons() {
    // Use fixed positions instead of random positions
    final iconsList = [
      FontAwesomeIcons.microphone,
      FontAwesomeIcons.user,
      FontAwesomeIcons.userGroup,
      FontAwesomeIcons.message,
      FontAwesomeIcons.comments,
      FontAwesomeIcons.headset,
      FontAwesomeIcons.phone,
      FontAwesomeIcons.volumeHigh,
      FontAwesomeIcons.peopleGroup,
      FontAwesomeIcons.paperPlane,
      FontAwesomeIcons.wifi,
      FontAwesomeIcons.commentDots,
      FontAwesomeIcons.video,
      FontAwesomeIcons.bell,
      FontAwesomeIcons.shareNodes,
    ];
    
    // Create a grid-like pattern for icons
    for (int i = 0; i < 30; i++) {
      final row = i ~/ 6;
      final col = i % 6;
      
      _backgroundIcons.add(
        _BackgroundIconData(
          icon: iconsList[i % iconsList.length],
          position: Offset(
            40.0 + col * 60.0 + (row % 2) * 30.0, 
            60.0 + row * 100.0
          ),
          size: 18.0 + (i % 3) * 6.0,
          opacity: 0.05 + (i % 5) * 0.02,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  void _buttonPressHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }
  
  void _buttonLongPressHaptic() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  void _successHaptic() async {
    // Enhanced success haptic pattern
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 70));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  void _failureHaptic() async {
    // Enhanced failure haptic pattern
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    try {
      _buttonPressHaptic();
      setState(() => _isLoading = true);

      final result = await _authService.signInWithGoogle();
      final user = result['user'];
      final isNewUser = result['isNewUser'];

      if (!mounted) return;

      if (user != null) {
        _successHaptic();
        if (isNewUser) {
          // New user, go to NameScreen for profile setup
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const NameScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeOutQuint;
                
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                
                return SlideTransition(
                  position: offsetAnimation,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: (1 - animation.value) * 5,
                      sigmaY: (1 - animation.value) * 5,
                    ),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        } else {
          // Existing user, go directly to HomeScreen
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutQuint,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else {
        _failureHaptic();
        _showErrorSnackBar('Sign-in failed: Unable to authenticate');
      }
    } catch (e) {
      if (mounted) {
        _failureHaptic();
        _showErrorSnackBar('Sign-in failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;

    try {
      _buttonPressHaptic();
      setState(() => _isLoading = true);

      final result = await _authService.signInWithApple();
      final user = result['user'];
      final isNewUser = result['isNewUser'];

      if (!mounted) return;

      if (result != null) {
        _successHaptic();
        if (isNewUser) {
          // New user, go to NameScreen for profile setup
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const NameScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeOutQuint;
                
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                
                return SlideTransition(
                  position: offsetAnimation,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: (1 - animation.value) * 5,
                      sigmaY: (1 - animation.value) * 5,
                    ),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        } else {
          // Existing user, go directly to HomeScreen
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutQuint,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else {
        _failureHaptic();
        _showErrorSnackBar('Sign-in failed: Unable to authenticate');
      }
    } catch (e) {
      if (mounted) {
        _failureHaptic();
        _showErrorSnackBar('Sign-in failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 8,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Improved button builder with shimmer effect on the button but NOT on the text
  Widget _buildAuthButton({
    required String text,
    required String svgAsset,
    required VoidCallback onPressed,
    required Color mainColor,
    required Color borderColor,
    required Color shadowColor,
    required List<Color> gradientColors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: NeoPopButton(
        color: mainColor,
        bottomShadowColor: shadowColor.withOpacity(0.6),
        rightShadowColor: shadowColor.withOpacity(0.8),
        animationDuration: const Duration(milliseconds: 200),
        depth: 7,
        onTapUp: _isLoading ? null : onPressed,
        onTapDown: _isLoading ? null : () {
          _buttonPressHaptic();
        },
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        child: Stack(
          children: [
            // Shimmer effect background
            Positioned.fill(
              child: Shimmer.fromColors(
                baseColor: mainColor,
                highlightColor: gradientColors[1],
                period: const Duration(milliseconds: 2000),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                ),
              ),
            ),
            // Content layer (always visible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    svgAsset,
                    height: 24,
                    width: 24,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 2.0,
                          color: Color.fromRGBO(0, 0, 0, 0.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'DuckBuck, the app name',
          child: Shimmer.fromColors(
            baseColor: textColor,
            highlightColor: gheeAccentDark,
            period: const Duration(milliseconds: 2500),
            child: Text(
              "DuckBuck",
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: textColor, // Base color for shimmer
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Connect with friends instantly',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.brown.shade800,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.white.withOpacity(0.7),
                offset: const Offset(0, 0.5),
                blurRadius: 1.0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Use fixed background icons
  List<Widget> _buildBackgroundIcons() {
    return _backgroundIcons.map((iconData) {
      return Positioned(
        top: iconData.position.dy,
        left: iconData.position.dx,
        child: FaIcon(
          iconData.icon,
          size: iconData.size,
          color: Colors.brown.withOpacity(iconData.opacity),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            // Background color (warm ghee)
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEEDCB5), // Warm ghee color
              ),
            ),
            
            // Background floating icons
            ..._buildBackgroundIcons(),
            
            // Main content
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(child: _buildLogo()),
                  ),
                  
                  // Bottom sheet-like container with enhanced visibility
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.only(top: 30, bottom: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Removed the small bar icon as requested
                        Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 20, // Increased font size
                            fontWeight: FontWeight.w600,
                            color: Colors.brown.shade800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Use your social account to log in',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15, // Increased font size
                              color: Colors.brown.shade500, // Darker for better visibility
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28), // More spacing
                        _buildAuthButton(
                          text: 'Continue with Google',
                          svgAsset: 'assets/google.svg',
                          onPressed: _handleGoogleSignIn,
                          mainColor: const Color(0xFFFFA000), // Amber
                          borderColor: const Color(0xFFFF8F00), // Dark amber
                          shadowColor: const Color(0xFFE65100), // Deep orange
                          gradientColors: [
                            const Color(0xFFFFA000),
                            const Color(0xFFFFD54F),
                            Colors.amber.shade600,
                            const Color(0xFFFFCA28),
                            const Color(0xFFFFA000),
                          ],
                        ),
                        _buildAuthButton(
                          text: 'Continue with Apple',
                          svgAsset: 'assets/apple.svg',
                          onPressed: _handleAppleSignIn,
                          mainColor: const Color(0xFF5D4037), // Brown
                          borderColor: const Color(0xFF3E2723), // Dark brown
                          shadowColor: Colors.black,
                          gradientColors: [
                            const Color(0xFF5D4037),
                            const Color(0xFF8D6E63),
                            const Color(0xFF6D4C41),
                            const Color(0xFF795548),
                            const Color(0xFF5D4037),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Loading overlay with enhanced visual feedback
            if (_isLoading)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Shimmer.fromColors(
                          baseColor: const Color(0xFFFFB300),
                          highlightColor: const Color(0xFFFFD54F),
                          period: const Duration(milliseconds: 1500),
                          child: const CircularProgressIndicator(
                            color: Color(0xFFFFB300),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Class to store fixed positions for background icons
class _BackgroundIconData {
  final IconData icon;
  final Offset position;
  final double size;
  final double opacity;
  
  _BackgroundIconData({
    required this.icon,
    required this.position,
    required this.size,
    required this.opacity,
  });
}