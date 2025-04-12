import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../app/providers/call_provider.dart';

/// A widget that displays animated call control buttons with advanced effects
class CallControlButtons extends StatefulWidget {
  final CallProvider callProvider;
  final bool controlsVisible;
  final VoidCallback onCallEnd;

  const CallControlButtons({
    super.key,
    required this.callProvider,
    required this.controlsVisible,
    required this.onCallEnd,
  });

  @override
  State<CallControlButtons> createState() => _CallControlButtonsState();
}

class _CallControlButtonsState extends State<CallControlButtons> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _buttonAnimController;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _buttonAnimController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Only show if controls are visible
    if (!widget.controlsVisible) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottom notched container
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          
          // Normal sized buttons in a row with staggered animations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute/Unmute button
              _buildNeonButton(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.callProvider.toggleMute();
                },
                icon: widget.callProvider.isAudioMuted ? Icons.mic_off : Icons.mic,
                color: widget.callProvider.isAudioMuted ? Colors.red : const Color(0xFF00BCD4),
                isActive: !widget.callProvider.isAudioMuted,
                index: 0,
              ),
              
              // Video button (with "Coming Soon" message)
              _buildNeonButton(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Video calling coming soon!"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icons.videocam_off,
                color: Colors.grey,
                isActive: false,
                index: 1,
              ),
              
              // Placeholder for end call button
              const SizedBox(width: 70),
              
              // Speaker toggle button
              _buildNeonButton(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.callProvider.toggleSpeaker();
                },
                icon: widget.callProvider.isSpeakerEnabled ? Icons.volume_up : Icons.volume_off,
                color: widget.callProvider.isSpeakerEnabled ? const Color(0xFFFFB300) : Colors.grey,
                isActive: widget.callProvider.isSpeakerEnabled,
                index: 2,
              ),
              
              // Camera flip button (disabled with "Coming Soon" message)
              _buildNeonButton(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Camera flip coming soon!"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icons.flip_camera_ios,
                color: Colors.grey,
                isActive: false,
                index: 3,
              ),
            ],
          ),
          
          // Larger end call button centered on top
          Positioned(
            bottom: 0,
            child: _buildEndCallButton(),
          ),
        ],
      ).animate().fade(duration: 350.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildNeonButton({
    required VoidCallback? onTap,
    required IconData icon,
    required Color color,
    required bool isActive,
    required int index,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          border: Border.all(
            color: isActive ? color : Colors.grey[700]!,
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Icon(
              icon,
              key: ValueKey(icon),
              color: isActive ? color : Colors.grey[700],
              size: 26,
            ),
          ),
        ),
      ).animate().fadeIn(
        duration: 400.ms, 
        delay: (index * 100).ms,
        curve: Curves.easeOutQuad
      ).scaleXY(
        begin: 0.8,
        end: 1.0,
        duration: 400.ms,
        delay: (index * 100).ms,
        curve: Curves.easeOutBack
      ).moveY(
        begin: 20,
        end: 0,
        duration: 400.ms,
        delay: (index * 100).ms,
        curve: Curves.easeOutCubic
      ).blurXY(
        begin: 5,
        end: 0,
        duration: 400.ms,
        delay: (index * 100).ms,
      ),
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        _buttonAnimController.forward().then((_) {
          _buttonAnimController.reverse();
          widget.callProvider.endCall();
          widget.onCallEnd();
        });
      },
      child: AnimatedBuilder(
        animation: _buttonAnimController,
        builder: (context, child) {
          final scale = 1.0 - 0.2 * _buttonAnimController.value;
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Lottie.asset(
                'assets/animations/end.json',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(
      duration: 400.ms, 
      delay: 400.ms,
      curve: Curves.easeOutQuad
    ).scaleXY(
      begin: 0.7,
      end: 1.0,
      duration: 500.ms,
      delay: 400.ms,
      curve: Curves.elasticOut
    );
  }
}