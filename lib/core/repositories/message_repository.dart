import 'dart:io';

import '../models/message_model.dart';
import '../services/message/message_service.dart';
import '../services/message/message_cache_service.dart';
import '../services/friend/friend_service.dart';
import '../services/firebase/firebase_database_service.dart';
import '../services/firebase/firebase_storage_service.dart';

/// Repository for handling messaging operations
class MessageRepository {
  final MessageService _messageService;
  final FriendService _friendService;

  /// Creates a new MessageRepository instance
  MessageRepository({
    required FirebaseDatabaseService databaseService,
    required FirebaseStorageService storageService,
    required FriendService friendService,
    MessageCacheService? cacheService,
  }) : 
    _messageService = MessageService(
      databaseService: databaseService,
      storageService: storageService,
      cacheService: cacheService,
    ),
    _friendService = friendService;

  /// Get or create a conversation between two users
  /// 
  /// [userId1] and [userId2] are the IDs of the two users in conversation
  /// Returns the ID of the conversation
  Future<String> getOrCreateConversation({
    required String userId1,
    required String userId2,
  }) async {
    return await _messageService.getOrCreateConversation(
      userId1: userId1,
      userId2: userId2,
    );
  }

  /// Send a text message in a conversation
  /// 
  /// [conversationId] is the ID of the conversation
  /// [senderId] is the ID of the sender
  /// [receiverId] is the ID of the recipient
  /// [content] is the text content of the message
  /// Returns the ID of the created message
  Future<String> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    return await _messageService.sendTextMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
    );
  }
  
  /// Send a photo message in a conversation
  /// 
  /// [conversationId] is the ID of the conversation
  /// [senderId] is the ID of the sender
  /// [receiverId] is the ID of the recipient
  /// [file] is the image file to send
  /// [caption] is an optional caption for the photo
  /// Returns the ID of the created message
  Future<String> sendPhotoMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required File file,
    String? caption,
  }) async {
    return await _messageService.sendPhotoMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      file: file,
      caption: caption,
    );
  }
  
  /// Send a video message in a conversation
  /// 
  /// [conversationId] is the ID of the conversation
  /// [senderId] is the ID of the sender
  /// [receiverId] is the ID of the recipient
  /// [file] is the video file to send
  /// [caption] is an optional caption for the video
  /// [thumbnailUrl] is an optional thumbnail image URL
  /// [duration] is the duration of the video in seconds
  /// Returns the ID of the created message
  Future<String> sendVideoMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required File file,
    String? caption,
    String? thumbnailUrl,
    double? duration,
  }) async {
    return await _messageService.sendVideoMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      file: file,
      caption: caption,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
    );
  }
  
  /// Send a voice message in a conversation
  /// 
  /// [conversationId] is the ID of the conversation
  /// [senderId] is the ID of the sender
  /// [receiverId] is the ID of the recipient
  /// [file] is the audio file to send
  /// [duration] is the duration of the voice note in seconds
  /// Returns the ID of the created message
  Future<String> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required File file,
    required double duration,
  }) async {
    return await _messageService.sendVoiceMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      file: file,
      duration: duration,
    );
  }

  /// Get messages for a conversation with pagination
  /// 
  /// [conversationId] is the ID of the conversation to get messages for
  /// [limit] is the maximum number of messages to retrieve (default 30)
  /// [lastMessageId] is the ID of the last message in the previous page (for pagination)
  /// [forceRefresh] if true, ignores cache and fetches from database
  /// Returns a list of messages for the conversation
  Future<List<MessageModel>> getMessages({
    required String conversationId,
    int limit = 30,
    String? lastMessageId,
    bool forceRefresh = false,
  }) async {
    return await _messageService.getMessages(
      conversationId: conversationId,
      limit: limit,
      lastMessageId: lastMessageId,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Mark messages as read for a user in a conversation
  /// 
  /// [conversationId] is the ID of the conversation
  /// [userId] is the ID of the user marking messages as read
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    await _messageService.markMessagesAsRead(
      conversationId: conversationId,
      userId: userId,
    );
  }
  
  /// Get conversations for a user
  /// 
  /// [userId] is the ID of the user to get conversations for
  /// [limit] is the maximum number of conversations to retrieve
  /// [forceRefresh] if true, ignores cache and fetches from database
  /// Returns a list of conversations for the user, sorted by last message timestamp
  Future<List<ConversationModel>> getConversations({
    required String userId,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    return await _messageService.getConversations(
      userId: userId,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }

  /// Delete a message
  /// 
  /// [messageId] is the ID of the message to delete
  /// [userId] is the ID of the user deleting the message
  /// [deleteForEveryone] if true, deletes for both parties (only sender can do this)
  /// [deleteMedia] if true, also deletes associated media files from storage
  Future<void> deleteMessage({
    required String messageId,
    required String userId,
    bool deleteForEveryone = false,
    bool deleteMedia = true,
  }) async {
    await _messageService.deleteMessage(
      messageId: messageId,
      userId: userId,
      deleteForEveryone: deleteForEveryone,
      deleteMedia: deleteMedia,
    );
  }
  
  /// Delete an entire conversation for a user
  /// 
  /// [conversationId] is the ID of the conversation to delete
  /// [userId] is the ID of the user deleting the conversation
  /// [deleteMedia] if true, also deletes all media files from this user in the conversation
  Future<void> deleteConversation({
    required String conversationId,
    required String userId,
    bool deleteMedia = true,
  }) async {
    await _messageService.deleteConversation(
      conversationId: conversationId,
      userId: userId,
      deleteMedia: deleteMedia,
    );
  }

  /// Stream of messages for a conversation
  /// 
  /// [conversationId] is the ID of the conversation to stream
  /// Returns a stream of messages
  Stream<List<MessageModel>> streamMessages(String conversationId) {
    return _messageService.streamMessages(conversationId);
  }
  
  /// Stream a single conversation
  /// 
  /// [conversationId] is the ID of the conversation to stream
  Stream<ConversationModel?> streamConversation(String conversationId) {
    return _messageService.streamConversation(conversationId);
  }
  
  /// Stream all conversations for a user
  /// 
  /// [userId] is the ID of the user
  Stream<List<ConversationModel>> streamUserConversations(String userId) {
    return _messageService.streamUserConversations(userId);
  }
  
  /// Dispose of MessageService resources
  void dispose() {
    _messageService.dispose();
  }

  /// Check if we can send message to a user
  /// 
  /// Verifies that users are friends and not blocked
  /// [senderId] is the ID of the user sending the message
  /// [receiverId] is the ID of the user receiving the message
  /// Returns true if message can be sent, otherwise throws an exception
  Future<bool> canSendMessage(String senderId, String receiverId) async {
    // Check if users are friends
    final friendsList = await _friendService.getUserFriends(senderId);
    final areFriends = friendsList.contains(receiverId);
    
    if (!areFriends) {
      throw Exception('You can only send messages to users who are your friends');
    }
    
    // Check if either user has blocked the other
    final isReceiverBlockedBySender = await _friendService.isUserBlocked(senderId, receiverId);
    if (isReceiverBlockedBySender) {
      throw Exception('Cannot send messages to a user you have blocked');
    }
    
    final isSenderBlockedByReceiver = await _friendService.isUserBlocked(receiverId, senderId);
    if (isSenderBlockedByReceiver) {
      throw Exception('This user has blocked you');
    }
    
    return true;
  }

  /// Get all friends with whom user has active conversations
  /// 
  /// [userId] is the ID of the user
  /// Returns a list of conversation models for the user's friends
  Future<List<ConversationModel>> getFriendsWithConversations(String userId) async {
    // Get user's friends list
    final friendsList = await _friendService.getUserFriends(userId);
    
    // Get conversations for user
    final conversations = await _messageService.getConversations(userId: userId);
    
    // Filter conversations to ensure they're only with friends
    return conversations.where((conversation) {
      // Get the other participant's ID (not the current user)
      final otherParticipants = conversation.participantIds
          .where((participantId) => participantId != userId)
          .toList();
          
      if (otherParticipants.isEmpty) {
        return false; // Skip conversations with no other participants
      }
      
      final otherUserId = otherParticipants.first;
      return friendsList.contains(otherUserId);
    }).toList();
  }

  /// Get friends who don't have conversations yet
  /// 
  /// [userId] is the ID of the user
  /// Returns a list of friend user IDs who don't yet have conversations with the user
  Future<List<String>> getFriendsWithoutConversations(String userId) async {
    // Get user's friends list
    final friendsList = await _friendService.getUserFriends(userId);
    
    // Get conversations for user
    final conversations = await _messageService.getConversations(userId: userId);
    
    // Create a set of friends who already have conversations
    final Set<String> friendsWithConversations = {};
    
    for (final conversation in conversations) {
      // Get the other participant's ID (not the current user)
      final otherParticipants = conversation.participantIds
          .where((participantId) => participantId != userId)
          .toList();
          
      if (otherParticipants.isNotEmpty) {
        final otherUserId = otherParticipants.first;
        if (friendsList.contains(otherUserId)) {
          friendsWithConversations.add(otherUserId);
        }
      }
    }
    
    // Return friends who don't have conversations
    return friendsList
        .where((friendId) => !friendsWithConversations.contains(friendId))
        .toList();
  }

  /// Send a message to a friend with all necessary checks
  /// 
  /// This is a convenience method that performs friend checks before sending
  /// [senderId] is the ID of the sender
  /// [receiverId] is the ID of the recipient
  /// [content] is the text content of the message
  /// Returns the ID of the created message
  Future<String> sendMessageToFriend({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    // Check if we can send message to this user
    await canSendMessage(senderId, receiverId);
    
    // Get or create conversation
    final conversationId = await getOrCreateConversation(
      userId1: senderId, 
      userId2: receiverId,
    );
    
    // Send the message
    return await sendTextMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
    );
  }
}
