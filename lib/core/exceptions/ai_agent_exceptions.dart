/// Custom exception for AI agent-related errors
class AiAgentException implements Exception {
  /// Error code for categorizing the error
  final String code;
  
  /// Human-readable message
  final String message;
  
  /// Optional stack trace or original error for debugging
  final dynamic originalError;
  
  /// The AI agent operation that was being performed when the exception occurred
  final AiAgentOperation? operation;
  
  /// Creates a new AI agent exception
  AiAgentException(this.code, this.message, [this.originalError, this.operation]);
  
  @override
  String toString() => 'AiAgentException($code, ${operation?.name ?? 'unknown'}): $message';
}

/// AI agent operations that can fail
enum AiAgentOperation {
  join,
  stop,
  updateTime,
  checkTime,
  streamTime
}

/// Error codes for AI agent-related operations
class AiAgentErrorCodes {
  // General errors
  static const String unknown = 'ai-agent/unknown';
  static const String networkError = 'ai-agent/network-error';
  static const String databaseError = 'ai-agent/database-error';
  static const String invalidParameters = 'ai-agent/invalid-parameters';
  
  // Agent operation errors
  static const String joinFailed = 'ai-agent/join-failed';
  static const String stopFailed = 'ai-agent/stop-failed';
  static const String agentNotFound = 'ai-agent/not-found';
  static const String agentAlreadyRunning = 'ai-agent/already-running';
  
  // Time management errors
  static const String insufficientTime = 'ai-agent/insufficient-time';
  static const String timeUpdateFailed = 'ai-agent/time-update-failed';
  static const String timeCheckFailed = 'ai-agent/time-check-failed';
  static const String invalidTimeValue = 'ai-agent/invalid-time-value';
  
  // User-related errors
  static const String userNotFound = 'ai-agent/user-not-found';
  static const String userNotAuthenticated = 'ai-agent/user-not-authenticated';
  static const String accessDenied = 'ai-agent/access-denied';
  
  // Stream and real-time errors
  static const String streamError = 'ai-agent/stream-error';
  static const String streamSubscriptionFailed = 'ai-agent/stream-subscription-failed';
  static const String realtimeUpdateFailed = 'ai-agent/realtime-update-failed';
  
  // Circuit breaker and rate limiting
  static const String circuitBreakerOpen = 'ai-agent/circuit-breaker-open';
  static const String rateLimitExceeded = 'ai-agent/rate-limit-exceeded';
  static const String serviceUnavailable = 'ai-agent/service-unavailable';
}

/// Helper methods for creating common AI agent exceptions
class AiAgentExceptions {
  /// Creates an exception for insufficient time
  static AiAgentException insufficientTime(int remainingSeconds) {
    return AiAgentException(
      AiAgentErrorCodes.insufficientTime,
      'Insufficient AI agent time remaining: ${remainingSeconds}s',
      null,
      AiAgentOperation.checkTime,
    );
  }
  
  /// Creates an exception for join failure
  static AiAgentException joinFailed(String reason, [dynamic originalError]) {
    return AiAgentException(
      AiAgentErrorCodes.joinFailed,
      'Failed to join AI agent: $reason',
      originalError,
      AiAgentOperation.join,
    );
  }
  
  /// Creates an exception for stop failure
  static AiAgentException stopFailed(String agentId, [dynamic originalError]) {
    return AiAgentException(
      AiAgentErrorCodes.stopFailed,
      'Failed to stop AI agent: $agentId',
      originalError,
      AiAgentOperation.stop,
    );
  }
  
  /// Creates an exception for time update failure
  static AiAgentException timeUpdateFailed(String uid, [dynamic originalError]) {
    return AiAgentException(
      AiAgentErrorCodes.timeUpdateFailed,
      'Failed to update AI agent time for user: $uid',
      originalError,
      AiAgentOperation.updateTime,
    );
  }
  
  /// Creates an exception for user not found
  static AiAgentException userNotFound(String uid) {
    return AiAgentException(
      AiAgentErrorCodes.userNotFound,
      'User not found: $uid',
      null,
      AiAgentOperation.checkTime,
    );
  }
  
  /// Creates an exception for stream errors
  static AiAgentException streamError(String reason, [dynamic originalError]) {
    return AiAgentException(
      AiAgentErrorCodes.streamError,
      'AI agent stream error: $reason',
      originalError,
      AiAgentOperation.streamTime,
    );
  }
  
  /// Creates an exception for network errors
  static AiAgentException networkError([dynamic originalError]) {
    return AiAgentException(
      AiAgentErrorCodes.networkError,
      'Network error occurred during AI agent operation',
      originalError,
    );
  }
  
  /// Creates an exception for database errors
  static AiAgentException databaseError(String operation, [dynamic originalError]) {
    return AiAgentException(
      AiAgentErrorCodes.databaseError,
      'Database error during $operation',
      originalError,
    );
  }
}
