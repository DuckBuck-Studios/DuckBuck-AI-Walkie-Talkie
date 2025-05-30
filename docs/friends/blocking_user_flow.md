# User Blocking Implementation

This document explains how the user blocking functionality works within the DuckBuck app.

## Overview

The block user functionality allows users to:
1. Block other users, removing them from their friends list
2. Prevent blocked users from sending them friend requests
3. Only allow the user who initiated the block to unblock the other user

## Technical Implementation

### Data Model

When a user blocks another user, we store the following information in the relationship document:

- `status`: Set to `blocked`
- `blockerId`: The user ID of the person who initiated the block
- `updatedAt`: Timestamp of when the block occurred

### Permissions

The blocking system enforces these permissions:

1. **Blocking**: Any user can block a friend (changing relationship status to `blocked`)
2. **Unblocking**: Only the user who initiated the block (the `blockerId`) can unblock the other user

### Block Flow

1. User A blocks User B:
   - The relationship status changes to `blocked`
   - The `blockerId` field is set to User A's ID
   - Both users are removed from each other's friends list

2. Unblocking:
   - Only User A (the blocker) can unblock User B
   - When unblocked, the relationship is deleted entirely
   - The users will need to send a new friend request to reconnect

## Error Handling

The system produces these errors to enforce blocking rules:

- `relationship/unauthorized`: Returned when a user tries to unblock someone they didn't block
- `relationship/not-blocked`: Returned when trying to unblock a relationship that isn't in blocked state
- `relationship/not-participant`: Returned when a user tries to modify a relationship they're not part of

## UI Implementation

The UI for blocking follows these principles:

1. Only show block options for actual friends (not for pending requests)
2. Show clear confirmation dialogs explaining blocking consequences
3. After successful blocking, show confirmation to the user
4. Don't show unblock options in the main friends UI (these belong in settings/blocked users)

## Future Enhancements

Potential future improvements:
- Add a dedicated "Blocked Users" screen in settings
- Add ability to report users when blocking
- Add automatic expiration of blocks after a certain period
