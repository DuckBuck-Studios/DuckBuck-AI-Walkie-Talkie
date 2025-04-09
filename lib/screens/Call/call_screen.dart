import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _controlsVisible = true;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    
    if (_controlsVisible) {
      // Auto-hide controls after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CallProvider>(
        builder: (context, callProvider, child) {
          // Get call data
          final call = callProvider.currentCall;
          final callState = callProvider.callState;
          final callerName = call['sender_name'] ?? 'Unknown Caller';
          final callerPhoto = call['sender_photo'];
          final duration = callProvider.callDurationText;
          
          return GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background color
                Container(
                  color: Colors.black.withOpacity(0.95),
                ),
                
                // Content
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top spacer
                      const SizedBox(height: 20),
                      
                      // Middle content
                      Column(
                        children: [
                          if (callerPhoto != null && callerPhoto.isNotEmpty)
                            Hero(
                              tag: 'caller_photo_${call['sender_uid']}',
                              child: CircleAvatar(
                                radius: 60,
                                backgroundImage: NetworkImage(callerPhoto),
                              ),
                            ).animate()
                              .scale(
                                duration: 600.ms,
                                curve: Curves.easeOutExpo,
                                begin: const Offset(0.5, 0.5),
                                end: const Offset(1, 1),
                              ),
                          if (callerPhoto == null || callerPhoto.isEmpty)
                            Hero(
                              tag: 'caller_photo_${call['sender_uid']}',
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.purple.shade700,
                                child: const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white,
                                ),
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
                            callerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ).animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                            .slideY(begin: 0.2, end: 0),
                            
                          const SizedBox(height: 12),
                          
                          // Call status text
                          Text(
                            _getCallStatusText(callState),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ).animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms),
                            
                          const SizedBox(height: 40),
                          
                          // Call duration
                          Text(
                            duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
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
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 30),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Video toggle button
                                    _buildControlButton(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        callProvider.toggleVideo();
                                      },
                                      icon: callProvider.isVideoEnabled ? 
                                        Icons.videocam : Icons.videocam_off,
                                      backgroundColor: callProvider.isVideoEnabled ? 
                                        Colors.green : Colors.red,
                                      animationDelay: 0.ms,
                                    ),
                                    const SizedBox(width: 20),
                                    
                                    // Audio toggle button
                                    _buildControlButton(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        callProvider.toggleMute();
                                      },
                                      icon: callProvider.isAudioMuted ? 
                                        Icons.mic_off : Icons.mic,
                                      backgroundColor: callProvider.isAudioMuted ? 
                                        Colors.red : Colors.green,
                                      animationDelay: 100.ms,
                                    ),
                                    const SizedBox(width: 20),
                                    
                                    // Flip camera button
                                    _buildControlButton(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        callProvider.switchCamera();
                                      },
                                      icon: Icons.flip_camera_ios,
                                      backgroundColor: Colors.blue,
                                      animationDelay: 200.ms,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // End call button - always visible
                            SizedBox(
                              width: 200,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  callProvider.endCall();
                                  Navigator.of(context).pop();
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
              ],
            ),
          );
        },
      ),
    );
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
  
  String _getCallStatusText(CallState state) {
    switch (state) {
      case CallState.connected:
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      default:
        return '';
    }
  }
}

class CallScreenRoute extends PageRouteBuilder {
  final Map<String, dynamic> callData;
  
  CallScreenRoute({required this.callData})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => const CallScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeOutExpo;
          var fadeAnimation = Tween(begin: begin, end: end).animate(
            CurvedAnimation(parent: animation, curve: curve),
          );
          
          return FadeTransition(opacity: fadeAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      );
} 