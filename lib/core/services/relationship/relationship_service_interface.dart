import '../../models/relationship_model.dart';

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
  
  /// Get all accepted friendships for a user
  Future<List<RelationshipModel>> getFriends(String userId);
  
  /// Get pending friend requests (received by user)
  Future<List<RelationshipModel>> getPendingRequests(String userId);
  
  /// Get sent friend requests (sent by user)
  Future<List<RelationshipModel>> getSentRequests(String userId);
  
  /// Get blocked relationships for a user
  Future<List<RelationshipModel>> getBlockedUsers(String userId);
  
  /// Check friendship status between two users
  Future<RelationshipModel?> getFriendshipStatus(String userId, String otherUserId);
  
  /// Search within user's friends
  Future<List<RelationshipModel>> searchFriends(String userId, String query);
  
  /// Get a specific relationship by ID
  Future<RelationshipModel?> getRelationshipById(String relationshipId);
  
  /// Check if two users are friends (quick check)
  Future<bool> checkIfUsersAreFriends(String userId1, String userId2);
  
  /// Get mutual friends between two users
  Future<List<RelationshipModel>> getMutualFriends(String userId1, String userId2);
  
  /// Get total friend count for a user
  Future<int> getFriendCount(String userId);
  
  /// Get multiple relationships efficiently
  Future<List<RelationshipModel>> getMultipleRelationships(List<String> relationshipIds);
  
  /// Get relationship summary (counts of different types)
  Future<Map<String, int>> getUserRelationshipsSummary(String userId);
  
  /// Update cached profile data across all relationships
  Future<void> updateCachedProfile(String userId, String displayName, String? photoURL);
  
  /// Refresh stale cached profiles in a relationship
  Future<void> refreshCachedProfiles(String relationshipId);
}
