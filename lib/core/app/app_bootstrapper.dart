import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase_options.dart';
import '../services/service_locator.dart'; 
import '../services/firebase/firebase_app_check_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/crashlytics_consent_manager.dart';
import '../services/logger/logger_service.dart';
import '../services/fcm/fcm_service.dart';
import '../services/database/local_database_service.dart';
import '../services/lifecycle/app_lifecycle_manager.dart';

/// Handles the bootstrapping of the app
///
/// Responsible for initializing all required services and ensuring
/// the application is in a valid state before starting
class AppBootstrapper {
  LoggerService? _logger;
  
  /// Initialize all required services for the app to function
  Future<void> initialize() async { 
    
    await _initializeFirebase();
    await _initializeCrashlytics();
    await _initializeAppCheck();
    await _initializePreferences();
    await _initializeServiceLocator();
    
    // Now we can use the service locator logger
    _logger = serviceLocator<LoggerService>();
    _logger!.i('BOOTSTRAP', 'Service locator initialized, continuing with remaining services');
     
    await _initializeCrashlyticsConsent();
    await _initializeFCM();
    await _syncAuthState();
    await _initializeAppLifecycle();
    
    _logger!.i('BOOTSTRAP', 'App initialization completed successfully');
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('[Firebase] Firebase initialized successfully');
    } catch (e) {
      print('[Firebase] Failed to initialize Firebase: $e');
      // Allow app to continue with limited functionality
    }
  }

  Future<void> _initializeCrashlytics() async {
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
      
      print('[Crashlytics] Firebase Crashlytics initialized successfully');
    } catch (e) {
      print('[Crashlytics] Failed to initialize Firebase Crashlytics: $e');
      // App can function without Crashlytics, with reduced error reporting
    }
  }

  Future<void> _initializeAppCheck() async {
    try {
      final appCheckService = FirebaseAppCheckService();
      await appCheckService.initialize();
      print('[AppCheck] Firebase App Check initialized successfully');
    } catch (e) {
      print('[AppCheck] Failed to initialize Firebase App Check: $e');
      // App can still function without App Check, with reduced security
    }
  }

  Future<void> _initializePreferences() async {
    try {
      // LocalDatabaseService is automatically initialized when accessed
      // No separate initialization needed like SharedPreferences
      print('[Database] LocalDatabaseService ready for app settings storage');
    } catch (e) {
      print('[Database] Failed to initialize database service: $e');
      // Critical error - app depends on local storage
      rethrow;
    }
  }

  Future<void> _initializeServiceLocator() async {
    try {
      await setupServiceLocator();
      print('[ServiceLocator] Service locator initialized successfully');
    } catch (e) {
      print('[ServiceLocator] Failed to setup service locator: $e');
      // Critical error - app depends on services
      rethrow;
    }
  }

  Future<void> _initializeCrashlyticsConsent() async {
    try {
      // Get the lazy singleton (immediately available)
      final crashlyticsConsentManager = serviceLocator<CrashlyticsConsentManager>();
      await crashlyticsConsentManager.initialize();
      _logger!.i('CRASHLYTICS', 'Crashlytics consent manager initialized');
    } catch (e) {
      _logger!.e('CRASHLYTICS', 'Error initializing Crashlytics consent manager: $e');
      // Continue execution even if this fails
    }
  }

  Future<void> _initializeFCM() async {
    try {
      final fcmService = serviceLocator<FCMService>();
      await fcmService.initialize();
      _logger!.i('FCM', 'FCM service initialized successfully');
    } catch (e) {
      _logger!.e('FCM', 'Failed to initialize FCM service: $e');
      // Continue execution even if FCM fails - notifications won't work but app will function
    }
  }

  /// Sync authentication state between Firebase and Local Database
  Future<void> _syncAuthState() async {
    try {
      // Check if Firebase says we're logged in
      final firebaseUser = FirebaseAuth.instance.currentUser;
      
      // Check if local database says we're logged in
      final localDb = LocalDatabaseService.instance;
      final isLoggedInLocalDb = await localDb.isAnyUserLoggedIn();

      // If there's a mismatch between Firebase and Local Database
      if (firebaseUser == null && isLoggedInLocalDb) {
        // Firebase says logged out but local DB says logged in - fix by clearing all
        await localDb.clearAllUserData();
        _logger!.w('AUTH', 'Auth state mismatch detected and fixed: Cleared invalid login state');
      } else if (firebaseUser != null && !isLoggedInLocalDb) {
        // Firebase says logged in but local DB says logged out
        // The user data will be saved to local DB during the normal auth flow
        _logger!.w('AUTH', 'Auth state mismatch detected and fixed: Local DB will be updated during auth flow');
      } else {
        // States match - no action needed
        _logger!.i('AUTH', 'Auth state synced: User is ${firebaseUser != null ? "logged in" : "logged out"}');
      }
    } catch (e) {
      _logger!.e('AUTH', 'Error syncing auth state: $e');
      // Handle but continue execution
    }
  }

  Future<void> _initializeAppLifecycle() async {
    try {
      final appLifecycleManager = serviceLocator<AppLifecycleManager>();
      appLifecycleManager.initialize();
      _logger!.i('LIFECYCLE', 'App lifecycle manager initialized');
    } catch (e) {
      _logger!.e('LIFECYCLE', 'Error initializing app lifecycle manager: $e');
      // Continue execution even if this fails
    }
  }
}
