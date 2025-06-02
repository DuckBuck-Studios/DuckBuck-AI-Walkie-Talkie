import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/call_provider.dart';
import '../../friends/widgets/profile_avatar.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        if (!callProvider.isInCall || callProvider.currentCall == null) {
          return const SizedBox.shrink(); // Don't show anything if no call
        }

        return WillPopScope(
          onWillPop: () async => false, // Prevent back navigation during call
          child: Platform.isIOS 
              ? _buildCupertinoCallScreen(context, callProvider)
              : _buildMaterialCallScreen(context, callProvider),
        );
      },
    );
  }

  Widget _buildCupertinoCallScreen(BuildContext context, CallProvider callProvider) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: _buildCallContent(context, callProvider, true),
      ),
    );
  }

  Widget _buildMaterialCallScreen(BuildContext context, CallProvider callProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildCallContent(context, callProvider, false),
      ),
    );
  }

  Widget _buildCallContent(BuildContext context, CallProvider callProvider, bool isIOS) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    
    // Responsive sizing similar to user_screen.dart
    double avatarRadius;
    double spacingHeight;
    double fontSize;
    double horizontalPadding;
    double topPadding;
    
    if (screenWidth <= 320) {
      avatarRadius = 60.0;
      spacingHeight = 16.0;
      fontSize = 22.0;
      horizontalPadding = screenWidth * 0.08;
      topPadding = screenHeight * 0.08;
    } else if (screenWidth <= 375) {
      avatarRadius = 70.0;
      spacingHeight = 20.0;
      fontSize = 24.0;
      horizontalPadding = screenWidth * 0.1;
      topPadding = screenHeight * 0.1;
    } else if (screenWidth <= 414) {
      avatarRadius = 80.0;
      spacingHeight = 24.0;
      fontSize = 26.0;
      horizontalPadding = screenWidth * 0.12;
      topPadding = screenHeight * 0.12;
    } else if (screenWidth <= 428) {
      avatarRadius = 90.0;
      spacingHeight = 28.0;
      fontSize = 28.0;
      horizontalPadding = screenWidth * 0.15;
      topPadding = screenHeight * 0.15;
    } else {
      avatarRadius = 100.0;
      spacingHeight = 32.0;
      fontSize = 32.0;
      horizontalPadding = screenWidth * 0.2;
      topPadding = screenHeight * 0.18;
    }
    
    // Adjust for screen height constraints
    if (screenHeight < 600) {
      avatarRadius *= 0.8;
      spacingHeight *= 0.7;
      fontSize *= 0.85;
      topPadding *= 0.5;
    } else if (screenHeight < 700) {
      avatarRadius *= 0.9;
      spacingHeight *= 0.85;
      fontSize *= 0.9;
      topPadding *= 0.7;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          // Top section with caller info
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: topPadding * 0.3), // Reduced spacing to move content up
                  
                  // Caller avatar with animation
                  ProfileAvatar(
                    photoURL: callProvider.currentCall!.callerPhotoUrl,
                    displayName: callProvider.currentCall!.callerName,
                    radius: avatarRadius,
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2500.ms, delay: 500.ms)
                  .scaleXY(begin: 1.0, end: 1.05, duration: 2000.ms)
                  .then(delay: 1000.ms)
                  .scaleXY(begin: 1.05, end: 1.0, duration: 2000.ms),
                  
                  SizedBox(height: spacingHeight),
                  
                  // Caller name with animation
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > 428 ? screenWidth * 0.05 : 0,
                    ),
                    child: Text(
                      callProvider.currentCall!.callerName,
                      style: isIOS 
                          ? CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: CupertinoColors.white,
                              letterSpacing: screenWidth > 428 ? 0.5 : 0,
                            )
                          : TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: Colors.white,
                              letterSpacing: screenWidth > 428 ? 0.5 : 0,
                            ),
                      textAlign: TextAlign.center,
                      maxLines: screenWidth <= 320 ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .moveY(begin: 10, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
                  
                  SizedBox(height: spacingHeight * 0.5),
                  
                  // Call duration with animation (moved below caller name)
                  Text(
                    callProvider.formattedCallDuration,
                    style: isIOS 
                        ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            color: CupertinoColors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w500,
                          )
                        : TextStyle(
                            color: Colors.white70,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w500,
                          ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(duration: 500.ms)
                  .then()
                  .fadeOut(duration: 500.ms)
                  .then()
                  .fadeIn(duration: 500.ms),
                ],
              ),
            ),
          ),
          
          // Bottom section with call controls
          Expanded(
            flex: 1,
            child: _buildCallControls(context, callProvider, isIOS),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls(BuildContext context, CallProvider callProvider, bool isIOS) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    // Responsive button sizing
    final buttonSize = screenWidth < 400 ? 60.0 : 70.0;
    final iconSize = buttonSize * 0.4;
    final horizontalPadding = screenWidth < 400 ? 20.0 : 30.0;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            context,
            icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
            isActive: callProvider.isMuted,
            size: buttonSize,
            iconSize: iconSize,
            onTap: callProvider.toggleMute,
            isIOS: isIOS,
          ),
          
          // End call button
          _buildControlButton(
            context,
            icon: Icons.call_end,
            isActive: false,
            isEndCall: true,
            size: buttonSize,
            iconSize: iconSize,
            onTap: callProvider.endCall,
            isIOS: isIOS,
          ),
          
          // Speaker button
          _buildControlButton(
            context,
            icon: callProvider.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            isActive: callProvider.isSpeakerOn,
            size: buttonSize,
            iconSize: iconSize,
            onTap: callProvider.toggleSpeaker,
            isIOS: isIOS,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
    required bool isIOS,
    bool isEndCall = false,
  }) {
    Color backgroundColor;
    Color iconColor;
    
    if (isEndCall) {
      backgroundColor = Colors.red;
      iconColor = Colors.white;
    } else if (isActive) {
      backgroundColor = isIOS ? CupertinoColors.white : Colors.white;
      iconColor = isIOS ? CupertinoColors.black : Colors.black;
    } else {
      backgroundColor = Colors.white.withOpacity(0.2);
      iconColor = Colors.white;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}
