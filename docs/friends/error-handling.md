# Error Handling

This document details the exception handling and error scenarios in the Relationship Service.

## RelationshipException

The primary exception class for relationship-related errors.

```dart
class RelationshipException implements Exception {
  final RelationshipErrorCode code;
  final String message;
  final String? details;
  final dynamic originalError;
  
  RelationshipException(this.code, this.message, {this.details, this.originalError});
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `code` | `RelationshipErrorCode` | Specific error code for programmatic handling |
| `message` | `String` | Human-readable error message |
| `details` | `String?` | Additional error details (optional) |
| `originalError` | `dynamic` | Original exception that caused this error (optional) |

## Error Codes

### RelationshipErrorCode Enum

```dart
enum RelationshipErrorCode {
  userNotFound,
  requestAlreadyExists,
  alreadyFriends,
  userBlocked,
  selfRequest,
  requestNotFound,
  notAuthorized,
  invalidStatus,
  alreadyBlocked,
  selfBlock,
  notBlocked,
  notFriends,
  invalidPagination,
  databaseError,
  networkError,
  unknownError,
}
```

## Error Scenarios by Method

### Friend Request Operations

#### sendFriendRequest

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `userNotFound` | Target user doesn't exist | "User with ID 'user123' not found" |
| `requestAlreadyExists` | Friend request already sent | "Friend request already exists between users" |
| `alreadyFriends` | Users are already friends | "Users are already friends" |
| `userBlocked` | Current user is blocked by target | "Cannot send friend request to user who has blocked you" |
| `selfRequest` | Attempting to befriend self | "Cannot send friend request to yourself" |
| `databaseError` | Database operation failed | "Failed to create friend request" |

```dart
// Example exception handling
try {
  final relationship = await relationshipService.sendFriendRequest('user123');
} on RelationshipException catch (e) {
  switch (e.code) {
    case RelationshipErrorCode.userNotFound:
      showError('User not found');
      break;
    case RelationshipErrorCode.alreadyFriends:
      showInfo('You are already friends with this user');
      break;
    case RelationshipErrorCode.userBlocked:
      showError('Unable to send friend request');
      break;
    default:
      showError('Failed to send friend request: ${e.message}');
  }
}
```

#### acceptFriendRequest

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `requestNotFound` | Friend request doesn't exist | "Friend request with ID 'req123' not found" |
| `notAuthorized` | User cannot accept this request | "You are not authorized to accept this friend request" |
| `invalidStatus` | Request is not pending | "Friend request is not in pending status" |
| `databaseError` | Database operation failed | "Failed to accept friend request" |

#### declineFriendRequest

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `requestNotFound` | Friend request doesn't exist | "Friend request with ID 'req123' not found" |
| `notAuthorized` | User cannot decline this request | "You are not authorized to decline this friend request" |
| `invalidStatus` | Request is not pending | "Friend request is not in pending status" |
| `databaseError` | Database operation failed | "Failed to decline friend request" |

### Blocking Operations

#### blockUser

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `userNotFound` | Target user doesn't exist | "User with ID 'user123' not found" |
| `alreadyBlocked` | User is already blocked | "User is already blocked" |
| `selfBlock` | Attempting to block self | "Cannot block yourself" |
| `databaseError` | Database operation failed | "Failed to block user" |

#### unblockUser

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `userNotFound` | Target user doesn't exist | "User with ID 'user123' not found" |
| `notBlocked` | User is not currently blocked | "User is not currently blocked" |
| `databaseError` | Database operation failed | "Failed to unblock user" |

### Friendship Management

#### removeFriend

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `userNotFound` | Target user doesn't exist | "User with ID 'user123' not found" |
| `notFriends` | Users are not friends | "You are not friends with this user" |
| `databaseError` | Database operation failed | "Failed to remove friendship" |

### Query Operations

#### Pagination Methods

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `invalidPagination` | Invalid page or pageSize | "Page number must be greater than 0" |
| `invalidPagination` | PageSize too large | "Page size cannot exceed 100 items" |
| `databaseError` | Database query failed | "Failed to retrieve relationships" |

#### Individual Query Methods

| Error Code | Scenario | Message Example |
|------------|----------|-----------------|
| `userNotFound` | Target user doesn't exist | "User with ID 'user123' not found" |
| `databaseError` | Database query failed | "Failed to check relationship status" |

## Error Handling Best Practices

### 1. Specific Exception Handling

```dart
try {
  await relationshipService.sendFriendRequest(userId);
  showSuccess('Friend request sent successfully');
} on RelationshipException catch (e) {
  // Handle specific relationship errors
  handleRelationshipError(e);
} catch (e) {
  // Handle unexpected errors
  showError('An unexpected error occurred');
  logError(e);
}
```

### 2. User-Friendly Error Messages

```dart
String getErrorMessage(RelationshipException e) {
  switch (e.code) {
    case RelationshipErrorCode.userNotFound:
      return 'User not found. Please check the username and try again.';
    case RelationshipErrorCode.alreadyFriends:
      return 'You are already friends with this user.';
    case RelationshipErrorCode.userBlocked:
      return 'Unable to send friend request to this user.';
    case RelationshipErrorCode.requestAlreadyExists:
      return 'Friend request already sent. Please wait for a response.';
    default:
      return 'Something went wrong. Please try again later.';
  }
}
```

### 3. Retry Logic for Network Errors

```dart
Future<T> withRetry<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
  int attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      return await operation();
    } on RelationshipException catch (e) {
      if (e.code == RelationshipErrorCode.networkError && attempts < maxRetries - 1) {
        attempts++;
        await Future.delayed(Duration(seconds: pow(2, attempts).toInt()));
        continue;
      }
      rethrow;
    }
  }
  
  throw RelationshipException(
    RelationshipErrorCode.networkError,
    'Operation failed after $maxRetries attempts'
  );
}
```

### 4. Validation Before API Calls

```dart
Future<bool> validateFriendRequest(String friendId) async {
  // Check if user exists
  if (!await userService.userExists(friendId)) {
    throw RelationshipException(
      RelationshipErrorCode.userNotFound,
      'User not found'
    );
  }
  
  // Check if already friends
  if (await relationshipService.isFriend(friendId)) {
    throw RelationshipException(
      RelationshipErrorCode.alreadyFriends,
      'Already friends with this user'
    );
  }
  
  // Check if blocked
  if (await relationshipService.isBlocked(friendId)) {
    throw RelationshipException(
      RelationshipErrorCode.userBlocked,
      'Cannot send request to blocked user'
    );
  }
  
  return true;
}
```

## Error Logging

### Log Error Details

```dart
void logRelationshipError(RelationshipException e) {
  final logData = {
    'error_code': e.code.toString(),
    'message': e.message,
    'details': e.details,
    'original_error': e.originalError?.toString(),
    'timestamp': DateTime.now().toIso8601String(),
    'user_id': currentUserId,
  };
  
  logger.error('Relationship service error', logData);
}
```

### Error Analytics

```dart
void trackRelationshipError(RelationshipException e, String operation) {
  analytics.track('relationship_error', {
    'operation': operation,
    'error_code': e.code.toString(),
    'error_category': _getErrorCategory(e.code),
  });
}

String _getErrorCategory(RelationshipErrorCode code) {
  switch (code) {
    case RelationshipErrorCode.userNotFound:
    case RelationshipErrorCode.notAuthorized:
      return 'validation';
    case RelationshipErrorCode.databaseError:
      return 'database';
    case RelationshipErrorCode.networkError:
      return 'network';
    default:
      return 'business_logic';
  }
}
```

## Error Recovery Strategies

### Automatic Recovery

Some errors can be automatically handled:

```dart
Future<void> smartFriendRequest(String friendId) async {
  try {
    await relationshipService.sendFriendRequest(friendId);
  } on RelationshipException catch (e) {
    switch (e.code) {
      case RelationshipErrorCode.requestAlreadyExists:
        // Silently succeed - request already exists
        return;
      case RelationshipErrorCode.alreadyFriends:
        // Show appropriate message
        showInfo('You are already friends!');
        return;
      default:
        rethrow;
    }
  }
}
```

### User Guidance

Provide actionable guidance for users:

```dart
String getErrorGuidance(RelationshipException e) {
  switch (e.code) {
    case RelationshipErrorCode.userNotFound:
      return 'Double-check the username or try searching for the user.';
    case RelationshipErrorCode.userBlocked:
      return 'This user has restricted friend requests.';
    case RelationshipErrorCode.networkError:
      return 'Check your internet connection and try again.';
    default:
      return 'Please try again in a few moments.';
  }
}
```
