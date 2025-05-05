import 'package:firebase_analytics/firebase_analytics.dart';

/// Service for handling Firebase Analytics operations
class FirebaseAnalyticsService {
  final FirebaseAnalytics _analytics;

  /// Creates a new FirebaseAnalyticsService instance
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  /// Log a custom event with parameters
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  /// Log a user login event
  Future<void> logLogin({required String loginMethod}) async {
    await _analytics.logLogin(loginMethod: loginMethod);
  }

  /// Log a user signup event
  Future<void> logSignUp({required String signUpMethod}) async {
    await _analytics.logSignUp(signUpMethod: signUpMethod);
  }

  /// Set the current screen name
  Future<void> setCurrentScreen({required String screenName}) async {
    await _analytics.setCurrentScreen(screenName: screenName);
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

  /// Get the instance of FirebaseAnalytics
  FirebaseAnalytics get instance => _analytics;
}
