import 'dart:async';
import '../service_locator.dart';
import '../logger/logger_service.dart';
import '../auth/auth_service_interface.dart';
import '../../repositories/relationship_repository.dart';
import '../../repositories/user_repository.dart';

/// Service to handle cache synchronization when app becomes active
/// 
/// This service ensures that cached relationship and user data is refreshed when the app
/// is reopened after being closed, ensuring users always see up-to-date information
/// about friends, requests, blocked users, and their own user profile.
class CacheSyncService {
  final RelationshipRepository _relationshipRepository;
  final UserRepository _userRepository;
  final AuthServiceInterface _authService;
  final LoggerService _logger;
  
  static const String _tag = 'CACHE_SYNC_SERVICE';
  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  
  CacheSyncService({
    RelationshipRepository? relationshipRepository,
    UserRepository? userRepository,
    AuthServiceInterface? authService,
    LoggerService? logger,
  }) : _relationshipRepository = relationshipRepository ?? serviceLocator<RelationshipRepository>(),
       _userRepository = userRepository ?? serviceLocator<UserRepository>(),
       _authService = authService ?? serviceLocator<AuthServiceInterface>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Check if cache needs refresh on app resume
  /// This should be called when app becomes active/foreground
  Future<bool> shouldRefreshCache() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _logger.d(_tag, 'No current user, no cache refresh needed');
        return false;
      }

      // Check both relationship and user cache staleness
      final relationshipStale = await _relationshipRepository.isCacheStale(maxAge: _cacheValidityDuration);
      final userStale = await _userRepository.isUserCacheStale(maxAge: _cacheValidityDuration);
      
      final needsRefresh = relationshipStale || userStale;
      _logger.d(_tag, 'Cache staleness - Relationships: $relationshipStale, User: $userStale, needs refresh: $needsRefresh');
      
      return needsRefresh;
      
    } catch (e) {
      _logger.e(_tag, 'Error checking cache validity: ${e.toString()}');
      return true; // Refresh on error to be safe
    }
  }

  /// Refresh all caches by fetching fresh data
  /// This fetches latest data from Firebase and updates local cache
  Future<void> refreshAllCaches() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _logger.w(_tag, 'Cannot refresh cache: No current user');
        return;
      }

      _logger.i(_tag, 'Starting cache refresh for user: ${currentUser.uid}');

      // Create futures for all cache refreshes
      final futures = <Future>[];

      // Refresh relationship caches (friends, pending requests, blocked users)
      futures.add(_relationshipRepository.forceRefreshAllCaches());
      
      // Refresh user data cache
      futures.add(_userRepository.forceRefreshUserData());

      // Wait for all cache refreshes to complete
      await Future.wait(futures);

      _logger.i(_tag, 'Cache refresh completed successfully');

    } catch (e) {
      _logger.e(_tag, 'Failed to refresh caches: ${e.toString()}');
      rethrow;
    }
  }

  /// Clear cache timestamp (call when user logs out)
  Future<void> clearCacheTimestamp(String userId) async {
    try {
      // Clear timestamps for both relationship and user caches
      await _relationshipRepository.clearCurrentUserRelationshipCache();
      await _userRepository.clearCurrentUserCache();
      _logger.d(_tag, 'Cleared cache data for user: $userId');
    } catch (e) {
      _logger.w(_tag, 'Failed to clear cache data: ${e.toString()}');
    }
  }
}
