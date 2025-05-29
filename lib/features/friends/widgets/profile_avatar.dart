import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';

/// A reusable cached profile avatar widget with fallback to initials
class ProfileAvatar extends StatelessWidget {
  final String? photoURL;
  final String displayName;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.displayName,
    this.photoURL,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceBlack,
      backgroundImage: photoURL == null
          ? null
          : CachedNetworkImageProvider(
              photoURL!,
            ),
      child: photoURL == null
          ? Text(
              _getInitials(displayName),
              style: TextStyle(
                fontSize: radius * 0.6,
                fontWeight: FontWeight.bold,
                color: AppColors.accentBlue,
              ),
            )
          : null,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }
}
