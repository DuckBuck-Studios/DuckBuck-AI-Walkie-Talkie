import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
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
  final bool isLoadingAccept;
  final bool isLoadingDecline;
  final bool isLoadingCancel;  
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;  

  const RequestTile({
    super.key,
    required this.relationship,
    required this.isIncoming,
    required this.provider,
    required this.isLoadingAccept,
    required this.isLoadingDecline,
    required this.isLoadingCancel, 
    required this.onAccept,
    required this.onDecline,
    required this.onCancel, 
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
        isIncoming ? 'Wants to be your friend' : 'Request Sent',
      ),
      trailing: isIncoming ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoadingAccept)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary, size: 28),
              tooltip: 'Accept Request',
              onPressed: onAccept,
            ),
          const SizedBox(width: 8),
          if (isLoadingDecline)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error, size: 28),
              tooltip: 'Decline Request',
              onPressed: onDecline,
            ),
        ],
      ) : Row( // Actions for outgoing requests (Cancel button)
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoadingCancel)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: Icon(Icons.cancel_schedule_send_outlined, color: Theme.of(context).colorScheme.error, size: 28),
              tooltip: 'Cancel Request',
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }

  Widget _buildCupertinoTile(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getCachedProfile(relationship, currentUserId);

    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: ProfileAvatar(
        photoURL: profile?.photoURL,
        displayName: profile?.displayName ?? 'Unknown User',
      ),
      title: Text(
        profile?.displayName ?? 'Unknown User',
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isIncoming ? 'Wants to be your friend' : 'Request Sent',
        style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
      ),
      trailing: isIncoming ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoadingAccept)
            const CupertinoActivityIndicator()
          else
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.check_mark_circled, color: CupertinoColors.activeGreen, size: 30),
              onPressed: onAccept,
            ),
          const SizedBox(width: 12),
          if (isLoadingDecline)
            const CupertinoActivityIndicator()
          else
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.clear_circled, color: CupertinoColors.destructiveRed, size: 30),
              onPressed: onDecline,
            ),
        ],
      ) : Row( // Actions for outgoing requests (Cancel button)
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoadingCancel)
            const CupertinoActivityIndicator()
          else
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.clear_circled_solid, color: CupertinoColors.destructiveRed, size: 30),
              onPressed: onCancel,
            ),
        ],
      ), 
    );
  }
}

// Using the same CupertinoListTile helper from friend_tile.dart
// If it's in a shared location, this definition can be removed.
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
