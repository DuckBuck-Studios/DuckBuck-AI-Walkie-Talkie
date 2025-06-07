import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

/// Reusable tile widget for displaying individual friends
/// 
/// Features:
/// - Platform-specific design (iOS/Android)
/// - Friend photo with fallback to initials
/// - Clean name display
/// - Tap handling for friend interactions
/// 
/// This widget is optimized for performance and follows platform conventions.
class FriendListTile extends StatelessWidget {
  /// Friend data containing name, photo, and other details
  final Map<String, dynamic> friend;
  
  /// Callback when the tile is tapped
  final VoidCallback? onTap;

  const FriendListTile({
    super.key,
    required this.friend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = friend['displayName'] ?? friend['name'] ?? 'Unknown';
    final photoUrl = friend['photoURL'];

    if (Platform.isIOS) {
      return _buildCupertinoTile(context, name, photoUrl);
    } else {
      return _buildMaterialTile(context, name, photoUrl);
    }
  }

  /// Builds iOS-style friend tile using Cupertino design
  Widget _buildCupertinoTile(BuildContext context, String name, String? photoUrl) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.separator.resolveFrom(context).withOpacity(0.3),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _buildAvatar(name, photoUrl),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          CupertinoIcons.chevron_right,
          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  /// Builds Android-style friend tile using Material design
  Widget _buildMaterialTile(BuildContext context, String name, String? photoUrl) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildAvatar(name, photoUrl),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }

  /// Builds friend avatar with photo or initials fallback
  Widget _buildAvatar(String name, String? photoUrl) {
    // If photo URL is available, use network image
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // If image fails to load, fall back to initials
        },
        child: photoUrl.isEmpty ? _buildInitialsWidget(name) : null,
      );
    }

    // Fallback to initials avatar
    return _buildInitialsAvatar(name);
  }

  /// Builds avatar with user initials and color based on name
  Widget _buildInitialsAvatar(String name) {
    _getInitials(name);
    final backgroundColor = _getAvatarColor(name);

    return CircleAvatar(
      radius: 24,
      backgroundColor: backgroundColor,
      child: _buildInitialsWidget(name),
    );
  }

  /// Builds the initials text widget
  Widget _buildInitialsWidget(String name) {
    final initials = _getInitials(name);
    
    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  /// Extracts initials from full name (max 2 characters)
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Generates a consistent color for the avatar based on name hash
  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.indigo.shade400,
      Colors.pink.shade400,
      Colors.amber.shade400,
      Colors.cyan.shade400,
      Colors.lime.shade400,
      Colors.deepOrange.shade400,
    ];
    
    // Use name hash to ensure consistent color for same name
    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }
}
