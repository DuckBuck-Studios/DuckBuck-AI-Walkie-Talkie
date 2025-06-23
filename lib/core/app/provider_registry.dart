import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/settings/providers/crashlytics_consent_provider.dart';
import '../../features/auth/providers/auth_state_provider.dart'; 
import '../../features/call/providers/call_provider.dart';
import '../../features/ai_agent/providers/ai_agent_provider.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../../features/shared/providers/shared_friends_provider.dart';

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
        lazy: false, // Keep immediately available for auth checks
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
        lazy: false, // Keep immediately available for crash reporting
      ),
      
      // Call provider for handling call UI state (receiver side)
      ChangeNotifierProvider<CallProvider>(
        create: (_) => CallProvider(),
        lazy: true, // Only create when call functionality is needed
      ),
      
      // AI Agent provider for managing AI agent operations and state
      ChangeNotifierProvider<AiAgentProvider>(
        create: (_) => AiAgentProvider(),
        lazy: true, // Only create when AI agent is accessed
      ),
      
      // Call initiator provider for handling call initiation (caller side)

      
      // Settings provider for real-time user updates in settings screen
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        lazy: true, // Only create when settings screen is accessed
      ),
      
      // Shared friends provider for unified friends and relationship management
      // Replaces both RelationshipProvider and HomeProvider with a single, optimized provider
      // Use lazy initialization to improve app startup performance
      ChangeNotifierProvider<SharedFriendsProvider>(
        create: (_) => SharedFriendsProvider(),
        lazy: true, // Only create when first accessed
      ),
      
      // Add more app-wide providers here as needed
    ];
  }
}
