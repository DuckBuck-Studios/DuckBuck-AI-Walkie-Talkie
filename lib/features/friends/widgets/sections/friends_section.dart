import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../../../core/models/relationship_model.dart';
import '../../providers/friends_provider.dart';
import '../friend_tile.dart';

class FriendsSection extends StatelessWidget {
  final FriendsProvider provider;
  final Function(BuildContext, RelationshipModel) showRemoveFriendDialog;

  const FriendsSection({
    super.key,
    required this.provider,
    required this.showRemoveFriendDialog,
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CupertinoActivityIndicator()),
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
        ),
      ).toList(),
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    final theme = Theme.of(context);

    if (provider.isLoadingFriends) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
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
}
