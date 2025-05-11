# DuckBuck Friend System Diagram

## Friend System Class Diagram

```mermaid
classDiagram
    class FriendService {
        -FirebaseDatabaseService _databaseService
        +Future~String~ sendFriendRequest(String senderId, String receiverId)
        +Future~FriendRequestModel?~ getFriendRequest(String requestId)
        +Future~List~FriendRequestModel~~ getPendingRequestsForUser(String userId)
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
        +Future~String~ sendFriendRequest(String receiverId)
        +Future~List~FriendRequestModel~~ getPendingRequests()
        +Future~bool~ acceptFriendRequest(String requestId)
        +Future~bool~ rejectFriendRequest(String requestId)
        +Future~bool~ cancelFriendRequest(String requestId)
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

    class FriendRequestModel {
        +String id
        +String senderId
        +String receiverId
        +FriendRequestStatus status
        +DateTime createdAt
        +DateTime updatedAt
        +toMap()
        +fromMap()
        +copyWith()
    }

    class FriendRepositoryMessagingExtension {
        +Future~bool~ canSendMessage(String senderId, String receiverId)
        +Future~List~String~~ getMessagingEnabledFriends(String userId)
    }

    enum FriendRequestStatus {
        pending
        accepted
        rejected
        cancelled
    }

    FriendRepository --> FriendService : uses
    FriendRepository --> UserRepository : uses
    FriendService --> FriendRequestModel : creates/manages
    FriendRepository <|-- FriendRepositoryMessagingExtension : extends
    FriendRequestModel --> FriendRequestStatus : uses
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
    FriendRepo->>FriendSvc: sendFriendRequest(senderId, receiverId)
    FriendSvc->>DB: Create Friend Request
    DB-->>FriendSvc: Request ID
    FriendSvc-->>FriendRepo: Request ID
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
    FriendRepo->>FriendSvc: acceptFriendRequest(requestId)
    FriendSvc->>DB: Update Request Status
    FriendSvc->>DB: Create Friendship (Both Ways)
    DB-->>FriendSvc: Success
    FriendSvc-->>FriendRepo: Success
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
    FriendRepo->>FriendSvc: blockUser(currentUserId, userId)
    FriendSvc->>FriendSvc: Remove friendship if exists
    FriendSvc->>DB: Create Block Record
    DB-->>FriendSvc: Success
    FriendSvc-->>FriendRepo: Success
    FriendRepo-->>UI: Success
    UI-->>User: User Blocked Confirmation
    
    %% Check if blocked before interaction
    User->>UI: Try to message user
    UI->>FriendRepo: canSendMessage(senderId, receiverId)
    FriendRepo->>FriendRepo: checkIfFriends(senderId, receiverId)
    FriendRepo->>FriendRepo: isUserBlockedBy(receiverId, senderId)
    FriendRepo->>FriendRepo: isUserBlockedBy(senderId, receiverId)
    FriendRepo-->>UI: Can/Cannot Send Message
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
