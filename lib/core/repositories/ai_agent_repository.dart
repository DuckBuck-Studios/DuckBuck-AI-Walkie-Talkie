import '../services/ai_agent/ai_agent_service_interface.dart';
import '../services/user/user_service_interface.dart';
import '../services/logger/logger_service.dart';
import '../services/service_locator.dart'; 

/// Repository to handle AI agent operations with user data integration
class AiAgentRepository {
  final AiAgentServiceInterface _aiAgentService;
  final UserServiceInterface _userService;
  final LoggerService _logger;
  
  static const String _tag = 'AI_AGENT_REPO';
  
  /// Creates a new AiAgentRepository
  AiAgentRepository({
    AiAgentServiceInterface? aiAgentService,
    UserServiceInterface? userService,
    LoggerService? logger,
  }) : _aiAgentService = aiAgentService ?? serviceLocator<AiAgentServiceInterface>(),
       _userService = userService ?? serviceLocator<UserServiceInterface>(),
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Join AI agent with full Agora setup and time tracking
  /// Handles token generation, Agora channel joining, and backend AI agent connection
  /// Returns the agent response data if successful, null otherwise
  Future<Map<String, dynamic>?> joinAgentWithFullSetup({
    required String uid,
  }) async {
    try {
      _logger.i(_tag, 'Starting full AI agent setup for user: $uid');

      // Get current user data to check remaining time
      final userData = await _userService.getUserData(uid);
      if (userData == null) {
        _logger.e(_tag, 'User data not found for uid: $uid');
        throw Exception('User data not found');
      }

      final remainingTime = userData.agentRemainingTime;
      _logger.d(_tag, 'User $uid has ${_aiAgentService.formatRemainingTime(remainingTime)} remaining');

      // Check if user has remaining time
      if (!_aiAgentService.hasRemainingTime(remainingTime)) {
        _logger.w(_tag, 'User $uid has no remaining AI agent time');
        return null;
      }

      // Use the service to handle Agora setup and get the response data
      final responseData = await _aiAgentService.joinAgentWithAgoraSetup(uid: uid);
      
      if (responseData != null) {
        _logger.i(_tag, 'AI agent setup completed successfully for user: $uid');
        return responseData;
      } else {
        _logger.e(_tag, 'AI agent setup failed for user: $uid');
        return null;
      }
    } catch (e) {
      _logger.e(_tag, 'Error in joinAgentWithFullSetup: $e');
      return null;
    }
  }

  /// Stop AI agent with full cleanup including Agora channel leave
  /// Returns true if successful
  Future<bool> stopAgentWithFullCleanup({
    required String agentId,
    required String uid,
    required int timeUsedSeconds,
  }) async {
    try {
      _logger.i(_tag, 'Stopping AI agent with full cleanup: $agentId for user: $uid, time used: ${_aiAgentService.formatRemainingTime(timeUsedSeconds)}');

      // Stop the agent through backend
      final backendStopped = await _aiAgentService.stopAgent(agentId: agentId);
      
      // Leave Agora channel (always do this regardless of backend success)
      final agoraLeft = await _aiAgentService.stopAgentAndLeaveChannel();
      
      if (backendStopped) {
        // Update user's remaining time only if backend stop was successful
        if (timeUsedSeconds > 0) {
          _logger.d(_tag, 'Updating user remaining time after agent use');
          await _aiAgentService.decreaseUserAgentTime(
            uid: uid,
            timeUsedSeconds: timeUsedSeconds,
          );
        }
        
        _logger.i(_tag, 'AI agent stopped and cleanup completed successfully');
        return true;
      } else {
        _logger.w(_tag, 'AI agent backend stop failed, but Agora cleanup was ${agoraLeft ? 'successful' : 'failed'}');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error in stopAgentWithFullCleanup: $e');
      
      // Try to ensure Agora cleanup even on error
      try {
        await _aiAgentService.stopAgentAndLeaveChannel();
      } catch (cleanupError) {
        _logger.e(_tag, 'Error during emergency Agora cleanup: $cleanupError');
      }
      
      return false;
    }
  }
  /// Returns the agent response data if successful, null if user has no remaining time
  /// Updates user's remaining time in the database
  Future<Map<String, dynamic>?> joinAgentWithTimeTracking({
    required String uid,
    required String channelName,
  }) async {
    try {
      _logger.i(_tag, 'Starting AI agent join process for user: $uid, channel: $channelName');

      // Get current user data to check remaining time
      final userData = await _userService.getUserData(uid);
      if (userData == null) {
        _logger.e(_tag, 'User data not found for uid: $uid');
        throw Exception('User data not found');
      }

      final remainingTime = userData.agentRemainingTime;
      _logger.d(_tag, 'User $uid has ${_aiAgentService.formatRemainingTime(remainingTime)} remaining');

      // Check if user has remaining time
      if (!_aiAgentService.hasRemainingTime(remainingTime)) {
        _logger.w(_tag, 'User $uid has no remaining AI agent time');
        return null;
      }

      // Attempt to join the agent
      final responseData = await _aiAgentService.joinAgent(
        uid: uid,
        channelName: channelName,
        remainingTimeSeconds: remainingTime,
      );

      if (responseData != null) {
        _logger.i(_tag, 'AI agent joined successfully with response: $responseData');
        // Note: Time tracking (decrementing remaining time) should be handled
        // by a separate timer or background service while the agent is active
      }

      return responseData;
    } catch (e) {
      _logger.e(_tag, 'Error in joinAgentWithTimeTracking: $e');
      rethrow;
    }
  }

  /// Stop AI agent and update user's remaining time
  /// Returns true if successful
  Future<bool> stopAgentWithTimeTracking({
    required String agentId,
    required String uid,
    required int timeUsedSeconds,
  }) async {
    try {
      _logger.i(_tag, 'Stopping AI agent: $agentId for user: $uid, time used: ${_aiAgentService.formatRemainingTime(timeUsedSeconds)}');

      // Stop the agent
      final success = await _aiAgentService.stopAgent(agentId: agentId);

      if (success) {
        // Update user's remaining time
        await updateUserRemainingTime(uid: uid, timeUsedSeconds: timeUsedSeconds);
        _logger.i(_tag, 'AI agent stopped and user time updated successfully');
      }

      return success;
    } catch (e) {
      _logger.e(_tag, 'Error in stopAgentWithTimeTracking: $e');
      rethrow;
    }
  }

  /// Check if user can use AI agent (has remaining time)
  Future<bool> canUseAiAgent(String uid) async {
    try {
      final userData = await _userService.getUserData(uid);
      if (userData == null) return false;

      return _aiAgentService.hasRemainingTime(userData.agentRemainingTime);
    } catch (e) {
      _logger.e(_tag, 'Error checking if user can use AI agent: $e');
      return false;
    }
  }

  /// Get user's remaining AI agent time
  Future<int> getUserRemainingTime(String uid) async {
    try {
      final userData = await _userService.getUserData(uid);
      return userData?.agentRemainingTime ?? 0;
    } catch (e) {
      _logger.e(_tag, 'Error getting user remaining time: $e');
      return 0;
    }
  }

  /// Get formatted remaining time for display
  Future<String> getFormattedRemainingTime(String uid) async {
    final remainingTime = await getUserRemainingTime(uid);
    return _aiAgentService.formatRemainingTime(remainingTime);
  }

  /// Get real-time stream of user's remaining AI agent time
  Stream<int> getUserRemainingTimeStream(String uid) {
    try {
      _logger.d(_tag, 'Creating real-time time stream for user: $uid');
      return _aiAgentService.getUserRemainingTimeStream(uid);
    } catch (e) {
      _logger.e(_tag, 'Error creating time stream for user $uid: $e');
      rethrow;
    }
  }

  /// Get formatted real-time stream of user's remaining AI agent time
  Stream<String> getFormattedRemainingTimeStream(String uid) {
    return getUserRemainingTimeStream(uid).map(
      (remainingTime) => _aiAgentService.formatRemainingTime(remainingTime),
    );
  }

  /// Dispose repository resources
  void dispose() {
    _logger.d(_tag, 'Disposing AI agent repository');
    _aiAgentService.dispose();
  }

  /// Update user's remaining time after agent usage
  Future<void> updateUserRemainingTime({
    required String uid,
    required int timeUsedSeconds,
  }) async {
    try {
      // Get current user data
      final userData = await _userService.getUserData(uid);
      if (userData == null) {
        _logger.e(_tag, 'Cannot update time - user data not found for uid: $uid');
        return;
      }

      // Calculate new remaining time (ensure it doesn't go below 0)
      final newRemainingTime = (userData.agentRemainingTime - timeUsedSeconds).clamp(0, double.infinity).toInt();
      
      _logger.i(_tag, 'Updating user $uid remaining time from ${_aiAgentService.formatRemainingTime(userData.agentRemainingTime)} to ${_aiAgentService.formatRemainingTime(newRemainingTime)}');

      // Update user data with new remaining time
      final updatedUser = userData.copyWith(
        agentRemainingTime: newRemainingTime,
      );

      await _userService.updateUserData(updatedUser);
      _logger.i(_tag, 'User remaining time updated successfully');
    } catch (e) {
      _logger.e(_tag, 'Error updating user remaining time: $e');
      rethrow;
    }
  }

  /// Add time to user's AI agent allowance (for premium features, rewards, etc.)
  Future<void> addTimeToUser({
    required String uid,
    required int additionalTimeSeconds,
  }) async {
    try {
      _logger.i(_tag, 'Adding ${_aiAgentService.formatRemainingTime(additionalTimeSeconds)} to user: $uid');

      // Get current user data
      final userData = await _userService.getUserData(uid);
      if (userData == null) {
        _logger.e(_tag, 'Cannot add time - user data not found for uid: $uid');
        return;
      }

      // Calculate new remaining time
      final newRemainingTime = userData.agentRemainingTime + additionalTimeSeconds;
      
      _logger.i(_tag, 'Updating user $uid remaining time from ${_aiAgentService.formatRemainingTime(userData.agentRemainingTime)} to ${_aiAgentService.formatRemainingTime(newRemainingTime)}');

      // Update user data with new remaining time
      final updatedUser = userData.copyWith(
        agentRemainingTime: newRemainingTime,
      );

      await _userService.updateUserData(updatedUser);
      _logger.i(_tag, 'Time added to user successfully');
    } catch (e) {
      _logger.e(_tag, 'Error adding time to user: $e');
      rethrow;
    }
  }

  /// Toggle microphone mute/unmute
  Future<bool> toggleMicrophone() async {
    try {
      _logger.d(_tag, 'Toggling microphone');
      return await _aiAgentService.toggleMicrophone();
    } catch (e) {
      _logger.e(_tag, 'Error toggling microphone: $e');
      return false;
    }
  }

  /// Toggle speaker on/off
  Future<bool> toggleSpeaker() async {
    try {
      _logger.d(_tag, 'Toggling speaker');
      return await _aiAgentService.toggleSpeaker();
    } catch (e) {
      _logger.e(_tag, 'Error toggling speaker: $e');
      return false;
    }
  }

  /// Get current microphone status
  bool isMicrophoneMuted() {
    return _aiAgentService.isMicrophoneMuted();
  }

  /// Get current speaker status
  bool isSpeakerEnabled() {
    return _aiAgentService.isSpeakerEnabled();
  }
}
