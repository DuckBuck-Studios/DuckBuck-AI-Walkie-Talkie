import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/app/app_bootstrapper.dart';
import 'core/app/provider_registry.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth/auth_security_manager.dart';
import 'core/services/firebase/firebase_crashlytics_service.dart';
import 'core/services/logger/logger_service.dart';
import 'core/services/service_locator.dart';
import 'features/call/widgets/call_overlay.dart';

/// Main entry point for the application
void main() async {
  // Setup error capture before any other initialization
  WidgetsFlutterBinding.ensureInitialized();
   
  final bootstrapper = AppBootstrapper();
  
  try { 
    await bootstrapper.initialize(); 

    // Get logger service after initialization
    final logger = serviceLocator<LoggerService>();
    logger.i('MAIN', 'App initialization completed successfully');

    // Start the application
    runApp(const MyApp());
  } catch (e, stack) { 
    
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
    } catch (crashlyticsError)  {
      // Unable to report to Crashlytics - fallback to print since logger might not be initialized
      debugPrint('Failed to report error to Crashlytics: $crashlyticsError');
      debugPrint('Original error: $e');
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
  }
  
  Future<void> _initializeSecurityManager() async {
    _securityManager = serviceLocator<AuthSecurityManager>();
    await _securityManager.initialize(); 
     
  }
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Use the centralized provider registry to manage all app providers
      // This makes it easier to add/remove providers and ensures consistency
      providers: ProviderRegistry.getProviders(),
      child: MaterialApp(
        title: 'DuckBuck',
        theme: AppTheme.blackTheme,
        darkTheme: AppTheme.blackTheme,
        themeMode: ThemeMode.system, // Uses system theme preference
        debugShowCheckedModeBanner: false,
        navigatorKey: AppRoutes.navigatorKey,
        initialRoute: _determineInitialRoute(),
        onGenerateRoute: AppRoutes.generateRoute,
        builder: (context, child) {
          return CallOverlay(
            child: child ?? const SizedBox(),
          );
        },
      ),
    );
  }

  /// Determine the initial route based on authentication state and local database
  String _determineInitialRoute() {
    final logger = serviceLocator<LoggerService>();
    final firebaseUser = FirebaseAuth.instance.currentUser;

    logger.d('MAIN', 'Determining initial route - firebaseUser: ${firebaseUser?.uid}');

    // Use Firebase as the primary auth source (local database will be synced in background)
    if (firebaseUser != null) {
      logger.d('MAIN', 'User is logged in - navigating to home');
      return AppRoutes.home;
    } else {
      logger.d('MAIN', 'User not logged in - navigating to welcome screen');
      // Default to welcome screen for new users
      return AppRoutes.welcome;
    }
  }
}
