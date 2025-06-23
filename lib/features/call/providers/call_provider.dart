import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/call_state.dart';
import '../../../core/services/agora/agora_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';

class CallProvider with ChangeNotifier {
  static const MethodChannel _methodChannel = MethodChannel('com.duckbuck.app/call');
  static const String _tag = 'CALL_PROVIDER';
  final LoggerService _logger = serviceLocator<LoggerService>();
  
  CallState? _currentCall;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Speaker is on by default for calls
  
  // Initiator-specific state
  CallRole _currentRole = CallRole.receiver; // Default to receiver
  String? _channelId;
  int? _myUid;
  bool _waitingForFriend = false;
  bool _friendJoined = false;

  // Getters for all functionality
  CallState? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  
  // Initiator-specific getters
  CallRole get currentRole => _currentRole;
  String? get channelId => _channelId;
  int? get myUid => _myUid;
  bool get waitingForFriend => _waitingForFriend;
  bool get friendJoined => _friendJoined;
  
  /// Check if currently in an active call (friend has joined for initiator, or just in call for receiver)
  bool get isActiveCall {
    if (_currentRole == CallRole.initiator) {
      final result = isInCall && _friendJoined && !_waitingForFriend;
      _logger.d(_tag, 'isActiveCall check (INITIATOR): isInCall=$isInCall, friendJoined=$_friendJoined, waitingForFriend=$_waitingForFriend => result=$result');
      return result;
    } else {
      // For receiver, active call = just being in call
      return isInCall;
    }
  }
  
  /// Check if currently waiting for friend to join (initiator only)
  bool get isWaitingForFriend => _currentRole == CallRole.initiator && isInCall && _waitingForFriend;

  // Protected setters for subclasses
  @protected
  set currentCall(CallState? value) {
    _currentCall = value;
  }
  
  @protected
  set isInCall(bool value) {
    _isInCall = value;
  }
  
  @protected
  set isMuted(bool value) {
    _isMuted = value;
  }
  
  @protected
  set isSpeakerOn(bool value) {
    _isSpeakerOn = value;
  }

  CallProvider() {
    _setupMethodChannelHandler();
    // Set up callback to listen for call end events from AgoraService
    AgoraService.setCallEndedCallback(_onAgoraCallEnded);
  }

  // ========== INITIATOR FUNCTIONALITY ==========
  
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

      // Haptic feedback for call initiation
      HapticFeedback.lightImpact();

      // Set initiator state
      _currentRole = CallRole.initiator;
      _channelId = channelId;
      _myUid = uid;
      _waitingForFriend = true;
      _friendJoined = false;

      // Create call state for initiator
      final callState = CallState(
        callerName: friendName, // Show friend's name on initiator's screen
        callerPhotoUrl: friendPhotoUrl,
        channelId: channelId,
        uid: uid,
        isInitiator: true,
        isActive: false, // Will become true when friend joins
      );

      // Show call UI immediately for initiator
      _showInitiatorCallUI(callState);
      
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
  void _showInitiatorCallUI(CallState callState) {
    _logger.i(_tag, 'Showing initiator call UI');
    
    _currentCall = callState;
    _isInCall = true;
    _isMuted = false; // Start unmuted for initiator
    _isSpeakerOn = true; // Speaker on by default
    
    _logger.d(_tag, 'Initial UI state:');
    _logger.d(_tag, '  - waitingForFriend: $_waitingForFriend');
    _logger.d(_tag, '  - friendJoined: $_friendJoined');
    _logger.d(_tag, '  - isInCall: $isInCall');
    _logger.d(_tag, '  - isActiveCall: $isActiveCall');
    
    // Start monitoring for disconnections
    _startStateMonitoring();
    
    notifyListeners();
  }

  /// Join channel in background without blocking UI
  void _joinChannelInBackground(String channelId, String token, int uid) async {
    try {
      _logger.i(_tag, 'Starting background channel join process...');
      _logger.d(_tag, 'Setting up user joined callback BEFORE joining channel...');

      // Set up friend join detection BEFORE joining channel
      _waitingForFriend = true;
      _friendJoined = false;
      
      bool friendJoined = false;
      bool timedOut = false;
      
      // Set up user joined callback BEFORE joining channel to avoid race condition
      late void Function() userJoinedListener;
      userJoinedListener = () {
        if (!timedOut) { // Only process if not timed out
          friendJoined = true;
          _friendJoined = true;
          _waitingForFriend = false;
          _logger.i(_tag, '✅ Friend joined the call!');
          
          // Haptic feedback for successful friend join
          HapticFeedback.mediumImpact();
          
          notifyListeners();
        }
        AgoraService.setUserJoinedCallback(null); // Always remove listener
      };
      
      // CRITICAL: Set callback BEFORE joining to avoid race condition
      AgoraService.setUserJoinedCallback(userJoinedListener);
      notifyListeners();

      _logger.d(_tag, 'Callback set up, now joining channel...');

      // Join channel (non-blocking)
      final joinResult = await AgoraService.joinChannel(
        channelName: channelId,
        token: token,
        uid: uid,
      );

      if (!joinResult) {
        _logger.w(_tag, 'Failed to join channel');
        _waitingForFriend = false;
        AgoraService.setUserJoinedCallback(null); // Clean up callback
        notifyListeners();
        return;
      }

      _logger.i(_tag, 'Successfully joined channel, waiting for friend...');

      // Check if friend is already in channel (race condition prevention)
      await Future.delayed(const Duration(milliseconds: 500)); // Give time for Agora to stabilize
      final remoteUserCount = await AgoraService.getRemoteUserCount();
      _logger.d(_tag, 'Remote users in channel after join: $remoteUserCount');
      
      if (remoteUserCount > 0 && !friendJoined && !timedOut) {
        _logger.i(_tag, '🎯 Friend was already in channel - marking as joined');
        friendJoined = true;
        _friendJoined = true;
        _waitingForFriend = false;
        
        // Haptic feedback for successful friend join
        HapticFeedback.mediumImpact();
        
        notifyListeners();
      }

      // Wait for friend to join or timeout (25 seconds)
      _logger.d(_tag, 'Waiting for friend to join (25 second timeout)...');
      
      final result = await Future.any([
        Future.delayed(const Duration(seconds: 25)).then((_) => 'timeout'),
        Future(() async {
          while (!friendJoined && !timedOut) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          return friendJoined ? 'joined' : 'timeout';
        }),
      ]);

      // Mark as timed out if needed
      if (result == 'timeout') {
        timedOut = true;
      }

      // Always remove listener after wait
      AgoraService.setUserJoinedCallback(null);

      // Check final result
      if (friendJoined && !timedOut) {
        // SUCCESS: Friend joined successfully
        _logger.i(_tag, '✅ Friend joined successfully - call is now active');
        _logger.d(_tag, 'Final state:');
        _logger.d(_tag, '  - waitingForFriend: $_waitingForFriend');
        _logger.d(_tag, '  - friendJoined: $_friendJoined');
        _logger.d(_tag, '  - isInCall: $isInCall');
        _logger.d(_tag, '  - isActiveCall: $isActiveCall');
        notifyListeners();
      } else {
        // FAILURE: Timeout or friend didn't join
        _logger.w(_tag, '⏰ Friend did not join within timeout - cleaning up call');
        
        // Haptic feedback for call failure
        HapticFeedback.heavyImpact();
        
        _waitingForFriend = false;
        _friendJoined = false;
        _isInCall = false;
        try {
          await AgoraService.leaveChannel();
        } catch (e) {
          _logger.w(_tag, 'Error leaving channel during cleanup: $e');
        }
        notifyListeners();
        return;
      }
    } catch (e) {
      _logger.e(_tag, 'Exception in _joinChannelInBackground: $e');
      
      // Haptic feedback for call failure
      HapticFeedback.heavyImpact();
      
      _waitingForFriend = false;
      _friendJoined = false;
      _isInCall = false;
      notifyListeners();
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

  // ========== RECEIVER FUNCTIONALITY (ORIGINAL) ==========

  /// Handle call ended event from AgoraService
  void _onAgoraCallEnded() {
    if (_isInCall) {
      _dismissCallUI();
    }
  }

  /// Setup method channel handler to receive calls from Kotlin
  void _setupMethodChannelHandler() {
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'showCallUI':
          final callerName = call.arguments['callerName'] as String?;
          final callerPhotoUrl = call.arguments['callerPhotoUrl'] as String?;
          final isMuted = call.arguments['isMuted'] as bool? ?? true;  
          
          if (callerName != null) {
            _showReceiverCallUI(CallState(
              callerName: callerName,
              callerPhotoUrl: callerPhotoUrl,
              isInitiator: false,
            ), isMuted);
          }
          break;
        
        case 'dismissCallUI':
          _dismissCallUI();
          break;
      }
    });
  }

  /// Show call UI for receiver (called from Kotlin via method channel)
  void _showReceiverCallUI(CallState callState, bool isMuted) {
    _logger.i(_tag, 'Showing receiver call UI');
    
    // Haptic feedback when call UI appears for receiver
    HapticFeedback.lightImpact();
    
    _currentRole = CallRole.receiver;
    _currentCall = callState;
    _isInCall = true;
    _isMuted = isMuted; // Use the actual mute state from Kotlin (always starts muted)
    _isSpeakerOn = true; // Default to speaker on
    
    notifyListeners();
  }

  /// Dismiss call UI (called from Kotlin via method channel)
  void _dismissCallUI() {
    _currentCall = null;
    _isInCall = false;
    _isMuted = false;
    _isSpeakerOn = true;
    
    notifyListeners();
  }

  /// End call (handles both initiator and receiver)
  Future<void> endCall() async {
    try {
      _logger.i(_tag, 'Ending call...');
      
      if (_currentRole == CallRole.initiator) {
        _logger.i(_tag, 'Ending call as initiator...');
        
        // Leave the channel
        await AgoraService.leaveChannel();
        
        // Clear initiator state
        _channelId = null;
        _myUid = null;
        _waitingForFriend = false;
        _friendJoined = false;
        
        _logger.i(_tag, 'Initiator call ended successfully');
      } else {
        _logger.i(_tag, 'Ending call as receiver...');
        
        // Send end call request to Kotlin (original receiver logic)
        await AgoraService.leaveChannel();
        
        // Don't clear state here - wait for Kotlin to call dismissCallUI
        _logger.i(_tag, 'Receiver call end request sent');
        return; // Don't clear state for receiver
      }
      
      // Clear call state only for initiator
      clearCallState();
      
    } catch (e) {
      _logger.e(_tag, 'Error ending call: $e');
      // Force clear state even if error
      clearCallState();
    }
  }

  /// Toggle microphone mute/unmute
  Future<void> toggleMute() async {
    try {
      // Get current state from AgoraService
      final currentlyMuted = await AgoraService.isMicrophoneMuted();
      
      if (currentlyMuted) {
        final result = await AgoraService.turnMicrophoneOn();
        if (result) {
          _isMuted = false;
          notifyListeners();
        }
      } else {
        final result = await AgoraService.turnMicrophoneOff();
        if (result) {
          _isMuted = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error toggling mute: $e');
    }
  }

  /// Toggle speaker on/off
  Future<void> toggleSpeaker() async {
    try {
      // Get current state from AgoraService
      final currentlySpeakerOn = await AgoraService.isSpeakerEnabled();
      
      if (currentlySpeakerOn) {
        final result = await AgoraService.turnSpeakerOff();
        if (result) {
          _isSpeakerOn = false;
          notifyListeners();
        }
      } else {
        final result = await AgoraService.turnSpeakerOn();
        if (result) {
          _isSpeakerOn = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error toggling speaker: $e');
    }
  }

  /// Sync provider state with actual Agora state
  Future<void> syncWithAgoraState() async {
    try {
      _isMuted = await AgoraService.isMicrophoneMuted();
      _isSpeakerOn = await AgoraService.isSpeakerEnabled();
      _isInCall = await AgoraService.isInChannel();
      notifyListeners();
    } catch (e) {
      _logger.e(_tag, 'Error syncing with Agora state: $e');
    }
  }

  /// Sync state with actual Agora state (for initiator monitoring)
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
      
      // Sync mute/speaker state (but DON'T sync isInCall)
      _isMuted = await AgoraService.isMicrophoneMuted();
      _isSpeakerOn = await AgoraService.isSpeakerEnabled();
      notifyListeners();
      
    } catch (e) {
      _logger.e(_tag, 'Error syncing with Agora state: $e');
    }
  }

  /// Clear call state (for cleanup)
  void clearCallState() {
    _currentCall = null;
    _isInCall = false;
    _isMuted = false;
    _isSpeakerOn = true;
    
    // Clear initiator-specific state
    _currentRole = CallRole.receiver; // Reset to default
    _channelId = null;
    _myUid = null;
    _waitingForFriend = false;
    _friendJoined = false;
    
    notifyListeners();
  }
}
