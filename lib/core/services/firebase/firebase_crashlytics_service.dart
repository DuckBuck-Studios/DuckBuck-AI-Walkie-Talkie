import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import '../logger/logger_service.dart';
import '../service_locator.dart';

/// Service for handling Firebase Crashlytics operations
/// 
/// Provides methods for tracking crashes, recording non-fatal errors,
/// and setting user identifiers for better error tracking
class FirebaseCrashlyticsService {
  final FirebaseCrashlytics _crashlytics;
  final LoggerService _logger;
  
  static const String _tag = 'FIREBASE_CRASHLYTICS_SERVICE';
  
  /// Creates a new FirebaseCrashlyticsService instance
  FirebaseCrashlyticsService({
    FirebaseCrashlytics? crashlytics,
    LoggerService? logger,
  }) : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance,
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Initialize Crashlytics and set up error handlers
  Future<void> initialize() async {
    // Only enable Crashlytics for non-debug builds
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    
    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    
    // Set app metadata for better crash analytics
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await _crashlytics.setCustomKey('app_version', packageInfo.version);
      await _crashlytics.setCustomKey('build_number', packageInfo.buildNumber);
      await _crashlytics.setCustomKey('package_name', packageInfo.packageName);
      await _crashlytics.setCustomKey('platform', Platform.operatingSystem);
      await _crashlytics.setCustomKey('platform_version', Platform.operatingSystemVersion);
      await _crashlytics.log('Crashlytics initialized with app metadata');
    } catch (e) {
      _logger.e(_tag, 'Failed to set app metadata for Crashlytics: $e');
    }
    
    _logger.i(_tag, 'Firebase Crashlytics initialized${kDebugMode ? " (disabled in debug mode)" : ""}');
  }

  /// Pass PlatformDispatcher errors to Crashlytics
  // Use this in main.dart with: PlatformDispatcher.instance.onError = crashlyticsService.recordPlatformError;
  bool recordPlatformError(Object error, StackTrace stack) {
    _crashlytics.recordError(error, stack, fatal: true);
    return true;
  }
  
  /// Set user ID for better crash analytics
  Future<void> setUserIdentifier(String userId) async {
    await _crashlytics.setUserIdentifier(userId);
  }
  
  /// Log non-fatal exceptions with custom keys
  Future<void> recordError(dynamic exception, StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? information,
  }) async {
    // Add custom keys if provided
    if (information != null) {
      for (final entry in information.entries) {
        await _crashlytics.setCustomKey(entry.key, entry.value.toString());
      }
    }
    
    // Record the error
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }
  
  /// Log a message to Crashlytics (useful for debugging crash reports)
  Future<void> log(String message) async {
    await _crashlytics.log(message);
  }
  
  /// Clear all Crashlytics keys (useful during logout)
  Future<void> clearKeys() async {
    // Note: As of current Firebase SDK, there's no direct method to clear all keys
    // You may need to set each important key to a blank/default value
    await _crashlytics.setUserIdentifier('');
  }
  
  /// Force a test crash (only for testing)
  Future<void> forceCrash() async {
    if (!kReleaseMode) {
      _crashlytics.crash();
    } else {
      _logger.w(_tag, 'Refusing to force crash in release mode');
    }
  }
  
  /// Get the instance of FirebaseCrashlytics
  FirebaseCrashlytics get instance => _crashlytics;
  
  /// Track the current screen the user is viewing
  Future<void> setCurrentScreen(String screenName) async {
    await _crashlytics.setCustomKey('current_screen', screenName);
    await _crashlytics.log('Screen viewed: $screenName');
  }
  
  /// Track the current feature the user is using
  Future<void> setCurrentFeature(String featureName) async {
    await _crashlytics.setCustomKey('current_feature', featureName);
  }
  
  /// Set a custom key and value to help with crash analysis
  Future<void> setCustomKey(String key, dynamic value) async {
    await _crashlytics.setCustomKey(key, value.toString());
  }
  
  /// Set user preference for crash reporting (opt-in/opt-out)
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }
}
