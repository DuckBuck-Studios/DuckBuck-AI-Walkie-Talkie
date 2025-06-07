import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/user_model.dart';
import '../logger/logger_service.dart';

/// Service for managing local SQLite database operations
/// Handles user data caching and local storage
class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  static Database? _database;
  final LoggerService _logger = LoggerService();
  static const String _tag = 'LOCAL_DB';
  
  // Dio instance for HTTP requests
  late final Dio _dio;
  
  // Counter for periodic cleanup
  static int _saveCounter = 0;

  // Database configuration
  static const String _databaseName = 'duckbuck_local.db';
  static const int _databaseVersion = 5; // Incremented for relationship tables

  // Table names
  static const String _usersTable = 'users';
  static const String _userSessionsTable = 'user_sessions';
  static const String _appSettingsTable = 'app_settings'; // New table for app-wide settings
  static const String _friendsTable = 'cached_friends'; // Cached friends data
  static const String _pendingRequestsTable = 'cached_pending_requests'; // Cached pending requests
  static const String _blockedUsersTable = 'cached_blocked_users'; // Cached blocked users

  // Singleton pattern
  LocalDatabaseService._internal() {
    // Initialize Dio with configuration
    _dio = Dio();
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers = {'User-Agent': 'DuckBuck-App/1.0'};
  }
  
  static LocalDatabaseService get instance {
    _instance ??= LocalDatabaseService._internal();
    return _instance!;
  }

  /// Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database with tables
  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _databaseName);
      
      _logger.d(_tag, 'Initializing database at: $path');
      
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to initialize database: ${e.toString()}');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _createTables(Database db, int version) async {
    try {
      _logger.d(_tag, 'Creating database tables...');
      
      // Users table - stores essential user information only
      await db.execute('''
        CREATE TABLE $_usersTable (
          uid TEXT PRIMARY KEY,
          email TEXT,
          display_name TEXT,
          photo_url TEXT,
          photo_data TEXT,
          phone_number TEXT,
          is_logged_in INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // User sessions table - for tracking login sessions
      await db.execute('''
        CREATE TABLE $_userSessionsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uid TEXT NOT NULL,
          session_start INTEGER NOT NULL,
          session_end INTEGER,
          device_info TEXT,
          login_method TEXT,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (uid) REFERENCES $_usersTable (uid) ON DELETE CASCADE
        )
      ''');

      // App settings table - for storing application-wide preferences
      await db.execute('''
        CREATE TABLE $_appSettingsTable (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Cached friends table - for storing friend relationships data
      await db.execute('''
        CREATE TABLE $_friendsTable (
          uid TEXT NOT NULL,
          user_id TEXT NOT NULL,
          display_name TEXT,
          photo_url TEXT,
          relationship_id TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          PRIMARY KEY (uid, user_id),
          FOREIGN KEY (uid) REFERENCES $_usersTable (uid) ON DELETE CASCADE
        )
      ''');

      // Cached pending requests table - for storing pending friend requests
      await db.execute('''
        CREATE TABLE $_pendingRequestsTable (
          uid TEXT NOT NULL,
          user_id TEXT NOT NULL,
          display_name TEXT,
          photo_url TEXT,
          relationship_id TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          PRIMARY KEY (uid, user_id),
          FOREIGN KEY (uid) REFERENCES $_usersTable (uid) ON DELETE CASCADE
        )
      ''');

      // Cached blocked users table - for storing blocked users data
      await db.execute('''
        CREATE TABLE $_blockedUsersTable (
          uid TEXT NOT NULL,
          user_id TEXT NOT NULL,
          display_name TEXT,
          photo_url TEXT,
          relationship_id TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          PRIMARY KEY (uid, user_id),
          FOREIGN KEY (uid) REFERENCES $_usersTable (uid) ON DELETE CASCADE
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_users_uid ON $_usersTable (uid)');
      await db.execute('CREATE INDEX idx_users_email ON $_usersTable (email)');
      await db.execute('CREATE INDEX idx_users_phone ON $_usersTable (phone_number)');
      await db.execute('CREATE INDEX idx_users_logged_in ON $_usersTable (is_logged_in)');
      await db.execute('CREATE INDEX idx_sessions_uid ON $_userSessionsTable (uid)');
      await db.execute('CREATE INDEX idx_settings_key ON $_appSettingsTable (key)');
      await db.execute('CREATE INDEX idx_friends_uid ON $_friendsTable (uid)');
      await db.execute('CREATE INDEX idx_friends_cached_at ON $_friendsTable (cached_at)');
      await db.execute('CREATE INDEX idx_pending_uid ON $_pendingRequestsTable (uid)');
      await db.execute('CREATE INDEX idx_pending_cached_at ON $_pendingRequestsTable (cached_at)');
      await db.execute('CREATE INDEX idx_blocked_uid ON $_blockedUsersTable (uid)');
      await db.execute('CREATE INDEX idx_blocked_cached_at ON $_blockedUsersTable (cached_at)');
      
      _logger.i(_tag, 'Database tables created successfully');
    } catch (e) {
      _logger.e(_tag, 'Failed to create tables: ${e.toString()}');
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.i(_tag, 'Upgrading database from version $oldVersion to $newVersion');
    
    // Handle schema migrations
    if (oldVersion < 3) {
      // Add photo_data column for version 3
      try {
        await db.execute('ALTER TABLE $_usersTable ADD COLUMN photo_data TEXT');
        _logger.i(_tag, 'Added photo_data column for version 3');
      } catch (e) {
        _logger.w(_tag, 'Failed to add photo_data column, might already exist: ${e.toString()}');
      }
    }

    if (oldVersion < 4) {
      // Add app_settings table for version 4
      try {
        await db.execute('''
          CREATE TABLE $_appSettingsTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_settings_key ON $_appSettingsTable (key)');
        _logger.i(_tag, 'Added app_settings table for version 4');
      } catch (e) {
        _logger.w(_tag, 'Failed to add app_settings table, might already exist: ${e.toString()}');
      }
    }

    if (oldVersion < 5) {
      // Add relationship tables for version 5
      try {
        // Cached friends table
        await db.execute('''
          CREATE TABLE $_friendsTable (
            uid TEXT NOT NULL,
            user_id TEXT NOT NULL,
            display_name TEXT,
            photo_url TEXT,
            relationship_id TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            PRIMARY KEY (uid, user_id),
            FOREIGN KEY (uid) REFERENCES $_usersTable (uid) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_friends_uid ON $_friendsTable (uid)');
        await db.execute('CREATE INDEX idx_friends_cached_at ON $_friendsTable (cached_at)');

        // Cached pending requests table
        await db.execute('''
          CREATE TABLE $_pendingRequestsTable (
            uid TEXT NOT NULL,
            user_id TEXT NOT NULL,
            display_name TEXT,
            photo_url TEXT,
            relationship_id TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            PRIMARY KEY (uid, user_id),
            FOREIGN KEY (uid) REFERENCES $_usersTable (uid) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_pending_uid ON $_pendingRequestsTable (uid)');
        await db.execute('CREATE INDEX idx_pending_cached_at ON $_pendingRequestsTable (cached_at)');

        // Cached blocked users table
        await db.execute('''
          CREATE TABLE $_blockedUsersTable (
            uid TEXT NOT NULL,
            user_id TEXT NOT NULL,
            display_name TEXT,
            photo_url TEXT,
            relationship_id TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            PRIMARY KEY (uid, user_id),
            FOREIGN KEY (uid) REFERENCES $_usersTable (uid) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_blocked_uid ON $_blockedUsersTable (uid)');
        await db.execute('CREATE INDEX idx_blocked_cached_at ON $_blockedUsersTable (cached_at)');
        
        _logger.i(_tag, 'Added relationship tables for version 5');
      } catch (e) {
        _logger.w(_tag, 'Failed to add relationship tables, might already exist: ${e.toString()}');
      }
    }
  }

  /// Save user data to local database
  Future<void> saveUser(UserModel user) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      _logger.i(_tag, 'Saving user data for UID: ${user.uid}');
      
      // Download and cache photo if photoURL is available
      String? cachedPhotoPath;
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        cachedPhotoPath = await downloadAndCachePhoto(user.uid, user.photoURL);
      }
      
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'photo_data': cachedPhotoPath, // Store local file path
        'phone_number': user.phoneNumber,
        'is_logged_in': 1,
        'created_at': now,
        'updated_at': now,
      };

      await db.insert(
        _usersTable,
        userData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.i(_tag, 'User data saved for UID: ${user.uid}${cachedPhotoPath != null ? ' with cached photo' : ''}');
      
      // Periodically clean up orphaned photos (every 10th save to avoid overhead)
      _saveCounter++;
      if (_saveCounter % 10 == 0) {
        _logger.d(_tag, 'Running periodic photo cleanup (save #$_saveCounter)...');
        // Run cleanup in background to avoid blocking save operation
        cleanupOrphanedPhotos().catchError((e) {
          _logger.w(_tag, 'Background photo cleanup failed: $e');
        });
      }
    } catch (e) {
      _logger.e(_tag, 'Failed to save user: ${e.toString()}');
      rethrow;
    }
  }

  /// Get user data from local database
  Future<UserModel?> getUser(String uid) async {
    try {
      final db = await database;
      
      final results = await db.query(
        _usersTable,
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );

      if (results.isEmpty) {
        _logger.d(_tag, 'No user found with UID: $uid');
        return null;
      }

      final userData = results.first;
      return _mapToUserModel(userData);
    } catch (e) {
      _logger.e(_tag, 'Failed to get user: ${e.toString()}');
      return null;
    }
  }

  /// Get currently logged in user
  Future<UserModel?> getCurrentUser() async {
    try {
      final db = await database;
      
      final results = await db.query(
        _usersTable,
        where: 'is_logged_in = ?',
        whereArgs: [1],
        orderBy: 'updated_at DESC',
        limit: 1,
      );

      if (results.isEmpty) {
        _logger.d(_tag, 'No logged in user found');
        return null;
      }

      final userData = results.first;
      return _mapToUserModel(userData);
    } catch (e) {
      _logger.e(_tag, 'Failed to get current user: ${e.toString()}');
      return null;
    }
  }

  /// Check if any user is currently logged in (from local database)
  Future<bool> isAnyUserLoggedIn() async {
    try {
      final db = await database;
      
      final results = await db.query(
        _usersTable,
        columns: ['uid'],
        where: 'is_logged_in = ?',
        whereArgs: [1],
        limit: 1,
      );

      final isLoggedIn = results.isNotEmpty;
      _logger.d(_tag, 'Local database login check: $isLoggedIn');
      return isLoggedIn;
    } catch (e) {
      _logger.e(_tag, 'Failed to check login status: ${e.toString()}');
      return false;
    }
  }



  /// Update user login status
  Future<void> setUserLoggedIn(String uid, bool isLoggedIn) async {
    try {
      final db = await database;
      
      // First set all users to logged out
      await db.update(
        _usersTable,
        {'is_logged_in': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'is_logged_in = ?',
        whereArgs: [1],
      );

      // Then set the specific user's login status
      if (isLoggedIn) {
        await db.update(
          _usersTable,
          {
            'is_logged_in': 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'uid = ?',
          whereArgs: [uid],
        );
      }

      _logger.d(_tag, 'User login status updated for UID: $uid, isLoggedIn: $isLoggedIn');
    } catch (e) {
      _logger.e(_tag, 'Failed to update login status: ${e.toString()}');
      rethrow;
    }
  }

  /// Start a new user session
  Future<void> startUserSession(String uid, String loginMethod) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // End any existing sessions for this user
      await db.update(
        _userSessionsTable,
        {'session_end': now},
        where: 'uid = ? AND session_end IS NULL',
        whereArgs: [uid],
      );

      // Start new session
      await db.insert(_userSessionsTable, {
        'uid': uid,
        'session_start': now,
        'login_method': loginMethod,
        'created_at': now,
      });

      _logger.d(_tag, 'New session started for UID: $uid, method: $loginMethod');
    } catch (e) {
      _logger.e(_tag, 'Failed to start user session: ${e.toString()}');
    }
  }

  /// End user session
  Future<void> endUserSession(String uid) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await db.update(
        _userSessionsTable,
        {'session_end': now},
        where: 'uid = ? AND session_end IS NULL',
        whereArgs: [uid],
      );

      _logger.d(_tag, 'Session ended for UID: $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to end user session: ${e.toString()}');
    }
  }

  /// Clear all user data (sign out all users) - deletes entire database
  Future<void> clearAllUserData() async {
    try {
      final db = await database;
      
      // Clear all cached photos first
      await clearAllCachedPhotos();
      
      // Delete all data from all tables (complete wipe)
      await db.delete(_usersTable);
      await db.delete(_userSessionsTable);
      await db.delete(_appSettingsTable); // Clear app settings table
      await db.delete(_friendsTable); // Clear relationship cache
      await db.delete(_pendingRequestsTable); // Clear pending requests cache
      await db.delete(_blockedUsersTable); // Clear blocked users cache

      _logger.i(_tag, 'Entire local database and cached photos cleared');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear entire database: ${e.toString()}');
      rethrow;
    }
  }

  /// Delete specific user data - deletes entire database
  Future<void> deleteUser(String uid) async {
    try {
      final db = await database;
      
      // Clear all cached photos first
      await clearAllCachedPhotos();
      
      // Delete entire database content (all users and sessions)
      await db.delete(_usersTable);
      await db.delete(_userSessionsTable);
      await db.delete(_appSettingsTable); // Clear app settings table

      _logger.i(_tag, 'Entire database and cached photos cleared for user deletion: $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear database for user deletion: ${e.toString()}');
      rethrow;
    }
  }

  /// Get user session history
  Future<List<Map<String, dynamic>>> getUserSessions(String uid, {int? limit}) async {
    try {
      final db = await database;
      
      return await db.query(
        _userSessionsTable,
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'session_start DESC',
        limit: limit,
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to get user sessions: ${e.toString()}');
      return [];
    }
  }

  /// Convert database map to UserModel
  UserModel _mapToUserModel(Map<String, dynamic> data) {
    // Use cached photo path if available, otherwise use original photoURL
    String? photoURL = data['photo_url'];
    final cachedPhotoPath = data['photo_data'] as String?;
    
    // If we have a cached photo and the file exists, use it
    if (cachedPhotoPath != null && cachedPhotoPath.isNotEmpty) {
      final file = File(cachedPhotoPath);
      if (file.existsSync()) {
        photoURL = 'file://$cachedPhotoPath'; // Use file:// scheme for local files
        _logger.d(_tag, 'Using cached photo for user: ${data['uid']}');
      } else {
        _logger.w(_tag, 'Cached photo file does not exist: $cachedPhotoPath');
      }
    }
    
    return UserModel(
      uid: data['uid'],
      email: data['email'],
      displayName: data['display_name'],
      photoURL: photoURL,
      phoneNumber: data['phone_number'],
      isEmailVerified: false, // Not stored locally, will be fetched from Firebase when needed
      isNewUser: false, // Not stored locally, will be determined by business logic
      metadata: null, // Not stored locally
      fcmTokenData: null, // Not stored locally
    );
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.d(_tag, 'Database closed');
    }
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final db = await database;
      
      final userCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_usersTable')
      ) ?? 0;
      
      final loggedInCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_usersTable WHERE is_logged_in = 1')
      ) ?? 0;
      
      final sessionCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_userSessionsTable')
      ) ?? 0;
      
      final settingsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_appSettingsTable')
      ) ?? 0;

      return {
        'total_users': userCount,
        'logged_in_users': loggedInCount,
        'total_sessions': sessionCount,
        'app_settings': settingsCount,
        'database_version': _databaseVersion,
      };
    } catch (e) {
      _logger.e(_tag, 'Failed to get database stats: ${e.toString()}');
      return {};
    }
  }

  /// Completely delete the database file (nuclear option)
  Future<void> deleteDatabaseFile() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _databaseName);
      
      await deleteDatabase(path);
      
      _logger.i(_tag, 'Database file completely deleted');
    } catch (e) {
      _logger.e(_tag, 'Failed to delete database file: ${e.toString()}');
      rethrow;
    }
  }

  /// Download and cache user photo locally
  /// Returns the local file path where the photo is stored
  /// Only downloads if URL has changed or no cached photo exists
  Future<String?> downloadAndCachePhoto(String uid, String? photoURL) async {
    if (photoURL == null || photoURL.isEmpty) {
      _logger.d(_tag, '📸 No photo URL provided for user: $uid');
      return null;
    }
    
    // Skip if the photoURL is already a local file path
    if (photoURL.startsWith('file://') || photoURL.startsWith('/')) {
      _logger.i(_tag, '📸 Photo URL is already a local file path for user: $uid - SKIPPING DOWNLOAD');
      return photoURL.startsWith('file://') ? photoURL.replaceFirst('file://', '') : photoURL;
    }
    
    try {
      _logger.i(_tag, 'Checking if photo needs download for user: $uid');
      
      // Check if we already have this exact URL cached in database
      final db = await database;
      final results = await db.query(
        _usersTable,
        columns: ['photo_url', 'photo_data'],
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        final existingPhotoUrl = results.first['photo_url'] as String?;
        final existingPhotoPath = results.first['photo_data'] as String?;
        
        // If URL hasn't changed and cached file exists, skip download
        if (existingPhotoUrl == photoURL && existingPhotoPath != null) {
          final existingFile = File(existingPhotoPath);
          if (await existingFile.exists()) {
            _logger.i(_tag, 'Same URL already cached and file exists - skipping download');
            return existingPhotoPath;
          } else {
            _logger.w(_tag, 'Cached file missing, will re-download: $existingPhotoPath');
          }
        } else if (existingPhotoUrl != photoURL) {
          _logger.i(_tag, 'URL changed, clearing old cached photo');
          
          // Clear old cached photo file if it exists and URL changed
          if (existingPhotoPath != null) {
            final oldFile = File(existingPhotoPath);
            if (await oldFile.exists()) {
              await oldFile.delete();
              _logger.d(_tag, 'Deleted old cached photo: $existingPhotoPath');
            }
          }
        }
      }
      
      // Get app's documents directory for storing photos
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/user_photos');
      
      // Create photos directory if it doesn't exist
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
        _logger.d(_tag, '📁 Created photos directory: ${photosDir.path}');
      }
      
      // Generate filename based on UID and URL hash
      final urlHash = photoURL.hashCode.abs().toString();
      final fileName = '${uid}_$urlHash.jpg';
      final localPath = '${photosDir.path}/$fileName';
      final localFile = File(localPath);
      
      // Check if photo with this hash already exists locally (should not happen with above logic)
      if (await localFile.exists()) {
        _logger.i(_tag, 'Photo already cached locally for user: $uid');
        return localPath;
      }
      
      // Download the photo
      _logger.i(_tag, 'Downloading photo for user: $uid');
      final response = await _dio.get(
        photoURL,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200) {
        // Save photo to local file
        await localFile.writeAsBytes(response.data);
        _logger.i(_tag, 'Photo successfully cached for user: $uid');
        return localPath;
      } else {
        _logger.w(_tag, 'Failed to download photo for user: $uid, status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e(_tag, 'Error downloading photo for user: $uid - ${e.toString()}');
      return null;
    }
  }
  

  

  
  /// Clear all cached photos
  Future<void> clearAllCachedPhotos() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/user_photos');
      
      if (await photosDir.exists()) {
        await photosDir.delete(recursive: true);
        _logger.i(_tag, 'All cached photos cleared');
      }
      
      // Also clear from database
      final db = await database;
      await db.update(
        _usersTable,
        {'photo_data': null},
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to clear all cached photos: ${e.toString()}');
    }
  }

  /// Clean up orphaned photo files that are no longer referenced in database
  /// This prevents storage bloat from old cached photos
  Future<void> cleanupOrphanedPhotos() async {
    try {
      _logger.d(_tag, 'Starting cleanup of orphaned photo files...');
      
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/user_photos');
      
      if (!await photosDir.exists()) {
        _logger.d(_tag, 'Photos directory does not exist, nothing to clean');
        return;
      }
      
      // Get all referenced photo paths from database
      final db = await database;
      final results = await db.query(
        _usersTable,
        columns: ['photo_data'],
        where: 'photo_data IS NOT NULL AND photo_data != ""',
      );
      
      final referencedPaths = results
          .map((row) => row['photo_data'] as String?)
          .where((path) => path != null && path.isNotEmpty)
          .toSet();
      
      _logger.d(_tag, 'Found ${referencedPaths.length} referenced photos in database');
      
      // Get all photo files in directory
      final files = await photosDir.list().toList();
      final photoFiles = files.whereType<File>().where((file) => 
        file.path.endsWith('.jpg') || file.path.endsWith('.png')
      ).toList();
      
      _logger.d(_tag, 'Found ${photoFiles.length} photo files on disk');
      
      // Delete orphaned files
      int deletedCount = 0;
      for (final file in photoFiles) {
        if (!referencedPaths.contains(file.path)) {
          try {
            await file.delete();
            deletedCount++;
            _logger.d(_tag, 'Deleted orphaned photo: ${file.path}');
          } catch (e) {
            _logger.w(_tag, 'Failed to delete orphaned photo ${file.path}: $e');
          }
        }
      }
      
      _logger.i(_tag, 'Cleanup completed: deleted $deletedCount orphaned photo files');
    } catch (e) {
      _logger.e(_tag, 'Failed to cleanup orphaned photos: ${e.toString()}');
    }
  }

  // --- App Settings Management ---

  /// Set an app-wide setting value
  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await db.insert(
        _appSettingsTable,
        {
          'key': key,
          'value': value,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      _logger.d(_tag, 'Setting saved: $key = $value');
    } catch (e) {
      _logger.e(_tag, 'Failed to save setting $key: ${e.toString()}');
      rethrow;
    }
  }

  /// Get an app-wide setting value
  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      
      final results = await db.query(
        _appSettingsTable,
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (results.isEmpty) {
        _logger.d(_tag, 'Setting not found: $key');
        return null;
      }

      final value = results.first['value'] as String;
      _logger.d(_tag, 'Setting retrieved: $key = $value');
      return value;
    } catch (e) {
      _logger.e(_tag, 'Failed to get setting $key: ${e.toString()}');
      return null;
    }
  }

  /// Get a boolean setting value with default
  Future<bool> getBoolSetting(String key, {bool defaultValue = false}) async {
    try {
      final value = await getSetting(key);
      if (value == null) return defaultValue;
      return value.toLowerCase() == 'true';
    } catch (e) {
      _logger.e(_tag, 'Failed to get boolean setting $key: ${e.toString()}');
      return defaultValue;
    }
  }

  /// Set a boolean setting value
  Future<void> setBoolSetting(String key, bool value) async {
    await setSetting(key, value.toString());
  }

  /// Remove a setting
  Future<void> removeSetting(String key) async {
    try {
      final db = await database;
      
      await db.delete(
        _appSettingsTable,
        where: 'key = ?',
        whereArgs: [key],
      );
      
      _logger.d(_tag, 'Setting removed: $key');
    } catch (e) {
      _logger.e(_tag, 'Failed to remove setting $key: ${e.toString()}');
      rethrow;
    }
  }

  /// Clear all app settings
  Future<void> clearAllSettings() async {
    try {
      final db = await database;
      await db.delete(_appSettingsTable);
      _logger.i(_tag, 'All app settings cleared');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear all settings: ${e.toString()}');
      rethrow;
    }
  }

  /// Get all settings as a map
  Future<Map<String, String>> getAllSettings() async {
    try {
      final db = await database;
      
      final results = await db.query(_appSettingsTable);
      
      final settingsMap = <String, String>{};
      for (final row in results) {
        settingsMap[row['key'] as String] = row['value'] as String;
      }
      
      return settingsMap;
    } catch (e) {
      _logger.e(_tag, 'Failed to get all settings: ${e.toString()}');
      return {};
    }
  }

  // --- Relationship Caching Methods ---

  /// Cache friends list for a user
  Future<void> cacheFriends(String uid, List<Map<String, dynamic>> friends) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Clear existing cached friends for this user
      await db.delete(_friendsTable, where: 'uid = ?', whereArgs: [uid]);
      
      // Insert new friends data
      for (final friend in friends) {
        await db.insert(_friendsTable, {
          'uid': uid,
          'user_id': friend['uid'] as String,
          'display_name': friend['displayName'] as String?,
          'photo_url': friend['photoURL'] as String?,
          'relationship_id': friend['relationshipId'] as String,
          'cached_at': now,
        });
      }
      
      _logger.i(_tag, 'Cached ${friends.length} friends for user: $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to cache friends: ${e.toString()}');
    }
  }

  /// Get cached friends for a user
  Future<List<Map<String, dynamic>>> getCachedFriends(String uid) async {
    try {
      final db = await database;
      
      final results = await db.query(
        _friendsTable,
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'cached_at DESC',
      );
      
      return results.map((row) => {
        'uid': row['user_id'] as String,
        'displayName': row['display_name'] as String?,
        'photoURL': row['photo_url'] as String?,
        'relationshipId': row['relationship_id'] as String,
      }).toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached friends: ${e.toString()}');
      return [];
    }
  }

  /// Cache pending requests for a user
  Future<void> cachePendingRequests(String uid, List<Map<String, dynamic>> requests) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Clear existing cached pending requests for this user
      await db.delete(_pendingRequestsTable, where: 'uid = ?', whereArgs: [uid]);
      
      // Insert new pending requests data
      for (final request in requests) {
        await db.insert(_pendingRequestsTable, {
          'uid': uid,
          'user_id': request['uid'] as String,
          'display_name': request['displayName'] as String?,
          'photo_url': request['photoURL'] as String?,
          'relationship_id': request['relationshipId'] as String,
          'cached_at': now,
        });
      }
      
      _logger.i(_tag, 'Cached ${requests.length} pending requests for user: $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to cache pending requests: ${e.toString()}');
    }
  }

  /// Get cached pending requests for a user
  Future<List<Map<String, dynamic>>> getCachedPendingRequests(String uid) async {
    try {
      final db = await database;
      
      final results = await db.query(
        _pendingRequestsTable,
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'cached_at DESC',
      );
      
      return results.map((row) => {
        'uid': row['user_id'] as String,
        'displayName': row['display_name'] as String?,
        'photoURL': row['photo_url'] as String?,
        'relationshipId': row['relationship_id'] as String,
      }).toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached pending requests: ${e.toString()}');
      return [];
    }
  }

  /// Cache blocked users for a user
  Future<void> cacheBlockedUsers(String uid, List<Map<String, dynamic>> blockedUsers) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Clear existing cached blocked users for this user
      await db.delete(_blockedUsersTable, where: 'uid = ?', whereArgs: [uid]);
      
      // Insert new blocked users data
      for (final blockedUser in blockedUsers) {
        await db.insert(_blockedUsersTable, {
          'uid': uid,
          'user_id': blockedUser['uid'] as String,
          'display_name': blockedUser['displayName'] as String?,
          'photo_url': blockedUser['photoURL'] as String?,
          'relationship_id': blockedUser['relationshipId'] as String,
          'cached_at': now,
        });
      }
      
      _logger.i(_tag, 'Cached ${blockedUsers.length} blocked users for user: $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to cache blocked users: ${e.toString()}');
    }
  }

  /// Get cached blocked users for a user
  Future<List<Map<String, dynamic>>> getCachedBlockedUsers(String uid) async {
    try {
      final db = await database;
      
      final results = await db.query(
        _blockedUsersTable,
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'cached_at DESC',
      );
      
      return results.map((row) => {
        'uid': row['user_id'] as String,
        'displayName': row['display_name'] as String?,
        'photoURL': row['photo_url'] as String?,
        'relationshipId': row['relationship_id'] as String,
      }).toList();
    } catch (e) {
      _logger.e(_tag, 'Failed to get cached blocked users: ${e.toString()}');
      return [];
    }
  }

  /// Clear all relationship cache for a user
  Future<void> clearRelationshipCache(String uid) async {
    try {
      final db = await database;
      
      await db.delete(_friendsTable, where: 'uid = ?', whereArgs: [uid]);
      await db.delete(_pendingRequestsTable, where: 'uid = ?', whereArgs: [uid]);
      await db.delete(_blockedUsersTable, where: 'uid = ?', whereArgs: [uid]);
      
      _logger.i(_tag, 'Cleared all relationship cache for user: $uid');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear relationship cache: ${e.toString()}');
    }
  }

  /// Clear all relationship cache for all users
  Future<void> clearAllRelationshipCache() async {
    try {
      final db = await database;
      
      await db.delete(_friendsTable);
      await db.delete(_pendingRequestsTable);
      await db.delete(_blockedUsersTable);
      
      _logger.i(_tag, 'Cleared all relationship cache for all users');
    } catch (e) {
      _logger.e(_tag, 'Failed to clear all relationship cache: ${e.toString()}');
    }
  }
}
