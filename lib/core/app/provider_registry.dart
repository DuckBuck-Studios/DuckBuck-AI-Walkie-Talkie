import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/settings/providers/crashlytics_consent_provider.dart';
import '../../features/auth/providers/auth_state_provider.dart'; 
import '../../features/call/providers/call_provider.dart';
import '../../features/call/providers/call_initiator_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/friends/providers/relationship_provider.dart';
import '../../features/home/providers/home_provider.dart';

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
      
      // Call provider for handling call UI state (receiver side)
      ChangeNotifierProvider<CallProvider>(
        create: (_) => CallProvider(),
      ),
      
      // Call initiator provider for handling call initiation (caller side)
      ChangeNotifierProvider<CallInitiatorProvider>(
        create: (_) => CallInitiatorProvider(),
      ),
      
      // Settings provider for real-time user updates in settings screen
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      
      // Relationship provider for friends, blocking, and friend requests
      ChangeNotifierProvider<RelationshipProvider>(
        create: (_) {
          final provider = RelationshipProvider();
          // Initialize provider with real-time streams
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await provider.initialize();
          });
          return provider;
        },
      ),
      
      // Home provider for managing home screen state
      // Uses RelationshipProvider through service locator and listener pattern
      ChangeNotifierProvider<HomeProvider>(
        create: (_) {
          final provider = HomeProvider();
          // Initialize provider which will ensure RelationshipProvider is ready
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await provider.initialize();
          });
          return provider;
        },
      ),
      
      // Add more app-wide providers here as needed
    ];
  }
}
