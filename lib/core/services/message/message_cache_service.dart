import 'package:flutter/foundation.dart';

import '../../models/message_model.dart';

/// Service for caching messages to improve performance
class MessageCacheService {
  /// Map to store messages by conversation ID
  final Map<String, List<MessageModel>> _messageCache = {};
  
  /// Map to store conversations by user ID
  final Map<String, List<ConversationModel>> _conversationCache = {};
  
  /// Maximum size of message cache per conversation
  static const int _maxMessageCacheSize = 100;
  
  /// Get cached messages for a conversation
  List<MessageModel>? getCachedMessages(String conversationId) {
    return _messageCache[conversationId];
  }
  
  /// Cache messages for a conversation
  void cacheMessages(String conversationId, List<MessageModel> messages) {
    // If we already have cached messages for this conversation, merge them
    if (_messageCache.containsKey(conversationId)) {
      final existingMessages = _messageCache[conversationId]!;
      final newMessages = [...messages];
      
      // Remove duplicates based on message ID
      final Map<String, MessageModel> uniqueMessages = {};
      for (final message in [...existingMessages, ...newMessages]) {
        uniqueMessages[message.id] = message;
      }
      
      // Sort by creation date descending (newest first)
      final mergedMessages = uniqueMessages.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Limit cache size
      _messageCache[conversationId] = mergedMessages.take(_maxMessageCacheSize).toList();
    } else {
      // Sort by creation date descending (newest first)
      final sortedMessages = [...messages]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Limit cache size
      _messageCache[conversationId] = sortedMessages.take(_maxMessageCacheSize).toList();
    }
  }
  
  /// Add a single message to cache
  void addMessageToCache(MessageModel message) {
    final conversationId = message.conversationId;
    if (_messageCache.containsKey(conversationId)) {
      final existingMessages = _messageCache[conversationId]!;
      
      // Check if message already exists
      final messageExists = existingMessages.any((m) => m.id == message.id);
      if (!messageExists) {
        // Add new message and sort by creation date descending
        _messageCache[conversationId] = [...existingMessages, message]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
        // Limit cache size
        if (_messageCache[conversationId]!.length > _maxMessageCacheSize) {
          _messageCache[conversationId] = _messageCache[conversationId]!
            .take(_maxMessageCacheSize).toList();
        }
      }
    } else {
      _messageCache[conversationId] = [message];
    }
    
    debugPrint('💬 MESSAGE CACHE: Added message ${message.id} to conversation ${message.conversationId} cache');
  }
  
  /// Update a message in cache
  void updateMessageInCache(MessageModel message) {
    final conversationId = message.conversationId;
    if (_messageCache.containsKey(conversationId)) {
      final existingMessages = _messageCache[conversationId]!;
      
      // Replace existing message with updated one
      final updatedMessages = existingMessages.map((m) {
        return m.id == message.id ? message : m;
      }).toList();
      
      _messageCache[conversationId] = updatedMessages;
      debugPrint('💬 MESSAGE CACHE: Updated message ${message.id} in conversation ${message.conversationId} cache');
    }
  }
  
  /// Remove a message from cache
  void removeMessageFromCache(String messageId, String conversationId) {
    if (_messageCache.containsKey(conversationId)) {
      final existingMessages = _messageCache[conversationId]!;
      
      // Remove message from cache
      _messageCache[conversationId] = existingMessages
        .where((m) => m.id != messageId).toList();
      
      debugPrint('💬 MESSAGE CACHE: Removed message $messageId from conversation $conversationId cache');
    }
  }
  
  /// Clear all cached messages for a conversation
  void clearConversationCache(String conversationId) {
    _messageCache.remove(conversationId);
    debugPrint('💬 MESSAGE CACHE: Cleared cache for conversation $conversationId');
  }
  
  /// Get cached conversations for a user
  List<ConversationModel>? getCachedConversations(String userId) {
    return _conversationCache[userId];
  }
  
  /// Cache conversations for a user
  void cacheConversations(String userId, List<ConversationModel> conversations) {
    _conversationCache[userId] = conversations;
    debugPrint('💬 CONVERSATION CACHE: Cached ${conversations.length} conversations for user $userId');
  }
  
  /// Update a conversation in cache
  void updateConversationInCache(ConversationModel conversation) {
    for (final userId in conversation.participantIds) {
      if (_conversationCache.containsKey(userId)) {
        final existingConversations = _conversationCache[userId]!;
        
        // Replace existing conversation with updated one
        final updatedConversations = existingConversations.map((c) {
          return c.id == conversation.id ? conversation : c;
        }).toList();
        
        // Sort by last message timestamp descending (newest first)
        updatedConversations.sort((a, b) {
          final aTime = a.lastMessageTimestamp ?? a.lastUpdatedAt;
          final bTime = b.lastMessageTimestamp ?? b.lastUpdatedAt;
          return bTime.compareTo(aTime);
        });
        
        _conversationCache[userId] = updatedConversations;
      }
    }
  }
  
  /// Clear all caches
  void clearAllCaches() {
    _messageCache.clear();
    _conversationCache.clear();
    debugPrint('💬 CACHE: Cleared all caches');
  }
}
