import 'package:firebase_messaging/firebase_messaging.dart';

import '../logger/logger_service.dart';
import 'fcm_message_handler.dart';
import 'fcm_background_handler.dart';

/// Main FCM Service that coordinates all Firebase Cloud Messaging functionality
/// 
/// This service:
/// - Initializes FCM message handling
/// - Sets up background message handlers
/// - Manages notification permissions
/// - Coordinates with NotificationsService for token management
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final LoggerService _logger = LoggerService();
  late final FCMMessageHandler _messageHandler;
  
  static const String _tag = 'FCM_SERVICE';
  
  bool _isInitialized = false;

  /// Initialize FCM service and message handling
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.d(_tag, 'FCM service already initialized');
      return;
    }

    try {
      _logger.i(_tag, 'Initializing FCM service');
      
      // Initialize message handler
      _messageHandler = FCMMessageHandler();
      await _messageHandler.initialize();
      
      // Set up background message handler
      await _setupBackgroundHandler();
      
      // Request permissions
      await _requestPermissions();
      
      _isInitialized = true;
      _logger.i(_tag, 'FCM service initialized successfully');
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize FCM service: $e');
      rethrow;
    }
  }

  /// Set up background message handler
  Future<void> _setupBackgroundHandler() async {
    try {
      _logger.d(_tag, 'Setting up background message handler');
      
      // Register the background message handler
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);
      
      _logger.d(_tag, 'Background message handler registered');
    } catch (e) {
      _logger.e(_tag, 'Failed to set up background handler: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    try {
      _logger.d(_tag, 'Requesting notification permissions');
      
      final bool granted = await _messageHandler.requestPermissions();
      
      if (granted) {
        _logger.i(_tag, 'Notification permissions granted');
      } else {
        _logger.w(_tag, 'Notification permissions denied');
      }
      
      return granted;
    } catch (e) {
      _logger.e(_tag, 'Error requesting permissions: $e');
      return false;
    }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      if (!_isInitialized) {
        _logger.w(_tag, 'FCM service not initialized, cannot get token');
        return null;
      }
      
      return await _messageHandler.getToken();
    } catch (e) {
      _logger.e(_tag, 'Error getting FCM token: $e');
      return null;
    }
  }

  /// Check if FCM service is initialized
  bool get isInitialized => _isInitialized;

  /// Get message handler instance
  FCMMessageHandler get messageHandler {
    if (!_isInitialized) {
      throw StateError('FCM service not initialized');
    }
    return _messageHandler;
  }
}
