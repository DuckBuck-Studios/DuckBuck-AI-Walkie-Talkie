# DuckBuck Friend-Messaging Integration

## Overview

The DuckBuck app integrates friend management and messaging while keeping these systems properly decoupled at the service layer. This document describes how these two systems interact.

## Architecture

### Service Layer
- **FriendService**: Handles all friend-related operations (requests, acceptance, blocking)
- **MessageService**: Handles messaging operations (sending, receiving, storage)

These services are intentionally kept separate to maintain clean separation of concerns.

### Repository Layer
- **FriendRepository**: Interface for the UI layer to interact with FriendService
- **MessageRepository**: Interface for the UI layer to interact with MessageService

### Coordination Layer
- **MessageFeatureController**: A controller that coordinates between friend and messaging systems
- **Extensions**: Utility extensions that add integration functionality without tight coupling

## Integration Points

### When are Friend System checks used in Messaging?
1. **Starting a conversation**: Can only start conversations with friends
2. **Sending messages**: Checks if users are still friends and not blocked
3. **Listing conversations**: Can filter conversations to only show friends
4. **User search**: When searching for users to message, blocked users are filtered out

## Design Decisions

### Why keep services separate?
1. **Single Responsibility Principle**: Each service has a clear, focused purpose
2. **Testability**: Services can be tested independently
3. **Flexibility**: Either system can be changed without affecting the other
4. **Reusability**: Services can be used in different contexts

### How integration happens
1. **Controller Layer**: The MessageFeatureController coordinates between systems
2. **Repository Extensions**: Extension methods add integration points without modifying base classes
3. **Service Locator**: Both repositories are injected where coordination is needed

## Usage Examples

### Starting a conversation
```dart
// In a controller or bloc:
final canMessage = await friendRepository.canSendMessage(currentUserId, otherUserId);
if (canMessage) {
  final conversationId = await messageRepository.getOrCreateConversation(
    userId1: currentUserId, 
    userId2: otherUserId
  );
  // Use conversationId...
}
```

### Filtering conversations to friends only
```dart
final allConversations = await messageRepository.getConversations(userId: currentUserId);
final friendConversations = await messageRepository.filterConversationsToFriendsOnly(
  currentUserId,
  friendRepository,
  allConversations
);
```

## Benefits of this Approach

1. **Clean Architecture**: Services remain focused on their domain
2. **Maintainability**: Changes to one system don't require changes to the other
3. **Performance**: No unnecessary checks when not needed
4. **Flexibility**: Integration points can be modified without changing the core services
5. **Security**: Friend system rules are consistently enforced when messaging
