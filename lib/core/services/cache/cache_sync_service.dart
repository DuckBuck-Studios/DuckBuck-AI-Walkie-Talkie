import '../service_locator.dart';
import '../logger/logger_service.dart';

/// Service to handle app state synchronization when app becomes active
/// 
/// This service provides compatibility for existing code but no longer handles caching
/// since the cache layer has been removed. Real-time streams provide up-to-date data.
class CacheSyncService {
  final LoggerService _logger;
  
  static const String _tag = 'CACHE_SYNC_SERVICE';
  
  CacheSyncService({
    LoggerService? logger,
  }) : _logger = logger ?? serviceLocator<LoggerService>();

  /// Check if refresh is needed on app resume
  /// Returns false since we no longer use caching - real-time streams provide fresh data
  Future<bool> shouldRefreshCache() async {
    _logger.d(_tag, 'Cache layer removed - no refresh needed, using real-time streams');
    return false;
  }

  /// Refresh method for compatibility
  /// No-op since cache layer has been removed
  Future<void> refreshAllCaches() async {
    _logger.d(_tag, 'Cache layer removed - no cache refresh needed');
  }

  /// Clear cache method for compatibility
  /// No-op since cache layer has been removed
  Future<void> clearCacheTimestamp(String userId) async {
    _logger.d(_tag, 'Cache layer removed - no cache data to clear');
  }
}
