import 'package:flutter/material.dart'; 
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/agora_service.dart';

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
  OverlayEntry? _overlayEntry;
  Timer? _timer;
  int _seconds = 0;
  final ValueNotifier<String> _timerText = ValueNotifier<String>("00:00");
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  bool _videoEnabled = true;
  bool _audioEnabled = true;

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
    _controlsTimer?.cancel();
    _timerText.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleControls() {
    if (!mounted) return;
    
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    
    _controlsTimer?.cancel();
    if (_controlsVisible) {
      // Only start timer if controls are now visible
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }

  void _startTimer() {
    _seconds = 0;
    _updateTimerText();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      _updateTimerText();
    });
  }

  void _updateTimerText() {
    if (mounted) {
      final hours = _seconds ~/ 3600;
      final minutes = (_seconds % 3600) ~/ 60;
      final remainingSeconds = _seconds % 60;

      String timeText;
      if (hours > 0) {
        timeText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
      } else {
        timeText = '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
      }

      _timerText.value = timeText;
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _seconds = 0;
    _updateTimerText();
  }

  void _showOverlay() async {
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
      enableVideo: false, // Start with video off
      enableAudio: true,  // Audio enabled but will be muted initially
    );
    
    if (!success) {
      debugPrint('MAIN_BUTTON ERROR: Failed to join channel for friend: ${widget.friendUid}');
      return;
    }
    
    debugPrint('MAIN_BUTTON: Successfully joined channel, showing call overlay');
    
    // If successfully joined, show the overlay call UI
    _removeOverlay();
    
    debugPrint('MAIN_BUTTON: Creating overlay entry');
    _overlayEntry = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setStateOverlay) {
          debugPrint('MAIN_BUTTON: Building overlay UI');
          return Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Background fade animation
                Animate(
                  effects: [
                    FadeEffect(
                      duration: 300.ms,
                      begin: 0,
                      end: 1,
                    ),
                  ],
                  onComplete: (controller) {
                    _startTimer();
                  },
                  child: GestureDetector(
                    onTap: () {
                      // Toggle controls - if showing, hide them; if hidden, show them
                      setStateOverlay(() {
                        _controlsVisible = !_controlsVisible;
                      });
                      
                      _controlsTimer?.cancel();
                      if (_controlsVisible) {
                        // Only start timer if controls are now visible
                        _controlsTimer = Timer(const Duration(seconds: 3), () {
                          if (_overlayEntry != null) {
                            setStateOverlay(() {
                              _controlsVisible = false;
                            });
                          }
                        });
                      }
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.95),
                    ),
                  ),
                ),
                
                // Content with animations
                Animate(
                  effects: [
                    SlideEffect(
                      duration: 500.ms,
                      begin: const Offset(0, 0.2),
                      end: const Offset(0, 0),
                      curve: Curves.easeOutExpo,
                    ),
                    FadeEffect(
                      duration: 400.ms,
                      begin: 0,
                      end: 1,
                    ),
                  ],
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top spacer
                        const SizedBox(height: 20),
                        
                        // Middle content
                        Column(
                          children: [
                            if (widget.currentFriend['photoURL'] != null)
                              Hero(
                                tag: 'friend_photo_${widget.friendUid}',
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundImage: NetworkImage(widget.currentFriend['photoURL']),
                                ),
                              ).animate()
                                .scale(
                                  duration: 600.ms,
                                  curve: Curves.easeOutExpo,
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1, 1),
                                ),
                            const SizedBox(height: 24),
                            Text(
                              widget.currentFriend['displayName'] ?? 'Unknown User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ).animate()
                              .fadeIn(delay: 200.ms, duration: 400.ms)
                              .slideY(begin: 0.2, end: 0),
                            // Status is available in widget.isOnline but not displayed
                            const SizedBox(height: 40),
                            ValueListenableBuilder<String>(
                              valueListenable: _timerText,
                              builder: (context, value, child) {
                                return Text(
                                  value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 2,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ).animate()
                              .fadeIn(delay: 400.ms, duration: 400.ms)
                              .slideY(begin: 0.2, end: 0),
                          ],
                        ),
                        
                        // Bottom controls
                        Padding(
                          padding: const EdgeInsets.only(bottom: 50),
                          child: Column(
                            children: [
                              // Control buttons that appear on tap
                              AnimatedOpacity(
                                opacity: _controlsVisible ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Animate(
                                  effects: [
                                    SlideEffect(
                                      begin: const Offset(0, 0.5),
                                      end: const Offset(0, 0),
                                      duration: 500.ms,
                                      curve: Curves.easeOutExpo,
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 30),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Video toggle button
                                        _buildControlButton(
                                          onTap: () async {
                                            debugPrint('MAIN_BUTTON: Video toggle button pressed');
                                            
                                            // Toggle video with Agora service
                                            final agoraService = AgoraService();
                                            final newState = !_videoEnabled;
                                            
                                            debugPrint('MAIN_BUTTON: Toggling video to ${newState ? 'enabled' : 'disabled'}');
                                            await agoraService.enableLocalVideo(newState);
                                            await agoraService.muteLocalVideo(!newState);
                                            
                                            // Update UI state
                                            setStateOverlay(() {
                                              _videoEnabled = newState;
                                            });
                                            
                                            debugPrint('MAIN_BUTTON: Video is now ${_videoEnabled ? 'enabled' : 'disabled'}');
                                            
                                            _controlsTimer?.cancel();
                                            _controlsTimer = Timer(const Duration(seconds: 3), () {
                                              if (_overlayEntry != null) {
                                                setStateOverlay(() {
                                                  _controlsVisible = false;
                                                });
                                              }
                                            });
                                          },
                                          icon: _videoEnabled ? Icons.videocam : Icons.videocam_off,
                                          backgroundColor: _videoEnabled ? Colors.green : Colors.red,
                                          animationDelay: 0.ms,
                                        ),
                                        const SizedBox(width: 20),
                                        // Audio toggle button
                                        _buildControlButton(
                                          onTap: () async {
                                            debugPrint('MAIN_BUTTON: Audio toggle button pressed');
                                            
                                            // Toggle audio mute with Agora service
                                            final agoraService = AgoraService();
                                            final newState = !_audioEnabled;
                                            
                                            debugPrint('MAIN_BUTTON: Toggling audio to ${newState ? 'enabled' : 'disabled'}');
                                            await agoraService.muteLocalAudio(!newState);
                                            
                                            // Update UI state
                                            setStateOverlay(() {
                                              _audioEnabled = newState;
                                            });
                                            
                                            debugPrint('MAIN_BUTTON: Audio is now ${_audioEnabled ? 'enabled' : 'disabled'}');
                                            
                                            _controlsTimer?.cancel();
                                            _controlsTimer = Timer(const Duration(seconds: 3), () {
                                              if (_overlayEntry != null) {
                                                setStateOverlay(() {
                                                  _controlsVisible = false;
                                                });
                                              }
                                            });
                                          },
                                          icon: _audioEnabled ? Icons.mic : Icons.mic_off,
                                          backgroundColor: _audioEnabled ? Colors.green : Colors.red,
                                          animationDelay: 100.ms,
                                        ),
                                        const SizedBox(width: 20),
                                        // Flip camera button
                                        _buildControlButton(
                                          onTap: () async {
                                            debugPrint('MAIN_BUTTON: Camera flip button pressed');
                                            
                                            // Flip camera with Agora service
                                            final agoraService = AgoraService();
                                            
                                            debugPrint('MAIN_BUTTON: Switching camera');
                                            await agoraService.switchCamera();
                                            
                                            debugPrint('MAIN_BUTTON: Camera switched');
                                            
                                            _controlsTimer?.cancel();
                                            _controlsTimer = Timer(const Duration(seconds: 3), () {
                                              if (_overlayEntry != null) {
                                                setStateOverlay(() {
                                                  _controlsVisible = false;
                                                });
                                              }
                                            });
                                          },
                                          icon: Icons.flip_camera_ios,
                                          backgroundColor: Colors.blue,
                                          animationDelay: 200.ms,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              // End call button - always visible
                              SizedBox(
                                width: 200,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    debugPrint('MAIN_BUTTON: End call button pressed');
                                    
                                    // Leave Agora channel before removing the overlay
                                    final agoraService = AgoraService();
                                    
                                    debugPrint('MAIN_BUTTON: Leaving Agora channel');
                                    await agoraService.leaveChannel();
                                    
                                    debugPrint('MAIN_BUTTON: Closing the call overlay');
                                    _removeOverlay();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: const Text(
                                    'End Call',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ).animate()
                                .fadeIn(delay: 500.ms, duration: 400.ms)
                                .slideY(begin: 0.2, end: 0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    debugPrint('MAIN_BUTTON: Inserting overlay into context');
    Overlay.of(context).insert(_overlayEntry!);
    
    // Begin with controls visible for 3 seconds
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      debugPrint('MAIN_BUTTON: Auto-hiding controls after 3 seconds');
      if (_overlayEntry != null && mounted) {
        _overlayEntry!.markNeedsBuild();
      }
    });
    
    debugPrint('==== MAIN_BUTTON: Call overlay shown successfully ====');
  }

  Widget _buildControlButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color backgroundColor,
    required Duration animationDelay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          icon, 
          color: Colors.white, 
          size: 24
        ),
      ).animate(
        delay: animationDelay,
        onPlay: (controller) => controller.repeat(), // This is for demo purposes only
      )
        .scaleXY(
          begin: 1.0,
          end: 1.1,
          duration: 1300.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scaleXY(
          begin: 1.1,
          end: 1.0,
          duration: 1300.ms,
          curve: Curves.easeInOut,
        ),
    );
  }

  void _removeOverlay() async {
    debugPrint('==== MAIN_BUTTON: Removing call overlay ====');
    
    if (_overlayEntry == null) {
      debugPrint('MAIN_BUTTON: No overlay to remove');
      return;
    }
    
    debugPrint('MAIN_BUTTON: Removing overlay entry');
    _overlayEntry?.remove();
    _overlayEntry = null;
    
    debugPrint('MAIN_BUTTON: Stopping timer');
    _stopTimer();
    
    debugPrint('MAIN_BUTTON: Creating AgoraService instance for leaving channel');
    final agoraService = AgoraService();
    
    debugPrint('MAIN_BUTTON: Leaving Agora channel');
    await agoraService.leaveChannel();
    
    debugPrint('==== MAIN_BUTTON: Call ended ====');
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
                statusText,
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
              child: GestureDetector(
                // Disable both onTapDown and onLongPress if muted by friend
                onTapDown: widget.isMutedByFriend ? null : (_) {
                  setState(() => isPressed = true);
                  _animationController.forward(from: 0);
                },
                onTapUp: widget.isMutedByFriend ? null : (_) {
                  setState(() => isPressed = false);
                  widget.onButtonPressed?.call();
                },
                onTapCancel: widget.isMutedByFriend ? null : () {
                  setState(() => isPressed = false);
                },
                onLongPress: widget.isMutedByFriend ? null : _showOverlay,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withOpacity(0.6),
                        blurRadius: isPressed ? 25 : 15,
                        spreadRadius: isPressed ? 3 : 2,
                      ),
                      if (isPressed && !widget.isMutedByFriend)
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
                        buttonIcon,
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
  }
} 