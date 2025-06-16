/// Model representing the AI agent response from backend
class AiAgentResponse {
  final bool success;
  final String message;
  final AiAgentData? data;

  AiAgentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory AiAgentResponse.fromJson(Map<String, dynamic> json) {
    return AiAgentResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: json['data'] != null 
          ? AiAgentData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data!.toJson(),
    };
  }
}

/// Model representing AI agent data
class AiAgentData {
  final String agentId;
  final String agentName;
  final String channelName;
  final String status;
  final int createTs;

  AiAgentData({
    required this.agentId,
    required this.agentName,
    required this.channelName,
    required this.status,
    required this.createTs,
  });

  factory AiAgentData.fromJson(Map<String, dynamic> json) {
    return AiAgentData(
      agentId: json['agent_id'] as String,
      agentName: json['agent_name'] as String,
      channelName: json['channel_name'] as String,
      status: json['status'] as String,
      createTs: json['create_ts'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_id': agentId,
      'agent_name': agentName,
      'channel_name': channelName,
      'status': status,
      'create_ts': createTs,
    };
  }

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createTs);

  /// Check if agent is currently running
  bool get isRunning => status.toLowerCase() == 'started';
}

/// Current state of AI agent
enum AiAgentState {
  idle,
  starting,
  running,
  stopping,
  error,
}

/// Model representing current AI agent session
class AiAgentSession {
  final AiAgentData agentData;
  final DateTime startTime;
  final String uid;

  AiAgentSession({
    required this.agentData,
    required this.startTime,
    required this.uid,
  });

  /// Get elapsed time since agent started
  Duration get elapsedTime => DateTime.now().difference(startTime);

  /// Get elapsed time in seconds
  int get elapsedSeconds => elapsedTime.inSeconds;
}
