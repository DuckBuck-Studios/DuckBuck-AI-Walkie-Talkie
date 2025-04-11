import 'dart:async';
import 'package:flutter/material.dart'; 
import 'package:wakelock_plus/wakelock_plus.dart';
import 'live_activity/call_activity_service.dart';

/// BackgroundCallService handles keeping calls active in the background
/// and on iOS devices, shows Live Activity UI in Dynamic Island
class BackgroundCallService {
  // Singleton instance
  static final BackgroundCallService _instance = BackgroundCallService._internal();
  factory BackgroundCallService() => _instance;
  BackgroundCallService._internal() {
    // No need to check for existing activities on startup
  }
 
  bool _isBackgroundServiceRunning = false;
  Timer? _callDurationTimer;
  int _callDurationSeconds = 0;
  DateTime? _callStartTime;
  
  // Call metadata
  String? _currentCallerName;
  String? _currentCallerAvatar;
  bool _isAudioMuted = false;
  
  // Live Activity service for iOS
  final CallActivityService _callActivityService = CallActivityService();

  /// Returns whether the background service is running
  bool get isBackgroundServiceRunning => _isBackgroundServiceRunning;
  
  /// Get current call duration in seconds
  int get callDurationInSeconds {
    if (_callStartTime == null) return _callDurationSeconds;
    
    // Calculate duration based on start time
    final now = DateTime.now();
    return now.difference(_callStartTime!).inSeconds;
  }

  /// Start the background service to keep the device awake during a call
  /// If initialDuration is provided, the timer will continue from that point
  Future<bool> startBackgroundService({
    required String callerName,
    String? callerAvatar,
    int initialDurationSeconds = 0,
    bool isAudioMuted = false,
  }) async {
    if (_isBackgroundServiceRunning) {
      debugPrint('BackgroundCallService: Service already running');
      return true;
    }

    try {
      // Store call metadata
      _currentCallerName = callerName;
      _currentCallerAvatar = callerAvatar;
      _isAudioMuted = isAudioMuted;
      
      // Set initial duration for resuming calls
      _callDurationSeconds = initialDurationSeconds;
      _callStartTime = DateTime.now().subtract(Duration(seconds: initialDurationSeconds));
      
      // Enable wakelock to keep the device awake
      await WakelockPlus.enable();
      
      // Start call duration timer
      _startCallDurationTimer();
      
      // Start Live Activity for iOS devices
      await _callActivityService.startCallActivity(
        callerName: callerName,
        callerAvatar: callerAvatar,
        isAudioMuted: isAudioMuted,
      );
      
      _isBackgroundServiceRunning = true;
      debugPrint('BackgroundCallService: Background service started with ${initialDurationSeconds}s initial duration');
      return true;
    } catch (e) {
      debugPrint('BackgroundCallService: Error starting background service - $e');
      return false;
    }
  }
  
  /// Start a call timer to update call duration
  void _startCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Just keep the timer running to update call duration
      final currentDuration = callDurationInSeconds;
      
      // Only log once every 60 seconds to reduce log spam
      if (currentDuration % 60 == 0 && currentDuration > 0) {
        debugPrint('BackgroundCallService: Call duration: ${_formatDuration(currentDuration)}');
      }
    });
  }
  
  /// Format duration as MM:SS
  String _formatDuration(int durationSeconds) {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Stop the background service
  Future<void> stopBackgroundService() async {
    if (!_isBackgroundServiceRunning) {
      debugPrint('BackgroundCallService: Service not running');
      return;
    }

    try {
      // Stop call duration timer
      _callDurationTimer?.cancel();
      _callDurationTimer = null;
      
      // Reset call start time
      _callStartTime = null;
      _callDurationSeconds = 0;
      
      // Reset call metadata
      _currentCallerName = null;
      _currentCallerAvatar = null;
      _isAudioMuted = false;
      
      // Disable wakelock
      await WakelockPlus.disable();
      
      // End Live Activity for iOS devices
      await _callActivityService.endCallActivity();
      
      _isBackgroundServiceRunning = false;
      debugPrint('BackgroundCallService: Background service stopped');
    } catch (e) {
      debugPrint('BackgroundCallService: Error stopping background service - $e');
    }
  }
  
  /// Update call attributes (like mute status)
  Future<void> updateCallAttributes({bool? isAudioMuted, String? callerName, String? callerAvatar}) async {
    if (!_isBackgroundServiceRunning) {
      return;
    }
    
    try {
      // Update local state with new values
      if (isAudioMuted != null) {
        _isAudioMuted = isAudioMuted;
      }
      
      if (callerName != null) {
        _currentCallerName = callerName;
      }
      
      if (callerAvatar != null) {
        _currentCallerAvatar = callerAvatar;
      }
      
      // Update Live Activity with new attributes (iOS only)
      await _callActivityService.updateCallActivity(
        callerName: _currentCallerName,
        callerAvatar: _currentCallerAvatar,
        isAudioMuted: _isAudioMuted,
      );
    } catch (e) {
      debugPrint('BackgroundCallService: Error updating call attributes - $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    _callActivityService.dispose();
  }
}