import 'dart:async';
import '../api/api_service.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';
import '../firebase/firebase_database_service.dart';
import '../agora/agora_service.dart';
import '../agora/agora_token_service.dart';
import '../auth/auth_service_interface.dart';
import '../../exceptions/ai_agent_exceptions.dart';
import 'ai_agent_service_interface.dart';

/// Service for handling AI agent operations with real-time time tracking
class AiAgentService implements AiAgentServiceInterface {
  final ApiService _apiService;
  final LoggerService _logger;
  final FirebaseDatabaseService _databaseService;
  final AgoraTokenService _agoraTokenService;
  
  static const String _tag = 'AI_AGENT_SERVICE';
  static const String _userCollection = 'users';
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<int>> _timeStreamControllers = {};
  final Map<String, StreamSubscription> _timeStreamSubscriptions = {};
  
  /// Creates a new AiAgentService
  AiAgentService({
    ApiService? apiService,
    LoggerService? logger,
    FirebaseDatabaseService? databaseService,
    AgoraTokenService? agoraTokenService,
    AuthServiceInterface? authService,
  }) : _apiService = apiService ?? serviceLocator<ApiService>(),
       _logger = logger ?? serviceLocator<LoggerService>(),
       _databaseService = databaseService ?? serviceLocator<FirebaseDatabaseService>(),
       _agoraTokenService = agoraTokenService ?? serviceLocator<AgoraTokenService>();

  @override
  @override
  Future<Map<String, dynamic>?> joinAgentWithAgoraSetup({
    required String uid,
  }) async {
    try {
      _logger.i(_tag, 'Starting AI agent with Agora setup for user: $uid');
      
      // Step 1: Create channel name using Firebase UID
      final channelName = 'ai_$uid';
      _logger.i(_tag, 'Using channel name: $channelName');
      
      // Step 2: Get Agora token (backend assigns UID)
      _logger.i(_tag, 'Getting Agora token for channel: $channelName');
      final tokenResponse = await _agoraTokenService.generateToken(
        uid: 0, // Let backend assign UID
        channelId: channelName,
      );
      
      _logger.i(_tag, 'Received Agora token with UID: ${tokenResponse.uid}');
      
      // Step 3: Initialize Agora engine
      final engineInitialized = await AgoraService.initializeEngine();
      if (!engineInitialized) {
        _logger.e(_tag, 'Failed to initialize Agora engine');
        return null;
      }
      
      // Step 4: Join Agora channel with the UID from backend
      final agoraJoined = await AgoraService.joinChannel(
        token: tokenResponse.token,
        channelName: channelName,
        uid: tokenResponse.uid,
      );
      
      if (!agoraJoined) {
        _logger.e(_tag, 'Failed to join Agora channel');
        return null;
      }
      
      _logger.i(_tag, 'Successfully joined Agora channel: $channelName with UID: ${tokenResponse.uid}');
      
      // Add 500ms delay after joining channel before inviting AI agent
      _logger.d(_tag, 'Waiting 500ms before inviting AI agent to channel');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 5: Get user's remaining time
      final remainingTime = await getUserRemainingTime(uid);
      if (!hasRemainingTime(remainingTime)) {
        _logger.w(_tag, 'User has no remaining time');
        await AgoraService.leaveChannel();
        return null;
      }
      
      // Step 6: Join AI agent to the channel (backend call)
      final agentResponse = await joinAgent(
        uid: uid,
        channelName: channelName,
        remainingTimeSeconds: remainingTime,
      );
      
      if (agentResponse == null) {
        _logger.e(_tag, 'Failed to join AI agent to channel');
        await AgoraService.leaveChannel();
        return null;
      }
      
      _logger.i(_tag, 'AI agent setup completed successfully');
      return agentResponse; // Return the backend response data instead of just true
    } catch (e) {
      _logger.e(_tag, 'Error in joinAgentWithAgoraSetup: $e');
      // Clean up on error
      await AgoraService.leaveChannel();
      return null;
    }
  }

  @override
  Future<bool> stopAgentAndLeaveChannel() async {
    try {
      _logger.i(_tag, 'Stopping AI agent and leaving Agora channel');
      
      // Leave Agora channel
      await AgoraService.leaveChannel();
      
      _logger.i(_tag, 'Successfully left Agora channel');
      return true;
    } catch (e) {
      _logger.e(_tag, 'Error in stopAgentAndLeaveChannel: $e');
      return false;
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
      if (newRemainingTimeSeconds < 0) {
        throw AiAgentException(
          AiAgentErrorCodes.invalidTimeValue,
          'Time cannot be negative: $newRemainingTimeSeconds',
        );
      }

      _logger.i(_tag, 'Updating user $uid agent time to ${formatRemainingTime(newRemainingTimeSeconds)}');

      await _databaseService.setDocument(
        collection: _userCollection,
        documentId: uid,
        data: {
          'agentRemainingTime': newRemainingTimeSeconds,
        },
        merge: true, // Only update the agentRemainingTime field
        logOperation: false,
      );

      _logger.i(_tag, 'User agent time updated successfully in Firebase');
    } catch (e) {
      if (e is AiAgentException) rethrow;
      _logger.e(_tag, 'Error updating user agent time in Firebase: $e');
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
      if (timeUsedSeconds < 0) {
        throw AiAgentException(
          AiAgentErrorCodes.invalidTimeValue,
          'Time used cannot be negative: $timeUsedSeconds',
        );
      }

      _logger.i(_tag, 'Decreasing user $uid agent time by ${formatRemainingTime(timeUsedSeconds)}');

      // Get current user data to calculate new remaining time
      final userData = await _databaseService.getDocument(
        collection: _userCollection,
        documentId: uid,
      );

      if (userData == null) {
        throw AiAgentExceptions.userNotFound(uid);
      }

      final currentRemainingTime = userData['agentRemainingTime'] as int? ?? 0;
      final newRemainingTime = (currentRemainingTime - timeUsedSeconds).clamp(0, double.infinity).toInt();

      _logger.d(_tag, 'User $uid time: ${formatRemainingTime(currentRemainingTime)} -> ${formatRemainingTime(newRemainingTime)}');

      // Update the remaining time in Firebase
      await updateUserAgentTime(
        uid: uid,
        newRemainingTimeSeconds: newRemainingTime,
      );

      return newRemainingTime;
    } catch (e) {
      if (e is AiAgentException) rethrow;
      _logger.e(_tag, 'Error decreasing user agent time: $e');
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
      if (additionalTimeSeconds < 0) {
        throw AiAgentException(
          AiAgentErrorCodes.invalidTimeValue,
          'Additional time cannot be negative: $additionalTimeSeconds',
        );
      }

      _logger.i(_tag, 'Increasing user $uid agent time by ${formatRemainingTime(additionalTimeSeconds)}');

      // Get current user data to calculate new remaining time
      final userData = await _databaseService.getDocument(
        collection: _userCollection,
        documentId: uid,
      );

      if (userData == null) {
        throw AiAgentExceptions.userNotFound(uid);
      }

      final currentRemainingTime = userData['agentRemainingTime'] as int? ?? 0;
      final newRemainingTime = currentRemainingTime + additionalTimeSeconds;

      _logger.d(_tag, 'User $uid time: ${formatRemainingTime(currentRemainingTime)} -> ${formatRemainingTime(newRemainingTime)}');

      // Update the remaining time in Firebase
      await updateUserAgentTime(
        uid: uid,
        newRemainingTimeSeconds: newRemainingTime,
      );

      return newRemainingTime;
    } catch (e) {
      if (e is AiAgentException) rethrow;
      _logger.e(_tag, 'Error increasing user agent time: $e');
      throw AiAgentExceptions.timeUpdateFailed(uid, e);
    }
  }

  /// Get user's current remaining AI agent time from Firebase
  @override
  Future<int> getUserRemainingTime(String uid) async {
    try {
      final userData = await _databaseService.getDocument(
        collection: _userCollection,
        documentId: uid,
      );

      if (userData == null) {
        _logger.w(_tag, 'User data not found for uid: $uid, returning 0 remaining time');
        return 0;
      }

      final remainingTime = userData['agentRemainingTime'] as int? ?? 0;
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
      _logger.i(_tag, 'Resetting user $uid agent time to default (1 hour)');
      
      await updateUserAgentTime(
        uid: uid,
        newRemainingTimeSeconds: 3600, // 1 hour default
      );
      
      _logger.i(_tag, 'User agent time reset successfully');
    } catch (e) {
      _logger.e(_tag, 'Error resetting user agent time: $e');
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
}
