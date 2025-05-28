import 'package:flutter/services.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';

/// Service to handle application security features
/// by interacting with native security implementations
class AppSecurityService {
  static const String _tag = 'AppSecurity';
  
  // Singleton instance
  static final AppSecurityService _instance = AppSecurityService._internal();
  
  // Method channel to communicate with native code
  final MethodChannel _channel = const MethodChannel('com.duckbuck.app/security');
  
  // Factory constructor to return singleton instance
  factory AppSecurityService() => _instance;
  
  // Private constructor
  AppSecurityService._internal();
  
  // Get logger service from service locator
  LoggerService get _logger => serviceLocator<LoggerService>();
  
  /// Initialize the security service
  Future<bool> initialize() async {
    try {
      // Perform security checks
      final securityPassed = await performSecurityChecks();
      _logger.i(_tag, '🔒 Initialization ${securityPassed ? 'passed' : 'failed'}');
      return securityPassed;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to initialize security service', e);
      return false;
    }
  }
  
  /// Perform all security checks
  /// Returns true if all checks pass, false otherwise
  Future<bool> performSecurityChecks() async {
    try {
      // Check both dart.vm.product and ENVIRONMENT to determine if in development mode
      final bool isDebug = const bool.fromEnvironment('dart.vm.product') == false;
      final String environment = const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
      final bool isDevelopment = isDebug || environment.toLowerCase() == 'development';
      
      _logger.d(_tag, 'Security checks running in ${isDevelopment ? 'DEVELOPMENT' : 'PRODUCTION'} mode');
      
      final result = await _channel.invokeMethod<bool>('performSecurityChecks', {
        'isDevelopment': isDevelopment,
      });
      
      if (result == true) {
        _logger.d(_tag, '✓ Security checks completed successfully');
      } else {
        _logger.w(_tag, '⚠️ Some security checks failed');
        
        // If in debug mode, log additional information about the signature verification
        if (isDebug) {
          try {
            final signatureValid = await _channel.invokeMethod<bool>('verifyAppSignature') ?? false;
            _logger.d(_tag, 'Debug mode - App signature verification: ${signatureValid ? 'passed' : 'failed'}');
          } catch (e) {
            // Just log and continue
            _logger.d(_tag, 'Could not verify app signature separately: $e');
          }
        }
      }
      return result ?? false;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to perform security checks', e);
      return false;
    }
  }
  
  /// Enable screen capture protection for security-sensitive screens
  Future<bool> enableScreenCaptureProtection() async {
    try {
      final result = await _channel.invokeMethod<bool>('enableScreenCaptureProtection');
      final success = result ?? false;
      if (success) {
        _logger.i(_tag, '🔒 Screen capture protection enabled');
      } else {
        _logger.w(_tag, '⚠️ Failed to enable screen capture protection');
      }
      return success;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to enable screen capture protection', e);
      return false;
    }
  }
  
  /// Disable screen capture protection
  Future<bool> disableScreenCaptureProtection() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableScreenCaptureProtection');
      final success = result ?? false;
      if (success) {
        _logger.d(_tag, 'Screen capture protection disabled');
      }
      return success;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to disable screen capture protection', e);
      return false;
    }
  }
  
  /// Encrypt a string using AES encryption
  Future<String?> encryptString(String text, {String key = 'default_key'}) async {
    try {
      final result = await _channel.invokeMethod<String>('encryptString', {
        'text': text,
        'key': key,
      });
      return result;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to encrypt string', e);
      return null;
    }
  }
  
  /// Decrypt a string using AES encryption
  Future<String?> decryptString(String encryptedText, {String key = 'default_key'}) async {
    try {
      final result = await _channel.invokeMethod<String>('decryptString', {
        'text': encryptedText,
        'key': key,
      });
      return result;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to decrypt string', e);
      return null;
    }
  }
  
  /// Store data securely using encrypted storage
  Future<bool> storeSecureData(String key, String value) async {
    try {
      final result = await _channel.invokeMethod<bool>('storeSecureData', {
        'key': key,
        'value': value,
      });
      return result ?? false;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to store secure data', e);
      return false;
    }
  }
  
  /// Get data from secure storage
  Future<String?> getSecureData(String key, {String defaultValue = ''}) async {
    try {
      final result = await _channel.invokeMethod<String>('getSecureData', {
        'key': key,
        'defaultValue': defaultValue,
      });
      return result;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to get secure data', e);
      return defaultValue;
    }
  }
  
  /// Remove data from secure storage
  Future<bool> removeSecureData(String key) async {
    try {
      final result = await _channel.invokeMethod<bool>('removeSecureData', {
        'key': key,
      });
      return result ?? false;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to remove secure data', e);
      return false;
    }
  }
  
  /// Clear all data from secure storage
  Future<bool> clearAllSecureData() async {
    try {
      final result = await _channel.invokeMethod<bool>('clearAllSecureData');
      return result ?? false;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to clear all secure data', e);
      return false;
    }
  }
  
  /// Directly verify the app signature 
  /// Useful for debugging signature issues in development
  Future<String?> verifyAppSignatureWithDetails() async {
    try {
      final bool isDebug = const bool.fromEnvironment('dart.vm.product') == false;
      if (!isDebug) {
        _logger.w(_tag, 'App signature details should only be checked in debug mode');
        return null;
      }
      
      // Get actual signature hash
      final signature = await _channel.invokeMethod<String>('getAppSignatureHash');
      
      // Check if it's valid
      final isValid = await _channel.invokeMethod<bool>('verifyAppSignature') ?? false;
      
      final status = isValid ? 'valid ✓' : 'invalid ✗';
      final result = 'App signature ($status): $signature';
      
      _logger.d(_tag, result);
      return result;
    } catch (e) {
      _logger.e(_tag, '❌ Failed to verify app signature details', e);
      return null;
    }
  }
}
