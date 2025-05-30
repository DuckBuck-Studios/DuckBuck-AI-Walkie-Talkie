# Friends Feature Code Organization

This document outlines the code organization of DuckBuck's friends system, with detailed class responsibilities and relationships. The friends system follows a layered architecture pattern with clear separation of concerns to ensure:

- **Maintainability**: Code is organized in logical units with well-defined responsibilities
- **Testability**: Components are decoupled to allow for proper unit and integration testing
- **Scalability**: New relationship types can be added with minimal changes to existing code
- **Performance**: Real-time updates and caching optimize user experience

## Directory Structure

```
lib/
├── core/
│   ├── exceptions/
│   │   └── relationship_exceptions.dart    # Relationship error handling
│   ├── models/
│   │   └── relationship_model.dart         # Relationship data structure
│   ├── repositories/
│   │   └── relationship_repository.dart    # Relationship coordination
│   └── services/
│       ├── relationship/
│       │   ├── relationship_service_interface.dart # Service contract
│       │   └── relationship_service.dart           # Core business logic
│       ├── firebase/
│       │   ├── firebase_analytics_service.dart     # Analytics tracking
│       │   ├── firebase_crashlytics_service.dart   # Error reporting
│       │   └── firebase_database_service.dart      # Firestore operations
│       ├── auth/
│       │   └── auth_service_interface.dart         # User context
│       ├── user/
│       │   └── user_service_interface.dart         # User data operations
│       ├── notifications/
│       │   └── notifications_service.dart          # Push notifications
│       ├── logger/
│       │   └── logger_service.dart                 # Logging system
│       └── service_locator.dart                    # Dependency injection
├── features/
│   ├── friends/
│   │   ├── providers/
│   │   │   └── friends_provider.dart               # State management
│   │   ├── screens/
│   │   │   └── friends_screen.dart                 # Main UI interface
│   │   └── widgets/
│   │       ├── add_friend_dialog.dart              # Add friend UI
│   │       ├── remove_friend_dialog.dart           # Remove friend UI
│   │       ├── error_state_widget.dart             # Error handling UI
│   │       ├── friend_tile.dart                    # Friend display component
│   │       └── sections/
│   │           ├── friends_section.dart            # Friends list section
│   │           └── pending_section.dart            # Pending requests section
│   └── home/
│       └── screens/
│           ├── home_screen.dart                    # Friends integration
│           └── user_profile_screen.dart            # Profile with friend actions
└── main.dart                                       # App initialization
```

## Key Classes and Responsibilities

### Model Layer

#### `RelationshipModel` (relationship_model.dart)
- **Purpose**: Represents friendship/relationship data structure
- **Responsibilities**:
  - Store relationship identity (id, participants, type, status)
  - Track relationship metadata (createdAt, updatedAt, initiatorId)
  - Cache user profile data for performance optimization
  - Handle relationship state transitions (pending → accepted, etc.)
  - Support conversion to/from Firestore documents
  - Provide immutable data structure for consistency
  - Validate relationship data integrity
  - Enable efficient querying with sorted participants
- **Key Methods**:
  - `fromMap()`: Create RelationshipModel from Firestore data
  - `toMap()`: Convert RelationshipModel to Firestore document
  - `copyWith()`: Create modified copy of RelationshipModel
  - `getFriendId()`: Get the other participant's ID
  - `getCachedProfile()`: Get cached profile for a user
  - `isInitiatedBy()`: Check if relationship was initiated by user
  - `canBeAcceptedBy()`: Check if user can accept the relationship
  - `sortParticipants()`: Static method to ensure consistent participant ordering

#### `CachedProfile` (relationship_model.dart)
- **Purpose**: Cache user profile data within relationships
- **Responsibilities**:
  - Store display information (displayName, photoURL)
  - Track cache freshness with lastUpdated timestamp
  - Minimize redundant user data fetches
  - Support profile updates without full relationship reload
- **Key Methods**:
  - `fromMap()`: Create CachedProfile from data map
  - `toMap()`: Convert CachedProfile to data map
  - `isExpired()`: Check if cache needs refresh
  - `copyWith()`: Create updated copy

#### `RelationshipException` (relationship_exceptions.dart)
- **Purpose**: Define friendship-specific error handling
- **Responsibilities**:
  - Provide standardized error codes for relationship operations
  - Include operation context for better error handling
  - Map service errors to user-friendly messages
  - Support error recovery strategies
- **Key Error Codes**:
  - `userNotFound`: Target user doesn't exist
  - `alreadyFriends`: Users are already friends
  - `requestAlreadySent`: Duplicate friend request
  - `requestAlreadyReceived`: Incoming request exists
  - `blocked`: User is blocked
  - `selfRequest`: Cannot friend yourself
  - `notLoggedIn`: Authentication required
  - `databaseError`: Database operation failed

### Provider Layer

#### `FriendsProvider` (friends_provider.dart)
- **Purpose**: Manage friends state throughout the application
- **Responsibilities**:
  - Orchestrate real-time data streams from Firestore
  - Maintain friends, incoming requests, outgoing requests, and blocked users lists
  - Handle loading states for individual operations (accept, decline, cancel, block)
  - Provide summary data (counts) for UI display
  - Manage stream subscriptions lifecycle
  - Handle errors with user-friendly messaging
  - Coordinate with RelationshipRepository for business operations
  - Optimize UI performance with smart state updates
  - Track processing states to prevent duplicate operations
- **Key Properties**:
  - `friends`: List of accepted relationships
  - `incomingRequests`: List of pending received requests
  - `outgoingRequests`: List of pending sent requests
  - `blockedUsers`: List of blocked relationships
  - `summary`: Map of relationship counts by type
  - `isLoadingSummary/Friends/Incoming/Outgoing/Blocked`: Loading states
  - `_processingAcceptRequestIds/DeclineRequestIds/etc.`: Operation tracking sets
- **Key Methods**:
  - `initialize()`: Set up streams and load initial data
  - `sendFriendRequest()`: Send a friend request
  - `acceptFriendRequest()`: Accept incoming request
  - `declineFriendRequest()`: Decline incoming request
  - `cancelFriendRequest()`: Cancel outgoing request
  - `blockUser()`: Block a user
  - `unblockUser()`: Unblock a user
  - `removeFriend()`: Remove a friend
  - `searchUsers()`: Search for users to add as friends
  - `_setupStreams()`: Configure Firestore stream subscriptions
  - `_handleStreamError()`: Process stream errors with recovery
  - `dispose()`: Clean up subscriptions

### Repository Layer

#### `RelationshipRepository` (relationship_repository.dart)
- **Purpose**: Coordinate relationship operations between UI and services
- **Responsibilities**:
  - Bridge between FriendsProvider and RelationshipService
  - Add analytics tracking to all relationship operations
  - Handle error logging and crash reporting
  - Provide consistent API for relationship operations
  - Transform service exceptions to user-friendly errors
  - Coordinate with multiple services (auth, user, relationship)
- **Key Methods**:
  - `sendFriendRequest()`: Send friend request with analytics
  - `acceptFriendRequest()`: Accept request with tracking
  - `declineFriendRequest()`: Decline request with logging
  - `cancelFriendRequest()`: Cancel request with analytics
  - `blockUser()`: Block user with comprehensive logging
  - `unblockUser()`: Unblock user with tracking
  - `removeFriend()`: Remove friend with analytics
  - `getFriendsStream()`: Get real-time friends stream
  - `getPendingRequestsStream()`: Get incoming requests stream
  - `getSentRequestsStream()`: Get outgoing requests stream
  - `getBlockedUsersStream()`: Get blocked users stream
  - `getFriendshipsSummary()`: Get relationship counts
  - `searchUsers()`: Search for users with validation
  - `_getErrorMessage()`: Convert exceptions to user messages

### Service Layer

#### `RelationshipServiceInterface` (relationship_service_interface.dart)
- **Purpose**: Define contract for relationship operations
- **Responsibilities**:
  - Abstract relationship business logic
  - Define consistent API for relationship management
  - Enable mockable service for testing
  - Support multiple relationship service implementations
- **Key Methods**:
  - `sendFriendRequest()`: Core friend request logic
  - `acceptFriendRequest()`: Accept relationship logic
  - `declineFriendRequest()`: Decline relationship logic
  - `cancelFriendRequest()`: Cancel request logic
  - `blockUser()`: Block user logic
  - `unblockUser()`: Unblock user logic
  - `removeFriend()`: Remove friendship logic
  - `getFriendsStream()`: Stream of accepted relationships
  - `getPendingRequestsStream()`: Stream of incoming requests
  - `getSentRequestsStream()`: Stream of outgoing requests
  - `getBlockedUsersStream()`: Stream of blocked relationships
  - `getFriendshipStatus()`: Check relationship status between users
  - `getFriendshipsSummary()`: Get relationship counts

#### `RelationshipService` (relationship_service.dart)
- **Purpose**: Implement core relationship business logic with Firebase
- **Responsibilities**:
  - Execute atomic relationship operations using Firestore transactions
  - Validate relationship state transitions
  - Prevent invalid operations (self-friending, duplicate requests)
  - Manage cached profile data within relationships
  - Send push notifications for relationship events
  - Handle complex business rules and edge cases
  - Provide real-time streams for relationship data
  - Ensure data consistency across concurrent operations
- **Key Methods**:
  - `sendFriendRequest()`: Create relationship with validation
  - `acceptFriendRequest()`: Update status with transaction safety
  - `declineFriendRequest()`: Update status with logging
  - `cancelFriendRequest()`: Delete or update relationship
  - `blockUser()`: Block relationship with privacy enforcement
  - `unblockUser()`: Remove block with state restoration
  - `removeFriend()`: Remove friendship with cleanup
  - `getFriendsStream()`: Query accepted relationships
  - `getPendingRequestsStream()`: Query incoming pending relationships
  - `getSentRequestsStream()`: Query outgoing pending relationships
  - `getBlockedUsersStream()`: Query blocked relationships
  - `getFriendshipStatus()`: Get current relationship state
  - `_getCurrentUserId()`: Validate user authentication
  - `_updateExistingRelationshipToPending()`: Handle declined → pending transitions
  - `_buildCompoundQuery()`: Build efficient Firestore queries

### UI Layer

#### `FriendsScreen` (friends_screen.dart)
- **Purpose**: Main interface for friends management
- **Responsibilities**:
  - Provide tabbed interface (Friends, Pending)
  - Display platform-specific UI (iOS Cupertino, Android Material)
  - Handle user interactions (add friend, remove friend, etc.)
  - Show loading states and error handling
  - Integrate with FriendsProvider for state management
  - Display real-time updates automatically
- **Key Methods**:
  - `_buildMaterialPage()`: Android Material Design interface
  - `_buildCupertinoPage()`: iOS Cupertino interface
  - `_buildMaterialTabBar()`: Material tab bar with counts
  - `_buildCupertinoSegmentedControl()`: iOS segmented control
  - `_showAddFriendDialog()`: Display add friend interface
  - `_showRemoveFriendDialog()`: Display remove friend confirmation
  - `_showBlockUserDialog()`: Display block user confirmation

#### `AddFriendDialog` (add_friend_dialog.dart)
- **Purpose**: User search and friend request interface
- **Responsibilities**:
  - Provide user search functionality
  - Display search results with user profiles
  - Handle friend request sending
  - Show loading states during operations
  - Handle errors with retry mechanisms
- **Key Methods**:
  - `show()`: Static method to display dialog
  - `_searchUsers()`: Search for users by username/display name
  - `_sendFriendRequest()`: Send friend request to selected user
  - `_buildSearchResults()`: Display search results list
  - `_buildUserTile()`: Display individual user in search

#### `RemoveFriendDialog` (remove_friend_dialog.dart)
- **Purpose**: Confirmation dialog for destructive friend actions
- **Responsibilities**:
  - Confirm friend removal with clear warning
  - Handle remove friend operation
  - Provide option to block user instead
  - Show operation progress
- **Key Methods**:
  - `show()`: Static method to display dialog
  - `_removeFriend()`: Execute friend removal
  - `_blockUser()`: Execute user blocking

#### `FriendTile` (friend_tile.dart)
- **Purpose**: Reusable component for displaying friend information
- **Responsibilities**:
  - Display friend profile (name, photo, status)
  - Handle different relationship states (friend, pending, blocked)
  - Provide action buttons (accept, decline, remove, block)
  - Show loading states for individual operations
  - Support both iOS and Android design systems
- **Key Methods**:
  - `build()`: Main widget build method
  - `_buildProfileSection()`: User profile display
  - `_buildActionButtons()`: Context-appropriate action buttons
  - `_buildLoadingState()`: Loading indicator overlay

#### `FriendsSection` (friends_section.dart)
- **Purpose**: Display accepted friends list
- **Responsibilities**:
  - Show list of confirmed friends
  - Provide friend management actions (remove, block)
  - Handle empty states with helpful messaging
  - Support pull-to-refresh functionality
- **Key Methods**:
  - `build()`: Section widget build
  - `_buildFriendsList()`: Friends list display
  - `_buildEmptyState()`: No friends placeholder
  - `showBlockFriendDialog()`: Block friend confirmation

#### `PendingSection` (pending_section.dart)
- **Purpose**: Display pending friend requests (incoming and outgoing)
- **Responsibilities**:
  - Show incoming requests with accept/decline actions
  - Show outgoing requests with cancel option
  - Handle empty states for both categories
  - Provide clear visual distinction between incoming and outgoing
- **Key Methods**:
  - `build()`: Section widget build
  - `_buildIncomingRequests()`: Incoming requests display
  - `_buildOutgoingRequests()`: Outgoing requests display
  - `_buildEmptyState()`: No requests placeholder

#### `ErrorStateWidget` (error_state_widget.dart)
- **Purpose**: Consistent error handling across friends feature
- **Responsibilities**:
  - Display user-friendly error messages
  - Provide retry functionality
  - Handle different error types appropriately
  - Support error recovery flows
- **Key Methods**:
  - `build()`: Error widget build
  - `_buildErrorMessage()`: Error message display
  - `_buildRetryButton()`: Retry action button
  - `_getErrorIcon()`: Context-appropriate error icon

## Data Flow Patterns

### Real-time Updates
1. **Stream Subscription**: FriendsProvider subscribes to Firestore streams
2. **Data Processing**: Incoming data is processed and cached
3. **State Update**: Provider notifies listeners of changes
4. **UI Refresh**: UI automatically rebuilds with new data

### User Actions
1. **UI Interaction**: User taps button/action
2. **Provider Method**: UI calls appropriate provider method
3. **Repository Coordination**: Provider delegates to repository
4. **Service Execution**: Repository calls service with analytics
5. **Database Operation**: Service executes Firestore transaction
6. **Stream Update**: Firestore change triggers stream update
7. **UI Refresh**: UI automatically reflects changes

### Error Handling
1. **Exception Thrown**: Service throws specific exception
2. **Repository Translation**: Repository converts to user-friendly message
3. **Provider State**: Provider sets error state
4. **UI Display**: ErrorStateWidget shows appropriate message
5. **User Recovery**: User can retry or take alternative action

## Testing Strategy

### Unit Tests
- **Models**: Data validation, serialization, immutability
- **Provider**: State management, stream handling, error states
- **Repository**: Service coordination, analytics tracking
- **Service**: Business logic, validation, transaction handling

### Integration Tests
- **Firestore Integration**: Database operations, stream subscriptions
- **Authentication Flow**: User context validation
- **Notification Flow**: Push notification delivery

### Widget Tests
- **Screen Rendering**: UI layout and component display
- **User Interactions**: Button taps, dialog flows
- **State Transitions**: Loading states, error handling
- **Platform Differences**: iOS vs Android UI behavior

## Performance Considerations

### Stream Management
- **Subscription Lifecycle**: Automatic cleanup prevents memory leaks
- **Selective Listening**: Only subscribe when screen is active
- **Error Recovery**: Automatic reconnection with exponential backoff

### Data Optimization
- **Profile Caching**: Embedded user data reduces database queries
- **Compound Queries**: Efficient Firestore indexing strategy
- **Lazy Loading**: On-demand data fetching for large lists

### UI Performance
- **Skeleton Screens**: Immediate feedback during loading
- **Optimistic Updates**: UI updates before server confirmation
- **Smart Rebuilds**: Minimal widget rebuilds with targeted listening

## Security Considerations

### Input Validation
- **User Authentication**: Verify user context for all operations
- **Parameter Validation**: Validate all input parameters
- **Business Rules**: Enforce relationship constraints

### Privacy Protection
- **Data Isolation**: Users only see their own relationship data
- **Block Functionality**: Complete relationship termination
- **Cached Data**: Sensitive data not exposed in caches

### Transaction Safety
- **Atomic Operations**: All relationship changes are transactional
- **Consistency Guarantees**: Data integrity maintained
- **Conflict Resolution**: Handle concurrent modifications

---

## Quick Reference

### Key Files by Layer
- **Models**: `relationship_model.dart`, `relationship_exceptions.dart`
- **Provider**: `friends_provider.dart`
- **Repository**: `relationship_repository.dart`
- **Service**: `relationship_service.dart`, `relationship_service_interface.dart`
- **UI Screens**: `friends_screen.dart`
- **UI Components**: `friend_tile.dart`, `add_friend_dialog.dart`, `remove_friend_dialog.dart`

### Key Concepts
- **Stream Management**: Real-time data synchronization
- **State Tracking**: Individual operation loading states
- **Profile Caching**: Performance optimization strategy
- **Transaction Safety**: Data consistency guarantees
- **Platform UI**: iOS Cupertino vs Android Material design
