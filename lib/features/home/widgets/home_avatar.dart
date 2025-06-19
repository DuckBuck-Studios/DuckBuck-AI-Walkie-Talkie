import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeAvatar extends StatelessWidget {
  final String? photoURL;
  final String displayName;
  final double radius;

  const HomeAvatar({
    super.key,
    this.photoURL,
    required this.displayName,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (photoURL != null && photoURL!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(photoURL!),
        onBackgroundImageError: (_, _) {
          // Fallback to initials if image fails to load
        },
        child: photoURL!.isEmpty ? _buildInitialsAvatar() : null,
      );
    }

    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initials = _getInitials(displayName);
    final color = _getColorFromName(displayName);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
