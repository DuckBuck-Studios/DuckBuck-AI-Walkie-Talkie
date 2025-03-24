import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';

/// Handles common UI elements and rendering for the FriendCard
class FriendCardUI {
  // Build the core card content
  static Widget buildCardContent({
    required Map<String, dynamic> friend,
    required bool showStatus,
    bool isFullScreen = false,
  }) {
    final String name = friend['displayName'] ?? friend['name'] ?? 'Friend';
    final String? statusAnimation = friend['statusAnimation'];
    final bool isOnline = friend['isOnline'] == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Friend Photo as Background
        ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcOver,
          child: friend['photoURL'] != null && friend['photoURL'].toString().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: friend['photoURL'],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.brown.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.brown.shade800,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.brown.shade100,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: isFullScreen ? 120 : 80,
                      color: Colors.brown.shade800,
                    ),
                  ),
                ),
              )
            : Container(
                color: Colors.brown.shade100,
                child: Center(
                  child: Icon(
                    Icons.person,
                    size: isFullScreen ? 120 : 80,
                    color: Colors.brown.shade800,
                  ),
                ),
              ),
        ),
        
        // Status animation at the top center
        if (showStatus && statusAnimation != null)
          Positioned(
            top: isFullScreen ? 40 : 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: isFullScreen ? 120 : 90,
                height: isFullScreen ? 120 : 90,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(isFullScreen ? 60 : 45),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isFullScreen ? 58 : 43),
                  child: Lottie.asset(
                    _getStatusAnimationPath(statusAnimation),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stacktrace) {
                      print('Error loading status animation: ${_getStatusAnimationPath(statusAnimation)}');
                      return const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 30,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

        // Friend name and status at the bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.all(isFullScreen ? 24.0 : 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isFullScreen ? 32 : 24,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                if (showStatus)
                  Row(
                    children: [
                      Container(
                        width: isFullScreen ? 12 : 8,
                        height: isFullScreen ? 12 : 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: isOnline ? Colors.green.shade300 : Colors.grey.shade400,
                          fontSize: isFullScreen ? 20 : 16,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Helper method to build call control buttons
  static Widget buildCallControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    double size = 48,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? Colors.black.withOpacity(0.4),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: color,
              size: size * 0.5,
            ),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  // Format call duration for display
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  // Get status animation path
  static String _getStatusAnimationPath(String? status) {
    if (status == null) return 'assets/status/offline.json';
    
    // Handle different status types
    if (status.startsWith('blue-demon')) {
      return 'assets/status/blue-demon/$status.json';
    } else if (status.startsWith('usr-emoji')) {
      return 'assets/status/usr-emoji/$status.json';
    }
    
    // Default case - try direct path
    return 'assets/status/$status.json';
  }
} 