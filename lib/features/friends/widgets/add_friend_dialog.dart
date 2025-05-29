import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';
import 'profile_avatar.dart';

class AddFriendDialog extends StatefulWidget {
  final FriendsProvider provider;

  const AddFriendDialog({
    super.key,
    required this.provider,
  });

  static Future<void> show(BuildContext context, FriendsProvider provider) {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddFriendDialog(provider: provider);
      },
    );
  }

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _foundUserData;
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceBlack,
      title: Text(
        'Add Friend',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'User ID',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              hintText: 'Enter user ID to search',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accentBlue, width: 2),
              ),
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: Colors.grey[900],
            ),
            onChanged: (value) {
              _foundUserData = null;
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          if (widget.provider.isSearching)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
            )
          else if (_foundUserData != null)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.grey[900],
              elevation: 2,
              child: ListTile(
                leading: ProfileAvatar(
                  photoURL: _foundUserData!['photoURL'],
                  displayName: _foundUserData!['displayName'] ?? 'Unknown',
                ),
                title: Text(
                  _foundUserData!['displayName'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'User ID: ${_foundUserData!['uid'] ?? 'unknown'}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_foundUserData == null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: widget.provider.isSearching
              ? null
              : () async {
                  final uid = _controller.text.trim();
                  if (uid.isNotEmpty) {
                    final result = await widget.provider.searchUserByUid(uid);
                    if (result != null) {
                      setState(() {
                        _foundUserData = result;
                      });
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User not found'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
            child: const Text('Search'),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final success = await widget.provider.sendFriendRequest(_foundUserData!['uid']);
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'Friend request sent!' 
                        : 'Failed to send friend request',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Send Request'),
          ),
      ],
    );
  }
}
