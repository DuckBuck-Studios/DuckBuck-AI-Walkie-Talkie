import 'dart:io';
import 'package:flutter/material.dart'; 
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../services/agora_service.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';
import '../Call/call_screen.dart';
import 'package:vibration/vibration.dart'; // Base vibration package

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
  StreamSubscription? _userJoinedSubscription;
  StreamSubscription? _userOfflineSubscription;
  StreamSubscription? _joinChannelSubscription;
  StreamSubscription? _leaveChannelSubscription;
  
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
    _unsubscribeFromAgoraEvents();
    super.dispose();
  }

  // Subscribe to Agora events to detect remote user joining/leaving
  void _subscribeToAgoraEvents(AgoraService agoraService) {
    _unsubscribeFromAgoraEvents(); // Ensure we're not duplicating subscriptions
    
    // Listen for remote user joined event
    _userJoinedSubscription = agoraService.onUserJoined.listen((event) {
      debugPrint('MAIN_BUTTON: Remote user joined: ${event.uid}');
      // Play success vibration when remote user joins
      _playSuccessVibration();
    });
    
    // Listen for remote user left event
    _userOfflineSubscription = agoraService.onUserOffline.listen((event) {
      debugPrint('MAIN_BUTTON: Remote user left: ${event.uid}');
      // Play error vibration when remote user leaves
      _playErrorVibration();
    });
    
    // Listen for local user joined channel event
    _joinChannelSubscription = agoraService.onJoinChannelSuccess.listen((event) {
      debugPrint('MAIN_BUTTON: Successfully joined channel: ${event.channelId}');
      // Play vibration when joining channel successfully
      _playJoinChannelVibration();
    });
    
    // Listen for leave channel event
    _leaveChannelSubscription = agoraService.onLeaveChannel.listen((event) {
      debugPrint('MAIN_BUTTON: Left channel: ${event.channelId}');
      // Play error vibration when leaving channel
      _playErrorVibration();
    });
  }
  
  // Unsubscribe from Agora events
  void _unsubscribeFromAgoraEvents() {
    _userJoinedSubscription?.cancel();
    _userOfflineSubscription?.cancel();
    _joinChannelSubscription?.cancel();
    _leaveChannelSubscription?.cancel();
    
    _userJoinedSubscription = null;
    _userOfflineSubscription = null;
    _joinChannelSubscription = null;
    _leaveChannelSubscription = null;
  }

  // Simple, reliable vibration
  void _vibrate({required int duration, int amplitude = 255}) {
    if (Platform.isIOS) {
      HapticFeedback.heavyImpact();
    } else {
      Vibration.vibrate(duration: duration, amplitude: amplitude);
    }
  }

  // Vibration when joining channel - medium intensity, medium duration
  void _playJoinChannelVibration() async {
    if (Platform.isIOS) {
      // For iOS, use a pattern of haptic impacts
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.mediumImpact();
    } else {
      // For Android, use the vibration API
      bool? hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      if (hasAmplitudeControl == true) {
        Vibration.vibrate(
          pattern: [0, 150, 100, 150],
          intensities: [0, 200, 0, 200],
        );
      } else {
        Vibration.vibrate(pattern: [0, 150, 100, 150]);
      }
    }
  }

  // Success vibration - a short double-pulse
  void _playSuccessVibration() async {
    if (Platform.isIOS) {
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();
    } else {
      bool? hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      if (hasAmplitudeControl == true) {
        Vibration.vibrate(
          pattern: [0, 100, 50, 100],
          intensities: [0, 255, 0, 255],
        );
      } else {
        Vibration.vibrate(pattern: [0, 100, 50, 100]);
      }
    }
  }
  
  // Error vibration - three quick pulses
  void _playErrorVibration() async {
    if (Platform.isIOS) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.heavyImpact();
    } else {
      bool? hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      if (hasAmplitudeControl == true) {
        Vibration.vibrate(
          pattern: [0, 80, 40, 80, 40, 80],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      } else {
        Vibration.vibrate(pattern: [0, 80, 40, 80, 40, 80]);
      }
    }
  }

  void _showCallScreen() async {
    debugPrint('==== MAIN_BUTTON: Long press detected ====');
    debugPrint('MAIN_BUTTON: Friend UID: ${widget.friendUid}');
    debugPrint('MAIN_BUTTON: Friend name: ${widget.currentFriend['displayName']}');
    
    if (widget.friendUid.isEmpty) {
      debugPrint('MAIN_BUTTON ERROR: Friend UID is empty, cannot initiate call');
      _playErrorVibration();
      return;
    }
    
    // Initial vibration when long-pressing the button
    _vibrate(duration: 300);
    
    debugPrint('MAIN_BUTTON: Creating AgoraService instance');
    final agoraService = AgoraService();
    
    // Subscribe to Agora events before joining channel
    _subscribeToAgoraEvents(agoraService);
    
    debugPrint('MAIN_BUTTON: About to call fetchAndJoinChannel with receiverUid: ${widget.friendUid}');
    
    // Try to fetch Agora credentials and join the channel
    final success = await agoraService.fetchAndJoinChannel(
      receiverUid: widget.friendUid, 
      enableAudio: true,   
    );
    
    if (!success) {
      debugPrint('MAIN_BUTTON ERROR: Failed to join channel for friend: ${widget.friendUid}');
      _playErrorVibration(); // Play error vibration
      _unsubscribeFromAgoraEvents(); // Clean up subscriptions
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
        _unsubscribeFromAgoraEvents(); // Clean up subscriptions
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

        // If call state changes and is now connected, stop vibration
        if (callProvider.callState == CallState.connected) { 
        }

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