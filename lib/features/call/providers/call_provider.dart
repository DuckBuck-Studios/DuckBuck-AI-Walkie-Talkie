import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/call_data.dart';
import '../../../core/services/call/agora_service.dart';

class CallProvider with ChangeNotifier {
  static const MethodChannel _methodChannel = MethodChannel('com.duckbuck.app/call');
  
  CallData? _currentCall;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isSpeakerOn = true; // Speaker is on by default for calls
  Duration _callDuration = Duration.zero;
  DateTime? _callStartTime;

  // Getters
  CallData? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  Duration get callDuration => _callDuration;

  CallProvider() {
    _setupMethodChannelHandler();
  }

  /// Setup method channel handler to receive calls from Kotlin
  void _setupMethodChannelHandler() {
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'showCallUI':
          final callerName = call.arguments['callerName'] as String?;
          final callerPhotoUrl = call.arguments['callerPhotoUrl'] as String?;
          final isMuted = call.arguments['isMuted'] as bool? ?? true; // Default to muted
          
          if (callerName != null) {
            _showCallUI(CallData(
              callerName: callerName,
              callerPhotoUrl: callerPhotoUrl,
            ), isMuted);
          }
          break;
        
        case 'dismissCallUI':
          _dismissCallUI();
          break;
      }
    });
  }

  /// Show call UI (called from Kotlin via method channel)
  void _showCallUI(CallData callData, bool isMuted) {
    _currentCall = callData;
    _isInCall = true;
    _callStartTime = DateTime.now();
    _isMuted = isMuted; // Use the actual mute state from Kotlin
    _isVideoEnabled = false; // Default to video off
    _isSpeakerOn = true; // Default to speaker on
    
    // Start call duration timer
    _startCallTimer();
    
    notifyListeners();
  }

  /// Dismiss call UI (called from Kotlin via method channel)
  void _dismissCallUI() {
    _currentCall = null;
    _isInCall = false;
    _isMuted = false;
    _isVideoEnabled = false;
    _isSpeakerOn = true;
    _callDuration = Duration.zero;
    _callStartTime = null;
    
    notifyListeners();
  }

  /// End call (sends request to Kotlin)
  Future<void> endCall() async {
    try {
      // Send end call request to Kotlin
      await AgoraService.leaveChannel();
      
      // Don't clear state here - wait for Kotlin to call dismissCallUI
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  /// Toggle microphone mute/unmute
  Future<void> toggleMute() async {
    try {
      if (_isMuted) {
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

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    try {
      if (_isVideoEnabled) {
        final result = await AgoraService.turnVideoOff();
        if (result) {
          _isVideoEnabled = false;
          notifyListeners();
        }
      } else {
        final result = await AgoraService.turnVideoOn();
        if (result) {
          _isVideoEnabled = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error toggling video: $e');
    }
  }

  /// Toggle speaker on/off
  /// Note: This is a UI state toggle. The actual speaker control
  /// would need additional native implementation
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
  }

  /// Start the call duration timer
  void _startCallTimer() {
    // Update call duration every second
    Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (_isInCall && _callStartTime != null) {
        _callDuration = DateTime.now().difference(_callStartTime!);
        notifyListeners();
      }
    });
  }

  /// Format call duration as MM:SS
  String get formattedCallDuration {
    final minutes = _callDuration.inMinutes.toString().padLeft(2, '0');
    final seconds = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Clear call state (for cleanup)
  void clearCallState() {
    _currentCall = null;
    _isInCall = false;
    _isMuted = false;
    _isVideoEnabled = false;
    _isSpeakerOn = true;
    _callDuration = Duration.zero;
    _callStartTime = null;
    notifyListeners();
  }
}
