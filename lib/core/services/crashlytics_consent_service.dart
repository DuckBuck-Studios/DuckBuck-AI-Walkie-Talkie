import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase/firebase_crashlytics_service.dart';
import 'service_locator.dart';

/// Service for managing user consent for crash reporting
class CrashlyticsConsentService {
  static const String _crashlyticsEnabledKey = 'crashlytics_enabled';
  
  final SharedPreferences _prefs;
  final FirebaseCrashlyticsService _crashlytics;
  
  /// Creates a new CrashlyticsConsentService
  CrashlyticsConsentService({
    SharedPreferences? prefs,
    FirebaseCrashlyticsService? crashlytics,
  }) : _prefs = prefs ?? serviceLocator<SharedPreferences>(),
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>();

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
  bool get isEnabled => _prefs.getBool(_crashlyticsEnabledKey) ?? kReleaseMode;
}
