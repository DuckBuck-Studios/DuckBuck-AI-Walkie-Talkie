import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/fullscreen_photo_viewer.dart';
import '../../call/providers/call_provider.dart';
import 'call_connection_handler.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';

/// Handler for managing fullscreen photo viewer functionality
/// Separates the photo viewing logic from HomeScreen
class FullscreenPhotoHandler {
  static const String _tag = 'FULLSCREEN_PHOTO_HANDLER';
  
  final BuildContext context;
  final Function(Widget)? onShowFullscreenOverlay;
  final VoidCallback? onHideFullscreenOverlay;
  final LoggerService _logger = serviceLocator<LoggerService>();
  
  Map<String, dynamic>? _currentFriend;
  
  FullscreenPhotoHandler({
    required this.context,
    this.onShowFullscreenOverlay,
    this.onHideFullscreenOverlay,
  });
  
  /// Show fullscreen photo viewer for a friend
  void showPhotoViewer(Map<String, dynamic> friend) {
    if (onShowFullscreenOverlay == null) return;
    
    _currentFriend = friend;
    
    // Wrap FullscreenPhotoViewer in Consumer to listen to real-time provider changes
    final photoViewer = Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        return FullscreenPhotoViewer(
          photoURL: _currentFriend!['photoURL'],
          displayName: _currentFriend!['displayName'] ?? 'Unknown User',
          onExit: _handleExit,
          onLongPress: () => _handleLongPress(callProvider),
          showCallControls: callProvider.isActiveCall,
          isMuted: callProvider.isMuted,
          isSpeakerOn: callProvider.isSpeakerOn,
          onToggleMute: callProvider.toggleMute,
          onToggleSpeaker: callProvider.toggleSpeaker,
          onEndCall: callProvider.endCall,
        );
      },
    );
    
    onShowFullscreenOverlay!(photoViewer);
  }
  
  /// Handle exit from fullscreen photo viewer
  void _handleExit() async {
    try {
      // Get call provider to handle cancellation
      final callProvider = context.read<CallProvider>();
      
      // If user is in a call or waiting for friend, end the call first
      if (callProvider.isActiveCall || callProvider.waitingForFriend) {
        _logger.i(_tag, 'Cancelling call and leaving channel...');
        await callProvider.endCall(); // This will clear everything and leave Agora channel
      }
      
      // Always allow exit after cancellation
      HapticFeedback.mediumImpact();
      
      // Add exit animation before hiding overlay
      _animateExit().then((_) {
        if (onHideFullscreenOverlay != null) {
          onHideFullscreenOverlay!();
        }
      });
      
    } catch (e) {
      _logger.e(_tag, 'Error during exit/cancellation: $e');
      // Force exit even if cancellation fails
      if (onHideFullscreenOverlay != null) {
        onHideFullscreenOverlay!();
      }
    }
  }
  
  /// Animate exit transition
  Future<void> _animateExit() async {
    // Add a slight delay for smooth exit animation
    await Future.delayed(const Duration(milliseconds: 200));
  }
  
  /// Handle long press to initiate call
  void _handleLongPress(CallProvider callProvider) {
    if (_currentFriend == null) return;
    
    _logger.i(_tag, 'Starting call initiation process...');
    
    // Set up listeners for call events to update UI
    _setupCallEventListeners(callProvider);
    
    // Start the actual call process in the background (non-blocking)
    _initiateCallInBackground(callProvider);
  }
  
  /// Initiate the actual call process in background while UI shows loading states
  void _initiateCallInBackground(CallProvider callProvider) async {
    if (_currentFriend == null) return;
    
    _logger.i(_tag, 'Starting background call initiation process...');
    
    // Create and use the call connection handler
    final connectionHandler = CallConnectionHandler(
      context: context,
      callProvider: callProvider,
    );
    
    // Run the call initiation in background without blocking UI
    connectionHandler.initiateCall(_currentFriend!);
  }
  
  /// Set up listeners for call events to coordinate with UI
  void _setupCallEventListeners(CallProvider callProvider) {
    // Listen to call provider changes to update UI
    callProvider.addListener(() {
      _logger.d(_tag, 'Call provider state changed:');
      _logger.d(_tag, '  - isActiveCall: ${callProvider.isActiveCall}');
      _logger.d(_tag, '  - waitingForFriend: ${callProvider.waitingForFriend}');
      _logger.d(_tag, '  - friendJoined: ${callProvider.friendJoined}');
      _logger.d(_tag, '  - isInCall: ${callProvider.isInCall}');
      
      if (callProvider.isActiveCall) {
        // Call succeeded - friend joined and call is active
        _logger.i(_tag, '✅ Call succeeded');
      } else if (!callProvider.waitingForFriend && !callProvider.friendJoined && callProvider.isInCall) {
        // Call failed (not waiting, friend didn't join, but still marked as in call)
        _logger.w(_tag, '❌ Call failed');
      }
    });
  }
  
  /// Get current friend data
  Map<String, dynamic>? get currentFriend => _currentFriend;
}

/*
   * ENHANCED CALL UI FLOW:
   * 
   * 1. User long presses -> _handleLongPress() called
   * 2. Call initiation starts immediately with UI feedback
   * 3. Background call initiation starts (_initiateCallInBackground)
   * 4. Actual Agora channel join happens in background
   * 5. If friend joins successfully, UI transitions to call controls
   * 6. If friend doesn't join, call times out and ends
   * 
   * Key: UI messaging is managed by CallProvider state for better UX
   */