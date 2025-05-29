import '../../models/relationship_model.dart';

/// Pagination result for relationship queries
class PaginatedRelationshipResult {
  final List<RelationshipModel> relationships;
  final bool hasMore;
  final String? lastDocumentId;

  const PaginatedRelationshipResult({
    required this.relationships,
    required this.hasMore,
    this.lastDocumentId,
  });
}

/// Interface for relationship service operations (friendships)
abstract class RelationshipServiceInterface {
  /// Send a friend request to another user
  Future<String> sendFriendRequest(String targetUserId);
  
  /// Accept a pending friend request
  Future<void> acceptFriendRequest(String relationshipId);
  
  /// Decline a pending friend request
  Future<void> declineFriendRequest(String relationshipId);
  
  /// Cancel a sent friend request (before acceptance)
  Future<void> cancelFriendRequest(String relationshipId);
  
  /// Remove an existing friend
  Future<void> removeFriend(String relationshipId);
  
  /// Block a user (prevents future requests)
  Future<void> blockUser(String relationshipId);
  
  /// Unblock a user
  Future<void> unblockUser(String relationshipId);
  
  /// Get all accepted friendships for a user with pagination support
  Future<PaginatedRelationshipResult> getFriends(String userId, {int limit = 20, String? startAfter});
  
  /// Get pending friend requests (received by user) with pagination support
  Future<PaginatedRelationshipResult> getPendingRequests(String userId, {int limit = 20, String? startAfter});
  
  /// Get sent friend requests (sent by user) with pagination support
  Future<PaginatedRelationshipResult> getSentRequests(String userId, {int limit = 20, String? startAfter});
  
  /// Get blocked relationships for a user with pagination support
  Future<PaginatedRelationshipResult> getBlockedUsers(String userId, {int limit = 20, String? startAfter});

  /// Search user by UID to send friend request
  Future<Map<String, dynamic>?> searchUserByUid(String uid);
  
  /// Get relationship summary (counts of different types)
  Future<Map<String, int>> getUserRelationshipsSummary(String userId);
}
