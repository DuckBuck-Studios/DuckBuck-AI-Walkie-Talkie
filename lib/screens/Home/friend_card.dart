import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';

class FriendCard extends StatefulWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onTap;
  final bool isSelected;

  const FriendCard({
    super.key,
    required this.friend,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<FriendCard> with SingleTickerProviderStateMixin {

  // Get the appropriate status animation asset
  String? _getStatusAnimationAsset() {
    final statusAnimation = widget.friend['statusAnimation'];
    
    print("FriendCard: Processing animation '${statusAnimation ?? 'null'}' for ${widget.friend['displayName']}");
    
    if (statusAnimation == null) {
      return null;
    }
    
    // Extract the number at the end if it exists
    final RegExp regExp = RegExp(r'(blue-demon|usr-emoji)(\d+)');
    final match = regExp.firstMatch(statusAnimation);
    
    if (match != null) {
      final prefix = match.group(1);  
      final number = match.group(2);  
      
      print("FriendCard: Matched pattern - prefix: $prefix, number: $number");
      
      if (prefix == 'blue-demon') {
        final path = 'assets/status/blue-demon/blue-demon$number.json';
        print("FriendCard: Using animation path: $path");
        return path;
      } else if (prefix == 'usr-emoji') {
        final path = 'assets/status/usr-emoji/usr-emoji$number.json';
        print("FriendCard: Using animation path: $path");
        return path;
      }
    }
    
    // If it's already a full name with folder prefix
    if (statusAnimation.startsWith('blue-demon')) {
      final path = 'assets/status/blue-demon/$statusAnimation.json';
      print("FriendCard: Using direct animation path: $path");
      return path;
    } else if (statusAnimation.startsWith('usr-emoji')) {
      final path = 'assets/status/usr-emoji/$statusAnimation.json';
      print("FriendCard: Using direct animation path: $path");
      return path;
    }
    
    print("FriendCard: Could not determine animation path for: $statusAnimation");
    return null;
  }
  
  // Format last seen timestamp
  String _formatLastSeen(int timestamp) {
    final now = DateTime.now();
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(lastSeen);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(lastSeen);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get friend data with privacy settings respect
    final bool isOnline = widget.friend['isOnline'] == true;
    final int lastSeenTimestamp = widget.friend['lastSeen'] ?? 0;
    final bool hasLastSeen = lastSeenTimestamp > 0;
    
    // Check privacy settings of the friend
    final bool showOnlineStatus = widget.friend['privacySettings']?['showOnlineStatus'] ?? true;
    final bool showLastSeen = widget.friend['privacySettings']?['showLastSeen'] ?? true;
    
    final String displayName = widget.friend['displayName'] ?? 'Unknown';
    final String? photoURL = widget.friend['photoURL'];
    final String? statusAnimation = _getStatusAnimationAsset();

    // Base card widget
    Widget card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background color
            Positioned.fill(
              child: Container(
                color: Colors.brown.shade900,
              ),
            ),
        
            // Profile Photo
            Positioned.fill(
              child: photoURL != null && photoURL.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoURL,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.brown.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD4A76A),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.brown.shade100,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.brown.shade300,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.brown.shade100,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.brown.shade300,
                      ),
                    ),
            ),

            // Status Animation (centered in top middle)
            if (isOnline && statusAnimation != null && showOnlineStatus)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Lottie.asset(
                      statusAnimation,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print("FriendCard: Error loading animation $statusAnimation: $error");
                        return const SizedBox.shrink(); 
                      },
                    ),
                  ),
                ),
              ),

            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.5, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // Status and Name
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Online status indicator - only show if friend allows it
                      showOnlineStatus ? Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: isOnline 
                                    ? Colors.green.withOpacity(0.6) 
                                    : Colors.transparent,
                                  blurRadius: 10,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ) : const SizedBox.shrink(),
                      
                      // Last seen (only shown if user is offline, has last seen timestamp, and allows showing it)
                      if (!isOnline && hasLastSeen && showLastSeen)
                        Text(
                          _formatLastSeen(lastSeenTimestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ).animate(autoPlay: true)
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutQuad),
            ),
          ],
        ),
      ),
    );

    // Add selection effect if selected
    if (widget.isSelected) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFD4A76A),
            width: 3,
          ),
        ),
        child: card,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: card,
    );
  }
} 