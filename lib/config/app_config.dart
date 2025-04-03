import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

/// Environment types for app configuration
enum Environment {
  development,
  staging,
  production,
}

/// AppConfig manages environment-specific configuration settings
/// 
/// This class provides centralized access to configuration settings
/// that vary between development, staging, and production environments.
class AppConfig {
  /// Singleton instance
  static final AppConfig _instance = AppConfig._internal();
  
  /// Factory constructor to return the singleton instance
  factory AppConfig() => _instance;
  
  /// Private constructor
  AppConfig._internal();
  
  /// Current environment
  Environment _environment = Environment.development;
  
  /// Get current environment
  Environment get environment => _environment;
  
  /// Check if running in production environment
  bool get isProduction => _environment == Environment.production;
  
  /// Check if running in development environment
  bool get isDevelopment => _environment == Environment.development;
  
  /// Check if debug logging is enabled
  bool get isLoggingEnabled => !isProduction || kDebugMode;
  
  /// Initialize the app configuration
  Future<void> initialize({Environment env = Environment.development}) async {
    _environment = env;
    
    // Configure Crashlytics
    await _configureCrashlytics();
    
    // Configure App Check with appropriate providers based on environment
    await _configureAppCheck();
    
    // Log initialization
    if (isLoggingEnabled) {
      log('AppConfig initialized in ${env.name} environment');
    }
  }
  
  /// Configure Firebase Crashlytics based on environment
  Future<void> _configureCrashlytics() async {
    try {
      // Only collect crash reports in non-debug mode or production
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        isProduction || !kDebugMode
      );
      
      // Set user-friendly app build identification
      await FirebaseCrashlytics.instance.setCustomKey('environment', _environment.name);
      await FirebaseCrashlytics.instance.setCustomKey('platform', defaultTargetPlatform.name);
      
      // Log startup
      if (isProduction) {
        FirebaseCrashlytics.instance.log('App started in ${_environment.name} mode');
      }
      
      // Catch Flutter errors automatically
      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        // Still show the error in dev console if we're in debug mode
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };
      
      // Catch async errors
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      
      log('Firebase Crashlytics initialized successfully');
    } catch (e, stackTrace) {
      // Failed to initialize Crashlytics
      if (isLoggingEnabled) {
        debugPrint('Failed to initialize Crashlytics: $e');
        if (isDevelopment) {
          debugPrint(stackTrace.toString());
        }
      }
    }
  }
  
  /// Set user ID for crash reports
  Future<void> setUserIdentifier(String userId) async {
    if (isProduction || !kDebugMode) {
      try {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId);
        log('Set Crashlytics user identifier: $userId');
      } catch (e) {
        if (isLoggingEnabled) {
          debugPrint('Failed to set user identifier for Crashlytics: $e');
        }
      }
    }
  }
  
  /// Configure Firebase App Check based on environment
  Future<void> _configureAppCheck() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // For Android, use debug provider in development, and Play Integrity in production
        await FirebaseAppCheck.instance.activate(
          // Debug provider only works in development builds
          androidProvider: isProduction ? AndroidProvider.playIntegrity : AndroidProvider.debug,
        );
        log('Firebase App Check activated for Android with ${isProduction ? "Play Integrity" : "debug"} provider');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // For iOS, use debug provider in development, and App Attest in production
        await FirebaseAppCheck.instance.activate(
          // Debug provider only works in development builds
          appleProvider: isProduction ? AppleProvider.appAttest : AppleProvider.debug,
        );
        log('Firebase App Check activated for iOS with ${isProduction ? "App Attest" : "debug"} provider');
      } else {
        log('Firebase App Check not configured for this platform: $defaultTargetPlatform');
      }
    } catch (e, stackTrace) {
      // Failed to initialize App Check
      if (isLoggingEnabled) {
        debugPrint('Failed to initialize App Check: $e');
        if (isDevelopment) {
          debugPrint(stackTrace.toString());
        }
      }
      
      // Report the error but don't rethrow - App Check failure shouldn't prevent app launch
      reportError(e, stackTrace, reason: 'Failed to initialize Firebase App Check');
    }
  }
  
  /// Safe logging method that respects environment configuration
  void log(String message) {
    if (isLoggingEnabled) {
      debugPrint('[DuckBuck] $message');
    }
  }
  
  /// Report non-fatal error to crashlytics
  void reportError(dynamic error, StackTrace stackTrace, {String? reason, Map<String, dynamic>? customData}) {
    try {
      // Always log in dev mode
      if (isDevelopment) {
        debugPrint('[DuckBuck Error] ${reason ?? 'Error'}: $error');
        if (customData != null && customData.isNotEmpty) {
          debugPrint('Additional data: $customData');
        }
        debugPrint(stackTrace.toString());
      }
      
      // Report to crashlytics if enabled
      if (isProduction || !kDebugMode) {
        // Add custom keys for additional context
        if (customData != null) {
          for (final entry in customData.entries) {
            FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value.toString());
          }
        }
        
        // Set the component/area where the error occurred
        if (reason != null) {
          FirebaseCrashlytics.instance.setCustomKey('error_context', reason);
        }
        
        // Log the error with a timestamp
        FirebaseCrashlytics.instance.log('Error occurred at ${DateTime.now().toIso8601String()}');
        
        // Record the error
        FirebaseCrashlytics.instance.recordError(
          error, 
          stackTrace,
          reason: reason,
        );
      }
    } catch (e) {
      // If Crashlytics fails, at least try to log the error
      if (isLoggingEnabled) {
        debugPrint('Failed to report error to Crashlytics: $e');
      }
    }
  }
  
  /// Track important app events for monitoring
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    try {
      // Always log in dev mode
      if (isDevelopment) {
        final paramString = parameters != null ? ' with parameters: $parameters' : '';
        debugPrint('[DuckBuck Event] $eventName$paramString');
      }
      
      // Log to Crashlytics in production for critical events
      if (isProduction) {
        // Prepare a formatted log entry
        final timestamp = DateTime.now().toIso8601String();
        final paramString = parameters != null ? ' params: ${parameters.toString()}' : '';
        final logEntry = '[$timestamp] EVENT: $eventName$paramString';
        
        // Log the event to Crashlytics
        FirebaseCrashlytics.instance.log(logEntry);
        
        // Set temporary custom keys for the most recent events (helps with debugging crashes)
        FirebaseCrashlytics.instance.setCustomKey('last_event', eventName);
        FirebaseCrashlytics.instance.setCustomKey('last_event_time', timestamp);
      }
    } catch (e) {
      // If tracking fails, just log to console
      if (isLoggingEnabled) {
        debugPrint('Failed to track event: $e');
      }
    }
  }

  /// Log app performance issue
  void logPerformanceIssue(String operation, int durationMs, {Map<String, dynamic>? context}) {
    // Only log performance issues that exceed certain thresholds
    final bool isSignificantDelay = durationMs > 1000; // 1 second threshold
    
    if (isSignificantDelay) {
      final Map<String, dynamic> perfData = {
        'operation': operation,
        'duration_ms': durationMs,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      if (context != null) {
        perfData.addAll(context);
      }
      
      // Log to console in development
      if (isDevelopment) {
        debugPrint('[DuckBuck Performance] Slow operation "$operation": ${durationMs}ms');
        if (context != null) {
          debugPrint('Performance context: $context');
        }
      }
      
      // Log to Crashlytics in production
      if (isProduction) {
        // Log non-crashing performance issues
        FirebaseCrashlytics.instance.log('PERFORMANCE ISSUE: $operation took ${durationMs}ms');
        
        // For very slow operations, record a non-fatal error
        if (durationMs > 5000) { // 5 seconds is very slow
          reportError(
            'Performance degradation', 
            StackTrace.current, 
            reason: 'Slow operation: $operation',
            customData: perfData,
          );
        }
      }
    }
  }
} 