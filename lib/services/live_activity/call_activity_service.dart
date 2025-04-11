import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:flutter_app_group_directory/flutter_app_group_directory.dart';
import 'call_activity_model.dart';

/// CallActivityService manages iOS Live Activities for ongoing calls
/// 
/// This service integrates with iOS Live Activities to show real-time 
/// call information in the Dynamic Island and Lock Screen when the app
/// is in the background.
class CallActivityService {
  // Singleton instance
  static final CallActivityService _instance = CallActivityService._internal();
  factory CallActivityService() => _instance;
  
  CallActivityService._internal() {
    _initLiveActivities();
  }
  
  /// App group identifier for sharing data with widget extension
  /// This must match the app group set up in Xcode
  static const String appGroupId = 'group.duckbuck.callactivity';
  
  /// The LiveActivities plugin instance
  final LiveActivities _liveActivities = LiveActivities();
  
  /// Timer for updating activity data
  Timer? _updateTimer;
  
  /// Current activity ID if active
  String? _currentActivityId;
  
  /// Timer start time for calculating duration
  DateTime? _timerStartTime;
  
  /// Current call activity model
  CallActivityModel? _currentCallActivity;
  
  /// Whether Live Activities are supported on this device
  bool _isSupported = false;
  
  /// Stream subscription for activity updates
  StreamSubscription? _activityUpdateSubscription;
  
  /// Check if Live Activities are supported on this device
  bool get isSupported => _isSupported;
  
  /// Initialize the Live Activities plugin
  Future<void> _initLiveActivities() async {
    if (!Platform.isIOS) {
      _isSupported = false;
      return;
    }
    
    try {
      // Initialize the plugin with app group ID
      await _liveActivities.init(
        appGroupId: appGroupId,
      );
      
      // Subscribe to activity updates
      _activityUpdateSubscription = _liveActivities.activityUpdateStream.listen((event) {
        debugPrint('CallActivityService: Activity update: $event');
      });
      
      // Check if device supports Live Activities (iOS 16.1+)
      final supported = await _liveActivities.areActivitiesEnabled();
      _isSupported = supported ?? false;
      
      debugPrint('CallActivityService: Live Activities supported: $_isSupported');
    } catch (e) {
      debugPrint('CallActivityService: Error initializing Live Activities: $e');
      _isSupported = false;
    }
  }
  
  /// Start a call live activity
  Future<bool> startCallActivity({
    required String callerName,
    String? callerAvatar,
    bool isAudioMuted = false,
  }) async {
    if (!isSupported) {
      debugPrint('CallActivityService: Live Activities not supported on this device');
      return false;
    }
    
    try {
      // Reset timer start time
      _timerStartTime = DateTime.now();
      
      // Create the initial call activity model
      _currentCallActivity = CallActivityModel(
        callerName: callerName,
        isAudioMuted: isAudioMuted,
        callStartTime: _timerStartTime,
      );
      
      // Prepare data for Live Activity
      final activityData = _currentCallActivity!.toActivityData();
      
      // Start the activity with the data
      final activityId = await _liveActivities.createActivity(activityData);
      
      if (activityId != null) {
        _currentActivityId = activityId;
        debugPrint('CallActivityService: Started call activity with ID: $activityId');
        
        // Start timer to update the activity every second
        _startUpdateTimer();
        
        return true;
      } else {
        debugPrint('CallActivityService: Failed to start call activity');
        return false;
      }
    } catch (e) {
      debugPrint('CallActivityService: Error starting call activity: $e');
      return false;
    }
  }
  
  /// Update call activity with current state
  Future<bool> updateCallActivity({
    String? callerName,
    String? callerAvatar,
    bool? isAudioMuted,
  }) async {
    if (!isSupported || _currentActivityId == null || _currentCallActivity == null) {
      return false;
    }
    
    try {
      // Get current formatted duration
      final formattedDuration = _getCurrentFormattedDuration();
      
      // Update our internal model
      _currentCallActivity = _currentCallActivity!.copyWith(
        callerName: callerName,
        callerAvatar: callerAvatar,
        isAudioMuted: isAudioMuted,
        callDuration: formattedDuration,
      );
      
      // Send data to the Live Activity
      final activityData = _currentCallActivity!.toActivityData();
      
      // Update the activity with the data
      await _liveActivities.updateActivity(_currentActivityId!, activityData);
      
      return true;
    } catch (e) {
      debugPrint('CallActivityService: Error updating call activity: $e');
      return false;
    }
  }
  
  /// End the current call activity
  Future<bool> endCallActivity() async {
    if (!isSupported || _currentActivityId == null) {
      return false;
    }
    
    try {
      // Stop the update timer
      _updateTimer?.cancel();
      _updateTimer = null;
      
      // Reset variables
      _timerStartTime = null;
      _currentCallActivity = null;
      
      // End the specific activity
      await _liveActivities.endActivity(_currentActivityId!);
      
      debugPrint('CallActivityService: Ended call activity with ID: $_currentActivityId');
      _currentActivityId = null;
      return true;
    } catch (e) {
      debugPrint('CallActivityService: Error ending call activity: $e');
      return false;
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _updateTimer?.cancel();
    _activityUpdateSubscription?.cancel();
    _liveActivities.dispose();
  }
  
  /// Start a timer to update the activity data periodically
  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Only update the duration on timer ticks
      updateCallActivity();
    });
  }
  
  /// Get the current call duration formatted as MM:SS
  String _getCurrentFormattedDuration() {
    final now = DateTime.now();
    final startTime = _timerStartTime ?? now;
    final durationSeconds = now.difference(startTime).inSeconds;
    
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Update shared data for the control widget
  Future<void> _updateSharedControlData() async {
    // This method is no longer needed - remove it
  }
  
  /// Clear shared data when call ends
  Future<void> _clearSharedControlData() async {
    // This method is no longer needed - remove it
  }
} 