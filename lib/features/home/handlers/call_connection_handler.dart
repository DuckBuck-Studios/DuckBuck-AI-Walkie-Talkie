import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/agora/agora_token_service.dart';
import '../../../core/services/agora/agora_service.dart';
import '../../../core/services/notifications/notifications_service.dart';
import '../../call/providers/call_provider.dart';

/// Handler for managing walkie-talkie call connections
/// Separates the call initiation logic from UI components
class CallConnectionHandler {
  static const String _tag = 'CALL_CONNECTION_HANDLER';
  
  final BuildContext context;
  final CallProvider callProvider;
  final LoggerService _logger = serviceLocator<LoggerService>();
  
  CallConnectionHandler({
    required this.context,
    required this.callProvider,
  });
  
  /// Initiate a walkie-talkie call with a friend
  Future<void> initiateCall(Map<String, dynamic> friend) async {
    // Prevent multiple activations
    if (callProvider.isInCall) return;
    
    // Haptic feedback on long press
    HapticFeedback.mediumImpact();
    
    _logger.i(_tag, 'Initiating walkie-talkie call...');
    
    try {
      // PART 1: Validate friend data
      final friendData = _validateFriendData(friend);
      if (friendData == null) return;
      
      // PART 2: Get Agora token from backend
      final tokenResponse = await _getAgoraToken(friendData.relationshipId);
      if (tokenResponse == null) return;
      
      // PART 3: Initialize Agora engine
      final engineInitialized = await _initializeAgoraEngine();
      if (!engineInitialized) return;
      
      // PART 4: Send FCM invitation to friend
      await _sendFCMInvitation(friendData);
      
      // PART 5: Start the call using provider
      final callStarted = await _startCallWithProvider(friendData, tokenResponse);
      
      if (!callStarted) {
        _logger.w(_tag, '❌ Call failed to start - friend did not join');
        // TODO: Show error message to user
      } else {
        _logger.i(_tag, '✅ Call started successfully!');
      }
      
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize walkie-talkie circuit: $e');
      // TODO: Show error message to user
    }
  }
  
  /// Validate friend data and extract required fields
  FriendData? _validateFriendData(Map<String, dynamic> friend) {
    _logger.i(_tag, 'PART 1 - Validating friend data...');
    
    final relationshipId = friend['relationshipId'] as String?;
    if (relationshipId == null || relationshipId.isEmpty) {
      _logger.e(_tag, 'Relationship ID is missing - cannot start walkie-talkie');
      return null;
    }
    
    final friendUid = friend['uid'] as String?;
    if (friendUid == null || friendUid.isEmpty) {
      _logger.e(_tag, 'Friend UID is missing - cannot start walkie-talkie');
      return null;
    }
    
    final friendName = friend['displayName'] ?? 'Unknown User';
    final friendPhotoUrl = friend['photoURL'] as String?;
    
    _logger.i(_tag, 'PART 1 - Using relationship ID as channel: $relationshipId');
    _logger.i(_tag, '   - Friend: $friendUid ($friendName)');
    
    return FriendData(
      relationshipId: relationshipId,
      friendUid: friendUid,
      friendName: friendName,
      friendPhotoUrl: friendPhotoUrl,
    );
  }
  
  /// Get Agora token from backend
  Future<dynamic> _getAgoraToken(String relationshipId) async {
    try {
      _logger.i(_tag, 'PART 2 - Fetching Agora token from backend...');
      final tokenService = serviceLocator<AgoraTokenService>();
      
      final tokenResponse = await tokenService.generateToken(
        channelId: relationshipId,
      );
      
      _logger.i(_tag, 'PART 2 - Successfully fetched Agora token');
      _logger.d(_tag, '   - Channel: ${tokenResponse.channelId}');
      _logger.d(_tag, '   - Backend assigned UID: ${tokenResponse.uid}');
      
      // Validate channel matches
      if (relationshipId != tokenResponse.channelId) {
        _logger.e(_tag, '❌ CHANNEL MISMATCH: Token generated for different channel!');
        throw Exception('Channel mismatch: requested $relationshipId, got ${tokenResponse.channelId}');
      }
      
      return tokenResponse;
    } catch (e) {
      _logger.e(_tag, 'PART 2 - Failed to fetch Agora token: $e');
      return null;
    }
  }
  
  /// Initialize Agora engine
  Future<bool> _initializeAgoraEngine() async {
    try {
      _logger.i(_tag, 'PART 3 - Initializing Agora engine...');
      final engineInitialized = await AgoraService.initializeEngine();
      
      if (!engineInitialized) {
        _logger.e(_tag, 'PART 3 - Failed to initialize Agora engine');
        throw Exception('Failed to initialize Agora engine');
      }
      
      _logger.i(_tag, 'PART 3 - Agora engine initialized successfully');
      return true;
    } catch (e) {
      _logger.e(_tag, 'PART 3 - Error initializing Agora engine: $e');
      return false;
    }
  }
  
  /// Send FCM invitation to friend
  Future<void> _sendFCMInvitation(FriendData friendData) async {
    try {
      _logger.i(_tag, 'PART 4 - Sending FCM invitation to friend...');
      final notificationsService = serviceLocator<NotificationsService>();
      
      final invitationSent = await notificationsService.sendDataOnlyNotification(
        uid: friendData.friendUid,
        type: 'invite',
        agoraChannelId: friendData.relationshipId,
      );
      
      if (!invitationSent) {
        _logger.w(_tag, 'PART 4 - Failed to send FCM invitation to friend');
      } else {
        _logger.i(_tag, 'PART 4 - FCM invitation sent successfully to friend');
      }
    } catch (e) {
      _logger.e(_tag, 'PART 4 - Error sending FCM invitation: $e');
    }
  }
  
  /// Start call using CallProvider
  Future<bool> _startCallWithProvider(FriendData friendData, dynamic tokenResponse) async {
    try {
      _logger.i(_tag, 'PART 5 - Starting call using CallProvider...');
      
      final callStarted = await callProvider.startCall(
        friendName: friendData.friendName,
        channelId: friendData.relationshipId,
        uid: tokenResponse.uid,
        token: tokenResponse.token,
        friendPhotoUrl: friendData.friendPhotoUrl,
      );
       if (!callStarted) {
        _logger.w(_tag, '❌ Call failed - friend did not join or timed out');
        // The call provider will handle the UI state transition
        // based on the timeout and friend join status
      }

      return callStarted;
    } catch (e) {
      _logger.e(_tag, 'PART 5 - Error starting call with provider: $e');
      // The call provider will handle showing the error state
      return false;
    }
  }
}

/// Data class for friend information
class FriendData {
  final String relationshipId;
  final String friendUid;
  final String friendName;
  final String? friendPhotoUrl;
  
  FriendData({
    required this.relationshipId,
    required this.friendUid,
    required this.friendName,
    this.friendPhotoUrl,
  });
}
