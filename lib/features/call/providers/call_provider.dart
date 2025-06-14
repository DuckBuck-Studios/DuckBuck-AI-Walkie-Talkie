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

  // Protected getters for subclasses
  CallData? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  // Protected setters for subclasses
  @protected
  set currentCall(CallData? value) {
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
      debugPrint('Error syncing with Agora state: $e');
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
