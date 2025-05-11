# DuckBuck Messaging System

## Overview

The DuckBuck messaging system is a comprehensive solution for handling text and multimedia messages between users. It supports real-time updates, different message types, media storage management, and provides efficient caching for optimal performance. The system is designed to work seamlessly with the friend system while maintaining proper separation of concerns.

## Components

### Models

1. **MessageModel**
   - Represents a message with support for different types (text, photo, video, voice)
   - Tracks message status (sent, delivered, read, failed)
   - Handles media path references and metadata

2. **ConversationModel**
   - Represents a conversation between two users
   - Tracks unread message counts
   - Contains preview of last message

### Services

1. **MessageService**
   - Core logic for sending/receiving messages
   - Handles storage and retrieval of messages
   - Manages conversations
   - Provides real-time updates via streams
   - Supports message deletion (for self or everyone)
   - Integrates with cache for performance

2. **MessageCacheService**
   - Optimizes performance by caching messages and conversations
   - Provides fallback data when network requests fail
   - Efficiently manages cache size
   - Handles updates to cached data

### Repository

**MessageRepository**
   - Provides a clean interface for UI components
   - Abstracts implementation details of messaging services
   - Exposes methods for sending different types of messages
   - Provides streams for real-time updates

## Features

### Message Types
- Text messages
- Photos with optional captions
- Videos with thumbnails and duration
- Voice notes with duration

### Real-time Messaging
- Live updates for new messages
- Conversation list updates
- Read status tracking

### Media Management
- Efficient storage of media files
- Proper cleanup of files when deleted
- Metadata tracking for media files

### Message Operations
- Send messages
- Delete messages (for self or everyone)
- Mark messages as read
- Get conversation history with pagination

### Conversation Management
- Create conversations
- Delete conversations
- Track unread message counts
- Update conversation previews

## Database Structure

### Collections
- **messages**: Stores all message data
- **conversations**: Stores conversation metadata
- **deletedMessages**: Tracks which messages are deleted for specific users
- **deletedConversations**: Tracks which conversations are deleted for specific users

### Storage Structure
- Media files are organized by user ID and type
- Naming convention includes timestamps for uniqueness

## Usage Examples

### Sending Messages
```dart
// Send text message
final messageId = await messageRepository.sendTextMessage(
  conversationId: conversationId,
  senderId: currentUserId,
  receiverId: friendId,
  content: "Hello, how are you?",
);

// Send photo message
final messageId = await messageRepository.sendPhotoMessage(
  conversationId: conversationId,
  senderId: currentUserId,
  receiverId: friendId,
  file: photoFile,
  caption: "Check out this photo!",
);
```

### Real-time Updates
```dart
// Get real-time message updates
messageRepository.streamMessages(conversationId).listen((messages) {
  // Update UI with new messages
});

// Get real-time conversation updates
messageRepository.streamUserConversations(currentUserId).listen((conversations) {
  // Update conversation list UI
});
```

### Managing Messages
```dart
// Delete a message for yourself
await messageRepository.deleteMessage(
  messageId: messageId,
  userId: currentUserId,
  deleteForEveryone: false,
);

// Delete a message for everyone (only sender can do this)
await messageRepository.deleteMessage(
  messageId: messageId,
  userId: currentUserId,
  deleteForEveryone: true,
);
```

## Integration with Friend System

The messaging system integrates with the existing friend system, allowing users to:

1. Start conversations only with friends
2. Block users, which prevents messaging
3. Search for friends to start new conversations

## Security Considerations

1. Only friends can message each other
2. Blocked users can't see each other's messages
3. Media files are secured with proper permissions
4. Message deletion properly cleans up associated media

## Performance Optimizations

1. Efficient caching of messages and conversations
2. Pagination for loading large message histories
3. Real-time updates only for active conversations
4. Fallback to cached data when network requests fail
