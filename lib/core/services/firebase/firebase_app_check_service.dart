import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';

/// Service to handle Firebase App Check setup
class FirebaseAppCheckService {
  final LoggerService _logger;
  
  static const String _tag = 'FIREBASE_APP_CHECK_SERVICE';
  
  /// Creates a new FirebaseAppCheckService instance
  FirebaseAppCheckService({LoggerService? logger})
    : _logger = logger ?? serviceLocator<LoggerService>();

  /// Initialize Firebase App Check with appropriate provider
  Future<void> initialize() async {
    try {
      // Initialize with the appropriate provider based on environment
      if (kDebugMode) {
        // For development environments, use debug provider with specific settings
        // This is crucial for phone authentication to work during development
        await FirebaseAppCheck.instance.activate(
          // For debugging, use the debug provider which is more reliable in development
          androidProvider: AndroidProvider.debug,
          // Keep using debug provider for Apple
          appleProvider: AppleProvider.debug,
        );

        // Explicitly set the app's package
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

        _logger.i(_tag, 'Using debug-compatible providers for development');

        // When using debug provider, log the debug token again to remind user
        final debugToken = await FirebaseAppCheck.instance.getToken();
        _logger.w(_tag, 'Debug token refreshed. Ensure this is added to Firebase Console: ${debugToken ?? 'No token available'}');
      } else {
        // For production environments
        await FirebaseAppCheck.instance.activate( 
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
        _logger.i(_tag, 'Using production providers');
      }

      _logger.i(_tag, 'Firebase App Check activated successfully');
    } catch (e) {
      _logger.e(_tag, 'Failed to activate Firebase App Check - ${e.toString()}'); 
    }
  }
}
