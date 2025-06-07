import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'home_avatar.dart';
import 'dart:io' show Platform;

class HomeFriendsSection extends StatelessWidget {
  final List<Map<String, dynamic>> friends;
  final bool isLoading;

  const HomeFriendsSection({
    super.key,
    required this.friends,
    this.isLoading = false,
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
        children: displayFriends.map((friendProfile) =>
          _buildFriendTile(context, friendProfile, true)
        ).toList(),
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
          children: displayFriends.map((friendProfile) =>
            _buildFriendTile(context, friendProfile, false)
          ).toList(),
        ),
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friendProfile, bool isIOS) {
    if (isIOS) {
      return CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: HomeAvatar(
          photoURL: friendProfile['photoURL'],
          displayName: friendProfile['displayName'] ?? 'Unknown User',
          radius: 18,
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      );
    } else {
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: HomeAvatar(
          photoURL: friendProfile['photoURL'],
          displayName: friendProfile['displayName'] ?? 'Unknown User',
          radius: 18,
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      );
    }
  }
}

/// Simple CupertinoListTile implementation for consistent design
class CupertinoListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const CupertinoListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Row(
        children: <Widget>[
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12.0),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DefaultTextStyle(
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                  child: title
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2.0),
                  DefaultTextStyle(
                    style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
                    child: subtitle!
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16.0),
            trailing!,
          ],
        ],
      ),
    );
  }
}
