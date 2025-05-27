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
  
  // Cached profile data for quick access
  final Map<String, CachedProfile> cachedProfiles;

  const RelationshipModel({
    required this.id,
    required this.participants,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.initiatorId,
    this.acceptedAt,
    this.cachedProfiles = const {},
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
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      initiatorId: map['initiatorId'],
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      cachedProfiles: Map<String, CachedProfile>.from(
        (map['cachedProfiles'] ?? {}).map(
          (key, value) => MapEntry(key, CachedProfile.fromMap(value)),
        ),
      ),
    );
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
      'cachedProfiles': cachedProfiles.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
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
    Map<String, CachedProfile>? cachedProfiles,
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
      cachedProfiles: cachedProfiles ?? this.cachedProfiles,
    );
  }

  /// Get the friend's ID (the other participant)
  String getFriendId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  /// Get cached profile for a user
  CachedProfile? getCachedProfile(String userId) {
    return cachedProfiles[userId];
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

/// Cached profile data stored in relationship documents
class CachedProfile {
  final String displayName;
  final String? photoURL;
  final DateTime lastUpdated;

  const CachedProfile({
    required this.displayName,
    this.photoURL,
    required this.lastUpdated,
  });

  factory CachedProfile.fromMap(Map<String, dynamic> map) {
    return CachedProfile(
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  CachedProfile copyWith({
    String? displayName,
    String? photoURL,
    DateTime? lastUpdated,
  }) {
    return CachedProfile(
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
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
