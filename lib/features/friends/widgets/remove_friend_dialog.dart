import 'package:flutter/material.dart';
import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';

class RemoveFriendDialog extends StatelessWidget {
  final RelationshipModel relationship;
  final FriendsProvider provider;

  const RemoveFriendDialog({
    super.key,
    required this.relationship,
    required this.provider,
  });

  static Future<void> show(BuildContext context, RelationshipModel relationship, FriendsProvider provider) {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return RemoveFriendDialog(
          relationship: relationship,
          provider: provider,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getCachedProfile(relationship, currentUserId);
    
    return AlertDialog(
      backgroundColor: AppColors.surfaceBlack,
      title: Text(
        'Remove Friend',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Text(
        'Are you sure you want to remove ${profile?.displayName ?? 'this user'} from your friends?',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            final success = await provider.removeFriend(relationship.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success 
                      ? 'Friend removed' 
                      : 'Failed to remove friend',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            }
          },
          child: const Text('Remove'),
        ),
      ],
    );
  }
}
