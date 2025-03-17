import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/friend_provider.dart';

class FriendCard extends StatelessWidget {
  final Map<String, dynamic> friend;
  final bool showStatus;

  const FriendCard({
    Key? key,
    required this.friend,
    this.showStatus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String name = friend['displayName'] ?? friend['name'] ?? 'Friend';
    
    return Hero(
      tag: 'friend-card-${friend['id']}',
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        height: MediaQuery.of(context).size.height * 0.5,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
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
                  ? Image.network(
                      friend['photoURL'],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.brown.shade100,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                              color: Colors.brown.shade800,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.brown.shade100,
                          child: Center(
                            child: Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.brown.shade800,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.brown.shade100,
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.brown.shade800,
                        ),
                      ),
                    ),
              ),
              
              // Status animation at the top center
              if (showStatus && friend['statusAnimation'] != null)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(45),
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
                        borderRadius: BorderRadius.circular(43),
                        child: Lottie.asset(
                          'assets/status/${_getStatusAnimationPath(friend['statusAnimation'])}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stacktrace) {
                            print('Error loading status animation: ${friend['statusAnimation']}');
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
              
              // Gradient overlay for better text visibility
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Friend name and info
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Friend name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Online status indicator
                    if (showStatus)
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: friend['isOnline'] == true ? Colors.green : Colors.grey,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            friend['isOnline'] == true ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          
                          // Display last seen time if offline
                          if (friend['isOnline'] != true && friend['lastSeen'] != null)
                            Expanded(
                              child: Text(
                                ' · ${_getLastSeenTime(friend['lastSeen'])}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn()
      .scale(
        begin: const Offset(0.9, 0.9),
        duration: 500.ms,
        curve: Curves.easeOutBack,
      );
  }
  
  // Calculate time since last seen
  String _getLastSeenTime(dynamic lastSeen) {
    if (lastSeen == null) return '';
    
    final int timestamp = lastSeen is int ? lastSeen : 0;
    if (timestamp == 0) return '';
    
    final DateTime lastSeenTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(lastSeenTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeenTime.day}/${lastSeenTime.month}/${lastSeenTime.year}';
    }
  }

  // Helper method to determine the correct path for status animations
  String _getStatusAnimationPath(String? animation) {
    if (animation == null) return '';
    
    // Check if animation is from blue-demon folder
    if (animation.startsWith('blue-demon')) {
      return 'blue-demon/$animation.json';
    }
    
    // Check if animation is from usr-emoji folder
    if (animation.startsWith('usr-emoji')) {
      return 'usr-emoji/$animation.json';
    }
    
    return '$animation.json';
  }
} 