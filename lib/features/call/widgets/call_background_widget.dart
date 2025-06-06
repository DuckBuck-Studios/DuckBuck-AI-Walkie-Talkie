
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'call_screen_constants.dart';

/// Full-screen background widget for the call screen with platform-specific optimizations
/// Handles both network images and fallback gradient backgrounds
class CallBackgroundWidget extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final bool isIOS;

  const CallBackgroundWidget({
    super.key,
    required this.photoUrl,
    required this.displayName,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallbackBackground(),
        errorWidget: (context, url, error) => _buildFallbackBackground(),
        fadeInDuration: CallScreenConstants.imageTransitionDuration,
        memCacheWidth: CallScreenConstants.memCacheWidth,
        memCacheHeight: CallScreenConstants.memCacheHeight,
      );
    } else {
      return _buildFallbackBackground();
    }
  }

  Widget _buildFallbackBackground() {
    final gradientColors = isIOS 
        ? [
            // iOS-style gradient with softer transitions
            CupertinoColors.systemBlue.darkColor,
            CupertinoColors.systemPurple.darkColor,
            CupertinoColors.systemIndigo.darkColor,
          ]
        : [
            // Material design gradient with vibrant colors
            Colors.blue.shade700,
            Colors.purple.shade700,
            Colors.indigo.shade800,
          ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(displayName),
          style: TextStyle(
            fontSize: CallScreenConstants.backgroundIconFontSize,
            fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold, // iOS uses medium weight
            color: Colors.white.withValues(alpha: CallScreenConstants.backgroundIconOpacity),
            letterSpacing: CallScreenConstants.backgroundIconLetterSpacing,
            fontFamily: isIOS ? '.SF Pro Display' : null, // iOS system font
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
}
