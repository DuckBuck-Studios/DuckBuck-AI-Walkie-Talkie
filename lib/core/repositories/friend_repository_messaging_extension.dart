import 'dart:async';

import '../repositories/friend_repository.dart';
import '../repositories/message_repository.dart';
import '../models/message_model.dart';

/// Extension methods for FriendRepository that provide messaging-related functionality
extension FriendRepositoryMessagingExtension on FriendRepository {
  /// Check if a user can send messages to another user
  /// 
  /// This checks if they are friends and not blocked
  Future<bool> canSendMessage(String senderId, String receiverId) async {
    // First, check if they are friends
    final areFriends = await checkIfFriends(senderId, receiverId);
    
    if (!areFriends) {
      return false;
    }
    
    // Then check if either has blocked the other
    final isSenderBlockedByReceiver = await isUserBlockedBy(receiverId, senderId);
    final isReceiverBlockedBySender = await isUserBlockedBy(senderId, receiverId);
    
    return !isSenderBlockedByReceiver && !isReceiverBlockedBySender;
  }
  
  /// Get a list of users who can be messaged (friends who haven't blocked the user)
  Future<List<String>> getMessagingEnabledFriends(String userId) async {
    // Get all friends using our new repository method
    final friends = await getFriendsFor(userId);
    
    // Filter out those who have blocked the user
    final result = <String>[];
    
    for (final friendId in friends) {
      final isBlocked = await isUserBlockedBy(friendId, userId);
      if (!isBlocked) {
        result.add(friendId);
      }
    }
    
    return result;
  }
}

/// Extension methods for MessageRepository that provide friend-related functionality
extension MessageRepositoryFriendExtension on MessageRepository {
  /// Filter conversations to only those with friends
  /// 
  /// [userId] is the current user's ID
  /// [friendRepository] is the friend repository
  /// [conversations] is the list of conversations to filter
  Future<List<ConversationModel>> filterConversationsToFriendsOnly(
    String userId,
    FriendRepository friendRepository,
    List<ConversationModel> conversations,
  ) async {
    final result = <ConversationModel>[];
    
    for (final conversation in conversations) {
      // Find the other participant (not the current user)
      final otherUserId = conversation.participantIds.firstWhere(
        (id) => id != userId,
        orElse: () => '',
      );
      
      if (otherUserId.isNotEmpty) {
        final areFriends = await friendRepository.checkIfFriends(userId, otherUserId);
        final isBlocked = await friendRepository.isUserBlockedBy(userId, otherUserId);
        final isBlockedBy = await friendRepository.isUserBlockedBy(otherUserId, userId);
        
        // Only include conversations with friends who aren't blocked in either direction
        if (areFriends && !isBlocked && !isBlockedBy) {
          result.add(conversation);
        }
      }
    }
    
    return result;
  }
}
