import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';
import 'package:duckbuck/core/services/logger/logger_service.dart';

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
  
  // Services
  final _analytics = serviceLocator<FirebaseAnalyticsService>();
  final _logger = serviceLocator<LoggerService>();
  final String _tag = 'OnboardingContainer';

  @override
  void initState() {
    super.initState();
    _liquidController = LiquidController();

    // Use post frame callback to ensure the widget is built before using controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreOnboardingProgress();
      _logScreenView();
    });
  }
  
  void _logScreenView() {
    _analytics.logScreenView(
      screenName: 'onboarding_container',
      screenClass: 'OnboardingContainer',
    );
    _logger.i(_tag, 'Onboarding container screen viewed');
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
      
      // Log analytics when user manually advances to next page
      _analytics.logEvent(
        name: 'onboarding_next_page',
        parameters: {
          'from_page': _currentPage,
          'to_page': nextPage,
          'action': 'next_button',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i(_tag, 'User advanced from page $_currentPage to page $nextPage');
    }
  }

  Future<void> _completeOnboarding() async {
    _triggerHapticFeedback();
    // Save that onboarding is complete
    await PreferencesService.instance.setOnboardingComplete(true);

    // Notify parent
    widget.onComplete();
  }

  /// Log analytics event for onboarding page views
  void _logOnboardingPageView(int page) {
    String screenName;
    switch (page) {
      case 0:
        screenName = 'onboarding_page_1';
        break;
      case 1:
        screenName = 'onboarding_page_2';
        break;
      case 2:
        screenName = 'onboarding_page_3';
        break;
      case 3:
        screenName = 'onboarding_signup';
        break;
      default:
        screenName = 'unknown_onboarding_page';
    }
    
    _analytics.logScreenView(
      screenName: screenName,
      screenClass: 'OnboardingContainer',
    );
    
    _analytics.logEvent(
      name: 'onboarding_page_view',
      parameters: {
        'page_number': page,
        'page_name': screenName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    _logger.i(_tag, 'Viewed onboarding page: $screenName (page $page)');
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
          
          // Log the onboarding page view for analytics
          _logOnboardingPageView(page);
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
