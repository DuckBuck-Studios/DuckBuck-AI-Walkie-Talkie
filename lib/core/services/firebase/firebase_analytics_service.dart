import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Analytics operations
/// 
/// Provides methods for tracking user interactions, authentication events, 
/// screen navigation, and other analytics data
class FirebaseAnalyticsService {
  final FirebaseAnalytics _analytics;
  
  // Constants for analytics event names
  static const String _eventAuthAttempt = 'auth_attempt';
  static const String _eventAuthSuccess = 'auth_success';
  static const String _eventAuthFailure = 'auth_failure';
  static const String _eventPhoneVerification = 'phone_verification';
  static const String _eventOtpEntered = 'otp_entered';

  /// Creates a new FirebaseAnalyticsService instance
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  /// Log a custom event with parameters
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    // Validate event name (1-40 characters)
    String eventName = name;
    if (eventName.length > 40) {
      debugPrint('WARNING: Firebase Analytics event name too long (max 40 chars): $eventName');
      eventName = eventName.substring(0, 40);
    }
    
    // Sanitize parameters if they exist
    Map<String, Object>? sanitizedParams;
    if (parameters != null) {
      sanitizedParams = {};
      parameters.forEach((key, value) {
        // Check key length (max 40 chars)
        String sanitizedKey = key;
        if (key.length > 40) {
          debugPrint('WARNING: Firebase Analytics param key too long (max 40 chars): $key');
          sanitizedKey = key.substring(0, 40);
        }
        
        // Check value type and sanitize if needed
        Object sanitizedValue;
        if (value is String) {
          if (value.length > 100) {
            debugPrint('WARNING: Firebase Analytics string param value too long (max 100 chars): $key');
            sanitizedValue = value.substring(0, 100);
          } else {
            sanitizedValue = value;
          }
        } else if (value is num || value is bool) {
          sanitizedValue = value;
        } else {
          // Convert to string for unsupported types
          debugPrint('WARNING: Firebase Analytics param value type not supported: ${value.runtimeType} for $key');
          String strValue = value.toString();
          if (strValue.length > 100) {
            strValue = strValue.substring(0, 100);
          }
          sanitizedValue = strValue;
        }
        
        sanitizedParams![sanitizedKey] = sanitizedValue;
      });
    }

    try {
      await _analytics.logEvent(
        name: eventName, 
        parameters: sanitizedParams,
      );
    } catch (e) {
      debugPrint('ERROR logging Firebase Analytics event: $e');
    }
  }

  /// Log a user login event
  Future<void> logLogin({required String loginMethod}) async {
    await _analytics.logLogin(loginMethod: loginMethod);
  }

  /// Log a user signup event
  Future<void> logSignUp({required String signUpMethod}) async {
    await _analytics.logSignUp(signUpMethod: signUpMethod);
  }

  /// Log screen view (replaces deprecated setCurrentScreen)
  Future<void> logScreenView({required String screenName, String screenClass = 'Flutter'}) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  /// Set user properties
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  /// Set user ID for analytics tracking
  Future<void> setUserId({required String userId}) async {
    await _analytics.setUserId(id: userId);
  }

  /// Log app open event
  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  /// Reset analytics data
  Future<void> resetAnalyticsData() async {
    await _analytics.resetAnalyticsData();
  }
  
  /// Log authentication attempt
  Future<void> logAuthAttempt({
    required String authMethod,
    Map<String, Object>? additionalParams,
  }) async {
    final params = <String, Object>{
      'auth_method': authMethod,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }
    
    await _analytics.logEvent(
      name: _eventAuthAttempt,
      parameters: params,
    );
  }
  
  /// Log authentication success
  Future<void> logAuthSuccess({
    required String authMethod,
    required String userId,
    bool isNewUser = false,
  }) async {
    await _analytics.logEvent(
      name: _eventAuthSuccess,
      parameters: {
        'auth_method': authMethod,
        'user_id': userId,
        'is_new_user': isNewUser ? '1' : '0', // Convert boolean to string
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Log authentication failure
  Future<void> logAuthFailure({
    required String authMethod,
    required String reason,
    String? errorCode,
  }) async {
    final Map<String, Object> params = {
      'auth_method': authMethod,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (errorCode != null) {
      params['error_code'] = errorCode;
    }
    
    await _analytics.logEvent(
      name: _eventAuthFailure,
      parameters: params,
    );
  }
  
  /// Log phone verification initiation
  Future<void> logPhoneVerificationStarted({
    required String phoneNumber,
    String? countryCode,
  }) async {
    final Map<String, Object> params = {
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (countryCode != null) {
      params['country_code'] = countryCode;
    }
    
    // Don't log the full phone number for privacy reasons
    if (phoneNumber.length > 4) {
      params['phone_suffix'] = phoneNumber.substring(phoneNumber.length - 4);
    }
    
    await _analytics.logEvent(
      name: _eventPhoneVerification,
      parameters: params,
    );
  }
  
  /// Log OTP entered
  Future<void> logOtpEntered({
    required bool isSuccessful,
    bool isAutoFilled = false,
  }) async {
    await _analytics.logEvent(
      name: _eventOtpEntered,
      parameters: {
        'is_successful': isSuccessful ? '1' : '0',  // Convert to string value
        'is_auto_filled': isAutoFilled ? '1' : '0',  // Convert to string value
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get the instance of FirebaseAnalytics
  FirebaseAnalytics get instance => _analytics;
}
