# Data Models

This document describes the core data structures used by the Relationship Service.

## RelationshipModel

The primary model representing a relationship between two users.

```dart
class RelationshipModel {
  final String id;
  final String userId;
  final String friendId;
  final RelationshipType type;
  final RelationshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier for the relationship |
| `userId` | `String` | ID of the user who initiated the relationship |
| `friendId` | `String` | ID of the target user in the relationship |
| `type` | `RelationshipType` | Type of relationship (see enum below) |
| `status` | `RelationshipStatus` | Current status (see enum below) |
| `createdAt` | `DateTime` | When the relationship was created |
| `updatedAt` | `DateTime` | When the relationship was last modified |

## CachedProfile

Enhanced user profile information included with relationship data for performance optimization.

```dart
class CachedProfile {
  final String displayName;
  final String? photoURL;
  final DateTime lastUpdated;
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `displayName` | `String` | User's display name |
| `photoURL` | `String?` | URL to user's profile picture (optional) |
| `lastUpdated` | `DateTime` | When the profile data was last updated |

## PaginatedRelationshipResult

Container for paginated relationship data with metadata.

```dart
class PaginatedRelationshipResult {
  final List<RelationshipModel> relationships;
  final List<CachedProfile> profiles;
  final int totalCount;
  final int currentPage;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `relationships` | `List<RelationshipModel>` | List of relationship records for current page |
| `profiles` | `List<CachedProfile>` | Associated user profiles for the relationships |
| `totalCount` | `int` | Total number of relationships matching the query |
| `currentPage` | `int` | Current page number (1-based) |
| `pageSize` | `int` | Number of items per page |
| `hasNextPage` | `bool` | Whether there are more pages available |
| `hasPreviousPage` | `bool` | Whether there are previous pages available |

## Enums

### RelationshipType

```dart
enum RelationshipType {
  friend,    // Standard friendship
  blocked,   // User has been blocked
}
```

### RelationshipStatus

```dart
enum RelationshipStatus {
  pending,   // Friend request sent, awaiting response
  accepted,  // Friend request accepted, users are friends
  declined,  // Friend request declined
  blocked,   // User has been blocked
}
```

## Data Relationships

### Profile Association
- Each `RelationshipModel` has corresponding `CachedProfile` entries
- Profiles are indexed by user ID for efficient lookup
- Profile data is cached to avoid repeated database queries

### Pagination Structure
- Results are ordered by `createdAt` timestamp (newest first)
- Page numbers start from 1
- Empty results return valid pagination metadata with zero counts

### Status Transitions
Valid status transitions:
- `pending` → `accepted` (accept friend request)
- `pending` → `declined` (decline friend request)
- `accepted` → `blocked` (block a friend)
- `blocked` → `accepted` (unblock and restore friendship)
- Any status → `blocked` (block user)
