import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:duckbuck/core/services/database/local_database_service.dart';
import 'package:duckbuck/core/navigation/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:duckbuck/core/theme/app_colors.dart';
import 'package:duckbuck/core/theme/widget_styles.dart';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';
import 'package:duckbuck/core/services/logger/logger_service.dart';
import 'package:duckbuck/features/auth/screens/onboarding_signup_screen.dart';
import 'package:duckbuck/core/services/permissions/permissions_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _appVersion = '';
  
  // Services
  final _analytics = serviceLocator<FirebaseAnalyticsService>();
  final _logger = serviceLocator<LoggerService>();
  final _permissionsService = serviceLocator<PermissionsService>();
  final String _tag = 'WelcomeScreen';

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    _markWelcomeScreenAsSeen();
    _logScreenView();
  }
  
  void _logScreenView() {
    _analytics.logScreenView(
      screenName: 'welcome_screen',
      screenClass: 'WelcomeScreen',
    );
    _logger.i(_tag, 'Welcome screen viewed');
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      debugPrint('Failed to get app version: $e');
      // Set a fallback version in case of error
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
        });
      }
    }
  }

  Future<void> _markWelcomeScreenAsSeen() async {
    try {
      await LocalDatabaseService.instance.setBoolSetting('welcome_seen', true);
    } catch (e) {
      debugPrint('Failed to save welcome screen state: $e');
    }
  }

  // Removed _navigateToOnboarding method as it's now handled directly in the slide action

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundBlack,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(screenSize)
                        .animate()
                        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                        .scale(begin: const Offset(0.8, 0.8), delay: 300.ms),
                    SizedBox(height: screenSize.height * 0.05),
                    _buildAppTitle(),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  bottom: bottomPadding > 0 ? bottomPadding + 16.0 : 24.0,
                ),
                child: Column(
                  children: [
                    // Terms & Privacy Policy links
                    _buildLegalLinks().animate().fadeIn(
                      delay: 300.ms,
                      duration: 600.ms,
                    ),
                    const SizedBox(height: 16),

                    // Continue button with platform-specific styling
                    _buildContinueButton(context, isIOS)
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms)
                        .slideY(begin: 0.2, end: 0.0),
                    const SizedBox(height: 16),

                    _buildStudioCredit().animate().fadeIn(
                      delay: 800.ms,
                      duration: 600.ms,
                    ),
                    const SizedBox(height: 4),
                    _buildVersionText().animate().fadeIn(
                      delay: 800.ms,
                      duration: 600.ms,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Size screenSize) {
    final logoSize = WidgetStyles.logoSize(screenSize);

    return Hero(
      tag: 'app_logo',
      child: Container(
        height: logoSize.height,
        width: logoSize.width,
        decoration: WidgetStyles.logoContainerDecoration,
        child: ClipOval(
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading logo: $error');
              return Icon(
                Icons.currency_exchange_rounded,
                size: logoSize.width * 0.5,
                color: AppColors.textPrimary,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return const Text(
      'DuckBuck',
      style: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () async {
            try {
              if (!mounted) return;
              await Navigator.of(context).pushNamed(AppRoutes.termsOfService);
            } catch (e) {
              debugPrint('Navigation error: $e');
            }
          },
          child: const Text(
            'Terms of Service',
            style: TextStyle(
              color: AppColors.accentBlue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(
          '•',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: () async {
            try {
              if (!mounted) return;
              await Navigator.of(context).pushNamed(AppRoutes.privacyPolicy);
            } catch (e) {
              debugPrint('Navigation error: $e');
            }
          },
          child: const Text(
            'Privacy Policy',
            style: TextStyle(
              color: AppColors.accentBlue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(BuildContext context, bool isIOS) {
    // Wrap in RepaintBoundary for better rendering performance
    return RepaintBoundary(
      child: Hero(
        // Use a Hero widget to create a smooth visual connection with the next screen
        tag: 'continue_button',
        child: Material(
          // Material is needed for proper Hero animation
          color: Colors.transparent,
          child: isIOS
              ? CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.accentBlue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_right,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _handleContinue(context),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _handleContinue(context),
                ),
        ),
      ),
    );
  }

  void _handleContinue(BuildContext context) {
    // Provide haptic feedback for better physical feedback
    HapticFeedback.mediumImpact();
    
    // Log analytics event
    _analytics.logEvent(
      name: 'start_onboarding',
      parameters: {
        'source': 'welcome_screen',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _logger.i(_tag, 'User started onboarding flow');
    
    // Request permissions before navigating
    _requestPermissionsAndNavigate(context);
  }

  /// Request optional permissions and navigate to onboarding
  Future<void> _requestPermissionsAndNavigate(BuildContext context) async {
    try {
      _logger.i(_tag, 'Requesting optional permissions');
      
      // Request both permissions (optional - user can deny)
      final result = await _permissionsService.requestAllPermissions();
      
      // Log permission results
      _analytics.logEvent(
        name: 'permissions_requested',
        parameters: {
          'microphone_granted': result.microphoneGranted,
          'notification_granted': result.notificationGranted,
          'source': 'welcome_screen',
        },
      );
      
      _logger.i(_tag, 'Permission results: $result');
      
      // Navigate to onboarding regardless of permission results
      if (mounted) {
        _navigateToOnboarding();
      }
    } catch (e) {
      _logger.e(_tag, 'Error requesting permissions: $e');
      
      // Navigate anyway even if permission request fails
      if (mounted) {
        _navigateToOnboarding();
      }
    }
  }

  /// Navigate to onboarding screen with premium transition
  void _navigateToOnboarding() {
    // Create an ultra-smooth, premium page transition
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          OnboardingSignupScreen(
            onComplete: () => Navigator.of(context).pushReplacementNamed(AppRoutes.home),
          ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Ultra-smooth transition with perfect easing
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.08), // Start slightly below
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          
          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ));
          
          final scaleAnimation = Tween<double>(
            begin: 0.96,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          
          return SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 900),
        reverseTransitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Widget _buildStudioCredit() {
    return const Text(
      'Designed by DuckBuck Studios',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
    );
  }

  Widget _buildVersionText() {
    return Text(
      _appVersion.isEmpty ? 'Loading version...' : 'Version $_appVersion',
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
    );
  }
}
