# DuckBuck Friend System

## Overview

The DuckBuck friend system enables users to connect, manage relationships, and control interactions in a social context. It provides comprehensive friend management functionality while maintaining clear boundaries with other system components.

## Architecture

### Service Layer
- **FriendService**: Core service handling all friend-related operations and data access
  
### Repository Layer
- **FriendRepository**: Enhanced repository with caching and error handling that mediates between UI and service layers

### Models
- **FriendRelationshipModel**: Single-document model that represents the complete relationship between two users
- **RelationshipStatus**: Enum representing possible relationship states (none, pending, friends, blocked)
- **RelationshipDirection**: Enum representing the direction of an action in a relationship (fromFirst, fromSecond, mutual)

## Key Features

1. **Friend Request Management**:
   - Send, accept, reject, and cancel friend requests
   - Request status tracking (pending, accepted, rejected, canceled)
   - Duplicate request prevention

2. **Friend Relationship Management**:
   - Add and remove friends
   - Friend list retrieval
   - Friendship status checking

3. **Blocking System**:
   - Block and unblock users
   - Block status checking 
   - Prevention of interactions with blocked users

4. **Privacy Controls**:
   - Friend visibility settings
   - Activity status sharing controls
   - Relationship privacy levels

## Implementation Details

### FriendService

The `FriendService` implements all core friend operations:

- Friend relationship database operations
- Friend relationship management in Firestore
- Block list management
- Real-time friendship status updates

### FriendRepository

The enhanced `FriendRepository` provides:

- **Performance Optimization**: Client-side caching with automatic invalidation
- **Consolidated Storage**: All relationship data between two users in a single document
- **Error Handling**: Custom exceptions with specific error codes
- **Relationship History**: Complete history of relationship events in a single document
- **Caching**: In-memory caching for frequently accessed data with configurable TTL

**Key Components**:
- Friend request collection management
- Friendship collection for bidirectional relationships
- Blocked users collection for privacy control
- Validation logic for all friend operations

### FriendRepository

The `FriendRepository` serves as the application-level interface:

- Translates service responses to application models
- Handles error cases and exception management
- Coordinates with UserRepository for profile enrichment
- Provides business logic for complex friend operations

**Extension Points**:
- Friend suggestions based on mutual connections
- Friend activity tracking
- Recent friend interactions

### Integration with Messaging

The friend system works closely with the messaging system through extension methods that:

1. Determine if users can message each other
2. Filter conversations to show only active friendships
3. Prevent message delivery to/from blocked users
4. Provide privacy-aware user search for messaging

## Friend Request Flow

1. **Request Initiation**:
   - Sender initiates friend request
   - System validates eligibility (no blocks, not already friends)
   - Request is stored with "pending" status
   - Notification is sent to receiver

2. **Request Response**:
   - Receiver accepts or rejects request
   - Friendship records are created on acceptance
   - Both users are notified of status change

3. **Friendship Management**:
   - Either user can end friendship
   - System cleans up both sides of relationship
   - Related data (shared items, etc.) is handled appropriately

## Blocking System

The blocking system provides critical privacy and safety controls:

1. **Block Operation**:
   - User blocks another user
   - System terminates any existing friendship
   - Block record is created
   - All interactions are prevented

2. **Unblock Operation**:
   - User unblocks another user
   - Block record is removed
   - Interactions become possible again (but friendship must be re-established)

3. **Interaction Prevention**:
   - Friend requests are prevented
   - Messages are blocked
   - Visibility in searches is controlled
   - User activities are hidden

## Performance Considerations

- Friend lists are cached for quick retrieval
- Friendship status checks are optimized with indexes
- Real-time listeners are used selectively to avoid battery drain
- Pagination is implemented for large friend lists

## Security Measures

- Firestore security rules restrict access to own friend data only
- Server timestamps prevent manipulation of request timing
- Validation logic prevents unauthorized friendship claims
- Rate limiting prevents abuse of friend request system

## Future Enhancements

1. **Friend Lists/Circles**:
   - Create custom friend groups
   - Apply different privacy settings per group
   - Share content with specific circles

2. **Friend Recommendations**:
   - Suggest new friends based on mutual connections
   - ML-based friend suggestions
   - Contact sync options

3. **Enhanced Blocking**:
   - Temporary blocking/muting
   - Graduated blocking levels
   - Report system integration

## Diagrams

```
┌───────────────┐     ┌──────────────────┐     ┌──────────────┐
│    UI Layer   │ ──> │ FriendRepository │ ──> │ FriendService│
│(Friend Screens)│     │(Business Logic)  │     │(Data Access) │
└───────────────┘     └──────────────────┘     └──────────────┘
                               │
                               ▼
                      ┌─────────────────────┐
                      │ MessageSystem Integration │
                      │  (Extension Methods)     │
                      └─────────────────────┘
```

## Enhanced Implementation

### Single-Document Relationship Architecture

The enhanced implementation uses a single-document approach for storing relationships:

```
┌─────────────────────────────┐
│   Relationship Document     │
├─────────────────────────────┤
│ - user1Id                   │
│ - user2Id                   │
│ - status (enum)             │
│ - direction                 │
│ - createdAt                 │
│ - updatedAt                 │
│ - history[]                 │
└─────────────────────────────┘
```

Benefits:
- Reduced database operations
- Atomic updates to relationship status
- Complete relationship history in one place
- Consistent document IDs based on user IDs

### Caching and Performance

The repository implements sophisticated caching:
- In-memory caching of friend lists with configurable TTL
- Automatic invalidation when relationships change
- Periodic cleanup of expired cache entries
- Batch processing for user details

### Robust Error Handling

Custom exception handling with specific error codes:
- Authentication errors (not logged in)
- Input validation errors (invalid IDs, self-requests)
- Blocking-related errors (blocked by sender/receiver)
- Relationship errors (already friends, not friends)
- Operation failures (request/accept/reject failures)

### Data Migration

The new architecture supports migration from multi-document to single-document structure:
1. Relationship documents are created with deterministic IDs
2. History records are populated from existing documents
3. Old documents can be preserved for backward compatibility
