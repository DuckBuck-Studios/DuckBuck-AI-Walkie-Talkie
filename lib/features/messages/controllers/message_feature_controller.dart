import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/repositories/message_repository.dart';
import '../../../core/repositories/friend_repository.dart';
import '../../../core/models/message_model.dart';

/// Controller that coordinates messaging features with friend system
class MessageFeatureController extends ChangeNotifier {
  final MessageRepository _messageRepository;
  final FriendRepository _friendRepository;

  /// List of current conversations
  List<ConversationModel> _conversations = [];
  
  /// Current active conversation
  ConversationModel? _activeConversation;
  
  /// Messages in the active conversation
  List<MessageModel> _messages = [];
  
  /// Loading state
  bool _isLoading = false;
  
  /// Error message
  String? _errorMessage;

  /// Creates a new MessageFeatureController
  MessageFeatureController({
    required MessageRepository messageRepository,
    required FriendRepository friendRepository,
  }) : 
    _messageRepository = messageRepository,
    _friendRepository = friendRepository;

  /// Get the list of conversations
  List<ConversationModel> get conversations => _conversations;

  /// Get the active conversation
  ConversationModel? get activeConversation => _activeConversation;

  /// Get messages in the active conversation
  List<MessageModel> get messages => _messages;

  /// Get loading state
  bool get isLoading => _isLoading;

  /// Get error message
  String? get errorMessage => _errorMessage;

  /// Load conversations for the current user
  Future<void> loadConversations(String userId) async {
    try {
      _setLoading(true);
      _conversations = await _messageRepository.getConversations(
        userId: userId,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load conversations: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Load messages for a conversation
  Future<void> loadMessages(String conversationId) async {
    try {
      _setLoading(true);
      
      // Find the conversation in the list
      _activeConversation = _conversations.firstWhere(
        (conversation) => conversation.id == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );
      
      _messages = await _messageRepository.getMessages(
        conversationId: conversationId,
      );
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load messages: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Start a new conversation with a user
  /// 
  /// Returns the conversation ID if successful
  Future<String?> startConversation(String currentUserId, String otherUserId) async {
    try {
      _setLoading(true);
      
      // Check if they are friends before starting a conversation
      final isFriend = await _friendRepository.checkIfFriends(currentUserId, otherUserId);
      
      if (!isFriend) {
        _setError('You can only message users who are your friends');
        return null;
      }
      
      // Check if the current user is blocked
      final isBlocked = await _friendRepository.isUserBlockedBy(otherUserId, currentUserId);
      
      if (isBlocked) {
        _setError('You cannot message this user');
        return null;
      }
      
      // Create or get existing conversation
      final conversationId = await _messageRepository.getOrCreateConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );
      
      return conversationId;
    } catch (e) {
      _setError('Failed to start conversation: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Send a text message
  Future<bool> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    try {
      _setLoading(true);
      
      // Check if the sender is blocked before sending
      final isBlocked = await _friendRepository.isUserBlockedBy(receiverId, senderId);
      
      if (isBlocked) {
        _setError('Cannot send messages to this user');
        return false;
      }
      
      await _messageRepository.sendTextMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
      );
      
      return true;
    } catch (e) {
      _setError('Failed to send message: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send a photo message
  Future<bool> sendPhotoMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required File file,
    String? caption,
  }) async {
    try {
      _setLoading(true);
      
      // Check if the sender is blocked before sending
      final isBlocked = await _friendRepository.isUserBlockedBy(receiverId, senderId);
      
      if (isBlocked) {
        _setError('Cannot send messages to this user');
        return false;
      }
      
      await _messageRepository.sendPhotoMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        file: file,
        caption: caption,
      );
      
      return true;
    } catch (e) {
      _setError('Failed to send photo: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      await _messageRepository.markMessagesAsRead(
        conversationId: conversationId,
        userId: userId,
      );
      
      // Update the conversation in the list
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        final updatedConversation = _conversations[index].copyWith(
          unreadCounts: {
            ..._conversations[index].unreadCounts,
            userId: 0,
          },
        );
        
        _conversations[index] = updatedConversation;
        
        // If this is the active conversation, update that too
        if (_activeConversation?.id == conversationId) {
          _activeConversation = updatedConversation;
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking messages as read: ${e.toString()}');
    }
  }

  /// Delete a message
  Future<bool> deleteMessage({
    required String messageId,
    required String userId,
    bool deleteForEveryone = false,
  }) async {
    try {
      _setLoading(true);
      
      await _messageRepository.deleteMessage(
        messageId: messageId,
        userId: userId,
        deleteForEveryone: deleteForEveryone,
      );
      
      // Remove the message from the list if it was deleted for everyone
      if (deleteForEveryone) {
        _messages = _messages.map((message) {
          if (message.id == messageId) {
            return message.copyWith(
              isDeleted: true,
              content: 'This message was deleted',
            );
          }
          return message;
        }).toList();
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete message: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Listen for real-time message updates
  void startMessageStream(String conversationId) {
    _messageRepository.streamMessages(conversationId).listen((messages) {
      _messages = messages;
      notifyListeners();
    });
  }

  /// Listen for real-time conversation updates
  void startConversationsStream(String userId) {
    _messageRepository.streamUserConversations(userId).listen((conversations) {
      _conversations = conversations;
      notifyListeners();
    });
  }

  /// Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// Helper to set error message
  void _setError(String message) {
    _errorMessage = message;
    debugPrint('MessageFeatureController Error: $message');
    notifyListeners();
  }

  @override
  void dispose() {
    _messageRepository.dispose();
    super.dispose();
  }
}
