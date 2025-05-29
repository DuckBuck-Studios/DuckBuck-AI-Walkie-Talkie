import 'package:flutter/material.dart';
import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../providers/friends_provider.dart';
import 'profile_avatar.dart';
import 'date_formatter.dart';

class FriendTile extends StatelessWidget {
  final RelationshipModel relationship;
  final FriendsProvider provider;
  final Function(RelationshipModel) onShowRemoveDialog;

  const FriendTile({
    super.key,
    required this.relationship,
    required this.provider,
    required this.onShowRemoveDialog,
  });

  @override
  Widget build(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getCachedProfile(relationship, currentUserId);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ProfileAvatar(
        photoURL: profile?.photoURL,
        displayName: profile?.displayName ?? 'Unknown User',
      ),
      title: Text(
        profile?.displayName ?? 'Unknown User',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        'Friend since ${relationship.acceptedAt != null ? DateFormatter.formatRelativeTime(relationship.acceptedAt!) : 'Unknown'}',
        style: TextStyle(color: Colors.grey[400]),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.grey[400]),
        onSelected: (value) {
          if (value == 'remove') {
            onShowRemoveDialog(relationship);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('Remove Friend'),
              ],
            ),
          ),
        ],
      ),
      onTap: () {
        // TODO: Navigate to friend's profile
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tapped on ${profile?.displayName ?? 'Unknown User'}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
