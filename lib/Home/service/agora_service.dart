import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';

class AgoraService {
  static RtcEngine? _engine; // Make it static and nullable
  bool _isMuted = false;
  final Dio _dio = Dio();

  Future<void> initializeAgora() async {
    if (_engine != null) return; // Only initialize if not already initialized

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: '95ee535609c24947ada895b77f7cd9e4',
    ));

    await _engine!.enableAudio(); // Enable audio engine

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("Joined channel: ${connection.channelId}");
        setSpeakerphoneOn(true); // Enable speaker mode on join
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
    await _requestPermissions();

    String token = await fetchToken(channelName, userUid);
    debugPrint('Joining channel with token: $token');

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: userUid,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  Future<void> leaveChannel() async {
    await _engine!.leaveChannel();
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    await _engine!.setEnableSpeakerphone(enabled);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _engine!.muteLocalAudioStream(_isMuted);
  }

  Future<String> fetchToken(String channelName, int userUid) async {
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

  Future<void> _requestPermissions() async {
    await [Permission.microphone].request();
  }
}
