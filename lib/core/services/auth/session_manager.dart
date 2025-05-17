import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manager for handling user session timeouts and activity tracking
///
/// Provides functionality to start, track, and manage user sessions with
/// configurable timeout durations. Can be integrated with authentication
/// flows to enforce security timeout policies.
class SessionManager {
  // Default session timeout duration (30 minutes)
  final Duration _sessionTimeout;
  
  // Preferences keys
  static const String _lastActivityKey = 'last_activity_timestamp';
  static const String _sessionTimeoutSecondsKey = 'session_timeout_seconds';
  
  // Internal state
  DateTime? _lastActivity;
  Timer? _sessionTimer;
  final VoidCallback _onSessionExpired;
  final SharedPreferences _prefs;
  bool _isTimerRunning = false;

  /// Creates a new SessionManager with the provided timeout duration and callback
  ///
  /// [onSessionExpired] will be called when the session times out
  /// [sessionTimeoutSeconds] defines how long (in seconds) a session can be inactive
  /// before timing out. Defaults to 30 minutes.
  SessionManager({
    required VoidCallback onSessionExpired,
    required SharedPreferences prefs,
    int sessionTimeoutSeconds = 1800, // 30 minutes default
  }) : _onSessionExpired = onSessionExpired,
       _prefs = prefs,
       _sessionTimeout = Duration(seconds: sessionTimeoutSeconds);
  
  /// Factory constructor to create a SessionManager with SharedPreferences
  static Future<SessionManager> create({
    required VoidCallback onSessionExpired,
    int sessionTimeoutSeconds = 1800,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Load timeout from preferences if available, otherwise use the provided value
    final storedTimeout = prefs.getInt(_sessionTimeoutSecondsKey);
    final timeout = storedTimeout ?? sessionTimeoutSeconds;
    
    return SessionManager(
      onSessionExpired: onSessionExpired,
      prefs: prefs,
      sessionTimeoutSeconds: timeout,
    );
  }
  
  /// Start the session timer
  /// This will begin tracking user activity and will trigger the timeout
  /// callback if the session becomes inactive for the defined duration
  void startSessionTimer() {
    _lastActivity = DateTime.now();
    _persistLastActivity();
    _sessionTimer?.cancel();
    _isTimerRunning = true;
    
    _sessionTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      _checkSession();
    });
  }
  
  /// Update the timestamp of the last user activity
  /// This should be called whenever the user interacts with the app
  void updateActivity() {
    _lastActivity = DateTime.now();
    _persistLastActivity();
  }
  
  /// Clear the current session and stop the timer
  void clearSession() {
    _sessionTimer?.cancel();
    _isTimerRunning = false;
    _lastActivity = null;
    _prefs.remove(_lastActivityKey);
  }
  
  /// Check if the session has timed out based on last activity
  void _checkSession() {
    if (_lastActivity == null) return;
    
    final now = DateTime.now();
    final difference = now.difference(_lastActivity!);
    
    if (difference >= _sessionTimeout) {
      _sessionTimer?.cancel();
      _isTimerRunning = false;
      _onSessionExpired();
    }
  }
  
  /// Save the last activity timestamp to SharedPreferences
  void _persistLastActivity() {
    if (_lastActivity != null) {
      _prefs.setString(_lastActivityKey, _lastActivity!.toIso8601String());
    }
  }
  
  /// Change the session timeout duration
  Future<void> updateSessionTimeout(int seconds) async {
    await _prefs.setInt(_sessionTimeoutSecondsKey, seconds);
    
    // Restart the timer with the new duration
    if (_isTimerRunning) {
      _sessionTimer?.cancel();
      startSessionTimer();
    }
  }
  
  /// Load the last activity from SharedPreferences
  /// Returns true if a recent session was found that hasn't expired
  Future<bool> restoreSession() async {
    final lastActivityStr = _prefs.getString(_lastActivityKey);
    if (lastActivityStr == null) return false;
    
    try {
      _lastActivity = DateTime.parse(lastActivityStr);
      final now = DateTime.now();
      final difference = now.difference(_lastActivity!);
      
      if (difference < _sessionTimeout) {
        // Session is still valid
        startSessionTimer();
        return true;
      } else {
        // Session has expired
        clearSession();
        return false;
      }
    } catch (e) {
      clearSession();
      return false;
    }
  }
  
  /// Check if the session is currently active
  bool get isSessionActive => _isTimerRunning;
  
  /// Get the current remaining time before session timeout
  Duration get remainingTime {
    if (_lastActivity == null) return Duration.zero;
    
    final now = DateTime.now();
    final elapsedSinceLastActivity = now.difference(_lastActivity!);
    final remaining = _sessionTimeout - elapsedSinceLastActivity;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
