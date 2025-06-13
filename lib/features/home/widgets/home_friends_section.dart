import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'home_avatar.dart';
import 'dart:io' show Platform;

class HomeFriendsSection extends StatelessWidget {
  final List<Map<String, dynamic>> friends;
  final bool isLoading;
  final Function(Map<String, dynamic>)? onFriendTap;

  const HomeFriendsSection({
    super.key,
    required this.friends,
    this.isLoading = false,
    this.onFriendTap,
  });

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildCupertinoContent(context) : _buildMaterialContent(context);
  }

  Widget _buildCupertinoContent(BuildContext context) {
    if (isLoading) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Colors.white24,
            secondary: Colors.white38,
            surface: Colors.white24,
            onSurface: Colors.white24,
          ),
        ),
        child: Skeletonizer(
          enabled: true,
          effect: ShimmerEffect(
            baseColor: Colors.white24,
            highlightColor: Colors.white38,
            duration: const Duration(milliseconds: 1000),
          ),
          child: CupertinoListSection.insetGrouped(
            backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            children: List.generate(
              3, // Show 3 skeleton tiles for home
              (index) => CupertinoListTile(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white24,
                ),
                title: Text(
                  'Friend Name Loading',
                  style: TextStyle(color: Colors.white24),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (friends.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.person_2,
                  size: 80,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                const SizedBox(height: 24),
                Text(
                  'No friends yet',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Go to Friends tab to add some!',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show only first 5 friends on home screen
    final displayFriends = friends.take(5).toList();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CupertinoListSection.insetGrouped(
          backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          children: displayFriends.asMap().entries.map((entry) {
            final friendProfile = entry.value;
            return _buildFriendTile(context, friendProfile, true);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: Colors.white24,
            secondary: Colors.white38,
            surface: Colors.white24,
            onSurface: Colors.white24,
          ),
        ),
        child: Skeletonizer(
          enabled: true,
          effect: ShimmerEffect(
            baseColor: Colors.white24,
            highlightColor: Colors.white38,
            duration: const Duration(milliseconds: 1000),
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: theme.colorScheme.surfaceContainerHighest,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: List.generate(
                3, // Show 3 skeleton tiles for home
                (index) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                  ),
                  title: Text(
                    'Friend Name Loading',
                    style: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (friends.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 24),
                Text(
                  'No friends yet',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Go to Friends tab to add some!',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show only first 5 friends on home screen
    final displayFriends = friends.take(5).toList();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: theme.colorScheme.surfaceContainerHighest,
          child: ListView.builder(
            itemCount: displayFriends.length,
            itemBuilder: (context, index) {
              final friendProfile = displayFriends[index];
              return _buildFriendTile(context, friendProfile, false);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friendProfile, bool isIOS) {
    final onTap = onFriendTap != null ? () => onFriendTap!(friendProfile) : null;
    
    if (isIOS) {
      return CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Hero(
          tag: 'friend_photo_${friendProfile['displayName'] ?? 'Unknown User'}',
          child: HomeAvatar(
            photoURL: friendProfile['photoURL'],
            displayName: friendProfile['displayName'] ?? 'Unknown User',
            radius: 18,
          ),
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        onTap: onTap,
      );
    } else {
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Hero(
          tag: 'friend_photo_${friendProfile['displayName'] ?? 'Unknown User'}',
          child: HomeAvatar(
            photoURL: friendProfile['photoURL'],
            displayName: friendProfile['displayName'] ?? 'Unknown User',
            radius: 18,
          ),
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      );
    }
  }
}
