import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase/firebase_crashlytics_service.dart';
import 'service_locator.dart';

/// Service for managing user consent for crash reporting
class CrashlyticsConsentManager {
  static const String _crashlyticsEnabledKey = 'crashlytics_enabled';
  
  final SharedPreferences _prefs;
  final FirebaseCrashlyticsService _crashlytics;
  
  /// Creates a new CrashlyticsConsentManager
  CrashlyticsConsentManager({
    required SharedPreferences prefs,
    FirebaseCrashlyticsService? crashlytics,
  }) : _prefs = prefs,
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>();
       
  /// Factory constructor to create an instance with SharedPreferences
  static Future<CrashlyticsConsentManager> create({
    FirebaseCrashlyticsService? crashlytics,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return CrashlyticsConsentManager(
      prefs: prefs,
      crashlytics: crashlytics,
    );
  }

  /// Initialize and load stored user consent
  Future<void> initialize() async {
    // Check if user has already made a choice
    final hasUserConsented = _prefs.containsKey(_crashlyticsEnabledKey);
    
    if (!hasUserConsented) {
      // Default to disabled in debug mode and enabled in release mode
      await setUserConsent(enabled: kReleaseMode);
    } else {
      // Load user preference and apply it
      final isEnabled = _prefs.getBool(_crashlyticsEnabledKey) ?? kReleaseMode;
      await _crashlytics.setCrashlyticsCollectionEnabled(isEnabled);
    }
  }
  
  /// Set user consent for crash reporting
  Future<void> setUserConsent({required bool enabled}) async {
    await _prefs.setBool(_crashlyticsEnabledKey, enabled);
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
    
    _crashlytics.log('User ${enabled ? 'enabled' : 'disabled'} crash reporting');
  }
  
  /// Get current user consent status
  Future<bool> getUserConsent() async {
    return _prefs.getBool(_crashlyticsEnabledKey) ?? kReleaseMode;
  }
  
  /// Show a dialog to prompt the user for crash reporting consent
  static Future<void> showConsentDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final manager = CrashlyticsConsentManager(
      prefs: prefs,
      crashlytics: serviceLocator<FirebaseCrashlyticsService>(),
    );
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help improve DuckBuck'),
        content: const Text(
          'Would you like to help us improve DuckBuck by automatically sending crash reports? '
          'This helps us identify and fix issues faster. '
          'No personal information is collected with these reports.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await manager.setUserConsent(enabled: false);
              Navigator.of(context).pop();
            },
            child: const Text('No thanks'),
          ),
          FilledButton(
            onPressed: () async {
              await manager.setUserConsent(enabled: true);
              Navigator.of(context).pop();
            },
            child: const Text('Yes, I\'ll help'),
          ),
        ],
      ),
    );
  }
}
