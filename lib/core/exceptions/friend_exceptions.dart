
/// Custom exception for friend-related errors
class FriendException implements Exception {
  /// Error code for categorizing the error
  final String code;
  
  /// Human-readable message
  final String message;
  
  /// Optional stack trace or original error for debugging
  final dynamic originalError;
  
  /// Creates a new friend exception
  FriendException(this.code, this.message, [this.originalError]);
  
  @override
  String toString() => 'FriendException($code): $message';
}

/// Error codes for friend-related operations
class FriendErrorCodes {
  // Authentication related
  static const String notLoggedIn = 'auth/not-logged-in';
  
  // Input validation
  static const String invalidReceiverId = 'invalid/receiver-id';
  static const String selfRequest = 'invalid/self-request';
  
  // Blocking related
  static const String blockedByReceiver = 'blocked/by-receiver';
  static const String blockedBySender = 'blocked/by-sender';
  
  // Relationship related
  static const String alreadyFriends = 'relationship/already-friends';
  static const String notFriends = 'relationship/not-friends';
  static const String requestNotFound = 'relationship/request-not-found';
  static const String invalidRequest = 'relationship/invalid-request';
  
  // Operation errors
  static const String requestFailed = 'friend/request-failed';
  static const String acceptFailed = 'friend/accept-failed';
  static const String rejectFailed = 'friend/reject-failed';
  static const String unfriendFailed = 'friend/unfriend-failed';
  static const String blockFailed = 'friend/block-failed';
  static const String unblockFailed = 'friend/unblock-failed';
  static const String getFriendsFailed = 'friend/get-friends-failed';
  
  // Data related
  static const String fetchFailed = 'data/fetch-failed';
  static const String userDetailsFailed = 'data/user-details-failed';
}
