import 'package:flutter/material.dart';
import '../../../../core/models/relationship_model.dart';
import '../../../../core/theme/app_colors.dart';
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
        // Removed 'Friends' text header
        const SizedBox(height: 8),
        _buildContent(context),
        const SizedBox(height: 80),  
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (provider.isLoadingFriends) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
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
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some friends to get started!',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            // Removed "Add Friends" button
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surfaceBlack,
      child: Column(
        children: [
          ...provider.friends.map((relationship) =>
            FriendTile(
              relationship: relationship,
              provider: provider,
              onShowRemoveDialog: (relationship) => showRemoveFriendDialog(context, relationship),
            ),
          ),
          if (provider.friendsHasMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: provider.isLoadingMoreFriends
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal.withValues(alpha: 0.2),
                      foregroundColor: AppColors.accentTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => provider.loadMoreFriends(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Load More'),
                  ),
            ),
        ],
      ),
    );
  }
  
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
