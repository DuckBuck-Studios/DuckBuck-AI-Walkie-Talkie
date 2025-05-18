import 'package:flutter/material.dart';
import 'app_security_service.dart';

/// A mixin that adds security features to screens containing sensitive information
/// 
/// Usage:
/// ```dart
/// class MySecureScreen extends StatefulWidget {
///   @override
///   _MySecureScreenState createState() => _MySecureScreenState();
/// }
/// 
/// class _MySecureScreenState extends State<MySecureScreen> with SecureScreenMixin {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Secure Screen')),
///       body: Center(child: Text('This screen is protected from screenshots')),
///     );
///   }
/// }
/// ```
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  final AppSecurityService _securityService = AppSecurityService();
  bool _securityInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeSecurity();
  }
  
  @override
  void dispose() {
    _cleanupSecurity();
    super.dispose();
  }
  
  /// Initialize all security features for this screen
  Future<void> _initializeSecurity() async {
    try {
      // Enable screenshot protection
      final screenshotProtected = await _securityService.enableScreenCaptureProtection();
      
      // Perform security checks to ensure the app is secure
      final securityPassed = await _securityService.performSecurityChecks();
      
      _securityInitialized = screenshotProtected && securityPassed;
      
      if (!_securityInitialized) {
        debugPrint('⚠️ SECURITY WARNING: Could not fully initialize security features');
      }
    } catch (e) {
      debugPrint('❌ SECURITY ERROR: Error initializing security features - $e');
    }
  }
  
  /// Clean up security features when screen is closed
  Future<void> _cleanupSecurity() async {
    try {
      await _securityService.disableScreenCaptureProtection();
    } catch (e) {
      debugPrint('❌ SECURITY ERROR: Error cleaning up security features - $e');
    }
  }
  
  /// Encrypt sensitive data before storing it
  Future<String?> encryptSensitiveData(String data) async {
    try {
      return await _securityService.encryptString(data);
    } catch (e) {
      debugPrint('❌ SECURITY ERROR: Error encrypting sensitive data - $e');
      return null;
    }
  }
  
  /// Decrypt sensitive data
  Future<String?> decryptSensitiveData(String encryptedData) async {
    try {
      return await _securityService.decryptString(encryptedData);
    } catch (e) {
      debugPrint('❌ SECURITY ERROR: Error decrypting sensitive data - $e');
      return null;
    }
  }
  
  /// Store sensitive data securely
  Future<bool> storeSecureData(String key, String data) async {
    try {
      // First encrypt the data
      final encryptedData = await encryptSensitiveData(data);
      if (encryptedData == null) return false;
      
      // Then store it securely
      return await _securityService.storeSecureData(key, encryptedData);
    } catch (e) {
      debugPrint('❌ SECURITY ERROR: Error storing secure data - $e');
      return false;
    }
  }
  
  /// Retrieve sensitive data securely
  Future<String?> retrieveSecureData(String key) async {
    try {
      // First get the encrypted data
      final encryptedData = await _securityService.getSecureData(key);
      if (encryptedData == null || encryptedData.isEmpty) return null;
      
      // Then decrypt it
      return await decryptSensitiveData(encryptedData);
    } catch (e) {
      debugPrint('❌ SECURITY ERROR: Error retrieving secure data - $e');
      return null;
    }
  }
}
