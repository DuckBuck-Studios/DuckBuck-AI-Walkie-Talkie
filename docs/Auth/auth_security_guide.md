# DuckBuck Authentication Security Guide

This document outlines the security practices implemented in the DuckBuck authentication system and provides guidance for maintaining security standards when modifying the authentication code.

## Table of Contents
1. [Security Design Principles](#security-design-principles)
2. [Authentication Vulnerabilities & Mitigations](#authentication-vulnerabilities--mitigations)
3. [Secure Storage Practices](#secure-storage-practices)
4. [Token Management Security](#token-management-security)
5. [Device Security Considerations](#device-security-considerations)
6. [Audit and Logging](#audit-and-logging)
7. [Security Testing Procedures](#security-testing-procedures)
8. [Security Update Procedure](#security-update-procedure)

## Security Design Principles

The DuckBuck authentication system adheres to the following security principles:

### 1. Defense in Depth
Multiple layers of security controls are implemented to protect user authentication:
- Firebase Authentication as a secure identity provider
- Secure token storage using platform-specific encryption
- Session timeout and token refresh mechanisms
- Device integrity verification

### 2. Least Privilege
- Authentication tokens have appropriate scopes limited to required functionality
- User permissions are enforced at the database level through Firebase Security Rules
- API access is restricted based on authenticated user identity

### 3. Secure by Default
- All authentication data is encrypted at rest and in transit
- Default configurations are set to the most secure options
- HTTPS is enforced for all API communications
- App automatically signs out after extended periods of inactivity

### 4. Fail Securely
- Authentication failures revert to an unauthenticated state
- Invalid tokens trigger automatic re-authentication
- Corrupted state management defaults to logged-out state
- Error handling never reveals sensitive implementation details

## Authentication Vulnerabilities & Mitigations

### 1. Account Enumeration

**Vulnerability**: Attackers could determine if a phone number is registered by observing different error messages.

**Mitigation**:
- Consistent error messages regardless of whether a phone number exists
- Rate limiting on verification attempts
- Server-side validation of phone formats before sending OTP

```dart
// Example of consistent error handling
Future<void> _handlePhoneSignIn(String phoneNumber) async {
  try {
    await _authProvider.signInWithPhone(phoneNumber);
    // Success case
  } catch (e) {
    // Generic error regardless of specific failure reason
    _showError('Verification failed. Please try again.');
    
    // Log the actual error for debugging (not shown to user)
    _logger.e(_tag, 'Phone verification error', e);
  }
}
```

### 2. Brute Force Attacks

**Vulnerability**: Attackers could attempt to guess OTP codes through repeated attempts.

**Mitigation**:
- Firebase's built-in rate limiting for SMS verification
- Maximum retry limits at the application level
- Exponential backoff for retry attempts
- OTP expiration after short timeframes (typically 60 seconds)

```dart
// Implementation of retry limits
int _otpAttempts = 0;
final int _maxOtpAttempts = 3;

Future<void> _verifyOtp(String otp) async {
  if (_otpAttempts >= _maxOtpAttempts) {
    _showError('Too many failed attempts. Please request a new code.');
    _resetPhoneVerification();
    return;
  }
  
  try {
    await _authProvider.verifyOtp(_verificationId!, otp);
    _completeAuthentication();
  } catch (e) {
    _otpAttempts++;
    _showError('Invalid verification code. Attempts left: ${_maxOtpAttempts - _otpAttempts}');
  }
}
```

### 3. Session Hijacking

**Vulnerability**: Malicious actors could intercept or steal authentication tokens.

**Mitigation**:
- Short-lived authentication tokens (60 minutes)
- Secure storage of refresh tokens
- Automatic token refresh using HTTPS
- Token invalidation on sign-out
- Device binding for authentication sessions

```dart
// Session invalidation on sign-out
Future<void> signOut() async {
  try {
    // Revoke token access on the server
    await _cancelActiveTokens();
    
    // Clear locally stored authentication data
    await _securityManager.clearCredentials();
    await PreferencesService.instance.clearUserCache();
    
    // Sign out from Firebase
    await _userRepository.signOut();
    
    // Reset local state
    _currentUser = null;
    notifyListeners();
  } catch (e) {
    _logger.e(_tag, 'Error during sign out', e);
    // Force sign out even on error
    _currentUser = null;
    notifyListeners();
    rethrow;
  }
}
```

### 4. Man-in-the-Middle Attacks

**Vulnerability**: Network traffic could be intercepted to steal credentials.

**Mitigation**:
- SSL certificate pinning for API communications
- Firebase's secure communications channel
- App Transport Security enforcement on iOS
- Network Security Configuration on Android

```xml
<!-- Android Network Security Config -->
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">firebase.googleapis.com</domain>
        <pin-set>
            <!-- Primary pin (leaf certificate) -->
            <pin digest="SHA-256">jYoTE/KICxVmNXPlhLcgJpD0FwK1sNupYdQSJg4RDos=</pin>
            <!-- Backup pin (intermediate certificate) -->
            <pin digest="SHA-256">YPtHaftLw6/0vnc2BnNKGF54xiCA28WFcccjkA4ypCM=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

> **Note on Certificate Pinning**: The primary pin is derived from the leaf certificate of the domain, while the backup pin is derived from an intermediate certificate in the same chain. The backup pin ensures the app continues to function when the leaf certificate is rotated, which happens periodically. Both pins are generated using OpenSSL commands that extract the public key hash.

### 5. Social Engineering

**Vulnerability**: Users could be tricked into providing authentication details.

**Mitigation**:
- Clear branding in all authentication screens
- Educational content about phishing
- No password collection for social authentication
- OAuth flows that don't expose credentials to the app
- App verification in Google Play and App Store

## Secure Storage Practices

### 1. Credential Storage

Authentication credentials are stored securely using platform-specific mechanisms:

**iOS**: Keychain Services with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection

**Android**: EncryptedSharedPreferences backed by Android Keystore

```dart
class SecureStorage {
  final FlutterSecureStorage _storage;
  
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
            // Require user authentication for accessing encrypted data
            authenticationRequired: true,
            // AES-GCM encryption with randomized encryption
            encryptionPadding: EncryptionPadding.pkcs7,
            keyCipherAlgorithm: KeyCipherAlgorithm.rsa_ecb_oaepsha256,
            storageCipherAlgorithm: StorageCipherAlgorithm.aes_gcm_nopadding,
          ),
          iOptions: IOSOptions(
            // Accessible only when device is unlocked
            accessibility: KeychainAccessibility.unlocked,
            // Not included in device backups
            synchronizable: false,
          ),
        );
  
  Future<void> storeSecurely(String key, String value) async {
    await _storage.write(key: key, value: value);
  }
  
  Future<String?> retrieveSecurely(String key) async {
    return await _storage.read(key: key);
  }
  
  Future<void> deleteSecurely(String key) async {
    await _storage.delete(key: key);
  }
  
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

### 2. Token Storage

Authentication tokens follow specific handling rules:

1. **ID Tokens** - Short-lived (60 min) and stored in memory only
2. **Refresh Tokens** - Stored in secure storage with encryption
3. **Session State** - Minimal information stored in preferences

```dart
class SessionManager {
  final AuthServiceInterface _auth;
  final SecureStorage _secureStorage;
  String? _cachedToken; // In-memory only, not persisted
  
  Future<String?> getAuthToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }
    
    try {
      // Get a fresh token from Firebase
      _cachedToken = await _auth.refreshIdToken();
      return _cachedToken;
    } catch (e) {
      // Token refresh failed, try to recover
      return await _recoverSession();
    }
  }
  
  Future<String?> _recoverSession() async {
    // Attempt recovery from secure storage
    final refreshToken = await _secureStorage.retrieveSecurely('auth_refresh_token');
    if (refreshToken == null) return null;
    
    try {
      // Use refresh token to get new ID token
      // Implementation depends on Firebase Auth mechanisms
      return null; // Placeholder
    } catch (e) {
      // Recovery failed, require re-authentication
      return null;
    }
  }
}
```

### 3. User Data Caching

User data is cached with appropriate security measures:

1. **Sensitive Data** - Never cached (payment info, etc.)
2. **Profile Data** - Cached with encryption
3. **Cache Invalidation** - Automatic on sign-out or token expiration
4. **Cache Timeout** - Maximum cache lifetime enforced

```dart
class PreferencesService {
  // User data cache methods
  Future<void> cacheUserData(Map<String, dynamic> userData) async {
    // Remove any sensitive fields before caching
    final Map<String, dynamic> sanitizedData = {...userData};
    _removeSensitiveFields(sanitizedData);
    
    // Store with expiration timestamp
    final dataWithExpiry = {
      'data': sanitizedData,
      'expiryTime': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
    };
    
    await _prefs.setString('cached_user_data', jsonEncode(dataWithExpiry));
  }
  
  bool isCachedUserDataValid() {
    final cachedData = _prefs.getString('cached_user_data');
    if (cachedData == null) return false;
    
    try {
      final parsed = jsonDecode(cachedData) as Map<String, dynamic>;
      final expiryTime = parsed['expiryTime'] as int;
      
      // Check if cache has expired
      return DateTime.now().millisecondsSinceEpoch < expiryTime;
    } catch (e) {
      return false;
    }
  }
  
  void _removeSensitiveFields(Map<String, dynamic> data) {
    // Remove any fields that should not be cached
    final sensitiveFields = [
      'authTokens',
      'paymentInfo',
      'recoveryEmail',
      // Add other sensitive fields here
    ];
    
    for (final field in sensitiveFields) {
      data.remove(field);
    }
  }
}
```

## Token Management Security

### 1. Token Lifecycle

Authentication tokens follow a secure lifecycle:

1. **Acquisition** - Obtained through secure Firebase authentication
2. **Storage** - ID token kept in memory, refresh token in secure storage
3. **Usage** - Sent via HTTPS headers for API requests
4. **Refresh** - Automatically refreshed before expiration
5. **Revocation** - Invalidated on sign-out or security event

### 2. Automatic Token Refresh

```dart
class SessionManager {
  // Refresh token 5 minutes before expiration (Firebase tokens last 60 minutes)
  static const _refreshInterval = Duration(minutes: 55);
  Timer? _refreshTimer;
  
  void startTokenRefreshCycle() {
    // Cancel existing timer if any
    _refreshTimer?.cancel();
    
    // Set up periodic token refresh
    _refreshTimer = Timer.periodic(_refreshInterval, (_) async {
      try {
        await _auth.refreshIdToken(forceRefresh: true);
        _logger.d(_tag, 'Auth token refreshed successfully');
      } catch (e) {
        _logger.e(_tag, 'Failed to refresh auth token', e);
        // Token refresh failed, attempt recovery
        _handleRefreshFailure();
      }
    });
  }
  
  void _handleRefreshFailure() {
    // Notify auth state provider of token refresh failure
    // This will trigger re-authentication if necessary
  }
  
  void stopTokenRefreshCycle() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
```

### 3. Token Validation

```dart
class ApiService {
  final SessionManager _sessionManager;
  
  Future<Map<String, dynamic>> makeAuthenticatedRequest(
    String endpoint, 
    {Map<String, dynamic>? data}
  ) async {
    // Get a valid token
    final token = await _sessionManager.getAuthToken();
    if (token == null) {
      throw AuthException(
        AuthErrorCodes.unauthenticated,
        'User is not authenticated',
      );
    }
    
    // Make request with token
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data ?? {}),
    );
    
    if (response.statusCode == 401) {
      // Token was rejected, force refresh
      final newToken = await _sessionManager.getAuthToken(forceRefresh: true);
      if (newToken == null) {
        throw AuthException(
          AuthErrorCodes.unauthenticated,
          'Failed to refresh authentication',
        );
      }
      
      // Retry with new token
      return makeAuthenticatedRequest(endpoint, data: data);
    }
    
    return jsonDecode(response.body);
  }
}
```

## Device Security Considerations

### 1. Root/Jailbreak Detection

The app implements basic detection for compromised devices:

```dart
class AuthSecurityManager {
  Future<bool> checkDeviceIntegrity() async {
    // Check for common signs of rooting/jailbreaking
    if (await _isDeviceRooted()) {
      _logger.w(_tag, 'Device integrity check failed - device appears to be rooted/jailbroken');
      return false;
    }
    
    return true;
  }
  
  Future<bool> _isDeviceRooted() async {
    if (Platform.isAndroid) {
      return _checkAndroidRoot();
    } else if (Platform.isIOS) {
      return _checkIosJailbreak();
    }
    return false;
  }
  
  Future<bool> _checkAndroidRoot() async {
    // Check for su binary
    const paths = [
      '/system/bin/su',
      '/system/xbin/su',
      '/sbin/su',
      '/system/su',
      '/system/bin/.ext/.su',
    ];
    
    for (final path in paths) {
      if (await File(path).exists()) {
        return true;
      }
    }
    
    // Check for Magisk, SuperSU, etc.
    const packages = [
      'com.topjohnwu.magisk',
      'eu.chainfire.supersu',
      'com.noshufou.android.su',
      'com.koushikdutta.superuser',
    ];
    
    // Implementation would use package manager to check
    return false; // Simplified for documentation
  }
  
  Future<bool> _checkIosJailbreak() async {
    // Check for common jailbreak files
    const paths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/usr/bin/ssh',
    ];
    
    for (final path in paths) {
      if (await File(path).exists()) {
        return true;
      }
    }
    
    // Check if app can write to system locations
    try {
      const testFile = '/private/jailbreak_test';
      await File(testFile).writeAsString('test');
      await File(testFile).delete();
      // If we can write to private, device is jailbroken
      return true;
    } catch (e) {
      // Expected to fail on non-jailbroken devices
    }
    
    return false;
  }
}
```

### 2. Biometric Authentication Integration

For high-security operations, the app supports biometric authentication:

```dart
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics && 
             await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> authenticateWithBiometrics({String reason = 'Verify your identity'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      _logger.e(_tag, 'Biometric authentication error', e);
      return false;
    }
  }
}
```

### 3. App-level Security

```dart
void main() async {
  // Prevent screenshots in release mode
  if (kReleaseMode) {
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }
  
  // Initialize Firebase with App Check
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up Firebase App Check
  await FirebaseAppCheck.instance.activate(
    // Use Debug Provider for development
    webProvider: kDebugMode ? ReCaptchaV3Provider('debug-token') : ReCaptchaV3Provider('site-key'),
    // Use App Attest for iOS and Play Integrity for Android in production
    appleProvider: AppleProvider.appAttest,
    androidProvider: AndroidProvider.playIntegrity,
  );
  
  runApp(const MyApp());
}
```

## Audit and Logging

### 1. Authentication Event Logging

All authentication events are logged for security monitoring:

```dart
class AuthStateProvider extends ChangeNotifier {
  Future<void> signInWithGoogle() async {
    _clearError();
    _setLoading(true);
    
    try {
      _logAuthAttempt('google');
      final (user, isNewUser) = await _userRepository.signInWithGoogle();
      _logAuthSuccess('google', user.uid, isNewUser);
      _currentUser = user;
    } catch (e) {
      _logAuthFailure('google', e);
      _handleAuthError(e);
    } finally {
      _setLoading(false);
    }
  }
  
  void _logAuthAttempt(String method) {
    _analytics.logEvent(
      name: 'auth_attempt',
      parameters: {
        'auth_method': method,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _logger.i(_tag, 'Authentication attempt with $method');
  }
  
  void _logAuthSuccess(String method, String uid, bool isNewUser) {
    _analytics.logLogin(loginMethod: method);
    _analytics.logEvent(
      name: 'auth_success',
      parameters: {
        'auth_method': method,
        'user_id': uid, // Firebase Analytics automatically strips PII
        'is_new_user': isNewUser,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _logger.i(_tag, 'Authentication success with $method (${isNewUser ? 'new user' : 'existing user'})');
  }
  
  void _logAuthFailure(String method, dynamic error) {
    String errorCode = 'unknown';
    if (error is AuthException) {
      errorCode = error.code;
    }
    
    _analytics.logEvent(
      name: 'auth_failure',
      parameters: {
        'auth_method': method,
        'error_code': errorCode,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _logger.e(_tag, 'Authentication failure with $method: $errorCode', error);
  }
}
```

### 2. Security Anomaly Detection

The system monitors for suspicious authentication activity:

```dart
class SecurityMonitor {
  final FirebaseAnalyticsService _analytics;
  final LoggerService _logger;
  
  Future<void> checkForAnomalies(UserModel user) async {
    try {
      // Check for unusual login patterns
      await _checkLoginLocation(user);
      await _checkLoginFrequency(user);
      await _checkMultiDeviceLogins(user);
    } catch (e) {
      _logger.e(_tag, 'Error during security anomaly check', e);
    }
  }
  
  Future<void> _checkLoginLocation(UserModel user) async {
    // Implementation would check if user is logging in from a new location
    // compared to their usual pattern
    
    // If anomaly detected, log it
    _logSecurityAnomaly(
      user.uid, 
      'unusual_location', 
      'Login from new location detected'
    );
  }
  
  void _logSecurityAnomaly(String uid, String type, String description) {
    _analytics.logEvent(
      name: 'security_anomaly',
      parameters: {
        'user_id': uid,
        'anomaly_type': type,
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _logger.w(_tag, 'Security anomaly ($type): $description for user $uid');
  }
}
```

### 3. Centralized Exception Tracking

Authentication exceptions are tracked in Firebase Crashlytics:

```dart
class FirebaseCrashlyticsService {
  final FirebaseCrashlytics _crashlytics;
  
  void recordAuthError(dynamic error, StackTrace stackTrace, {String? reason}) {
    // Set custom keys for authentication errors
    if (error is AuthException) {
      _crashlytics.setCustomKey('auth_error_code', error.code);
    }
    
    // Log non-fatal exception
    _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason ?? 'Authentication error',
      // Mark as non-fatal
      fatal: false,
      // List of error types that should be reported
      printDetails: !_isExpectedError(error),
    );
  }
  
  bool _isExpectedError(dynamic error) {
    // Don't print details for these common expected errors
    if (error is AuthException) {
      return [
        AuthErrorCodes.userCancelled,
        AuthErrorCodes.networkError,
        AuthErrorCodes.invalidVerificationCode,
      ].contains(error.code);
    }
    return false;
  }
}
```

## Security Testing Procedures

### 1. Authentication Flow Testing

**Manual Test Script 1: Social Authentication**
1. Launch app in clean state
2. Navigate to authentication screen
3. Attempt Google sign-in
4. Verify proper authentication success/failure handling
5. Sign out
6. Repeat with Apple sign-in (on iOS)
7. Verify proper authentication success/failure handling

**Manual Test Script 2: Phone Authentication**
1. Launch app in clean state
2. Navigate to authentication screen
3. Select phone authentication
4. Enter valid phone number
5. Verify OTP is sent
6. Enter correct OTP
7. Verify authentication succeeds
8. Sign out
9. Repeat with invalid OTP
10. Verify proper error handling and retry limits

### 2. Penetration Testing Checklist

1. **Token Security**
   - Attempt to extract tokens from app storage
   - Test token expiration handling
   - Test session persistence across app restarts

2. **Authentication Bypass**
   - Attempt to bypass authentication screens
   - Test deep link handling when not authenticated
   - Test API access without valid tokens

3. **Input Validation**
   - Test SQL injection in phone number field
   - Test XSS attacks in profile data
   - Test overflow attacks in input fields

4. **Session Management**
   - Test concurrent sessions on multiple devices
   - Test session handling after password change
   - Test background/foreground transition security

### 3. Automated Security Tests

```dart
void main() {
  group('AuthSecurityManager Tests', () {
    late AuthSecurityManager securityManager;
    late MockSecureStorage mockStorage;
    
    setUp(() {
      mockStorage = MockSecureStorage();
      securityManager = AuthSecurityManager(storage: mockStorage);
    });
    
    test('secure credential storage encrypts data', () async {
      // Arrange
      const testCredential = '{"type":"google","token":"test-token"}';
      when(mockStorage.storeSecurely(any, any))
          .thenAnswer((_) => Future.value());
      
      // Act
      await securityManager.storeCredentialSecurely('google', testCredential);
      
      // Assert
      verify(mockStorage.storeSecurely(
        'auth_credential_google',
        argThat(isNot(equals(testCredential))), // Verify it's not stored in plain text
      )).called(1);
    });
    
    test('detects corrupted credential data', () async {
      // Arrange
      when(mockStorage.retrieveSecurely('auth_credential_google'))
          .thenAnswer((_) => Future.value('corrupted-data'));
      
      // Act & Assert
      expect(
        () => securityManager.retrieveSecureCredential('google'),
        throwsA(isA<SecurityException>()),
      );
    });
  });
}
```

## Security Update Procedure

### 1. Vulnerability Assessment

When a security vulnerability is identified:

1. **Severity Assessment**
   - Critical: Immediate user data exposure or account takeover
   - High: Potential for data exposure with specific conditions
   - Medium: Limited data exposure or denial of service
   - Low: Minor issues with minimal impact

2. **Impact Analysis**
   - Affected users quantification
   - Data exposure assessment
   - Exploitation difficulty evaluation

3. **Containment Strategy**
   - Server-side blocks if applicable
   - Feature disablement if necessary
   - Temporary authentication restrictions if needed

### 2. Security Patch Process

1. **Development Phase**
   - Create a separate security branch
   - Implement fix with minimal changes
   - Add tests that verify vulnerability is fixed
   - Document changes in security log

2. **Testing Phase**
   - Verify fix addresses vulnerability
   - Ensure no regression in authentication flows
   - Test on all supported platforms
   - Test upgrade path from vulnerable versions

3. **Deployment Phase**
   - Expedited review process for security fixes
   - Force update for critical vulnerabilities
   - Staged rollout with monitoring
   - Post-deployment verification

### 3. Security Incident Response

For active security incidents:

1. **Detection & Analysis**
   - Monitor authentication anomalies
   - Track unusual error rates
   - Analyze logs for attack patterns

2. **Containment & Remediation**
   - Revoke compromised tokens
   - Force re-authentication for affected users
   - Deploy emergency fixes

3. **Recovery & Post-Incident**
   - Restore normal authentication operations
   - Notify affected users if necessary
   - Document incident timeline and response
   - Update security procedures as needed

---

This security guide provides a comprehensive overview of the security measures implemented in the DuckBuck authentication system. Following these practices when modifying authentication code will help maintain the security posture of the application.
