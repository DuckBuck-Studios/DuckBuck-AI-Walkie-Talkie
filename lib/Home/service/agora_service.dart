import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class AgoraService {
  static RtcEngine? _engine;
  bool _isMuted = false;
  final Dio _dio = Dio();

  Future<void> initializeAgora() async {
    if (_engine != null) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: '95ee535609c24947ada895b77f7cd9e4',
    ));

    await _engine!.enableAudio();

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("Joined channel: ${connection.channelId}");
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("Remote user joined: $remoteUid");
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint("Remote user left: $remoteUid");
      },
    ));
  }

  

  Future<void> joinChannel(String channelName, int userUid) async {
    try {
      // Leave any existing channel first
      try {
        await leaveChannel();
        debugPrint('✅ Successfully left previous channel');
      } catch (e) {
        debugPrint('⚠️ Non-fatal error leaving previous channel: $e');
      }

      // Add a small delay to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Fetch token before joining the channel
      final token = await _fetchToken(channelName, userUid);
      
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: userUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
          publishMicrophoneTrack: true,
          enableAudioRecordingOrPlayout: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error joining channel: $e');
      throw e;
    }
  }

  Future<void> leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
    }
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _engine?.muteLocalAudioStream(_isMuted);
  }

  Future<String> _fetchToken(String channelName, int userUid) async {
    try {
      Response response = await _dio.get(
        'https://firm-bluegill-engaged.ngrok-free.app/api/token/generate',
        queryParameters: {
          'channelName': channelName,
          'uid': userUid.toString(),
        },
      );

      debugPrint('Token response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data['token'];
      } else {
        throw Exception('Failed to fetch token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching token: $e');
      throw Exception('Error fetching token');
    }
  }

  Future<void> configureAudioSession() async {
    try {
      await _engine?.enableAudioVolumeIndication(
          interval: 200, smooth: 3, reportVad: true);
      await _engine?.enableLocalAudio(true);
      await _engine?.setParameters('{"che.audio.keep_audiosession": true}');
      await _engine?.setParameters('{"che.audio.enable.aec": true}');
      await _engine?.setParameters('{"che.audio.enable.agc": true}');
      await _engine?.setParameters('{"che.audio.enable.ns": true}');
      debugPrint('✅ Agora audio session configured successfully');
    } catch (e) {
      debugPrint('❌ Error configuring audio session: $e');
    }
  }
}
