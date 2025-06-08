import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// Shared UI components for call interfaces
/// Used in both fullscreen photo viewer and call screen for consistency
class CallUIComponents {
  
  /// Builds the caller name display with consistent positioning and styling
  static Widget buildCallerName(
    BuildContext context, {
    required String displayName,
  }) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + MediaQuery.of(context).size.height * 0.08,
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: Text(
        displayName,
        style: TextStyle(
          color: Colors.white,
          fontSize: MediaQuery.of(context).size.width * 0.055,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
          shadows: [
            Shadow(
              offset: const Offset(0, 1),
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the call controls container with consistent styling
  static Widget buildCallControls(
    BuildContext context, {
    required bool isMuted,
    required bool isSpeakerOn,
    required VoidCallback? onToggleMute,
    required VoidCallback? onToggleSpeaker,
    required VoidCallback? onEndCall,
  }) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.12,
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.04,
          vertical: MediaQuery.of(context).size.height * 0.02,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute Button
            _buildCallButton(
              context,
              icon: isMuted 
                ? (Platform.isIOS ? CupertinoIcons.mic_slash_fill : Icons.mic_off)
                : (Platform.isIOS ? CupertinoIcons.mic_fill : Icons.mic),
              onPressed: () {
                HapticFeedback.lightImpact();
                onToggleMute?.call();
              },
              backgroundColor: isMuted ? Colors.red : Colors.white.withValues(alpha: 0.2),
              iconColor: Colors.white,
            ),
            
            // End Call Button
            _buildCallButton(
              context,
              icon: Platform.isIOS ? CupertinoIcons.phone_down_fill : Icons.call_end,
              onPressed: () {
                HapticFeedback.heavyImpact();
                onEndCall?.call();
              },
              backgroundColor: Colors.red,
              iconColor: Colors.white,
            ),
            
            // Speaker Button
            _buildCallButton(
              context,
              icon: isSpeakerOn
                ? (Platform.isIOS ? CupertinoIcons.speaker_3_fill : Icons.volume_up)
                : (Platform.isIOS ? CupertinoIcons.speaker_1_fill : Icons.volume_down),
              onPressed: () {
                HapticFeedback.lightImpact();
                onToggleSpeaker?.call();
              },
              backgroundColor: isSpeakerOn ? Colors.blue : Colors.white.withValues(alpha: 0.2),
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds individual call control buttons with consistent styling
  static Widget _buildCallButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.18,
        height: MediaQuery.of(context).size.width * 0.18,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: MediaQuery.of(context).size.width * 0.09,
        ),
      ),
    );
  }

  /// Builds a loading indicator with consistent styling
  static Widget buildLoadingIndicator(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.12,
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: MediaQuery.of(context).size.height * 0.015,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.05,
              height: MediaQuery.of(context).size.width * 0.05,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width * 0.03),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: MediaQuery.of(context).size.width * 0.04,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a tap to exit container (for fullscreen photo viewer)
  static Widget buildTapToExit(
    BuildContext context, {
    required VoidCallback onExit,
    VoidCallback? onLongPress,
  }) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.12,
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: GestureDetector(
        onTap: onExit,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: MediaQuery.of(context).size.height * 0.015,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Platform.isIOS ? CupertinoIcons.hand_point_left_fill : Icons.touch_app,
                color: Colors.white.withValues(alpha: 0.8),
                size: MediaQuery.of(context).size.width * 0.045,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                'Tap to exit',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
