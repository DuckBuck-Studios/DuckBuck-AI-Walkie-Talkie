import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
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
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
        onSelected: (value) {
          if (value == 'remove') {
            onShowRemoveDialog(relationship);
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
      onTap: () {
        // TODO: Navigate to friend's profile
        showCupertinoDialog(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text('Tapped on ${profile?.displayName ?? 'Unknown User'}'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(dialogContext),
              )
            ],
          ),
        );
      },
    );
  }
}

// Helper for CupertinoListTile if not available or for custom styling
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
