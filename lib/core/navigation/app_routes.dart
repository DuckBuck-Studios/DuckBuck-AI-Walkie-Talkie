import 'package:flutter/material.dart';
import 'package:duckbuck/features/auth/screens/welcome_screen.dart';
import 'package:duckbuck/features/auth/screens/onboarding_container.dart';
import 'package:duckbuck/features/auth/screens/profile_completion_screen.dart';
import 'package:duckbuck/features/home/screens/home_screen.dart';
import 'package:duckbuck/core/services/preferences_service.dart';
import 'package:duckbuck/core/legal/legal_document_screen.dart';
import 'package:duckbuck/core/legal/legal_service.dart';

/// Main app routes and navigation helper
class AppRoutes {
  // Make welcome the root route
  static const String welcome = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String profileCompletion = '/profile_completion';
  static const String termsOfService = '/terms';
  static const String privacyPolicy = '/privacy';

  /// Generate routes for the app
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        // Mark that user has seen welcome screen
        PreferencesService.instance.setWelcomeSeen(true);
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case onboarding:
        return MaterialPageRoute(
          builder:
              (_) => OnboardingContainer(
                onComplete:
                    () => navigatorKey.currentState?.pushReplacementNamed(home),
              ),
        );

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case profileCompletion:
        return MaterialPageRoute(
          builder: (_) => const ProfileCompletionScreen(),
        );

      case termsOfService:
        return MaterialPageRoute(
          builder:
              (_) => LegalDocumentScreen(
                title: 'Terms of Service',
                documentLoader: () => LegalService.instance.getTermsOfService(),
              ),
        );

      case privacyPolicy:
        return MaterialPageRoute(
          builder:
              (_) => LegalDocumentScreen(
                title: 'Privacy Policy',
                documentLoader: () => LegalService.instance.getPrivacyPolicy(),
              ),
        );

      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('No route defined for ${settings.name}'),
                ),
              ),
        );
    }
  }

  /// Get the initial route based on app state
  static String getInitialRoute() {
    final prefsService = PreferencesService.instance;

    if (prefsService.hasCompletedOnboarding) {
      // User completed the onboarding, go to home
      return home;
    } else if (prefsService.hasSeenWelcome &&
        prefsService.currentOnboardingStep > 0) {
      // User started onboarding but didn't complete it
      return onboarding;
    } else {
      // User is new or reset everything
      return welcome;
    }
  }

  // Global navigator key to use for navigation from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
