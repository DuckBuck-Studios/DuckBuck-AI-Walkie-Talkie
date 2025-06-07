import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../providers/settings_provider.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize RelationshipProvider to ensure blocked users streams are active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().initializeRelationshipProvider();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;

    return Scaffold(
      backgroundColor: isIOS 
        ? CupertinoColors.systemGroupedBackground.resolveFrom(context)
        : Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: isIOS 
          ? CupertinoColors.systemGroupedBackground.resolveFrom(context)
          : Theme.of(context).colorScheme.surface,
        foregroundColor: isIOS 
          ? CupertinoColors.label.resolveFrom(context)
          : Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          icon: Icon(isIOS ? CupertinoIcons.back : Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, child) {
          final blockedUsers = provider.blockedUsers;
          final isLoading = provider.isLoadingBlockedUsers;
          final error = provider.relationshipError;

          if (isLoading) {
            return _buildLoadingState();
          }

          if (error != null) {
            return _buildErrorState(error, provider);
          }

          return blockedUsers.isEmpty 
            ? _buildEmptyState() 
            : _buildBlockedUsersList(blockedUsers, provider);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isIOS = Platform.isIOS;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isIOS ? CupertinoIcons.shield : Icons.shield,
            size: 64,
            color: isIOS 
              ? CupertinoColors.secondaryLabel.resolveFrom(context)
              : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No blocked users',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isIOS 
                ? CupertinoColors.label.resolveFrom(context)
                : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'When you block someone, they will appear here and won\'t be able to send you friend requests',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isIOS 
                  ? CupertinoColors.secondaryLabel.resolveFrom(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final bool isIOS = Platform.isIOS;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isIOS 
            ? const CupertinoActivityIndicator(radius: 20)
            : const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading blocked users...',
            style: TextStyle(
              color: isIOS 
                ? CupertinoColors.secondaryLabel.resolveFrom(context)
                : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, SettingsProvider provider) {
    final bool isIOS = Platform.isIOS;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isIOS ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
            size: 64,
            color: isIOS 
              ? CupertinoColors.systemRed.resolveFrom(context)
              : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading blocked users',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isIOS 
                ? CupertinoColors.label.resolveFrom(context)
                : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isIOS 
                  ? CupertinoColors.secondaryLabel.resolveFrom(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          isIOS
            ? CupertinoButton(
                onPressed: () {
                  provider.clearRelationshipError();
                  provider.initializeRelationshipProvider();
                },
                child: const Text('Retry'),
              )
            : ElevatedButton(
                onPressed: () {
                  provider.clearRelationshipError();
                  provider.initializeRelationshipProvider();
                },
                child: const Text('Retry'),
              ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersList(List<Map<String, dynamic>> blockedUsers, SettingsProvider provider) {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: blockedUsers.length,
        itemBuilder: (context, index) {
          final user = blockedUsers[index];
          final String userId = user['uid'] ?? user['id'] ?? '';
          final String displayName = user['displayName'] ?? user['name'] ?? 'Unknown User';
          final String? photoURL = user['photoURL'];
          final bool isProcessingUnblock = provider.isProcessingUnblockUser(userId);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoListTile(
              padding: const EdgeInsets.all(16),
              leading: _buildAvatar(displayName, photoURL),
              title: Text(
                displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              subtitle: Text(
                user['email'] ?? '',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              trailing: isProcessingUnblock
                ? const CupertinoActivityIndicator(radius: 10)
                : CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minSize: 0,
                    color: CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(16),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.white,
                      ),
                    ),
                    onPressed: () => _showUnblockDialog(user, provider),
                  ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: blockedUsers.length,
        itemBuilder: (context, index) {
          final user = blockedUsers[index];
          final String userId = user['uid'] ?? user['id'] ?? '';
          final String displayName = user['displayName'] ?? user['name'] ?? 'Unknown User';
          final String? photoURL = user['photoURL'];
          final bool isProcessingUnblock = provider.isProcessingUnblockUser(userId);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: _buildAvatar(displayName, photoURL),
              title: Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(user['email'] ?? ''),
              trailing: isProcessingUnblock
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => _showUnblockDialog(user, provider),
                  ),
            ),
          );
        },
      );
    }
  }

  Widget _buildAvatar(String name, [String? photoURL]) {
    if (photoURL != null && photoURL.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photoURL),
        backgroundColor: Colors.grey[300],
      );
    }

    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    final color = colors[name.hashCode % colors.length];

    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showUnblockDialog(Map<String, dynamic> user, SettingsProvider provider) {
    final bool isIOS = Platform.isIOS;
    final String displayName = user['displayName'] ?? user['name'] ?? 'Unknown User';
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Unblock $displayName?'),
          content: Text(
            'Unblocking $displayName will allow them to send you friend requests again.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('Unblock'),
              onPressed: () {
                Navigator.pop(context);
                _unblockUser(user, provider);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unblock $displayName?'),
          content: Text(
            'Unblocking $displayName will allow them to send you friend requests again.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Unblock'),
              onPressed: () {
                Navigator.pop(context);
                _unblockUser(user, provider);
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _unblockUser(Map<String, dynamic> user, SettingsProvider provider) async {
    final String userId = user['uid'] ?? user['id'] ?? '';
    
    if (userId.isEmpty) {
      // Silently return if no user ID - error will be handled by provider
      return;
    }

    // Perform unblock operation silently - all errors are handled by the provider
    await provider.unblockUser(userId);
  }
}
