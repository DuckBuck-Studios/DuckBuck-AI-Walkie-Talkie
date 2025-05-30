import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../providers/home_provider.dart';
import '../../friends/widgets/friend_tile.dart' show FriendTileSkeleton;
import '../../friends/widgets/profile_avatar.dart';
import '../../friends/widgets/date_formatter.dart';

class HomeFriendsSection extends StatelessWidget {
  final HomeProvider provider;
  final Function(BuildContext, RelationshipModel)? onFriendTap;

  const HomeFriendsSection({
    super.key,
    required this.provider,
    this.onFriendTap,
  });

  @override
  Widget build(BuildContext context) {
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

    return CupertinoListSection.insetGrouped(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      children: displayFriends.map((relationship) =>
        _buildFriendTile(context, relationship, true)
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
        children: displayFriends.map((relationship) =>
          _buildFriendTile(context, relationship, false)
        ).toList(),
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, RelationshipModel relationship, bool isIOS) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getCachedProfile(relationship, currentUserId);

    if (isIOS) {
      return CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ProfileAvatar(
          photoURL: profile?.photoURL,
          displayName: profile?.displayName ?? 'Unknown User',
          radius: 20, // Smaller for home screen
        ),
        title: Text(
          profile?.displayName ?? 'Unknown User',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Friend since ${relationship.acceptedAt != null ? DateFormatter.formatRelativeTime(relationship.acceptedAt!) : 'Unknown'}',
          style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
        ),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
        onTap: onFriendTap != null ? () => onFriendTap!(context, relationship) : null,
      );
    } else {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ProfileAvatar(
          photoURL: profile?.photoURL,
          displayName: profile?.displayName ?? 'Unknown User',
          radius: 20, // Smaller for home screen
        ),
        title: Text(
          profile?.displayName ?? 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Friend since ${relationship.acceptedAt != null ? DateFormatter.formatRelativeTime(relationship.acceptedAt!) : 'Unknown'}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: onFriendTap != null ? () => onFriendTap!(context, relationship) : null,
      );
    }
  }
}
