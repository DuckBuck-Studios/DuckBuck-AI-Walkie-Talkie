import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/services/agora/agora_service.dart';

/// CallProvider - Manages call state and handles CallUIBridge method channel communication
class CallProvider extends ChangeNotifier {
  static const MethodChannel _callUIChannel = MethodChannel('com.duckbuck.app/call_ui');
  
  // Call state
  bool _isCallActive = false;
  String? _callType; // 'incoming' or 'outgoing'
  String? _channelId;
  String? _callerName;
  String? _callerPhoto;
  String? _agoraToken;
  String? _agoraUid;
  
  // Audio controls state
  bool _isMuted = true; // Start muted (receiver side)
  bool _isSpeakerEnabled = true; // Start with speaker enabled for walkie-talkie
  
  // Services
  final AgoraService _agoraService = AgoraService.instance;
  
  // Getters
  bool get isCallActive => _isCallActive;
  String? get callType => _callType;
  String? get channelId => _channelId;
  String? get callerName => _callerName;
  String? get callerPhoto => _callerPhoto;
  String? get agoraToken => _agoraToken;
  String? get agoraUid => _agoraUid;
  bool get isMuted => _isMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  
  CallProvider() {
    _setupMethodChannelHandler();
  }
  
  /// Setup method channel handler to receive calls from native CallUIBridge
  void _setupMethodChannelHandler() {
    _callUIChannel.setMethodCallHandler((MethodCall call) async {
      debugPrint('📞 CallProvider received method: ${call.method}');
      
      switch (call.method) {
        case 'showCallUI':
          _handleShowCallUI(call.arguments);
          break;
        case 'hideCallUI':
          _handleHideCallUI(call.arguments);
          break;
        case 'onCallFailed':
          _handleCallFailed(call.arguments);
          break;
        case 'updateCallState':
          _handleUpdateCallState(call.arguments);
          break;
        case 'checkActiveCall':
          _handleCheckActiveCall();
          break;
        default:
          debugPrint('⚠️ Unknown method: ${call.method}');
      }
    });
  }
  
  /// Handle showCallUI from native bridge
  void _handleShowCallUI(dynamic arguments) {
    try {
      final data = Map<String, dynamic>.from(arguments);
      
      _callType = data['callType'] as String?;
      _channelId = data['channelId'] as String?;
      _callerName = data['callerName'] as String?;
      _callerPhoto = data['callerPhoto'] as String?;
      _agoraToken = data['agoraToken'] as String?;
      _agoraUid = data['agoraUid'] as String?;
      
      // Set initial audio state for walkie-talkie experience
      _isMuted = true; // Start muted
      _isSpeakerEnabled = true; // Start with speaker enabled
      
      _isCallActive = true;
      
      debugPrint('📞 Call UI triggered: $data');
      debugPrint('📞 Caller: $_callerName, Type: $_callType');
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error handling showCallUI: $e');
    }
  }
  
  /// Handle hideCallUI from native bridge
  void _handleHideCallUI(dynamic arguments) {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final reason = data['reason'] as String?;
      
      debugPrint('🚪 Hiding call UI, reason: $reason');
      
      _endCall();
      
    } catch (e) {
      debugPrint('❌ Error handling hideCallUI: $e');
    }
  }
  
  /// Handle call failure from native bridge
  void _handleCallFailed(dynamic arguments) {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final reason = data['reason'] as String?;
      final errorMessage = data['errorMessage'] as String?;
      
      debugPrint('❌ Call failed: $reason - $errorMessage');
      
      _endCall();
      
    } catch (e) {
      debugPrint('❌ Error handling call failed: $e');
    }
  }
  
  /// Handle call state update from native bridge
  void _handleUpdateCallState(dynamic arguments) {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final state = data['state'] as String?;
      
      debugPrint('📊 Call state updated: $state');
      
      // Handle different call states if needed
      // For now, just log the state
      
    } catch (e) {
      debugPrint('❌ Error handling call state update: $e');
    }
  }
  
  /// Handle check active call from native bridge
  void _handleCheckActiveCall() {
    debugPrint('🔍 Native requested active call check');
    
    // If we have an active call, we can respond back to native if needed
    if (_isCallActive) {
      debugPrint('✅ Flutter has active call: $_callerName');
    } else {
      debugPrint('🚫 Flutter has no active call');
    }
  }
  
  /// Show outgoing call UI (for initiator scenarios)
  void showOutgoingCallUI({
    required String channelId,
    required String friendName,
    required String? friendPhoto,
    required String agoraToken,
    required String agoraUid,
  }) {
    _callType = 'outgoing';
    _channelId = channelId;
    _callerName = friendName;
    _callerPhoto = friendPhoto;
    _agoraToken = agoraToken;
    _agoraUid = agoraUid;
    
    // Set initial audio state for walkie-talkie experience
    _isMuted = true; // Start muted
    _isSpeakerEnabled = true; // Start with speaker enabled
    
    _isCallActive = true;
    
    debugPrint('📞 Outgoing call UI triggered: $friendName');
    
    notifyListeners();
  }
  
  /// Toggle mute state
  Future<void> toggleMute() async {
    try {
      final newMutedState = !_isMuted;
      final success = await _agoraService.muteLocalAudio(newMutedState);
      
      if (success) {
        _isMuted = newMutedState;
        debugPrint('🎤 Mute toggled: ${_isMuted ? "Muted" : "Unmuted"}');
        notifyListeners();
      } else {
        debugPrint('❌ Failed to toggle mute');
      }
    } catch (e) {
      debugPrint('❌ Error toggling mute: $e');
    }
  }
  
  /// Toggle speaker state
  Future<void> toggleSpeaker() async {
    try {
      final newSpeakerState = !_isSpeakerEnabled;
      final success = await _agoraService.setSpeakerphoneEnabled(newSpeakerState);
      
      if (success) {
        _isSpeakerEnabled = newSpeakerState;
        debugPrint('🔊 Speaker toggled: ${_isSpeakerEnabled ? "Enabled" : "Disabled"}');
        notifyListeners();
      } else {
        debugPrint('❌ Failed to toggle speaker');
      }
    } catch (e) {
      debugPrint('❌ Error toggling speaker: $e');
    }
  }
  
  /// End the current call
  Future<void> endCall() async {
    debugPrint('📞 User ended call');
    
    try {
      // Leave Agora channel
      await _agoraService.leaveChannel();
      
      // Clear local state
      _endCall();
      
    } catch (e) {
      debugPrint('❌ Error ending call: $e');
      _endCall(); // Still clear state even if Agora fails
    }
  }
  
  /// Internal method to clear call state
  void _endCall() {
    _isCallActive = false;
    _callType = null;
    _channelId = null;
    _callerName = null;
    _callerPhoto = null;
    _agoraToken = null;
    _agoraUid = null;
    _isMuted = true;
    _isSpeakerEnabled = true;
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _callUIChannel.setMethodCallHandler(null);
    super.dispose();
  }
}
