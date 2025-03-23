import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/agora_service.dart';

enum CallStatus {
  idle,
  connecting,
  connected,
  disconnected,
}

enum CallRole {
  none,
  initiator,
  receiver,
}

class CallProvider with ChangeNotifier {
  // Call state
  CallStatus _status = CallStatus.idle;
  CallRole _role = CallRole.none;
  Map<String, dynamic> _currentCallData = {};
  bool _isMuted = true;
  bool _isVideoEnabled = false;
  bool _isSpeakerOn = true;
  Set<int> _remoteUsers = {};
  
  // Agora service
  final AgoraService _agoraService = AgoraService();
  
  // Stream controllers
  final StreamController<Set<int>> _remoteUsersController = StreamController.broadcast();
  
  // Getters
  CallStatus get status => _status;
  CallRole get role => _role;
  Map<String, dynamic> get currentCallData => _currentCallData;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isInCall => _status != CallStatus.idle;
  Set<int> get remoteUsers => _remoteUsers;
  Stream<Set<int>> get onRemoteUsersChanged => _remoteUsersController.stream;
  
  // Constructor - Setup event listeners
  CallProvider() {
    _setupEventListeners();
  }
  
  void _setupEventListeners() {
    // Listen for users joining the channel
    _agoraService.onUserJoined.listen((data) {
      final int uid = data['uid'] as int;
      _remoteUsers.add(uid);
      _remoteUsersController.add(_remoteUsers);
      notifyListeners();
      debugPrint('Call: Remote user joined: $uid');
    });
    
    // Listen for users leaving the channel
    _agoraService.onUserLeft.listen((data) {
      final int uid = data['uid'] as int;
      _remoteUsers.remove(uid);
      _remoteUsersController.add(_remoteUsers);
      notifyListeners();
      debugPrint('Call: Remote user left: $uid');
      
      // If all remote users left, consider ending the call
      if (_remoteUsers.isEmpty && _status == CallStatus.connected) {
        debugPrint('Call: All remote users left, ending call');
        endCall();
      }
    });
    
    // Listen for successful channel join
    _agoraService.onJoinChannelSuccess.listen((data) {
      debugPrint('Call: Successfully joined channel: ${data['channel']}');
      _status = CallStatus.connected;
      notifyListeners();
    });
    
    // Listen for connection state changes
    _agoraService.onConnectionStateChanged.listen((data) {
      final int state = data['state'] as int;
      debugPrint('Call: Connection state changed to: $state');
      
      // Update UI based on connection state
      if (state == 1) { // Connected
        _status = CallStatus.connected;
      } else if (state == 5) { // Failed
        _status = CallStatus.disconnected;
      }
      notifyListeners();
    });
    
    // Listen for leave channel events
    _agoraService.onLeaveChannel.listen((data) {
      debugPrint('Call: Left channel');
      _resetState();
      notifyListeners();
    });
    
    // Listen for errors
    _agoraService.onError.listen((data) {
      final int errorCode = data['errorCode'] as int;
      debugPrint('Call: Error occurred: $errorCode');
      
      // Handle specific errors
      switch (errorCode) {
        case -17: // Typically a permission or resource issue
          debugPrint('Call: Permission denied or resource unavailable');
          // Show an error in the app
          _status = CallStatus.disconnected;
          notifyListeners();
          break;
        case -20: // Audio recording error
          debugPrint('Call: Audio recording error - microphone might be unavailable');
          // Continue with call but disable mic
          _isMuted = true;
          notifyListeners();
          break;
        default:
          if (_status == CallStatus.connecting) {
            debugPrint('Call: Failed to connect due to error: $errorCode');
            _status = CallStatus.disconnected;
            notifyListeners();
          }
      }
    });
    
    // Listen for token expiration
    _agoraService.onTokenExpired.listen((data) {
      debugPrint('Call: Token expired');
      // Handle token refresh here if needed
    });
  }
  
  // Start a new call as initiator
  Future<bool> startCall(Map<String, dynamic> callData) async {
    debugPrint('Call: Starting call as initiator with data: $callData');
    
    // Update state
    _currentCallData = callData;
    _status = CallStatus.connecting;
    _role = CallRole.initiator;
    notifyListeners();
    
    // Connect to the call
    return connectToCall();
  }
  
  // Handle incoming call as receiver
  void handleIncomingCall(Map<String, dynamic> callData) async {
    // Log complete call data for debugging
    debugPrint('Call: Handling incoming call with data: $callData');
    
    // Extract channel ID from FCM data format
    final String channelId = callData['channel_id'] ?? callData['channelId'] ?? '';
    
    // Ensure we have a caller ID, or generate one if missing
    if (!callData.containsKey('sender_uid') && !callData.containsKey('callerUid')) {
      debugPrint('Call: Missing caller ID in call data, generating fallback ID');
      
      // Use channelName as a fallback identifier if available
      if (channelId.isNotEmpty) {
        callData['callerUid'] = 'channel-$channelId';
        debugPrint('Call: Generated fallback caller ID: ${callData['callerUid']}');
      } else {
        // Last resort: use timestamp
        callData['callerUid'] = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('Call: Generated timestamp-based caller ID: ${callData['callerUid']}');
      }
    }
    
    // Ensure we have a caller ID in consistent format
    if (callData.containsKey('sender_uid') && !callData.containsKey('callerUid')) {
      callData['callerUid'] = callData['sender_uid'];
    }
    
    // Ensure we have a caller name
    if (!callData.containsKey('callerName') || callData['callerName'] == null || callData['callerName'].toString().isEmpty) {
      callData['callerName'] = 'Unknown Caller';
      debugPrint('Call: Using default caller name: ${callData['callerName']}');
    }
    
    // Ensure we have a channel ID in the call data
    if (channelId.isNotEmpty) {
      callData['channelName'] = channelId;
    }
    
    // Add dummy token if missing (for testing)
    if (!callData.containsKey('token') || callData['token'] == null || callData['token'].toString().isEmpty) {
      callData['token'] = 'dummy_token';
    }
    
    // Add dummy UID if missing
    if (!callData.containsKey('uid') || callData['uid'] == null) {
      callData['uid'] = DateTime.now().millisecondsSinceEpoch % 100000;
    }
    
    // Update state
    _currentCallData = callData;
    _status = CallStatus.connecting;
    _role = CallRole.receiver;
    notifyListeners();
    
    // Automatically join the channel
    await connectToCall();
  }
  
  // Connect to call
  Future<bool> connectToCall() async {
    // Validate channel ID checking all possible formats from FCM
    final String channelId = _currentCallData['channelId'] ?? 
                             _currentCallData['channel_id'] ?? 
                             _currentCallData['channelName'] ??
                             _currentCallData['agora_channel'] ?? '';
    
    if (channelId.isEmpty) {
      debugPrint('Call: Cannot connect - missing channel ID');
      debugPrint('Call: Available call data keys: ${_currentCallData.keys.join(', ')}');
      return false;
    }
    
    // Ensure channelName is consistently set
    _currentCallData['channelName'] = channelId;
    
    // Log connection attempt
    debugPrint('Call: Connecting to channel: $channelId');
    debugPrint('Call: Complete call data: $_currentCallData');
    
    try {
      // Initialize engine
      final engineInitialized = await _agoraService.initializeEngine();
      if (!engineInitialized) {
        debugPrint('Call: Failed to initialize Agora engine');
        return false;
      }
      
      // Join the channel
      final success = await _agoraService.joinChannel(
        token: '',  // Using app ID auth for simplicity
        channelName: channelId,
        userId: 0,  // Let Agora assign a user ID
        muteOnJoin: _isMuted, // Use current mute setting
      );
      
      // Handle join result
      if (!success) {
        debugPrint('Call: Failed to join channel');
        
        // Try one more time with different settings
        final retrySuccess = await _agoraService.joinChannel(
          token: '',
          channelName: channelId,
          userId: 0,
          muteOnJoin: true, // Force mute on retry
        );
        
        if (!retrySuccess) {
          _status = CallStatus.disconnected;
          notifyListeners();
          return false;
        }
      }
      
      debugPrint('Call: Successfully joined channel');
      _status = CallStatus.connecting; // Will transition to connected when join success event fires
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Call: Exception during connection: $e');
      _status = CallStatus.disconnected;
      notifyListeners();
      return false;
    }
  }
  
  // End an ongoing call
  Future<void> endCall() async {
    debugPrint('Call: Ending call');
    await _agoraService.leaveChannel();
    _resetState();
    notifyListeners();
  }
  
  // Toggle microphone mute
  Future<bool> toggleMute() async {
    try {
      // Log current state
      debugPrint('Call: Toggling microphone from ${_isMuted ? "muted" : "unmuted"} to ${!_isMuted ? "muted" : "unmuted"}');
      
      // If we're not in a call, don't perform the toggle
      if (_status != CallStatus.connected && _status != CallStatus.connecting) {
        debugPrint('Call: Cannot toggle mic - not in an active call (status: $_status)');
        return false;
      }
      
      // Toggle mute state
      final newMuteState = !_isMuted;
      
      // Call native method
      final success = await _agoraService.muteLocalAudio(newMuteState);
      
      // Only update state if the operation succeeded
      if (success == true) {
        _isMuted = newMuteState;
        notifyListeners();
        debugPrint('Call: Microphone ${_isMuted ? "muted" : "unmuted"} successfully');
        return true;
      } else {
        debugPrint('Call: Failed to ${newMuteState ? "mute" : "unmute"} microphone');
        return false;
      }
    } catch (e) {
      debugPrint('Call: Error toggling microphone: $e');
      return false;
    }
  }
  
  // Toggle video
  Future<bool> toggleVideo() async {
    try {
      // Log current state
      debugPrint('Call: Toggling video from ${_isVideoEnabled ? "enabled" : "disabled"} to ${!_isVideoEnabled ? "enabled" : "disabled"}');
      
      // If we're not in a call, don't perform the toggle
      if (_status != CallStatus.connected && _status != CallStatus.connecting) {
        debugPrint('Call: Cannot toggle video - not in an active call (status: $_status)');
        return false;
      }
      
      // Toggle video state
      final newVideoState = !_isVideoEnabled;
      
      // Call native method
      final success = await _agoraService.enableLocalVideo(newVideoState);
      
      // Only update state if the operation succeeded
      if (success == true) {
        _isVideoEnabled = newVideoState;
        notifyListeners();
        debugPrint('Call: Video ${_isVideoEnabled ? "enabled" : "disabled"} successfully');
        return true;
      } else {
        debugPrint('Call: Failed to ${newVideoState ? "enable" : "disable"} video');
        return false;
      }
    } catch (e) {
      debugPrint('Call: Error toggling video: $e');
      return false;
    }
  }
  
  // Toggle speaker
  Future<bool> toggleSpeaker() async {
    try {
      // Log current state
      debugPrint('Call: Toggling speaker from ${_isSpeakerOn ? "on" : "off"} to ${!_isSpeakerOn ? "on" : "off"}');
      
      // If we're not in a call, don't perform the toggle
      if (_status != CallStatus.connected && _status != CallStatus.connecting) {
        debugPrint('Call: Cannot toggle speaker - not in an active call (status: $_status)');
        return false;
      }
      
      // Toggle speaker state
      final newSpeakerState = !_isSpeakerOn;
      
      // Update state immediately for UI feedback, even if we can't control hardware
      _isSpeakerOn = newSpeakerState;
      notifyListeners();
      
      // Log success message
      debugPrint('Call: Speaker ${_isSpeakerOn ? "enabled" : "disabled"} in UI');
      return true;
    } catch (e) {
      debugPrint('Call: Error toggling speaker: $e');
      return false;
    }
  }
  
  // Test method to simulate an incoming call
  Future<void> testIncomingCall() async {
    // Create a test call data map
    final callData = {
      'token': 'test_token',
      'channelName': 'test-channel',
      'uid': 12345,
      'callerName': 'Test Caller',
      'callerPhoto': '',
      'callerUid': 'test-user-123',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Log the test call data
    debugPrint('Call: Testing incoming call with data: $callData');
    
    // Handle the test incoming call
    handleIncomingCall(callData);
  }
  
  // Test method with customizable caller ID for testing different matching scenarios
  Future<void> testIncomingCallWithId(String callerId, {String? callerName}) async {
    // Create a test call data map with the specified caller ID
    final callData = {
      'token': 'test_token',
      'channelName': 'test-channel-$callerId',
      'uid': 12345,
      'callerName': callerName ?? 'Test Caller ($callerId)',
      'callerPhoto': '',
      'callerUid': callerId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Log the test call data
    debugPrint('Call: Testing incoming call with custom ID: $callerId');
    
    // Handle the test incoming call
    handleIncomingCall(callData);
  }
  
  // Reset call state
  void _resetState() {
    debugPrint('Call: Resetting call state');
    _status = CallStatus.idle;
    _role = CallRole.none;
    _currentCallData = {};
    _remoteUsers.clear();
    _remoteUsersController.add(_remoteUsers);
    _isMuted = true;
    _isVideoEnabled = false;
    _isSpeakerOn = true;
  }
  
  @override
  void dispose() {
    // Clean up Agora resources
    _agoraService.cleanup();
    _agoraService.dispose();
    _remoteUsersController.close();
    super.dispose();
  }
} 