import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/fullscreen_photo_viewer.dart';
import '../../call/providers/call_provider.dart';
import 'call_connection_handler.dart';
import 'walkie_talkie_handler.dart';
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
  final WalkieTalkieHandler _walkieTalkieHandler = WalkieTalkieHandler();
  
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
        return ListenableBuilder(
          listenable: _walkieTalkieHandler,
          builder: (context, child) {
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
              // Walkie-talkie properties
              walkieTalkieHandler: _walkieTalkieHandler,
            );
          },
        );
      },
    );
    
    onShowFullscreenOverlay!(photoViewer);
  }
  
  /// Handle exit from fullscreen photo viewer
  void _handleExit() async {
    try {
      _logger.i(_tag, 'Handling exit from fullscreen photo viewer...');
      
      // Stop walkie-talkie connection if active
      if (_walkieTalkieHandler.isConnecting) {
        _logger.i(_tag, 'Stopping walkie-talkie connection on exit...');
        _walkieTalkieHandler.stopConnection();
      }
      
      // Get call provider to handle cleanup
      final callProvider = context.read<CallProvider>();
      
      // If user is in a call or waiting for friend, end the call first
      if (callProvider.isActiveCall || callProvider.waitingForFriend || callProvider.isInCall) {
        _logger.i(_tag, 'Ending call and leaving channel on exit...');
        _logger.d(_tag, 'Current call state - isActiveCall: ${callProvider.isActiveCall}, waitingForFriend: ${callProvider.waitingForFriend}, isInCall: ${callProvider.isInCall}');
        
        await callProvider.endCall(); // This will clear everything and leave Agora channel
        _logger.i(_tag, 'Call ended and channel left successfully on exit');
        
        // Add delay to ensure cleanup is complete
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        _logger.d(_tag, 'No active call state to clean up on exit');
      }
      
      // Always allow exit after cleanup
      HapticFeedback.mediumImpact();
      
      // Add exit animation before hiding overlay
      _animateExit().then((_) {
        if (onHideFullscreenOverlay != null) {
          onHideFullscreenOverlay!();
        }
      });
      
    } catch (e) {
      _logger.e(_tag, 'Error during exit cleanup: $e');
      // Force exit even if cleanup fails
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
  
  /// Handle long press to start connection
  void _handleLongPress(CallProvider callProvider) async {
    if (_currentFriend == null) return;
    
    // Don't allow starting a new connection if already connecting or in a call
    if (_walkieTalkieHandler.isConnecting || callProvider.isActiveCall) {
      _logger.w(_tag, 'Cannot start connection - already connecting or in call');
      return;
    }
    
    _logger.i(_tag, 'Starting walkie-talkie connection process...');
    
    // Start walkie-talkie connection UI immediately
    _walkieTalkieHandler.startConnection();
    
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
        _walkieTalkieHandler.connectionSucceeded();
      } else if (!callProvider.waitingForFriend && !callProvider.friendJoined && callProvider.isInCall) {
        // Call failed (not waiting, friend didn't join, but still marked as in call)
        _logger.w(_tag, '❌ Call failed');
        _walkieTalkieHandler.connectionFailed();
      } else if (!callProvider.isInCall && !callProvider.waitingForFriend) {
        // Call completely ended
        _walkieTalkieHandler.endSession();
      }
    });
    
    // Listen to walkie-talkie handler for timeout events
    _walkieTalkieHandler.addListener(() {
      if (!_walkieTalkieHandler.isConnecting && 
          _walkieTalkieHandler.remainingSeconds <= 0 &&
          (callProvider.waitingForFriend || callProvider.isInCall)) {
        // Walkie-talkie timed out, force end the call
        _logger.w(_tag, 'Walkie-talkie timed out, force ending call...');
        _forceCleanupCall(callProvider);
      }
    });
  }
  
  /// Force cleanup call and channel leaving
  void _forceCleanupCall(CallProvider callProvider) async {
    try {
      _logger.i(_tag, 'Force cleanup: ending call and leaving channel...');
      await callProvider.endCall();
      _logger.i(_tag, 'Force cleanup completed successfully');
    } catch (e) {
      _logger.e(_tag, 'Error during force cleanup: $e');
    }
  }
  
  /// Get current friend data
  Map<String, dynamic>? get currentFriend => _currentFriend;
}
 