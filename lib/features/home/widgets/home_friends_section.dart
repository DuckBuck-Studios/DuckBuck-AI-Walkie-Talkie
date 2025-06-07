import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../providers/home_provider.dart';
import '../../friends/widgets/friend_tile.dart' show FriendTileSkeleton;
import '../../friends/widgets/profile_avatar.dart';

class HomeFriendsSection extends StatelessWidget {
  final HomeProvider provider;
  final Function(BuildContext, Map<String, dynamic>)? onFriendTap;

  const HomeFriendsSection({
    super.key,
    required this.provider,
    this.onFriendTap,
  });

  @override
  Widget build(BuildContext context) {
    // Debug print to see what's happening
    print('HomeFriendsSection build: isLoading=${provider.isLoadingFriends}, friendsCount=${provider.friends.length}');
    return Platform.isIOS ? _buildCupertinoContent(context) : _buildMaterialContent(context);
  }

  Widget _buildCupertinoContent(BuildContext context) {
    if (provider.isLoadingFriends) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: List.generate(
            3, // Show 3 skeleton tiles for home
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FriendTileSkeleton(isIOS: true),
            ),
          ),
        ),
      );
    }

    if (provider.friends.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6, // Take up more vertical space
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
    final displayFriends = provider.friends.take(5).toList();
    print('Display friends count: ${displayFriends.length}');

    return CupertinoListSection.insetGrouped(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      children: displayFriends.map((friendProfile) =>
        _buildFriendTile(context, friendProfile, true)
      ).toList(),
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    final theme = Theme.of(context);

    if (provider.isLoadingFriends) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: List.generate(
            3, // Show 3 skeleton tiles for home
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FriendTileSkeleton(isIOS: false),
            ),
          ),
        ),
      );
    }

    if (provider.friends.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6, // Take up more vertical space
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
    final displayFriends = provider.friends.take(5).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: displayFriends.map((friendProfile) =>
          _buildFriendTile(context, friendProfile, false)
        ).toList(),
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friendProfile, bool isIOS) {
    // Debug output
    print('Building friend tile: ${friendProfile['uid']}, displayName: ${friendProfile['displayName']}, isIOS: $isIOS');

    if (isIOS) {
      return CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ProfileAvatar(
          photoURL: friendProfile['photoURL'],
          displayName: friendProfile['displayName'] ?? 'Unknown User',
          radius: 20, // Smaller for home screen
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onFriendTap != null ? () => onFriendTap!(context, friendProfile) : null,
      );
    } else {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ProfileAvatar(
          photoURL: friendProfile['photoURL'],
          displayName: friendProfile['displayName'] ?? 'Unknown User',
          radius: 20, // Smaller for home screen
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onFriendTap != null ? () => onFriendTap!(context, friendProfile) : null,
      );
    }
  }
}
