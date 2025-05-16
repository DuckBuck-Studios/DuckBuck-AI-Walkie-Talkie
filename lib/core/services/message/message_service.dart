import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/message_model.dart';
import '../firebase/firebase_database_service.dart';
import '../firebase/firebase_storage_service.dart';
import 'message_cache_service.dart';

/// Service for handling messaging operations
class MessageService {
  final FirebaseDatabaseService _databaseService;
  final FirebaseStorageService _storageService;
  final MessageCacheService _cacheService;
  
  /// Collection reference for messages
  static const String _messagesCollection = 'messages';
  
  /// Collection reference for conversations
  static const String _conversationsCollection = 'conversations';
  
  /// Storage folder for message media
  static const String _mediaFolder = 'message_media';
  
  /// Stream controllers for real-time updates
  final Map<String, StreamController<List<MessageModel>>> _messageStreamControllers = {};
  final Map<String, StreamController<ConversationModel?>> _conversationStreamControllers = {};

  /// Creates a new MessageService instance
  MessageService({
    required FirebaseDatabaseService databaseService,
    required FirebaseStorageService storageService,
    MessageCacheService? cacheService,
  }) : 
    _databaseService = databaseService,
    _storageService = storageService,
    _cacheService = cacheService ?? MessageCacheService();

  /// Get or create a conversation between two users
  /// 
  /// [userId1] and [userId2] are the IDs of the two users in conversation
  /// Returns the ID of the conversation
  Future<String> getOrCreateConversation({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Sort user IDs to ensure consistent conversation IDs
      final List<String> participantIds = [userId1, userId2]..sort();
      
      // Check if conversation already exists between these users
      final existingConversations = await _databaseService.queryDocuments(
        collection: _conversationsCollection,
        field: 'participantIds',
        isEqualTo: participantIds,
      );
      
      // If conversation exists, return its ID
      if (existingConversations.isNotEmpty) {
        return existingConversations.first['id'];
      }
      
      // Create a new conversation
      final Map<String, int> unreadCounts = {
        userId1: 0,
        userId2: 0,
      };
      
      final conversationData = ConversationModel(
        id: '', // Will be replaced with actual ID
        participantIds: participantIds,
        unreadCounts: unreadCounts,
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
      ).toMap();
      
      final conversationId = await _databaseService.addDocument(
        collection: _conversationsCollection,
        data: conversationData,
      );
      
      return conversationId;
    } catch (e) {
      throw Exception('Failed to get or create conversation: ${e.toString()}');
    }
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
    return await _sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      type: MessageType.text,
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
    final String fileName = file.path.split('/').last;
    final String mediaPath = _storageService.generateFilePath(
      userId: senderId,
      folderName: '$_mediaFolder/photos',
      fileName: fileName,
    );
    
    // Upload the photo to storage
    final String downloadUrl = await _storageService.uploadFile(
      path: mediaPath,
      file: file,
      metadata: {
        'senderId': senderId,
        'conversationId': conversationId,
        'type': 'photo',
      },
    );
    
    // Create metadata with image dimensions if possible
    Map<String, dynamic> metadata = {
      'caption': caption,
    };
    
    return await _sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: downloadUrl, // URL of the photo
      type: MessageType.photo,
      mediaPath: mediaPath,
      metadata: metadata,
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
    final String fileName = file.path.split('/').last;
    final String mediaPath = _storageService.generateFilePath(
      userId: senderId,
      folderName: '$_mediaFolder/videos',
      fileName: fileName,
    );
    
    // Upload the video to storage
    final String downloadUrl = await _storageService.uploadFile(
      path: mediaPath,
      file: file,
      metadata: {
        'senderId': senderId,
        'conversationId': conversationId,
        'type': 'video',
      },
    );
    
    // Create metadata with video details
    Map<String, dynamic> metadata = {
      'caption': caption,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
    };
    
    return await _sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: downloadUrl, // URL of the video
      type: MessageType.video,
      mediaPath: mediaPath,
      metadata: metadata,
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
    final String fileName = file.path.split('/').last;
    final String mediaPath = _storageService.generateFilePath(
      userId: senderId,
      folderName: '$_mediaFolder/voice',
      fileName: fileName,
    );
    
    // Upload the audio to storage
    final String downloadUrl = await _storageService.uploadFile(
      path: mediaPath,
      file: file,
      metadata: {
        'senderId': senderId,
        'conversationId': conversationId,
        'type': 'voice',
      },
    );
    
    // Create metadata with audio details
    Map<String, dynamic> metadata = {
      'duration': duration,
    };
    
    return await _sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: downloadUrl, // URL of the voice note
      type: MessageType.voice,
      mediaPath: mediaPath,
      metadata: metadata,
    );
  }
  
  /// Helper method to send a message of any type
  Future<String> _sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String content,
    required MessageType type,
    String? mediaPath,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final messageData = MessageModel(
        id: '', // Will be replaced with actual ID
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        type: type,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
        mediaPath: mediaPath,
        metadata: metadata,
      ).toMap();
      
      // Create the message in Firestore
      final messageId = await _databaseService.addDocument(
        collection: _messagesCollection,
        data: messageData,
      );
      
      // Update the conversation with the latest message info
      await _updateConversationWithLastMessage(
        conversationId: conversationId,
        messageId: messageId,
        messagePreview: _generateMessagePreview(content, type, metadata),
        messageType: type,
        senderId: senderId,
        receiverId: receiverId,
      );
      
      return messageId;
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }
  
  /// Generate a preview text for the conversation list
  String _generateMessagePreview(String content, MessageType type, Map<String, dynamic>? metadata) {
    switch (type) {
      case MessageType.text:
        // For text messages, use the content directly (truncated if needed)
        return content.length > 50 ? '${content.substring(0, 47)}...' : content;
      case MessageType.photo:
        // For photos, use the caption if available, otherwise a generic message
        return metadata != null && metadata['caption'] != null 
            ? '📷 Photo: ${metadata['caption']}'
            : '📷 Photo';
      case MessageType.video:
        // For videos, use the caption if available, otherwise a generic message
        return metadata != null && metadata['caption'] != null 
            ? '🎥 Video: ${metadata['caption']}'
            : '🎥 Video';
      case MessageType.voice:
        // For voice messages, include duration if available
        if (metadata != null && metadata['duration'] != null) {
          final duration = metadata['duration'] as double;
          final minutes = (duration / 60).floor();
          final seconds = (duration % 60).floor();
          return '🎤 Voice message (${minutes > 0 ? '${minutes}m ' : ''}${seconds}s)';
        }
        return '🎤 Voice message';
    }
  }

  /// Update a conversation with information about the last message
  Future<void> _updateConversationWithLastMessage({
    required String conversationId,
    required String messageId,
    required String messagePreview,
    required MessageType messageType,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      // Get the current conversation
      final conversationData = await _databaseService.getDocument(
        collection: _conversationsCollection,
        documentId: conversationId,
      );
      
      if (conversationData == null) {
        throw Exception('Conversation not found');
      }
      
      // Convert to model for easier handling
      final conversation = ConversationModel.fromMap(conversationData, conversationId);
      
      // Increment unread count for the receiver
      final updatedUnreadCounts = Map<String, int>.from(conversation.unreadCounts);
      updatedUnreadCounts[receiverId] = (updatedUnreadCounts[receiverId] ?? 0) + 1;
      
      // Update the conversation
      await _databaseService.updateDocument(
        collection: _conversationsCollection,
        documentId: conversationId,
        data: {
          'lastMessageId': messageId,
          'lastMessagePreview': messagePreview,
          'lastMessageType': messageType.name,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'unreadCounts': updatedUnreadCounts,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      // Log the error but don't fail the message send operation
      debugPrint('Failed to update conversation with last message: ${e.toString()}');
    }
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
    try {
      // Try to get messages from cache if this is the first page and not forcing refresh
      if (lastMessageId == null && !forceRefresh) {
        final cachedMessages = _cacheService.getCachedMessages(conversationId);
        if (cachedMessages != null && cachedMessages.length >= limit) {
          debugPrint('💬 MESSAGE SERVICE: Using cached messages for conversation $conversationId');
          return cachedMessages.take(limit).toList();
        }
      }
      
      final List<MessageModel> messages = [];
      List<Map<String, dynamic>> messagesData;
      
      if (lastMessageId != null) {
        // Get the last message snapshot for pagination
        final lastMessageDoc = await _databaseService.getDocument(
          collection: _messagesCollection,
          documentId: lastMessageId,
        );
        
        if (lastMessageDoc == null) {
          throw Exception('Last message not found for pagination');
        }
        
        messagesData = await _databaseService.queryDocumentsWithPagination(
          collection: _messagesCollection,
          field: 'conversationId',
          isEqualTo: conversationId,
          orderBy: 'createdAt',
          descending: true,
          limit: limit,
          startAfterDocument: lastMessageId,
        );
      } else {
        // First page - no pagination cursor needed
        messagesData = await _databaseService.queryDocuments(
          collection: _messagesCollection,
          field: 'conversationId',
          isEqualTo: conversationId,
          orderBy: 'createdAt',
          descending: true,
          limit: limit,
        );
      }
      
      // Convert to message models
      for (final messageData in messagesData) {
        messages.add(MessageModel.fromMap(messageData, messageData['id']));
      }
      
      // Cache the messages if this is the first page
      if (lastMessageId == null) {
        _cacheService.cacheMessages(conversationId, messages);
      }
      
      return messages;
    } catch (e) {
      debugPrint('💬 MESSAGE SERVICE: Failed to get messages: ${e.toString()}');
      
      // If there was an error but we have cached messages, return those as a fallback
      if (lastMessageId == null && !forceRefresh) {
        final cachedMessages = _cacheService.getCachedMessages(conversationId);
        if (cachedMessages != null) {
          debugPrint('💬 MESSAGE SERVICE: Using cached messages as fallback');
          return cachedMessages.take(limit).toList();
        }
      }
      
      throw Exception('Failed to get messages: ${e.toString()}');
    }
  }
  
  /// Mark messages as read for a user in a conversation
  /// 
  /// [conversationId] is the ID of the conversation
  /// [userId] is the ID of the user marking messages as read
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // First, update the unread count in the conversation document
      final conversationData = await _databaseService.getDocument(
        collection: _conversationsCollection,
        documentId: conversationId,
      );
      
      if (conversationData == null) {
        throw Exception('Conversation not found');
      }
      
      final conversation = ConversationModel.fromMap(conversationData, conversationId);
      
      // Reset unread count for this user
      final updatedUnreadCounts = Map<String, int>.from(conversation.unreadCounts);
      updatedUnreadCounts[userId] = 0;
      
      // Update the conversation
      await _databaseService.updateDocument(
        collection: _conversationsCollection,
        documentId: conversationId,
        data: {
          'unreadCounts': updatedUnreadCounts,
        },
      );
      
      // Update all unread messages where this user is the receiver
      final batch = _databaseService.firestoreInstance.batch();
      
      // Get unread messages for this user
      final unreadMessagesData = await _databaseService.queryDocuments(
        collection: _messagesCollection,
        conditions: [
          {'field': 'conversationId', 'operator': '==', 'value': conversationId},
          {'field': 'receiverId', 'operator': '==', 'value': userId},
          {'field': 'status', 'operator': 'in', 'value': ['sent', 'delivered']},
        ],
      );
      
      // Mark each message as read in a batch
      final now = FieldValue.serverTimestamp();
      for (final messageData in unreadMessagesData) {
        final messageRef = _databaseService.firestoreInstance
            .collection(_messagesCollection)
            .doc(messageData['id']);
            
        batch.update(messageRef, {
          'status': MessageStatus.read.name,
          'readAt': now,
        });
      }
      
      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark messages as read: ${e.toString()}');
    }
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
    try {
      // Try to get conversations from cache if not forcing refresh
      if (!forceRefresh) {
        final cachedConversations = _cacheService.getCachedConversations(userId);
        if (cachedConversations != null) {
          debugPrint('💬 MESSAGE SERVICE: Using cached conversations for user $userId');
          return cachedConversations.take(limit).toList();
        }
      }
      
      final List<ConversationModel> conversations = [];
      
      final conversationsData = await _databaseService.queryDocuments(
        collection: _conversationsCollection,
        field: 'participantIds',
        arrayContains: userId,
        orderBy: 'lastUpdatedAt',
        descending: true,
        limit: limit,
      );
      
      // Convert to conversation models
      for (final conversationData in conversationsData) {
        conversations.add(ConversationModel.fromMap(
          conversationData, 
          conversationData['id'],
        ));
      }
      
      // Cache the conversations
      _cacheService.cacheConversations(userId, conversations);
      
      return conversations;
    } catch (e) {
      debugPrint('💬 MESSAGE SERVICE: Failed to get conversations: ${e.toString()}');
      
      // If there was an error but we have cached conversations, return those as a fallback
      if (!forceRefresh) {
        final cachedConversations = _cacheService.getCachedConversations(userId);
        if (cachedConversations != null) {
          debugPrint('💬 MESSAGE SERVICE: Using cached conversations as fallback');
          return cachedConversations.take(limit).toList();
        }
      }
      
      throw Exception('Failed to get conversations: ${e.toString()}');
    }
  }

  /// Delete a message for a user
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
    try {
      final messageData = await _databaseService.getDocument(
        collection: _messagesCollection,
        documentId: messageId,
      );
      
      if (messageData == null) {
        throw Exception('Message not found');
      }
      
      final message = MessageModel.fromMap(messageData, messageId);
      
      if (deleteForEveryone && message.senderId != userId) {
        throw Exception('Only the sender can delete messages for everyone');
      }
      
      if (deleteForEveryone) {
        // If deleting for everyone, update the message document
        await _databaseService.updateDocument(
          collection: _messagesCollection,
          documentId: messageId,
          data: {
            'isDeleted': true,
            'content': 'This message was deleted',
          },
        );
        
        // Delete media files if present and requested
        if (deleteMedia && message.mediaPath != null) {
          await _storageService.deleteFile(message.mediaPath!);
        }
      } else {
        // If only deleting for the current user, we don't change the original message
        // Instead, we add this message ID to a "deletedMessages" collection for this user
        await _databaseService.setDocument(
          collection: 'deletedMessages',
          documentId: '${userId}_$messageId',
          data: {
            'userId': userId,
            'messageId': messageId,
            'deletedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
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
    try {
      // First, record that this conversation is deleted for this user
      await _databaseService.setDocument(
        collection: 'deletedConversations',
        documentId: '${userId}_$conversationId',
        data: {
          'userId': userId,
          'conversationId': conversationId,
          'deletedAt': FieldValue.serverTimestamp(),
        },
      );
      
      // If deleteMedia is true, find and delete all media sent by this user in the conversation
      if (deleteMedia) {
        final messagesData = await _databaseService.queryDocuments(
          collection: _messagesCollection,
          conditions: [
            {'field': 'conversationId', 'operator': '==', 'value': conversationId},
            {'field': 'senderId', 'operator': '==', 'value': userId},
            {'field': 'mediaPath', 'operator': '!=', 'value': null},
          ],
        );
        
        // Delete each media file
        for (final messageData in messagesData) {
          final message = MessageModel.fromMap(messageData, messageData['id']);
          if (message.mediaPath != null) {
            await _storageService.deleteFile(message.mediaPath!);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to delete conversation: ${e.toString()}');
    }
  }

  /// Stream of messages for a conversation
  /// 
  /// [conversationId] is the ID of the conversation to stream
  /// Returns a stream of messages
  Stream<List<MessageModel>> streamMessages(String conversationId) {
    if (!_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId] = StreamController<List<MessageModel>>.broadcast();
      
      // Set up the stream from Firestore
      final messageStream = _databaseService.collectionStream(
        collection: _messagesCollection,
        queryBuilder: (query) => query
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('createdAt', descending: true),
      );
      
      // Listen to changes and update the stream controller
      messageStream.listen((snapshot) {
        final messages = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return MessageModel.fromMap(data, doc.id);
        }).toList();
        
        // Cache the messages
        _cacheService.cacheMessages(conversationId, messages);
        
        // Add to the stream
        if (!_messageStreamControllers[conversationId]!.isClosed) {
          _messageStreamControllers[conversationId]!.add(messages);
        }
      });
    }
    
    // If we have cached messages, emit them immediately
    final cachedMessages = _cacheService.getCachedMessages(conversationId);
    if (cachedMessages != null && !_messageStreamControllers[conversationId]!.isClosed) {
      _messageStreamControllers[conversationId]!.add(cachedMessages);
    }
    
    return _messageStreamControllers[conversationId]!.stream;
  }
  
  /// Stream a single conversation
  /// 
  /// [conversationId] is the ID of the conversation to stream
  Stream<ConversationModel?> streamConversation(String conversationId) {
    if (!_conversationStreamControllers.containsKey(conversationId)) {
      _conversationStreamControllers[conversationId] = StreamController<ConversationModel>.broadcast();
      
      // Set up the stream from Firestore
      final conversationStream = _databaseService.documentStream(
        collection: _conversationsCollection,
        documentId: conversationId,
      );
      
      // Listen to changes and update the stream controller
      conversationStream.listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          data['id'] = snapshot.id;
          final conversation = ConversationModel.fromMap(data, snapshot.id);
          
          // Update cache
          _cacheService.updateConversationInCache(conversation);
          
          // Add to the stream
          if (!_conversationStreamControllers[conversationId]!.isClosed) {
            _conversationStreamControllers[conversationId]!.add(conversation);
          }
        } else {
          // Conversation deleted or doesn't exist
          if (!_conversationStreamControllers[conversationId]!.isClosed) {
            _conversationStreamControllers[conversationId]!.add(null);
          }
        }
      });
    }
    
    return _conversationStreamControllers[conversationId]!.stream;
  }
  
  /// Stream all conversations for a user
  /// 
  /// [userId] is the ID of the user
  Stream<List<ConversationModel>> streamUserConversations(String userId) {
    final controller = StreamController<List<ConversationModel>>.broadcast();
    
    // Set up the stream from Firestore
    final conversationStream = _databaseService.collectionStream(
      collection: _conversationsCollection,
      queryBuilder: (query) => query
        .where('participantIds', arrayContains: userId)
        .orderBy('lastUpdatedAt', descending: true),
    );
    
    // Listen to changes and update the stream controller
    conversationStream.listen((snapshot) {
      final conversations = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ConversationModel.fromMap(data, doc.id);
      }).toList();
      
      // Cache the conversations
      _cacheService.cacheConversations(userId, conversations);
      
      // Add to the stream
      if (!controller.isClosed) {
        controller.add(conversations);
      }
    });
    
    // If we have cached conversations, emit them immediately
    final cachedConversations = _cacheService.getCachedConversations(userId);
    if (cachedConversations != null && !controller.isClosed) {
      controller.add(cachedConversations);
    }
    
    return controller.stream;
  }
  
  /// Dispose of resources
  void dispose() {
    // Close all stream controllers
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    for (final controller in _conversationStreamControllers.values) {
      controller.close();
    }
    
    _messageStreamControllers.clear();
    _conversationStreamControllers.clear();
    
    // Clear caches
    _cacheService.clearAllCaches();
  }
}
