/// Custom exception for relationship-related errors
class RelationshipException implements Exception {
  /// Error code for categorizing the error
  final String code;
  
  /// Human-readable message
  final String message;
  
  /// Optional stack trace or original error for debugging
  final dynamic originalError;
  
  /// The relationship operation that was being performed when the exception occurred
  final RelationshipOperation? operation;
  
  /// Creates a new relationship exception
  RelationshipException(this.code, this.message, [this.originalError, this.operation]);
  
  @override
  String toString() => 'RelationshipException($code, ${operation?.name ?? 'unknown'}): $message';
}

/// Relationship operations supported by the app
enum RelationshipOperation {
  sendRequest,
  acceptRequest,
  declineRequest,
  cancelRequest,
  removeFriend,
  blockUser,
  unblockUser,
  getFriends,
  getFriendsStream, // Added
  getPendingRequestsStream, // Added
  getSentRequestsStream, // Added
  searchFriends,
  searchUser,
  updateProfile,
}

/// Error codes for relationship-related operations
class RelationshipErrorCodes {
  // General errors
  static const String unknown = 'relationship/unknown';
  static const String networkError = 'relationship/network-error';
  static const String databaseError = 'relationship/database-error';
  static const String unauthorized = 'relationship/unauthorized';
  static const String invalidRequest = 'relationship/invalid-request';
  
  // User-related errors
  static const String userNotFound = 'relationship/user-not-found';
  static const String selfRequest = 'relationship/self-request';
  static const String notLoggedIn = 'relationship/not-logged-in';
  
  // Relationship state errors
  static const String alreadyExists = 'relationship/already-exists';
  static const String alreadyFriends = 'relationship/already-friends';
  static const String requestAlreadySent = 'relationship/request-already-sent';
  static const String requestAlreadyReceived = 'relationship/request-already-received';
  static const String notFound = 'relationship/not-found';
  static const String notPending = 'relationship/not-pending';
  static const String notAccepted = 'relationship/not-accepted';
  static const String notBlocked = 'relationship/not-blocked';
  
  // Permission errors
  static const String cannotAcceptOwnRequest = 'relationship/cannot-accept-own-request';
  static const String cannotDeclineOwnRequest = 'relationship/cannot-decline-own-request';
  static const String cannotCancelOthersRequest = 'relationship/cannot-cancel-others-request';
  static const String notParticipant = 'relationship/not-participant';
  
  // Blocking errors
  static const String blocked = 'relationship/blocked';
  static const String blockedByUser = 'relationship/blocked-by-user';
  static const String blockedUser = 'relationship/blocked-user';
  
  // Cache errors
  static const String cacheUpdateFailed = 'relationship/cache-update-failed';
  static const String profileRefreshFailed = 'relationship/profile-refresh-failed';
}

/// Helper to get user-friendly messages from error codes
class RelationshipErrorMessages {
  static String getMessageFromCode(String code, {RelationshipOperation? operation}) {
    switch (code) {
      // General errors
      case RelationshipErrorCodes.networkError:
        return 'Network error occurred. Please check your internet connection.';
      case RelationshipErrorCodes.databaseError:
        return 'Unable to access relationship data. Please try again.';
      case RelationshipErrorCodes.unauthorized:
        return 'You are not authorized to perform this action.';
      case RelationshipErrorCodes.invalidRequest:
        return 'Invalid request. Please check your input and try again.';
        
      // User-related errors
      case RelationshipErrorCodes.userNotFound:
        return 'User not found.';
      case RelationshipErrorCodes.selfRequest:
        return 'You cannot send a friend request to yourself.';
      case RelationshipErrorCodes.notLoggedIn:
        return 'You must be logged in to perform this action.';
        
      // Relationship state errors
      case RelationshipErrorCodes.alreadyExists:
        return 'A relationship already exists with this user.';
      case RelationshipErrorCodes.alreadyFriends:
        return 'You are already friends with this user.';
      case RelationshipErrorCodes.requestAlreadySent:
        return 'Friend request already sent to this user.';
      case RelationshipErrorCodes.requestAlreadyReceived:
        return 'You already have a pending friend request from this user.';
      case RelationshipErrorCodes.notFound:
        return 'Relationship not found.';
      case RelationshipErrorCodes.notPending:
        return 'Friend request is not pending.';
      case RelationshipErrorCodes.notAccepted:
        return 'Friendship is not accepted.';
      case RelationshipErrorCodes.notBlocked:
        return 'User is not blocked.';
        
      // Permission errors
      case RelationshipErrorCodes.cannotAcceptOwnRequest:
        return 'You cannot accept your own friend request.';
      case RelationshipErrorCodes.cannotDeclineOwnRequest:
        return 'You cannot decline your own friend request.';
      case RelationshipErrorCodes.cannotCancelOthersRequest:
        return 'You can only cancel your own friend requests.';
      case RelationshipErrorCodes.notParticipant:
        return 'You are not a participant in this relationship.';
        
      // Blocking errors
      case RelationshipErrorCodes.blocked:
        return 'Cannot perform action on blocked user.';
      case RelationshipErrorCodes.blockedByUser:
        return 'You have been blocked by this user.';
      case RelationshipErrorCodes.blockedUser:
        return 'You have blocked this user.';
        
      // Cache errors
      case RelationshipErrorCodes.cacheUpdateFailed:
        return 'Failed to update profile cache.';
      case RelationshipErrorCodes.profileRefreshFailed:
        return 'Failed to refresh profile information.';
        
      // Default fallback
      default:
        return _getOperationSpecificMessage(operation) ?? 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Get operation-specific fallback messages
  static String? _getOperationSpecificMessage(RelationshipOperation? operation) {
    switch (operation) {
      case RelationshipOperation.sendRequest:
        return 'Failed to send friend request. Please try again.';
      case RelationshipOperation.acceptRequest:
        return 'Failed to accept friend request. Please try again.';
      case RelationshipOperation.declineRequest:
        return 'Failed to decline friend request. Please try again.';
      case RelationshipOperation.cancelRequest:
        return 'Failed to cancel friend request. Please try again.';
      case RelationshipOperation.removeFriend:
        return 'Failed to remove friend. Please try again.';
      case RelationshipOperation.blockUser:
        return 'Failed to block user. Please try again.';
      case RelationshipOperation.unblockUser:
        return 'Failed to unblock user. Please try again.';
      case RelationshipOperation.getFriends:
        return 'Failed to load friends list. Please try again.';
      case RelationshipOperation.searchFriends:
        return 'Failed to search friends. Please try again.';
      case RelationshipOperation.updateProfile:
        return 'Failed to update profile information. Please try again.';
      default:
        return null;
    }
  }
  
  /// Get a user-friendly message specific to the operation
  static String getOperationSpecificMessage(RelationshipException exception) {
    if (exception.operation != null) {
      return getMessageFromCode(exception.code, operation: exception.operation);
    }
    return getMessageFromCode(exception.code);
  }
  
  /// Get an error message with operation context
  static String getContextualizedMessage(RelationshipException exception) {
    String baseMessage = getMessageFromCode(exception.code, operation: exception.operation);
    
    switch (exception.operation) {
      case RelationshipOperation.sendRequest:
        return 'Send Friend Request: $baseMessage';
      case RelationshipOperation.acceptRequest:
        return 'Accept Request: $baseMessage';
      case RelationshipOperation.declineRequest:
        return 'Decline Request: $baseMessage';
      case RelationshipOperation.cancelRequest:
        return 'Cancel Request: $baseMessage';
      case RelationshipOperation.removeFriend:
        return 'Remove Friend: $baseMessage';
      case RelationshipOperation.blockUser:
        return 'Block User: $baseMessage';
      case RelationshipOperation.unblockUser:
        return 'Unblock User: $baseMessage';
      case RelationshipOperation.getFriends:
        return 'Load Friends: $baseMessage';
      case RelationshipOperation.searchFriends:
        return 'Search Friends: $baseMessage';
      case RelationshipOperation.updateProfile:
        return 'Update Profile: $baseMessage';
      default:
        return baseMessage;
    }
  }
  
  /// Standardized error handling for relationship operations
  static RelationshipException handleError(dynamic error, {RelationshipOperation? operation}) {
    // If it's already our custom RelationshipException, just ensure operation is set
    if (error is RelationshipException) {
      if (error.operation == null && operation != null) {
        return RelationshipException(
          error.code, 
          error.message,
          error.originalError,
          operation
        );
      }
      return error;
    }
    
    // For all other errors, create a new RelationshipException
    String code = RelationshipErrorCodes.unknown;
    String message = error.toString();
    
    // Try to categorize common errors
    if (error.toString().contains('network')) {
      code = RelationshipErrorCodes.networkError;
      message = 'Network error occurred during relationship operation';
    } else if (error.toString().contains('permission') || error.toString().contains('unauthorized')) {
      code = RelationshipErrorCodes.unauthorized;
      message = 'Unauthorized to perform this relationship operation';
    } else if (error.toString().contains('not found')) {
      code = RelationshipErrorCodes.notFound;
      message = 'Relationship or user not found';
    }
    
    return RelationshipException(code, message, error, operation);
  }
}
