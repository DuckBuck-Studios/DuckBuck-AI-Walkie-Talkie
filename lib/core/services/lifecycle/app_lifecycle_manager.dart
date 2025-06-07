import 'package:flutter/widgets.dart';
import '../service_locator.dart';
import '../logger/logger_service.dart';
import '../cache/cache_sync_service.dart';

/// Manages app lifecycle events and triggers cache refresh when needed
/// 
/// This manager listens to app lifecycle changes and ensures that when the app
/// resumes from background, cached relationship data is refreshed if it's stale.
class AppLifecycleManager extends WidgetsBindingObserver {
  final CacheSyncService _cacheSyncService;
  final LoggerService _logger;
  
  static const String _tag = 'APP_LIFECYCLE_MANAGER';
  
  AppLifecycleManager({
    CacheSyncService? cacheSyncService,
    LoggerService? logger,
  }) : _cacheSyncService = cacheSyncService ?? serviceLocator<CacheSyncService>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Initialize the lifecycle manager
  void initialize() {
    _logger.i(_tag, 'Initializing app lifecycle manager');
    WidgetsBinding.instance.addObserver(this);
  }

  /// Dispose the lifecycle manager
  void dispose() {
    _logger.i(_tag, 'Disposing app lifecycle manager');
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    _logger.d(_tag, 'App lifecycle state changed to: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning between states
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS 13+)
        break;
    }
  }

  /// Handle app resumed from background
  void _onAppResumed() async {
    try {
      _logger.i(_tag, '🔄 App resumed - checking if cache refresh is needed');
      
      final shouldRefresh = await _cacheSyncService.shouldRefreshCache();
      
      if (shouldRefresh) {
        _logger.i(_tag, '♻️ Cache is stale - refreshing relationship data');
        await _cacheSyncService.refreshAllCaches();
        _logger.i(_tag, '✅ Cache refresh completed');
      } else {
        _logger.d(_tag, '👍 Cache is still fresh - no refresh needed');
      }
      
    } catch (e) {
      _logger.e(_tag, 'Error during app resume cache refresh: ${e.toString()}');
      // Don't block app resume on cache refresh failure
    }
  }

  /// Handle app paused (going to background)
  void _onAppPaused() {
    _logger.d(_tag, '⏸️ App paused - going to background');
    // Could implement background sync scheduling here in the future
  }

  /// Handle app detached (being terminated)
  void _onAppDetached() {
    _logger.d(_tag, '🚪 App detached - being terminated');
    // Cleanup if needed
  }

  /// Force refresh cache (can be called manually)
  Future<void> forceRefreshCache() async {
    try {
      _logger.i(_tag, '🔄 Force refreshing relationship cache');
      await _cacheSyncService.refreshAllCaches();
      _logger.i(_tag, '✅ Force cache refresh completed');
    } catch (e) {
      _logger.e(_tag, 'Error during force cache refresh: ${e.toString()}');
      rethrow;
    }
  }
}
