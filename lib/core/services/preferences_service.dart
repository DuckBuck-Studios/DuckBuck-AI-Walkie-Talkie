import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage shared preferences for app-wide settings and state
class PreferencesService {
  static final PreferencesService instance = PreferencesService._();
  late SharedPreferences _prefs;

  // Keys for preferences
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _hasSeenWelcomeKey = 'has_seen_welcome';
  static const String _currentOnboardingStepKey = 'current_onboarding_step';
  static const String _passwordlessEmailKey = 'passwordless_email';

  PreferencesService._();

  /// Initialize the preferences service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Gets whether a user is logged in
  bool get isLoggedIn => _prefs.getBool(_isLoggedInKey) ?? false;

  /// Sets the logged in state
  Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool(_isLoggedInKey, value);
  }

  // --- Passwordless Email Sign-in ---

  /// Gets the email stored for passwordless sign-in
  String? getEmailForPasswordlessSignIn() =>
      _prefs.getString(_passwordlessEmailKey);

  /// Sets the email for passwordless sign-in
  Future<void> setEmailForPasswordlessSignIn(String email) async {
    await _prefs.setString(_passwordlessEmailKey, email);
  }

  /// Clears the email for passwordless sign-in
  Future<void> clearEmailForPasswordlessSignIn() async {
    await _prefs.remove(_passwordlessEmailKey);
  }

  // --- Onboarding state ---

  // Check if user has completed onboarding
  bool get hasCompletedOnboarding =>
      _prefs.getBool(_hasCompletedOnboardingKey) ?? false;

  // Set onboarding as completed
  Future<void> setOnboardingComplete(bool completed) async {
    await _prefs.setBool(_hasCompletedOnboardingKey, completed);
  }

  // Get the current onboarding step (0-based index)
  int get currentOnboardingStep =>
      _prefs.getInt(_currentOnboardingStepKey) ?? 0;

  // Save the current onboarding step
  Future<void> setCurrentOnboardingStep(int step) async {
    await _prefs.setInt(_currentOnboardingStepKey, step);
  }

  // --- Welcome screen state ---

  // Check if user has seen the welcome screen
  bool get hasSeenWelcome => _prefs.getBool(_hasSeenWelcomeKey) ?? false;

  // Set welcome screen as seen
  Future<void> setWelcomeSeen(bool seen) async {
    await _prefs.setBool(_hasSeenWelcomeKey, seen);
  }

  // --- Reset all preferences ---

  /// Clear all preferences (used during logout)
  Future<void> clearAll() async {
    try {
      // Define the keys to reset with their default values
      final Map<String, dynamic> defaultValues = {
        _isLoggedInKey: false,
        _hasCompletedOnboardingKey: false,
        _currentOnboardingStepKey: 0,
        // Maintain welcome screen as seen to avoid showing it to returning users
        _hasSeenWelcomeKey: _prefs.getBool(_hasSeenWelcomeKey) ?? false,
      };

      // Clear email for passwordless sign-in completely
      await _prefs.remove(_passwordlessEmailKey);
      
      // Apply default values in a batch
      for (final entry in defaultValues.entries) {
        final key = entry.key;
        final value = entry.value;
        
        if (value is bool) {
          await _prefs.setBool(key, value);
        } else if (value is int) {
          await _prefs.setInt(key, value);
        } else if (value is String) {
          await _prefs.setString(key, value);
        }
      }
      
      debugPrint('All auth-related preferences have been reset to defaults');
    } catch (e) {
      debugPrint('Error while clearing preferences: $e');
      // Attempt a more aggressive clear if the standard approach fails
      try {
        final keysToRemove = [
          _isLoggedInKey,
          _hasCompletedOnboardingKey,
          _currentOnboardingStepKey,
          _passwordlessEmailKey
        ];
        
        for (final key in keysToRemove) {
          await _prefs.remove(key);
        }
        
        // Always set logged in to false as a minimum fallback
        await _prefs.setBool(_isLoggedInKey, false);
        
        debugPrint('Preferences cleared using fallback method');
      } catch (fallbackError) {
        debugPrint('Critical error clearing preferences: $fallbackError');
      }
    }
  }
}
