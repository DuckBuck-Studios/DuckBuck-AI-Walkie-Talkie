import 'package:flutter/material.dart';
import 'package:duckbuck/features/splash/screens/splash_screen.dart';
import 'package:duckbuck/features/auth/screens/welcome_screen.dart';
import 'package:duckbuck/features/auth/screens/onboarding_signup_screen.dart';
import 'package:duckbuck/features/auth/screens/profile_completion_screen.dart';
import 'package:duckbuck/features/main_navigation.dart';  
import 'package:duckbuck/core/services/database/local_database_service.dart';
import 'package:duckbuck/core/legal/legal_document_screen.dart';
import 'package:duckbuck/core/legal/legal_service.dart';
import 'package:duckbuck/features/settings/screens/privacy_settings_screen.dart';
import 'package:duckbuck/features/settings/screens/blocked_users_screen.dart';
import 'package:duckbuck/features/ai_agent/screens/ai_agent_screen.dart';

/// Main app routes and navigation helper
class AppRoutes {
  // Premium splash screen as initial route
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String onboarding = '/onboarding';
  static const String home = '/home'; // This now points to the HomeScreen with GNav
  static const String profileCompletion = '/profile_completion';
  static const String termsOfService = '/terms';
  static const String privacyPolicy = '/privacy';
  static const String privacySettings = '/privacy_settings';
  static const String blockedUsers = '/blocked_users';
  static const String aiAgent = '/ai-agent'; 

  /// Generate routes for the app
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case welcome:
        // Mark that user has seen welcome screen
        LocalDatabaseService.instance.setBoolSetting('welcome_seen', true);
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case onboarding:
        return MaterialPageRoute(
          builder:
              (_) => OnboardingSignupScreen(
                onComplete:
                    () => navigatorKey.currentState?.pushReplacementNamed(home),
              ),
        );

      case home: // This route now leads to MainNavigation which contains GNav and HomeScreen as a tab
        return MaterialPageRoute(builder: (_) => const MainNavigation()); // Changed to MainNavigation

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

      case privacySettings:
        return MaterialPageRoute(
          builder: (_) => const PrivacySettingsScreen(),
        );
        
      case blockedUsers:
        return MaterialPageRoute(
          builder: (_) => const BlockedUsersScreen(),
        );
        
      case aiAgent:
        return MaterialPageRoute(
          builder: (_) => const AiAgentScreen(),
        );
              
      // case friends: // Removed as it's part of HomeScreen's GNav
      //   return MaterialPageRoute(
      //     builder: (_) => const FriendsScreen(),
      //   );

      // case AppRoutes.settings: // Removed as it's part of HomeScreen's GNav
      //   return MaterialPageRoute(
      //     builder: (_) => const SettingsScreen(),
      //   );

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
   

  // Global navigator key to use for navigation from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
