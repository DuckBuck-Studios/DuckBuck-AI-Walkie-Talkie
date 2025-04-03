import 'dart:async';
import 'package:flutter/services.dart';

/// AgoraRtcService provides an interface to the Agora RTC Engine for real-time audio and video communication.
/// This service acts as a bridge between the Flutter app and native Agora SDK.
class AgoraRtcService {
  // Singleton instance
  static final AgoraRtcService _instance = AgoraRtcService._internal();
  
  // Method channel for communication with platform-specific code
  final MethodChannel _channel = const MethodChannel('com.duckbuck/agora_rtc');
  
  // Event listeners
  final _userJoinedStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _userOfflineStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _joinChannelSuccessStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _localAudioStateStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _localVideoStateStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _remoteVideoStateStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _networkQualityStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _rtcStatsStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _localVideoViewCreatedStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _remoteVideoViewCreatedStreamController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Connection state tracking
  bool _isInitialized = false;
  bool _isInChannel = false;
  String? _currentChannel;
  int? _localUid;
  final Set<int> _remoteUsers = {};
  
  // Media state tracking
  bool _isLocalAudioEnabled = true;
  bool _isLocalVideoEnabled = false;
  bool _isLocalAudioMuted = false;
  bool _isLocalVideoMuted = false;
  bool _isSpeakerphoneEnabled = true;
  
  // Factory constructor returns singleton instance
  factory AgoraRtcService() {
    return _instance;
  }
  
  // Private constructor to initialize the service
  AgoraRtcService._internal() {
    _setupMethodCallHandler();
  }
  
  // Getters for connection state
  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  String? get currentChannel => _currentChannel;
  int? get localUid => _localUid;
  Set<int> get remoteUsers => Set.from(_remoteUsers);
  
  // Getters for media state
  bool get isLocalAudioEnabled => _isLocalAudioEnabled;
  bool get isLocalVideoEnabled => _isLocalVideoEnabled;
  bool get isLocalAudioMuted => _isLocalAudioMuted;
  bool get isLocalVideoMuted => _isLocalVideoMuted;
  bool get isSpeakerphoneEnabled => _isSpeakerphoneEnabled;
  
  // Stream getters for event listeners
  Stream<Map<String, dynamic>> get onUserJoined => _userJoinedStreamController.stream;
  Stream<Map<String, dynamic>> get onUserOffline => _userOfflineStreamController.stream;
  Stream<Map<String, dynamic>> get onJoinChannelSuccess => _joinChannelSuccessStreamController.stream;
  Stream<Map<String, dynamic>> get onConnectionStateChanged => _connectionStateStreamController.stream;
  Stream<Map<String, dynamic>> get onError => _errorStreamController.stream;
  Stream<Map<String, dynamic>> get onLocalAudioStateChanged => _localAudioStateStreamController.stream;
  Stream<Map<String, dynamic>> get onLocalVideoStateChanged => _localVideoStateStreamController.stream;
  Stream<Map<String, dynamic>> get onRemoteVideoStateChanged => _remoteVideoStateStreamController.stream;
  Stream<Map<String, dynamic>> get onNetworkQuality => _networkQualityStreamController.stream;
  Stream<Map<String, dynamic>> get onRtcStats => _rtcStatsStreamController.stream;
  Stream<Map<String, dynamic>> get onLocalVideoViewCreated => _localVideoViewCreatedStreamController.stream;
  Stream<Map<String, dynamic>> get onRemoteVideoViewCreated => _remoteVideoViewCreatedStreamController.stream;
  
  /// Initialize the Agora RTC Engine
  Future<bool> initialize(String appId, {bool enableVideo = false}) async {
    try {
      final result = await _channel.invokeMethod('initialize', {
        'appId': appId,
        'enableVideo': enableVideo,
      });
      _isInitialized = result ?? false;
      _isLocalVideoEnabled = enableVideo;
      return _isInitialized;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to initialize: $e'});
      return false;
    }
  }
  
  /// Join an audio/video channel
  Future<bool> joinChannel({
    required String channelName,
    String? token,
    int uid = 0,
    bool enableAudio = true,
    bool enableVideo = false,
  }) async {
    try {
      final result = await _channel.invokeMethod('joinChannel', {
        'token': token ?? '',
        'channelName': channelName,
        'uid': uid,
        'enableAudio': enableAudio,
        'enableVideo': enableVideo,
      });
      
      if (result == true) {
        _isLocalAudioEnabled = enableAudio;
        _isLocalVideoEnabled = enableVideo;
        _currentChannel = channelName;
        // Note: We'll get the actual UID from onJoinChannelSuccess callback
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to join channel: $e'});
      return false;
    }
  }
  
  /// Leave the current audio/video channel
  Future<bool> leaveChannel() async {
    try {
      final result = await _channel.invokeMethod('leaveChannel');
      
      if (result == true) {
        _isInChannel = false;
        _currentChannel = null;
        _remoteUsers.clear();
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to leave channel: $e'});
      return false;
    }
  }
  
  /// Enable or disable local audio capture and transmission
  Future<bool> enableLocalAudio(bool enabled) async {
    try {
      final result = await _channel.invokeMethod('enableLocalAudio', {
        'enabled': enabled,
      });
      
      if (result == true) {
        _isLocalAudioEnabled = enabled;
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to enable/disable local audio: $e'});
      return false;
    }
  }
  
  /// Mute or unmute local audio
  Future<bool> muteLocalAudio(bool mute) async {
    try {
      final result = await _channel.invokeMethod('muteLocalAudio', {
        'mute': mute,
      });
      
      if (result == true) {
        _isLocalAudioMuted = mute;
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to mute/unmute local audio: $e'});
      return false;
    }
  }
  
  /// Enable or disable local video capture and transmission
  Future<bool> enableLocalVideo(bool enabled) async {
    try {
      final result = await _channel.invokeMethod('enableLocalVideo', {
        'enabled': enabled,
      });
      
      if (result == true) {
        _isLocalVideoEnabled = enabled;
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to enable/disable local video: $e'});
      return false;
    }
  }
  
  /// Mute or unmute local video
  Future<bool> muteLocalVideo(bool mute) async {
    try {
      final result = await _channel.invokeMethod('muteLocalVideo', {
        'mute': mute,
      });
      
      if (result == true) {
        _isLocalVideoMuted = mute;
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to mute/unmute local video: $e'});
      return false;
    }
  }
  
  /// Switch between front and back camera
  Future<bool> switchCamera() async {
    try {
      final result = await _channel.invokeMethod('switchCamera');
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to switch camera: $e'});
      return false;
    }
  }
  
  /// Setup the local video view
  Future<bool> setupLocalVideo(int viewId) async {
    try {
      final result = await _channel.invokeMethod('setupLocalVideo', {
        'viewId': viewId,
      });
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to setup local video: $e'});
      return false;
    }
  }
  
  /// Setup a remote video view
  Future<bool> setupRemoteVideo(int uid, int viewId) async {
    try {
      final result = await _channel.invokeMethod('setupRemoteVideo', {
        'uid': uid,
        'viewId': viewId,
      });
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to setup remote video: $e'});
      return false;
    }
  }
  
  /// Set local audio volume (0-100)
  Future<bool> setVolume(int volume) async {
    try {
      // Ensure volume is within allowed range
      if (volume < 0) volume = 0;
      if (volume > 400) volume = 400; // Agora allows up to 400% volume
      
      final result = await _channel.invokeMethod('setVolume', {
        'volume': volume,
      });
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to set volume: $e'});
      return false;
    }
  }
  
  /// Mute a specific remote user's audio
  Future<bool> muteRemoteUser(int uid, bool mute) async {
    try {
      final result = await _channel.invokeMethod('muteRemoteUser', {
        'uid': uid,
        'mute': mute,
      });
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to mute remote user: $e'});
      return false;
    }
  }
  
  /// Get a list of remote users in the channel
  Future<List<int>> getRemoteUsers() async {
    try {
      final result = await _channel.invokeMethod('getRemoteUsers');
      if (result is List) {
        return result.map((item) => item as int).toList();
      }
      return [];
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to get remote users: $e'});
      return [];
    }
  }
  
  /// Enable or disable the speakerphone
  Future<bool> setEnableSpeakerphone(bool enabled) async {
    try {
      final result = await _channel.invokeMethod('setEnableSpeakerphone', {
        'enabled': enabled,
      });
      
      if (result == true) {
        _isSpeakerphoneEnabled = enabled;
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to toggle speakerphone: $e'});
      return false;
    }
  }
  
  /// Destroy the Agora RTC Engine and release resources
  Future<bool> destroy() async {
    try {
      final result = await _channel.invokeMethod('destroy');
      
      if (result == true) {
        _isInitialized = false;
        _isInChannel = false;
        _currentChannel = null;
        _localUid = null;
        _remoteUsers.clear();
      }
      
      return result ?? false;
    } catch (e) {
      _errorStreamController.add({'errorMessage': 'Failed to destroy Agora engine: $e'});
      return false;
    }
  }
  
  /// Dispose of resources when no longer needed
  void dispose() {
    destroy();
    _userJoinedStreamController.close();
    _userOfflineStreamController.close();
    _joinChannelSuccessStreamController.close();
    _connectionStateStreamController.close();
    _errorStreamController.close();
    _localAudioStateStreamController.close();
    _localVideoStateStreamController.close();
    _remoteVideoStateStreamController.close();
    _networkQualityStreamController.close();
    _rtcStatsStreamController.close();
    _localVideoViewCreatedStreamController.close();
    _remoteVideoViewCreatedStreamController.close();
  }
  
  /// Set up method call handler to handle platform events
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onUserJoined':
          final uid = call.arguments['uid'] as int;
          _remoteUsers.add(uid);
          _userJoinedStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
        
        case 'onUserOffline':
          final uid = call.arguments['uid'] as int;
          _remoteUsers.remove(uid);
          _userOfflineStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
        
        case 'onJoinChannelSuccess':
          _isInChannel = true;
          _localUid = call.arguments['uid'] as int;
          _joinChannelSuccessStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
        
        case 'onConnectionStateChanged':
          _connectionStateStreamController.add(Map<String, dynamic>.from(call.arguments));
          
          // Update connection state based on state code
          final state = call.arguments['state'] as int;
          if (state == 4) { // FAILED
            _isInChannel = false;
          }
          break;
        
        case 'onError':
          _errorStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
        
        case 'onLocalAudioStateChanged':
          _localAudioStateStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
          
        case 'onLocalVideoStateChanged':
          _localVideoStateStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
          
        case 'onRemoteVideoStateChanged':
          _remoteVideoStateStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
          
        case 'onNetworkQuality':
          _networkQualityStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
          
        case 'onRtcStats':
          _rtcStatsStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
          
        case 'onLocalVideoViewCreated':
          _localVideoViewCreatedStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
          
        case 'onRemoteVideoViewCreated':
          _remoteVideoViewCreatedStreamController.add(Map<String, dynamic>.from(call.arguments));
          break;
      }
      
      return null;
    });
  }
} 