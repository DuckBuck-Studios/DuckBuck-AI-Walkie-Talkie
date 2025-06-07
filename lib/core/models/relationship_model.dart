import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for relationships between users (friendships only for now)
class RelationshipModel {
  final String id;
  final List<String> participants; // Always sorted for consistent querying - exactly 2 for friendships
  final RelationshipType type;
  final RelationshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? initiatorId;
  final DateTime? acceptedAt; 

  const RelationshipModel({
    required this.id,
    required this.participants,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.initiatorId,
    this.acceptedAt, 
  });

  factory RelationshipModel.fromMap(Map<String, dynamic> map, String id) {
    return RelationshipModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      type: RelationshipType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RelationshipType.friendship,
      ),
      status: RelationshipStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RelationshipStatus.pending,
      ),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      initiatorId: map['initiatorId'], 
      acceptedAt: _parseDateTime(map['acceptedAt']),
    );
  }

  /// Helper method to parse DateTime from either Timestamp or String
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'type': type.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'initiatorId': initiatorId,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null, 
    };
  }

  RelationshipModel copyWith({
    String? id,
    List<String>? participants,
    RelationshipType? type,
    RelationshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? initiatorId,
    DateTime? acceptedAt, 
  }) {
    return RelationshipModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      initiatorId: initiatorId ?? this.initiatorId,
      acceptedAt: acceptedAt ?? this.acceptedAt, 
    );
  }

  /// Get the friend's ID (the other participant)
  String getFriendId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  /// Check if relationship is a friendship
  bool get isFriendship => type == RelationshipType.friendship;

  /// Helper to create a sorted participants list
  static List<String> sortParticipants(List<String> participants) {
    final sorted = List<String>.from(participants);
    sorted.sort();
    return sorted;
  }
}

/// Type of relationship (friendship only for now)
enum RelationshipType {
  friendship,
  // Future types can be added here (e.g., group, business, family, etc.)
}

/// Status of the relationship
enum RelationshipStatus {
  pending,    // Invitation sent but not accepted
  accepted,   // Active relationship
  blocked,    // Blocked by one party
  declined,   // Invitation declined
}
