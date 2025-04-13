import 'dart:io';
import 'package:duckbuck/app/screens/Authentication/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:action_slider/action_slider.dart';
import 'package:duckbuck/app/widgets/terms_agreement_widget.dart';
import 'package:duckbuck/app/widgets/animated_background.dart';

// Constants for the application
class AppColors {
  static const Color primary = Color(0xFFD4A76A);
  static const Color primaryDark = Color(0xFFB38B4D);
  static const Color background = Color(0xFFF5E8C7);
  static const Color textDark = Color(0xFF8B4513);
  static const Color textLight = Colors.white;
}

class AppStyles {
  static const TextStyle dialogTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
  
  static const TextStyle dialogBody = TextStyle(
    fontSize: 14,
    color: AppColors.textDark,
  );
}

class WelcomeScreen extends StatefulWidget {
  final bool accountDeleted;
  final bool loggedOut;
  
  const WelcomeScreen({
    super.key, 
    this.accountDeleted = false,
    this.loggedOut = false,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final Future<LottieComposition> _micAnimationFuture;
  final ActionSliderController _actionSliderController = ActionSliderController();
  
  @override
  void initState() {
    super.initState();
    
    // Pre-load the animation
    _micAnimationFuture = AssetLottie('assets/animations/mic.json').load();
    
    // Show appropriate dialog after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.accountDeleted) {
        _showStatusDialog(
          title: 'Account Deleted Successfully',
          message: 'Your account and all related data have been successfully deleted.',
          animationPath: 'assets/animations/delete.json',
          useAnimation: true
        );
      } else if (widget.loggedOut) {
        _showStatusDialog(
          title: 'Logged Out Successfully',
          message: 'You have been successfully logged out of your account.',
          icon: Icons.logout_rounded,
        );
      }
    });
  }

  @override
  void dispose() {
    _actionSliderController.dispose();
    super.dispose();
  }

  void _showStatusDialog({
    required String title,
    required String message,
    String? animationPath,
    IconData? icon,
    bool useAnimation = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => StatusDialog(
        title: title,
        message: message,
        animationPath: animationPath,
        icon: icon,
        useAnimation: useAnimation,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    final safePadding = MediaQuery.of(context).padding;
    
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate responsive sizes
              final double titleFontSize = constraints.maxWidth * 0.09;
              final double subtitleFontSize = constraints.maxWidth * 0.045;
              final double lottieSize = constraints.maxWidth * 0.5;
              
              return Column(
                children: [
                  // App title section
                  Padding(
                    padding: EdgeInsets.only(
                      top: isSmallScreen ? 20.0 : 40.0,
                      left: 16.0,
                      right: 16.0,
                    ),
                    child: Column(
                      children: [
                        _buildShimmerTitle(titleFontSize),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildSubtitle(subtitleFontSize),
                      ],
                    ),
                  ),
                  
                  // Mic animation with error handling
                  Expanded(
                    child: Center(
                      child: FutureBuilder<LottieComposition>(
                        future: _micAnimationFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Lottie(
                              composition: snapshot.data!,
                              width: lottieSize,
                              height: lottieSize,
                              fit: BoxFit.contain,
                            );
                          } 
                          if (snapshot.hasError) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic, size: lottieSize / 2, color: AppColors.primary),
                                const SizedBox(height: 16),
                                const Text("Animation couldn't be loaded",
                                  style: TextStyle(color: AppColors.textDark)),
                              ],
                            );
                          }
                          return const CupertinoActivityIndicator();
                        },
                      ),
                    ),
                  ),
                  
                  // Terms agreement
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.08, 
                      vertical: isSmallScreen ? 5.0 : 10.0
                    ),
                    child: const TermsAgreementWidget(),
                  ),
                  
                  // Action slider
                  Padding(
                    padding: EdgeInsets.only(
                      left: constraints.maxWidth * 0.06, 
                      right: constraints.maxWidth * 0.06, 
                      bottom: (safePadding.bottom + 16.0).clamp(24.0, 40.0),
                      top: 10.0,
                    ),
                    child: _buildActionSlider(constraints),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionSlider(BoxConstraints constraints) {
    return Semantics(
      label: "Slide to start using DuckBuck",
      child: ActionSlider.custom(
        controller: _actionSliderController,
        width: double.infinity,
        height: 60.0,
        toggleWidth: 60.0,
        toggleMargin: const EdgeInsets.all(4.0),
        actionThreshold: 0.9,
        slideAnimationCurve: Curves.easeOutQuart,
        reverseSlideAnimationCurve: Curves.easeInQuad,
        sliderBehavior: SliderBehavior.stretch,
        toggleMarginDuration: const Duration(milliseconds: 800),
        slideAnimationDuration: const Duration(milliseconds: 500),
        reverseSlideAnimationDuration: const Duration(milliseconds: 500),
        
        // Outer background builder
        outerBackgroundBuilder: (context, state, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade50, Colors.amber.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.shade200.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
        
        // Background builder
        backgroundBuilder: (context, state, child) => Container(
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.primaryDark.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              "Let's Go",
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: (constraints.maxWidth * 0.04).clamp(16.0, 22.0),
              ),
            ),
          ),
        ),
        
        // Foreground builder (slider thumb)
        foregroundBuilder: (context, state, child) => Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
        
        // Foreground child (slider thumb)
        foregroundChild: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: IconTheme(
            data: const IconThemeData(color: AppColors.textLight),
            child: ValueListenableBuilder<ActionSliderControllerState>(
              valueListenable: _actionSliderController,
              builder: (context, state, _) {
                if (state.status is SliderStatusLoading) {
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                      ),
                    ),
                  );
                }
                return const Icon(Icons.arrow_forward_rounded);
              },
            ),
          ),
        ),
        
        // Action handler
        action: (controller) async {
          controller.loading();
          await Future.delayed(const Duration(milliseconds: 800));
          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerTitle(double fontSize) {
    return Stack(
      children: [
        // Shadow layers for 3D effect
        for (var i = 0; i < 2; i++)
          Positioned(
            left: 3.0 - i.toDouble(),
            top: 3.0 - i.toDouble(),
            child: Text(
              "DuckBuck",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.brown.shade900.withOpacity(i == 0 ? 0.3 : 0.5),
              ),
            ),
          ),
        
        // Main text with shimmer
        Shimmer.fromColors(
          baseColor: Colors.brown.shade700,
          highlightColor: Colors.amber.shade300,
          child: Text(
            "DuckBuck",
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(double fontSize) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade200.withOpacity(0.7),
              Colors.amber.shade300.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.shade200.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: Colors.brown.shade400.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          "Your Internet Walkie Talkie",
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.brown.shade800,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// Extracted dialog widget
class StatusDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? animationPath;
  final IconData? icon;
  final bool useAnimation;

  const StatusDialog({
    super.key,
    required this.title,
    required this.message,
    this.animationPath,
    this.icon,
    this.useAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget headerWidget = useAnimation && animationPath != null
      ? LottieBuilder.asset(
          animationPath!,
          width: 120,
          height: 120,
          repeat: false,
          frameRate: FrameRate.max,
          errorBuilder: (_, __, ___) => Icon(
            icon ?? Icons.check_circle_outline,
            size: 70,
            color: AppColors.primary,
          ),
        )
      : Icon(
          icon ?? Icons.check_circle_outline,
          size: 70,
          color: AppColors.primary,
        );

    final Widget buttonWidget = SizedBox(
      width: double.infinity,
      child: Platform.isIOS
        ? CupertinoButton(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        : ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('OK'),
          ),
    );

    final dialogContent = Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          headerWidget,
          const SizedBox(height: 16),
          Text(title, style: AppStyles.dialogTitle, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(message, style: AppStyles.dialogBody, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          buttonWidget,
        ],
      ),
    );

    final dialogWidget = Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: AppColors.background,
      child: dialogContent,
    );

    // Use appropriate platform dialog
    return Platform.isIOS
        ? CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.light,
              primaryColor: AppColors.primary,
            ),
            child: dialogWidget,
          )
        : dialogWidget;
  }
}