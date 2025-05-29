import 'package:flutter/material.dart';
import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../providers/friends_provider.dart';
import 'profile_avatar.dart';

class RequestTile extends StatelessWidget {
  final RelationshipModel relationship;
  final bool isIncoming;
  final FriendsProvider provider;

  const RequestTile({
    super.key,
    required this.relationship,
    required this.isIncoming,
    required this.provider,
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
        'Request ${isIncoming ? 'from' : 'to'} user',
        style: TextStyle(color: Colors.grey[400]),
      ),
      trailing: isIncoming
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                ),
                onPressed: () => provider.acceptFriendRequest(relationship.id),
                tooltip: 'Accept',
              ),
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: Colors.red[600],
                ),
                onPressed: () => provider.declineFriendRequest(relationship.id),
                tooltip: 'Decline',
              ),
            ],
          )
        : IconButton(
            icon: Icon(
              Icons.cancel_outlined,
              color: Colors.orange[600],
            ),
            onPressed: () => provider.cancelFriendRequest(relationship.id),
            tooltip: 'Cancel',
          ),
    );
  }
}
