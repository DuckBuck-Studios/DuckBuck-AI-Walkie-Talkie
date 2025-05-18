import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase App Check setup
class FirebaseAppCheckService {
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

        debugPrint('🔒 APP CHECK: Using debug-compatible providers for development');

        // When using debug provider, log the debug token again to remind user
        final debugToken = await FirebaseAppCheck.instance.getToken();
        debugPrint(
          '🔑 APP CHECK: Debug token refreshed. Ensure this is added to Firebase Console: ${debugToken ?? 'No token available'}',
        );
      } else {
        // For production environments
        await FirebaseAppCheck.instance.activate( 
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
        debugPrint('🔒 APP CHECK: Using production providers');
      }

      debugPrint('🔒 APP CHECK: Firebase App Check activated successfully');
    } catch (e) {
      debugPrint(
        '❌ APP CHECK ERROR: Failed to activate Firebase App Check - ${e.toString()}',
      ); 
    }
  }
}
