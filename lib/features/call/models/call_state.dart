/// Unified call state model that replaces the simple CallData
/// Contains all necessary information for both initiator and receiver sides
class CallState {
  final String callerName;
  final String? callerPhotoUrl;
  final String? channelId;
  final int? uid;
  final bool isInitiator;
  final bool isActive;
  final bool isMuted;
  final bool isSpeakerOn;

  CallState({
    required this.callerName,
    this.callerPhotoUrl,
    this.channelId,
    this.uid,
    this.isInitiator = false,
    this.isActive = false,
    this.isMuted = true,
    this.isSpeakerOn = true,
  });

  factory CallState.fromMap(Map<String, dynamic> map) {
    return CallState(
      callerName: map['callerName'] ?? 'Unknown Caller',
      callerPhotoUrl: map['callerPhotoUrl'],
      channelId: map['channelId'],
      uid: map['uid'],
      isInitiator: map['isInitiator'] ?? false,
      isActive: map['isActive'] ?? false,
      isMuted: map['isMuted'] ?? true,
      isSpeakerOn: map['isSpeakerOn'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'channelId': channelId,
      'uid': uid,
      'isInitiator': isInitiator,
      'isActive': isActive,
      'isMuted': isMuted,
      'isSpeakerOn': isSpeakerOn,
    };
  }

  CallState copyWith({
    String? callerName,
    String? callerPhotoUrl,
    String? channelId,
    int? uid,
    bool? isInitiator,
    bool? isActive,
    bool? isMuted,
    bool? isSpeakerOn,
  }) {
    return CallState(
      callerName: callerName ?? this.callerName,
      callerPhotoUrl: callerPhotoUrl ?? this.callerPhotoUrl,
      channelId: channelId ?? this.channelId,
      uid: uid ?? this.uid,
      isInitiator: isInitiator ?? this.isInitiator,
      isActive: isActive ?? this.isActive,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
    );
  }
}

/// Role of the call participant
enum CallRole {
  INITIATOR,  // User who started the call
  RECEIVER    // User who received the call
}

/// UI state for call loading progression (used by initiator)
enum CallLoadingState {
  connecting,    // "📞 Connecting to your friend..." (0-5 seconds)
  waitingLong,   // "🐌 Your friend's internet is slower..." (5-10 seconds)
  failed         // "💥 Connection failed..." (10+ seconds or timeout)
}
