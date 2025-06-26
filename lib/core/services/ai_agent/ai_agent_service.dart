import 'dart:async';
import 'package:flutter/services.dart';
import '../api/api_service.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';
import '../firebase/firebase_database_service.dart';
import '../agora/agora_service.dart';
import '../agora/agora_token_service.dart';
import '../auth/auth_service_interface.dart';
import '../user/user_service_interface.dart';
import '../../exceptions/ai_agent_exceptions.dart';
import 'ai_agent_service_interface.dart';

/// Service for handling AI agent operations with real-time time tracking
class AiAgentService implements AiAgentServiceInterface {
  final ApiService _apiService;
  final LoggerService _logger;
  final FirebaseDatabaseService _databaseService;
  final AgoraTokenService _agoraTokenService;
  final UserServiceInterface _userService;
  
  // Method channel for background service communication
  static const MethodChannel _channel = MethodChannel('com.duckbuck.app/ai_agent');
  
  static const String _tag = 'AI_AGENT_SERVICE';
  static const String _backgroundTag = 'AI_AGENT_BACKGROUND';
  static const String _userCollection = 'users';
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<int>> _timeStreamControllers = {};
  final Map<String, StreamSubscription> _timeStreamSubscriptions = {};
  
  // Track audio states for AI conversations
  bool _isMicrophoneMuted = false;
  bool _isSpeakerEnabled = true;
  
  /// Creates a new AiAgentService
  AiAgentService({
    ApiService? apiService,
    LoggerService? logger,
    FirebaseDatabaseService? databaseService,
    AgoraTokenService? agoraTokenService,
    AuthServiceInterface? authService,
    UserServiceInterface? userService,
  }) : _apiService = apiService ?? serviceLocator<ApiService>(),
       _logger = logger ?? serviceLocator<LoggerService>(),
       _databaseService = databaseService ?? serviceLocator<FirebaseDatabaseService>(),
       _agoraTokenService = agoraTokenService ?? serviceLocator<AgoraTokenService>(),
       _userService = userService ?? serviceLocator<UserServiceInterface>();

  @override
  Future<Map<String, dynamic>?> joinAgentWithAgoraSetup({
    required String uid,
  }) async {
    try {
      _logger.i(_tag, '🤖 Starting AI agent with Agora AI conversational setup for user: $uid');
      
      // Step 1: Create channel name using Firebase UID
      final channelName = 'ai_$uid';
      _logger.i(_tag, '🤖 Using AI channel name: $channelName');
      
      // Step 2: Get Agora token (backend assigns UID)
      _logger.i(_tag, '🤖 Getting Agora token for AI channel: $channelName');
      final tokenResponse = await _agoraTokenService.generateToken(
        channelId: channelName,
      );
      
      _logger.i(_tag, '🤖 Received Agora token with UID: ${tokenResponse.uid}');
      
      // Step 3: Initialize Agora engine with AI enhancements
      final engineInitialized = await AgoraService.instance.initializeEngine();
      if (!engineInitialized) {
        _logger.e(_tag, '❌ Failed to initialize Agora engine with AI enhancements');
        return null;
      }
      _logger.i(_tag, '✅ Agora engine initialized with AI audio enhancements');
      
      // Step 4: Set AI audio scenario for conversational AI
      final aiScenarioSet = await AgoraService.instance.setAiAudioScenario();
      if (aiScenarioSet) {
        _logger.i(_tag, '🤖 AI audio scenario configured for conversational AI');
      } else {
        _logger.w(_tag, '⚠️ Failed to set AI audio scenario, continuing with default');
      }
      
      // Step 5: Configure AI audio parameters for optimal quality
      final aiConfigSet = await AgoraService.instance.setAudioConfigParameters();
      if (aiConfigSet) {
        _logger.i(_tag, '🤖 AI audio parameters configured for optimal conversational quality');
      } else {
        _logger.w(_tag, '⚠️ Failed to configure AI audio parameters, continuing with default');
      }
      
      // Step 6: Join Agora channel with the UID from backend
      final agoraJoined = await AgoraService.instance.joinChannel(
        token: tokenResponse.token,
        channelName: channelName,
        uid: tokenResponse.uid,
        joinMuted: false, // Start unmuted for AI conversation
      );
      
      if (!agoraJoined) {
        _logger.e(_tag, '❌ Failed to join Agora AI channel');
        return null;
      }
      
      _logger.i(_tag, '🤖 Successfully joined Agora AI channel: $channelName with UID: ${tokenResponse.uid}');
      
      // Add 500ms delay after joining channel before inviting AI agent
      _logger.d(_tag, '⏳ Waiting 500ms before inviting AI agent to channel');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 7: Get user's remaining time
      final remainingTime = await getUserRemainingTime(uid);
      if (!hasRemainingTime(remainingTime)) {
        _logger.w(_tag, '❌ User has no remaining AI agent time');
        await AgoraService.instance.leaveChannel();
        return null;
      }
      
      // Step 8: Join AI agent to the channel (backend call)
      final agentResponse = await joinAgent(
        uid: uid,
        channelName: channelName,
        remainingTimeSeconds: remainingTime,
      );
      
      if (agentResponse == null) {
        _logger.e(_tag, '❌ Failed to join AI agent to channel');
        await AgoraService.instance.leaveChannel();
        return null;
      }
      
      // Step 9: Start background service for session management
      _logger.i(_tag, '🤖 Starting AI agent background service');
      final backgroundServiceStarted = await _startAiAgentService(
        userId: uid,
        channelName: channelName,
      );
      
      if (backgroundServiceStarted) {
        _logger.i(_tag, '✅ AI agent background service started successfully');
      } else {
        _logger.w(_tag, '⚠️ Failed to start AI agent background service, continuing without it');
      }
      
      _logger.i(_tag, '🤖 AI agent setup with conversational AI enhancements completed successfully');
      return agentResponse; // Return the backend response data
    } catch (e) {
      _logger.e(_tag, '❌ Error in joinAgentWithAgoraSetup: $e');
      // Clean up on error
      await AgoraService.instance.leaveChannel();
      return null;
    }
  }

  @override
  Future<bool> stopAgentAndLeaveChannel() async {
    try {
      _logger.i(_tag, '🤖 Stopping AI agent and leaving Agora channel');
      
      // Stop background service first
      _logger.i(_tag, '🛑 Stopping AI agent background service');
      final backgroundServiceStopped = await _stopAiAgentService();
      
      if (backgroundServiceStopped) {
        _logger.i(_tag, '✅ AI agent background service stopped successfully');
      } else {
        _logger.w(_tag, '⚠️ Failed to stop AI agent background service');
      }
      
      // Leave Agora channel
      await AgoraService.instance.leaveChannel();
      
      _logger.i(_tag, '✅ Successfully left Agora AI channel');
      return true;
    } catch (e) {
      _logger.e(_tag, '❌ Error in stopAgentAndLeaveChannel: $e');
      return false;
    }
  }

  @override
  Future<bool> toggleMicrophone() async {
    try {
      _logger.d(_tag, '🎤 Toggling microphone for AI conversation');
      
      // Toggle mute state
      final newMutedState = !_isMicrophoneMuted;
      final success = await AgoraService.instance.muteLocalAudio(newMutedState);
      
      if (success) {
        _isMicrophoneMuted = newMutedState;
        _logger.i(_tag, '🎤 Microphone ${_isMicrophoneMuted ? 'muted' : 'unmuted'} for AI conversation');
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, '❌ Error toggling microphone: $e');
      return false;
    }
  }

  @override
  Future<bool> toggleSpeaker() async {
    try {
      _logger.d(_tag, '🔊 Toggling speaker for AI conversation');
      
      // Toggle speaker state
      final newSpeakerState = !_isSpeakerEnabled;
      final success = await AgoraService.instance.setSpeakerphoneEnabled(newSpeakerState);
      
      if (success) {
        _isSpeakerEnabled = newSpeakerState;
        _logger.i(_tag, '🔊 Speaker ${_isSpeakerEnabled ? 'enabled' : 'disabled'} for AI conversation');
        
        // Reconfigure AI audio when audio route changes
        await AgoraService.instance.reconfigureAiAudioForRoute();
        _logger.d(_tag, '🤖 AI audio reconfigured for new audio route');
      }
      
      return success;
    } catch (e) {
      _logger.e(_tag, '❌ Error toggling speaker: $e');
      return false;
    }
  }

  @override
  bool isMicrophoneMuted() {
    // Return current tracked state
    return _isMicrophoneMuted;
  }

  @override
  bool isSpeakerEnabled() {
    // Return current tracked state
    return _isSpeakerEnabled;
  }

  @override
  Future<bool> isMicrophoneMutedAsync() async {
    try {
      _logger.d(_tag, '🎤 Getting microphone mute status for AI conversation');
      // Return locally tracked state for consistency
      return _isMicrophoneMuted;
    } catch (e) {
      _logger.e(_tag, '❌ Error getting microphone status: $e');
      return false; // Default to not muted
    }
  }

  @override
  Future<bool> isSpeakerEnabledAsync() async {
    try {
      _logger.d(_tag, '🔊 Getting speaker status for AI conversation');
      // Return locally tracked state for consistency
      return _isSpeakerEnabled;
    } catch (e) {
      _logger.e(_tag, '❌ Error getting speaker status: $e');
      return true; // Default to enabled
    }
  }

  // Background Service Methods
  // These methods handle communication with the Android foreground service

  /// Start AI agent background service
  /// This keeps the app alive and shows notification when backgrounded
  Future<bool> _startAiAgentService({
    required String userId,
    required String channelName,
  }) async {
    try {
      _logger.i(_backgroundTag, '🤖 Starting AI agent background service - User: $userId, Channel: $channelName');
      
      final result = await _channel.invokeMethod('startAiAgentService', {
        'userId': userId,
        'channelName': channelName,
      });
      
      if (result == true) {
        _logger.i(_backgroundTag, '✅ AI agent background service started successfully');
        return true;
      } else {
        _logger.e(_backgroundTag, '❌ Failed to start AI agent background service');
        return false;
      }
      
    } on PlatformException catch (e) {
      _logger.e(_backgroundTag, '❌ Platform error starting AI agent service: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Unexpected error starting AI agent service: $e');
      return false;
    }
  }
  
  /// Stop AI agent background service
  Future<bool> _stopAiAgentService() async {
    try {
      _logger.i(_backgroundTag, '🛑 Stopping AI agent background service');
      
      final result = await _channel.invokeMethod('stopAiAgentService');
      
      if (result == true) {
        _logger.i(_backgroundTag, '✅ AI agent background service stopped successfully');
        return true;
      } else {
        _logger.e(_backgroundTag, '❌ Failed to stop AI agent background service');
        return false;
      }
      
    } on PlatformException catch (e) {
      _logger.e(_backgroundTag, '❌ Platform error stopping AI agent service: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Unexpected error stopping AI agent service: $e');
      return false;
    }
  }
  
  /// Check if AI agent service is currently running
  Future<bool> isAiAgentServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isAiAgentServiceRunning');
      final isRunning = result == true;
      
      _logger.d(_backgroundTag, '📊 AI agent service running: $isRunning');
      return isRunning;
      
    } on PlatformException catch (e) {
      _logger.e(_backgroundTag, '❌ Platform error checking AI agent service status: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Unexpected error checking AI agent service status: $e');
      return false;
    }
  }
  
  /// Get current AI agent session information
  Future<Map<String, dynamic>?> getAiAgentSessionInfo() async {
    try {
      final result = await _channel.invokeMethod('getAiAgentSessionInfo');
      
      if (result is Map) {
        final sessionInfo = Map<String, dynamic>.from(result);
        _logger.d(_backgroundTag, '📋 AI agent session info: $sessionInfo');
        return sessionInfo;
      } else {
        _logger.w(_backgroundTag, '⚠️ Invalid session info format received');
        return null;
      }
      
    } on PlatformException catch (e) {
      _logger.e(_backgroundTag, '❌ Platform error getting AI agent session info: ${e.message}');
      return null;
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Unexpected error getting AI agent session info: $e');
      return null;
    }
  }
  
  /// Notify Android that app went to background
  /// This triggers foreground service and notification
  Future<bool> onAppBackgrounded() async {
    try {
      _logger.i(_backgroundTag, '📱 Notifying Android: App backgrounded');
      
      final result = await _channel.invokeMethod('onAppBackgrounded');
      final notificationShown = result == true;
      
      if (notificationShown) {
        _logger.i(_backgroundTag, '✅ Background notification shown for active AI session');
      } else {
        _logger.d(_backgroundTag, '📱 No active AI session, no notification needed');
      }
      
      return notificationShown;
      
    } on PlatformException catch (e) {
      _logger.e(_backgroundTag, '❌ Platform error handling app background: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Unexpected error handling app background: $e');
      return false;
    }
  }
  
  /// Notify Android that app came to foreground
  /// This can clear notification if desired
  Future<bool> onAppForegrounded() async {
    try {
      _logger.i(_backgroundTag, '📱 Notifying Android: App foregrounded');
      
      final result = await _channel.invokeMethod('onAppForegrounded');
      
      _logger.d(_backgroundTag, '✅ App foreground state handled');
      return result == true;
      
    } on PlatformException catch (e) {
      _logger.e(_backgroundTag, '❌ Platform error handling app foreground: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Unexpected error handling app foreground: $e');
      return false;
    }
  }
  
  /// Get formatted session duration for UI display
  Future<String> getSessionDuration() async {
    try {
      final sessionInfo = await getAiAgentSessionInfo();
      
      if (sessionInfo != null && sessionInfo['isActive'] == true) {
        return sessionInfo['formattedDuration'] ?? '0s';
      } else {
        return '0s';
      }
      
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Error getting session duration: $e');
      return '0s';
    }
  }
  
  /// Get session duration in seconds for calculations
  Future<int> getSessionDurationSeconds() async {
    try {
      final sessionInfo = await getAiAgentSessionInfo();
      
      if (sessionInfo != null && sessionInfo['isActive'] == true) {
        return sessionInfo['duration'] ?? 0;
      } else {
        return 0;
      }
      
    } catch (e) {
      _logger.e(_backgroundTag, '❌ Error getting session duration seconds: $e');
      return 0;
    }
  }

  /// Dispose all stream controllers and subscriptions
  @override
  void dispose() {
    _logger.d(_tag, 'Disposing AI agent service streams');
    
    // Cancel all subscriptions
    for (final subscription in _timeStreamSubscriptions.values) {
      subscription.cancel();
    }
    _timeStreamSubscriptions.clear();
    
    // Close all stream controllers
    for (final controller in _timeStreamControllers.values) {
      controller.close();
    }
    _timeStreamControllers.clear();
  }

  @override
  bool hasRemainingTime(int remainingTimeSeconds) {
    return remainingTimeSeconds > 0;
  }

  @override
  String formatRemainingTime(int remainingTimeSeconds) {
    if (remainingTimeSeconds <= 0) {
      return '0 minutes';
    }
    
    final hours = remainingTimeSeconds ~/ 3600;
    final minutes = (remainingTimeSeconds % 3600) ~/ 60;
    final seconds = remainingTimeSeconds % 60;
    
    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${hours}h';
      }
    } else if (minutes > 0) {
      if (seconds > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${minutes}m';
      }
    } else {
      return '${seconds}s';
    }
  }

  @override
  Future<Map<String, dynamic>?> joinAgent({
    required String uid,
    required String channelName,
    required int remainingTimeSeconds,
  }) async {
    try {
      // Check if user has remaining time
      if (!hasRemainingTime(remainingTimeSeconds)) {
        _logger.w(_tag, 'User $uid has no remaining AI agent time: ${remainingTimeSeconds}s');
        return null;
      }

      _logger.i(_tag, 'Attempting to join AI agent for user: $uid, channel: $channelName, remaining time: ${formatRemainingTime(remainingTimeSeconds)}');

      // Call the API service to join the agent
      final responseData = await _apiService.joinAiAgent(
        uid: uid,
        channelName: channelName,
      );

      if (responseData != null) {
        _logger.i(_tag, 'AI agent successfully joined channel: $channelName');
        return responseData;
      } else {
        _logger.e(_tag, 'Failed to join AI agent to channel: $channelName');
        throw AiAgentExceptions.joinFailed('API returned null response');
      }
    } catch (e) {
      if (e is AiAgentException) rethrow;
      _logger.e(_tag, 'Error joining AI agent: $e');
      throw AiAgentExceptions.joinFailed(e.toString(), e);
    }
  }

  @override
  Future<bool> stopAgent({
    required String agentId,
  }) async {
    try {
      _logger.i(_tag, 'Attempting to stop AI agent: $agentId');

      // Call the API service to stop the agent
      final success = await _apiService.stopAiAgent(
        agentId: agentId,
      );

      if (success) {
        _logger.i(_tag, 'AI agent successfully stopped: $agentId');
        return true;
      } else {
        _logger.w(_tag, 'Failed to stop AI agent: $agentId');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error stopping AI agent: $e');
      throw AiAgentExceptions.stopFailed(agentId, e);
    }
  }

  /// Get real-time stream of user's remaining AI agent time
  @override
  Stream<int> getUserRemainingTimeStream(String uid) {
    try {
      _logger.d(_tag, 'Creating time stream for user: $uid');

      // Return existing stream if already created
      if (_timeStreamControllers.containsKey(uid)) {
        return _timeStreamControllers[uid]!.stream;
      }

      // Create new stream controller
      final controller = StreamController<int>.broadcast(
        onCancel: () {
          _logger.d(_tag, 'Time stream cancelled for user: $uid');
          _disposeUserTimeStream(uid);
        },
      );

      _timeStreamControllers[uid] = controller;

      // Listen to Firebase document changes
      final subscription = _databaseService.documentStream(
        collection: _userCollection,
        documentId: uid,
      ).listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final userData = snapshot.data()!;
            final remainingTime = userData['agentRemainingTime'] as int? ?? 0;
            
            _logger.d(_tag, 'Time update for user $uid: ${formatRemainingTime(remainingTime)}');
            
            if (!controller.isClosed) {
              controller.add(remainingTime);
            }
          } else {
            _logger.w(_tag, 'User document not found for uid: $uid');
            if (!controller.isClosed) {
              controller.add(0); // Default to 0 if user not found
            }
          }
        },
        onError: (error) {
          _logger.e(_tag, 'Error in time stream for user $uid: $error');
          if (!controller.isClosed) {
            controller.addError(AiAgentExceptions.streamError('Firebase stream error', error));
          }
        },
      );

      _timeStreamSubscriptions[uid] = subscription;
      return controller.stream;
    } catch (e) {
      _logger.e(_tag, 'Error creating time stream for user $uid: $e');
      throw AiAgentExceptions.streamError('Failed to create time stream', e);
    }
  }

  /// Update user's remaining AI agent time in Firebase
  @override
  Future<void> updateUserAgentTime({
    required String uid,
    required int newRemainingTimeSeconds,
  }) async {
    try {
      _logger.i(_tag, 'Updating user $uid agent time to ${formatRemainingTime(newRemainingTimeSeconds)} via UserService');
      await _userService.updateUserAgentTime(
        uid: uid,
        newRemainingTimeSeconds: newRemainingTimeSeconds,
      );
      _logger.i(_tag, 'User agent time updated successfully via UserService');
    } catch (e) {
      _logger.e(_tag, 'Error updating user agent time via UserService: $e');
      throw AiAgentExceptions.timeUpdateFailed(uid, e);
    }
  }

  /// Decrease user's remaining AI agent time by specified amount
  @override
  Future<int> decreaseUserAgentTime({
    required String uid,
    required int timeUsedSeconds,
  }) async {
    try {
      _logger.i(_tag, 'Decreasing user $uid agent time by ${formatRemainingTime(timeUsedSeconds)} via UserService');
      final newRemainingTime = await _userService.decreaseUserAgentTime(
        uid: uid,
        timeUsedSeconds: timeUsedSeconds,
      );
      _logger.d(_tag, 'User $uid time decreased successfully to ${formatRemainingTime(newRemainingTime)}');
      return newRemainingTime;
    } catch (e) {
      _logger.e(_tag, 'Error decreasing user agent time via UserService: $e');
      throw AiAgentExceptions.timeUpdateFailed(uid, e);
    }
  }

  /// Increase user's remaining AI agent time by specified amount
  @override
  Future<int> increaseUserAgentTime({
    required String uid,
    required int additionalTimeSeconds,
  }) async {
    try {
      _logger.i(_tag, 'Increasing user $uid agent time by ${formatRemainingTime(additionalTimeSeconds)} via UserService');
      final newRemainingTime = await _userService.increaseUserAgentTime(
        uid: uid,
        additionalTimeSeconds: additionalTimeSeconds,
      );
      _logger.d(_tag, 'User $uid time increased successfully to ${formatRemainingTime(newRemainingTime)}');
      return newRemainingTime;
    } catch (e) {
      _logger.e(_tag, 'Error increasing user agent time via UserService: $e');
      throw AiAgentExceptions.timeUpdateFailed(uid, e);
    }
  }

  /// Get user's current remaining AI agent time from Firebase
  @override
  Future<int> getUserRemainingTime(String uid) async {
    try {
      _logger.d(_tag, 'Getting user remaining time via UserService for uid: $uid');
      final remainingTime = await _userService.getUserAgentRemainingTime(uid);
      _logger.d(_tag, 'User $uid has ${formatRemainingTime(remainingTime)} remaining');
      return remainingTime;
    } catch (e) {
      _logger.e(_tag, 'Error getting user remaining time: $e');
      return 0; // Return 0 on error to prevent agent usage
    }
  }

  /// Reset user's AI agent time to default (1 hour)
  @override
  Future<void> resetUserAgentTime(String uid) async {
    try {
      _logger.i(_tag, 'Resetting user $uid agent time to default (1 hour) via UserService');
      await _userService.resetUserAgentTime(uid);
      _logger.i(_tag, 'User agent time reset successfully via UserService');
    } catch (e) {
      _logger.e(_tag, 'Error resetting user agent time via UserService: $e');
      rethrow;
    }
  }

  /// Dispose stream resources for a specific user
  void _disposeUserTimeStream(String uid) {
    // Cancel subscription
    final subscription = _timeStreamSubscriptions.remove(uid);
    subscription?.cancel();

    // Close stream controller
    final controller = _timeStreamControllers.remove(uid);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }

    _logger.d(_tag, 'Disposed time stream resources for user: $uid');
  }

  @override
  Future<bool> joinAgoraChannelOnly({
    required String uid,
  }) async {
    try {
      _logger.i(_tag, '🤖 Joining Agora AI channel only for user: $uid');
      
      // Step 1: Create channel name using Firebase UID
      final channelName = 'ai_$uid';
      _logger.i(_tag, '🤖 Using AI channel name: $channelName');
      
      // Step 2: Get Agora token (backend assigns UID)
      _logger.i(_tag, '🤖 Getting Agora token for AI channel: $channelName');
      final tokenResponse = await _agoraTokenService.generateToken(
        channelId: channelName,
      );
      
      _logger.i(_tag, '🤖 Received Agora token with UID: ${tokenResponse.uid}');
      
      // Step 3: Initialize Agora engine with AI enhancements
      final engineInitialized = await AgoraService.instance.initializeEngine();
      if (!engineInitialized) {
        _logger.e(_tag, '❌ Failed to initialize Agora engine with AI enhancements');
        return false;
      }
      _logger.i(_tag, '✅ Agora engine initialized with AI audio enhancements');
      
      // Step 4: Set AI audio scenario for conversational AI
      final aiScenarioSet = await AgoraService.instance.setAiAudioScenario();
      if (aiScenarioSet) {
        _logger.i(_tag, '🤖 AI audio scenario configured for conversational AI');
      } else {
        _logger.w(_tag, '⚠️ Failed to set AI audio scenario, continuing with default');
      }
      
      
      // Step 5: Configure AI audio parameters for optimal quality
      final aiConfigSet = await AgoraService.instance.setAudioConfigParameters();
      if (aiConfigSet) {
        _logger.i(_tag, '🤖 AI audio parameters configured for optimal conversational quality');
      } else {
        _logger.w(_tag, '⚠️ Failed to configure AI audio parameters, continuing with default');
      }
      
      // Step 6: Join Agora channel with the UID from backend
      final agoraJoined = await AgoraService.instance.joinChannel(
        token: tokenResponse.token,
        channelName: channelName,
        uid: tokenResponse.uid,
        joinMuted: false, // Start unmuted for AI conversation
      );
      
      if (!agoraJoined) {
        _logger.e(_tag, '❌ Failed to join Agora AI channel');
        return false;
      }
      
      _logger.i(_tag, '🤖 Successfully joined Agora AI channel: $channelName with UID: ${tokenResponse.uid}');
      return true;
    } catch (e) {
      _logger.e(_tag, '❌ Error in joinAgoraChannelOnly: $e');
      return false;
    }
  }
}
