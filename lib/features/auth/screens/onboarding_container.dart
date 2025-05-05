import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:duckbuck/core/services/preferences_service.dart';

import 'onboarding_screen_1.dart';
import 'onboarding_screen_2.dart';
import 'onboarding_screen_3.dart';
import 'onboarding_signup_screen.dart';

class OnboardingContainer extends StatefulWidget {
  const OnboardingContainer({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingContainer> createState() => _OnboardingContainerState();
}

class _OnboardingContainerState extends State<OnboardingContainer> {
  int _currentPage = 0;
  late final LiquidController _liquidController;

  @override
  void initState() {
    super.initState();
    _liquidController = LiquidController();

    // Use post frame callback to ensure the widget is built before using controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreOnboardingProgress();
    });
  }

  Future<void> _restoreOnboardingProgress() async {
    // Restore the last saved onboarding step
    final savedStep = PreferencesService.instance.currentOnboardingStep;
    if (savedStep > 0 && savedStep < 4) {
      setState(() {
        _currentPage = savedStep;
      });

      // Now the controller should be properly attached
      try {
        _liquidController.jumpToPage(page: savedStep);
      } catch (e) {
        debugPrint('Error jumping to page: $e');
        // Fallback to animating if jump fails
        _liquidController.animateToPage(page: savedStep, duration: 0);
      }
    }
  }

  void _triggerHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  void _goToNextPage() {
    if (_currentPage < 3) {
      // Animate to the next page
      final nextPage = _currentPage + 1;
      _liquidController.animateToPage(page: nextPage, duration: 600);
      _triggerHapticFeedback();

      // Save the current step to preferences
      PreferencesService.instance.setCurrentOnboardingStep(nextPage);
    }
  }

  Future<void> _completeOnboarding() async {
    _triggerHapticFeedback();
    // Save that onboarding is complete
    await PreferencesService.instance.setOnboardingComplete(true);

    // Notify parent
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    // Pre-create all pages at once to avoid rebuilding during transitions
    final pages = [
      OnboardingScreen1(onNext: _goToNextPage),
      OnboardingScreen2(onNext: _goToNextPage),
      OnboardingScreen3(onNext: _goToNextPage),
      OnboardingSignupScreen(onComplete: _completeOnboarding),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: LiquidSwipe(
        pages: pages,
        enableSideReveal: false,
        onPageChangeCallback: (page) {
          setState(() {
            _currentPage = page;
          });
          // Save the current page when user manually swipes
          PreferencesService.instance.setCurrentOnboardingStep(page);
          _triggerHapticFeedback();
        },
        waveType: WaveType.liquidReveal,
        liquidController: _liquidController,
        enableLoop: false,
        fullTransitionValue: 880,
        ignoreUserGestureWhileAnimating: true,
        disableUserGesture: false,
        slidePercentCallback: (slidePercent, slideDirection) {
          // This lets us monitor the slide progress if needed
        },
        positionSlideIcon: 0.5,
        preferDragFromRevealedArea: true,
      ),
    );
  }
}
