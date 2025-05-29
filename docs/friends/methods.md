# Method Documentation

This document provides detailed documentation for each method in the Relationship Service.

## Friend Request Operations

### sendFriendRequest

Sends a friend request to another user.

```dart
Future<RelationshipModel> sendFriendRequest(String friendId)
```

#### Parameters
- `friendId` (`String`): The ID of the user to send a friend request to

#### Return Value
Returns a `RelationshipModel` representing the newly created friend request.

```dart
RelationshipModel {
  id: "rel_abc123",
  userId: "current_user_id", 
  friendId: "target_user_id",
  type: RelationshipType.friend,
  status: RelationshipStatus.pending,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now()
}
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist
- `RelationshipException.requestAlreadyExists`: Friend request already exists
- `RelationshipException.alreadyFriends`: Users are already friends
- `RelationshipException.userBlocked`: Current user is blocked by target user
- `RelationshipException.selfRequest`: Attempting to send request to self

---

### acceptFriendRequest

Accepts an incoming friend request.

```dart
Future<RelationshipModel> acceptFriendRequest(String requestId)
```

#### Parameters
- `requestId` (`String`): The ID of the friend request to accept

#### Return Value
Returns the updated `RelationshipModel` with accepted status.

```dart
RelationshipModel {
  id: "rel_abc123",
  userId: "sender_user_id",
  friendId: "current_user_id", 
  type: RelationshipType.friend,
  status: RelationshipStatus.accepted,
  createdAt: DateTime(original_creation_time),
  updatedAt: DateTime.now()
}
```

#### Exceptions
- `RelationshipException.requestNotFound`: Friend request doesn't exist
- `RelationshipException.notAuthorized`: User not authorized to accept this request
- `RelationshipException.invalidStatus`: Request is not in pending status

---

### declineFriendRequest

Declines an incoming friend request.

```dart
Future<void> declineFriendRequest(String requestId)
```

#### Parameters
- `requestId` (`String`): The ID of the friend request to decline

#### Return Value
Returns `void`. The friend request is marked as declined and removed from active requests.

#### Exceptions
- `RelationshipException.requestNotFound`: Friend request doesn't exist
- `RelationshipException.notAuthorized`: User not authorized to decline this request
- `RelationshipException.invalidStatus`: Request is not in pending status

## Blocking Operations

### blockUser

Blocks a user, preventing all future interactions.

```dart
Future<RelationshipModel> blockUser(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to block

#### Return Value
Returns a `RelationshipModel` representing the block relationship.

```dart
RelationshipModel {
  id: "rel_block123",
  userId: "current_user_id",
  friendId: "blocked_user_id",
  type: RelationshipType.blocked,
  status: RelationshipStatus.blocked,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now()
}
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist
- `RelationshipException.alreadyBlocked`: User is already blocked
- `RelationshipException.selfBlock`: Attempting to block self

#### Side Effects
- If users were friends, the friendship is terminated
- Any pending friend requests between users are cancelled
- Blocked user cannot send friend requests to the blocking user

---

### unblockUser

Unblocks a previously blocked user.

```dart
Future<void> unblockUser(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to unblock

#### Return Value
Returns `void`. The block relationship is removed.

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist
- `RelationshipException.notBlocked`: User is not currently blocked

## Friendship Management

### removeFriend

Removes an existing friendship between users.

```dart
Future<void> removeFriend(String friendId)
```

#### Parameters
- `friendId` (`String`): The ID of the friend to remove

#### Return Value
Returns `void`. The friendship relationship is terminated.

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist
- `RelationshipException.notFriends`: Users are not currently friends

## Query Operations - Lists

### getFriends

Retrieves a paginated list of the user's friends.

```dart
Future<PaginatedRelationshipResult> getFriends({
  int page = 1,
  int pageSize = 20,
})
```

#### Parameters
- `page` (`int`, optional): Page number to retrieve (default: 1)
- `pageSize` (`int`, optional): Number of items per page (default: 20)

#### Return Value
Returns `PaginatedRelationshipResult` containing friends data.

```dart
PaginatedRelationshipResult {
  relationships: [
    RelationshipModel {
      id: "rel_friend1",
      userId: "current_user_id",
      friendId: "friend1_id",
      type: RelationshipType.friend,
      status: RelationshipStatus.accepted,
      createdAt: DateTime(2024, 1, 15),
      updatedAt: DateTime(2024, 1, 15)
    },
    // ... more relationships
  ],
  profiles: [
    CachedProfile {
      displayName: "Friend One",
      photoURL: "https://example.com/avatar1.jpg",
      lastUpdated: DateTime(2024, 1, 15)
    },
    // ... more profiles
  ],
  totalCount: 45,
  currentPage: 1,
  pageSize: 20,
  hasNextPage: true,
  hasPreviousPage: false
}
```

#### Exceptions
- `RelationshipException.invalidPagination`: Invalid page or pageSize parameters

---

### getIncomingRequests

Retrieves a paginated list of incoming friend requests.

```dart
Future<PaginatedRelationshipResult> getIncomingRequests({
  int page = 1,
  int pageSize = 20,
})
```

#### Parameters
- `page` (`int`, optional): Page number to retrieve (default: 1)
- `pageSize` (`int`, optional): Number of items per page (default: 20)

#### Return Value
Returns `PaginatedRelationshipResult` containing incoming friend requests.

```dart
PaginatedRelationshipResult {
  relationships: [
    RelationshipModel {
      id: "rel_incoming1",
      userId: "sender_id",
      friendId: "current_user_id",
      type: RelationshipType.friend,
      status: RelationshipStatus.pending,
      createdAt: DateTime(2024, 1, 18),
      updatedAt: DateTime(2024, 1, 18)
    }
  ],
  profiles: [
    CachedProfile {
      displayName: "Request Sender",
      photoURL: "https://example.com/avatar_sender.jpg",
      lastUpdated: DateTime(2024, 1, 18)
    }
  ],
  totalCount: 3,
  currentPage: 1,
  pageSize: 20,
  hasNextPage: false,
  hasPreviousPage: false
}
```

#### Exceptions
- `RelationshipException.invalidPagination`: Invalid page or pageSize parameters

---

### getOutgoingRequests

Retrieves a paginated list of outgoing friend requests.

```dart
Future<PaginatedRelationshipResult> getOutgoingRequests({
  int page = 1,
  int pageSize = 20,
})
```

#### Parameters
- `page` (`int`, optional): Page number to retrieve (default: 1)
- `pageSize` (`int`, optional): Number of items per page (default: 20)

#### Return Value
Returns `PaginatedRelationshipResult` containing outgoing friend requests.

```dart
PaginatedRelationshipResult {
  relationships: [
    RelationshipModel {
      id: "rel_outgoing1",
      userId: "current_user_id",
      friendId: "target_id",
      type: RelationshipType.friend,
      status: RelationshipStatus.pending,
      createdAt: DateTime(2024, 1, 17),
      updatedAt: DateTime(2024, 1, 17)
    }
  ],
  profiles: [
    CachedProfile {
      displayName: "Pending Friend",
      photoURL: null,
      lastUpdated: DateTime(2024, 1, 17)
    }
  ],
  totalCount: 1,
  currentPage: 1,
  pageSize: 20,
  hasNextPage: false,
  hasPreviousPage: false
}
```

#### Exceptions
- `RelationshipException.invalidPagination`: Invalid page or pageSize parameters

---

### getBlockedUsers

Retrieves a paginated list of blocked users.

```dart
Future<PaginatedRelationshipResult> getBlockedUsers({
  int page = 1,
  int pageSize = 20,
})
```

#### Parameters
- `page` (`int`, optional): Page number to retrieve (default: 1)
- `pageSize` (`int`, optional): Number of items per page (default: 20)

#### Return Value
Returns `PaginatedRelationshipResult` containing blocked users.

```dart
PaginatedRelationshipResult {
  relationships: [
    RelationshipModel {
      id: "rel_blocked1",
      userId: "current_user_id",
      friendId: "blocked_id",
      type: RelationshipType.blocked,
      status: RelationshipStatus.blocked,
      createdAt: DateTime(2024, 1, 10),
      updatedAt: DateTime(2024, 1, 10)
    }
  ],
  profiles: [
    CachedProfile {
      displayName: "Blocked User",
      photoURL: "https://example.com/avatar_blocked.jpg",
      lastUpdated: DateTime(2024, 1, 12, 8, 20)
    }
  ],
  totalCount: 2,
  currentPage: 1,
  pageSize: 20,
  hasNextPage: false,
  hasPreviousPage: false
}
```

#### Exceptions
- `RelationshipException.invalidPagination`: Invalid page or pageSize parameters

## Query Operations - Individual

### getRelationship

Retrieves a specific relationship between the current user and another user.

```dart
Future<RelationshipModel?> getRelationship(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to check relationship with

#### Return Value
Returns `RelationshipModel?` representing the relationship, or `null` if no relationship exists.

```dart
// When relationship exists:
RelationshipModel {
  id: "rel_example",
  userId: "current_user_id",
  friendId: "other_user_id",
  type: RelationshipType.friend,
  status: RelationshipStatus.accepted,
  createdAt: DateTime(2024, 1, 15),
  updatedAt: DateTime(2024, 1, 15)
}

// When no relationship exists:
null
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist

## Status Check Operations

### isBlocked

Checks if a specific user is blocked by the current user.

```dart
Future<bool> isBlocked(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to check

#### Return Value
Returns `bool` indicating whether the user is blocked.

```dart
// User is blocked
true

// User is not blocked
false
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist

---

### isFriend

Checks if a specific user is friends with the current user.

```dart
Future<bool> isFriend(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to check

#### Return Value
Returns `bool` indicating whether the users are friends.

```dart
// Users are friends
true

// Users are not friends
false
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist

---

### hasIncomingRequest

Checks if there's an incoming friend request from a specific user.

```dart
Future<bool> hasIncomingRequest(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to check for incoming request

#### Return Value
Returns `bool` indicating whether there's an incoming friend request.

```dart
// Incoming request exists
true

// No incoming request
false
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist

---

### hasOutgoingRequest

Checks if there's an outgoing friend request to a specific user.

```dart
Future<bool> hasOutgoingRequest(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to check for outgoing request

#### Return Value
Returns `bool` indicating whether there's an outgoing friend request.

```dart
// Outgoing request exists
true

// No outgoing request
false
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist

## Utility Operations

### getFriendProfile

Retrieves cached profile information for a specific friend.

```dart
Future<CachedProfile?> getFriendProfile(String friendId)
```

#### Parameters
- `friendId` (`String`): The ID of the friend to get profile for

#### Return Value
Returns `CachedProfile?` containing friend's profile data, or `null` if not friends.

```dart
// When users are friends:
CachedProfile {
  displayName: "Friend Display Name",
  photoURL: "https://example.com/avatar.jpg",
  lastUpdated: DateTime(2024, 1, 20, 15, 30)
}

// When not friends or user doesn't exist:
null
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist

---

### getMutualFriends

Retrieves mutual friends between the current user and another user.

```dart
Future<List<CachedProfile>> getMutualFriends(String userId)
```

#### Parameters
- `userId` (`String`): The ID of the user to find mutual friends with

#### Return Value
Returns `List<CachedProfile>` containing profiles of mutual friends.

```dart
[
  CachedProfile {
    displayName: "Mutual Friend 1",
    photoURL: "https://example.com/mutual1.jpg",
    lastUpdated: DateTime(2024, 1, 19, 12, 0)
  },
  CachedProfile {
    displayName: "Mutual Friend 2",
    photoURL: null,
    lastUpdated: DateTime(2024, 1, 20, 9, 15)
  }
]
```

#### Exceptions
- `RelationshipException.userNotFound`: Target user doesn't exist
