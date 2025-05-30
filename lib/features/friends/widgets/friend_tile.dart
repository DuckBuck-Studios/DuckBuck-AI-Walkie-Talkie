import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
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
  final Function(RelationshipModel)? onShowBlockDialog;

  const FriendTile({
    super.key,
    required this.relationship,
    required this.provider,
    required this.onShowRemoveDialog,
    this.onShowBlockDialog,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoTile(context);
    } else {
      return _buildMaterialTile(context);
    }
  }

  Widget _buildMaterialTile(BuildContext context) {
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
          // color: Colors.white, // Assuming dark theme, adjust if needed
        ),
      ),
      subtitle: Text(
        'Friend since ${relationship.acceptedAt != null ? DateFormatter.formatRelativeTime(relationship.acceptedAt!) : 'Unknown'}',
        // style: TextStyle(color: Colors.grey[400]), // Adjust color if needed
      ),
      trailing: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onSurfaceVariant),
          tooltip: 'Friend Options',
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.under,
          onSelected: (value) {
            if (value == 'remove') {
              onShowRemoveDialog(relationship);
            } else if (value == 'block' && onShowBlockDialog != null) {
              onShowBlockDialog!(relationship);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  const Text('Remove Friend'),
                ],
              ),
            ),
            if (onShowBlockDialog != null)
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Theme.of(context).colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    const Text('Block User'),
                  ],
                ),
              ),
          ],
        ),
      ), 
    );
  }

  Widget _buildCupertinoTile(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getCachedProfile(relationship, currentUserId);

    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ProfileAvatar(
        photoURL: profile?.photoURL,
        displayName: profile?.displayName ?? 'Unknown User',
      ),
      title: Text(
        profile?.displayName ?? 'Unknown User',
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Friend since ${relationship.acceptedAt != null ? DateFormatter.formatRelativeTime(relationship.acceptedAt!) : 'Unknown'}',
        style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.ellipsis),
        onPressed: () {
          showCupertinoModalPopup(
            context: context,
            builder: (BuildContext modalContext) => CupertinoActionSheet(
              actions: <CupertinoActionSheetAction>[
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.pop(modalContext);
                    onShowRemoveDialog(relationship);
                  },
                  child: const Text('Remove Friend'),
                ),
                if (onShowBlockDialog != null)
                  CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    onPressed: () {
                      Navigator.pop(modalContext);
                      onShowBlockDialog!(relationship);
                    },
                    child: const Text('Block User'),
                  ),
              ],
              cancelButton: CupertinoActionSheetAction(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.pop(modalContext);
                },
              ),
            ),
          );
        },
      ),
      // No onTap - removing interaction to focus only on add/remove/block functionality
    );
  }
}

// Helper for CupertinoListTile if not available or for custom styling
/// A skeleton version of the friend tile for loading states
class FriendTileSkeleton extends StatelessWidget {
  final bool isIOS;
  
  const FriendTileSkeleton({
    super.key, 
    this.isIOS = false,
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: isIOS ? _buildCupertinoSkeleton(context) : _buildMaterialSkeleton(context),
    );
  }
  
  Widget _buildMaterialSkeleton(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const CircleAvatar(radius: 24),
      title: const Text('Friend Name'),
      subtitle: const Text('Friend since Jan 1, 2025'),
      trailing: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.more_horiz, color: Colors.grey.shade400),
      ),
    );
  }
  
  Widget _buildCupertinoSkeleton(BuildContext context) {
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const CircleAvatar(radius: 24),
      title: const Text('Friend Name'),
      subtitle: const Text('Friend since Jan 1, 2025'),
      trailing: Icon(CupertinoIcons.ellipsis, color: CupertinoColors.systemGrey),
    );
  }
}

class CupertinoListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const CupertinoListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        color: CupertinoTheme.of(context).scaffoldBackgroundColor, // Or another appropriate color
        child: Row(
          children: <Widget>[
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 16.0),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DefaultTextStyle(
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                    child: title
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2.0),
                    DefaultTextStyle(
                      style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
                      child: subtitle!
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 16.0),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
