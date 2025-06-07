import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../providers/relationship_provider.dart';

class RemoveFriendDialog extends StatelessWidget {
  final RelationshipModel relationship;
  final RelationshipProvider provider;

  const RemoveFriendDialog({
    super.key,
    required this.relationship,
    required this.provider,
  });

  static Future<void> show(BuildContext context, RelationshipModel relationship, RelationshipProvider provider) {
    if (Platform.isIOS) {
      return showCupertinoDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return RemoveFriendDialog(
            relationship: relationship,
            provider: provider,
          );
        },
      );
    } else {
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
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoDialog(context);
    } else {
      return _buildMaterialDialog(context);
    }
  }

  Widget _buildCupertinoDialog(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getProfileForRelationship(relationship, currentUserId);

    return CupertinoAlertDialog(
      title: const Text('Remove Friend'),
      content: Text(
        'Are you sure you want to remove ${profile?['displayName'] ?? 'this user'} from your friends?',
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          child: const Text('Remove'),
          onPressed: () => _handleRemoveFriend(context, true),
        ),
      ],
    );
  }

  Widget _buildMaterialDialog(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getProfileForRelationship(relationship, currentUserId);
    
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(
        'Remove Friend',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Text(
        'Are you sure you want to remove ${profile?['displayName'] ?? 'this user'} from your friends?',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _handleRemoveFriend(context, false),
          child: const Text('Remove'),
        ),
      ],
    );
  }

  Future<void> _handleRemoveFriend(BuildContext context, bool isIOS) async {
    Navigator.of(context).pop();
    
    // Get the target user ID (the friend to remove)
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final targetUserId = relationship.getFriendId(currentUserId);
    
    final success = await provider.removeFriend(targetUserId);
    if (context.mounted) {
      final snackBar = SnackBar(
        content: Text(
          success 
            ? 'Friend removed' 
            : 'Failed to remove friend',
        ),
        backgroundColor: success 
          ? (isIOS ? CupertinoColors.activeGreen : Colors.green)
          : (isIOS ? CupertinoColors.destructiveRed : Colors.red),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
}
