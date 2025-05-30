# Block User Functionality

This document explains how to use the user blocking functionality in the DuckBuck app.

## Overview

The block user feature allows users to block other users, which:
1. Removes them from the friends list
2. Prevents them from sending friend requests to the user
3. Prevents any future interaction between the users

## Implementation

### In Friends Screen

To implement blocking in your friends screen:

```dart
import 'package:flutter/material.dart';
import '../widgets/sections/friends_section.dart';
import '../providers/friends_provider.dart';

class FriendsScreen extends StatelessWidget {
  final FriendsProvider provider;

  const FriendsScreen({Key? key, required this.provider}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Column(
        children: [
          // Other sections...
          
          // Friends section with block functionality
          FriendsSection(
            provider: provider,
            showRemoveFriendDialog: _showRemoveFriendDialog,
            showBlockUserDialog: _showBlockUserDialog,
          ),
          
          // Other sections...
        ],
      ),
    );
  }
  
  // Show dialog to confirm removing a friend
  void _showRemoveFriendDialog(BuildContext context, RelationshipModel relationship) {
    // Implementation of remove friend dialog...
  }
  
  // Show dialog to confirm blocking a user
  void _showBlockUserDialog(BuildContext context, RelationshipModel relationship) {
    // Call the static helper method from FriendsSection
    FriendsSection.showBlockFriendDialog(context, relationship, provider);
  }
}
```

### UI Flow

1. User selects a friend from their friends list
2. User taps on the "more" menu (three dots or ellipsis)
3. User selects "Block User" option from the dropdown/action sheet
4. A confirmation dialog appears explaining the consequences
5. If user confirms, the friend is blocked and removed from the friends list
6. A success notification is shown

### Blocked Users Management

Blocked users can be viewed and unblocked in the Settings screen, under Privacy settings.
The implementation for unblocking users follows a similar pattern using the `provider.unblockUser()` method.

## Provider Methods

The following methods are available in the FriendsProvider:

- `blockUser(String relationshipId)`: Blocks a user by relationship ID.
- `unblockUser(String relationshipId)`: Unblocks a previously blocked user.
- `isBlockingUser(String id)`: Returns whether a block operation is in progress.

## Repository Methods

The RelationshipRepository provides these methods:

- `blockUser(String relationshipId)`: Handles the actual blocking operation.
- `unblockUser(String relationshipId)`: Handles unblocking users.
- `getBlockedUsers(String userId)`: Retrieves a list of blocked users.