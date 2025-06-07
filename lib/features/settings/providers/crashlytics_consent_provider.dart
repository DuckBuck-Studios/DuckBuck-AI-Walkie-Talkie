import 'package:flutter/foundation.dart';
import '../../../core/services/crashlytics_consent_manager.dart';
import '../../../core/services/service_locator.dart';

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
        _manager = serviceLocator<CrashlyticsConsentManager>();
        
        // Get current consent status
        _isEnabled = await _manager!.getUserConsent();
        
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
      // Fallback to direct manager creation if not available
      final manager = CrashlyticsConsentManager.create();
      await manager.setUserConsent(enabled: enabled);
    }
    
    _isEnabled = enabled;
    notifyListeners();
  }

  /// Check if user has made a consent choice
  Future<bool> hasUserMadeChoice() async {
    if (_manager != null) {
      return await _manager!.hasUserMadeChoice();
    } else {
      final manager = CrashlyticsConsentManager.create();
      return await manager.hasUserMadeChoice();
    }
  }

  /// Clear consent data (useful for testing or reset)
  Future<void> clearConsent() async {
    if (_manager != null) {
      await _manager!.clearConsent();
    } else {
      final manager = CrashlyticsConsentManager.create();
      await manager.clearConsent();
    }
    
    _isEnabled = kReleaseMode; // Reset to default
    notifyListeners();
  }
}
