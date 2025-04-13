import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../screens/Call/call_screen.dart';

/// BackgroundCallService handles keeping calls active when app is in background
/// This service uses wakelock to prevent device from sleeping during active calls
/// For Android, it uses a native implementation with wake lock and foreground service
class BackgroundCallService {
  // Singleton instance
  static final BackgroundCallService _instance = BackgroundCallService._internal();
  factory BackgroundCallService() => _instance;
  BackgroundCallService._internal();
 
  bool _isBackgroundServiceRunning = false;
  Timer? _callDurationTimer;
  int _callDurationSeconds = 0;
  DateTime? _callStartTime;
  static const MethodChannel _channel = MethodChannel('com.example.duckbuck/background_call');
  static const MethodChannel _navigationChannel = MethodChannel('com.example.duckbuck/navigation');
  
  // Basic call metadata for background operation
  String? _callerName;
  String? _callerAvatar;
  String? _senderUid;
  bool _isAudioMuted = false;
  
  // Callback for when remote user ends call
  Function? _onRemoteCallEnded;

  /// Returns whether the background service is running
  bool get isBackgroundServiceRunning => _isBackgroundServiceRunning;
  
  /// Get current call duration in seconds
  int get callDurationInSeconds {
    if (_callStartTime == null) return _callDurationSeconds;
    
    // Calculate duration based on start time
    final now = DateTime.now();
    return now.difference(_callStartTime!).inSeconds;
  }
  
  /// Check if we need to navigate to call screen from a notification
  Future<Map<String, dynamic>?> checkPendingNavigation() async {
    try {
      final Map<String, dynamic>? result = await _navigationChannel.invokeMapMethod('checkPendingNavigation');
      if (result != null && result.isNotEmpty) {
        debugPrint('BackgroundCallService: Received pending navigation: $result');
        return result;
      }
    } catch (e) {
      debugPrint('BackgroundCallService: Error checking pending navigation - $e');
    }
    return null;
  }

  /// Handle app lifecycle state changes and manage call functionality
  void handleAppLifecycleState(AppLifecycleState state, BuildContext context, GlobalKey<NavigatorState> navigatorKey) {
    // Get call provider without listening to changes
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // Handle app lifecycle state changes
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and interactive (foreground)
        debugPrint('App resumed - Call state: ${callProvider.callState}');
        
        // Check if we need to navigate from notification
        handlePendingCallNavigation(navigatorKey);
        
        // Check if call ended while in background
        if (callProvider.callState == CallState.connected) {
          callProvider.checkPendingNavigation();
        }
        break;
      case AppLifecycleState.inactive:
        // App is in an inactive state (transitioning between states)
        debugPrint('App inactive - Call state: ${callProvider.callState}');
        break;
      case AppLifecycleState.paused:
        // App is not visible (background)
        debugPrint('App paused - Call state: ${callProvider.callState}');
        // If there's an active call, make sure the background service is running
        if (callProvider.callState == CallState.connected) {
          debugPrint('App paused with active call - ensuring background service is running');
        }
        break;
      case AppLifecycleState.detached:
        // App is detached from the UI (though this callback may not be called in this state)
        debugPrint('App detached - Call state: ${callProvider.callState}');
        break;
      default:
        break;
    }
  }

  /// Handle navigation to call screen from a notification
  Future<void> handlePendingCallNavigation(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      final callData = await checkPendingNavigation();
      if (callData != null && callData.isNotEmpty && navigatorKey.currentState != null) {
        debugPrint('BackgroundCallService: Navigating to call screen from notification: $callData');
        
        // Get the call provider
        final callProvider = Provider.of<CallProvider>(navigatorKey.currentContext!, listen: false);
        
        // Create the call data for the provider
        final callProviderData = {
          'sender_name': callData['sender_name'],
          'sender_photo': callData['sender_photo'],
          'sender_uid': callData['sender_uid'],
          'from_notification': true,
        };
        
        // Start or restore the call
        callProvider.startCall(callProviderData);
        
        // Navigate to call screen
        navigatorKey.currentState!.push(
          CallScreenRoute(callData: callProviderData),
        );
      }
    } catch (e) {
      debugPrint('BackgroundCallService: Error handling pending call navigation - $e');
    }
  }

  /// Start the background service to keep the device awake during a call
  /// If initialDuration is provided, the timer will continue from that point
  Future<bool> startBackgroundService({
    required String callerName,
    String? callerAvatar,
    String? senderUid,
    int initialDurationSeconds = 0,
    bool isAudioMuted = false,
    Function? onRemoteCallEnded,
  }) async {
    if (_isBackgroundServiceRunning) {
      debugPrint('BackgroundCallService: Service already running');
      return true;
    }

    try {
      // Store basic call metadata
      _callerName = callerName;
      _callerAvatar = callerAvatar;
      _senderUid = senderUid;
      _isAudioMuted = isAudioMuted;
      _onRemoteCallEnded = onRemoteCallEnded;
      
      // Set initial duration for resuming calls
      _callDurationSeconds = initialDurationSeconds;
      _callStartTime = DateTime.now().subtract(Duration(seconds: initialDurationSeconds));
      
      debugPrint('BackgroundCallService: Starting with caller $callerName, avatar: $callerAvatar, uid: $senderUid');
      
      if (Platform.isAndroid) {
        // Use native Android implementation
        final success = await _channel.invokeMethod<bool>('startBackgroundService', {
          'callerName': callerName,
          'callerAvatar': callerAvatar,
          'senderUid': senderUid,
          'initialDurationSeconds': initialDurationSeconds,
          'isAudioMuted': isAudioMuted,
        }) ?? false;
        
        if (!success) {
          debugPrint('BackgroundCallService: Failed to start native service');
          return false;
        }
      } else {
        // For iOS or other platforms, use wakelock as fallback
        await WakelockPlus.enable();
      }
      
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
  Future<void> stopBackgroundService({bool showEndedNotification = false, bool remoteEnded = false}) async {
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
      
      if (Platform.isAndroid) {
        // Use native Android implementation
        if (showEndedNotification) {
          // Update call attributes with call ended flag
          await updateCallAttributes(isCallEnded: true);
          // Give a short delay to show the notification
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        await _channel.invokeMethod('stopBackgroundService');
      } else {
        // For iOS or other platforms, disable wakelock
        await WakelockPlus.disable();
      }
      
      // Clear call metadata
      _callerName = null;
      _callerAvatar = null;
      _senderUid = null;
      _isAudioMuted = false;
      
      _isBackgroundServiceRunning = false;
      debugPrint('BackgroundCallService: Background service stopped');
      
      // Call the callback if remote user ended the call
      if (remoteEnded && _onRemoteCallEnded != null) {
        _onRemoteCallEnded!();
      }
    } catch (e) {
      debugPrint('BackgroundCallService: Error stopping background service - $e');
    }
  }
  
  /// Update call attributes (like mute status)
  Future<void> updateCallAttributes({
    bool? isAudioMuted, 
    String? callerName, 
    String? callerAvatar,
    String? senderUid,
    bool? isCallEnded,
  }) async {
    if (!_isBackgroundServiceRunning) {
      return;
    }
    
    try {
      // Update local state with new values
      if (isAudioMuted != null) {
        _isAudioMuted = isAudioMuted;
      }
      
      if (callerName != null) {
        _callerName = callerName;
      }
      
      if (callerAvatar != null) {
        _callerAvatar = callerAvatar;
      }
      
      if (senderUid != null) {
        _senderUid = senderUid;
      }
      
      if (Platform.isAndroid) {
        // Use native Android implementation
        await _channel.invokeMethod('updateCallAttributes', {
          'isAudioMuted': isAudioMuted,
          'callerName': callerName,
          'callerAvatar': callerAvatar,
          'senderUid': senderUid,
          'isCallEnded': isCallEnded,
        });
      }
      
      // If call ended by remote party, stop service and trigger callback
      if (isCallEnded == true) {
        await stopBackgroundService(remoteEnded: true);
      }
    } catch (e) {
      debugPrint('BackgroundCallService: Error updating call attributes - $e');
    }
  }
  
  /// Mark call as ended by remote user
  Future<void> markCallEndedByRemote() async {
    await updateCallAttributes(isCallEnded: true);
  }
  
  /// Dispose resources
  void dispose() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    _onRemoteCallEnded = null;
    
    // Ensure background service is stopped
    if (_isBackgroundServiceRunning) {
      stopBackgroundService();
    }
  }
}