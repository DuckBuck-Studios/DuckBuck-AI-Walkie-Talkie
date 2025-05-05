import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Storage operations
class FirebaseStorageService {
  final FirebaseStorage _storage;

  /// Creates a new FirebaseStorageService instance
  FirebaseStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  /// Upload a file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadFile({
    required String path,
    required File file,
    Map<String, String>? metadata,
  }) async {
    try {
      final ref = _storage.ref().child(path);

      final UploadTask task = ref.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(file.path),
          customMetadata: metadata,
        ),
      );

      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  /// Upload bytes to Firebase Storage (useful for web)
  /// Returns the download URL
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    try {
      final ref = _storage.ref().child(path);

      final UploadTask task = ref.putData(
        bytes,
        SettableMetadata(contentType: contentType, customMetadata: metadata),
      );

      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload bytes: ${e.toString()}');
    }
  }

  /// Generate a unique file path for upload
  String generateFilePath({
    required String userId,
    required String folderName,
    required String fileName,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$userId/$folderName/$timestamp-$fileName';
  }

  /// Download a file from Firebase Storage
  Future<Uint8List> downloadBytes(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getData() ?? Uint8List(0);
    } catch (e) {
      throw Exception('Failed to download file: ${e.toString()}');
    }
  }

  /// Get the download URL for a file
  Future<String> getDownloadURL(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get download URL: ${e.toString()}');
    }
  }

  /// Delete a file from Firebase Storage
  Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: ${e.toString()}');
    }
  }

  /// Get list of files in a directory
  Future<List<Reference>> listFiles(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final result = await ref.listAll();
      return result.items;
    } catch (e) {
      throw Exception('Failed to list files: ${e.toString()}');
    }
  }

  /// Get metadata for a file
  Future<FullMetadata> getMetadata(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getMetadata();
    } catch (e) {
      throw Exception('Failed to get metadata: ${e.toString()}');
    }
  }

  /// Update metadata for a file
  Future<FullMetadata> updateMetadata(
    String path,
    Map<String, String> customMetadata,
  ) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.updateMetadata(
        SettableMetadata(customMetadata: customMetadata),
      );
    } catch (e) {
      throw Exception('Failed to update metadata: ${e.toString()}');
    }
  }

  /// Upload a profile image for a user
  /// Returns the download URL
  Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'profile_images/$userId/$timestamp.jpg';

      return await uploadFile(
        path: path,
        file: imageFile,
        metadata: {
          'userId': userId,
          'uploadTime': timestamp.toString(),
          'type': 'profile_image',
        },
      );
    } catch (e) {
      debugPrint('Failed to upload profile image: $e');
      throw Exception('Failed to upload profile image: ${e.toString()}');
    }
  }

  /// Get content type based on file extension
  String? _getContentType(String path) {
    final ext = path.split('.').last.toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mp3';
      default:
        return null;
    }
  }
}
