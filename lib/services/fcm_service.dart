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
      final payload = {
        'channel_id': channelId,
        'receiver_uid': receiverUid,
        'sender_uid': senderUid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      return _sendThroughBackend('$_backendUrl/room-invitation', payload);
    } catch (e) {
      debugPrint('Error sending room invitation: $e');
      return false;
    }
  }
  
  // Get current user auth token
  Future<String?> _getAuthToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }
  
  // Send through backend
  Future<bool> _sendThroughBackend(String endpoint, Map<String, dynamic> payload) async {
    try {
      // Get auth token
      final authToken = await _getAuthToken();
      if (authToken == null) {
        debugPrint('Authentication token not available');
        return false;
      }
      
      final response = await _dio.post(
        endpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ),
        data: payload,
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        debugPrint('Notification sent successfully through backend: $responseData');
        return true;
      } else {
        debugPrint('Notification failed with status: ${response.statusCode}');
        debugPrint('Response: ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('Error in _sendThroughBackend: $e');
      return false;
    }
  }
} 