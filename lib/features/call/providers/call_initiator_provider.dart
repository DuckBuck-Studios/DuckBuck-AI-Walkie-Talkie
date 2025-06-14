import '../models/call_data.dart';
import '../../../core/services/agora/agora_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import 'call_provider.dart';

/// Provider for handling call initiation (caller side)
/// Extends CallProvider to reuse common functionality while adding initiator-specific features
class CallInitiatorProvider extends CallProvider {
  static const String _tag = 'CALL_INITIATOR_PROVIDER';
  final LoggerService _logger = serviceLocator<LoggerService>();
  
  String? _channelId;
  int? _myUid;
  bool _waitingForFriend = false;
  bool _friendJoined = false;

  // Additional getters for initiator
  String? get channelId => _channelId;
  int? get myUid => _myUid;
  bool get waitingForFriend => _waitingForFriend;
  bool get friendJoined => _friendJoined;

  /// Start call as initiator
  Future<bool> startCall({
    required String friendName,
    required String channelId,
    required int uid,
    required String token,
    String? friendPhotoUrl,
  }) async {
    try {
      _logger.i(_tag, 'Starting call as initiator...');
      _logger.d(_tag, '  - Channel: $channelId');
      _logger.d(_tag, '  - My UID: $uid');
      _logger.d(_tag, '  - Friend: $friendName');

      // Set initiator state
      _channelId = channelId;
      _myUid = uid;
      _waitingForFriend = true;
      _friendJoined = false;

      // Create call data for initiator
      final callData = CallData(
        callerName: friendName, // Show friend's name on initiator's screen
        callerPhotoUrl: friendPhotoUrl,
      );

      // Show call UI immediately for initiator
      _showInitiatorCallUI(callData);
      
      // CRITICAL: Notify listeners immediately to show UI
      notifyListeners();

      // Join channel and wait for friend in background - don't block UI
      _joinChannelInBackground(channelId, token, uid);
      
      // Return true immediately since UI is shown
      return true;

    } catch (e) {
      _logger.e(_tag, 'Error starting call: $e');
      _waitingForFriend = false;
      notifyListeners(); // Notify UI of state change
      await endCall();
      return false;
    }
  }

  /// Show call UI for initiator
  void _showInitiatorCallUI(CallData callData) {
    _logger.i(_tag, 'Showing initiator call UI');
    
    // Use parent's protected setters
    currentCall = callData;
    isInCall = true;
    isMuted = false; // Start unmuted for initiator
    isSpeakerOn = true; // Speaker on by default
    
    _logger.d(_tag, 'Initial UI state:');
    _logger.d(_tag, '  - waitingForFriend: $_waitingForFriend');
    _logger.d(_tag, '  - friendJoined: $_friendJoined');
    _logger.d(_tag, '  - isInCall: $isInCall');
    _logger.d(_tag, '  - isActiveCall: $isActiveCall');
    
    // Start monitoring for disconnections
    _startStateMonitoring();
    
    notifyListeners();
  }

  /// End call for initiator
  @override
  Future<void> endCall() async {
    try {
      _logger.i(_tag, 'Ending call as initiator...');
      
      // Leave Agora channel using centralized service
      await AgoraService.leaveChannel();
      
      // Clear initiator state
      _channelId = null;
      _myUid = null;
      _waitingForFriend = false;
      _friendJoined = false;
      
      // Clear call state (from parent) - this will call notifyListeners()
      clearCallState();
      
      _logger.i(_tag, 'Call ended successfully');
      
    } catch (e) {
      _logger.e(_tag, 'Error ending call: $e');
      // Force clear state even if error
      clearCallState();
    }
  }

  /// Sync state with actual Agora state
  Future<void> _syncWithAgoraState() async {
    try {
      final isInChannel = await AgoraService.isInChannel();
      final hasOtherUsers = await AgoraService.hasOtherUsers();
      
      _logger.d(_tag, 'Agora state check: isInChannel=$isInChannel, hasOtherUsers=$hasOtherUsers');
      
      // If we're not in channel anymore, end the call
      if (!isInChannel && _friendJoined) {
        _logger.i(_tag, 'No longer in channel - ending call');
        await endCall();
        return;
      }
      
      // If no other users and we were in an active call, end it
      if (!hasOtherUsers && _friendJoined) {
        _logger.i(_tag, 'No other users in channel - ending call');
        await endCall();
        return;
      }
      
      // Sync mute/speaker state with parent (but DON'T sync isInCall)
      isMuted = await AgoraService.isMicrophoneMuted();
      isSpeakerOn = await AgoraService.isSpeakerEnabled();
      notifyListeners();
      
    } catch (e) {
      _logger.e(_tag, 'Error syncing with Agora state: $e');
    }
  }

  /// Start periodic state sync to detect when friend leaves
  void _startStateMonitoring() {
    // Check Agora state every 2 seconds to detect disconnections
    Future.doWhile(() async {
      if (!isInCall) return false; // Stop monitoring if call ended
      
      await _syncWithAgoraState();
      await Future.delayed(const Duration(seconds: 2));
      return isInCall; // Continue monitoring while in call
    });
  }

  /// Check if currently in an active call (friend has joined)
  bool get isActiveCall {
    final result = isInCall && _friendJoined && !_waitingForFriend;
    _logger.d(_tag, 'isActiveCall check: isInCall=$isInCall, friendJoined=$_friendJoined, waitingForFriend=$_waitingForFriend => result=$result');
    return result;
  }

  /// Check if currently waiting for friend to join
  bool get isWaitingForFriend => isInCall && _waitingForFriend;

  /// Join channel in background without blocking UI
  void _joinChannelInBackground(String channelId, String token, int uid) async {
    try {
      _logger.i(_tag, 'Starting background channel join process...');
      
      // Join channel and wait for friend in background
      final friendJoined = await AgoraService.joinChannelAndWaitForUsers(
        channelId,
        token: token,
        uid: uid,
        timeoutSeconds: 25, // Increased timeout from 20 to 25 seconds
      );

      _waitingForFriend = false;
      _friendJoined = friendJoined;
      
      _logger.d(_tag, 'Background join completed - State updated:');
      _logger.d(_tag, '  - waitingForFriend: $_waitingForFriend');
      _logger.d(_tag, '  - friendJoined: $_friendJoined');
      _logger.d(_tag, '  - isInCall: $isInCall');
      _logger.d(_tag, '  - isActiveCall: $isActiveCall');
      
      // CRITICAL: Notify listeners when background process completes
      notifyListeners();

      if (friendJoined) {
        _logger.i(_tag, '✅ Friend joined the call in background!');
        // UI will automatically show active call state via notifyListeners
      } else {
        _logger.w(_tag, '❌ Friend did not join within timeout - auto ending call');
        // Auto-dismiss call UI
        await endCall();
      }
    } catch (e) {
      _logger.e(_tag, 'Error in background channel join: $e');
      _waitingForFriend = false;
      notifyListeners();
      await endCall();
    }
  }

  @override
  void clearCallState() {
    _channelId = null;
    _myUid = null;
    _waitingForFriend = false;
    _friendJoined = false;
    super.clearCallState();
  }
}
