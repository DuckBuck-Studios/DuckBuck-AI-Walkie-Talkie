/// Interface for AI agent service operations
abstract class AiAgentServiceInterface {
  /// Join AI agent to a channel with Agora setup
  /// Handles token generation, channel joining, and AI agent connection
  /// Returns the agent response data if successful, null otherwise
  Future<Map<String, dynamic>?> joinAgentWithAgoraSetup({
    required String uid,
  });
  
  /// Stop AI agent and leave Agora channel
  /// Returns true if successful, false otherwise
  Future<bool> stopAgentAndLeaveChannel();
  
  /// Toggle microphone on/off
  /// Returns true if successful, false otherwise
  Future<bool> toggleMicrophone();
  
  /// Toggle speaker on/off
  /// Returns true if successful, false otherwise
  Future<bool> toggleSpeaker();
  
  /// Get current microphone status
  bool isMicrophoneMuted();
  
  /// Get current speaker status
  bool isSpeakerEnabled();

  /// Get current microphone status (async)
  Future<bool> isMicrophoneMutedAsync();
  
  /// Get current speaker status (async)
  Future<bool> isSpeakerEnabledAsync();
  
  /// Join AI agent to a channel (backend only)
  /// Returns the agent response data if successful, null if user has no remaining time
  /// Throws exception on failure
  Future<Map<String, dynamic>?> joinAgent({
    required String uid,
    required String channelName,
    required int remainingTimeSeconds,
  });
  
  /// Stop AI agent (backend only)
  /// Returns true if successful, false otherwise
  Future<bool> stopAgent({
    required String agentId,
  });
  
  /// Check if user has remaining AI agent time
  bool hasRemainingTime(int remainingTimeSeconds);
  
  /// Get formatted remaining time for display
  String formatRemainingTime(int remainingTimeSeconds);
  
  /// Get real-time stream of user's remaining AI agent time
  Stream<int> getUserRemainingTimeStream(String uid);
  
  /// Update user's remaining AI agent time in Firebase
  Future<void> updateUserAgentTime({
    required String uid,
    required int newRemainingTimeSeconds,
  });
  
  /// Decrease user's remaining AI agent time by specified amount
  Future<int> decreaseUserAgentTime({
    required String uid,
    required int timeUsedSeconds,
  });
  
  /// Increase user's remaining AI agent time by specified amount
  Future<int> increaseUserAgentTime({
    required String uid,
    required int additionalTimeSeconds,
  });
  
  /// Get user's current remaining AI agent time from Firebase
  Future<int> getUserRemainingTime(String uid);
  
  /// Reset user's AI agent time to default (1 hour)
  Future<void> resetUserAgentTime(String uid);
  
  /// Dispose all stream controllers and subscriptions
  void dispose();

  /// Join only Agora channel without backend AI agent connection
  /// Returns true if successful, false otherwise
  Future<bool> joinAgoraChannelOnly({
    required String uid,
  });
}
