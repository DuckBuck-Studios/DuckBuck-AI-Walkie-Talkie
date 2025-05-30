import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../../../core/models/relationship_model.dart';
import '../../../../core/services/auth/auth_service_interface.dart';
import '../../../../core/services/service_locator.dart';
import '../../providers/friends_provider.dart';
import '../friend_tile.dart';

class FriendsSection extends StatelessWidget {
  final FriendsProvider provider;
  final Function(BuildContext, RelationshipModel) showRemoveFriendDialog;
  final Function(BuildContext, RelationshipModel)? showBlockUserDialog; // Add parameter for block dialog

  const FriendsSection({
    super.key,
    required this.provider,
    required this.showRemoveFriendDialog,
    this.showBlockUserDialog, // Optional parameter for showing block dialog
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Platform.isIOS ? _buildCupertinoContent(context) : _buildMaterialContent(context),
        const SizedBox(height: 80), // For FAB overlap
      ],
    );
  }

  Widget _buildCupertinoContent(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);

    if (provider.isLoadingFriends) {
      return Column(
        children: List.generate(
          5, // Show 5 skeleton tiles
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FriendTileSkeleton(isIOS: true),
          ),
        ),
      );
    }

    if (provider.friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        width: double.infinity,
        alignment: Alignment.center,
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
              style: cupertinoTheme.textTheme.navTitleTextStyle.copyWith(
                color: cupertinoTheme.textTheme.textStyle.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some friends to get started!',
              style: cupertinoTheme.textTheme.tabLabelTextStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return CupertinoListSection.insetGrouped(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      header: provider.friends.isNotEmpty ? const Padding(padding: EdgeInsets.zero) : null, // Keep consistent with Material if no header text
      children: provider.friends.map((relationship) =>
        FriendTile(
          relationship: relationship,
          provider: provider,
          onShowRemoveDialog: (relationship) => showRemoveFriendDialog(context, relationship),
          onShowBlockDialog: showBlockUserDialog != null
              ? (relationship) => showBlockUserDialog!(context, relationship)
              : null,
        ),
      ).toList(),
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    final theme = Theme.of(context);

    if (provider.isLoadingFriends) {
      return Column(
        children: List.generate(
          5, // Show 5 skeleton tiles
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FriendTileSkeleton(isIOS: false),
          ),
        ),
      );
    }

    if (provider.friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        width: double.infinity,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some friends to get started!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0, // Flatter design, more modern
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest, // Or surfaceContainer
      margin: const EdgeInsets.symmetric(horizontal: 16.0), // Add some margin for the card
      child: Column(
        children: [
          ...provider.friends.map((relationship) =>
            FriendTile(
              relationship: relationship,
              provider: provider,
              onShowRemoveDialog: (relationship) => showRemoveFriendDialog(context, relationship),
              onShowBlockDialog: showBlockUserDialog != null
                  ? (relationship) => showBlockUserDialog!(context, relationship)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
  
  // SnackBar is Material-specific. For a truly platform-adaptive UI,
  // this might need a Cupertino equivalent (e.g., a custom toast or alert).
  // For now, keeping it as is, as it's a minor informational message.
  void showAddFriendAction(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Use the + button to add friends'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {
            scaffoldMessenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Shows a platform-specific dialog to confirm blocking a user
  static void showBlockFriendDialog(BuildContext context, RelationshipModel relationship, FriendsProvider provider) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getCachedProfile(relationship, currentUserId);
    final userName = profile?.displayName ?? 'this user';
    
    if (Platform.isIOS) {
      // iOS-style dialog
      showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return CupertinoAlertDialog(
            title: Text('Block $userName?'),
            content: Text(
              'Blocking $userName will remove them from your friends list and prevent them from sending you friend requests in the future. You can unblock them later from your settings.'
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final success = await provider.blockUser(relationship.id);
                  if (success && context.mounted) {
                    _showBlockSuccessNotification(context, userName);
                  }
                },
                child: const Text('Block User'),
              ),
            ],
          );
        }
      );
    } else {
      // Material-style dialog
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Block $userName?'),
            content: Text(
              'Blocking $userName will remove them from your friends list and prevent them from sending you friend requests in the future. You can unblock them later from your settings.'
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final success = await provider.blockUser(relationship.id);
                  if (success && context.mounted) {
                    _showBlockSuccessNotification(context, userName);
                  }
                },
                child: Text(
                  'Block User',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          );
        }
      );
    }
  }
  
  /// Shows a notification that a user was successfully blocked
  static void _showBlockSuccessNotification(BuildContext context, String userName) {
    if (Platform.isIOS) {
      // iOS-style notification
      showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('User Blocked'),
          content: Text('You have blocked $userName successfully.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } else {
      // Material-style notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName has been blocked'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  }
}
