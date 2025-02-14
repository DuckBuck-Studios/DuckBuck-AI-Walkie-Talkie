import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

class VoiceMessageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();
  final int _uploadRetryCount = 3;
  final Duration _uploadTimeout = Duration(seconds: 30);

  Future<String?> uploadVoiceMessage(
      File audioFile, String senderUid, String receiverUid) async {
    String fileName = "${_uuid.v4()}.aac";
    Reference storageRef =
        _storage.ref().child("voice_messages/$senderUid/$fileName");

    for (int attempt = 0; attempt < _uploadRetryCount; attempt++) {
      try {
        UploadTask uploadTask = storageRef.putFile(audioFile);
        TaskSnapshot snapshot = await uploadTask.timeout(_uploadTimeout);
        String downloadUrl = await snapshot.ref.getDownloadURL();

        String chatId = _generateChatId(senderUid, receiverUid);
        String messageId = _uuid.v4();

        int durationMs = await _getDuration(audioFile);

        await _firestore
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .doc(messageId)
            .set({
          "messageId": messageId,
          "senderUid": senderUid,
          "receiverUid": receiverUid,
          "audioUrl": downloadUrl,
          "timestamp": FieldValue.serverTimestamp(),
          "isOpened": false,
          "durationMs": durationMs,
        });

        return downloadUrl;
      } catch (e) {
        print("Error uploading voice message (attempt ${attempt + 1}): $e");
        if (attempt == _uploadRetryCount - 1) {
          print(
              "Failed to upload voice message after $_uploadRetryCount attempts.");
          return null;
        }
      }
    }
    return null;
  }

  Stream<List<Map<String, dynamic>>> fetchVoiceMessages(
      String senderUid, String receiverUid) {
    String chatId = _generateChatId(senderUid, receiverUid);

    return _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        return {
          "id": doc.id,
          "senderUid": doc["senderUid"],
          "receiverUid": doc["receiverUid"],
          "audioUrl": doc["audioUrl"],
          "timestamp": doc["timestamp"],
          "isOpened": doc["isOpened"],
          "durationMs": doc["durationMs"],
        };
      }).toList();
    });
  }

  Future<void> markMessageAsOpened(String messageId, String currentUserId,
      String friendId, String senderUid) async {
    String chatId = _generateChatId(currentUserId, friendId);

    try {
      DocumentSnapshot messageDoc = await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .get();

      if (messageDoc.exists) {
        Map<String, dynamic> messageData =
            messageDoc.data() as Map<String, dynamic>;
        String audioUrl = messageData['audioUrl'];

        await _firestore
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .doc(messageId)
            .update({
          "isOpened": true,
        });

        // Add delay before deletion
        await Future.delayed(const Duration(milliseconds: 500));
        await deleteMessageForEveryone(chatId, messageId, audioUrl);
      }
    } catch (e) {
      print("Error marking message as opened and deleting: $e");
      rethrow;
    }
  }

  Future<void> deleteMessageForMe(
      String chatId, String messageId, String userId) async {
    try {
      // Update the message to mark it as deleted for the current user
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .update({
        "deletedFor": FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print("Error deleting message for me: $e");
    }
  }

  Future<void> deleteMessageForEveryone(
      String chatId, String messageId, String audioUrl) async {
    try {
      // Delete the message from Firestore
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .delete();

      // Delete the audio file from Firebase Storage
      await _storage.refFromURL(audioUrl).delete();
    } catch (e) {
      print("Error deleting message for everyone: $e");
    }
  }

  String _generateChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? "$uid1\_$uid2" : "$uid2\_$uid1";
  }

  Future<int> _getDuration(File audioFile) async {
    final player = AudioPlayer();
    try {
      await player.setFilePath(audioFile.path);
      final duration = await player.duration;
      return duration?.inMilliseconds ?? 0;
    } catch (e) {
      print("Error getting audio duration: $e");
      return 0;
    } finally {
      await player.dispose();
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String chatId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .orderBy("timestamp", descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error getting messages: $e");
      return [];
    }
  }
}
