import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  // Your backend URL
  static const String baseUrl = 'https://firm-bluegill-engaged.ngrok-free.app';

  /// Get FCM token from user document
  static Future<String?> _getFCMToken(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final token = userDoc.data()?['fcmToken'] as String?;
        debugPrint('Retrieved FCM token for user $userId: $token');
        return token;
      }
      debugPrint('No FCM token found for user $userId');
      return null;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Sends a FCM notification through your backend
  static Future<bool> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('Sending FCM notification to token: $token');
      final response = await http.post(
        Uri.parse('$baseUrl/api/send/notification'),
        headers: {
          'Content-Type': 'application/json',
          // Add any auth headers if needed
          // 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data ?? {},
          // Matching your backend structure
          'android': {
            'priority': 'high',
            'notification': {'channel_id': 'calls_channel'}
          }
        }),
      );

      debugPrint('FCM Send Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] ?? false;
      }

      return false;
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
      return false;
    }
  }

  /// Send call notification using receiver's UID
  static Future<bool> sendCallNotificationToUser({
    required String receiverUid,
    required String callerName,
    required String callerId,
    required String channelName,
  }) async {
    // Get receiver's FCM token
    final receiverToken = await _getFCMToken(receiverUid);

    if (receiverToken == null) {
      debugPrint('No FCM token found for user: $receiverUid');
      return false;
    }

    return sendNotification(
      token: receiverToken,
      title: 'Incoming Call',
      body: '$callerName is calling you',
      data: {
        'type': 'call',
        'callerId': callerId,
        'callerName': callerName,
        'channelName': channelName,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  /// Send missed call notification using receiver's UID
  static Future<bool> sendMissedCallNotificationToUser({
    required String receiverUid,
    required String callerName,
  }) async {
    // Get receiver's FCM token
    final receiverToken = await _getFCMToken(receiverUid);

    if (receiverToken == null) {
      debugPrint('No FCM token found for user: $receiverUid');
      return false;
    }

    return sendNotification(
      token: receiverToken,
      title: 'Missed Call',
      body: 'You missed a call from $callerName',
      data: {
        'type': 'missed_call',
        'callerName': callerName,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }
}