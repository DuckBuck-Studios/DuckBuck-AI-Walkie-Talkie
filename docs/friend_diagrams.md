# DuckBuck Friend System Diagram

## Friend System Class Diagram

```mermaid
classDiagram
    class FriendService {
        -FirebaseDatabaseService _databaseService
        +Future~String~ sendFriendRequest(String senderId, String receiverId)
        +Future~FriendRelationshipModel?~ getRelationship(String relationshipId)
        +Future~FriendRelationshipModel?~ getRelationshipBetweenUsers(String user1Id, String user2Id)
        +Future~bool~ acceptFriendRequest(String requestId)
        +Future~bool~ rejectFriendRequest(String requestId)
        +Future~bool~ cancelFriendRequest(String requestId)
        +Future~List~String~~ getUserFriends(String userId)
        +Future~bool~ removeFriend(String userId1, String userId2)
        +Future~bool~ blockUser(String blockerId, String blockedId)
        +Future~bool~ unblockUser(String blockerId, String blockedId)
        +Future~bool~ isUserBlocked(String blockerId, String blockedId)
        +Future~bool~ _checkIfFriends(String user1Id, String user2Id)
        +Stream~List~String~~ streamUserFriends(String userId)
    }

    class FriendRepository {
        -FriendService _friendService
        -UserRepository _userRepository
        -Map~String, List~String~~ _friendsCache
        -Map~String, DateTime~ _cacheTimestamps
        -Map~String, FriendRelationshipModel~ _relationshipCache
        -Duration _cacheDuration
        -Timer? _cacheCleanupTimer
        +Future~String~ sendFriendRequest(String receiverId)
        +Future~List~FriendRelationshipModel~~ getPendingRequests()
        +Future~bool~ acceptFriendRequest(String requestId)
        +Future~bool~ rejectFriendRequest(String requestId)
        +Future~List~String~~ getFriends(bool forceRefresh)
        +Future~List~String~~ getFriendsFor(String userId, bool forceRefresh)
        +Future~RelationshipStatus~ getRelationshipWith(String userId)
        +void invalidateCache(String userId)
        -void _cleanupExpiredCache()
        +Future~List~String~~ getFriends()
        +Future~List~String~~ getFriendsFor(String userId)
        +Future~bool~ isFriendWith(String userId)
        +Future~bool~ checkIfFriends(String user1Id, String user2Id)
        +Future~bool~ removeFriend(String friendId)
        +Future~bool~ blockUser(String userId)
        +Future~bool~ unblockUser(String userId)
        +Future~bool~ isUserBlocked(String userId)
        +Future~bool~ isUserBlockedBy(String blockerId, String blockedId)
    }

    // FriendRequestModel removed - using a single model approach
    
    class FriendRelationshipModel {
        +String id
        +String user1Id
        +String user2Id
        +RelationshipStatus status
        +RelationshipDirection direction
        +DateTime createdAt
        +DateTime updatedAt
        +List~RelationshipEvent~ history
        +toMap()
        +fromMap()
        +addEvent()
        +updateStatus()
        +hasUser()
        +getOtherUserId()
    }
    
    class RelationshipEvent {
        +String eventType
        +String userId
        +DateTime timestamp
        +String? message
        +toMap()
        +fromMap()
    }
    
    enum RelationshipStatus {
        none
        pending
        friends
        blocked
    }
    
    enum RelationshipDirection {
        mutual
        fromUser1ToUser2
        fromUser2ToUser1
    }

    class FriendRepositoryMessagingExtension {
        +Future~bool~ canSendMessage(String senderId, String receiverId)
        +Future~List~String~~ getMessagingEnabledFriends(String userId)
    }

    // Using RelationshipStatus instead of FriendRequestStatus

    FriendRepository --> FriendService : uses
    FriendRepository --> UserRepository : uses
    FriendService --> FriendRelationshipModel : creates/manages
    FriendRepository <|-- FriendRepositoryMessagingExtension : extends
    FriendRelationshipModel --> RelationshipStatus : uses
    FriendRelationshipModel --> RelationshipDirection : uses
    FriendRelationshipModel *-- RelationshipEvent : contains
    RelationshipEvent --> RelationshipStatus : affects
```

## Friend Request Flow Diagram

```mermaid
sequenceDiagram
    actor Sender
    actor Receiver
    participant SenderUI as Sender UI
    participant ReceiverUI as Receiver UI
    participant FriendRepo as FriendRepository
    participant FriendSvc as FriendService
    participant DB as Firebase Database

    %% Friend Request Flow
    Sender->>SenderUI: Send Friend Request
    SenderUI->>FriendRepo: sendFriendRequest(receiverId)
    FriendRepo->>FriendRepo: validate & check relationships
    FriendRepo->>FriendSvc: sendFriendRequest(senderId, receiverId)
    FriendSvc->>DB: Get or Create Relationship Document
    FriendSvc->>DB: Update Relationship Status to Pending
    FriendSvc->>DB: Add Request Event to History
    DB-->>FriendSvc: Request ID
    FriendSvc-->>FriendRepo: Request ID
    FriendRepo->>FriendRepo: Invalidate Cache
    FriendRepo-->>SenderUI: Success
    SenderUI-->>Sender: Request Sent Confirmation
    
    %% Receiver gets notification and checks requests
    Receiver->>ReceiverUI: View Friend Requests
    ReceiverUI->>FriendRepo: getPendingRequests()
    FriendRepo->>FriendSvc: getPendingRequestsForUser()
    FriendSvc->>DB: Query Pending Requests
    DB-->>FriendSvc: Request List
    FriendSvc-->>FriendRepo: Request List
    FriendRepo-->>ReceiverUI: Display Request List
    ReceiverUI-->>Receiver: Show Friend Requests
    
    %% Accept Friend Request
    Receiver->>ReceiverUI: Accept Request
    ReceiverUI->>FriendRepo: acceptFriendRequest(requestId)
    FriendRepo->>FriendRepo: Validate request belongs to user
    FriendRepo->>FriendSvc: acceptFriendRequest(requestId)
    FriendSvc->>DB: Get Relationship Document
    FriendSvc->>DB: Update Status to Friends
    FriendSvc->>DB: Add Accept Event to History
    DB-->>FriendSvc: Success
    FriendSvc-->>FriendRepo: Success
    FriendRepo->>FriendRepo: Invalidate Cache for both users
    FriendRepo-->>ReceiverUI: Success
    ReceiverUI-->>Receiver: Friend Added Confirmation
```

## Blocking System Flow Diagram

```mermaid
sequenceDiagram
    actor User
    participant UI as User Interface
    participant FriendRepo as FriendRepository
    participant FriendSvc as FriendService
    participant DB as Firebase Database

    %% Block User Flow
    User->>UI: Block User (userId)
    UI->>FriendRepo: blockUser(userId)
    FriendRepo->>FriendRepo: Validate request & currentUser
    FriendRepo->>FriendSvc: blockUser(currentUserId, userId)
    FriendSvc->>DB: Get or Create Relationship Document
    FriendSvc->>FriendSvc: Calculate relationship direction
    FriendSvc->>DB: Set Status to Blocked
    FriendSvc->>DB: Add Block Event to History
    DB-->>FriendSvc: Success
    FriendSvc-->>FriendRepo: Success
    FriendRepo->>FriendRepo: Invalidate Cache for both users
    FriendRepo-->>UI: Success
    UI-->>User: User Blocked Confirmation
    
    %% Check if blocked before interaction
    User->>UI: Try to message user
    UI->>FriendRepo: canSendMessage(senderId, receiverId)
    FriendRepo->>FriendRepo: getRelationshipWith(receiverId)
    FriendRepo->>FriendSvc: Get relationship document
    FriendSvc->>DB: Query relationship by deterministic ID
    DB-->>FriendSvc: Relationship document
    FriendSvc-->>FriendRepo: Relationship data
    FriendRepo-->>UI: Can/Cannot Send Message (based on status)
    UI-->>User: Allow/Block Action
```

## Friend-Messaging Integration

```mermaid
flowchart TD
    subgraph Friend System
        FR[FriendRepository]
        FS[FriendService]
    end
    
    subgraph Messaging System
        MR[MessageRepository]
        MS[MessageService]
    end
    
    subgraph Integration Layer
        FRE[FriendRepositoryMessagingExtension]
        MRE[MessageRepositoryFriendExtension]
        MFC[MessageFeatureController]
    end
    
    FR --> FS
    MR --> MS
    
    FRE -.-> FR
    MRE -.-> MR
    
    MFC --> FR
    MFC --> MR
    MFC --> FRE
    MFC --> MRE
    
    UI[User Interface] --> MFC
    
    classDef main fill:#f96,stroke:#333,stroke-width:2px
    classDef extension fill:#bbf,stroke:#333,stroke-width:1px
    classDef controller fill:#ff9,stroke:#333,stroke-width:2px
    
    class FR,MR main
    class FRE,MRE extension
    class MFC controller
```
