import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  // Demo blocked users data
  final List<Map<String, dynamic>> _demoBlockedUsers = [
    {
      'id': '1',
      'name': 'John Doe',
      'email': 'john.doe@example.com',
      'photoURL': null,
      'blockedDate': '2024-01-15',
    },
    {
      'id': '2', 
      'name': 'Jane Smith',
      'email': 'jane.smith@example.com',
      'photoURL': null,
      'blockedDate': '2024-02-20',
    },
    {
      'id': '3',
      'name': 'Mike Johnson', 
      'email': 'mike.johnson@example.com',
      'photoURL': null,
      'blockedDate': '2024-03-10',
    },
  ];

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
      body: _demoBlockedUsers.isEmpty ? _buildEmptyState() : _buildBlockedUsersList(),
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

  Widget _buildBlockedUsersList() {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _demoBlockedUsers.length,
        itemBuilder: (context, index) {
          final user = _demoBlockedUsers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoListTile(
              padding: const EdgeInsets.all(16),
              leading: _buildAvatar(user['name']),
              title: Text(
                user['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              subtitle: Text(
                'Blocked on ${user['blockedDate']}',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              trailing: CupertinoButton(
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
                onPressed: () => _showUnblockDialog(user),
              ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _demoBlockedUsers.length,
        itemBuilder: (context, index) {
          final user = _demoBlockedUsers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: _buildAvatar(user['name']),
              title: Text(
                user['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text('Blocked on ${user['blockedDate']}'),
              trailing: TextButton(
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
                onPressed: () => _showUnblockDialog(user),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildAvatar(String name) {
    final initials = name.split(' ').map((n) => n[0]).take(2).join();
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

  void _showUnblockDialog(Map<String, dynamic> user) {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Unblock ${user['name']}?'),
          content: Text(
            'Unblocking ${user['name']} will allow them to send you friend requests again.',
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
                _unblockUser(user);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unblock ${user['name']}?'),
          content: Text(
            'Unblocking ${user['name']} will allow them to send you friend requests again.',
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
                _unblockUser(user);
              },
            ),
          ],
        ),
      );
    }
  }

  void _unblockUser(Map<String, dynamic> user) {
    setState(() {
      _demoBlockedUsers.removeWhere((u) => u['id'] == user['id']);
    });

    final snackBar = SnackBar(
      content: Text('${user['name']} has been unblocked'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
