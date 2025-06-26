import 'package:flutter/widgets.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';
import 'ai_agent_service.dart';

/// Service for handling app lifecycle events and AI agent background management
class AiAgentLifecycleService with WidgetsBindingObserver {
  final LoggerService _logger;
  final AiAgentService _aiAgentService;
  
  static const String _tag = 'AI_AGENT_LIFECYCLE';
  
  // Singleton instance
  static AiAgentLifecycleService? _instance;
  static AiAgentLifecycleService get instance {
    return _instance ??= AiAgentLifecycleService._();
  }
  
  AiAgentLifecycleService._() : 
    _logger = serviceLocator<LoggerService>(),
    _aiAgentService = serviceLocator<AiAgentService>();
  
  bool _isInitialized = false;
  
  /// Initialize the lifecycle service
  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      _logger.i(_tag, '✅ AI agent lifecycle service initialized');
    }
  }
  
  /// Dispose the lifecycle service
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      _logger.i(_tag, '🗑️ AI agent lifecycle service disposed');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    _logger.d(_tag, '📱 App lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }
  
  /// Handle app resumed (foreground)
  void _handleAppResumed() {
    _logger.i(_tag, '📱 App resumed - notifying Android');
    
    // Notify Android that app is in foreground
    _aiAgentService.onAppForegrounded().then((result) {
      if (result) {
        _logger.d(_tag, '✅ Android notified of app foreground state');
      } else {
        _logger.w(_tag, '⚠️ Failed to notify Android of app foreground state');
      }
    }).catchError((error) {
      _logger.e(_tag, '❌ Error notifying Android of app foreground: $error');
    });
  }
  
  /// Handle app paused (background)
  void _handleAppPaused() {
    _logger.i(_tag, '📱 App paused - notifying Android');
    
    // Notify Android that app is in background
    _aiAgentService.onAppBackgrounded().then((notificationShown) {
      if (notificationShown) {
        _logger.i(_tag, '✅ AI agent notification shown for background operation');
      } else {
        _logger.d(_tag, '📱 No active AI session, no notification needed');
      }
    }).catchError((error) {
      _logger.e(_tag, '❌ Error notifying Android of app background: $error');
    });
  }
  
  /// Handle app inactive (transitioning)
  void _handleAppInactive() {
    _logger.d(_tag, '📱 App inactive - transitioning state');
    // App is transitioning between foreground and background
    // Usually no action needed here
  }
  
  /// Handle app detached (about to be destroyed)
  void _handleAppDetached() {
    _logger.i(_tag, '📱 App detached - cleaning up');
    
    // App is about to be destroyed
    // Ensure background service is properly managed
    _aiAgentService.isAiAgentServiceRunning().then((isRunning) {
      if (isRunning) {
        _logger.i(_tag, '🤖 AI agent service is running, it will continue in background');
      }
    }).catchError((error) {
      _logger.e(_tag, '❌ Error checking AI agent service on app detach: $error');
    });
  }
  
  /// Handle app hidden (iOS specific)
  void _handleAppHidden() {
    _logger.d(_tag, '📱 App hidden');
    // Similar to paused but for iOS
    _handleAppPaused();
  }
  
  /// Check if there's an active AI agent session
  Future<bool> hasActiveAiSession() async {
    try {
      return await _aiAgentService.isAiAgentServiceRunning();
    } catch (e) {
      _logger.e(_tag, '❌ Error checking active AI session: $e');
      return false;
    }
  }
  
  /// Get current session info for UI display
  Future<Map<String, dynamic>?> getCurrentSessionInfo() async {
    try {
      return await _aiAgentService.getAiAgentSessionInfo();
    } catch (e) {
      _logger.e(_tag, '❌ Error getting current session info: $e');
      return null;
    }
  }
}
