import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'database/local_database_service.dart';
import 'firebase/firebase_crashlytics_service.dart';
import 'service_locator.dart';
import 'logger/logger_service.dart';

/// Service for managing user consent for crash reporting using LocalDatabaseService
class CrashlyticsConsentManager {
  static const String _crashlyticsEnabledKey = 'crashlytics_enabled';
  
  final LocalDatabaseService _localDb;
  final FirebaseCrashlyticsService _crashlytics;
  final LoggerService _logger;
  
  static const String _tag = 'CRASHLYTICS_CONSENT';
  
  /// Creates a new CrashlyticsConsentManager
  CrashlyticsConsentManager({
    LocalDatabaseService? localDb,
    FirebaseCrashlyticsService? crashlytics,
    LoggerService? logger,
  }) : _localDb = localDb ?? LocalDatabaseService.instance,
       _crashlytics = crashlytics ?? serviceLocator<FirebaseCrashlyticsService>(),
       _logger = logger ?? LoggerService();
       
  /// Factory constructor to create an instance
  static CrashlyticsConsentManager create({
    LocalDatabaseService? localDb,
    FirebaseCrashlyticsService? crashlytics,
    LoggerService? logger,
  }) {
    return CrashlyticsConsentManager(
      localDb: localDb,
      crashlytics: crashlytics,
      logger: logger,
    );
  }

  /// Initialize and load stored user consent
  Future<void> initialize() async {
    try {
      _logger.d(_tag, 'Initializing crashlytics consent manager...');
      
      // Check if user has already made a choice
      final consentValue = await _localDb.getSetting(_crashlyticsEnabledKey);
      final hasUserConsented = consentValue != null;
      
      if (!hasUserConsented) {
        // Default to disabled in debug mode and enabled in release mode
        _logger.i(_tag, 'No existing consent found, setting default: ${kReleaseMode}');
        await setUserConsent(enabled: kReleaseMode);
      } else {
        // Load user preference and apply it
        final isEnabled = await _localDb.getBoolSetting(_crashlyticsEnabledKey, defaultValue: kReleaseMode);
        await _crashlytics.setCrashlyticsCollectionEnabled(isEnabled);
        _logger.i(_tag, 'Loaded existing consent: $isEnabled');
      }
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize crashlytics consent: $e');
      // Fallback to default behavior
      await setUserConsent(enabled: kReleaseMode);
    }
  }
  
  /// Set user consent for crash reporting
  Future<void> setUserConsent({required bool enabled}) async {
    try {
      await _localDb.setBoolSetting(_crashlyticsEnabledKey, enabled);
      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
      
      _logger.i(_tag, 'User ${enabled ? 'enabled' : 'disabled'} crash reporting');
      _crashlytics.log('User ${enabled ? 'enabled' : 'disabled'} crash reporting');
    } catch (e) {
      _logger.e(_tag, 'Failed to set user consent: $e');
      rethrow;
    }
  }
  
  /// Get current user consent status
  Future<bool> getUserConsent() async {
    try {
      return await _localDb.getBoolSetting(_crashlyticsEnabledKey, defaultValue: kReleaseMode);
    } catch (e) {
      _logger.e(_tag, 'Failed to get user consent: $e');
      return kReleaseMode;
    }
  }

  /// Check if user has made a consent choice
  Future<bool> hasUserMadeChoice() async {
    try {
      final value = await _localDb.getSetting(_crashlyticsEnabledKey);
      return value != null;
    } catch (e) {
      _logger.e(_tag, 'Failed to check if user made choice: $e');
      return false;
    }
  }

  /// Clear consent data (useful for testing or reset)
  Future<void> clearConsent() async {
    try {
      await _localDb.removeSetting(_crashlyticsEnabledKey);
      _logger.i(_tag, 'Crashlytics consent data cleared');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear consent data: $e');
      rethrow;
    }
  }
  
  /// Show a dialog to prompt the user for crash reporting consent
  static Future<void> showConsentDialog(BuildContext context) async {
    final manager = CrashlyticsConsentManager.create();
    
    return showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => AlertDialog(
        title: const Text('Help improve DuckBuck'),
        content: const Text(
          'Would you like to help us improve DuckBuck by automatically sending crash reports? '
          'This helps us identify and fix issues faster. '
          'No personal information is collected with these reports.\n\n'
          'You can change this setting later in the app settings.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await manager.setUserConsent(enabled: false);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('No thanks'),
          ),
          FilledButton(
            onPressed: () async {
              await manager.setUserConsent(enabled: true);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Yes, I\'ll help'),
          ),
        ],
      ),
    );
  }

  /// Show consent dialog only if user hasn't made a choice yet
  static Future<void> showConsentDialogIfNeeded(BuildContext context) async {
    final manager = CrashlyticsConsentManager.create();
    final hasChoice = await manager.hasUserMadeChoice();
    
    if (!hasChoice) {
      await showConsentDialog(context);
    }
  }
}
