import 'package:cloud_firestore/cloud_firestore.dart';

enum BugReportStatus { pending, inProgress, resolved, closed }
class BugReport {
  final String id;
  final String userId;
  final String title;
  final String description;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  BugReport({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.videoUrls,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a BugReport from a JSON map
  factory BugReport.fromJson(Map<String, dynamic> json) {
    return BugReport(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      videoUrls: List<String>.from(json['videoUrls'] ?? []),
      status: json['status'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Optional: Convert BugReport to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
