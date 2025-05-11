import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of messages supported by the messaging system
enum MessageType {
  /// Plain text message
  text,
  
  /// Photo/image message
  photo,
  
  /// Video message
  video,
  
  /// Voice note/audio message
  voice,
}

/// Status of message delivery
enum MessageStatus {
  /// Message has been sent but not delivered to recipient
  sent,
  
  /// Message has been delivered to recipient's device
  delivered,
  
  /// Message has been read by recipient
  read,
  
  /// Failed to send message
  failed,
}

/// Model representing a message in the chat system
class MessageModel {
  /// Unique ID for the message
  final String id;
  
  /// ID of the conversation this message belongs to
  final String conversationId;
  
  /// ID of the sender user
  final String senderId;
  
  /// ID of the recipient user
  final String receiverId;
  
  /// Content of the message (text content or file URL)
  final String content;
  
  /// Type of message (text, photo, video, voice)
  final MessageType type;
  
  /// Status of the message (sent, delivered, read, failed)
  final MessageStatus status;
  
  /// When the message was created
  final DateTime createdAt;
  
  /// When the message was read by recipient (null if not read)
  final DateTime? readAt;
  
  /// If this message has been deleted
  final bool isDeleted;
  
  /// Reference to media file path in storage (for non-text messages)
  final String? mediaPath;
  
  /// Additional metadata for media (like duration for voice, dimensions for images)
  final Map<String, dynamic>? metadata;

  /// Creates a new MessageModel instance
  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.status,
    required this.createdAt,
    this.readAt,
    this.isDeleted = false,
    this.mediaPath,
    this.metadata,
  });

  /// Create a MessageModel from a map
  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      conversationId: map['conversationId'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      content: map['content'],
      type: _typeFromString(map['type']),
      status: _statusFromString(map['status']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      readAt: map['readAt'] != null ? (map['readAt'] as Timestamp).toDate() : null,
      isDeleted: map['isDeleted'] ?? false,
      mediaPath: map['mediaPath'],
      metadata: map['metadata'],
    );
  }

  /// Convert message model to a map
  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.name,
      'status': status.name,
      'createdAt': createdAt,
      'readAt': readAt,
      'isDeleted': isDeleted,
      'mediaPath': mediaPath,
      'metadata': metadata,
    };
  }

  /// Create a copy of this message model with updated fields
  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isDeleted,
    String? mediaPath,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isDeleted: isDeleted ?? this.isDeleted,
      mediaPath: mediaPath ?? this.mediaPath,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Helper method to convert string to MessageType
  static MessageType _typeFromString(String type) {
    switch (type) {
      case 'photo':
        return MessageType.photo;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  /// Helper method to convert string to MessageStatus
  static MessageStatus _statusFromString(String status) {
    switch (status) {
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }
}

/// Model representing a conversation between two users
class ConversationModel {
  /// Unique ID for the conversation
  final String id;
  
  /// IDs of the participants in the conversation
  final List<String> participantIds;
  
  /// ID of the last message in the conversation
  final String? lastMessageId;
  
  /// Content preview of the last message
  final String? lastMessagePreview;
  
  /// Type of the last message
  final MessageType? lastMessageType;
  
  /// Timestamp of the last message
  final DateTime? lastMessageTimestamp;
  
  /// Count of unread messages for each participant (userId -> unreadCount)
  final Map<String, int> unreadCounts;
  
  /// When the conversation was created
  final DateTime createdAt;
  
  /// When the conversation was last updated
  final DateTime lastUpdatedAt;

  /// Creates a new ConversationModel instance
  ConversationModel({
    required this.id,
    required this.participantIds,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastMessageType,
    this.lastMessageTimestamp,
    required this.unreadCounts,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  /// Create a ConversationModel from a map
  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, int> unreadCountsMap = {};
    if (map['unreadCounts'] != null) {
      (map['unreadCounts'] as Map<String, dynamic>).forEach((key, value) {
        unreadCountsMap[key] = value as int;
      });
    }

    return ConversationModel(
      id: id,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      lastMessageId: map['lastMessageId'],
      lastMessagePreview: map['lastMessagePreview'],
      lastMessageType: map['lastMessageType'] != null ? 
          MessageModel._typeFromString(map['lastMessageType']) : null,
      lastMessageTimestamp: map['lastMessageTimestamp'] != null ? 
          (map['lastMessageTimestamp'] as Timestamp).toDate() : null,
      unreadCounts: unreadCountsMap,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUpdatedAt: (map['lastUpdatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert conversation model to a map
  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'lastMessageId': lastMessageId,
      'lastMessagePreview': lastMessagePreview,
      'lastMessageType': lastMessageType?.name,
      'lastMessageTimestamp': lastMessageTimestamp,
      'unreadCounts': unreadCounts,
      'createdAt': createdAt,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }

  /// Create a copy of this conversation model with updated fields
  ConversationModel copyWith({
    String? id,
    List<String>? participantIds,
    String? lastMessageId,
    String? lastMessagePreview,
    MessageType? lastMessageType,
    DateTime? lastMessageTimestamp,
    Map<String, int>? unreadCounts,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
