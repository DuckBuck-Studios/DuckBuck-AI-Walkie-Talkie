# Friends Feature User Flows - Enhanced v2.0

This document describes the comprehensive user flows for the unified friends system in the DuckBuck application. These flows illustrate the interactions between the SharedFriendsProvider, RelationshipRepository, and all integrated services including real-time updates, smart caching, error handling, and cross-platform functionality.

## Architecture Flow Integration

The user flows incorporate all the enhanced features from the DuckBuck friends architecture v2.0:

- **Unified SharedFriendsProvider**: Single source of truth for all friends data
- **Repository-Level Caching**: Smart caching with 5-minute validity and background refresh
- **Real-time Firebase Streams**: Live updates with automatic reconnection
- **Comprehensive State Management**: Friends, pending requests, and blocked users
- **Analytics Integration**: Full event tracking and performance monitoring
- **Memory Optimization**: Efficient disposal and resource management
- **Error Recovery**: Comprehensive error handling with retry mechanisms
- **Photo Caching**: Optimized profile image loading and storage

## User Flow Diagrams

### Send Friend Request Flow - Enhanced

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Dialog as Add Friend Dialog
    participant SFP as SharedFriendsProvider
    participant RR as RelationshipRepository
    participant RS as RelationshipService
    participant US as UserService
    participant LDB as LocalDatabaseService
    participant FS as Firestore
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    
    User->>UI: Clicks "Add Friend" button
    UI->>Dialog: Show add friend dialog
    Dialog->>Dialog: Display UID search interface
    
    User->>Dialog: Enters target user UID
    Dialog->>SFP: searchUserByUid(uid)
    SFP->>RR: searchUserByUid(uid)
    RR->>RS: searchUserByUid(uid)
    RS->>FS: Query users collection by UID
    FS-->>RS: User document
    RS-->>RR: UserModel
    RR-->>SFP: Map<String, dynamic>
    SFP-->>Dialog: User profile data
    Dialog->>Dialog: Display user profile
    
    User->>Dialog: Confirms friend request
    Dialog->>SFP: sendFriendRequest(targetUid)
    SFP->>RR: sendFriendRequest(targetUid)
    
    %% Repository handles caching and analytics
    RR->>Analytics: Log event 'friend_request_sent'
    RR->>RS: sendFriendRequest(targetUid)
    
    %% Service layer handles business logic
    RS->>FS: Create relationship document
    FS-->>RS: Relationship ID
    RS-->>RR: Success with relationshipId
    
    %% Update local cache
    RR->>RR: Invalidate requests cache
    RR-->>SFP: Success response
    
    %% Provider updates UI state
    SFP->>SFP: Refresh requests data
    SFP->>SFP: notifyListeners()
    SFP-->>Dialog: Success
    Dialog->>UI: Close dialog
    UI->>UI: Update friends list
    
    %% Background analytics and logging
    RR->>Analytics: Log success metrics
    RR->>Logger: Log operation success
    Dialog->>Provider: sendFriendRequest(targetUserId)
    Provider->>Provider: Set loading state
    Provider->>Repo: sendFriendRequest(targetUserId)
    
    Repo->>Analytics: Log event: "friend_request_attempt"
    Repo->>Logger: Log operation start
    Repo->>Service: sendFriendRequest(targetUserId)
    
    Service->>Service: Validate current user
    Service->>UserSvc: getUserData(targetUserId)
    UserSvc->>Firestore: Get target user
    Firestore-->>UserSvc: Target user data
    UserSvc-->>Service: UserModel
    
    Service->>Service: Validate request (not self, not existing)
    Service->>Service: Get existing relationships
    Service->>Firestore: Query existing relationship
    Firestore-->>Service: Existing relationship (if any)
    
    alt No existing relationship
        Service->>Service: Create new relationship
        Service->>DB: Start transaction
        DB->>Service: Transaction context
        Service->>Service: Build RelationshipModel
        Service->>Firestore: Create relationship document
        Firestore-->>Service: Document created
        Service->>DB: Commit transaction
        DB-->>Service: Transaction committed
        
        Service->>UserSvc: getCurrentUserData()
        UserSvc->>Firestore: Get current user
        Firestore-->>UserSvc: Current user data
        UserSvc-->>Service: Current user
        
        Service->>Notif: Send friend request notification
        Notif->>FCM: Send push notification
        FCM-->>User: Push notification received
        
        Service-->>Repo: Relationship ID
        Repo->>Analytics: Log event: "friend_request_sent_success"
        Repo->>Logger: Log operation success
        Repo-->>Provider: Success response
        
    else Existing relationship
        Service->>Service: Check relationship status
        alt Status is declined
            Service->>Service: Update to pending with new initiator
            Service->>DB: Start transaction  
            Service->>Firestore: Update relationship status
            Service->>DB: Commit transaction
            Service->>Notif: Send notification
            Service-->>Repo: Updated relationship
        else Status is pending/accepted/blocked
            Service->>Service: Throw appropriate exception
            Service-->>Repo: RelationshipException
            Repo->>Analytics: Log event: "friend_request_failed"
            Repo->>Logger: Log operation failure
            Repo-->>Provider: Error response
        end
    end
    
    Provider->>Provider: Clear loading state
    Provider->>Provider: notifyListeners()
    Provider-->>Dialog: Operation complete
    Dialog->>Dialog: Close dialog
    Dialog-->>UI: Return to friends screen
    UI->>UI: Show success message
    
    Note over Firestore: Real-time stream updates
    Firestore->>Provider: Stream update (outgoing requests)
    Provider->>Provider: Update outgoing requests list
    Provider->>Provider: notifyListeners()
    Provider-->>UI: UI automatically refreshes
```

### Accept Friend Request Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Pending as Pending Section
    participant Provider as Friends Provider
    participant Repo as Relationship Repository
    participant Service as Relationship Service
    participant DB as Firebase Database
    participant Firestore as Firestore
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    
    Note over UI: User views pending tab
    UI->>Pending: Switch to pending requests tab
    Pending->>Provider: Get incoming requests
    Provider-->>Pending: List of pending requests
    Pending->>Pending: Display incoming requests
    
    User->>Pending: Clicks "Accept" on request
    Pending->>Provider: acceptFriendRequest(relationshipId)
    Provider->>Provider: Add to processing set
    Provider->>Provider: notifyListeners() [show loading]
    Provider-->>Pending: Show loading indicator
    
    Provider->>Repo: acceptFriendRequest(relationshipId)
    Repo->>Analytics: Log event: "friend_request_accept_attempt"
    Repo->>Logger: Log operation start
    Repo->>Service: acceptFriendRequest(relationshipId)
    
    Service->>Service: Validate current user
    Service->>DB: Start transaction
    DB->>Service: Transaction context
    
    Service->>Firestore: Get relationship document
    Firestore-->>Service: RelationshipModel
    
    Service->>Service: Validate relationship state
    alt Valid pending request
        Service->>Service: Update relationship status
        Service->>Service: Set acceptedAt timestamp
        Service->>Service: Update cached profiles
        Service->>Firestore: Update relationship document
        Firestore-->>Service: Document updated
        Service->>DB: Commit transaction
        DB-->>Service: Transaction committed
        
        Service-->>Repo: Success response
        Repo->>Analytics: Log event: "friend_request_accepted_success"
        Repo->>Logger: Log operation success
        Repo-->>Provider: Success response
        
    else Invalid state
        Service->>Service: Throw RelationshipException
        Service->>DB: Rollback transaction
        Service-->>Repo: RelationshipException
        Repo->>Analytics: Log event: "friend_request_accept_failed"
        Repo->>Logger: Log operation failure
        Repo-->>Provider: Error response
    end
    
    Provider->>Provider: Remove from processing set
    Provider->>Provider: notifyListeners()
    Provider-->>UI: Operation complete
    
    Note over Firestore: Real-time stream updates
    Firestore->>Provider: Stream update (friends list)
    Provider->>Provider: Update friends list
    Firestore->>Provider: Stream update (incoming requests)
    Provider->>Provider: Update incoming requests
    Provider->>Provider: notifyListeners()
    Provider-->>UI: UI automatically refreshes
    UI->>UI: Show in friends tab
    UI->>UI: Remove from pending tab
```

### Block User Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Dialog as Block Dialog
    participant Provider as Friends Provider
    participant Repo as Relationship Repository
    participant Service as Relationship Service
    participant DB as Firebase Database
    participant Firestore as Firestore
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    
    User->>UI: Long press on friend tile
    UI->>UI: Show context menu
    User->>UI: Selects "Block User"
    UI->>Dialog: Show block confirmation dialog
    Dialog->>Dialog: Display warning message
    
    User->>Dialog: Confirms block action
    Dialog->>Provider: blockUser(relationshipId)
    Provider->>Provider: Add to processing set
    Provider->>Provider: notifyListeners() [show loading]
    Provider-->>Dialog: Show loading indicator
    
    Provider->>Repo: blockUser(relationshipId)
    Repo->>Analytics: Log event: "user_block_attempt"
    Repo->>Logger: Log operation start
    Repo->>Service: blockUser(relationshipId)
    
    Service->>Service: Validate current user
    Service->>DB: Start transaction
    DB->>Service: Transaction context
    
    Service->>Firestore: Get relationship document
    Firestore-->>Service: RelationshipModel
    
    Service->>Service: Validate relationship exists
    alt Valid relationship
        Service->>Service: Update to blocked status
        Service->>Service: Set blockerId to current user
        Service->>Service: Update timestamp
        Service->>Firestore: Update relationship document
        Firestore-->>Service: Document updated
        Service->>DB: Commit transaction
        DB-->>Service: Transaction committed
        
        Service-->>Repo: Success response
        Repo->>Analytics: Log event: "user_blocked_success"
        Repo->>Logger: Log operation success
        Repo-->>Provider: Success response
        
    else Invalid relationship
        Service->>Service: Throw RelationshipException
        Service->>DB: Rollback transaction
        Service-->>Repo: RelationshipException
        Repo->>Analytics: Log event: "user_block_failed"
        Repo->>Logger: Log operation failure
        Repo-->>Provider: Error response
    end
    
    Provider->>Provider: Remove from processing set
    Provider->>Provider: notifyListeners()
    Provider-->>Dialog: Operation complete
    Dialog->>Dialog: Close dialog
    Dialog-->>UI: Return to friends screen
    
    Note over Firestore: Real-time stream updates
    Firestore->>Provider: Stream update (friends list)
    Provider->>Provider: Remove from friends list
    Firestore->>Provider: Stream update (blocked users)
    Provider->>Provider: Add to blocked users list
    Provider->>Provider: notifyListeners()
    Provider-->>UI: UI automatically refreshes
    UI->>UI: Remove friend from list
    UI->>UI: Show success message
```

### Real-time Updates Flow

```mermaid
sequenceDiagram
    actor User1
    actor User2
    participant UI1 as User1 Friends Screen
    participant Provider1 as User1 Provider
    participant Firestore as Firestore
    participant Provider2 as User2 Provider  
    participant UI2 as User2 Friends Screen
    
    Note over UI1,UI2: Both users have friends screen open
    
    User1->>UI1: Opens friends screen
    UI1->>Provider1: initialize()
    Provider1->>Provider1: Setup stream subscriptions
    Provider1->>Firestore: Subscribe to friends stream
    Provider1->>Firestore: Subscribe to incoming requests stream
    Provider1->>Firestore: Subscribe to outgoing requests stream
    Provider1->>Firestore: Subscribe to blocked users stream
    
    User2->>UI2: Opens friends screen  
    UI2->>Provider2: initialize()
    Provider2->>Provider2: Setup stream subscriptions
    Provider2->>Firestore: Subscribe to streams
    
    Note over UI1,UI2: User1 sends friend request to User2
    User1->>UI1: Sends friend request to User2
    UI1->>Provider1: sendFriendRequest(user2Id)
    Provider1->>Firestore: Create relationship document
    
    Note over Firestore: Document created, streams notify
    Firestore-->>Provider1: Outgoing requests stream update
    Provider1->>Provider1: Add to outgoing requests
    Provider1->>Provider1: notifyListeners()
    Provider1-->>UI1: UI refreshes - shows in outgoing
    
    Firestore-->>Provider2: Incoming requests stream update
    Provider2->>Provider2: Add to incoming requests
    Provider2->>Provider2: notifyListeners()
    Provider2-->>UI2: UI refreshes - shows in incoming
    UI2->>UI2: Show notification badge on pending tab
    
    Note over UI1,UI2: User2 accepts friend request
    User2->>UI2: Accepts friend request
    UI2->>Provider2: acceptFriendRequest(relationshipId)
    Provider2->>Firestore: Update relationship status to accepted
    
    Note over Firestore: Document updated, streams notify
    Firestore-->>Provider1: Friends stream update
    Provider1->>Provider1: Add to friends list
    Firestore-->>Provider1: Outgoing requests stream update
    Provider1->>Provider1: Remove from outgoing requests
    Provider1->>Provider1: notifyListeners()
    Provider1-->>UI1: UI refreshes
    UI1->>UI1: Move to friends tab
    UI1->>UI1: Remove from outgoing tab
    
    Firestore-->>Provider2: Friends stream update
    Provider2->>Provider2: Add to friends list
    Firestore-->>Provider2: Incoming requests stream update
    Provider2->>Provider2: Remove from incoming requests
    Provider2->>Provider2: notifyListeners()
    Provider2-->>UI2: UI refreshes
    UI2->>UI2: Move to friends tab
    UI2->>UI2: Remove from incoming tab
    
    Note over UI1,UI2: Both users now see each other as friends
```

### Unblock User Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Blocked as Blocked Section
    participant Dialog as Unblock Dialog
    participant Provider as Friends Provider
    participant Repo as Relationship Repository
    participant Service as Relationship Service
    participant DB as Firebase Database
    participant Firestore as Firestore
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    
    Note over UI: User views blocked users section
    UI->>Blocked: Navigate to blocked users tab
    Blocked->>Provider: Get blocked users
    Provider-->>Blocked: List of blocked relationships
    Blocked->>Blocked: Display blocked users
    
    User->>Blocked: Clicks "Unblock" on user
    Blocked->>Dialog: Show unblock confirmation dialog
    Dialog->>Dialog: Display confirmation message
    
    User->>Dialog: Confirms unblock action
    Dialog->>Provider: unblockUser(relationshipId)
    Provider->>Provider: Add to processing set
    Provider->>Provider: notifyListeners() [show loading]
    Provider-->>Dialog: Show loading indicator
    
    Provider->>Repo: unblockUser(relationshipId)
    Repo->>Analytics: Log event: "user_unblock_attempt"
    Repo->>Logger: Log operation start
    Repo->>Service: unblockUser(relationshipId)
    
    Service->>Service: Validate current user
    Service->>DB: Start transaction
    DB->>Service: Transaction context
    
    Service->>Firestore: Get relationship document
    Firestore-->>Service: RelationshipModel
    
    Service->>Service: Validate user is blocker
    alt Valid blocked relationship and user is blocker
        Service->>Service: Delete relationship document
        Service->>Firestore: Delete relationship document
        Firestore-->>Service: Document deleted
        Service->>DB: Commit transaction
        DB-->>Service: Transaction committed
        
        Service-->>Repo: Success response
        Repo->>Analytics: Log event: "user_unblocked_success"
        Repo->>Logger: Log operation success
        Repo-->>Provider: Success response
        
    else Invalid state or not blocker
        Service->>Service: Throw RelationshipException
        Service->>DB: Rollback transaction
        Service-->>Repo: RelationshipException
        Repo->>Analytics: Log event: "user_unblock_failed"
        Repo->>Logger: Log operation failure
        Repo-->>Provider: Error response
    end
    
    Provider->>Provider: Remove from processing set
    Provider->>Provider: notifyListeners()
    Provider-->>Dialog: Operation complete
    Dialog->>Dialog: Close dialog
    Dialog-->>UI: Return to friends screen
    
    Note over Firestore: Real-time stream updates
    Firestore->>Provider: Stream update (blocked users)
    Provider->>Provider: Remove from blocked users list
    Provider->>Provider: notifyListeners()
    Provider-->>UI: UI automatically refreshes
    UI->>UI: Remove user from blocked list
    UI->>UI: Show success message
```

### Remove Friend Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Friends as Friends Section
    participant Dialog as Remove Dialog
    participant Provider as Friends Provider
    participant Repo as Relationship Repository
    participant Service as Relationship Service
    participant DB as Firebase Database
    participant Firestore as Firestore
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    
    User->>UI: Long press on friend tile
    UI->>UI: Show context menu
    User->>UI: Selects "Remove Friend"
    UI->>Dialog: Show remove confirmation dialog
    Dialog->>Dialog: Display warning message
    
    User->>Dialog: Confirms remove action
    Dialog->>Provider: removeFriend(relationshipId)
    Provider->>Provider: Add to processing set
    Provider->>Provider: notifyListeners() [show loading]
    Provider-->>Dialog: Show loading indicator
    
    Provider->>Repo: removeFriend(relationshipId)
    Repo->>Analytics: Log event: "friend_remove_attempt"
    Repo->>Logger: Log operation start
    Repo->>Service: removeFriend(relationshipId)
    
    Service->>Service: Validate current user
    Service->>DB: Start transaction
    DB->>Service: Transaction context
    
    Service->>Firestore: Get relationship document
    Firestore-->>Service: RelationshipModel
    
    Service->>Service: Validate friendship exists
    alt Valid friendship
        Service->>Service: Delete relationship document
        Service->>Firestore: Delete relationship document
        Firestore-->>Service: Document deleted
        Service->>DB: Commit transaction
        DB-->>Service: Transaction committed
        
        Service-->>Repo: Success response
        Repo->>Analytics: Log event: "friend_removed_success"
        Repo->>Logger: Log operation success
        Repo-->>Provider: Success response
        
    else Invalid friendship
        Service->>Service: Throw RelationshipException
        Service->>DB: Rollback transaction
        Service-->>Repo: RelationshipException
        Repo->>Analytics: Log event: "friend_remove_failed"
        Repo->>Logger: Log operation failure
        Repo-->>Provider: Error response
    end
    
    Provider->>Provider: Remove from processing set
    Provider->>Provider: notifyListeners()
    Provider-->>Dialog: Operation complete
    Dialog->>Dialog: Close dialog
    Dialog-->>UI: Return to friends screen
    
    Note over Firestore: Real-time stream updates
    Firestore->>Provider: Stream update (friends list)
    Provider->>Provider: Remove from friends list
    Provider->>Provider: notifyListeners()
    Provider-->>UI: UI automatically refreshes
    UI->>UI: Remove friend from list
    UI->>UI: Show success message
```

### Decline Friend Request Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Pending as Pending Section
    participant Provider as Friends Provider
    participant Repo as Relationship Repository
    participant Service as Relationship Service
    participant DB as Firebase Database
    participant Firestore as Firestore
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    
    Note over UI: User views pending requests tab
    UI->>Pending: Switch to pending requests tab
    Pending->>Provider: Get incoming requests
    Provider-->>Pending: List of pending requests
    Pending->>Pending: Display incoming requests
    
    User->>Pending: Clicks "Decline" on request
    Pending->>Provider: declineFriendRequest(relationshipId)
    Provider->>Provider: Add to processing set
    Provider->>Provider: notifyListeners() [show loading]
    Provider-->>Pending: Show loading indicator
    
    Provider->>Repo: declineFriendRequest(relationshipId)
    Repo->>Analytics: Log event: "friend_request_decline_attempt"
    Repo->>Logger: Log operation start
    Repo->>Service: declineFriendRequest(relationshipId)
    
    Service->>Service: Validate current user
    Service->>DB: Start transaction
    DB->>Service: Transaction context
    
    Service->>Firestore: Get relationship document
    Firestore-->>Service: RelationshipModel
    
    Service->>Service: Validate pending request
    alt Valid pending request to current user
        Service->>Service: Update status to declined
        Service->>Service: Set declinedAt timestamp
        Service->>Firestore: Update relationship document
        Firestore-->>Service: Document updated
        Service->>DB: Commit transaction
        DB-->>Service: Transaction committed
        
        Service-->>Repo: Success response
        Repo->>Analytics: Log event: "friend_request_declined_success"
        Repo->>Logger: Log operation success
        Repo-->>Provider: Success response
        
    else Invalid state
        Service->>Service: Throw RelationshipException
        Service->>DB: Rollback transaction
        Service-->>Repo: RelationshipException
        Repo->>Analytics: Log event: "friend_request_decline_failed"
        Repo->>Logger: Log operation failure
        Repo-->>Provider: Error response
    end
    
    Provider->>Provider: Remove from processing set
    Provider->>Provider: notifyListeners()
    Provider-->>UI: Operation complete
    
    Note over Firestore: Real-time stream updates
    Firestore->>Provider: Stream update (incoming requests)
    Provider->>Provider: Remove from incoming requests
    Provider->>Provider: notifyListeners()
    Provider-->>UI: UI automatically refreshes
    UI->>UI: Remove request from pending tab
    UI->>UI: Show success message
```

### Cancel Friend Request Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Outgoing as Outgoing Section
    participant Provider as Friends Provider
    participant Repo as Relationship Repository
    participant Service as Relationship Service
    participant DB as Firebase Database
    participant Firestore as Firestore
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    
    Note over UI: User views outgoing requests tab
    UI->>Outgoing: Switch to outgoing requests tab
    Outgoing->>Provider: Get outgoing requests
    Provider-->>Outgoing: List of sent requests
    Outgoing->>Outgoing: Display outgoing requests
    
    User->>Outgoing: Clicks "Cancel" on request
    Outgoing->>Provider: cancelFriendRequest(relationshipId)
    Provider->>Provider: Add to processing set
    Provider->>Provider: notifyListeners() [show loading]
    Provider-->>Outgoing: Show loading indicator
    
    Provider->>Repo: cancelFriendRequest(relationshipId)
    Repo->>Analytics: Log event: "friend_request_cancel_attempt"
    Repo->>Logger: Log operation start
    Repo->>Service: cancelFriendRequest(relationshipId)
    
    Service->>Service: Validate current user
    Service->>DB: Start transaction
    DB->>Service: Transaction context
    
    Service->>Firestore: Get relationship document
    Firestore-->>Service: RelationshipModel
    
    Service->>Service: Validate user is initiator
    alt Valid pending request from current user
        Service->>Service: Delete relationship document
        Service->>Firestore: Delete relationship document
        Firestore-->>Service: Document deleted
        Service->>DB: Commit transaction
        DB-->>Service: Transaction committed
        
        Service-->>Repo: Success response
        Repo->>Analytics: Log event: "friend_request_cancelled_success"
        Repo->>Logger: Log operation success
        Repo-->>Provider: Success response
        
    else Invalid state or not initiator
        Service->>Service: Throw RelationshipException
        Service->>DB: Rollback transaction
        Service-->>Repo: RelationshipException
        Repo->>Analytics: Log event: "friend_request_cancel_failed"
        Repo->>Logger: Log operation failure
        Repo-->>Provider: Error response
    end
    
    Provider->>Provider: Remove from processing set
    Provider->>Provider: notifyListeners()
    Provider-->>UI: Operation complete
    
    Note over Firestore: Real-time stream updates
    Firestore->>Provider: Stream update (outgoing requests)
    Provider->>Provider: Remove from outgoing requests
    Provider->>Provider: notifyListeners()
    Provider-->>UI: UI automatically refreshes
    UI->>UI: Remove request from outgoing tab
    UI->>UI: Show success message
```

### Error Handling Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as Friends Screen
    participant Provider as Friends Provider
    participant Repo as Relationship Repository
    participant Service as Relationship Service
    participant Error as Error Widget
    participant Analytics as Firebase Analytics
    participant Logger as Logger Service
    participant Crashlytics as Firebase Crashlytics
    
    User->>UI: Attempts friend operation
    UI->>Provider: Operation request
    Provider->>Repo: Forward request
    Repo->>Service: Execute operation
    
    alt Network Error
        Service->>Service: Network timeout/failure
        Service-->>Repo: NetworkException
        Repo->>Logger: Log network error
        Repo->>Crashlytics: Report error (non-fatal)
        Repo->>Analytics: Log error event
        Repo-->>Provider: Wrapped RelationshipException
        Provider->>Provider: Set error state
        Provider->>Provider: notifyListeners()
        Provider-->>UI: Error state
        UI->>Error: Show error widget
        Error->>Error: Display "Network error" message
        Error->>Error: Show retry button
        
        User->>Error: Clicks retry
        Error->>Provider: Retry operation
        Provider->>Provider: Clear error state
        Provider->>Repo: Retry original request
        
    else Validation Error
        Service->>Service: Validate request
        Service->>Service: Business rule violation
        Service-->>Repo: RelationshipException(INVALID_STATE)
        Repo->>Logger: Log validation error
        Repo->>Analytics: Log validation failure
        Repo-->>Provider: ValidationException
        Provider->>Provider: Set error state
        Provider-->>UI: Error state
        UI->>UI: Show inline error message
        UI->>UI: Highlight problematic field
        
    else Permission Error
        Service->>Service: Check user permissions
        Service->>Service: Unauthorized operation
        Service-->>Repo: RelationshipException(UNAUTHORIZED)
        Repo->>Logger: Log permission error
        Repo->>Analytics: Log auth failure
        Repo-->>Provider: AuthorizationException
        Provider->>Provider: Set error state
        Provider-->>UI: Error state
        UI->>UI: Show "Permission denied" message
        UI->>UI: Suggest re-authentication
        
    else Database Error
        Service->>Service: Firestore operation fails
        Service-->>Repo: FirestoreException
        Repo->>Logger: Log database error
        Repo->>Crashlytics: Report error (fatal)
        Repo->>Analytics: Log critical error
        Repo-->>Provider: DatabaseException
        Provider->>Provider: Set error state
        Provider-->>UI: Error state
        UI->>Error: Show error widget
        Error->>Error: Display "Service unavailable" message
        Error->>Error: Show retry and contact support options
    end
    
    Note over Provider: Error recovery mechanisms
    Provider->>Provider: Implement exponential backoff
    Provider->>Provider: Check error count and type
    alt Too many consecutive errors
        Provider->>Provider: Enter degraded mode
        Provider-->>UI: Limited functionality message
        UI->>UI: Disable problematic features
        UI->>UI: Show offline mode indicator
    else Recoverable error
        Provider->>Provider: Schedule automatic retry
        Provider->>Provider: Continue normal operation
    end
```

### Profile Caching Flow

```mermaid
sequenceDiagram
    participant Provider as Friends Provider
    participant Service as Relationship Service
    participant UserSvc as User Service
    participant Cache as Profile Cache
    participant Firestore as Firestore
    participant UI as Friends Screen
    
    Note over Provider: Stream receives relationship update
    Firestore-->>Provider: Friends stream update
    Provider->>Provider: Process relationship data
    
    loop For each relationship
        Provider->>Provider: Check cached profile age
        alt Profile cache expired
            Provider->>Service: requestProfileUpdate(userId)
            Service->>UserSvc: getUserData(userId)
            UserSvc->>Firestore: Query user document
            Firestore-->>UserSvc: Latest user data
            UserSvc-->>Service: UserModel
            
            Service->>Service: Update cached profile in relationship
            Service->>Firestore: Update relationship document
            Firestore-->>Service: Document updated
            Service-->>Provider: Updated profile
            
            Provider->>Cache: Update local cache
            Cache->>Cache: Store with timestamp
            
        else Profile cache valid
            Provider->>Cache: Use cached profile
            Cache-->>Provider: Cached profile data
        end
    end
    
    Provider->>Provider: notifyListeners()
    Provider-->>UI: Updated friends list
    UI->>UI: Render with latest profiles
    
    Note over UI: UI shows fresh profile data
    UI->>UI: Display updated names/photos
    UI->>UI: Show last seen information
    UI->>UI: Handle profile placeholder states
```

## Flow Characteristics

### Real-time Synchronization
- **Instant Updates**: Changes appear immediately across all connected clients
- **Optimistic UI**: UI updates before server confirmation for better UX
- **Conflict Resolution**: Handles concurrent modifications gracefully
- **Stream Management**: Automatic reconnection and error recovery

### Transaction Safety
- **Atomic Operations**: All database changes are transactional
- **Rollback Support**: Failed operations don't leave partial state
- **Consistency Guarantees**: Data integrity maintained across all operations
- **Idempotent Operations**: Safe to retry without side effects

### Error Recovery
- **Graceful Degradation**: App remains functional during service issues
- **Retry Mechanisms**: Automatic and manual retry options
- **User Feedback**: Clear error messages with actionable guidance
- **Offline Support**: Cached data availability during network issues

### Performance Optimization
- **Stream Efficiency**: Only subscribes to necessary data streams
- **Profile Caching**: Reduces redundant user data fetches
- **Lazy Loading**: On-demand data loading for better performance
- **Memory Management**: Proper cleanup of subscriptions and resources

## Analytics Events

### Friend Request Events
- `friend_request_sent`: When a user sends a friend request
- `friend_request_accepted`: When a user accepts a friend request
- `friend_request_declined`: When a user declines a friend request
- `friend_request_cancelled`: When a user cancels their sent request

### User Action Events
- `user_blocked`: When a user blocks another user
- `user_unblocked`: When a user unblocks another user
- `friend_removed`: When a user removes a friend
- `friends_screen_viewed`: When user views the friends screen

### Error Events
- `friend_operation_failed`: When any friend operation fails
- `stream_connection_failed`: When real-time streams fail
- `profile_cache_miss`: When profile cache needs refresh
- `validation_error_occurred`: When business rule validation fails

## Performance Metrics

### Response Times
- **Friend Request Send**: < 500ms average
- **Request Accept/Decline**: < 300ms average
- **Stream Update Propagation**: < 100ms average
- **Profile Cache Hit Rate**: > 90%

### Resource Usage
- **Memory**: Efficient stream management with proper cleanup
- **Network**: Optimized queries with compound indices
- **Battery**: Background sync optimization for mobile devices
- **Storage**: Minimal local caching with automatic cleanup

### Reliability Metrics
- **Uptime**: > 99.9% service availability
- **Error Rate**: < 0.1% for core operations
- **Data Consistency**: 100% transactional integrity
- **Recovery Time**: < 30 seconds for stream reconnection

---

## Quick Reference

### Key Operations
- **Send Request**: User search → validation → creation → notification
- **Accept Request**: Validation → status update → stream propagation
- **Block User**: Confirmation → status change → relationship termination
- **Real-time Updates**: Stream subscription → data processing → UI refresh

### Error Categories
- **Network**: Connection issues, timeouts, service unavailable
- **Validation**: Business rules, duplicate requests, invalid states
- **Permission**: Authentication failures, unauthorized operations
- **Data**: Database errors, corruption, constraint violations

### Stream Types
- **Friends Stream**: Accepted relationships for current user
- **Incoming Stream**: Pending requests received by current user
- **Outgoing Stream**: Pending requests sent by current user
- **Blocked Stream**: Blocked relationships involving current user

### Cache Strategy
- **Profile Cache**: User display data cached in relationships
- **Summary Cache**: Relationship counts for quick access
- **Stream Cache**: Local state synchronized with Firestore
- **Error Cache**: Recent errors for retry logic
