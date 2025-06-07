/// Interface for relationship service operations
abstract class RelationshipServiceInterface {
  /// Send a friend request to another user
  /// Returns the relationship ID if successful
  Future<String> sendFriendRequest(String targetUserId);
  
  /// Accept a pending friend request
  /// Returns the relationship ID if successful
  Future<String> acceptFriendRequest(String relationshipId);
  
  /// Reject/decline a pending friend request
  /// Returns true if successful
  Future<bool> rejectFriendRequest(String relationshipId);
  
  /// Cancel a sent friend request
  /// Returns true if successful
  Future<bool> cancelFriendRequest(String relationshipId);
  
  /// Remove an existing friend
  /// Returns true if successful
  Future<bool> removeFriend(String targetUserId);
  
  /// Block a user
  /// Returns the relationship ID if successful
  Future<String> blockUser(String targetUserId);
  
  /// Unblock a user
  /// Returns true if successful
  Future<bool> unblockUser(String targetUserId);
  
  /// Get real-time stream of friends list (accepted relationships)
  /// Returns stream of relationship data (uid, relationshipId) without user profiles
  Stream<List<Map<String, dynamic>>> getFriendsStream();
  
  /// Get real-time stream of pending friend requests (received)
  /// Returns stream of relationship data (uid, relationshipId, isIncoming, initiatorId) without user profiles
  Stream<List<Map<String, dynamic>>> getPendingRequestsStream();

  /// Get real-time stream of blocked users
  /// Returns stream of relationship data (uid, relationshipId) without user profiles
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream();
  
  /// Search for a user by their UID directly from the users collection
  /// Returns user data if found, null if not found
  Future<Map<String, dynamic>?> searchUserByUid(String uid);
  
  /// Setup user stream subscription for a list of user IDs
  /// This method can be used to get user data streams for UIDs returned from relationship streams
  /// Returns a stream that emits a map where keys are user IDs and values are user data
  Stream<Map<String, Map<String, dynamic>>> setupUserStreamSubscription(List<String> userIds);
}
