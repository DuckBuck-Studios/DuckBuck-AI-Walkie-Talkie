import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FCMService {
  final String _backendUrl = 'https://firm-bluegill-engaged.ngrok-free.app/api/notifications';
  final Dio _dio = Dio();
  
  // Send a room invitation data notification
  Future<bool> sendRoomInvitation({
    required String channelId,
    required String receiverUid,
    required String senderUid,
  }) async {
    try {
      debugPrint('FCMService: Preparing room invitation');
      debugPrint('FCMService: Channel ID: $channelId');
      debugPrint('FCMService: Receiver UID: $receiverUid');
      
      final payload = {
        'channel_id': channelId,
        'receiver_uid': receiverUid,
        'sender_uid': senderUid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      debugPrint('FCMService: Sending invitation payload via backend');
      final result = await _sendThroughBackend('$_backendUrl/room-invitation', payload);
      debugPrint('FCMService: Room invitation send result: $result');
      return result;
    } catch (e) {
      debugPrint('FCMService: Error sending room invitation: $e');
      return false;
    }
  }
  
  // Get current user auth token
  Future<String?> _getAuthToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('FCMService: Error getting auth token: $e');
      return null;
    }
  }
  
  // Send through backend
  Future<bool> _sendThroughBackend(String endpoint, Map<String, dynamic> payload) async {
    try {
      // Add auth token to the request
      final authToken = await _getAuthToken();
      if (authToken == null) {
        debugPrint('FCMService: No auth token available for sending notification');
        return false;
      }
      
      // Send the request to the backend
      final response = await _dio.post(
        endpoint,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        debugPrint('FCMService: Notification sent successfully');
        // Additional debug information from the backend response
        if (response.data != null && response.data is Map) {
          final responseData = response.data as Map;
          if (responseData.containsKey('message')) {
            debugPrint('FCMService: Server response: ${responseData['message']}');
          }
        }
        return true;
      } else {
        debugPrint('FCMService: Failed to send notification. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('FCMService: Error sending through backend: $e');
      return false;
    }
  }
} 