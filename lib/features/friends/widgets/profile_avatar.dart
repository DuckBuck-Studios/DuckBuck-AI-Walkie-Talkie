import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final hasImage = photoURL != null && photoURL!.isNotEmpty;

    if (Platform.isIOS) {
      return _buildCupertinoAvatar(context, hasImage);
    } else {
      return _buildMaterialAvatar(context, hasImage);
    }
  }

  Widget _buildMaterialAvatar(BuildContext context, bool hasImage) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.secondaryContainer,
      backgroundImage: hasImage
          ? CachedNetworkImageProvider(photoURL!)
          : null,
      child: !hasImage
          ? Text(
              _getInitials(displayName),
              style: TextStyle(
                fontSize: radius * 0.6,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            )
          : null,
    );
  }

  Widget _buildCupertinoAvatar(BuildContext context, bool hasImage) {
    final theme = CupertinoTheme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.brightness == Brightness.dark 
          ? CupertinoColors.systemGrey3.darkColor 
          : CupertinoColors.systemGrey5.color,
      backgroundImage: hasImage
          ? CachedNetworkImageProvider(photoURL!)
          : null,
      child: !hasImage
          ? Text(
              _getInitials(displayName),
              style: TextStyle(
                fontSize: radius * 0.6,
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark
                    ? CupertinoColors.white
                    : CupertinoColors.black,
              ),
            )
          : null,
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
