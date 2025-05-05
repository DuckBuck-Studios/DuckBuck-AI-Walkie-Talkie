import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:duckbuck/core/navigation/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:duckbuck/core/theme/app_colors.dart';
import 'package:duckbuck/core/theme/widget_styles.dart';
import 'package:duckbuck/core/widgets/safe_slide_action.dart'; // Import our custom widget

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _appVersion = '1.0.0';
  bool _isStartingApp = false;

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    _markWelcomeScreenAsSeen();
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Failed to get app version: $e');
    }
  }

  Future<void> _markWelcomeScreenAsSeen() async {
    try {
      await PreferencesService.instance.setWelcomeSeen(true);
    } catch (e) {
      debugPrint('Failed to save welcome screen state: $e');
    }
  }

  Future<void> _navigateToOnboarding() async {
    if (_isStartingApp) return;

    setState(() {
      _isStartingApp = true;
    });

    // Use the AppRoutes system for navigation
    Navigator.of(context).pushNamed(AppRoutes.onboarding);
  }

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

                    // Slide action button with updated colors
                    _buildSlideToAction(context, isIOS)
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
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.termsOfService);
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
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.privacyPolicy);
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

  Widget _buildSlideToAction(BuildContext context, bool isIOS) {
    // Use our custom SafeSlideAction widget instead of the original SlideAction
    return SafeSlideAction(
      height: 60,
      sliderButtonIconSize: 24,
      sliderRotate: false,
      borderRadius: 16,
      elevation: 0,
      innerColor: AppColors.accentBlue,
      outerColor: AppColors.surfaceBlack,
      sliderButtonIcon:
          isIOS
              ? const Icon(CupertinoIcons.arrow_right, color: Colors.white)
              : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
      text: 'Slide to get started',
      textStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      onSubmit: () {
        // Navigate to onboarding screens after a short delay
        Future.delayed(const Duration(milliseconds: 200), () {
          _navigateToOnboarding();
        });
      },
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
      'Version $_appVersion',
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
    );
  }
}
