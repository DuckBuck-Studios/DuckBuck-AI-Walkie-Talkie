import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase_options.dart';
import '../services/preferences_service.dart';
import '../services/service_locator.dart';
import '../services/security/app_security_service.dart';
import '../services/firebase/firebase_app_check_service.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/crashlytics_consent_manager.dart';
import '../services/logger/logger_service.dart';
import '../services/fcm/fcm_service.dart';

/// Handles the bootstrapping of the app
///
/// Responsible for initializing all required services and ensuring
/// the application is in a valid state before starting
class AppBootstrapper {
  LoggerService? _logger;
  
  /// Initialize all required services for the app to function
  Future<void> initialize() async {
    // Can't use service locator logger yet since we haven't set it up
    print('[AppBootstrapper] Starting app initialization');
    
    await _initializeFirebase();
    await _initializeCrashlytics();
    await _initializeAppCheck();
    await _initializePreferences();
    await _initializeServiceLocator();
    
    // Now we can use the service locator logger
    _logger = serviceLocator<LoggerService>();
    _logger!.i('BOOTSTRAP', 'Service locator initialized, continuing with remaining services');
    
    await _initializeSecurity();
    await _initializeCrashlyticsConsent();
    await _initializeFCM();
    await _syncAuthState();
    
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
      await PreferencesService.instance.init();
      print('[Preferences] Preferences service initialized successfully');
    } catch (e) {
      print('[Preferences] Failed to initialize Preferences: $e');
      // Critical error - app depends on preferences
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

  Future<void> _initializeSecurity() async {
    try {
      final securityService = serviceLocator<AppSecurityService>();
      final securityInitialized = await securityService.initialize();
      if (!securityInitialized) {
        _logger!.w('SECURITY', 'Security services initialized with warnings');
      } else {
        _logger!.i('SECURITY', 'Security services initialized successfully');
      }
    } catch (e) {
      _logger!.e('SECURITY', 'Error initializing security services: $e');
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
  }

  Future<void> _initializeCrashlyticsConsent() async {
    try {
      // Wait for the async singleton to be ready
      await serviceLocator.isReady<CrashlyticsConsentManager>();
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

  /// Sync authentication state between Firebase and SharedPreferences
  Future<void> _syncAuthState() async {
    try {
      // Check if Firebase says we're logged in
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final isLoggedInPrefs = PreferencesService.instance.isLoggedIn;

      // If there's a mismatch between Firebase and SharedPreferences
      if (firebaseUser == null && isLoggedInPrefs) {
        // Firebase says logged out but SharedPrefs says logged in - fix by clearing all
        await PreferencesService.instance.setLoggedIn(false);
        await PreferencesService.instance.clearAll();
        _logger!.w('AUTH', 'Auth state mismatch detected and fixed: Cleared invalid login state');
      } else if (firebaseUser != null && !isLoggedInPrefs) {
        // Firebase says logged in but SharedPrefs says logged out - update preferences
        await PreferencesService.instance.setLoggedIn(true);
        _logger!.w('AUTH', 'Auth state mismatch detected and fixed: Updated preferences to match Firebase auth state');
      } else {
        // States match, ensure they're both up to date
        await PreferencesService.instance.setLoggedIn(firebaseUser != null);
        _logger!.i('AUTH', 'Auth state synced: User is ${firebaseUser != null ? "logged in" : "logged out"}');
      }
    } catch (e) {
      _logger!.e('AUTH', 'Error syncing auth state: $e');
      // Handle but continue execution
    }
  }
}
