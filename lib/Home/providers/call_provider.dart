import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../fcm_service/fcm_service.dart';
import '../service/agora_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum CallState {
  idle,
  calling,
  connected,
  ended,
  missed,
  error,
}

class CallProvider extends ChangeNotifier {
  final AgoraService _agoraService = AgoraService();

  // Call state
  CallState _callState = CallState.idle;
  String? _channelName;
  String? _callerName;
  String? _callerId;
  String? _callerProfileUrl;
  String? _receiverName;
  String? _receiverId;
  bool _isMuted = true; // Default to muted for receiver
  bool _isSpeakerOn = true;
  bool _isInitiator = false; // Track if user is the call initiator
  bool _isSpeaking = false; // Track push-to-talk state
  bool _hasStartedSpeaking = false; // Track if receiver has started speaking
  DateTime? _callStartTime;
  String _callDuration = '00:00';
  String? _errorMessage;

  // Getters
  CallState get callState => _callState;
  String? get channelName => _channelName;
  String? get callerName => _callerName;
  String? get callerId => _callerId;
  String? get callerProfileUrl => _callerProfileUrl;
  String? get receiverName => _receiverName;
  String? get receiverId => _receiverId;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String get callDuration => _callDuration;
  String? get errorMessage => _errorMessage;
  bool get isInCall => _callState == CallState.connected;
  bool get isCalling => _callState == CallState.calling;
  bool get isInitiator => _isInitiator;
  bool get isSpeaking => _isSpeaking;
  bool get hasStartedSpeaking => _hasStartedSpeaking;

  // Initialize call as caller
  Future<void> initiateCall({
    required String receiverId,
    required String receiverName,
    required String channelName,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _setError('User not authenticated');
        return;
      }

      debugPrint('🎯 Initiating call as caller');
      _isInitiator = true;
      _isMuted = false; // Caller starts unmuted
      _channelName = channelName;
      _callerName = currentUser.displayName ?? 'Unknown';
      _callerId = currentUser.uid;
      _callerProfileUrl = currentUser.photoURL;
      _receiverId = receiverId;
      _receiverName = receiverName;
      _callState = CallState.calling;
      notifyListeners();

      // Send FCM notification to receiver
      final success = await FCMService.sendCallNotificationToUser(
        receiverUid: receiverId,
        callerName: _callerName!,
        callerId: _callerId!,
        channelName: channelName,
      );

      if (!success) {
        _setError('Failed to reach receiver');
        return;
      }

      // Join the channel as caller
      await _joinChannel(channelName);
      debugPrint('✅ Call initiated successfully');
    } catch (e) {
      _setError('Error initiating call: $e');
    }
  }

  // Handle incoming call for receiver
  Future<void> handleIncomingCall({
    required String channelName,
    required String callerName,
    required String callerId,
  }) async {
    debugPrint('📞 Handling incoming call:');
    debugPrint('🎯 Channel: $channelName');
    debugPrint('👤 Caller: $callerName');
    debugPrint('🆔 Caller ID: $callerId');

    try {
      // Reset any existing call state first
      _resetCallState();

      // Set new call state for receiver
      _isInitiator = false;
      _isMuted = true; // Receiver starts muted
      _isSpeaking = false;
      _hasStartedSpeaking = false;
      _channelName = channelName;
      _callerName = callerName;
      _callerId = callerId;
      _callState = CallState.connected;

      // Completely disable microphone for receiver initially
      await _agoraService.disableAudio();

      notifyListeners();

      // Join the channel as receiver
      await _joinChannel(channelName);
      debugPrint('✅ Receiver joined call successfully');
    } catch (e) {
      debugPrint('❌ Error handling incoming call: $e');
      _setError('Error handling incoming call: $e');
    }
  }

  // Start speaking (push-to-talk)
  Future<void> startSpeaking() async {
    if (_isInitiator) return; // Only for receivers

    debugPrint('🎤 Starting to speak...');
    _isSpeaking = true;
    _isMuted = false;
    _hasStartedSpeaking = true;
    await _agoraService.enableAudio(); // Enable audio when starting to speak
    notifyListeners();
    debugPrint('✅ Microphone enabled for speaking');
  }

  // Stop speaking (push-to-talk)
  Future<void> stopSpeaking() async {
    if (_isInitiator) return; // Only for receivers

    debugPrint('🎤 Stopping speaking...');
    _isSpeaking = false;
    _isMuted = true;
    await _agoraService
        .disableAudio(); // Completely disable audio when not speaking
    notifyListeners();
    debugPrint('✅ Microphone disabled after speaking');
  }

  // Join channel with mute state
  Future<void> _joinChannel(String channelName) async {
    try {
      await _agoraService.initializeAgora();

      // Set callbacks for call end scenarios
      _agoraService.setOnUserOfflineCallback(() {
        debugPrint('Remote user left the channel, ending call...');
        if (_callState != CallState.idle && _callState != CallState.ended) {
          _handleCallEnd();
        }
      });

      await _agoraService.configureAudioSession();
      await _agoraService.joinChannel(channelName, _generateUID());

      // Set initial audio state
      if (!_isInitiator) {
        await _agoraService
            .disableAudio(); // Ensure receiver starts with audio disabled
      }

      if (_callState != CallState.ended) {
        _callState = CallState.connected;
        _startCallTimer();
        notifyListeners();
      }
    } catch (e) {
      _setError('Error joining channel: $e');
    }
  }

  // Handle call end from any source
  Future<void> _handleCallEnd() async {
    if (_callState == CallState.idle || _callState == CallState.ended) {
      debugPrint('🚫 Call already ended or idle, ignoring end request');
      return;
    }

    try {
      debugPrint('🔄 Handling call end...');

      // Set call state to ended immediately
      _callState = CallState.ended;
      notifyListeners();

      // Leave the channel
      try {
        await _agoraService.leaveChannel();
        debugPrint('✅ Successfully left Agora channel');
      } catch (e) {
        debugPrint('⚠️ Error leaving channel: $e');
      }

      // Reset state and update UI
      _resetCallState();
      notifyListeners();
      debugPrint('✅ Call ended and UI reset successfully');
    } catch (e) {
      debugPrint('❌ Error handling call end: $e');
      _setError('Error ending call: $e');
      _resetCallState();
      notifyListeners();
    }
  }

  // End call (user initiated)
  Future<void> endCall() async {
    debugPrint('👤 User initiated call end');
    await _handleCallEnd();
  }

  // Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _agoraService.toggleMute(_isMuted);
    notifyListeners();
  }

  // Toggle speaker
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _agoraService.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  // Start call timer
  void _startCallTimer() {
    debugPrint('⏱️ Initializing call timer');
    _callStartTime = DateTime.now();
    debugPrint(
        '🕐 Call start time set to: ${_callStartTime?.toIso8601String()}');

    // Update call duration every second
    Future.doWhile(() async {
      if (_callState != CallState.connected) {
        debugPrint('⏹️ Call timer stopped: call state is not connected');
        return false;
      }

      final duration = DateTime.now().difference(_callStartTime!);
      _callDuration = _formatDuration(duration);
      debugPrint('⏱️ Call duration updated: $_callDuration');
      notifyListeners();

      await Future.delayed(const Duration(seconds: 1));
      return _callState == CallState.connected;
    });
  }

  // Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Generate UID
  int _generateUID() {
    return 100000 + DateTime.now().millisecondsSinceEpoch % 900000;
  }

  // Set error state
  void _setError(String message) {
    debugPrint('❌ Setting error state: $message');
    _errorMessage = message;
    _callState = CallState.error;
    notifyListeners();
    debugPrint('✅ Error state set and listeners notified');
  }

  // Reset call state with notification
  void _resetCallState() {
    debugPrint('🔄 Resetting call state');

    // Save temporary values for logging
    final wasInitiator = _isInitiator;
    final previousState = _callState;

    // Reset all state variables
    _callState = CallState.idle;
    _channelName = null;
    _callerName = null;
    _callerId = null;
    _callerProfileUrl = null;
    _receiverName = null;
    _receiverId = null;
    _isMuted = true;
    _isSpeakerOn = true;
    _isInitiator = false;
    _isSpeaking = false;
    _hasStartedSpeaking = false;
    _callStartTime = null;
    _callDuration = '00:00';
    _errorMessage = null;

    debugPrint(
        '✅ Call state reset complete (was initiator: $wasInitiator, previous state: $previousState)');
    notifyListeners();
  }

  @override
  void dispose() {
    endCall();
    super.dispose();
  }
}
