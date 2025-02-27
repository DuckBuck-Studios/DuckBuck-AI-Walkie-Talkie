import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  final Dio _dio = Dio();

  // Add callback for user offline
  Function? _onUserOfflineCallback;

  // Add callback for connection state changes
  Function? _onConnectionStateChanged;

  void setOnUserOfflineCallback(Function callback) {
    _onUserOfflineCallback = callback;
  }

  void setOnConnectionStateChanged(Function callback) {
    _onConnectionStateChanged = callback;
  }

  factory AgoraService() {
    return _instance;
  }

  AgoraService._internal();

  Future<void> initializeAgora() async {
    if (_isInitialized) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: "95ee535609c24947ada895b77f7cd9e4",
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    await _engine!.enableAudio();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    _isInitialized = true;

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("✅ Joined channel: ${connection.channelId}");
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("👥 Remote user joined: $remoteUid");
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint("⚠️ Remote user left: $remoteUid, reason: $reason");
        // Only trigger for actual user leaving
        if (reason == UserOfflineReasonType.userOfflineQuit) {
          debugPrint("🔔 Triggering user offline callback - user quit");
          _onUserOfflineCallback?.call();
        }
      },
      onConnectionStateChanged: (RtcConnection connection,
          ConnectionStateType state, ConnectionChangedReasonType reason) {
        debugPrint("🔄 Connection state changed: $state, reason: $reason");

        // Only handle critical disconnections
        if (state == ConnectionStateType.connectionStateDisconnected ||
            state == ConnectionStateType.connectionStateFailed) {
          debugPrint("📞 Call ended due to critical connection state: $state");
          _onConnectionStateChanged?.call();
        }
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        debugPrint("👋 Left channel: ${connection.channelId}");
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint("❌ Error occurred: $err, $msg");
        // Only handle critical errors
        if (err == ErrorCodeType.errTokenExpired ||
            err == ErrorCodeType.errInvalidToken ||
            err == ErrorCodeType.errConnectionLost) {
          debugPrint("🔔 Triggering error callback for critical error");
          _onConnectionStateChanged?.call();
        }
      },
    ));
  }

  // Completely disable audio
  Future<void> disableAudio() async {
    if (_engine == null) return;
    debugPrint("🎤 Completely disabling audio");
    await _engine!.enableLocalAudio(false);
    await _engine!.muteLocalAudioStream(true);
    _isMuted = true;
  }

  // Enable audio
  Future<void> enableAudio() async {
    if (_engine == null) return;
    debugPrint("🎤 Enabling audio");
    await _engine!.enableLocalAudio(true);
    await _engine!.muteLocalAudioStream(false);
    _isMuted = false;
  }

  Future<void> configureAudioSession() async {
    if (_engine == null) return;

    await _engine!.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );

    await _engine!.setParameters('{"che.audio.keep_audiosession": true}');
    await _engine!.setParameters('{"che.audio.enable.aec": true}');
    await _engine!.setParameters('{"che.audio.enable.agc": true}');
    await _engine!.setParameters('{"che.audio.enable.ns": true}');
  }

  Future<void> joinChannel(String channelName, int uid) async {
    if (_engine == null) {
      throw Exception('Agora engine not initialized');
    }

    final token = await _getToken(channelName);

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
        enableAudioRecordingOrPlayout: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> leaveChannel() async {
    if (_engine == null) {
      debugPrint("⚠️ Cannot leave channel - engine is null");
      return;
    }

    try {
      debugPrint("🔄 Leaving channel...");
      await _engine!.leaveChannel();
      debugPrint("✅ Left channel successfully");
    } catch (e) {
      debugPrint("❌ Error leaving channel: $e");
      throw e;
    }
  }

  Future<void> toggleMute(bool mute) async {
    if (_engine == null) return;
    await _engine!.enableLocalAudio(!mute);
    _isMuted = mute;
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    if (_engine == null) return;
    await _engine!.setEnableSpeakerphone(enabled);
  }

  bool get isMuted => _isMuted;

  Future<String> _getToken(String channelName) async {
    return _fetchToken(
        channelName, 0); // Using 0 as default UID for token generation
  }

  void dispose() {
    _engine?.release();
    _engine = null;
    _isInitialized = false;
  }

  Future<String> _fetchToken(String channelName, int userUid) async {
    try {
      Response response = await _dio.post(
        'https://firm-bluegill-engaged.ngrok-free.app/api/agora/token',
        data: {
          'channelName': channelName,
        },
      );

      debugPrint('Token response: ${response.data}');

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['token'];
      } else {
        throw Exception('Failed to fetch token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching token: $e');
      throw Exception('Error fetching token');
    }
  }
}
