import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for friendship relationships between users
class FriendshipModel {
  final String id;
  final List<String> participants;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? initiatorId;
  final DateTime? acceptedAt;
  
  // Cached profile data for quick access
  final Map<String, CachedProfile> cachedProfiles;

  const FriendshipModel({
    required this.id,
    required this.participants,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.initiatorId,
    this.acceptedAt,
    this.cachedProfiles = const {},
  });

  factory FriendshipModel.fromMap(Map<String, dynamic> map, String id) {
    return FriendshipModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      status: FriendshipStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FriendshipStatus.pending,
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

  FriendshipModel copyWith({
    String? id,
    List<String>? participants,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? initiatorId,
    DateTime? acceptedAt,
    Map<String, CachedProfile>? cachedProfiles,
  }) {
    return FriendshipModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
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
}

/// Cached profile data stored in friendship documents
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

enum FriendshipStatus {
  pending,
  accepted,
  blocked,
  declined,
}
