import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/services/preferences_service.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/services/service_locator.dart';
import 'features/auth/providers/auth_state_provider.dart';
import 'core/services/firebase/firebase_app_check_service.dart'; 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check
  final appCheckService = FirebaseAppCheckService();
  await appCheckService.initialize();

  // Initialize shared preferences
  await PreferencesService.instance.init();

  // Setup service locator
  await setupServiceLocator();

  // Removed deep link service initialization

  // Configure system UI overlay for consistent appearance
  AppTheme.configureSystemUIOverlay();

  // Ensure authentication state is in sync
  await _syncAuthState();

  runApp(const MyApp());
}

/// Sync authentication state between Firebase and SharedPreferences
Future<void> _syncAuthState() async {
  // Check if Firebase says we're logged in
  final firebaseUser = FirebaseAuth.instance.currentUser;
  final isLoggedInPrefs = PreferencesService.instance.isLoggedIn;

  // If there's a mismatch between Firebase and SharedPreferences
  if (firebaseUser == null && isLoggedInPrefs) {
    // Firebase says logged out but SharedPrefs says logged in - fix by clearing all
    await PreferencesService.instance.setLoggedIn(false);
    await PreferencesService.instance.clearAll();
    debugPrint(
      'Auth state mismatch detected and fixed: Cleared invalid login state',
    );
  } else {
    // Update shared preferences to match Firebase auth state
    await PreferencesService.instance.setLoggedIn(firebaseUser != null);
    debugPrint(
      'Auth state synced: User is ${firebaseUser != null ? "logged in" : "logged out"}',
    );
  }
}

/// Root application widget
///
/// Sets up global providers and theme configuration for the app.
/// Use MultiProvider pattern for scalable state management.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication state provider
        ChangeNotifierProvider<AuthStateProvider>(
          create: (_) => AuthStateProvider(),
        ),
        // Add more app-wide providers here as needed
      ],
      child: MaterialApp(
        title: 'DuckBuck',
        theme: AppTheme.blackTheme,
        darkTheme: AppTheme.blackTheme,
        themeMode: ThemeMode.system, // Uses system theme preference
        debugShowCheckedModeBanner: false,
        navigatorKey: AppRoutes.navigatorKey,
        initialRoute: _determineInitialRoute(),
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }

  /// Determine the initial route based on authentication state and preferences
  String _determineInitialRoute() {
    final bool isLoggedIn = PreferencesService.instance.isLoggedIn;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Only consider user logged in if both Firebase and SharedPreferences agree
    if (isLoggedIn && firebaseUser != null) {
      return AppRoutes.home;
    } else {
      // If there's a mismatch, ensure we're properly logged out
      if (isLoggedIn && firebaseUser == null) {
        // Fix inconsistent state - SharedPrefs says logged in but Firebase says no
        PreferencesService.instance.setLoggedIn(false);
        PreferencesService.instance.clearAll();
      }

      // Default to welcome screen for new users
      return AppRoutes.welcome;
    }
  }
}
