import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/call_data.dart';
import '../../../core/services/agora/agora_service.dart';

class CallProvider with ChangeNotifier {
  static const MethodChannel _methodChannel = MethodChannel('com.duckbuck.app/call');
  
  CallData? _currentCall;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Speaker is on by default for calls

  // Getters
  CallData? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

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
          final isMuted = call.arguments['isMuted'] as bool? ?? true;  
          
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
    _isMuted = isMuted; // Use the actual mute state from Kotlin
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

  /// Toggle speaker on/off
  Future<void> toggleSpeaker() async {
    try {
      if (_isSpeakerOn) {
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
 

  /// Clear call state (for cleanup)
  void clearCallState() {
    _currentCall = null;
    _isInCall = false;
    _isMuted = false;
    _isSpeakerOn = true;
    notifyListeners();
  }
}
