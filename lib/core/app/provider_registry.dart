import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/settings/providers/crashlytics_consent_provider.dart';
import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/friends/providers/relationship_provider.dart';
import '../../features/call/providers/call_provider.dart';
import '../../features/settings/providers/settings_provider.dart';

/// Manages the app's providers in a centralized location
///
/// This makes it easier to add/remove providers and ensures
/// a consistent way to access them throughout the app
class ProviderRegistry {
  /// Get the list of global providers for the app
  /// 
  /// These providers are available throughout the entire app
  static List<SingleChildWidget> getProviders() {
    return [
      // Authentication state provider
      ChangeNotifierProvider<AuthStateProvider>(
        create: (_) => AuthStateProvider(),
      ),
      
      // Crashlytics consent provider
      ChangeNotifierProvider<CrashlyticsConsentProvider>(
        create: (_) {
          final provider = CrashlyticsConsentProvider();
          // Initialize provider immediately and synchronously
          // to ensure it's ready when the UI is built
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await provider.initialize();
          });
          return provider;
        },
      ),
      
      // Relationship provider (friends and relationships management)
      ChangeNotifierProvider<RelationshipProvider>(
        create: (_) => RelationshipProvider(),
      ),
      
      // Call provider for handling call UI state
      ChangeNotifierProvider<CallProvider>(
        create: (_) => CallProvider(),
      ),
      
      // Settings provider for real-time user updates in settings screen
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      
      // Add more app-wide providers here as needed
    ];
  }
}
