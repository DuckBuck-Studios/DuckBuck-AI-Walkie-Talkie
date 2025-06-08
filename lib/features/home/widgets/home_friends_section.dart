import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      return Skeletonizer(
        enabled: true,
        child: CupertinoListSection.insetGrouped(
          backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          children: List.generate(
            3, // Show 3 skeleton tiles for home
            (index) => CupertinoListTile(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(radius: 20),
              title: const Text('Friend Name Loading'),
            ),
          ),
        ),
      );
    }

    if (friends.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.group,
              size: 64,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Friends tab to add some!',
              style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show only first 5 friends on home screen
    final displayFriends = friends.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: CupertinoListSection.insetGrouped(
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        children: displayFriends.asMap().entries.map((entry) {
          final index = entry.key;
          final friendProfile = entry.value;
          return _buildFriendTile(context, friendProfile, true)
            .animate()
            .fadeIn(
              duration: 400.ms,
              delay: Duration(milliseconds: index * 100),
              curve: Curves.easeOut,
            )
            .slideY(
              duration: 500.ms,
              delay: Duration(milliseconds: index * 100),
              begin: 0.3,
              end: 0.0,
              curve: Curves.easeOutCubic,
            );
        }).toList(),
      ),
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Skeletonizer(
        enabled: true,
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
                leading: const CircleAvatar(radius: 20),
                title: const Text('Friend Name Loading'),
              ),
            ),
          ),
        ),
      );
    }

    if (friends.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Friends tab to add some!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show only first 5 friends on home screen
    final displayFriends = friends.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: displayFriends.asMap().entries.map((entry) {
            final index = entry.key;
            final friendProfile = entry.value;
            return _buildFriendTile(context, friendProfile, false)
              .animate()
              .fadeIn(
                duration: 400.ms,
                delay: Duration(milliseconds: index * 100),
                curve: Curves.easeOut,
              )
              .slideY(
                duration: 500.ms,
                delay: Duration(milliseconds: index * 100),
                begin: 0.3,
                end: 0.0,
                curve: Curves.easeOutCubic,
              );
          }).toList(),
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
