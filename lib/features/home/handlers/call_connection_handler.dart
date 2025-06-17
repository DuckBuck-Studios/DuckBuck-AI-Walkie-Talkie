import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/agora/agora_token_service.dart';
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
      
      // PART 3: Send FCM invitation to friend
      await _sendFCMInvitation(friendData);
      
      // PART 4: Start the call using provider
      await _startCallWithProvider(friendData, tokenResponse);
      
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize walkie-talkie circuit: $e');
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
      
      return tokenResponse;
    } catch (e) {
      _logger.e(_tag, 'PART 2 - Failed to fetch Agora token: $e');
      return null;
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
  Future<void> _startCallWithProvider(FriendData friendData, dynamic tokenResponse) async {
    try {
      _logger.i(_tag, 'PART 4 - Starting call using CallProvider...');
      
      await callProvider.startCall(
        friendName: friendData.friendName,
        channelId: friendData.relationshipId,
        uid: tokenResponse.uid,
        token: tokenResponse.token,
        friendPhotoUrl: friendData.friendPhotoUrl,
      );

    } catch (e) {
      _logger.e(_tag, 'PART 4 - Error starting call with provider: $e');
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
