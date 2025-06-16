import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'home_avatar.dart';
import 'dart:io' show Platform;

class HomeFriendsSection extends StatelessWidget {
  final List<Map<String, dynamic>> friends;
  final bool isLoading;
  final Function(Map<String, dynamic>)? onFriendTap;
  final VoidCallback? onAiAgentTap;

  const HomeFriendsSection({
    super.key,
    required this.friends,
    this.isLoading = false,
    this.onFriendTap,
    this.onAiAgentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildCupertinoContent(context) : _buildMaterialContent(context);
  }

  Widget _buildCupertinoContent(BuildContext context) {
    if (isLoading) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Colors.white24,
            secondary: Colors.white38,
            surface: Colors.white24,
            onSurface: Colors.white24,
          ),
        ),
        child: Skeletonizer(
          enabled: true,
          effect: ShimmerEffect(
            baseColor: Colors.white24,
            highlightColor: Colors.white38,
            duration: const Duration(milliseconds: 1000),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
              children: List.generate(
                3, // Show 3 skeleton tiles for home
                (index) => CupertinoListTile(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                  ),
                  title: Text(
                    'Friend Name Loading',
                    style: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (friends.isEmpty) {
      // Show AI agent even when no friends
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // DuckBuck AI Agent - always visible
            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
              children: [
                CupertinoListTile(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: CupertinoColors.systemGrey6.resolveFrom(context),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            CupertinoIcons.sparkles,
                            color: CupertinoColors.systemBlue.resolveFrom(context),
                            size: 24,
                          );
                        },
                      ),
                    ),
                  ),
                  title: Text(
                    'DuckBuck AI',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  onTap: onAiAgentTap,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Show only first 5 friends on home screen
    final displayFriends = friends.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Friends List including AI Agent
          CupertinoListSection.insetGrouped(
            backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            children: [
              // DuckBuck AI Agent as first tile
              CupertinoListTile(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: CupertinoColors.systemGrey6.resolveFrom(context),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          CupertinoIcons.sparkles,
                          color: CupertinoColors.systemBlue.resolveFrom(context),
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                title: Text(
                  'DuckBuck AI',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                onTap: onAiAgentTap,
              ),
              // Add friends after AI agent
              ...displayFriends.map((friendProfile) {
                return _buildFriendTile(context, friendProfile, true);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: Colors.white24,
            secondary: Colors.white38,
            surface: Colors.white24,
            onSurface: Colors.white24,
          ),
        ),
        child: Skeletonizer(
          enabled: true,
          effect: ShimmerEffect(
            baseColor: Colors.white24,
            highlightColor: Colors.white38,
            duration: const Duration(milliseconds: 1000),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                children: List.generate(
                  3, // Show 3 skeleton tiles for home
                  (index) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                    ),
                    title: Text(
                      'Friend Name Loading',
                      style: TextStyle(color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (friends.isEmpty) {
      // Show AI agent even when no friends
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // DuckBuck AI Agent - always visible
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.auto_awesome,
                          color: theme.colorScheme.primary,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                title: Text(
                  'DuckBuck AI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                onTap: onAiAgentTap,
              ),
            ),
          ],
        ),
      );
    }

    // Show only first 5 friends on home screen
    final displayFriends = friends.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Friends List including AI Agent
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayFriends.length + 1, // +1 for AI agent
              itemBuilder: (context, index) {
                if (index == 0) {
                  // DuckBuck AI Agent as first tile
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.auto_awesome,
                              color: theme.colorScheme.primary,
                              size: 24,
                            );
                          },
                        ),
                      ),
                    ),
                    title: Text(
                      'DuckBuck AI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    onTap: onAiAgentTap,
                  );
                } else {
                  // Friend tiles
                  final friendProfile = displayFriends[index - 1];
                  return _buildFriendTile(context, friendProfile, false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friendProfile, bool isIOS) {
    final onTap = onFriendTap != null ? () => onFriendTap!(friendProfile) : null;
    
    if (isIOS) {
      return CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Hero(
          tag: 'friend_photo_${friendProfile['displayName'] ?? 'Unknown User'}',
          child: HomeAvatar(
            photoURL: friendProfile['photoURL'],
            displayName: friendProfile['displayName'] ?? 'Unknown User',
            radius: 18,
          ),
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        onTap: onTap,
      );
    } else {
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Hero(
          tag: 'friend_photo_${friendProfile['displayName'] ?? 'Unknown User'}',
          child: HomeAvatar(
            photoURL: friendProfile['photoURL'],
            displayName: friendProfile['displayName'] ?? 'Unknown User',
            radius: 18,
          ),
        ),
        title: Text(
          friendProfile['displayName'] ?? 'Unknown User',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      );
    }
  }
}
