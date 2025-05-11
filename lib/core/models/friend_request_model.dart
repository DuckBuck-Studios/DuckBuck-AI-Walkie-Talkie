import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a friend request
enum FriendRequestStatus {
  /// Request is pending approval or rejection
  pending,
  
  /// Request was accepted
  accepted,
  
  /// Request was rejected
  rejected,
}

/// Model representing a friend request in the application
class FriendRequestModel {
  /// Unique ID for the friend request
  final String id;
  
  /// ID of the user who sent the request
  final String senderId;
  
  /// ID of the user who received the request
  final String receiverId;
  
  /// Status of the friend request
  final FriendRequestStatus status;
  
  /// When the request was created
  final DateTime createdAt;
  
  /// When the request was last updated
  final DateTime? updatedAt;

  /// Creates a new FriendRequestModel instance
  FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create a FriendRequestModel from a map
  factory FriendRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return FriendRequestModel(
      id: id,
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      status: _statusFromString(map['status']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Convert friend request model to a map
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create a copy of this friend request model with updated fields
  FriendRequestModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    FriendRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper method to convert string to FriendRequestStatus
  static FriendRequestStatus _statusFromString(String status) {
    switch (status) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      case 'pending':
      default:
        return FriendRequestStatus.pending;
    }
  }
}