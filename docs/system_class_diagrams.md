# DuckBuck Authentication System Class Diagram

```
┌───────────────────────────┐
│  <<interface>>            │
│  AuthServiceInterface     │
├───────────────────────────┤
│ + currentUser: User?      │
│ + authStateChanges: Stream│
├───────────────────────────┤
│ + signInWithEmailPassword()│
│ + createAccountWithEmail() │
│ + signInWithGoogle()      │
│ + signInWithApple()       │
│ + verifyPhoneNumber()     │
│ + signOut()               │
│ + updateProfile()         │
│ + deleteAccount()         │
└───────────────┬───────────┘
                │
                │ implements
                ▼
┌───────────────────────────┐
│  FirebaseAuthService      │
├───────────────────────────┤
│ - _auth: FirebaseAuth     │
│ - _googleSignIn: GoogleSignIn │
├───────────────────────────┤
│ + signInWithEmailPassword()│
│ + createAccountWithEmail() │
│ + signInWithGoogle()      │
│ + signInWithApple()       │
│ + verifyPhoneNumber()     │
│ + signOut()               │
│ + updateProfile()         │
│ + deleteAccount()         │
└───────────────────────────┘
                ▲
                │ uses
┌───────────────┴───────────┐
│  UserRepository           │
├───────────────────────────┤
│ - authService: AuthServiceInterface │
│ - _firestore: FirebaseFirestore │
├───────────────────────────┤
│ + currentUser: UserModel? │
│ + authStateChanges: Stream│
│ + signIn()                │
│ + signUp()                │
│ + googleSignIn()          │
│ + appleSignIn()           │
│ + phoneSignIn()           │
│ + signOut()               │
│ + updateProfile()         │
│ + resetPassword()         │
└───────────────────────────┘
                ▲
                │ uses
┌───────────────┴───────────┐
│  AuthController           │
├───────────────────────────┤
│ - _userRepository: UserRepository │
├───────────────────────────┤
│ + user: UserModel?        │
│ + isAuthenticated: bool   │
│ + authStateChanges: Stream│
│ + signIn()                │
│ + signUp()                │
│ + socialSignIn()          │
│ + signOut()               │
└───────────────────────────┘
```

# DuckBuck Friend System Class Diagram

```
┌───────────────────────────┐
│  FriendService            │
├───────────────────────────┤
│ - _databaseService: FirebaseDatabaseService │
├───────────────────────────┤
│ + sendFriendRequest()     │
│ + getFriendRequest()      │
│ + getPendingRequestsForUser() │
│ + acceptFriendRequest()   │
│ + rejectFriendRequest()   │
│ + cancelFriendRequest()   │
│ + getUserFriends()        │
│ + removeFriend()          │
│ + blockUser()             │
│ + unblockUser()           │
│ + isUserBlocked()         │
└───────────────┬───────────┘
                │
                │ uses
                ▼
┌───────────────────────────┐
│  FriendRepository         │
├───────────────────────────┤
│ - _friendService: FriendService │
│ - _userRepository: UserRepository │
├───────────────────────────┤
│ + sendFriendRequest()     │
│ + getPendingRequests()    │
│ + acceptFriendRequest()   │
│ + rejectFriendRequest()   │
│ + cancelFriendRequest()   │
│ + getFriends()            │
│ + isFriendWith()          │
│ + removeFriend()          │
│ + blockUser()             │
│ + unblockUser()           │
│ + isUserBlocked()         │
│ + checkIfFriends()        │
│ + isUserBlockedBy()       │
└───────────────────────────┘
                │
┌───────────────┴───────────┐
│<<extension>>              │
│FriendRepositoryMessagingExtension │
├───────────────────────────┤
│ + canSendMessage()        │
│ + getMessagingEnabledFriends() │
└───────────────────────────┘
```

# DuckBuck Messaging System Class Diagram

```
┌───────────────────────────┐
│  MessageModel             │
├───────────────────────────┤
│ + id: String              │
│ + conversationId: String  │
│ + senderId: String        │
│ + receiverId: String      │
│ + content: String         │
│ + type: MessageType       │
│ + timestamp: DateTime     │
│ + status: MessageStatus   │
│ + mediaMetadata: Map?     │
│ + isDeleted: bool         │
└───────────────────────────┘
                │
                │
                ▼
┌───────────────────────────┐
│  ConversationModel        │
├───────────────────────────┤
│ + id: String              │
│ + participantIds: List<String> │
│ + lastMessagePreview: String │
│ + lastMessageTime: DateTime │
│ + unreadCounts: Map<String, int> │
└───────────────────────────┘
                │
                │
                ▼
┌───────────────────────────┐
│  MessageService           │
├───────────────────────────┤
│ - _databaseService: FirebaseDatabaseService │
│ - _storageService: FirebaseStorageService │
│ - _cacheService: MessageCacheService │
├───────────────────────────┤
│ + getMessages()           │
│ + getConversations()      │
│ + sendTextMessage()       │
│ + sendMediaMessage()      │
│ + deleteMessage()         │
│ + markMessagesAsRead()    │
│ + streamMessages()        │
│ + streamConversations()   │
└───────────────┬───────────┘
                │
                │ uses
                ▼
┌───────────────────────────┐
│  MessageCacheService      │
├───────────────────────────┤
│ - _messageCache: Map      │
│ - _conversationCache: Map │
├───────────────────────────┤
│ + cacheMessages()         │
│ + getCachedMessages()     │
│ + cacheConversations()    │
│ + getCachedConversations()│
│ + clearCache()            │
└───────────────────────────┘
                ▲
                │ uses
┌───────────────┴───────────┐
│  MessageRepository        │
├───────────────────────────┤
│ - _messageService: MessageService │
│ - _friendService: FriendService │
├───────────────────────────┤
│ + getMessages()           │
│ + getConversations()      │
│ + getOrCreateConversation() │
│ + sendTextMessage()       │
│ + sendPhotoMessage()      │
│ + sendVideoMessage()      │
│ + sendVoiceMessage()      │
│ + deleteMessage()         │
│ + markMessagesAsRead()    │
│ + streamMessages()        │
│ + streamUserConversations() │
└───────────────────────────┘
                │
┌───────────────┴───────────┐
│<<extension>>              │
│MessageRepositoryFriendExtension │
├───────────────────────────┤
│ + filterConversationsToFriendsOnly() │
└───────────────────────────┘
                ▲
                │ uses
┌───────────────┴───────────┐
│  MessageFeatureController │
├───────────────────────────┤
│ - _messageRepository: MessageRepository │
│ - _friendRepository: FriendRepository │
│ - _conversations: List<ConversationModel> │
│ - _messages: List<MessageModel> │
├───────────────────────────┤
│ + loadConversations()     │
│ + loadMessages()          │
│ + startConversation()     │
│ + sendTextMessage()       │
│ + sendPhotoMessage()      │
│ + sendVideoMessage()      │
│ + sendVoiceMessage()      │
│ + deleteMessage()         │
│ + markAsRead()            │
│ + startMessageStream()    │
│ + startConversationsStream() │
└───────────────────────────┘
```

# DuckBuck System Integration Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Service Locator (GetIt)                       │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    │ registers/provides
                                    ▼
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  Auth System     │      │  Friend System   │      │ Messaging System │
├──────────────────┤      ├──────────────────┤      ├──────────────────┤
│AuthServiceInterface│─────►FriendService    │◄─────┤MessageService    │
│FirebaseAuthService │      │FriendRepository │─────►│MessageRepository │
│UserRepository     │◄────┘└────────┬─────────┘      │MessageCacheService│
└──────────────────┘               │                └──────────────────┘
                                   │                        ▲
                                   │                        │
                                   ▼                        │
               ┌────────────────────────────────┐           │
               │   Integration Components        │           │
               ├────────────────────────────────┤           │
               │FriendRepositoryMessagingExtension│──────────┘
               │MessageRepositoryFriendExtension  │
               │MessageFeatureController         │
               └────────────────────────────────┘
```
