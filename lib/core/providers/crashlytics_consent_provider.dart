import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/crashlytics_consent_manager.dart';
import '../services/firebase/firebase_crashlytics_service.dart';
import '../services/service_locator.dart';

/// Provider to manage crashlytics consent state in the app
class CrashlyticsConsentProvider with ChangeNotifier {
  CrashlyticsConsentManager? _manager;
  bool _isEnabled = kReleaseMode; // Default to enabled in release mode
  bool _isInitialized = false;

  /// Creates a new CrashlyticsConsentProvider
  CrashlyticsConsentProvider();

  /// Whether crash reporting is currently enabled
  bool get isEnabled => _isEnabled;
  
  /// Whether the consent state has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the provider by loading saved consent status
  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        // Wait for the singleton to be ready
        await serviceLocator.isReady<CrashlyticsConsentManager>();
        _manager = serviceLocator<CrashlyticsConsentManager>();
        
        // Get current consent status
        final prefs = await SharedPreferences.getInstance();
        _isEnabled = prefs.getBool(
          'crashlytics_enabled'
        ) ?? kReleaseMode;
        
        _isInitialized = true;
        notifyListeners();
      } catch (e) {
        debugPrint('Error initializing CrashlyticsConsentProvider: $e');
        // Use default value
        _isEnabled = kReleaseMode;
        _isInitialized = true;
      }
    }
  }

  /// Update the user's consent for crash reporting
  Future<void> setConsent(bool enabled) async {
    if (_manager != null) {
      await _manager!.setUserConsent(enabled: enabled);
    } else {
      // Direct implementation if manager isn't available
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('crashlytics_enabled', enabled);
      
      final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
      await crashlytics.setCrashlyticsCollectionEnabled(enabled);
    }
    
    _isEnabled = enabled;
    notifyListeners();
  }
}
