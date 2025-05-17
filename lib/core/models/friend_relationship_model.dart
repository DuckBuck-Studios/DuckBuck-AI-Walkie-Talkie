import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the current relationship status between two users
enum RelationshipStatus {
  /// No relationship established yet
  none,
  
  /// A friend request has been sent and is pending
  pending,
  
  /// Users are friends
  friends,
  
  /// One user has blocked the other
  blocked,
}

/// Direction of the relationship action
enum RelationshipDirection {
  /// Action initiated by the first user (user1 -> user2)
  fromFirst,
  
  /// Action initiated by the second user (user2 -> user1)
  fromSecond,
  
  /// Action is mutual or system-initiated
  mutual,
}

/// Model representing the relationship between two users in the application
class FriendRelationshipModel {
  /// Unique ID for the relationship document
  final String id;
  
  /// First user ID in the relationship (lexicographically smaller)
  final String user1Id;
  
  /// Second user ID in the relationship (lexicographically larger)
  final String user2Id;
  
  /// Current status of the relationship
  final RelationshipStatus status;
  
  /// Direction of the current relationship status (who initiated it)
  final RelationshipDirection direction;
  
  /// When the relationship was first created
  final DateTime createdAt;
  
  /// When the relationship was last updated
  final DateTime updatedAt;
  
  /// User who is blocked (if status is 'blocked')
  final String? blockedUserId;
  
  /// User who initiated the block (if status is 'blocked')
  final String? blockedByUserId;
  
  /// History of previous relationship states
  final List<Map<String, dynamic>> history;

  /// Creates a new FriendRelationshipModel instance
  FriendRelationshipModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.status,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
    this.blockedUserId,
    this.blockedByUserId,
    required this.history,
  });

  /// Create a FriendRelationshipModel from a Firestore document
  factory FriendRelationshipModel.fromMap(Map<String, dynamic> map, String id) {
    return FriendRelationshipModel(
      id: id,
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      status: _statusFromString(map['status']),
      direction: _directionFromString(map['direction']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      blockedUserId: map['blockedUserId'],
      blockedByUserId: map['blockedByUserId'],
      history: List<Map<String, dynamic>>.from(map['history'] ?? []),
    );
  }

  /// Convert relationship model to a map
  Map<String, dynamic> toMap() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      'status': status.name,
      'direction': direction.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'blockedUserId': blockedUserId,
      'blockedByUserId': blockedByUserId,
      'history': history,
    };
  }

  /// Create a copy of this relationship model with updated fields
  FriendRelationshipModel copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    RelationshipStatus? status,
    RelationshipDirection? direction,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? blockedUserId,
    String? blockedByUserId,
    List<Map<String, dynamic>>? history,
  }) {
    return FriendRelationshipModel(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      status: status ?? this.status,
      direction: direction ?? this.direction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      blockedUserId: blockedUserId ?? this.blockedUserId,
      blockedByUserId: blockedByUserId ?? this.blockedByUserId,
      history: history ?? this.history,
    );
  }
  
  /// Add an entry to the history of this relationship
  FriendRelationshipModel addHistoryEntry({
    required RelationshipStatus previousStatus,
    required String actionByUserId,
    String? note,
  }) {
    final historyEntry = {
      'previousStatus': previousStatus.name,
      'newStatus': status.name,
      'timestamp': FieldValue.serverTimestamp(),
      'actionByUserId': actionByUserId,
      'note': note,
    };
    
    final updatedHistory = [...history, historyEntry];
    
    return copyWith(
      history: updatedHistory,
    );
  }

  /// Helper method to convert string to RelationshipStatus
  static RelationshipStatus _statusFromString(String? status) {
    switch (status) {
      case 'friends':
        return RelationshipStatus.friends;
      case 'pending':
        return RelationshipStatus.pending;
      case 'blocked':
        return RelationshipStatus.blocked;
      case 'none':
      default:
        return RelationshipStatus.none;
    }
  }

  /// Helper method to convert string to RelationshipDirection
  static RelationshipDirection _directionFromString(String? direction) {
    switch (direction) {
      case 'fromFirst':
        return RelationshipDirection.fromFirst;
      case 'fromSecond':
        return RelationshipDirection.fromSecond;
      case 'mutual':
      default:
        return RelationshipDirection.mutual;
    }
  }
}
