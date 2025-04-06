import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import '../services/user_service.dart';

/// AgoraService provides a wrapper around the Agora RTC Engine SDK
/// to simplify voice and video calling functionality in the application.
///
/// This service handles:
/// - Initialization of the Agora SDK
/// - Managing channel connections
/// - Audio and video control
/// - Real-time user tracking
/// - Event streaming for UI updates
class AgoraService {
  /// Default Agora App ID for the application
  static const String appId = '3983e52a08424b7da5e79be4c9dfae0f';
  
  /// The Agora RTC Engine instance
  RtcEngine? _engine;
  
  /// Tracks whether the service has been initialized
  bool _isInitialized = false;
  
  /// Current channel name the user is connected to
  String? _currentChannel;
  
  /// Current token used for authenticating with Agora servers
  String? _currentToken;
  
  /// Current user ID in the Agora session
  int? _currentUid;
  
  /// Tracks if local video (camera) is currently enabled
  bool _isVideoEnabled = false;
  
  /// Tracks if local audio (microphone) is currently enabled
  bool _isAudioEnabled = true;
  
  /// Tracks if speakerphone mode is enabled
  bool _isSpeakerphoneEnabled = true;
  
  /// Set of user IDs currently in the channel
  /// This provides quick access to active participants
  final Set<int> _remoteUsers = {};
  
  /// Stream controller for user joined events
  final StreamController<UserJoinedEvent> _userJoinedController = StreamController.broadcast();
  
  /// Stream controller for user offline events
  final StreamController<UserOfflineEvent> _userOfflineController = StreamController.broadcast();
  
  /// Stream controller for successful channel join events
  final StreamController<JoinChannelSuccessEvent> _joinChannelSuccessController = StreamController.broadcast();
  
  /// Stream controller for channel leave events
  final StreamController<LeaveChannelEvent> _leaveChannelController = StreamController.broadcast();
  
  /// Stream that emits events when a user joins the channel
  Stream<UserJoinedEvent> get onUserJoined => _userJoinedController.stream;
  
  /// Stream that emits events when a user leaves the channel
  Stream<UserOfflineEvent> get onUserOffline => _userOfflineController.stream;
  
  /// Stream that emits events when successfully joining a channel
  Stream<JoinChannelSuccessEvent> get onJoinChannelSuccess => _joinChannelSuccessController.stream;
  
  /// Stream that emits events when leaving a channel
  Stream<LeaveChannelEvent> get onLeaveChannel => _leaveChannelController.stream;
  
  /// Singleton instance of the AgoraService
  static final AgoraService _instance = AgoraService._internal();
  
  /// Factory constructor to return the singleton instance
  factory AgoraService() => _instance;
  
  /// Internal constructor for singleton pattern
  AgoraService._internal();
  
  /// Initializes the Agora engine with the provided app ID
  ///
  /// This must be called before any other methods.
  /// [customAppId] - Optional custom Agora App ID. If not provided, the default app ID will be used.
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> initialize({String? customAppId}) async {
    if (_isInitialized) return true;
    
    try {
      // Use custom app ID if provided, otherwise use default
      final String agoraAppId = customAppId ?? appId;
      
      // Request necessary permissions for audio/video
      await _requestPermissions();
      
      // Create the RTC engine instance
      _engine = createAgoraRtcEngine();
      
      // Initialize with app ID and set default channel profile
      await _engine!.initialize(RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      
      // Register event handlers for Agora callbacks
      _registerEventHandlers();
      
      _isInitialized = true;
      debugPrint('Agora engine initialized successfully with appId: $agoraAppId');
      return true;
    } catch (e) {
      debugPrint('Error initializing Agora engine: $e');
      return false;
    }
  }
  
  /// Joins an Agora channel with the specified parameters
  ///
  /// [token] - The token for authentication with Agora servers
  /// [channelId] - The channel name to join
  /// [uid] - The user ID to use in the channel
  /// [enableVideo] - Whether to enable video (camera) when joining
  /// [enableAudio] - Whether to enable audio (microphone) when joining
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    bool enableVideo = false,
    bool enableAudio = true,
  }) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      // Store current channel information for later use
      _currentChannel = channelId;
      _currentToken = token;
      _currentUid = uid;
      
      // Set client role to broadcaster (can send audio/video)
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      
      // Configure video and audio based on parameters
      await enableLocalVideo(enableVideo);
      await enableLocalAudio(enableAudio);
      
      // Mute local audio by default - user will unmute later via UI
      await muteLocalAudio(true);
      
      // Set audio profile for optimal quality
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );
      
      // Join the channel with the specified parameters
      await _engine!.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      
      debugPrint('Join channel request sent: $channelId (with audio muted)');
      return true;
    } catch (e) {
      debugPrint('Error joining channel: $e');
      return false;
    }
  }
  
  /// Leaves the current channel
  ///
  /// This disconnects from the active call and cleans up resources
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> leaveChannel() async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.leaveChannel();
      _currentChannel = null;
      _currentToken = null;
      // Clear remote users when leaving channel
      _remoteUsers.clear();
      debugPrint('Left channel successfully');
      return true;
    } catch (e) {
      debugPrint('Error leaving channel: $e');
      return false;
    }
  }
  
  /// Enables or disables the local audio (microphone)
  ///
  /// [enabled] - Whether to enable (true) or disable (false) the microphone
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> enableLocalAudio(bool enabled) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.enableLocalAudio(enabled);
      _isAudioEnabled = enabled;
      debugPrint('Local audio ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('Error toggling local audio: $e');
      return false;
    }
  }
  
  /// Mutes or unmutes the local audio stream
  ///
  /// This differs from enableLocalAudio - muting still keeps the audio
  /// module active but stops sending audio data, which is more efficient
  /// for temporary muting.
  ///
  /// [mute] - Whether to mute (true) or unmute (false) the microphone
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> muteLocalAudio(bool mute) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.muteLocalAudioStream(mute);
      debugPrint('Local audio ${mute ? 'muted' : 'unmuted'}');
      return true;
    } catch (e) {
      debugPrint('Error muting local audio: $e');
      return false;
    }
  }
  
  /// Enables or disables the local video (camera)
  ///
  /// [enabled] - Whether to enable (true) or disable (false) the camera
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> enableLocalVideo(bool enabled) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      if (enabled && !_isVideoEnabled) {
        // If enabling video for the first time, enable the video module
        await _engine!.enableVideo();
      }
      
      await _engine!.enableLocalVideo(enabled);
      _isVideoEnabled = enabled;
      debugPrint('Local video ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('Error toggling local video: $e');
      return false;
    }
  }
  
  /// Mutes or unmutes the local video stream
  ///
  /// This differs from enableLocalVideo - muting still keeps the video
  /// module active but stops sending video data, which is more efficient
  /// for temporary video pausing.
  ///
  /// [mute] - Whether to mute (true) or unmute (false) the camera
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> muteLocalVideo(bool mute) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.muteLocalVideoStream(mute);
      debugPrint('Local video ${mute ? 'muted' : 'unmuted'}');
      return true;
    } catch (e) {
      debugPrint('Error muting local video: $e');
      return false;
    }
  }
  
  /// Switches between front and back camera
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> switchCamera() async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.switchCamera();
      debugPrint('Camera switched');
      return true;
    } catch (e) {
      debugPrint('Error switching camera: $e');
      return false;
    }
  }
  
  /// Enables or disables the speakerphone mode
  ///
  /// [enabled] - Whether to use speakerphone (true) or earpiece (false)
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> setEnableSpeakerphone(bool enabled) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.setEnableSpeakerphone(enabled);
      _isSpeakerphoneEnabled = enabled;
      debugPrint('Speakerphone ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('Error toggling speakerphone: $e');
      return false;
    }
  }
  
  /// Mutes or unmutes a specific remote user's audio
  ///
  /// [uid] - The user ID of the remote user to mute/unmute
  /// [mute] - Whether to mute (true) or unmute (false) the user
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> muteRemoteUser(int uid, bool mute) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.muteRemoteAudioStream(uid: uid, mute: mute);
      debugPrint('Remote user $uid audio ${mute ? 'muted' : 'unmuted'}');
      return true;
    } catch (e) {
      debugPrint('Error muting remote user: $e');
      return false;
    }
  }
  
  /// Sets the audio recording volume
  ///
  /// [volume] - Volume value from 0-400. Default is 100.
  ///   Values 0-100 create attenuation, values > 100 create amplification.
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> setVolume(int volume) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('Agora engine not initialized');
      return false;
    }
    
    try {
      await _engine!.adjustRecordingSignalVolume(volume);
      debugPrint('Audio volume set to $volume');
      return true;
    } catch (e) {
      debugPrint('Error setting volume: $e');
      return false;
    }
  }
  
  /// Destroys the Agora engine instance and cleans up resources
  ///
  /// Should be called when the app is closing or the service is no longer needed
  Future<void> destroy() async {
    if (_engine != null) {
      if (_currentChannel != null) {
        await leaveChannel();
      }
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
      
      // Close all stream controllers
      _closeStreamControllers();
      
      debugPrint('Agora engine destroyed');
    }
  }
  
  /// Registers event handlers for Agora RTC callbacks
  ///
  /// This sets up listeners for various events like users joining/leaving,
  /// connection state changes, etc.
  void _registerEventHandlers() {
    _engine?.registerEventHandler(RtcEngineEventHandler(
      // Called when successfully joined an Agora channel
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint('Successfully joined channel: ${connection.channelId} with uid: ${connection.localUid}');
        
        // According to Agora docs, channelId and localUid are guaranteed to be non-null
        // after successful join, so we use defensive coding to avoid null issues
        try {
          final localUid = connection.localUid;
          if (localUid != null && localUid > 0) { // Safe check for valid non-null UID
            _remoteUsers.add(localUid);
          }
          
          // Use the event class that handles null values gracefully
          _joinChannelSuccessController.add(
            JoinChannelSuccessEvent(connection.channelId, connection.localUid, elapsed)
          );
        } catch (e) {
          debugPrint('Error processing join success: $e');
        }
      },
      
      // Called when leaving an Agora channel
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        debugPrint('Left channel: ${connection.channelId}');
        
        // Clear remote users list when leaving channel
        _remoteUsers.clear();
        
        try {
          // Use the event class that handles null values gracefully
          _leaveChannelController.add(
            LeaveChannelEvent(connection.channelId)
          );
        } catch (e) {
          debugPrint('Error processing leave event: $e');
        }
      },
      
      // Called when a remote user joins the channel
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('Remote user joined: $remoteUid');
        
        // Add user to tracking set - remoteUid is guaranteed to be non-null
        _remoteUsers.add(remoteUid);
        
        // Emit event
        _userJoinedController.add(
          UserJoinedEvent(remoteUid, elapsed)
        );
      },
      
      // Called when a remote user leaves the channel
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint('Remote user offline: $remoteUid, reason: ${reason.name}');
        
        // Remove user from tracking set - remoteUid is guaranteed to be non-null
        _remoteUsers.remove(remoteUid);
        
        // Emit event
        _userOfflineController.add(
          UserOfflineEvent(remoteUid, reason)
        );
      },
      
      // Called when an error occurs in the Agora SDK
      onError: (ErrorCodeType errorCode, String msg) {
        debugPrint('Agora error: $errorCode - $msg');
      },
      
      // Called when the connection state changes
      onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
        debugPrint('Connection state changed to: ${state.name}, reason: ${reason.name}');
      },
      
      // Simplified handlers for other events to avoid type issues
      onLocalAudioStateChanged: (connection, state, error) {
        debugPrint('Local audio state changed');
      },
      
      onRemoteVideoStateChanged: (connection, uid, state, reason, elapsed) {
        debugPrint('Remote video state changed for user: $uid');
      },
      
      onNetworkQuality: (connection, uid, txQuality, rxQuality) {
        debugPrint('Network quality update for user: $uid');
      },
      
      onRtcStats: (RtcConnection connection, RtcStats stats) {
        // Throttled stats reporting
      },
    ));
  }
  
  /// Closes all stream controllers to prevent memory leaks
  void _closeStreamControllers() {
    _userJoinedController.close();
    _userOfflineController.close();
    _joinChannelSuccessController.close();
    _leaveChannelController.close();
  }
  
  /// Requests necessary permissions for audio and video functionality
  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();
  }

  /// Returns the set of user IDs currently in the channel
  Set<int> get remoteUsers => _remoteUsers;

  /// Fetches Agora credentials from the backend and joins the channel in one step
  ///
  /// This method:
  /// 1. Gets the current user ID from UserService
  /// 2. Sends a request to your backend API to fetch token, uid, and channelId
  /// 3. Joins the Agora channel with the fetched credentials
  ///
  /// [enableVideo] - Whether to enable video when joining
  /// [enableAudio] - Whether to enable audio when joining
  ///
  /// Returns a boolean indicating success or failure
  Future<bool> fetchAndJoinChannel({
    bool enableVideo = false,
    bool enableAudio = true,
  }) async {
    try {
      // Ensure Agora engine is initialized first
      if (!_isInitialized) {
        final initSuccess = await initialize();
        if (!initSuccess) {
          debugPrint('Failed to initialize Agora engine');
          return false;
        }
      }
      
      // Get current user ID from UserService
      final userService = UserService();
      final userId = userService.currentUserId;
      
      if (userId == null || userId.isEmpty) {
        debugPrint('Error: No current user ID available');
        return false;
      }
      
      // Fetch Agora credentials from backend
      final dio = Dio();
      final baseUrl = 'https://firm-bluegill-engaged.ngrok-free.app'; // Replace with your actual backend URL
      final endpoint = '$baseUrl/api/agora/credentials';
      
      final response = await dio.get(
        endpoint,
        queryParameters: {'userId': userId},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      // Check if the request was successful
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Validate that all required fields are present
        if (data.containsKey('token') && data.containsKey('uid') && data.containsKey('channelId')) {
          // Convert uid to integer if needed
          final dynamic rawUid = data['uid'];
          final int uid = rawUid is int ? rawUid : int.tryParse(rawUid.toString()) ?? 0;
          
          if (uid <= 0) {
            debugPrint('Error: Invalid UID received from server');
            return false;
          }
          
          // Join the channel with the fetched credentials
          return joinChannel(
            token: data['token'],
            channelId: data['channelId'],
            uid: uid,
            enableVideo: enableVideo,
            enableAudio: enableAudio,
          );
        } else {
          debugPrint('Error: Missing required fields in server response');
          return false;
        }
      } else {
        debugPrint('Error: Failed to fetch Agora token. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error in fetchAndJoinChannel: $e');
      return false;
    }
  }

  /// Returns the current state of the service
  ///
  /// This provides a snapshot of the service's state including:
  /// - Initialization status
  /// - Current channel information
  /// - Audio/video status
  /// - Connected users
  Map<String, dynamic> getCurrentState() {
    return {
      'isInitialized': _isInitialized,
      'currentChannel': _currentChannel,
      'currentUid': _currentUid,
      'isVideoEnabled': _isVideoEnabled,
      'isAudioEnabled': _isAudioEnabled,
      'isSpeakerphoneEnabled': _isSpeakerphoneEnabled,
      'remoteUsers': remoteUsers.toList(),
    };
  }
}

/// Event class for when a user joins the channel
///
/// Contains information about the user who joined and when
class UserJoinedEvent {
  /// The user ID of the user who joined
  final int uid;
  
  /// Time elapsed (ms) since the local user joined the channel
  final int elapsed;
  
  UserJoinedEvent(this.uid, this.elapsed);
}

/// Event class for when a user leaves the channel
///
/// Contains information about the user who left and why
class UserOfflineEvent {
  /// The user ID of the user who left
  final int uid;
  
  /// The reason why the user went offline
  final UserOfflineReasonType reason;
  
  UserOfflineEvent(this.uid, this.reason);
}

/// Event class for when successfully joining a channel
///
/// Contains information about the joined channel and local user
class JoinChannelSuccessEvent {
  /// The channel ID that was joined
  final String channelId;
  
  /// The user ID assigned to the local user
  final int uid;
  
  /// Time elapsed (ms) from calling joinChannel until this callback
  final int elapsed;
  
  // Constructor that handles potentially null values
  JoinChannelSuccessEvent(String? channelId, int? uid, this.elapsed)
      : channelId = channelId ?? "unknown",
        uid = uid ?? 0;
}

/// Event class for when leaving a channel
///
/// Contains information about the channel that was left
class LeaveChannelEvent {
  /// The channel ID that was left
  final String channelId;
  
  // Constructor that handles potentially null values
  LeaveChannelEvent(String? channelId)
      : channelId = channelId ?? "unknown";
} 