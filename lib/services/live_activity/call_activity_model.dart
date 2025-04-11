import 'package:flutter/foundation.dart';

/// Model representing data for a call Live Activity
///
/// This model stores all necessary information for displaying
/// a call in iOS Live Activities (Dynamic Island and Lock Screen)
@immutable
class CallActivityModel {
  /// Name of the caller
  final String callerName;

  /// Avatar URL of the caller (optional)
  final String? callerAvatar;

  /// Whether audio is muted
  final bool isAudioMuted;

  /// Call start time
  final DateTime? callStartTime;

  /// Formatted call duration (MM:SS)
  final String? callDuration;

  /// Creates a call activity model
  const CallActivityModel({
    required this.callerName,
    this.callerAvatar,
    this.isAudioMuted = false,
    this.callStartTime,
    this.callDuration,
  });

  /// Creates a copy of this model with specified attributes changed
  CallActivityModel copyWith({
    String? callerName,
    String? callerAvatar,
    bool? isAudioMuted,
    DateTime? callStartTime,
    String? callDuration,
  }) {
    return CallActivityModel(
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      callStartTime: callStartTime ?? this.callStartTime,
      callDuration: callDuration ?? this.callDuration,
    );
  }

  /// Converts model to a map for Live Activities
  Map<String, dynamic> toActivityData() {
    return {
      'callerName': callerName,
      'callDuration': callDuration ?? '00:00',
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallActivityModel &&
        other.callerName == callerName &&
        other.callerAvatar == callerAvatar &&
        other.isAudioMuted == isAudioMuted &&
        other.callStartTime == callStartTime &&
        other.callDuration == callDuration;
  }

  @override
  int get hashCode {
    return Object.hash(
      callerName,
      callerAvatar,
      isAudioMuted,
      callStartTime,
      callDuration,
    );
  }
} 