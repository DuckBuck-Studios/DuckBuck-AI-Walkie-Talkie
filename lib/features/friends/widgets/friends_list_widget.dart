import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/relationship_provider.dart';
import 'friend_list_tile.dart';
import 'empty_state_widget.dart';
import 'dart:io' show Platform;

/// Production-level widget for displaying the friends list with real-time updates
/// 
/// Features:
/// - Real-time updates from RelationshipProvider
/// - Platform-specific design (iOS/Android)
/// - Loading states and error handling
/// - Pull-to-refresh functionality
/// - Friend removal with confirmation dialogs
/// 
/// This widget automatically subscribes to relationship updates and rebuilds
/// when the friends list changes in real-time.
class FriendsListWidget extends StatelessWidget {
  const FriendsListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RelationshipProvider>(
      builder: (context, relationshipProvider, child) {
        // Handle loading state
        if (relationshipProvider.isLoadingFriends && relationshipProvider.friends.isEmpty) {
          return _buildLoadingState();
        }

        // Handle error state
        if (relationshipProvider.error != null && relationshipProvider.friends.isEmpty) {
          return _buildErrorState(context, relationshipProvider);
        }

        // Handle empty state
        if (relationshipProvider.friends.isEmpty) {
          return EmptyStateWidget(
            icon: Platform.isIOS ? CupertinoIcons.person_2 : Icons.people_outline,
            title: 'No Friends Yet',
            message: 'Add friends to start connecting with them.',
          );
        }

        // Build friends list
        return _buildFriendsList(context, relationshipProvider);
      },
    );
  }

  /// Builds the loading state with platform-specific indicators
  Widget _buildLoadingState() {
    if (Platform.isIOS) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 16),
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
  }

  /// Builds the error state with retry functionality
  Widget _buildErrorState(BuildContext context, RelationshipProvider provider) {
    return EmptyStateWidget(
      icon: Platform.isIOS ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
      title: 'Unable to Load Friends',
      message: provider.error ?? 'Something went wrong. Please try again.',
      actionText: 'Retry',
      onAction: () => provider.initialize(),
    );
  }

  /// Builds the friends list with pull-to-refresh
  Widget _buildFriendsList(BuildContext context, RelationshipProvider provider) {
    final friends = provider.friends;

    if (Platform.isIOS) {
      return CustomScrollView(
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () => provider.initialize(),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FriendListTile(
                    friend: friends[index],
                    onTap: () => _showFriendActions(context, friends[index]),
                  ),
                ),
                childCount: friends.length,
              ),
            ),
          ),
        ],
      );
    } else {
      return RefreshIndicator(
        onRefresh: () => provider.initialize(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FriendListTile(
              friend: friends[index],
              onTap: () => _showFriendActions(context, friends[index]),
            ),
          ),
        ),
      );
    }
  }

  /// Shows friend action dialog (remove, block)
  void _showFriendActions(BuildContext context, Map<String, dynamic> friend) {
    final friendName = friend['displayName'] ?? friend['name'] ?? 'Friend';

    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(friendName),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showRemoveFriendDialog(context, friend);
              },
              isDestructiveAction: true,
              child: const Text('Remove Friend'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showBlockFriendDialog(context, friend);
              },
              isDestructiveAction: true,
              child: const Text('Block'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                friendName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('Remove Friend', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveFriendDialog(context, friend);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockFriendDialog(context, friend);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Shows confirmation dialog for removing a friend
  void _showRemoveFriendDialog(BuildContext context, Map<String, dynamic> friend) {
    final friendName = friend['displayName'] ?? friend['name'] ?? 'Friend';
    final userId = friend['uid'] ?? friend['id'];

    if (userId == null) return;

    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Remove Friend'),
          content: Text('Are you sure you want to remove $friendName from your friends list?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Remove'),
              onPressed: () async {
                Navigator.pop(context);
                await _removeFriend(context, userId);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Friend'),
          content: Text('Are you sure you want to remove $friendName from your friends list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _removeFriend(context, userId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }
  }

  /// Removes a friend using the RelationshipProvider
  Future<void> _removeFriend(BuildContext context, String userId) async {
    final provider = Provider.of<RelationshipProvider>(context, listen: false);
    
    final success = await provider.removeFriend(userId);
    
    if (!success && context.mounted) {
      final errorMessage = provider.error ?? 'Failed to remove friend';
      
      if (Platform.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Shows confirmation dialog for blocking a friend
  void _showBlockFriendDialog(BuildContext context, Map<String, dynamic> friend) {
    final friendName = friend['displayName'] ?? friend['name'] ?? 'Friend';
    final userId = friend['uid'] ?? friend['id'];

    if (userId == null) return;

    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Block Friend'),
          content: Text(
            'Are you sure you want to block $friendName? They will be removed from your friends list and won\'t be able to send you friend requests.'
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Block'),
              onPressed: () async {
                Navigator.pop(context);
                await _blockFriend(context, userId, friendName);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Block Friend'),
          content: Text(
            'Are you sure you want to block $friendName? They will be removed from your friends list and won\'t be able to send you friend requests.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _blockFriend(context, userId, friendName);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Block'),
            ),
          ],
        ),
      );
    }
  }

  /// Blocks a friend using the RelationshipProvider
  Future<void> _blockFriend(BuildContext context, String userId, String friendName) async {
    final provider = Provider.of<RelationshipProvider>(context, listen: false);
    
    final success = await provider.blockUser(userId);
    
    if (!success && context.mounted) {
      final errorMessage = provider.error ?? 'Failed to block friend';
      
      if (Platform.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else if (success && context.mounted) {
      // Show success message
      if (Platform.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Friend Blocked'),
            content: Text('$friendName has been blocked successfully.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$friendName has been blocked'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    }
  }
}
