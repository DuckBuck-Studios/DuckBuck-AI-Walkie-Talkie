import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// BackgroundCallService handles keeping calls active when app is in background
/// This service uses wakelock to prevent device from sleeping during active calls
/// No platform-specific implementations (like iOS Live Activity) are used
class BackgroundCallService {
  // Singleton instance
  static final BackgroundCallService _instance = BackgroundCallService._internal();
  factory BackgroundCallService() => _instance;
  BackgroundCallService._internal();
 
  bool _isBackgroundServiceRunning = false;
  Timer? _callDurationTimer;
  int _callDurationSeconds = 0;
  DateTime? _callStartTime;
  
  // Basic call metadata for background operation

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
      // Store basic call metadata
      
      // Set initial duration for resuming calls
      _callDurationSeconds = initialDurationSeconds;
      _callStartTime = DateTime.now().subtract(Duration(seconds: initialDurationSeconds));
      
      // Enable wakelock to keep the device awake during background operation
      await WakelockPlus.enable();
      
      // Start call duration timer
      _startCallDurationTimer();
      
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
      
      // Disable wakelock
      await WakelockPlus.disable();
      
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
      }
      
      if (callerName != null) {
      }
      
      if (callerAvatar != null) {
      }
    } catch (e) {
      debugPrint('BackgroundCallService: Error updating call attributes - $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
  }
}