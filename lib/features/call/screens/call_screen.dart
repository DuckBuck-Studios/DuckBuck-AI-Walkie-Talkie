import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/call_provider.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        if (!callProvider.isInCall || callProvider.currentCall == null) {
          return const SizedBox.shrink();  
        }

        return WillPopScope(
          onWillPop: () async => false, 
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
      child: _buildCallContent(context, callProvider, true),
    );
  }

  Widget _buildMaterialCallScreen(BuildContext context, CallProvider callProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCallContent(context, callProvider, false),
    );
  }

  Widget _buildCallContent(BuildContext context, CallProvider callProvider, bool isIOS) {
    // Get caller info
    final callerName = callProvider.currentCall!.callerName;
    final callerPhotoUrl = callProvider.currentCall!.callerPhotoUrl;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen background image
        _buildFullScreenBackground(callerPhotoUrl, callerName),
        
        // Gradient overlay for better text readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.2),
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.2, 0.7, 1.0],
            ),
          ),
        ),
        
        // Content overlay
        SafeArea(
          child: Column(
            children: [
              // Top section with caller name
              _buildCallerNameSection(context, callerName, isIOS),
              
              // Spacer to push controls to bottom
              const Spacer(),
              
              // Bottom section with call controls
              _buildCallControls(context, callProvider, isIOS),
              
              // Bottom padding for controls
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullScreenBackground(String? photoUrl, String displayName) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallbackBackground(displayName),
        errorWidget: (context, url, error) => _buildFallbackBackground(displayName),
        fadeInDuration: const Duration(milliseconds: 200),
        memCacheWidth: 800, // Optimize for performance
        memCacheHeight: 1200,
      );
    } else {
      return _buildFallbackBackground(displayName);
    }
  }

  Widget _buildFallbackBackground(String displayName) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.purple.shade700,
            Colors.indigo.shade800,
          ],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(displayName),
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1 && parts.last.isNotEmpty) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    } else if (parts.first.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    return '?';
  }

  Widget _buildCallerNameSection(BuildContext context, String callerName, bool isIOS) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    
    // Responsive sizing based on screen width
    double fontSize;
    double horizontalPadding;
    double verticalPadding;
    double letterSpacing;
    int maxLines;
    
    if (screenWidth <= 320) {
      // iPhone SE (1st gen) and smaller
      fontSize = 24.0;
      horizontalPadding = 16.0;
      verticalPadding = 20.0;
      letterSpacing = 0.2;
      maxLines = 2;
    } else if (screenWidth <= 375) {
      // iPhone SE (2nd/3rd gen), iPhone 12 mini
      fontSize = 28.0;
      horizontalPadding = 20.0;
      verticalPadding = 24.0;
      letterSpacing = 0.3;
      maxLines = 2;
    } else if (screenWidth <= 390) {
      // iPhone 12, iPhone 13
      fontSize = 30.0;
      horizontalPadding = 24.0;
      verticalPadding = 28.0;
      letterSpacing = 0.4;
      maxLines = 2;
    } else if (screenWidth <= 414) {
      // iPhone 11, iPhone XR, iPhone 12/13 Pro Max
      fontSize = 32.0;
      horizontalPadding = 28.0;
      verticalPadding = 32.0;
      letterSpacing = 0.5;
      maxLines = 2;
    } else if (screenWidth <= 428) {
      // iPhone 14 Pro Max, iPhone 15 Pro Max
      fontSize = 34.0;
      horizontalPadding = 32.0;
      verticalPadding = 36.0;
      letterSpacing = 0.6;
      maxLines = 2;
    } else {
      // Larger screens (iPad, etc.)
      fontSize = 36.0;
      horizontalPadding = 40.0;
      verticalPadding = 40.0;
      letterSpacing = 0.8;
      maxLines = 1;
    }
    
    // Adjust for very small screens
    if (screenHeight < 600) {
      fontSize *= 0.9;
      verticalPadding *= 0.8;
    } else if (screenHeight < 700) {
      fontSize *= 0.95;
      verticalPadding *= 0.9;
    }
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Text(
        callerName,
        style: isIOS 
            ? CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                color: Colors.white,
                letterSpacing: letterSpacing,
                height: 1.2,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                    color: Colors.black.withOpacity(0.8),
                  ),
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ],
              )
            : TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                color: Colors.white,
                letterSpacing: letterSpacing,
                height: 1.2,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                    color: Colors.black.withOpacity(0.8),
                  ),
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ],
              ),
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    )
    .animate()
    .fadeIn(duration: 600.ms)
    .moveY(begin: -20, end: 0, duration: 600.ms, curve: Curves.easeOutQuad)
    .shimmer(duration: 2000.ms, delay: 1000.ms);
  }

  Widget _buildCallControls(BuildContext context, CallProvider callProvider, bool isIOS) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    // Responsive button sizing
    final buttonSize = screenWidth < 400 ? 70.0 : 80.0;
    final iconSize = buttonSize * 0.35;
    final horizontalPadding = screenWidth < 400 ? 20.0 : 30.0;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20.0,
      ),
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
          )
          .animate()
          .scale(
            duration: 200.ms,
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            curve: Curves.easeInOut,
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
          )
          .animate()
          .scale(
            duration: 300.ms,
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.0, 1.0),
            curve: Curves.elasticOut,
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
          )
          .animate()
          .scale(
            duration: 200.ms,
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            curve: Curves.easeInOut,
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
      backgroundColor = Colors.red.shade600;
      iconColor = Colors.white;
    } else if (isActive) {
      backgroundColor = Colors.white;
      iconColor = Colors.black87;
    } else {
      backgroundColor = Colors.white.withOpacity(0.25);
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
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
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
