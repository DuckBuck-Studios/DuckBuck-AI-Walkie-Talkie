import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/fullscreen_photo_viewer.dart';
import '../../call/providers/call_initiator_provider.dart';
import 'call_connection_handler.dart';
import 'call_ui_state_manager.dart';
import '../widgets/call_ui.dart';
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
  CallUIStateManager? _callUIStateManager;
  
  FullscreenPhotoHandler({
    required this.context,
    this.onShowFullscreenOverlay,
    this.onHideFullscreenOverlay,
  });
  
  /// Show fullscreen photo viewer for a friend
  void showPhotoViewer(Map<String, dynamic> friend) {
    if (onShowFullscreenOverlay == null) return;
    
    _currentFriend = friend;
    
    // Initialize the call UI state manager
    _callUIStateManager = CallUIStateManager();
    
    // Wrap FullscreenPhotoViewer in Consumer to listen to real-time provider changes
    final photoViewer = Consumer<CallInitiatorProvider>(
      builder: (context, callProvider, child) {
        return ChangeNotifierProvider<CallUIStateManager>.value(
          value: _callUIStateManager!,
          child: FullscreenPhotoViewer(
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
            callUIStateManager: _callUIStateManager!,
          ),
        );
      },
    );
    
    onShowFullscreenOverlay!(photoViewer);
  }
  
  /// Handle exit from fullscreen photo viewer
  void _handleExit() async {
    try {
      // Stop the call UI state manager if active
      _callUIStateManager?.callCancelled();
      
      // Get call provider to handle cancellation
      final callProvider = context.read<CallInitiatorProvider>();
      
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
  void _handleLongPress(CallInitiatorProvider callProvider) {
    if (_currentFriend == null) return;
    
    // IMMEDIATELY start showing the enhanced UI messages
    if (_callUIStateManager?.currentState == CallLoadingState.failed) {
      _logger.i(_tag, 'Retrying call after failure...');
      _callUIStateManager?.callRetry();
    } else {
      _logger.i(_tag, 'Starting call UI - showing messages immediately');
      _callUIStateManager?.startCallUI();
    }
    
    // Set up listeners for call events to update UI state manager
    _setupCallEventListeners(callProvider);
    
    // Start the actual call process in the background (non-blocking)
    _initiateCallInBackground(callProvider);
  }
  
  /// Initiate the actual call process in background while UI shows loading states
  void _initiateCallInBackground(CallInitiatorProvider callProvider) async {
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
  
  /// Set up listeners for call events to coordinate with UI state manager
  void _setupCallEventListeners(CallInitiatorProvider callProvider) {
    // Listen to call provider changes to update UI state manager
    callProvider.addListener(() {
      if (_callUIStateManager == null) return;
      
      _logger.d(_tag, 'Call provider state changed:');
      _logger.d(_tag, '  - isActiveCall: ${callProvider.isActiveCall}');
      _logger.d(_tag, '  - waitingForFriend: ${callProvider.waitingForFriend}');
      _logger.d(_tag, '  - friendJoined: ${callProvider.friendJoined}');
      _logger.d(_tag, '  - isInCall: ${callProvider.isInCall}');
      
      if (callProvider.isActiveCall) {
        // Call succeeded - friend joined and call is active
        _logger.i(_tag, '✅ Call succeeded - updating UI state manager');
        _callUIStateManager!.callSucceeded();
      } else if (!callProvider.waitingForFriend && !callProvider.friendJoined && callProvider.isInCall) {
        // Call failed (not waiting, friend didn't join, but still marked as in call)
        _logger.w(_tag, '❌ Call failed - updating UI state manager');
        _callUIStateManager!.callFailed();
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
   * 2. CallUIStateManager.startCallUI() called IMMEDIATELY 
   *    - Shows "📞 Connecting to your friend..." (5 seconds)
   * 3. Background call initiation starts (_initiateCallInBackground)
   * 4. After 5 seconds -> UI shows "🐌 Your friend's internet is slower..."
   * 5. After another 5 seconds -> UI shows "💥 Connection failed..." if no success
   * 6. Meanwhile, actual Agora channel join happens in background
   * 7. If friend joins successfully, UI transitions to call controls
   * 8. If friend doesn't join, UI shows retry option
   * 
   * Key: UI messaging is independent of actual channel joining for better UX
   */