import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'core/services/firebase/firebase_crashlytics_service.dart';
import 'core/services/crashlytics_consent_manager.dart';
import 'core/providers/crashlytics_consent_provider.dart';
import 'core/services/auth/auth_security_manager.dart'; 
import 'core/services/security/app_security_service.dart';
import 'core/repositories/user_repository.dart'; 
void main() async {
  // Setup error capture before any other initialization
  WidgetsFlutterBinding.ensureInitialized();
  
  try {

    // Initialize Firebase with error handling
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      // Allow app to continue even if Firebase fails, with limited functionality
    }

    // Initialize Firebase Crashlytics with error handling
    try {
      final crashlyticsService = FirebaseCrashlyticsService();
      await crashlyticsService.initialize();
      
      // Register for unhandled errors in Flutter/Dart
      FlutterError.onError = crashlyticsService.instance.recordFlutterFatalError;
      
      // Register for unhandled errors in the platform/native side
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlyticsService.recordError(error, stack, fatal: true);
        return true;
      };
      
      // Note: FirebaseCrashlyticsService is registered in setupServiceLocator()
      debugPrint('Firebase Crashlytics initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Firebase Crashlytics: $e');
      // App can function without Crashlytics, but with reduced error reporting
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

    // Initialize the security service
    try {
      final securityService = serviceLocator<AppSecurityService>();
      final securityInitialized = await securityService.initialize();
      if (!securityInitialized) {
        debugPrint('⚠️ Security services initialized with warnings');
      } else {
        debugPrint('🔒 Security services initialized successfully');
      }
    } catch (e) {
      debugPrint('❌ Error initializing security services: $e');
      // Continue with reduced security, but log the issue
      try {
        final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
        crashlytics.recordError(
          e,
          null,
          reason: 'Security initialization failure',
          fatal: false,
          information: {'startup_stage': 'security_initialization'},
        );
      } catch (_) {
        // Silently continue if logging fails
      }
    }

    // Initialize Crashlytics consent manager
    try {
      // Wait for the async singleton to be ready
      await serviceLocator.isReady<CrashlyticsConsentManager>();
      final crashlyticsConsentManager = serviceLocator<CrashlyticsConsentManager>();
      await crashlyticsConsentManager.initialize();
      debugPrint('Crashlytics consent manager initialized');
    } catch (e) {
      debugPrint('Error initializing Crashlytics consent manager: $e');
      // Continue execution even if this fails
    }

    // Ensure authentication state is in sync
    try {
      await _syncAuthState();
      debugPrint('Auth state synchronized successfully');
    } catch (e) {
      debugPrint('Error syncing auth state: $e');
      // Handle but continue execution
    }
    
    runApp(const MyApp());
  } catch (e, stack) {
    debugPrint('Critical error during app initialization: $e');
    
    // Try to log the error to Crashlytics if available
    try {
      final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
      crashlytics.recordError(
        e,
        stack,
        reason: 'App initialization failure',
        fatal: true,
        information: {'startup_stage': 'main_initialization'},
      );
    } catch (crashlyticsError) {
      // Crashlytics itself failed, just log to console
      debugPrint('Failed to log to Crashlytics: $crashlyticsError');
    }
    
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
  } else if (firebaseUser != null && !isLoggedInPrefs) {
    // Firebase says logged in but SharedPrefs says logged out - update preferences
    await PreferencesService.instance.setLoggedIn(true);
    debugPrint(
      'Auth state mismatch detected and fixed: Updated preferences to match Firebase auth state',
    );
  } else {
    // States match, ensure they're both up to date
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late AuthSecurityManager _securityManager;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSecurityManager();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User has returned to the app - update activity
      _securityManager.updateUserActivity();
    }
  }
  
  Future<void> _initializeSecurityManager() async {
    _securityManager = serviceLocator<AuthSecurityManager>();
    await _securityManager.initialize(
      onSessionExpired: _handleSessionExpired,
    );
    
    // Start session tracking if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _securityManager.startUserSession();
    }
  }
  
  void _handleSessionExpired() {
    // Handle session timeout by logging the user out
    if (!mounted) return;
    
    // Use serviceLocator to get the UserRepository directly instead of using Provider
    // This avoids the Provider dependency in this context
    final userRepository = serviceLocator<UserRepository>();
    userRepository.signOut().then((_) {
      if (!mounted) return;
      
      // Show session expired message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please sign in again.'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Navigate to welcome screen
      AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.welcome,
        (route) => false,
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication state provider
        ChangeNotifierProvider<AuthStateProvider>(
          create: (_) => AuthStateProvider(),
        ),
        // Crashlytics consent provider
        ChangeNotifierProvider<CrashlyticsConsentProvider>(
          create: (_) {
            final provider = CrashlyticsConsentProvider();
            // Initialize in the background
            provider.initialize();
            return provider;
          },
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
