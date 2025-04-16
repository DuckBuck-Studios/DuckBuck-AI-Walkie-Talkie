import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/agora_service.dart';
import '../services/fcm_receiver_service.dart';
import '../services/background_call_service.dart';
import 'package:flutter/foundation.dart';

enum CallState { idle, connecting, connected, connectionFailed, ended }

// Event class for remote video state changes
class RemoteVideoStateEvent {
  final int uid;
  final bool isEnabled;

  RemoteVideoStateEvent(this.uid, this.isEnabled);
}

class CallProvider extends ChangeNotifier {
  // Singleton instance
  static final CallProvider _instance = CallProvider._internal();
  factory CallProvider() => _instance;
  CallProvider._internal();

  // Services
  final AgoraService _agoraService = AgoraService();
  final FCMReceiverService _fcmService = FCMReceiverService();
  final BackgroundCallService _backgroundCallService = BackgroundCallService();

  // Call state
  CallState _callState = CallState.idle;
  Map<String, dynamic> _currentCall = {};
  bool _isAudioMuted = true;
  bool _isSpeakerEnabled = true;
  String _connectionErrorMessage = "";

  // Remote user state tracking
  int? _remoteUid;

  // Call state change stream controller
  final StreamController<CallState> _callStateController =
      StreamController<CallState>.broadcast();

  // Getters
  CallState get callState => _callState;
  Map<String, dynamic> get currentCall => _currentCall;
  bool get isAudioMuted => _isAudioMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  String get connectionErrorMessage => _connectionErrorMessage;
  Stream<CallState> get callStateChanges => _callStateController.stream;

  // Getter for agoraEngine - exposes the RTC engine for video views
  RtcEngine? get agoraEngine => _agoraService.getEngineSync();

  // Getter for the remote user ID
  int? get remoteUid => _remoteUid;

  // Timer for call duration
  Timer? _callTimer;
  int _callDurationSeconds = 0;
  String _callDurationText = "00:00";
  String get callDurationText => _callDurationText;

  // Stream subscriptions
  StreamSubscription? _roomInvitationSubscription;
  StreamSubscription? _userJoinedSubscription;
  StreamSubscription? _userOfflineSubscription;
  StreamSubscription? _joinChannelSuccessSubscription;

  /// Initialize the call provider and set up listeners
  Future<void> initialize() async {
    try {
      debugPrint('CallProvider: Initializing');

      // Initialize Agora service
      await _agoraService.initialize();

      // Listen for room invitations from FCM
      _roomInvitationSubscription = _fcmService.onRoomInvitation.listen(
        _handleRoomInvitation,
      );

      // Listen for Agora events
      _userJoinedSubscription = _agoraService.onUserJoined.listen(
        _handleUserJoined,
      );
      _userOfflineSubscription = _agoraService.onUserOffline.listen(
        _handleUserOffline,
      );
      _joinChannelSuccessSubscription = _agoraService.onJoinChannelSuccess
          .listen(_handleJoinChannelSuccess);

      // Check for pending navigation from background notification
      checkPendingNavigation();

      debugPrint('CallProvider: Initialized successfully');
    } catch (e) {
      debugPrint('CallProvider: Error initializing - $e');
    }
  }

  /// Check if we need to navigate to call screen from a notification
  Future<void> checkPendingNavigation() async {
    try {
      final callData = await _backgroundCallService.checkPendingNavigation();
      if (callData != null && callData.isNotEmpty) {
        debugPrint(
          'CallProvider: Found pending navigation from notification: $callData',
        );

        // Check if this was for a call that might have ended while in background
        if (callData['from_notification'] == true) {
          // Get current state from Agora service
          final agoraState = _agoraService.getCurrentState();
          final bool hasActiveChannel = agoraState['currentChannel'] != null;
          final bool hasRemoteUsers = _agoraService.remoteUsers.isNotEmpty;

          if (!hasActiveChannel || !hasRemoteUsers) {
            // Call was likely ended by the other party while app was in background
            debugPrint(
              'CallProvider: Call appears to have ended while in background',
            );
            await _backgroundCallService.stopBackgroundService(
              showEndedNotification: true,
            );
            return;
          }

          // If we have active channel and remote users, restore the call state
          _currentCall = {
            'sender_name': callData['sender_name'],
            'sender_photo': callData['sender_photo'],
            'sender_uid': callData['sender_uid'],
          };
          _updateCallState(CallState.connected);
          _startCallTimer();
        }
      }
    } catch (e) {
      debugPrint('CallProvider: Error checking pending navigation - $e');
    }
  }

  /// Handle room invitation received from FCM
  void _handleRoomInvitation(Map<String, dynamic> data) {
    debugPrint('CallProvider: Room invitation received - $data');

    // Set current call data
    _currentCall = data;

    // Update call state to connecting
    _updateCallState(CallState.connecting);

    // Start a timer to check if connection was successful
    Timer(const Duration(seconds: 5), () {
      if (_callState == CallState.connecting) {
        // If still in connecting state after 5 seconds, check Agora service state
        final agoraState = _agoraService.getCurrentState();

        if (!agoraState['isInitialized'] ||
            agoraState['currentChannel'] == null) {
          // Connection is failing, update state
          _connectionErrorMessage =
              "Failed to connect to the call. Token may be invalid.";
          _updateCallState(CallState.connectionFailed);

          // Clean up the failed call attempt
          _agoraService.leaveChannel();

          debugPrint('CallProvider: Connection to call failed - $agoraState');
        }
      }
    });
  }

  /// Handle successful join channel event
  void _handleJoinChannelSuccess(JoinChannelSuccessEvent event) {
    debugPrint(
      'CallProvider: Successfully joined channel - ${event.channelId}',
    );

    // If we were in connecting state, update to connected
    if (_callState == CallState.connecting) {
      _updateCallState(CallState.connected);

      // Start call timer once connected
      _startCallTimer();

      // Start background service to keep call active when app is minimized
      _startBackgroundService();
    }
  }

  /// Start the background service to keep the call active when app is minimized
  Future<void> _startBackgroundService() async {
    try {
      // Get caller information from current call data
      final callerName = _currentCall['sender_name'] ?? 'Unknown Caller';
      final callerAvatar = _currentCall['sender_photo'];
      final senderUid = _currentCall['sender_uid'];

      // Start background service with current mute state and handle remote call ending
      final success = await _backgroundCallService.startBackgroundService(
        callerName: callerName,
        callerAvatar: callerAvatar,
        senderUid: senderUid,
        initialDurationSeconds: _callDurationSeconds,
        isAudioMuted: _isAudioMuted,
        onRemoteCallEnded: _handleRemoteCallEnded,
      );
      debugPrint(
        'CallProvider: Background service ${success ? 'started' : 'failed to start'}',
      );
    } catch (e) {
      debugPrint('CallProvider: Error starting background service - $e');
    }
  }

  /// Handle when a remote user ends the call while our app is in the background
  void _handleRemoteCallEnded() {
    debugPrint('CallProvider: Remote call end detected from background');

    // Update the call state to ended
    _updateCallState(CallState.ended);

    // Clean up other resources
    _callTimer?.cancel();
    _callTimer = null;
    _callDurationSeconds = 0;
    _updateCallDurationText();

    // Reset remote user ID
    _remoteUid = null;

    // Reset state with a small delay to allow animations to complete
    Future.delayed(const Duration(milliseconds: 500), () {
      _updateCallState(CallState.idle);
      _currentCall = {};
      _connectionErrorMessage = "";
    });

    // Leave the Agora channel
    _agoraService.leaveChannel();
  }

  /// Update the background service when call attributes change
  Future<void> _updateBackgroundService() async {
    if (_backgroundCallService.isBackgroundServiceRunning) {
      try {
        final callerName = _currentCall['sender_name'] ?? 'Unknown Caller';
        final callerAvatar = _currentCall['sender_photo'];
        final senderUid = _currentCall['sender_uid'];

        await _backgroundCallService.updateCallAttributes(
          callerName: callerName,
          callerAvatar: callerAvatar,
          senderUid: senderUid,
          isAudioMuted: _isAudioMuted,
        );
      } catch (e) {
        debugPrint('CallProvider: Error updating background service - $e');
      }
    }
  }

  /// Stop the background service
  Future<void> _stopBackgroundService() async {
    try {
      await _backgroundCallService.stopBackgroundService(
        showEndedNotification: true,
      );
      debugPrint('CallProvider: Background service stopped');
    } catch (e) {
      debugPrint('CallProvider: Error stopping background service - $e');
    }
  }

  /// Handle a user joining the channel
  void _handleUserJoined(UserJoinedEvent event) {
    debugPrint('CallProvider: User joined - ${event.uid}');

    // Track the remote user ID
    _remoteUid = event.uid;
    notifyListeners();
  }

  /// Handle a user leaving the channel
  void _handleUserOffline(UserOfflineEvent event) {
    debugPrint(
      'CallProvider: User offline - ${event.uid}, reason: ${event.reason}',
    );

    // Clear remote user ID if it matches the user who left
    if (_remoteUid == event.uid) {
      _remoteUid = null;
      notifyListeners();
    }

    // End the call if we were connected and the last remote user left
    if (_callState == CallState.connected) {
      // Check if there are any remaining remote users
      final remoteUsers = _agoraService.remoteUsers;
      if (remoteUsers.isEmpty) {
        debugPrint('CallProvider: No more remote users, ending call');

        // If background service is running, mark call as ended by remote
        if (_backgroundCallService.isBackgroundServiceRunning) {
          // End call with remote ended flag to ensure proper notification
          endCall(remoteEnded: true);
        } else {
          // If background service isn't running, just end the call normally
          endCall();
        }
      }
    }
  }

  /// Start a call timer to track call duration
  void _startCallTimer() {
    _callDurationSeconds = 0;
    _updateCallDurationText();

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      _updateCallDurationText();
    });
  }

  /// Update the call duration text
  void _updateCallDurationText() {
    final hours = _callDurationSeconds ~/ 3600;
    final minutes = (_callDurationSeconds % 3600) ~/ 60;
    final seconds = _callDurationSeconds % 60;

    String timeText;
    if (hours > 0) {
      timeText =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      timeText =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    _callDurationText = timeText;
    notifyListeners();
  }

  /// Toggle microphone mute state
  Future<void> toggleMute() async {
    try {
      await _agoraService.muteLocalAudio(!_isAudioMuted);
      _isAudioMuted = !_isAudioMuted;

      // Update background service with new mute state
      _updateBackgroundService();

      notifyListeners();
      debugPrint(
        'CallProvider: Microphone ${_isAudioMuted ? 'muted' : 'unmuted'}',
      );
    } catch (e) {
      debugPrint('CallProvider: Error toggling mute - $e');
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    try {
      await _agoraService.setEnableSpeakerphone(!_isSpeakerEnabled);
      _isSpeakerEnabled = !_isSpeakerEnabled;
      notifyListeners();
      debugPrint(
        'CallProvider: Speaker ${_isSpeakerEnabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('CallProvider: Error toggling speaker - $e');
    }
  }

  /// Retry failed connection
  Future<void> retryConnection() async {
    try {
      debugPrint('CallProvider: Retrying connection with data: $_currentCall');

      if (_currentCall.isEmpty) {
        debugPrint('CallProvider: No call data available for retry');
        return;
      }

      // Reset error message
      _connectionErrorMessage = "";

      // Update state to connecting
      _updateCallState(CallState.connecting);

      // Make sure Agora engine is reset
      await _agoraService.destroy();
      await _agoraService.initialize();

      // Extract token information
      final token = _currentCall['agora_token'] as String? ?? '';
      final channelId = _currentCall['agora_channel'] as String? ?? '';
      final uidString = _currentCall['agora_uid'] as String? ?? '';

      if (token.isEmpty || channelId.isEmpty || uidString.isEmpty) {
        debugPrint('CallProvider: Missing required call information for retry');
        _connectionErrorMessage = "Missing call information. Cannot retry.";
        _updateCallState(CallState.connectionFailed);
        return;
      }

      // Convert UID
      final int uid = int.tryParse(uidString.toString()) ?? 0;

      if (uid <= 0) {
        debugPrint('CallProvider: Invalid UID for retry: $uidString');
        _connectionErrorMessage = "Invalid user ID. Cannot retry.";
        _updateCallState(CallState.connectionFailed);
        return;
      }

      // Try to join again
      final success = await _agoraService.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid,
        enableAudio: true,
      );

      if (success) {
        debugPrint('CallProvider: Retry connection request sent');
        // Wait for join success event to update state

        // Add a backup timer in case success event doesn't come
        Timer(const Duration(seconds: 5), () {
          if (_callState == CallState.connecting) {
            _connectionErrorMessage =
                "Connection retry timed out. Please try again.";
            _updateCallState(CallState.connectionFailed);
          }
        });
      } else {
        debugPrint('CallProvider: Retry connection request failed');
        _connectionErrorMessage =
            "Failed to retry connection. Please try again.";
        _updateCallState(CallState.connectionFailed);
      }
    } catch (e) {
      debugPrint('CallProvider: Error in retry connection - $e');
      _connectionErrorMessage = "Error: $e";
      _updateCallState(CallState.connectionFailed);
    }
  }

  /// End the current call
  Future<void> endCall({bool remoteEnded = false}) async {
    try {
      debugPrint('CallProvider: Ending call, remote ended: $remoteEnded');
      await _agoraService.leaveChannel();

      // Get caller name before clearing call data to ensure we have it for notifications
      final callerName = _currentCall['sender_name'] ?? 'Unknown';

      // Stop background service and show ended notification
      // Pass the remote-ended flag to ensure consistent notification handling
      await _backgroundCallService.stopBackgroundService(
        showEndedNotification: true,
        remoteEnded: remoteEnded,
        callerName: callerName,
      );

      _updateCallState(CallState.ended);
      _callTimer?.cancel();
      _callTimer = null;
      _callDurationSeconds = 0;
      _updateCallDurationText();

      // Reset remote user ID
      _remoteUid = null;

      // Reset state with a small delay to allow animations to complete
      Future.delayed(const Duration(milliseconds: 500), () {
        _updateCallState(CallState.idle);
        _currentCall = {};
        _connectionErrorMessage = "";
      });
    } catch (e) {
      debugPrint('CallProvider: Error ending call - $e');
    }
  }

  /// Dispose of resources
  @override
  void dispose() {
    _callTimer?.cancel();
    _roomInvitationSubscription?.cancel();
    _userJoinedSubscription?.cancel();
    _userOfflineSubscription?.cancel();
    _joinChannelSuccessSubscription?.cancel();
    _callStateController.close();
    _stopBackgroundService(); // Ensure background service is stopped
    super.dispose();
  }

  // Update call state with notification
  void _updateCallState(CallState newState) {
    _callState = newState;
    _callStateController.add(newState);
    notifyListeners();
  }

  /// Set current call data
  void setCallData(Map<String, dynamic> callData) {
    _currentCall = callData;
    notifyListeners();
  }

  /// Synchronize button states based on call type and settings
  void syncButtonStates() {
    if (_callState == CallState.connected) {
      // For call initiator, ensure their mic is unmuted by default
      _isAudioMuted = false;

      // Notify listeners of state changes
      notifyListeners();

      debugPrint(
        'CallProvider: Button states synchronized - audio muted: $_isAudioMuted',
      );
    }
  }

  /// Start a call with the given data
  void startCall(Map<String, dynamic> callData) {
    // Set call data
    setCallData(callData);

    // Update call state to connected
    _updateCallState(CallState.connected);

    // Sync button states
    syncButtonStates();

    // Start call timer
    _startCallTimer();

    // Start background service
    _startBackgroundService();
  }
}
