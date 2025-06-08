import 'package:permission_handler/permission_handler.dart';
import '../logger/logger_service.dart';

/// Service for handling app permissions
///
/// This service manages microphone and notification permissions optionally.
/// Users can choose to grant or deny permissions without being forced.
class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  final LoggerService _logger = LoggerService();
  
  static const String _tag = 'PERMISSIONS';

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      _logger.i(_tag, 'Requesting microphone permission');
      
      final status = await Permission.microphone.request();
      final granted = status == PermissionStatus.granted;
      
      _logger.i(_tag, 'Microphone permission status: $status, granted: $granted');
      return granted;
    } catch (e) {
      _logger.e(_tag, 'Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check microphone permission status
  Future<bool> isMicrophonePermissionGranted() async {
    try {
      final status = await Permission.microphone.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      _logger.e(_tag, 'Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermission() async {
    try {
      _logger.i(_tag, 'Requesting notification permissions');
      
      final status = await Permission.notification.request();
      final granted = status == PermissionStatus.granted;
      
      _logger.i(_tag, 'Notification permission granted: $granted');
      return granted;
    } catch (e) {
      _logger.e(_tag, 'Error requesting notification permission: $e');
      return false;
    }
  }

  /// Check notification permission status
  Future<bool> isNotificationPermissionGranted() async {
    try {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      _logger.e(_tag, 'Error checking notification permission: $e');
      return false;
    }
  }

  /// Request both microphone and notification permissions (optional)
  /// Users can choose to grant or deny without being forced
  Future<PermissionRequestResult> requestAllPermissions() async {
    try {
      _logger.i(_tag, 'Requesting permissions (optional - user can deny)');
      
      // Request both permissions - user can deny either or both
      final microphoneGranted = await requestMicrophonePermission();
      final notificationGranted = await requestNotificationPermission();
      
      final result = PermissionRequestResult(
        microphoneGranted: microphoneGranted,
        notificationGranted: notificationGranted,
      );
      
      _logger.i(_tag, 'Permission request completed - Microphone: $microphoneGranted, Notifications: $notificationGranted');
      
      return result;
    } catch (e) {
      _logger.e(_tag, 'Error requesting permissions: $e');
      return PermissionRequestResult(
        microphoneGranted: false,
        notificationGranted: false,
      );
    }
  }

  /// Check if permissions are granted (optional check)
  Future<bool> areAllPermissionsGranted() async {
    try {
      final microphoneGranted = await isMicrophonePermissionGranted();
      final notificationGranted = await isNotificationPermissionGranted();
      
      return microphoneGranted && notificationGranted;
    } catch (e) {
      _logger.e(_tag, 'Error checking permissions: $e');
      return false;
    }
  }

  /// Open app settings for permission management
  Future<bool> openAppSettings() async {
    try {
      _logger.i(_tag, 'Opening app settings for permission management');
      return await openAppSettings();
    } catch (e) {
      _logger.e(_tag, 'Error opening app settings: $e');
      return false;
    }
  }
}

/// Result class for permission requests
class PermissionRequestResult {
  final bool microphoneGranted;
  final bool notificationGranted;

  PermissionRequestResult({
    required this.microphoneGranted,
    required this.notificationGranted,
  });

  /// Check if all permissions were granted
  bool get allGranted => microphoneGranted && notificationGranted;

  /// Check if any permissions were granted
  bool get anyGranted => microphoneGranted || notificationGranted;

  @override
  String toString() {
    return 'PermissionRequestResult(microphone: $microphoneGranted, notification: $notificationGranted)';
  }
}
