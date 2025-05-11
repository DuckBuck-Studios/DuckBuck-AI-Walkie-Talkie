# DuckBuck Messaging System Diagram

## Messaging System Class Diagram

```mermaid
classDiagram
    class MessageModel {
        +String id
        +String conversationId
        +String senderId
        +String receiverId
        +String content
        +MessageType type
        +MessageStatus status
        +DateTime createdAt
        +DateTime? readAt
        +bool isDeleted
        +String? mediaPath
        +Map~String, dynamic~? metadata
        +toMap()
        +fromMap()
        +copyWith()
    }
    
    class ConversationModel {
        +String id
        +List~String~ participantIds
        +String? lastMessageId
        +String? lastMessagePreview
        +MessageType? lastMessageType
        +DateTime? lastMessageTimestamp
        +Map~String, int~ unreadCounts
        +DateTime createdAt
        +DateTime lastUpdatedAt
        +toMap()
        +fromMap()
        +copyWith()
    }
    
    class MessageService {
        -FirebaseDatabaseService _databaseService
        -FirebaseStorageService _storageService
        -MessageCacheService _cacheService
        +Future~String~ getOrCreateConversation(String userId1, String userId2)
        +Future~String~ sendTextMessage(...)
        +Future~String~ sendPhotoMessage(...)
        +Future~String~ sendVideoMessage(...)
        +Future~String~ sendVoiceMessage(...)
        +Future~List~MessageModel~~ getMessages(String conversationId)
        +Future~void~ markMessagesAsRead(String conversationId, String userId)
        +Future~List~ConversationModel~~ getConversations(String userId)
        +Future~bool~ deleteMessage(String messageId, String userId, bool deleteForEveryone)
        +Future~bool~ deleteConversation(String conversationId, String userId)
        +Stream~List~MessageModel~~ streamMessages(String conversationId)
        +Stream~ConversationModel?~ streamConversation(String conversationId)
        +Stream~List~ConversationModel~~ streamUserConversations(String userId)
        +void dispose()
    }
    
    class MessageCacheService {
        -Map~String, List~MessageModel~~ _messageCache
        -Map~String, ConversationModel~ _conversationCache
        -Map~String, List~ConversationModel~~ _userConversationsCache
        +List~MessageModel~? getCachedMessages(String conversationId)
        +void cacheMessages(String conversationId, List~MessageModel~ messages)
        +ConversationModel? getCachedConversation(String conversationId)
        +void cacheConversation(String conversationId, ConversationModel conversation)
        +List~ConversationModel~? getCachedUserConversations(String userId)
        +void cacheUserConversations(String userId, List~ConversationModel~ conversations)
        +void clearCache()
        +void updateCachedMessage(String conversationId, MessageModel message)
        +void updateCachedConversation(ConversationModel conversation)
    }
    
    class MessageRepository {
        -MessageService _messageService
        -FriendService _friendService
        +Future~String~ getOrCreateConversation(String userId1, String userId2)
        +Future~String~ sendTextMessage(...)
        +Future~String~ sendPhotoMessage(...)
        +Future~String~ sendVideoMessage(...)
        +Future~String~ sendVoiceMessage(...)
        +Future~List~MessageModel~~ getMessages(String conversationId)
        +Future~void~ markMessagesAsRead(String conversationId, String userId)
        +Future~List~ConversationModel~~ getConversations(String userId)
        +Future~bool~ deleteMessage(String messageId, String userId, bool deleteForEveryone)
        +Stream~List~MessageModel~~ streamMessages(String conversationId)
        +Stream~List~ConversationModel~~ streamUserConversations(String userId)
        +void dispose()
    }
    
    class MessageRepositoryFriendExtension {
        +Future~List~ConversationModel~~ filterConversationsToFriendsOnly(String userId, FriendRepository friendRepository, List~ConversationModel~ conversations)
    }

    class MessageFeatureController {
        -MessageRepository _messageRepository
        -FriendRepository _friendRepository
        -List~ConversationModel~ _conversations
        -ConversationModel? _activeConversation
        -List~MessageModel~ _messages
        -bool _isLoading
        -String? _errorMessage
        +List~ConversationModel~ get conversations
        +ConversationModel? get activeConversation
        +List~MessageModel~ get messages
        +bool get isLoading
        +String? get errorMessage
        +Future~void~ loadConversations(String userId)
        +Future~void~ loadMessages(String conversationId)
        +Future~String?~ startConversation(String currentUserId, String otherUserId)
        +Future~bool~ sendTextMessage(...)
        +Future~bool~ sendPhotoMessage(...)
        +Future~bool~ sendVideoMessage(...)
        +Future~bool~ sendVoiceMessage(...)
        +Future~void~ markAsRead(String conversationId, String userId)
        +Future~bool~ deleteMessage(...)
        +void startMessageStream(String conversationId)
        +void startConversationsStream(String userId)
        +void dispose()
    }
    
    enum MessageType {
        text
        photo
        video
        voice
    }
    
    enum MessageStatus {
        sent
        delivered
        read
        failed
    }
    
    MessageModel --> MessageType : uses
    MessageModel --> MessageStatus : uses
    ConversationModel --> MessageType : uses
    MessageService --> MessageCacheService : uses
    MessageRepository --> MessageService : uses
    MessageRepository --> FriendService : uses
    MessageRepository <|-- MessageRepositoryFriendExtension : extends
    MessageFeatureController --> MessageRepository : uses
    MessageFeatureController --> FriendRepository : uses
```

## Message Flow Diagram

```mermaid
sequenceDiagram
    actor Sender
    actor Receiver
    participant SenderUI as Sender UI
    participant ReceiverUI as Receiver UI
    participant MsgCtrl as MessageFeatureController
    participant MsgRepo as MessageRepository
    participant FriendRepo as FriendRepository
    participant MsgSvc as MessageService
    participant DB as Firebase Database
    participant Storage as Firebase Storage
    
    %% Send Text Message Flow
    Sender->>SenderUI: Type and Send Message
    SenderUI->>MsgCtrl: sendTextMessage(...)
    MsgCtrl->>FriendRepo: canSendMessage(senderId, receiverId)
    FriendRepo-->>MsgCtrl: true/false
    
    alt Can Send Message
        MsgCtrl->>MsgRepo: sendTextMessage(...)
        MsgRepo->>MsgSvc: sendTextMessage(...)
        MsgSvc->>DB: Create Message Document
        MsgSvc->>DB: Update Conversation
        DB-->>MsgSvc: Success
        MsgSvc-->>MsgRepo: Message ID
        MsgRepo-->>MsgCtrl: Message ID
        MsgCtrl-->>SenderUI: Success
    else Cannot Send Message
        MsgCtrl-->>SenderUI: Error (Not Friends/Blocked)
    end
    
    %% Real-time Message Reception
    DB->>MsgSvc: New Message Event
    MsgSvc->>MsgRepo: Stream Update
    MsgRepo->>MsgCtrl: Stream Update
    MsgCtrl->>ReceiverUI: Update UI
    ReceiverUI-->>Receiver: Display New Message
    
    %% Send Media Message Flow
    Sender->>SenderUI: Select Media & Send
    SenderUI->>MsgCtrl: sendPhotoMessage(...)
    MsgCtrl->>FriendRepo: canSendMessage(senderId, receiverId)
    FriendRepo-->>MsgCtrl: true
    MsgCtrl->>MsgRepo: sendPhotoMessage(...)
    MsgRepo->>MsgSvc: sendPhotoMessage(...)
    MsgSvc->>Storage: Upload Media File
    Storage-->>MsgSvc: Media URL
    MsgSvc->>DB: Create Message with Media URL
    MsgSvc->>DB: Update Conversation
    DB-->>MsgSvc: Success
    MsgSvc-->>MsgRepo: Message ID
    MsgRepo-->>MsgCtrl: Message ID
    MsgCtrl-->>SenderUI: Success
```

## Conversation Lifecycle Diagram

```mermaid
stateDiagram-v2
    [*] --> New: Create Conversation
    New --> Active: First Message Sent
    Active --> Unread: New Message for Recipient
    Unread --> Read: Messages Marked as Read
    Read --> Active: Response Sent
    Active --> Inactive: No Activity
    Inactive --> Active: New Message
    Active --> DeletedForOne: One User Deletes
    DeletedForOne --> Active: New Message from Other User
    Active --> DeletedForBoth: Both Users Delete
    DeletedForBoth --> [*]
```

## Media Handling Diagram

```mermaid
flowchart TD
    S[Start] --> D{Message Type?}
    D -->|Text| T[Store Text Only]
    D -->|Photo| P[Photo Process]
    D -->|Video| V[Video Process]
    D -->|Voice| A[Voice Process]
    
    P --> P1[Compress Image]
    P --> P2[Generate Thumbnail]
    P --> P3[Upload to Firebase Storage]
    P --> P4[Store URL in Message]
    
    V --> V1[Compress Video]
    V --> V2[Extract Thumbnail]
    V --> V3[Upload to Firebase Storage]
    V --> V4[Store URL & Duration in Message]
    
    A --> A1[Compress Audio]
    A --> A2[Upload to Firebase Storage] 
    A --> A3[Store URL & Duration in Message]
    
    T --> DB[Store in Firebase Database]
    P4 --> DB
    V4 --> DB
    A3 --> DB
    
    DB --> E[End]
    
    style S fill:#4CAF50,stroke:#006400,color:white
    style E fill:#F44336,stroke:#B71C1C,color:white
    style D fill:#FFEB3B,stroke:#F57F17
    style T,P,V,A fill:#2196F3,stroke:#0D47A1,color:white
    style DB fill:#9C27B0,stroke:#4A148C,color:white
```
