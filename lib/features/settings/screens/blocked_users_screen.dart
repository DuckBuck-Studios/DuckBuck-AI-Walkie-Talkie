import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../../friends/providers/relationship_provider.dart';
import '../../friends/widgets/profile_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RelationshipProvider>(context, listen: false).loadBlockedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        leading: IconButton(
          icon: Icon(isIOS ? CupertinoIcons.back : Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<RelationshipProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingBlocked) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48.0,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${provider.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadBlockedUsers(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIOS ? CupertinoIcons.shield : Icons.shield,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No blocked users',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'When you block someone, they will appear here and won\'t be able to send you friend requests',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.blockedUsers.length,
            itemBuilder: (context, index) {
              final relationship = provider.blockedUsers[index];
              return _BlockedUserTile(
                relationship: relationship,
                provider: provider,
              );
            },
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  final RelationshipModel relationship;
  final RelationshipProvider provider;

  const _BlockedUserTile({
    required this.relationship,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getProfileForRelationship(relationship, currentUserId);
    final isProcessing = provider.isBlockingUser(relationship.id);
    final bool isIOS = Platform.isIOS;

    return ListTile(
      leading: ProfileAvatar(
        photoURL: profile?['photoURL'],
        displayName: profile?['displayName'] ?? 'Unknown User',
      ),
      title: Text(profile?['displayName'] ?? 'Unknown User'),
      subtitle: const Text('Blocked'),
      trailing: isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () => _showUnblockDialog(context, relationship),
              child: Text(
                'Unblock',
                style: TextStyle(
                  color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                ),
              ),
            ),
    );
  }

  void _showUnblockDialog(BuildContext context, RelationshipModel relationship) {
    final profile = provider.getProfileForRelationship(relationship, relationship.blockerId ?? '');
    final userName = profile?['displayName'] ?? 'this user';
    final bool isIOS = Platform.isIOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Unblock $userName?'),
          content: Text(
            'Unblocking $userName will allow them to send you friend requests again.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('Unblock'),
              onPressed: () async {
                Navigator.pop(context);
                await provider.unblockUser(relationship.id);
                await provider.loadBlockedUsers();
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unblock $userName?'),
          content: Text(
            'Unblocking $userName will allow them to send you friend requests again.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Unblock'),
              onPressed: () async {
                Navigator.pop(context);
                await provider.unblockUser(relationship.id);
                await provider.loadBlockedUsers();
              },
            ),
          ],
        ),
      );
    }
  }
}
