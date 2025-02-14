import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duckbuck/Authentication/service/auth_service.dart';
import 'package:duckbuck/Home/models/bug_report_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

typedef ProgressCallback = void Function(double progress);

class BugReportService {
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB
  static const Set<String> _allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'heic'
  };
  static const Set<String> _allowedVideoExtensions = {'mp4', 'mov', 'avi'};

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  BugReportService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _auth = auth,
        _firestore = firestore,
        _storage = storage;

  Future<String> submitReport({
    required String title,
    required String description,
    required List<File> images,
    required List<File> videos,
    ProgressCallback? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('No authenticated user found');
    }

    // Validate inputs
    if (title.trim().isEmpty) {
      throw ValidationException('Title cannot be empty');
    }
    if (description.trim().isEmpty) {
      throw ValidationException('Description cannot be empty');
    }

    try {
      // Create a unique reportId for this submission
      final String reportId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload media files (images and videos)
      final imageUrls = await _uploadFiles(
        files: images,
        allowedExtensions: _allowedImageExtensions,
        basePath: 'bug_reports/${user.uid}/$reportId/images',
        fileType: 'image',
        onProgress: onProgress,
      );

      final videoUrls = await _uploadFiles(
        files: videos,
        allowedExtensions: _allowedVideoExtensions,
        basePath: 'bug_reports/${user.uid}/$reportId/videos',
        fileType: 'video',
        onProgress: onProgress,
      );

      // Create the bug report data
      final reportData = BugReport(
        id: reportId,
        userId: user.uid,
        title: title.trim(),
        description: description.trim(),
        imageUrls: imageUrls,
        videoUrls: videoUrls,
        status: BugReportStatus.pending.toString().split('.').last,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save the bug report document in Firestore under bugReports/{userId}/reports/{reportId}
      final bugReportRef = _firestore
          .collection('bugReports')
          .doc(user.uid)
          .collection('reports')
          .doc(reportId);

      await bugReportRef.set(reportData.toJson());

      return reportId; // Return the reportId to confirm the report has been submitted
    } catch (e) {
      throw BugReportException(
        'Failed to submit bug report: ${e.toString()}',
        originalError: e,
      );
    }
  }

  Future<List<String>> _uploadFiles({
    required List<File> files,
    required Set<String> allowedExtensions,
    required String basePath,
    required String fileType,
    ProgressCallback? onProgress,
  }) async {
    final urls = <String>[];
    int totalBytes = 0;
    int uploadedBytes = 0;

    // Calculate total size
    for (final file in files) {
      totalBytes += await file.length();
    }

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileSize = await file.length();

      // Validate file size
      if (fileSize > _maxFileSize) {
        throw ValidationException(
            'File ${file.path} exceeds maximum size of ${_maxFileSize ~/ 1024 ~/ 1024}MB');
      }

      final fileExtension = file.path.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(fileExtension)) {
        throw ValidationException(
            'Invalid $fileType format. Allowed: ${allowedExtensions.join(", ")}');
      }

      final fileName =
          '$basePath/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExtension';
      final url = await _uploadSingleFile(
        file: file,
        fileName: fileName,
        fileExtension: fileExtension,
        onProgress: (progress) {
          if (onProgress != null) {
            final currentProgress =
                (uploadedBytes + (fileSize * progress)) / totalBytes;
            onProgress(currentProgress);
          }
        },
      );

      uploadedBytes += fileSize;
      urls.add(url);
    }

    return urls;
  }

  Future<String> _uploadSingleFile({
    required File file,
    required String fileName,
    required String fileExtension,
    required ProgressCallback onProgress,
  }) async {
    try {
      // Get the user's authentication token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw AuthException('User is not authenticated');
      }


      final metadata = SettableMetadata(
        contentType: _getContentType(fileExtension),
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = _storage.ref().child(fileName).putFile(file, metadata);

      // Optionally, you can add custom headers with the token if needed:

      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw StorageException('Failed to upload file: ${file.path}',
          originalError: e);
    }
  }

  String _getContentType(String fileExtension) {
    if (fileExtension == 'heic') return 'image/heic';
    if (_allowedImageExtensions.contains(fileExtension))
      return 'image/$fileExtension';
    if (_allowedVideoExtensions.contains(fileExtension))
      return 'video/$fileExtension';
    throw ValidationException('Unsupported file type: $fileExtension');
  }
}

// Custom exceptions (keep these if not already defined in your auth_service.dart)
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

class StorageException implements Exception {
  final String message;
  final Object? originalError;
  StorageException(this.message, {this.originalError});
  @override
  String toString() => message;
}

class BugReportException implements Exception {
  final String message;
  final Object? originalError;
  BugReportException(this.message, {this.originalError});
  @override
  String toString() => message;
}
