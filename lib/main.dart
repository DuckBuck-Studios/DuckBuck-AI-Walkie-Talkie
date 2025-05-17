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
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with error handling
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      // Allow app to continue even if Firebase fails, with limited functionality
    }

    // Initialize Firebase App Check with error handling
    try {
      final appCheckService = FirebaseAppCheckService();
      await appCheckService.initialize();
      debugPrint('Firebase App Check initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Firebase App Check: $e');
      // App can still function without App Check, but with reduced security
    }

    // Initialize shared preferences
    try {
      await PreferencesService.instance.init();
      debugPrint('Preferences service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Preferences: $e');
      // Critical error - app depends on preferences
      rethrow;
    }

    // Setup service locator
    try {
      await setupServiceLocator();
      debugPrint('Service locator initialized successfully');
    } catch (e) {
      debugPrint('Failed to setup service locator: $e');
      // Critical error - app depends on services
      rethrow;
    }

    // Configure system UI overlay for consistent appearance
    AppTheme.configureSystemUIOverlay();

    // Ensure authentication state is in sync
    try {
      await _syncAuthState();
      debugPrint('Auth state synchronized successfully');
    } catch (e) {
      debugPrint('Error syncing auth state: $e');
      // Handle but continue execution
    }
    
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Critical error during app initialization: $e');
    // Show some kind of error UI or gracefully exit
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app: $e'),
          ),
        ),
      ),
    );
  }
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
        title: 'DuckBuck - Updated',
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
