import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/call_provider.dart';

/// Handles the receiver functionality for incoming calls
/// This includes showing the incoming call screen and handling full-screen transitions
class FriendCardReceiver {
  // The BuildContext from the parent FriendCard
  final BuildContext context;
  
  // Friend data
  final Map<String, dynamic> friend;
  
  // Call data for incoming calls
  final Map<String, dynamic>? callData;
  
  // State management callbacks
  final Function(bool) setInIntermediateState;
  final Function(bool) setMovingToFullScreen;
  final Function(bool) setLocked;
  final Function(int) setIntermediateProgress;
  final Function(double) setVibrationProgress;
  final Function(double) setVibrationOffset;
  final Function(double) setVibrationAngle;
  final Function(String) setChannelId;
  final Function() startCallTimer;
  final Function() updateOverlay;
  final Function() connectToCall;
  
  // Animation controller
  final AnimationController controller;
  
  // Constructor
  FriendCardReceiver({
    required this.context,
    required this.friend,
    required this.callData,
    required this.setInIntermediateState,
    required this.setMovingToFullScreen,
    required this.setLocked,
    required this.setIntermediateProgress,
    required this.setVibrationProgress,
    required this.setVibrationOffset,
    required this.setVibrationAngle,
    required this.setChannelId,
    required this.startCallTimer,
    required this.updateOverlay,
    required this.connectToCall,
    required this.controller,
  });
  
  // Show incoming call screen as a dialog
  static void showIncomingCallScreen(BuildContext context, Widget receiverCard) {
    // Update call provider with call data
    try {
      // Show the receiver card as an overlay using a dialog or modal bottom sheet
      // for more reliable rendering without Navigator issues
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (dialogContext) {
          return Material(
            type: MaterialType.transparency,
            child: receiverCard,
          );
        },
      );
    } catch (e) {
      print("FriendCardReceiver: Error showing incoming call screen: $e");
      // Fallback - try to show as a route if dialog fails
      try {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, animation, secondaryAnimation) {
              return receiverCard;
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      } catch (e) {
        print("FriendCardReceiver: Error showing incoming call with fallback: $e");
      }
    }
  }
  
  // Handle incoming call data
  static void handleIncomingCall(BuildContext context, Map<String, dynamic> callData) {
    try {
      // Update call provider with call data
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      callProvider.handleIncomingCall(callData);
    } catch (e) {
      print("FriendCardReceiver: Error handling incoming call: $e");
    }
  }
  
  // Method for receiver to go directly to full screen
  void goToFullScreenDirectly() {
    print("DEBUG: Going directly to full screen for incoming call");
    
    // Extract channel ID from call data if available
    if (callData != null && callData!.containsKey('channel_id')) {
      final channelId = callData!['channel_id'] ?? '';
      if (channelId.isNotEmpty) {
        setChannelId(channelId);
      }
    }
    
    // Set state for full screen transition
    setInIntermediateState(false);
    setMovingToFullScreen(true);
    setIntermediateProgress(5);
    setVibrationProgress(0.0);
    setVibrationOffset(0.0);
    setVibrationAngle(0.0);
    
    // Set longer duration for animation
    controller.duration = const Duration(milliseconds: 800);
    controller.reset();
    
    // Automatically go to full screen
    controller.forward().then((_) {
      // When animation completes, auto-lock the card and start call timer
      setLocked(true);
      
      // Start tracking call duration
      startCallTimer();
      
      // Update UI
      updateOverlay();
    });
    
    // Connect to the Agora channel
    connectToCall();
  }
  
  // Create bottom control buttons for the incoming call
  Widget buildCallControls(Function() onEndCall, Function() onToggleMicrophone, Function() onToggleVideo, Function() onToggleSpeaker, bool isMicOn, bool isVideoOn, bool isSpeakerOn) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic toggle button
          _buildCallControlButton(
            icon: isMicOn
              ? Icons.mic
              : Icons.mic_off,
            color: isMicOn
              ? Colors.white
              : Colors.red,
            onPressed: onToggleMicrophone,
            label: isMicOn ? 'Mute' : 'Unmute',
          ),
          // Video toggle button
          _buildCallControlButton(
            icon: isVideoOn
              ? Icons.videocam
              : Icons.videocam_off,
            color: isVideoOn
              ? Colors.white
              : Colors.red,
            onPressed: onToggleVideo,
            label: isVideoOn ? 'Video Off' : 'Video On',
          ),
          // End call button (larger and red)
          _buildCallControlButton(
            icon: Icons.call_end,
            color: Colors.white,
            backgroundColor: Colors.red.shade700,
            size: 64,
            onPressed: onEndCall,
            label: 'End',
          ),
          // Speaker toggle button
          _buildCallControlButton(
            icon: isSpeakerOn
              ? Icons.volume_up
              : Icons.volume_off,
            color: isSpeakerOn
              ? Colors.white
              : Colors.red,
            onPressed: onToggleSpeaker,
            label: isSpeakerOn ? 'Speaker' : 'Earpiece',
          ),
        ],
      ),
    );
  }
  
  // Helper method to build call control buttons
  Widget _buildCallControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    double size = 48,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? Colors.black.withOpacity(0.4),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: color,
              size: size * 0.5,
            ),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 