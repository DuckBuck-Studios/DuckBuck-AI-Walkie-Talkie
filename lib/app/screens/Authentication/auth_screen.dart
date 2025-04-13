import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import '../../widgets/phone_auth_popup.dart';
import '../../providers/auth_provider.dart' as auth_provider;
import '../onboarding/name_screen.dart';
import '../onboarding/dob_screen.dart';
import '../onboarding/gender_screen.dart';
import '../onboarding/profile_photo_screen.dart';
import '../Home/home_screen.dart';
import 'onboarding_screens/first_screen.dart';
import 'onboarding_screens/second_screen.dart';
import '../../constants/onboarding_constants.dart';

// Extracted authentication logic to a separate class
class _AuthHandler {
  final BuildContext context;
  final auth_provider.AuthProvider authProvider;
  final Function(bool) onGoogleLoadingChange;
  final Function(bool) onAppleLoadingChange;
  final Function(bool) onPhoneLoadingChange;
  final Function(String) onError;

  _AuthHandler({
    required this.context,
    required this.authProvider,
    required this.onGoogleLoadingChange,
    required this.onAppleLoadingChange,
    required this.onPhoneLoadingChange,
    required this.onError,
  });

  Future<void> handleGoogleSignIn() async {
    try {
      onGoogleLoadingChange(true);
      HapticFeedback.selectionClick();
      await authProvider.signInWithGoogle();
    } catch (e) {
      // Handle cancellation or any other error
      if (e.toString().contains('sign_in_canceled') || 
          e.toString().contains('Sign in cancelled') ||
          e.toString().contains('sign_in_cancelled')) {
        // User cancelled the sign-in, just reset loading state
        onGoogleLoadingChange(false);
        return;
      }
      // For other errors, show error message
      onError(e.toString());
    } finally {
      // Always reset loading state
      onGoogleLoadingChange(false);
    }
  }

  Future<void> handleAppleSignIn() async {
    onAppleLoadingChange(true);
    HapticFeedback.selectionClick();
    await authProvider.signInWithApple();
    onAppleLoadingChange(false);
  }

  void handlePhoneSignIn() {
    onPhoneLoadingChange(true);
    HapticFeedback.selectionClick();
    onPhoneLoadingChange(false);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PhoneAuthPopup(
        onSubmit: (phoneNumber) { 
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void handleAuthError(String message) {
    String friendlyMessage = 'An error occurred during authentication. Please try again.';
    
    if (message.contains('firebase') || 
        message.contains('Firebase') ||
        message.contains('Google') ||
        message.contains('Apple')) { 
    } else {
      friendlyMessage = message;
    }
    
    onError(friendlyMessage);
  }
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
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isPhoneLoading = false;
  
  // Content for each onboarding screen with eye-catching colors
  static const List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Instant Push-to-Talk',
      'subtitle': 'Modern walkie-talkie on your phone',
      'features': [
        'Voice transmission in milliseconds',
        'No calls to answer or decline',
        'Talk with a simple button press',
        'Create your profile in seconds'
      ],
      'gradient': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF0080), Color(0xFF7928CA)],
      ),
      'iconColor': Color(0xFFFF0080),
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
      'gradient': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0070F3), Color(0xFF00DFD8)],
      ),
      'iconColor': Color(0xFF0070F3),
    },
    {
      'title': 'Join DuckBuck',
      'subtitle': 'Become part of the community',
      'features': [],
      'gradient': LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFF4D4D), Color(0xFFF9CB28)],
      ),
      'iconColor': Color(0xFFFF4D4D),
    },
  ];

  late final _AuthHandler _authHandler;

  @override
  void initState() {
    super.initState();
    _authHandler = _AuthHandler(
      context: context,
      authProvider: Provider.of<auth_provider.AuthProvider>(context, listen: false),
      onGoogleLoadingChange: (isLoading) => setState(() => _isGoogleLoading = isLoading),
      onAppleLoadingChange: (isLoading) => setState(() => _isAppleLoading = isLoading),
      onPhoneLoadingChange: (isLoading) => setState(() => _isPhoneLoading = isLoading),
      onError: _showErrorSnackBar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<auth_provider.AuthProvider>(context, listen: true);
    
    if (authProvider.isAuthenticated) {
      _handleAuthentication(authProvider);
    }

    if (authProvider.status == auth_provider.AuthStatus.error && authProvider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authHandler.handleAuthError(authProvider.errorMessage!);
        authProvider.clearError();
      });
    }

    return _buildScaffold(context);
  }

  void _handleAuthentication(auth_provider.AuthProvider authProvider) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final exists = await authProvider.authService.userExists(authProvider.currentUser!.uid);
      
      if (!exists) {
        _navigateToScreen(const NameScreen());
      } else {
        final currentStage = await authProvider.getOnboardingStage();
        final targetScreen = _getTargetScreen(currentStage);
        _navigateToScreen(targetScreen);
      }
    });
  }

  Widget _getTargetScreen(auth_provider.OnboardingStage stage) {
    switch (stage) {
      case auth_provider.OnboardingStage.notStarted:
      case auth_provider.OnboardingStage.completed:
        return const HomeScreen();
      case auth_provider.OnboardingStage.name:
        return const NameScreen();
      case auth_provider.OnboardingStage.dateOfBirth:
        return const DOBScreen();
      case auth_provider.OnboardingStage.gender:
        return const GenderScreen();
      case auth_provider.OnboardingStage.profilePhoto:
        return const ProfilePhotoScreen();
      }
  }

  void _navigateToScreen(Widget screen) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
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

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                RepaintBoundary(
                  child: _buildMagneticSwiper(constraints),
                ),
                if (_currentPage < 2)
                  _buildPageIndicator(constraints),
                if (_showBottomSheet)
                  _buildAuthUI(constraints),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMagneticSwiper(BoxConstraints constraints) {
    final liquidController = LiquidController();
    
    return GestureDetector(
      onHorizontalDragUpdate: (details) => _handleDragUpdate(details, liquidController, constraints),
      onHorizontalDragEnd: (details) => _handleDragEnd(details, liquidController, constraints),
      child: LiquidSwipe(
        pages: _buildPages(),
        enableLoop: false,
        fullTransitionValue: 500,
        enableSideReveal: true,
        slideIconWidget: null,
        positionSlideIcon: 0.8,
        waveType: WaveType.circularReveal,
        onPageChangeCallback: (index) {
          setState(() {
            _currentPage = index;
            _showBottomSheet = index >= 2;
          });
          HapticFeedback.lightImpact();
        },
        liquidController: liquidController,
        ignoreUserGestureWhileAnimating: false,
      ),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details, LiquidController controller, BoxConstraints constraints) {
    final dragDistance = details.delta.dx;
    final currentPage = controller.currentPage;
    
    if ((dragDistance > 0 && currentPage > 0) || 
        (dragDistance < 0 && currentPage < _onboardingData.length - 1)) {
      controller.animateToPage(
        page: currentPage + (dragDistance < 0 ? 1 : -1),
        duration: 300,
      );
    }
  }

  void _handleDragEnd(DragEndDetails details, LiquidController controller, BoxConstraints constraints) {
    final velocity = details.primaryVelocity ?? 0;
    final screenWidth = constraints.maxWidth;
    final velocityThreshold = screenWidth * 0.05;
    final currentPage = controller.currentPage;
    
    if (velocity.abs() > velocityThreshold) {
      if (velocity > 0 && currentPage > 0) {
        controller.jumpToPage(page: currentPage - 1);
        HapticFeedback.lightImpact();
      } else if (velocity < 0 && currentPage < _onboardingData.length - 1) {
        controller.jumpToPage(page: currentPage + 1);
        HapticFeedback.lightImpact();
      }
    } else {
      controller.animateToPage(
        page: currentPage,
        duration: 300,
      );
    }
  }

  Widget _buildPageIndicator(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxHeight < 600;
    
    return Positioned(
      bottom: isSmallScreen ? 20 : 30,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _onboardingData.length,
              (i) => _buildDotIndicator(i, isSmallScreen),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 600.ms);
  }

  Widget _buildDotIndicator(int index, bool isSmallScreen) {
    final isActive = index == _currentPage;
    final currentGradient = _onboardingData[index]['gradient'] as LinearGradient;
    final dotColor = currentGradient.colors.last;
    
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
  }

  List<Widget> _buildPages() {
    return _onboardingData.asMap().entries.map((entry) {
      final int index = entry.key;
      final Map<String, dynamic> data = entry.value;
      
      switch (index) {
        case 0:
          return FirstOnboardingScreen(
            data: data,
            screenSize: MediaQuery.of(context).size,
          );
        case 1:
          return SecondOnboardingScreen(
            data: data,
            screenSize: MediaQuery.of(context).size,
          );
        case 2:
          return _buildFinalScreen(data);
        default:
          return Container();
      }
    }).toList();
  }

  Widget _buildFinalScreen(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        gradient: data['gradient'] as LinearGradient,
      ),
      width: MediaQuery.of(context).size.width,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: OnboardingConstants.getLogoTopPadding(context)),
            
            _buildLogo(),
            
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTitle(data['title']),
                  const SizedBox(height: 24),
                  _buildSubtitle(data['subtitle']),
                ],
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).size.height * 0.35),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: OnboardingConstants.logoSize,
        height: OnboardingConstants.logoSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          boxShadow: _getOptimizedShadows(),
        ),
        child: Padding(
          padding: EdgeInsets.all(OnboardingConstants.logoPadding),
          child: Image.asset(
            'assets/app_logo.png',
            fit: BoxFit.contain,
            cacheWidth: (OnboardingConstants.logoSize * MediaQuery.of(context).devicePixelRatio).round(),
            cacheHeight: (OnboardingConstants.logoSize * MediaQuery.of(context).devicePixelRatio).round(),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: _getPlatformSpecificTitleStyle(),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle(String subtitle) {
    return Text(
      subtitle,
      style: _getPlatformSpecificSubtitleStyle(),
      textAlign: TextAlign.center,
    );
  }

  List<BoxShadow> _getOptimizedShadows() {
    if (Platform.isIOS) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(OnboardingConstants.logoShadowOpacity),
          blurRadius: OnboardingConstants.logoShadowBlur,
          spreadRadius: OnboardingConstants.logoShadowSpread,
          offset: Offset(0, OnboardingConstants.logoShadowOffset),
        )
      ];
    } else {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(OnboardingConstants.logoShadowOpacity),
          blurRadius: OnboardingConstants.logoShadowBlur,
          spreadRadius: OnboardingConstants.logoShadowSpread,
          offset: Offset(0, OnboardingConstants.logoShadowOffset),
        )
      ];
    }
  }

  TextStyle _getPlatformSpecificTitleStyle() {
    if (Platform.isIOS) {
      return CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
        color: Colors.white,
        letterSpacing: 0.5,
        height: 1.1,
      );
    }
    return const TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 0.5,
      height: 1.1,
    );
  }

  TextStyle _getPlatformSpecificSubtitleStyle() {
    if (Platform.isIOS) {
      return CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
        color: Colors.white.withOpacity(0.9),
        height: 1.4,
      );
    }
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(0.9),
      letterSpacing: 0,
    );
  }

  Widget _buildAuthUI(BoxConstraints constraints) {
    final safePadding = MediaQuery.of(context).padding;
    final _ = constraints.maxWidth > constraints.maxHeight;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
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
            _buildAuthButtons(),
            _buildTermsText(),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 500.ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuint);
  }

  Widget _buildAuthButtons() {
    return Column(
      children: [
        _buildModernAuthButton(
          "Continue with Google",
          _isGoogleLoading,
          _authHandler.handleGoogleSignIn,
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
        
        if (Platform.isIOS) ...[
          const SizedBox(height: 16),
          _buildModernAuthButton(
            "Continue with Apple",
            _isAppleLoading,
            _authHandler.handleAppleSignIn,
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
        ],
        
        if (!Platform.isIOS) ...[
          const SizedBox(height: 16),
          _buildModernAuthButton(
            "Continue with Phone",
            _isPhoneLoading,
            () => _authHandler.handlePhoneSignIn(),
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
        ],
      ],
    );
  }

  Widget _buildTermsText() {
    return Padding(
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
      .fadeIn(delay: 500.ms, duration: 600.ms);
  }

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