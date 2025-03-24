import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../providers/call_provider.dart';
import '../../../services/fcm_service.dart';
import 'swipe_path_painter.dart';

/// Handles the initiator functionality of a friend card
/// This includes sending a call invitation when long-pressing a friend card
class FriendCardInitiator {
  // FCM service for sending call notifications
  final FCMService _fcmService = FCMService();
  
  // The BuildContext from the parent FriendCard
  final BuildContext context;
  
  // Friend data
  final Map<String, dynamic> friend;
  
  // State management callbacks
  final Function(bool) setLongPressed;
  final Function(bool) setLocked;
  final Function(bool) setInIntermediateState;
  final Function(bool) setMovingToFullScreen;
  final Function(Offset?) setDragStartPosition;
  final Function(double) setDragProgress;
  final Function(PathDirection?) setCurrentPathDirection;
  final Function(Offset?) setPathEndPosition;
  final Function(String) setChannelId;
  final Function() captureInitialCardPosition;
  final Function() showOverlay;
  final Function() removeOverlay;
  final Function() startIntermediateState;
  final Function() listenForRemoteUsers;
  final Function() connectToCall;
  
  // Animation controller
  final AnimationController controller;
  
  // Constructor
  FriendCardInitiator({
    required this.context,
    required this.friend,
    required this.setLongPressed,
    required this.setLocked,
    required this.setInIntermediateState,
    required this.setMovingToFullScreen,
    required this.setDragStartPosition,
    required this.setDragProgress,
    required this.setCurrentPathDirection,
    required this.setPathEndPosition,
    required this.setChannelId,
    required this.captureInitialCardPosition,
    required this.showOverlay,
    required this.removeOverlay,
    required this.startIntermediateState,
    required this.listenForRemoteUsers,
    required this.connectToCall,
    required this.controller,
  });
  
  // Generate a random channel ID
  String generateChannelId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(10000);
    return 'channel_${timestamp}_$randomNum';
  }
  
  // Send call invitation via FCM
  Future<bool> sendCallInvitation() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("FriendCardInitiator: Cannot send invitation - not logged in");
        return false;
      }
      
      final receiverUid = friend['id'];
      if (receiverUid == null || receiverUid.isEmpty) {
        print("FriendCardInitiator: Cannot send invitation - no receiver ID");
        return false;
      }
      
      // Generate a channel ID
      final channelId = generateChannelId();
      setChannelId(channelId);
      
      print("FriendCardInitiator: Sending call invitation to: $receiverUid with channel: $channelId");
      
      // Send the invitation via FCM
      final success = await _fcmService.sendRoomInvitation(
        channelId: channelId,
        receiverUid: receiverUid,
        senderUid: currentUser.uid,
      );
      
      print("FriendCardInitiator: FCM invitation sent: $success");
      return success;
    } catch (e) {
      print("FriendCardInitiator: Error sending call invitation: $e");
      return false;
    }
  }
  
  // Method to programmatically trigger call animation from FCM
  void triggerCallAnimation() {
    // Even if we're already in a call state, force a reset to start fresh
    if (controller.status != AnimationStatus.dismissed) {
      print("DEBUG: Resetting animation state to start fresh");
      controller.reset();
    }
    
    print("DEBUG: Triggering call animation programmatically");
    
    // First send the FCM notification as initiator
    sendCallInvitation().then((success) {
      if (success) {
        // Capture initial card position
        captureInitialCardPosition();
        
        // Show the overlay first
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showOverlay();
        });
        
        // Start the initial animation
        controller.forward().then((_) {
          // Move to intermediate state (connecting animation)
          startIntermediateState();
          
          // Listen for remote users joining
          listenForRemoteUsers();
          
          // Connect to the call channel
          connectToCall();
        });
      } else {
        // Show error if FCM notification failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate call. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }
  
  // Check if already in a call state
  bool isAlreadyInCallState() {
    final bool isLocked = controller.status == AnimationStatus.completed;
    final bool isInIntermediateState = controller.status == AnimationStatus.forward;
    // AnimationStatus.dismissed is actually the INITIAL state, not "moving to full screen"
    // Only consider the card in a call state if it's completed or currently animating
    return isLocked || isInIntermediateState;
  }
  
  // Handle long press start event
  void onLongPressStart(LongPressStartDetails details) {
    print("DEBUG: Long press started");
    
    // Reset any existing state to ensure we can start a new call
    if (controller.status != AnimationStatus.dismissed) {
      controller.reset();
    }
    
    // Capture the current position and size of the card first
    captureInitialCardPosition();
    
    // Determine path direction and end position once at the start of the gesture
    final Size screenSize = MediaQuery.of(context).size;
    final PathDirection direction = SwipePathPainter.determineDirection(details.globalPosition, screenSize);
    final Offset endPosition = SwipePathPainter.calculateEndPosition(details.globalPosition, screenSize, direction);
    
    setLongPressed(true);
    setDragStartPosition(details.globalPosition);
    setDragProgress(0.0);
    setCurrentPathDirection(direction);
    setPathEndPosition(endPosition);
    
    // Trigger call animation which will send FCM and show connecting UI
    triggerCallAnimation();
  }
  
  // Handle long press end event
  void onLongPressEnd(LongPressEndDetails details) {
    print("DEBUG: Long press ended");
    setLongPressed(false);
    
    // Always return to original size when released, unless locked
    if (!controller.isCompleted) {
      print("DEBUG: Returning to original size on release - not locked");
      
      // Reset states
      setInIntermediateState(false);
      setMovingToFullScreen(false);
      
      // End the call since user released without locking
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      callProvider.endCall();
      
      // Animate back to original size
      controller.reverse();
      removeOverlay();
    } else {
      print("DEBUG: Not returning to original size - card is locked");
    }
  }
  
  // Handle long press move update
  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    // Only allow locking when in full screen mode
    if (controller.isCompleted && details.globalPosition != null) {
      // Get the drag start position and path end position
      final Offset? startPos = details.globalPosition;
      final Offset? endPos = null; // This would be set in the FriendCard class
      
      if (startPos == null || endPos == null) return;
      
      // Calculate displacement based on the fixed direction
      final Offset displacement = details.globalPosition - startPos;
      final Offset pathVector = endPos - startPos;
      
      // Project displacement onto the path direction to get progress
      double dotProduct = displacement.dx * pathVector.dx + displacement.dy * pathVector.dy;
      double pathLengthSquared = pathVector.dx * pathVector.dx + pathVector.dy * pathVector.dy;
      
      // Calculate normalized projection (progress along the path)
      double progress = (dotProduct / pathLengthSquared).clamp(0.0, 1.0);
      
      // Update drag progress
      setDragProgress(progress);
      
      // If overlay is null, recreate it to update the UI
      removeOverlay();
      showOverlay();
      
      // If progress is sufficient, lock the card
      if (progress > 0.9) {  // Threshold for locking
        setLocked(true);
        setLongPressed(false);
        
        // Vibrate for haptic feedback
        HapticFeedback.mediumImpact();
        
        // Show a visual feedback that card is locked
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card locked! Use the End button to close.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
} 