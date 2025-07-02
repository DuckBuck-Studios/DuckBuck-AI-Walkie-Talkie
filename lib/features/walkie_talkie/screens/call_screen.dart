import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';

/// CallScreen - Full-screen call interface with caller image and controls
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for active call indicator
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Slide animation for screen entrance
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        if (!callProvider.isCallActive) {
          return const SizedBox.shrink();
        }

        return SlideTransition(
          position: _slideAnimation,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  // Background caller image (blurred)
                  _buildBackgroundImage(callProvider),
                  
                  // Main content
                  Column(
                    children: [
                      // Top section with caller info
                      Expanded(
                        flex: 3,
                        child: _buildCallerInfo(callProvider),
                      ),
                      
                      // Bottom section with controls
                      Expanded(
                        flex: 1,
                        child: _buildCallControls(callProvider),
                      ),
                    ],
                  ),
                  
                  // Close button (top right)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _buildCloseButton(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build blurred background image
  Widget _buildBackgroundImage(CallProvider callProvider) {
    final callerPhoto = callProvider.callerPhoto;
    
    if (callerPhoto == null || callerPhoto.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1e3c72),
              Color(0xFF2a5298),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(callerPhoto),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3),
            BlendMode.darken,
          ),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withOpacity(0.2),
        ),
      ),
    );
  }

  /// Build caller information section
  Widget _buildCallerInfo(CallProvider callProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Call type indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: callProvider.callType == 'incoming' 
                ? Colors.green.withOpacity(0.2)
                : Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: callProvider.callType == 'incoming' 
                  ? Colors.green
                  : Colors.blue,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Icon(
                      callProvider.callType == 'incoming' 
                          ? Icons.call_received
                          : Icons.call_made,
                      color: callProvider.callType == 'incoming' 
                          ? Colors.green
                          : Colors.blue,
                      size: 16,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                callProvider.callType == 'incoming' 
                    ? 'Incoming Call'
                    : 'Outgoing Call',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Caller avatar
        _buildCallerAvatar(callProvider),
        
        const SizedBox(height: 24),
        
        // Caller name
        Text(
          callProvider.callerName ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Call status
        Text(
          'Walkie-Talkie Call',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// Build caller avatar with border animation
  Widget _buildCallerAvatar(CallProvider callProvider) {
    final callerPhoto = callProvider.callerPhoto;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(_pulseAnimation.value * 0.5),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: _pulseAnimation.value * 5,
              ),
            ],
          ),
          child: ClipOval(
            child: callerPhoto != null && callerPhoto.isNotEmpty
                ? Image.network(
                    callerPhoto,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar();
                    },
                  )
                : _buildDefaultAvatar(),
          ),
        );
      },
    );
  }

  /// Build default avatar
  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      child: const Icon(
        Icons.person,
        size: 80,
        color: Colors.white,
      ),
    );
  }

  /// Build call control buttons
  Widget _buildCallControls(CallProvider callProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
            isActive: !callProvider.isMuted,
            color: callProvider.isMuted ? Colors.red : Colors.white,
            backgroundColor: callProvider.isMuted 
                ? Colors.red.withOpacity(0.2)
                : Colors.white.withOpacity(0.2),
            onTap: callProvider.toggleMute,
            label: callProvider.isMuted ? 'Unmute' : 'Mute',
          ),
          
          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            isActive: true,
            color: Colors.white,
            backgroundColor: Colors.red,
            onTap: callProvider.endCall,
            label: 'End',
            size: 64,
          ),
          
          // Speaker button
          _buildControlButton(
            icon: callProvider.isSpeakerEnabled 
                ? Icons.volume_up 
                : Icons.volume_down,
            isActive: callProvider.isSpeakerEnabled,
            color: callProvider.isSpeakerEnabled ? Colors.white : Colors.grey,
            backgroundColor: callProvider.isSpeakerEnabled 
                ? Colors.blue.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            onTap: callProvider.toggleSpeaker,
            label: callProvider.isSpeakerEnabled ? 'Speaker' : 'Earpiece',
          ),
        ],
      ),
    );
  }

  /// Build individual control button
  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    required String label,
    double size = 56,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: size * 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build close button
  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: () => context.read<CallProvider>().endCall(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
