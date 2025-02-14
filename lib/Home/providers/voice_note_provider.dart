import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:duckbuck/Home/service/voice_note_service.dart';

class VoiceMessageProvider with ChangeNotifier {
  final VoiceMessageService _voiceMessageService = VoiceMessageService();
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;

  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  VoiceMessageService get voiceMessageService => _voiceMessageService;

  void listenToVoiceMessages(String senderUid, String receiverUid) {
    // Ensure previous subscription is canceled before starting a new one
    _messagesSubscription?.cancel();

    _messagesSubscription =
        _voiceMessageService.fetchVoiceMessages(senderUid, receiverUid).listen(
      (newMessages) {
        if (!listEquals(_messages, newMessages)) {
          _messages = newMessages;
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("Error listening to voice messages: $error");
      },
    );
  }

  void addTemporaryMessage(Map<String, dynamic> message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  Future<void> markMessageAsOpened(String senderUid, String receiverUid,
      String messageId, String audioUrl) async {
    try {
      await _voiceMessageService.markMessageAsOpened(
          senderUid, receiverUid, messageId, audioUrl);
    } catch (e) {
      debugPrint("Error marking message as opened: $e");
    }
  }
}
