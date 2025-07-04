import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';

/// Service for handling Firebase Storage operations
class FirebaseStorageService {
  final FirebaseStorage _storage;
  final LoggerService _logger;
  
  static const String _tag = 'FIREBASE_STORAGE_SERVICE';

  /// Creates a new FirebaseStorageService instance
  FirebaseStorageService({
    FirebaseStorage? storage,
    LoggerService? logger,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _logger = logger ?? serviceLocator<LoggerService>();

  /// Upload a file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadFile({
    required String path,
    required File file,
    Map<String, String>? metadata,
  }) async {
    try {
      _logger.d(_tag, 'Uploading file to path: $path');
      final ref = _storage.ref().child(path);

      final UploadTask task = ref.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(file.path),
          customMetadata: metadata,
        ),
      );

      final snapshot = await task;
      final downloadURL = await snapshot.ref.getDownloadURL();
      _logger.i(_tag, 'File uploaded successfully to: $path');
      return downloadURL;
    } catch (e) {
      _logger.e(_tag, 'Failed to upload file: ${e.toString()}');
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
      _logger.d(_tag, 'Uploading bytes to path: $path');
      final ref = _storage.ref().child(path);

      final UploadTask task = ref.putData(
        bytes,
        SettableMetadata(contentType: contentType, customMetadata: metadata),
      );

      final snapshot = await task;
      final downloadURL = await snapshot.ref.getDownloadURL();
      _logger.i(_tag, 'Bytes uploaded successfully to: $path');
      return downloadURL;
    } catch (e) {
      _logger.e(_tag, 'Failed to upload bytes: ${e.toString()}');
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
      _logger.d(_tag, 'Downloading bytes from path: $path');
      final ref = _storage.ref().child(path);
      final data = await ref.getData() ?? Uint8List(0);
      _logger.i(_tag, 'Downloaded ${data.length} bytes from: $path');
      return data;
    } catch (e) {
      _logger.e(_tag, 'Failed to download file: ${e.toString()}');
      throw Exception('Failed to download file: ${e.toString()}');
    }
  }

  /// Get the download URL for a file
  Future<String> getDownloadURL(String path) async {
    try {
      _logger.d(_tag, 'Getting download URL for path: $path');
      final ref = _storage.ref().child(path);
      final url = await ref.getDownloadURL();
      _logger.i(_tag, 'Retrieved download URL for: $path');
      return url;
    } catch (e) {
      _logger.e(_tag, 'Failed to get download URL: ${e.toString()}');
      throw Exception('Failed to get download URL: ${e.toString()}');
    }
  }

  /// Delete a file from Firebase Storage
  Future<void> deleteFile(String path) async {
    try {
      _logger.d(_tag, 'Deleting file at path: $path');
      final ref = _storage.ref().child(path);
      await ref.delete();
      _logger.i(_tag, 'File deleted successfully: $path');
    } catch (e) {
      _logger.e(_tag, 'Failed to delete file: ${e.toString()}');
      throw Exception('Failed to delete file: ${e.toString()}');
    }
  }

  /// Get list of files in a directory
  Future<List<Reference>> listFiles(String path) async {
    try {
      _logger.d(_tag, 'Listing files in path: $path');
      final ref = _storage.ref().child(path);
      final result = await ref.listAll();
      _logger.i(_tag, 'Found ${result.items.length} files in: $path');
      return result.items;
    } catch (e) {
      _logger.e(_tag, 'Failed to list files: ${e.toString()}');
      throw Exception('Failed to list files: ${e.toString()}');
    }
  }

  /// Get metadata for a file
  Future<FullMetadata> getMetadata(String path) async {
    try {
      _logger.d(_tag, 'Getting metadata for path: $path');
      final ref = _storage.ref().child(path);
      final metadata = await ref.getMetadata();
      _logger.i(_tag, 'Retrieved metadata for: $path');
      return metadata;
    } catch (e) {
      _logger.e(_tag, 'Failed to get metadata: ${e.toString()}');
      throw Exception('Failed to get metadata: ${e.toString()}');
    }
  }

  /// Update metadata for a file
  Future<FullMetadata> updateMetadata(
    String path,
    Map<String, String> customMetadata,
  ) async {
    try {
      _logger.d(_tag, 'Updating metadata for path: $path');
      final ref = _storage.ref().child(path);
      final metadata = await ref.updateMetadata(
        SettableMetadata(customMetadata: customMetadata),
      );
      _logger.i(_tag, 'Updated metadata for: $path');
      return metadata;
    } catch (e) {
      _logger.e(_tag, 'Failed to update metadata: ${e.toString()}');
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
      final path = 'users/$userId/profile/$timestamp.jpg';
      
      _logger.i(_tag, 'Uploading profile image for user: $userId');

      final downloadURL = await uploadFile(
        path: path,
        file: imageFile,
        metadata: {
          'userId': userId,
          'uploadTime': timestamp.toString(),
          'type': 'profile_image',
        },
      );
      
      _logger.i(_tag, 'Profile image uploaded successfully for user: $userId');
      return downloadURL;
    } catch (e) {
      _logger.e(_tag, 'Failed to upload profile image for user $userId: ${e.toString()}');
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
