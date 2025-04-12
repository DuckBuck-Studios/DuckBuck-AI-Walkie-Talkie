import 'package:flutter/material.dart'; 
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../app/services/agora_service.dart';
import 'package:provider/provider.dart';
import '../../app/providers/call_provider.dart';
import '../../screens/Call/call_screen.dart';

class CurvedBottomBar extends StatefulWidget {
  final VoidCallback? onButtonPressed;
  final String? photoUrl;
  final String? name;
  final bool isOnline;
  final Map<String, dynamic> currentFriend;
  final bool isMuted;
  final bool isMutedByFriend;
  final String friendUid;

  const CurvedBottomBar({
    super.key,
    this.onButtonPressed,
    this.photoUrl,
    this.name,
    this.isOnline = false,
    required this.currentFriend,
    this.isMuted = false,
    this.isMutedByFriend = false,
    required this.friendUid,
  });

  @override
  State<CurvedBottomBar> createState() => _CurvedBottomBarState();
}

class _CurvedBottomBarState extends State<CurvedBottomBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool isPressed = false;
  Timer? _timer;
  final ValueNotifier<String> _timerText = ValueNotifier<String>("00:00");

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _timerText.dispose();
    super.dispose();
  }

  void _showCallScreen() async {
    debugPrint('==== MAIN_BUTTON: Long press detected ====');
    debugPrint('MAIN_BUTTON: Friend UID: ${widget.friendUid}');
    debugPrint('MAIN_BUTTON: Friend name: ${widget.currentFriend['displayName']}');
    
    if (widget.friendUid.isEmpty) {
      debugPrint('MAIN_BUTTON ERROR: Friend UID is empty, cannot initiate call');
      return;
    }
    
    debugPrint('MAIN_BUTTON: Creating AgoraService instance');
    final agoraService = AgoraService();
    
    debugPrint('MAIN_BUTTON: About to call fetchAndJoinChannel with receiverUid: ${widget.friendUid}');
    
    // Try to fetch Agora credentials and join the channel
    final success = await agoraService.fetchAndJoinChannel(
      receiverUid: widget.friendUid, 
      enableAudio: true,   
    );
    
    if (!success) {
      debugPrint('MAIN_BUTTON ERROR: Failed to join channel for friend: ${widget.friendUid}');
      return;
    }
    
    debugPrint('MAIN_BUTTON: Successfully joined channel, navigating to CallScreen');
    
    // Get call provider
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // Create call data from friend info
    final callData = {
      'sender_uid': widget.friendUid,
      'sender_name': widget.currentFriend['displayName'] ?? 'Unknown User',
      'sender_photo': widget.currentFriend['photoURL'],
      'agora_channel': agoraService.getCurrentState()['currentChannel'],
      'agora_token': agoraService.getCurrentState()['currentToken'],
      'call_type': 'audio',
    };
    
    // Start the call in the provider
    callProvider.startCall(callData);
    
    // Navigate to call screen
    if (mounted) {
      Navigator.of(context).push(
        CallScreenRoute(callData: callData),
      ).then((_) {
        // When returning from call screen, ensure call is ended
        callProvider.endCall();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomBarHeight = screenHeight * 0.18;
    final buttonSize = screenHeight * 0.09;

    // Determine button colors based on mute status
    final List<Color> gradientColors;
    final Color shadowColor;
    final IconData buttonIcon;
    final String statusText;

    if (widget.isMutedByFriend) {
      // The user is muted by the friend, show red button with "x" icon
      gradientColors = [
        const Color(0xFFB71C1C),
        const Color(0xFFD32F2F),
      ];
      shadowColor = const Color(0xFFB71C1C);
      buttonIcon = Icons.block;
      statusText = "You are muted";
    } else {
      // Normal state, show purple button
      gradientColors = [
        isPressed ? const Color(0xFF4A148C) : const Color(0xFF6A1B9A),
        isPressed ? const Color(0xFF6A1B9A) : const Color(0xFF8E24AA),
      ];
      shadowColor = const Color(0xFF6A1B9A);
      buttonIcon = Icons.bolt_rounded;
      statusText = widget.isMuted ? "You muted them" : "Tap to call";
    }

    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        // Check if there's an active call
        final bool isInCall = callProvider.callState == CallState.connected || 
                              callProvider.callState == CallState.connecting;

    return SizedBox(
      height: bottomBarHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: bottomBarHeight * 0.8,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ).animate()
              .fadeIn(duration: 400.ms, curve: Curves.easeOutQuad)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutQuint),
          ),
          
          // Status text
          Positioned(
            bottom: bottomBarHeight * 0.25,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                    isInCall ? "In call" : statusText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 5, 
            left: 0,
            right: 0,
            child: Center(
              child: widget.isMutedByFriend 
                ? SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: Lottie.asset(
                      'assets/animations/mute.json',
                      width: buttonSize,
                      height: buttonSize,
                      fit: BoxFit.contain,
                    ),
                  ).animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                      delay: 200.ms,
                    )
                : GestureDetector(
                    // Only enable interactions if not in a call
                    onTapDown: isInCall ? null : (_) {
                      setState(() => isPressed = true);
                      _animationController.forward(from: 0);
                    },
                    onTapUp: isInCall ? null : (_) {
                      setState(() => isPressed = false);
                      if (widget.onButtonPressed != null) {
                        widget.onButtonPressed!();
                      }
                    },
                    onTapCancel: isInCall ? null : () {
                      setState(() => isPressed = false);
                    },
                    onLongPress: isInCall ? null : _showCallScreen,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isInCall ? [Colors.green, Colors.green.shade700] : gradientColors,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isInCall ? Colors.green : shadowColor).withOpacity(0.6),
                            blurRadius: isPressed ? 25 : 15,
                            spreadRadius: isPressed ? 3 : 2,
                          ),
                          if (isPressed && !isInCall)
                            BoxShadow(
                              color: shadowColor.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isInCall ? Icons.phone : buttonIcon,
                            color: Colors.white.withOpacity(isPressed ? 0.9 : 0.8),
                            size: isPressed ? 45 : 40,
                          ),
                        ),
                      ),
                    ),
                  ).animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                      delay: 200.ms,
                    ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }
} 